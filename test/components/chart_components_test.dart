// Widget tests of the charts: the playground's LineChart, AreaChart,
// BarChart, PieChart, ScatterChart and Sparkline (after charts.tsx and
// chart-kit.tsx) and the standard Chart (after Chart.tsx).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/playground/charts/cartesian.dart';
import 'package:a2ui_kit/src/components/playground/charts/chart_kit.dart';
import 'package:a2ui_kit/src/components/playground/charts/pie_sparkline.dart';
import 'package:a2ui_kit/src/components/standard/data/chart.dart';
import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_guides.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderClipRect, RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../goldens/chart_samples.dart';
import '../helpers/harness.dart';
import '../helpers/paint_calls.dart';
import '../helpers/parity.dart' show tableOf, tableRows;

final _light = A2uiKitTheme.playground(Brightness.light);
final _dark = A2uiKitTheme.playground(Brightness.dark);

/// The scenes the charts painted, in order.
List<PlotScene> _scenes(WidgetTester tester) => [
  for (final paint in tester.widgetList<CustomPaint>(find.byType(CustomPaint)))
    if (paint.painter case final ChartScenePainter painter) painter.scene,
];

T _scene<T>(WidgetTester tester) => _scenes(tester).whereType<T>().first;

Map<String, Object?> _root(Map<String, Object?> props) => {
  'id': 'root',
  ...props,
};

List<Map<String, Object?>> _rows(
  String series,
  List<num> ys, [
  List<Object>? xs,
]) => [
  for (var i = 0; i < ys.length; i++)
    {'x': xs?[i] ?? 'P${i + 1}', 'y': ys[i], 'series': series},
];

/// Hovers the mouse at [at] (global) and pumps.
Future<TestGesture> _hover(WidgetTester tester, Offset at) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(at);
  await tester.pump();
  return gesture;
}

/// The global position of [local] in the first chart drawing.
Offset _inPlot(WidgetTester tester, Offset local) =>
    tester.getTopLeft(find.byType(ChartPlot).first) + local;

void main() {
  group('LineChart', () {
    testWidgets('frame, legend, ticks, the 220px default and no dots past 16 '
        'rows', (tester) async {
      await pumpComponents(tester, theme: _light, chartSamples['line_chart']!);
      await tester.pumpAndSettle();
      expect(find.text('Weekly active users'), findsOneWidget);
      expect(find.text('Web vs mobile, last 12 months'), findsOneWidget);
      expect(find.text('Web'), findsOneWidget);
      expect(find.text('Mobile'), findsOneWidget);
      expect(tester.getSize(find.byType(ChartPlot)).height, 220);
      final scene = _scene<LineAreaScene>(tester);
      expect(
        [for (final t in scene.leftTicks) t.label],
        ['5K', '10K', '15K', '20K', '25K', '30K', '35K', '40K'],
      );
      expect(scene.bottomTicks.first.label, 'Jan');
      expect(scene.marks.where((m) => m.kind == 'point'), isEmpty);
      expect(scene.marks.where((m) => m.kind == 'line'), hasLength(2));
      // The series take the palette in order.
      expect(
        [for (final m in scene.marks.where((m) => m.kind == 'line')) m.color],
        [_light.playground.chart[0], _light.playground.chart[1]],
      );
    });

    testWidgets('one series at or above 0: a fade, dots, the title as the '
        "tooltip's name", (tester) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'LineChart',
          'title': 'Signups',
          'height': 180,
          'data': _rows('', [3, 7, 5]),
        }),
      ]);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ChartPlot)).height, 180);
      final scene = _scene<LineAreaScene>(tester);
      expect(scene.marks.where((m) => m.kind == 'area'), hasLength(1));
      expect(scene.marks.where((m) => m.kind == 'point'), hasLength(3));
      // No legend for one series.
      expect(find.byType(ChartLegend), findsNothing);
      // The domain takes in 0 for the fade.
      expect(scene.leftTicks.first.label, '0');
      final point = scene.marks.firstWhere((m) => m.kind == 'point');
      await _hover(tester, _inPlot(tester, point.rect.center));
      expect(find.byType(PlaygroundChartTooltip), findsOneWidget);
      expect(find.text('P1'), findsWidgets);
      expect(find.text('Signups'), findsWidgets);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('negative values: no fade; highlight greys the others', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'LineChart',
          'highlight': 'B',
          'curve': false,
          'data': [
            ..._rows('A', [-3, 2]),
            ..._rows('B', [1, 4]),
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      final scene = _scene<LineAreaScene>(tester);
      expect(scene.marks.where((m) => m.kind == 'area'), isEmpty);
      expect(scene.curve, isFalse);
      final colors = {
        for (final m in scene.marks.where((m) => m.kind == 'line'))
          m.series: m.color,
      };
      expect(colors['B'], _light.playground.chart[0]);
      expect(colors['A'], _light.playground.charts.mute[0]);
      expect(double.parse(scene.leftTicks.first.label), lessThan(0));
    });

    testWidgets('numeric x: a nice linear scale; NaN rows are dropped', (
      tester,
    ) async {
      // Bound rows the schema refuses (a missing key, a string `y`, no
      // object) show the invalid-props alert instead, as CopilotKit's
      // render check does (RULEBOOK section 0; surface_components_test.
      // dart). A NaN `y` passes the schema's `number`, which an app's own
      // data write can hold.
      await pumpComponents(
        tester,
        theme: _light,
        [
          _root({
            'component': 'LineChart',
            'data': {'@path': '/rows'},
          }),
        ],
        data: {
          'rows': [
            {'x': 0, 'y': 1},
            {'x': 10, 'y': 2},
            {'x': 25, 'y': double.nan},
            {'x': 40, 'y': 3},
          ],
        },
      );
      await tester.pumpAndSettle();
      final scene = _scene<LineAreaScene>(tester);
      expect(scene.marks.where((m) => m.kind == 'point'), hasLength(3));
      // A 360px card leaves a plot under 276px: 2 x ticks (one per 92px,
      // at least 2), dist/scene.js:1151.
      expect(scene.plot.width, lessThan(276));
      expect([for (final t in scene.bottomTicks) t.label], ['0', '20', '40']);
    });

    testWidgets('no rows says "No data yet"; one point draws', (tester) async {
      final surfaces = await pumpComponents(tester, theme: _light, [
        _root({'component': 'LineChart', 'title': 'T', 'data': <Object>[]}),
      ]);
      await tester.pump();
      expect(find.text('No data yet'), findsOneWidget);
      expect(find.byType(ChartPlot), findsNothing);
      surfaces.apply([
        {
          'version': '1.0',
          'updateComponents': {
            'surfaceId': testSurfaceId,
            'components': [
              _root({
                'component': 'LineChart',
                'data': [
                  {'x': 'only', 'y': 5},
                ],
              }),
            ],
          },
        },
      ]);
      await tester.pumpAndSettle();
      expect(find.text('No data yet'), findsNothing);
      final point = _scene<LineAreaScene>(
        tester,
      ).marks.singleWhere((m) => m.kind == 'point');
      // A lone category sits in the middle.
      expect(
        point.rect.center.dx,
        closeTo(_scene<LineAreaScene>(tester).plot.center.dx, 1e-9),
      );
    });

    testWidgets('the keyboard: focus-in on the first x, the arrows, Home and '
        'End; Enter pins and Escape unpins (renderer.js:619-692)', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _light, chartSamples['line_chart']!);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // Taking the focus focuses the first point at once.
      expect(find.byType(PlaygroundChartTooltip), findsOneWidget);
      expect(find.text('Jan'), findsWidgets);
      expect(find.text('18.2K'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('19.4K'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(find.text('Dec'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(find.text('18.2K'), findsOneWidget);
      // Escape only dismisses a pinned tooltip.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(PlaygroundChartTooltip), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(PlaygroundChartTooltip), findsNothing);
    });

    testWidgets('screen readers get the name and a table of the data', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponents(tester, theme: _light, chartSamples['line_chart']!);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Weekly active users'), findsWidgets);
      expect(
        find.bySemanticsLabel('x: Jan, Web: 18.2K, Mobile: 9.8K'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('the grow-in', () {
    testWidgets('wipes in over 700ms from the left', (tester) async {
      await pumpComponents(tester, theme: _light, chartSamples['line_chart']!);
      await tester.pump(const Duration(milliseconds: 100));
      final clip = find.descendant(
        of: find.byType(ChartReveal),
        matching: find.byType(ClipRect),
      );
      expect(clip, findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(ChartReveal),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, inExclusiveRange(.4, 1));
      final drawing = find.descendant(
        of: find.byType(ChartReveal),
        matching: find.byType(CustomPaint),
      );
      final painting = tester.element(drawing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.renderObject<RenderClipRect>(clip).clipBehavior,
        isNot(Clip.none),
      );
      // 700ms from the first frame the drawing showed in: the clip and the
      // opacity stay, inert (RULEBOOK section 2, one tree shape), so the
      // drawing is not mounted again.
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.renderObject<RenderClipRect>(clip).clipBehavior, Clip.none);
      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: find.byType(ChartReveal),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        1,
      );
      expect(tester.element(drawing), same(painting));
    });

    testWidgets('is still under reduced motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpComponents(tester, theme: _light, chartSamples['bar_chart']!);
      // The clip is there, inert: nothing is clipped or faded.
      expect(
        tester
            .renderObject<RenderClipRect>(
              find.descendant(
                of: find.byType(ChartReveal),
                matching: find.byType(ClipRect),
              ),
            )
            .clipBehavior,
        Clip.none,
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('AreaChart', () {
    testWidgets('stacks more series, with a Total in the tooltip', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _light, chartSamples['area_chart']!);
      await tester.pumpAndSettle();
      final scene = _scene<LineAreaScene>(tester);
      expect(scene.kind, LineAreaKind.stackedArea);
      expect(scene.marks.where((m) => m.kind == 'area'), hasLength(3));
      // The stack's top: 14,100 + 9,800 + 2,080 = 25,980, so 30K.
      expect(scene.leftTicks.last.label, r'$30K');
      final tooltip = scene.tooltipOf(const PlotFocus(0))!;
      // Rows top to bottom on the screen (tooltip-model.js:2-16): the top
      // band first.
      expect(
        [for (final r in tooltip.rows) r.label],
        ['Embeddings', 'Agents', 'Chat', 'Total'],
      );
      expect(tooltip.rows.last.value, r'$7,200');
      expect(tooltip.rows.last.active, isTrue);
    });

    testWidgets('stacked: false draws fades and lines', (tester) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'AreaChart',
          'stacked': false,
          'data': [
            ..._rows('A', [1, 2]),
            ..._rows('B', [2, 1]),
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      final scene = _scene<LineAreaScene>(tester);
      expect(scene.kind, LineAreaKind.area);
      expect(scene.marks.where((m) => m.kind == 'line'), hasLength(2));
      expect(scene.tooltipOf(const PlotFocus(0))!.rows, hasLength(2));
    });
  });

  group('BarChart', () {
    testWidgets('grouped bars at most 18px; 230px tall', (tester) async {
      await pumpComponents(
        tester,
        theme: _light,
        width: 720,
        chartSamples['bar_chart']!,
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ChartPlot)).height, 230);
      final scene = _scene<BarScene>(tester);
      final bars = scene.marks.where((m) => m.kind == 'bar').toList();
      expect(bars, hasLength(8));
      for (final bar in bars) {
        expect(bar.rect.width, lessThanOrEqualTo(18));
      }
      expect(
        [for (final t in scene.bottomTicks) t.label],
        ['NA', 'EMEA', 'APAC', 'LATAM'],
      );
      final tooltip = scene.tooltipOf(const PlotFocus(0))!;
      expect(tooltip.title, 'NA');
      // The taller bar's row first (screen order).
      expect(
        [for (final r in tooltip.rows) r.value],
        [r'$538,000', r'$412,000'],
      );
    });

    testWidgets('stacked: one 40px column per category from 0', (tester) async {
      await pumpComponents(tester, theme: _light, width: 720, [
        _root({
          'component': 'BarChart',
          'stacked': true,
          'data': [
            ..._rows('A', [1, 2]),
            ..._rows('B', [3, 1]),
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      final bars = _scene<BarScene>(tester).marks.toList();
      expect(bars, hasLength(4));
      // The bars in data order; A's and B's bars of the first category
      // share a column, B on A.
      expect([for (final b in bars) b.series], ['A', 'A', 'B', 'B']);
      expect(bars[0].rect.left, bars[2].rect.left);
      expect(bars[2].rect.bottom, closeTo(bars[0].rect.top, 1e-9));
      expect(bars[0].rect.width, lessThanOrEqualTo(40));
      // The stack starts at 0, the axis' bottom.
      expect(
        bars[0].rect.bottom,
        closeTo(_scene<BarScene>(tester).plot.bottom, 1e-9),
      );
    });

    testWidgets('horizontal: categories down the left, cut at 18', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'BarChart',
          'horizontal': true,
          'data': [
            {'x': 'A category name that is long', 'y': 3},
            {'x': 'B', 'y': -2},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      // max(160, 2 × 30 + 40).
      expect(tester.getSize(find.byType(ChartPlot)).height, 160);
      final scene = _scene<BarScene>(tester);
      expect(scene.leftTicks.first.label, 'A category name t…');
      final bars = scene.marks.toList();
      expect(bars[0].rect.height, lessThanOrEqualTo(22));
      // The negative bar runs left of the positive one's start.
      expect(bars[1].rect.right, closeTo(bars[0].rect.left, 1e-9));
    });

    testWidgets('a long vertical label is cut at 12', (tester) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'BarChart',
          'data': [
            {'x': 'North America', 'y': 3},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      expect(_scene<BarScene>(tester).bottomTicks.single.label, 'North Ameri…');
    });
  });

  group('PieChart', () {
    testWidgets("a donut: the total and centerLabel; the list's values and "
        'shares', (tester) async {
      await pumpComponents(
        tester,
        theme: _light,
        width: 520,
        chartSamples['pie_chart']!,
      );
      await tester.pumpAndSettle();
      expect(find.text('105K'), findsOneWidget);
      expect(find.text('sessions'), findsOneWidget);
      expect(find.text('48.2K'), findsOneWidget);
      expect(find.text('46%'), findsOneWidget);
      expect(find.text('5.0%'), findsOneWidget);
      final scene = _scene<PieScene>(tester);
      expect(scene.slicePaths, hasLength(5));
      expect(scene.innerRadius, closeTo(scene.outerRadius * .64, 1e-9));
      expect(scene.outerRadius, 200 / 2 - 6);
      final tooltip = scene.tooltipOf(const PlotFocus(4))!;
      expect(tooltip.title, 'Email');
      expect([for (final r in tooltip.rows) r.value], ['5.3K', '5.0%']);
    });

    // RC3-1 (RULEBOOK section 2, stacking order): TanStack's tooltip is
    // `position: absolute; z-index: 1` in the chart's container
    // (@tanstack/charts 1.1.0 dist/tooltip.js:312-326, appended at
    // :106-113); the donut's centre is a later `z-index: auto` sibling
    // (charts.tsx:597-627). A positive z-index paints after every
    // `z-index: auto` box of its stacking context (CSS 2.1 Appendix E,
    // steps 8 and 9), so the card covers the total. A port that paints the
    // centre after the plot draws the total over the card.
    testWidgets("a donut's total paints under TanStack's tooltip", (
      tester,
    ) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'PieChart',
          'data': [
            {'label': 'A', 'value': 3},
            {'label': 'B', 'value': 1},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      final total = find.text('4');
      final tip = find.byType(PlaygroundChartTooltip);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      // The slice whose card covers the total (the keys reach both).
      for (var i = 0; i < 2; i++) {
        if (tester.getRect(tip).overlaps(tester.getRect(total))) break;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      final totalBox = tester.getRect(total);
      expect(tester.getRect(tip).overlaps(totalBox), isTrue);
      final frame = find.byType(PlaygroundChartFrame);
      final origin = tester.getTopLeft(frame);
      final card = tester.getRect(
        find.descendant(of: tip, matching: find.byType(Container)).first,
      );
      expect(
        tester.renderObject(frame),
        paints
          // The total's paragraph,
          ..something(
            (method, args) =>
                method == #drawParagraph &&
                ((args[0] as ui.Paragraph).longestLine - totalBox.width).abs() <
                    .5 &&
                ((args[1] as Offset).dy - (totalBox.top - origin.dy)).abs() <
                    .5,
          )
          // then the card's fill over it.
          ..something(
            paintedRRect(
              rrect: RRect.fromRectAndRadius(
                card.shift(-origin),
                const Radius.circular(10),
              ),
              color: _light.playground.charts.tooltipBackground,
            ),
          ),
      );
    });

    // RC3-9 (RULEBOOK section 2, text layout): the total's `<div>` sets no
    // `overflow-wrap` (charts.tsx:609-624), so the number, which has no
    // break opportunity (UAX #14 LB25), stays on one line; the grid item is
    // as wide as it (`fit-content`) and overflows both sides, centred. A
    // port that keeps the box's 200px breaks it into lines of digits.
    testWidgets("a donut's total longer than the box keeps one line, "
        'centred, overflowing both sides', (tester) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'PieChart',
          'data': [
            {'label': 'a', 'value': 1e308},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final totalFinder = find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.style?.fontSize == 20 &&
            w.text.toPlainText().length > 100,
      );
      final paragraph = tester.renderObject<RenderParagraph>(totalFinder);
      final text = paragraph.text.toPlainText();
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      );
      expect(boxes, isNotEmpty);
      expect(boxes.map((b) => b.top).toSet(), hasLength(1));
      final plot = tester.getRect(find.byType(ChartPlot));
      final box = tester.getRect(totalFinder);
      expect(box.left, lessThan(plot.left));
      expect(box.right, greaterThan(plot.right));
      expect(box.center.dx, closeTo(plot.center.dx, .5));
      // "Total" stays under it, centred.
      expect(
        tester.getRect(find.text('Total')).center.dx,
        closeTo(plot.center.dx, .5),
      );
      expect(tester.getRect(find.text('Total')).top, box.bottom);
    });

    testWidgets('a pie has no hole and no total', (tester) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'PieChart',
          'donut': false,
          'data': [
            {'label': 'A', 'value': 1},
            {'label': 'B', 'value': 3},
            {'label': 'bad', 'value': -1},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsNothing);
      final scene = _scene<PieScene>(tester);
      expect(scene.innerRadius, 0);
      expect(scene.slicePaths, hasLength(2));
    });

    testWidgets('a total of 0 says "No data yet"', (tester) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'PieChart',
          'data': [
            {'label': 'A', 'value': 0},
          ],
        }),
      ]);
      await tester.pump();
      expect(find.text('No data yet'), findsOneWidget);
    });
  });

  group('ScatterChart', () {
    testWidgets('dots sized by size, a legend by series, x and y in the '
        'tooltip', (tester) async {
      await pumpComponents(
        tester,
        theme: _light,
        width: 520,
        chartSamples['scatter_chart']!,
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ChartPlot)).height, 260);
      expect(find.text('us-east'), findsOneWidget);
      final scene = _scene<ScatterScene>(tester);
      final dots = scene.marks.toList();
      expect(dots, hasLength(11));
      // The largest size (14) is 3.5 + 11.
      expect(dots[7].rect.width / 2, closeTo(14.5, 1e-9));
      final tooltip = scene.tooltipOf(const PlotFocus(2))!;
      expect(tooltip.title, 'checkout');
      expect(
        [for (final r in tooltip.rows) (r.label, r.value)],
        [('Requests / s', '610'), ('p95 latency', '168 ms'), ('Size', '8')],
      );
    });

    testWidgets('without size every dot is 5px', (tester) async {
      // A row the schema refuses (a string `x`) shows the invalid-props
      // alert instead (RULEBOOK section 0); a negative `size` passes it.
      await pumpComponents(
        tester,
        theme: _light,
        [
          _root({
            'component': 'ScatterChart',
            'data': {'@path': '/points'},
          }),
        ],
        data: {
          'points': [
            {'x': 1, 'y': 2},
            {'x': 3, 'y': 4, 'size': -1},
          ],
        },
      );
      await tester.pumpAndSettle();
      final dots = _scene<ScatterScene>(tester).marks.toList();
      expect(dots, hasLength(2));
      for (final dot in dots) {
        expect(dot.rect.width, 10);
      }
    });
  });

  group('Sparkline', () {
    testWidgets('label, value, delta pill and a positive line', (tester) async {
      await pumpComponents(tester, theme: _light, chartSamples['sparkline']!);
      await tester.pumpAndSettle();
      expect(find.text('Monthly recurring revenue'), findsOneWidget);
      expect(find.text(r'$184.2K'), findsOneWidget);
      expect(find.text('+12.4%'), findsOneWidget);
      expect(tester.getSize(find.byType(ChartPlot)).height, 44);
      final scene = _scene<SparklineScene>(tester);
      expect(scene.stroke, _light.playground.toneColor(A2uiTone.positive));
      expect(scene.positions, hasLength(14));
    });

    testWidgets('the tone from the first and last values; the compact last '
        'value', (tester) async {
      await pumpComponents(tester, theme: _dark, brightness: Brightness.dark, [
        _root({
          'component': 'Sparkline',
          'values': [5000, 1200],
        }),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('1.2K'), findsOneWidget);
      expect(
        _scene<SparklineScene>(tester).stroke,
        _dark.playground.toneColor(A2uiTone.negative),
      );
    });

    testWidgets('fewer than two values: a pulsing bar', (tester) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'Sparkline',
          'label': 'L',
          'values': [3],
        }),
      ]);
      await tester.pump();
      expect(find.byType(ChartPlot), findsNothing);
      expect(find.byType(ChartShimmer), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('TanStack Charts 1.1.0 (review 2a)', () {
    Map<String, Object?> line(List<Map<String, Object?>> data) =>
        _root({'component': 'LineChart', 'data': data});

    testWidgets('F1, F2: a numeric x is written by the scale and gets one '
        'tick per 92px', (tester) async {
      await pumpComponents(tester, theme: _light, width: 480, [
        line([
          for (final year in [2019, 2020, 2021, 2022]) {'x': year, 'y': 3},
        ]),
      ]);
      await tester.pumpAndSettle();
      final scene = _scene<LineAreaScene>(tester);
      // A plot of 368 to 460px: 4 ticks, a step of 1, no decimals.
      expect(scene.plot.width, inInclusiveRange(368, 460));
      expect(
        [for (final t in scene.bottomTicks) t.label],
        ['2019', '2020', '2021', '2022'],
      );
    });

    testWidgets('F3: tick labels at 68% of the muted colour, 10px under a '
        '360px chart, 11px from 360px', (tester) async {
      await pumpComponents(tester, theme: _light, width: 320, [
        line(_rows('A', [1, 2])),
      ]);
      await tester.pumpAndSettle();
      final narrow = _scene<LineAreaScene>(tester).layout;
      expect(narrow.xLabels.first.fontSize, 10);
      final muted = _light.playground.charts.muted;
      expect(narrow.yLabels.first.color.a, closeTo(muted.a * .68, 1e-9));
      await pumpComponents(tester, theme: _light, width: 720, [
        line(_rows('A', [1, 2])),
      ]);
      await tester.pumpAndSettle();
      expect(_scene<LineAreaScene>(tester).layout.xLabels.first.fontSize, 11);
    });

    testWidgets('F4: the grid rules are 11% of the grid colour', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _light, [
        line(_rows('A', [1, 2])),
      ]);
      await tester.pumpAndSettle();
      final grid = _light.playground.charts.grid;
      expect(
        tester.renderObject(
          find.descendant(
            of: find.byType(ChartPlot),
            matching: find.byType(CustomPaint),
          ),
        ),
        paints..line(color: grid.withValues(alpha: grid.a * .11)),
      );
    });

    testWidgets('F5, F8, N4: one ring on the focused series, then the '
        'crosshair in the text colour at 35%', (tester) async {
      await pumpComponents(tester, theme: _light, width: 520, [
        line([
          ..._rows('A', [10, 10]),
          ..._rows('B', [30, 30]),
        ]),
      ]);
      await tester.pumpAndSettle();
      var scene = _scene<LineAreaScene>(tester);
      final b = scene.marks.firstWhere(
        (m) => m.kind == 'point' && m.series == 'B',
      );
      await _hover(tester, _inPlot(tester, b.rect.center + const Offset(0, 3)));
      scene = _scene<LineAreaScene>(tester);
      final rings = scene.marks.where((m) => m.kind == 'ring').toList();
      expect(rings, hasLength(1));
      expect(rings.single.series, 'B');
      expect(scene.marks.last.kind, 'crosshair');
      final foreground = _light.playground.charts.foreground;
      expect(scene.marks.last.color!.a, closeTo(foreground.a * .35, 1e-9));
    });

    testWidgets('F6, F7: line points are 2.5px dots with no ring; scatter '
        'dots have no outline', (tester) async {
      await pumpComponents(tester, theme: _light, [
        line(_rows('A', [1, 2, 3])),
      ]);
      await tester.pumpAndSettle();
      final points = _scene<LineAreaScene>(
        tester,
      ).marks.where((m) => m.kind == 'point');
      for (final p in points) {
        expect(p.rect.width, 5);
      }
      final paint = find.descendant(
        of: find.byType(ChartPlot),
        matching: find.byType(CustomPaint),
      );
      // A dot per point, nothing else round them.
      expect(
        tester.renderObject(paint),
        paintsExactlyCountTimes(#drawCircle, 3),
      );
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'ScatterChart',
          'data': [
            {'x': 1, 'y': 2},
            {'x': 3, 'y': 4},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      expect(
        tester.renderObject(paint),
        paintsExactlyCountTimes(#drawCircle, 2),
      );
    });

    testWidgets('F8, F12: a bar gets a focus ring at its value end; the '
        'pointer focuses a category only within 48px', (tester) async {
      await pumpComponents(tester, theme: _light, width: 640, [
        _root({
          'component': 'BarChart',
          'data': [
            {'x': 'A', 'y': 3},
            {'x': 'B', 'y': 5},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      var scene = _scene<BarScene>(tester);
      final bars = scene.marks.where((m) => m.kind == 'bar').toList();
      final between = Offset(
        (bars[0].rect.right + bars[1].rect.left) / 2,
        scene.plot.center.dy,
      );
      expect(bars[1].rect.left - between.dx, greaterThan(48));
      expect(scene.focusAt(between), isNull);
      await _hover(tester, _inPlot(tester, bars[1].rect.center));
      scene = _scene<BarScene>(tester);
      final ring = scene.marks.singleWhere((m) => m.kind == 'ring');
      expect(ring.rect.center.dx, closeTo(bars[1].rect.center.dx, 1e-9));
      expect(ring.rect.center.dy, closeTo(bars[1].rect.top, 1e-9));
    });

    testWidgets('F9: the tooltip sits 10px above the focused point, '
        'centred on it', (tester) async {
      await pumpComponents(tester, theme: _light, width: 520, [
        _root({
          'component': 'LineChart',
          'height': 300,
          'data': _rows('A', [-5, 0, 5, -5]),
        }),
      ]);
      await tester.pumpAndSettle();
      final scene = _scene<LineAreaScene>(tester);
      final point = scene.marks.where((m) => m.kind == 'point').elementAt(1);
      await _hover(tester, _inPlot(tester, point.rect.center));
      final anchor = _inPlot(tester, point.rect.center);
      final tooltip = tester.getRect(find.byType(PlaygroundChartTooltip));
      expect(tooltip.bottom, closeTo(anchor.dy - 10, 1e-6));
      expect(tooltip.center.dx, closeTo(anchor.dx, 1e-6));
    });

    testWidgets('F10: rows in screen order, top first', (tester) async {
      await pumpComponents(tester, theme: _light, [
        line([
          ..._rows('A', [10]),
          ..._rows('B', [30]),
        ]),
      ]);
      await tester.pumpAndSettle();
      final scene = _scene<LineAreaScene>(tester);
      expect(
        [for (final r in scene.tooltipOf(const PlotFocus(0))!.rows) r.label],
        ['B', 'A'],
      );
    });

    testWidgets("F11: TanStack's tooltip insides: grid rows, a full-colour "
        'label, a 500 value, a 650 title, an empty swatch cell, a bold active '
        'row', (tester) async {
      await pumpComponents(tester, theme: _light, chartSamples['area_chart']!);
      await tester.pumpAndSettle();
      final scene = _scene<LineAreaScene>(tester);
      final point = scene.points.first;
      await _hover(tester, _inPlot(tester, Offset(point.x, point.y)));
      final tooltip = find.byType(PlaygroundChartTooltip);
      expect(tooltip, findsOneWidget);
      final rows = find.descendant(of: tooltip, matching: find.byType(CssGrid));
      expect(rows, findsNWidgets(4));
      final total = tester.widget<CssGrid>(rows.last);
      // Total has no colour: its swatch cell stays, empty.
      expect(total.children.first, isA<SizedBox>());
      final fg = _light.playground.charts.tooltipForeground;
      final label = DefaultTextStyle.of(
        tester.element(
          find.descendant(of: tooltip, matching: find.text('Chat')),
        ),
      ).style;
      expect(label.color, fg);
      expect(label.fontWeight, FontWeight.w500);
      final totalLabel = DefaultTextStyle.of(
        tester.element(
          find.descendant(of: tooltip, matching: find.text('Total')),
        ),
      ).style;
      expect(totalLabel.fontWeight, FontWeight.w700);
      final title = tester.widget<Text>(
        find.descendant(of: tooltip, matching: find.text('Jan')),
      );
      expect(title.style!.fontWeight, const FontWeight(650));
    });

    testWidgets('F13: the margins start at 4: a bar chart leaves 4px on the '
        'right', (tester) async {
      await pumpComponents(tester, theme: _light, width: 520, [
        _root({
          'component': 'BarChart',
          'data': [
            {'x': 'A', 'y': 3},
            {'x': 'B', 'y': 5},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      final scene = _scene<BarScene>(tester);
      expect(scene.plot.right, closeTo(scene.size.width - 4, 1e-9));
    });

    testWidgets('F15, F17: stacked areas diverge from 0; a missing x has no '
        'point', (tester) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'AreaChart',
          'data': [
            {'x': 'Jan', 'y': 5, 'series': 'A'},
            {'x': 'Jan', 'y': -3, 'series': 'B'},
            {'x': 'Feb', 'y': 4, 'series': 'A'},
            {'x': 'Mar', 'y': 2, 'series': 'A'},
            {'x': 'Mar', 'y': 1, 'series': 'B'},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      final scene = _scene<LineAreaScene>(tester);
      final extents = LineAreaScene.stackOf(scene.rows, scene.names);
      expect(extents[1], (start: -3.0, end: 0.0));
      expect(extents[4], (start: 2.0, end: 3.0));
      expect(scene.points.where((p) => p.group == 'B'), hasLength(2));
    });

    testWidgets('F16: two values of one series at one position of a stack '
        'wait for complete data; grouped bars draw them', (tester) async {
      final duplicate = [
        {'x': 'Jan', 'y': 1, 'series': 'A'},
        {'x': 'Jan', 'y': 2, 'series': 'A'},
      ];
      for (final component in ['AreaChart', 'BarChart']) {
        await pumpComponents(tester, theme: _light, [
          _root({
            'component': component,
            'data': [
              ...duplicate,
              {'x': 'Jan', 'y': 2, 'series': 'B'},
            ],
          }),
        ]);
        // The waiting state pulses: pump, not settle.
        await tester.pump();
        expect(
          find.text('Waiting for complete data'),
          component == 'AreaChart' ? findsOneWidget : findsNothing,
        );
      }
      // One series of bars always stacks.
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'BarChart',
          'data': [
            {'x': 'Jan', 'y': 1},
            {'x': 'Jan', 'y': 2},
          ],
        }),
      ]);
      await tester.pump();
      expect(find.text('Waiting for complete data'), findsOneWidget);
    });

    testWidgets('F18: a stack rounds its outer non-empty bar', (tester) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'BarChart',
          'stacked': true,
          'data': [
            {'x': 'Jan', 'y': 5, 'series': 'A'},
            {'x': 'Jan', 'y': 0, 'series': 'B'},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      final radii = _scene<BarScene>(tester).barRadii;
      expect(radii[0], [4, 4, 0, 0]);
      expect(radii[1], [0, 0, 0, 0]);
    });

    testWidgets('F19, N3: angular gaps after each positive slice; a gap does '
        'not focus', (tester) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'PieChart',
          'data': [
            {'label': 'A', 'value': 1},
            {'label': 'B', 'value': 0},
            {'label': 'C', 'value': 1},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      final scene = _scene<PieScene>(tester);
      final angles = scene.sliceAngles;
      expect(angles[0].$1, 0);
      expect(angles[0].$2, closeTo(math.pi - .025, 1e-12));
      expect(angles[1], (angles[0].$2 + .025, angles[0].$2 + .025));
      expect(angles[2].$2, closeTo(2 * math.pi - .025, 1e-12));
      // The middle of the first gap, half-way out.
      const a = math.pi - .0125;
      final r = (scene.innerRadius + scene.outerRadius) / 2;
      final center = scene.size.center(Offset.zero);
      final gap = center + Offset(math.sin(a), -math.cos(a)) * r;
      expect(scene.focusAt(gap), isNull);
    });

    testWidgets('F20: a constant series widens 5% each way', (tester) async {
      await pumpComponents(tester, theme: _light, [
        line([
          ..._rows('A', [50, 50]),
          ..._rows('B', [50, 50]),
        ]),
      ]);
      await tester.pumpAndSettle();
      expect(
        [for (final t in _scene<LineAreaScene>(tester).leftTicks) t.label],
        ['47', '48', '49', '50', '51', '52', '53'],
      );
    });

    testWidgets('F21: a click pins the tooltip, which then ignores the '
        'pointer; a click outside unpins it', (tester) async {
      await pumpComponents(tester, theme: _light, width: 520, [
        _root({
          'component': 'Column',
          'children': ['chart', 'note'],
        }),
        {
          'id': 'chart',
          'component': 'LineChart',
          'data': _rows('A', [1, 2, 3]),
        },
        {'id': 'note', 'component': 'Text', 'text': 'Below'},
      ]);
      await tester.pumpAndSettle();
      final scene = _scene<LineAreaScene>(tester);
      final points = [
        for (final m in scene.marks.where((m) => m.kind == 'point'))
          _inPlot(tester, m.rect.center),
      ];
      await tester.tapAt(points[0]);
      await tester.pump();
      expect(find.text('P1'), findsWidgets);
      final gesture = await _hover(tester, points[2]);
      await gesture.moveTo(points[2]);
      await tester.pump();
      // Pinned: P1 stays.
      expect(find.text('P1'), findsWidgets);
      await tester.tapAt(tester.getCenter(find.text('Below')));
      await tester.pump();
      expect(find.byType(PlaygroundChartTooltip), findsNothing);
    });

    testWidgets('F22: axis titles 8px past the tick labels, at 76% of the '
        'text colour', (tester) async {
      await pumpComponents(tester, theme: _light, width: 520, [
        _root({
          'component': 'ScatterChart',
          'xLabel': 'Requests',
          'yLabel': 'Latency',
          'data': [
            {'x': 1, 'y': 2},
            {'x': 3, 'y': 40},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      final scene = _scene<ScatterScene>(tester);
      final layout = scene.layout;
      final text = scene.style.text;
      final xBottom = layout.xLabels
          .map((l) => text.labelBounds(l).bottom)
          .reduce(math.max);
      expect(layout.xTitle!.y, closeTo(xBottom + 8, 1e-9));
      expect(layout.xTitle!.baseline, TanstackBaseline.hanging);
      final yLeft = layout.yLabels
          .map((l) => text.labelBounds(l).left)
          .reduce(math.min);
      expect(text.labelBounds(layout.yTitle!).right, closeTo(yLeft - 8, 1e-6));
      final foreground = _light.playground.charts.foreground;
      expect(layout.xTitle!.color.a, closeTo(foreground.a * .76, 1e-9));
      expect(layout.xTitle!.fontWeight, FontWeight.w500);
    });

    testWidgets('N1: points stay in data order', (tester) async {
      await pumpComponents(tester, theme: _light, [
        line([
          {'x': 3, 'y': 1},
          {'x': 1, 'y': 2},
          {'x': 2, 'y': 3},
        ]),
      ]);
      await tester.pumpAndSettle();
      final xs = [for (final p in _scene<LineAreaScene>(tester).points) p.x];
      expect(xs[0], greaterThan(xs[2]));
      expect(xs[2], greaterThan(xs[1]));
    });

    testWidgets('a font that loads late rebuilds the scene; after the chart '
        'goes nothing listens', (tester) async {
      await pumpComponents(tester, theme: _light, [
        line(_rows('A', [1, 2])),
      ]);
      await tester.pumpAndSettle();
      final before = _scene<LineAreaScene>(tester);
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.pump();
      expect(identical(_scene<LineAreaScene>(tester), before), isFalse);
      await pumpComponents(tester, theme: _light, [
        _root({'component': 'Text', 'text': 'gone'}),
      ]);
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    for (final MapEntry(key: name, value: components) in chartSamples.entries) {
      if (name == 'chart') continue;
      testWidgets('$name holds at 320px and text scale 2 in the standard look '
          'and in the dark', (tester) async {
        for (final (theme, brightness) in [
          (A2uiKitTheme.standard(Brightness.light), Brightness.light),
          (_dark, Brightness.dark),
        ]) {
          await pumpComponents(
            tester,
            width: 320,
            textScale: 2,
            theme: theme,
            brightness: brightness,
            components,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Focus the first point: the tooltip fits too.
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      });
    }
  });

  group('the standard Chart', () {
    final standard = A2uiKitTheme.standard(Brightness.light);

    testWidgets('title, legend, 240px, the hidden table', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponents(tester, theme: standard, [
        _root({
          'component': 'Chart',
          'title': 'Signups by week',
          'xKey': 'week',
          'series': [
            {'key': 'signups', 'label': 'Signups'},
          ],
          'data': [
            {'week': 'W1', 'signups': 120},
            {'week': 'W2', 'signups': 164},
          ],
        }),
      ]);
      await tester.pump();
      expect(find.text('Signups by week'), findsOneWidget);
      // The legend's name, after its icon's no-break run (a word joiner and
      // a no-break space).
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText(includePlaceholders: false) ==
                  '⁠ Signups',
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(ChartPlot)).height, lessThan(240));
      expect(
        tableRows(tester),
        tableOf(
          ['week', 'Signups'],
          [
            ['W1', '120'],
            ['W2', '164'],
          ],
        ),
      );
      handle.dispose();
    });

    testWidgets("recharts' ticks and the bar's rounded end; the tooltip", (
      tester,
    ) async {
      await pumpComponents(tester, theme: standard, [
        _root({
          'component': 'Chart',
          'xKey': 'week',
          'showLegend': false,
          'data': [
            {'week': 'W1', 'signups': 120},
            {'week': 'W2', 'signups': 164},
            {'week': 'W3', 'signups': 151},
            {'week': 'W4', 'signups': 208},
          ],
        }),
      ]);
      await tester.pump();
      final scene = _scene<RechartsScene>(tester);
      expect(
        [for (final (_, label) in scene.valueLabelsOnAxis) label],
        ['120', '150', '180', '210', '240'],
      );
      // W1 sits on the axis' 120: a 0px bar recharts leaves out.
      expect([for (final m in scene.marks) m.value], [164, 151, 208]);
      final bar = scene.marks.firstWhere((m) => m.value == 164);
      await _hover(tester, _inPlot(tester, bar.rect.center));
      expect(find.byType(RechartsTooltip), findsOneWidget);
      expect(find.text('W2'), findsWidgets);
      expect(find.text('signups : 164'), findsOneWidget);
    });

    testWidgets('lines, areas and stacks', (tester) async {
      for (final type in ['line', 'area']) {
        await pumpComponents(tester, theme: standard, [
          _root({
            'component': 'Chart',
            'chartType': type,
            'xKey': 'd',
            'stacked': true,
            'showDots': true,
            'yAxis': {'min': 0},
            'data': [
              {'d': 'a', 'x': 1, 'y': 2},
              {'d': 'b', 'x': 2, 'y': 1},
            ],
          }),
        ]);
        await tester.pump();
        final scene = _scene<RechartsScene>(tester);
        expect(scene.marks, hasLength(4), reason: type);
        expect(scene.valueLabelsOnAxis.first.$2, '0', reason: type);
      }
    });

    testWidgets('a donut of 55% inside 80%; paddingAngle; a horizontal bar', (
      tester,
    ) async {
      await pumpComponents(tester, theme: standard, [
        _root({
          'component': 'Chart',
          'chartType': 'donut',
          'xKey': 'n',
          'paddingAngle': 5,
          'data': [
            {'n': 'a', 'v': 1},
            {'n': 'b', 'v': 1},
          ],
        }),
      ]);
      await tester.pump();
      final pie = _scene<RechartsPieScene>(tester);
      expect(pie.innerRadius, closeTo(pie.outerRadius / .8 * .55, 1e-9));
      expect(pie.slices[1].startAngle, pie.slices[0].endAngle - 5);
      await pumpComponents(tester, theme: standard, [
        _root({
          'component': 'Chart',
          'layout': 'horizontal',
          'xKey': 'n',
          'yAxis': {'min': 0},
          'data': [
            {'n': 'a', 'v': 1},
          ],
        }),
      ]);
      await tester.pump();
      final bars = _scene<RechartsScene>(tester);
      // The category axis is 96px wide.
      expect(bars.plot.left, 96);
      expect(bars.marks.single.rect.left, 96);
    });
  });

  group('every chart sample', () {
    for (final MapEntry(key: name, value: components) in chartSamples.entries) {
      testWidgets('$name holds at 320px and text scale 2', (tester) async {
        await pumpComponents(
          tester,
          width: 320,
          textScale: 2,
          theme: _light,
          components,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('$name draws in the dark', (tester) async {
        await pumpComponents(
          tester,
          theme: _dark,
          brightness: Brightness.dark,
          components,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_scenes(tester), isNotEmpty);
      });
    }
  });

  testWidgets('a chart in a Row and a Grid answers their sizing questions', (
    tester,
  ) async {
    // CSS flex and grid containers ask their items' intrinsic and dry
    // sizes; the drawing's LayoutBuilder cannot answer them itself.
    await pumpComponents(tester, theme: _light, [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['row', 'grid'],
      },
      {
        'id': 'row',
        'component': 'Row',
        'children': ['spark', 'note'],
      },
      {
        'id': 'spark',
        'component': 'Sparkline',
        'label': 'Signups',
        'values': [1, 3, 2],
      },
      {'id': 'note', 'component': 'Text', 'text': 'beside it'},
      {
        'id': 'grid',
        'component': 'Grid',
        'columns': 2,
        'children': ['line', 'pie'],
      },
      {
        'id': 'line',
        'component': 'LineChart',
        'data': _rows('A', [1, 2]),
      },
      {
        'id': 'pie',
        'component': 'Chart',
        'chartType': 'pie',
        'xKey': 'n',
        'data': [
          {'n': 'a', 'v': 1},
          {'n': 'b', 'v': 2},
        ],
      },
    ]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_scenes(tester), hasLength(3));
  });

  test('guardChart waits for complete data when the chart cannot draw', () {
    final widget = guardChart(() => throw StateError('partial'));
    expect(widget, isA<ChartEmptyState>());
    expect((widget as ChartEmptyState).label, 'Waiting for complete data');
    expect(guardChart(() => const SizedBox()), isA<SizedBox>());
  });

  _paintedStateTests();
}

Finder get _drawing => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is ChartScenePainter,
);

/// A point inside [path] (a slice), searched on a 1px grid of its bounds.
Offset _inside(Path path) {
  final box = path.getBounds();
  for (var y = box.top; y <= box.bottom; y += 1) {
    for (var x = box.left; x <= box.right; x += 1) {
      final at = Offset(x, y);
      if (path.contains(at)) return at;
    }
  }
  throw StateError('empty path');
}

// Review 2a regen RR22 (T4): behaviours read from TanStack Charts 1.1.0 and
// the playground's charts.tsx that no test had pinned, each checked where
// it is painted or laid out.
void _paintedStateTests() {
  group('painted states', () {
    // charts.tsx ScatterChart states: `focus: "primary"` fills at .95, the
    // others at .55 fade to .45 (dist/mark-state.js:84-112).
    testWidgets('the focused scatter dot fills at 95%; the others at 55% '
        'fade to 45%', (tester) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'ScatterChart',
          'data': [
            {'x': 1, 'y': 2},
            {'x': 9, 'y': 8},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      final dots = [
        for (final m in _scene<ScatterScene>(tester).marks)
          if (m.kind == 'dot') m,
      ];
      await _hover(tester, _inPlot(tester, dots[0].rect.center));
      final c = dots[0].color!;
      expect(
        tester.renderObject(_drawing),
        paints
          ..something(
            paintedCircle(
              x: dots[0].rect.center.dx,
              y: dots[0].rect.center.dy,
              color: c.withValues(alpha: c.a * .95),
            ),
          )
          ..something(
            paintedCircle(
              x: dots[1].rect.center.dx,
              y: dots[1].rect.center.dy,
              color: c.withValues(alpha: c.a * .55 * .45),
            ),
          ),
      );
    });

    // charts.tsx PieChart: `{when: {focus: "unmatched"}, style: {opacity:
    // .35}}`.
    testWidgets('a focused pie dims the other slices to 35%', (tester) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'PieChart',
          'data': [
            {'label': 'A', 'value': 1},
            {'label': 'B', 'value': 1},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      final pie = _scene<PieScene>(tester);
      await _hover(tester, _inPlot(tester, _inside(pie.slicePaths[0])));
      final a = pie.colors[0];
      final b = pie.colors[1];
      expect(
        tester.renderObject(_drawing),
        paints
          ..something(paintedPath(color: a))
          ..something(paintedPath(color: b.withValues(alpha: b.a * .35))),
      );
    });

    // charts.tsx Sparkline: `focusRing: {radius: 3.5, fill: stroke}`.
    testWidgets('a focused Sparkline point is a 3.5px dot', (tester) async {
      await pumpComponents(tester, theme: _light, chartSamples['sparkline']!);
      await tester.pumpAndSettle();
      final plot = tester.getRect(find.byType(ChartPlot));
      await _hover(tester, plot.center);
      expect(
        tester.renderObject(_drawing),
        paints..something(paintedCircle(radius: 3.5)),
      );
    });

    // dist/bar.js:479-484 (`endCornerRadii`): a negative horizontal bar
    // rounds its left (value) end.
    testWidgets('a negative horizontal bar rounds its left end', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'BarChart',
          'horizontal': true,
          'data': [
            {'x': 'A', 'y': -2},
            {'x': 'B', 'y': 3},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      final bar = _scene<BarScene>(
        tester,
      ).marks.firstWhere((m) => m.kind == 'bar' && m.value == -2);
      expect(
        tester.renderObject(_drawing),
        paints..something(
          paintedRRect(
            rrect: RRect.fromRectAndCorners(
              bar.rect,
              topLeft: const Radius.circular(4),
              bottomLeft: const Radius.circular(4),
            ),
          ),
        ),
      );
    });

    // dist/stack-ends-internal.js:25-75: a stack below 0 rounds only its
    // lowest end; no maximum above 0 is marked.
    testWidgets('an all-negative stack rounds only its outer end', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _light, [
        _root({
          'component': 'BarChart',
          'stacked': true,
          'data': [
            {'x': 'A', 'y': -2, 'series': 's1'},
            {'x': 'A', 'y': -3, 'series': 's2'},
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      final bars = [
        for (final m in _scene<BarScene>(tester).marks)
          if (m.kind == 'bar') m,
      ];
      expect(bars, hasLength(2));
      final outer = bars.firstWhere((m) => m.value == -3).rect;
      final inner = bars.firstWhere((m) => m.value == -2).rect;
      expect(
        tester.renderObject(_drawing),
        paints
          ..something(
            paintedRRect(rrect: RRect.fromRectAndRadius(inner, Radius.zero)),
          )
          ..something(
            paintedRRect(
              rrect: RRect.fromRectAndCorners(
                outer,
                bottomLeft: const Radius.circular(4),
                bottomRight: const Radius.circular(4),
              ),
            ),
          ),
      );
    });

    // dist/scene.js:1184: `width < 360 ? 10 : 11`, strict.
    testWidgets('tick labels are 11px on a scene exactly 360px wide', (
      tester,
    ) async {
      var width = 400.0;
      LineAreaScene scene() => _scene<LineAreaScene>(tester);
      await pumpComponents(
        tester,
        theme: _light,
        width: width,
        chartSamples['line_chart']!,
      );
      await tester.pumpAndSettle();
      width += 360 - scene().size.width;
      await pumpComponents(
        tester,
        theme: _light,
        width: width,
        chartSamples['line_chart']!,
      );
      await tester.pumpAndSettle();
      expect(scene().size.width, 360);
      expect(scene().layout.yLabels.first.fontSize, 11);
    });

    // dist/renderer.js:637-655: Enter pins and Enter again unpins, so the
    // pointer moves the focus again.
    testWidgets('Enter twice unpins', (tester) async {
      await pumpComponents(tester, theme: _light, chartSamples['line_chart']!);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      final scene = _scene<LineAreaScene>(tester);
      final june = scene.bottomTicks.firstWhere((t) => t.label == 'Jun');
      await _hover(
        tester,
        _inPlot(tester, Offset(june.position, scene.size.height / 2)),
      );
      expect(
        find.descendant(
          of: find.byType(PlaygroundChartTooltip),
          matching: find.text('Jun'),
        ),
        findsOneWidget,
      );
    });

    // dist/tooltip.js:504-581: the title `.3rem` over the rows; the active
    // row (a stack's Total) on its tint with a 2px ring, `.2rem` corners.
    testWidgets("the tooltip's title gap and the active row's ring", (
      tester,
    ) async {
      await pumpComponents(tester, theme: _light, chartSamples['area_chart']!);
      await tester.pumpAndSettle();
      final scene = _scene<LineAreaScene>(tester);
      await _hover(tester, _inPlot(tester, scene.size.center(Offset.zero)));
      final tooltip = find.byType(PlaygroundChartTooltip);
      final grids = find.descendant(
        of: tooltip,
        matching: find.byType(CssGrid),
      );
      final title = find
          .ancestor(
            of: find.descendant(of: tooltip, matching: find.byType(Text)).first,
            matching: find.byType(CssFlex),
          )
          .first;
      expect(
        tester.getRect(grids.first).top - tester.getRect(title).bottom,
        closeTo(.3 * 16, 1e-9),
      );
      final ring = find.descendant(
        of: tooltip,
        matching: find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_ActiveRowPainter',
        ),
      );
      final size = tester.getSize(ring);
      expect(
        tester.renderObject(ring),
        paints..something(
          paintedRRect(
            rrect: RRect.fromRectAndRadius(
              Rect.fromLTWH(-2, -2, size.width + 4, size.height + 4),
              const Radius.circular(.2 * 16 + 2),
            ),
          ),
        ),
      );
    });
  });
}
