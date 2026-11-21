// The playground's LineChart, after `LineChart` in the playground's
// `charts.tsx` (MIT, (c) Atai Barkai), which draws it with TanStack Charts
// 1.1.0 (`cartesian.dart`).

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/charts/cartesian.dart';
import 'package:a2ui_kit/src/components/playground/charts/chart_kit.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:flutter/widgets.dart';

/// The playground `LineChart`: a trend over an ordered x, one line per
/// series.
///
/// - x is a nice linear scale when every x is a number (one tick per 92px,
///   2 to 8, written as the scale writes them: `2019`, `0.5`), else points
///   in the order they first appear (padding .25); y a nice linear scale
///   asked for 5 ticks (d3 gives about that many: the sample draws 8) over
///   a dashed (2 4) grid at 11% of the grid colour, formatted by `format`
///   and `unit`.
/// - Lines are 2px, smooth (a monotone cubic, never overshooting, in data
///   order) unless `curve` is false; with at most 16 rows each point has a
///   2.5px dot under its line. A single series that never goes below 0
///   gets a fade under it.
/// - `highlight` keeps one series coloured and greys the others.
/// - The pointer focuses the nearest x (one series: its point; more: the
///   series nearest the pointer, with the others at that x): a focus ring
///   on the focused point, a crosshair (the text colour at 35%) and a
///   tooltip above it, rows top to bottom. A click or tap pins it; Tab
///   focuses the first x, the arrow keys, Home and End move, Enter and
///   Space pin, Escape unpins.
/// - Tick labels are 10px under a 360px chart (else 11px) at 68% of the
///   muted colour, thinned 4px apart; the margins grow to hold them.
/// - The legend shows with more than one series. Without rows it says "No
///   data yet". It is 220px tall unless `height` says otherwise, and grows
///   in from the left (700ms, not under reduced motion).
///
/// A `CustomPaint` draws it, not `fl_chart`: `fl_chart`'s curve is a
/// Catmull-Rom spline with a smoothness factor, not the playground's
/// Fritsch-Carlson monotone cubic, and its axes are not TanStack's.
///
/// Differences from CopilotKit: TanStack's own SVG transitions are not
/// drawn; the playground's CSS wipe-in is (700ms, none under reduced
/// motion). Labels are measured by their advance width and the font's
/// ascent and descent, as Flutter has no ink bounds (TanStack measures the
/// canvas' painted bounds); the hanging baseline is 80% of the ascent, and
/// SVG's middle baseline (the y labels) half an x-height above the
/// alphabetic one, half an em standing in for the x-height: margins and
/// label thinning can differ by a pixel or two. A focused area
/// point's tooltip swatch is its series' colour, where TanStack's is the
/// area's fade (`url(#a2-fade-N)`), which no HTML swatch paints. A pinned
/// tooltip ignores the pointer (TanStack's takes it, so its text can be
/// selected). Chart text in
/// goldens: painted text: alchemist's CI goldens draw it as black blocks.
/// Chart accessibility: every chart is an image named by its title,
/// followed by hidden rows that read each cell after its column.
Widget buildLineChart(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = LineChartProps(props);
  final tokens = playgroundTokens(context);
  final rows = cleanRows(view.data);
  final names = seriesNames(rows.map((r) => r.series));
  final colors = seriesColors(tokens, names, view.highlight);
  final (columns, table) = xyTable(rows, names, view.format, view.unit);
  return PlaygroundChartFrame(
    title: view.title,
    subtitle: view.subtitle,
    legend: legendItems(names, colors),
    empty: rows.isEmpty,
    child: guardChart(
      () => PlaygroundPlot(
        height: view.height ?? 220,
        // `rows` is `useMemo`'d on `props.data` (charts.tsx).
        rowsKey: view.data,
        label: view.title ?? 'Line chart',
        columns: columns,
        rows: table,
        scene: (size, style) => LineAreaScene(
          size: size,
          style: style,
          kind: LineAreaKind.line,
          rows: rows,
          names: names,
          colors: colors,
          format: view.format,
          unit: view.unit,
          title: view.title,
          curve: view.curve != false,
        ),
      ),
    ),
  );
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/charts.tsx
