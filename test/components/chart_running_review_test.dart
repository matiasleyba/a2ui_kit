// Widget tests of the charts' running review (CR1-CR16), most from its
// probes:
// a keyboard focus the scene lacks, non-finite values in all seven charts,
// the keys the library leaves alone, a press that focuses, the keyboard
// index clamp, a mouse leaving a keyboard-owned TanStack focus, the bar
// corner cap, and the browser's own focus outline. Expected values are
// worked out from recharts 3.10.1 and @tanstack/charts 1.1.0, cited next to
// each.

import 'dart:math' as math;

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/playground/charts/cartesian.dart';
import 'package:a2ui_kit/src/components/playground/charts/chart_kit.dart';
import 'package:a2ui_kit/src/components/playground/charts/pie_sparkline.dart';
import 'package:a2ui_kit/src/components/standard/data/chart.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart'
    show FocusRing;
import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:a2ui_kit/src/foundation/platform.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderClipRRect;
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/finite_canvas.dart' show nonFiniteCalls;
import '../helpers/harness.dart';
import '../helpers/paint_calls.dart';

final _standard = A2uiKitTheme.standard(Brightness.light);
final _playground = A2uiKitTheme.playground(Brightness.light);

List<PlotScene> _scenes(WidgetTester tester) => [
  for (final paint in tester.widgetList<CustomPaint>(find.byType(CustomPaint)))
    if (paint.painter case final ChartScenePainter painter) painter.scene,
];

T _scene<T>(WidgetTester tester) => _scenes(tester).whereType<T>().first;

/// The focus the first chart drawing paints.
PlotFocus? _painterFocus(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<ChartScenePainter>()
    .first
    .focus;

Future<TestSurfaces> _chart(
  WidgetTester tester,
  Map<String, Object?> props, {
  double width = 360,
  A2uiKitTheme? theme,
  Object? data,
}) async {
  final surfaces = await pumpComponents(
    tester,
    width: width,
    theme: theme ?? _standard,
    data: data,
    [
      {'id': 'root', ...props},
    ],
  );
  // The playground charts measure and grow in over a few frames.
  await tester.pumpAndSettle();
  return surfaces;
}

const List<Map<String, Object>> _signups = [
  {'week': 'W1', 'signups': 120},
  {'week': 'W2', 'signups': 164},
  {'week': 'W3', 'signups': 151},
  {'week': 'W4', 'signups': 208},
];

Offset _plotTopLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byType(ChartPlot).first);

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

/// The paint clip, in global coordinates, that the render objects from
/// [to]'s down to [from]'s parent put on [from]: the intersection of each
/// one's `describeApproximatePaintClip`, or null where none clips.
Rect? _clipBetween(WidgetTester tester, Finder from, Finder to) {
  final top = tester.renderObject(to);
  Rect? clip;
  var child = tester.renderObject(from);
  while (child != top) {
    final parent = child.parent!;
    if (parent.describeApproximatePaintClip(child) case final rect?) {
      final global = MatrixUtils.transformRect(
        parent.getTransformTo(null),
        rect,
      );
      clip = clip?.intersect(global) ?? global;
    }
    child = parent;
  }
  return clip;
}

/// A row field the agent left out.
const Object _missing = Object();

/// WidgetsApp's `_defaultWebShortcuts` (flutter 3.47.9 widgets/app.dart:
/// 1308-1343), copied whole: what an app has on the web.
const Map<ShortcutActivator, Intent> _webShortcuts = {
  SingleActivator(LogicalKeyboardKey.space): PrioritizedIntents(
    orderedIntents: [
      ActivateIntent(),
      ScrollIntent(
        direction: AxisDirection.down,
        type: ScrollIncrementType.page,
      ),
    ],
  ),
  SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ButtonActivateIntent(),
  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
  SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
  SingleActivator(LogicalKeyboardKey.tab, shift: true): PreviousFocusIntent(),
  SingleActivator(LogicalKeyboardKey.arrowUp): ScrollIntent(
    direction: AxisDirection.up,
  ),
  SingleActivator(LogicalKeyboardKey.arrowDown): ScrollIntent(
    direction: AxisDirection.down,
  ),
  SingleActivator(LogicalKeyboardKey.arrowLeft): ScrollIntent(
    direction: AxisDirection.left,
  ),
  SingleActivator(LogicalKeyboardKey.arrowRight): ScrollIntent(
    direction: AxisDirection.right,
  ),
  SingleActivator(LogicalKeyboardKey.pageUp): ScrollIntent(
    direction: AxisDirection.up,
    type: ScrollIncrementType.page,
  ),
  SingleActivator(LogicalKeyboardKey.pageDown): ScrollIntent(
    direction: AxisDirection.down,
    type: ScrollIncrementType.page,
  ),
};

/// A chart of [props] 1500px down a long page (a primary scroll view, its
/// [ScrollController] returned), [wrap] round the chart, with the app's
/// shortcuts on the web path ([web]) or off it; the chart has the focus,
/// by Tab.
Future<ScrollController> _pumpOnPage(
  WidgetTester tester,
  Map<String, Object?> props, {
  required bool web,
  A2uiKitTheme? theme,
  Widget Function(Widget chart)? wrap,
}) async {
  debugKitIsWebOverride = web;
  addTearDown(() => debugKitIsWebOverride = null);
  final surfaces = TestSurfaces()
    ..create([
      {'id': 'root', ...props},
    ]);
  addTearDown(surfaces.dispose);
  final controller = ScrollController();
  addTearDown(controller.dispose);
  final chart = SizedBox(
    width: 360,
    child: A2uiSurface(surface: surfaces.surface),
  );
  await tester.pumpWidget(
    MaterialApp(
      shortcuts: web ? _webShortcuts : WidgetsApp.defaultShortcuts,
      theme: ThemeData(extensions: [theme ?? _standard]),
      home: Scaffold(
        body: PrimaryScrollController(
          controller: controller,
          child: SingleChildScrollView(
            primary: true,
            child: Column(
              children: [
                const SizedBox(height: 1500),
                (wrap ?? (chart) => chart)(chart),
                const SizedBox(height: 3000),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
  expect(_focused(), 'chart');
  return controller;
}

/// Presses [key] with [modifier] held.
Future<void> _withModifier(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
}

const Map<String, Object?> _barChart = {
  'component': 'Chart',
  'xKey': 'week',
  'showLegend': false,
  'data': _signups,
};

/// An app's own shortcut intent.
class _MarkIntent extends Intent {
  const _MarkIntent();
}

/// The values the review asks every chart to take (RULEBOOK section 6 item
/// 3): JSON's 1e999 and -1e999 (the infinities), the texts JavaScript's
/// `Number()` reads as infinite or NaN, "", null, and a missing key.
const Map<String, Object?> _odd = {
  'Infinity (JSON 1e999)': double.infinity,
  '-Infinity (JSON -1e999)': double.negativeInfinity,
  '"Infinity"': 'Infinity',
  '"-Infinity"': '-Infinity',
  '"1e999"': '1e999',
  '"NaN"': 'NaN',
  '""': '',
  'null': null,
  'a missing key': _missing,
};

Map<String, Object?> _row(Map<String, Object?> fields) => {
  for (final MapEntry(:key, :value) in fields.entries)
    if (!identical(value, _missing)) key: value,
};

/// Hovers, tabs, steps, toggles and escapes through the charts on screen;
/// the exceptions any of it raised.
Future<List<String>> _interact(WidgetTester tester) async {
  final problems = <String>[];
  final plots = find.byType(ChartPlot);
  for (var p = 0; p < plots.evaluate().length; p++) {
    final rect = tester.getRect(plots.at(p));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    for (final f in [.05, .3, .5, .7, .95]) {
      await gesture.moveTo(
        Offset(rect.left + rect.width * f, rect.top + rect.height * .5),
      );
      await tester.pump();
      if (tester.takeException() case final e?) problems.add('hover $f: $e');
    }
    await gesture.moveTo(const Offset(5000, 5000));
    await gesture.removePointer();
    await tester.pump();
  }
  for (final key in [
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.escape,
  ]) {
    await tester.sendKeyEvent(key);
    await tester.pump(const Duration(milliseconds: 500));
    if (tester.takeException() case final e?) {
      problems.add('key ${key.keyLabel}: $e');
    }
  }
  return problems;
}

void main() {
  _keyboardFocusTests();
  _stateAcrossDataTests();
  _nonFiniteTests();
  _standardNonFiniteGeometryTests();
  _interactionTests();
  _outlineTests();
}

// RR2-1 (RULEBOOK section 6 item 3): every standard Chart scene painted into
// a recording canvas, with no focus and with each focus its keys reach,
// gets no number that is not finite, for values whose arithmetic
// overflows a double too.
void _standardNonFiniteGeometryTests() {
  group('no non-finite geometry in the standard Chart (RR2-1)', () {
    const sets = <String, List<Object?>>{
      'huge': [1e308, -1e308, 1e308],
      'max': [1.7976931348623157e308, -1.7976931348623157e308, 5],
      'infinite': [double.infinity, 3, double.negativeInfinity],
    };
    for (final type in [
      'bar',
      'bar-horizontal',
      'bar-stacked',
      'line',
      'line-horizontal',
      'area-stacked',
      'scatter',
      'pie',
      'donut',
    ]) {
      testWidgets('the standard Chart ($type)', (tester) async {
        final problems = <String>[];
        for (final MapEntry(key: name, value: values) in sets.entries) {
          await _chart(tester, {
            'component': 'Chart',
            'xKey': 'k',
            'series': ['v', 'w'],
            'showDots': true,
            'showValueLabels': true,
            ...switch (type) {
              'bar-horizontal' => {'chartType': 'bar', 'layout': 'horizontal'},
              'bar-stacked' => {'chartType': 'bar', 'stacked': true},
              'line-horizontal' => {
                'chartType': 'line',
                'layout': 'horizontal',
              },
              'area-stacked' => {'chartType': 'area', 'stacked': true},
              _ => {'chartType': type},
            },
            'data': [
              for (final (i, v) in values.indexed)
                {'k': 'r$i', 'v': v, 'w': values[values.length - 1 - i]},
            ],
          });
          if (tester.takeException() case final e?) problems.add('$name: $e');
          for (final scene in _scenes(tester)) {
            for (final focus in [
              null,
              for (var i = 0; i < scene.keyboardRows; i++)
                scene.keyboardFocus(i),
            ]) {
              for (final call in nonFiniteCalls(scene, focus: focus)) {
                problems.add('$name, $focus: $call');
              }
            }
          }
          for (final p in await _interact(tester)) {
            problems.add('$name: $p');
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }
        expect(problems, isEmpty);
      });
    }
  });
}

// CR1, CR8: es6/state/selectors/combiners/combineActiveTooltipIndex.js:
// 39-70, es6/state/keyboardEventsMiddleware.js:140-163,
// es6/component/TooltipBoundingBox.js:93.
void _keyboardFocusTests() {
  group('a keyboard index the scene does not have (CR1, CR8)', () {
    for (final (name, values) in [
      ('no rows', <int>[]),
      ('rows of 0', [0, 0]),
      ('negative rows', [-1, -2]),
    ]) {
      testWidgets('a pie of $name takes Tab: nothing shows, nothing throws', (
        tester,
      ) async {
        await _chart(tester, {
          'component': 'Chart',
          'chartType': 'pie',
          'xKey': 'n',
          'series': ['v'],
          'data': [
            for (final (i, v) in values.indexed) {'n': 'r$i', 'v': v},
          ],
        });
        expect(_scene<RechartsPieScene>(tester).slices, isEmpty);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_focused(), 'chart');
        expect(find.byType(RechartsTooltip), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(RechartsTooltip), findsNothing);
      });
    }

    testWidgets('a pie whose rows go while it has the keyboard shows nothing', (
      tester,
    ) async {
      final surfaces = await _chart(
        tester,
        {
          'component': 'Chart',
          'chartType': 'pie',
          'xKey': 'n',
          'showLegend': false,
          'data': {'@path': '/rows'},
        },
        data: {
          'rows': [
            {'n': 'a', 'v': 1},
            {'n': 'b', 'v': 2},
          ],
        },
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('a : 1'), findsOneWidget);
      surfaces.setData('/rows', <Object?>[]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(RechartsTooltip), findsNothing);
    });

    // CR8 (M8b): combineActiveTooltipIndex.js:55-63 clamps the index to the
    // rows there are.
    testWidgets('rows shrinking under the keyboard index clamp it', (
      tester,
    ) async {
      final surfaces = await _chart(
        tester,
        {
          'component': 'Chart',
          'xKey': 'week',
          'showLegend': false,
          'data': {'@path': '/rows'},
        },
        data: {'rows': _signups},
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      }
      await tester.pumpAndSettle();
      expect(find.text('signups : 208'), findsOneWidget);
      surfaces.setData('/rows', _signups.sublist(0, 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('signups : 164'), findsOneWidget);
      // One step back from the clamped index: W1.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('signups : 120'), findsOneWidget);
    });
  });
}

// RR2-5, RR2-6 (RULEBOOK section 6 item 3): state across new data, kept
// as each library keeps it.
void _stateAcrossDataTests() {
  group('state across new data (RR2-5, RR2-6)', () {
    // recharts keeps the hovered index (tooltipSlice resets nothing on new
    // data) and combineActiveTooltipIndex.js:39-70 clamps whichever
    // interaction is active to the rows there are.
    testWidgets("recharts' hovered index past the new rows is clamped", (
      tester,
    ) async {
      final surfaces = await _chart(
        tester,
        {
          'component': 'Chart',
          'xKey': 'week',
          'showLegend': false,
          'data': {'@path': '/rows'},
        },
        width: 600,
        data: {'rows': _signups},
      );
      final scene = _scene<RechartsScene>(tester);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      // W4's band.
      await gesture.moveTo(
        _plotTopLeft(tester) +
            Offset(scene.plot.right - 10, scene.plot.center.dy),
      );
      await tester.pumpAndSettle();
      expect(find.text('signups : 208'), findsOneWidget);
      surfaces.setData('/rows', _signups.sublist(0, 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('signups : 164'), findsOneWidget);
    });

    List<Map<String, Object>> rowsOf(List<String> xs) => [
      for (final (i, x) in xs.indexed) {'x': x, 'y': i + 1},
    ];
    Finder tooltipTitle(String text) => find.descendant(
      of: find.byType(PlaygroundChartTooltip),
      matching: find.text(text),
    );

    // @tanstack/charts 1.1.0 dist/renderer.js:159-177: a keyboard focus is
    // found again by its point's key (`restoreChartFocusPoint`, dist/
    // interaction.js:33-47; a bar's key is its x, dist/bar.js:69-73).
    testWidgets("TanStack keeps the keyboard's point by its key when a row "
        'is put first', (tester) async {
      final surfaces = await _chart(
        tester,
        {
          'component': 'BarChart',
          'data': {'@path': '/rows'},
        },
        theme: _playground,
        data: {
          'rows': rowsOf(['A', 'B', 'C']),
        },
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tooltipTitle('B'), findsOneWidget);
      surfaces.setData('/rows', rowsOf(['Z', 'A', 'B', 'C']));
      await tester.pumpAndSettle();
      expect(tooltipTitle('B'), findsOneWidget);
    });

    // :167-168: no point restored, no pin (`if (!nextFocusedPoint)
    // pinnedKey = null`), so the pointer moves the focus again.
    testWidgets('TanStack drops a pin whose point is gone', (tester) async {
      final surfaces = await _chart(
        tester,
        {
          'component': 'LineChart',
          'data': {'@path': '/rows'},
        },
        theme: _playground,
        data: {
          'rows': rowsOf(['P0', 'P1', 'P2', 'P3']),
        },
      );
      LineAreaScene scene() => _scene<LineAreaScene>(tester);
      Offset pointOf(int i) =>
          _plotTopLeft(tester) +
          Offset(scene().points[i].x, scene().points[i].y);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: pointOf(3));
      addTearDown(gesture.removePointer);
      await gesture.moveTo(pointOf(3));
      await tester.pump();
      await gesture.down(pointOf(3));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tooltipTitle('P3'), findsOneWidget);
      surfaces.setData('/rows', rowsOf(['P0', 'P1']));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await gesture.moveTo(pointOf(0));
      await tester.pumpAndSettle();
      expect(tooltipTitle('P0'), findsOneWidget);
    });

    // RC3-3 (RULEBOOK section 6 items 3 and 8): each kept state, as rows
    // shrink and as a row is put first, kept as each library keeps it.
    _keptStateMatrix(rowsOf, tooltipTitle);

    // RC3-2: TanStack restores a focus only on its `render`
    // (@tanstack/charts 1.1.0 dist/renderer.js:97-182, the restore at
    // :159-177): `handleKeyDown` moves the focus and restores nothing
    // (:619-670). Two slices labelled A take one key (`key: "label"`,
    // charts.tsx:540-589; dist/polar.js:203), and a weight of 0 takes no
    // angle and no gap (dist/proportional-interval-internal.js:45-57), so
    // their values are equal too; in screen order (dist/interaction.js:
    // 71-121) C (left), A0 and A1 (top, by index), B (right). A port that
    // restores on every build sends ArrowRight from A1 back to A0 for ever.
    group('two pie slices sharing a key', () {
      Future<TestSurfaces> pumpPie(WidgetTester tester) => _chart(
        tester,
        {
          'component': 'PieChart',
          'title': {'@path': '/t'},
          'height': {'@path': '/h'},
          'format': {'@path': '/f'},
          'data': {'@path': '/rows'},
        },
        theme: _playground,
        data: {
          't': 'Before',
          'h': 200,
          'f': 'compact',
          'rows': [
            {'label': 'A', 'value': 0},
            {'label': 'A', 'value': 0},
            {'label': 'B', 'value': 5},
            {'label': 'C', 'value': 5},
          ],
        },
      );
      Future<List<int?>> steps(WidgetTester tester) async {
        final groups = <int?>[];
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        groups.add(_painterFocus(tester)?.group);
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          groups.add(_painterFocus(tester)?.group);
        }
        return groups;
      }

      testWidgets('the arrows step over both, C, A, A, B', (tester) async {
        await pumpPie(tester);
        final scene = _scene<PieScene>(tester);
        expect(
          scene.focusKeyOf(const PlotFocus(0)),
          scene.focusKeyOf(const PlotFocus(1)),
        );
        expect(await steps(tester), [3, 0, 1, 2]);
        expect(tooltipTitle('B'), findsOneWidget);
      });

      // A new title is a new `ariaLabel`, which renders the same definition
      // (dist/renderer.js:719, `needsRender`), so the same slice objects:
      // the second A is found by its own row first (dist/interaction.js:
      // 36-41), though its values are the first A's too.
      testWidgets('a render over the same definition keeps the second A', (
        tester,
      ) async {
        final surfaces = await pumpPie(tester);
        final groups = await steps(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect([...groups, _painterFocus(tester)?.group], [3, 0, 1, 2, 1]);
        surfaces.setData('/t', 'After');
        await tester.pumpAndSettle();
        expect(find.text('After'), findsOneWidget);
        expect(_painterFocus(tester), const PlotFocus(1));
      });

      // A new size over the same definition: the slices' radii move with
      // it, so the values no longer match, and the second A is found by its
      // row (:36-41, or :44-45 failing that).
      testWidgets('a new size keeps the second A', (tester) async {
        final surfaces = await pumpPie(tester);
        await steps(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(_painterFocus(tester), const PlotFocus(1));
        surfaces.setData('/h', 180);
        await tester.pumpAndSettle();
        expect(_scene<PieScene>(tester).size, const Size(180, 180));
        expect(_painterFocus(tester), const PlotFocus(1));
      });

      // A new `format` makes a new definition and new slice objects
      // (charts.tsx:589), so the key's values decide: the first A.
      testWidgets('a new definition goes back to the first A', (tester) async {
        final surfaces = await pumpPie(tester);
        await steps(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(_painterFocus(tester), const PlotFocus(1));
        surfaces.setData('/f', 'currency');
        await tester.pumpAndSettle();
        expect(_painterFocus(tester), const PlotFocus(0));
      });
    });

    // RR3-1 (RULEBOOK section 6 item 3): on a render, a pointer the focus
    // belongs to is resolved again where it rests, whether or not it had
    // found a point (`trackedPointer`, dist/renderer.js:161-162;
    // `pointsAtPointer` keeps the place either way, :434-437); only
    // `mouseleave` clears the place (`clearPointerFocus`, :539-547).
    group("TanStack's resting pointer on new data", () {
      List<Map<String, Object>> dots(List<int> xs) => [
        for (final x in xs) {'x': x, 'y': x, 'label': 'd$x'},
      ];

      testWidgets('a pointer resting where no dot is gets the dot new data '
          'puts under it', (tester) async {
        final surfaces = await _chart(
          tester,
          {
            'component': 'ScatterChart',
            'data': {'@path': '/rows'},
          },
          theme: _playground,
          data: {
            'rows': dots([0, 10]),
          },
        );
        final scene = _scene<ScatterScene>(tester);
        final mid = Offset(
          (scene.points[0].x + scene.points[1].x) / 2,
          (scene.points[0].y + scene.points[1].y) / 2,
        );
        // Farther than maxFocusDistance (48) from both dots.
        expect(scene.focusAt(mid), isNull);
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(_plotTopLeft(tester) + mid);
        await tester.pumpAndSettle();
        expect(find.byType(PlaygroundChartTooltip), findsNothing);
        surfaces.setData('/rows', dots([0, 5, 10]));
        await tester.pumpAndSettle();
        final now = _scene<ScatterScene>(tester);
        expect(now.focusAt(mid), isNotNull);
        expect(_painterFocus(tester), now.focusAt(mid));
        expect(find.byType(PlaygroundChartTooltip), findsOneWidget);
      });

      testWidgets('a dot that goes and comes back under the resting pointer '
          'is focused again', (tester) async {
        final surfaces = await _chart(
          tester,
          {
            'component': 'ScatterChart',
            'data': {'@path': '/rows'},
          },
          theme: _playground,
          data: {
            'rows': dots([0, 5, 10]),
          },
        );
        final scene = _scene<ScatterScene>(tester);
        final b = Offset(scene.points[1].x, scene.points[1].y);
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(_plotTopLeft(tester) + b);
        await tester.pumpAndSettle();
        expect(find.byType(PlaygroundChartTooltip), findsOneWidget);
        surfaces.setData('/rows', dots([0, 10]));
        await tester.pumpAndSettle();
        expect(find.byType(PlaygroundChartTooltip), findsNothing);
        surfaces.setData('/rows', dots([0, 5, 10]));
        await tester.pumpAndSettle();
        expect(_painterFocus(tester), const PlotFocus(1));
        expect(find.byType(PlaygroundChartTooltip), findsOneWidget);
      });

      // `mouseleave` clears the place the pointer rested (:539-547), so new
      // data under where it was focuses nothing.
      testWidgets('a pointer that left the chart takes nothing new data '
          'puts where it was', (tester) async {
        final surfaces = await _chart(
          tester,
          {
            'component': 'ScatterChart',
            'data': {'@path': '/rows'},
          },
          theme: _playground,
          data: {
            'rows': dots([0, 10]),
          },
        );
        final scene = _scene<ScatterScene>(tester);
        final mid = Offset(
          (scene.points[0].x + scene.points[1].x) / 2,
          (scene.points[0].y + scene.points[1].y) / 2,
        );
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(_plotTopLeft(tester) + mid);
        await tester.pumpAndSettle();
        await gesture.moveTo(const Offset(5000, 5000));
        await tester.pumpAndSettle();
        surfaces.setData('/rows', dots([0, 5, 10]));
        await tester.pumpAndSettle();
        expect(_scene<ScatterScene>(tester).focusAt(mid), isNotNull);
        expect(_painterFocus(tester), isNull);
        expect(find.byType(PlaygroundChartTooltip), findsNothing);
      });

      // The ResizeObserver renders the chart at its new size
      // (dist/renderer.js:232-249), and the resting pointer is resolved
      // again in it: the bar now under it, not the one it was over.
      // The chart's widgets are built once and only their box changes, so
      // the size alone renders it.
      testWidgets('a new size resolves the resting pointer again', (
        tester,
      ) async {
        final surfaces = TestSurfaces()
          ..create(
            [
              {
                'id': 'root',
                'component': 'BarChart',
                'data': {'@path': '/rows'},
              },
            ],
            data: {
              'rows': rowsOf(['A', 'B', 'C']),
            },
          );
        addTearDown(surfaces.dispose);
        final width = ValueNotifier<double>(360);
        addTearDown(width.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [_playground]),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: ValueListenableBuilder<double>(
                  valueListenable: width,
                  builder: (context, value, child) =>
                      SizedBox(width: value, child: child),
                  child: A2uiSurface(surface: surfaces.surface),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scene = _scene<BarScene>(tester);
        final local = Offset(scene.points[0].x, scene.size.height / 2);
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(_plotTopLeft(tester) + local);
        await tester.pumpAndSettle();
        expect(tooltipTitle('A'), findsOneWidget);
        width.value = 180;
        await tester.pumpAndSettle();
        final now = _scene<BarScene>(tester);
        expect(now.size.width, lessThan(scene.size.width));
        final under = now.focusAt(local);
        expect(under, isNotNull);
        expect(now.tooltipOf(under!)!.title, isNot('A'));
        expect(_painterFocus(tester), under);
        expect(tooltipTitle(now.tooltipOf(under)!.title!), findsOneWidget);
      });
    });

    // RULEBOOK section 6 item 3: an undrawn point keeps its focus and its
    // tooltip; the box's `left` and `top` that don't parse are dropped one by
    // one (CSSOM `setProperty`), so each keeps its last value, or, never set,
    // the box's static position (@tanstack/charts 1.1.0 dist/
    // tooltip-position.js:17-18; dist/tooltip.js:184-196, :310-325).
    testWidgets('a TanStack tooltip keeps its last left and top each on its '
        'own, and sits at its static position where never set', (tester) async {
      await _chart(tester, {
        'component': 'Sparkline',
        'label': 'MRR',
        // 1e308's y is Infinity / Infinity = NaN; -1e308's is the plot's
        // bottom (dist/scales/linear.js:76-81).
        'values': [1e308, -1e308, 1e308],
      }, theme: _playground);
      double? left;
      double? top;
      final nanSteps = <int>[];
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      // `nearest-x` steps through every point (dist/focus.js:35-39, no
      // grouping): the area's and the line's at each value, then the
      // dot's at the last (sorted by x, then y).
      for (var step = 0; step < 7; step++) {
        if (step > 0) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<ChartScenePainter>()
            .first;
        final focus = painter.focus;
        expect(focus, isNotNull, reason: 'step $step');
        // Its rows show, drawn or not.
        expect(find.byType(PlaygroundChartTooltip), findsOneWidget);
        final want = painter.scene.tooltipPosition(
          focus!,
          null,
          tester.getSize(find.byType(PlaygroundChartTooltip)),
        );
        if (!want.dx.isFinite || !want.dy.isFinite) nanSteps.add(step);
        if (want.dx.isFinite) left = want.dx;
        if (want.dy.isFinite) top = want.dy;
        final fallback = painter.scene.tooltipStaticPlace;
        final box =
            tester.getTopLeft(find.byType(PlaygroundChartTooltip)) -
            _plotTopLeft(tester);
        expect(
          box,
          Offset(left ?? fallback.dx, top ?? fallback.dy),
          reason: 'step $step',
        );
        expect(box.isFinite, isTrue, reason: 'step $step');
      }
      // The first value's two points are undrawn and come first: their top
      // was never set, so the box sits at its static top; the last value's
      // three come after the drawn -1e308 ones: they keep that top.
      expect(nanSteps, [0, 1, 4, 5, 6]);
    });

    // The playground's `ChartFrame` is a `<figure>` with `overflow-hidden`
    // (chart-kit.tsx:269-271), which clips at its padding box, inside its
    // 1px border, each corner's radius less the border's width (CSS
    // Overflow 3, 3.1; CSS Backgrounds 3, 5.3). TanStack's tooltip is
    // absolute in the chart's container (`position: relative`, dist/
    // renderer.js:90-96; the playground sets no `portal`, dist/tooltip.js:
    // 159-196), inside the figure, so the figure clips it wherever it sits.
    testWidgets('a TanStack tooltip that leaves the figure is clipped at '
        "the figure's padding box, never over its border", (tester) async {
      await _chart(tester, {
        'component': 'LineChart',
        // Every y is NaN (playground_charts_non_finite_test.dart): the
        // box's `top` never parses, so it sits at its static place, under
        // the chart, and leaves the figure at the bottom.
        'data': [
          for (final (i, y) in [1e308, -1e308, 1e308].indexed)
            {'x': 'X$i', 'y': y},
        ],
      }, theme: _playground);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final tip = find.byType(PlaygroundChartTooltip);
      expect(tip, findsOneWidget);
      final frameFinder = find.byType(PlaygroundChartFrame);
      final frame = tester.getRect(frameFinder);
      final box = tester.getRect(tip);
      const border = 1.0;
      final paddingBox = frame.deflate(border);
      // It reaches past the padding box, over the border and beyond.
      expect(box.top, lessThan(paddingBox.bottom));
      expect(box.bottom, greaterThan(frame.bottom));
      final clip = _clipBetween(tester, tip, frameFinder);
      expect(clip, rectMoreOrLessEquals(paddingBox));
      // The clip's corners: the card's radius less the border's width.
      final card = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: frameFinder,
              matching: find.byType(DecoratedBox),
            ),
          )
          .first
          .decoration;
      final outer = (card as BoxDecoration).borderRadius! as BorderRadius;
      final clipper = tester.renderObject<RenderClipRRect>(
        find.ancestor(of: tip, matching: find.byType(ClipRRect)).first,
      );
      expect(
        clipper.borderRadius,
        BorderRadius.circular(math.max(0, outer.topLeft.x - border)),
      );
    });

    // The Sparkline's card has no `overflow` (charts.tsx:1037; `.a2-card`,
    // globals.css:210-217): its tooltip is clipped by nothing in it.
    testWidgets('a Sparkline tooltip that leaves its card is not clipped', (
      tester,
    ) async {
      await _chart(tester, {
        'component': 'Sparkline',
        'label': 'MRR',
        'values': [1e308, -1e308, 1e308],
      }, theme: _playground);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final tip = find.byType(PlaygroundChartTooltip);
      expect(tip, findsOneWidget);
      // The nearest bordered box round it: the card.
      final cardFinder = find
          .ancestor(
            of: tip,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).border != null,
            ),
          )
          .first;
      final card = tester.getRect(cardFinder);
      // Its top never parsed: it hangs under the 44px chart, past the
      // card's 12px padding and border.
      expect(tester.getRect(tip).bottom, greaterThan(card.bottom));
      expect(_clipBetween(tester, tip, cardFinder), isNull);
    });

    // RR2-10: upstream always renders the `<table>` (Chart.tsx:424-452).
    testWidgets('an empty Chart with no xKey and no series keeps its table '
        'node', (tester) async {
      final handle = tester.ensureSemantics();
      await _chart(tester, {'component': 'Chart', 'data': <Object?>[]});
      expect(
        find.semantics.byPredicate((node) => node.role == SemanticsRole.table),
        findsOne,
      );
      handle.dispose();
    });
  });
}

/// RC3-3 (RULEBOOK section 6 items 3 and 8): each kept state (hover,
/// keyboard, pin) as rows shrink and as a row is put first, for each
/// library. recharts' hover and keyboard as rows shrink are the tests
/// "recharts' hovered index past the new rows is clamped" and "rows
/// shrinking under the keyboard index clamp it"; TanStack's keyboard as a
/// row is put first, "TanStack keeps the keyboard's point by its key when a
/// row is put first".
void _keptStateMatrix(
  List<Map<String, Object>> Function(List<String>) rowsOf,
  Finder Function(String) tooltipTitle,
) {
  // recharts keeps both indexes on new data (tooltipSlice resets neither)
  // and reads them through combineActiveTooltipIndex.js:39-70: the row now
  // at the index shows. A port that kept the row by its key would show the
  // old one.
  group('recharts, a row put first', () {
    final withW0 = [
      {'week': 'W0', 'signups': 99},
      ..._signups,
    ];
    Future<TestSurfaces> pump(WidgetTester tester) => _chart(
      tester,
      {
        'component': 'Chart',
        'xKey': 'week',
        'showLegend': false,
        'data': {'@path': '/rows'},
      },
      width: 600,
      data: {'rows': _signups},
    );

    testWidgets('the hovered index shows the row now there', (tester) async {
      final surfaces = await pump(tester);
      final scene = _scene<RechartsScene>(tester);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      // W2's band, the second of four.
      await gesture.moveTo(
        _plotTopLeft(tester) +
            Offset(
              scene.plot.left + scene.plot.width * 1.5 / 4,
              scene.plot.center.dy,
            ),
      );
      await tester.pumpAndSettle();
      expect(find.text('signups : 164'), findsOneWidget);
      surfaces.setData('/rows', withW0);
      await tester.pumpAndSettle();
      expect(find.text('signups : 120'), findsOneWidget);
    });

    testWidgets('the keyboard index shows the row now there', (tester) async {
      final surfaces = await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('signups : 164'), findsOneWidget);
      surfaces.setData('/rows', withW0);
      await tester.pumpAndSettle();
      expect(find.text('signups : 120'), findsOneWidget);
    });
  });

  // @tanstack/charts 1.1.0 dist/renderer.js:159-177: on a render, the
  // pointer's focus is resolved again where it rests (:161-162), the
  // keyboard's and a pinned one are found by the point's key
  // (`restoreChartFocusPoint`, dist/interaction.js:33-47; a bar's key is its
  // x, dist/bar.js:69-73). Each test's data tells the three apart: the bar
  // under the pointer, the bar with the key and the bar at the old index
  // differ.
  group('TanStack', () {
    Future<(TestSurfaces, BarScene)> pump(
      WidgetTester tester,
      List<String> xs,
    ) async {
      final surfaces = await _chart(
        tester,
        {
          'component': 'BarChart',
          'data': {'@path': '/rows'},
        },
        theme: _playground,
        data: {'rows': rowsOf(xs)},
      );
      return (surfaces, _scene<BarScene>(tester));
    }

    TestGesture? mouse;
    Future<Offset> hover(WidgetTester tester, BarScene scene, int bar) async {
      final local = Offset(scene.points[bar].x, scene.size.height / 2);
      final gesture = mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(_plotTopLeft(tester) + local);
      await tester.pump();
      return local;
    }

    // A click where the mouse rests: TanStack pins its point
    // (dist/renderer.js:569-618).
    Future<void> click(WidgetTester tester, Offset local) async {
      await mouse!.down(_plotTopLeft(tester) + local);
      await mouse!.up();
      await tester.pumpAndSettle();
    }

    String? titleAt(WidgetTester tester, Offset local) {
      final scene = _scene<BarScene>(tester);
      final focus = scene.focusAt(local);
      return focus == null ? null : scene.tooltipOf(focus)!.title;
    }

    testWidgets('a hover as rows shrink: the bar now under the pointer', (
      tester,
    ) async {
      final (surfaces, scene) = await pump(tester, ['A', 'B', 'C']);
      final local = await hover(tester, scene, 2);
      await tester.pumpAndSettle();
      expect(tooltipTitle('C'), findsOneWidget);
      surfaces.setData('/rows', rowsOf(['A', 'B']));
      await tester.pumpAndSettle();
      expect(titleAt(tester, local), 'B');
      expect(tooltipTitle('B'), findsOneWidget);
    });

    testWidgets('a hover as a row is put first: the bar now under the '
        'pointer', (tester) async {
      final (surfaces, scene) = await pump(tester, ['A', 'B', 'C']);
      final local = await hover(tester, scene, 0);
      await tester.pumpAndSettle();
      expect(tooltipTitle('A'), findsOneWidget);
      surfaces.setData('/rows', rowsOf(['Z', 'A', 'B', 'C']));
      await tester.pumpAndSettle();
      expect(titleAt(tester, local), 'Z');
      expect(tooltipTitle('Z'), findsOneWidget);
    });

    testWidgets('the keyboard as rows shrink: the point by its key', (
      tester,
    ) async {
      final (surfaces, _) = await pump(tester, ['A', 'B', 'C']);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tooltipTitle('B'), findsOneWidget);
      // B moves from index 1 to 0; C takes index 1.
      surfaces.setData('/rows', rowsOf(['B', 'C']));
      await tester.pumpAndSettle();
      expect(tooltipTitle('B'), findsOneWidget);
    });

    testWidgets('a pin as rows shrink: the point by its key', (tester) async {
      final (surfaces, scene) = await pump(tester, ['A', 'B', 'C', 'D']);
      final local = await hover(tester, scene, 2);
      await click(tester, local);
      expect(tooltipTitle('C'), findsOneWidget);
      surfaces.setData('/rows', rowsOf(['C', 'D']));
      await tester.pumpAndSettle();
      // Under the pointer now: D; at C's old index: nothing.
      expect(titleAt(tester, local), 'D');
      expect(tooltipTitle('C'), findsOneWidget);
    });

    testWidgets('a pin as a row is put first: the point by its key', (
      tester,
    ) async {
      final (surfaces, scene) = await pump(tester, ['A', 'B', 'C']);
      final local = await hover(tester, scene, 0);
      await click(tester, local);
      expect(tooltipTitle('A'), findsOneWidget);
      surfaces.setData('/rows', rowsOf(['Z', 'A', 'B', 'C']));
      await tester.pumpAndSettle();
      // Under the pointer now, and at A's old index: Z.
      expect(titleAt(tester, local), 'Z');
      expect(tooltipTitle('A'), findsOneWidget);
    });
  });
}

// CR2. recharts 3.10.1: the value axis keeps only finite numbers
// (es6/state/selectors/axisSelectors.js:383-391, `makeNumber`); a stacked
// one leaves out a series whose least or greatest is not finite
// (es6/util/ChartUtils.js:443-470); an infinite value scales to NaN, so its
// bar is dropped (Bar.js:618-620, :667; Rectangle.js:143-145), its point is
// a gap (Curve.js:42-43) with no dot (Dot.js:23) or label (Text.js:234-236),
// its scatter point is not drawn (ChartUtils.js:396-401, Symbols.js:101),
// and a pie's slices get NaN angles from it (Pie.js:351-385). The
// playground drops every row whose number is not finite before TanStack
// sees it (chart-kit.tsx:18-19, `isNum`).
void _nonFiniteTests() {
  group('non-finite and odd values (CR2)', () {
    Map<String, Object?> cartesian(String type, Object? odd) => {
      'component': 'Chart',
      'xKey': 'k',
      'series': ['v', 'w'],
      'showDots': true,
      'showValueLabels': true,
      ...switch (type) {
        'bar-horizontal' => {'chartType': 'bar', 'layout': 'horizontal'},
        'bar-stacked' => {'chartType': 'bar', 'stacked': true},
        'line-horizontal' => {'chartType': 'line', 'layout': 'horizontal'},
        'area-stacked' => {'chartType': 'area', 'stacked': true},
        _ => {'chartType': type},
      },
      'data': [
        {'k': 'a', 'v': 1, 'w': 2},
        _row({'k': 'b', 'v': odd, 'w': 3}),
        _row({'k': 'c', 'v': 3, 'w': odd}),
      ],
    };

    for (final type in [
      'bar',
      'bar-horizontal',
      'bar-stacked',
      'line',
      'line-horizontal',
      'area',
      'area-stacked',
      'scatter',
    ]) {
      testWidgets('the standard Chart ($type) takes every odd value', (
        tester,
      ) async {
        final problems = <String>[];
        for (final MapEntry(key: name, value: odd) in _odd.entries) {
          await _chart(tester, cartesian(type, odd));
          if (tester.takeException() case final e?) problems.add('$name: $e');
          for (final p in await _interact(tester)) {
            problems.add('$name: $p');
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }
        expect(problems, isEmpty);
      });
    }

    for (final type in ['pie', 'donut']) {
      testWidgets('the standard Chart ($type) takes every odd value', (
        tester,
      ) async {
        final problems = <String>[];
        for (final MapEntry(key: name, value: odd) in _odd.entries) {
          await _chart(tester, {
            'component': 'Chart',
            'chartType': type,
            'xKey': 'n',
            'series': ['v'],
            'showValueLabels': true,
            'cornerRadius': 4,
            'data': [
              {'n': 'a', 'v': 1},
              _row({'n': 'b', 'v': odd}),
              {'n': 'c', 'v': 3},
            ],
          });
          if (tester.takeException() case final e?) problems.add('$name: $e');
          for (final p in await _interact(tester)) {
            problems.add('$name: $p');
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }
        expect(problems, isEmpty);
      });
    }

    for (final layout in ['vertical', 'horizontal']) {
      testWidgets('an infinite bar ($layout) is not drawn; the axis is the '
          "finite values', as with null", (tester) async {
        Map<String, Object?> props(Object? odd) => {
          'component': 'Chart',
          'xKey': 'k',
          'series': ['v'],
          'showValueLabels': true,
          'layout': layout,
          // From 0, so the bar of 1 is not the domain's floor (a 0px bar).
          'yAxis': {'min': 0},
          'data': [
            {'k': 'a', 'v': 1},
            {'k': 'b', 'v': odd},
            {'k': 'c', 'v': 3},
          ],
        };
        await _chart(tester, props(null));
        final ticks = _scene<RechartsScene>(tester).valueTicks;
        expect(ticks, isNotEmpty);
        for (final odd in [
          double.infinity,
          double.negativeInfinity,
          'Infinity',
          '1e999',
        ]) {
          await _chart(tester, props(odd));
          final scene = _scene<RechartsScene>(tester);
          expect(scene.valueTicks, ticks, reason: '$odd');
          expect(
            [
              for (final m in scene.marks)
                if (m.kind == 'bar') m.value,
            ],
            [1, 3],
            reason: '$odd',
          );
          // No label for it either: Text draws nothing at NaN.
          expect(
            [for (final l in scene.labels) l.text],
            ['1', '3'],
            reason: '$odd',
          );
        }
      });
    }

    // ChartUtils.js:443-470: one infinite value in the bottom series
    // carries into the series above it (d3-shape src/offset/none.js:6), so
    // both are left out of the domain, which is then [0, 0] and its nice
    // ticks 0 to 4 (getNiceTickValues.js:126-127). The infinite bar runs
    // from its base to the domain's top (truncateByDomain, :210-230); the
    // one above it, [Infinity, Infinity], is clamped to nothing.
    testWidgets('a stacked infinite value leaves its series and those above '
        'it out of the axis; its bar runs to the top', (tester) async {
      await _chart(tester, {
        'component': 'Chart',
        'chartType': 'bar',
        'stacked': true,
        'xKey': 'k',
        'series': ['a', 'b'],
        'showLegend': false,
        'data': [
          {'k': 'x', 'a': 1, 'b': 2},
          {'k': 'y', 'a': double.infinity, 'b': 2},
        ],
      });
      final scene = _scene<RechartsScene>(tester);
      expect(scene.valueTicks, [0, 1, 2, 3, 4]);
      final bars = [
        for (final m in scene.marks)
          if (m.kind == 'bar') m,
      ];
      expect([for (final b in bars) b.value], [1, 3, 4]);
      final tall = bars.last;
      expect(tall.series, 'a');
      expect(tall.rect.top, closeTo(scene.plot.top, 1e-9));
      expect(tall.rect.bottom, closeTo(scene.plot.bottom, 1e-9));
    });

    // Line.js:509 keeps an infinite value's NaN point and Curve.js:42 makes
    // it a gap in either layout; in recharts' vertical layout (CopilotKit's
    // horizontal one) a point without a value is left out instead, so the
    // line runs past it (Line.js:525-527).
    testWidgets('a line breaks at an infinite value, and lying down runs '
        'past a missing one', (tester) async {
      Future<RechartsScene> line(String layout, Object? odd) async {
        await _chart(tester, {
          'component': 'Chart',
          'chartType': 'line',
          'layout': layout,
          'showDots': true,
          'xKey': 'k',
          'series': ['v'],
          'data': [
            {'k': 'a', 'v': 1},
            {'k': 'b', 'v': odd},
            {'k': 'c', 'v': 3},
          ],
        });
        return _scene<RechartsScene>(tester);
      }

      for (final layout in ['vertical', 'horizontal']) {
        final broken = await line(layout, double.infinity);
        expect(broken.linePaths, hasLength(2), reason: layout);
        // A dot for each finite point only (Dot.js:23).
        expect(
          broken.marks.where((m) => m.kind == 'dot'),
          hasLength(2),
          reason: layout,
        );
      }
      expect((await line('vertical', 'NaN')).linePaths, hasLength(2));
      expect((await line('horizontal', 'NaN')).linePaths, hasLength(1));
      // The tooltip still reads the row's own value.
      await line('vertical', double.infinity);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final scene = _scene<RechartsScene>(tester);
      await gesture.moveTo(
        _plotTopLeft(tester) + Offset(scene.plot.center.dx, scene.plot.top),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('v : Infinity'), findsOneWidget);
    });

    testWidgets('a scatter point with an infinite value is not drawn', (
      tester,
    ) async {
      await _chart(tester, {
        'component': 'Chart',
        'chartType': 'scatter',
        'xKey': 'k',
        'series': ['v'],
        'data': [
          {'k': 'a', 'v': 1},
          {'k': 'b', 'v': double.infinity},
          {'k': 'c', 'v': 3},
        ],
      });
      final scene = _scene<RechartsScene>(tester);
      expect([for (final m in scene.marks) m.value], [1, 3]);
    });

    // Pie.js:351-385: an infinite value makes the sum infinite, the finite
    // slices 0° wide and its own share NaN, and every later slice starts
    // at NaN; none is drawn. The labels of the 0° slices before it are
    // still drawn (their angle is finite), the later ones are not
    // (Text.js:234-236).
    testWidgets('a pie with an infinite value draws no slice', (tester) async {
      await _chart(tester, {
        'component': 'Chart',
        'chartType': 'pie',
        'xKey': 'n',
        'series': ['v'],
        'showValueLabels': true,
        'showLegend': false,
        'data': [
          {'n': 'a', 'v': 1},
          {'n': 'b', 'v': double.infinity},
          {'n': 'c', 'v': 3},
        ],
      });
      final scene = _scene<RechartsPieScene>(tester);
      expect(scene.slices, hasLength(3));
      expect(scene.innerOutlineBox, isNull);
      expect([for (final l in scene.labels) l.text], ['1']);
      for (final slice in scene.slices) {
        expect(
          tester.renderObject(find.byType(ChartPlot)),
          isNot(paints..something(paintedPath(color: slice.color))),
        );
      }
      // RC4: the keyboard reaches its row. Its place is NaN, so recharts
      // writes `translate(NaNpx, NaNpx)` (translate.js:31-64,
      // TooltipBoundingBox.js:74-91), which CSSOM drops (`setProperty`
      // returns on a value that doesn't parse): the box stays where row a
      // put it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('a : 1'), findsOneWidget);
      final shownAt = tester.getTopLeft(find.byType(RechartsTooltip));
      expect(shownAt, isNot(_plotTopLeft(tester)));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('b : Infinity'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(RechartsTooltip)), shownAt);
    });

    // RC4, the other case: a box that never had a place sits at its
    // wrapper's top left (no `transform` yet).
    testWidgets("a pie's first tooltip at a NaN place sits at the top left", (
      tester,
    ) async {
      await _chart(tester, {
        'component': 'Chart',
        'chartType': 'pie',
        'xKey': 'n',
        'series': ['v'],
        'showLegend': false,
        'data': [
          {'n': 'b', 'v': double.infinity},
          {'n': 'c', 'v': 3},
        ],
      });
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('b : Infinity'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(RechartsTooltip)),
        _plotTopLeft(tester),
      );
    });

    // isDomainSpecifiedByUser.js:134-136, :179-186: `isNumber(Infinity)`
    // takes it, the domain is not well formed, so the axis has none: no
    // ticks and no marks.
    testWidgets('a yAxis min of 1e999 leaves the chart without a value axis', (
      tester,
    ) async {
      await _chart(tester, {
        'component': 'Chart',
        'xKey': 'week',
        'yAxis': {'min': double.infinity},
        'data': _signups,
      });
      final scene = _scene<RechartsScene>(tester);
      expect(scene.valueTicks, isEmpty);
      expect(scene.marks, isEmpty);
    });

    for (final (component, fields) in [
      ('LineChart', ('x', 'y')),
      ('AreaChart', ('x', 'y')),
      ('BarChart', ('x', 'y')),
      ('ScatterChart', ('x', 'y')),
      ('PieChart', ('label', 'value')),
    ]) {
      testWidgets('the playground $component drops a row whose number is '
          'not finite', (tester) async {
        final (xField, yField) = fields;
        Map<String, Object?> row(Object? x, Object? y) =>
            _row({xField: x, yField: y});
        final xs = component == 'ScatterChart' ? [1, 2, 3] : ['A', 'B', 'C'];
        await _chart(tester, {
          'component': component,
          'data': [row(xs[0], 1), row(xs[2], 3)],
        }, theme: _playground);
        final expected = _scene<TanstackScene>(tester).points.length;
        expect(expected, greaterThan(0));
        final problems = <String>[];
        for (final MapEntry(key: name, value: odd) in _odd.entries) {
          await _chart(tester, {
            'component': component,
            'data': [row(xs[0], 1), row(xs[1], odd), row(xs[2], 3)],
          }, theme: _playground);
          if (tester.takeException() case final e?) problems.add('$name: $e');
          final scenes = _scenes(tester).whereType<TanstackScene>();
          if (odd is! num) {
            // Text, null or nothing where the catalog's schema asks a
            // number: the payload is refused, no chart is drawn.
            if (scenes.isNotEmpty) problems.add('$name: a chart was drawn');
          } else if (scenes.isEmpty) {
            problems.add('$name: no chart');
          } else if (scenes.first.points.length != expected) {
            problems.add('$name: the row was drawn');
          }
          for (final p in await _interact(tester)) {
            problems.add('$name: $p');
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }
        expect(problems, isEmpty);
      });
    }

    testWidgets('the playground Sparkline drops a value that is not finite', (
      tester,
    ) async {
      await _chart(tester, {
        'component': 'Sparkline',
        'label': 'MRR',
        'values': [1, 3],
      }, theme: _playground);
      final expected = _scene<TanstackScene>(tester).points.length;
      final problems = <String>[];
      for (final MapEntry(key: name, value: odd) in _odd.entries) {
        await _chart(tester, {
          'component': 'Sparkline',
          'label': 'MRR',
          'values': [1, if (!identical(odd, _missing)) odd, 3],
        }, theme: _playground);
        if (tester.takeException() case final e?) problems.add('$name: $e');
        final scenes = _scenes(tester).whereType<TanstackScene>();
        if (odd is! num && !identical(odd, _missing)) {
          // Text or null where the catalog's schema asks a number: the
          // payload is refused, no chart is drawn.
          if (scenes.isNotEmpty) problems.add('$name: a chart was drawn');
        } else if (scenes.isEmpty) {
          problems.add('$name: no chart');
        } else if (scenes.first.points.length != expected) {
          problems.add('$name: the value was drawn');
        }
        for (final p in await _interact(tester)) {
          problems.add('$name: $p');
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
      expect(problems, isEmpty);
    });
  });
}

void _interactionTests() {
  group('keys, presses and the pointer (CR4, CR5, CR12, CR13, CR14)', () {
    // CR4, RC2, RR2-4, RR2-12 (RULEBOOK section 2): recharts acts on Left,
    // Right and Enter and leaves every other key alone
    // (keyboardEventsMiddleware.js:39-112), and prevents none
    // (RechartsWrapper.js:274-276), so each keeps the browser's default:
    // the arrows and Page Up/Down scroll the page and the focus stays;
    // Enter on an `<svg>` does nothing. On the web Flutter's web shortcuts
    // scroll (the key is `ignored`); off the web the plot scrolls itself
    // and keeps the key, where the default shortcuts would move the focus.
    for (final web in [true, false]) {
      testWidgets('the keys scroll the page and keep the focus '
          '(${web ? 'on the web' : 'off the web'})', (tester) async {
        debugKitIsWebOverride = web;
        addTearDown(() => debugKitIsWebOverride = null);
        final surfaces = TestSurfaces()
          ..create([
            {
              'id': 'root',
              'component': 'Chart',
              'xKey': 'week',
              'showLegend': false,
              'data': _signups,
            },
          ]);
        addTearDown(surfaces.dispose);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final after = FocusNode(debugLabel: 'after');
        addTearDown(after.dispose);
        await tester.pumpWidget(
          MaterialApp(
            shortcuts: web
                ? {
                    // WidgetsApp's `_defaultWebShortcuts` for these keys.
                    ...WidgetsApp.defaultShortcuts,
                    const SingleActivator(LogicalKeyboardKey.arrowUp):
                        const ScrollIntent(direction: AxisDirection.up),
                    const SingleActivator(LogicalKeyboardKey.arrowDown):
                        const ScrollIntent(direction: AxisDirection.down),
                    const SingleActivator(LogicalKeyboardKey.arrowLeft):
                        const ScrollIntent(direction: AxisDirection.left),
                    const SingleActivator(LogicalKeyboardKey.arrowRight):
                        const ScrollIntent(direction: AxisDirection.right),
                    const SingleActivator(
                      LogicalKeyboardKey.pageDown,
                    ): const ScrollIntent(
                      direction: AxisDirection.down,
                      type: ScrollIncrementType.page,
                    ),
                  }
                : WidgetsApp.defaultShortcuts,
            theme: ThemeData(extensions: [_standard]),
            home: Scaffold(
              body: PrimaryScrollController(
                controller: controller,
                child: SingleChildScrollView(
                  primary: true,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 360,
                        child: A2uiSurface(surface: surfaces.surface),
                      ),
                      // Where an arrow's `DirectionalFocusIntent` would go.
                      Focus(
                        focusNode: after,
                        child: const SizedBox(width: 360, height: 40),
                      ),
                      const SizedBox(height: 3000),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(_focused(), 'chart');
        expect(find.text('signups : 120'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(0));
        // The chart keeps the focus and its tooltip.
        expect(_focused(), 'chart');
        expect(find.text('signups : 120'), findsOneWidget);
        final down = controller.offset;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(controller.offset, lessThan(down));
        // ArrowRight steps the tooltip and keeps the focus.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(_focused(), 'chart');
        expect(find.text('signups : 164'), findsOneWidget);
        // Page Down scrolls a page.
        final before = controller.offset;
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(before + 100));
        expect(_focused(), 'chart');
        // Enter hides the tooltip; the focus stays.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(_focused(), 'chart');
        expect(find.byType(RechartsTooltip), findsNothing);
      });
    }

    // On the web the key goes on to the app's shortcuts, whatever they map
    // it to: the plot never scrolls itself there.
    testWidgets("on the web an arrow goes on to the app's own shortcut", (
      tester,
    ) async {
      debugKitIsWebOverride = true;
      addTearDown(() => debugKitIsWebOverride = null);
      final surfaces = TestSurfaces()
        ..create([
          {
            'id': 'root',
            'component': 'Chart',
            'xKey': 'week',
            'showLegend': false,
            'data': _signups,
          },
        ]);
      addTearDown(surfaces.dispose);
      var marked = 0;
      await tester.pumpWidget(
        MaterialApp(
          shortcuts: {
            ...WidgetsApp.defaultShortcuts,
            const SingleActivator(LogicalKeyboardKey.arrowDown):
                const _MarkIntent(),
          },
          actions: {
            ...WidgetsApp.defaultActions,
            _MarkIntent: CallbackAction<_MarkIntent>(onInvoke: (_) => marked++),
          },
          theme: ThemeData(extensions: [_standard]),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: A2uiSurface(surface: surfaces.surface),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_focused(), 'chart');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(marked, 1);
    });

    _browserScrollKeyTests();

    // RR3-3, P6: an `<svg>` has no default for Enter, and recharts prevents
    // nothing, so the key stops at the chart: the app's own Enter shortcut
    // (`ButtonActivateIntent` on the web, `ActivateIntent` off it) is not
    // the browser's.
    testWidgets("Enter on a recharts chart does not reach the app's Enter "
        'shortcut', (tester) async {
      final surfaces = TestSurfaces()
        ..create([
          {'id': 'root', ..._barChart},
        ]);
      addTearDown(surfaces.dispose);
      var marked = 0;
      await tester.pumpWidget(
        MaterialApp(
          shortcuts: {
            ...WidgetsApp.defaultShortcuts,
            const SingleActivator(LogicalKeyboardKey.enter):
                const _MarkIntent(),
          },
          actions: {
            ...WidgetsApp.defaultActions,
            _MarkIntent: CallbackAction<_MarkIntent>(onInvoke: (_) => marked++),
          },
          theme: ThemeData(extensions: [_standard]),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: A2uiSurface(surface: surfaces.surface),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_focused(), 'chart');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(marked, 0);
      // Enter still acts for recharts: the tooltip goes.
      expect(find.byType(RechartsTooltip), findsNothing);
    });

    // CR5: @tanstack/charts 1.1.0 dist/svg-renderer.js:25 (`<svg
    // tabindex=0>`), dist/adapter-shared.js:10-12; the browser focuses it on
    // mousedown, and `handleFocus` keeps the pointer's point
    // (dist/renderer.js:671-692), from which the arrows step.
    testWidgets('a click on a TanStack chart gives it the keyboard focus, '
        'and the arrows step from the clicked point', (tester) async {
      await _chart(tester, {
        'component': 'LineChart',
        'data': [
          for (final (i, y) in [3, 7, 4, 9].indexed) {'x': 'P$i', 'y': y},
        ],
      }, theme: _playground);
      await tester.pumpAndSettle();
      final scene = _scene<LineAreaScene>(tester);
      final p1 = scene.points[1];
      final at = _plotTopLeft(tester) + Offset(p1.x, p1.y);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: at);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(at);
      await tester.pump();
      await gesture.down(at);
      await tester.pump();
      expect(_focused(), 'chart');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(PlaygroundChartTooltip), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PlaygroundChartTooltip),
          matching: find.text('P1'),
        ),
        findsOneWidget,
      );
      // The click pinned P1 (dist/renderer.js:569-618); Enter unpins, and
      // ArrowRight steps to P2.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(PlaygroundChartTooltip),
          matching: find.text('P2'),
        ),
        findsOneWidget,
      );
    });

    // CR12 (M21): dist/renderer.js:539-547, `clearPointerFocus` only clears
    // a focus the pointer owns.
    testWidgets('a mouse leaving a TanStack chart whose focus the keyboard '
        'moved keeps it', (tester) async {
      await _chart(tester, {
        'component': 'LineChart',
        'data': [
          for (final (i, y) in [3, 7, 4, 9].indexed) {'x': 'P$i', 'y': y},
        ],
      }, theme: _playground);
      await tester.pumpAndSettle();
      final scene = _scene<LineAreaScene>(tester);
      final p1 = scene.points[1];
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(_plotTopLeft(tester) + Offset(p1.x, p1.y));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      Finder tooltipText(String text) => find.descendant(
        of: find.byType(PlaygroundChartTooltip),
        matching: find.text(text),
      );
      expect(tooltipText('P2'), findsOneWidget);
      await gesture.moveTo(const Offset(5000, 5000));
      await tester.pumpAndSettle();
      expect(tooltipText('P2'), findsOneWidget);
    });

    // CR14: a press on the element that already has the focus fires no
    // blur and no focus, so recharts' keyboard tooltip stays
    // (keyboardEventsMiddleware.js:164-181 would hide it on a blur).
    testWidgets('a press on a slice of a pie whose group has the focus keeps '
        'the keyboard tooltip', (tester) async {
      await _chart(tester, {
        'component': 'Chart',
        'chartType': 'pie',
        'xKey': 'n',
        'showLegend': false,
        'data': [
          {'n': 'a', 'v': 1},
          {'n': 'b', 'v': 1},
        ],
      });
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_focused(), 'chart item group');
      expect(find.text('b : 1'), findsOneWidget);
      final scene = _scene<RechartsPieScene>(tester);
      // A point inside slice a, halfway out along its middle angle.
      final a = scene.slices.first;
      final inside =
          scene.center +
          Offset.fromDirection(
            -a.midAngle * 3.141592653589793 / 180,
            scene.outerRadius / 2,
          );
      expect(scene.focusAt(inside), isNotNull);
      final at = _plotTopLeft(tester) + inside;
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: at);
      addTearDown(gesture.removePointer);
      await gesture.down(at);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_focused(), 'chart item group');
      await gesture.moveTo(const Offset(5000, 5000));
      await tester.pumpAndSettle();
      // The keyboard interaction is still active at index 1.
      expect(find.text('b : 1'), findsOneWidget);
    });

    // The review's traversal probe: each chart's tab stops (recharts'
    // `<svg>`, the pie's `<g>`, TanStack's `<svg>`) in order, then on to
    // the next field, and back: no trap, no stop skipped.
    for (final (name, chart, stops) in [
      (
        'a recharts pie',
        <String, Object?>{
          'component': 'Chart',
          'chartType': 'pie',
          'xKey': 'n',
          'data': [
            {'n': 'a', 'v': 1},
            {'n': 'b', 'v': 2},
          ],
        },
        ['chart', 'chart item group'],
      ),
      (
        'a recharts bar chart',
        <String, Object?>{
          'component': 'Chart',
          'xKey': 'n',
          'data': [
            {'n': 'a', 'v': 1},
            {'n': 'b', 'v': 2},
          ],
        },
        ['chart'],
      ),
      (
        'a TanStack line chart',
        <String, Object?>{
          'component': 'LineChart',
          'data': [
            {'x': 'a', 'y': 1},
            {'x': 'b', 'y': 2},
          ],
        },
        ['chart'],
      ),
    ]) {
      testWidgets('Tab and Shift+Tab pass through $name', (tester) async {
        await pumpComponents(tester, theme: _standard, [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['before', 'chart', 'after'],
          },
          {'id': 'before', 'component': 'TextField', 'label': 'Before'},
          {'id': 'chart', ...chart},
          {'id': 'after', 'component': 'TextField', 'label': 'After'},
        ]);
        await tester.pumpAndSettle();
        final forward = <String?>[];
        for (var i = 0; i < stops.length + 2; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          forward.add(_focused());
        }
        final backward = <String?>[];
        for (var i = 0; i < stops.length + 1; i++) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pumpAndSettle();
          backward.add(_focused());
        }
        expect(forward.sublist(1, 1 + stops.length), stops);
        expect(forward.last, isNot(anyOf(stops.map(equals).toList())));
        expect(backward.sublist(0, stops.length), stops.reversed.toList());
        expect(tester.takeException(), isNull);
      });
    }

    // CR13 (M22): Rectangle.js:37-49, a corner is at most half the bar's
    // width or height; Chart.tsx:317-325 asks 4px.
    testWidgets('a bar shorter than 8px rounds its corners by half its '
        'height', (tester) async {
      await _chart(tester, {
        'component': 'Chart',
        'xKey': 'k',
        'series': ['v'],
        'showLegend': false,
        'yAxis': {'min': 0, 'max': 100},
        'data': [
          {'k': 'a', 'v': 3},
          {'k': 'b', 'v': 100},
        ],
      });
      final scene = _scene<RechartsScene>(tester);
      final short = scene.marks.firstWhere((m) => m.value == 3).rect;
      expect(short.height, lessThan(8));
      expect(short.height, greaterThan(2));
      final r = Radius.circular(short.height / 2);
      expect(
        tester.renderObject(find.byType(ChartPlot)),
        paints..something(
          paintedRRect(
            rrect: RRect.fromRectAndCorners(short, topLeft: r, topRight: r),
          ),
        ),
      );
      final tall = scene.marks.firstWhere((m) => m.value == 100).rect;
      const four = Radius.circular(4);
      expect(
        tester.renderObject(find.byType(ChartPlot)),
        paints..something(
          paintedRRect(
            rrect: RRect.fromRectAndCorners(
              tall,
              topLeft: four,
              topRight: four,
            ),
          ),
        ),
      );
    });
  });
}

/// RC3-6, RR3-2 (RULEBOOK section 2, the interaction row): the browser's
/// scroll keys on a focused `<svg>`, from Chromium 159.0.8154.13
/// (`keyboard_event_manager.cc`: `MapKeyCodeForScroll`, :67-188;
/// `DefaultSpaceEventHandler`, :493-525; `DefaultNavigationKeyEventHandler`,
/// :527-573; `scroll_manager.cc`: the scroll chain by axis, :98-190, the
/// first box that scrolls, :192-333), on the web path and off it. recharts
/// prevents no key (RechartsWrapper.js:274-276), so each keeps its default.
void _browserScrollKeyTests() {
  for (final web in [true, false]) {
    final where = web ? 'on the web' : 'off the web';

    testWidgets('End and Ctrl+End scroll to the bottom, $where', (
      tester,
    ) async {
      final page = await _pumpOnPage(tester, _barChart, web: web);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(_focused(), 'chart');
      expect(page.offset, page.position.maxScrollExtent);
      page.jumpTo(1000);
      await tester.pump();
      await _withModifier(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.end,
      );
      await tester.pumpAndSettle();
      expect(page.offset, page.position.maxScrollExtent);
    });

    testWidgets('Home and Ctrl+Home scroll to the top, $where', (tester) async {
      final page = await _pumpOnPage(tester, _barChart, web: web);
      expect(page.offset, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(_focused(), 'chart');
      expect(page.offset, 0);
      page.jumpTo(1000);
      await tester.pump();
      await _withModifier(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.home,
      );
      await tester.pumpAndSettle();
      expect(page.offset, 0);
    });

    testWidgets('Space pages down and Shift+Space up, $where', (tester) async {
      final page = await _pumpOnPage(tester, _barChart, web: web);
      final at = page.offset;
      expect(at, greaterThan(100));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(_focused(), 'chart');
      expect(page.offset, greaterThan(at + 100));
      final down = page.offset;
      await _withModifier(
        tester,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.space,
      );
      await tester.pumpAndSettle();
      expect(_focused(), 'chart');
      expect(page.offset, lessThan(down - 100));
    });

    // Shift or Meta stops every key (:72-74), Ctrl all but Home and End
    // (:110-120), Alt every arrow, Home and End (a system key, :551-552)
    // and Space (:498). Off the web, Flutter's own Ctrl+arrow scroll
    // (app.dart:1285-1297) is not the browser's either.
    for (final (modifier, key) in [
      (LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.arrowDown),
      (LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.arrowDown),
      (LogicalKeyboardKey.altLeft, LogicalKeyboardKey.arrowDown),
      (LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.pageDown),
      (LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.end),
      (LogicalKeyboardKey.altLeft, LogicalKeyboardKey.end),
      (LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.space),
    ]) {
      testWidgets('${modifier.keyLabel}+${key.keyLabel} scrolls nothing, '
          '$where', (tester) async {
        final page = await _pumpOnPage(tester, _barChart, web: web);
        final at = page.offset;
        await _withModifier(tester, modifier, key);
        await tester.pumpAndSettle();
        expect(_focused(), 'chart');
        expect(page.offset, at);
      });
    }

    // The scroll chain holds only boxes that scroll on the key's axis
    // (`CanScroll`, scroll_manager.cc:148-190): a horizontal scroll view
    // round the chart is passed over for ArrowDown. Flutter's ScrollAction
    // takes the nearest scrollable of any axis and does nothing off its
    // axis (scrollable_helpers.dart:452-459, :463).
    testWidgets('ArrowDown in a horizontal scroll view scrolls the page, '
        '$where', (tester) async {
      final page = await _pumpOnPage(
        tester,
        _barChart,
        web: web,
        wrap: (chart) => SizedBox(
          width: 360,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: 600, child: chart),
          ),
        ),
      );
      final at = page.offset;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_focused(), 'chart');
      expect(page.offset, closeTo(at + 50, 1e-6));
    });

    // The first box of the chain that scrolls takes the key; one at its end
    // passes it on (`LogicalScroll`, scroll_manager.cc:192-314).
    testWidgets('ArrowDown scrolls the inner scroll view, then, at its end, '
        'the page, $where', (tester) async {
      final inner = ScrollController();
      addTearDown(inner.dispose);
      final page = await _pumpOnPage(
        tester,
        _barChart,
        web: web,
        wrap: (chart) => SizedBox(
          height: 200,
          child: SingleChildScrollView(
            controller: inner,
            child: Column(children: [chart, const SizedBox(height: 300)]),
          ),
        ),
      );
      final at = page.offset;
      final innerAt = inner.offset;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(inner.offset, closeTo(innerAt + 50, 1e-6));
      expect(page.offset, at);
      inner.jumpTo(inner.position.maxScrollExtent);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_focused(), 'chart');
      expect(inner.offset, inner.position.maxScrollExtent);
      expect(page.offset, closeTo(at + 50, 1e-6));
    });

    // TanStack prevents the keys it acts on (dist/renderer.js:619-670): the
    // arrows, Home and End move the focus, Space pins; Page Down it leaves
    // alone, so the page scrolls (RR3-3, P8).
    testWidgets('TanStack: what it acts on scrolls nothing, Page Down '
        'scrolls, $where', (tester) async {
      final page = await _pumpOnPage(
        tester,
        {
          'component': 'LineChart',
          'data': [
            for (final (i, y) in [3, 7, 4, 9].indexed) {'x': 'P$i', 'y': y},
          ],
        },
        web: web,
        theme: _playground,
      );
      final at = page.offset;
      for (final key in [
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.end,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.space,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(_focused(), 'chart', reason: key.keyLabel);
        expect(page.offset, at, reason: key.keyLabel);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(_focused(), 'chart');
      expect(page.offset, greaterThan(at + 100));
    });
  }

  // On the web Flutter's Space is `PrioritizedIntents` with
  // `ActivateIntent` first (app.dart:1310-1315): the browser's Space on an
  // `<svg>` scrolls, whatever an ancestor does with activation.
  testWidgets('on the web Space scrolls the page, never activating an '
      'ancestor', (tester) async {
    var activated = 0;
    final page = await _pumpOnPage(
      tester,
      _barChart,
      web: true,
      wrap: (chart) => Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => activated++,
          ),
        },
        child: chart,
      ),
    );
    final at = page.offset;
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(activated, 0);
    expect(page.offset, greaterThan(at + 100));
  });
}

// CR16, INV-049: recharts sets no focus style (no `outline` in its es6/
// files; RootSurface.js:40-59 gives the `<svg>` its tabIndex, Pie.js:594-596
// the `<g>`), nor TanStack Charts (dist/svg-renderer.js:25), so the user
// agent's outline shows on `:focus-visible`, in CopilotKit's
// `outline-ring/50` (react-core src/v2/styles/globals.css:144-146).
void _outlineTests() {
  group("the browser's focus outline (CR16)", () {
    Finder ringAt(Rect box) => find.byWidgetPredicate(
      (widget) =>
          widget is Positioned &&
          widget.child is IgnorePointer &&
          (widget.child as IgnorePointer).child is FocusRing &&
          widget.left == box.left &&
          widget.top == box.top &&
          widget.width == box.width &&
          widget.height == box.height,
    );

    // RC1, RR2-3: `:focus-visible` by Chrome's heuristic (Selectors 4, 9.4):
    // focus a pointer press gave shows no ring until a key is pressed while
    // the element holds it, whatever Flutter's highlight mode (a mouse
    // leaves it `traditional`, as on desktop and the web).
    for (final (name, props, theme, target) in [
      (
        "recharts' svg",
        <String, Object?>{
          'component': 'Chart',
          'xKey': 'week',
          'showLegend': false,
          'data': _signups,
        },
        _standard,
        'chart',
      ),
      (
        "the pie's group",
        <String, Object?>{
          'component': 'Chart',
          'chartType': 'pie',
          'xKey': 'n',
          'showLegend': false,
          'data': [
            {'n': 'a', 'v': 1},
            {'n': 'b', 'v': 2},
          ],
        },
        _standard,
        'chart item group',
      ),
      (
        "TanStack's svg",
        <String, Object?>{
          'component': 'LineChart',
          'data': [
            {'x': 'A', 'y': 1},
            {'x': 'B', 'y': 2},
          ],
        },
        _playground,
        'chart',
      ),
    ]) {
      for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
        testWidgets('a ${kind.name} press focuses $name with no ring, and a '
            'key then shows it', (tester) async {
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.alwaysTraditional;
          addTearDown(
            () => FocusManager.instance.highlightStrategy =
                FocusHighlightStrategy.automatic,
          );
          await _chart(tester, props, theme: theme);
          final at =
              tester.getTopLeft(find.byType(ChartPlot)) +
              switch (_scenes(tester).first) {
                // Halfway out along slice a's middle angle.
                final RechartsPieScene pie =>
                  pie.center +
                      Offset.fromDirection(
                        -pie.slices.first.midAngle * math.pi / 180,
                        pie.outerRadius / 2,
                      ),
                final scene => scene.size.center(Offset.zero),
              };
          final gesture = await tester.createGesture(kind: kind);
          await gesture.addPointer(location: at);
          addTearDown(gesture.removePointer);
          await gesture.down(at);
          await tester.pump();
          await gesture.up();
          await tester.pumpAndSettle();
          expect(_focused(), target);
          expect(
            FocusManager.instance.highlightMode,
            FocusHighlightMode.traditional,
          );
          expect(find.byType(FocusRing), findsNothing);
          // A key while it holds the focus: `:focus-visible` matches.
          await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pumpAndSettle();
          expect(_focused(), target);
          expect(find.byType(FocusRing), findsOneWidget);
          // Away, then back by Tab: the keyboard's focus shows it, the
          // press long over.
          FocusManager.instance.primaryFocus!.unfocus();
          await tester.pumpAndSettle();
          expect(find.byType(FocusRing), findsNothing);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(_focused(), 'chart');
          expect(find.byType(FocusRing), findsOneWidget);
        });
      }
    }

    testWidgets("the keyboard's focus rings the recharts svg, then the pie's "
        'group, round the tight box of its slices', (tester) async {
      await _chart(tester, {
        'component': 'Chart',
        'chartType': 'pie',
        'xKey': 'n',
        'showLegend': true,
        'data': [
          {'n': 'a', 'v': 1},
          {'n': 'b', 'v': 2},
        ],
      });
      expect(find.byType(FocusRing), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final scene = _scene<RechartsPieScene>(tester);
      // The svg is the chart's whole box, its legend included.
      expect(scene.outlineBox, Offset.zero & scene.chartSize);
      expect(scene.chartSize.height, greaterThan(scene.size.height));
      expect(ringAt(scene.outlineBox), findsOneWidget);
      // Offset 0, in the outline colour: a 2px stroke 1px outside.
      final ring = tester.renderObject(
        find.descendant(
          of: find.byType(FocusRing),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(
        ring,
        paints..something(
          paintedRRect(
            rrect: RRect.fromRectAndCorners(scene.outlineBox.inflate(1)),
            color: _standard.color(A2uiColorToken.outlineRing),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_focused(), 'chart item group');
      final group = scene.innerOutlineBox!;
      expect(ringAt(group), findsOneWidget);
      expect(find.byType(FocusRing), findsOneWidget);
      // RR2-2: the slices make a whole disc, so the group's box (`getBBox`,
      // tight) is the circle's, not its paths' control points.
      final disc = Rect.fromCircle(
        center: scene.center,
        radius: scene.outerRadius,
      );
      // Exactly (RC3-10: each arc's ends and the axis angles it sweeps).
      expect(group.left, closeTo(disc.left, 1e-9));
      expect(group.top, closeTo(disc.top, 1e-9));
      expect(group.right, closeTo(disc.right, 1e-9));
      expect(group.bottom, closeTo(disc.bottom, 1e-9));
      // Away: no ring.
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();
      expect(find.byType(FocusRing), findsNothing);
    });

    // RR2-9 (R19): a cartesian chart's svg is its whole box, the legend laid
    // over its foot, so its ring falls wholly outside the overflow box.
    testWidgets("a cartesian chart's svg ring is round the box with its "
        'legend', (tester) async {
      await _chart(tester, {
        'component': 'Chart',
        'xKey': 'week',
        'showLegend': true,
        'data': _signups,
      });
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final scene = _scene<RechartsScene>(tester);
      expect(scene.chartSize.height, greaterThan(scene.size.height));
      expect(scene.outlineBox, Offset.zero & scene.chartSize);
      expect(ringAt(Offset.zero & scene.chartSize), findsOneWidget);
    });

    // react-core src/v2/styles/globals.css:28, :65: `--ring` is
    // oklch(0.708 0 0) and, dark, oklch(0.556 0 0) (Tailwind's neutral-400
    // #a1a1a1 and neutral-500 #737373), at 50% (`outline-ring/50`,
    // :144-146). A playground surface keeps the app's `--ring`
    // (src/app/globals.css:53-54, :76, :114: alpha 50% and 60%), at 50%.
    test("the outline is CopilotKit's `outline-ring/50`", () {
      Color ring(A2uiKitTheme theme) => theme.color(A2uiColorToken.outlineRing);
      expect(ring(_standard).toARGB32(), 0x80a1a1a1);
      expect(
        ring(A2uiKitTheme.standard(Brightness.dark)).toARGB32(),
        0x80737373,
      );
      // oklch(0.5 0.2 292) is sRGB (106.7, 63.7, 200.6), at 25% (63.75 of
      // 255); oklch(0.72 0.17 292) is (168.4, 141.3, 255), at 30% (76.5,
      // which rounds up) (OKLab to linear sRGB, then the sRGB transfer, CSS
      // Color 4).
      expect(ring(_playground).toARGB32(), 0x406b40c9);
      expect(
        ring(A2uiKitTheme.playground(Brightness.dark)).toARGB32(),
        0x4da88dff,
      );
    });

    testWidgets('a touch that focuses the chart shows no outline', (
      tester,
    ) async {
      await _chart(tester, {
        'component': 'Chart',
        'xKey': 'week',
        'data': _signups,
      });
      final plot = tester.getRect(find.byType(ChartPlot));
      await tester.tapAt(plot.center);
      await tester.pumpAndSettle();
      expect(_focused(), 'chart');
      expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
      expect(find.byType(FocusRing), findsNothing);
    });

    // RC3-5 (RULEBOOK section 2, the focus outline): after a mouse press's
    // focus, Chromium 159.0.8154.13 counts a keydown towards
    // `:focus-visible` only with Ctrl, Alt and Meta all up
    // (keyboard_event_manager.cc:355-359; node.cc:3644-3660 sets the flag
    // `selector_checker.cc:3863-3902` reads), the modifier's own keydown
    // included; Shift and Escape count (the exclusion of modifiers and
    // Escape at :250-259 is the user-activation rule).
    for (final (name, ring, press)
        in <(String, bool, List<List<LogicalKeyboardKey>>)>[
          (
            'a plain key',
            true,
            [
              [LogicalKeyboardKey.keyA],
            ],
          ),
          (
            'Shift',
            true,
            [
              [LogicalKeyboardKey.shiftLeft],
            ],
          ),
          (
            'Escape',
            true,
            [
              [LogicalKeyboardKey.escape],
            ],
          ),
          (
            'Ctrl alone',
            false,
            [
              [LogicalKeyboardKey.controlLeft],
            ],
          ),
          (
            'Ctrl+C',
            false,
            [
              [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyC],
            ],
          ),
          (
            'Alt alone',
            false,
            [
              [LogicalKeyboardKey.altLeft],
            ],
          ),
          (
            'Meta alone',
            false,
            [
              [LogicalKeyboardKey.metaLeft],
            ],
          ),
        ]) {
      testWidgets(
        'after a mouse press, $name ${ring ? 'shows' : 'leaves '
                  'out'} the ring',
        (tester) async {
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.alwaysTraditional;
          addTearDown(
            () => FocusManager.instance.highlightStrategy =
                FocusHighlightStrategy.automatic,
          );
          await _chart(tester, _barChart);
          final at = tester.getRect(find.byType(ChartPlot)).center;
          final gesture = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await gesture.addPointer(location: at);
          addTearDown(gesture.removePointer);
          await gesture.down(at);
          await tester.pump();
          await gesture.up();
          await tester.pumpAndSettle();
          expect(_focused(), 'chart');
          expect(find.byType(FocusRing), findsNothing);
          for (final chord in press) {
            for (final key in chord) {
              await tester.sendKeyDownEvent(key);
            }
            for (final key in chord.reversed) {
              await tester.sendKeyUpEvent(key);
            }
          }
          await tester.pumpAndSettle();
          expect(_focused(), 'chart');
          expect(find.byType(FocusRing), ring ? findsOneWidget : findsNothing);
        },
      );
    }

    // RR3-3, P4: a press the system cancels (a scroll that takes the touch)
    // ends the press, so the keyboard's focus after it shows the ring.
    testWidgets('a press the system cancels: the keyboard focus that follows '
        'shows the ring', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await _chart(tester, _barChart);
      final at = tester.getRect(find.byType(ChartPlot)).center;
      final gesture = await tester.createGesture();
      await gesture.down(at);
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(_focused(), 'chart');
      expect(find.byType(FocusRing), findsNothing);
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_focused(), 'chart');
      expect(find.byType(FocusRing), findsOneWidget);
    });

    testWidgets("the keyboard's focus rings a TanStack chart's svg", (
      tester,
    ) async {
      await _chart(tester, {
        'component': 'BarChart',
        'data': [
          {'x': 'A', 'y': 1},
          {'x': 'B', 'y': 2},
        ],
      }, theme: _playground);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final scene = _scene<BarScene>(tester);
      expect(ringAt(Offset.zero & scene.size), findsOneWidget);
      expect(
        tester.renderObject(
          find.descendant(
            of: find.byType(FocusRing),
            matching: find.byType(CustomPaint),
          ),
        ),
        paints..something(
          paintedRRect(color: _playground.color(A2uiColorToken.outlineRing)),
        ),
      );
    });
  });
}
