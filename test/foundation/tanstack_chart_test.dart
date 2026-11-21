// Unit tests of the TanStack Charts 1.1.0 ports in lib/src/foundation/chart
// (tanstack_scale, tanstack_stack, tanstack_guides, tanstack_interaction):
// the expected values are worked out from the published source each test
// names.

import 'dart:math' as math;
import 'dart:ui';

import 'package:a2ui_kit/src/foundation/chart/tanstack_guides.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_interaction.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_scale.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_stack.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

TanstackPoint _point(
  int datum,
  double x,
  double y, {
  Object? group,
  String mark = 'm',
  Object? xValue,
  Object? yValue,
}) => TanstackPoint(
  key: '$mark:$group:$datum',
  markId: mark,
  group: group,
  datum: datum,
  x: x,
  y: y,
  color: const Color(0xff000000),
  xValue: xValue ?? x,
  yValue: yValue ?? y,
);

void main() {
  group('scales/ticks.js and scales/linear.js', () {
    test('ticks and the step by the preferred multiples 1, 2, 5, 10', () {
      expect(tanstackTicks(0, 40, 2), [0, 20, 40]);
      expect(tanstackTicks(0, 40, 4), [0, 10, 20, 30, 40]);
      expect(tanstackTicks(2019, 2022, 4), [2019, 2020, 2021, 2022]);
      expect(tanstackTicks(1, 0, 2), [1, .5, 0]);
      expect(tanstackTicks(3, 3, 5), [3]);
      expect(tanstackTicks(0, 1, 0), isEmpty);
      expect(tanstackTickStep(0, 2, 4), .5);
      expect(tanstackTickStep(2, 0, 4), -.5);
    });

    test("tickFormat: the step's decimals, else String(); never -0", () {
      final half = TanstackLinearScale(0, 2).tickFormat(4);
      expect([half(0), half(.5), half(1)], ['0.0', '0.5', '1.0']);
      final whole = TanstackLinearScale(2019, 2022).tickFormat(4);
      expect(whole(2020), '2020');
      final negativeZero = double.parse('-0');
      expect(negativeZero.isNegative, isTrue);
      expect(TanstackLinearScale(-1, 1).tickFormat(4)(negativeZero), '0.0');
      expect(TanstackLinearScale(-10, 10).tickFormat(4)(negativeZero), '0');
    });

    test('nice extends the domain to the step, stopping when it settles', () {
      final scale = TanstackLinearScale(47.5, 52.5)..nice(5);
      expect((scale.domain0, scale.domain1), (47, 53));
      final reversed = TanstackLinearScale(9.5, .5)..nice(5);
      expect((reversed.domain0, reversed.domain1), (10, 0));
    });

    test('a domain of one value widens 5% each way, 0 to 0..1 (F20)', () {
      expect(tanstackInferDomain([50, 50]), (47.5, 52.5));
      expect(tanstackInferDomain([-20]), (-21.0, -19.0));
      expect(tanstackInferDomain([0]), (0, 1));
      expect(tanstackInferDomain([3, 9], includeZero: true), (0, 9));
      expect(tanstackInferDomain([]), isNull);
      final scale = tanstackLinearScale([50, 50], niceCount: 5);
      expect(scale.ticks(5), [47, 48, 49, 50, 51, 52, 53]);
    });

    test('tick count: count, else one per 92px (x, 2..8) or 48px (y, 2..7) '
        '(F2)', () {
      expect(tanstackTickCount(length: 600, x: true), 6);
      expect(tanstackTickCount(length: 200, x: true), 2);
      expect(tanstackTickCount(length: 2000, x: true), 8);
      expect(tanstackTickCount(length: 2000, x: false), 7);
      expect(tanstackTickCount(length: 50, x: true, count: 5), 5);
    });
  });

  group('stack-internal.js and stack-ends-internal.js', () {
    test('diverging from 0, in series order (F15)', () {
      final extents = tanstackStackValues(
        ['Jan', 'Jan', 'Feb'],
        [5, -3, 2],
        ['A', 'B', 'A'],
        order: ['A', 'B'],
      );
      expect(extents, [
        (start: 0.0, end: 5.0),
        (start: -3.0, end: 0.0),
        (start: 0.0, end: 2.0),
      ]);
    });

    test('a series missing at a position has no extent there (F17)', () {
      final extents = tanstackStackValues(['Jan', 'Jan', 'Feb'], [1, 2, 3], [
        'A',
        'B',
        'B',
      ]);
      expect(extents, hasLength(3));
      expect(extents[2], (start: 0.0, end: 3.0));
    });

    test('two values of one series at one position throw (F16)', () {
      expect(
        () => tanstackStackValues(['Jan', 'Jan'], [1, 2], ['A', 'A']),
        throwsA(isA<TanstackStackError>()),
      );
      // The text "1" and the number 1 are different positions.
      expect(tanstackStackValues(['1', 1], [1, 2], ['A', 'A']), hasLength(2));
    });

    test('a zero at the top is skipped for the rounded end (F18)', () {
      final extents = tanstackStackValues(['Jan', 'Jan', 'Jan'], [5, 0, -2], [
        'A',
        'B',
        'C',
      ]);
      final ends = tanstackStackOuterEnds(
        ['Jan', 'Jan', 'Jan'],
        [5, 0, -2],
        extents,
      );
      expect(ends[0], (start: false, end: true));
      expect(ends[1], isNull);
      expect(ends[2], (start: true, end: false));
    });
  });

  group('polar-pie.js and proportional-interval-internal.js (F19)', () {
    test('two equal slices: a gap after each, from 0', () {
      final slices = tanstackPie([1, 1], gapAngle: .025);
      expect(slices[0].startAngle, 0);
      expect(slices[0].endAngle, closeTo(math.pi - .025, 1e-12));
      expect(slices[1].startAngle, closeTo(math.pi, 1e-12));
      expect(slices[1].endAngle, closeTo(2 * math.pi - .025, 1e-12));
      expect(slices[0].fraction, .5);
    });

    test('a slice of 0 takes no angle and no gap', () {
      final slices = tanstackPie([1, 0, 1], gapAngle: .025);
      expect(slices[1].startAngle, slices[1].endAngle);
      expect(slices[1].startAngle, closeTo(math.pi, 1e-12));
      expect(slices[2].endAngle, closeTo(2 * math.pi - .025, 1e-12));
    });
  });

  group('scene.js thinTickLabels (F14)', () {
    TanstackLabelCandidate candidate(double left) => TanstackLabelCandidate(
      left,
      TanstackLabel(
        text: '$left',
        x: left,
        y: 0,
        fontSize: 10,
        color: const Color(0xff000000),
      ),
      Rect.fromLTWH(left, 0, 30, 10),
    );

    test('a band x keeps its ends first, then bisects', () {
      // Each label overlaps only its neighbours.
      final labels = [
        for (final x in const <double>[0, 25, 50, 75]) candidate(x),
      ];
      final kept = thinTickLabels(labels, categoricalX: true);
      expect([for (final c in kept) c.value], [0, 75]);
      final linear = thinTickLabels(labels, categoricalX: false);
      // The middle (index 2) first, then index 1's neighbourhood...
      expect([for (final c in linear) c.value], [0, 50]);
    });

    test('bisection order: the middle, then the middles of the halves', () {
      expect(distributedCandidates([0, 1, 2, 3, 4, 5, 6]), [
        3,
        1,
        5,
        0,
        2,
        4,
        6,
      ]);
      expect(distributedCandidates([0, 1]), [0, 1]);
    });

    test('bounds collide within the gap', () {
      const a = Rect.fromLTWH(0, 0, 10, 10);
      expect(boundsCollide(a, const Rect.fromLTWH(14, 0, 10, 10), 4), isFalse);
      expect(boundsCollide(a, const Rect.fromLTWH(13, 0, 10, 10), 4), isTrue);
    });

    test('rotated bounds swap width and height round the origin', () {
      final bounds = rotateBounds(
        const Rect.fromLTWH(-20, -5, 40, 10),
        0,
        0,
        -90,
      );
      expect(bounds.width, closeTo(10, 1e-9));
      expect(bounds.height, closeTo(40, 1e-9));
      expect(bounds.center.dx, closeTo(0, 1e-9));
    });
  });

  group('tooltip-placement.js (F9)', () {
    const boundary = Rect.fromLTWH(0, 0, 400, 300);

    test('above the anchor, 10px away, centred', () {
      final at = tanstackTooltipPlacement(
        const Offset(200, 150),
        const Size(80, 40),
        boundary,
      );
      expect(at, const Offset(160, 100));
    });

    test('below when the top has no room, then clamped 8px inside', () {
      final below = tanstackTooltipPlacement(
        const Offset(200, 20),
        const Size(80, 40),
        boundary,
      );
      expect(below, const Offset(160, 30));
      final clamped = tanstackTooltipPlacement(
        const Offset(5, 150),
        const Size(80, 40),
        boundary,
      );
      // Right of it fits (15px), above does not leave 8px on the left.
      expect(clamped, const Offset(15, 130));
    });
  });

  group('focus.js, nearest.js and interaction.js', () {
    test('group-x: the points at the nearest x, the one nearest in y first '
        '(F8)', () {
      final a = _point(0, 100, 50, group: 'A');
      final b = _point(1, 100, 10, group: 'B');
      final c = _point(2, 200, 30, group: 'A');
      final focused = tanstackFocusResolve(
        TanstackFocus.groupX,
        [a, b, c],
        110,
        12,
        48,
      );
      expect(focused, [b, a]);
      final single = tanstackFocusResolve(
        TanstackFocus.nearestX,
        [a, b, c],
        110,
        12,
        48,
      );
      expect(single, [b]);
      expect(
        tanstackFocusResolve(TanstackFocus.groupX, [a], 200, 0, 48),
        isEmpty,
      );
    });

    test('a bar focuses along its axis within 48px; a dot from its edge '
        '(F12)', () {
      final p = _point(0, 50, 100);
      final bar = TanstackTarget.rect(
        const Rect.fromLTWH(40, 100, 20, 100),
        affinity: TanstackAffinity.x,
        point: p,
      );
      expect(tanstackNearestPoint([bar], [p], 100, 0, 48), p);
      expect(tanstackNearestPoint([bar], [p], 109, 0, 48), isNull);
      final q = _point(1, 0, 0);
      final dot = TanstackTarget.dot(
        Offset.zero,
        10,
        affinity: TanstackAffinity.xy,
        point: q,
      );
      expect(tanstackNearestPoint([dot], [q], 57, 0, 48), q);
      expect(tanstackNearestPoint([dot], [q], 59, 0, 48), isNull);
    });

    // dist/focus.js:26: a strict `<`, so of two points equally near in y
    // the first found stays primary.
    test('a tie in y keeps the first point primary', () {
      final a = _point(0, 100, 40, group: 'A');
      final b = _point(1, 100, 60, group: 'B');
      expect(tanstackFocusResolve(TanstackFocus.groupX, [a, b], 100, 50, 48), [
        a,
        b,
      ]);
    });

    // dist/nearest.js:30-46: of targets equally near along their axis, the
    // nearer in geometry wins, whichever comes first.
    test('a tie along the axis goes to the nearer target', () {
      final far = _point(0, 50, 5);
      final near = _point(1, 50, 105);
      final targets = [
        TanstackTarget.rect(
          const Rect.fromLTWH(40, 0, 20, 10),
          affinity: TanstackAffinity.x,
          point: far,
        ),
        TanstackTarget.rect(
          const Rect.fromLTWH(40, 100, 20, 10),
          affinity: TanstackAffinity.x,
          point: near,
        ),
      ];
      expect(tanstackNearestPoint(targets, [far, near], 50, 80, 48), near);
    });

    test('the last painted target under the pointer wins', () {
      final first = _point(0, 0, 0);
      final last = _point(1, 4, 0);
      final targets = [
        TanstackTarget.dot(
          Offset.zero,
          10,
          affinity: TanstackAffinity.xy,
          point: first,
        ),
        TanstackTarget.dot(
          const Offset(4, 0),
          10,
          affinity: TanstackAffinity.xy,
          point: last,
        ),
      ];
      expect(tanstackNearestPoint(targets, [first, last], 1, 0, 48), last);
    });

    test('keyboard: one step clamped, Home, End; screen order without a '
        'strategy (F21)', () {
      final points = [
        _point(0, 30, 0),
        _point(1, 10, 0),
        _point(2, 20, 5),
        _point(3, 20, 1),
      ];
      expect(
        tanstackPointFromNavigationOrder(points, null, TanstackKey.next),
        points[0],
      );
      expect(
        tanstackPointFromNavigationOrder(points, points[3], TanstackKey.next),
        points[3],
      );
      expect(
        tanstackPointFromNavigationOrder(points, null, TanstackKey.last),
        points[3],
      );
      expect(
        tanstackPointFromSceneOrder(points, null, TanstackKey.first),
        points[1],
      );
      expect(
        tanstackPointFromSceneOrder(points, points[1], TanstackKey.next),
        points[3],
      );
      expect(
        tanstackPointFromSceneOrder(points, points[0], TanstackKey.next),
        points[0],
      );
      expect(
        tanstackPointFromSceneOrder(points, null, TanstackKey.last),
        points[0],
      );
    });

    test('tooltip rows by screen y, or by x when they share y (F10)', () {
      final low = _point(0, 10, 80, xValue: 'Jan');
      final high = _point(1, 10, 20, xValue: 'Jan');
      expect(tanstackTooltipOrder([low, high]), [high, low]);
      final right = _point(2, 90, 50, yValue: 'NA', xValue: 3);
      final left = _point(3, 30, 50, yValue: 'NA', xValue: 5);
      expect(tanstackTooltipOrder([right, left]), [left, right]);
    });

    test('corner radii scale down together, as CSS does', () {
      expect(tanstackCornerRadii([4, 4, 0, 0], 6, 20), [3, 3, 0, 0]);
      expect(tanstackCornerRadii([4, 4, 0, 0], 20, 2), [2, 2, 0, 0]);
      expect(tanstackCornerRadii([4, 4, 4, 4], 20, 6), [3, 3, 3, 3]);
    });
  });

  group('boundaries the review found untested (running review CR9, CR10, '
      'CR11)', () {
    // dist/scene.js:1241: `minGap` is 4 unless the axis sets one. The first
    // label ends at 30 and the second starts at 32: 30 + 4 > 32, so they
    // collide and the second is left out; with a gap of 0 (30 <= 32) both
    // stay.
    test('tick labels 2px apart collide: the gap is 4px (scene.js:1241)', () {
      TanstackLabelCandidate at(double left) => TanstackLabelCandidate(
        left,
        TanstackLabel(
          text: '$left',
          x: left,
          y: 0,
          fontSize: 10,
          color: const Color(0xff000000),
        ),
        Rect.fromLTWH(left, 0, 30, 10),
      );
      final labels = [at(0), at(32)];
      for (final categoricalX in [false, true]) {
        final kept = thinTickLabels(labels, categoricalX: categoricalX);
        expect([for (final c in kept) c.value], [0]);
      }
    });

    // dist/tooltip-placement.js:8: `edge = 8`. An 80 × 40 tooltip above an
    // anchor 30px into a boundary from x 20 to 120 starts at 50 - 40 = 10:
    // 20 + 8 - 10 = 18 over on the left, less than right of the anchor
    // (60 + 80 + 8 - 120 = 28) or left of it (20 + 8 + 40 = 68), so it stays
    // above, clamped to 20 + 8 = 28. Anchored at 90 it is clamped to
    // 120 - 8 - 80 = 32. An edge of 4 gives 24 and 36.
    test('the tooltip is kept 8px inside the boundary '
        '(tooltip-placement.js:8)', () {
      const boundary = Rect.fromLTWH(20, 0, 100, 300);
      const size = Size(80, 40);
      expect(
        tanstackTooltipPlacement(const Offset(50, 150), size, boundary),
        const Offset(28, 100),
      );
      expect(
        tanstackTooltipPlacement(const Offset(90, 150), size, boundary),
        const Offset(32, 100),
      );
    });

    // dist/stack-internal.js:77-86 and 100-101: a series with negative
    // values and no positive one is on the negative side, and its zero sits
    // on the negative baseline. In Feb, B (stacked first) takes the negative
    // baseline to -1, so A's 0 there is (-1, -1); on the positive baseline
    // (0) it would be (0, 0). With A first both baselines are still 0 there
    // and the two agree, so B goes first.
    test('a zero of a series with only negatives sits on the negative '
        'baseline (stack-internal.js:100-101)', () {
      final extents = tanstackStackValues(
        ['Jan', 'Feb', 'Mar', 'Jan', 'Feb', 'Mar'],
        [-1, -1, -1, -3, 0, -2],
        ['B', 'B', 'B', 'A', 'A', 'A'],
        order: ['B', 'A'],
      );
      expect(extents, [
        (start: -1.0, end: 0.0),
        (start: -1.0, end: 0.0),
        (start: -1.0, end: 0.0),
        (start: -4.0, end: -1.0),
        (start: -1.0, end: -1.0),
        (start: -3.0, end: -1.0),
      ]);
    });
  });
}
