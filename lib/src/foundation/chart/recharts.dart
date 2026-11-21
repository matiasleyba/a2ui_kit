// The parts of recharts 3.10.1 (MIT, (c) Recharts Group) that CopilotKit's
// standard Chart draws with, ported from its published `es6/` source (the
// version CopilotKit's lockfile pins): bar positions, tick thinning, the
// tooltip's position, the active category, SVG text placement and line
// breaking, stacks, sorting and the paint order. See NOTICE.md.
//
// Every file these ports lean on is among the fetched sources
// ($A2UI_THIRDPARTY_SRC/recharts@3.10.1/es6/, with
// es-toolkit@1.43.0 for `sortBy` and `get`); each site cites its own.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:a2ui_kit/src/functions/calc.dart';
import 'package:flutter/painting.dart';

/// recharts' `DefaultZIndexes`: the order its layers paint in, lowest
/// first.
// recharts 3.10.1 es6/zIndex/DefaultZIndexes.js
abstract final class RechartsZIndex {
  /// `CartesianGrid`.
  static const int grid = -100;

  /// `Area` (and `Pie`, `defaultPieProps.zIndex`).
  static const int area = 100;

  /// The bar chart's cursor band.
  static const int cursorRectangle = 200;

  /// `Bar`.
  static const int bar = 300;

  /// `Line` and its dots.
  static const int line = 400;

  /// The axis lines.
  static const int axis = 500;

  /// `Scatter`.
  static const int scatter = 600;

  /// The line and cross cursors.
  static const int cursorLine = 1100;

  /// The active dots.
  static const int activeDot = 1200;

  /// Every label: tick labels, value labels, the axis title.
  static const int label = 2000;
}

/// recharts' default gap between the bars of a category, in pixels
/// (`barGap`).
// recharts 3.10.1 es6/chart/CartesianChart.js:25-26
const double kRechartsBarGap = 4;

/// recharts' default gap round a category's bars, a percentage of its band
/// (`barCategoryGap: '10%'`).
// recharts 3.10.1 es6/chart/CartesianChart.js:25-26
const String kRechartsBarCategoryGap = '10%';

/// One bar's place in its band: `offset` from the band's start, `size`
/// across.
typedef RechartsBarPosition = ({double offset, double size});

/// recharts' `getBarPositions` without a `barSize` or `maxBarSize` (as
/// CopilotKit's Chart leaves them): [count] bars in a band [bandSize] wide,
/// 10% of the band on each side, 4px between bars (none when they would
/// not fit), each bar's size rounded with `Math.round` when over 1px.
// recharts 3.10.1 es6/state/selectors/combiners/combineAllBarPositions.js:
// 8-73 (the `else` branch, :53-71). The gaps go through `getPercentValue(
// gap, bandSize, 0, true)` (util/DataUtils.js:48-71): "10%" is
// `bandSize * 10 / 100` in that order, and both are capped at the band.
List<RechartsBarPosition> rechartsBarPositions(double bandSize, int count) {
  if (count < 1) return const [];
  var realBarGap = math.min(kRechartsBarGap, bandSize);
  final offset = rechartsPercentValue(
    kRechartsBarCategoryGap,
    bandSize,
    validate: true,
  );
  if (bandSize - 2 * offset - (count - 1) * realBarGap <= 0) realBarGap = 0;
  var originalSize = (bandSize - 2 * offset - (count - 1) * realBarGap) / count;
  if (originalSize > 1) originalSize = jsMathRound(originalSize);
  // No `maxBarSize`: the size is the original one, so the centring term
  // `len * (originalSize - size) / 2` is 0.
  final size = originalSize;
  return [
    for (var i = 0; i < count; i++)
      (offset: offset + (size + realBarGap) * i, size: size),
  ];
}

/// recharts' `getPercentValue(percent, totalValue, defaultValue, validate)`:
/// a number as is; text whose only `%` ends it as that share of
/// [totalValue] (`parseFloat` of what comes before); other text through
/// `Number()`; [defaultValue] for anything else, a NaN result or a share of
/// no total; with [validate], never more than [totalValue].
// recharts 3.10.1 es6/util/DataUtils.js:24 (`isPercent`), :25 (`isNumber`:
// a number that is not NaN), :48-71
double rechartsPercentValue(
  Object? percent,
  double? totalValue, {
  double defaultValue = 0,
  bool validate = false,
}) {
  double value;
  switch (percent) {
    case final num n when !n.isNaN:
      value = n.toDouble();
    case final String s when s.length > 1 && s.indexOf('%') == s.length - 1:
      if (totalValue == null) return defaultValue;
      value = totalValue * jsParseFloat(s.substring(0, s.length - 1)) / 100;
    case final String s:
      value = jsNumberOf(s);
    default:
      return defaultValue;
  }
  if (value.isNaN) value = defaultValue;
  if (validate && totalValue != null && value > totalValue) value = totalValue;
  return value;
}

/// recharts' `isRenderableText`: what a `Text` writes (nullish, text, a
/// number, NaN included, or a boolean).
// recharts 3.10.1 es6/component/Text.js:66-68
bool rechartsIsRenderableText(Object? value) =>
    value == null || value is String || value is num || value is bool;

/// The value recharts' label list reads from a point's `value`: the last
/// element of an array (a stack's or a range's top), only when `Text` can
/// write it; null otherwise.
// recharts 3.10.1 es6/component/LabelList.js:47-53 (`defaultAccessor`)
Object? rechartsLabelValue(Object? value) {
  final last = value is List<Object?>
      ? (value.isEmpty ? null : value.last)
      : value;
  return rechartsIsRenderableText(last) ? last : null;
}

/// The names a plain JavaScript object inherits from `Object.prototype`:
/// reading one of them from a JSON object finds that inherited member.
const Set<String> kJsObjectPrototypeNames = {
  '__proto__',
  '__defineGetter__',
  '__defineSetter__',
  '__lookupGetter__',
  '__lookupSetter__',
  'constructor',
  'hasOwnProperty',
  'isPrototypeOf',
  'propertyIsEnumerable',
  'toLocaleString',
  'toString',
  'valueOf',
};

/// recharts' `hasDuplicate`: whether two of [texts] (each value's
/// `String()`) are the same key of a plain object, where a name the object
/// inherits ([kJsObjectPrototypeNames]) is taken on its first appearance.
// recharts 3.10.1 es6/util/DataUtils.js:72-86 (`cache[String(ary[i])]`)
bool rechartsHasDuplicate(Iterable<String> texts) {
  final seen = <String>{};
  for (final text in texts) {
    if (kJsObjectPrototypeNames.contains(text) || !seen.add(text)) {
      return true;
    }
  }
  return false;
}

/// es-toolkit's `toPath` of a deep key: `a.b[0]["c"]` is `a`, `b`, `0`,
/// `c`; a leading `.` gives an empty first key.
// es-toolkit 1.43.0 dist/compat/util/toPath.mjs:4-80
List<String> rechartsToPath(String deepKey) {
  final result = <String>[];
  final length = deepKey.length;
  if (length == 0) return result;
  var index = 0;
  final key = StringBuffer();
  var quoteChar = '';
  var bracket = false;
  if (deepKey.codeUnitAt(0) == 46) {
    result.add('');
    index++;
  }
  while (index < length) {
    final char = deepKey[index];
    if (quoteChar.isNotEmpty) {
      if (char == r'\' && index + 1 < length) {
        index++;
        key.write(deepKey[index]);
      } else if (char == quoteChar) {
        quoteChar = '';
      } else {
        key.write(char);
      }
    } else if (bracket) {
      if (char == '"' || char == "'") {
        quoteChar = char;
      } else if (char == ']') {
        bracket = false;
        result.add(key.toString());
        key.clear();
      } else {
        key.write(char);
      }
    } else if (char == '[') {
      bracket = true;
      if (key.isNotEmpty) {
        result.add(key.toString());
        key.clear();
      }
    } else if (char == '.') {
      if (key.isNotEmpty) {
        result.add(key.toString());
        key.clear();
      }
    } else {
      key.write(char);
    }
    index++;
  }
  if (key.isNotEmpty) result.add(key.toString());
  return result;
}

/// Whether es-toolkit's `get` reads [key] as a path when the object has no
/// field of that name (`isDeepKey`: a `.`, `[` or `]` in it).
// es-toolkit 1.43.0 dist/compat/_internal/isDeepKey.mjs:1-12
bool rechartsIsDeepKey(String key) =>
    key.contains('.') || key.contains('[') || key.contains(']');

/// recharts' `getBaseValueOfBar` for a number axis of [domainMin] to
/// [domainMax]: 0 when the domain holds it, else its end nearest 0.
// recharts 3.10.1 es6/util/ChartUtils.js:425-442
double rechartsBarBaseValue(double domainMin, double domainMax) {
  final minValue = math.min(domainMin, domainMax);
  final maxValue = math.max(domainMin, domainMax);
  if (minValue <= 0 && maxValue >= 0) return 0;
  if (maxValue < 0) return maxValue;
  return minValue;
}

/// recharts' `getBaseValue` of an Area without a `baseValue`: the domain's
/// maximum when it is below 0, else its minimum or 0, the larger.
// recharts 3.10.1 es6/cartesian/Area.js:502-530
double rechartsAreaBaseValue(double domainMin, double domainMax) {
  final maxValue = math.max(domainMin, domainMax);
  return maxValue < 0 ? maxValue : math.max(math.min(domainMin, domainMax), 0);
}

/// d3's `stackOffsetNone` over [values] (series by row, NaN for a value
/// `Number()` cannot read): each series starts where the one before it
/// ends, so a negative value lowers the stack. Returns each series' (base,
/// top) per row.
// recharts 3.10.1 es6/util/ChartUtils.js:341-374 (`getStackedData`,
// `stackOffsetNone`, `stackOrderNone`); d3-shape 3.2.0 src/stack.js:22-39
// and src/offset/none.js:1-9
List<List<(double, double)>> rechartsStack(List<List<double>> values) {
  final out = [
    for (final series in values) [for (final v in series) (0.0, v)],
  ];
  for (var i = 1; i < out.length; i++) {
    final s0 = out[i - 1];
    final s1 = out[i];
    for (var j = 0; j < s1.length; j++) {
      final base = s0[j].$2.isNaN ? s0[j].$1 : s0[j].$2;
      s1[j] = (base, s1[j].$2 + base);
    }
  }
  return out;
}

/// recharts' `truncateByDomain`: [value] (a stack's base and top) clamped
/// to the domain [domainMin]..[domainMax]; a NaN end takes the domain's.
// recharts 3.10.1 es6/util/ChartUtils.js:210-232
(double, double) rechartsTruncateByDomain(
  (double, double) value,
  double domainMin,
  double domainMax,
) {
  final minValue = math.min(domainMin, domainMax);
  final maxValue = math.max(domainMin, domainMax);
  var r0 = value.$1;
  var r1 = value.$2;
  if (r0.isNaN || r0 < minValue) r0 = minValue;
  if (r1.isNaN || r1 > maxValue) r1 = maxValue;
  if (r0 > maxValue) r0 = maxValue;
  if (r1 < minValue) r1 = minValue;
  return (r0, r1);
}

/// A tick recharts shows: its `index` among the axis' ticks and where its
/// label goes (`tickCoord`, moved in from the edge for the last one).
typedef RechartsShownTick = ({int index, double tickCoord});

/// recharts' `getTicks` for `interval: "preserveEnd"` (both axes' default)
/// and `minTickGap` 5: from the last tick back, a tick shows when its label
/// ([sizeOf], along the axis) fits inside [start]..[end] and keeps
/// [minTickGap] from the one shown after it; the last tick's label is first
/// moved in to end at [end]. [start] and [end] are the chart's edges along
/// the axis (`selectAxisViewBox`: the whole chart).
// recharts 3.10.1 es6/cartesian/getTicks.js:11-53 (`getTicksEnd`) and
// :119-171 (`getTicks`); es6/util/TickUtils.js:10-35 (`getTickBoundaries`,
// `isVisible`); the boundaries, es6/state/selectors/
// selectChartOffsetInternal.js:89-93 and es6/cartesian/XAxis.js:75
List<RechartsShownTick> rechartsTicksEnd(
  List<double> coordinates,
  double Function(int index) sizeOf, {
  required double start,
  required double end,
  double minTickGap = 5,
}) {
  final len = coordinates.length;
  if (len == 0) return const [];
  final sign = len >= 2 ? _mathSign(coordinates[1] - coordinates[0]) : 1.0;
  // getTickBoundaries: the start and end in the ticks' direction.
  final boundStart = sign == 1 ? start : end;
  var boundEnd = sign == 1 ? end : start;
  final shown = <RechartsShownTick>[];
  for (var i = len - 1; i >= 0; i--) {
    final coordinate = coordinates[i];
    double? size;
    double getSize() => size ??= sizeOf(i);
    double tickCoord;
    if (i == len - 1) {
      final gap = sign * (coordinate + sign * getSize() / 2 - boundEnd);
      tickCoord = gap > 0 ? coordinate - gap * sign : coordinate;
    } else {
      tickCoord = coordinate;
    }
    if (_isVisible(sign, tickCoord, getSize, boundStart, boundEnd)) {
      boundEnd = tickCoord - sign * (getSize() / 2 + minTickGap);
      shown.add((index: i, tickCoord: tickCoord));
    }
  }
  return shown.reversed.toList();
}

// recharts 3.10.1 es6/util/TickUtils.js:27-35
bool _isVisible(
  double sign,
  double tickPosition,
  double Function() getSize,
  double start,
  double end,
) {
  if (sign * tickPosition < sign * start || sign * tickPosition > sign * end) {
    return false;
  }
  final size = getSize();
  return sign * (tickPosition - sign * size / 2 - start) >= 0 &&
      sign * (tickPosition + sign * size / 2 - end) <= 0;
}

// recharts 3.10.1 es6/util/DataUtils.js:3-11 (`mathSign`): 0 for 0.
double _mathSign(double value) => value == 0
    ? 0
    : value > 0
    ? 1
    : -1;

/// recharts' `getCoordinatesOfGrid` without `syncWithTicks`: the shown
/// ticks' coordinates, then [minValue] and [maxValue] (the plot's edges)
/// when no tick is on them.
// recharts 3.10.1 es6/util/ChartUtils.js:84-104
List<double> rechartsGridCoordinates(
  Iterable<double> coordinates,
  double minValue,
  double maxValue,
) {
  var hasMin = false;
  var hasMax = false;
  final values = [for (final coordinate in coordinates) coordinate];
  for (final coordinate in values) {
    if (coordinate == minValue) hasMin = true;
    if (coordinate == maxValue) hasMax = true;
  }
  if (!hasMin) values.add(minValue);
  if (!hasMax) values.add(maxValue);
  return values;
}

/// recharts' `calculateActiveTickIndex` for ticks along one direction
/// ([coordinates], ascending): the tick whose half-way marks hold
/// [coordinate]; 0 with one tick or none; -1 when none holds it.
// recharts 3.10.1 es6/util/getActiveCoordinate.js:79-86 and :136-152
int rechartsActiveTickIndex(double coordinate, List<double> coordinates) {
  final len = coordinates.length;
  if (len <= 1) return 0;
  for (var i = 0; i < len; i++) {
    final curr = coordinates[i];
    final next = i + 1 < len ? coordinates[i + 1] : null;
    final prev = i > 0 ? coordinates[i - 1] : null;
    if (i == 0 && next != null && coordinate <= (curr + next) / 2) return i;
    if (i == len - 1 && prev != null && coordinate > (curr + prev) / 2) {
      return i;
    }
    if (i > 0 &&
        i < len - 1 &&
        prev != null &&
        next != null &&
        coordinate > (curr + prev) / 2 &&
        coordinate <= (curr + next) / 2) {
      return i;
    }
  }
  return -1;
}

/// recharts' tooltip offset (`offset: 10`).
// recharts 3.10.1 es6/component/Tooltip.js:58
const double kRechartsTooltipOffset = 10;

/// recharts' `getTooltipTranslateXY` for one axis, with its defaults (no
/// `position`, `allowEscapeViewBox` and `reverseDirection` false): 10px
/// past the [coordinate], or before it when the tooltip of [dimension]
/// would leave the view box (from [viewBoxStart], [viewBoxDimension] long),
/// never before the view box's start.
// recharts 3.10.1 es6/util/tooltip/translate.js:18-57; the view box is the
// plot (`selectChartViewBox`, es6/state/selectors/
// selectChartOffsetInternal.js:82-88, which `useViewBox` reads,
// es6/context/chartLayoutContext.js:10-18)
double rechartsTooltipTranslate({
  required double coordinate,
  required double dimension,
  required double viewBoxStart,
  required double viewBoxDimension,
  double offset = kRechartsTooltipOffset,
}) {
  final negative = coordinate - dimension - (offset > 0 ? offset : 0);
  final positive = coordinate + offset;
  final tooltipBoundary = positive + dimension;
  final viewBoxBoundary = viewBoxStart + viewBoxDimension;
  if (tooltipBoundary > viewBoxBoundary) {
    return math.max(negative, viewBoxStart);
  }
  return math.max(positive, viewBoxStart);
}

/// SVG's `text-anchor`.
enum RechartsTextAnchor {
  /// The text starts at x.
  start,

  /// The text is centred on x.
  middle,

  /// The text ends at x.
  end,
}

/// recharts' `verticalAnchor` of a `Text`.
enum RechartsVerticalAnchor {
  /// The cap height under y (`dy: capHeight`, 0.71em).
  start,

  /// The cap height centred on y (`dy: capHeight / 2`).
  middle,

  /// The baseline on y (`dy: 0`).
  end,
}

/// recharts' `Text`: SVG text broken into words and lines, each line a
/// `tspan` placed by its anchor, the block by its first line's baseline
/// (`capHeight` 0.71em, d3's; `lineHeight` 1em), turned by an angle about
/// its anchor point.
///
/// SVG puts a line's baseline at y plus its `dy`; Flutter lays text out
/// from the top of its line box, so each line is moved up by the font's
/// distance from that top to its alphabetic baseline.
// recharts 3.10.1 es6/component/Text.js:22 (`BREAKING_SPACES`), :23-48
// (`calculateWordWidths`), :69-86 (`calculate`), :150-187
// (`getWordsByLines`: no `maxLines` or `scaleToFit` from CopilotKit),
// :188-200 (`textDefaultProps`), :236-282 (`startDy`, one `tspan` per line
// joined with a space, `rotate(angle, x, y)`)
class RechartsText {
  /// Text in [style] at [textScaler].
  RechartsText(this.style, this.textScaler);

  /// The style: family, size, weight, colour, and no line height, so a
  /// line is as tall as the font's own (CSS `normal`).
  final TextStyle style;

  /// The text scale.
  final TextScaler textScaler;

  /// recharts' `BREAKING_SPACES`.
  static final RegExp breakingSpaces = RegExp('[ \f\n\r\t\v  ]+');

  TextPainter _layout(String text, {int? maxLines}) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: maxLines,
  )..layout();

  /// The font size in pixels, at the text scale: one `em`.
  double get em => textScaler.scale(style.fontSize ?? 14);

  /// The size of [text] as recharts' `getStringSize` reads it: the box of a
  /// `white-space: pre` span (its advance width, its lines' height; a line
  /// feed starts a line) in this style.
  // recharts 3.10.1 es6/util/DOMUtils.js:14-22 (`SPAN_STYLE`), :41-65
  // (`measureTextWithDOM`: `getBoundingClientRect`)
  Size measure(String text) {
    final painter = _layout(text);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  /// The lines recharts' `Text` writes for [text]: its words (split on
  /// [breakingSpaces]) joined with a space, on one line when [width] is null
  /// (JavaScript's falsy `width`: none, 0, NaN), else broken where a word
  /// and a no-break space would not fit strictly within `Number(width)` (a
  /// word wider than that keeps a line of its own; a NaN puts every word on
  /// a line of its own).
  List<String> lines(String text, {double? width}) {
    final words = text.split(breakingSpaces);
    if (width == null) return [words.join(' ')];
    final space = measure(' ').width;
    final out = <({List<String> words, double width})>[];
    for (final word in words) {
      final size = measure(word).width;
      final current = out.lastOrNull;
      if (current != null && current.width + size + space < width) {
        current.words.add(word);
        out[out.length - 1] = (
          words: current.words,
          width: current.width + size + space,
        );
      } else {
        out.add((words: [word], width: size));
      }
    }
    return [for (final line in out) line.words.join(' ')];
  }

  /// Paints [text] at ([x], [y]) by its [anchor] and [vertical] anchor,
  /// broken into [lines] at [width], turned [angle] degrees about that point
  /// (SVG's `rotate`, clockwise on screen for a positive angle). Returns each
  /// line it painted with its box, unturned.
  List<RechartsTextLine> paint(
    ui.Canvas canvas,
    String text,
    double x,
    double y, {
    RechartsTextAnchor anchor = RechartsTextAnchor.start,
    RechartsVerticalAnchor vertical = RechartsVerticalAnchor.end,
    double angle = 0,
    double? width,
  }) {
    final written = lines(text, width: width);
    final count = written.length;
    // Text.js:236-249: `calc(capHeight)`, `calc((n - 1) / 2 * -lineHeight +
    // (capHeight / 2))`, `calc((n - 1) * -lineHeight)`.
    final startDy = switch (vertical) {
      RechartsVerticalAnchor.start => .71 * em,
      RechartsVerticalAnchor.middle => (count - 1) / 2 * -em + .71 * em / 2,
      RechartsVerticalAnchor.end => (count - 1) * -em,
    };
    if (angle != 0) {
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(angle * math.pi / 180);
    }
    final origin = angle == 0 ? Offset(x, y) : Offset.zero;
    final out = <RechartsTextLine>[];
    for (var i = 0; i < count; i++) {
      final painter = _layout(written[i], maxLines: 1);
      final baseline = painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      // Each `tspan` has the text's x, so each line is anchored on its own.
      final dx = switch (anchor) {
        RechartsTextAnchor.start => 0.0,
        RechartsTextAnchor.middle => -painter.width / 2,
        RechartsTextAnchor.end => -painter.width,
      };
      final offset = Offset(dx, startDy + i * em - baseline);
      painter.paint(canvas, origin + offset);
      out.add((
        text: written[i],
        box: Offset(x, y) + offset & painter.size,
        color: style.color,
      ));
      painter.dispose();
    }
    if (angle != 0) canvas.restore();
    return out;
  }
}

/// A line of text a [RechartsText] painted: its text, its box (unturned)
/// and its colour.
typedef RechartsTextLine = ({String text, Rect box, Color? color});

/// es-toolkit's `sortBy(items, key)` as recharts sorts with it: stable,
/// ascending by [keyOf] compared with JavaScript's `<` and `>` (UTF-16 code
/// units for text, numerically for numbers), a null key after the rest.
///
/// recharts sorts the tooltip's rows by `name` (`Tooltip`'s default
/// `itemSorter: 'name'`) and the legend's entries by `value` (`Legend`'s
/// default `itemSorter: 'value'`, which CopilotKit's `LEGEND_PROPS` keep).
// es-toolkit 1.43.0 dist/compat/array/sortBy.mjs:5-14, array/orderBy.mjs:
// 5-76, _internal/compareValues.mjs:1-31 (`getPriority`: null 2, undefined
// 3); recharts 3.10.1 es6/component/Tooltip.js:55, es6/component/
// DefaultTooltipContent.js:47-53, :83; es6/component/Legend.js:176,
// es6/state/selectors/legendSelectors.js:6-10
List<T> rechartsSortBy<T>(List<T> items, Object? Function(T item) keyOf) {
  int priority(Object? key) => key == null
      ? 2
      : key is num && key.isNaN
      ? 4
      : 0;
  // JavaScript's `<` (ECMA-262 7.2.13): text by code units, anything else
  // by its number, where NaN is neither less nor greater.
  double numberOf(Object? key) => switch (key) {
    final num n => n.toDouble(),
    final bool b => b ? 1 : 0,
    final String s => jsNumberOf(s),
    _ => double.nan,
  };
  int compare(Object? a, Object? b) {
    if (a == b) return 0;
    final pa = priority(a);
    final pb = priority(b);
    if (pa == 0 && pb == 0) {
      if (a is String && b is String) return a.compareTo(b).sign;
      final na = numberOf(a);
      final nb = numberOf(b);
      if (na < nb) return -1;
      if (na > nb) return 1;
    }
    return pa - pb;
  }

  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])]
    ..sort((a, b) {
      final byKey = compare(keyOf(a.$2), keyOf(b.$2));
      return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
    });
  return [for (final (_, item) in indexed) item];
}

// PORT STATUS: confidence=high todos=0 upstream=recharts@3.10.1
