// The Lucide icon table of a2ui_kit: lucide-react's own icon nodes in, one
// node table and a name map per release out. The releases are the ones
// CopilotKit's lockfiles pin: lucide-react 0.525.0 (react-core's) and
// lucide-react 1.57.0 (the A2UI playground's), whole published packages
// fetched from registry.npmjs.org and checked against the lockfiles' sha512
// (port/RULEBOOK.md section 0 item 4). `tool/generate.dart` runs it.

import 'dart:io';
import 'dart:math' as math;

import 'generator.dart';

/// Where the generated table goes, relative to the package root.
const String lucideTablePath = 'lib/src/foundation/icons/lucide_icons.g.dart';

/// A lucide-react release the table holds.
class LucideReactRelease {
  /// The release [version], whose constants in the table start with [id].
  const LucideReactRelease(this.id, this.version);

  /// The prefix of its constants (`_reactCoreIcons`), and its
  /// `LucideRelease` value's name.
  final String id;

  /// The npm version.
  final String version;
}

/// The releases CopilotKit draws icons with: react-core's lucide-react
/// (`packages/react-core/package.json:109` asks `^0.525.0`; the repo's
/// `pnpm-lock.yaml:3245-3247` resolves it, and so does the playground's
/// `pnpm-lock.yaml:6058`, in its published `@copilotkit/react-core@1.85.0`)
/// and the playground's own (`examples/showcases/a2ui-playground/
/// package.json:38`, `pnpm-lock.yaml:62-64`).
const List<LucideReactRelease> lucideReactReleases = [
  LucideReactRelease('reactCore', '0.525.0'),
  LucideReactRelease('playground', '1.57.0'),
];

/// The folder that holds the fetched packages, each in
/// `lucide-react@<version>/`: `$A2UI_THIRDPARTY_SRC`, else
/// `third_party_src/` in the package, which git ignores (port/RULEBOOK.md
/// section 0 item 4).
Directory thirdPartySources() =>
    Directory(Platform.environment['A2UI_THIRDPARTY_SRC'] ?? 'third_party_src');

/// The name CopilotKit looks an icon up by: `kebabToPascal` in react-core's
/// `media.tsx:64-70` ("arrow-down-0-1" gives "ArrowDown01").
String lucidePascalName(String name) => name
    .split(RegExp(r'[-_\s]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join();

/// One element of an icon node: its SVG [tag] and its attributes, `key`
/// (React's) left out.
class LucideNodeElement {
  /// An element.
  const LucideNodeElement(this.tag, this.attributes);

  /// `path`, `circle`, `rect`, `line`, `polyline`, `polygon` or `ellipse`.
  final String tag;

  /// The attributes, as the package writes them.
  final Map<String, String> attributes;
}

/// One lucide-react package, read from its published `dist/esm/` files.
class LucideReactPackage {
  /// A package of [version].
  const LucideReactPackage({
    required this.version,
    required this.icons,
    required this.aliases,
  });

  /// Reads the package at [root] (`lucide-react@<version>/`), which must be
  /// [version].
  ///
  /// Throws [StateError] when a file is missing or holds anything the
  /// reader does not know, so that a new form stops the generator rather
  /// than drawing something else.
  factory LucideReactPackage.read(Directory root, String version) {
    String read(String path) {
      final file = File('${root.path}/$path');
      if (!file.existsSync()) {
        throw StateError(
          '${file.path} not found: fetch lucide-react@$version whole from '
          'registry.npmjs.org into ${root.path} (port/RULEBOOK.md section 0 '
          'item 4), or set A2UI_THIRDPARTY_SRC.',
        );
      }
      return file.readAsStringSync().replaceAll('\r\n', '\n');
    }

    final manifest = read('package.json');
    final found = RegExp('"version": "([^"]+)"').firstMatch(manifest)?[1];
    if (found != version) {
      throw StateError('${root.path} holds lucide-react $found, not $version.');
    }
    // 0.525.0 builds `.js` files, 1.57.0 `.mjs`.
    final ext = File('${root.path}/dist/esm/lucide-react.mjs').existsSync()
        ? '.mjs'
        : '.js';
    final stems = lucideIndex(read('dist/esm/icons/index$ext'), ext);
    final icons = <String, List<LucideNodeElement>>{
      for (final MapEntry(key: name, value: stem) in stems.entries)
        name: lucideIconNode(read('dist/esm/icons/$stem$ext'), stem),
    };
    final aliases = lucideAliases(
      read('dist/esm/lucide-react$ext'),
      ext,
      stems,
    );
    return LucideReactPackage(version: version, icons: icons, aliases: aliases);
  }

  /// The npm version.
  final String version;

  /// The `icons` map (`import { icons } from "lucide-react"`, the namespace
  /// of `dist/esm/icons/index`): each name and its node, in the index's
  /// order.
  final Map<String, List<LucideNodeElement>> icons;

  /// The other names the package exports an icon by (`AlertTriangle`), each
  /// with the [icons] name of the same icon (`TriangleAlert`).
  final Map<String, String> aliases;
}

/// The names of `dist/esm/icons/index.js` ([source]; `.mjs` with [ext]) and
/// the file stem of each: lucide-react's `icons` map.
///
/// Throws [StateError] on a line that is neither the licence comment nor
/// one `export { default as Name } from './stem.js';`.
Map<String, String> lucideIndex(String source, String ext) {
  final line = RegExp(
    r"^export \{ default as ([A-Za-z0-9]+) \} from '\./([a-z0-9-]+)"
    '${RegExp.escape(ext)}'
    r"';$",
  );
  final stems = <String, String>{};
  for (final text in _code(source)) {
    final match = line.firstMatch(text);
    if (match == null) {
      throw StateError('Unexpected line in icons/index$ext: $text');
    }
    if (stems.containsKey(match[1])) {
      throw StateError('icons/index$ext exports ${match[1]} twice.');
    }
    stems[match[1]!] = match[2]!;
  }
  if (stems.length < 1000) {
    throw StateError('icons/index$ext exports ${stems.length} icons.');
  }
  return stems;
}

/// The lines of a built file that are code: not blank, not the licence
/// comment, not the source map, not a directive.
Iterable<String> _code(String source) => source
    .split('\n')
    .map((line) => line.trim())
    .where(
      (line) =>
          line.isNotEmpty &&
          !line.startsWith('/**') &&
          !line.startsWith('*') &&
          !line.startsWith('//') &&
          line != '"use strict";' &&
          line != '"use client";',
    );

/// The node of one icon file ([source], `dist/esm/icons/<stem>.js`): 0.525.0
/// writes `const __iconNode = [...]`, 1.57.0 `const __iconData = { name,
/// size, node, aliases }`.
///
/// Throws [StateError] on another form, an element or attribute the table
/// cannot hold, a size other than 24, or a name other than [stem].
List<LucideNodeElement> lucideIconNode(String source, String stem) {
  Object? node;
  final legacy = source.indexOf('const __iconNode = ');
  final data = source.indexOf('const __iconData = ');
  if (legacy >= 0) {
    node = _JsReader(source, legacy + 'const __iconNode = '.length).literal();
  } else if (data >= 0) {
    final value = _JsReader(
      source,
      data + 'const __iconData = '.length,
    ).literal();
    if (value is! Map<String, Object?> ||
        value['name'] != stem ||
        value['size'] != 24 ||
        !value.keys.every({'name', 'size', 'node', 'aliases'}.contains)) {
      throw StateError('$stem: unexpected __iconData $value.');
    }
    node = value['node'];
  } else {
    throw StateError('$stem: no __iconNode or __iconData.');
  }
  if (node is! List<Object?> || node.isEmpty) {
    throw StateError('$stem: the node is not a list of elements.');
  }
  return [
    for (final element in node)
      switch (element) {
        [final String tag, final Map<String, Object?> attributes] =>
          LucideNodeElement(tag, {
            for (final MapEntry(:key, :value) in attributes.entries)
              if (key != 'key')
                key: value is String
                    ? value
                    : throw StateError('$stem: $tag $key is not a string.'),
          }),
        _ => throw StateError('$stem: unexpected element $element.'),
      },
  ];
}

/// The other names [source] (`dist/esm/lucide-react.js`) exports each icon
/// by, with the `icons` name ([stems]: name to file stem) of each.
///
/// Each icon's line exports its names with an `Icon` suffix and a `Lucide`
/// prefix too (`AlertTriangle`, `AlertTriangleIcon`, `LucideAlertTriangle`);
/// only the plain names are kept.
///
/// Throws [StateError] when a line breaks that pattern, a stem is not in the
/// index, an index name is not among its line's names, or a name is exported
/// twice.
Map<String, String> lucideAliases(
  String source,
  String ext,
  Map<String, String> stems,
) {
  final names = {
    for (final MapEntry(:key, :value) in stems.entries) value: key,
  };
  final line = RegExp(
    r"^export \{ (.*) \} from '\./icons/([a-z0-9-]+)"
    '${RegExp.escape(ext)}'
    r"';$",
  );
  final aliases = <String, String>{};
  final seen = <String>{};
  final lines = <String>{};
  for (final text in _code(source)) {
    final match = line.firstMatch(text);
    if (match == null) continue;
    final stem = match[2]!;
    final canonical =
        names[stem] ?? (throw StateError('$stem is not in icons/index$ext.'));
    if (!lines.add(stem)) throw StateError('$stem is exported twice.');
    final exported = <String>[];
    for (final part in match[1]!.split(', ')) {
      if (!part.startsWith('default as ')) {
        throw StateError('$stem: unexpected export $part.');
      }
      exported.add(part.substring('default as '.length));
    }
    final all = exported.toSet();
    final plain = {
      for (final name in all)
        if (all.contains('${name}Icon') && all.contains('Lucide$name')) name,
    };
    if (all.length != exported.length ||
        all.length != 3 * plain.length ||
        !plain.contains(canonical)) {
      throw StateError('$stem: unexpected exports ${match[1]}.');
    }
    for (final name in all) {
      if (!seen.add(name)) throw StateError('$name is exported twice.');
    }
    for (final name in plain) {
      if (name != canonical) aliases[name] = canonical;
    }
  }
  if (lines.length != stems.length) {
    throw StateError(
      'lucide-react$ext exports ${lines.length} icons; the index has '
      '${stems.length}.',
    );
  }
  return aliases;
}

final RegExp _number = RegExp(r'^-?(\d+\.?\d*|\.\d+)$');

String _dartNumber(String text, String where) {
  if (!_number.hasMatch(text)) throw StateError('$where: $text is no number.');
  final value = double.parse(text);
  return value == value.truncateToDouble() && value.abs() < 1e9
      ? value.toInt().toString()
      : value.toString();
}

/// The Dart source of [element] (of the [icon] named in an error): a
/// `const` element of `lib/src/foundation/icons/lucide.dart`.
///
/// Throws [StateError] on a tag, an attribute or a value the element classes
/// do not hold: `fill` other than `currentColor`, a missing coordinate, a
/// number SVG would not read as one, path data with a quote in it.
String lucideElementSource(LucideNodeElement element, String icon) {
  final where = '$icon ${element.tag}';
  final attributes = {...element.attributes};
  final fill = attributes.remove('fill');
  if (fill != null && fill != 'currentColor') {
    throw StateError('$where: fill $fill.');
  }
  String take(String name) => _dartNumber(
    attributes.remove(name) ?? (throw StateError('$where: no $name.')),
    where,
  );
  String? maybe(String name) {
    final text = attributes.remove(name);
    return text == null ? null : _dartNumber(text, where);
  }

  // A radius or a size of 0 or less (which SVG draws as nothing, or reads
  // as `auto`) is not a form the element classes hold.
  String positive(String? number, String name) =>
      number != null && double.parse(number) > 0
      ? number
      : throw StateError('$where: $name ${number ?? 'missing'}.');

  final arguments = <String>[];
  final String type;
  switch (element.tag) {
    case 'path':
      final d = attributes.remove('d') ?? (throw StateError('$where: no d.'));
      if (!RegExp(r'^[MmZzLlHhVvCcSsQqTtAa0-9eE.,+\- ]+$').hasMatch(d)) {
        throw StateError('$where: unexpected path data $d.');
      }
      type = 'LucidePath';
      arguments.add("'$d'");
    case 'circle':
      type = 'LucideCircle';
      arguments.addAll([take('cx'), take('cy'), positive(take('r'), 'r')]);
    case 'ellipse':
      type = 'LucideEllipse';
      arguments.addAll([
        take('cx'),
        take('cy'),
        positive(take('rx'), 'rx'),
        positive(take('ry'), 'ry'),
      ]);
    case 'rect':
      type = 'LucideRect';
      arguments.addAll([
        maybe('x') ?? '0',
        maybe('y') ?? '0',
        positive(take('width'), 'width'),
        positive(take('height'), 'height'),
      ]);
      if (maybe('rx') case final rx?) {
        arguments.add('rx: ${positive(rx, 'rx')}');
      }
      if (maybe('ry') case final ry?) {
        arguments.add('ry: ${positive(ry, 'ry')}');
      }
    case 'line':
      type = 'LucideLine';
      arguments.addAll([take('x1'), take('y1'), take('x2'), take('y2')]);
    case 'polyline' || 'polygon':
      type = element.tag == 'polyline' ? 'LucidePolyline' : 'LucidePolygon';
      final points =
          (attributes.remove('points') ??
                  (throw StateError('$where: no points.')))
              .trim()
              .split(RegExp(r'[\s,]+'));
      if (points.length.isOdd || points.length < 4) {
        throw StateError('$where: points ${points.join(' ')}.');
      }
      arguments.add('[${points.map((p) => _dartNumber(p, where)).join(', ')}]');
    default:
      throw StateError('$where: the table has no ${element.tag} element.');
  }
  if (attributes.isNotEmpty) {
    throw StateError('$where: unexpected ${attributes.keys.join(', ')}.');
  }
  if (fill != null) arguments.add('filled: true');
  return '$type(${arguments.join(', ')})';
}

/// The generated table from [packages], in the order of
/// [lucideReactReleases]: every distinct node once, then each release's
/// `icons` map (name to node) and its aliases.
GeneratedFile generateLucideTable(List<LucideReactPackage> packages) {
  if ([for (final p in packages) p.version].join() !=
      [for (final r in lucideReactReleases) r.version].join()) {
    throw StateError('The packages are not ${lucideReactReleases.length}.');
  }
  final nodeIndex = <String, int>{};
  final nodeNames = <List<String>>[];
  final nodes = <String>[];
  final maps = <Map<String, int>>[];
  for (final package in packages) {
    final map = <String, int>{};
    for (final MapEntry(key: name, value: node) in package.icons.entries) {
      final where = '$name (${package.version})';
      final source =
          '[${node.map((e) => lucideElementSource(e, where)).join(', ')}]';
      final index = nodeIndex.putIfAbsent(source, () {
        nodes.add(source);
        nodeNames.add([]);
        return nodes.length - 1;
      });
      nodeNames[index].add('$name ${package.version}');
      map[name] = index;
    }
    maps.add(map);
  }
  final out = StringBuffer()
    ..writeln(
      '// GENERATED CODE. Do not edit by hand: run '
      '`dart run tool/generate.dart`.',
    )
    ..writeln(
      '// Source: lucide-react ${packages.first.version} and lucide-react '
      '${packages.last.version}',
    )
    ..writeln(
      '// (ISC License, see NOTICE.md), read from each package: the icon '
      'nodes from',
    )
    ..writeln(
      '// `dist/esm/icons/<name>.js` (`.mjs`), the `icons` map from '
      '`dist/esm/icons/index.js`',
    )
    ..writeln(
      '// and the names each icon is exported by from '
      '`dist/esm/lucide-react.js`.',
    )
    ..writeln(
      '// ignore_for_file: lines_longer_than_80_chars (one path per line)',
    )
    ..writeln()
    ..writeln("part of 'lucide.dart';")
    ..writeln();
  for (final (i, release) in lucideReactReleases.indexed) {
    out
      ..writeln('/// The version of [LucideRelease.${release.id}].')
      ..writeln(
        "const String _${release.id}Version = '${packages[i].version}';",
      )
      ..writeln();
  }
  out
    ..writeln('/// Every distinct icon node of the releases, once each: the')
    ..writeln(
      "/// elements of lucide-react's `__iconNode` (`__iconData.node`),",
    )
    ..writeln('/// in its order.')
    ..writeln('const List<List<LucideElement>> _nodes = [');
  for (final (i, node) in nodes.indexed) {
    out
      ..writeln('  // $i: ${nodeNames[i].join(', ')}')
      ..writeln('  $node,');
  }
  out.writeln('];');
  for (final (i, release) in lucideReactReleases.indexed) {
    final version = packages[i].version;
    out
      ..writeln()
      ..writeln("/// lucide-react $version's `icons` map: each name and its")
      ..writeln('/// node in [_nodes].')
      ..writeln('const Map<String, int> _${release.id}Icons = {');
    for (final MapEntry(:key, :value) in maps[i].entries) {
      out.writeln("  '$key': $value,");
    }
    out
      ..writeln('};')
      ..writeln()
      ..writeln('/// The other names lucide-react $version exports an icon')
      ..writeln('/// by, each with its name in [_${release.id}Icons].')
      ..writeln('const Map<String, String> _${release.id}Aliases = {');
    final aliases = packages[i].aliases.keys.toList()..sort();
    for (final alias in aliases) {
      out.writeln("  '$alias': '${packages[i].aliases[alias]}',");
    }
    out.writeln('};');
  }
  return GeneratedFile(lucideTablePath, out.toString());
}

/// One line per release whose package is not in [sources]
/// ([thirdPartySources] by default); empty when every one is there.
List<String> missingLucideSources([Directory? sources]) {
  final root = sources ?? thirdPartySources();
  return [
    for (final release in lucideReactReleases)
      if (!File(
        '${root.path}/lucide-react@${release.version}/package.json',
      ).existsSync())
        _missing(release.version, root),
  ];
}

String _missing(String version, Directory root) =>
    'lucide-react@$version is not in ${root.path}: fetch it whole from '
    'registry.npmjs.org and check it against the sha512 in '
    "CopilotKit's pnpm-lock.yaml (port/RULEBOOK.md section 0 item 4), or "
    'set A2UI_THIRDPARTY_SRC.';

/// The generated table from the fetched packages in [sources]
/// ([thirdPartySources] by default).
GeneratedFile generateLucideTableFromSources([Directory? sources]) {
  final root = sources ?? thirdPartySources();
  return generateLucideTable([
    for (final release in lucideReactReleases)
      LucideReactPackage.read(
        Directory('${root.path}/lucide-react@${release.version}'),
        release.version,
      ),
  ]);
}

/// A reader of the JavaScript literals lucide-react's built files hold:
/// arrays, objects with identifier keys, double-quoted strings without
/// escapes, and integers. Anything else throws [StateError].
class _JsReader {
  _JsReader(this.source, this.at);

  final String source;
  int at;

  Never _fail(String what) {
    final end = math.min(at + 40, source.length);
    throw StateError('Unexpected $what at ${source.substring(at, end)}');
  }

  void _space() {
    while (at < source.length && ' \n\t'.contains(source[at])) {
      at++;
    }
  }

  Object? literal() {
    _space();
    if (at >= source.length) _fail('end');
    final char = source[at];
    if (char == '[') {
      at++;
      final items = <Object?>[];
      _space();
      if (source[at] == ']') {
        at++;
        return items;
      }
      while (true) {
        items.add(literal());
        _space();
        if (source[at] == ',') {
          at++;
        } else if (source[at] == ']') {
          at++;
          return items;
        } else {
          _fail('array text');
        }
      }
    }
    if (char == '{') {
      at++;
      final entries = <String, Object?>{};
      while (true) {
        _space();
        final key = RegExp('[A-Za-z_][A-Za-z0-9_]*').matchAsPrefix(source, at);
        if (key == null) _fail('object key');
        at = key.end;
        _space();
        if (source[at] != ':') _fail('object text');
        at++;
        if (entries.containsKey(key[0])) _fail('repeated key');
        entries[key[0]!] = literal();
        _space();
        if (source[at] == ',') {
          at++;
        } else if (source[at] == '}') {
          at++;
          return entries;
        } else {
          _fail('object text');
        }
      }
    }
    if (char == '"') {
      final end = source.indexOf('"', at + 1);
      if (end < 0) _fail('string');
      final text = source.substring(at + 1, end);
      if (text.contains(r'\') || text.contains('\n')) _fail('string escape');
      at = end + 1;
      return text;
    }
    final number = RegExp(r'\d+').matchAsPrefix(source, at);
    if (number == null) _fail('value');
    at = number.end;
    return int.parse(number[0]!);
  }
}
