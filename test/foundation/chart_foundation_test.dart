// The chart foundation: scales (d3's and recharts' ticks), curves, arcs,
// and the chart number formats, checked against what JavaScript writes.
//
// The expected strings are `Intl.NumberFormat("en-US", …)` outputs, worked
// out by hand from ECMA-402's rules (round the shortest decimal half away
// from zero; compact notation re-picks K/M/B/T after rounding; currency
// fraction digits from CLDR).

import 'dart:math' as math;
import 'dart:ui';

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/chart/arc.dart';
import 'package:a2ui_kit/src/foundation/chart/curve.dart';
import 'package:a2ui_kit/src/foundation/chart/js_decimal.dart';
import 'package:a2ui_kit/src/foundation/chart/recharts.dart';
import 'package:a2ui_kit/src/foundation/chart/scale.dart';
import 'package:a2ui_kit/src/foundation/format/chart_format.dart';
import 'package:a2ui_kit/src/functions/calc.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("d3's linear ticks and nice", () {
    test('ticks are round values', () {
      expect(linearTicks(0, 1, 5), [0, .2, .4, .6, .8, 1]);
      expect(linearTicks(0, 40000, 5), [0, 10000, 20000, 30000, 40000]);
      expect(linearTicks(1, 1, 5), [1]);
      expect(linearTicks(10, 0, 2), [10, 5, 0]);
    });

    test('nice extends the domain to the ticks', () {
      final scale = LinearScale(9800, 38400)..nice(5);
      expect([scale.domain0, scale.domain1], [5000, 40000]);
      expect(scale.ticks(5).first, 5000);
      expect(scale.ticks(5).last, 40000);
      final small = LinearScale(-0.37, 0.93)..nice(5);
      expect([small.domain0, small.domain1], [-0.4, 1]);
    });

    test('a one-value domain maps to the middle', () {
      expect(LinearScale(5, 5).map(5, 0, 100), 50);
      expect(LinearScale.extent(const []).domain1, 1);
    });
  });

  group("d3's band and point scales", () {
    test('band: steps, bandwidth and centring', () {
      const band = BandScale.padded(['a', 'b', 'c', 'd'], .24);
      // step = 400 / (4 - .24 + .48)
      const step = 400 / 4.24;
      expect(band.step(0, 400), closeTo(step, 1e-9));
      expect(band.bandwidth(0, 400), closeTo(step * .76, 1e-9));
      expect(band.start(0, 0, 400), closeTo(step * .24, 1e-9));
      expect(band.startOf('z', 0, 400), isNull);
    });

    test('point: padding in steps, one point in the middle', () {
      const point = PointScale(['a', 'b', 'c'], padding: .25);
      const step = 300 / 2.5;
      expect(point.position(0, 0, 300), closeTo(step * .25, 1e-9));
      expect(point.position(2, 0, 300), closeTo(300 - step * .25, 1e-9));
      expect(const PointScale(['a'], padding: .25).position(0, 0, 300), 150);
    });
  });

  group("recharts' nice ticks", () {
    test('an easy step that covers the data, 0 kept', () {
      expect(rechartsNiceTicks(120, 208), [120, 150, 180, 210, 240]);
      expect(rechartsNiceTicks(290, 580), [255, 340, 425, 510, 595]);
      expect(rechartsNiceTicks(0, 208), [0, 55, 110, 165, 220]);
      expect(rechartsNiceTicks(0, 0), [0, 1, 2, 3, 4]);
    });

    test('a fixed domain keeps its ends', () {
      expect(rechartsFixedTicks(0, 1), [0, .25, .5, .75, 1]);
    });

    // recharts 3.10.1 getNiceTickValues.js:247-285: `[...rangeStep(min,
    // max, step), max]`, rangeStep stopping below max (arithmetic.js:42).
    // A bound of `max - .99 * step` would drop 90.
    test(
      'a fixed domain that is not a multiple of the step keeps every step',
      () {
        expect(rechartsFixedTicks(0, 110), [0, 30, 60, 90, 110]);
        expect(rechartsFixedTicks(110, 0), [110, 90, 60, 30, 0]);
        final axis = rechartsNumberAxis(
          dataMin: 12,
          dataMax: 97,
          specifiedMin: 0,
          specifiedMax: 110,
        )!;
        expect(axis.ticks, [0, 30, 60, 90, 110]);
        expect([axis.min, axis.max], [0, 110]);
      },
    );

    test('decimal steps add up exactly, as decimal.js does', () {
      // 0.075 × 3 is 0.22499999999999998 in binary floating point.
      expect(rechartsNiceTicks(0, .3), [0, .075, .15, .225, .3]);
      expect(rechartsNiceTicks(.1, .3).every((t) => '$t'.length < 8), isTrue);
    });

    test('one value: five ticks round it', () {
      expect(rechartsNiceTicks(5, 5), [3, 4, 5, 6, 7]);
      expect(rechartsNiceTicks(2.5, 2.5), [0, 1, 2, 3, 4]);
      expect(rechartsNiceTicks(.25, .25), [0, .1, .2, .3, .4]);
    });

    test('a specified end only widens the data', () {
      final axis = rechartsNumberAxis(
        dataMin: .05,
        dataMax: .4,
        specifiedMin: 0,
        specifiedMax: 1,
      )!;
      expect([axis.min, axis.max], [0, 1]);
      final wide = rechartsNumberAxis(
        dataMin: -2,
        dataMax: 3,
        specifiedMin: 0,
        specifiedMax: 1,
      )!;
      expect([wide.min, wide.max], [-2, 3]);
    });

    // isDomainSpecifiedByUser.js:105-109: no data, no domain.
    test('no data: no axis, even with both ends set', () {
      expect(rechartsNumberAxis(dataMin: null, dataMax: null), isNull);
      expect(
        rechartsNumberAxis(
          dataMin: null,
          dataMax: null,
          specifiedMin: 0,
          specifiedMax: 10,
        ),
        isNull,
      );
    });

    // arithmetic.js:17-25: the decimal logarithm is read back as a double
    // before its floor.
    test("getDigitCount reads the logarithm as JavaScript's double", () {
      expect(rechartsDigitCount(0), 1);
      expect(rechartsDigitCount(1), 1);
      expect(rechartsDigitCount(27.5), 2);
      expect(rechartsDigitCount(.1), 0);
      expect(rechartsDigitCount(.099), -1);
      expect(rechartsDigitCount(9.999999999999998), 1);
      // log10 is -1.00000000000000008…, which reads back as -1.
      expect(rechartsDigitCount(.09999999999999998), 0);
    });
  });

  group('JsDecimal (decimal.js-light)', () {
    test('sums, products and quotients of decimals', () {
      final a = JsDecimal.fromNum(.1);
      final b = JsDecimal.fromNum(.2);
      expect((a + b).toDouble(), .3);
      expect((a * b).toDouble(), .02);
      expect(
        (JsDecimal.fromNum(1) / JsDecimal.fromNum(3)).toString(),
        '33333333333333333333e-20',
      );
      // decimal.js-light truncates arithmetic at 20 digits (README.md:21,
      // decimal.js:1261): 2/3 is 0.66666666666666666666, toward zero for a
      // negative quotient too; rounding half up would give …667.
      expect(
        (JsDecimal.fromNum(2) / JsDecimal.fromNum(3)).toString(),
        '66666666666666666666e-20',
      );
      expect(
        (JsDecimal.fromNum(-2) / JsDecimal.fromNum(3)).toString(),
        '-66666666666666666666e-20',
      );
      // add, times: the 21st digit is dropped, not rounded (decimal.js:998,
      // :605).
      expect(
        (JsDecimal.parse('0.99999999999999999999') +
                JsDecimal.parse('0.000000000000000000009'))
            .toString(),
        '99999999999999999999e-20',
      );
      expect(
        (JsDecimal.parse('1.0000000000000000001') * JsDecimal.parse('1.9'))
            .toString(),
        '19000000000000000001e-19',
      );
      expect(
        JsDecimal.fromNum(-7).remainder(JsDecimal.fromNum(3)).toDouble(),
        -1,
      );
      expect(
        JsDecimal.fromNum(435).remainder(JsDecimal.fromNum(85)).toDouble(),
        10,
      );
      expect(JsDecimal.fromNum(1e21).toDouble(), 1e21);
      expect(JsDecimal.fromNum(1.5e-7).isInteger, isFalse);
      expect(JsDecimal.fromNum(120).isInteger, isTrue);
    });
  });

  group("recharts' layout helpers", () {
    // combineAllBarPositions.js:53-71
    test(
      'bar sizes are rounded with Math.round, gaps dropped when too wide',
      () {
        final one = rechartsBarPositions(49.6, 1).single;
        // getPercentValue("10%", 49.6): `49.6 * 10 / 100` in that order
        // (DataUtils.js:60), 4.96; `.1 * 49.6` is 4.960000000000001.
        expect(one.offset, 49.6 * 10 / 100);
        expect(one.offset, isNot(.1 * 49.6));
        // 39.68 rounds to 40 (a floor would give 39).
        expect(one.size, 40);
        final three = rechartsBarPositions(10, 3);
        expect([for (final p in three) p.size], [3, 3, 3]);
        expect([for (final p in three) p.offset], [1, 4, 7]);
        // 10% on each side, 4px between: (100 - 20 - 4) / 2 = 38.
        final two = rechartsBarPositions(100, 2);
        expect([for (final p in two) p.offset], [10, 52]);
        expect(two.first.size, 38);
      },
    );

    // getTicks.js:11-53, TickUtils.js:27-35
    test('preserveEnd moves the last label in and drops crowded ones', () {
      final shown = rechartsTicksEnd(
        [10, 50, 90],
        (_) => 30,
        start: 0,
        end: 100,
      );
      expect(shown, [(index: 1, tickCoord: 50.0), (index: 2, tickCoord: 85.0)]);
      // Descending coordinates (a value axis from the bottom up).
      final up = rechartsTicksEnd(
        [190, 100, 10],
        (_) => 14,
        start: 0,
        end: 200,
      );
      expect([for (final t in up) t.index], [0, 1, 2]);
      expect(up.last.tickCoord, 10);
    });

    // getActiveCoordinate.js:79-155
    test('the active category is the one whose half-way marks hold the '
        'pointer', () {
      expect(rechartsActiveTickIndex(20, [10, 30, 50]), 0);
      expect(rechartsActiveTickIndex(20.01, [10, 30, 50]), 1);
      expect(rechartsActiveTickIndex(40, [10, 30, 50]), 1);
      expect(rechartsActiveTickIndex(40.01, [10, 30, 50]), 2);
      expect(rechartsActiveTickIndex(500, [10]), 0);
    });

    // translate.js:18-57
    test('the tooltip goes 10px past the coordinate, or before it', () {
      double x(double at) => rechartsTooltipTranslate(
        coordinate: at,
        dimension: 50,
        viewBoxStart: 64,
        viewBoxDimension: 248,
      );
      expect(x(100), 110);
      expect(x(290), 230);
      // Never before the view box; no clamp at its end.
      expect(x(70), 80);
      expect(
        rechartsTooltipTranslate(
          coordinate: 80,
          dimension: 300,
          viewBoxStart: 64,
          viewBoxDimension: 248,
        ),
        64,
      );
    });

    // d3-shape stack.js:22-39, offset/none.js:1-9; ChartUtils.js:210-232
    test('stacks lower for negatives; truncation clamps to the domain', () {
      final stack = rechartsStack([
        [5, 2],
        [-3, double.nan],
        [1, 4],
      ]);
      expect(stack[0], [(0.0, 5.0), (0.0, 2.0)]);
      expect(stack[1][0], (5.0, 2.0));
      expect(stack[1][1].$1, 2);
      expect(stack[1][1].$2.isNaN, isTrue);
      // After a NaN top the next series starts from that series' base.
      expect(stack[2], [(2.0, 3.0), (2.0, 6.0)]);
      expect(rechartsTruncateByDomain((2, double.nan), 0, 10), (2.0, 10.0));
      expect(rechartsTruncateByDomain((-5, 3), 0, 10), (0.0, 3.0));
      expect(rechartsTruncateByDomain((12, 15), 0, 10), (10.0, 10.0));
    });

    // es-toolkit compat sortBy / compareValues.mjs:1-31: `<` and `>`, stable,
    // null after the rest.
    test(
      'rows and legend entries sort by key, by code unit, ties in order',
      () {
        expect(rechartsSortBy(['b', 'A', 'a', 'B', 'a2'], (s) => s), [
          'A',
          'B',
          'a',
          'a2',
          'b',
        ]);
        final tied = [('x', 1), ('y', 0), ('x', 0)];
        expect(rechartsSortBy(tied, (e) => e.$1), [
          ('x', 1),
          ('x', 0),
          ('y', 0),
        ]);
        expect(rechartsSortBy(<Object?>[null, 'b', 10, 9], (v) => v), [
          'b',
          9,
          10,
          null,
        ]);
      },
    );

    // DataUtils.js:48-71 (`getPercentValue`), :24 (`isPercent`).
    test('getPercentValue', () {
      expect(rechartsPercentValue('55%', 100), 55);
      expect(rechartsPercentValue('40', 100), 40);
      expect(rechartsPercentValue(' 40 ', 100), 40);
      expect(rechartsPercentValue('40px', 100, defaultValue: 7), 7);
      expect(rechartsPercentValue('abc', 100), 0);
      expect(rechartsPercentValue('%', 100, defaultValue: 3), 3);
      expect(rechartsPercentValue('1e1%', 100), 10);
      expect(rechartsPercentValue(150, 100, validate: true), 100);
      expect(rechartsPercentValue(null, 100, defaultValue: 80), 80);
    });

    // Text.js:66-68; LabelList.js:47-53.
    test('isRenderableText and the label list accessor', () {
      expect(rechartsIsRenderableText(true), isTrue);
      expect(rechartsIsRenderableText(double.nan), isTrue);
      expect(rechartsIsRenderableText(const <Object>[]), isFalse);
      expect(rechartsLabelValue(const [1, 8]), 8);
      expect(rechartsLabelValue(const <Object?>[]), isNull);
      expect(rechartsLabelValue(const {'a': 1}), isNull);
    });

    // DataUtils.js:72-86.
    test('hasDuplicate keys by String() in a plain object', () {
      expect(rechartsHasDuplicate(['5', 'a', '5']), isTrue);
      expect(rechartsHasDuplicate(['a', 'b']), isFalse);
      expect(rechartsHasDuplicate(['toString']), isTrue);
      expect(rechartsHasDuplicate(['__proto__']), isTrue);
    });

    // es-toolkit compat/util/toPath.mjs, _internal/isDeepKey.mjs.
    test('toPath and isDeepKey', () {
      expect(rechartsToPath('a.b[0]["c.d"]'), ['a', 'b', '0', 'c.d']);
      expect(rechartsToPath('.a'), ['', 'a']);
      expect(rechartsToPath(r"a['b\'c']"), ['a', "b'c"]);
      expect(rechartsIsDeepKey('a.b'), isTrue);
      expect(rechartsIsDeepKey('a]'), isTrue);
      expect(rechartsIsDeepKey('ab'), isFalse);
    });

    // Text.js:69-86 (`calculate`), :150-187; the test font's glyphs are 1em.
    test("Text's lines at a width", () {
      final text = RechartsText(
        const TextStyle(fontSize: 10),
        TextScaler.noScaling,
      );
      // "ab" 20 + nbsp 10 + "cd" 20 = 50, not under 50: two lines.
      expect(text.lines('ab cd', width: 50), ['ab', 'cd']);
      expect(text.lines('ab cd', width: 50.5), ['ab cd']);
      expect(text.lines('a  b\nc'), ['a b c']);
      expect(text.lines('a b', width: double.nan), ['a', 'b']);
      expect(text.lines(' a'), [' a']);
    });
  });

  group('JavaScript number reading (calc.dart)', () {
    // ECMA-262 21.1.2.12.
    test('parseFloat', () {
      expect(jsParseFloat('40%'), 40);
      expect(jsParseFloat('  -1.5e2px'), -150);
      expect(jsParseFloat('1e'), 1);
      expect(jsParseFloat('1.'), 1);
      expect(jsParseFloat('.5'), .5);
      expect(jsParseFloat('  3'), 3);
      expect(jsParseFloat('-Infinityx'), double.negativeInfinity);
      expect(jsParseFloat('0x10'), 0);
      expect(jsParseFloat('px'), isNaN);
    });

    // ECMA-262 21.1.3.3.
    test('toFixed', () {
      expect(jsToFixed(12.5, 1), '12.5');
      // -0 (`0 * -1.5`): `x < 0` is false, so no sign.
      expect(jsToFixed(0 * -1.5, 1), '0.0');
      expect(jsToFixed(1e21, 2), '1e+21');
    });
  });

  group('curves', () {
    List<Offset> sample(Path path) {
      final out = <Offset>[];
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d <= metric.length; d += 1) {
          out.add(metric.getTangentForOffset(d)!.position);
        }
      }
      return out;
    }

    test('the monotone cubic never overshoots monotone data', () {
      const points = [
        Offset(0, 100),
        Offset(10, 90),
        Offset(20, 20),
        Offset(30, 18),
        Offset(40, 0),
      ];
      for (final add in [addMonotonePath, addMonotoneXPath]) {
        final path = Path();
        add(path, points);
        for (final p in sample(path)) {
          expect(p.dy, inInclusiveRange(-1e-6, 100 + 1e-6));
        }
      }
    });

    test('two points make a straight line', () {
      final path = Path();
      addMonotonePath(path, const [Offset.zero, Offset(10, 10)]);
      expect(path.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
    });

    // d3-shape 3.2.0 src/curve/monotone.js:79-96: curveMonotoneY is
    // monotone X on (y, x), reflected back.
    test('monotone Y is monotone X with x and y swapped', () {
      const points = [Offset(10, 0), Offset(30, 50), Offset(20, 100)];
      final y = Path();
      addMonotoneYPath(y, points);
      final x = Path();
      addMonotoneXPath(x, [for (final p in points) Offset(p.dy, p.dx)]);
      final swapped = [for (final p in sample(x)) Offset(p.dy, p.dx)];
      final along = sample(y);
      // The same curve: every sampled point of one lies on the other.
      for (final p in along) {
        final nearest = swapped.map((q) => (q - p).distance).reduce(math.min);
        expect(nearest, lessThan(1));
      }
      // x as a function of y never passes 30 between the rising and falling
      // points: no overshoot.
      for (final p in along) {
        expect(p.dx, inInclusiveRange(10 - 1e-6, 30 + 1e-6));
      }
    });

    test('an area closes on its baseline', () {
      final area = monotoneArea(
        const [Offset(0, 10), Offset(10, 0), Offset(20, 5)],
        const [Offset(0, 20), Offset(10, 20), Offset(20, 20)],
      );
      expect(area.contains(const Offset(10, 15)), isTrue);
      expect(area.contains(const Offset(10, 25)), isFalse);
    });
  });

  group('arcs', () {
    test('a d3 slice holds its middle and keeps its gap', () {
      final slice = d3ArcPath(
        center: const Offset(100, 100),
        innerRadius: 50,
        outerRadius: 90,
        startAngle: 0,
        endAngle: math.pi / 2,
        padAngle: .025,
        cornerRadius: 4,
      );
      expect(
        slice.contains(d3ArcPoint(const Offset(100, 100), 70, 0, math.pi / 2)),
        isTrue,
      );
      // The hole and the outside are not in it.
      expect(slice.contains(const Offset(100, 100)), isFalse);
      expect(slice.contains(const Offset(195, 100)), isFalse);
      // The pad keeps the edge at 12 o'clock clear.
      expect(slice.contains(const Offset(100.2, 30)), isFalse);
    });

    // d3-path 3.1.0 src/path.js:126-137: `da % tau + tau` with JavaScript's
    // `%` (a whole turn the wrong way is still a whole circle), nothing for
    // 1e-6 or less; d3-shape 3.2.0 src/math.js:14-20.
    test("d3-path's arc and d3-shape's clamped asin and acos", () {
      final circle = Path()..moveTo(10, 0);
      d3PathArc(circle, 0, 0, 10, 0, 2 * math.pi, ccw: true);
      expect(circle.contains(Offset.zero), isTrue);
      final tiny = Path()..moveTo(10, 0);
      d3PathArc(tiny, 0, 0, 10, 0, 1e-7, ccw: false);
      expect(tiny.getBounds().height, lessThan(1e-3));
      expect(d3Acos(1.0000000000000002), 0);
      expect(d3Acos(-1.0000000000000002), math.pi);
      expect(d3Asin(1.0000000000000002), math.pi / 2);
      expect(d3Asin(-1), -math.pi / 2);
    });

    test('a whole d3 ring is an annulus', () {
      final ring = d3ArcPath(
        center: Offset.zero,
        innerRadius: 10,
        outerRadius: 20,
        startAngle: 0,
        endAngle: 2 * math.pi,
      );
      expect(ring.contains(const Offset(15, 0)), isTrue);
      expect(ring.contains(Offset.zero), isFalse);
    });

    test('a recharts sector from 90° clockwise', () {
      final sector = rechartsSectorPath(
        center: const Offset(100, 100),
        innerRadius: 0,
        outerRadius: 80,
        startAngle: 90,
        endAngle: 0,
        cornerRadius: 4,
      );
      // The top-right quarter.
      expect(sector.contains(const Offset(130, 70)), isTrue);
      expect(sector.contains(const Offset(70, 70)), isFalse);
      expect(
        rechartsPolar(const Offset(100, 100), 10, 90),
        const Offset(100, 90),
      );
    });

    // RC3-10 (RULEBOOK section 2, an SVG element's box): `getBBox` is the
    // tight box of what the path draws, so an arc adds its ends and the
    // extremes at the axis angles it sweeps, exactly.
    group("a recharts sector's tight box", () {
      Rect? box(double start, double end, {double inner = 0, double c = 0}) =>
          rechartsSectorBounds(
            center: const Offset(100, 100),
            innerRadius: inner,
            outerRadius: 50,
            startAngle: start,
            endAngle: end,
            cornerRadius: c,
          );

      test('a quarter has its ends and its centre', () {
        expect(box(0, 90), const Rect.fromLTRB(100, 50, 150, 100));
        expect(box(90, 0), const Rect.fromLTRB(100, 50, 150, 100));
      });

      test('an arc over 12 o’clock reaches the circle’s top', () {
        final ends = rechartsPolar(const Offset(100, 100), 50, 30);
        final expected = Rect.fromLTRB(200 - ends.dx, 50, ends.dx, 100);
        for (final (start, end) in [(30.0, 150.0), (150.0, 30.0)]) {
          final b = box(start, end)!;
          expect(b.left, closeTo(expected.left, 1e-9));
          expect(b.top, closeTo(expected.top, 1e-9));
          expect(b.right, closeTo(expected.right, 1e-9));
          expect(b.bottom, closeTo(expected.bottom, 1e-9));
        }
      });

      test('a ring of all but a hair is the circle', () {
        final b = box(0, 359.999, inner: 20)!;
        expect(b.left, closeTo(50, 1e-9));
        expect(b.top, closeTo(50, 1e-9));
        expect(b.right, closeTo(150, 1e-9));
        expect(b.bottom, closeTo(150, 1e-9));
      });

      // With rounded corners every arc is the path's own (Sector.js:64-153):
      // the box holds everything the path draws, and no more than its
      // flattening (Skia keeps a curve within 0.5px of its chords) apart.
      for (final (start, end, inner) in [
        (10.0, 170.0, 20.0),
        (200.0, 20.0, 0.0),
        (-30.0, 250.0, 25.0),
      ]) {
        test('$start° to $end°, inner $inner, corners 6: the drawn path', () {
          final b = box(start, end, inner: inner, c: 6)!;
          final path = rechartsSectorPath(
            center: const Offset(100, 100),
            innerRadius: inner,
            outerRadius: 50,
            startAngle: start,
            endAngle: end,
            cornerRadius: 6,
          );
          var drawn = Rect.zero;
          var first = true;
          for (final metric in path.computeMetrics()) {
            for (var d = 0.0; d <= metric.length; d += .05) {
              final p = metric.getTangentForOffset(d)!.position;
              drawn = first
                  ? Rect.fromPoints(p, p)
                  : drawn.expandToInclude(Rect.fromPoints(p, p));
              first = false;
            }
          }
          // Skia measures in 32-bit floats: a few millionths of a pixel.
          expect(b.left, lessThanOrEqualTo(drawn.left + 1e-4));
          expect(b.top, lessThanOrEqualTo(drawn.top + 1e-4));
          expect(b.right, greaterThanOrEqualTo(drawn.right - 1e-4));
          expect(b.bottom, greaterThanOrEqualTo(drawn.bottom - 1e-4));
          expect(b.left, greaterThan(drawn.left - .5));
          expect(b.top, greaterThan(drawn.top - .5));
          expect(b.right, lessThan(drawn.right + .5));
          expect(b.bottom, lessThan(drawn.bottom + .5));
        });
      }
    });
  });

  group("the playground's formatNumber (format.ts)", () {
    String f(Object? v, A2uiValueFormat format, [String? unit]) =>
        formatPlaygroundValue(v, format: format, unit: unit);

    test('number: at most 2 decimals, grouped', () {
      expect(f(1234567.891, A2uiValueFormat.number), '1,234,567.89');
      expect(f(1.005, A2uiValueFormat.number), '1.01');
      expect(f(-0.001, A2uiValueFormat.number), '-0');
    });

    test('currency: no decimals from 1,000, else 2', () {
      expect(f(1234.5, A2uiValueFormat.currency), r'$1,235');
      expect(f(12.5, A2uiValueFormat.currency), r'$12.50');
      expect(f(-12.5, A2uiValueFormat.currency), r'-$12.50');
      expect(f(999.995, A2uiValueFormat.currency), r'$1,000.00');
    });

    test('percent: the value itself, 1 decimal; a % unit once', () {
      expect(f(34.56, A2uiValueFormat.percent), '34.6%');
      expect(f(34.56, A2uiValueFormat.percent, '%'), '34.6%');
      expect(f(.5, A2uiValueFormat.percent), '0.5%');
    });

    test('compact: K, M, B, T with 1 decimal, re-picked after rounding', () {
      expect(f(18200, A2uiValueFormat.compact), '18.2K');
      expect(f(1234, A2uiValueFormat.compact), '1.2K');
      expect(f(999, A2uiValueFormat.compact), '999');
      expect(f(999.96, A2uiValueFormat.compact), '1K');
      expect(f(999950, A2uiValueFormat.compact), '1M');
      expect(f(1500000, A2uiValueFormat.compact), '1.5M');
      expect(f(-2500, A2uiValueFormat.compact), '-2.5K');
      expect(f(2.5e9, A2uiValueFormat.compact), '2.5B');
      expect(f(1e15, A2uiValueFormat.compact), '1000T');
      expect(f(12.34, A2uiValueFormat.compact), '12.3');
    });

    test('units: a space, none before % and °', () {
      expect(f(12, A2uiValueFormat.number, 'ms'), '12 ms');
      expect(f(21, A2uiValueFormat.number, '°C'), '21°C');
      expect(f(3, A2uiValueFormat.number, '%pt'), '3%pt');
    });

    test('a value that is not a number is text', () {
      expect(f(null, A2uiValueFormat.number), '');
      expect(f('n/a', A2uiValueFormat.number), 'n/a');
      expect(f(double.nan, A2uiValueFormat.number), 'NaN');
    });
  });

  group("the playground's tickFormatter and shortLabel", () {
    test('ticks stay short', () {
      final currency = playgroundTickFormatter(A2uiValueFormat.currency);
      expect(currency(1200), r'$1.2K');
      expect(currency(-500), r'-$500');
      expect(playgroundTickFormatter(A2uiValueFormat.percent)(34), '34%');
      final number = playgroundTickFormatter(null, 'ms');
      expect(number(1400000), '1.4M ms');
      expect(number(12.5), '12.5 ms');
      expect(playgroundTickFormatter()(40000), '40K');
    });

    test('shortLabel cuts with an ellipsis', () {
      expect(shortLabel('North America', 12), 'North Ameri…');
      expect(shortLabel('APAC', 12), 'APAC');
      expect(shortLabel(null), '');
      expect(shortLabel(2026), '2026');
    });
  });

  group('A2uiChartColors', () {
    test('light and dark, lerp, copyWith and equality', () {
      final light = A2uiChartColors.light();
      final dark = A2uiChartColors.dark();
      expect(light, A2uiChartColors.light());
      expect(light.hashCode, A2uiChartColors.light().hashCode);
      expect(light, isNot(dark));
      expect(A2uiChartColors.lerp(light, dark, 0), light);
      expect(A2uiChartColors.lerp(light, dark, 1), dark);
      final red = light.copyWith(grid: const Color(0xffff0000));
      expect(red.grid, const Color(0xffff0000));
      expect(red.muted, light.muted);
      expect(light.muteAt(5), light.mute[1]);
      expect(light.muteAt(-1), light.mute[3]);
      // The playground tokens carry them, and lerp them too.
      final tokens = A2uiKitTheme.playground(Brightness.light).playground;
      expect(tokens.charts, light);
      expect(
        A2uiPlaygroundTokens.lerp(
          tokens,
          A2uiKitTheme.playground(Brightness.dark).playground,
          1,
        ).charts,
        dark,
      );
    });
  });

  group("the standard Chart's formatter", () {
    test('no decimals, compact from 10,000', () {
      final number = standardChartFormatter(ChartFormat.number, null)!;
      expect(number(1234.6), '1,235');
      expect(number(12345), '12K');
      final currency = standardChartFormatter(ChartFormat.currency, null)!;
      expect(currency(-16000), r'-$16K');
      expect(currency(9999.5), r'$10,000');
      final percent = standardChartFormatter(ChartFormat.percent, null)!;
      expect(percent(.125), '12.5%');
      // Compact is chosen by the value, not the percentage.
      expect(percent(150), '15,000%');
      expect(percent(20000), '2M%');
      expect(
        standardChartFormatter(ChartFormat.currency, 'CHF')!(12),
        'CHF\u{a0}12',
      );
    });

    test('recharts writes a value with no formatter as String() does', () {
      expect(rechartsText(255), '255');
      expect(rechartsText(.35), '0.35');
      expect(rechartsText(null), '');
    });
  });

  group('boundaries the review found untested (running review CR6, CR7)', () {
    // The points of [path] every 0.1px along it.
    List<Offset> along(Path path) => [
      for (final metric in path.computeMetrics())
        for (var d = 0.0; d <= metric.length; d += .1)
          metric.getTangentForOffset(d)!.position,
    ];

    // How near [path] comes to [point].
    double distanceTo(Path path, Offset point) =>
        along(path).map((p) => (p - point).distance).reduce(math.min);

    // chart-kit.tsx:151 (`t.push(m[n - 2])`): the last tangent is the last
    // secant, (100 - 0) / (200 - 100) = 1. The last cubic leaves (100, 0)
    // with tangent 0 (the secants 0 and 1, `m[i - 1] * m[i] <= 0`), so its
    // controls are (133.33, 0) and (166.67, 100 - 1 × 100 / 3 = 66.67): it
    // ends at slope 1 and its middle is (150, (3 × 66.67 + 100) / 8 = 37.5).
    // Half the secant puts the second control at 83.33: an end slope of .5
    // and a middle at (150, (3 × 83.33 + 100) / 8 = 43.75), 3.7px off.
    test("the playground's monotone end tangent is the last secant "
        '(chart-kit.tsx:151)', () {
      const points = [Offset.zero, Offset(100, 0), Offset(200, 100)];
      final path = Path();
      addMonotonePath(path, points);
      final metric = path.computeMetrics().single;
      final end = metric.getTangentForOffset(metric.length)!.vector;
      expect(end.dy / end.dx, closeTo(1, 1e-2));
      expect(distanceTo(path, const Offset(150, 37.5)), lessThan(.25));
    });

    // d3-shape 3.2.0 src/curve/monotone.js:15: slope3 is (sign(s0) +
    // sign(s1)) × min(|s0|, |s1|, .5 × |p|). Through (0, 0), (100, 100) and
    // (200, 200), s0 = s1 = p = 1: the middle tangent is 2 × .5 = 1, and
    // slope2 (:19-22) gives both ends (3 × 1 - 1) / 2 = 1, a straight line.
    // With 1 × |p| the middle tangent is 2 and the ends (3 - 2) / 2 = .5: the
    // first cubic's controls are (33.33, 16.67) and (66.67, 33.33), and its
    // middle (50, (3 × 16.67 + 3 × 33.33 + 100) / 8 = 31.25), 18.75px off.
    test("d3's monotone slope is capped at half |p|, so collinear points draw "
        'a straight line (monotone.js:15)', () {
      const points = [Offset.zero, Offset(100, 100), Offset(200, 200)];
      final path = Path();
      addMonotoneXPath(path, points);
      final off = along(path).map((p) => (p.dy - p.dx).abs()).reduce(math.max);
      expect(off, lessThan(1e-2));
    });

    // recharts 3.10.1 es6/shape/Sector.js:193: the corner is at most half
    // the ring, `Math.min(cr, deltaRadius / 2)`. Ring 40 to 80 round
    // (100, 100), 0° to 90°, corner 30: 20, so each end is a half disc of
    // radius 20 round a centre at radius 60, asin(20 / 60) = 19.47° in:
    // (156.57, 80) for the 0° end, 16.4px from (160, 96), which is inside.
    // Capped at the ring (30), the outer corner circle is round (140, 70)
    // and the inner one round (163.25, 70), both radius 30, and they cross:
    // (160, 96) is 2.8px outside the first and 3.8px inside the second,
    // above that arc's bottom (y 99.82 at x 160) and the closing edge
    // (y 100), which wind it to 0: outside.
    test("recharts' sector corner is at most half the ring "
        '(Sector.js:193)', () {
      final sector = rechartsSectorPath(
        center: const Offset(100, 100),
        innerRadius: 40,
        outerRadius: 80,
        startAngle: 0,
        endAngle: 90,
        cornerRadius: 30,
      );
      expect(sector.contains(const Offset(160, 96)), isTrue);
    });

    // d3-shape 3.2.0 src/arc.js:126: `rc = min(abs(r1 - r0) / 2,
    // cornerRadius)`. Ring 80 to 200, 12 to 3 o'clock, corner 20 (a quarter
    // limits it only past 200 / (1 + √2) = 82.8, :166-167). The outer corner
    // at 12 o'clock touches the edge (x = 0) and the outer circle, so its
    // centre is (20, -√(180² - 20²)) = (20, -178.89), 14.3px from
    // (11, -190): inside. A corner of 40 would be centred at
    // (40, -√(160² - 40²)) = (40, -154.92), 45.5px from it: cut off.
    test("d3's arc corner radius is the one given, below half the ring "
        '(arc.js:126)', () {
      final slice = d3ArcPath(
        center: Offset.zero,
        innerRadius: 80,
        outerRadius: 200,
        startAngle: 0,
        endAngle: math.pi / 2,
        cornerRadius: 20,
      );
      expect(slice.contains(const Offset(11, -190)), isTrue);
    });
  });
}
