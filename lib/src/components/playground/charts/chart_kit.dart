// The playground's chart kit: a port of `chart-kit.tsx` (MIT, (c) Atai
// Barkai) for the playground's charts: the data guards, the palette, the
// frame (card, title, legend, empty and waiting states) and the theme of
// the plot (axis text, grid), with TanStack Charts' tooltip
// (`@tanstack/charts` 1.1.0, MIT, (c) Tanner Linsley).

import 'dart:math' as math;

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart'
    show FocusRing;
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_guides.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/format/chart_format.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_grid.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/functions/validators.dart';
import 'package:a2ui_kit/src/theme/chart_colors.dart';
import 'package:a2ui_kit/src/theme/playground_tokens.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/widgets.dart';

/// One cartesian row: `{x, y, series?}`.
@immutable
class ChartRow {
  /// A row.
  const ChartRow(this.x, this.y, [this.series]);

  /// The x value: a string or a finite number.
  final Object x;

  /// The y value.
  final double y;

  /// The series, or null for the default one.
  final String? series;

  /// The x as the chart's categories read it (JavaScript's `String(x)`).
  String get xText => jsText(x);
}

/// A row's field, read through a binding.
Object? rowField(Map<Object?, Object?> row, String key) =>
    ComponentProps.unwrap(row[key]);

/// Whether [value] is a finite number (`isNum`).
bool isChartNumber(Object? value) => value is num && value.isFinite;

/// The playground's `cleanRows`: the rows of [data] with a finite `y` and
/// a string or finite `x`; anything partial (a streaming row) or malformed
/// is dropped.
List<ChartRow> cleanRows(Object? data) {
  if (data is! List) return const [];
  return [
    for (final raw in data)
      if (ComponentProps.unwrap(raw) case final Map<Object?, Object?> row)
        if (rowField(row, 'y') case final num y when y.isFinite)
          if (rowField(row, 'x') case final Object x
              when x is String || (x is num && x.isFinite))
            ChartRow(x, y.toDouble(), switch (rowField(row, 'series')) {
              final String s when s.isNotEmpty => s,
              _ => null,
            }),
  ];
}

/// The playground's `pickRows`: the object rows of [data] that [guard]
/// turns into a value.
List<T> pickRows<T>(
  Object? data,
  T? Function(Map<Object?, Object?> row) guard,
) {
  if (data is! List) return const [];
  return [
    for (final raw in data)
      if (ComponentProps.unwrap(raw) case final Map<Object?, Object?> row)
        ?guard(row),
  ];
}

/// The series name of a row without one (`SERIES_FALLBACK`).
const String kSeriesFallback = 'Value';

/// The playground's `seriesOf`, with the fallback name: each series once,
/// in the order it first appears.
List<String> seriesNames(Iterable<String?> series) => [
  ...{for (final name in series) name ?? kSeriesFallback},
];

/// The categories of [rows] in the order they first appear (`xDomain`).
List<String> xDomainOf(Iterable<ChartRow> rows) => [
  ...{for (final row in rows) row.xText},
];

/// The playground palette colour at [index] (`paletteAt`), wrapping.
Color paletteAt(A2uiPlaygroundTokens tokens, int index) {
  final palette = tokens.chart;
  return palette[(index % palette.length + palette.length) % palette.length];
}

/// The colour of each series name, after `useStableSeries`: the palette in
/// order; with [highlight] naming a series, that one takes the first
/// colour and the others the muted greys.
List<Color> seriesColors(
  A2uiPlaygroundTokens tokens,
  List<String> names,
  String? highlight,
) {
  final on = highlight != null && names.contains(highlight) ? highlight : null;
  return [
    for (var i = 0; i < names.length; i++)
      if (on == null)
        paletteAt(tokens, i)
      else if (names[i] == on)
        paletteAt(tokens, 0)
      else
        tokens.charts.muteAt(i),
  ];
}

/// The hidden table of cartesian [rows]: one row per x, one column per
/// series, the values in [format] with [unit].
(List<String>, List<List<String>>) xyTable(
  List<ChartRow> rows,
  List<String> names,
  A2uiValueFormat? format,
  String? unit,
) {
  final xs = xDomainOf(rows);
  final cells = {
    for (final r in rows)
      (r.xText, r.series ?? kSeriesFallback): fmtValue(r.y, format, unit),
  };
  return (
    ['x', ...names],
    [
      for (final x in xs) [x, for (final name in names) cells[(x, name)] ?? ''],
    ],
  );
}

/// A legend entry per series: [names] in [colors].
List<LegendItem> legendItems(List<String> names, List<Color> colors) => [
  for (var i = 0; i < names.length; i++) LegendItem(names[i], colors[i]),
];

/// One entry of a chart legend.
@immutable
class LegendItem {
  /// An entry: [label], its swatch [color] and an optional [value].
  const LegendItem(this.label, this.color, [this.value]);

  /// The name.
  final String label;

  /// The swatch.
  final Color color;

  /// A value after the name, or null.
  final String? value;
}

/// The playground's chart `Legend`: wrapping entries 12px apart (4px
/// between lines), each an 8px swatch with 3px corners, then the name
/// (11.5px, muted, cut with an ellipsis) and its value.
class ChartLegend extends StatelessWidget {
  /// A legend of [items].
  const ChartLegend({required this.items, super.key});

  /// The entries.
  final List<LegendItem> items;

  @override
  Widget build(BuildContext context) {
    final tokens = playgroundTokens(context);
    return CssFlex(
      flex: const A2uiFlexStyle(
        direction: Axis.horizontal,
        wrap: A2uiWrap.wrap,
        align: A2uiAlign.center,
        columnGap: 12,
        rowGap: 4,
      ),
      children: [
        for (final item in items)
          // `inline-flex min-w-0 items-center gap-1.5`.
          CssFlexItem(
            style: const A2uiFlexItemStyle(minWidth: A2uiLength.zero),
            child: CssFlex(
              flex: const A2uiFlexStyle(
                direction: Axis.horizontal,
                align: A2uiAlign.center,
                columnGap: 6,
              ),
              box: const A2uiBoxStyle(fill: false),
              children: [
                CssFlexItem(
                  style: const A2uiFlexItemStyle(shrink: 0),
                  child: _Swatch(color: item.color),
                ),
                CssFlexItem(
                  style: const A2uiFlexItemStyle(minWidth: A2uiLength.zero),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: playgroundText(11.5, color: tokens.mutedForeground),
                  ),
                ),
                if (item.value != null)
                  Text(
                    item.value!,
                    style: playgroundText(
                      11.5,
                      color: tokens.foreground.withValues(
                        alpha: tokens.foreground.a * .85,
                      ),
                      tabular: true,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

/// The playground's `ChartFrame`: a card (16px across, 14px above, 12px
/// below; contents 12px apart; anything leaving it clipped inside its
/// border, the tooltip included) with the
/// title (13.5px semibold, one line) and subtitle (11.5px, muted), the
/// legend beside them (only with more than one entry) or [aside] in its
/// place, then the chart, or the empty state, and the [footer].
class PlaygroundChartFrame extends StatelessWidget {
  /// A frame around [child].
  const PlaygroundChartFrame({
    required this.child,
    this.title,
    this.subtitle,
    this.legend = const [],
    this.aside,
    this.footer,
    this.empty = false,
    super.key,
  });

  /// The title, or null.
  final String? title;

  /// The subtitle, or null.
  final String? subtitle;

  /// The legend's entries; it shows when there is more than one.
  final List<LegendItem> legend;

  /// What stands beside the title in place of the legend.
  final Widget? aside;

  /// What follows the chart, or null.
  final Widget? footer;

  /// Whether the chart has no data: the empty state shows instead.
  final bool empty;

  /// The chart.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = playgroundTokens(context);
    final showLegend = legend.length > 1;
    final hasTitle = title != null && title!.isNotEmpty;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    final side = aside ?? (showLegend ? ChartLegend(items: legend) : null);
    final card = playgroundCardDecoration(tokens);
    // `overflow-hidden` clips at the padding box: inside the border, each
    // corner's radius less the border's width (CSS Overflow 3, 3.1; CSS
    // Backgrounds 3, 5.3), so nothing paints over the border. It clips
    // every descendant whose containing block lies inside the figure,
    // TanStack's tooltip included, whose containing block is the chart's
    // container (`position: relative`, dist/renderer.js:90-96), the
    // playground setting no `portal` (dist/tooltip.js:159-196).
    final border = card.border!.top.width;
    return Container(
      decoration: card,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          math.max(0, tokens.radius - border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: tokens.chartInk),
            // `flex flex-col gap-3`.
            child: CssFlex(
              flex: const A2uiFlexStyle(rowGap: 12),
              children: [
                if (hasTitle || hasSubtitle || side != null)
                  CssFlex(
                    flex: const A2uiFlexStyle(
                      direction: Axis.horizontal,
                      wrap: A2uiWrap.wrap,
                      justify: A2uiJustify.spaceBetween,
                      align: A2uiAlign.start,
                      columnGap: 16,
                      rowGap: 6,
                    ),
                    children: [
                      CssFlexItem(
                        style: const A2uiFlexItemStyle(
                          minWidth: A2uiLength.zero,
                        ),
                        // `<div class="min-w-0">`: a block of two block lines,
                        // not a flex box.
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasTitle)
                              Semantics(
                                header: true,
                                child: Text(
                                  title!,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: playgroundText(
                                    13.5,
                                    weight: FontWeight.w600,
                                    trackingEm: -.025,
                                    color: tokens.foreground,
                                  ),
                                ),
                              ),
                            if (hasSubtitle)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  subtitle!,
                                  style: playgroundText(
                                    11.5,
                                    height: 1.375,
                                    color: tokens.mutedForeground,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (side != null)
                        CssFlexItem(
                          style: const A2uiFlexItemStyle(
                            minWidth: A2uiLength.zero,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: side,
                          ),
                        ),
                    ],
                  ),
                if (empty) const ChartEmptyState() else child,
                if (footer != null && !empty) footer!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The playground chart's `EmptyState`: a 144px well (3% ink, a hairline,
/// 10px corners) with a pulsing bar and [label] (12px, muted) in its
/// middle.
class ChartEmptyState extends StatelessWidget {
  /// An empty state saying [label].
  const ChartEmptyState({this.label = 'No data yet', super.key});

  /// The text: "No data yet", or "Waiting for complete data".
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = playgroundTokens(context);
    // `a2-well grid h-36 place-items-center`: one item centred both ways in
    // a 144px box (CssGrid neither stretches its one row to the box nor
    // centres across, so the box's own alignment).
    return Container(
      height: 144,
      decoration: BoxDecoration(
        color: tokens.ink.withValues(alpha: .03),
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      // `flex items-center gap-2`, centred in the well.
      child: CssFlex(
        flex: const A2uiFlexStyle(
          direction: Axis.horizontal,
          align: A2uiAlign.center,
          columnGap: 8,
        ),
        box: const A2uiBoxStyle(fill: false),
        children: [
          const CssFlexItem(
            style: A2uiFlexItemStyle(shrink: 0),
            child: ChartShimmer(width: 40, height: 6),
          ),
          Text(label, style: playgroundText(12, color: tokens.mutedForeground)),
        ],
      ),
    );
  }
}

/// The playground's `.a2-shimmer` bar: the shimmer colour, fully rounded,
/// its opacity pulsing between 1 and .5 every second (transitions.dev's
/// skeleton pulse). Still under reduced motion.
class ChartShimmer extends StatefulWidget {
  /// A bar [width] wide (the width offered when null) and [height] tall.
  const ChartShimmer({required this.height, this.width, super.key});

  /// The width, or null to fill.
  final double? width;

  /// The height.
  final double height;

  /// One pulse.
  static const Duration period = Duration(milliseconds: 1000);

  @override
  State<ChartShimmer> createState() => _ChartShimmerState();
}

class _ChartShimmerState extends State<ChartShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: ChartShimmer.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) {
      _pulse
        ..stop()
        ..value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = playgroundTokens(context).charts.shimmer;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        // 1 at the ends, .5 halfway, eased in and out (`t-skel-pulse`).
        final t = _pulse.value;
        final half = t < .5 ? t * 2 : (1 - t) * 2;
        final opacity = 1 - .5 * Curves.easeInOut.transform(half);
        return Opacity(opacity: opacity, child: child);
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(widget.height / 2),
        ),
      ),
    );
  }
}

/// The playground's `ChartBoundary`: [build] the chart, or, when its data
/// cannot be drawn yet (a stream cut short), "Waiting for complete data".
/// New props get a fresh attempt.
Widget guardChart(Widget Function() build) {
  try {
    return build();
  } on Object {
    return const ChartEmptyState(label: 'Waiting for complete data');
  }
}

/// The text and colours of the playground's chart scenes: TanStack's labels
/// in the surface's font family (SVG text with `font-family="inherit"`,
/// `@tanstack/charts` 1.1.0 `dist/svg-renderer.js:70`) and the colours of
/// the playground's `THEME`.
class PlaygroundChartStyle {
  /// The style of [tokens] in the ambient [base] text style.
  PlaygroundChartStyle(this.tokens, TextStyle base, this.textScaler)
    : text = TanstackText(
        textScaler: textScaler,
        fontFamily: base.fontFamily,
        fontFamilyFallback: base.fontFamilyFallback,
      );

  /// The tokens.
  final A2uiPlaygroundTokens tokens;

  /// The text scale.
  final TextScaler textScaler;

  /// Measures and paints the scenes' labels.
  final TanstackText text;

  /// Tick labels: `theme.muted` at `fillOpacity` .68.
  // @tanstack/charts 1.1.0 dist/scene.js:1218-1221
  Color get tickColor {
    final muted = tokens.charts.muted;
    return muted.withValues(alpha: muted.a * .68);
  }

  /// Axis titles: `theme.foreground` at `fillOpacity` .76.
  // @tanstack/charts 1.1.0 dist/scene.js:998-1001, 1082-1085
  Color get titleColor {
    final foreground = tokens.charts.foreground;
    return foreground.withValues(alpha: foreground.a * .76);
  }

  /// The crosshair: `theme.foreground` at `strokeOpacity` .35.
  // @tanstack/charts 1.1.0 dist/crosshair.js:79-86 (`resolveRuleStyle`)
  Color get crosshairColor {
    final foreground = tokens.charts.foreground;
    return foreground.withValues(alpha: foreground.a * .35);
  }
}

/// A playground chart's drawing (TanStack's `<Chart>` in a `Plot`): the
/// interactive [ChartPlot] of [scene] with the playground's tooltip, read
/// by screen readers as an image named [label] followed by a table of the
/// data ([columns], [rows]).
class PlaygroundPlot extends StatelessWidget {
  /// A drawing [height] pixels tall.
  const PlaygroundPlot({
    required this.height,
    required this.label,
    required this.scene,
    required this.columns,
    required this.rows,
    this.width,
    this.underlay,
    this.rowsKey,
    super.key,
  });

  /// What sits over the drawing and under the tooltip
  /// ([ChartPlot.underlay]), or null.
  final Widget? underlay;

  /// What the chart's points are drawn for ([ChartPlot.rowsKey]).
  final Object? rowsKey;

  /// The height in pixels.
  final double height;

  /// The width, or null for the width offered.
  final double? width;

  /// The chart's name (`ariaLabel`).
  final String label;

  /// Builds the scene for a size.
  final PlotScene Function(Size size, PlaygroundChartStyle style) scene;

  /// The data table's column names.
  final List<String> columns;

  /// The data table's rows.
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final style = PlaygroundChartStyle(
      playgroundTokens(context),
      DefaultTextStyle.of(context).style,
      MediaQuery.textScalerOf(context),
    );
    // TanStack's SVG is `role="img"` named by `ariaLabel`
    // (`@tanstack/charts` 1.1.0 `dist/svg-renderer.js:25`); the data
    // follows as hidden rows (port/inventory.tsv INV-030).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Semantics(
          image: true,
          label: label,
          child: ExcludeSemantics(
            child: ChartPlot(
              height: math.max(0, height),
              width: width,
              interaction: ChartInteraction.tanstack,
              fallbackWidth: kTanstackFallbackWidth,
              // The user agent's outline round the focused `<svg
              // tabindex=0>`, which sets no focus style (@tanstack/charts
              // 1.1.0 dist/svg-renderer.js:25; RULEBOOK section 2;
              // port/inventory.tsv INV-049).
              outline: const FocusRing(
                visible: true,
                offset: 0,
                color: A2uiColorToken.outlineRing,
                child: SizedBox.expand(),
              ),
              scene: (size) => scene(size, style),
              underlay: underlay,
              rowsKey: rowsKey,
              tooltipBuilder: (context, content) =>
                  PlaygroundChartTooltip(content: content),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: ChartTableSemantics(columns: columns, rows: rows),
        ),
      ],
    );
  }
}

/// The playground chart tooltip: TanStack's built-in structured tooltip in
/// the playground's `TOOLTIP_VARS` chrome (the tooltip colours, a 1px
/// border, 10px corners, its shadow, 8px by 10px padding, 500 11.5px/1.45
/// text, at most 240px wide, as wide as its content).
///
/// An optional title (weight 650, 4.8px above the rows), then one CSS grid
/// per row: `.55rem minmax(0,1fr) auto` with `.4rem` between columns, a
/// swatch (8.8px, 2.4px corners, a 1px 12% black inset ring) or an empty
/// cell, the label (it wraps) and the value (right-aligned, tabular, on one
/// line). An active row (a stack's Total) is bold on a 12% tint of the
/// text colour that reaches 2px past it. Rows have no gap. The rem is taken
/// as 16px.
// @tanstack/charts 1.1.0 dist/tooltip.js:302-326 (`tooltipCardStyle`,
// `createTooltip`), 504-544 (`paintStructuredTooltip`) and 574-581
// (`createTooltipSwatch`); chart-kit.tsx `TOOLTIP_VARS`
class PlaygroundChartTooltip extends StatelessWidget {
  /// A tooltip showing [content].
  const PlaygroundChartTooltip({required this.content, super.key});

  /// What it shows.
  final ChartTooltipContent content;

  /// The rem the tooltip's lengths are written in.
  static const double _rem = 16;

  @override
  Widget build(BuildContext context) {
    final tokens = playgroundTokens(context);
    final colors = tokens.charts;
    final foreground = colors.tooltipForeground;
    final title = content.title;
    final hasTitle = title != null && title.isNotEmpty;
    // An absolutely placed block: as wide as its content, at most 240px.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colors.tooltipBackground,
            border: Border.all(color: colors.tooltipBorder),
            borderRadius: BorderRadius.circular(10),
            boxShadow: colors.tooltipShadow,
          ),
          child: DefaultTextStyle.merge(
            style: playgroundText(
              11.5,
              weight: FontWeight.w500,
              height: 1.45,
              color: foreground,
            ),
            // The tooltip's block children: the title, then the rows.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasTitle)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: content.rows.isEmpty ? 0 : .3 * _rem,
                    ),
                    // `display:flex; align-items:center; gap:.4rem`.
                    child: CssFlex(
                      flex: const A2uiFlexStyle(
                        direction: Axis.horizontal,
                        align: A2uiAlign.center,
                        columnGap: .4 * _rem,
                      ),
                      children: [
                        CssFlexItem(
                          style: const A2uiFlexItemStyle(
                            minWidth: A2uiLength.zero,
                          ),
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight(650)),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final row in content.rows)
                  _TooltipRow(row: row, colors: colors),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of [PlaygroundChartTooltip]: TanStack's `ts-chart-tooltip__row`
/// grid.
class _TooltipRow extends StatelessWidget {
  const _TooltipRow({required this.row, required this.colors});

  final ChartTooltipRow row;
  final A2uiChartColors colors;

  @override
  Widget build(BuildContext context) {
    const rem = PlaygroundChartTooltip._rem;
    final color = row.color;
    final grid = CssGrid(
      columns: const GridColumns.tracks([
        GridTrack(pixels: .55 * rem),
        GridTrack(fraction: 1),
        GridTrack.auto(),
      ]),
      columnGap: .4 * rem,
      align: A2uiAlign.center,
      children: [
        if (color == null)
          const SizedBox.shrink()
        else
          // `display:block` in its cell.
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: .55 * rem,
              height: .55 * rem,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(.15 * rem),
                // `box-shadow: inset 0 0 0 1px rgb(0 0 0/.12)` (dist/
                // tooltip.js:578): with no blur and no offset, a 1px spread
                // inside the box is a 1px inner border, which is drawn as
                // one (INV-052).
                border: Border.all(
                  color: A2uiKitScope.themeOf(
                    context,
                  ).color(A2uiColorToken.tanstackTooltipSwatchRing),
                ),
              ),
            ),
          ),
        Text(row.label),
        // `white-space: nowrap` (dist/tooltip.js:536): its min-content is the
        // whole line, which the auto track starts from; a `softWrap: false`
        // Text's would be its longest word.
        IntrinsicWidth(
          child: Text(
            row.value,
            textAlign: TextAlign.right,
            softWrap: false,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
    if (!row.active) return grid;
    final tint =
        DefaultTextStyle.of(context).style.color ?? colors.tooltipForeground;
    return DefaultTextStyle.merge(
      style: const TextStyle(fontWeight: FontWeight.w700),
      child: CustomPaint(
        painter: _ActiveRowPainter(tint.withValues(alpha: tint.a * .12)),
        child: grid,
      ),
    );
  }
}

/// The active row's look: `background: color-mix(currentColor 12%)` with
/// `.2rem` corners, and `box-shadow: 0 0 0 2px` of the same colour round
/// it: one rounded box 2px larger than the row, in that colour.
class _ActiveRowPainter extends CustomPainter {
  _ActiveRowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = .2 * PlaygroundChartTooltip._rem;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(2),
        const Radius.circular(radius + 2),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_ActiveRowPainter oldDelegate) =>
      oldDelegate.color != color;
}

// PORT STATUS: confidence=medium todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/chart-kit.tsx
