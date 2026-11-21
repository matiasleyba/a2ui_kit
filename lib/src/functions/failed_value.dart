// What makes a component's props invalid when a function value in them
// cannot be computed: a port of the problem CopilotKit's renderer finds
// (packages/react-core/src/v2/generative-ui/SurfaceView.tsx:457-538,
// `useModelDataProps`: each prop resolved on its own with
// `tryResolveDynamicValue`, the first that fails giving
// `"<prop>: <message>"`; MIT, (c) Atai Barkai). The invalid-props fallback
// that shows it, in the component's place, is the node guard's.
//
// a2ui_core's binder has resolved the props already, a failed function to
// null; this asks the same calls again, in a quiet context that keeps the
// first error, so the guard can tell a failure from a null value.
//
// The node guard (components/node_guard.dart) shows this problem as the
// invalid-props fallback with its report. TODO(port): a2ui_core's binder
// reports the failed call itself first (component_context.dart:54-55), which
// upstream does not (INV-205; dynamic-values.test.tsx:130, :203, queued in
// dynamic_values_test.dart).

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/src/document/behaviour.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';

/// The keys of a component's envelope, which are not props
/// (packages/shared/src/generative-ui/types.ts:68-72,
/// `A2UI_COMPONENT_ENVELOPE_KEYS`). a2ui_core keeps `catalogId` and
/// `metadata` out of a component's properties already; the accessibility
/// envelope's fields are resolved apart upstream, and a field that fails
/// names nothing and is not the component's fault (SurfaceView.tsx:530-534).
const Set<String> _envelopeKeys = {'catalogId', 'accessibility', 'metadata'};

/// [key] without the `@` a2ui_core may keep a reserved prop under
/// (`@checks`, `@accessibility`).
String _bare(String key) =>
    key.startsWith('@') && !key.startsWith('@@') ? key.substring(1) : key;

/// The problem of [node]'s props when a function value in them cannot be
/// computed now, as CopilotKit's renderer words it (`"text: value must be a
/// number"`), or null when every one can.
///
/// The props are taken in their order, the events and the envelope left
/// out, and so is `@index` outside a template, which is undefined upstream
/// (resolve.ts:158-160) and not a failure. Each function call the agent
/// wrote, outside an event binding, is evaluated as the binder evaluates it;
/// the first that fails gives the problem, with the message of the call that
/// failed first (an arg's own failure, not the call it was passed to).
// PERF(port): every call of the props is evaluated a second time per build
// of a node that has one; a binder that kept its failures would spare it.
String? failedFunctionValueOf(KitNode node) {
  final context = node.context;
  if (context == null) return null;
  final events = eventArguments[node.type]?.keys.toSet() ?? const <String>{};
  final units = [
    for (final MapEntry(:key, :value)
        in context.componentModel.properties.entries)
      if (!_envelopeKeys.contains(_bare(key)) && !events.contains(_bare(key)))
        if (_callsIn(value).toList() case final calls when calls.isNotEmpty)
          (_bare(key), calls),
  ];
  if (units.isEmpty) return null;
  final data = context.dataContext;
  A2uiExpressionError? failure;
  final quiet = ComponentContext(
    context.surface,
    context.componentModel,
    basePath: data.path,
    index: data.index,
    parentDataContext: data.parent,
    onError: (error) => failure ??= error,
    onMissingData: (_) {},
  ).dataContext;
  for (final (key, calls) in units) {
    for (final call in calls) {
      if (call['@call'] == '@index' && quiet.index == null) continue;
      failure = null;
      try {
        quiet.resolveDynamicValue(call);
      } on A2uiError catch (error) {
        // A call a2ui_core cannot read (its args not an object) throws
        // rather than reports.
        return '$key: ${error.message}';
      }
      if (failure case final error?) return '$key: ${error.message}';
    }
  }
  return null;
}

/// The function calls in [value], in the order CopilotKit's `walk` reaches
/// them (resolve.ts:105-146): a call's own args are its to evaluate, and an
/// event binding is not a value.
Iterable<Map<Object?, Object?>> _callsIn(Object? value) sync* {
  if (value is List) {
    for (final item in value) {
      yield* _callsIn(item);
    }
    return;
  }
  if (value is! Map) return;
  if (value['@call'] is String) {
    yield value;
    return;
  }
  if (value.length == 1 &&
      (value['functionCall'] is Map || value['event'] is Map)) {
    return;
  }
  for (final item in value.values) {
    yield* _callsIn(item);
  }
}

// PORT STATUS: confidence=medium todos=1 upstream=packages/react-core/src/v2/generative-ui/SurfaceView.tsx
