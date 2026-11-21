// The playground's BarChart, after `BarChart` in the playground's
// `charts.tsx` (MIT, (c) Atai Barkai), which draws it with TanStack Charts
// 1.1.0 (`cartesian.dart`).

import 'dart:math' as math;

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/charts/cartesian.dart';
import 'package:a2ui_kit/src/components/playground/charts/chart_kit.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:flutter/widgets.dart';

/// The playground `BarChart`: categories compared, series side by side
/// (or `stacked`), `horizontal` for long labels.
///
/// - Categories on a band scale (padding .24 with more series, .32 with
///   one), in the order they first appear, labels cut at 12 characters
///   (18 when horizontal); values on a nice linear scale with 0, asked for
///   5 ticks, over a dashed grid.
/// - Grouped bars at most 18px thick (series padding .12), stacked or
///   single ones 40px, horizontal ones 22px, in data order; each bar's
///   value end rounded 4px, of a stack (diverging from 0, a single series
///   too) only its outer ends, and no corner on an empty bar. Two values of
///   one series in one category of a stack say "Waiting for complete
///   data", as TanStack refuses the stack.
/// - 230px tall, horizontal max(160, categories × 30 (40 grouped) + 40),
///   unless `height` says otherwise.
/// - The pointer within 48px of a bar along the category axis focuses it
///   (more series: the category within 48px, its bar nearest the pointer
///   first): a focus ring at its value end and a tooltip, rows top to
///   bottom (left to right when horizontal). The keyboard steps a grouped
///   chart by category (its focus strategy) and a single series in screen
///   order, which TanStack uses without a strategy (dist/interaction.js:
///   71-121), so a horizontal one by where each bar ends; `highlight`, the
///   legend, "No data yet" and the grow-in as the LineChart.
///
/// A `CustomPaint` draws it, not `fl_chart`: `fl_chart` sizes bars in
/// pixels with fixed group gaps, not by TanStack's band and group padding
/// with a thickness cap, and its axes would differ from the other charts'.
///
/// Differences from CopilotKit: TanStack's own SVG transitions are not
/// drawn; the playground's CSS wipe-in is (700ms, none under reduced
/// motion). Labels are measured by their advance width and the font's
/// ascent and descent, as Flutter has no ink bounds (TanStack measures the
/// canvas' painted bounds); the hanging baseline is 80% of the ascent, and
/// SVG's middle baseline (the y labels) half an x-height above the
/// alphabetic one, half an em standing in for the x-height: margins and
/// label thinning can differ by a pixel or two. A pinned
/// tooltip ignores the pointer (TanStack's takes it, so its text can be
/// selected). Chart text in
/// goldens: painted text: alchemist's CI goldens draw it as black blocks.
/// Chart accessibility: every chart is an image named by its title,
/// followed by hidden rows that read each cell after its column.
Widget buildBarChart(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = BarChartProps(props);
  final tokens = playgroundTokens(context);
  final rows = cleanRows(view.data);
  final names = seriesNames(rows.map((r) => r.series));
  final colors = seriesColors(tokens, names, view.highlight);
  final horizontal = view.horizontal ?? false;
  final multi = names.length > 1;
  final grouped = multi && view.stacked != true;
  final categories = xDomainOf(rows);
  final height =
      view.height ??
      (horizontal
          ? math
                .max(160, categories.length * (grouped ? 40 : 30) + 40)
                .toDouble()
          : 230.0);
  final (columns, table) = xyTable(rows, names, view.format, view.unit);
  return PlaygroundChartFrame(
    title: view.title,
    subtitle: view.subtitle,
    legend: legendItems(names, colors),
    empty: rows.isEmpty,
    child: guardChart(() {
      // A stack TanStack refuses throws here, before the drawing is laid
      // out (port/inventory.tsv INV-041).
      if (!grouped) BarScene.stackOf(rows, names);
      return PlaygroundPlot(
        height: height,
        // `rows` is `useMemo`'d on `props.data` (charts.tsx).
        rowsKey: view.data,
        label: view.title ?? 'Bar chart',
        columns: columns,
        rows: table,
        scene: (size, style) => BarScene(
          size: size,
          style: style,
          rows: rows,
          names: names,
          colors: colors,
          format: view.format,
          unit: view.unit,
          title: view.title,
          stacked: view.stacked ?? false,
          horizontal: horizontal,
        ),
      );
    }),
  );
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/charts.tsx
