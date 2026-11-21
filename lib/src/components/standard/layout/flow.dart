import 'dart:async';

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/item_styles.dart';
import 'package:a2ui_kit/src/components/node_guard.dart' show isDrawnChild;
import 'package:a2ui_kit/src/components/standard/layout/containers.dart';
import 'package:a2ui_kit/src/components/standard/layout/flex_container.dart';
import 'package:a2ui_kit/src/components/standard/layout/grid.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/interaction/visible_once.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_grid.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:flutter/widgets.dart';

/// The standard `Flow`: a masonry-like grid of FlowItem cells
/// (layout.tsx:553-561).
///
/// Its columns are the Grid's auto-fit template for `columns` (3 by
/// default): at most that many, each at least round(max(120, 520 /
/// columns)) pixels wide, so they collapse towards one on a narrow screen.
/// The cells are `gap` steps apart (4, 16px, by default; `rowGap` and
/// `columnGap` win over it). With `layout: "pack"` (the default) each cell
/// takes the first place that fits it, so a small cell fills a hole a
/// wide one left (`grid-auto-flow: dense`); `"fixed"` keeps the cells in
/// order. A FlowItem spanning more columns than are shown adds columns, as
/// CSS adds them for `span N` (`grid-auto-columns: auto`). `rows` is read
/// by nothing, as in CopilotKit.
///
/// Deliberate difference (Chromium clamps `span N` to 10,000,000 grid
/// lines): a span or row span past 1,000 is 1,000 ([cssGridMaxTracks],
/// INV-340): each track is sized as an entry of its own, so ten million
/// would take a phone's memory and many seconds of layout; an implicit grid
/// of 1,000 tracks and their gaps already runs far past any screen.
///
/// It is a container like Box: the layout props, `onVisible` once it
/// shows, a known ARIA `role`, and inside a Card a background in the panel
/// palette.
Widget buildFlow(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = FlowProps(props);
  final position = CardScope.of(context);
  final css = containerCss(context, props);
  containerDefaults(css, props, position);
  // `gap: spacing(props.gap ?? 4)` over the container's own default.
  css.gap = css.steps(props.value('gap') ?? 4);
  final flex = css.toFlex();
  final columns = gridColumnsOf(view.columns ?? 3, null, css);
  // A cyclic reference's or an unknown type's fallback is a cell too, as
  // CopilotKit's fallback `<div>` is a grid item (SurfaceView.tsx:314-340).
  final resolved = view.children.where(isDrawnChild).toList();
  final grid = ChildPropsBuilder<GridPlacement>(
    children: resolved,
    derive: flowPlacementOf,
    builder: (context, placements) => CssGrid(
      columns: columns,
      rowGap: flex.rowGap,
      columnGap: flex.columnGap,
      align: css.align,
      dense: view.layout != FlowLayout.fixed,
      implicitColumns: true,
      children: [
        for (var i = 0; i < resolved.length; i++)
          KeyedSubtree(
            key: NodeKey(resolved[i].instanceId),
            child: CssGridItem(
              placement: placements[i],
              child: buildChild(resolved[i]),
            ),
          ),
      ],
    ),
  );
  Widget content = CardScope(
    position: position.child,
    child: gridBox(css, grid),
  );
  final onVisible = view.onVisible;
  if (onVisible != null) {
    content = VisibleOnce(
      onVisible: () => unawaited(onVisible()),
      child: content,
    );
  }
  return withRole(props.string('role'), content);
}

/// The placement of a Flow child: a FlowItem's (or GridItem's) `span` and
/// `rowSpan` as CSS `span N` ([cssGridSpanOf]: a positive whole number,
/// at most [cssGridMaxTracks]; CSS ignores any other, and CopilotKit sets
/// none for 0), never clamped to the columns shown; and whether it keeps
/// an aspect ratio ([hasAspectRatio]).
GridPlacement flowPlacementOf(KitNode child) {
  final props = ComponentProps(child.props.peek());
  final spans = child.type == 'FlowItem' || child.type == 'GridItem';
  return GridPlacement(
    span: spans ? cssGridSpanOf(props.number('span')) ?? 1 : 1,
    rowSpan: spans ? cssGridSpanOf(props.number('rowSpan')) ?? 1 : 1,
    hasAspectRatio: hasAspectRatio(child),
  );
}

/// The standard `FlowItem`: a cell of a Flow, a flex column with its
/// `aspectRatio` (`"1 / 1"` by default: square, unless its content is
/// taller), spanning `span` columns and `rowSpan` rows (layout.tsx:563-567).
///
/// A container like Box: the layout props, the default gap of its depth,
/// `onVisible` once it shows, a known ARIA `role`. `aspectMode` is read by
/// nothing, as in CopilotKit.
Widget buildFlowItem(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final position = CardScope.of(context);
  final css = containerCss(context, props)..direction = Axis.vertical;
  containerDefaults(css, props, position);
  css.aspectRatio = cssAspectRatio(props.value('aspectRatio') ?? '1 / 1');
  return flexContainer(
    context,
    props: props,
    css: css,
    children: FlowItemProps(props).children,
    buildChild: buildChild,
    childPosition: position.child,
  );
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/layout.tsx
