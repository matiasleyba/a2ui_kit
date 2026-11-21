import 'dart:async';

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/item_styles.dart';
import 'package:a2ui_kit/src/components/node_guard.dart' show isDrawnChild;
import 'package:a2ui_kit/src/components/standard/layout/container_css.dart';
import 'package:a2ui_kit/src/components/standard/layout/focusable_scroll_box.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/interaction/visible_once.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Marks the last Text of a `spaceBetween` Row, which CopilotKit's
/// stylesheet pushes flush right (`margin-inline-start: auto`) and aligns
/// right: the key/value row idiom.
class RowEndText extends InheritedWidget {
  /// Marks [child].
  const RowEndText({required super.child, super.key});

  /// Whether the Text at [context] is the last of a `spaceBetween` Row.
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RowEndText>() != null;

  @override
  bool updateShouldNotify(RowEndText oldWidget) => false;
}

/// A container: [css] lays out the resolved [children] as CSS flex items
/// under [childPosition].
///
/// `scrollable` scrolls the content along the main axis. Unless [wired] is
/// false (GridItem's React renderer wires neither), `onVisible` fires once
/// when the container shows and a known ARIA `role` becomes semantics.
Widget flexContainer(
  BuildContext context, {
  required ComponentProps props,
  required ContainerCss css,
  required List<KitNode> children,
  required ChildWidgetBuilder buildChild,
  required CardPosition childPosition,
  bool isRow = false,
  bool wired = true,
}) {
  final resolved = children.where(isDrawnChild).toList();
  final step = css.theme.spacingStep;
  final fontSize = css.fontSize;
  final flex = css.toFlex();
  final box = css.toBox();
  final keyValueRow =
      css.theme.keyValueRows &&
      isRow &&
      css.justify == A2uiJustify.spaceBetween &&
      resolved.length > 1;

  Widget content = ChildPropsBuilder<(A2uiFlexItemStyle, String)>(
    children: resolved,
    derive: (child) =>
        (flexItemStyleOf(child, step: step, fontSize: fontSize), child.type),
    builder: (context, items) {
      Widget item(int i) {
        var (style, type) = items[i];
        var built = buildChild(resolved[i]);
        if (keyValueRow && i == resolved.length - 1 && type == 'Text') {
          style = style.copyWith(autoMarginStart: true);
          built = RowEndText(child: built);
        }
        return KeyedSubtree(
          key: NodeKey(resolved[i].instanceId),
          child: CssFlexItem(style: style, child: built),
        );
      }

      if (!css.scroll) {
        return CssFlex(
          flex: flex,
          box: box,
          children: [for (var i = 0; i < resolved.length; i++) item(i)],
        );
      }
      // overflow: auto. The box stays put and its padded content scrolls;
      // the box is a tab stop (`scrollAttributes`, layout.tsx:162-167).
      return FocusableScrollBox(
        borderRadius: box.decoration?.borderRadius,
        child: CssFlex(
          flex: const A2uiFlexStyle(),
          box: A2uiBoxStyle(
            borderWidth: box.borderWidth,
            decoration: box.decoration,
            width: box.width,
            height: box.height,
            minWidth: box.minWidth,
            minHeight: box.minHeight,
            maxWidth: box.maxWidth,
            maxHeight: box.maxHeight,
            aspectRatio: box.aspectRatio,
            fill: box.fill,
            clip: true,
          ),
          children: [
            scrollArea(
              direction: flex.direction,
              child: CssFlex(
                flex: flex,
                box: A2uiBoxStyle(padding: box.padding),
                children: [for (var i = 0; i < resolved.length; i++) item(i)],
              ),
            ),
          ],
        ),
      );
    },
  );

  content = CardScope(position: childPosition, child: content);
  if (!wired) return content;
  final onVisible = props.action('onVisible');
  if (onVisible != null) {
    content = VisibleOnce(
      onVisible: () => unawaited(onVisible()),
      child: content,
    );
  }
  return withRole(props.string('role'), content);
}

/// The scrolling content of an `overflow: auto` box: a flex item of the
/// box that may shrink below its content (min width and height 0), so a
/// box with a `height` or `maxHeight` scrolls instead of clipping. It is
/// the box's scroll view ([FocusableScrollBox.scrollView]), which the box's
/// keys scroll.
Widget scrollArea({required Axis direction, required Widget child}) =>
    CssFlexItem(
      style: const A2uiFlexItemStyle(
        minWidth: A2uiLength.zero,
        minHeight: A2uiLength.zero,
      ),
      child: FocusableScrollBox.scrollView(axis: direction, child: child),
    );

/// [child] with the semantics of the ARIA [role], for the roles Flutter
/// can express; other roles change nothing. A `group` (`namedRole`'s
/// explicit role, layout.tsx:259, :377) is a node of its own, which is all
/// Flutter's semantics hold of it (`SemanticsRole` has no group).
Widget withRole(String? role, Widget child) => switch (role) {
  'group' => Semantics(container: true, child: child),
  'heading' => Semantics(container: true, header: true, child: child),
  'button' => Semantics(container: true, button: true, child: child),
  'link' => Semantics(container: true, link: true, child: child),
  'img' || 'image' => Semantics(container: true, image: true, child: child),
  'list' => Semantics(container: true, role: SemanticsRole.list, child: child),
  'form' => Semantics(container: true, role: SemanticsRole.form, child: child),
  'dialog' => Semantics(
    container: true,
    role: SemanticsRole.dialog,
    child: child,
  ),
  'alertdialog' => Semantics(
    container: true,
    role: SemanticsRole.alertDialog,
    child: child,
  ),
  'tabpanel' => Semantics(
    container: true,
    role: SemanticsRole.tabPanel,
    child: child,
  ),
  _ => child,
};

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/layout.tsx
