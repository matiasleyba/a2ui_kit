// The playground's ScatterChart, after `ScatterChart` in the playground's
// `charts.tsx` (MIT, (c) Atai Barkai), which draws it with TanStack Charts
// 1.1.0 (`cartesian.dart`).

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/charts/cartesian.dart';
import 'package:a2ui_kit/src/components/playground/charts/chart_kit.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/format/chart_format.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:flutter/widgets.dart';

/// The playground `ScatterChart`: two numbers against each other.
///
/// - Rows need a numeric `x` and `y`; `label`, `size` (0 or more) and
///   `series` are optional.
/// - Both axes are nice linear scales over dashed grids (x one tick per
///   92px, 2 to 8; y asked for 5); x ticks are compact from 1,000, y ticks
///   follow `format` and `unit`; `xLabel` and `yLabel` title the axes
///   (11px, medium, the text colour at 76%; 8px past the tick labels).
/// - Dots of radius 5, or 3.5 + √(size ÷ largest size) × 11, filled at 55%
///   with no outline, coloured by series, in data order. The pointer on a
///   dot, or within 48px of its edge, focuses it: it fills at 95% with a
///   focus ring and the others fade to 45%; its tooltip shows x, y and
///   size, titled by `label` (or the series). The keyboard steps through
///   the dots left to right.
/// - 260px tall unless `height` says otherwise; the legend shows with more
///   than one series.
///
/// A `CustomPaint` draws it, not `fl_chart`: `fl_chart` could draw the
/// dots, but not the axes, tooltip and focus states the other playground
/// charts share, which would then differ between charts.
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
Widget buildScatterChart(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = ScatterChartProps(props);
  final tokens = playgroundTokens(context);
  final points = pickRows(view.data, (row) {
    final x = rowField(row, 'x');
    final y = rowField(row, 'y');
    if (x is! num || !x.isFinite || y is! num || !y.isFinite) return null;
    final label = rowField(row, 'label');
    final size = rowField(row, 'size');
    final series = rowField(row, 'series');
    return ScatterPoint(
      x: x.toDouble(),
      y: y.toDouble(),
      label: label is String ? label : null,
      size: size is num && size.isFinite && size >= 0 ? size.toDouble() : null,
      series: series is String && series.isNotEmpty ? series : null,
    );
  });
  final names = seriesNames(points.map((p) => p.series));
  return PlaygroundChartFrame(
    title: view.title,
    subtitle: view.subtitle,
    legend: [
      for (var i = 0; i < names.length; i++)
        LegendItem(names[i], paletteAt(tokens, i)),
    ],
    empty: points.isEmpty,
    child: guardChart(
      () => PlaygroundPlot(
        height: view.height ?? 260,
        // `rows` is `useMemo`'d on `props.data` (charts.tsx).
        rowsKey: view.data,
        label: view.title ?? 'Scatter chart',
        columns: [
          view.xLabel ?? 'x',
          view.yLabel ?? 'y',
          'size',
          'series',
          'label',
        ],
        rows: [
          for (final p in points)
            [
              fmtValue(p.x),
              fmtValue(p.y, view.format, view.unit),
              if (p.size == null)
                ''
              else
                fmtValue(p.size, A2uiValueFormat.compact),
              p.series ?? kSeriesFallback,
              p.label ?? '',
            ],
        ],
        scene: (size, style) => ScatterScene(
          size: size,
          style: style,
          scatter: points,
          names: names,
          format: view.format,
          unit: view.unit,
          xLabel: view.xLabel,
          yLabel: view.yLabel,
        ),
      ),
    ),
  );
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/charts.tsx
