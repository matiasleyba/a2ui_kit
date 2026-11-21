// The playground's AreaChart, after `AreaChart` in the playground's
// `charts.tsx` (MIT, (c) Atai Barkai), which draws it with TanStack Charts
// 1.1.0 (`cartesian.dart`).

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/charts/cartesian.dart';
import 'package:a2ui_kit/src/components/playground/charts/chart_kit.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:flutter/widgets.dart';

/// The playground `AreaChart`: filled trends; with more than one series
/// they stack unless `stacked` is false.
///
/// - Stacked (`stack({order})`, diverging: positives up from 0, negatives
///   down from 0, in series order): each band at 62% of its colour with a
///   1px surface line round it; a series missing at an x has no point
///   there; the tooltip ends with the stack's Total. Two values of one
///   series at one x say "Waiting for complete data", as TanStack refuses
///   the stack.
/// - Unstacked: each series a fade (34% to clear, by its palette slot)
///   under a 1.75px line.
/// - x points have padding .02; the rest is as the LineChart (220px,
///   `highlight`, the focus of the nearest x with the crosshair, the
///   tooltip and the keyboard, the legend, "No data yet", the grow-in),
///   without dots; the marks are clipped to the plot.
///
/// A `CustomPaint` draws it, not `fl_chart`: the playground's monotone
/// cubic and its stacking with a surface line between bands are not
/// `fl_chart`'s.
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
Widget buildAreaChart(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = AreaChartProps(props);
  final tokens = playgroundTokens(context);
  final rows = cleanRows(view.data);
  final names = seriesNames(rows.map((r) => r.series));
  final colors = seriesColors(tokens, names, view.highlight);
  final stacked = view.stacked != false && names.length > 1;
  final (columns, table) = xyTable(rows, names, view.format, view.unit);
  return PlaygroundChartFrame(
    title: view.title,
    subtitle: view.subtitle,
    legend: legendItems(names, colors),
    empty: rows.isEmpty,
    child: guardChart(() {
      // A stack TanStack refuses throws here, before the drawing is laid
      // out (port/inventory.tsv INV-041).
      if (stacked) LineAreaScene.stackOf(rows, names);
      return PlaygroundPlot(
        height: view.height ?? 220,
        // `rows` is `useMemo`'d on `props.data` (charts.tsx).
        rowsKey: view.data,
        label: view.title ?? 'Area chart',
        columns: columns,
        rows: table,
        scene: (size, style) => LineAreaScene(
          size: size,
          style: style,
          kind: stacked ? LineAreaKind.stackedArea : LineAreaKind.area,
          rows: rows,
          names: names,
          colors: colors,
          format: view.format,
          unit: view.unit,
          title: view.title,
        ),
      );
    }),
  );
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/charts.tsx
