import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/src/generator.dart';
import '../tool/src/lucide.dart';

/// Fails when lib/src/document/*.g.dart is not what tool/generate.dart
/// makes from the fixtures: run `dart run tool/generate.dart`.
void main() {
  final files = generate(
    catalogJson: File(catalogFixturePath).readAsStringSync(),
    inferenceJson: File(inferenceFixturePath).readAsStringSync(),
  );

  test('generates the four document files', () {
    expect(files.map((f) => f.path), [
      'lib/src/document/catalog_document.g.dart',
      'lib/src/document/inference_document.g.dart',
      'lib/src/document/props.g.dart',
      'lib/src/document/behaviour.g.dart',
    ]);
  });

  test('the event table names exactly the Action props of the catalog', () {
    // A catalog with a new event on Button stops the generator. (The
    // checkout may have Windows line ends.)
    final catalog = File(catalogFixturePath)
        .readAsStringSync()
        .replaceAll('\r\n', '\n')
        .replaceFirst(
          '"onClick": {\n     "\$ref": "common_types.json#/\$defs/Action",\n'
              '     "description": "Sent when the user clicks the button."',
          '"onPress": {"\$ref": "common_types.json#/\$defs/Action"},\n'
              '    "onClick": {\n'
              '     "\$ref": "common_types.json#/\$defs/Action",\n'
              '     "description": "Sent when the user clicks the button."',
        );
    expect(catalog, contains('onPress'));
    expect(
      () => generate(
        catalogJson: catalog,
        inferenceJson: File(inferenceFixturePath).readAsStringSync(),
      ),
      throwsStateError,
    );
  });

  for (final file in files) {
    test('${file.path} is up to date', () {
      final committed = File(file.path);
      expect(committed.existsSync(), isTrue);
      expect(
        normalizeDart(committed.readAsStringSync()),
        normalizeDart(file.content),
        reason: 'Run `dart run tool/generate.dart`.',
      );
    });
  }

  test('generate.dart --check compares the formatted output exactly', () async {
    // A copy of the committed files, so the package's own stay untouched
    // whatever happens to the test.
    final root = Directory('.dart_tool/a2ui_kit_sync_test');
    if (root.existsSync()) root.deleteSync(recursive: true);
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    for (final path in [...files.map((f) => f.path), lucideTablePath]) {
      File('${root.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(File(path).readAsStringSync());
    }
    Future<ProcessResult> check() => Process.run('dart', [
      'run',
      'tool/generate.dart',
      '--check',
      '--root=${root.path}',
    ], runInShell: true);

    final fresh = await check();
    expect(fresh.exitCode, 0, reason: '${fresh.stdout}${fresh.stderr}');

    // A doubled space in a doc comment, which a comparison that drops
    // whitespace would miss.
    final props = File('${root.path}/lib/src/document/props.g.dart');
    props.writeAsStringSync(
      props.readAsStringSync().replaceFirst('The values of', 'The  values of'),
    );
    expect(props.readAsStringSync(), contains('The  values of'));
    // And one Lucide path drawn a pixel longer.
    final table = File('${root.path}/$lucideTablePath');
    table.writeAsStringSync(
      table.readAsStringSync().replaceFirst(
        "LucidePath('M5 12h14')",
        "LucidePath('M5 12h15')",
      ),
    );
    expect(table.readAsStringSync(), contains("LucidePath('M5 12h15')"));
    final stale = await check();
    expect(stale.exitCode, 1, reason: '${stale.stdout}${stale.stderr}');
    expect('${stale.stderr}', contains('props.g.dart'));
    expect('${stale.stderr}', contains('lucide_icons.g.dart'));

    // Without the lucide-react packages the check stops, rather than pass a
    // table it cannot compare.
    final empty = Directory('${root.path}/no-sources')..createSync();
    final unsourced = await Process.run(
      'dart',
      ['run', 'tool/generate.dart', '--check', '--root=${root.path}'],
      runInShell: true,
      environment: {'A2UI_THIRDPARTY_SRC': empty.path},
    );
    expect(
      unsourced.exitCode,
      1,
      reason: '${unsourced.stdout}${unsourced.stderr}',
    );
    expect(
      '${unsourced.stderr}',
      contains('lucide-react@0.525.0 is not in ${empty.path}'),
    );
    expect('${unsourced.stderr}', contains('lucide-react@1.57.0 is not in'));

    // `--root` without `--check` is refused rather than writing the
    // package's own files (review 2a A-nit).
    final write = await Process.run('dart', [
      'run',
      'tool/generate.dart',
      '--root=${root.path}',
    ], runInShell: true);
    expect(write.exitCode, 64, reason: '${write.stdout}${write.stderr}');
    expect('${write.stderr}', contains('--root=<dir> only works with --check'));

    // `--root <dir>` (a space, not `=`) and any argument the tool doesn't
    // read are refused before anything is written, rather than ignored
    // (review 2a regen Q17): the run would write the package's own files.
    // A write leaves the same text, so the file's time shows it.
    final committed = File(files.first.path);
    final before = committed.lastModifiedSync();
    final spaced = await Process.run('dart', [
      'run',
      'tool/generate.dart',
      '--check',
      '--root',
      root.path,
    ], runInShell: true);
    expect(spaced.exitCode, 64, reason: '${spaced.stdout}${spaced.stderr}');
    expect(
      '${spaced.stderr}',
      contains('--root takes its directory as --root=<dir>.'),
    );
    final unknown = await Process.run('dart', [
      'run',
      'tool/generate.dart',
      '--frobnicate',
    ], runInShell: true);
    expect(unknown.exitCode, 64, reason: '${unknown.stdout}${unknown.stderr}');
    expect('${unknown.stderr}', contains('Unknown argument: --frobnicate.'));
    expect(
      '${unknown.stderr}',
      contains('Usage: dart run tool/generate.dart [--check [--root=<dir>]]'),
    );
    expect(committed.lastModifiedSync(), before);
  }, timeout: const Timeout(Duration(minutes: 8)));

  test('the generator refuses a document with another component count', () {
    final catalog = File(catalogFixturePath).readAsStringSync().replaceFirst(
      '"Box": {',
      '"Boxy": {"type": "object"}, "Box": {',
    );
    expect(
      () => generate(
        catalogJson: catalog,
        inferenceJson: File(inferenceFixturePath).readAsStringSync(),
      ),
      throwsStateError,
    );
  });

  test('the Lucide table is what the lucide-react packages make', () {
    expect(
      missingLucideSources(),
      isEmpty,
      reason: 'The table is checked against the fetched packages.',
    );
    expect(
      normalizeDart(File(lucideTablePath).readAsStringSync()),
      normalizeDart(generateLucideTableFromSources().content),
      reason: 'Run `dart run tool/generate.dart`.',
    );
    expect(lucidePascalName('arrow-down-0-1'), 'ArrowDown01');
    expect(lucidePascalName('arrowRight'), 'ArrowRight');
  });

  group('the lucide-react reader', () {
    LucideReactPackage read(String version) => LucideReactPackage.read(
      Directory('${thirdPartySources().path}/lucide-react@$version'),
      version,
    );

    test("reads each package's icons, nodes and other names", () {
      final reactCore = read('0.525.0');
      final playground = read('1.57.0');
      expect(reactCore.icons, hasLength(1611));
      expect(playground.icons, hasLength(1890));
      // The index's order, which the `icons` map keeps.
      expect(reactCore.icons.keys.take(3), [
        'AArrowDown',
        'ALargeSmall',
        'AArrowUp',
      ]);
      String describe(List<LucideNodeElement> node) =>
          [for (final e in node) '${e.tag} ${e.attributes}'].join('; ');
      // 0.525.0's `__iconNode` and 1.57.0's `__iconData.node`, `key` left
      // out.
      for (final package in [reactCore, playground]) {
        expect(
          describe(package.icons['CircleAlert']!),
          'circle {cx: 12, cy: 12, r: 10}; '
          'line {x1: 12, x2: 12, y1: 8, y2: 12}; '
          'line {x1: 12, x2: 12.01, y1: 16, y2: 16}',
        );
      }
      expect(
        describe(reactCore.icons['Tag']!),
        endsWith('circle {cx: 7.5, cy: 7.5, r: .5, fill: currentColor}'),
      );
      // From each package's dist/esm/lucide-react.js.
      expect(reactCore.aliases['AlertCircle'], 'CircleAlert');
      expect(reactCore.aliases['AlertTriangle'], 'TriangleAlert');
      expect(reactCore.icons, contains('Trash2'));
      expect(playground.aliases['Trash2'], 'Trash');
      expect(playground.aliases['CheckCircle2'], 'CircleCheck');
      expect(playground.aliases['XCircle'], 'CircleX');
      expect(playground.aliases, isNot(contains('AlertTriangleIcon')));
      expect(playground.aliases, isNot(contains('LucideAlertTriangle')));
    });

    test('stops on a form it does not know', () {
      void refused(Object? Function() read, String message) => expect(
        read,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
      );
      const ok = "export { default as Ab } from './ab.js';\n";
      refused(() => lucideIndex('$ok${'x' * 3}\n', '.js'), 'Unexpected line');
      refused(() => lucideIndex('$ok$ok', '.js'), 'exports Ab twice');
      refused(() => lucideIndex(ok, '.js'), 'exports 1 icons');
      refused(
        () => lucideIconNode('const __iconNode = [["path", {d: 1}]];', 'a'),
        'path d is not a string',
      );
      refused(
        () => lucideIconNode('const __iconNode = [["path"]];', 'a'),
        'unexpected element',
      );
      refused(
        () => lucideIconNode(
          'const __iconData = {name: "a", size: 32, node: []};',
          'a',
        ),
        'unexpected __iconData',
      );
      refused(
        () =>
            lucideIconNode(r'const __iconNode = [["path", {d: "M1\n"}]];', 'a'),
        'string escape',
      );
      refused(() => lucideIconNode('export {};', 'a'), 'no __iconNode');
      String element(String tag, Map<String, String> attributes) =>
          lucideElementSource(LucideNodeElement(tag, attributes), 'a');
      expect(
        element('rect', {
          'width': '18',
          'height': '18',
          'x': '3',
          'y': '3',
          'rx': '2',
        }),
        'LucideRect(3, 3, 18, 18, rx: 2)',
      );
      expect(
        element('circle', {
          'cx': '7.5',
          'cy': '7.5',
          'r': '.5',
          'fill': 'currentColor',
        }),
        'LucideCircle(7.5, 7.5, 0.5, filled: true)',
      );
      expect(
        element('polygon', {'points': '6 3 20 12 6 21 6 3'}),
        'LucidePolygon([6, 3, 20, 12, 6, 21, 6, 3])',
      );
      refused(
        () =>
            element('circle', {'cx': '1', 'cy': '1', 'r': '1', 'fill': 'red'}),
        'fill red',
      );
      refused(() => element('rect', {'width': '0', 'height': '2'}), 'width 0');
      refused(
        () => element('circle', {'cx': '1', 'cy': '1', 'r': '1px'}),
        'no number',
      );
      refused(() => element('polyline', {'points': '1 2 3'}), 'points 1 2 3');
      refused(() => element('path', {'d': "M1 1'"}), 'unexpected path data');
      refused(() => element('text', {'x': '1'}), 'the table has no text');
      refused(
        () => element('ellipse', {'cx': '1', 'cy': '1', 'rx': '1'}),
        'no ry',
      );
      refused(
        () => element('line', {
          'x1': '1',
          'y1': '1',
          'x2': '2',
          'y2': '2',
          'stroke': 'red',
        }),
        'unexpected stroke',
      );
    });

    test('the other names: plain ones kept, each line checked', () {
      const index = {'CircleAlert': 'circle-alert', 'X': 'x'};
      const source =
          'export { index as icons };\n'
          'export { default as AlertCircle, default as AlertCircleIcon, '
          'default as CircleAlert, default as CircleAlertIcon, '
          'default as LucideAlertCircle, default as LucideCircleAlert } '
          "from './icons/circle-alert.js';\n"
          'export { default as LucideX, default as X, default as XIcon } '
          "from './icons/x.js';\n";
      expect(lucideAliases(source, '.js', index), {
        'AlertCircle': 'CircleAlert',
      });
      expect(
        () => lucideAliases(
          source.replaceFirst('default as XIcon', 'default as Y'),
          '.js',
          index,
        ),
        throwsStateError,
      );
      expect(
        () => lucideAliases(source, '.js', {...index, 'Y': 'y'}),
        throwsStateError,
      );
    });
  });

  test('enum value names', () {
    expect(enumValueName('2xl'), 'twoXl');
    expect(enumValueName('wrap-reverse'), 'wrapReverse');
    expect(enumValueName('default'), 'default_');
    expect(enumValueName('1'), 'one');
    expect(enumValueName('C'), 'c');
    expect(enumValueName('spaceBetween'), 'spaceBetween');
  });

  test('defaults read from descriptions', () {
    expect(describedDefault('Default "col"'), 'col');
    expect(describedDefault('Column count or CSS template. Default 2'), 2);
    expect(describedDefault('Default true: a click opens'), true);
    expect(describedDefault('Default: every number field'), isNull);
    expect(describedDefault(null), isNull);
  });
}
