// A port of CopilotKit's `validateOperation`
// (packages/shared/src/generative-ui/validate-operation.ts, MIT, (c) Atai
// Barkai): the check its surface manager runs on each operation before it
// applies it (packages/core/src/generative-ui/surface-manager.ts:884-893),
// and the manager's reading of a literal null that a prop's schema refuses
// as an unset prop (`checkNodeProps`, surface-manager.ts:986-992;
// `withoutRejectedNulls`, shared catalog/schema.ts:75-90).

import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/src/catalog.dart' show a2uiKitCatalogDocument;
import 'package:a2ui_kit/src/validation/component_manifest.dart';

/// Refuses the operations CopilotKit refuses, before `a2ui_core` sees them.
///
/// CopilotKit checks every operation an agent sends against its catalog
/// and the surfaces that exist, and drops the ones that fail, with a
/// reason the agent gets back: an operation not of version `"1.0"`, a
/// component of an unknown type or with a prop its schema does not
/// declare, a component that is its own child, a template whose path has
/// an empty segment, a data prop that calls a function other than the
/// basic value functions (`openUrl` runs only from an event), a v0.9
/// `{"path": "/x"}` binding, a data write to a path with an empty segment,
/// a root write that is no object. `a2ui_core` takes many of those. Pass
/// the agent's messages through [filterMessages] first, before the id
/// normaliser, so the operation checked is the one the agent sent:
///
/// ```dart
/// final checks = A2uiOperationValidator(processor);
/// processor.processMessages(
///   owned.filterMessages(ids.normalizeMessages(checks.filterMessages(m))),
/// );
/// ```
///
/// A refused operation is not passed on. Its reason, CopilotKit's wording,
/// reaches the processor's `model.onError` (its surface's, when the surface
/// exists) as a `VALIDATION_FAILED` error, which the README's app sends to
/// the agent. The operations of one batch are checked in order, each
/// against the surfaces the earlier ones leave, as CopilotKit's surface
/// manager checks them as it applies them.
///
/// A literal `null` on a data prop whose schema takes no null is taken out
/// of the component, which CopilotKit reads as the prop being unset.
///
/// A `metadata.extensions` key CopilotKit takes and `a2ui_core` refuses
/// (`acme.track`, no UAX #31 identifier) passes: the `A2uiIdNormalizer`
/// after this rewrites it, its value kept (INV-260).
///
/// A `callRendererFunction` passes untouched: CopilotKit's surface manager
/// leaves it to the function runner (surface-manager.ts:868-869), and
/// `a2ui_core` answers it.
class A2uiOperationValidator {
  /// Checks the operations of [processor]'s agent against its catalogs and
  /// surfaces.
  A2uiOperationValidator(MessageProcessor<ComponentApi> processor)
    : _processor = processor;

  final MessageProcessor<ComponentApi> _processor;

  /// [messages] from the agent without the operations CopilotKit refuses,
  /// and with the literal nulls it reads as unset props taken out. Messages
  /// may be maps or JSON text, as the processor takes; what is neither a
  /// JSON object nor JSON text of one passes, for the processor to refuse.
  List<Object?> filterMessages(List<Object?> messages) {
    final batch = _Batch(_processor);
    return [
      for (final message in messages)
        if (_check(message, batch) case (:final Object? kept)) kept,
    ];
  }

  ({Object? kept})? _check(Object? message, _Batch batch) {
    final decoded = message is String ? _tryDecode(message) : message;
    if (decoded is! Map<Object?, Object?>) return (kept: message);
    final reason = _Validation(batch).operationProblem(decoded);
    if (reason != null) {
      _report(decoded, reason);
      return null;
    }
    batch.apply(decoded);
    return (kept: _forEngine(decoded, batch) ?? message);
  }

  void _report(Map<Object?, Object?> op, String reason) {
    final kind = operationKindOf(op);
    final surfaceId = switch (kind == null ? null : op[kind]) {
      {'surfaceId': final String id} => id,
      _ => '',
    };
    final error = A2uiRendererError(
      code: A2uiRendererError.validationFailedCode,
      surfaceId: surfaceId,
      path: kind == null ? '/' : '/$kind',
      message: reason,
    );
    final surface = surfaceId.isEmpty
        ? null
        : _processor.model.getSurface(surfaceId);
    if (surface != null) {
      unawaited(surface.dispatchError(error));
    } else {
      _processor.model.emitError(error);
    }
  }

  /// [op], a valid operation, as `a2ui_core` takes what CopilotKit takes,
  /// or null when it needs no change: each component without the literal
  /// nulls its schema refuses.
  static Map<String, Object?>? _forEngine(
    Map<Object?, Object?> op,
    _Batch batch,
  ) {
    final kind = operationKindOf(op);
    if (kind != 'createSurface' && kind != 'updateComponents') return null;
    final payload = op[kind];
    if (payload is! Map<Object?, Object?>) return null;
    final components = payload['components'];
    if (components is! List<Object?>) return null;
    final surfaceCatalog = switch (payload['surfaceId']) {
      final String id => batch.catalogOf(id),
      _ => null,
    };
    var changed = false;
    final kept = <Object?>[];
    for (final node in components) {
      final changedNode = node is Map<Object?, Object?>
          ? _nodeForEngine(node, batch, surfaceCatalog)
          : null;
      changed |= changedNode != null;
      kept.add(changedNode ?? node);
    }
    if (!changed) return null;
    return {
      for (final MapEntry(:key, :value) in op.entries) '$key': value,
      kind!: {
        for (final MapEntry(:key, :value) in payload.entries) '$key': value,
        'components': kept,
      },
    };
  }

  /// [node] as [_forEngine] gives it, or null when it needs no change.
  static Map<String, Object?>? _nodeForEngine(
    Map<Object?, Object?> node,
    _Batch batch,
    String? surfaceCatalog,
  ) {
    final type = node['component'];
    if (type is! String) return null;
    final manifest = batch.manifestFor(type, node['catalogId'], surfaceCatalog);
    if (manifest == null) return null;
    // A null the schema rejects is an unset prop (surface-manager.ts:
    // 986-992; shared catalog/schema.ts:75-90, a top-level null only).
    final rejected = {
      for (final MapEntry(:key, :value) in node.entries)
        if (value == null &&
            manifest.props.containsKey(key) &&
            !acceptsNull(manifest.props[key]))
          key,
    };
    if (rejected.isEmpty) return null;
    return {
      for (final MapEntry(:key, :value) in node.entries)
        if (!rejected.contains(key)) '$key': value,
    };
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}

/// The operation kinds of A2UI 1.0 that CopilotKit reads
/// (validate-operation.ts:25-31).
const List<String> _operationKinds = [
  'createSurface',
  'updateComponents',
  'updateDataModel',
  'deleteSurface',
  'callRendererFunction',
];

/// The one operation kind [op] holds, or null when it holds none or
/// several: CopilotKit's `getOperationKind` (validate-operation.ts:88-92).
String? operationKindOf(Map<Object?, Object?> op) {
  final kinds = [
    for (final kind in _operationKinds)
      if (op.containsKey(kind)) kind,
  ];
  return kinds.length == 1 ? kinds.single : null;
}

/// The surfaces as the operations of one batch leave them, each after the
/// ones before it.
class _Batch {
  _Batch(this.processor);

  final MessageProcessor<ComponentApi> processor;

  /// The surfaces created earlier in the batch, with the catalog each
  /// names.
  final Map<String, String?> _created = {};

  /// The surfaces deleted earlier in the batch.
  final Set<String> _deleted = {};

  /// The ids of the processor's catalogs: CopilotKit's `catalogIds`, the
  /// catalogs a `catalogId` may name.
  late final List<String> catalogIds = [
    for (final catalog in processor.catalogs) catalog.id,
  ];

  /// Whether the surface [id] exists before the next operation.
  bool knows(String id) =>
      !_deleted.contains(id) &&
      (_created.containsKey(id) || processor.model.getSurface(id) != null);

  /// The catalog the surface [id] names, or null for none.
  String? catalogOf(String id) => _created.containsKey(id)
      ? _created[id]
      : processor.model.getSurface(id)?.defaultCatalog?.id;

  /// The manifest of the component [type] in the catalog its own
  /// [componentCatalog] or its surface's [surfaceCatalog] names, else in
  /// the first catalog that declares it. CopilotKit has one manifest, of
  /// the catalog and its bases (validate-operation.ts:356), which these are
  /// together.
  ComponentManifest? manifestFor(
    String type,
    Object? componentCatalog,
    String? surfaceCatalog,
  ) {
    final named = componentCatalog is String
        ? componentCatalog
        : surfaceCatalog;
    for (final catalog in processor.catalogs) {
      if (catalog.id != named) continue;
      if (manifestOf(catalog, type) case final ComponentManifest manifest) {
        return manifest;
      }
    }
    for (final catalog in processor.catalogs) {
      if (manifestOf(catalog, type) case final ComponentManifest manifest) {
        return manifest;
      }
    }
    return null;
  }

  /// Records what the valid operation [op] does to the surfaces.
  void apply(Map<Object?, Object?> op) {
    switch (operationKindOf(op)) {
      case 'createSurface':
        if (op['createSurface'] case {'surfaceId': final String id}) {
          _deleted.remove(id);
          _created[id] = switch (op['createSurface']) {
            {'catalogId': final String catalogId} => catalogId,
            _ => null,
          };
        }
      case 'deleteSurface':
        if (op['deleteSurface'] case {'surfaceId': final String id}) {
          _created.remove(id);
          _deleted.add(id);
        }
    }
  }
}

/// CopilotKit's `A2UI_VERSION` (types.ts:2).
const String _a2uiVersion = '1.0';

/// The reason v0.9 bindings are refused (validate-operation.ts:74).
const String _v09PathReason =
    'bind data with {"@path": "/x"}, not {"path": "/x"}';

/// CopilotKit's built-in functions (`GENERATIVE_UI_FUNCTIONS`,
/// basic-functions.ts:213-215), by whether a prop may call them: every
/// built-in the catalog document exports (catalog-export.ts:82-91, which
/// adds no function the playground does not declare), a value function
/// unless it needs a user gesture (`isA2UIValueFunction`,
/// basic-functions.ts:232-241).
final Map<String, bool> _builtInFunctions = {
  if (a2uiKitCatalogDocument['functions'] case final Map<Object?, Object?> fns)
    for (final MapEntry(:key, :value) in fns.entries)
      '$key': switch (value) {
        {'requiresUserActivation': true} => false,
        _ => true,
      },
};

/// `@index`: CopilotKit's `A2UI_INDEX_FUNCTION` (basic-functions.ts:218).
const String _indexFunction = '@index';

/// CopilotKit's `isA2UIBasicFunction` (basic-functions.ts:221-226).
bool _isBasicFunction(String name) =>
    name == _indexFunction || _builtInFunctions.containsKey(name);

/// CopilotKit's `isA2UIValueFunction` (basic-functions.ts:232-241).
bool _isValueFunction(String name) =>
    name == _indexFunction || (_builtInFunctions[name] ?? false);

/// `@index` and the value functions, as CopilotKit's reasons name them
/// (`VALUE_FUNCTION_LIST`, validate-operation.ts:620-624).
final String _valueFunctionList = () {
  final names = [
    for (final MapEntry(:key, :value) in _builtInFunctions.entries)
      if (value) key,
  ];
  return '@index and the built-in functions (${names.join(', ')})';
}();

/// The segments CopilotKit refuses in a path (validate-operation.ts:282).
const Set<String> _forbiddenSegments = {
  '__proto__',
  'constructor',
  'prototype',
};

/// The keys of an envelope's `accessibility` (validate-operation.ts:416).
const List<String> _accessibilityKeys = [
  'label',
  'description',
  'live',
  'hidden',
];

/// The values of `accessibility.live` (validate-operation.ts:417).
const List<String> _liveValues = ['off', 'polite', 'assertive'];

/// `{ "@path": "/x" }`: CopilotKit's `isPathBinding`
/// (validate-operation.ts:106-112).
bool _isPathBinding(Object? value) =>
    value is Map<Object?, Object?> &&
    value['@path'] is String &&
    value.length == 1;

/// `{ "path": "/x" }`, the v0.9 binding: CopilotKit's `isV09PathBinding`
/// (validate-operation.ts:115-121).
bool _isV09PathBinding(Object? value) =>
    value is Map<Object?, Object?> &&
    value['path'] is String &&
    value.length == 1;

/// `{ "@call": "<name>" }`: CopilotKit's `isCallBinding`
/// (basic-functions.ts:244-254).
bool _isCallBinding(Object? value) =>
    value is Map<Object?, Object?> && value['@call'] is String;

/// `{ "@call": "@index" }` with at most a finite `offset`: CopilotKit's
/// `isIndexCall` (validate-operation.ts:127-142).
bool _isIndexCall(Object? value) {
  if (value is! Map<Object?, Object?> || value['@call'] != _indexFunction) {
    return false;
  }
  if (!value.keys.every((key) => key == '@call' || key == 'args')) {
    return false;
  }
  if (!value.containsKey('args')) return true;
  final args = value['args'];
  if (args is! Map<Object?, Object?>) return false;
  if (!args.keys.every((key) => key == 'offset')) return false;
  if (!args.containsKey('offset')) return true;
  final offset = args['offset'];
  return offset is num && offset.isFinite;
}

/// The checks of one operation against the surfaces of [batch].
class _Validation {
  _Validation(this.batch);

  final _Batch batch;

  /// Why CopilotKit refuses [op], or null when it takes it:
  /// `validateOperation` (validate-operation.ts:169-216).
  String? operationProblem(Map<Object?, Object?> op) {
    final version = op['version'];
    if (version != _a2uiVersion) {
      return version is String
          ? 'unsupported version "$version"; use "$_a2uiVersion"'
          : 'operation needs "version":"$_a2uiVersion"';
    }
    final kind = operationKindOf(op);
    if (kind == null) {
      return 'operation must contain exactly one of '
          '${_operationKinds.join(', ')}';
    }
    // The function runner checks it, not the surface manager
    // (surface-manager.ts:868-869); a2ui_core answers it.
    if (kind == 'callRendererFunction') return null;
    final payload = op[kind];
    final surfaceId = switch (payload) {
      {'surfaceId': final String id} when id.isNotEmpty => id,
      _ => null,
    };
    if (payload is! Map<Object?, Object?> || surfaceId == null) {
      return '$kind.surfaceId is required';
    }
    if (kind == 'createSurface') {
      return _createSurfaceProblem(payload, surfaceId);
    }
    if (!batch.knows(surfaceId)) {
      return 'surface "$surfaceId" does not exist; send createSurface first';
    }
    return switch (kind) {
      'updateDataModel' => _dataModelUpdateProblem(payload),
      'updateComponents' => _componentsProblem(
        payload['components'],
        'updateComponents.components',
        surfaceCatalog: batch.catalogOf(surfaceId),
      ),
      _ => null,
    };
  }

  /// CopilotKit's `catalogProblem` (validate-operation.ts:225-236): a
  /// `catalogId` that is [present] names one of the processor's catalogs.
  String? _catalogProblem(Object? catalogId, {required bool present}) {
    final ids = batch.catalogIds;
    if (!present || (catalogId is String && ids.contains(catalogId))) {
      return null;
    }
    final names = ids.map((id) => '"$id"').join(', ');
    final use = ids.length == 1 ? names : 'one of: $names';
    return 'unknown catalog "${_jsString(catalogId)}"; leave out catalogId or '
        'use $use';
  }

  /// CopilotKit's `validateCreateSurface` (validate-operation.ts:238-259).
  /// The `createdSurfaces` bookkeeping (a surface id used once for the
  /// life of the page) is CopilotKit's manager's, not ported.
  String? _createSurfaceProblem(
    Map<Object?, Object?> payload,
    String surfaceId,
  ) {
    if (batch.knows(surfaceId)) return 'surface "$surfaceId" already exists';
    final catalogReason = _catalogProblem(
      payload['catalogId'],
      present: payload.containsKey('catalogId'),
    );
    if (catalogReason != null) return catalogReason;
    if (payload.containsKey('dataModel') &&
        payload['dataModel'] is! Map<Object?, Object?>) {
      return 'createSurface.dataModel must be a JSON object';
    }
    if (!payload.containsKey('components')) return null;
    return _componentsProblem(
      payload['components'],
      'createSurface.components',
      surfaceCatalog: switch (payload['catalogId']) {
        final String id => id,
        _ => null,
      },
    );
  }

  /// CopilotKit's `validateDataModelUpdate` (validate-operation.ts:288-307).
  String? _dataModelUpdateProblem(Map<Object?, Object?> payload) {
    if (!payload.containsKey('value')) {
      return 'updateDataModel.value is required; use "value":null to delete';
    }
    final path = payload['path'] ?? '/';
    if (path is! String || !path.startsWith('/')) {
      return 'updateDataModel.path must be an absolute JSON pointer';
    }
    if (path == '/') {
      // Paths such as "/items" point into the root, so the root must be
      // an object.
      return payload['value'] is Map<Object?, Object?>
          ? null
          : 'a root updateDataModel value must be a JSON object';
    }
    return _pathProblem(path, 'updateDataModel.path');
  }

  /// CopilotKit's `pathProblem` (validate-operation.ts:313-325): the
  /// segments of an absolute JSON pointer or of a path relative to a
  /// template item.
  static String? _pathProblem(String path, String label) {
    final relative = path.startsWith('/') ? path.substring(1) : path;
    final segments = relative.split('/');
    if (segments.any((segment) => segment.isEmpty)) {
      return '$label must not contain empty segments';
    }
    for (final segment in segments) {
      final decoded = segment.replaceAllMapped(
        RegExp('~([01])'),
        (match) => match[1] == '1' ? '/' : '~',
      );
      if (_forbiddenSegments.contains(decoded)) {
        return 'path segment "$decoded" is not allowed in $label';
      }
    }
    return null;
  }

  /// CopilotKit's `validateComponents` (validate-operation.ts:327-348).
  String? _componentsProblem(
    Object? components,
    String label, {
    required String? surfaceCatalog,
  }) {
    if (components is! List<Object?> || components.isEmpty) {
      return '$label must be a non-empty array';
    }
    final ids = <String>{};
    for (final node in components) {
      if (node is! Map<Object?, Object?>) {
        return 'component must be a JSON object';
      }
      final id = node['id'];
      if (id is! String || id.isEmpty) return 'id is required';
      final reason = _nodeProblem(node, id, surfaceCatalog);
      if (reason != null) return 'component "$id": $reason';
      if (!ids.add(id)) return 'component "$id" appears twice in one update';
    }
    return null;
  }

  /// CopilotKit's `nodeProblem` (validate-operation.ts:350-414). The
  /// targets' component lists (`allowedComponents`) are CopilotKit's
  /// manager's, not ported.
  String? _nodeProblem(
    Map<Object?, Object?> node,
    String id,
    String? surfaceCatalog,
  ) {
    final type = node['component'];
    if (type is! String) return 'component type is required';
    final entry = batch.manifestFor(type, node['catalogId'], surfaceCatalog);
    if (entry == null) return 'unknown component "$type"';
    for (final MapEntry(:key, :value) in node.entries) {
      if (key == 'id' || key == 'component') continue;
      if (key == 'catalogId') {
        final reason = _catalogProblem(value, present: true);
        if (reason != null) return '$key: $reason';
        continue;
      }
      if (key == 'metadata') {
        final isMetadata =
            value is Map<Object?, Object?> &&
            (!value.containsKey('extensions') ||
                value['extensions'] is Map<Object?, Object?>);
        if (!isMetadata) return 'metadata must be { "extensions": { ... } }';
        continue;
      }
      if (key == 'accessibility') {
        final reason = _accessibilityProblem(value);
        if (reason != null) return '$key: $reason';
        continue;
      }
      if (entry.events.contains(key)) {
        final reason = _actionBindingProblem(value);
        if (reason != null) return '$key: $reason';
        continue;
      }
      if (entry.slots[key] case final SlotKind slot) {
        final reason = _slotProblem(value, slot, id);
        if (reason != null) return '$key: $reason';
        continue;
      }
      if (!entry.props.containsKey(key)) return 'unknown prop "$key"';
      if (_isV09PathBinding(value)) return '$key: $_v09PathReason';
      final call = _forbiddenCall(value, allowValueFunctions: true);
      if (call != null) {
        return '$key: $call; a data prop can call only $_valueFunctionList';
      }
    }
    for (final ref in entry.childRefs) {
      final reason = _childRefProblem(node, ref, id);
      if (reason != null) return reason;
    }
    for (final name in entry.required) {
      if (!node.containsKey(name)) return 'missing required prop "$name"';
    }
    return null;
  }

  /// CopilotKit's `accessibilityProblem` (validate-operation.ts:424-449).
  static String? _accessibilityProblem(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return 'must be { "label": "...", "description": "...", "live": '
          '"polite", "hidden": false }';
    }
    for (final MapEntry(:key, value: field) in value.entries) {
      if (!_accessibilityKeys.contains(key)) return 'unknown key "$key"';
      if (_isV09PathBinding(field)) return '$key: $_v09PathReason';
      if (_isPathBinding(field) || _isCallBinding(field)) {
        final call = _forbiddenCall(field, allowValueFunctions: true);
        if (call != null) return '$key: $call';
        continue;
      }
      if (key == 'live') {
        if (field is! String || !_liveValues.contains(field)) {
          return 'live must be one of ${_liveValues.join(', ')}';
        }
      } else if (key == 'hidden') {
        if (field is! bool) return 'hidden must be a boolean';
      } else if (field is! String) {
        return '$key must be a string';
      }
    }
    return null;
  }

  /// CopilotKit's `actionBindingProblem` (validate-operation.ts:451-466).
  String? _actionBindingProblem(Object? value) {
    if (value is! Map<Object?, Object?>) return 'must be an action object';
    final keys = value.keys.toList();
    final isOneAction =
        keys.length == 1 && (keys[0] == 'functionCall' || keys[0] == 'event');
    if (!isOneAction) {
      return 'must be { "event": ... } or { "functionCall": ... }';
    }
    if (keys[0] == 'functionCall') {
      return _functionCallProblem(value['functionCall'], 'functionCall');
    }
    return _eventProblem(value['event']);
  }

  /// CopilotKit's `functionCallProblem` (validate-operation.ts:472-521),
  /// as its surface manager calls it: with no list of app functions, so a
  /// function is not refused by its name (the dispatcher checks that when
  /// the call runs).
  String? _functionCallProblem(Object? call, String label) {
    if (call is! Map<Object?, Object?>) {
      return '$label must be { "@call": "<function>", "args": { ... } }';
    }
    final name = call['@call'];
    if (name is! String || name.isEmpty) {
      return call['call'] is String
          ? '$label names the function with "@call", not "call"'
          : '$label["@call"] must be a function name';
    }
    final args = call['args'];
    if (call.containsKey('args') && args is! Map<Object?, Object?>) {
      return '$label.args must be an object';
    }
    final catalogReason = _catalogProblem(
      call['catalogId'],
      present: call.containsKey('catalogId'),
    );
    if (catalogReason != null) return '$label: $catalogReason';
    if (args is Map<Object?, Object?>) {
      for (final MapEntry(:key, value: arg) in args.entries) {
        if (_isV09PathBinding(arg)) return '$label.args.$key: $_v09PathReason';
      }
    }
    return null;
  }

  /// CopilotKit's `eventProblem` (validate-operation.ts:545-576).
  static String? _eventProblem(Object? event) {
    final name = event is Map<Object?, Object?> ? event['name'] : null;
    if (event is! Map<Object?, Object?> || name is! String || name.isEmpty) {
      return 'event.name is required';
    }
    final userMessage = event['userMessage'];
    final isUserMessage =
        !event.containsKey('userMessage') ||
        userMessage is String ||
        _isPathBinding(userMessage) ||
        (userMessage is Map<Object?, Object?> &&
            userMessage['@call'] is String &&
            _forbiddenCall(userMessage, allowValueFunctions: true) == null);
    if (!isUserMessage) {
      return _isV09PathBinding(userMessage)
          ? 'event.userMessage: $_v09PathReason'
          : 'event.userMessage must be a string, {"@path": "/x"} or a '
                'function value';
    }
    if (!event.containsKey('context')) return null;
    final context = event['context'];
    if (context is! Map<Object?, Object?>) {
      return 'event.context must be an object';
    }
    for (final MapEntry(:key, value: entry) in context.entries) {
      if (_isV09PathBinding(entry)) {
        return 'event.context.$key: $_v09PathReason';
      }
      final call = _forbiddenCall(entry, allowValueFunctions: true);
      if (call != null) {
        return 'event.context.$key: $call; a context value can call only '
            '$_valueFunctionList';
      }
    }
    return null;
  }

  /// CopilotKit's `slotProblem` (validate-operation.ts:578-600).
  static String? _slotProblem(Object? value, SlotKind kind, String ownId) {
    if (value is Map<Object?, Object?> && value.containsKey('componentId')) {
      return kind == SlotKind.single
          ? 'a template { "componentId", "path" } is only allowed in a '
                '"multiple" slot'
          : _templateProblem(value, ownId);
    }
    if (kind == SlotKind.multiple && value is! List<Object?>) {
      return 'must be an array of component ids or a template { '
          '"componentId", "path" }';
    }
    final ids = kind == SlotKind.multiple && value is List<Object?>
        ? value
        : [value];
    for (final id in ids) {
      if (id is! String || id.isEmpty) {
        return 'must reference component ids (strings)';
      }
      if (id == ownId) return 'a component cannot be its own child';
    }
    return null;
  }

  /// CopilotKit's `templateProblem` (validate-operation.ts:602-618).
  static String? _templateProblem(
    Map<Object?, Object?> template,
    String ownId,
  ) {
    final hasOnlyTemplateKeys = template.keys.every(
      (key) => key == 'componentId' || key == 'path',
    );
    if (!hasOnlyTemplateKeys) {
      return 'a template takes only "componentId" and "path"';
    }
    final componentId = template['componentId'];
    final path = template['path'];
    if (componentId is! String || componentId.isEmpty) {
      return 'template componentId must be a component id';
    }
    if (componentId == ownId) return 'a component cannot be its own child';
    if (path is! String || path.isEmpty) {
      return 'template path must be a JSON pointer or a relative path';
    }
    return _pathProblem(path, 'template path');
  }

  /// The reason for the first function call in [value] that a data value
  /// may not make, at any depth, or null: CopilotKit's `findForbiddenCall`
  /// (validate-operation.ts:626-672). A data value may call `@index` and,
  /// with [allowValueFunctions], the basic functions that need no user
  /// gesture. An app function, `openUrl` or an event binding is not a
  /// value.
  static String? _forbiddenCall(
    Object? value, {
    required bool allowValueFunctions,
  }) {
    if (value is List<Object?>) {
      for (final item in value) {
        final reason = _forbiddenCall(
          item,
          allowValueFunctions: allowValueFunctions,
        );
        if (reason != null) return reason;
      }
      return null;
    }
    if (value is! Map<Object?, Object?>) return null;
    if (_isIndexCall(value)) return null;
    if (value['@call'] == _indexFunction) return '@index takes only an offset';
    if (value['call'] is String) {
      return 'name the function with "@call", not "call"';
    }
    if (value.containsKey('functionCall')) {
      return 'an event binding is not a value';
    }
    final name = value['@call'];
    if (name is String) {
      if (!allowValueFunctions || !_isValueFunction(name)) {
        return _isBasicFunction(name)
            ? '"$name" runs only from an event'
            : '"$name" is not a basic function';
      }
      final args = value['args'];
      if (value.containsKey('args') && args is! Map<Object?, Object?>) {
        return 'the args of "$name" must be an object';
      }
      return args == null
          ? null
          : _forbiddenCall(args, allowValueFunctions: allowValueFunctions);
    }
    for (final item in value.values) {
      final reason = _forbiddenCall(
        item,
        allowValueFunctions: allowValueFunctions,
      );
      if (reason != null) return reason;
    }
    return null;
  }

  /// CopilotKit's `childRefProblem` (validate-operation.ts:691-723): the
  /// component ids at one reference nested in a node's props. A missing
  /// key is fine (the required props are checked apart).
  static String? _childRefProblem(
    Map<Object?, Object?> node,
    ChildRefPath ref,
    String ownId,
  ) {
    final label = ref.path.where((step) => step != '*').join('.');
    bool isDynamic(Object? value) =>
        _isPathBinding(value) ||
        (value is Map<Object?, Object?> && value.containsKey('@call'));
    String? visit(Object? value, List<String> steps) {
      // A bound or computed value, at the reference or above it, is known
      // only at render.
      if (isDynamic(value)) return null;
      if (steps.isEmpty) {
        final reason = _slotProblem(value, ref.kind, ownId);
        return reason == null ? null : '$label: $reason';
      }
      final head = steps.first;
      final rest = steps.sublist(1);
      if (head == '*') {
        if (value is! List<Object?>) return null;
        for (final item in value) {
          final reason = visit(item, rest);
          if (reason != null) return reason;
        }
        return null;
      }
      if (value is! Map<Object?, Object?> || !value.containsKey(head)) {
        return null;
      }
      return visit(value[head], rest);
    }

    return visit(node, ref.path);
  }
}

/// [value] as JavaScript's `String(value)` writes a JSON value, for a
/// reason that quotes it.
String _jsString(Object? value) => switch (value) {
  final Map<Object?, Object?> _ => '[object Object]',
  final List<Object?> list => list.map(_jsString).join(','),
  final double d when d.isFinite && d == d.truncateToDouble() => '${d.toInt()}',
  _ => '$value',
};

// PORT STATUS: confidence=medium todos=0 upstream=packages/shared/src/generative-ui/validate-operation.ts, packages/core/src/generative-ui/surface-manager.ts
