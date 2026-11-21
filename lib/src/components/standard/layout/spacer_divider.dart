import 'dart:math' as math;

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:flutter/widgets.dart';

/// The standard `Spacer`: empty space that grows (`flex: 1`), at least
/// `minSize` (2 steps, 8px) on both axes, hidden from screen readers.
Widget buildSpacer(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final theme = A2uiKitScope.themeOf(context);
  final fontSize = DefaultTextStyle.of(context).style.fontSize ?? 16;
  final min =
      A2uiLength.steps(
        SpacerProps(props).minSize ?? 2,
        step: theme.spacingStep,
      )?.resolve(fontSize: fontSize) ??
      0;
  return ExcludeSemantics(
    child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: min, minHeight: min),
      child: const SizedBox.shrink(),
    ),
  );
}

/// The standard `Divider`: a `size`px line (1 by default) in `color`
/// (`subtle` by default), `spacing` (2 steps, 8px) away from its
/// neighbours, none with `flush`. Horizontal lines span their container;
/// a vertical one (`axis: "vertical"`) stretches across a Row.
Widget buildDivider(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = DividerProps(props);
  final theme = A2uiKitScope.themeOf(context);
  final fontSize = DefaultTextStyle.of(context).style.fontSize ?? 16;
  // A negative size makes CopilotKit's `border-top` invalid: no line.
  final thickness = math.max(0, view.size ?? 1).toDouble();
  final color =
      theme.borderColor(view.color?.wire ?? 'subtle') ??
      const Color(0x00000000);
  final margin = (view.flush ?? false)
      ? 0.0
      : A2uiLength.steps(
              view.spacing ?? 2,
              step: theme.spacingStep,
            )?.resolve(fontSize: fontSize) ??
            0;
  // Flutter draws a 0-width side as a hairline; CSS draws nothing.
  final side = thickness > 0
      ? BorderSide(color: color, width: thickness)
      : BorderSide.none;
  if (view.axis == DividerAxis.vertical) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: margin),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(left: side)),
        child: SizedBox(width: thickness),
      ),
    );
  }
  return Padding(
    padding: EdgeInsets.symmetric(vertical: margin),
    child: FractionallySizedBox(
      widthFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: side)),
        child: SizedBox(height: thickness),
      ),
    ),
  );
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/layout.tsx
