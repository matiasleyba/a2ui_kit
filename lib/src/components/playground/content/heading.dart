import 'dart:math' as math;

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How long a streamed word takes to fade in.
const Duration streamWordFade = Duration(milliseconds: 350);

/// The delay between two streamed words.
const Duration streamWordGap = Duration(milliseconds: 60);

const Cubic _streamCurve = Cubic(.22, 1, .36, 1);

/// The playground `Heading`: a surface title with an optional `eyebrow`
/// after it on the same line and a `subtitle` under it.
///
/// Level 1 is 24px, 2 (the default) 19px and 3 15.5px, semibold. The words
/// fade in one after another; when the text grows (a streamed update) only
/// the new words do. Under reduced motion they show at once. CSS's
/// balanced wrapping (`text-wrap: balance`) has no Flutter equivalent.
Widget buildHeading(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = HeadingProps(props);
  final tokens = playgroundTokens(context);
  final (size, height) = switch (view.level) {
    HeadingLevel.one => (24.0, 1.25),
    HeadingLevel.three => (15.5, null),
    _ => (19.0, 1.375),
  };
  final eyebrow = view.eyebrow;
  final subtitle = view.subtitle;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 4,
    children: [
      TitleLine(
        title: Semantics(
          header: true,
          child: StreamWords(
            text: view.text ?? '',
            style: playgroundText(
              size,
              weight: FontWeight.w600,
              height: height,
              trackingEm: -.025,
              color: tokens.foreground,
            ),
          ),
        ),
        eyebrow: eyebrow == null || eyebrow.isEmpty
            ? null
            : Text(eyebrow, style: playgroundLabelStyle(tokens)),
      ),
      if (subtitle != null && subtitle.isNotEmpty)
        StreamWords(
          text: subtitle,
          style: playgroundText(
            13,
            height: 1.625,
            color: tokens.mutedForeground,
          ),
        ),
    ],
  );
}

/// A title and an eyebrow after it, on one baseline, wrapping (`flex
/// flex-wrap items-baseline gap-x-2.5 gap-y-0.5`).
class TitleLine extends StatelessWidget {
  /// The [title] and its [eyebrow].
  const TitleLine({required this.title, this.eyebrow, super.key});

  /// The title.
  final Widget title;

  /// The eyebrow, or null.
  final Widget? eyebrow;

  @override
  Widget build(BuildContext context) => CssFlex(
    flex: const A2uiFlexStyle(
      direction: Axis.horizontal,
      wrap: A2uiWrap.wrap,
      align: A2uiAlign.baseline,
      columnGap: 10,
      rowGap: 2,
    ),
    children: [title, ?eyebrow],
  );
}

/// Text whose words fade in one after another (transitions.dev's streaming
/// text): 350ms each, 60ms apart. When the text grows, only the words after
/// the ones already shown fade in.
class StreamWords extends StatefulWidget {
  /// Shows [text] in [style].
  const StreamWords({required this.text, this.style, super.key});

  /// The text.
  final String text;

  /// The style.
  final TextStyle? style;

  @override
  State<StreamWords> createState() => _StreamWordsState();
}

class _StreamWordsState extends State<StreamWords>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);

  /// The time of the last frame, on a clock that runs on across ticks.
  Duration _now = Duration.zero;
  Duration _tickerBase = Duration.zero;
  List<String> _words = const [];

  /// When each token starts fading in. A token keeps its start when the
  /// text grows, as a CSS transition already running keeps running.
  final List<Duration> _starts = [];

  static List<String> _split(String text) => [
    for (final match in RegExp(r'\s+|\S+').allMatches(text)) match[0]!,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_words.isEmpty) _update(initial: true);
  }

  @override
  void didUpdateWidget(StreamWords oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _update(initial: false);
  }

  bool get _settled => _starts.every((start) => _now >= start + streamWordFade);

  void _tick(Duration elapsed) {
    setState(() => _now = _tickerBase + elapsed);
    if (_settled) _ticker.stop();
  }

  /// The playground's `StreamWords`: the tokens after the ones already
  /// shown fade in, `--stream-gap` apart from now; the others keep theirs.
  void _update({required bool initial}) {
    final words = _split(widget.text);
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final base = initial ? 0 : math.min(_words.length, words.length);
    _words = words;
    if (_starts.length > words.length) {
      _starts.removeRange(words.length, _starts.length);
    }
    for (var i = base; i < words.length; i++) {
      final start = reduced
          ? _now - streamWordFade
          : _now + streamWordGap * math.min(math.max(0, i - base) >> 1, 24);
      if (i < _starts.length) {
        _starts[i] = start;
      } else {
        _starts.add(start);
      }
    }
    if (!_settled && !_ticker.isActive) {
      _tickerBase = _now;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final color = style.color ?? const Color(0xff000000);
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < _words.length; i++)
            TextSpan(
              text: _words[i],
              style: switch (_opacity(i)) {
                final o when o >= 1 || _words[i].trim().isEmpty => null,
                final o => TextStyle(
                  color: color.withValues(alpha: color.a * o),
                ),
              },
            ),
        ],
      ),
      style: widget.style,
    );
  }

  /// The opacity of the [index]th token now.
  double _opacity(int index) {
    final local =
        ((_now - _starts[index]).inMicroseconds / streamWordFade.inMicroseconds)
            .clamp(0.0, 1.0);
    return local >= 1 ? 1 : _streamCurve.transform(local).clamp(0.0, 1.0);
  }
}

// PORT STATUS: confidence=medium todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/content.tsx
