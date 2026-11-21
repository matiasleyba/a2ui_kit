// TanStack Charts' stacking and pie layout: the stacks of the playground's
// BarChart and AreaChart (`stack({order})`), which bar ends a stack
// rounds, and the angles of its PieChart (`pie({gapAngle})`).
//
// Ported from the published source of @tanstack/charts 1.1.0 (MIT, (c)
// Tanner Linsley): `dist/stack-internal.js`, `dist/stack-ends-internal.js`,
// `dist/polar-pie.js` and `dist/proportional-interval-internal.js`; the
// stack generator is d3-shape 3.2.0's `stack` (ISC, (c) Mike Bostock),
// `src/stack.js`, with TanStack's own diverging offset. See NOTICE.md.

import 'dart:math' as math;

import 'package:a2ui_kit/src/functions/calc.dart';

/// TanStack's `valueKey`: the identity of a chart value, so that the text
/// "1" and the number 1 differ.
// @tanstack/charts 1.1.0 dist/scales.js:143-147
String tanstackValueKey(Object? value) => switch (value) {
  final String s => 'string:${s.length}:$s',
  final num n => 'number:${jsNumberString(n)}',
  null => 'object:null',
  _ => '${value.runtimeType}:$value',
};

/// The extent of each stacked value: its start and end.
typedef TanstackExtent = ({double start, double end});

/// A stack with two values at one position for one series: TanStack
/// throws "A stack requires at most one value for each position and
/// series", and the playground's `ChartBoundary` then shows "Waiting for
/// complete data".
class TanstackStackError extends Error {
  /// The error for a duplicate [position] and [series].
  TanstackStackError(this.position, this.series);

  /// The position.
  final Object position;

  /// The series.
  final Object series;

  @override
  String toString() =>
      'A stack requires at most one value for each position and series; '
      'duplicate $position / $series';
}

/// TanStack's `stackValues` with its default (diverging) offset: for each
/// index, the extent of `values[index]` stacked at `positions[index]` with
/// the other series there, positives up from 0 and negatives down, series
/// in [order] (then first appearance). Null for an index that is not
/// stacked. Throws [TanstackStackError] for two values at one position of
/// one series.
// @tanstack/charts 1.1.0 dist/stack-internal.js:156-184 (`stackValues`) and
// 10-74 (`stackExtents`, offset `stackOffsetDivergingZeroAware`, no
// anchor)
List<TanstackExtent?> tanstackStackValues(
  List<Object> positions,
  List<double> values,
  List<Object> series, {
  List<Object> order = const [],
}) {
  final positionIndex = <String, int>{};
  final seriesSeen = <String>{};
  final seriesInput = <Object>[];
  for (var index = 0; index < positions.length; index++) {
    positionIndex.putIfAbsent(
      tanstackValueKey(positions[index]),
      () => positionIndex.length,
    );
    if (seriesSeen.add(tanstackValueKey(series[index]))) {
      seriesInput.add(series[index]);
    }
  }
  final rows = [
    for (var i = 0; i < positionIndex.length; i++) <String, double>{},
  ];
  final sourceIndices = <String, int>{};
  for (var index = 0; index < positions.length; index++) {
    final position = positionIndex[tanstackValueKey(positions[index])]!;
    final seriesIdentity = tanstackValueKey(series[index]);
    final identity = '$position:$seriesIdentity';
    if (sourceIndices.containsKey(identity)) {
      throw TanstackStackError(positions[index], series[index]);
    }
    sourceIndices[identity] = index;
    rows[position][seriesIdentity] = values[index];
  }
  // @tanstack/charts 1.1.0 dist/stack-internal.js:194-202 (`orderedSeries`
  // with an explicit order)
  final orderKeys = {for (final s in order) tanstackValueKey(s)};
  final ordered = [
    ...order,
    for (final s in seriesInput)
      if (!orderKeys.contains(tanstackValueKey(s))) s,
  ];
  final identities = [for (final s in ordered) tanstackValueKey(s)];
  // d3-shape 3.2.0 src/stack.js: each series' [0, value] (`row[key] ?? 0`),
  // then the offset over the series in order.
  final stacked = [
    for (final key in identities)
      [
        for (final row in rows) <double>[0, row[key] ?? 0],
      ],
  ];
  _stackOffsetDivergingZeroAware(stacked);
  final output = List<TanstackExtent?>.filled(positions.length, null);
  for (var s = 0; s < stacked.length; s++) {
    for (var position = 0; position < stacked[s].length; position++) {
      final source = sourceIndices['$position:${identities[s]}'];
      if (source == null) continue;
      final extent = stacked[s][position];
      output[source] = (start: extent[0], end: extent[1]);
    }
  }
  return output;
}

// @tanstack/charts 1.1.0 dist/stack-internal.js:75-108
// (`stackOffsetDivergingZeroAware`, with d3's default order: the series
// in key order)
void _stackOffsetDivergingZeroAware(List<List<List<double>>> series) {
  if (series.isEmpty) return;
  final negativeSide = [
    for (final values in series)
      () {
        var negative = false;
        var positive = false;
        for (final extent in values) {
          final value = extent[1] - extent[0];
          if (value < 0) {
            negative = true;
          } else if (value > 0) {
            positive = true;
          }
        }
        return negative && !positive;
      }(),
  ];
  final positionCount = series[0].length;
  for (var position = 0; position < positionCount; position += 1) {
    var positiveBaseline = 0.0;
    var negativeBaseline = 0.0;
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final extent = series[seriesIndex][position];
      final value = extent[1] - extent[0];
      if (value > 0) {
        extent[0] = positiveBaseline;
        extent[1] = positiveBaseline += value;
      } else if (value < 0) {
        extent[1] = negativeBaseline;
        extent[0] = negativeBaseline += value;
      } else if (value == 0) {
        extent[0] = extent[1] = negativeSide[seriesIndex]
            ? negativeBaseline
            : positiveBaseline;
      } else {
        extent[0] = 0;
        extent[1] = value;
      }
    }
  }
}

/// Which ends of each stacked bar are the stack's outer ends, to round:
/// among the bars that are not empty, the end at the stack's maximum (when
/// above 0) and the one at its minimum (when below 0). Null for a bar with
/// no outer end.
// @tanstack/charts 1.1.0 dist/stack-ends-internal.js:3-75
// (`stackOuterEnds` with the diverging offset, `groupStackEnds`,
// `markExtremeEnd`)
List<({bool start, bool end})?> tanstackStackOuterEnds(
  List<Object> positions,
  List<double> values,
  List<TanstackExtent?> extents,
) {
  final outerEnds = List<({bool start, bool end})?>.filled(
    positions.length,
    null,
  );
  // `groupStackEnds`: rows with a value and a length, by position.
  final groups = <String, List<int>>{};
  for (var index = 0; index < positions.length; index++) {
    final extent = extents[index];
    if (extent == null) continue;
    if (values[index] == 0 || extent.start == extent.end) continue;
    (groups[tanstackValueKey(positions[index])] ??= []).add(index);
  }
  void markExtremeEnd(List<int> rows, {required bool maximum}) {
    if (rows.isEmpty) return;
    final ends = [
      for (final index in rows) ...[extents[index]!.start, extents[index]!.end],
    ];
    final target = ends.reduce(maximum ? math.max : math.min);
    for (final index in rows) {
      final extent = extents[index]!;
      final start = extent.start == target;
      final end = extent.end == target;
      if (!start && !end) continue;
      final existing = outerEnds[index];
      outerEnds[index] = (
        start: existing?.start == true || start,
        end: existing?.end == true || end,
      );
    }
  }

  for (final rows in groups.values) {
    final ends = [
      for (final index in rows) ...[extents[index]!.start, extents[index]!.end],
    ];
    final minimum = ends.reduce(math.min);
    final maximum = ends.reduce(math.max);
    if (maximum > 0) markExtremeEnd(rows, maximum: true);
    if (minimum < 0) markExtremeEnd(rows, maximum: false);
  }
  return outerEnds;
}

/// A slice of a TanStack pie: its share and its angles (radians, clockwise
/// from 12 o'clock).
typedef TanstackPieSlice = ({
  double fraction,
  double startAngle,
  double endAngle,
});

/// TanStack's `pie(rows, {gapAngle})` over a whole turn: each positive
/// value takes its share of the turn less the gaps, in data order from 0,
/// and a gap of [gapAngle] follows it (the last one too); a value of 0
/// takes no angle and no gap. The slices' pad angle is 0.
// @tanstack/charts 1.1.0 dist/polar-pie.js:5-67 (`pie`, no order) and
// dist/proportional-interval-internal.js:1-60
// (`allocateProportionalIntervals`, `gapAfterLast` on a whole turn)
List<TanstackPieSlice> tanstackPie(List<double> values, {double gapAngle = 0}) {
  const start = 0.0;
  const end = math.pi * 2;
  const span = end - start;
  var positiveCount = 0;
  var unscaledTotal = 0.0;
  var maximum = 0.0;
  for (final weight in values) {
    if (weight > 0) positiveCount += 1;
    unscaledTotal += weight;
    maximum = math.max(maximum, weight);
  }
  final valueScale = unscaledTotal.isFinite ? 1.0 : maximum;
  final total = valueScale == 1
      ? unscaledTotal
      : values.fold<double>(0, (sum, weight) => sum + weight / valueScale);
  // A whole turn, clockwise: `gapAfterLast` holds and the direction is 1
  // (dist/polar-pie.js:33, 41).
  final gapCount = positiveCount == 0 ? 0 : math.max(0, positiveCount - 1) + 1;
  final totalGap = gapCount * gapAngle;
  final drawableSpan = span.abs() - totalGap;
  final intervals = <TanstackPieSlice>[];
  var cursor = start;
  var remainingPositive = positiveCount;
  for (final weight in values) {
    final fraction = total == 0 ? 0.0 : weight / valueScale / total;
    final intervalStart = cursor;
    var intervalEnd = cursor;
    if (weight > 0) {
      remainingPositive -= 1;
      intervalEnd = remainingPositive == 0
          ? end - gapAngle
          : cursor + drawableSpan * fraction;
      cursor = intervalEnd;
      cursor += gapAngle;
    }
    intervals.add((
      fraction: fraction,
      startAngle: intervalStart,
      endAngle: intervalEnd,
    ));
  }
  return intervals;
}

// PORT STATUS: confidence=high todos=0 upstream=@tanstack/charts@1.1.0
