// Chart scales.
//
// `linearTicks`, `tickIncrement` and `LinearScale.nice` port d3-array 3.2.4's
// `ticks`/`tickIncrement` and d3-scale 4.0.2's `linear.nice` (ISC, (c) Mike
// Bostock); `BandScale` and `PointScale` port d3-scale 4.0.2's band and
// point scales (ISC). recharts 3.10.1 draws its axes on these scales
// (through victory-vendor 37.3.6), and the playground's TanStack Charts
// uses the band and point scales. `rechartsNiceTicks`,
// `rechartsFixedTicks` and `rechartsNumberAxis` port recharts 3.10.1's
// `getNiceTickValues`, `getTickValuesFixedDomain` and the axis domain
// selectors (MIT, (c) Recharts Group), on recharts' decimal arithmetic
// (`JsDecimal`). See NOTICE.md.

import 'dart:math' as math;

import 'package:a2ui_kit/src/foundation/chart/js_decimal.dart';
import 'package:a2ui_kit/src/functions/calc.dart';

// d3-array 3.2.4 src/ticks.js:1-3
final double _e10 = math.sqrt(50);
final double _e5 = math.sqrt(10);
final double _e2 = math.sqrt(2);

double _pow10(int power) => math.pow(10, power).toDouble();

/// d3's `tickSpec`: the first and last tick index and the increment (a
/// negative increment is the inverse of the step).
// d3-array 3.2.4 src/ticks.js:5-27
(int, int, double) _tickSpec(double start, double stop, double count) {
  final step = (stop - start) / math.max(0, count);
  final power = jsLog10(step).floor();
  final error = step / _pow10(power);
  final factor = error >= _e10
      ? 10
      : error >= _e5
      ? 5
      : error >= _e2
      ? 2
      : 1;
  int i1;
  int i2;
  double inc;
  if (power < 0) {
    inc = _pow10(-power) / factor;
    i1 = jsMathRound(start * inc).toInt();
    i2 = jsMathRound(stop * inc).toInt();
    if (i1 / inc < start) ++i1;
    if (i2 / inc > stop) --i2;
    inc = -inc;
  } else {
    inc = _pow10(power) * factor;
    i1 = jsMathRound(start / inc).toInt();
    i2 = jsMathRound(stop / inc).toInt();
    if (i1 * inc < start) ++i1;
    if (i2 * inc > stop) --i2;
  }
  if (i2 < i1 && .5 <= count && count < 2) {
    return _tickSpec(start, stop, count * 2);
  }
  return (i1, i2, inc);
}

/// d3's `tickIncrement`: the step of about [count] ticks over
/// [start]..[stop], as a power of ten times 1, 2 or 5; negative for a step
/// below 1 (its inverse, negated).
// d3-array 3.2.4 src/ticks.js:46-49
double tickIncrement(double start, double stop, double count) {
  if (!start.isFinite || !stop.isFinite || !(count > 0)) return double.nan;
  if (start == stop) return double.nan;
  return _tickSpec(start, stop, count).$3;
}

/// d3's `ticks`: about [count] round values between [start] and [stop].
// d3-array 3.2.4 src/ticks.js:29-44
List<double> linearTicks(double start, double stop, int count) {
  if (count <= 0 || !start.isFinite || !stop.isFinite) return const [];
  if (start == stop) return [start];
  final reverse = stop < start;
  final (i1, i2, inc) = reverse
      ? _tickSpec(stop, start, count.toDouble())
      : _tickSpec(start, stop, count.toDouble());
  if (!(i2 >= i1)) return const [];
  final n = i2 - i1 + 1;
  if (reverse) {
    return [
      for (var i = 0; i < n; i++)
        if (inc < 0) (i2 - i) / -inc else (i2 - i) * inc,
    ];
  }
  return [
    for (var i = 0; i < n; i++)
      if (inc < 0) (i1 + i) / -inc else (i1 + i) * inc,
  ];
}

/// A continuous scale from a numeric domain onto a range of pixels.
class LinearScale {
  /// A scale of [domain0]..[domain1].
  LinearScale(this.domain0, this.domain1);

  /// A scale over the extent of [values] (0..1 when there are none).
  factory LinearScale.extent(Iterable<double> values) {
    var low = double.infinity;
    var high = double.negativeInfinity;
    for (final value in values) {
      if (!value.isFinite) continue;
      low = math.min(low, value);
      high = math.max(high, value);
    }
    if (low > high) return LinearScale(0, 1);
    return LinearScale(low, high);
  }

  /// The start of the domain.
  double domain0;

  /// The end of the domain.
  double domain1;

  /// Extends the domain to round values, as d3's `linear.nice(count)` does,
  /// so the first and last of [ticks] (at the same [count]) are its ends.
  /// As in d3, the domain only changes once the step settles within ten
  /// rounds.
  // d3-scale 4.0.2 src/linear.js:19-55
  void nice([int count = 10]) {
    var start = domain0;
    var stop = domain1;
    final reverse = stop < start;
    if (reverse) (start, stop) = (stop, start);
    double? previous;
    for (var iterations = 10; iterations > 0; iterations--) {
      final step = tickIncrement(start, stop, count.toDouble());
      if (step == previous) {
        domain0 = reverse ? stop : start;
        domain1 = reverse ? start : stop;
        return;
      } else if (step > 0) {
        start = (start / step).floorToDouble() * step;
        stop = (stop / step).ceilToDouble() * step;
      } else if (step < 0) {
        start = (start * step).ceilToDouble() / step;
        stop = (stop * step).floorToDouble() / step;
      } else {
        break;
      }
      previous = step;
    }
  }

  /// About [count] round values in the domain.
  // d3-scale 4.0.2 src/linear.js:9-12
  List<double> ticks([int count = 10]) => linearTicks(domain0, domain1, count);

  /// [value] on a range from [range0] to [range1]; the middle of the range
  /// when the domain is a single value, as d3 maps it.
  // d3-scale 4.0.2 src/continuous.js:12-16 (`normalize`), :85-87; d3-
  // interpolate 3.0.1 src/number.js:1-5 (`a * (1 - t) + b * t`)
  double map(double value, double range0, double range1) {
    final span = domain1 - domain0;
    final t = span == 0 ? .5 : (value - domain0) / span;
    return range0 * (1 - t) + range1 * t;
  }

  /// The domain value at the pixel [position] of the range.
  double invert(double position, double range0, double range1) {
    final span = range1 - range0;
    final t = span == 0 ? .5 : (position - range0) / span;
    return domain0 * (1 - t) + domain1 * t;
  }
}

/// A band scale (d3's `scaleBand`): equal bands for categories, with inner
/// and outer padding as fractions of a step, centred in the range.
// d3-scale 4.0.2 src/band.js:5-83
class BandScale {
  /// A scale of [domain] with the given padding.
  const BandScale(
    this.domain, {
    this.paddingInner = 0,
    this.paddingOuter = 0,
    this.align = .5,
  });

  /// d3's `scaleBand().padding(padding)`: inner and outer padding alike.
  // d3-scale 4.0.2 src/band.js:58-60
  const BandScale.padded(this.domain, double padding)
    : paddingInner = padding,
      paddingOuter = padding,
      align = .5;

  /// The categories, in order.
  final List<String> domain;

  /// The gap between bands, as a fraction of a step (at most 1).
  final double paddingInner;

  /// The space before the first band and after the last one, in steps.
  final double paddingOuter;

  /// Where the bands sit in leftover space: 0 start, .5 centre, 1 end.
  final double align;

  double _inner() => math.min(1, paddingInner);

  /// The distance from one band's start to the next one's, on a range from
  /// [range0] to [range1].
  // d3-scale 4.0.2 src/band.js:20-26 (`rescale`)
  double step(double range0, double range1) {
    final n = domain.length;
    return (range1 - range0).abs() /
        math.max(1, n - _inner() + paddingOuter * 2);
  }

  /// The width of a band.
  double bandwidth(double range0, double range1) =>
      step(range0, range1) * (1 - _inner());

  /// The start of the band at [index].
  // d3-scale 4.0.2 src/band.js:20-31 (`rescale`: the values, reversed for
  // a reversed range)
  double start(int index, double range0, double range1) {
    final n = domain.length;
    final reverse = range1 < range0;
    final low = reverse ? range1 : range0;
    final high = reverse ? range0 : range1;
    final s = step(range0, range1);
    final first = low + (high - low - s * (n - _inner())) * align;
    final i = reverse ? n - 1 - index : index;
    return first + s * i;
  }

  /// The start of [category]'s band, or null when it is not in the domain.
  double? startOf(String category, double range0, double range1) {
    final index = domain.indexOf(category);
    return index < 0 ? null : start(index, range0, range1);
  }

  /// The centre of the band at [index].
  double center(int index, double range0, double range1) =>
      start(index, range0, range1) + bandwidth(range0, range1) / 2;
}

/// A point scale (d3's `scalePoint`): categories at evenly spaced points,
/// with [padding] steps before the first and after the last.
// d3-scale 4.0.2 src/band.js:85-101 (`point`: a band scale with inner
// padding 1)
class PointScale {
  /// A scale of [domain] padded by [padding] steps at each end.
  const PointScale(this.domain, {this.padding = 0});

  /// The categories, in order.
  final List<String> domain;

  /// The outer padding, in steps.
  final double padding;

  BandScale get _band =>
      BandScale(domain, paddingInner: 1, paddingOuter: padding);

  /// The distance between two points on a range [range0]..[range1].
  double step(double range0, double range1) => _band.step(range0, range1);

  /// The position of the point at [index].
  double position(int index, double range0, double range1) =>
      _band.start(index, range0, range1);
}

// ---------------------------------------------------------------- recharts

/// recharts' `getAdaptiveStep` with `allowDecimals` (true by default): a
/// step that is easy to read, near [roughStep], a multiple of .05 of a power
/// of ten (.1 below 10), [correction] multiples further up.
// recharts 3.10.1 es6/util/scale/getNiceTickValues.js:44-58
JsDecimal _adaptiveStep(JsDecimal roughStep, int correction) {
  if (roughStep <= JsDecimal.zero) return JsDecimal.zero;
  final digitCount = rechartsDigitCount(roughStep.toDouble());
  final digitCountValue = JsDecimal.pow10(digitCount);
  final stepRatio = roughStep / digitCountValue;
  final stepRatioScale = JsDecimal.fromNum(digitCount != 1 ? .05 : .1);
  final amendStepRatio =
      (JsDecimal.fromNum((stepRatio / stepRatioScale).toDouble().ceil()) +
          JsDecimal.fromNum(correction)) *
      stepRatioScale;
  final formatStep = amendStepRatio * digitCountValue;
  return JsDecimal.fromNum(formatStep.toDouble());
}

/// recharts' `getTickOfSingleValue` with `allowDecimals`.
// recharts 3.10.1 es6/util/scale/getNiceTickValues.js:112-137
List<double> _tickOfSingleValue(double value, int tickCount) {
  var step = JsDecimal.pow10(0);
  var middle = JsDecimal.fromNum(value);
  if (!middle.isInteger) {
    final absVal = value.abs();
    if (absVal < 1) {
      step = JsDecimal.pow10(rechartsDigitCount(value) - 1);
      middle =
          JsDecimal.fromNum((middle / step).toDouble().floorToDouble()) * step;
    } else if (absVal > 1) {
      middle = JsDecimal.fromNum(value.floorToDouble());
    }
  } else if (value == 0) {
    middle = JsDecimal.fromNum(((tickCount - 1) / 2).floor());
  }
  final middleIndex = ((tickCount - 1) / 2).floor();
  return [
    for (var i = 0; i < tickCount; i++)
      (middle + JsDecimal.fromNum(i - middleIndex) * step).toDouble(),
  ];
}

/// recharts' `calculateStep`: the step and the first and last tick.
// recharts 3.10.1 es6/util/scale/getNiceTickValues.js:149-193
({JsDecimal step, JsDecimal tickMin, JsDecimal tickMax}) _calculateStep(
  double min,
  double max,
  int tickCount, [
  int correctionFactor = 0,
]) {
  if (!((max - min) / (tickCount - 1)).isFinite) {
    return (
      step: JsDecimal.zero,
      tickMin: JsDecimal.zero,
      tickMax: JsDecimal.zero,
    );
  }
  final step = _adaptiveStep(
    (JsDecimal.fromNum(max) - JsDecimal.fromNum(min)) /
        JsDecimal.fromNum(tickCount - 1),
    correctionFactor,
  );
  JsDecimal middle;
  if (min <= 0 && max >= 0) {
    middle = JsDecimal.zero;
  } else {
    middle =
        (JsDecimal.fromNum(min) + JsDecimal.fromNum(max)) /
        JsDecimal.fromNum(2);
    middle = middle - middle.remainder(step);
  }
  var belowCount = ((middle - JsDecimal.fromNum(min)) / step).toDouble().ceil();
  var upCount = ((JsDecimal.fromNum(max) - middle) / step).toDouble().ceil();
  final scaleCount = belowCount + upCount + 1;
  if (scaleCount > tickCount) {
    return _calculateStep(min, max, tickCount, correctionFactor + 1);
  }
  if (scaleCount < tickCount) {
    upCount = max > 0 ? upCount + (tickCount - scaleCount) : upCount;
    belowCount = max > 0 ? belowCount : belowCount + (tickCount - scaleCount);
  }
  return (
    step: step,
    tickMin: middle - JsDecimal.fromNum(belowCount) * step,
    tickMax: middle + JsDecimal.fromNum(upCount) * step,
  );
}

/// recharts' `rangeStep`: [start], then steps of [step], below [end].
// recharts 3.10.1 es6/util/scale/util/arithmetic.js:36-48
List<double> _rangeStep(JsDecimal start, JsDecimal end, JsDecimal step) {
  var number = start;
  var i = 0;
  final result = <double>[];
  // recharts' "magic number to prevent infinite loop".
  while (number < end && i < 100000) {
    result.add(number.toDouble());
    number = number + step;
    i++;
  }
  return result;
}

/// recharts' `getNiceTickValues([min, max], tickCount)`: ticks with an easy
/// step (a multiple of .05 or .1 of a power of ten) that cover
/// [min]..[max], with 0 a tick when the range holds it. The axis domain
/// becomes the first to the last tick. [tickCount] is the axis' (5 unless an
/// axis sets one; `getNiceTickValues`' own default of 6 is never used).
// recharts 3.10.1 es6/util/scale/getNiceTickValues.js:206-235 (`'auto'`
// is the adaptive step, :226); the axis' tickCount 5,
// es6/state/selectors/axisSelectors.js:73, :119
List<double> rechartsNiceTicks(double min, double max, [int tickCount = 5]) {
  final count = math.max(tickCount, 2);
  final cormin = math.min(min, max);
  final cormax = math.max(min, max);
  if (cormin == double.negativeInfinity || cormax == double.infinity) {
    final values = cormax == double.infinity
        ? [cormin, for (var i = 0; i < tickCount - 1; i++) double.infinity]
        : [
            for (var i = 0; i < tickCount - 1; i++) double.negativeInfinity,
            cormax,
          ];
    return min > max ? values.reversed.toList() : values;
  }
  if (cormin == cormax) return _tickOfSingleValue(cormin, tickCount);
  final (:step, :tickMin, :tickMax) = _calculateStep(cormin, cormax, count);
  final values = _rangeStep(
    tickMin,
    tickMax + JsDecimal.fromNum(.1) * step,
    step,
  );
  return min > max ? values.reversed.toList() : values;
}

/// recharts' `getTickValuesFixedDomain([min, max], tickCount)`: the ticks
/// of a domain the chart fixed: [min], steps of an easy size below [max],
/// then [max] itself.
// recharts 3.10.1 es6/util/scale/getNiceTickValues.js:247-285
List<double> rechartsFixedTicks(double min, double max, [int tickCount = 5]) {
  final cormin = math.min(min, max);
  final cormax = math.max(min, max);
  if (cormin == double.negativeInfinity || cormax == double.infinity) {
    return [min, max];
  }
  if (cormin == cormax) return [cormin];
  final count = math.max(tickCount, 2);
  final step = _adaptiveStep(
    (JsDecimal.fromNum(cormax) - JsDecimal.fromNum(cormin)) /
        JsDecimal.fromNum(count - 1),
    0,
  );
  final values = [
    ..._rangeStep(JsDecimal.fromNum(cormin), JsDecimal.fromNum(cormax), step),
    cormax,
  ];
  return min > max ? values.reversed.toList() : values;
}

/// The domain and ticks of a recharts number axis whose `domain` prop is
/// `[min ?? "auto", max ?? "auto"]`, the data running over
/// [dataMin]..[dataMax] (null without data), `allowDataOverflow` false and
/// `niceTicks` `'auto'` (recharts' defaults).
///
/// - [specifiedMin] and [specifiedMax] (null for `"auto"`) only widen the
///   data's extent (`parseNumericalUserDomain`, `extendDomain`);
/// - with an `"auto"` end the ticks are nice ([rechartsNiceTicks]), else
///   those of the fixed domain ([rechartsFixedTicks]);
/// - the domain then takes in the first and last tick.
///
/// Null without data: recharts then has no domain, so no scale and no
/// ticks.
// recharts 3.10.1 es6/util/isDomainSpecifiedByUser.js:12-22 (`extendDomain`)
// and :105-187 (`parseNumericalUserDomain`); es6/state/selectors/
// axisSelectors.js:743-777 (`combineNumericalDomain`), :827-854
// (`combineNiceTicks`) and :856-873 (`combineAxisDomainWithNiceTicks`)
({double min, double max, List<double> ticks})? rechartsNumberAxis({
  required double? dataMin,
  required double? dataMax,
  double? specifiedMin,
  double? specifiedMax,
  int tickCount = 5,
}) {
  if (dataMin == null || dataMax == null) return null;
  final finalMin = specifiedMin ?? dataMin;
  final finalMax = specifiedMax ?? dataMax;
  if (!finalMin.isFinite || !finalMax.isFinite) return null;
  final domainMin = math.min(finalMin, dataMin);
  final domainMax = math.max(finalMax, dataMax);
  final auto = specifiedMin == null || specifiedMax == null;
  final ticks = auto
      ? rechartsNiceTicks(domainMin, domainMax, tickCount)
      : rechartsFixedTicks(domainMin, domainMax, tickCount);
  if (ticks.isEmpty) return (min: domainMin, max: domainMax, ticks: ticks);
  return (
    min: math.min(domainMin, ticks.first),
    max: math.max(domainMax, ticks.last),
    ticks: ticks,
  );
}

// PORT STATUS: confidence=high todos=0 upstream=d3-array@3.2.4, d3-scale@4.0.2
