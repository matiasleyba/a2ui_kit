// The playground's PieChart, after `PieChart` in the playground's
// `charts.tsx` (MIT, (c) Atai Barkai), which draws it with TanStack Charts.

import 'dart:math' as math;

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/charts/chart_kit.dart';
import 'package:a2ui_kit/src/components/playground/charts/pie_sparkline.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/format/chart_format.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/layout/fit_content.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_grid.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/functions/calc.dart';
import 'package:a2ui_kit/src/theme/playground_tokens.dart';
import 'package:flutter/widgets.dart';

/// The playground `PieChart`: parts of a whole, a donut unless `donut` is
/// false.
///
/// - Rows need a string `label` and a value of 0 or more; with no rows, or
///   a total of 0, it says "No data yet".
/// - The chart is `height` (200) pixels square: TanStack's own pie, the
///   slices in data order clockwise from 12 o'clock, each slice with a
///   value followed by a .025 rad gap (with more than one row; a slice of
///   0 takes no angle and no gap), d3 arcs with corners 4px (2px on a pie),
///   coloured by label. The pointer on a slice focuses it: the others fade
///   to 35% and its value and share show in the tooltip; the keyboard steps
///   through the slices by their middles, left to right.
/// - A donut shows the total in its middle (20px semibold; compact, or
///   currency or percent by `format`) over `centerLabel` (Total).
/// - Beside it (under it when the row is narrower than the chart, 24px
///   and 180px) a list (a CSS grid, 6px between rows): swatch, label,
///   value (compact, or currency) and share (1 decimal under 10%).
///
/// A `CustomPaint` draws it, not `fl_chart`: `fl_chart`'s sections have no
/// angular gaps or rounded corners like TanStack's d3 arcs.
///
/// Differences from CopilotKit: TanStack's own SVG transitions are not
/// drawn; the playground's CSS wipe-in is (700ms, none under reduced
/// motion). A pinned tooltip ignores the pointer (TanStack's takes it, so
/// its text can be selected). Chart
/// text in goldens: painted text: alchemist's CI goldens draw it as black
/// blocks. Chart accessibility: every chart is an image named by its
/// title, followed by hidden rows that read each cell after its column.
Widget buildPieChart(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = PieChartProps(props);
  final tokens = playgroundTokens(context);
  final rows = pickRows(view.data, (row) {
    final label = rowField(row, 'label');
    final value = rowField(row, 'value');
    return label is String && value is num && value.isFinite && value >= 0
        ? PieRow(label, value.toDouble())
        : null;
  });
  final format = view.format;
  final unit = view.unit;
  final donut = view.donut != false;
  final total = rows.fold<double>(0, (sum, r) => sum + r.value);
  // The slices take their colour by label (an ordinal scale), the list by
  // row.
  final firstOf = <String, int>{};
  for (final row in rows) {
    firstOf.putIfAbsent(row.label, () => firstOf.length);
  }
  final sliceColors = [
    for (final row in rows) paletteAt(tokens, firstOf[row.label]!),
  ];
  final size = math.max(0, view.height ?? 200).toDouble();
  String share(double value) {
    final fraction = total > 0 ? value / total : 0.0;
    // charts.tsx PieChart: `(share * 100).toFixed(share < 0.1 ? 1 : 0)`.
    return '${jsToFixed(fraction * 100, fraction < .1 ? 1 : 0)}%';
  }

  // The donut's centre: `pointer-events-none absolute inset-0 grid
  // place-items-center text-center` after the `<Chart>` in its `relative`
  // box (charts.tsx:597-627). It goes in the plot's underlay, so the
  // tooltip (`z-index: 1`) covers it, as in the browser.
  final centre = donut
      ? IgnorePointer(
          // The grid's one item centred both ways (CssGrid neither stretches
          // its one row to the box nor centres across, so a Center, INV-051)
          // and sized to its content (`fit-content`): a total longer than
          // the box (1e308 in compact form is 309 characters, no break
          // opportunity in it, UAX #14 LB25) keeps its one line and
          // overflows on both sides, as a centred grid item does.
          child: Center(
            child: CssFitContent(
              alignment: Alignment.center,
              // Its `<div>` of two block lines, `text-center`.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fmtValue(total, switch (format) {
                      A2uiValueFormat.currency => A2uiValueFormat.currency,
                      A2uiValueFormat.percent => A2uiValueFormat.percent,
                      _ => A2uiValueFormat.compact,
                    }, unit),
                    textAlign: TextAlign.center,
                    style: playgroundText(
                      20,
                      weight: FontWeight.w600,
                      trackingEm: -.025,
                      color: tokens.foreground,
                      tabular: true,
                    ),
                  ),
                  Text(
                    view.centerLabel ?? 'Total',
                    textAlign: TextAlign.center,
                    style: playgroundText(11, color: tokens.mutedForeground),
                  ),
                ],
              ),
            ),
          ),
        )
      : null;
  final pie = SizedBox(
    width: size,
    height: size,
    child: PlaygroundPlot(
      width: size,
      height: size,
      label: view.title ?? 'Pie chart',
      columns: const ['label', 'value', 'share'],
      rows: [
        for (final r in rows)
          [r.label, fmtValue(r.value, format, unit), share(r.value)],
      ],
      underlay: centre,
      // The slices (the points' data) are made in the definition's
      // `useMemo`, on `[rows, labels, donut, format, unit]`, `rows` on
      // `props.data` (charts.tsx:527-589): a record compares its fields
      // with `==`, the data list by identity, as `Object.is` does.
      rowsKey: (view.data, donut, format, unit),
      scene: (box, style) => PieScene(
        size: box,
        style: style,
        rows: rows,
        colors: sliceColors,
        donut: donut,
        format: format,
        unit: unit,
      ),
    ),
  );
  // `ul grid gap-1.5`: a CSS grid of one column, a row per slice.
  final list = CssGrid(
    columns: const GridColumns.tracks([GridTrack(fraction: 1)]),
    rowGap: 6,
    children: [
      for (var i = 0; i < rows.length; i++)
        _PieListItem(
          tokens: tokens,
          color: paletteAt(tokens, i),
          label: rows[i].label,
          value: fmtValue(
            rows[i].value,
            format == A2uiValueFormat.currency
                ? A2uiValueFormat.currency
                : A2uiValueFormat.compact,
            format == A2uiValueFormat.currency ? null : unit,
          ),
          share: share(rows[i].value),
        ),
    ],
  );
  return PlaygroundChartFrame(
    title: view.title,
    subtitle: view.subtitle,
    empty: rows.isEmpty || total <= 0,
    child: guardChart(
      // `flex flex-wrap items-center gap-x-6 gap-y-4`.
      () => CssFlex(
        flex: const A2uiFlexStyle(
          direction: Axis.horizontal,
          wrap: A2uiWrap.wrap,
          align: A2uiAlign.center,
          columnGap: 24,
          rowGap: 16,
        ),
        children: [
          CssFlexItem(style: const A2uiFlexItemStyle(shrink: 0), child: pie),
          CssFlexItem(
            style: const A2uiFlexItemStyle(
              grow: 1,
              basis: A2uiLength.zero,
              minWidth: A2uiPx(180),
            ),
            child: list,
          ),
        ],
      ),
    ),
  );
}

/// A row of the PieChart's list: `flex min-w-0 items-center gap-2
/// text-[12px]`, a swatch, the label (muted, cut), the value and the share
/// (44px, right-aligned).
class _PieListItem extends StatelessWidget {
  const _PieListItem({
    required this.tokens,
    required this.color,
    required this.label,
    required this.value,
    required this.share,
  });

  final A2uiPlaygroundTokens tokens;
  final Color color;
  final String label;
  final String value;
  final String share;

  @override
  Widget build(BuildContext context) => CssFlex(
    flex: const A2uiFlexStyle(
      direction: Axis.horizontal,
      align: A2uiAlign.center,
      columnGap: 8,
    ),
    children: [
      CssFlexItem(
        style: const A2uiFlexItemStyle(shrink: 0),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
      CssFlexItem(
        style: const A2uiFlexItemStyle(
          grow: 1,
          basis: A2uiLength.zero,
          minWidth: A2uiLength.zero,
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: playgroundText(12, color: tokens.mutedForeground),
        ),
      ),
      Text(
        value,
        maxLines: 1,
        softWrap: false,
        style: playgroundText(
          12,
          color: tokens.foreground.withValues(alpha: tokens.foreground.a * .9),
          tabular: true,
        ),
      ),
      CssFlexItem(
        style: const A2uiFlexItemStyle(width: A2uiPx(44)),
        child: Text(
          share,
          textAlign: TextAlign.right,
          maxLines: 1,
          softWrap: false,
          style: playgroundText(
            12,
            color: tokens.mutedForeground,
            tabular: true,
          ),
        ),
      ),
    ],
  );
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/charts.tsx
