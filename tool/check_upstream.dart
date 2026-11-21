// Compares the catalog fixture with the one the live playground serves, and
// reports what changed: components and functions added or removed, and the
// props of each component that differ.
//
//   dart run tool/check_upstream.dart [url]
//
// The default url is https://a2ui.open.bot/catalog.json. Run it by hand or
// on a schedule, not in CI: it needs the network. It exits with 1 when the
// documents differ, 2 when the live one cannot be read.

import 'dart:convert';
import 'dart:io';

import 'src/generator.dart';

/// Where the playground serves its catalog.
const String defaultCatalogUrl = 'https://a2ui.open.bot/catalog.json';

Future<void> main(List<String> args) async {
  final url = Uri.parse(args.isEmpty ? defaultCatalogUrl : args.first);
  final local =
      jsonDecode(File(catalogFixturePath).readAsStringSync())
          as Map<String, Object?>;
  final Map<String, Object?> live;
  try {
    live = await _fetch(url);
  } on Object catch (error) {
    stderr.writeln('Could not read $url: $error');
    exitCode = 2;
    return;
  }
  final report = compareCatalogs(local, live);
  if (report.isEmpty) {
    stdout.writeln('The fixture matches $url.');
    return;
  }
  stdout
    ..writeln('The fixture differs from $url:')
    ..writeln(report.map((line) => '  $line').join('\n'))
    ..writeln(
      'Copy the live document to $catalogFixturePath, run '
      '`dart run tool/generate.dart`, and let the tests show what changed.',
    );
  exitCode = 1;
}

Future<Map<String, Object?>> _fetch(Uri url) async {
  final client = HttpClient()..userAgent = 'a2ui_kit check_upstream';
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    final body = await response.transform(utf8.decoder).join();
    return jsonDecode(body) as Map<String, Object?>;
  } finally {
    client.close();
  }
}

/// The differences between the [local] and [live] catalog documents, one
/// line each; empty when they are equal as JSON.
List<String> compareCatalogs(
  Map<String, Object?> local,
  Map<String, Object?> live,
) {
  final out = <String>[];
  for (final key in {...local.keys, ...live.keys}) {
    if (key == 'components' || key == 'functions') continue;
    if (!_equal(local[key], live[key])) out.add('"$key" changed');
  }
  for (final section in ['components', 'functions']) {
    final before = (local[section] as Map? ?? const {}).cast<String, Object?>();
    final after = (live[section] as Map? ?? const {}).cast<String, Object?>();
    for (final name in after.keys) {
      if (!before.containsKey(name)) out.add('$section: $name added');
    }
    for (final name in before.keys) {
      if (!after.containsKey(name)) {
        out.add('$section: $name removed');
        continue;
      }
      if (_equal(before[name], after[name])) continue;
      final oldProps = _props(before[name]);
      final newProps = _props(after[name]);
      final changed = [
        for (final prop in {...oldProps.keys, ...newProps.keys})
          if (!oldProps.containsKey(prop))
            '+$prop'
          else if (!newProps.containsKey(prop))
            '-$prop'
          else if (!_equal(oldProps[prop], newProps[prop]))
            prop,
      ];
      out.add(
        '$section: $name changed'
        '${changed.isEmpty ? '' : ' (${changed.join(', ')})'}',
      );
    }
  }
  return out;
}

Map<String, Object?> _props(Object? schema) => switch (schema) {
  {'properties': final Map<Object?, Object?> props} =>
    props.cast<String, Object?>(),
  _ => const {},
};

/// JSON equality: maps compare by key, whatever their order.
bool _equal(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || !_equal(entry.value, b[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_equal(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
