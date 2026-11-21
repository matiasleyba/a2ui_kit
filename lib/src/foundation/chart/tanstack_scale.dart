// TanStack Charts' own linear scale and ticks, the scales of the
// playground's LineChart, AreaChart, BarChart, ScatterChart and Sparkline
// (`scaleLinear` from `@tanstack/charts/scales/linear`).
//
// Ported from the published source of @tanstack/charts 1.1.0 (MIT, (c)
// Tanner Linsley), the version the playground's lockfile pins:
// `dist/scales/ticks.js`, `dist/scales/linear.js`, `dist/scale-input.js`
// and `dist/scene.js`. See NOTICE.md.

import 'dart:math' as math;

import 'package:a2ui_kit/src/functions/calc.dart';

double _pow10(double exponent) => math.pow(10, exponent).toDouble();

// @tanstack/charts 1.1.0 dist/scales/ticks.js:1
const List<double> _preferredMultiples = [1, 2, 5, 10];

/// TanStack's `ticks(start, stop, count)`: about [count] round values from
/// [start] to [stop] (in their order).
// @tanstack/charts 1.1.0 dist/scales/ticks.js:2-19
List<double> tanstackTicks(double start, double stop, double count) {
  if (!(count > 0)) return const [];
  if (start == stop) return [start];
  final descending = stop < start;
  final plan = _createTickPlan(
    descending ? stop : start,
    descending ? start : stop,
    count,
  );
  if (!(plan.lastIndex >= plan.firstIndex)) return const [];
  return [
    for (
      var offset = 0;
      offset < plan.lastIndex - plan.firstIndex + 1;
      offset++
    )
      _valueAtIndex(
        descending ? plan.lastIndex - offset : plan.firstIndex + offset,
        plan.interval,
      ),
  ];
}

/// TanStack's `tickIncrement`: the step, negative for the inverse of a step
/// below 1.
// @tanstack/charts 1.1.0 dist/scales/ticks.js:20-22
double tanstackTickIncrement(double start, double stop, double count) =>
    _createTickPlan(start, stop, count).interval;

/// TanStack's `tickStep`: the step itself, negative when [stop] is below
/// [start].
// @tanstack/charts 1.1.0 dist/scales/ticks.js:23-32
double tanstackTickStep(double start, double stop, double count) {
  final descending = stop < start;
  final interval = tanstackTickIncrement(
    descending ? stop : start,
    descending ? start : stop,
    count,
  );
  final magnitude = interval < 0 ? -1 / interval : interval;
  return descending ? -magnitude : magnitude;
}

// @tanstack/charts 1.1.0 dist/scales/ticks.js:33-44
({double firstIndex, double lastIndex, double interval}) _createTickPlan(
  double start,
  double stop,
  double count,
) {
  var requestedCount = count;
  while (true) {
    final interval = _chooseInterval(start, stop, requestedCount);
    final firstIndex = _indexAtOrAbove(start, interval);
    final lastIndex = _indexAtOrBelow(stop, interval);
    if (lastIndex >= firstIndex ||
        !(requestedCount >= .5 && requestedCount < 2)) {
      return (firstIndex: firstIndex, lastIndex: lastIndex, interval: interval);
    }
    requestedCount *= 2;
  }
}

// @tanstack/charts 1.1.0 dist/scales/ticks.js:45-51
double _chooseInterval(double start, double stop, double count) {
  final target = (stop - start) / math.max(0, count);
  final exponent = jsLog10(target).floorToDouble();
  final decade = _pow10(exponent);
  final multiple = _closestPreferredMultiple(target / decade);
  return exponent < 0 ? -_pow10(-exponent) / multiple : decade * multiple;
}

// @tanstack/charts 1.1.0 dist/scales/ticks.js:52-60
double _closestPreferredMultiple(double normalizedTarget) {
  var selected = _preferredMultiples[0];
  for (final candidate in _preferredMultiples.skip(1)) {
    final midpoint = math.sqrt(selected * candidate);
    if (!(normalizedTarget >= midpoint)) break;
    selected = candidate;
  }
  return selected;
}

// @tanstack/charts 1.1.0 dist/scales/ticks.js:61-65
double _indexAtOrAbove(double value, double interval) {
  final position = interval < 0 ? value * -interval : value / interval;
  final nearest = jsMathRound(position);
  return nearest < position ? nearest + 1 : nearest;
}

// @tanstack/charts 1.1.0 dist/scales/ticks.js:66-70
double _indexAtOrBelow(double value, double interval) {
  final position = interval < 0 ? value * -interval : value / interval;
  final nearest = jsMathRound(position);
  return nearest > position ? nearest - 1 : nearest;
}

// @tanstack/charts 1.1.0 dist/scales/ticks.js:71-73
double _valueAtIndex(double index, double interval) =>
    interval < 0 ? index / -interval : index * interval;

/// TanStack's `scaleLinear`: a domain of two numbers onto a range.
class TanstackLinearScale {
  /// A scale of [domain0]..[domain1].
  TanstackLinearScale(this.domain0, this.domain1);

  /// The start of the domain.
  double domain0;

  /// The end of the domain.
  double domain1;

  /// [value] on a range from [range0] to [range1]; the middle when the
  /// domain is a single value; NaN for a [value] that is not finite.
  ///
  /// A domain whose span overflows a double (-1e308..1e308: 2e308 is
  /// Infinity) maps a value whose distance from the start is finite to
  /// [range0] (1e308 / Infinity is 0; the start itself, 0 / Infinity) and
  /// one whose distance overflows too to NaN (Infinity / Infinity), as
  /// TanStack's arithmetic does.
  // @tanstack/charts 1.1.0 dist/scales/linear.js:6-9 (a value that is not
  // finite maps to undefined, which the configured scale turns into NaN:
  // dist/configured-scale.js:26-29) and :76-81 (`interpolate`)
  double map(double value, double range0, double range1) {
    if (!value.isFinite) return double.nan;
    final span = domain1 - domain0;
    // `span ? … : 0.5`: NaN is falsy too. No data reaches a NaN span: a
    // domain end that is not finite is refused by `pair()` (dist/scales/
    // linear.js:82-89, a TypeError) and is never kept by `nice()` (:35-67,
    // which assigns a domain only once a step repeats, :46-52, so an
    // overflowing end, `ceil(1.79e308 / 1e307) * 1e307`, followed by a NaN
    // step, is dropped); the playground drops rows that are not finite
    // (`isNum`, chart-kit.tsx:18-19). Two finite ends give a finite or an
    // infinite span, never NaN.
    final ratio = span != 0 && !span.isNaN ? (value - domain0) / span : .5;
    return range0 + ratio * (range1 - range0);
  }

  /// About [count] round values in the domain.
  // @tanstack/charts 1.1.0 dist/scales/linear.js:26
  List<double> ticks(double count) => tanstackTicks(domain0, domain1, count);

  /// The scale's own tick text at [count] ticks: as many decimals as the
  /// step needs (`toFixed`), else JavaScript's `String()`; never "-0".
  // @tanstack/charts 1.1.0 dist/scales/linear.js:27-34
  String Function(double value) tickFormat(double count) {
    final step = tanstackTickStep(domain0, domain1, count).abs();
    final digits = step > 0 && step < 1
        ? math.min(20, math.max(0, -jsLog10(step).floor()))
        : 0;
    return (value) {
      final formatted = digits != 0
          ? jsToFixed(value, digits)
          : jsNumberString(value);
      return formatted == '-0' ? '0' : formatted;
    };
  }

  /// Extends the domain to round values at about [count] ticks.
  // @tanstack/charts 1.1.0 dist/scales/linear.js:35-67
  void nice(double count) {
    var start = domain0;
    var stop = domain1;
    var reversed = false;
    if (stop < start) {
      (start, stop) = (stop, start);
      reversed = true;
    }
    double? previousStep;
    for (var remaining = 10; remaining > 0; remaining--) {
      final step = tanstackTickIncrement(start, stop, count);
      if (step == previousStep) {
        if (reversed) {
          domain0 = stop;
          domain1 = start;
        } else {
          domain0 = start;
          domain1 = stop;
        }
        break;
      }
      if (step > 0) {
        start = (start / step).floorToDouble() * step;
        stop = (stop / step).ceilToDouble() * step;
      } else if (step < 0) {
        start = (start * step).ceilToDouble() / step;
        stop = (stop * step).floorToDouble() / step;
      } else {
        break;
      }
      previousStep = step;
    }
  }
}

/// The domain TanStack infers for a linear scale from the channel [values]
/// (finite numbers): their extent, taking in 0 with [includeZero]; a single
/// value widens by 5% of itself each way (0 becomes 0..1).
// @tanstack/charts 1.1.0 dist/scale-input.js:82-113 (`inferScaleDomain`)
(double, double)? tanstackInferDomain(
  Iterable<double> values, {
  bool includeZero = false,
}) {
  var minimum = double.infinity;
  var maximum = double.negativeInfinity;
  var observed = false;
  for (final value in values) {
    if (!value.isFinite) continue;
    observed = true;
    minimum = math.min(minimum, value);
    maximum = math.max(maximum, value);
  }
  if (!observed) return null;
  if (includeZero) {
    minimum = math.min(0, minimum);
    maximum = math.max(0, maximum);
  }
  if (minimum == maximum) {
    if (minimum == 0) return (0, 1);
    var offset = minimum.abs() * .05;
    if (offset == 0) offset = 1;
    minimum -= offset;
    maximum += offset;
  }
  return (minimum, maximum);
}

/// A linear scale over [values] as a TanStack chart builds it: the inferred
/// domain ([tanstackInferDomain]; 0..1 without values), made nice at
/// [niceCount] ticks (the axis' tick count) when [niceCount] is given.
// @tanstack/charts 1.1.0 dist/scale-input.js:2-20 (`resolveScaleInput`;
// `niceCount` is the scale's tick count, dist/configured-scale.js:3-8)
TanstackLinearScale tanstackLinearScale(
  Iterable<double> values, {
  bool includeZero = false,
  double? niceCount,
}) {
  final domain = tanstackInferDomain(values, includeZero: includeZero);
  final scale = domain == null
      ? TanstackLinearScale(0, 1)
      : TanstackLinearScale(domain.$1, domain.$2);
  // @tanstack/charts 1.1.0 dist/scale-input.js:123-130 (`applyScaleNice`)
  if (niceCount != null) scale.nice(niceCount);
  return scale;
}

/// The tick count of an axis [length] pixels long: [count] when the axis
/// sets one, else one tick per 92px (x) or 48px (y), from 2 to 8 (x) or 7
/// (y).
// @tanstack/charts 1.1.0 dist/scene.js:1127-1152 (`resolveTickCount`),
// called with 92/8 for x and 48/7 for y at dist/scene.js:578-583
double tanstackTickCount({
  required double length,
  required bool x,
  double? count,
}) {
  if (count != null) {
    return math.max(
      1,
      (count.isFinite ? math.max(0, count) : 0).floorToDouble(),
    );
  }
  final spacing = x ? 92.0 : 48.0;
  final maximum = x ? 8.0 : 7.0;
  return math.max(2, math.min(maximum, (length / spacing).floorToDouble()));
}

// PORT STATUS: confidence=high todos=0 upstream=@tanstack/charts@1.1.0
