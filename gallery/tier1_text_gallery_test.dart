// Pictures of tier 1's text components for the user (RULEBOOK section 7: a
// tier stops for the user to look). Not part of the suite: `flutter test`
// runs only test/, so this runs on its own:
//
//   flutter test gallery/tier1_text_gallery_test.dart
//
// Each of Math, Bold, Italic, Underline, Strikethrough, Code and Blockquote
// is drawn with tutor content in the standard catalog, in both looks, light
// and dark, 390px wide, with real fonts (not the test font): Roboto (the
// Flutter SDK's Material fonts) for the text, flutter_math_fork's KaTeX fonts
// for the formulas, and Consolas (a Windows font, one of the theme's mono
// fallbacks) for the code.
// One PNG per component, look and brightness goes to `$A2UI_GALLERY_OUT`,
// else build/gallery/ in the package, at twice the pixels. Consolas is read
// from Windows' fonts folder, so this gallery runs on Windows.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:a2ui_flutter/a2ui_flutter.dart' show A2uiSurface;
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/harness.dart';

/// Where the pictures go.
final String _out = Platform.environment['A2UI_GALLERY_OUT'] ?? 'build/gallery';

/// The width of a phone screen.
const double _width = 390;

/// The Flutter SDK's Material fonts, beside the test engine.
Directory _materialFonts() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (!Directory('${dir.path}/material_fonts').existsSync()) {
    dir = dir.parent;
  }
  return Directory('${dir.path}/material_fonts');
}

/// flutter_math_fork's KaTeX fonts, from the package config.
Directory _katexFonts() {
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, Object?>;
  final packages = (config['packages']! as List).cast<Map<String, Object?>>();
  final root =
      packages.firstWhere((p) => p['name'] == 'flutter_math_fork')['rootUri']!
          as String;
  return Directory('${Uri.parse(root).toFilePath()}/lib/katex_fonts/fonts');
}

Future<void> _loadFont(String family, Iterable<File> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  final roboto = _materialFonts();
  await _loadFont('Roboto', [
    for (final name in [
      'regular',
      'italic',
      'medium',
      'mediumitalic',
      'bold',
      'bolditalic',
      'black',
      'blackitalic',
    ])
      File('${roboto.path}/roboto-$name.ttf'),
  ]);
  final katex = _katexFonts();
  final families = <String, List<File>>{};
  for (final file in katex.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (!name.endsWith('.ttf')) continue;
    final family = name.substring(0, name.indexOf('-'));
    (families[family] ??= []).add(file);
  }
  for (final MapEntry(key: family, value: files) in families.entries) {
    await _loadFont('packages/flutter_math_fork/$family', files);
  }
  // The theme's mono family is the generic `monospace`, which the test
  // engine has no font for; Consolas comes from the theme's fallbacks.
  // Consolas is loaded under both names, so the code draws in a monospace
  // font whichever the engine resolves first.
  for (final family in ['monospace', 'Consolas']) {
    await _loadFont(family, [
      for (final name in ['consola', 'consolab', 'consolai', 'consolaz'])
        File('C:/Windows/Fonts/$name.ttf'),
    ]);
  }
}

/// The surfaces to draw: a name and its components.
final Map<String, List<Map<String, Object?>>> _samples = {
  'math': [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['t1', 'm1', 't2', 'm2', 'c', 'e'],
    },
    {
      'id': 't1',
      'component': 'Text',
      'text': 'For a thin lens, the **lens formula** is',
      'children': ['i1'],
    },
    {
      'id': 'i1',
      'component': 'Math',
      'value': r'\frac{1}{v} - \frac{1}{u} = \frac{1}{f}',
    },
    {
      'id': 'm1',
      'component': 'Math',
      'value': r'\frac{1}{v} - \frac{1}{u} = \frac{1}{f}',
      'block': true,
    },
    {
      'id': 't2',
      'component': 'Text',
      'text': 'A body of mass m moving at speed v has kinetic energy',
      'children': ['i2'],
    },
    {'id': 'i2', 'component': 'Math', 'value': r'K = \tfrac{1}{2}mv^2'},
    {
      'id': 'm2',
      'component': 'Math',
      'value': r'K = \frac{1}{2}mv^2 = \frac{p^2}{2m}',
      'block': true,
    },
    {
      'id': 'c',
      'component': 'Caption',
      'text': 'TeX that does not parse shows its source in red:',
    },
    {'id': 'e', 'component': 'Math', 'value': r'\frac{1}{v'},
  ],
  for (final (name, component, alone) in [
    ('bold', 'Bold', "Newton's second law"),
    ('italic', 'Italic', 'Velocity is a vector; speed is a scalar.'),
    ('underline', 'Underline', 'Units must match on both sides.'),
    ('strikethrough', 'Strikethrough', 'Heavier bodies fall faster.'),
  ])
    name: [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['sentence', 'alone', if (component == 'Bold') 'weight'],
      },
      {
        'id': 'sentence',
        'component': 'Text',
        'text': 'In code, `F = m * a`; in words,',
        'children': ['b', 'i', 'u', 's'],
      },
      {'id': 'b', 'component': 'Bold', 'text': 'force'},
      {'id': 'i', 'component': 'Italic', 'text': ' equals mass'},
      {'id': 'u', 'component': 'Underline', 'text': ' times acceleration,'},
      {'id': 's', 'component': 'Strikethrough', 'text': ' not velocity'},
      {'id': 'alone', 'component': component, 'text': alone},
      if (component == 'Bold')
        {
          'id': 'weight',
          'component': 'Bold',
          'text': 'fontWeight: medium (500)',
          'fontWeight': 'medium',
        },
    ],
  'code': [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['t', 'k'],
    },
    {
      'id': 't',
      'component': 'Text',
      'text': 'Check your answer with a few lines of Python:',
    },
    {
      'id': 'k',
      'component': 'Code',
      'language': 'python',
      'text':
          'def kinetic_energy(m, v):\n'
          '    """Kinetic energy in joules: K = mv^2 / 2."""\n'
          '    return 0.5 * m * v ** 2\n'
          '\n'
          'print(kinetic_energy(2, 3))  # 9.0 J\n',
    },
  ],
  'blockquote': [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['t', 'q'],
    },
    {'id': 't', 'component': 'Title', 'text': 'Laws of motion', 'size': 'sm'},
    {
      'id': 'q',
      'component': 'Blockquote',
      'text':
          "**Newton's second law of motion:** the rate of change of "
          'momentum of a body is directly proportional to the *applied '
          'force* and takes place in the direction in which the force acts.',
    },
  ],
};

void main() {
  setUpAll(() async {
    await _loadFonts();
    Directory(_out).createSync(recursive: true);
  });

  for (final MapEntry(key: name, value: components) in _samples.entries) {
    for (final look in A2uiKitLook.values) {
      for (final brightness in Brightness.values) {
        final file = '$name-${look.name}-${brightness.name}.png';
        testWidgets(file, (tester) async {
          tester.view
            ..physicalSize = const Size(_width, 1600)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final theme = A2uiKitTheme.fromLook(look, brightness);
          final surfaces = TestSurfaces(
            catalog: a2uiKitStandardCatalog(
              options: A2uiKitOptions(look: look),
            ),
          )..create(components, catalogId: kA2uiStandardCatalogId);
          addTearDown(surfaces.dispose);
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(brightness: brightness, extensions: [theme]),
              home: Scaffold(
                backgroundColor: theme.color(A2uiColorToken.surface),
                body: Align(
                  alignment: Alignment.topLeft,
                  child: RepaintBoundary(
                    key: key,
                    child: ColoredBox(
                      color: theme.color(A2uiColorToken.surface),
                      child: SizedBox(
                        width: _width,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: A2uiSurface(surface: surfaces.surface),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(key),
            );
            final image = await boundary.toImage(pixelRatio: 2);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            File('$_out/$file').writeAsBytesSync(png!.buffer.asUint8List());
          });
        });
      }
    }
  }
}
