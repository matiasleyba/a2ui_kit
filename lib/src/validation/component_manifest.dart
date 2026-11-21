// The component manifest CopilotKit's validators read
// (`GenerativeUIComponentManifest`, packages/shared/src/generative-ui/
// types.ts:173-189: a props schema, the events and the slots), recovered
// from the component schemas of an exported catalog, and the child
// references inside the props (`collectChildRefs`, child-refs.ts:82-123).
// MIT, (c) Atai Barkai.

import 'package:a2ui_core/a2ui_core.dart';

/// The kind of a component reference: one id, or a list of ids or a
/// template (CopilotKit's `ChildRefKind`, child-refs.ts:22).
enum SlotKind {
  /// `common_types.json#/$defs/ComponentId`: one component id.
  single,

  /// `common_types.json#/$defs/ChildList`: ids, or a template.
  multiple,
}

/// One component reference inside the props, by its keys from the props
/// root (`*` for the items of a list): CopilotKit's `ChildRef`
/// (child-refs.ts:25-34).
typedef ChildRefPath = ({List<String> path, SlotKind kind});

/// What CopilotKit's `validateOperation` and render check know of one
/// component: its data props (each by its literal schema), events, slots,
/// required props and the child references nested in its props.
class ComponentManifest {
  ComponentManifest._({
    required this.props,
    required this.events,
    required this.slots,
    required this.required,
    required this.childRefs,
  });

  /// The manifest of a component whose exported schema is [schema].
  ///
  /// The export writes a slot as a `ComponentId` or `ChildList` reference
  /// and an event as an `Action` reference (catalog-export.ts:177-194), and
  /// every other prop as its literal schema, a data binding or a function
  /// call, at every depth (`dynamicProp`, catalog-export.ts:283-292). The
  /// data props keep their literal schemas, which is what the props schema
  /// of the manifest says.
  ///
  /// A top-level reference is read as a slot. The playground's own
  /// components declare theirs with `childList()` in the props instead
  /// (definitions/layout.ts:17), which CopilotKit tells apart only for a
  /// bound or computed value there; a2ui_core's `ChildList` and
  /// `ComponentId` schemas refuse such a value either way.
  factory ComponentManifest.fromSchema(Map<Object?, Object?> schema) {
    final props = <String, Object?>{};
    final events = <String>{};
    final slots = <String, SlotKind>{};
    if (schema['properties'] case final Map<Object?, Object?> properties) {
      for (final MapEntry(:key, :value) in properties.entries) {
        if (key is! String || key == 'component') continue;
        if (_refName(value) == 'Action') {
          events.add(key);
        } else if (_slotKind(value) case final SlotKind kind) {
          slots[key] = kind;
        } else {
          props[key] = literalSchemaOf(value);
        }
      }
    }
    final required = [
      if (schema['required'] case final List<Object?> names)
        for (final name in names)
          if (name is String && name != 'component') name,
    ];
    return ComponentManifest._(
      props: props,
      events: events,
      slots: slots,
      required: required,
      childRefs: collectChildRefs({'type': 'object', 'properties': props}),
    );
  }

  /// The data props, each by its literal schema, in the schema's order.
  final Map<String, Object?> props;

  /// The event props.
  final Set<String> events;

  /// The slots, by name.
  final Map<String, SlotKind> slots;

  /// The required data props.
  final List<String> required;

  /// The component references nested in the data props (Tabs' `tabs[].
  /// child`).
  final List<ChildRefPath> childRefs;

  /// The props schema the render check validates resolved values with: an
  /// object of the data props and their literal schemas, requiring the
  /// required ones.
  Map<String, Object?> get propsSchema => {
    'type': 'object',
    'properties': props,
    if (required.isNotEmpty) 'required': required,
  };
}

final Expando<Map<String, ComponentManifest?>> _manifests = Expando(
  'a2ui_kit component manifests',
);

/// The manifest of the component [type] of [catalog], or null when the
/// catalog declares no such component.
ComponentManifest? manifestOf(
  Catalog<ComponentApi, FunctionApi> catalog,
  String type,
) {
  final cache = _manifests[catalog] ??= {};
  return cache.putIfAbsent(type, () {
    final api = catalog.components[type];
    return api == null ? null : ComponentManifest.fromSchema(api.schema.value);
  });
}

/// The last segment of [schema]'s `common_types.json` reference, or null.
String? _refName(Object? schema) => switch (schema) {
  {r'$ref': final String ref} when ref.startsWith(_commonTypes) =>
    ref.substring(_commonTypes.length),
  _ => null,
};

const String _commonTypes = r'common_types.json#/$defs/';

/// The kind of the reference [schema] is, or null for a plain value:
/// CopilotKit's `childRefKind` (child-refs.ts:37-44).
SlotKind? _slotKind(Object? schema) => switch (_refName(schema)) {
  'ComponentId' => SlotKind.single,
  'ChildList' => SlotKind.multiple,
  _ => null,
};

/// [schema] as the props schema wrote it before the export made each value
/// dynamic: every `anyOf` of a value, a data binding and a function call is
/// its value's schema (catalog-export.ts:283-292, the inverse), at every
/// depth.
Object? literalSchemaOf(Object? schema) {
  if (schema is! Map<Object?, Object?>) return schema;
  if (schema['anyOf']
      case [final Object? literal, final Object? binding, final Object? call]
      when _refName(binding) == 'DataBinding' &&
          _refName(call) == 'FunctionCall') {
    return literalSchemaOf(literal);
  }
  Object? literalList(Object? value) => switch (value) {
    final List<Object?> list => [
      for (final item in list) literalSchemaOf(item),
    ],
    _ => literalSchemaOf(value),
  };
  return <String, Object?>{
    for (final MapEntry(:key, :value) in schema.entries)
      '$key': switch (key) {
        'properties' ||
        r'$defs' ||
        'definitions' when value is Map<Object?, Object?> => <String, Object?>{
          for (final entry in value.entries)
            '${entry.key}': literalSchemaOf(entry.value),
        },
        'items' ||
        'prefixItems' ||
        'anyOf' ||
        'oneOf' ||
        'allOf' => literalList(value),
        'additionalItems' || 'additionalProperties' => literalSchemaOf(value),
        _ => value,
      },
  };
}

/// Every component reference in the props schema [schema], with its path:
/// CopilotKit's `collectChildRefs` (child-refs.ts:82-123), which walks
/// `properties`, array `items` and the variants of `anyOf`, `oneOf` and
/// `allOf`. A union counts as a reference only when every variant is one
/// of the same kind.
List<ChildRefPath> collectChildRefs(Object? schema) {
  final refs = <ChildRefPath>[];
  final seen = <String>{};
  void add(List<String> path, SlotKind kind) {
    if (seen.add(path.join('\u0000'))) refs.add((path: path, kind: kind));
  }

  void visit(Object? node, List<String> path) {
    if (node is! Map<Object?, Object?>) return;
    final kind = _slotKind(node);
    if (kind != null) return add(path, kind);
    for (final list in [node['anyOf'], node['oneOf']]) {
      if (list is! List<Object?> || list.isEmpty) continue;
      final kinds = [for (final variant in list) _slotKind(variant)];
      final first = kinds.first;
      if (first != null && kinds.every((k) => k == first)) {
        add(path, first);
      } else if (kinds.every((k) => k == null)) {
        // Objects in a union: a nested reference counts only when every
        // variant has it at the same path with the same kind.
        final perVariant = [
          for (final variant in list) collectChildRefs(variant),
        ];
        String key(ChildRefPath ref) =>
            '${ref.kind.name}\u0000${ref.path.join('\u0000')}';
        for (final ref in perVariant.first) {
          if (perVariant.every((refs) => refs.any((r) => key(r) == key(ref)))) {
            add([...path, ...ref.path], ref.kind);
          }
        }
      }
    }
    if (node['allOf'] case final List<Object?> variants) {
      for (final variant in variants) {
        visit(variant, path);
      }
    }
    if (node['properties'] case final Map<Object?, Object?> properties) {
      for (final MapEntry(:key, :value) in properties.entries) {
        visit(value, [...path, '$key']);
      }
    }
    if (node['items'] case final Map<Object?, Object?> items) {
      visit(items, [...path, '*']);
    }
  }

  visit(schema, const []);
  return refs;
}

/// Whether a literal [schema] (a JSON Schema of one prop) takes `null`, so
/// a literal null on that prop is a value, not an unset prop. No prop of
/// CopilotKit's catalog document does (no `"type": "null"`), but one
/// written as any value (`{}`) would.
bool acceptsNull(Object? schema) {
  if (schema == true) return true;
  if (schema is! Map<Object?, Object?>) return false;
  if (schema.containsKey('const')) return schema['const'] == null;
  if (schema['enum'] case final List<Object?> values) {
    return values.contains(null);
  }
  if (schema['not'] != null || schema[r'$ref'] != null) return false;
  if (schema['allOf'] case final List<Object?> variants) {
    if (!variants.every(acceptsNull)) return false;
  }
  for (final key in const ['anyOf', 'oneOf']) {
    if (schema[key] case final List<Object?> variants) {
      if (!variants.any(acceptsNull)) return false;
    }
  }
  return switch (schema['type']) {
    null => true,
    final String type => type == 'null',
    final List<Object?> types => types.contains('null'),
    _ => false,
  };
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/shared/src/generative-ui/types.ts, packages/shared/src/generative-ui/child-refs.ts
