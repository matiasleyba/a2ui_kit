// Generates lib/src/document/*.g.dart from CopilotKit's exported catalog
// documents in test/fixtures/copilotkit/, and the Lucide icon table from the
// lucide-react packages CopilotKit's lockfiles pin (tool/src/lucide.dart).
//
//   dart run tool/generate.dart          writes the files and formats them
//   dart run tool/generate.dart --check  fails when they are out of date
//
// The lucide-react packages are read from `lucide-react@<version>/` under
// `$A2UI_THIRDPARTY_SRC`, else `third_party_src/` in the package (ignored by
// git): whole published packages, fetched as port/RULEBOOK.md section 0 item
// 4 says.
// Without them the run stops, `--check` included: the table cannot be
// checked against nothing.
//
// Run it from the package root. With `--root=<dir>`, `--check` compares the
// files under <dir> (laid out as in the package) instead of the package's
// own: the tests check a copy. `--root` without `--check` is refused, and so
// is any other argument (`--root <dir>` with a space included), before
// anything is written.

import 'dart:io';

import 'src/generator.dart';
import 'src/lucide.dart';

const String _usage =
    'Usage: dart run tool/generate.dart [--check [--root=<dir>]]';

Future<void> main(List<String> args) async {
  var check = false;
  String? root;
  for (final arg in args) {
    if (arg == '--check') {
      check = true;
    } else if (arg.startsWith('--root=') && arg.length > '--root='.length) {
      root = arg.substring('--root='.length);
    } else {
      // An argument the tool doesn't read would otherwise be ignored, and
      // the run would write the package's own files (review 2a regen Q17).
      stderr
        ..writeln(
          arg.startsWith('--root')
              ? '--root takes its directory as --root=<dir>.'
              : 'Unknown argument: $arg.',
        )
        ..writeln(_usage);
      exitCode = 64;
      return;
    }
  }
  if (root != null && !check) {
    // A write always goes to the package's own files; `--root` only
    // redirects a check (review 2a A-nit).
    stderr.writeln('--root=<dir> only works with --check.');
    exitCode = 64;
    return;
  }
  String committed(String path) => root == null ? path : '$root/$path';
  final missing = missingLucideSources();
  if (missing.isNotEmpty) {
    stderr.writeln(missing.join('\n'));
    exitCode = 1;
    return;
  }
  final files = [
    ...generate(
      catalogJson: File(catalogFixturePath).readAsStringSync(),
      inferenceJson: File(inferenceFixturePath).readAsStringSync(),
    ),
    generateLucideTableFromSources(),
  ];
  if (check) {
    // The generated sources, formatted by `dart format` as a write would
    // be, compared with the committed files exactly (line endings aside).
    final scratch = Directory('.dart_tool/a2ui_kit_generate_check');
    if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    scratch.createSync(recursive: true);
    final copies = [
      for (var i = 0; i < files.length; i++)
        File('${scratch.path}/generated_$i.dart')
          ..writeAsStringSync(files[i].content),
    ];
    final format = await Process.run(Platform.resolvedExecutable, [
      'format',
      scratch.path,
    ]);
    if (format.exitCode != 0) {
      stderr.write(format.stderr);
      exitCode = format.exitCode;
      return;
    }
    String text(File file) => file.readAsStringSync().replaceAll('\r\n', '\n');
    final stale = [
      for (var i = 0; i < files.length; i++)
        if (File(committed(files[i].path)) case final file
            when !file.existsSync() || text(file) != text(copies[i]))
          files[i].path,
    ];
    scratch.deleteSync(recursive: true);
    if (stale.isEmpty) {
      stdout.writeln('Generated files are up to date.');
      return;
    }
    stderr.writeln(
      'Out of date: ${stale.join(', ')}. Run `dart run tool/generate.dart`.',
    );
    exitCode = 1;
    return;
  }
  for (final file in files) {
    File(file.path)
      ..createSync(recursive: true)
      ..writeAsStringSync(file.content);
  }
  final result = await Process.run(Platform.resolvedExecutable, [
    'format',
    ...files.map((f) => f.path),
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) exitCode = result.exitCode;
}
