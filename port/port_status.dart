// Writes port/manifest.tsv, the port's queue, from what is on disk
// (port/RULEBOOK.md, sections 4 and 7):
//
//   dart run port/port_status.dart          writes the manifest
//   dart run port/port_status.dart --check  fails when it is out of date
//   ... --skips <report.json>               also checks the skip counts
//
// Run it from the package root. A component's row comes from PORT_PLAN.md
// (the table "All 121 components" and its Appendix A line). Its status comes
// from the code: `todo` until lib/src/components/registry.dart registers it,
// then `built` once its Dart file ends with a PORT STATUS trailer
// (`built-no-trailer` before). The parity column lists the files in
// test/parity/ whose header names the component in a `// Parity for:` line.
// `issues` names what a reviewer must look at: a trailer whose `todos=`
// differs from the file's `TODO(port)` markers, or no parity file for a
// component that CopilotKit's tests cover (port/upstream_tests.tsv names it in
// its `subject` column; the playground's components have no upstream tests).
// The signals column lists the files whose `// Signals for:` line names the
// component: a later-phase component kept in a surface so a test fails once it
// draws. A signal is not parity coverage (RULEBOOK section 6 item 2).
//
// It also checks NOTICE.md (RULEBOOK section 6 item 6): every third-party
// package a file in lib/ names in its header comment, at a version, has its
// NOTICE.md section ([noticeIssues]); either mode fails while one lacks it.
// And the shared files' trailers (section 6 item 9): every Dart file under
// lib/ that is no component's own and no generated `.g.dart` ends with a
// PORT STATUS trailer that counts its TODO(port) markers ([trailerIssues]);
// either mode fails while one does not.
//
// With `--skips <report.json>` it also checks port/upstream_tests.tsv's
// "Port-queue skips: N" counts (section 6 item 9) against a run: the report
// is the JSON file `flutter test --file-reporter json:<path>` writes for the
// full suite (the queue check's normal run, section 6 item 2), and the
// count a row claims is the skipped tests that run reports in its parity
// files ([skippedTestsIn], [skipCountIssues]). A run is the only source: a
// parity file can skip through a helper (validate_operation_test.dart's
// `_refused` and `_accepted`), in a loop or on a condition, so its
// `portQueue(` calls do not count its skips. Without `--skips` the counts
// are not checked, and the tool says so.

import 'dart:convert';
import 'dart:io';

const String _manifestPath = 'port/manifest.tsv';

/// The third-party packages a file's header may name, and the `NOTICE.md`
/// section (`## <name> …`) each one needs; null for a package a header names
/// that the file does not port (a dependency, whose licence ships with it).
const Map<String, String?> noticeSections = {
  '@tanstack/charts': 'TanStack Charts',
  'recharts': 'recharts',
  'decimal.js-light': 'decimal.js-light',
  'es-toolkit': 'es-toolkit',
  'd3-array': 'd3',
  'd3-color': 'd3',
  'd3-format': 'd3',
  'd3-interpolate': 'd3',
  'd3-path': 'd3',
  'd3-scale': 'd3',
  'd3-shape': 'd3',
  'd3-time': 'd3',
  'd3-time-format': 'd3',
  // recharts reaches d3's scales through it; what is ported is d3's.
  'victory-vendor': 'd3',
  'whatwg-url': 'whatwg-url',
  // The icon nodes, from the releases CopilotKit pins (0.525.0, 1.57.0).
  'lucide-react': 'Lucide',
  // A dependency, not ported: the Lucide and Svg paths are parsed with it.
  'path_parsing': null,
  // The Math component follows KaTeX's source around the formula.
  'katex': 'KaTeX',
  // A dependency: it typesets the Math component's formula.
  'flutter_math_fork': null,
  // A dependency whose MarkdownBody and list layout the Markdown component
  // adapts.
  'flutter_markdown_plus': 'flutter_markdown_plus',
  // The browser engine, as `chromium@<tag>`: its table layout and its SVG
  // shape, scroll-key and :focus-visible rules are ported.
  'chromium': 'Chromium',
};

/// A package at a version in a header: a scoped name, a name with a `-`,
/// `.` or `_` in it, or one word (kept only when [noticeSections] lists it,
/// so prose such as "and 1.57.0" is not taken for a package).
final RegExp _packageAtVersion = RegExp(
  r'(?<![\w@/.-])(@[a-z0-9-]+/[a-z0-9._-]+|[a-z0-9]+(?:[-._][a-z0-9]+)+'
  r'|[a-z]+)[ @]v?\d+\.\d+\.\d+',
);

/// What NOTICE.md ([notice], its text) lacks for the files of [sources]
/// (path to text): one line per package a file's header comment names at a
/// version without its section, or that [noticeSections] does not list.
List<String> noticeIssues(Map<String, String> sources, String notice) {
  final issues = <String>{};
  for (final MapEntry(key: path, value: text) in sources.entries) {
    final header = StringBuffer();
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          (trimmed.startsWith('//') && !trimmed.startsWith('///'))) {
        header.writeln(trimmed);
        continue;
      }
      break;
    }
    for (final match in _packageAtVersion.allMatches(header.toString())) {
      final name = match.group(1)!;
      final listed = noticeSections.containsKey(name);
      if (!listed) {
        if (RegExp('[-._/]').hasMatch(name)) {
          issues.add(
            '$path names $name, which port_status.dart does not list: add '
            'its NOTICE.md section and its noticeSections entry',
          );
        }
        continue;
      }
      final section = noticeSections[name];
      if (section == null) continue;
      final heading = RegExp(
        '^## ${RegExp.escape(section)}( |\$)',
        multiLine: true,
      );
      if (!heading.hasMatch(notice)) {
        issues.add('$path names $name: NOTICE.md has no "## $section" section');
      }
    }
  }
  return issues.toList()..sort();
}

/// The trailer of a file: `// PORT STATUS: confidence=` (`high`, `medium`
/// or `low`) `todos=` (the count of its markers) `upstream=` (what it
/// ports, or `none`).
final RegExp _trailer = RegExp(
  r'^// PORT STATUS: confidence=(high|medium|low) todos=(\d+) upstream=(\S.*)$',
);

/// What the shared files' trailers lack (RULEBOOK section 6 item 9, RC14),
/// for the files of [sources] (path to text): every Dart file under `lib/`
/// that declares none of [builders] (a component's own file, which the
/// manifest's status and issues cover) ends with a trailer whose `todos=`
/// counts the file's `TODO(port)` markers, so a marker outside a component
/// file is still counted: the foundation, the theme, the functions, the
/// validation, the ids, the catalog, the owned data and the library file.
/// A generated file (`.g.dart`) is the generator's, and has none.
List<String> trailerIssues(
  Map<String, String> sources, {
  Iterable<String> builders = const [],
}) {
  final issues = <String>[];
  final declarations = [
    for (final builder in builders) RegExp('Widget\\s+$builder\\s*\\('),
  ];
  for (final MapEntry(key: path, value: text) in sources.entries) {
    final shared =
        path.startsWith('lib/') &&
        path.endsWith('.dart') &&
        !declarations.any((d) => d.hasMatch(text));
    if (!shared || path.endsWith('.g.dart')) continue;
    final lines = text.trimRight().split('\n');
    final last = lines.last.trim();
    final match = _trailer.firstMatch(last);
    if (match == null) {
      issues.add(
        last.startsWith('// PORT STATUS')
            ? '$path: its PORT STATUS trailer is malformed'
            : '$path ends with no PORT STATUS trailer',
      );
      continue;
    }
    final markers = 'TODO(port)'.allMatches(text).length;
    if (int.parse(match.group(2)!) != markers) {
      issues.add('$path: trailer todos=${match.group(2)}, file has $markers');
    }
  }
  return issues..sort();
}

/// The skipped tests of each test file of a `flutter test
/// --file-reporter json:` [report] (its lines of JSON events), by the file's
/// path from `test/` (`test/parity/x_test.dart`); a file that ran with no
/// skip is there with 0. Hidden tests (the reporter's own loading and
/// teardown entries) do not count.
Map<String, int> skippedTestsIn(String report) {
  final suites = <int, String>{};
  final testSuite = <int, int>{};
  final skipped = <String, int>{};
  for (final line in report.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('{')) continue;
    final Object? event;
    try {
      event = jsonDecode(trimmed);
    } on FormatException {
      continue;
    }
    if (event is! Map<String, Object?>) continue;
    switch (event['type']) {
      case 'suite':
        if (event['suite'] case {
          'id': final int id,
          'path': final String path,
        }) {
          final normal = path.replaceAll(r'\', '/');
          final at = normal.lastIndexOf('/test/');
          final relative = at < 0 ? normal : normal.substring(at + 1);
          suites[id] = relative;
          skipped.putIfAbsent(relative, () => 0);
        }
      case 'testStart':
        if (event['test'] case {
          'id': final int id,
          'suiteID': final int suite,
        }) {
          testSuite[id] = suite;
        }
      case 'testDone':
        if (event['skipped'] != true || event['hidden'] == true) continue;
        final suite = suites[testSuite[event['testID']]];
        if (suite != null) skipped[suite] = skipped[suite]! + 1;
    }
  }
  return skipped;
}

/// What the "Port-queue skips: N" counts of [tsv] (port/upstream_tests.tsv's
/// text) get wrong against [skipped] ([skippedTestsIn] of a run): the rows
/// that share a parity file are counted together (a file that ports two
/// upstream files holds both rows' skips), so their counts' sum must be the
/// skips the run reports in their files; a row that states no count claims
/// 0. A parity file the run does not hold is an issue too.
List<String> skipCountIssues(String tsv, Map<String, int> skipped) {
  final lines = tsv.split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return const [];
  final header = lines.first.split('\t');
  final fileColumn = header.indexOf('parity_file');
  final noteColumn = header.indexOf('note');
  final count = RegExp(r'Port-queue skips: (\d+)');
  // Rows by their parity files, joined where they share one.
  final groups = <({Set<String> files, int claimed})>[];
  for (final line in lines.skip(1)) {
    final cells = line.split('\t');
    if (cells.length <= fileColumn) continue;
    final files = {
      for (final file in cells[fileColumn].split(' '))
        if (file.trim().isNotEmpty) file.trim(),
    };
    if (files.isEmpty) continue;
    final note = noteColumn < cells.length ? cells[noteColumn] : '';
    var claimed = int.parse(count.firstMatch(note)?.group(1) ?? '0');
    final joined = {...files};
    for (final group in [...groups]) {
      if (group.files.any(joined.contains)) {
        groups.remove(group);
        joined.addAll(group.files);
        claimed += group.claimed;
      }
    }
    groups.add((files: joined, claimed: claimed));
  }
  final issues = <String>[];
  for (final group in groups) {
    final files = group.files.toList()..sort();
    final missing = files.where((f) => !skipped.containsKey(f)).toList();
    if (missing.isNotEmpty) {
      issues.add('the run holds no ${missing.join(', ')}');
      continue;
    }
    final ran = files.fold(0, (sum, file) => sum + skipped[file]!);
    if (ran != group.claimed) {
      issues.add(
        '${files.join(' ')}: upstream_tests.tsv says Port-queue skips: '
        '${group.claimed}, the run skipped $ran',
      );
    }
  }
  return issues..sort();
}

void main(List<String> args) {
  final plan = File('PORT_PLAN.md').readAsStringSync();
  final registry = File('lib/src/components/registry.dart').readAsStringSync();
  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  final parityFiles = Directory('test/parity').existsSync()
      ? Directory('test/parity')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('_test.dart'))
            .toList()
      : <File>[];
  // A folder lists its files in an order that differs by platform; sorted,
  // the manifest is the same on every machine.
  libFiles.sort(_byPath);
  parityFiles.sort(_byPath);

  final upstreamFiles = <String, List<String>>{};
  final upstream = File('port/upstream_tests.tsv');
  if (upstream.existsSync()) {
    final lines = upstream.readAsLinesSync();
    final header = lines.first.split('\t');
    final fileColumn = header.indexOf('upstream_file');
    final subjectColumn = header.indexOf('subject');
    for (final line in lines.skip(1)) {
      final cells = line.split('\t');
      if (cells.length <= subjectColumn) continue;
      for (final name in cells[subjectColumn].split(',')) {
        (upstreamFiles[name.trim()] ??= []).add(cells[fileColumn]);
      }
    }
  }

  final definitions = <String, String>{};
  final appendix = RegExp(
    r'^#### (\w+)\s*\n+\*(?:Standard|Playground) ·[^`]*definition `([^`]+)`',
    multiLine: true,
  );
  for (final m in appendix.allMatches(plan)) {
    definitions[m.group(1)!] = m.group(2)!;
  }

  final builders = <String, String>{
    for (final m in RegExp(
      r"^\s*'(\w+)': (\w+),",
      multiLine: true,
    ).allMatches(registry))
      m.group(1)!: m.group(2)!,
  };

  final parityFor = <String, List<String>>{};
  final signalsFor = <String, List<String>>{};
  for (final file in parityFiles) {
    final text = file.readAsStringSync();
    for (final (header, into) in [
      ('Parity for', parityFor),
      ('Signals for', signalsFor),
    ]) {
      final line = RegExp(
        '^// $header: (.+)\$',
        multiLine: true,
      ).firstMatch(text);
      if (line == null) continue;
      for (final name in line.group(1)!.split(',')) {
        (into[name.trim()] ??= []).add(_rel(file.path));
      }
    }
  }

  final rows = <String>[
    [
      'n',
      'component',
      'source',
      'group',
      'size',
      'phase',
      'status',
      'dart_file',
      'confidence',
      'todos',
      'parity',
      'signals',
      'issues',
      'definition',
    ].join('\t'),
  ];
  final table = RegExp(
    r'^\| (\d+) \| \[(\w+)\]\([^)]*\) \| (\w+) \| ([^|]+?) \|'
    r'(?:[^|]*\|){4} (\w) \| (\w+) \|',
    multiLine: true,
  );
  for (final m in table.allMatches(plan)) {
    final name = m.group(2)!;
    final builder = builders[name];
    var status = 'todo';
    var dartFile = '';
    var confidence = '';
    var todos = '';
    final issues = <String>[];
    if (builder != null) {
      final declaration = RegExp('Widget\\s+$builder\\s*\\(');
      final file = libFiles
          .where((f) => declaration.hasMatch(f.readAsStringSync()))
          .firstOrNull;
      if (file != null) {
        dartFile = _rel(file.path);
        final text = file.readAsStringSync();
        final markers = 'TODO(port)'.allMatches(text).length;
        final trailer = RegExp(
          r'// PORT STATUS: confidence=(\w+) todos=(\d+)',
        ).allMatches(text).lastOrNull;
        todos = '$markers';
        if (trailer == null) {
          status = 'built-no-trailer';
        } else {
          status = 'built';
          confidence = trailer.group(1)!;
          if (int.parse(trailer.group(2)!) != markers) {
            issues.add('trailer todos=${trailer.group(2)}, file has $markers');
          }
        }
      } else {
        status = 'built-no-trailer';
        issues.add('builder $builder not found in lib/');
      }
      final covering = upstreamFiles[name] ?? const <String>[];
      if (covering.isNotEmpty && !parityFor.containsKey(name)) {
        issues.add('no parity file (${covering.length} upstream test files)');
      }
    }
    rows.add(
      [
        m.group(1),
        name,
        m.group(3),
        m.group(4)!.trim(),
        m.group(5),
        m.group(6),
        status,
        dartFile,
        confidence,
        todos,
        (parityFor[name] ?? const []).join(' '),
        (signalsFor[name] ?? const []).join(' '),
        issues.join('; '),
        definitions[name] ?? '',
      ].join('\t'),
    );
  }

  final notices = noticeIssues({
    for (final file in libFiles) _rel(file.path): file.readAsStringSync(),
  }, File('NOTICE.md').readAsStringSync());
  for (final issue in notices) {
    stderr.writeln('NOTICE.md: $issue');
  }
  if (notices.isNotEmpty) exitCode = 1;

  final trailers = trailerIssues({
    for (final file in libFiles) _rel(file.path): file.readAsStringSync(),
  }, builders: builders.values);
  for (final issue in trailers) {
    stderr.writeln('trailer: $issue');
  }
  if (trailers.isNotEmpty) exitCode = 1;

  final skips = args.indexOf('--skips');
  if (skips >= 0 && skips + 1 < args.length) {
    final counted = skipCountIssues(
      upstream.readAsStringSync(),
      skippedTestsIn(File(args[skips + 1]).readAsStringSync()),
    );
    for (final issue in counted) {
      stderr.writeln('skips: $issue');
    }
    if (counted.isNotEmpty) exitCode = 1;
  } else {
    stdout.writeln(
      "upstream_tests.tsv's Port-queue skips: not checked; pass --skips "
      '<report.json>, a flutter test --file-reporter json: report of the '
      'full suite',
    );
  }

  final text = '${rows.join('\n')}\n';
  final manifest = File(_manifestPath);
  if (args.contains('--check')) {
    final current = manifest.existsSync() ? manifest.readAsStringSync() : '';
    if (current.replaceAll('\r\n', '\n') != text) {
      stderr.writeln(
        '$_manifestPath is out of date: run dart run port/port_status.dart',
      );
      exitCode = 1;
    }
    return;
  }
  manifest.writeAsStringSync(text);
  final built = rows.skip(1).where((r) => !r.contains('\ttodo\t')).length;
  stdout.writeln('${rows.length - 1} components, $built built: $_manifestPath');
}

String _rel(String path) => path.replaceAll(r'\', '/');

int _byPath(File a, File b) => a.path.compareTo(b.path);
