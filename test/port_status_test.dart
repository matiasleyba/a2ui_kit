// port/port_status.dart's NOTICE.md check (RULEBOOK section 6 item 6,
// RC3-7): a package a file's header names at a version needs its NOTICE.md
// section.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../port/port_status.dart'
    show noticeIssues, skipCountIssues, skippedTestsIn, trailerIssues;

void main() {
  const notice = '# Notices\n\n## recharts (MIT License)\n\n> text\n';

  test('a header naming a package NOTICE.md lacks is an issue', () {
    const tanstack =
        'lib/a.dart names @tanstack/charts: NOTICE.md has no "## TanStack '
        'Charts" section';
    const toolkit =
        'lib/b.dart names es-toolkit: NOTICE.md has no "## es-toolkit" '
        'section';
    expect(
      noticeIssues({
        'lib/a.dart':
            '// Ported from @tanstack/charts 1.1.0 (MIT).\n\nimport "x";\n',
        'lib/b.dart':
            '// recharts 3.10.1, with es-toolkit@1.43.0.\nvoid f() {}\n',
      }, notice),
      [tanstack, toolkit],
    );
  });

  test('a section heading is matched whole, not as a prefix', () {
    expect(
      noticeIssues({
        'lib/a.dart': '// d3-shape 3.2.0\n',
      }, '## d3js (ISC License)\n'),
      ['lib/a.dart names d3-shape: NOTICE.md has no "## d3" section'],
    );
    expect(
      noticeIssues({'lib/a.dart': '// d3-shape 3.2.0\n'}, '## d3 (ISC)\n'),
      isEmpty,
    );
  });

  test('a package the check does not list is an issue; prose is not', () {
    const unlisted =
        'lib/a.dart names left-pad, which port_status.dart does not list: '
        'add its NOTICE.md section and its noticeSections entry';
    expect(
      noticeIssues({
        'lib/a.dart':
            '// left-pad 1.3.0, and 1.57.0 is 0.562.0 at 2.5.1; Node '
            '24.17.0\n',
      }, notice),
      [unlisted],
    );
  });

  test('only the header counts: a doc comment or code below it does not', () {
    expect(
      noticeIssues({
        'lib/a.dart':
            '// A file.\n\nimport "x";\n// es-toolkit 1.43.0\n'
            '/// decimal.js-light 2.5.1\n',
        'lib/b.dart': '/// es-toolkit 1.43.0\nvoid f() {}\n',
      }, notice),
      isEmpty,
    );
  });

  test('a dependency that is not ported needs no section', () {
    expect(
      noticeIssues({'lib/a.dart': '// path_parsing 1.1.0\n'}, notice),
      isEmpty,
    );
  });

  test('lucide-react is ported: it needs the Lucide section', () {
    expect(
      noticeIssues({
        'lib/a.dart': '// lucide-react 0.525.0 and lucide-react@1.57.0\n',
      }, notice),
      ['lib/a.dart names lucide-react: NOTICE.md has no "## Lucide" section'],
    );
    expect(
      noticeIssues({
        'lib/a.dart': '// lucide-react 1.57.0\n',
      }, '$notice\n## Lucide (ISC License)\n'),
      isEmpty,
    );
    // flutter_lucide is no dependency any more.
    expect(noticeIssues({'lib/a.dart': '// flutter_lucide 1.72.0\n'}, notice), [
      contains('flutter_lucide, which port_status.dart does not list'),
    ]);
  });

  test("the package's own headers and NOTICE.md agree", () {
    final sources = {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          file.path.replaceAll(r'\', '/'): file.readAsStringSync(),
    };
    expect(sources, isNotEmpty);
    expect(
      noticeIssues(sources, File('NOTICE.md').readAsStringSync()),
      isEmpty,
    );
  });

  // RULEBOOK section 6 item 9 (RC14): the shared files' trailers.
  group('trailerIssues', () {
    const good = '// PORT STATUS: confidence=high todos=1 upstream=none\n';
    test('a shared file needs a last-line trailer that counts its TODOs', () {
      expect(
        trailerIssues({
          'lib/src/foundation/a.dart': '// TODO(port): x\nvoid a() {}\n$good',
          'lib/src/theme/b.dart': 'void b() {}\n',
          'lib/src/foundation/c.dart': 'void c() {}\n$good',
          'lib/src/foundation/d.dart': '${good}void d() {}\n',
          'lib/src/theme/e.dart':
              '// PORT STATUS: confidence=sure todos=0 upstream=none\n',
        }),
        [
          'lib/src/foundation/c.dart: trailer todos=1, file has 0',
          'lib/src/foundation/d.dart ends with no PORT STATUS trailer',
          'lib/src/theme/b.dart ends with no PORT STATUS trailer',
          'lib/src/theme/e.dart: its PORT STATUS trailer is malformed',
        ],
      );
    });

    // Widened at the first phase's merge: every file under lib/ but a
    // component's own and a generated one.
    test("a component's own file and a generated file are not checked; "
        'every other file under lib/ is', () {
      expect(
        trailerIssues(
          {
            'lib/src/components/x/own.dart': 'Widget buildOwn(\n',
            'lib/src/components/x/helper.dart': 'void help() {}\n',
            'lib/src/foundation/names.g.dart': 'const a = 1;\n',
            'lib/src/functions/f.dart': '// TODO(port): x\nvoid f() {}\n',
            'lib/src/validation/v.dart':
                'void v() {}\n// PORT STATUS: confidence=high todos=0 '
                'upstream=none\n',
            'lib/a2ui_kit.dart': "export 'src/a.dart';\n",
            'test/t.dart': 'void t() {}\n',
          },
          builders: ['buildOwn'],
        ),
        [
          'lib/a2ui_kit.dart ends with no PORT STATUS trailer',
          'lib/src/components/x/helper.dart ends with no PORT STATUS trailer',
          'lib/src/functions/f.dart ends with no PORT STATUS trailer',
        ],
      );
    });

    test("the package's own shared files have their trailers", () {
      final registry = File(
        'lib/src/components/registry.dart',
      ).readAsStringSync();
      final builders = [
        for (final m in RegExp(
          r"^\s*'(\w+)': (\w+),",
          multiLine: true,
        ).allMatches(registry))
          m.group(2)!,
      ];
      final sources = {
        for (final file in Directory('lib').listSync(recursive: true))
          if (file is File && file.path.endsWith('.dart'))
            file.path.replaceAll(r'\', '/'): file.readAsStringSync(),
      };
      expect(trailerIssues(sources, builders: builders), isEmpty);
    });
  });

  // RULEBOOK section 6 item 9: the tsv's "Port-queue skips: N" against the
  // skipped tests of a run, which a helper's or a loop's skips reach too.
  group('the skip counts', () {
    /// A `--file-reporter json:` report: [tests] of each file, as (name,
    /// skipped), with the reporter's own hidden entries among them.
    String report(Map<String, List<(String, bool)>> tests) {
      final lines = <String>[];
      var suite = 0;
      var test = 100;
      for (final MapEntry(key: path, value: entries) in tests.entries) {
        suite++;
        lines
          ..add(
            jsonEncode({
              'type': 'suite',
              'suite': {'id': suite, 'path': r'D:\pkg\' + path},
            }),
          )
          ..add(
            jsonEncode({
              'type': 'testStart',
              'test': {'id': ++test, 'suiteID': suite, 'name': 'loading'},
            }),
          )
          ..add(
            jsonEncode({
              'type': 'testDone',
              'testID': test,
              'skipped': true,
              'hidden': true,
            }),
          );
        for (final (name, skipped) in entries) {
          lines
            ..add(
              jsonEncode({
                'type': 'testStart',
                'test': {'id': ++test, 'suiteID': suite, 'name': name},
              }),
            )
            ..add(
              jsonEncode({
                'type': 'testDone',
                'testID': test,
                'skipped': skipped,
                'hidden': false,
              }),
            );
        }
      }
      return lines.join('\n');
    }

    test('a run gives each file its skipped tests, hidden ones aside', () {
      expect(
        skippedTestsIn(
          report({
            r'test\parity\a_test.dart': [
              ('a', true),
              ('b', true),
              ('c', false),
            ],
            'test/parity/b_test.dart': [('d', false)],
          }),
        ),
        {'test/parity/a_test.dart': 2, 'test/parity/b_test.dart': 0},
      );
    });

    const tsv =
        'upstream_file\ttests\tportable\tinternal_bound\tsubject\t'
        'parity_file\tstate\tnote\n'
        'a.test.ts\t3\t3\t0\tX\ttest/parity/a_test.dart\tported\t'
        'Port-queue skips: 2\n'
        'b.test.ts\t1\t1\t0\tX\ttest/parity/b_test.dart '
        'test/parity/c_test.dart\tported\tPort-queue skips: 1\n'
        'c.test.ts\t1\t1\t0\tX\ttest/parity/c_test.dart\tported\tno count\n'
        'd.test.ts\t1\t1\t0\tnot-ours\t\tnot-ours\tPort-queue skips: 9\n';

    test('counts that match the run pass, rows sharing a file together', () {
      expect(
        skipCountIssues(tsv, {
          'test/parity/a_test.dart': 2,
          'test/parity/b_test.dart': 0,
          'test/parity/c_test.dart': 1,
        }),
        isEmpty,
      );
    });

    test('a stale count, and a file the run lacks, are issues', () {
      const stale =
          'test/parity/a_test.dart: upstream_tests.tsv says Port-queue skips: '
          '2, the run skipped 1';
      expect(
        skipCountIssues(tsv, {
          'test/parity/a_test.dart': 1,
          'test/parity/b_test.dart': 0,
        }),
        [stale, 'the run holds no test/parity/c_test.dart'],
      );
      // The shared rows' sum: a skip moved from one of their files to
      // the other is still the same count; one more is not.
      const shared =
          'test/parity/b_test.dart test/parity/c_test.dart: '
          'upstream_tests.tsv says Port-queue skips: 1, the run skipped 2';
      expect(
        skipCountIssues(tsv, {
          'test/parity/a_test.dart': 2,
          'test/parity/b_test.dart': 1,
          'test/parity/c_test.dart': 1,
        }),
        [shared],
      );
    });
  });
}
