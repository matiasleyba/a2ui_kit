// The code generator of a2ui_kit: CopilotKit's exported catalog documents in,
// Dart sources out. `tool/generate.dart` runs it; a test checks that the
// committed sources match what it produces.

import 'dart:convert';

/// One generated source file.
class GeneratedFile {
  /// A generated file at [path] (relative to the package root, with `/`).
  const GeneratedFile(this.path, this.content);

  /// The path relative to the package root.
  final String path;

  /// The Dart source, before `dart format`.
  final String content;
}

/// Where the generator reads the catalog document, relative to the package.
const String catalogFixturePath = 'test/fixtures/copilotkit/catalog.json';

/// Where the generator reads the inference catalog document.
const String inferenceFixturePath =
    'test/fixtures/copilotkit/inference-catalog.json';

/// The id of the playground catalog.
const String playgroundCatalogId =
    'https://copilotkit.ai/a2ui/catalogs/playground/v1';

/// The 69 components of CopilotKit's `standardUI`, in its order
/// (`packages/react-core/src/v2/generative-ui/standard/index.ts`).
const List<String> standardComponentNames = [
  'Box', 'Column', 'Row', 'Grid', 'GridItem', 'Card', 'Flow', 'FlowItem', //
  'Carousel', 'CarouselItem', 'CarouselMediaItem', 'Spacer', 'Divider',
  'Tabs', 'Title', 'Text', 'Caption', 'Label', 'Bold', 'Italic',
  'Underline', 'Strikethrough', 'Badge', 'Blockquote', 'Code', 'Markdown',
  'Math', 'ShimmerText', 'Link', 'Tooltip', 'Button', 'Pressable', 'Form',
  'TextField', 'TextArea', 'Select', 'CheckBox', 'Radio', 'RadioGroup',
  'Slider', 'SegmentedControl', 'ChoicePicker', 'DateTimeInput',
  'PulseIndicator', 'FlashcardFlip', 'Popover', 'PopoverTrigger',
  'PopoverContent', 'Modal', 'Table', 'TableSection', 'TableRow',
  'TableCell', 'List', 'ListItem', 'Chart', 'Map', 'Image', 'Icon',
  'Favicon', 'Svg', 'Video', 'AudioPlayer', 'HtmlView', 'LinkCard',
  'Citation', 'FollowUp', 'EntityCard', 'ImageGrid',
];

/// Names for enums whose value set more than one prop shares, keyed by the
/// value set joined with `|`. A shared set without a name here stops the
/// generator, so a new CopilotKit release cannot add one silently.
const Map<String, String> sharedEnumNames = {
  'default|subtle|strong|info|warning|caution|success|danger|discovery':
      'A2uiBorderColor',
  '2xs|xs|sm|md|lg|xl|2xl|3xl|4xl|full': 'A2uiRadius',
  'start|center|end|baseline|stretch': 'A2uiAlign',
  'start|center|end|spaceBetween|spaceAround|spaceEvenly|stretch':
      'A2uiJustify',
  'nowrap|wrap|wrap-reverse': 'A2uiWrap',
  'number|currency|percent|compact': 'A2uiValueFormat',
  'start|center|end': 'A2uiTextAlign',
  'error|warning|info': 'A2uiCheckSeverity',
  'normal|medium|semibold|bold': 'A2uiFontWeight',
  'sm|md|lg': 'A2uiSize',
  'sm|md|lg|xl': 'A2uiControlSize',
  'default|positive|negative|warning|info|accent': 'A2uiTone',
  '3xs|2xs|xs|sm|md|lg': 'A2uiTextSize',
  'vertical|horizontal': 'A2uiOrientation',
  'secondary|success|danger|warning|info|discovery': 'A2uiBadgeColor',
  'solid|soft|outline|ghost': 'A2uiActionVariant',
  'up|down|flat': 'A2uiTrend',
};

/// The props each component writes back to the data model when bound with
/// `{"@path"}`: the `writable` lists of CopilotKit's declarations, which the
/// export leaves out. Sources: `packages/shared/src/generative-ui/standard/
/// {inputs,layout,feedback,data}.ts` and the playground's
/// `src/a2ui/catalog/definitions/inputs.ts` (`writableValue`).
const Map<String, List<String>> writableProps = {
  'TextField': ['value'],
  'TextArea': ['value'],
  'Select': ['value'],
  'CheckBox': ['value'],
  'RadioGroup': ['value'],
  'Slider': ['value'],
  'SegmentedControl': ['value'],
  'ChoicePicker': ['value'],
  'DateTimeInput': ['value'],
  'Tabs': ['selectedIndex'],
  'Carousel': ['activeIndex'],
  'Popover': ['open'],
  'Modal': ['open'],
  'Map': ['selected'],
  'Combobox': ['value'],
  'Switch': ['value'],
  'DatePicker': ['value'],
  'ButtonGroup': ['value'],
  'ChipSelect': ['value'],
};

/// The arguments each event sends, by component and event prop: the
/// `parameters` of CopilotKit's event declarations, which the export leaves
/// out. Every `Action` prop of the catalog must be here; most send none
/// (`NO_ARGS`). The arguments go into the event's context, where the
/// binding's own context entries win.
const Map<String, Map<String, List<String>>> eventArguments = {
  'Box': {'onVisible': []},
  'Column': {'onVisible': []},
  'Row': {'onVisible': []},
  'Grid': {'onVisible': []},
  'GridItem': {'onVisible': []},
  'Card': {'onVisible': []},
  'Flow': {'onVisible': []},
  'FlowItem': {'onVisible': []},
  'Carousel': {'onVisible': []},
  'CarouselItem': {'onVisible': []},
  'CarouselMediaItem': {'onClick': [], 'onVisible': []},
  'Button': {'onClick': []},
  'Pressable': {'onClick': [], 'onVisible': []},
  'Form': {'onSubmit': []},
  // `listSelection` in data.ts: the picked item.
  'List': {
    'action': ['index', 'label', 'value'],
  },
  'ListItem': {'action': []},
  'Image': {'onOverlayClick': []},
  'LinkCard': {'onClick': []},
  // `followUpArgs` in composites.ts.
  'FollowUp': {
    'onFollowUp': ['message'],
  },
  // `entityActionArgs` in composites.ts.
  'EntityCard': {
    'onAction': ['label'],
    'onClick': [],
  },
  // The playground's `def(…, { events })`: `z.object({}).passthrough()`.
  'Callout': {'onAction': []},
  'EmptyState': {'onAction': []},
  'EventCard': {'onAction': []},
};

const String _dataBinding = r'common_types.json#/$defs/DataBinding';
const String _functionCall = r'common_types.json#/$defs/FunctionCall';

const Set<String> _reserved = {
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', //
  'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
  'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
  'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
};

/// Member names a typed props view cannot declare.
const Set<String> _forbiddenGetters = {
  'raw', 'hashCode', 'runtimeType', 'toString', 'noSuchMethod', //
};

const List<String> _digitWords = [
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', //
  'nine',
];

const String _header =
    '// GENERATED CODE. Do not edit by hand: run `dart run tool/generate.dart`.\n'
    '// Source: CopilotKit (MIT, (c) Atai Barkai), commit ff6f3b03, the A2UI\n'
    '// Playground export. See NOTICE.md.\n';

/// Generates every source from the two documents' JSON text.
///
/// Throws [StateError] when the documents break an assumption of the
/// package: the component or function count, the standard names, or an
/// unnamed shared enum.
List<GeneratedFile> generate({
  required String catalogJson,
  required String inferenceJson,
}) {
  final catalog = jsonDecode(catalogJson) as Map<String, Object?>;
  final inference = jsonDecode(inferenceJson) as Map<String, Object?>;
  _checkCatalog(catalog);
  return [
    GeneratedFile(
      'lib/src/document/catalog_document.g.dart',
      _documentSource(
        catalog,
        constName: 'catalogDocumentJson',
        doc:
            "/// CopilotKit's exported A2UI Playground catalog document\n"
            '/// (`catalog.json`): the render contract, 121 components and 16\n'
            '/// functions, as JSON text.\n',
        extra: _namesSource(catalog),
      ),
    ),
    GeneratedFile(
      'lib/src/document/inference_document.g.dart',
      _documentSource(
        inference,
        constName: 'inferenceDocumentJson',
        doc:
            "/// CopilotKit's model-facing A2UI Playground catalog document\n"
            '/// (`inference-catalog.json`): the render catalog with trimmed\n'
            '/// descriptions, without styling props, plus the macros.\n',
      ),
    ),
    GeneratedFile(
      'lib/src/document/props.g.dart',
      _PropsWriter(catalog).write(),
    ),
    GeneratedFile(
      'lib/src/document/behaviour.g.dart',
      _behaviourSource(catalog),
    ),
  ];
}

/// The writable props and event arguments as Dart, after checking the
/// tables against the catalog: every named prop exists, every writable prop
/// takes a data binding, and the event table names exactly the catalog's
/// `Action` props.
String _behaviourSource(Map<String, Object?> catalog) {
  final components = (catalog['components']! as Map<String, Object?>)
      .cast<String, Map<String, Object?>>();
  Map<String, Object?> propsOf(String component) {
    final schema = components[component];
    if (schema == null) {
      throw StateError('The tables name $component, which is no component.');
    }
    return schema['properties']! as Map<String, Object?>;
  }

  writableProps.forEach((component, props) {
    final declared = propsOf(component);
    for (final prop in props) {
      final schema = declared[prop];
      if (schema is! Map || !jsonEncode(schema).contains(_dataBinding)) {
        throw StateError('$component.$prop is not a bindable prop.');
      }
    }
  });
  final actions = <String, Set<String>>{};
  components.forEach((component, schema) {
    final props = schema['properties']! as Map<String, Object?>;
    for (final entry in props.entries) {
      final value = entry.value;
      if (value is Map && '${value[r'$ref']}'.endsWith('/Action')) {
        actions.putIfAbsent(component, () => {}).add(entry.key);
      }
    }
  });
  final named = {
    for (final entry in eventArguments.entries)
      entry.key: entry.value.keys.toSet(),
  };
  for (final component in {...actions.keys, ...named.keys}) {
    final inCatalog = actions[component] ?? const <String>{};
    final inTable = named[component] ?? const <String>{};
    if (inCatalog.length != inTable.length || !inCatalog.containsAll(inTable)) {
      throw StateError(
        'The events of $component are $inCatalog in the catalog but '
        '$inTable in eventArguments: update the table.',
      );
    }
  }

  final out = StringBuffer()
    ..write(_header)
    ..writeln()
    ..writeln('/// The props each component writes back to the data model when')
    ..writeln(
      '/// the payload binds them with `{"@path"}`: the `writable` lists',
    )
    ..writeln("/// of CopilotKit's declarations, which the exported catalog")
    ..writeln("/// leaves out. A written path becomes the user's: later agent")
    ..writeln('/// writes at or below it are ignored.')
    ..writeln('const Map<String, Set<String>> writableProps = {');
  writableProps.forEach((component, props) {
    out.writeln("  '$component': {${props.map((p) => "'$p'").join(', ')}},");
  });
  out
    ..writeln('};')
    ..writeln()
    ..writeln(
      '/// The arguments each event sends, by component and event prop:',
    )
    ..writeln(
      "/// the `parameters` of CopilotKit's event declarations. They go",
    )
    ..writeln("/// into the event's context, where the binding's own context")
    ..writeln('/// entries win. An empty list is no arguments.')
    ..writeln(
      'const Map<String, Map<String, List<String>>> eventArguments = {',
    );
  eventArguments.forEach((component, events) {
    final entries = [
      for (final MapEntry(key: event, value: args) in events.entries)
        "'$event': [${args.map((a) => "'$a'").join(', ')}]",
    ];
    out.writeln("  '$component': {${entries.join(', ')}},");
  });
  out.writeln('};');
  return out.toString();
}

/// [source] with the differences `dart format` makes removed: whitespace,
/// and the commas before a closing bracket that the formatter adds or drops.
String normalizeDart(String source) => source
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAllMapped(RegExp(r',([)\]}])'), (m) => m[1]!);

void _checkCatalog(Map<String, Object?> catalog) {
  if (catalog['catalogId'] != playgroundCatalogId) {
    throw StateError('Unexpected catalogId ${catalog['catalogId']}.');
  }
  final components = catalog['components']! as Map<String, Object?>;
  final functions = catalog['functions']! as Map<String, Object?>;
  if (components.length != 121) {
    throw StateError('Expected 121 components, got ${components.length}.');
  }
  if (functions.length != 16) {
    throw StateError('Expected 16 functions, got ${functions.length}.');
  }
  final names = components.keys.toList();
  for (var i = 0; i < standardComponentNames.length; i++) {
    if (names[i] != standardComponentNames[i]) {
      throw StateError(
        'Component ${i + 1} is ${names[i]}, expected the standard '
        '${standardComponentNames[i]}.',
      );
    }
  }
}

String _documentSource(
  Map<String, Object?> document, {
  required String constName,
  required String doc,
  String extra = '',
}) {
  final json = const JsonEncoder.withIndent(' ').convert(document);
  if (json.contains("'''")) {
    throw StateError('The document contains three quotes in a row.');
  }
  return '$_header'
      '// ignore_for_file: lines_longer_than_80_chars '
      '(a JSON document, kept whole)\n'
      '\n'
      '$doc'
      "const String $constName = r'''\n"
      '$json\n'
      "''';\n"
      '$extra';
}

String _namesSource(Map<String, Object?> catalog) {
  final names = (catalog['components']! as Map<String, Object?>).keys;
  final functions = (catalog['functions']! as Map<String, Object?>).keys;
  final out = StringBuffer()
    ..writeln()
    ..writeln(
      '/// Every component of the playground catalog, in document order:',
    )
    ..writeln('/// the 69 standard components, then the 52 of the playground.')
    ..writeln('const List<String> playgroundComponentNames = [');
  for (final name in names) {
    out.writeln("  '$name',");
  }
  out
    ..writeln('];')
    ..writeln()
    ..writeln("/// The 69 components of CopilotKit's standard catalog.")
    ..writeln('const List<String> standardComponentNames = [');
  for (final name in standardComponentNames) {
    out.writeln("  '$name',");
  }
  out
    ..writeln('];')
    ..writeln()
    ..writeln(
      '/// Every function of the playground catalog, in document order.',
    )
    ..writeln('const List<String> playgroundFunctionNames = [');
  for (final name in functions) {
    out.writeln("  '$name',");
  }
  out.writeln('];');
  return out.toString();
}

/// The Dart identifier of an enum wire value.
String enumValueName(String wire) {
  var parts = wire
      .split(RegExp('[^A-Za-z0-9]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) throw StateError('Empty enum value "$wire".');
  // A leading number becomes a word: "2xl" is twoXl, "1" is one.
  final lead = RegExp(r'^(\d)(.*)$').firstMatch(parts.first);
  if (lead != null) {
    parts = [
      _digitWords[int.parse(lead[1]!)],
      lead[2]!,
      ...parts.skip(1),
    ].where((p) => p.isNotEmpty).toList();
  }
  final buffer = StringBuffer(_lowerFirst(parts.first));
  for (final part in parts.skip(1)) {
    buffer.write(_upperFirst(part));
  }
  final name = buffer.toString();
  return _reserved.contains(name) ? '${name}_' : name;
}

String _upperFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _lowerFirst(String s) {
  if (s.isEmpty) return s;
  // An all-caps value ("C") becomes lower case.
  if (s.toUpperCase() == s) return s.toLowerCase();
  return s[0].toLowerCase() + s.substring(1);
}

/// A doc comment of [text], one `///` line per line of [text], wrapped at
/// about 76 columns.
String _docComment(String text, {String indent = ''}) {
  final out = StringBuffer();
  for (final paragraph in text.split('\n')) {
    if (paragraph.trim().isEmpty) {
      out.writeln('$indent///');
      continue;
    }
    var line = StringBuffer();
    for (final word in paragraph.split(' ')) {
      if (line.isNotEmpty && line.length + word.length + 1 > 72) {
        out.writeln('$indent/// $line'.trimRight());
        line = StringBuffer();
      }
      if (line.isNotEmpty) line.write(' ');
      line.write(word);
    }
    if (line.isNotEmpty) out.writeln('$indent/// $line'.trimRight());
  }
  return out.toString();
}

/// [text] from CopilotKit's descriptions with its square brackets escaped,
/// so dartdoc does not read `[{x,y}]` as a reference.
String _escapeBrackets(String text) =>
    text.replaceAll('[', r'\[').replaceAll(']', r'\]');

/// The value of a schema description's `Default …` sentence: a string, a
/// bool or a number, or null when it states none.
Object? describedDefault(String? description) {
  if (description == null) return null;
  final match = RegExp(
    r'(?:^|\. |\()Default ("[^"]*"|true|false|-?\d+(?:\.\d+)?)',
  ).firstMatch(description);
  if (match == null) return null;
  final raw = match[1]!;
  if (raw.startsWith('"')) return raw.substring(1, raw.length - 1);
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  return num.parse(raw);
}

class _Enum {
  _Enum(this.name, this.values);
  final String name;
  final List<String> values;
  final List<String> uses = [];
}

class _Prop {
  _Prop(this.name, this.schema);
  final String name;
  final Map<String, Object?> schema;
}

/// The kind of a prop's value, once the dynamic alternatives are removed.
enum _Kind {
  childList,
  componentId,
  action,
  enumeration,
  string,
  number,
  boolean,
  list,
  map,
  text,
  any,
}

class _Shape {
  const _Shape(this.kind, {this.values = const []});
  final _Kind kind;
  final List<String> values;
}

class _PropsWriter {
  _PropsWriter(this.catalog)
    : components = (catalog['components']! as Map<String, Object?>)
          .cast<String, Map<String, Object?>>();

  final Map<String, Object?> catalog;
  final Map<String, Map<String, Object?>> components;
  final Map<String, _Enum> enums = {};

  String write() {
    // Every enum a top-level prop uses, named first, so that the views can
    // refer to them.
    final setsUsed = <String, List<String>>{};
    components.forEach((component, schema) {
      for (final prop in _props(schema)) {
        final shape = _shapeOf(prop.schema);
        if (shape.kind != _Kind.enumeration) continue;
        setsUsed
            .putIfAbsent(shape.values.join('|'), () => [])
            .add('$component.${prop.name}');
      }
    });
    final allUses = _allEnumUses();
    setsUsed.forEach((key, uses) {
      final everyUse = allUses[key] ?? uses;
      final shared = sharedEnumNames[key];
      String name;
      if (shared != null) {
        name = shared;
      } else if (everyUse.length == 1) {
        final [component, prop] = uses.single.split('.');
        // Chart.chartType is ChartType, not ChartChartType.
        name = prop.toLowerCase().startsWith(component.toLowerCase())
            ? _upperFirst(prop)
            : '$component${_upperFirst(prop)}';
      } else {
        throw StateError(
          'The enum {$key} is shared by ${everyUse.join(', ')}: give it a '
          'name in sharedEnumNames.',
        );
      }
      enums[key] = _Enum(name, key.split('|'))..uses.addAll(uses);
    });
    // A shared set that only nested props use (Box.radius sits in a union)
    // still gets its enum: the theme and the builders name its values.
    allUses.forEach((key, uses) {
      final shared = sharedEnumNames[key];
      if (shared == null || enums.containsKey(key)) return;
      enums[key] = _Enum(shared, key.split('|'))..uses.addAll(uses);
    });
    for (final key in sharedEnumNames.keys) {
      if (!enums.containsKey(key)) {
        throw StateError('No prop uses the shared enum {$key} any more.');
      }
    }
    final names = <String>{};
    for (final e in enums.values) {
      if (!names.add(e.name)) throw StateError('Two enums named ${e.name}.');
    }

    final out = StringBuffer()
      ..write(_header)
      ..writeln(
        '// ignore_for_file: comment_references, constant_identifier_names, '
        'lines_longer_than_80_chars, unintended_html_in_doc_comment '
        "(names and docs from CopilotKit's catalog)",
      )
      ..writeln()
      ..writeln("import 'package:a2ui_core/a2ui_core.dart';")
      ..writeln("import 'package:a2ui_flutter/a2ui_flutter.dart';")
      ..writeln();
    final sortedEnums = enums.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final e in sortedEnums) {
      _writeEnum(out, e);
    }
    out
      ..writeln('/// The values of every enum above, for tests that check each')
      ..writeln('/// value is handled.')
      ..writeln('const List<List<Enum>> propEnumValues = [');
    for (final e in sortedEnums) {
      out.writeln('  ${e.name}.values,');
    }
    out
      ..writeln('];')
      ..writeln();
    components.forEach((name, schema) => _writeView(out, name, schema));
    return out.toString();
  }

  /// Every use of each enum value set anywhere in the document, nested ones
  /// included, so that a set shared only through a nested prop still needs a
  /// shared name.
  Map<String, List<String>> _allEnumUses() {
    final uses = <String, List<String>>{};
    void walk(String where, Object? node) {
      if (node is Map) {
        final values = node['enum'];
        if (node['type'] == 'string' && values is List) {
          uses.putIfAbsent(values.join('|'), () => []).add(where);
        }
        node.forEach((key, value) {
          if (key == 'properties' && value is Map) {
            value.forEach((p, s) => walk('$where.$p', s));
          } else if (key == 'items') {
            walk('$where[]', value);
          } else if (value is List) {
            for (final item in value) {
              walk(where, item);
            }
          }
        });
      }
    }

    components.forEach(walk);
    return uses;
  }

  Iterable<_Prop> _props(Map<String, Object?> schema) sync* {
    final props = (schema['properties']! as Map<String, Object?>)
        .cast<String, Map<String, Object?>>();
    for (final entry in props.entries) {
      if (entry.key == 'component') continue;
      yield _Prop(entry.key, entry.value);
    }
  }

  _Shape _shapeOf(Map<String, Object?> schema) {
    final ref = schema[r'$ref'];
    if (ref is String) {
      if (ref.endsWith('/ChildList')) return const _Shape(_Kind.childList);
      if (ref.endsWith('/ComponentId')) return const _Shape(_Kind.componentId);
      if (ref.endsWith('/Action')) return const _Shape(_Kind.action);
      return const _Shape(_Kind.any);
    }
    final anyOf = schema['anyOf'];
    if (anyOf is List) {
      final alternatives = [
        for (final alt in anyOf.cast<Map<String, Object?>>())
          if (alt[r'$ref'] != _dataBinding && alt[r'$ref'] != _functionCall)
            alt,
      ];
      if (alternatives.length == 1) return _shapeOf(alternatives.single);
      return const _Shape(_Kind.any);
    }
    final type = schema['type'];
    if (type is List) {
      // "string or number" is text that may be a number; "number or
      // string" is a length or a count.
      return type.first == 'string'
          ? const _Shape(_Kind.text)
          : const _Shape(_Kind.any);
    }
    switch (type) {
      case 'string':
        final values = schema['enum'];
        if (values is List) {
          return _Shape(_Kind.enumeration, values: values.cast<String>());
        }
        return const _Shape(_Kind.string);
      case 'number':
      case 'integer':
        return const _Shape(_Kind.number);
      case 'boolean':
        return const _Shape(_Kind.boolean);
      case 'array':
        return const _Shape(_Kind.list);
      case 'object':
        return const _Shape(_Kind.map);
    }
    return const _Shape(_Kind.any);
  }

  void _writeEnum(StringBuffer out, _Enum e) {
    final uses = e.uses.map((u) => '`$u`').join(', ');
    out
      ..write(_docComment('The values of $uses.'))
      ..writeln('enum ${e.name} {');
    for (var i = 0; i < e.values.length; i++) {
      final wire = e.values[i];
      out
        ..writeln('  /// `"$wire"`.')
        ..writeln(
          "  ${enumValueName(wire)}('$wire')"
          '${i == e.values.length - 1 ? ';' : ','}',
        );
    }
    out
      ..writeln()
      ..writeln('  const ${e.name}(this.wire);')
      ..writeln()
      ..writeln('  /// The value as A2UI writes it.')
      ..writeln('  final String wire;')
      ..writeln()
      ..writeln(
        '  /// The value whose [wire] is [value], or null when [value] is '
        'none of them.',
      )
      ..writeln('  static ${e.name}? fromWire(Object? value) {')
      ..writeln('    for (final candidate in values) {')
      ..writeln('      if (candidate.wire == value) return candidate;')
      ..writeln('    }')
      ..writeln('    return null;')
      ..writeln('  }')
      ..writeln('}')
      ..writeln();
  }

  void _writeView(
    StringBuffer out,
    String component,
    Map<String, Object?> schema,
  ) {
    final viewName = '${component}Props';
    final required = (schema['required'] as List? ?? const []).toSet();
    out
      ..write(_docComment('The props of a `$component` node, typed.'))
      ..writeln('///')
      ..write(
        _docComment(_escapeBrackets(schema['description'] as String? ?? '')),
      )
      ..writeln('extension type const $viewName(ComponentProps raw) {');
    for (final prop in _props(schema)) {
      if (_forbiddenGetters.contains(prop.name) ||
          _reserved.contains(prop.name)) {
        throw StateError('$component.${prop.name} cannot be a getter name.');
      }
      final shape = _shapeOf(prop.schema);
      final description = prop.schema['description'] as String?;
      final def = describedDefault(description);
      final doc = StringBuffer('`${prop.name}`');
      if (required.contains(prop.name)) doc.write(' (required)');
      final text = description == null
          ? _genericDoc(shape.kind)
          : _escapeBrackets(description);
      doc.write(text == null ? '.' : ': $text');
      if (text != null && !text.trim().endsWith('.')) doc.write('.');
      out
        ..writeln()
        ..write(_docComment(doc.toString(), indent: '  '))
        ..writeln('  ${_getter(component, prop.name, shape, def)}');
    }
    out
      ..writeln('}')
      ..writeln();
  }

  String? _genericDoc(_Kind kind) => switch (kind) {
    _Kind.childList => 'the child nodes, in order',
    _Kind.componentId => 'the child node',
    _Kind.action => 'the action to run',
    _ => null,
  };

  String _getter(String component, String name, _Shape shape, Object? def) {
    final key = "'$name'";
    switch (shape.kind) {
      case _Kind.childList:
        return 'List<ComponentNode<ComponentImplementation>> get $name => '
            'raw.children($key);';
      case _Kind.componentId:
        return 'ComponentNode<ComponentImplementation>? get $name => '
            'raw.child($key);';
      case _Kind.action:
        return 'NodeAction? get $name => raw.action($key);';
      case _Kind.enumeration:
        final e = enums[shape.values.join('|')]!;
        if (def is String) {
          if (!e.values.contains(def)) {
            throw StateError('$component.$name defaults to "$def", no value.');
          }
          return '${e.name} get $name => '
              '${e.name}.fromWire(raw.value($key)) ?? '
              '${e.name}.${enumValueName(def)};';
        }
        return '${e.name}? get $name => ${e.name}.fromWire(raw.value($key));';
      case _Kind.string:
        if (def is String) {
          return 'String get $name => raw.string($key) ?? '
              '${_dartString(def)};';
        }
        return 'String? get $name => raw.string($key);';
      case _Kind.text:
        return 'String? get $name => raw.string($key);';
      case _Kind.number:
        if (def is num) {
          return 'double get $name => raw.number($key) ?? ${def.toDouble()};';
        }
        return 'double? get $name => raw.number($key);';
      case _Kind.boolean:
        if (def is bool) {
          return 'bool get $name => raw.boolean($key) ?? $def;';
        }
        return 'bool? get $name => raw.boolean($key);';
      case _Kind.list:
        return 'List<Object?> get $name => raw.list($key);';
      case _Kind.map:
        return 'Map<String, Object?>? get $name => switch (raw.value($key)) '
            '{ final Map<Object?, Object?> m => m.cast<String, Object?>(), '
            '_ => null };';
      case _Kind.any:
        return 'Object? get $name => raw.value($key);';
    }
  }
}

String _dartString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}
