import 'dart:math' as math;

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/item_styles.dart' show hasAspectRatio;
import 'package:a2ui_kit/src/components/node_guard.dart' show isDrawnChild;
import 'package:a2ui_kit/src/components/standard/layout/container_css.dart';
import 'package:a2ui_kit/src/components/standard/layout/containers.dart';
import 'package:a2ui_kit/src/components/standard/layout/flex_container.dart';
import 'package:a2ui_kit/src/components/standard/layout/focusable_scroll_box.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_grid.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:flutter/widgets.dart';

/// The narrowest track that keeps `columns` cards side by side: 520px.
const double _gridMinTrackPx = 520;

/// CopilotKit's `gridTemplateColumns` as a [GridColumns]: a string is a
/// CSS template; `minChildWidth` fills the row with columns at least that
/// wide; a number (2 by default) is an auto-fit count whose columns
/// collapse towards one when narrower than round(max(120, 520 / count)).
GridColumns gridColumnsOf(
  Object? columns,
  Object? minChildWidth,
  ContainerCss css,
) {
  if (columns is String) return parseGridTemplate(columns, css);
  if (minChildWidth != null) {
    final min = css.steps(minChildWidth)?.resolve(fontSize: css.fontSize);
    return GridColumns.autoFill(minTrack: min ?? 0);
  }
  final count = math.max(1, (columns is num ? columns : 2).floor());
  if (count == 1) return const GridColumns.tracks([GridTrack(fraction: 1)]);
  return GridColumns.autoFit(
    count: count,
    minTrack: math.max(120, _gridMinTrackPx / count).roundToDouble(),
  );
}

/// The tracks of a CSS `grid-template-columns` string.
///
/// Reads lengths (`200px`, `10rem`), `fr` shares (as `minmax(0, Nfr)`: a
/// bare `Nfr` column never widens to its content's min-content, where CSS
/// reads it as `minmax(auto, Nfr)`), `auto`, `min-content` and
/// `max-content` (sized from their items as CSS Grid sizes them),
/// `minmax(a, b)` (as b when b is a share or a content keyword, else a),
/// `repeat(n, …)`, and `repeat(auto-fill | auto-fit, minmax(L, 1fr))`.
/// Anything else gives equal columns, one per token.
GridColumns parseGridTemplate(String template, ContainerCss css) {
  final tokens = _splitTopLevel(template.trim());
  if (tokens.length == 1) {
    final auto = RegExp(
      r'^repeat\(\s*(auto-fill|auto-fit)\s*,\s*minmax\((.+),\s*1fr\s*\)\s*\)$',
    ).firstMatch(tokens.single);
    if (auto != null) {
      final min = _minLength(auto[2]!, css) ?? 0;
      return auto[1] == 'auto-fit'
          ? GridColumns.autoFit(count: 1 << 20, minTrack: min)
          : GridColumns.autoFill(minTrack: min);
    }
  }
  final tracks = <GridTrack>[];
  for (final token in tokens) {
    final repeat = RegExp(r'^repeat\(\s*(\d+)\s*,(.+)\)$').firstMatch(token);
    if (repeat != null) {
      final inner = _splitTopLevel(repeat[2]!.trim());
      final parsed = [for (final t in inner) _track(t, css)];
      if (parsed.contains(null)) return _equalColumns(tokens.length);
      for (var i = 0; i < int.parse(repeat[1]!); i++) {
        tracks.addAll(parsed.cast<GridTrack>());
      }
      continue;
    }
    final track = _track(token, css);
    if (track == null) return _equalColumns(tokens.length);
    tracks.add(track);
  }
  return tracks.isEmpty ? _equalColumns(1) : GridColumns.tracks(tracks);
}

GridColumns _equalColumns(int count) => GridColumns.tracks([
  for (var i = 0; i < count; i++) const GridTrack(fraction: 1),
]);

GridTrack? _track(String token, ContainerCss css) {
  final value = token.trim();
  final fr = RegExp(r'^(\d*\.?\d+)fr$').firstMatch(value);
  if (fr != null) return GridTrack(fraction: double.parse(fr[1]!));
  switch (value) {
    case 'auto':
      return const GridTrack.auto();
    case 'min-content':
      return const GridTrack.minContent();
    case 'max-content':
      return const GridTrack.maxContent();
  }
  final minmax = RegExp(r'^minmax\((.+),(.+)\)$').firstMatch(value);
  if (minmax != null) {
    final max = _track(minmax[2]!, css);
    if (max != null && (max.flexible || max.content != null)) return max;
    return _track(minmax[1]!, css) ?? max;
  }
  final length = A2uiLength.parse(value);
  if (length == null || length is A2uiPercent) return null;
  return GridTrack(pixels: length.resolve(fontSize: css.fontSize)!);
}

double? _minLength(String value, ContainerCss css) {
  final inner = RegExp(r'^min\(\s*100%\s*,(.+)\)$').firstMatch(value.trim());
  final length = A2uiLength.parse((inner?[1] ?? value).trim());
  if (length == null || length is A2uiPercent) return null;
  return length.resolve(fontSize: css.fontSize);
}

/// [text] split at top-level whitespace and commas outside parentheses
/// are kept: `repeat(2, 1fr) 100px` is two tokens.
List<String> _splitTopLevel(String text) {
  final tokens = <String>[];
  var depth = 0;
  final current = StringBuffer();
  for (final char in text.split('')) {
    if (char == '(') depth++;
    if (char == ')') depth--;
    if (depth == 0 && char.trim().isEmpty) {
      if (current.isNotEmpty) tokens.add(current.toString());
      current.clear();
    } else {
      current.write(char);
    }
  }
  if (current.isNotEmpty) tokens.add(current.toString());
  return tokens;
}

/// The standard `Grid`: CSS grid columns that collapse towards one column
/// on a narrow screen, 16px apart by default. `scrollable` scrolls it
/// vertically inside its `height` or `maxHeight`.
///
/// `rows` is not applied: each row is as tall as its tallest cell, where
/// CopilotKit sets `grid-template-rows` (a count adds empty `auto` rows,
/// a template sizes the rows).
///
/// A string template reads lengths, `fr`, `auto`, `min-content`,
/// `max-content`, `minmax()` and `repeat()`; anything else is equal
/// columns. A bare `Nfr` reads as `minmax(0, Nfr)` where CSS reads
/// `minmax(auto, Nfr)`, so an `fr` column never widens to its content's
/// min-content; `minmax(a, b)` reads as b when b is `fr` or a content
/// keyword, else as a; and an item spanning several columns does not
/// widen the `auto`, `min-content` or `max-content` columns it crosses
/// (INV-016).
///
/// CopilotKit's Grid declares `onVisible` but does not wire it, and gives
/// its element no role: neither does this.
Widget buildGrid(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final css = containerCss(context, props)..direction = Axis.vertical;
  if (!css.hasGap) css.gap = css.steps(4);
  final flex = css.toFlex();
  final columns = gridColumnsOf(
    props.value('columns'),
    props.value('minChildWidth'),
    css,
  );
  final resolved = props.children('children').where(isDrawnChild).toList();
  final grid = ChildPropsBuilder<GridPlacement>(
    children: resolved,
    derive: gridPlacementOf,
    builder: (context, placements) => CssGrid(
      columns: columns,
      rowGap: flex.rowGap,
      columnGap: flex.columnGap,
      align: css.align,
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
  return gridBox(css, grid);
}

/// The box of a grid container: [grid] inside the container's padding,
/// border and fill, and with `scrollable` scrolling vertically inside its
/// `height` or `maxHeight`, a tab stop then (layout.tsx:472).
Widget gridBox(ContainerCss css, Widget grid) {
  final box = css.toBox();
  final container = CssFlex(
    flex: const A2uiFlexStyle(),
    box: A2uiBoxStyle(
      // overflow: auto. The box stays put and its padded grid scrolls.
      padding: css.scroll ? EdgeInsets.zero : box.padding,
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
      clip: box.clip || css.scroll,
    ),
    children: [
      if (css.scroll)
        scrollArea(
          direction: Axis.vertical,
          child: CssFlex(
            flex: const A2uiFlexStyle(),
            box: A2uiBoxStyle(padding: box.padding),
            children: [grid],
          ),
        )
      else
        grid,
    ],
  );
  // A scrollable Grid is a tab stop too (layout.tsx:472).
  return css.scroll
      ? FocusableScrollBox(
          borderRadius: box.decoration?.borderRadius,
          child: container,
        )
      : container;
}

/// The placement of a Grid child: a GridItem's `span` and `rowSpan`
/// ([cssGridSpanOf]: positive whole numbers, at most [cssGridMaxTracks];
/// others are ignored, as CSS ignores them), one cell for anything else;
/// and whether it keeps an aspect ratio ([hasAspectRatio]: a GridItem's or
/// another container's `aspectRatio`, which `normal` alignment keeps).
GridPlacement gridPlacementOf(KitNode child) {
  final ratio = hasAspectRatio(child);
  if (child.type != 'GridItem') {
    return ratio
        ? const GridPlacement(hasAspectRatio: true)
        : GridPlacement.cell;
  }
  final props = ComponentProps(child.props.peek());
  return GridPlacement(
    span: cssGridSpanOf(props.number('span')) ?? 1,
    rowSpan: cssGridSpanOf(props.number('rowSpan')) ?? 1,
    hasAspectRatio: ratio,
  );
}

/// The standard `GridItem`: a flex column cell of a Grid, without a
/// default gap. Its span is read by the Grid.
///
/// Deliberate difference (Chromium clamps `span N` to 10,000,000 grid
/// lines): a span or row span past 1,000 is 1,000 ([cssGridMaxTracks],
/// INV-340): each track is sized as an entry of its own, so ten million
/// would take a phone's memory and many seconds of layout; an implicit grid
/// of 1,000 tracks and their gaps already runs far past any screen.
Widget buildGridItem(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final css = containerCss(context, props)..direction = Axis.vertical;
  return flexContainer(
    context,
    props: props,
    css: css,
    children: props.children('children'),
    buildChild: buildChild,
    childPosition: CardScope.of(context),
    wired: false,
  );
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/layout.tsx
