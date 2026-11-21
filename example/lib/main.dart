// A gallery of a2ui_kit surfaces: pick a sample or a recorded playground
// run, the look, the brightness and the text scale.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit_example/replays.dart';
import 'package:a2ui_kit_example/samples.dart';
import 'package:flutter/material.dart';

/// The menu's entry for the replay [name].
String replayEntry(String name) => 'replay: $name';

void main() => runApp(const GalleryApp());

class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key, this.initialSample});

  /// The menu entry shown first: the first sample when null.
  final String? initialSample;

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

/// The looks the gallery shows: the two shipped ones and a Material
/// colour scheme mapped onto the tokens.
enum _Look { playground, standard, material }

class _GalleryAppState extends State<GalleryApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  Brightness _brightness = Brightness.light;
  _Look _look = _Look.playground;
  double _textScale = 1;
  late String _sample = widget.initialSample ?? gallerySamples.keys.first;

  A2uiKitTheme get _kit => switch (_look) {
    _Look.playground => A2uiKitTheme.playground(_brightness),
    _Look.standard => A2uiKitTheme.standard(_brightness),
    _Look.material => A2uiKitTheme.fromColorScheme(
      ColorScheme.fromSeed(
        seedColor: const Color(0xff0b57d0),
        brightness: _brightness,
      ),
    ),
  };

  void _showAction(A2uiRendererAction action) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${action.name} ${action.context}')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final kit = _kit;
    return MaterialApp(
      title: 'a2ui_kit gallery',
      scaffoldMessengerKey: _messenger,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: _brightness, extensions: [kit]),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('a2ui_kit'),
          actions: [
            DropdownButton<String>(
              value: _sample,
              items: [
                for (final name in gallerySamples.keys)
                  DropdownMenuItem(value: name, child: Text(name)),
                for (final name in replayNames)
                  DropdownMenuItem(
                    value: replayEntry(name),
                    child: Text(replayEntry(name)),
                  ),
              ],
              onChanged: (name) => setState(() => _sample = name!),
            ),
            IconButton(
              tooltip: 'Brightness',
              icon: Icon(
                _brightness == Brightness.light
                    ? Icons.dark_mode
                    : Icons.light_mode,
              ),
              onPressed: () => setState(
                () => _brightness = _brightness == Brightness.light
                    ? Brightness.dark
                    : Brightness.light,
              ),
            ),
            IconButton(
              tooltip: 'Look',
              icon: const Icon(Icons.palette),
              onPressed: () =>
                  setState(() => _look = _Look.values[(_look.index + 1) % 3]),
            ),
          ],
        ),
        body: Column(
          children: [
            Slider(
              value: _textScale,
              min: 1,
              max: 2,
              divisions: 4,
              label: 'Text scale $_textScale',
              onChanged: (value) => setState(() => _textScale = value),
            ),
            Expanded(
              child: ColoredBox(
                color: kit.color(A2uiColorToken.surface),
                child: MediaQuery.withClampedTextScaling(
                  minScaleFactor: _textScale,
                  maxScaleFactor: _textScale,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: switch (gallerySamples[_sample]) {
                          final components? => SampleSurface(
                            key: ValueKey(_sample),
                            components: components,
                            onAction: _showAction,
                          ),
                          null => ReplayPage(
                            key: ValueKey(_sample),
                            name: _sample.substring(replayEntry('').length),
                            onAction: _showAction,
                          ),
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A surface of [components], with its own message processor. The agent's
/// messages go through an [A2uiIdNormalizer], as a playground agent's
/// must (its ids may hold hyphens), then an [A2uiUserOwnedData], so a
/// later agent write keeps what the user typed; [onAction] gets each
/// action with the agent's ids.
class SampleSurface extends StatefulWidget {
  const SampleSurface({required this.components, this.onAction, super.key});

  final List<Map<String, Object?>> components;

  final void Function(A2uiRendererAction action)? onAction;

  @override
  State<SampleSurface> createState() => _SampleSurfaceState();
}

class _SampleSurfaceState extends State<SampleSurface> {
  final _processor = MessageProcessor<ComponentImplementation>(
    catalogs: [a2uiKitCatalog()],
  );
  final _ids = A2uiIdNormalizer();
  late final _owned = A2uiUserOwnedData(_processor);
  SurfaceModel<ComponentImplementation>? _surface;

  /// The agent's [messages], as an app gives them to the processor.
  void _fromAgent(List<Object?> messages) => _processor.processMessages(
    _owned.filterMessages(_ids.normalizeMessages(messages)),
  );

  @override
  void initState() {
    super.initState();
    _processor.model.onSurfaceCreated.subscribe((s) => _surface = s);
    _processor.model.onAction.subscribe(
      (action) => widget.onAction?.call(_ids.outboundAction(action)),
    );
    _fromAgent([
      {
        'version': '1.0',
        'createSurface': {
          'surfaceId': 'sample',
          'catalogId': kA2uiPlaygroundCatalogId,
        },
      },
      {
        'version': '1.0',
        'updateComponents': {
          'surfaceId': 'sample',
          'components': widget.components,
        },
      },
    ]);
  }

  @override
  void dispose() {
    _processor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = _surface;
    return surface == null
        ? const SizedBox.shrink()
        : A2uiSurface(surface: surface);
  }
}
