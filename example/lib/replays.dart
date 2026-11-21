// Three recorded playground runs (CopilotKit's replay fixtures), played back
// frame by frame. Each frame holds the whole surface so far, so a frame is
// shown by a fresh processor that applies its messages.

import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The replays bundled in `assets/replays/`.
const List<String> replayNames = [
  'sales-dashboard',
  'tokyo-trip',
  'lisbon-weather',
];

/// One recorded run: its prompt and its frames of A2UI messages.
class Replay {
  Replay({required this.prompt, required this.frames});

  /// Reads a replay's JSON.
  factory Replay.fromJson(Map<String, Object?> json) => Replay(
    prompt: json['prompt'] as String? ?? '',
    frames: [
      for (final frame in (json['frames'] as List?) ?? const <Object?>[])
        if (frame is Map)
          (
            ms: (frame['t'] as num?)?.toInt() ?? 0,
            messages: List<Object?>.from(frame['ops'] as List? ?? const []),
          ),
    ],
  );

  final String prompt;
  final List<({int ms, List<Object?> messages})> frames;

  /// Loads the bundled replay [name].
  static Future<Replay> load(String name, {AssetBundle? bundle}) async {
    final text = await (bundle ?? rootBundle).loadString(
      'assets/replays/$name.json',
    );
    return Replay.fromJson(jsonDecode(text) as Map<String, Object?>);
  }
}

/// Plays a [Replay]: a frame slider, previous and next, and play, which
/// steps through the frames at their recorded pace.
class ReplayView extends StatefulWidget {
  const ReplayView({required this.replay, this.onAction, super.key});

  final Replay replay;

  final void Function(A2uiRendererAction action)? onAction;

  @override
  State<ReplayView> createState() => _ReplayViewState();
}

class _ReplayViewState extends State<ReplayView> {
  int _frame = 0;
  Timer? _timer;
  MessageProcessor<ComponentImplementation>? _processor;
  A2uiIdNormalizer _ids = A2uiIdNormalizer();
  final List<SurfaceModel<ComponentImplementation>> _surfaces = [];
  final List<A2uiRendererError> _errors = [];

  @override
  void initState() {
    super.initState();
    _show(0);
  }

  @override
  void didUpdateWidget(ReplayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.replay, widget.replay)) {
      _stop();
      _show(0);
    }
  }

  @override
  void dispose() {
    _stop();
    _processor?.dispose();
    super.dispose();
  }

  /// Shows frame [index]: its messages through the id normaliser, as a
  /// playground agent's must go, into a fresh processor.
  void _show(int index) {
    _processor?.dispose();
    _surfaces.clear();
    _errors.clear();
    _ids = A2uiIdNormalizer();
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [a2uiKitCatalog()],
      reportErrorsOnly: true,
    );
    processor.model.onSurfaceCreated.subscribe((surface) {
      _surfaces.add(surface);
      surface.onError.subscribe(_errors.add);
    });
    processor.model.onError.subscribe(_errors.add);
    processor.model.onAction.subscribe(
      (action) => widget.onAction?.call(_ids.outboundAction(action)),
    );
    final frames = widget.replay.frames;
    if (frames.isNotEmpty) {
      processor.processMessages(_ids.normalizeMessages(frames[index].messages));
    }
    _processor = processor;
    _frame = index;
  }

  void _go(int index) => setState(() => _show(index));

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _play() {
    final frames = widget.replay.frames;
    if (_frame >= frames.length - 1) _go(0);
    void next() {
      if (!mounted || _frame >= frames.length - 1) {
        setState(_stop);
        return;
      }
      final wait = (frames[_frame + 1].ms - frames[_frame].ms).clamp(16, 1000);
      _timer = Timer(Duration(milliseconds: wait), () {
        _go(_frame + 1);
        next();
      });
    }

    setState(next);
  }

  @override
  Widget build(BuildContext context) {
    final frames = widget.replay.frames;
    final last = frames.isEmpty ? 0 : frames.length - 1;
    final playing = _timer != null;
    final ms = frames.isEmpty ? 0 : frames[_frame].ms;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.replay.prompt,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous frame',
              icon: const Icon(Icons.skip_previous),
              onPressed: _frame > 0 ? () => _go(_frame - 1) : null,
            ),
            IconButton(
              tooltip: playing ? 'Pause' : 'Play',
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: frames.length < 2
                  ? null
                  : playing
                  ? () => setState(_stop)
                  : _play,
            ),
            IconButton(
              tooltip: 'Next frame',
              icon: const Icon(Icons.skip_next),
              onPressed: _frame < last ? () => _go(_frame + 1) : null,
            ),
            Expanded(
              child: Slider(
                value: _frame.toDouble(),
                max: last.toDouble(),
                divisions: last == 0 ? null : last,
                label: 'Frame ${_frame + 1}',
                onChanged: last == 0
                    ? null
                    : (value) {
                        _stop();
                        _go(value.round());
                      },
              ),
            ),
          ],
        ),
        Text(
          'Frame ${_frame + 1} of ${frames.length} · $ms ms'
          '${_errors.isEmpty ? '' : ' · ${_errors.length} errors'}',
        ),
        const SizedBox(height: 12),
        for (final surface in _surfaces)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: A2uiSurface(key: ObjectKey(surface), surface: surface),
          ),
      ],
    );
  }
}

/// Loads the replay [name] and plays it.
class ReplayPage extends StatefulWidget {
  const ReplayPage({required this.name, this.onAction, super.key});

  final String name;

  final void Function(A2uiRendererAction action)? onAction;

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  late Future<Replay> _replay = Replay.load(widget.name);

  @override
  void didUpdateWidget(ReplayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) _replay = Replay.load(widget.name);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Replay>(
    future: _replay,
    builder: (context, snapshot) {
      final replay = snapshot.data;
      if (replay == null) {
        return snapshot.hasError
            ? Text('${snapshot.error}')
            : const Center(child: CircularProgressIndicator());
      }
      return ReplayView(replay: replay, onAction: widget.onAction);
    },
  );
}
