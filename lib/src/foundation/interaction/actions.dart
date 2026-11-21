import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';

/// Runs the action prop [key] of [node] with the event arguments [args], as
/// CopilotKit's `invokeBoundEvent` does: they go into an `{"event"}`
/// binding's context, or into a `{"functionCall"}` binding's args, and the
/// binding's own entries win.
///
/// `a2ui_core`'s action closures take no arguments, so the binding is
/// resolved and run here. Without [args] the plain closure runs.
Future<void> runActionWithArgs(
  KitNode node,
  ComponentProps props,
  String key,
  Map<String, Object?> args,
) async {
  final action = props.action(key);
  if (action == null) return;
  final context = node.context;
  final raw = context?.componentModel.properties[key];
  if (context == null || args.isEmpty || raw is! Map) {
    await action();
    return;
  }
  final call = raw['functionCall'];
  if (call is Map && context.dataContext.isFunctionCall(call)) {
    await _runFunctionCall(context, withCallArgs(call, args));
    return;
  }
  if (raw['event'] is! Map) {
    await action();
    return;
  }
  var failed = false;
  final resolved = await context.dataContext
      .withUserActivation()
      .resolveActionAsync(raw, onExpressionFailed: () => failed = true);
  if (resolved == null) {
    // The closure reports a malformed action; a failed expression has been
    // reported already.
    if (!failed) await action();
    return;
  }
  final event = Map<String, dynamic>.from(resolved['event'] as Map);
  final own = event['context'];
  event['context'] = <String, Object?>{
    ...args,
    if (own is Map)
      for (final entry in own.entries) '${entry.key}': entry.value,
  };
  await context.dispatchAction({...resolved, 'event': event});
}

/// The function [call] of an action with the event [args] spread into its
/// args, the call's own args winning: `{...componentArgs, ...args}` in
/// CopilotKit's `invokeBoundEvent`.
Map<String, dynamic> withCallArgs(
  Map<Object?, Object?> call,
  Map<String, Object?> args,
) {
  final own = call['args'];
  return {
    for (final entry in call.entries) '${entry.key}': entry.value,
    'args': <String, Object?>{
      ...args,
      if (own is Map)
        for (final entry in own.entries) '${entry.key}': entry.value,
    },
  };
}

/// Runs [call] from a user gesture, reporting a failure on the surface as
/// `a2ui_core`'s own action closure does.
Future<void> _runFunctionCall(
  ComponentContext context,
  Map<String, dynamic> call,
) async {
  try {
    await context.dataContext.withUserActivation().evaluateFunctionCall(call);
  } on Object catch (error) {
    if (error is A2uiRpcError && error.rpcCode == RpcErrorCode.cancelled) {
      return;
    }
    final functionCallId = error is A2uiRpcError ? error.functionCallId : null;
    await context.surface.dispatchError(
      A2uiRendererError(
        code: error is A2uiRpcError ? 'EXPRESSION_ERROR' : 'EXECUTION_ERROR',
        surfaceId: functionCallId == null ? context.surface.id : null,
        functionCallId: functionCallId,
        message:
            "Function '${call['@call'] ?? call['call']}' failed in "
            "component '${context.componentModel.id}': $error",
      ),
    );
  }
}

// PORT STATUS: confidence=high todos=0 upstream=packages/core/src/generative-ui/events.ts (invokeBoundEvent)
