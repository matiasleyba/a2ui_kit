// Golden images of the ported components (phase 1 and the phase 2a
// charts): each sample in the light and dark playground look at text scale
// 1, in light at text scale 2, and in the standard look, 360px wide. Update
// them with `flutter test --update-goldens test/goldens`.

import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';

import '../helpers/harness.dart' show copilotKitHost;
import 'chart_samples.dart';
import 'samples.dart';

/// A surface of [components] that owns its processor.
class _Sample extends StatefulWidget {
  const _Sample(this.components, {this.look = A2uiKitLook.playground});

  final List<Map<String, Object?>> components;
  final A2uiKitLook look;

  @override
  State<_Sample> createState() => _SampleState();
}

class _SampleState extends State<_Sample> {
  late final MessageProcessor<ComponentImplementation> _processor =
      MessageProcessor<ComponentImplementation>(
        catalogs: [a2uiKitCatalog(options: A2uiKitOptions(look: widget.look))],
      );
  late SurfaceModel<ComponentImplementation> _surface;

  @override
  void initState() {
    super.initState();
    _processor.model.onSurfaceCreated.subscribe((s) => _surface = s);
    _processor.processMessages([
      {
        'version': '1.0',
        'createSurface': {
          'surfaceId': 'golden',
          'catalogId': kA2uiPlaygroundCatalogId,
        },
      },
      {
        'version': '1.0',
        'updateComponents': {
          'surfaceId': 'golden',
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
  Widget build(BuildContext context) => A2uiSurface(surface: _surface);
}

/// [child] on the surface colour of [brightness], 360px wide.
Widget _frame(Brightness brightness, Widget child, {A2uiKitLook? look}) {
  final theme = A2uiKitTheme.fromLook(
    look ?? A2uiKitLook.playground,
    brightness,
  );
  return Theme(
    data: ThemeData(brightness: brightness),
    // The page's type, a CopilotKit chat's: the standard look takes it,
    // the playground look sets its own.
    child: DefaultTextStyle.merge(
      style: copilotKitHost(brightness),
      child: ColoredBox(
        color: theme.color(A2uiColorToken.surface),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(width: 360, child: child),
        ),
      ),
    ),
  );
}

void main() {
  for (final MapEntry(key: name, value: components) in {
    ...goldenSamples,
    ...chartSamples,
  }.entries) {
    unawaited(
      goldenTest(
        '$name renders',
        fileName: name,
        builder: () => GoldenTestGroup(
          columns: 1,
          children: [
            GoldenTestScenario(
              name: 'light',
              child: _frame(Brightness.light, _Sample(components)),
            ),
            GoldenTestScenario(
              name: 'dark',
              child: _frame(Brightness.dark, _Sample(components)),
            ),
            GoldenTestScenario.withTextScaleFactor(
              name: 'light, text scale 2',
              textScaler: const TextScaler.linear(2),
              child: _frame(Brightness.light, _Sample(components)),
            ),
            GoldenTestScenario(
              name: 'standard look',
              child: _frame(
                Brightness.light,
                _Sample(components, look: A2uiKitLook.standard),
                look: A2uiKitLook.standard,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
