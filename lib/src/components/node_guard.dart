// What CopilotKit's SurfaceView does round every node it renders
// (packages/react-core/src/v2/generative-ui/SurfaceView.tsx,
// boundaries.tsx and host.tsx; MIT, (c) Atai Barkai): the render check of
// the resolved props, the boundary that catches a component that throws,
// the default fallback shown in their place and in place of a cyclic
// reference or an unknown type, and one copy of a child id a list repeats.

import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart'
    show Activatable;
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/functions/failed_value.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:a2ui_kit/src/validation/props_check.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// The code of the error a component that throws reports: CopilotKit's
/// `kind: "render"` (boundaries.tsx:401-406).
const String renderFailedCode = 'RENDER_FAILED';

/// The code of the error a component with invalid props reports:
/// CopilotKit's `kind: "props"` (SurfaceView.tsx:1110-1118).
const String invalidPropsCode = 'INVALID_PROPS';

/// Whether a container draws [child]: a resolved node, or the fallback in
/// place of a cyclic reference or an unknown type (SurfaceView.tsx:314-340).
/// A child that has not arrived draws nothing (`NodePlaceholder`).
bool isDrawnChild(KitNode child) =>
    !child.isPlaceholder ||
    child.state == NodeState.cyclic ||
    child.state == NodeState.unknownType;

/// What CopilotKit's render check finds wrong with [props] of [node], or
/// null when they pass: a function value in them that cannot be computed
/// ([failedFunctionValueOf]) first, then its resolved data props against
/// its props schema (SurfaceView.tsx:740-753).
String? nodeProblemOf(KitNode node, Map<String, Object?> props) =>
    failedFunctionValueOf(node) ?? invalidPropsOf(node, props);

/// Whether [node]'s props pass the render check [NodeGuard] makes
/// ([nodeProblemOf]; SurfaceView.tsx:740-760, :1095-1132). A container that
/// reads a child's props itself (a Table its sections, rows and cells)
/// takes such a child only when they pass; else it builds the child, whose
/// guard shows the "invalid props" fallback in its place and reports it, as
/// upstream's every node renders through that check.
bool hasValidProps(KitNode node) =>
    nodeProblemOf(node, ComponentProps(node.props.peek())) == null;

/// Builds a node of a component with [builder] as CopilotKit's SurfaceView
/// renders one:
///
/// - its props are checked first: a function value in them that cannot be
///   computed ([failedFunctionValueOf]), else its resolved data props
///   against its props schema; props that fail show the "invalid props"
///   fallback in its place, with no Retry, reported once until they are
///   valid (SurfaceView.tsx:740-753, :1095-1132);
/// - a [builder] that throws shows the fallback with the error's message
///   and a Retry, and reports the error, once while it comes back the same
///   (boundaries.tsx:33-39); it is tried again on Retry and for a new
///   revision of the node, the agent's props, never for new data alone
///   (boundaries.tsx:380-476);
/// - a child that is a cyclic reference, or of a type no catalog has,
///   builds as the fallback naming it, with no Retry (SurfaceView.tsx:
///   314-340);
/// - a list of children that names one id twice gives the first only
///   (SurfaceView.tsx:910-923).
///
/// Deliberate difference (CopilotKit's error boundary catches a throw
/// anywhere in its render): a throw inside a widget the builder returns,
/// during that widget's own build or layout, is not caught, and shows
/// Flutter's error widget: Flutter gives a parent no way to catch a
/// descendant's build error (`ComponentElement.performRebuild` hands it to
/// the global `ErrorWidget.builder`).
class NodeGuard extends StatefulWidget {
  /// Guards the build of [node] with [props] by [builder].
  const NodeGuard({
    required this.node,
    required this.props,
    required this.buildChild,
    required this.builder,
    super.key,
  });

  /// The node.
  final KitNode node;

  /// Its resolved props.
  final ComponentProps props;

  /// Builds a child node.
  final ChildWidgetBuilder buildChild;

  /// The component's builder.
  final ComponentWidgetBuilder builder;

  @override
  State<NodeGuard> createState() => _NodeGuardState();
}

class _NodeGuardState extends State<NodeGuard> {
  /// The props problem last reported, until the props are valid again: a
  /// problem is reported once while it stays, a different one again
  /// (`createFailureLog`, boundaries.tsx:33-39, :91-108).
  String? _reportedProblem;

  /// The throw last reported, until the node builds without one.
  String? _reportedFailure;

  /// The last check, by the props it was made of.
  (Object?, Object?, String?)? _check;

  /// The message of the throw the fallback shows, and the revision it came
  /// from.
  (String, Object?)? _failure;

  /// The node's revision: the agent's props of it, a new object for each
  /// update the agent sends (`ComponentModel.applyUpdate`).
  Object? get _revision => widget.node.context?.componentModel.properties;

  String? _problem() {
    final Map<String, Object?> props = widget.props;
    final check = _check;
    if (check != null &&
        identical(check.$1, props) &&
        identical(check.$2, _revision)) {
      return check.$3;
    }
    final problem = nodeProblemOf(widget.node, props);
    _check = (props, _revision, problem);
    return problem;
  }

  void _report(String code, String message) {
    final surface = widget.node.context?.surface;
    if (surface == null) return;
    unawaited(
      surface.dispatchError(
        A2uiRendererError(code: code, surfaceId: surface.id, message: message),
      ),
    );
  }

  void _retry() => setState(() => _failure = null);

  Widget _buildChild(KitNode child) => switch (child.state) {
    NodeState.cyclic => NodeFallback(
      message: 'cyclic reference to ${child.componentId}',
    ),
    NodeState.unknownType => NodeFallback(
      message: 'unknown component "${child.type}"',
    ),
    _ => widget.buildChild(child),
  };

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final problem = _problem();
    if (problem != null) {
      if (problem != _reportedProblem) {
        _reportedProblem = problem;
        _report(
          invalidPropsCode,
          "Component '${node.componentId}' has invalid props: $problem",
        );
      }
      return NodeFallback(message: 'invalid props ($problem)');
    }
    _reportedProblem = null;
    final failure = _failure;
    if (failure != null && identical(failure.$2, _revision)) {
      return NodeFallback(message: failure.$1, onRetry: _retry);
    }
    _failure = null;
    try {
      final built = widget.builder(
        context,
        node,
        _withoutRepeatedChildren(widget.props),
        _buildChild,
      );
      _reportedFailure = null;
      return built;
    } on Object catch (error) {
      final message = switch (error) {
        StateError(:final message) => message,
        _ => '$error',
      };
      _failure = (message, _revision);
      // The same failure again, before the node built without one, is not
      // reported again (`createFailureLog`, boundaries.tsx:91-108).
      if (message != _reportedFailure) {
        _reportedFailure = message;
        _report(
          renderFailedCode,
          "Component '${node.componentId}' failed to render: $message",
        );
      }
      return NodeFallback(message: message, onRetry: _retry);
    }
  }
}

/// [props] with each list of child nodes keeping the first node of each
/// component id and data scope: CopilotKit dedupes the ids of a list slot
/// (SurfaceView.tsx:910-923), so a repeated id renders once, while the
/// items of a template, one scope each, stay.
ComponentProps _withoutRepeatedChildren(ComponentProps props) {
  Map<String, Object?>? changed;
  for (final MapEntry(:key, :value) in props.entries) {
    if (value is! List<Object?> || value.length < 2) continue;
    final seen = <(String, String)>{};
    final kept = [
      for (final item in value)
        if (item is! KitNode || seen.add((item.componentId, item.dataPath)))
          item,
    ];
    if (kept.length == value.length) continue;
    (changed ??= Map.of(props))[key] = List<Object?>.unmodifiable(kept);
  }
  return changed == null ? props : ComponentProps(changed);
}

/// The text CopilotKit's default fallback shows for [message]
/// (host.tsx:139), U+2019 in "Couldn’t".
String fallbackText(String message) => 'Couldn’t display this part: $message';

/// CopilotKit's default node fallback (`DefaultNodeFallback`, host.tsx:
/// 116-150): an alert with [message] in a pale red box, and a Retry button
/// when [onRetry] is given. It is a block: as wide as its container gives
/// it, as tall as its text.
///
/// Deliberate difference (CopilotKit's `<button>` sits inline after the
/// message): the button follows the message as the next item of a wrap, so
/// a message of several lines puts it on a line of its own: the message
/// stays the alert's own label, and the button a node of its own.
class NodeFallback extends StatelessWidget {
  /// A fallback showing [message].
  const NodeFallback({required this.message, this.onRetry, super.key});

  /// What could not be displayed, and why.
  final String message;

  /// Tries the component again; null for no Retry.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = A2uiKitScope.themeOf(context);
    final text = fallbackText(message);
    final retry = onRetry;
    return Semantics(
      container: true,
      role: SemanticsRole.alert,
      label: text,
      child: DecoratedBox(
        // `border: 1px solid #fca5a5`, `background: #fef2f2`,
        // `borderRadius: 8`, `padding: 8px 12px` (host.tsx:127-133).
        decoration: BoxDecoration(
          color: theme.color(A2uiColorToken.copilotkitFallbackBackground),
          border: Border.all(
            color: theme.color(A2uiColorToken.copilotkitFallbackBorder),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: DefaultTextStyle.merge(
            // `color: #991b1b`, `fontSize: 13` (host.tsx:130, :132).
            style: TextStyle(
              fontSize: 13,
              color: theme.color(A2uiColorToken.copilotkitFallbackText),
            ),
            child: Wrap(
              // The button's `marginLeft: 8` (host.tsx:144).
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ExcludeSemantics(child: Text(text)),
                if (retry != null)
                  Semantics(
                    container: true,
                    button: true,
                    child: Activatable(
                      onActivate: retry,
                      // TODO(port): Chromium's html.css not fetched: the
                      // browser's own <button> look (border, background,
                      // padding) is not drawn, only its underlined text
                      // (host.tsx:144).
                      child: const Text(
                        'Retry',
                        style: TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// PORT STATUS: confidence=medium todos=1 upstream=packages/react-core/src/v2/generative-ui/SurfaceView.tsx, packages/react-core/src/v2/generative-ui/boundaries.tsx, packages/react-core/src/v2/generative-ui/host.tsx
