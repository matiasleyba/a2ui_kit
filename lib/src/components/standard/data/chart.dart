// CopilotKit's standard `Chart`, after its React renderer (`Chart.tsx`) and
// the shared helpers (`chart-config.ts`; MIT, (c) Atai Barkai), drawn as
// recharts 3.10.1 draws it (MIT, (c) Recharts Group; the version
// CopilotKit's lockfile pins, pnpm-lock.yaml:3251). The geometry is ported
// from recharts' published `es6/` source, each block naming its file and
// lines; the shared ports are in `foundation/chart/recharts.dart`,
// `scale.dart`, `curve.dart` and `arc.dart`.

import 'dart:math' as math;

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart'
    show FocusRing;
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/chart/arc.dart';
import 'package:a2ui_kit/src/foundation/chart/curve.dart';
import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:a2ui_kit/src/foundation/chart/recharts.dart';
import 'package:a2ui_kit/src/foundation/chart/scale.dart';
import 'package:a2ui_kit/src/foundation/css/css_color.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/format/chart_format.dart';
import 'package:a2ui_kit/src/foundation/js_object_keys.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/layout/fit_content.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/functions/calc.dart';
import 'package:a2ui_kit/src/functions/validators.dart';
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A series of a standard Chart: the data field it reads, its name and its
/// colour.
@immutable
class StandardChartSeries {
  /// A series.
  const StandardChartSeries(this.key, this.label, this.color);

  /// The field of each row.
  final String key;

  /// The name (the key unless the series gives a label).
  final String label;

  /// The colour, or null when the series' `color` is one the browser cannot
  /// read: SVG then fills with its initial black and strokes nothing.
  final Color? color;

  @override
  bool operator ==(Object other) =>
      other is StandardChartSeries &&
      other.key == key &&
      other.label == label &&
      other.color == color;

  @override
  int get hashCode => Object.hash(key, label, color);

  @override
  String toString() => 'StandardChartSeries($key, $label, $color)';
}

/// The chart palette of [theme] (`--a2ui-chart-1` to `-6`).
List<Color> standardChartPalette(A2uiKitTheme theme) => [
  for (final token in const [
    A2uiColorToken.chart1,
    A2uiColorToken.chart2,
    A2uiColorToken.chart3,
    A2uiColorToken.chart4,
    A2uiColorToken.chart5,
    A2uiColorToken.chart6,
  ])
    theme.color(token),
];

/// CopilotKit's `normalizeSeries`: the [series] prop, each a key or a
/// `{key, label?, color?}`, or, when it is empty, every number field of
/// the first row except [xKey], in JavaScript's key order (`Object.keys`:
/// integer-like keys first). A series' colour is its `color` (a text colour
/// token or a CSS colour), else the palette colour of its place in the
/// list.
// packages/react-core/src/v2/generative-ui/standard/Chart.tsx:73-96
List<StandardChartSeries> normalizeChartSeries(
  List<Object?> series,
  List<Map<Object?, Object?>> data,
  String? xKey,
  A2uiKitTheme theme,
) {
  final palette = standardChartPalette(theme);
  final List<Object?> list;
  if (series.isEmpty && data.isNotEmpty) {
    final first = data.first;
    list = [
      for (final key in jsObjectKeys(first))
        if (key is String &&
            key != xKey &&
            ComponentProps.unwrap(first[key]) is num)
          key,
    ];
  } else {
    list = series;
  }
  final out = <StandardChartSeries>[];
  for (var index = 0; index < list.length; index++) {
    final String key;
    String? label;
    String? color;
    switch (ComponentProps.unwrap(list[index])) {
      case final String item:
        key = item;
      case final Map<Object?, Object?> item:
        final k = ComponentProps.unwrap(item['key']);
        if (k is! String) continue;
        key = k;
        final l = ComponentProps.unwrap(item['label']);
        label = l is String && l.isNotEmpty ? l : null;
        final c = ComponentProps.unwrap(item['color']);
        color = c is String && c.isNotEmpty ? c : null;
      default:
        continue;
    }
    out.add(
      StandardChartSeries(
        key,
        label ?? key,
        color == null
            ? palette[index % palette.length]
            : theme.textColor(color),
      ),
    );
  }
  return out;
}

/// A row's own field, read through a binding, as CopilotKit's table and
/// series reads it (`row[key]`, Chart.tsx:82, :449).
Object? _field(Map<Object?, Object?> row, String? key) =>
    key == null ? null : ComponentProps.unwrap(row[key]);

/// Whether [row] has the field [key] (JavaScript's `undefined` when not).
bool _has(Map<Object?, Object?> row, String? key) =>
    key != null && row.containsKey(key);

/// A value read by recharts' `getValueByDataKey`: `defined` is false for
/// JavaScript's `undefined`.
typedef _JsRead = ({bool defined, Object? value});

const _JsRead _undefined = (defined: false, value: null);

/// The row's own field [key] (`row[key]`) as a read.
_JsRead _own(Map<Object?, Object?> row, String? key) =>
    _has(row, key) ? (defined: true, value: _field(row, key)) : _undefined;

/// recharts' `getValueByDataKey(row, key)`, which reads with es-toolkit's
/// `get`: the row's own field; for a key the row lacks that holds `.`, `[`
/// or `]`, the field at that path; never `__proto__`.
///
/// A key naming a member every JavaScript object inherits (`constructor`,
/// `toString`) reads that inherited function in recharts; here it reads as
/// missing (INV-047).
// recharts 3.10.1 es6/util/ChartUtils.js:13-24; es-toolkit 1.43.0
// dist/compat/object/get.mjs:6-75, dist/_internal/isUnsafeProperty.mjs
_JsRead _read(Map<Object?, Object?> row, String? key) {
  if (key == null || key == '__proto__') return _undefined;
  if (row.containsKey(key)) {
    return (defined: true, value: ComponentProps.unwrap(row[key]));
  }
  if (!rechartsIsDeepKey(key)) return _undefined;
  final path = rechartsToPath(key);
  if (path.isEmpty) return _undefined;
  Object? current = row;
  for (final segment in path) {
    if (current == null || segment == '__proto__') return _undefined;
    switch (current) {
      case final Map<Object?, Object?> map:
        if (!map.containsKey(segment)) return _undefined;
        current = ComponentProps.unwrap(map[segment]);
      case final List<Object?> list:
        final index = segment == 'length' ? null : int.tryParse(segment);
        if (segment == 'length') {
          current = list.length;
        } else if (index != null &&
            '$index' == segment &&
            index >= 0 &&
            index < list.length) {
          current = ComponentProps.unwrap(list[index]);
        } else {
          return _undefined;
        }
      case final String text when segment == 'length':
        current = text.length;
      default:
        return _undefined;
    }
  }
  return (defined: true, value: current);
}

/// [_read]'s value, null for `undefined` too.
Object? _get(Map<Object?, Object?> row, String? key) => _read(row, key).value;

/// JavaScript's `"".concat(value)` of a read: "undefined" for a missing
/// one, "null" for null.
String _concat(_JsRead read) {
  if (!read.defined) return 'undefined';
  return read.value == null ? 'null' : jsText(read.value);
}

/// JavaScript's strict equality (`===`) of two JSON reads: numbers by value,
/// text by its code units, booleans, null, and `undefined` only to itself.
bool _strictEquals(_JsRead a, _JsRead b) {
  if (a.defined != b.defined) return false;
  if (!a.defined) return true;
  final x = a.value;
  final y = b.value;
  if (x == null || y == null) return x == null && y == null;
  if (x is num && y is num) return x == y;
  if (x is String && y is String) return x == y;
  if (x is bool && y is bool) return x == y;
  return identical(x, y);
}

/// recharts' `makeNumber`: a number, or text `Number()` reads, when finite.
// recharts 3.10.1 es6/state/selectors/axisSelectors.js:383-391
double? _makeNumber(Object? value) {
  final number = switch (value) {
    final num n => n.toDouble(),
    final String s => jsNumberOf(s),
    _ => null,
  };
  return number != null && number.isFinite ? number : null;
}

/// JavaScript's `+x` of a JSON value: numbers, text `Number()` reads,
/// booleans, an array through its `String()` (`[5]` is 5, `[]` is 0), NaN
/// for anything else.
double _jsPlus(Object? value) => switch (value) {
  null => double.nan,
  final num n => n.toDouble(),
  final String s => jsNumberOf(s),
  final bool b => b ? 1.0 : 0.0,
  final List<Object?> list => jsNumberOf(jsText(list)),
  _ => double.nan,
};

/// A value as d3's continuous scales read it (`+x`); null where d3 maps to
/// `unknown` (recharts then has no coordinate).
// d3-scale 4.0.2 src/continuous.js:85-87 (`scale(x)`: `x == null ||
// isNaN(x = +x) ? unknown`), src/number.js:1-3; recharts 3.10.1
// es6/util/scale/RechartsScale.js:44-48
double? _scaleInput(Object? value) {
  final number = _jsPlus(value);
  return number.isNaN ? null : number;
}

/// `Number(getValueByDataKey(row, key, 0))`, a stack's value: 0 for a
/// missing field, NaN for one `Number()` cannot read (null is 0).
// recharts 3.10.1 es6/util/ChartUtils.js:341-347
double _stackInput(Map<Object?, Object?> row, String key) {
  final read = _read(row, key);
  if (!read.defined || read.value == null) return 0;
  return _jsPlus(read.value);
}

/// The text a recharts `Text` writes for [value] (`children.toString()`, or
/// a number's `String()`).
String _textOf(Object? value) => jsText(value);

/// The text React writes for a tooltip value without a formatter: a
/// number's `String()`, text as is, nothing for a boolean or null (React
/// renders neither); an array whose first two items are text or numbers
/// joined with " ~ " (`defaultFormatter`), any other array item by item.
// recharts 3.10.1 es6/component/DefaultTooltipContent.js:21-23
// (`defaultFormatter`), :117-118 (the value's `<span>`)
String _reactChild(Object? value) {
  bool numOrStr(Object? v) => v is String || (v is num && !v.isNaN);
  return switch (value) {
    null || bool() => '',
    final List<Object?> list
        when list.length >= 2 && numOrStr(list[0]) && numOrStr(list[1]) =>
      list.map((v) => v == null ? '' : jsText(v)).join(' ~ '),
    final List<Object?> list => list.map(_reactChild).join(),
    _ => jsText(value),
  };
}

/// CopilotKit's standard `Chart`: a bar, line, area, scatter, pie or donut
/// chart of `data` rows, drawn as recharts 3.10.1 draws it.
///
/// - `xKey` names the category field; `series` the value fields (keys or
///   `{key, label, color}`), by default every number field of the first
///   row, in JavaScript's key order. Series take the chart colours
///   (`--a2ui-chart-1` to `-6`) in order.
/// - `chartType` (bar): bars with their value end rounded 4px (`barRadius`
///   for all four corners; none when `stacked`), 0px bars left out; 2px
///   monotone lines; areas with a 1px monotone edge over a 20% fill
///   (`stacked` stacks bars and areas; lines never stack); scatter dots;
///   pie and donut slices (`innerRadius` 0 or 55%, `outerRadius` 80%, from
///   `startAngle` 90 to `endAngle` -270, `cornerRadius`, `paddingAngle`),
///   white-edged.
/// - `layout: horizontal` lays bars from the left; the category axis is
///   then 96px wide (`yAxis.width`), else the value axis 64px. `yAxis`
///   `min` and `max` widen the value axis, whose ticks recharts makes
///   "nice" (5 of them) where an end is automatic; `yAxis.label` titles it.
///   Tick labels that would crowd are left out from the last one back; a
///   left label breaks into lines at the axis' width.
/// - `format` (number, currency, percent: fractions) and `currency` (USD)
///   format the value ticks, tooltip and labels: en-US, no decimals
///   (percent 1), compact from 10,000.
/// - `showGrid` (dashed 3 3 lines), `showLegend` (8px circles, 13px names,
///   sorted by name, centred under the chart), `showTooltip` (the category
///   over each series' value, sorted by name, beside the category, the
///   point or the slice, gliding there over 400ms), `showDots` (3px point
///   markers; a one-point line or area draws its dot anyway),
///   `showValueLabels` (11px grey values above the marks, a stack's total
///   on a stacked one; a slice's beside it, with a leader line unless
///   `showLabelLines` is false). Hovering a line or area marks its points
///   with 4px dots, tooltip or not.
/// - The keyboard is recharts': taking the focus shows the first
///   category's tooltip, ArrowLeft and ArrowRight step one category with no
///   wrap (ArrowRight steps back in the horizontal layout; a scatter steps
///   its first series' rows), Enter hides or shows it, Escape hides its box
///   until it moves; a pie's slices are a second stop for Tab.
/// - `title` (semibold, the surface's small text) heads the figure and
///   names it for screen readers; `height` (240) is the drawing's, legend
///   included.
/// - The drawing is hidden from screen readers, which read a table of the
///   data instead.
///
/// Differences from CopilotKit: recharts' geometry is ported to a
/// CustomPaint from recharts 3.10.1's published es6/ source, with d3-shape
/// 3.2.0, d3-scale 4.0.2 and d3-array 3.2.4 (INV-026). No lazy loading, so
/// no placeholder or fallback table (INV-027). A white box with the label
/// in the surface's text colour, as CopilotKit leaves it: BUG(port)
/// (INV-028). Painted text: alchemist's CI goldens draw it as black blocks
/// (INV-029). The figure is a group named by its title (the `<figure>`
/// named by its `<figcaption>`), its drawing hidden, holding the data table
/// read as CopilotKit's visually hidden `<table>`: a table, a row of column
/// headers, then a row of cells per data row; the row header
/// (`<th scope="row">`) is read as a cell, as Flutter's roles have no row
/// header (INV-034). recharts
/// places SVG text by its baseline: the font's alphabetic baseline goes
/// there, d3's cap height (0.71em) moves it, and a slice label's
/// `alignment-baseline: middle` is stood in for by centring the cap height
/// (INV-035). What leaves the chart's box, the tooltip included, is clipped
/// as CopilotKit's `overflow-x: auto` box clips it; the scrollbar it would
/// show is not drawn (INV-037). Other SVG props a row could carry (stroke,
/// opacity, …) and a row's fill on lines and areas are not honoured
/// (INV-039). A slice label has no font size of its own, so the page's
/// CSS size applies; the surface's text size stands in for it (INV-046).
/// A data key naming a member every JavaScript object inherits
/// (`constructor`, `toString`) reads as missing, where recharts reads that
/// inherited function (INV-047). recharts measures tick words in the page's
/// font at the size it last measured; the ticks' own 12px stands in for it
/// (INV-048). The browser's own focus outline shows when the focus matches
/// `:focus-visible` by Chrome's heuristic (the keyboard's focus; a press's
/// once a key is pressed): a 2px ring at offset 0 in CopilotKit's
/// `outline-ring/50`, round recharts' `<svg>` (the chart's whole box, so
/// the overflow box clips it, as in the browser), the pie's `<g>` (the
/// tight box of its slices) and TanStack's `<svg>`; `outline: auto` is the
/// browser's own drawing, so its exact width and colour differ (INV-049).
/// The legend's icon has its middle half an x-height above the entry's
/// first baseline, where CSS's `vertical-align: middle` puts it (CSS 2.1
/// section 10.8.1), the entry in the surface's font (INV-046); Flutter's
/// text API gives no x-height (`dart:ui`'s line metrics give the ascent,
/// descent and baseline only), so CSS's own value for an x-height a browser
/// can't determine, 0.5em (CSS Values 4 section 6.1.1), stands in for the
/// font's (INV-053). A
/// tooltip that shows again glides from where the last one was shown;
/// recharts first moves its hidden, emptied box (INV-050).
Widget buildChart(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = ChartProps(props);
  final theme = A2uiKitScope.themeOf(context);
  final data = [
    for (final raw in view.data)
      if (ComponentProps.unwrap(raw) case final Map<Object?, Object?> row) row,
  ];
  final series = normalizeChartSeries(view.series, data, view.xKey, theme);
  final format = standardChartFormatter(view.format, view.currency);
  final height = math.max(0, view.height).toDouble();
  final title = view.title;
  final base = DefaultTextStyle.of(context).style;
  final fontSize = base.fontSize ?? theme.typography.fontSize;
  final pie =
      view.chartType == ChartType.pie || view.chartType == ChartType.donut;
  final first = series.firstOrNull;
  final nameKey = view.xKey ?? 'name';
  final legend = view.showLegend && (pie || series.isNotEmpty)
      ? _RechartsLegend(
          // recharts 3.10.1 es6/state/selectors/pieSelectors.js:42-65
          // (`selectPieLegend`: `getTooltipNameProp` of the row's name, else
          // the data key, in the cell's fill) and the series' entries
          // (`getTooltipNameProp(name)`: Bar.js:51-65, Line.js:144-158,
          // Area.js:119-134, Scatter.js:66-80; util/ChartUtils.js:532-540),
          // sorted by `value` (`legendDefaultProps.itemSorter`, Legend.js:
          // 176, which CopilotKit's `LEGEND_PROPS` keep, Chart.tsx:46-51;
          // legendSelectors.js:6-10).
          items: rechartsSortBy(
            pie
                ? [
                    if (first != null)
                      for (var i = 0; i < data.length; i++)
                        (
                          _get(data[i], nameKey) == null
                              ? first.key
                              : _textOf(_get(data[i], nameKey)),
                          standardChartPalette(theme)[i % 6],
                        ),
                  ]
                : [
                    for (final s in series)
                      (
                        s.label,
                        s.color ?? theme.color(A2uiColorToken.svgInitialFill),
                      ),
                  ],
            (item) => item.$1,
          ),
          theme: theme,
          pie: pie,
          // The `li`'s font is the page's: the surface's stands in (INV-046).
          item: base.copyWith(fontSize: fontSize),
        )
      : null;
  // recharts' wrapper: the legend under the drawing takes its height from
  // the chart's (`appendOffsetOfLegend`, es6/util/ChartUtils.js:25-73); a
  // legend taller than the chart leaves the drawing none. CopilotKit's
  // `<div style={{minHeight: height, overflowX: "auto"}}>` (Chart.tsx:
  // 513-517) clips what leaves the chart's box, the tooltip included: a
  // non-visible `overflow-x` makes `overflow-y` compute to `auto` too (CSS
  // Overflow 3, 3.1). Its scrollbar is not drawn (INV-037).
  final drawing = ClipRect(
    child: CssFlex(
      flex: const A2uiFlexStyle(),
      box: A2uiBoxStyle(height: A2uiPx(height)),
      children: [
        CssFlexItem(
          style: const A2uiFlexItemStyle(
            grow: 1,
            basis: A2uiLength.zero,
            minHeight: A2uiLength.zero,
          ),
          child: ChartPlot(
            reveal: false,
            tooltipBuilder: view.showTooltip
                ? (context, content) =>
                      RechartsTooltip(content: content, theme: theme)
                : null,
            // Pie.js:556, :595 (`rootTabIndex: 0`): the pie's `<g>` is a
            // second stop for Tab inside the chart's `<svg>`.
            tabStops: pie && first != null ? 2 : 1,
            // The user agent's outline round the focused `<svg>` or `<g>`
            // (RULEBOOK section 2; INV-049). The `<svg>`'s lies outside the
            // chart's box, where the overflow box above clips it.
            outline: const FocusRing(
              visible: true,
              offset: 0,
              color: A2uiColorToken.outlineRing,
              child: SizedBox.expand(),
            ),
            scene: (size) {
              final style = RechartsStyle(
                theme,
                base,
                MediaQuery.textScalerOf(context),
              );
              // The chart's own box, its legend included: recharts' axis view
              // box (`selectAxisViewBox`, selectChartOffsetInternal.js:89-94)
              // and the keyboard tooltip's anchor
              // (combineCoordinateForDefaultIndex.js:19-34) use it.
              final chartSize = Size(size.width, math.max(height, size.height));
              return pie
                  ? RechartsPieScene(
                      size: size,
                      chartSize: chartSize,
                      view: view,
                      data: data,
                      series: series,
                      format: format,
                      style: style,
                      legendBelow: legend != null,
                    )
                  : RechartsScene(
                      size: size,
                      chartSize: chartSize,
                      view: view,
                      data: data,
                      series: series,
                      format: format,
                      style: style,
                    );
            },
          ),
        ),
        ?legend,
      ],
    ),
  );
  final xKey = view.xKey;
  // BUG(port): without `format`, CopilotKit's table writes `String(value)`
  // (Chart.tsx:415, :449): a missing value reads "undefined" and null
  // "null". Reproduced: `{"m": "Jan"}` under series `v` reads "v:
  // undefined".
  String cellOf(Map<Object?, Object?> row, String key) =>
      format == null ? _concat(_own(row, key)) : format(_field(row, key));
  // Chart.tsx:497-523: a `<figure>` (a block) named by its `<figcaption>`,
  // then the chart's `<div aria-hidden>` and the visually hidden `<table>`.
  return Semantics(
    container: true,
    explicitChildNodes: true,
    label: title != null && title.isNotEmpty ? title : null,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null && title.isNotEmpty)
          // The caption names the figure, so it is not read a second time.
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: fontSize * .875,
                  height: 1.429,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            ExcludeSemantics(child: drawing),
            Positioned(
              left: 0,
              top: 0,
              // Read as upstream's `<table>`: table, rows, column headers
              // and cells (RULEBOOK section 0; INV-034).
              child: ChartTableSemantics(
                table: true,
                columns: [?xKey, for (final s in series) s.label],
                rows: [
                  for (final row in data)
                    [
                      // Chart.tsx:444: `String(row[xKey] ?? "")` (jsText
                      // writes null as "").
                      if (xKey != null) jsText(_field(row, xKey)),
                      for (final s in series) cellOf(row, s.key),
                    ],
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// The text and colours of the standard Chart.
class RechartsStyle {
  /// The style of [theme] in the ambient [base] text style.
  RechartsStyle(this.theme, TextStyle base, this.textScaler)
    : _family = base.fontFamily,
      _fallback = base.fontFamilyFallback,
      _fontSize = base.fontSize ?? theme.typography.fontSize;

  /// The theme.
  final A2uiKitTheme theme;

  /// The text scale.
  final TextScaler textScaler;

  final String? _family;
  final List<String>? _fallback;
  final double _fontSize;

  TextStyle _text(double size, Color color) => TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: size,
    color: color,
  );

  /// Axis ticks: 12px in the secondary text colour (Chart.tsx:189).
  RechartsText get ticks => RechartsText(
    _text(12, theme.color(A2uiColorToken.textSecondary)),
    textScaler,
  );

  /// The value axis' title: 12px, secondary (Chart.tsx:263-273).
  RechartsText get axisTitle => ticks;

  /// Value labels: 11px (Chart.tsx:190-192) in recharts' default text fill:
  /// the label lists of bars, lines and areas give no fill
  /// (es6/component/LabelList.js:103, es6/cartesian/Bar.js:166,
  /// es6/cartesian/Line.js:243, es6/cartesian/Area.js:207), so `Text`'s
  /// `DEFAULT_FILL` paints (es6/component/Text.js:188).
  RechartsText get valueLabels => RechartsText(
    _text(11, theme.color(A2uiColorToken.rechartsTextFill)),
    textScaler,
  );

  /// Slice labels: the surface's text size, in the slice's colour.
  // Nothing sets their size: the label's props are the Pie's SVG props,
  // the sector and `stroke: 'none'` (recharts 3.10.1 es6/polar/Pie.js:
  // 216-239), CopilotKit's `label` is `true` or a function (Chart.tsx:
  // 219-225), and `Text` has no default size (es6/component/Text.js:
  // 188-200). So the `<text>` takes the page's CSS font size, which the
  // surface's stands in for (INV-046).
  RechartsText sliceLabels(Color color) =>
      RechartsText(_text(_fontSize, color), textScaler);
}

/// recharts' cartesian chart margin as CopilotKit sets it (Chart.tsx:341).
const EdgeInsets _margin = EdgeInsets.only(top: 8, right: 8);

/// The height of a recharts x axis.
// recharts 3.10.1 es6/state/selectors/axisSelectors.js:57
const double _xAxisHeight = 30;

/// recharts' y axis width when the one given is not a number
/// (`DEFAULT_Y_AXIS_WIDTH`).
// recharts 3.10.1 es6/state/selectors/axisSelectors.js:1052-1058
const double _defaultYAxisWidth = 60;

/// recharts' tick size (drawn or not, the labels keep clear of it) plus its
/// tick margin.
// recharts 3.10.1 es6/cartesian/CartesianAxis.js:68-69, :131-170
const double _tickOffset = 6 + 2;

/// The offset of recharts' `Label` (`defaultLabelProps.offset`).
// recharts 3.10.1 es6/component/Label.js:210-212
const double _labelOffset = 5;

/// The area of recharts' default scatter symbol (`implicitZAxis.range`).
// recharts 3.10.1 es6/state/selectors/axisSelectors.js:136-147
const double _scatterSymbolArea = 64;

/// A drawn standard Chart mark, for tests.
@immutable
class RechartsMark {
  /// A mark.
  const RechartsMark(this.kind, this.rect, this.series, this.value);

  /// `bar`, `dot` (a line or area marker, drawn with `showDots`) or
  /// `point` (a scatter point).
  final String kind;

  /// Its box; a dot's centre is the box's.
  final Rect rect;

  /// Its series' key.
  final String series;

  /// Its value as the row holds it (a stack's top for a stacked bar).
  final Object? value;
}

/// A text the standard Chart painted, for tests.
@immutable
class RechartsLabel {
  /// A label.
  const RechartsLabel(this.text, this.at, this.anchor, this.vertical);

  /// The text.
  final String text;

  /// Its anchor point.
  final Offset at;

  /// How it sits along x on [at].
  final RechartsTextAnchor anchor;

  /// How it sits along y on [at].
  final RechartsVerticalAnchor vertical;
}

/// A bar of a [RechartsScene], signed as recharts holds it: (x, y) is the
/// value end of a vertical bar, whose height is negative below the base.
typedef _Bar = ({
  int series,
  double x,
  double y,
  double width,
  double height,
  Object? value,
});

/// The category axis of a bar, line, area or categorical scatter chart.
///
/// Its domain is the rows' values, or the rows' indexes when there is no
/// `xKey` or a value repeats; a band scale for a bar or scatter chart and
/// a point scale for a line or area chart, over the axis' range.
// recharts 3.10.1 es6/state/selectors/axisSelectors.js:657-670
// (`computeDomainOfTypeCategory`), :806-824 (`combineAxisDomain`),
// :1177-1191 (`combineDuplicateDomain`), :1228-1305 (`combineAxisTicks`:
// half a band in), :1317-1370 (`combineGraphicalItemTicks`: the band's
// start); es6/state/selectors/combiners/combineRealScaleType.js:9-28
class _CategoryAxis {
  _CategoryAxis(
    List<Map<Object?, Object?>> data,
    String? xKey, {
    required this.band,
    required this.range0,
    required this.range1,
  }) {
    final values = [
      for (final row in data)
        if (_get(row, xKey) case final Object value
            when value is num || value is String)
          value,
    ];
    // es6/util/DataUtils.js:72-86 (`hasDuplicate`): `String(value)` as a
    // plain object's key.
    final duplicate = rechartsHasDuplicate(values.map(jsText));
    if (xKey == null || duplicate) {
      count = data.length;
      for (var i = 0; i < data.length; i++) {
        // The index domain; a tick's value is its row's own (es6/state/
        // selectors/tooltipSelectors.js:121-130), or the index without an
        // `xKey`.
        final read = xKey == null
            ? (defined: true, value: i)
            : _read(data[i], xKey);
        tickValues.add(read);
        labels.add(_concat(read));
      }
    } else {
      count = values.length;
      for (final value in values) {
        tickValues.add((defined: true, value: value));
        labels.add(jsText(value));
      }
    }
  }

  /// Each tick's value (`tooltipTicks[i].value`).
  final List<_JsRead> tickValues = [];

  /// Bands (a bar or scatter chart) or points (a line or area chart).
  final bool band;

  /// The axis' range.
  final double range0;

  /// The axis' range's end.
  final double range1;

  /// The number of ticks.
  late final int count;

  /// Each tick's text (`"".concat(value)`).
  final List<String> labels = [];

  List<String> get _domain => [for (var i = 0; i < count; i++) '$i'];

  late final BandScale _band = BandScale(_domain);
  late final PointScale _point = PointScale(_domain);

  /// The band's width (d3's `bandwidth()`; 0 for a point scale).
  double get bandwidth => band ? _band.bandwidth(range0, range1) : 0;

  /// The scale's value of tick [i]: a band's start, or the point.
  double start(int i) => band
      ? _band.start(i, range0, range1)
      : _point.position(i, range0, range1);

  /// Tick [i]'s coordinate: the band's centre, or the point.
  double tick(int i) => start(i) + bandwidth / 2;

  /// The coordinate of row [index] on a line, area or scatter chart
  /// (`getCateCoordinateOfLine`: the item tick plus half the band), or null
  /// past the ticks.
  // recharts 3.10.1 es6/util/ChartUtils.js:378-403
  double? ofRow(int index) => index < count ? tick(index) : null;
}

/// The scene of a bar, line, area or scatter standard Chart.
// The recharts 3.10.1 defaults CopilotKit doesn't pass, each ported here
// (RULEBOOK section 2; es6/ files):
// - CartesianChart (chart/CartesianChart.js:17-33): `accessibilityLayer:
//   true` (the keyboard, [step] and [keyboardLength]), `barCategoryGap:
//   '10%'`, `barGap: 4` ([rechartsBarPositions]), `stackOffset: 'none'`,
//   `reverseStackOrder: false` ([rechartsStack]); `layout` and `margin` are
//   CopilotKit's (Chart.tsx:340-341). Its tooltip is by axis for bars,
//   lines and areas, by item for scatter (BarChart.js, LineChart.js,
//   AreaChart.js, ScatterChart.js).
// - XAxis and YAxis (cartesian/XAxis.js:137-161, YAxis.js:139-163,
//   state/selectors/axisSelectors.js:50-125): `height: 30`, `interval:
//   'preserveEnd'`, `minTickGap: 5`, `tickSize: 6`, `tickMargin: 2`
//   (CartesianAxis.js:68-69), `tickCount: 5`, `allowDecimals: true`,
//   `allowDuplicatedCategory: true`, `scale: 'auto'` (bands for bars and
//   scatter, points for lines and areas), `padding` 0, the YAxis `width`
//   given to each tick's `Text` (YAxis.js:125-129) and the XAxis' own width
//   (CartesianAxis.js:318); CopilotKit passes `type`, `dataKey`, `domain`,
//   `tick`, `tickLine`, `axisLine`, `tickFormatter`, `width` and `label`.
// - CartesianGrid (cartesian/CartesianGrid.js:268-282): `syncWithTicks:
//   false` (lines at the plot's edges too), `fill: 'none'`; CopilotKit
//   passes `strokeDasharray`, `stroke`, `vertical` and `horizontal`.
// - Bar (cartesian/Bar.js:494-511): `activeBar: false`, `background:
//   false`, `minPointSize: 0` (a 0px bar is left out); a row's own fields
//   spread over its rectangle (:277-279).
// - Line (cartesian/Line.js:116-138): `activeDot: true`, `connectNulls:
//   false`, `fill: '#fff'` (the dot of a one-point line); Area
//   (cartesian/Area.js:88-110): `activeDot: true`, `strokeWidth: 1`,
//   `connectNulls: false`, `baseValue` none.
// - Dots (component/Dots.js:38-46, :65-75): drawn for a run of one point
//   even without `dot`, r 3 over the series' SVG props (a line's white
//   fill and 2px stroke; an area's 20% fill opacity, kept under
//   CopilotKit's `dot` too).
// - ActivePoints (component/ActivePoints.js:28-39): r 4, the series'
//   colour, a 2px `#fff` ring, whether or not a Tooltip is rendered.
// - Scatter (cartesian/Scatter.js:527-545): `shape: 'circle'`, no active
//   shape; the implicit ZAxis' `range: [64, 64]` (axisSelectors.js:
//   136-147); a row's own fields spread over its point (:459-478, :259).
// - Cursor (component/Cursor.js:93-97): `stroke: '#ccc'`; the band's
//   rectangle unstroked, 0.5px in (util/cursor/getCursorRectangle.js:1-10).
// - Label (component/Label.js:210-216): `offset: 5`; LabelList
//   (component/LabelList.js:47-53): the last item of an array value, only
//   text `Text` can write; a bar's label as wide as its bar
//   (cartesian/getCartesianPosition.js:63-73).
// - Text (component/Text.js:188-200): `fill: '#808080'` for value labels,
//   `capHeight: '0.71em'`, `lineHeight: '1em'`, `verticalAnchor: 'end'`,
//   words broken at a given `width`, no `maxLines`.
class RechartsScene extends PlotScene {
  /// The scene at [size], in a chart of [chartSize] (its legend included;
  /// [size] when null).
  RechartsScene({
    required this.size,
    required this.view,
    required this.data,
    required this.series,
    required this.format,
    required this.style,
    Size? chartSize,
  }) : chartSize = chartSize ?? size {
    _build();
  }

  @override
  final Size size;

  /// The chart's box: the scene and the legend under it.
  final Size chartSize;

  /// The props.
  final ChartProps view;

  /// The rows.
  final List<Map<Object?, Object?>> data;

  /// The series.
  final List<StandardChartSeries> series;

  /// The value formatter, or null.
  final String Function(Object? value)? format;

  /// The text and colours.
  final RechartsStyle style;

  /// The plot's box (recharts' chart offset).
  late Rect plot;

  /// The value axis' ticks (data values); empty without a domain.
  List<double> valueTicks = const [];

  /// The category or x axis' labels that are painted, and where.
  final List<(double, String)> categoryTicks = [];

  /// The value axis' labels that are painted, and where.
  final List<(double, String)> valueLabelsOnAxis = [];

  /// Where the grid lines are drawn, across the value axis.
  final List<double> gridLines = [];

  /// The marks painted, for tests.
  final List<RechartsMark> marks = [];

  /// The value labels painted, for tests.
  final List<RechartsLabel> labels = [];

  /// The lines stroked (each run of a line, or an area's edge), for tests.
  final List<Path> linePaths = [];

  /// Every line of text painted (tick labels, the axis title, value
  /// labels), in paint order, for tests.
  final List<RechartsTextLine> text = [];

  /// The value axis' title as painted, or null when none is.
  String? axisTitle;

  late final ChartType _type = view.chartType;
  late final bool _horizontal = view.layout == A2uiOrientation.horizontal;

  /// Chart.tsx:247, :303, :316: only bars and areas take the `stackId`.
  late final bool _stacked =
      view.stacked == true &&
      (_type == ChartType.bar || _type == ChartType.area);

  /// Chart.tsx:252-258: a scatter chart with every x a finite number.
  late final bool _numericX =
      _type == ChartType.scatter &&
      view.xKey != null &&
      data.isNotEmpty &&
      data.every((row) {
        final v = _field(row, view.xKey);
        return v is num && v.isFinite;
      });

  /// The value axis' domain, or null without one.
  ({double min, double max})? _domain;

  /// The value axis' pixel range.
  late double _v0;
  late double _v1;

  /// The category axis, unless the x axis is a number axis.
  _CategoryAxis? _category;

  /// The scatter chart's number x axis, and the x axis' pixel range.
  ({double min, double max, List<double> ticks})? _xAxis;
  late double _c0;
  late double _c1;

  /// The stack of each series, row by row (base, top), when stacked.
  List<List<(double, double)>> _stack = const [];

  /// d3's linear map of [v] onto the value axis.
  // d3-scale 4.0.2 src/continuous.js:12-16 (`normalize`: a single-value
  // domain maps to the middle, no clamp), :85-87; d3-interpolate 3.0.1
  // src/number.js:1-5 (`a * (1 - t) + b * t`)
  double _value(double v) {
    final d = _domain!;
    final span = d.max - d.min;
    final t = span == 0 ? .5 : (v - d.min) / span;
    return _v0 * (1 - t) + _v1 * t;
  }

  double _xValue(double v) {
    final x = _xAxis!;
    final span = x.max - x.min;
    final t = span == 0 ? .5 : (v - x.min) / span;
    return _c0 * (1 - t) + _c1 * t;
  }

  void _build() {
    _buildLayout();
    _buildDomain();
    _buildCategory();
    _buildTicks();
  }

  void _buildLayout() {
    // Chart.tsx:368, :386: `yAxis.width ?? 96` (horizontal) or `?? 64`;
    // recharts takes a width that is not a number as 60.
    final width = view.yAxis?['width'];
    final axisWidth = width == null
        ? (_horizontal ? 96.0 : 64.0)
        : width is num
        ? width.toDouble()
        : _defaultYAxisWidth;
    // recharts 3.10.1 es6/state/selectors/selectChartOffsetInternal.js:
    // 52-79: the margin, the left axis' width, the bottom axis' height;
    // never a negative width or height.
    final left = axisWidth;
    final top = _margin.top;
    plot = Rect.fromLTWH(
      left,
      top,
      math.max(0, size.width - left - _margin.right),
      math.max(0, size.height - top - _xAxisHeight),
    );
    // es6/state/selectors/axisSelectors.js:978-994: x left to right; the
    // value y axis bottom to top, the category y axis top to bottom.
    if (_horizontal) {
      _v0 = plot.left;
      _v1 = plot.right;
      _c0 = plot.top;
      _c1 = plot.bottom;
    } else {
      _v0 = plot.bottom;
      _v1 = plot.top;
      _c0 = plot.left;
      _c1 = plot.right;
    }
  }

  /// A `yAxis.min` or `max` recharts takes (`isNumber`: Infinity too, which
  /// JSON's 1e999 gives; the domain it makes is then not well formed, so
  /// the axis has none and the chart draws no marks).
  // recharts 3.10.1 es6/util/isDomainSpecifiedByUser.js:134-136, :179-186
  // (`isWellFormedNumberDomain`, :10-19); es6/state/selectors/
  // axisSelectors.js:743-777
  static double? _number(Object? value) =>
      value is num && !value.isNaN ? value.toDouble() : null;

  void _buildDomain() {
    double? low;
    double? high;
    void take(double value) {
      low = low == null ? value : math.min(low!, value);
      high = high == null ? value : math.max(high!, value);
    }

    if (_stacked && series.isNotEmpty) {
      // es6/state/selectors/axisSelectors.js:484-517 (`combineStackGroups`)
      // and es6/util/ChartUtils.js:443-470 (`getDomainOfStackGroups`): each
      // series' least and greatest base or top that is a number (NaN is
      // not, Infinity is: `getDomainOfSingle`, :443-446); a series whose
      // least or greatest is not finite (an infinite value, which d3's
      // stack also carries into every series above it, or no number) is
      // left out whole (:461-463); none left gives [0, 0]
      // (`makeDomainFinite`, :447-449), so a stacked chart without data
      // still has ticks.
      _stack = rechartsStack([
        for (final s in series)
          [for (final row in data) _stackInput(row, s.key)],
      ]);
      for (final points in _stack) {
        final numbers = [
          for (final (a, b) in points) ...[a, b],
        ].where((v) => !v.isNaN).toList();
        if (numbers.isEmpty) continue;
        final least = numbers.reduce(math.min);
        final greatest = numbers.reduce(math.max);
        if (!least.isFinite || !greatest.isFinite) continue;
        take(least);
        take(greatest);
      }
      low ??= 0;
      high ??= 0;
    } else {
      // es6/state/selectors/axisSelectors.js:593-644: each series' values
      // through `makeDomain`.
      for (final s in series) {
        for (final row in data) {
          final v = _makeNumber(_get(row, s.key));
          if (v != null) take(v);
        }
      }
    }
    final y = view.yAxis;
    final axis = rechartsNumberAxis(
      dataMin: low,
      dataMax: high,
      specifiedMin: _number(y?['min']),
      specifiedMax: _number(y?['max']),
    );
    if (axis != null) {
      _domain = (min: axis.min, max: axis.max);
      valueTicks = axis.ticks;
    }
  }

  void _buildCategory() {
    if (_numericX) {
      // Chart.tsx:373-374 (XAxis type number) and es6/state/selectors/
      // axisSelectors.js:532-549 (no domain: `[0, "auto"]`).
      double? low;
      double? high;
      for (final row in data) {
        final v = _makeNumber(_get(row, view.xKey));
        if (v == null) continue;
        low = low == null ? v : math.min(low, v);
        high = high == null ? v : math.max(high, v);
      }
      _xAxis = rechartsNumberAxis(dataMin: low, dataMax: high, specifiedMin: 0);
      return;
    }
    _category = _CategoryAxis(
      data,
      view.xKey,
      band: _type == ChartType.bar || _type == ChartType.scatter,
      range0: _c0,
      range1: _c1,
    );
  }

  /// The ticks recharts shows of an axis along x ([alongX]) or y:
  /// `getTicks` with `interval: "preserveEnd"`, the chart's box as the view
  /// box.
  // The view box is the whole chart, legend included (`selectAxisViewBox`,
  // es6/state/selectors/selectChartOffsetInternal.js:89-94: 0, 0, the
  // chart's width and height; es6/cartesian/XAxis.js:75, YAxis.js:72).
  // Each label is measured whole, as `getStringSize` reads a
  // `white-space: pre` span at the ticks' 12px (es6/cartesian/getTicks.js:
  // 136-152; the measuring font is the page's, INV-048).
  List<RechartsShownTick> _thin(
    List<double> coordinates,
    List<String> texts, {
    required bool alongX,
  }) {
    final ticks = style.ticks;
    return rechartsTicksEnd(
      coordinates,
      (i) => alongX
          ? ticks.measure(texts[i]).width
          : ticks.measure(texts[i]).height,
      start: 0,
      end: alongX ? chartSize.width : chartSize.height,
    );
  }

  void _buildTicks() {
    if (_domain != null) {
      final coordinates = [for (final t in valueTicks) _value(t)];
      final valueText = format ?? _textOf;
      final texts = [for (final t in valueTicks) valueText(t)];
      final shown = _thin(coordinates, texts, alongX: _horizontal);
      valueLabelsOnAxis.addAll([
        for (final (:index, :tickCoord) in shown) (tickCoord, texts[index]),
      ]);
      // The grid: the shown ticks' coordinates and the plot's edges. The
      // grid thins the ticks again with `getTicks` and no font size
      // (es6/cartesian/CartesianGrid.js:253-266, :336-350): `getStringSize`
      // then measures in the shared span's last font size (es6/util/
      // DOMUtils.js:41-65, `Object.assign` keeps it), which the axis'
      // 12px stands in for, so the axis' thinning is reused (INV-048).
      final shownCoordinates = [
        for (final (:index, tickCoord: _) in shown) coordinates[index],
      ];
      gridLines.addAll(_gridOf(shownCoordinates));
    } else {
      gridLines.addAll(_gridOf(const []));
    }
    final category = _category;
    if (category != null) {
      final coordinates = [
        for (var i = 0; i < category.count; i++) category.tick(i),
      ];
      final shown = _thin(coordinates, category.labels, alongX: !_horizontal);
      categoryTicks.addAll([
        for (final (:index, :tickCoord) in shown)
          (tickCoord, category.labels[index]),
      ]);
    } else if (_xAxis case final x?) {
      // R4: Chart.tsx:373-379 gives the x axis no `tickFormatter`.
      final coordinates = [for (final t in x.ticks) _xValue(t)];
      final texts = [for (final t in x.ticks) _textOf(t)];
      final shown = _thin(coordinates, texts, alongX: !_horizontal);
      categoryTicks.addAll([
        for (final (:index, :tickCoord) in shown) (tickCoord, texts[index]),
      ]);
    }
  }

  // recharts 3.10.1 es6/cartesian/CartesianGrid.js:236-265
  // (`defaultHorizontalCoordinatesGenerator`, `…Vertical…`): the shown
  // ticks and the plot's edges; nothing on an empty plot (:320-322).
  List<double> _gridOf(List<double> coordinates) {
    if (!(plot.width > 0) || !(plot.height > 0)) return const [];
    return _horizontal
        ? rechartsGridCoordinates(coordinates, plot.left, plot.right)
        : rechartsGridCoordinates(coordinates, plot.top, plot.bottom);
  }

  /// The along-axis coordinate of row [i], or null.
  double? _along(int i) {
    if (_numericX) {
      final x = _scaleInput(_get(data[i], view.xKey));
      return x == null ? null : _xValue(x);
    }
    return _category?.ofRow(i);
  }

  /// A line, area or scatter point of series [s] in row [i]: where it is,
  /// with a null coordinate where recharts has none.
  // recharts 3.10.1 es6/cartesian/Line.js:489-535 (`computeLinePoints`),
  // es6/cartesian/Area.js:531-592 (`computeArea`), es6/cartesian/
  // Scatter.js:389-480 (`computeScatterPoints`)
  ({double? along, double? value}) _point(int i, int s) {
    final along = _along(i);
    if (_domain == null) return (along: along, value: null);
    final raw = _get(data[i], series[s].key);
    double? value;
    if (_stacked) {
      // Area.js:572-573: a missing value breaks a stacked area.
      final top = _stack[s][i].$2;
      value = raw == null || top.isNaN ? null : _value(top);
    } else {
      final v = _scaleInput(raw);
      value = v == null ? null : _value(v);
    }
    return (along: along, value: value);
  }

  Offset _offsetOf(double along, double value) =>
      _horizontal ? Offset(value, along) : Offset(along, value);

  /// The bar positions in a band.
  late final List<RechartsBarPosition> _positions = rechartsBarPositions(
    _category?.bandwidth ?? 0,
    _stacked ? 1 : series.length,
  );

  /// The bars of row [i]: recharts' `computeBarRectangles`, signed, 0px
  /// bars left out.
  // recharts 3.10.1 es6/cartesian/Bar.js:580-689; es6/util/ChartUtils.js:
  // 404-424 (`getCateCoordinateOfBar`), :425-442 (`getBaseValueOfBar`),
  // :210-232 (`truncateByDomain`)
  List<_Bar> _barsOf(int i) {
    final category = _category;
    final domain = _domain;
    if (category == null || domain == null || i >= category.count) {
      return const [];
    }
    final base = rechartsBarBaseValue(domain.min, domain.max);
    final out = <_Bar>[];
    for (var s = 0; s < series.length; s++) {
      final pos = _positions[_stacked ? 0 : s];
      double from;
      double to;
      Object? labelValue;
      if (_stacked) {
        final (a, b) = rechartsTruncateByDomain(
          _stack[s][i],
          domain.min,
          domain.max,
        );
        from = a;
        to = b;
        labelValue = b;
      } else {
        final raw = _get(data[i], series[s].key);
        final v = _scaleInput(raw);
        if (v == null) continue;
        from = base;
        to = v;
        labelValue = raw;
      }
      final across = category.start(i) + pos.offset;
      final baseScale = _value(from);
      final valueScale = _value(to);
      final bar = _horizontal
          ? (
              series: s,
              x: baseScale,
              y: across,
              width: valueScale - baseScale,
              height: pos.size,
              value: labelValue,
            )
          : (
              series: s,
              x: across,
              y: valueScale,
              width: pos.size,
              height: baseScale - valueScale,
              value: labelValue,
            );
      // Bar.js:661-669: no 0px rectangle.
      if (bar.width == 0 || bar.height == 0) continue;
      // An infinite value scales to NaN (d3's `a * (1 - t) + b * t` at an
      // infinite t). Upright, recharts takes a NaN height as 0 and drops
      // the bar (Bar.js:618-620, :667); lying down, it keeps the item but
      // `Rectangle` draws nothing for a NaN width (Bar.js:647,
      // Rectangle.js:143-145), nor `Text` its label (Text.js:234-236).
      if (!bar.x.isFinite ||
          !bar.y.isFinite ||
          !bar.width.isFinite ||
          !bar.height.isFinite) {
        continue;
      }
      out.add(bar);
    }
    return out;
  }

  // recharts 3.10.1 es6/shape/Rectangle.js:37-73 (`getRectanglePath`): a
  // corner is at most half the bar's width or height (each rounded to 4
  // decimals, es6/util/round.js:1-11, which no pixel shows); an array's
  // corners in the bar's signed geometry, so [4, 4, 0, 0] rounds the value
  // end of a negative bar too; a number for all four when above 0; a plain
  // rectangle otherwise.
  RRect _barShape(Rect rect, {required bool negative}) {
    if (_stacked) return RRect.fromRectAndRadius(rect, Radius.zero);
    final limit = math.min(rect.width, rect.height) / 2;
    final custom = view.barRadius;
    if (custom != null) {
      return RRect.fromRectAndRadius(
        rect,
        Radius.circular(math.max(0, math.min(custom, limit))),
      );
    }
    // Chart.tsx:317-325: [4, 4, 0, 0] (or [0, 4, 4, 0]), the corners at the
    // value's end.
    final r = Radius.circular(math.min(4, limit));
    if (_horizontal) {
      return negative
          ? RRect.fromRectAndCorners(rect, topLeft: r, bottomLeft: r)
          : RRect.fromRectAndCorners(rect, topRight: r, bottomRight: r);
    }
    return negative
        ? RRect.fromRectAndCorners(rect, bottomLeft: r, bottomRight: r)
        : RRect.fromRectAndCorners(rect, topLeft: r, topRight: r);
  }

  Color _fill(StandardChartSeries s) =>
      s.color ?? style.theme.color(A2uiColorToken.svgInitialFill);

  /// A row's own `fill`, which recharts spreads over a bar's props and its
  /// label entry (Bar.js:277-279, :166): its colour, SVG's initial black
  /// when the browser cannot read it, or null without one.
  Color? _rowFill(int i) => switch (_field(data[i], 'fill')) {
    final String css =>
      parseCssColor(css) ?? style.theme.color(A2uiColorToken.svgInitialFill),
    _ => null,
  };

  @override
  void paint(Canvas canvas, PlotFocus? focus) {
    marks.clear();
    labels.clear();
    linePaths.clear();
    text.clear();
    axisTitle = null;
    // An `<svg>` that is not the root clips what leaves it (the UA
    // stylesheet's `svg:not(:root) { overflow: hidden }`).
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    final cursor = focus != null && view.showTooltip;
    // recharts 3.10.1 es6/zIndex/DefaultZIndexes.js: grid, area, cursor
    // rectangle, bar, line, axis, scatter, cursor line, active dot, label.
    if (view.showGrid) _paintGrid(canvas);
    if (_type == ChartType.area) _paintLines(canvas, area: true);
    if (cursor && _type == ChartType.bar) _paintBandCursor(canvas, focus);
    if (_type == ChartType.bar) _paintBars(canvas);
    if (_type == ChartType.line) _paintLines(canvas, area: false);
    _paintAxisLine(canvas);
    if (_type == ChartType.scatter) _paintScatter(canvas);
    if (cursor && _type != ChartType.bar) _paintLineCursor(canvas, focus);
    // Line.js:425-431, Area.js:419-424: the active dots belong to the
    // series, not to the Tooltip (only the cursor does, Tooltip.js:177-183).
    if (focus != null) _paintActiveDots(canvas, focus);
    _paintAxisLabels(canvas);
    if (view.showValueLabels == true) _paintValueLabels(canvas);
    canvas.restore();
  }

  // recharts 3.10.1 es6/cartesian/CartesianGrid.js:92-160: horizontal
  // lines from the plot's left (vertical ones from its top), dashed 3 3 in
  // the subtle border colour (Chart.tsx:343-349).
  void _paintGrid(Canvas canvas) {
    final paint = Paint()
      ..color = style.theme.color(A2uiColorToken.borderSubtle)
      ..strokeWidth = 1;
    for (final at in gridLines) {
      if (_horizontal) {
        paintDashedLine(
          canvas,
          Offset(at, plot.top),
          Offset(at, plot.bottom),
          paint,
          dash: 3,
          gap: 3,
        );
      } else {
        paintDashedLine(
          canvas,
          Offset(plot.left, at),
          Offset(plot.right, at),
          paint,
          dash: 3,
          gap: 3,
        );
      }
    }
  }

  // recharts 3.10.1 es6/component/Cursor.js:57-67: the bar chart's
  // `Rectangle` over the active band, filled with CopilotKit's
  // `CHART_CURSOR` (Chart.tsx:60), unstroked: es6/util/cursor/
  // getCursorRectangle.js:1-10 gives `stroke: 'none'` after Cursor.js:93-97's
  // `stroke: '#ccc'`, and insets the band 0.5px from the plot's edges (its
  // height less 1; across a horizontal chart, its width less 1).
  void _paintBandCursor(Canvas canvas, PlotFocus focus) {
    final category = _category;
    if (category == null || focus.group >= category.count) return;
    final start = category.tick(focus.group) - category.bandwidth / 2;
    final rect = _horizontal
        ? Rect.fromLTWH(
            plot.left + .5,
            start,
            plot.width - 1,
            category.bandwidth,
          )
        : Rect.fromLTWH(
            start,
            plot.top + .5,
            category.bandwidth,
            plot.height - 1,
          );
    canvas.drawRect(
      rect,
      Paint()..color = style.theme.color(A2uiColorToken.chartCursor),
    );
  }

  // recharts 3.10.1 es6/component/Cursor.js:53-57 (a ScatterChart's `Cross`
  // through the point) and :78-84 (a line or area chart's `Curve` across
  // the plot at the active category), stroked `#ccc`, 1px (:93-97). The
  // line runs (x, top) to (x, top + height), or (left, y) to (left + width,
  // y) (es6/util/cursor/getCursorPoints.js:2-20); the cross is `M x,top v
  // height M left,y h width` (es6/shape/Cross.js:6-8, :24-40).
  void _paintLineCursor(Canvas canvas, PlotFocus focus) {
    final paint = Paint()
      ..color = style.theme.color(A2uiColorToken.rechartsCursorStroke)
      ..strokeWidth = 1;
    if (_type == ChartType.scatter) {
      final at = _scatterAt(focus);
      if (at == null) return;
      canvas
        ..drawLine(Offset(at.dx, plot.top), Offset(at.dx, plot.bottom), paint)
        ..drawLine(Offset(plot.left, at.dy), Offset(plot.right, at.dy), paint);
      return;
    }
    final along = _category?.ofRow(focus.group);
    if (along == null) return;
    if (_horizontal) {
      canvas.drawLine(
        Offset(plot.left, along),
        Offset(plot.right, along),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(along, plot.top),
        Offset(along, plot.bottom),
        paint,
      );
    }
  }

  // The x axis' line in the default border colour (Chart.tsx:358, :378);
  // the y axes have none.
  void _paintAxisLine(Canvas canvas) => canvas.drawLine(
    plot.bottomLeft,
    plot.bottomRight,
    Paint()
      ..color = style.theme.color(A2uiColorToken.borderDefault)
      ..strokeWidth = 1,
  );

  /// The `width` the YAxis gives each tick's `Text` (YAxis.js:125-129):
  /// CopilotKit's `yAxis.width ?? 96` (horizontal) or `?? 64` (Chart.tsx:
  /// 368, :386, a number by the schema); null (no breaking) for a falsy 0.
  double? get _yTickWidth {
    final width = view.yAxis?['width'];
    return switch (width) {
      null => _horizontal ? 96 : 64,
      final num n when n != 0 && !n.isNaN => n.toDouble(),
      _ => null,
    };
  }

  // recharts 3.10.1 es6/cartesian/CartesianAxis.js:131-170
  // (`getTickLineCoord`), :185-216 (the anchors), :300-379 (`Ticks`): each
  // tick a `Text` with the axis' `width` (the XAxis' own, the plot's width,
  // :318; the YAxis' `width` prop, YAxis.js:125-129), which breaks it into
  // lines (es6/component/Text.js:150-187).
  void _paintAxisLabels(Canvas canvas) {
    final ticks = style.ticks;
    final bottom = _horizontal ? valueLabelsOnAxis : categoryTicks;
    final left = _horizontal ? categoryTicks : valueLabelsOnAxis;
    // The bottom axis: centred, the cap height under the tick's y.
    for (final (at, label) in bottom) {
      text.addAll(
        ticks.paint(
          canvas,
          label,
          at,
          plot.bottom + _tickOffset,
          anchor: RechartsTextAnchor.middle,
          vertical: RechartsVerticalAnchor.start,
          width: plot.width == 0 ? null : plot.width,
        ),
      );
    }
    // The left axis: ending at the tick, its lines centred on it.
    final width = _yTickWidth;
    for (final (at, label) in left) {
      text.addAll(
        ticks.paint(
          canvas,
          label,
          plot.left - _tickOffset,
          at,
          anchor: RechartsTextAnchor.end,
          vertical: RechartsVerticalAnchor.middle,
          width: width,
        ),
      );
    }
    // Chart.tsx:263-273: a label only when `yAxis.label` is not empty. An
    // axis `Label` has no parent view box, so no width (es6/component/
    // Label.js:283-299; getCartesianPosition.js:119-122).
    final title = view.yAxis?['label'];
    if (title is String && title.isNotEmpty) {
      if (_horizontal) {
        // `insideBottom` of the x axis' box (es6/cartesian/
        // getCartesianPosition.js:147-154): its baseline 5px above the
        // box's bottom, centred.
        text.addAll(
          style.axisTitle.paint(
            canvas,
            title,
            plot.left + plot.width / 2,
            plot.bottom + _xAxisHeight - _labelOffset,
            anchor: RechartsTextAnchor.middle,
          ),
        );
      } else {
        // `insideLeft` of the y axis' box, which starts at the chart's left
        // edge (getCartesianPosition.js:123-130; es6/state/selectors/
        // axisSelectors.js:1094-1153): 5px in, at the plot's middle, its
        // start there, turned -90° about that point, so it runs up.
        text.addAll(
          style.axisTitle.paint(
            canvas,
            title,
            _labelOffset,
            plot.top + plot.height / 2,
            vertical: RechartsVerticalAnchor.middle,
            angle: -90,
          ),
        );
      }
      axisTitle = title;
    }
  }

  // recharts 3.10.1 es6/cartesian/Bar.js (`DefaultZIndexes.bar`).
  void _paintBars(Canvas canvas) {
    for (var i = 0; i < data.length; i++) {
      for (final bar in _barsOf(i)) {
        final s = series[bar.series];
        final rect = Rect.fromLTRB(
          math.min(bar.x, bar.x + bar.width),
          math.min(bar.y, bar.y + bar.height),
          math.max(bar.x, bar.x + bar.width),
          math.max(bar.y, bar.y + bar.height),
        );
        final negative = _horizontal ? bar.width < 0 : bar.height < 0;
        canvas.drawRRect(
          _barShape(rect, negative: negative),
          Paint()..color = _rowFill(i) ?? _fill(s),
        );
        marks.add(RechartsMark('bar', rect, s.key, bar.value));
      }
    }
  }

  /// The points of series [s] in the runs between missing ones
  /// (`connectNulls` false; d3's `defined`), each with its base for an
  /// area.
  // recharts 3.10.1 es6/shape/Curve.js:41-43 (`defined`), :73-129
  // (`getPath`); es6/cartesian/Area.js:593-616 (the base line)
  List<List<(int, Offset, double?)>> _segments(int s, {required bool area}) {
    final out = <List<(int, Offset, double?)>>[[]];
    for (var i = 0; i < data.length; i++) {
      final p = _point(i, s);
      final along = p.along;
      final value = p.value;
      if (along == null || value == null) {
        // Line.js:517-534: recharts' vertical layout (CopilotKit's
        // horizontal one) leaves a missing point out, so the line runs past
        // it.
        if (!area && _horizontal) continue;
        if (out.last.isNotEmpty) out.add([]);
        continue;
      }
      double? base;
      if (area) {
        final domain = _domain!;
        base = _stacked
            ? _value(_stack[s][i].$1)
            : _value(rechartsAreaBaseValue(domain.min, domain.max));
      }
      // An infinite value (or a stack base or top it carried) scales to
      // NaN, which recharts keeps as a point (Line.js:509, :519; Area.js:
      // 584) but d3 leaves undefined: a gap, in either layout (Curve.js:42
      // `defined`, :43 `areaDefined`), with no dot (Dot.js:23).
      if (!along.isFinite ||
          !value.isFinite ||
          (base != null && !base.isFinite)) {
        if (out.last.isNotEmpty) out.add([]);
        continue;
      }
      out.last.add((i, _offsetOf(along, value), base));
    }
    return [
      for (final run in out)
        if (run.isNotEmpty) run,
    ];
  }

  void _addCurve(Path path, List<Offset> points, {bool move = true}) =>
      _horizontal
      ? addMonotoneYPath(path, points, move: move)
      : addMonotoneXPath(path, points, move: move);

  // recharts 3.10.1 es6/cartesian/Line.js and Area.js; es6/shape/Curve.js:
  // 46-58 (`getCurveFactory`: monotone Y in recharts' vertical layout, X in
  // its horizontal one; CopilotKit passes the layout, Chart.tsx:340).
  void _paintLines(Canvas canvas, {required bool area}) {
    for (var s = 0; s < series.length; s++) {
      final item = series[s];
      final color = item.color;
      final runs = _segments(s, area: area);
      for (final run in runs) {
        final points = [for (final (_, p, _) in run) p];
        if (area) {
          // d3's area: the top, then the base back with the same curve,
          // closed (d3-shape 3.2.0 src/curve/monotone.js:41-60: `areaStart`
          // starts the second line with a line).
          final bottom = [
            for (final (_, p, b) in run)
              if (_horizontal) Offset(b!, p.dy) else Offset(p.dx, b!),
          ];
          final path = Path();
          _addCurve(path, points);
          _addCurve(path, bottom.reversed.toList(), move: false);
          path.close();
          final fill = _fill(item);
          canvas.drawPath(
            path,
            Paint()..color = fill.withValues(alpha: fill.a * .2),
          );
          if (color != null) {
            final edge = Path();
            _addCurve(edge, points);
            canvas.drawPath(
              edge,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1
                ..color = color,
            );
            linePaths.add(edge);
          }
        } else if (color != null) {
          final path = Path();
          _addCurve(path, points);
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = color,
          );
          linePaths.add(path);
        }
      }
      _paintDots(canvas, s, [for (final run in runs) ...run], area: area);
    }
  }

  /// The dots of series [s] over its curve, after it in its layer: with
  /// `showDots` (Chart.tsx:274: r 3, `strokeWidth: 0`, the series' fill),
  /// or, without, when recharts' points are just one (a one-point line is a
  /// white dot ringed 2px in the series' colour, a one-point area its 20%
  /// fill ringed 1px). Over an area a dot keeps the area's 20%
  /// `fillOpacity`, which CopilotKit's `dot` does not set.
  // recharts 3.10.1 es6/component/Dots.js:38-46 (`shouldRenderDots`),
  // :65-75 (r 3, the series' SVG props, then `dot`'s); es6/cartesian/
  // Line.js:193-217 (`lineProps`: `fill: '#fff'`, Line.js:126),
  // Area.js:169-187 (`svgPropertiesNoEvents(props)`: fill, `fillOpacity`,
  // stroke, `strokeWidth: 1`, Area.js:103)
  void _paintDots(
    Canvas canvas,
    int s,
    List<(int, Offset, double?)> points, {
    required bool area,
  }) {
    final item = series[s];
    // Line.js:517-534: recharts' vertical layout (CopilotKit's horizontal
    // one) keeps only the points with both coordinates (a NaN one, from an
    // infinite value, is kept); every other line or area has a point per
    // row.
    final count = !area && _horizontal
        ? [
            for (var i = 0; i < data.length; i++)
              if (_point(i, s) case (along: _?, value: _?)) i,
          ].length
        : data.length;
    final dots = view.showDots == true;
    if (!dots && count != 1) return;
    final color = item.color;
    final fill = dots
        ? _fill(item)
        : area
        ? _fill(item)
        : style.theme.color(A2uiColorToken.rechartsLineFill);
    final dotFill = area ? fill.withValues(alpha: fill.a * .2) : fill;
    final strokeWidth = dots
        ? 0.0
        : area
        ? 1.0
        : 2.0;
    for (final (i, at, _) in points) {
      canvas.drawCircle(at, 3, Paint()..color = dotFill);
      if (strokeWidth > 0 && color != null) {
        canvas.drawCircle(
          at,
          3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..color = color,
        );
      }
      marks.add(
        RechartsMark(
          'dot',
          Rect.fromCircle(center: at, radius: 3),
          item.key,
          _get(data[i], item.key),
        ),
      );
    }
  }

  /// A scatter point of series [s] in row [i]: its coordinates, each null
  /// where the scale gives no number (`getCateCoordinateOfLine` keeps only
  /// an `isNumber`: an infinite value's NaN is null too).
  // recharts 3.10.1 es6/util/ChartUtils.js:396-401; es6/cartesian/
  // Scatter.js:389-480
  ({double? along, double? value}) _scatterPoint(int i, int s) {
    final p = _point(i, s);
    double? finite(double? v) => v != null && v.isFinite ? v : null;
    return (along: finite(p.along), value: finite(p.value));
  }

  /// The scatter points: row, series and position. `Symbols` draws one
  /// only with both coordinates (Symbols.js:101-102).
  // recharts 3.10.1 es6/cartesian/Scatter.js:389-480
  List<(int, int, Offset)> _scatterPoints() => [
    for (var s = 0; s < series.length; s++)
      for (var i = 0; i < data.length; i++)
        if (_scatterPoint(i, s) case (:final double along, :final double value))
          (i, s, _offsetOf(along, value)),
  ];

  Offset? _scatterAt(PlotFocus focus) {
    final item = focus.item;
    if (item == null || item >= series.length || focus.group >= data.length) {
      return null;
    }
    if (_scatterPoint(focus.group, item) case (
      :final double along,
      :final double value,
    )) {
      return _offsetOf(along, value);
    }
    return null;
  }

  void _paintScatter(Canvas canvas) {
    // recharts' default symbol: a circle of area 64 (Scatter.js:452-453),
    // filled with the row's own `fill` when it has one: the row is spread
    // into its point (Scatter.js:459-478) and the point over the Scatter's
    // props (`{...baseProps, ...entry}`, :259).
    final radius = math.sqrt(_scatterSymbolArea / math.pi);
    for (final (i, s, at) in _scatterPoints()) {
      canvas.drawCircle(
        at,
        radius,
        Paint()..color = _rowFill(i) ?? _fill(series[s]),
      );
      marks.add(
        RechartsMark(
          'point',
          Rect.fromCircle(center: at, radius: radius),
          series[s].key,
          _get(data[i], series[s].key),
        ),
      );
    }
  }

  /// The row recharts' axis tooltip and active dots read for category
  /// [index]: with an `xKey`, the first row whose value is strictly the
  /// tick's (`findEntryInArray`), else the row at the index.
  // recharts 3.10.1 es6/state/selectors/combiners/combineTooltipPayload.js:
  // 83-121; es6/util/DataUtils.js:112-117 (`get(entry, key) === value`);
  // es6/component/ActivePoints.js:65-70 (the dot on the point whose payload
  // is that row)
  int _rowOf(int index) {
    final key = view.xKey;
    final category = _category;
    if (key == null || category == null || index >= category.count) {
      return index;
    }
    final value = category.tickValues[index];
    for (var r = 0; r < data.length; r++) {
      if (_strictEquals(_read(data[r], key), value)) return r;
    }
    return index;
  }

  // The active dot of each line or area at the active row: r 4 in the
  // series' colour, ringed 2px `#fff`, over the cursor (z 1200).
  // recharts 3.10.1 es6/component/ActivePoints.js:13-56; es6/cartesian/
  // Line.js:425-431 (`mainColor: stroke`), Area.js:419-424
  // (`getLegendItemColor(stroke, fill)`, the stroke here)
  void _paintActiveDots(Canvas canvas, PlotFocus focus) {
    if (_type != ChartType.line && _type != ChartType.area) return;
    final row = _rowOf(focus.group);
    if (row >= data.length) return;
    for (var s = 0; s < series.length; s++) {
      // ActivePoints.js:25 passes a NaN point (an infinite value) on, and
      // `Dot` draws nothing for it (Dot.js:23).
      if (_point(row, s) case (
        :final double along,
        :final double value,
      ) when along.isFinite && value.isFinite) {
        final at = _offsetOf(along, value);
        canvas
          ..drawCircle(at, 4, Paint()..color = _fill(series[s]))
          ..drawCircle(
            at,
            4,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = style.theme.color(
                A2uiColorToken.rechartsActiveDotStroke,
              ),
          );
      }
    }
  }

  void _label(
    Canvas canvas,
    Object? value,
    double x,
    double y,
    double height, {
    Color? fill,
    double? width,
  }) {
    // recharts 3.10.1 es6/component/LabelList.js:47-53 (an array's last
    // value: a stack's top; only what `Text` writes), es6/component/
    // Label.js:272 (nothing for a nullish value), :93-101 (`formatter`:
    // Chart.tsx:191's `format`), Text.js:156-187 (`children.toString()`).
    final shown = rechartsLabelValue(value);
    if (shown == null) return;
    // Text.js:234-236: nothing at a NaN x or y (a point an infinite value
    // put there).
    if (!x.isFinite || !y.isFinite) return;
    final label = format == null ? _textOf(shown) : format!(shown);
    // `position: "top"`, es6/cartesian/getCartesianPosition.js:52-79: 5px
    // past the value end, which is the bottom of a negative bar.
    final sign = height >= 0 ? 1.0 : -1.0;
    final vertical = sign > 0
        ? RechartsVerticalAnchor.end
        : RechartsVerticalAnchor.start;
    final at = Offset(x, y - sign * _labelOffset);
    // LabelList.js:103: the entry's own fill, else Text's default.
    text.addAll(
      (fill == null
              ? style.valueLabels
              : RechartsText(
                  style.valueLabels.style.copyWith(color: fill),
                  style.textScaler,
                ))
          .paint(
            canvas,
            label,
            at.dx,
            at.dy,
            anchor: RechartsTextAnchor.middle,
            vertical: vertical,
            width: width,
          ),
    );
    labels.add(RechartsLabel(label, at, RechartsTextAnchor.middle, vertical));
  }

  void _paintValueLabels(Canvas canvas) {
    switch (_type) {
      case ChartType.bar:
        // es6/cartesian/Bar.js:148-172: each series' rectangles, each label
        // as wide as its bar (its parent view box, Bar.js:164, :683;
        // getCartesianPosition.js:63-73).
        for (var s = 0; s < series.length; s++) {
          for (var i = 0; i < data.length; i++) {
            for (final bar in _barsOf(i)) {
              if (bar.series != s) continue;
              _label(
                canvas,
                bar.value,
                bar.x + bar.width / 2,
                bar.y,
                bar.height,
                fill: _rowFill(i),
                width: bar.width == 0 ? null : bar.width,
              );
            }
          }
        }
      case ChartType.line:
      case ChartType.area:
        // es6/cartesian/Line.js:219-249, Area.js:188-213: each point, at 0
        // where it has no coordinate.
        for (var s = 0; s < series.length; s++) {
          for (var i = 0; i < data.length; i++) {
            final p = _point(i, s);
            final raw = _get(data[i], series[s].key);
            final Object? value;
            if (_stacked) {
              value = _stack[s][i].$2;
            } else {
              // Line.js:517-534: the vertical layout leaves a missing
              // point out.
              if (_type == ChartType.line &&
                  _horizontal &&
                  (p.along == null || p.value == null)) {
                continue;
              }
              value = raw;
            }
            final at = _offsetOf(p.along ?? 0, p.value ?? 0);
            _label(canvas, value, at.dx, at.dy, 0);
          }
        }
      case ChartType.scatter:
      case ChartType.pie:
      case ChartType.donut:
        break;
    }
  }

  /// Whether [position] is in the plot, its edges included.
  // recharts 3.10.1 es6/util/getActiveCoordinate.js:74-78
  // (`isInCartesianRange`), which es6/state/selectors/selectors.js:61-75
  // asks before it finds the active tick.
  bool _inPlot(Offset position) =>
      position.dx >= plot.left &&
      position.dx <= plot.right &&
      position.dy >= plot.top &&
      position.dy <= plot.bottom;

  @override
  PlotFocus? focusAt(Offset position) {
    if (data.isEmpty) return null;
    if (_type == ChartType.scatter) {
      // The point under the pointer (`trigger: "item"`), the last drawn
      // first.
      final radius = math.sqrt(_scatterSymbolArea / math.pi);
      for (final (i, s, at) in _scatterPoints().reversed) {
        if ((at - position).distance <= radius) return PlotFocus(i, s);
      }
      return null;
    }
    if (!_inPlot(position)) return null;
    final category = _category;
    if (category == null || category.count == 0) return null;
    // recharts 3.10.1 es6/util/getActiveCoordinate.js:79-155.
    final index = rechartsActiveTickIndex(
      _horizontal ? position.dy : position.dx,
      [for (var i = 0; i < category.count; i++) category.tick(i)],
    );
    return index < 0 ? null : PlotFocus(index);
  }

  /// The focus a pointer [focus] still has in this scene ([delta] 0); the
  /// arrow keys are recharts' ([keyboardLength]), not steps.
  @override
  PlotFocus? step(PlotFocus? focus, int delta) {
    if (data.isEmpty || focus == null) return null;
    if (_type == ChartType.scatter) {
      return _scatterPoints().any(
            (p) => p.$1 == focus.group && p.$2 == focus.item,
          )
          ? focus
          : null;
    }
    return focus.group < (_category?.count ?? 0) ? focus : null;
  }

  // recharts' keyboard (es6/state/keyboardEventsMiddleware.js): the chart's
  // rows (`selectTooltipDisplayedData`); the tooltip axis' ticks, one per
  // category, or one per row with a finite x on a number axis
  // (combineCategoricalDomain, es6/state/selectors/axisSelectors.js:
  // 1015-1026; tooltipSelectors.js:91-131).
  @override
  int get keyboardRows => data.length;

  @override
  int get keyboardLength {
    final ticks = _numericX
        ? data.where((row) => _makeNumber(_get(row, view.xKey)) != null).length
        : (_category?.count ?? 0);
    return ticks == 0 ? data.length : ticks;
  }

  // combineActiveTooltipIndex.js:15-38 (`isValueWithinDomain`): only a
  // domain of two finite numbers checks the row's value, read as a number.
  @override
  bool keyboardInDomain(int row) {
    final key = view.xKey;
    if (key == null || row >= data.length) return true;
    final value = _get(data[row], key);
    if (value == null) return true;
    final double low;
    final double high;
    if (_numericX) {
      final x = _xAxis;
      if (x == null) return true;
      (low, high) = (x.min, x.max);
    } else {
      final category = _category;
      if (category == null || category.count != 2) return true;
      final a = category.tickValues[0].value;
      final b = category.tickValues[1].value;
      if (a is! num || b is! num || !a.isFinite || !b.isFinite) return true;
      (low, high) = (a.toDouble(), b.toDouble());
    }
    final number = value is num ? value.toDouble() : _jsPlus(value);
    return number.isFinite &&
        number >= math.min(low, high) &&
        number <= math.max(low, high);
  }

  // es6/state/selectors/axisSelectors.js:1402-1411: CopilotKit's
  // horizontal layout is recharts' vertical one, top to bottom.
  @override
  int get keyboardDirection => _horizontal ? -1 : 1;

  // combineTooltipPayloadConfigurations.js:29-38: a scatter's keyboard shows
  // the first Scatter's rows only.
  @override
  PlotFocus keyboardFocus(int index) =>
      _type == ChartType.scatter ? PlotFocus(index, 0) : PlotFocus(index);

  /// The point recharts puts the tooltip of [focus] by: the scatter point,
  /// else the category and the pointer's other coordinate. With the
  /// keyboard ([pointer] null) a scatter point's, else the category at the
  /// middle of the chart's height (or width) from the plot's top (or left):
  /// `(offset.top + chartHeight) / 2`.
  // recharts 3.10.1 es6/util/getActiveCoordinate.js:8-28
  // (`getActiveCartesianCoordinate`), es6/cartesian/Scatter.js:94, :473
  // (`tooltipPosition`), es6/state/selectors/combiners/
  // combineCoordinateForDefaultIndex.js:1-36 (Bar.js:79, Line.js:173,
  // Area.js:149: no position of their own)
  @override
  Offset coordinateOf(PlotFocus focus, Offset? pointer) {
    if (_type == ChartType.scatter) {
      final item = focus.item;
      if (item == null || item >= series.length || focus.group >= data.length) {
        return Offset.zero;
      }
      // A point without a coordinate has `{x: null, y: null}`, which the
      // tooltip's arithmetic reads as 0 (translate.js:18-57).
      final p = _scatterPoint(focus.group, item);
      final x = p.along;
      final y = p.value;
      return _horizontal ? Offset(y ?? 0, x ?? 0) : Offset(x ?? 0, y ?? 0);
    }
    final category = _category;
    final along = category != null && focus.group < category.count
        ? category.tick(focus.group)
        : 0.0;
    if (pointer == null) {
      return _horizontal
          ? Offset((plot.left + chartSize.width) / 2, along)
          : Offset(along, (plot.top + chartSize.height) / 2);
    }
    return _horizontal ? Offset(pointer.dx, along) : Offset(along, pointer.dy);
  }

  @override
  Offset anchorOf(PlotFocus focus) => coordinateOf(focus, null);

  /// The `<svg>`: the chart's whole box, the legend laid over its foot
  /// (recharts' wrapper; es6/chart/RechartsWrapper.js, es6/component/
  /// Legend.js), so CopilotKit's overflow box, which is as big, clips the
  /// outline round it (Chart.tsx:513-517).
  @override
  Rect get outlineBox => Offset.zero & chartSize;

  @override
  Offset tooltipPosition(PlotFocus focus, Offset? pointer, Size tooltip) {
    final at = coordinateOf(focus, pointer);
    return Offset(
      rechartsTooltipTranslate(
        coordinate: at.dx,
        dimension: tooltip.width,
        viewBoxStart: plot.left,
        viewBoxDimension: plot.width,
      ),
      rechartsTooltipTranslate(
        coordinate: at.dy,
        dimension: tooltip.height,
        viewBoxStart: plot.top,
        viewBoxDimension: plot.height,
      ),
    );
  }

  /// A tooltip row: [name] and [value] through the tooltip's formatter
  /// (CopilotKit's `format`, else what React writes of the value).
  // recharts 3.10.1 es6/component/DefaultTooltipContent.js:84-120
  ChartTooltipRow _row(String name, Object? value, Color? color) =>
      ChartTooltipRow(
        label: name,
        value: format == null ? _reactChild(value) : format!(value),
        color: color,
      );

  @override
  ChartTooltipContent? tooltipOf(PlotFocus focus) {
    if (focus.group >= data.length) return null;
    final List<ChartTooltipRow> rows;
    String? title;
    if (_type == ChartType.scatter) {
      final row = data[focus.group];
      final s = focus.item;
      if (s == null || s >= series.length) return null;
      final item = series[s];
      // Scatter.js:405-427: the x axis' entry, then the y axis'; an axis
      // with no data key names the series and reads its value. In
      // CopilotKit's horizontal layout the x axis is the value axis.
      final key = view.xKey;
      final xEntry = (name: key ?? item.label, key: key ?? item.key);
      final valueEntry = (name: item.label, key: item.key);
      final entries = _horizontal ? [valueEntry, xEntry] : [xEntry, valueEntry];
      rows = [
        for (final entry in entries)
          if (_get(row, entry.key) != null)
            _row(entry.name, _get(row, entry.key), item.color),
      ];
      // An item tooltip has no label: Tooltip.js:137 passes `label:
      // undefined` for `item` events, which DefaultTooltipContent.js:
      // 133-150 writes as an empty `<p>` with no height.
    } else {
      // combineTooltipPayload.js:83-121: the row whose `xKey` is the tick's
      // value; combineActiveLabel.js: the tick's value is the label.
      final row = data[_rowOf(focus.group)];
      final category = _category;
      // DefaultTooltipContent.js:128-150: `"".concat(label)`, nothing for a
      // nullish one (the axis writes those "null" and "undefined").
      title = category != null && focus.group < category.count
          ? (category.tickValues[focus.group].value == null
                ? null
                : category.labels[focus.group])
          : null;
      // Tooltip.js:147-148 (`filterNull`): no row for a missing value.
      rows = [
        for (final s in series)
          if (_get(row, s.key) != null)
            _row(s.label, _get(row, s.key), s.color),
      ];
    }
    // TooltipBoundingBox shows no box without a payload.
    if (rows.isEmpty) return null;
    return ChartTooltipContent(
      title: title,
      rows: rechartsSortBy(rows, (r) => r.label),
    );
  }
}

/// A slice of a [RechartsPieScene].
@immutable
class RechartsSlice {
  /// A slice.
  const RechartsSlice({
    required this.index,
    required this.name,
    required this.value,
    required this.startAngle,
    required this.endAngle,
    required this.color,
    this.named = true,
  });

  /// The row.
  final int index;

  /// The row's name (`getValueByDataKey(entry, nameKey, i)`: the index
  /// when it has none) as text.
  final String name;

  /// Whether the name is text or a number, which the tooltip writes
  /// (`isNumOrStr`); a null or boolean name is not written, nor its
  /// separator.
  final bool named;

  /// The value as the row holds it (0 when it has none).
  final Object? value;

  /// Its start, in degrees counterclockwise from 3 o'clock.
  final double startAngle;

  /// Its end.
  final double endAngle;

  /// Its colour.
  final Color color;

  /// The middle angle.
  double get midAngle => (startAngle + endAngle) / 2;
}

/// The scene of a pie or donut standard Chart: recharts' `Pie` of the first
/// series, 5px inside the chart, slices white-edged, with their values
/// beside them for `showValueLabels`.
// The recharts 3.10.1 defaults CopilotKit doesn't pass, each ported here:
// PolarChart (es6/chart/PolarChart.js:21-45): `margin` 5 all round,
// `accessibilityLayer: true` (the keyboard); its tooltip by item
// (PieChart.js:27), no cursor (Cursor.js:56). Pie (es6/polar/Pie.js:
// 535-561): `cx`, `cy` '50%', `stroke: '#fff'`, `rootTabIndex: 0` (a
// second Tab stop, ChartPlot.tabStops), `minAngle: 0`, no active or
// inactive shape, `labelLine` drawn in the slice's fill, the label 20px out
// (`offsetRadius`, :229) with `alignmentBaseline: 'middle'` (:212);
// `paddingAngle` 0 when CopilotKit passes none. Sector (es6/shape/
// Sector.js:157-167): `forceCornerRadius` and `cornerIsExternal` false.
class RechartsPieScene extends PlotScene {
  /// The scene at [size]; [legendBelow] when the legend stands under it.
  RechartsPieScene({
    required this.size,
    required this.view,
    required this.data,
    required this.series,
    required this.format,
    required this.style,
    this.legendBelow = false,
    Size? chartSize,
  }) : chartSize = chartSize ?? size {
    _build();
  }

  @override
  final Size size;

  /// The chart's whole box, its legend included: the `<svg>`'s.
  final Size chartSize;

  /// The props.
  final ChartProps view;

  /// The rows.
  final List<Map<Object?, Object?>> data;

  /// The series; the first one's values are the slices.
  final List<StandardChartSeries> series;

  /// The value formatter, or null.
  final String Function(Object? value)? format;

  /// The text and colours.
  final RechartsStyle style;

  /// Whether the legend stands under the scene: its box then holds the
  /// chart's 5px bottom margin.
  final bool legendBelow;

  /// The slices.
  final List<RechartsSlice> slices = [];

  /// The slice labels painted, for tests.
  final List<RechartsLabel> labels = [];

  /// Every line of text painted (the slice labels), for tests.
  final List<RechartsTextLine> text = [];

  /// The leader lines painted, for tests: from and to.
  final List<(Offset, Offset)> labelLines = [];

  /// The pie's box (the chart offset).
  late Rect box;

  /// The pie's centre.
  late Offset center;

  /// The inner radius (0 for a pie).
  late double innerRadius;

  /// The outer radius.
  late double outerRadius;

  void _build() {
    // recharts' PieChart keeps a 5px margin; a legend under it holds the
    // bottom one in its own box.
    box = Rect.fromLTRB(
      5,
      5,
      math.max(5, size.width - 5),
      math.max(5, size.height - (legendBelow ? 0 : 5)),
    );
    // recharts 3.10.1 es6/polar/Pie.js:151-174 (`parseCoordinateOfPie`):
    // `cx`, `cy` '50%' of the box; the radii through `getPercentValue`
    // (es6/util/DataUtils.js:48-71), an inner one it cannot read 0 and an
    // outer one 80%. CopilotKit passes `innerRadius ?? (donut ? "55%" :
    // 0)` and `outerRadius ?? "80%"` (Chart.tsx:211-214).
    center = Offset(
      box.left + rechartsPercentValue('50%', box.width),
      box.top + rechartsPercentValue('50%', box.height),
    );
    final max = math.max(0, math.min(box.width, box.height) / 2).toDouble();
    final donut = view.chartType == ChartType.donut;
    outerRadius = rechartsPercentValue(
      view.outerRadius ?? '80%',
      max,
      defaultValue: max * .8,
    );
    innerRadius = rechartsPercentValue(
      view.innerRadius ?? (donut ? '55%' : 0),
      max,
    );
    final first = series.firstOrNull;
    if (first == null) return;
    final palette = standardChartPalette(style.theme);
    // recharts 3.10.1 es6/polar/Pie.js:333-418 (`computePieSectors`):
    // `getValueByDataKey(entry, dataKey, 0)`, a number for the angles, and
    // anything but 0 counting for the padding.
    final values = <Object?>[
      for (final row in data)
        if (_read(row, first.key) case (defined: true, :final value))
          value
        else
          0,
    ];
    double numberOf(Object? v) => v is num && !v.isNaN ? v.toDouble() : 0;
    bool nonZero(Object? v) => !(v is num && v == 0);
    final start = view.startAngle;
    final end = view.endAngle;
    // Pie.js:177-181 (`parseDeltaAngle`)
    final delta = _sign(end - start) * math.min((end - start).abs(), 360);
    final absDelta = delta.abs();
    // Pie.js:348: no padding with one slice.
    final paddingAngle = data.length <= 1 ? 0.0 : view.paddingAngle ?? 0;
    _paddingAngle = paddingAngle;
    final notZeroItemCount = values.where(nonZero).length;
    final totalPaddingAngle =
        (absDelta >= 360 ? notZeroItemCount : notZeroItemCount - 1) *
        paddingAngle;
    final sum = values.fold<double>(0, (a, v) => a + numberOf(v));
    if (!(sum > 0)) return;
    final realTotalAngle = absDelta - totalPaddingAngle;
    double? previousEnd;
    for (var i = 0; i < data.length; i++) {
      final v = values[i];
      final percent = numberOf(v) / sum;
      final startAngle = i == 0
          ? start
          : previousEnd! + _sign(delta) * paddingAngle * (nonZero(v) ? 1 : 0);
      final endAngle = startAngle + _sign(delta) * (percent * realTotalAngle);
      previousEnd = endAngle;
      // Pie.js:373: `getValueByDataKey(entry, nameKey, i)`.
      final name = switch (_read(data[i], view.xKey ?? 'name')) {
        (defined: true, :final value) => value,
        _ => i,
      };
      slices.add(
        RechartsSlice(
          index: i,
          name: name == null ? '' : _textOf(name),
          named: name is String || (name is num && !name.isNaN),
          value: v,
          startAngle: startAngle,
          endAngle: endAngle,
          color: palette[i % palette.length],
        ),
      );
    }
  }

  static double _sign(double value) => value == 0
      ? 0
      : value > 0
      ? 1
      : -1;

  Path _path(RechartsSlice slice) => rechartsSectorPath(
    center: center,
    innerRadius: innerRadius,
    outerRadius: outerRadius,
    startAngle: slice.startAngle,
    endAngle: slice.endAngle,
    cornerRadius: view.cornerRadius ?? 0,
  );

  /// Whether recharts draws [slice]: `Sector` draws nothing for an empty
  /// angle or a ring turned inside out, and a slice whose angle is NaN (an
  /// infinite value makes the sum infinite, its share `Infinity / Infinity`
  /// and every later slice start there) paints nothing either: its path
  /// holds `NaN`, and the browser draws a path only up to its first error,
  /// here at most the opening `M` (getSectorPath, Sector.js:41-64; SVG 2,
  /// Paths, "Error handling in path data"). The label line and label of
  /// such a slice go too ([_paintLabels]).
  // recharts 3.10.1 es6/shape/Sector.js:180-182; es6/polar/Pie.js:351-354
  // (`isNumber` keeps Infinity in the sum), :378-385
  bool _drawn(RechartsSlice slice) =>
      !(outerRadius < innerRadius || slice.startAngle == slice.endAngle) &&
      slice.startAngle.isFinite &&
      slice.endAngle.isFinite;

  @override
  void paint(Canvas canvas, PlotFocus? focus) {
    labels.clear();
    text.clear();
    labelLines.clear();
    // An `<svg>` that is not the root clips what leaves it.
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    for (final slice in slices) {
      if (!_drawn(slice)) continue;
      final path = _path(slice);
      canvas
        ..drawPath(path, Paint()..color = slice.color)
        // recharts' Pie edges each slice in its `stroke`, `#fff`.
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = style.theme.color(A2uiColorToken.rechartsPieStroke),
        );
    }
    if (view.showValueLabels == true) _paintLabels(canvas);
    canvas.restore();
  }

  // recharts 3.10.1 es6/polar/Pie.js:216-257 (`PieLabels`): every slice,
  // 20px out, the leader line in the slice's colour.
  void _paintLabels(Canvas canvas) {
    final lines = view.showLabelLines;
    final first = series.first;
    for (final slice in slices) {
      // A NaN middle angle (an infinite value, see [_drawn]) places neither
      // the leader line (its Curve has no defined point, Curve.js:42) nor
      // the label (Text draws nothing at a NaN x or y, Text.js:234-236).
      if (!slice.midAngle.isFinite) continue;
      final from = rechartsPolar(center, outerRadius, slice.midAngle);
      final to = rechartsPolar(center, outerRadius + 20, slice.midAngle);
      if (lines) {
        canvas.drawLine(
          from,
          to,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = slice.color,
        );
        labelLines.add((from, to));
      }
      // Chart.tsx:219-225: `format(value)` of the sector's value (0 for a
      // missing one), else recharts' own label: the sector's field of the
      // data key (Pie.js:253, `getValueByDataKey(entry, dataKey)`) as
      // `Text` writes it, nothing for a nullish one (Pie.js:198-215,
      // Text.js:150-187).
      final String label;
      if (format != null) {
        label = format!(slice.value);
      } else {
        final raw = _sectorField(slice, first.key);
        if (raw == null) continue;
        label = _textOf(raw);
      }
      // Pie.js:142-150 (`getTextAnchor`)
      final anchor = to.dx > center.dx
          ? RechartsTextAnchor.start
          : to.dx < center.dx
          ? RechartsTextAnchor.end
          : RechartsTextAnchor.middle;
      // Pie.js:209-212: `alignment-baseline: middle` (INV-035).
      text.addAll(
        style
            .sliceLabels(slice.color)
            .paint(
              canvas,
              label,
              to.dx,
              to.dy,
              anchor: anchor,
              vertical: RechartsVerticalAnchor.middle,
            ),
      );
      labels.add(
        RechartsLabel(label, to, anchor, RechartsVerticalAnchor.middle),
      );
    }
  }

  /// A field of recharts' sector entry for [slice]: the row spread under
  /// the sector's own geometry and value, over its computed names.
  // recharts 3.10.1 es6/polar/Pie.js:395-414 (`prev = {...presentation,
  // percent, cornerRadius, name, …, midAngle, middleRadius, …, ...entry,
  // ...coordinate, value: val, dataKey, startAngle, endAngle, payload,
  // paddingAngle}`)
  Object? _sectorField(RechartsSlice slice, String key) {
    final sign = _sign(slice.endAngle - slice.startAngle);
    switch (key) {
      case 'value':
        return slice.value;
      case 'startAngle':
        return slice.startAngle;
      case 'endAngle':
        return slice.endAngle;
      case 'cx':
        return center.dx;
      case 'cy':
        return center.dy;
      case 'innerRadius':
        return innerRadius;
      case 'outerRadius':
        return outerRadius;
      case 'paddingAngle':
        return _isZero(slice.value) ? 0 : sign * (_paddingAngle ?? 0);
    }
    final read = _read(data[slice.index], key);
    if (read.defined) return read.value;
    return switch (key) {
      'midAngle' => slice.midAngle,
      'middleRadius' => (innerRadius + outerRadius) / 2,
      'name' => slice.name,
      _ => null,
    };
  }

  static bool _isZero(Object? value) => value is num && value == 0;

  /// The padding angle the slices were laid out with.
  double? _paddingAngle;

  @override
  PlotFocus? focusAt(Offset position) {
    // The slice under the pointer (`trigger: "item"`), the last drawn
    // first: the browser hit-tests the sector's path.
    for (final slice in slices.reversed) {
      if (_drawn(slice) && _path(slice).contains(position)) {
        return PlotFocus(slice.index);
      }
    }
    return null;
  }

  @override
  PlotFocus? step(PlotFocus? focus, int delta) =>
      focus != null && focus.group < slices.length ? focus : null;

  // recharts' keyboard over the Pie's rows (its data; the angle axis' ticks
  // are their indexes, es6/state/selectors/axisSelectors.js:806-815).
  @override
  int get keyboardRows => slices.length;

  /// The `<svg>`: the chart's whole box (see [RechartsScene.outlineBox]).
  @override
  Rect get outlineBox => Offset.zero & chartSize;

  /// The pie's `<g>` (Pie.js:594-596, `tabIndex: rootTabIndex`): the tight
  /// box (`getBBox`, SVG 2's bounding box) of the slices it draws, never
  /// their paths' control points (its labels go to a z-index layer of their
  /// own, Pie.js:250-257); none when it draws none.
  @override
  Rect? get innerOutlineBox {
    Rect? box;
    for (final slice in slices) {
      if (!_drawn(slice)) continue;
      final bounds = rechartsSectorBounds(
        center: center,
        innerRadius: innerRadius,
        outerRadius: outerRadius,
        startAngle: slice.startAngle,
        endAngle: slice.endAngle,
        cornerRadius: view.cornerRadius ?? 0,
      );
      if (bounds == null) continue;
      box = box == null ? bounds : box.expandToInclude(bounds);
    }
    return box;
  }

  /// The slice's tooltip position: the middle of its ring at its middle
  /// angle; the centre for a slice the pie does not have.
  // recharts 3.10.1 es6/polar/Pie.js:386-398
  @override
  Offset anchorOf(PlotFocus focus) => focus.group < slices.length
      ? rechartsPolar(
          center,
          (innerRadius + outerRadius) / 2,
          slices[focus.group].midAngle,
        )
      : center;

  /// The box's `translate`: NaN for a slice whose angle is NaN, which the
  /// plot's layout keeps the box's last place for, as CSSOM keeps the last
  /// valid `transform`.
  @override
  Offset tooltipPosition(PlotFocus focus, Offset? pointer, Size tooltip) {
    final at = anchorOf(focus);
    return Offset(
      rechartsTooltipTranslate(
        coordinate: at.dx,
        dimension: tooltip.width,
        viewBoxStart: box.left,
        viewBoxDimension: box.width,
      ),
      rechartsTooltipTranslate(
        coordinate: at.dy,
        dimension: tooltip.height,
        viewBoxStart: box.top,
        viewBoxDimension: box.height,
      ),
    );
  }

  @override
  ChartTooltipContent? tooltipOf(PlotFocus focus) {
    if (focus.group >= slices.length) return null;
    final slice = slices[focus.group];
    // Pie.js:388-397: one entry, the slice's name and value in its colour;
    // `filterNull` drops a null value (Tooltip.js:147-148); a name that is
    // not text or a number is not written, nor its separator
    // (DefaultTooltipContent.js:112-116).
    if (slice.value == null) return null;
    return ChartTooltipContent(
      rows: [
        ChartTooltipRow(
          label: slice.name,
          value: format == null
              ? _reactChild(slice.value)
              : format!(slice.value),
          color: slice.color,
          named: slice.named,
        ),
      ],
    );
  }
}

/// recharts' legend as CopilotKit sets it up (Chart.tsx:39-51): under the
/// chart, 8px above its entries, each an 8px circle 4px before its name
/// (13px, the text colour), entries 10px apart, centred in the chart's
/// width less its left and right margins.
// recharts 3.10.1 es6/component/Legend.js:86-118 (`getDefaultPosition`:
// left at the left margin, bottom at the bottom margin) and es6/component/
// DefaultLegendContent.js:95-162 (`li` inline-blocks with `marginRight`
// 10, the icon's `marginRight` 4, the `ul` centred).
// The defaults CopilotKit's `LEGEND_PROPS` (`iconType`, `iconSize`,
// `formatter`, `wrapperStyle`) leave, each ported (Legend.js:172-181,
// DefaultLegendContent.js:14-21): `itemSorter: 'value'` (the entries
// sorted by name, in buildChart), `align: 'center'`, `verticalAlign:
// 'bottom'`, `layout: 'auto'` (horizontal), `inactiveColor: '#ccc'` (no
// entry is inactive: CopilotKit hides no series), `payloadUniqBy` none
// (every entry listed), no click or hover handlers.
class _RechartsLegend extends StatelessWidget {
  const _RechartsLegend({
    required this.items,
    required this.theme,
    required this.pie,
    required this.item,
  });

  final List<(String, Color)> items;
  final A2uiKitTheme theme;

  /// A PieChart's legend sits inside its 5px margins; a cartesian chart's
  /// inside CopilotKit's (0 left, 8 right, 0 bottom).
  final bool pie;

  /// The `li`'s text style: the page's font, the surface's standing in
  /// (INV-046).
  final TextStyle item;

  /// The icon's box and its margin (`iconSize: 8`, Chart.tsx:46-51;
  /// `marginRight: 4`, DefaultLegendContent.js:103-107), in `px`, which a
  /// browser's text size leaves alone (RULEBOOK section 6 item 3).
  static const double _icon = 8;
  static const double _iconMargin = 4;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // The icon is an inline box no break may follow (RULEBOOK section 2,
    // inline children): a no-break space (U+00A0, UAX #14 class GL: LB12
    // allows no break after it) in the `li`'s font, its advance made the
    // icon's 8px and margin's 4px with `letterSpacing` (which the text
    // scale leaves alone), measured once without the style's own spacing;
    // the dot is painted over its place ([_LegendIcon]). A `WidgetSpan`
    // would not do: Flutter's line wrapper breaks after a placeholder
    // whatever follows it. A word joiner (U+2060, class WJ, LB11: no break
    // either side, no advance) goes first: SkParagraph shifts a line whose
    // first character is letter-spaced by half that spacing, and one that
    // starts with the joiner by nothing (observed by the fourth chart batch,
    // Flutter 3.47.9).
    final space = TextPainter(
      text: TextSpan(text: '\u00a0', style: item.copyWith(letterSpacing: 0)),
      textScaler: scaler,
      textDirection: direction,
    )..layout();
    final spacing = _icon + _iconMargin - space.width;
    space.dispose();
    return Padding(
      padding: pie
          ? const EdgeInsets.fromLTRB(5, 8, 5, 5)
          : const EdgeInsets.only(top: 8, right: 8),
      // The `ul`'s inline-block `li`s, centred (`textAlign: align`,
      // DefaultLegendContent.js:159-163): a run of inline boxes, not a flex
      // box.
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (label, color) in items)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              // The `li` (`display: inline-block; white-space: nowrap`,
              // DefaultLegendContent.js:98-102), as wide as its content
              // (CSS 2.1 section 10.3.9): at most the line, unless the icon
              // and the name's first word, which no break may part (the
              // `li`'s `nowrap` rules between them, CSS Text 3 section
              // 5.1), or a longer word, are wider (`overflow-wrap:
              // break-word`'s breaks don't count towards min-content, CSS
              // Text 3 section 5.5); then it overflows its line,
              // start-aligned (CSS Text 3 section 6.1). Its lines are
              // centred: it inherits the `ul`'s `text-align`.
              child: CssFitContent(
                child: _LegendIcon(
                  color: color,
                  // `vertical-align: middle`: the icon's middle at the
                  // `li`'s baseline plus half its x-height (CSS 2.1 section
                  // 10.8.1). Flutter's text API gives no x-height, so CSS's
                  // own fallback, 0.5em (CSS Values 4 section 6.1.1), stands
                  // in for it (INV-053).
                  middle: scaler.scale(item.fontSize ?? 14) * .5 / 2,
                  child: RichText(
                    textAlign: TextAlign.center,
                    textDirection: direction,
                    textScaler: scaler,
                    // The `li`'s strut: its font sets each line's least
                    // height (CSS 2.1 section 10.8.1).
                    strutStyle: StrutStyle.fromTextStyle(item),
                    text: TextSpan(
                      style: item,
                      children: [
                        const TextSpan(text: '⁠'),
                        TextSpan(
                          text: ' ',
                          style: TextStyle(letterSpacing: spacing),
                        ),
                        // The name's `span` (`white-space: normal`,
                        // `overflow-wrap: break-word`, :119-122) holding the
                        // formatter's 13px `span` (Chart.tsx:39-43).
                        TextSpan(
                          text: label,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.color(A2uiColorToken.textDefault),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A legend entry's icon: an 8px circle in [color] painted over the
/// no-break space that holds its place, its child paragraph's second
/// character (after a word joiner), centred [middle] above that
/// paragraph's first baseline.
class _LegendIcon extends SingleChildRenderObjectWidget {
  const _LegendIcon({
    required this.color,
    required this.middle,
    required RichText super.child,
  });

  final Color color;
  final double middle;

  @override
  _RenderLegendIcon createRenderObject(BuildContext context) =>
      _RenderLegendIcon(color, middle);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLegendIcon renderObject,
  ) => renderObject
    ..color = color
    ..middle = middle;
}

class _RenderLegendIcon extends RenderProxyBox {
  _RenderLegendIcon(this._color, this._middle);

  Color _color;
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  double _middle;
  double get middle => _middle;
  set middle(double value) {
    if (value == _middle) return;
    _middle = value;
    markNeedsLayout();
  }

  /// The icon's centre, in this box.
  Offset? _centre;

  @override
  void performLayout() {
    super.performLayout();
    final paragraph = child;
    _centre = null;
    if (paragraph is! RenderParagraph) return;
    final run = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 1, extentOffset: 2),
    );
    final baseline = paragraph.getDistanceToBaseline(
      TextBaseline.alphabetic,
      onlyReal: true,
    );
    if (run.isEmpty || baseline == null) return;
    // The `<svg>` box is the run's first 8px, its margin the last 4px
    // (`margin-right`, physical whatever the direction).
    _centre = Offset(
      run.first.left + _RechartsLegend._icon / 2,
      baseline - _middle,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final centre = _centre;
    if (centre == null) return;
    // recharts' `circle` icon, a circle as wide as its 32-unit view box
    // (`Symbols` with `sizeType: "diameter"`, DefaultLegendContent.js:13,
    // :75-82), the `<svg>` `iconSize` (8) wide (:128-137).
    context.canvas.drawCircle(
      offset + centre,
      _RechartsLegend._icon / 2,
      Paint()..color = _color,
    );
  }
}

/// recharts' default tooltip with CopilotKit's `contentStyle`: a white box,
/// a subtle 1px border, 10px corners, the `md` shadow, 13px text, 10px
/// padding; the category over one `name : value` line per series in the
/// series' colour, 4px above and below each.
///
/// The box stays white in the dark, and the category keeps the surface's
/// text colour, as in CopilotKit.
// recharts 3.10.1 es6/component/DefaultTooltipContent.js:28-46 (the
// default styles), :128-150 (the label's `p`, the items' `ul`); Chart.tsx:
// 53-61.
// The defaults CopilotKit's `TOOLTIP_PROPS` (`contentStyle`, `cursor`) and
// `formatter` leave, each ported (Tooltip.js:42-67): `itemSorter: 'name'`,
// `separator: ' : '`, `offset: 10` and `allowEscapeViewBox` false
// ([rechartsTooltipTranslate]), `filterNull: true`, `animationDuration:
// 400`, `animationEasing: 'ease'`, `isAnimationActive: 'auto'` (the glide,
// ChartPlot), `trigger: 'hover'`, `payloadUniqBy` none;
// DefaultTooltipContent's padding 10, white box, `nowrap`, items 4px above
// and below in their series' colour (:29-46, :105-107).
class RechartsTooltip extends StatelessWidget {
  /// A tooltip of [content].
  const RechartsTooltip({
    required this.content,
    required this.theme,
    super.key,
  });

  /// What it shows.
  final ChartTooltipContent content;

  /// The theme.
  final A2uiKitTheme theme;

  @override
  Widget build(BuildContext context) {
    // BUG(port): recharts' tooltip box is white whatever the theme, and its
    // label inherits the surface's text colour: light text on white in the
    // dark look. Reproduced, as CopilotKit sets only the radius, border,
    // shadow and size.
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.color(A2uiColorToken.rechartsTooltipBackground),
        border: Border.all(color: theme.color(A2uiColorToken.borderSubtle)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: theme.shadow(A2uiShadowToken.md),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 13),
        softWrap: false,
        // The label's `p` and the items' `li`s: blocks, one under another.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.title case final String title when title.isNotEmpty)
              Text(title),
            for (final row in content.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  row.named ? '${row.label} : ${row.value}' : row.value,
                  style: TextStyle(color: row.color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/Chart.tsx
