// The render check of CopilotKit's SurfaceView: a node's data props, with
// their dynamic values resolved, are parsed with its props schema before it
// renders, and a node whose props fail shows the "invalid props" fallback
// instead (`useDataProps` and `checkModelProps`, packages/react-core/src/
// v2/generative-ui/SurfaceView.tsx:686-753; `formatIssues`, shared
// catalog/schema.ts:92-107). MIT, (c) Atai Barkai.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/src/validation/component_manifest.dart';

/// Why the resolved data props of [node] fail its props schema, as
/// CopilotKit's render check gives it (`"text: ..."`), or null when they
/// pass. [props] is the node's resolved props.
///
/// The props are the agent's (the component model's properties) with each
/// dynamic value replaced by what it resolved to; an unset prop is left
/// out, and so is a `null` the prop's schema refuses (CopilotKit reads it
/// as unset). The `checks` are left out: the controls read them from the
/// agent's rules as CopilotKit's `useChecks` does (`firstFailedCheck`), and
/// their resolved validation results are no JSON.
String? invalidPropsOf(
  ComponentNode<ComponentApi> node,
  Map<String, Object?> props,
) {
  final impl = node.impl;
  final context = node.context;
  if (impl == null || context == null) return null;
  final checker = _checkers[impl] ??= _PropsChecker(impl);
  return checker.problemOf(context.componentModel.properties, props);
}

final Expando<_PropsChecker> _checkers = Expando('a2ui_kit props checks');

/// The data props the render check leaves out (see [invalidPropsOf]).
const Set<String> _unchecked = {'checks'};

class _PropsChecker {
  _PropsChecker(ComponentApi api)
    : _name = api.name,
      _manifest = ComponentManifest.fromSchema(api.schema.value) {
    final props = {
      for (final MapEntry(:key, :value) in _manifest.props.entries)
        if (!_unchecked.contains(key)) key: value,
    };
    final required = [
      for (final name in _manifest.required)
        if (props.containsKey(name)) name,
    ];
    _validator = PayloadValidator<ComponentApi, FunctionApi>(
      catalog: Catalog.fromJson({
        'catalogId': 'a2ui-kit-props-check',
        'protocolVersion': '1.0',
        'components': {
          _name: {
            'type': 'object',
            'properties': {
              'component': {'const': _name},
              ...props,
            },
            'required': ['component', ...required],
          },
        },
        'functions': <String, Object?>{},
      }),
    );
    _checked = props;
  }

  final String _name;
  final ComponentManifest _manifest;
  late final PayloadValidator<ComponentApi, FunctionApi> _validator;
  late final Map<String, Object?> _checked;

  String? problemOf(Map<String, Object?> raw, Map<String, Object?> resolved) {
    final values = <String, Object?>{
      for (final key in _checked.keys)
        if (raw.containsKey(key)) key: _plain(raw[key], resolved[key]),
    };
    var problem = _problem(values);
    if (problem == null) return null;
    // A null the schema rejects is an unset prop: check again without it
    // (SurfaceView.tsx:700-707).
    final rejected = [
      for (final MapEntry(:key, :value) in values.entries)
        if (value == null && problem.paths.contains(key)) key,
    ];
    if (rejected.isNotEmpty) {
      rejected.forEach(values.remove);
      problem = _problem(values);
    }
    return problem?.text;
  }

  /// The issues of [values] against the props schema, or null for none.
  ({String text, Set<String> paths})? _problem(Map<String, Object?> values) {
    try {
      _validator.validateComponent({
        'id': 'node',
        'component': _name,
        ...values,
      });
      return null;
    } on A2uiValidationError catch (error) {
      final details = error.errors;
      if (details.isEmpty) return (text: error.message, paths: const {});
      final keys = <String>{};
      final issues = <String>[];
      for (final detail in details) {
        final steps = [
          for (final step in detail.path.split('/'))
            if (step.isNotEmpty)
              step.replaceAll('~1', '/').replaceAll('~0', '~'),
        ];
        if (steps.isNotEmpty) keys.add(steps.first);
        // `"a.b: message"`, a path-less issue under "props"
        // (shared catalog/schema.ts:92-107).
        final path = steps.isEmpty ? 'props' : steps.join('.');
        issues.add('$path: ${detail.message}');
      }
      return (text: issues.join('; '), paths: keys);
    }
  }
}

/// The value of a prop the agent wrote as [raw], with each dynamic value in
/// it replaced by what it resolved to in [resolved]: only the keys and
/// items the agent wrote (the binder fills in a null for a dynamic prop it
/// leaves out), and the agent's own ids where a child reference resolved
/// to a node.
Object? _plain(Object? raw, Object? resolved) {
  final value = resolved is ResolvedBinding<Object?>
      ? resolved.value
      : resolved;
  if (value is ComponentNode || (value is List && value.any(_isNode))) {
    return raw;
  }
  if (_isDynamic(raw)) return _unwrapped(value);
  return switch (raw) {
    final Map<Object?, Object?> map => <String, Object?>{
      for (final MapEntry(:key, value: item) in map.entries)
        '$key': _plain(item, value is Map ? value[key] : null),
    },
    final List<Object?> list => [
      for (var i = 0; i < list.length; i++)
        _plain(list[i], value is List && i < value.length ? value[i] : null),
    ],
    _ => raw,
  };
}

bool _isNode(Object? value) => value is ComponentNode;

/// Whether the agent wrote [raw] as a dynamic value: a data binding or a
/// function call.
bool _isDynamic(Object? raw) =>
    raw is Map<Object?, Object?> &&
    (raw['@path'] is String || raw['@call'] is String);

/// [value] with every binding inside it replaced by its value.
Object? _unwrapped(Object? value) => switch (value) {
  final ResolvedBinding<Object?> binding => _unwrapped(binding.value),
  final Map<Object?, Object?> map => <String, Object?>{
    for (final MapEntry(:key, value: item) in map.entries)
      '$key': _unwrapped(item),
  },
  final List<Object?> list => [for (final item in list) _unwrapped(item)],
  _ => value,
};

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/SurfaceView.tsx, packages/shared/src/generative-ui/catalog/schema.ts
