// The playground charts with finite values whose arithmetic overflows a
// double (RR2-1) and their focus kept by the point's key across new data
// (RR2-6), from the charts' second running review. RULEBOOK section 6
// item 3: every scene is painted, with no focus and with each focus its
// keys reach (points that are not drawn included), into a recording
// canvas, and no Canvas call may get a number that is not finite; a point
// that is not drawn takes the focus as TanStack's own comparisons give it,
// its anchor and tooltip place NaN where TanStack's are. Expected values
// are worked out from @tanstack/charts 1.1.0's published source, cited next
// to each.

import 'dart:math' as math;

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/playground/charts/cartesian.dart';
import 'package:a2ui_kit/src/components/playground/charts/pie_sparkline.dart';
import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_interaction.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_scale.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/finite_canvas.dart';
import '../helpers/harness.dart';

final _playground = A2uiKitTheme.playground(Brightness.light);

/// `Number.MAX_VALUE`.
const double _max = double.maxFinite;

/// Values whose arithmetic overflows a double, alone and among ordinary
/// ones: a span of 2e308 is Infinity.
const Map<String, List<double>> _sets = {
  'huge': [1e308, -1e308, 1e308],
  'max': [_max, -_max, _max],
  'mixed': [3, 1e308, -1e308, 7],
  'mixed, one side': [3, 1e308, 7],
  'max with 0': [-_max, 0, 5],
};

List<Map<String, Object?>> _xy(List<double> ys, {String? series}) => [
  for (final (i, y) in ys.indexed) {'x': 'X$i', 'y': y, 'series': ?series},
];

List<Map<String, Object?>> _twoSeries(List<double> ys) => [
  ..._xy(ys, series: 'A'),
  ..._xy(ys, series: 'B'),
];

/// Each playground chart's props for the values `ys`.
final Map<String, Map<String, Object?> Function(List<double> ys)> _charts = {
  'LineChart': (ys) => {'component': 'LineChart', 'data': _xy(ys)},
  'LineChart, two series': (ys) => {
    'component': 'LineChart',
    'data': _twoSeries(ys),
  },
  'AreaChart, stacked': (ys) => {
    'component': 'AreaChart',
    'data': _twoSeries(ys),
  },
  'AreaChart, not stacked': (ys) => {
    'component': 'AreaChart',
    'stacked': false,
    'data': _twoSeries(ys),
  },
  'BarChart': (ys) => {'component': 'BarChart', 'data': _xy(ys)},
  'BarChart, horizontal': (ys) => {
    'component': 'BarChart',
    'horizontal': true,
    'data': _xy(ys),
  },
  'BarChart, grouped': (ys) => {
    'component': 'BarChart',
    'data': _twoSeries(ys),
  },
  'BarChart, stacked': (ys) => {
    'component': 'BarChart',
    'stacked': true,
    'data': _twoSeries(ys),
  },
  'ScatterChart': (ys) => {
    'component': 'ScatterChart',
    'data': [
      for (final (i, y) in ys.indexed) {'x': i * 2, 'y': y},
    ],
  },
  'PieChart, pie': (ys) => {
    'component': 'PieChart',
    'donut': false,
    'data': [
      for (final (i, y) in ys.indexed) {'label': 'L$i', 'value': y},
    ],
  },
  'PieChart, donut': (ys) => {
    'component': 'PieChart',
    'data': [
      for (final (i, y) in ys.indexed) {'label': 'L$i', 'value': y},
    ],
  },
  'Sparkline': (ys) => {'component': 'Sparkline', 'label': 'MRR', 'values': ys},
};

Future<void> _pump(WidgetTester tester, Map<String, Object?> props) async {
  await pumpComponents(tester, theme: _playground, [
    {'id': 'root', ...props},
  ]);
  // The playground charts measure and grow in over a few frames.
  await tester.pumpAndSettle();
}

List<TanstackScene> _scenes(WidgetTester tester) => [
  for (final paint in tester.widgetList<CustomPaint>(find.byType(CustomPaint)))
    if (paint.painter case final ChartScenePainter painter)
      if (painter.scene case final TanstackScene scene) scene,
];

Future<T> _sceneOf<T extends TanstackScene>(
  WidgetTester tester,
  Map<String, Object?> props,
) async {
  await _pump(tester, props);
  return _scenes(tester).whereType<T>().single;
}

/// The arguments of every `drawCircle` [scene] makes with [focus].
List<List<Object?>> _circles(TanstackScene scene, PlotFocus? focus) {
  final canvas = TestRecordingCanvas();
  scene.paint(canvas, focus);
  return [
    for (final call in canvas.invocations)
      if (call.invocation.memberName == #drawCircle)
        call.invocation.positionalArguments,
  ];
}

/// Hovers across every plot, clicks it, then Tab, the arrows, End, Home,
/// Enter, Space and Escape; the exceptions any of it raised.
Future<List<String>> _interact(WidgetTester tester) async {
  final problems = <String>[];
  void take(String what) {
    if (tester.takeException() case final e?) problems.add('$what: $e');
  }

  final plots = find.byType(ChartPlot);
  for (var p = 0; p < plots.evaluate().length; p++) {
    final rect = tester.getRect(plots.at(p));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    for (final f in [.02, .25, .5, .75, .98]) {
      await mouse.moveTo(
        Offset(rect.left + rect.width * f, rect.top + rect.height / 2),
      );
      await tester.pump();
      take('hover $f');
    }
    await mouse.down(rect.center);
    await tester.pump();
    await mouse.up();
    await tester.pump();
    take('click');
    await mouse.moveTo(const Offset(5000, 5000));
    await mouse.removePointer();
    await tester.pump();
    take('mouse leaves');
  }
  for (final key in [
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.end,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.escape,
  ]) {
    await tester.sendKeyEvent(key);
    await tester.pump(const Duration(milliseconds: 450));
    take('key ${key.keyLabel}');
  }
  return problems;
}

void main() {
  _arithmeticTests();
  _everyChartTests();
  _keyTests();
  _sortInputTests();
}

// RC3-8 (RULEBOOK section 0 item 4): TanStack sorts its points with
// comparators of their coordinates' differences (`l.x - r.x || l.y - r.y`,
// dist/focus.js:35-46; `l.y - r.y`, :49-60; dist/tooltip-model.js:2-16),
// and ECMAScript leaves the order an inconsistent comparator gives
// implementation-defined. The port sorts stably, which gives the browser's
// order only while no comparator is inconsistent on the points the charts
// make. That holds by these invariants, which a change that makes the
// input reachable breaks:
// - on each axis of an axis chart the points' coordinates are all finite or
//   all NaN: a coordinate is NaN only when its scale's span overflows
//   (dist/scales/linear.js:76-81), and then that axis' one tick sits at NaN
//   (dist/scales/ticks.js:2-19, :45-51) and its label makes the axis' two
//   margins NaN (dist/scene.js:756-767);
// - in the Sparkline, which has no axes, points sharing an x share a y;
// - pie points are finite (charts.tsx:529-533 keeps values of 0 or more;
//   an infinite total is rescaled, dist/proportional-interval-internal.js:
//   25-26).
void _sortInputTests() {
  group("the sorts' inputs keep TanStack's comparators consistent (RC3-8)", () {
    final sets = <String, List<double>>{
      'ordinary': [3, 1, 4, 1, 5],
      ..._sets,
    };
    final charts = <String, Map<String, Object?> Function(List<double>)>{
      ..._charts,
      'ScatterChart, x overflows': (ys) => {
        'component': 'ScatterChart',
        'data': [
          for (final (i, y) in ys.indexed) {'x': y, 'y': i * 2},
        ],
      },
      'LineChart, numeric x overflows': (ys) => {
        'component': 'LineChart',
        'data': [
          for (final (i, y) in ys.indexed) {'x': y, 'y': i * 2},
        ],
      },
    };
    String? axisProblem(String axis, List<double> values) {
      if (values.every((v) => v.isFinite) || values.every((v) => v.isNaN)) {
        return null;
      }
      return '$axis mixes finite and non-finite: $values';
    }

    for (final MapEntry(key: name, value: props) in charts.entries) {
      testWidgets(name, (tester) async {
        final problems = <String>[];
        for (final MapEntry(key: set, value: ys) in sets.entries) {
          await _pump(tester, props(ys));
          final scenes = _scenes(tester);
          expect(scenes, isNotEmpty, reason: set);
          for (final scene in scenes) {
            final points = scene.points;
            switch (scene) {
              case PieScene():
                for (final p in points) {
                  if (!p.x.isFinite || !p.y.isFinite) {
                    problems.add('$set: a slice at (${p.x}, ${p.y})');
                  }
                }
              case SparklineScene():
                for (final a in points) {
                  for (final b in points) {
                    final sameX = a.x == b.x || a.x.isNaN && b.x.isNaN;
                    final sameY = a.y == b.y || a.y.isNaN && b.y.isNaN;
                    if (sameX && !sameY) {
                      problems.add('$set: x ${a.x} at y ${a.y} and ${b.y}');
                    }
                  }
                }
              default:
                for (final problem in [
                  axisProblem('x', [for (final p in points) p.x]),
                  axisProblem('y', [for (final p in points) p.y]),
                ]) {
                  if (problem != null) problems.add('$set: $problem');
                }
            }
          }
          await tester.pumpWidget(const SizedBox());
        }
        expect(problems, isEmpty);
      });
    }
  });

  // P21 (RR3-3): `left.x - right.x || left.y - right.y` falls through a NaN
  // difference to y (dist/focus.js:35-46; JavaScript's `||`, NaN falsy).
  test("nearest-x's order falls through a NaN x to y", () {
    TanstackPoint at(int datum, double x, double y) => TanstackPoint(
      key: 'line:$datum',
      markId: 'line',
      group: null,
      datum: datum,
      x: x,
      y: y,
      color: const Color(0xff000000),
    );
    final points = [
      at(0, double.nan, 30),
      at(1, double.nan, 10),
      at(2, double.nan, 20),
    ];
    expect(
      [
        for (final p in tanstackFocusNavigation(TanstackFocus.nearestX, points))
          p.datum,
      ],
      [1, 2, 0],
    );
    // A tie in x and in y keeps the data's order (a stable sort), past the
    // 32 items under which Dart's own sort happens to keep it.
    final tied = [at(0, 5, 1), at(1, 5, 1), at(2, 4, 1)];
    expect(
      [
        for (final p in tanstackFocusNavigation(TanstackFocus.nearestX, tied))
          p.datum,
      ],
      [2, 0, 1],
    );
    final many = [
      for (var i = 0; i < 200; i++) at(i, (i * 7919 % 5).toDouble(), 1),
    ];
    final order = [
      for (final p in tanstackFocusNavigation(TanstackFocus.nearestX, many))
        p.datum,
    ];
    expect(order, [
      for (var x = 0; x < 5; x++)
        for (var i = 0; i < 200; i++)
          if (i * 7919 % 5 == x) i,
    ]);
  });

  // P21 at widget level (the running review's probe): a LineChart whose
  // numeric x overflows its scale has every x at NaN, so the keys step by y.
  testWidgets('nearest-x over points whose x is NaN orders the keys by y', (
    tester,
  ) async {
    await _pump(tester, {
      'component': 'LineChart',
      'data': [
        for (final (x, y) in [(-1e308, 5), (0.0, 1), (1e308, 3)])
          {'x': x, 'y': y},
      ],
    });
    final scene = _scenes(tester).whereType<LineAreaScene>().single;
    for (final p in scene.points) {
      expect(p.x, isNaN);
      expect(p.y.isFinite, isTrue);
    }
    final ys = [for (final f in keyboardFoci(scene)) scene.anchorOf(f).dy];
    expect(ys, hasLength(scene.points.length));
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThanOrEqualTo(ys[i - 1]), reason: '$ys');
    }
    expect(ys.first, lessThan(ys.last));
  });
}

void _arithmeticTests() {
  group('TanStack arithmetic for ±1e308 (RR2-1)', () {
    test('a linear scale over -1e308..1e308 stays as it is under nice(), '
        'maps -1e308 to its range start and 1e308 to NaN, and has one tick, '
        'at NaN', () {
      final scale = TanstackLinearScale(-1e308, 1e308)..nice(5);
      // dist/scales/linear.js:46-65: tickIncrement(-1e308, 1e308, 5) is
      // Infinity (ticks.js:45-51: the target (1e308 - -1e308) / 5 is
      // Infinity, and 10 ** Infinity); start = Math.floor(-1e308 / Infinity)
      // * Infinity = -0 * Infinity = NaN, and stop NaN too; the next step is
      // NaN, neither > 0 nor < 0, so the loop breaks before it assigns the
      // domain.
      expect(scale.domain0, -1e308);
      expect(scale.domain1, 1e308);
      // linear.js:76-81: span = 1e308 - -1e308 = Infinity. -1e308: 0 /
      // Infinity = 0, the range start; 5: 1e308 / Infinity = 0, the range
      // start too; 1e308: Infinity / Infinity = NaN.
      expect(scale.map(-1e308, 200, 0), 200);
      expect(scale.map(5, 200, 0), 200);
      expect(scale.map(1e308, 200, 0), isNaN);
      // ticks.js:2-19: the plan's interval is Infinity, its first index -0
      // (-1e308 / Infinity, rounded) and its last 0: one tick, at
      // valueAtIndex(0, Infinity) = 0 * Infinity = NaN.
      final ticks = scale.ticks(5);
      expect(ticks, hasLength(1));
      expect(ticks.single, isNaN);
    });

    test('a value that is not finite maps to NaN, not to an end of the '
        'range', () {
      // dist/scales/linear.js:7 gives undefined and dist/configured-scale.js:
      // 26-29 turns it into NaN; `interpolate` alone would give Infinity
      // (a wrong port's answer).
      expect(TanstackLinearScale(0, 10).map(double.infinity, 0, 100), isNaN);
      expect(
        TanstackLinearScale(0, 10).map(double.negativeInfinity, 0, 100),
        isNaN,
      );
      expect(TanstackLinearScale(0, 10).map(5, 0, 100), 50);
    });

    testWidgets('LineChart: the y axis tick at NaN makes the plot NaN tall, '
        'so every point, the -1e308 one too, is at y NaN: nothing is drawn, '
        'and the keys and the pointer focus the points all the same', (
      tester,
    ) async {
      final scene = await _sceneOf<LineAreaScene>(tester, {
        'component': 'LineChart',
        'data': _xy(_sets['huge']!),
      });
      // The y axis' one tick is at NaN (above), so its label's box is at y
      // NaN, and includeBoundsMargin takes Math.max(4, chart.y - NaN + 4) =
      // NaN for the top margin, and the bottom one (dist/scene.js:756-767,
      // :1062-1066). marginsEqual never holds (:787-791), so after four
      // passes the layout compiles with them (:549-565): chart.y is NaN and
      // chart.height Math.max(1, NaN) = NaN (:567-572). The y range is NaN,
      // so the -1e308 point's ratio of 0 gives NaN + 0 * NaN = NaN.
      expect(scene.plot.top, isNaN);
      expect(scene.plot.height, isNaN);
      expect(scene.plot.left.isFinite, isTrue);
      expect(scene.plot.width.isFinite, isTrue);
      expect(scene.points, isNotEmpty);
      for (final point in scene.points) {
        expect(point.x.isFinite, isTrue);
        expect(point.y, isNaN);
      }
      // Every grid rule, label, dot and the line is at y NaN: none is
      // drawn.
      expect(paintCalls(scene).where((c) => c.startsWith('draw')), isEmpty);
      expect(nonFiniteScene(scene), isEmpty);
      // The keys step over every point (`nearest-x`'s navigation sorts by
      // x, then y: `left.x - right.x || left.y - right.y`, dist/focus.js:
      // 35-46), Home and End included (dist/interaction.js:60-65).
      expect(keyboardFoci(scene), const [
        PlotFocus(0),
        PlotFocus(1),
        PlotFocus(2),
      ]);
      expect(scene.navigate(null, PlotNavigation.last), const PlotFocus(2));
      // A focused point that isn't drawn draws nothing (no ring, no
      // crosshair: dist/crosshair-resolver.js:103 in a plot at NaN), and its
      // tooltip shows its row.
      const focus = PlotFocus(1);
      expect(
        paintCalls(scene, focus: focus).where((c) => c.startsWith('draw')),
        isEmpty,
      );
      final tooltip = scene.tooltipOf(focus)!;
      expect(tooltip.title, 'X1');
      expect(tooltip.rows, hasLength(1));
      // Its anchor is the point, at y NaN (dist/tooltip-model.js:30-38).
      final x1 = scene.points[1].x;
      expect(scene.anchorOf(focus).dx, x1);
      expect(scene.anchorOf(focus).dy, isNaN);
      // dist/tooltip-placement.js:7-70: every candidate's top is NaN, so
      // every overflow is NaN; none is 0 and none is less, and the first,
      // "top", stays: left = clamp(x - 80 / 2, 8, width - 8 - 80), top =
      // clamp(NaN) = NaN (`Math.max` and `Math.min` keep a NaN).
      final place = scene.tooltipPosition(focus, null, const Size(80, 40));
      final maxLeft = math.max<double>(8, scene.size.width - 8 - 80);
      expect(place.dx, math.max<double>(8, math.min(maxLeft, x1 - 40)));
      expect(place.dy, isNaN);
      // A `top` that never parsed leaves the box at its static place: at
      // the left, under the `<svg>` (dist/tooltip.js:184-196, 312-326).
      expect(scene.tooltipStaticPlace, Offset(0, scene.size.height));
      // The pointer: `nearest-x` measures x alone (dist/focus.js:11-30), so
      // the point under the pointer's x is focused, its y NaN or not.
      expect(scene.focusAt(Offset(x1, 10)), focus);
      // Kept by its key across new data like any point.
      final key = scene.focusKeyOf(focus)!;
      expect(scene.focusOfKey(key), focus);
    });

    testWidgets('LineChart, two series, numeric x: the x tick at NaN makes '
        'every x NaN, and group-x makes them one stop and one group', (
      tester,
    ) async {
      final scene = await _sceneOf<LineAreaScene>(tester, {
        'component': 'LineChart',
        'data': [
          for (final (i, x) in [-1e308, 0.0, 1e308].indexed) ...[
            {'x': x, 'y': i + 1, 'series': 'A'},
            {'x': x, 'y': i + 4, 'series': 'B'},
          ],
        ],
      });
      // All x numbers: a linear x scale (charts.tsx:186), over
      // -1e308..1e308, whose one tick is at NaN; the bottom axis keeps its
      // lone label (dist/scene.js:1238-1239: thinning needs two), and its
      // box at x NaN makes the left and right margins NaN
      // (dist/scene.js:756-767): every x is NaN, every y finite.
      expect(scene.points, isNotEmpty);
      for (final p in scene.points) {
        expect(p.x, isNaN);
        expect(p.focusX, isNaN);
        expect(p.y.isFinite, isTrue);
      }
      // group-x's navigation keeps one point per x value key
      // (dist/focus.js:40-44): every NaN is `number:NaN`, one key, so the
      // keys have one stop.
      final foci = keyboardFoci(scene);
      expect(foci, hasLength(1));
      // Its group is every point whose x has that key, one per series
      // (dist/focus.js:49-60): A's and B's.
      expect(
        {for (final p in scene.focusPoints(foci.single)) p.group},
        {'A', 'B'},
      );
      expect(scene.focusPoints(foci.single), hasLength(2));
    });

    testWidgets('AreaChart, stacked: a row whose sum overflows has no '
        'point, so no sort sees a NaN', (tester) async {
      // The series stack in the order first seen (A, X, B, C at "Q");
      // at "P" they end at 3e307, 6e307, 9e307 and 9e307 + 9e307 =
      // Infinity. The y domain leaves Infinity out (dist/scale-input.js:51,
      // `isChartValue`), so its ticks are finite and no margin is NaN.
      final scene = await _sceneOf<LineAreaScene>(tester, {
        'component': 'AreaChart',
        'data': [
          for (final s in ['A', 'X', 'B', 'C']) {'x': 'Q', 'y': 1, 'series': s},
          {'x': 'P', 'y': 3e307, 'series': 'A'},
          {'x': 'P', 'y': 3e307, 'series': 'B'},
          {'x': 'P', 'y': 9e307, 'series': 'C'},
          {'x': 'P', 'y': 3e307, 'series': 'X'},
        ],
      });
      // A row whose stacked end is not finite draws no point (dist/area.js:
      // 128-131): C has its point at Q alone. The area's points come by
      // series in first appearance (dist/area.js:49-155).
      expect(
        [for (final p in scene.points) '${p.group}${p.xValue}'],
        ['AQ', 'AP', 'XQ', 'XP', 'BQ', 'BP', 'CQ'],
      );
      // So every point is at a finite place, and no sort (the keys' x then
      // y, the group's and the tooltip's y) compares a NaN.
      for (final p in scene.points) {
        expect(p.x.isFinite && p.y.isFinite, isTrue, reason: p.key);
      }
      final [_, ap, _, xp, _, bp, _] = scene.points;
      expect(bp.y, lessThan(xp.y));
      expect(xp.y, lessThan(ap.y));
      final focus = scene.focusAt(Offset(ap.x, ap.y))!;
      expect([for (final p in scene.focusPoints(focus)) p], [ap, bp, xp]);
      final rows = scene.tooltipOf(focus)!.rows;
      expect([for (final r in rows.take(3)) r.label], ['B', 'X', 'A']);
    });

    testWidgets('Sparkline: the -1e308 value is drawn at the bottom of the '
        'plot, the 1e308 ones nowhere', (tester) async {
      final scene = await _sceneOf<SparklineScene>(tester, {
        'component': 'Sparkline',
        'label': 'MRR',
        'values': _sets['huge'],
      });
      final size = scene.size;
      expect(size.height, 44);
      // No guides: the plot is the box inside `margin: {top: 4, right: 4,
      // bottom: 2, left: 2}` (dist/scene.js:566-572), and y runs from its
      // bottom, 4 + (44 - 6) = 42, up to 4. y's domain is the values'
      // extent, -1e308..1e308 (dist/scale-input.js:82-113; no `nice`), so
      // -1e308 maps to (-1e308 - -1e308) / Infinity = 0, the range start:
      // 42 (dist/scales/linear.js:76-81). x's domain is 0..2: index 1 is
      // halfway across.
      final p1 = scene.positions[1];
      expect(p1.dy, 42);
      // The plot is at least 1px wide (`Math.max(1, …)`, dist/scene.js:
      // 567-572).
      expect(p1.dx, closeTo(2 + math.max(1, size.width - 6) / 2, 1e-9));
      // 1e308: Infinity / Infinity = NaN.
      expect(scene.positions[0].dy, isNaN);
      expect(scene.positions[2].dy, isNaN);
      // The area and the line start at the NaN point, an error in their
      // first command (SVG 2, Paths, "Error handling in path data"), and
      // the end dot is at NaN: nothing is drawn.
      expect(paintCalls(scene), isEmpty);
      expect(nonFiniteScene(scene), isEmpty);
      // The points: the area's (0-2), the line's (3-5), the end dot (6).
      // `nearest-x`'s navigation sorts them by x, then y (dist/focus.js:
      // 35-46): at one x, `0 || NaN - NaN` is NaN, which sorts as equal, so
      // each x keeps its points in scene order. The keys step over all of
      // them, the 1e308 ones too.
      expect(
        [for (final f in keyboardFoci(scene)) f.group],
        [0, 3, 1, 4, 2, 5, 6],
      );
      // On a 1e308 value: its tooltip shows its row; nothing is drawn (its
      // rings would be at NaN).
      const undrawn = PlotFocus(0);
      final tooltip = scene.tooltipOf(undrawn)!;
      expect(tooltip.rows, hasLength(1));
      expect(tooltip.rows.single.label, 'MRR');
      expect(paintCalls(scene, focus: undrawn), isEmpty);
      expect(scene.anchorOf(undrawn).dy, isNaN);
      // On the -1e308 value: its rings (the area's and the line's points of
      // its row) are drawn where it is.
      final rings = _circles(scene, const PlotFocus(1));
      expect(rings, hasLength(2));
      for (final ring in rings) {
        expect(ring[0], p1);
        expect(ring[1], 3.5);
      }
      expect(scene.anchorOf(const PlotFocus(1)), p1);
      // The pointer: `nearest-x` measures x alone (dist/focus.js:11-30), so
      // a pointer at the first value's x focuses it, its y NaN.
      final at0 = Offset(scene.positions[0].dx, 20);
      expect(scene.focusAt(at0), undrawn);
      // Its key finds it again.
      final key = scene.focusKeyOf(undrawn)!;
      expect(scene.focusOfKey(key), undrawn);
    });

    testWidgets('BarChart, horizontal: every x is NaN; Home, End and the '
        'arrows fall through to y, and the pointer finds a bar by its y', (
      tester,
    ) async {
      final scene = await _sceneOf<BarScene>(tester, {
        'component': 'BarChart',
        'horizontal': true,
        'data': _xy(_sets['huge']!),
      });
      // The value axis is x here: its tick at NaN makes the left and right
      // margins NaN (dist/scene.js:756-767), so every bar's x is NaN; the
      // band runs down y, finite.
      for (final point in scene.points) {
        expect(point.x, isNaN);
        expect(point.y.isFinite, isTrue);
      }
      expect(paintCalls(scene).where((c) => c.startsWith('draw')), isEmpty);
      // One series: no focus strategy, so the keys go in screen order,
      // `left.x - right.x || left.y - right.y || leftIndex - rightIndex`
      // (dist/interaction.js:119-121): NaN - NaN is NaN, falsy, so the
      // bands' y decide. Home is the top bar, End the bottom one
      // (`navigationExtreme`, :100-118), the arrows step down
      // (`chartPointFromSceneOrder`, :71-99).
      expect(scene.navigate(null, PlotNavigation.first), const PlotFocus(0));
      expect(scene.navigate(null, PlotNavigation.last), const PlotFocus(2));
      expect(
        scene.navigate(const PlotFocus(0), PlotNavigation.next),
        const PlotFocus(1),
      );
      expect(
        scene.navigate(const PlotFocus(2), PlotNavigation.previous),
        const PlotFocus(1),
      );
      expect(nonFiniteScene(scene), isEmpty);
      expect(scene.tooltipOf(const PlotFocus(1))!.title, 'X1');
      // The pointer: a bar's affinity is y (dist/bar.js barX), so its
      // distance is along y alone, from its box's finite top and height
      // (dist/nearest.js:39, :406-411), and the bar beside the pointer's y
      // is found though its x is NaN.
      expect(
        scene.focusAt(Offset(scene.size.width / 2, scene.points[1].y)),
        const PlotFocus(1),
      );
    });

    testWidgets('ScatterChart: the keys reach dots at y NaN; the pointer '
        'never does, as a NaN distance never wins', (tester) async {
      final scene = await _sceneOf<ScatterScene>(tester, {
        'component': 'ScatterChart',
        'data': [
          for (final (i, y) in _sets['huge']!.indexed) {'x': i * 2, 'y': y},
        ],
      });
      for (final point in scene.points) {
        expect(point.x.isFinite, isTrue);
        expect(point.y, isNaN);
      }
      // No focus strategy: screen order, x first (dist/interaction.js:
      // 100-121).
      expect(scene.navigate(null, PlotNavigation.first), const PlotFocus(0));
      expect(scene.navigate(null, PlotNavigation.last), const PlotFocus(2));
      expect(keyboardFoci(scene), hasLength(3));
      expect(nonFiniteScene(scene), isEmpty);
      expect(scene.tooltipOf(const PlotFocus(1)), isNotNull);
      // `nearestScenePoint` (dist/nearest.js:21-66): a dot's distance is
      // NaN (dy is NaN), and `NaN > d`, `NaN < d` and `NaN === d` are all
      // false, so no dot is ever the nearest: even at a dot's own x, no
      // focus.
      for (final point in scene.points) {
        expect(scene.focusAt(Offset(point.x, scene.size.height / 2)), isNull);
      }
    });

    testWidgets('BarChart: the pointer finds a bar at y NaN by its x', (
      tester,
    ) async {
      final scene = await _sceneOf<BarScene>(tester, {
        'component': 'BarChart',
        'data': _xy(_sets['huge']!),
      });
      expect(scene.points[1].y, isNaN);
      // One series, no strategy: `nearestScenePoint` measures a vertical
      // bar along x alone (affinity "x", dist/nearest.js:38-39 and 406-411):
      // its box's x and width are finite, so its distance is too.
      expect(scene.focusAt(Offset(scene.points[1].x, 10)), const PlotFocus(1));
      expect(nonFiniteScene(scene), isEmpty);
    });

    testWidgets('a stacked BarChart draws no bar for a row whose stack '
        'overflows a double, and the others as usual', (tester) async {
      final scene = await _sceneOf<BarScene>(tester, {
        'component': 'BarChart',
        'stacked': true,
        'data': [
          {'x': 'X0', 'y': 1e308, 'series': 'A'},
          {'x': 'X0', 'y': 1e308, 'series': 'B'},
          {'x': 'X1', 'y': 5, 'series': 'A'},
          {'x': 'X1', 'y': 7, 'series': 'B'},
        ],
      });
      // B at X0 runs from 1e308 to 1e308 + 1e308 = Infinity
      // (dist/stack-internal.js:75-108); dist/bar.js:113-114 makes no bar
      // and no point for a y2 that is not finite. The value channel keeps
      // the finite ends (dist/bar.js:81-88), 0..1e308, a finite span.
      expect([for (final p in scene.points) p.datum], [0, 2, 3]);
      for (final p in scene.points) {
        expect([p.x, p.y, p.focusX, p.focusY].every((v) => v.isFinite), isTrue);
      }
      expect(paintCalls(scene).where((c) => c == 'drawRRect'), hasLength(3));
      expect(nonFiniteScene(scene), isEmpty);
    });

    testWidgets('a stacked AreaChart ends the area of a series at a row '
        'whose stack overflows a double', (tester) async {
      final scene = await _sceneOf<LineAreaScene>(tester, {
        'component': 'AreaChart',
        'data': [
          {'x': 'X0', 'y': 1, 'series': 'A'},
          {'x': 'X0', 'y': 5, 'series': 'B'},
          {'x': 'X1', 'y': 1e308, 'series': 'A'},
          {'x': 'X1', 'y': 1e308, 'series': 'B'},
          {'x': 'X2', 'y': 1, 'series': 'A'},
          {'x': 'X2', 'y': 5, 'series': 'B'},
        ],
      });
      // B at X1 runs from 1e308 to Infinity: dist/area.js:128-131 flushes
      // B's segment there and draws no point, so B has two areas (X0, X2)
      // and A one. Points by series, rows in data order (dist/area.js:
      // 49-55, :77).
      expect([for (final p in scene.points) p.datum], [0, 2, 4, 1, 5]);
      scene.paint(TestRecordingCanvas(), null);
      expect(scene.marks.where((m) => m.kind == 'area'), hasLength(3));
      expect(nonFiniteScene(scene), isEmpty);
    });
  });
}

void _everyChartTests() {
  group('every playground chart with ±1e308 and Number.MAX_VALUE (RR2-1)', () {
    for (final MapEntry(key: name, value: props) in _charts.entries) {
      // An anchor may be NaN where TanStack's is (RULEBOOK section 6 item
      // 3); the tooltip's laid-out box is checked in
      // chart_running_review_test.dart.
      testWidgets('$name: no number that is not finite reaches a Canvas '
          'call, with no focus or any the keys reach, and the pointer and '
          'keys raise nothing', (tester) async {
        final problems = <String>[];
        for (final MapEntry(key: set, value: ys) in _sets.entries) {
          await _pump(tester, props(ys));
          if (tester.takeException() case final e?) {
            problems.add('$set, pump: $e');
          }
          final scenes = _scenes(tester);
          if (scenes.isEmpty) problems.add('$set: no chart');
          for (final scene in scenes) {
            for (final problem in nonFiniteScene(scene)) {
              problems.add('$set, ${scene.runtimeType}, $problem');
            }
          }
          for (final problem in await _interact(tester)) {
            problems.add('$set, $problem');
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          if (tester.takeException() case final e?) {
            problems.add('$set, unmount: $e');
          }
        }
        expect(problems, isEmpty);
      });
    }
  });
}

void _keyTests() {
  group('a TanStack focus is kept by the key of its point (RR2-6)', () {
    test('a mark keys its points by x when x is unique in its series, else '
        'by the next candidate, else by index', () {
      // dist/mark.js:87-115, :132-143: unique within each group.
      expect(
        tanstackInferredKeys(
          ['a', 'a', 'b'],
          [
            ['P0', 'P1', 'P0'],
          ],
        ),
        ['P0', 'P1', 'P0'],
      );
      expect(
        tanstackInferredKeys(
          ['a', 'a'],
          [
            ['P0', 'P0'],
          ],
        ),
        [0, 1],
      );
      // dist/dot.js:43: x, then y, then the pair.
      expect(
        tanstackInferredKeys(
          [null, null],
          [
            [1.0, 1.0],
            [2.0, 3.0],
          ],
        ),
        [2.0, 3.0],
      );
      // dist/mark.js:116-124: JSON.stringify of the value keys.
      expect(
        tanstackCompositeKeys([
          [1.0, 2.5],
          [3.0, 'a'],
        ]),
        ['["number:1","number:3"]', '["number:2.5","string:1:a"]'],
      );
      // dist/bar.js:150, dist/scales.js:143-147.
      expect(
        tanstackPointKey('bar-y-0', 'Sales', 'B'),
        'bar-y-0:string:5:Sales:string:1:B',
      );
      expect(
        tanstackPointKey('area-y-0', null, 2),
        'area-y-0:object:null:number:2',
      );
    });

    test('of two points with one key, a focus goes back to the one with its '
        'values, else to its row, else to the first', () {
      TanstackPoint slice(int datum, double angle) => TanstackPoint(
        key: 'polar-0:arc-0:object:null:string:1:A',
        markId: 'polar-0:arc-0',
        group: null,
        datum: datum,
        x: 10,
        y: 10,
        xValue: angle,
        yValue: 50.0,
        color: const Color(0xff000000),
      );
      final points = [slice(0, 1), slice(1, 2)];
      // dist/interaction.js:42-43: the mark, the group and both values.
      expect(
        tanstackRestoreFocusPoint(points, TanstackFocusKey.of(slice(5, 2))),
        same(points[1]),
      );
      // :44-45: else the mark and the row.
      expect(
        tanstackRestoreFocusPoint(points, TanstackFocusKey.of(slice(1, 9))),
        same(points[1]),
      );
      // :46: else the first.
      expect(
        tanstackRestoreFocusPoint(points, TanstackFocusKey.of(slice(7, 9))),
        same(points[0]),
      );
      expect(
        tanstackRestoreFocusPoint(
          points,
          const TanstackFocusKey(key: 'other', markId: 'm', datum: 0),
        ),
        isNull,
      );
      // A pin is the key alone (dist/renderer.js:609, :647).
      expect(TanstackFocusKey.of(slice(0, 1)), TanstackFocusKey.of(points[1]));
      // :36-41: first, while the rows are the same objects, the point drawn
      // for the focus' own row, whatever the values say.
      final twins = [slice(0, 1), slice(1, 1)];
      expect(
        tanstackRestoreFocusPoint(twins, TanstackFocusKey.of(twins[1])),
        same(twins[0]),
      );
      expect(
        tanstackRestoreFocusPoint(
          twins,
          TanstackFocusKey.of(twins[1]),
          sameRows: true,
        ),
        same(twins[1]),
      );
    });

    testWidgets('BarChart: a focus on B stays on B when a row is put first, '
        'and goes when B goes', (tester) async {
      const a = {'x': 'A', 'y': 3};
      const b = {'x': 'B', 'y': 5};
      const c = {'x': 'C', 'y': 4};
      final before = await _sceneOf<BarScene>(tester, {
        'component': 'BarChart',
        'data': [a, b, c],
      });
      const focus = PlotFocus(1);
      expect(before.tooltipOf(focus)!.title, 'B');
      final key = before.focusKeyOf(focus)!;
      // A bar's key is its category (dist/bar.js:69-74, :150).
      final after = await _sceneOf<BarScene>(tester, {
        'component': 'BarChart',
        'data': [
          {'x': 'Z', 'y': 2},
          a,
          b,
          c,
        ],
      });
      final kept = after.focusOfKey(key)!;
      expect(kept, const PlotFocus(2));
      expect(after.tooltipOf(kept)!.title, 'B');
      expect(after.focusKeyOf(kept), key);
      final gone = await _sceneOf<BarScene>(tester, {
        'component': 'BarChart',
        'data': [a, c],
      });
      expect(gone.focusOfKey(key), isNull);
    });

    testWidgets('LineChart: a focus on P1 stays on P1 when a row is put '
        'first, and goes when P1 goes', (tester) async {
      const p0 = {'x': 'P0', 'y': 3};
      const p1 = {'x': 'P1', 'y': 7};
      const p2 = {'x': 'P2', 'y': 4};
      final before = await _sceneOf<LineAreaScene>(tester, {
        'component': 'LineChart',
        'data': [p0, p1, p2],
      });
      // One series that never goes below 0: the fade (area-y-0), then the
      // line (line-1).
      final focus = before.focusOn(
        before.points.firstWhere(
          (p) => p.markId == 'line-1' && p.xValue == 'P1',
        ),
      )!;
      final key = before.focusKeyOf(focus)!;
      final after = await _sceneOf<LineAreaScene>(tester, {
        'component': 'LineChart',
        'data': [
          {'x': 'Z', 'y': 1},
          p0,
          p1,
          p2,
        ],
      });
      final kept = after.focusOfKey(key)!;
      final point = after.primaryOf(kept)!;
      expect(point.markId, 'line-1');
      expect(point.xValue, 'P1');
      expect(point.datum, 2);
      expect(after.tooltipOf(kept)!.title, 'P1');
      final gone = await _sceneOf<LineAreaScene>(tester, {
        'component': 'LineChart',
        'data': [p0, p2],
      });
      expect(gone.focusOfKey(key), isNull);
    });

    testWidgets('LineChart: with an x repeated in its series, the keys are '
        'the indexes, and a focus stays at its index', (tester) async {
      // dist/mark.js:102-114: x is not unique in the series, so the keys
      // fall back to the indexes; a row put first moves every row on.
      final before = await _sceneOf<LineAreaScene>(tester, {
        'component': 'LineChart',
        'data': [
          {'x': 'P0', 'y': 3},
          {'x': 'P0', 'y': 4},
          {'x': 'P1', 'y': 5},
        ],
      });
      final focus = before.focusOn(
        before.points.firstWhere((p) => p.markId == 'line-1' && p.datum == 1),
      )!;
      final key = before.focusKeyOf(focus)!;
      final after = await _sceneOf<LineAreaScene>(tester, {
        'component': 'LineChart',
        'data': [
          {'x': 'Z', 'y': 1},
          {'x': 'P0', 'y': 3},
          {'x': 'P0', 'y': 4},
          {'x': 'P1', 'y': 5},
        ],
      });
      final point = after.primaryOf(after.focusOfKey(key)!)!;
      expect(point.datum, 1);
      expect(point.yValue, 3);
    });

    testWidgets('AreaChart, stacked: a focus on B at X1 stays there when a '
        'row is put first, and goes when it goes', (tester) async {
      const rows = [
        {'x': 'X0', 'y': 1, 'series': 'A'},
        {'x': 'X0', 'y': 2, 'series': 'B'},
        {'x': 'X1', 'y': 3, 'series': 'A'},
        {'x': 'X1', 'y': 4, 'series': 'B'},
      ];
      final before = await _sceneOf<LineAreaScene>(tester, {
        'component': 'AreaChart',
        'data': rows,
      });
      final focus = before.focusOn(
        before.points.firstWhere((p) => p.group == 'B' && p.xValue == 'X1'),
      )!;
      final key = before.focusKeyOf(focus)!;
      final after = await _sceneOf<LineAreaScene>(tester, {
        'component': 'AreaChart',
        'data': [
          {'x': 'X9', 'y': 1, 'series': 'A'},
          ...rows,
        ],
      });
      final point = after.primaryOf(after.focusOfKey(key)!)!;
      expect(point.group, 'B');
      expect(point.xValue, 'X1');
      expect(point.datum, 4);
      final gone = await _sceneOf<LineAreaScene>(tester, {
        'component': 'AreaChart',
        'data': rows.sublist(0, 3),
      });
      expect(gone.focusOfKey(key), isNull);
    });

    testWidgets('ScatterChart: a focus on x 2 stays there when a row is put '
        'first, and goes when it goes', (tester) async {
      const rows = [
        {'x': 1, 'y': 3},
        {'x': 2, 'y': 5},
        {'x': 4, 'y': 4},
      ];
      final before = await _sceneOf<ScatterScene>(tester, {
        'component': 'ScatterChart',
        'data': rows,
      });
      // A dot's key is its x while x is unique (dist/dot.js:41-46, :71).
      final key = before.focusKeyOf(const PlotFocus(1))!;
      final after = await _sceneOf<ScatterScene>(tester, {
        'component': 'ScatterChart',
        'data': [
          {'x': 0, 'y': 1},
          ...rows,
        ],
      });
      final point = after.primaryOf(after.focusOfKey(key)!)!;
      expect(point.xValue, 2.0);
      expect(point.datum, 2);
      final gone = await _sceneOf<ScatterScene>(tester, {
        'component': 'ScatterChart',
        'data': [rows[0], rows[2]],
      });
      expect(gone.focusOfKey(key), isNull);
    });

    testWidgets('PieChart: a focus on L1 stays on L1 when a slice is put '
        'first, and goes when L1 goes', (tester) async {
      const rows = [
        {'label': 'L0', 'value': 3},
        {'label': 'L1', 'value': 5},
        {'label': 'L2', 'value': 4},
      ];
      final before = await _sceneOf<PieScene>(tester, {
        'component': 'PieChart',
        'data': rows,
      });
      // charts.tsx: `radialArc(slices, {key: "label"})`.
      final key = before.focusKeyOf(const PlotFocus(1))!;
      final after = await _sceneOf<PieScene>(tester, {
        'component': 'PieChart',
        'data': [
          {'label': 'L9', 'value': 1},
          ...rows,
        ],
      });
      final kept = after.focusOfKey(key)!;
      expect(kept, const PlotFocus(2));
      expect(after.tooltipOf(kept)!.title, 'L1');
      final gone = await _sceneOf<PieScene>(tester, {
        'component': 'PieChart',
        'data': [rows[0], rows[2]],
      });
      expect(gone.focusOfKey(key), isNull);
    });

    testWidgets('Sparkline: the keys are the indexes, so a focus stays at '
        'its index when a value is put first, and goes when the index '
        'goes', (tester) async {
      final before = await _sceneOf<SparklineScene>(tester, {
        'component': 'Sparkline',
        'label': 'MRR',
        'values': [3, 7, 4],
      });
      // The rows are `{i, v}` and every mark's x is `i` (charts.tsx), so
      // a point's key is its index (dist/mark.js:87-115).
      final key = before.focusKeyOf(const PlotFocus(1))!;
      final last = before.focusKeyOf(const PlotFocus(2))!;
      final after = await _sceneOf<SparklineScene>(tester, {
        'component': 'Sparkline',
        'label': 'MRR',
        'values': [9, 3, 7, 4],
      });
      final point = after.primaryOf(after.focusOfKey(key)!)!;
      expect(point.datum, 1);
      expect(point.yValue, 3);
      final shorter = await _sceneOf<SparklineScene>(tester, {
        'component': 'Sparkline',
        'label': 'MRR',
        'values': [3, 7],
      });
      expect(shorter.focusOfKey(last), isNull);
    });
  });
}
