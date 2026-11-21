// Widget tests of the standard Chart (Chart.tsx, drawn as recharts 3.10.1
// draws it): the cases of the phase 2a review (R1-R22) and the
// certificate's fit, dark, motion and disposal items. Expected pixels are
// worked out from recharts' source, cited next to each.

import 'dart:math' as math;
import 'dart:ui';

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/data/chart.dart';
import 'package:a2ui_kit/src/foundation/chart/arc.dart';
import 'package:a2ui_kit/src/foundation/chart/curve.dart';
import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:a2ui_kit/src/foundation/chart/recharts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderClipRect, RenderParagraph;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../goldens/chart_samples.dart';
import '../helpers/harness.dart';
import '../helpers/paint_calls.dart';
import '../helpers/parity.dart' show tableOf, tableRows;

final _standard = A2uiKitTheme.standard(Brightness.light);

/// The box of the legend entry named [label]: its paragraph, the icon's
/// placeholder and the name.
Rect _legendRect(WidgetTester tester, String label) =>
    tester.getRect(_legendEntry(label));

/// A legend entry's paragraph: a word joiner, the no-break space that holds
/// the icon's place (its characters 0 and 1), then [label].
Finder _legendEntry(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is RichText &&
      widget.text.toPlainText(includePlaceholders: false) == '⁠ $label',
);

/// What paints [label]'s legend icon over its paragraph.
RenderObject _legendIcon(WidgetTester tester, String label) =>
    tester.renderObject(_legendEntry(label)).parent!;
final _standardDark = A2uiKitTheme.standard(Brightness.dark);

/// The scenes the charts painted, in order.
List<PlotScene> _scenes(WidgetTester tester) => [
  for (final paint in tester.widgetList<CustomPaint>(find.byType(CustomPaint)))
    if (paint.painter case final ChartScenePainter painter) painter.scene,
];

T _scene<T>(WidgetTester tester) => _scenes(tester).whereType<T>().first;

Future<TestSurfaces> _chart(
  WidgetTester tester,
  Map<String, Object?> props, {
  double width = 360,
  double textScale = 1,
  A2uiKitTheme? theme,
  Brightness brightness = Brightness.light,
}) async {
  final surfaces = await pumpComponents(
    tester,
    width: width,
    textScale: textScale,
    theme: theme ?? _standard,
    brightness: brightness,
    [
      {'id': 'root', 'component': 'Chart', ...props},
    ],
  );
  await tester.pump();
  return surfaces;
}

/// Hovers the mouse at [at] (global) and pumps.
Future<TestGesture> _hover(WidgetTester tester, Offset at) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(at);
  await tester.pump();
  return gesture;
}

Offset _global(WidgetTester tester, Offset local) =>
    tester.getTopLeft(find.byType(ChartPlot).first) + local;

List<String> _painted(List<(double, String)> ticks) => [
  for (final (_, text) in ticks) text,
];

List<Offset> _samples(Path path) => [
  for (final metric in path.computeMetrics())
    for (var d = 0.0; d <= metric.length; d += 1)
      metric.getTangentForOffset(d)!.position,
];

const List<Map<String, Object>> _signups = [
  {'week': 'W1', 'signups': 120},
  {'week': 'W2', 'signups': 164},
  {'week': 'W3', 'signups': 151},
  {'week': 'W4', 'signups': 208},
];

void main() {
  group('the value axis (recharts getNiceTickValues)', () {
    // R1: getNiceTickValues.js:247-285; a `.99 * step` bound drops 90.
    testWidgets('a fixed 0..110 domain ticks 0, 30, 60, 90, 110', (
      tester,
    ) async {
      await _chart(tester, {
        'xKey': 'k',
        'showLegend': false,
        'yAxis': {'min': 0, 'max': 110},
        'data': [
          {'k': 'a', 'v': 12},
          {'k': 'b', 'v': 97},
        ],
      });
      final scene = _scene<RechartsScene>(tester);
      expect(_painted(scene.valueLabelsOnAxis), ['0', '30', '60', '90', '110']);
      // A grid line per tick; the plot's edges are ticks already.
      expect(scene.gridLines, hasLength(5));
    });

    // R19: isDomainSpecifiedByUser.js:105-109, axisSelectors.js:806-810;
    // CartesianGrid.js:253-265 still adds the plot's edges.
    testWidgets('no data: no value ticks, only the grid at the edges', (
      tester,
    ) async {
      await _chart(tester, {
        'xKey': 'k',
        'series': ['v'],
        'data': [],
      });
      final scene = _scene<RechartsScene>(tester);
      expect(scene.valueLabelsOnAxis, isEmpty);
      expect(scene.categoryTicks, isEmpty);
      expect(scene.gridLines, [scene.plot.top, scene.plot.bottom]);
      expect(scene.marks, isEmpty);
    });

    // ChartUtils.js:443-470 (`makeDomainFinite`): a stack with no values
    // still has the domain [0, 0], so recharts draws ticks 0 to 4.
    testWidgets('a stacked chart without data ticks 0 to 4', (tester) async {
      await _chart(tester, {
        'xKey': 'k',
        'series': ['v'],
        'stacked': true,
        'data': [],
      });
      expect(_painted(_scene<RechartsScene>(tester).valueLabelsOnAxis), [
        '0',
        '1',
        '2',
        '3',
        '4',
      ]);
    });

    // R12: getTicks.js:11-53 on the left axis at a short height.
    testWidgets('crowded value labels are left out from the top down', (
      tester,
    ) async {
      await _chart(tester, {
        'xKey': 'k',
        'showLegend': false,
        'height': 120,
        'data': [
          {'k': 'a', 'v': 0},
          {'k': 'b', 'v': 100},
        ],
      }, textScale: 2);
      final scene = _scene<RechartsScene>(tester);
      // 5 ticks over 82px at 24px text: not all fit.
      expect(scene.valueTicks, hasLength(5));
      expect(scene.valueLabelsOnAxis.length, lessThan(5));
      // The top tick is always tried first and kept.
      expect(scene.valueLabelsOnAxis.last.$2, '100');
      for (var i = 1; i < scene.valueLabelsOnAxis.length; i++) {
        final gap =
            scene.valueLabelsOnAxis[i - 1].$1 - scene.valueLabelsOnAxis[i].$1;
        expect(gap, greaterThanOrEqualTo(24 + 5 - 1e-6));
      }
    });
  });

  group('bars (recharts computeBarRectangles)', () {
    // R13: Bar.js:661-669; W1 sits on the axis' 120.
    testWidgets('a 0px bar and its label are left out', (tester) async {
      await _chart(tester, {
        'xKey': 'week',
        'showLegend': false,
        'showValueLabels': true,
        'data': _signups,
      });
      final scene = _scene<RechartsScene>(tester);
      expect([for (final m in scene.marks) m.value], [164, 151, 208]);
      expect([for (final l in scene.labels) l.text], ['164', '151', '208']);
    });

    // R2: combineAllBarPositions.js:58-61, `Math.round`.
    testWidgets('bar sizes round: 39.68 is 40', (tester) async {
      await _chart(tester, {
        'xKey': 'week',
        'showLegend': false,
        'yAxis': {'min': 0},
        'data': [
          for (var i = 0; i < 5; i++) {'week': 'W$i', 'signups': 10 + i},
        ],
      }, width: 320);
      // Plot 64..312: 248 / 5 = 49.6 a band, 4.96 each side.
      final marks = _scene<RechartsScene>(tester).marks;
      expect(marks, hasLength(5));
      for (final m in marks) {
        expect(m.rect.width, closeTo(40, 1e-9));
      }
    });

    // R7: LabelList.js:47-53, Bar.js:676.
    testWidgets("a stacked bar's label is the stack's top", (tester) async {
      await _chart(tester, {
        'xKey': 'k',
        'stacked': true,
        'showValueLabels': true,
        'showLegend': false,
        'series': ['A', 'B'],
        'data': [
          {'k': 'a', 'A': 5, 'B': 3},
        ],
      });
      expect(
        [for (final l in _scene<RechartsScene>(tester).labels) l.text],
        ['5', '8'],
      );
    });

    // R14: getCartesianPosition.js:52-79: `top` of a negative bar is below
    // its end.
    testWidgets("a negative bar's label hangs 5px past its end", (
      tester,
    ) async {
      await _chart(tester, {
        'xKey': 'k',
        'showValueLabels': true,
        'showLegend': false,
        'yAxis': {'min': -50, 'max': 50},
        'data': [
          {'k': 'a', 'v': -40},
          {'k': 'b', 'v': 40},
        ],
      });
      final scene = _scene<RechartsScene>(tester);
      final down = scene.marks.first;
      final up = scene.marks.last;
      expect(scene.labels.first.at.dy, down.rect.bottom + 5);
      expect(scene.labels.first.vertical, RechartsVerticalAnchor.start);
      expect(scene.labels.last.at.dy, up.rect.top - 5);
      expect(scene.labels.last.vertical, RechartsVerticalAnchor.end);
    });

    // R17: axisSelectors.js:383-391 (`makeNumber`).
    testWidgets('numeric text plots', (tester) async {
      await _chart(tester, {
        'xKey': 'm',
        'series': ['v'],
        'yAxis': {'min': 0},
        'data': [
          {'m': 'Jan', 'v': '5'},
          {'m': 'Feb', 'v': '8'},
        ],
      });
      expect(
        [for (final m in _scene<RechartsScene>(tester).marks) m.value],
        ['5', '8'],
      );
    });

    // Bar.js:277-279: a row's fields are spread over its bar's props.
    testWidgets("a row's own fill paints its bar", (tester) async {
      await _chart(tester, {
        'xKey': 'k',
        'series': ['v'],
        'showLegend': false,
        'showGrid': false,
        'data': [
          {'k': 'a', 'v': 5, 'fill': '#ff0000'},
          {'k': 'b', 'v': 8},
        ],
      });
      final painted = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ChartScenePainter,
      );
      expect(
        tester.renderObject(painted),
        paints
          ..rrect(color: const Color(0xffff0000))
          ..rrect(color: _standard.color(A2uiColorToken.chart1)),
      );
    });

    // R6: Text.js:188 `DEFAULT_FILL`: the labels are painted #808080 in
    // both looks, a row's own fill painting its label (LabelList.js:103).
    for (final (look, theme) in [
      ('light', _standard),
      ('dark', _standardDark),
    ]) {
      testWidgets("value labels are painted in recharts' #808080 ($look)", (
        tester,
      ) async {
        await _chart(tester, {
          'xKey': 'week',
          'showLegend': false,
          'showValueLabels': true,
          'data': [
            ..._signups,
            {'week': 'W5', 'signups': 180, 'fill': '#ff0000'},
          ],
        }, theme: theme);
        final scene = _scene<RechartsScene>(tester);
        // The value labels paint last (DefaultZIndexes.label), after any
        // tick of the same text.
        Color? colorOf(String text) =>
            scene.text.lastWhere((line) => line.text == text).color;
        expect(colorOf('164'), const Color(0xff808080));
        expect(colorOf('208'), const Color(0xff808080));
        expect(colorOf('180'), const Color(0xffff0000));
      });
    }
  });

  group('lines, areas and scatter points', () {
    // R5: Curve.js:46-58: monotone Y in recharts' vertical layout.
    testWidgets('a horizontal line is monotone in y', (tester) async {
      await _chart(tester, {
        'chartType': 'line',
        'layout': 'horizontal',
        'xKey': 'k',
        'showLegend': false,
        'yAxis': {'min': 0, 'max': 40},
        'data': [
          {'k': 'a', 'v': 10},
          {'k': 'b', 'v': 30},
          {'k': 'c', 'v': 20},
        ],
      }, width: 400);
      final scene = _scene<RechartsScene>(tester);
      // The value axis runs 96..392 (`yAxis.width` 96, the right margin 8);
      // the categories are points from 8 to 210.
      double x(double v) => 96 + v / 40 * 296;
      final points = [Offset(x(10), 8), Offset(x(30), 109), Offset(x(20), 210)];
      final expected = Path();
      addMonotoneYPath(expected, points);
      final line = _samples(scene.linePaths.single);
      final curve = _samples(expected);
      expect(line, hasLength(curve.length));
      for (var i = 0; i < line.length; i++) {
        expect((line[i] - curve[i]).distance, lessThan(1e-6));
      }
      // Monotone X of the same points is another curve.
      final wrong = Path();
      addMonotoneXPath(wrong, points);
      final other = _samples(wrong);
      final same =
          other.length == curve.length &&
          [
            for (var i = 0; i < other.length; i++)
              (other[i] - curve[i]).distance < .5,
          ].every((near) => near);
      expect(same, isFalse);
    });

    // R24 (Chart.tsx:283-292): a Line takes no `stackId`.
    testWidgets('lines never stack', (tester) async {
      await _chart(tester, {
        'chartType': 'line',
        'xKey': 'k',
        'stacked': true,
        'showDots': true,
        'showLegend': false,
        'series': ['A', 'B'],
        'data': [
          {'k': 'a', 'A': 5, 'B': 5},
        ],
      });
      final dots = _scene<RechartsScene>(tester).marks;
      expect(dots.first.rect.center, dots.last.rect.center);
    });

    // R3: combineRealScaleType.js:9-28, ChartUtils.js:378-403.
    for (final layout in ['vertical', 'horizontal']) {
      testWidgets('string scatter categories sit at band centres ($layout)', (
        tester,
      ) async {
        await _chart(tester, {
          'chartType': 'scatter',
          'layout': layout,
          'xKey': 'category',
          'height': 300,
          'showLegend': false,
          'showTooltip': false,
          'data': [
            for (final c in ['A', 'B', 'C', 'D']) {'category': c, 'score': 10},
          ],
        }, width: 600);
        final scene = _scene<RechartsScene>(tester);
        final along = [
          for (final m in scene.marks)
            if (layout == 'vertical') m.rect.center.dx else m.rect.center.dy,
        ];
        // Vertical: 64..592 in bands of 132; horizontal: 8..270 in 65.5.
        final expected = layout == 'vertical'
            ? [130.0, 262.0, 394.0, 526.0]
            : [40.75, 106.25, 171.75, 237.25];
        for (var i = 0; i < 4; i++) {
          expect(along[i], closeTo(expected[i], 1e-9));
          expect(scene.categoryTicks[i].$1, closeTo(expected[i], 1e-9));
        }
      });
    }

    // R4: Chart.tsx:373-379, the x axis has no tickFormatter.
    testWidgets("a numeric scatter's x ticks are not formatted", (
      tester,
    ) async {
      await _chart(tester, {
        'chartType': 'scatter',
        'xKey': 'amount',
        'format': 'percent',
        'showLegend': false,
        'data': [
          for (final a in [100, 200, 400, 800]) {'amount': a, 'score': .5},
        ],
      }, width: 600);
      final scene = _scene<RechartsScene>(tester);
      expect(_painted(scene.categoryTicks), ['0', '200', '400', '600', '800']);
      expect(_painted(scene.valueLabelsOnAxis).join(), contains('%'));
    });
  });

  group('the tooltip (recharts Tooltip)', () {
    // R9: getActiveCoordinate.js:8-28 and translate.js:18-57: 10px right of
    // the category's centre, at the pointer's height.
    testWidgets('sits by the category, not the pointer, along x', (
      tester,
    ) async {
      await _chart(tester, {
        'xKey': 'week',
        'showLegend': false,
        'data': _signups,
      }, width: 600);
      final scene = _scene<RechartsScene>(tester);
      final band = scene.marks.first.rect; // W2
      final at1 = _global(tester, Offset(band.center.dx - 8, 100));
      final gesture = await _hover(tester, at1);
      // The box glides to its place (Tooltip.js:47-48: 400ms).
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(find.byType(RechartsTooltip));
      await gesture.moveTo(_global(tester, Offset(band.center.dx + 8, 120)));
      await tester.pump();
      await tester.pumpAndSettle();
      final second = tester.getTopLeft(find.byType(RechartsTooltip));
      expect(second.dx, first.dx);
      expect(second.dy - first.dy, 20);
      // 10px right of W2's tick, its band's centre: plot 64..592, bands of
      // 132.
      expect(
        first.dx,
        _global(tester, const Offset(64 + 132 * 1.5 + 10, 0)).dx,
      );
    });

    // R23: Tooltip.js:56 `itemSorter: "name"`, DefaultTooltipContent.js:82.
    testWidgets('rows are sorted by name', (tester) async {
      await _chart(tester, {
        'xKey': 'k',
        'showLegend': false,
        'series': [
          {'key': 'rev', 'label': 'Revenue'},
          {'key': 'cost', 'label': 'Cost'},
        ],
        'data': [
          {'k': 'a', 'rev': 5, 'cost': 3},
        ],
      });
      final scene = _scene<RechartsScene>(tester);
      await _hover(tester, _global(tester, scene.plot.center));
      expect(
        rectOfText(tester, 'Cost : 3').top,
        lessThan(rectOfText(tester, 'Revenue : 5').top),
      );
    });

    // R15: Scatter.js:405-427: in the horizontal layout the x axis is the
    // value axis; rows then sort by name.
    testWidgets("a scatter point's rows, sorted by name", (tester) async {
      await _chart(tester, {
        'chartType': 'scatter',
        'layout': 'horizontal',
        'xKey': 'hours',
        'showLegend': false,
        'series': ['score'],
        'data': [
          {'hours': 2, 'score': 10},
        ],
      });
      final point = _scene<RechartsScene>(tester).marks.single.rect.center;
      await _hover(tester, _global(tester, point));
      expect(
        rectOfText(tester, 'hours : 2').top,
        lessThan(rectOfText(tester, 'score : 10').top),
      );
    });
  });

  group('the pie (recharts Pie)', () {
    // R16: Pie.js:348.
    testWidgets('one slice takes no padding angle', (tester) async {
      await _chart(tester, {
        'chartType': 'pie',
        'xKey': 'n',
        'paddingAngle': 10,
        'data': [
          {'n': 'a', 'v': 1},
        ],
      });
      final slice = _scene<RechartsPieScene>(tester).slices.single;
      expect(slice.endAngle - slice.startAngle, -360);
    });

    // Sector.js:180-182: no path for a 0° slice; Pie.js:216-257 still
    // labels it.
    testWidgets('a 0 slice is not drawn but is labelled', (tester) async {
      await _chart(tester, {
        'chartType': 'pie',
        'xKey': 'n',
        'showValueLabels': true,
        'data': [
          {'n': 'a', 'v': 1},
          {'n': 'b', 'v': 0},
          {'n': 'c', 'v': 1},
        ],
      });
      final pie = _scene<RechartsPieScene>(tester);
      expect(pie.slices[1].startAngle, pie.slices[1].endAngle);
      expect([for (final l in pie.labels) l.text], ['1', '0', '1']);
      // A pointer at the 0 slice's angle finds a neighbour, never it.
      final at = rechartsPolar(
        pie.center,
        (pie.innerRadius + pie.outerRadius) / 2 + 1,
        pie.slices[1].startAngle,
      );
      expect(pie.focusAt(at)?.group, isNot(1));
    });
  });

  group('series, the table and the figure', () {
    // R18: Chart.tsx:82 `Object.keys`: integer-like keys first.
    testWidgets('the automatic series follow JavaScript key order', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _chart(tester, {
        'xKey': 'region',
        'data': [
          {'region': 'N', '2024': 5, '2023': 3},
        ],
      });
      expect(
        tableRows(tester),
        tableOf(
          ['region', '2023', '2024'],
          [
            ['N', '3', '5'],
          ],
        ),
      );
      expect(
        _legendRect(tester, '2023').left,
        lessThan(_legendRect(tester, '2024').left),
      );
      handle.dispose();
    });

    // R20, BUG(port): Chart.tsx:415, :449: `String(value)` without format.
    testWidgets('the table reads undefined and null as CopilotKit writes '
        'them', (tester) async {
      final handle = tester.ensureSemantics();
      await _chart(tester, {
        'xKey': 'm',
        'series': ['v'],
        'data': [
          {'m': 'Jan'},
          {'m': 'Feb', 'v': null},
        ],
      });
      expect(
        tableRows(tester),
        tableOf(
          ['m', 'v'],
          [
            ['Jan', 'undefined'],
            ['Feb', 'null'],
          ],
        ),
      );
      // With a format, `String(value ?? "")`.
      await _chart(tester, {
        'xKey': 'm',
        'series': ['v'],
        'format': 'number',
        'data': [
          {'m': 'Jan'},
        ],
      });
      expect(
        tableRows(tester),
        tableOf(
          ['m', 'v'],
          [
            ['Jan', ''],
          ],
        ),
      );
      handle.dispose();
    });

    // INV-034: the `<figure>` named by its `<figcaption>`, holding the
    // `<table>` (Chart.tsx:424-452, :497-523): a table node, a row of
    // column headers, then a row of cells per data row.
    testWidgets('the figure is a group named by its title, holding the table', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _chart(tester, {
        'title': 'Signups by week',
        'xKey': 'week',
        'data': _signups,
      });
      final figure = tester.getSemantics(
        find.bySemanticsLabel('Signups by week'),
      );
      final inside = <String>[];
      final roles = <SemanticsRole>[];
      void collect(SemanticsNode node) {
        inside.add(node.label);
        roles.add(node.role);
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      figure.visitChildren((child) {
        collect(child);
        return true;
      });
      expect(
        tableRows(tester),
        tableOf(
          ['week', 'signups'],
          [
            ['W1', '120'],
            ['W2', '164'],
            ['W3', '151'],
            ['W4', '208'],
          ],
        ),
      );
      // The table is inside the figure.
      expect(roles, contains(SemanticsRole.table));
      // The caption is the group's name, not read again inside it.
      expect(inside, isNot(contains('Signups by week')));
      // The drawing has no node: the cells are all that is read.
      expect(inside.where((l) => l.isNotEmpty), hasLength(2 + 4 * 2));
      handle.dispose();
    });
  });

  group('fit, looks, motion and disposal', () {
    for (final (look, theme, brightness) in [
      ('standard light', _standard, Brightness.light),
      ('standard dark', _standardDark, Brightness.dark),
      (
        'playground light',
        A2uiKitTheme.playground(Brightness.light),
        Brightness.light,
      ),
      (
        'playground dark',
        A2uiKitTheme.playground(Brightness.dark),
        Brightness.dark,
      ),
    ]) {
      testWidgets('the samples hold at 320px and text scale 2 ($look)', (
        tester,
      ) async {
        await pumpComponents(
          tester,
          width: 320,
          textScale: 2,
          theme: theme,
          brightness: brightness,
          chartSamples['chart']!,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final scene in _scenes(tester).whereType<RechartsScene>()) {
          // The labels painted along the bottom keep 5px apart.
          final bottom = scene.categoryTicks;
          double width(String text) => scene.style.ticks.measure(text).width;
          for (var i = 1; i < bottom.length; i++) {
            final (a, aText) = bottom[i - 1];
            final (b, bText) = bottom[i];
            expect(
              b - width(bText) / 2,
              greaterThanOrEqualTo(a + width(aText) / 2 + 5 - 1e-6),
            );
          }
          expect(scene.plot.width, greaterThan(0));
        }
      });
    }

    testWidgets('nothing moves, with or without reduced motion', (
      tester,
    ) async {
      for (final reduced in [false, true]) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: reduced);
        await _chart(tester, {'xKey': 'week', 'data': _signups});
        expect(tester.binding.hasScheduledFrame, isFalse, reason: '$reduced');
      }
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });

    testWidgets('a font that loads later rebuilds the scene; a removed chart '
        'stops listening', (tester) async {
      await _chart(tester, {'xKey': 'week', 'data': _signups});
      final before = _scene<RechartsScene>(tester);
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.pump();
      expect(identical(_scene<RechartsScene>(tester), before), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    // INV-031: a drawing's widest intrinsic width is the width its library
    // draws at before it measures its box: recharts' `initialDimension` 320
    // (Chart.tsx:335), TanStack's `initialWidth` 640 (dist/react/
    // RendererChart.js:34); its narrowest is 0 (`min-w-0`, a measured SVG).
    testWidgets('the drawings answer their intrinsic widths', (tester) async {
      await pumpComponents(tester, theme: _standard, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['chart', 'line'],
        },
        {'id': 'chart', 'component': 'Chart', 'xKey': 'week', 'data': _signups},
        {
          'id': 'line',
          'component': 'LineChart',
          'data': [
            {'x': 'a', 'y': 1},
            {'x': 'b', 'y': 2},
          ],
        },
      ]);
      await tester.pumpAndSettle();
      final plots = tester.renderObjectList<RenderBox>(find.byType(ChartPlot));
      expect([for (final p in plots) p.getMaxIntrinsicWidth(100)], [320, 640]);
      expect([for (final p in plots) p.getMinIntrinsicWidth(100)], [0, 0]);
    });
  });

  _legendTests();
  _textTests();
  _keyboardTests();
  _pointerTests();
  _dataTests();
  _pieTests();
  _paintTests();
}

/// The tooltip's top left in the plot.
Offset _tooltipAt(WidgetTester tester) =>
    tester.getTopLeft(find.byType(RechartsTooltip)) -
    tester.getTopLeft(find.byType(ChartPlot).first);

/// Whether the tooltip shows: built and not dismissed (an `Opacity` of 1).
bool _tooltipShown(WidgetTester tester) {
  final tooltip = find.byType(RechartsTooltip);
  if (tooltip.evaluate().isEmpty) return false;
  final opacity = tester.widget<Opacity>(
    find.ancestor(of: tooltip, matching: find.byType(Opacity)).first,
  );
  return opacity.opacity == 1;
}

Finder get _drawing => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is ChartScenePainter,
);

// recharts 3.10.1 es6/component/Legend.js:176 (`itemSorter: 'value'`),
// es6/state/selectors/legendSelectors.js:6-10; es-toolkit compareValues
// (`<`, code units).
void _legendTests() {
  group('the legend (sorted by name)', () {
    testWidgets('series entries by name, capitals first', (tester) async {
      await _chart(tester, {
        'xKey': 'k',
        'series': [
          {'key': 'rev', 'label': 'revenue'},
          {'key': 'cost', 'label': 'Cost'},
          {'key': 'tax', 'label': 'Tax'},
        ],
        'data': [
          {'k': 'a', 'rev': 5, 'cost': 3, 'tax': 1},
        ],
      }, width: 600);
      final cost = _legendRect(tester, 'Cost');
      final tax = _legendRect(tester, 'Tax');
      final revenue = _legendRect(tester, 'revenue');
      expect(cost.left, lessThan(tax.left));
      expect(tax.left, lessThan(revenue.left));
    });

    // CR15: DefaultLegendContent.js:98-107, :120-121, :124-142: the `li` is
    // one inline flow, the icon's inline-block `svg` (`vertical-align:
    // middle`, 4px before the name) then the name's wrapping `span`.
    testWidgets("a pie's rows by name, each in its own colour", (tester) async {
      await _chart(tester, {
        'chartType': 'pie',
        'xKey': 'device',
        'data': [
          {'device': 'Mobile', 'v': 5},
          {'device': 'Desktop', 'v': 3},
          {'device': 'Tablet', 'v': 1},
        ],
      }, width: 600);
      final desktop = _legendRect(tester, 'Desktop');
      final mobile = _legendRect(tester, 'Mobile');
      final tablet = _legendRect(tester, 'Tablet');
      expect(desktop.left, lessThan(mobile.left));
      expect(mobile.left, lessThan(tablet.left));
      for (final (label, token) in [
        ('Desktop', A2uiColorToken.chart2),
        ('Mobile', A2uiColorToken.chart1),
        ('Tablet', A2uiColorToken.chart3),
      ]) {
        expect(
          _legendIcon(tester, label),
          paints..something(
            paintedCircle(radius: 4, color: _standard.color(token)),
          ),
          reason: label,
        );
      }
    });

    // RC3: the icon's 8px and its 4px margin are `px` (Chart.tsx:46-51,
    // DefaultLegendContent.js:103-107): the same at text scale 2.0.
    for (final scale in [1.0, 2.0]) {
      testWidgets('a wrapped name runs on under its icon, which sits on the '
          'first line, 8px with a 4px gap (text scale $scale)', (tester) async {
        await _wrappedLegend(tester, scale);
      });
    }

    // RC3-4: the `li` is `white-space: nowrap` (DefaultLegendContent.js:
    // 98-102), so no break falls between the icon and the name's first word
    // (CSS Text 3 section 5.1); the `li` is an inline-block as wide as
    // min(max(min-content, the line), max-content) (CSS 2.1 section
    // 10.3.9), where `break-word`'s breaks don't count towards min-content
    // (CSS Text 3 section 5.5): a first word that fits a line alone but not
    // beside the icon stays beside it, whole, and the `li` overflows its
    // line, start-aligned (CSS Text 3 section 6.1). A port with the icon as
    // a placeholder drops the word to the next line; one that keeps the
    // line's width breaks the word.
    testWidgets('a first word too long to fit beside the icon stays beside '
        'it, whole, the entry overflowing its line from its start', (
      tester,
    ) async {
      Future<RenderParagraph> legendOf(String name) async {
        await _chart(tester, {
          'xKey': 'k',
          'series': [
            {'key': 'v', 'label': name},
          ],
          'data': [
            {'k': 'a', 'v': 5},
          ],
        }, width: 200);
        return tester.renderObject<RenderParagraph>(_legendEntry(name));
      }

      // The line's width and a letter's, then a word as long as fits a line
      // alone, which the 12px icon and gap leave no room for.
      final probe = await legendOf('M');
      final line = probe.constraints.maxWidth;
      final end = probe.text.toPlainText().length;
      final letter = probe
          .getBoxesForSelection(
            TextSelection(baseOffset: end - 1, extentOffset: end),
          )
          .single;
      final width = letter.right - letter.left;
      final count = (line / width).floor();
      expect(count * width, lessThanOrEqualTo(line));
      expect(count * width + 12, greaterThan(line));
      final name = 'M' * count;
      final paragraph = await legendOf(name);
      List<TextBox> boxes(int start, int end) => paragraph.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
        boxHeightStyle: BoxHeightStyle.max,
      );
      final icon = boxes(1, 2).single;
      expect(icon.right - icon.left, closeTo(12, 1e-6));
      // The whole name on the icon's line, right after its 12px.
      final letters = boxes(2, 2 + name.length);
      expect({for (final box in letters) box.top}, {icon.top});
      expect(letters.first.left, closeTo(icon.right, 1e-6));
      // The entry is wider than its line and starts at the legend's start.
      final entry = tester.getRect(_legendEntry(name));
      expect(entry.width, greaterThan(line));
      expect(entry.left, tester.getTopLeft(find.byType(Wrap)).dx);
      // Its one line fills it; Flutter rounds a paragraph's intrinsic
      // widths up to a whole pixel, so the centred line may sit up to half
      // a pixel in.
      expect(icon.left, inInclusiveRange(0, .5));
    });

    // RC3-4: `vertical-align: middle` puts the icon's middle at the `li`'s
    // baseline plus half its x-height (CSS 2.1 section 10.8.1); the `li`'s
    // font is the page's, the surface's standing in (INV-046), and its
    // x-height, which Flutter's text API does not give, is CSS's own
    // fallback, 0.5em (CSS Values 4 section 6.1.1; INV-053).
    for (final scale in [1.0, 2.0]) {
      testWidgets("the icon's middle is a quarter of the entry's font size "
          'above the first baseline (text scale $scale)', (tester) async {
        await _chart(tester, {
          'xKey': 'k',
          'series': [
            {'key': 'v', 'label': 'Revenue'},
          ],
          'data': [
            {'k': 'a', 'v': 5},
          ],
        }, textScale: scale);
        final entry = _legendEntry('Revenue');
        final paragraph = tester.renderObject<RenderParagraph>(entry);
        final surfaceSize =
            DefaultTextStyle.of(tester.element(entry)).style.fontSize ??
            _standard.typography.fontSize;
        expect(paragraph.text.style!.fontSize, surfaceSize);
        // The paragraph's first baseline, from the same text laid out alike.
        final widget = tester.widget<RichText>(entry);
        final painter = TextPainter(
          text: widget.text,
          textAlign: widget.textAlign,
          textDirection: TextDirection.ltr,
          textScaler: widget.textScaler,
          strutStyle: widget.strutStyle,
        )..layout(maxWidth: paragraph.constraints.maxWidth);
        addTearDown(painter.dispose);
        expect(painter.size, paragraph.size);
        final baseline = painter.computeDistanceToActualBaseline(
          TextBaseline.alphabetic,
        );
        final run = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 1, extentOffset: 2),
            )
            .single;
        expect(
          _legendIcon(tester, 'Revenue'),
          paints..something(
            paintedCircle(
              x: run.left + 4,
              y: baseline - surfaceSize * scale / 4,
              radius: 4,
              color: _standard.color(A2uiColorToken.chart1),
            ),
          ),
        );
      });
    }
  });
}

/// CR15 and RC3: a wrapped legend name at text scale [scale].
Future<void> _wrappedLegend(WidgetTester tester, double scale) async {
  const name =
      'Revenue from enterprise subscriptions and every add-on sold '
      'with them';
  await _chart(
    tester,
    {
      'xKey': 'k',
      'series': [
        {'key': 'v', 'label': name},
      ],
      'data': [
        {'k': 'a', 'v': 5},
      ],
    },
    width: 200,
    textScale: scale,
  );
  final paragraph = tester.renderObject<RenderParagraph>(_legendEntry(name));
  TextBox boxOf(int index) => paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: index, extentOffset: index + 1),
        boxHeightStyle: BoxHeightStyle.max,
      )
      .single;
  // The icon holds the no-break space's place: its 8px and 4px gap at any
  // text scale, the 8px dot painted at its start.
  final icon = boxOf(1);
  expect(icon.right - icon.left, closeTo(8 + 4, 1e-6));
  expect(
    _legendIcon(tester, name),
    paints..something(paintedCircle(x: icon.left + 4, radius: 4)),
  );
  // The lines, each from its first letter to its last (the spaces at a
  // break are not drawn, CSS Text 3 section 4.1.3).
  final lines = <double, (double, double)>{icon.top: (icon.left, icon.right)};
  for (var i = 0; i < name.length; i++) {
    if (name[i] == ' ') continue;
    final box = boxOf(2 + i);
    final (left, right) = lines[box.top] ?? (box.left, box.right);
    lines[box.top] = (math.min(left, box.left), math.max(right, box.right));
  }
  expect(lines.length, greaterThan(1), reason: 'the name wraps');
  // The icon sits on the first line, with the name's first word.
  expect(lines.keys.reduce(math.min), icon.top);
  // Every line is as tall as the first, which holds the entry's font: the
  // `li`'s strut sets each line's least height (CSS 2.1 section 10.8.1),
  // the later lines' 13px text alone would make them shorter.
  for (var i = 0; i < name.length; i++) {
    if (name[i] == ' ') continue;
    final box = boxOf(2 + i);
    expect(box.bottom - box.top, closeTo(icon.bottom - icon.top, 1e-4));
  }
  // The entry is as wide as its line, and each line is centred in it: the
  // `li` inherits the `ul`'s `text-align: center` (DefaultLegendContent.js:
  // 159-163). Start-aligned, a later line would start at 0.
  final width = paragraph.size.width;
  expect(width, lessThanOrEqualTo(paragraph.constraints.maxWidth));
  for (final MapEntry(key: top, value: (left, right)) in lines.entries) {
    expect(left, closeTo(width - right, .5), reason: 'the line at $top');
  }
}

// recharts 3.10.1 es6/component/Text.js:22, :69-86, :150-187, :236-280;
// es6/cartesian/YAxis.js:125-130; es6/cartesian/CartesianAxis.js:318.
void _textTests() {
  group('tick text (recharts Text)', () {
    testWidgets('a horizontal chart breaks its category labels at the '
        'axis width, centred on the band', (tester) async {
      await _chart(tester, {
        'layout': 'horizontal',
        'xKey': 'team',
        'showLegend': false,
        'data': [
          {'team': 'Customer Support', 'v': 5},
          {'team': 'Ops', 'v': 3},
        ],
      }, width: 400);
      final scene = _scene<RechartsScene>(tester);
      final lines = [for (final line in scene.text) line.text];
      // The test font's glyphs are 1em wide: "Customer" (96px), a no-break
      // space and "Support" (84px) do not fit within 96.
      expect(lines, containsAllInOrder(['Customer', 'Support', 'Ops']));
      expect(lines, isNot(contains('Customer Support')));
      Rect box(String text) =>
          scene.text.firstWhere((line) => line.text == text).box;
      final end = scene.plot.left - 8;
      expect(box('Customer').right, closeTo(end, 1e-9));
      expect(box('Support').right, closeTo(end, 1e-9));
      // `lineHeight` 1em apart; the block centred on the band as one line
      // is (`startDy = (n - 1) / 2 * -1em + capHeight / 2`).
      expect(box('Support').top - box('Customer').top, closeTo(12, 1e-9));
      final ticks = [for (final (at, _) in scene.categoryTicks) at];
      expect(
        (box('Customer').top + box('Support').top) / 2 - ticks[0],
        closeTo(box('Ops').top - ticks[1], 1e-9),
      );
    });

    testWidgets('a label is written as its words joined by one space', (
      tester,
    ) async {
      await _chart(tester, {
        'xKey': 'q',
        'showLegend': false,
        'data': [
          {'q': 'Q1\n2024', 'v': 5},
          {'q': 'Q2 \t 2024', 'v': 3},
        ],
      }, width: 600);
      final lines = [
        for (final line in _scene<RechartsScene>(tester).text) line.text,
      ];
      expect(lines, containsAll(['Q1 2024', 'Q2 2024']));
    });
  });
}

// recharts 3.10.1 es6/state/keyboardEventsMiddleware.js:15-181,
// es6/component/TooltipBoundingBox.js:38-60, es6/state/selectors/
// combiners/combineCoordinateForDefaultIndex.js:1-36.
void _keyboardTests() {
  group('the keyboard (recharts accessibilityLayer)', () {
    testWidgets("Tab shows the first index at the chart's middle height; "
        'the arrows step without wrapping; Up and Down do nothing', (
      tester,
    ) async {
      await _chart(tester, {
        'xKey': 'week',
        'showLegend': false,
        'data': _signups,
      }, width: 600);
      expect(find.byType(RechartsTooltip), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('signups : 120'), findsOneWidget);
      // (offset.top + chartHeight) / 2 = (8 + 240) / 2 = 124, the box 10px
      // under it; x 10px right of W1's band centre (64 + 132 / 2).
      expect(_tooltipAt(tester), const Offset(64 + 66 + 10, 124 + 10));
      for (final want in ['164', '151', '208', '208']) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(find.text('signups : $want'), findsOneWidget);
      }
      final focused = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.text('signups : 208'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, same(focused));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('signups : 151'), findsOneWidget);
    });

    testWidgets('Enter hides and shows; a blur hides and the next focus '
        'shows nothing until a key', (tester) async {
      await _chart(tester, {
        'xKey': 'week',
        'showLegend': false,
        'data': _signups,
      });
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.byType(RechartsTooltip), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(RechartsTooltip), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('signups : 120'), findsOneWidget);
      final node = FocusManager.instance.primaryFocus!..unfocus();
      await tester.pumpAndSettle();
      expect(find.byType(RechartsTooltip), findsNothing);
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(find.byType(RechartsTooltip), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('signups : 164'), findsOneWidget);
    });

    testWidgets('Escape hides only the box, until its point moves', (
      tester,
    ) async {
      await _chart(tester, {
        'xKey': 'week',
        'showLegend': false,
        'data': _signups,
      });
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_tooltipShown(tester), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_tooltipShown(tester), isFalse);
      // The cursor stays (Tooltip.js:177-183).
      final scene = _scene<RechartsScene>(tester);
      expect(
        tester.renderObject(_drawing),
        paints..something(
          paintedRect(color: _standard.color(A2uiColorToken.chartCursor)),
        ),
      );
      expect(scene.plot.width, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_tooltipShown(tester), isTrue);
    });

    testWidgets('a horizontal chart runs top to bottom: ArrowRight steps '
        'back', (tester) async {
      await _chart(tester, {
        'layout': 'horizontal',
        'xKey': 'week',
        'showLegend': false,
        'data': _signups,
      }, width: 600);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('signups : 120'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('signups : 120'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('signups : 164'), findsOneWidget);
      // ((offset.left + chartWidth) / 2, the band's centre): left 96, the
      // box 10px right of it.
      expect(_tooltipAt(tester).dx, (96 + 600) / 2 + 10);
    });

    testWidgets("a scatter's keyboard steps its first series only", (
      tester,
    ) async {
      await _chart(tester, {
        'chartType': 'scatter',
        'xKey': 'x',
        'showLegend': false,
        'series': ['a', 'b'],
        'data': [
          {'x': 1, 'a': 10, 'b': 20},
          {'x': 2, 'a': 11, 'b': 21},
        ],
      });
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('a : 10'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('a : 11'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('a : 11'), findsOneWidget);
      expect(find.textContaining('b :'), findsNothing);
    });

    testWidgets('a pie shows slice 0 on Tab, never wraps, and its group is '
        'a second stop', (tester) async {
      await _chart(tester, {
        'chartType': 'pie',
        'xKey': 'n',
        'showLegend': false,
        'data': [
          {'n': 'a', 'v': 1},
          {'n': 'b', 'v': 2},
          {'n': 'c', 'v': 3},
        ],
      });
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('a : 1'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('c : 3'), findsOneWidget);
      final svg = FocusManager.instance.primaryFocus;
      // Tab moves to the pie's `<g>`: a blur, then a focus that shows
      // nothing, the index kept.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, isNot(same(svg)));
      expect(find.byType(RechartsTooltip), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('b : 2'), findsOneWidget);
    });
  });
}

void _pointerTests() {
  group('the pointer', () {
    // Line.js:425-431, ActivePoints.js:28-39: r 4 in the series' colour,
    // ringed 2px #fff, with or without a Tooltip.
    testWidgets('active dots show on hover without a tooltip', (tester) async {
      await _chart(tester, {
        'chartType': 'line',
        'xKey': 'k',
        'showLegend': false,
        'showTooltip': false,
        'yAxis': {'min': 0, 'max': 10},
        'data': [
          {'k': 'a', 'v': 2},
          {'k': 'b', 'v': 6},
        ],
      });
      final scene = _scene<RechartsScene>(tester);
      // Points at the plot's edges (a point scale): b at the right.
      final b = Offset(
        scene.plot.right,
        scene.plot.bottom - .6 * scene.plot.height,
      );
      await _hover(tester, _global(tester, b + const Offset(-1, 0)));
      expect(find.byType(RechartsTooltip), findsNothing);
      expect(
        tester.renderObject(_drawing),
        paints
          ..something(
            paintedCircle(
              x: b.dx,
              y: b.dy,
              radius: 4,
              color: _standard.color(A2uiColorToken.chart1),
            ),
          )
          ..something(
            paintedCircle(
              x: b.dx,
              y: b.dy,
              radius: 4,
              color: const Color(0xffffffff),
              strokeWidth: 2,
              style: PaintingStyle.stroke,
            ),
          ),
      );
    });

    // getCursorRectangle.js:1-10: the band, 0.5px in from the plot's top
    // and bottom; Cursor.js:93-97, Chart.tsx:60.
    testWidgets("the bar chart's cursor band", (tester) async {
      await _chart(tester, {
        'xKey': 'week',
        'showLegend': false,
        'data': _signups,
      }, width: 600);
      final scene = _scene<RechartsScene>(tester);
      await _hover(tester, _global(tester, const Offset(64 + 132 * 1.5, 100)));
      expect(
        tester.renderObject(_drawing),
        paints..something(
          paintedRect(
            rect: Rect.fromLTWH(
              64 + 132,
              scene.plot.top + .5,
              132,
              scene.plot.height - 1,
            ),
            color: _standard.color(A2uiColorToken.chartCursor),
          ),
        ),
      );
    });

    // isInCartesianRange (getActiveCoordinate.js:74-78): every edge in.
    testWidgets("a pointer on the plot's right and bottom edges still "
        'focuses', (tester) async {
      await _chart(tester, {
        'xKey': 'week',
        'showLegend': false,
        'data': _signups,
      });
      final scene = _scene<RechartsScene>(tester);
      await _hover(tester, _global(tester, scene.plot.bottomRight));
      expect(find.text('signups : 208'), findsOneWidget);
    });

    // combineTooltipPayload.js:83-121: with an `xKey`, the first row whose
    // value is the tick's.
    testWidgets('a repeated category reads its first row', (tester) async {
      await _chart(tester, {
        'chartType': 'line',
        'xKey': 'q',
        'showLegend': false,
        'yAxis': {'min': 0, 'max': 10},
        'data': [
          {'q': 'Q1', 'v': 1},
          {'q': 'Q2', 'v': 2},
          {'q': 'Q1', 'v': 3},
        ],
      });
      final scene = _scene<RechartsScene>(tester);
      await _hover(
        tester,
        _global(tester, Offset(scene.plot.right - 1, scene.plot.center.dy)),
      );
      expect(find.text('v : 1'), findsOneWidget);
      // The active dot on the first row's point (x at the plot's left).
      expect(
        tester.renderObject(_drawing),
        paints..something(
          paintedCircle(
            x: scene.plot.left,
            radius: 4,
            color: _standard.color(A2uiColorToken.chart1),
          ),
        ),
      );
    });

    testWidgets('a row without a category: the band reads the row with '
        "that band's value", (tester) async {
      await _chart(tester, {
        'xKey': 'm',
        'showLegend': false,
        'data': [
          {'m': 'Jan', 'v': 1},
          {'v': 2},
          {'m': 'Mar', 'v': 3},
        ],
      }, width: 600);
      final scene = _scene<RechartsScene>(tester);
      await _hover(
        tester,
        _global(tester, Offset(scene.plot.right - 10, scene.plot.center.dy)),
      );
      expect(find.text('v : 3'), findsOneWidget);
    });

    // TooltipBoundingBox.js:15-24, Tooltip.js:47-48, :54: 400ms, CSS `ease`;
    // the first time from the wrapper's top left.
    testWidgets('the tooltip glides into place', (tester) async {
      await _chart(tester, {
        'xKey': 'week',
        'showLegend': false,
        'data': _signups,
      }, width: 600);
      await _hover(tester, _global(tester, const Offset(64 + 132 * 1.5, 100)));
      expect(_tooltipAt(tester), Offset.zero);
      // The glide starts on the next frame.
      await tester.pump();
      expect(_tooltipAt(tester), Offset.zero);
      await tester.pump(const Duration(milliseconds: 200));
      final middle = _tooltipAt(tester);
      await tester.pump(const Duration(milliseconds: 200));
      final end = _tooltipAt(tester);
      expect(end, const Offset(64 + 132 * 1.5 + 10, 110));
      // CSS `ease` (cubic-bezier(.25, .1, .25, 1)) at half time is 80.24% of
      // the way.
      expect(middle.dx / end.dx, closeTo(.8024, .001));
      expect(middle.dy / end.dy, closeTo(.8024, .001));
    });

    testWidgets('no glide under reduced motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _chart(tester, {
        'xKey': 'week',
        'showLegend': false,
        'data': _signups,
      }, width: 600);
      await _hover(tester, _global(tester, const Offset(64 + 132 * 1.5, 100)));
      expect(_tooltipAt(tester), const Offset(64 + 132 * 1.5 + 10, 110));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    // Chart.tsx:513-517: the chart's `overflow-x: auto` box clips the
    // tooltip.
    testWidgets("the tooltip is clipped to the chart's box", (tester) async {
      await _chart(tester, {
        'xKey': 'm',
        'height': 160,
        'showLegend': false,
        'series': ['a', 'b', 'c', 'd', 'e', 'f'],
        'data': [
          {'m': 'Jan', 'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5, 'f': 6},
        ],
      });
      await _hover(tester, _global(tester, const Offset(200, 80)));
      await tester.pumpAndSettle();
      final tooltip = tester.getRect(find.byType(RechartsTooltip));
      final chart = tester.getRect(find.byType(ChartPlot));
      expect(tooltip.bottom, greaterThan(chart.bottom));
      // The nearest clip round the tooltip is the chart's box.
      final clip = find
          .ancestor(
            of: find.byType(RechartsTooltip),
            matching: find.byType(ClipRect),
          )
          .first;
      expect(
        tester.getRect(clip),
        Rect.fromLTWH(chart.left, chart.top, 360, 160),
      );
      expect(
        tester.renderObject<RenderClipRect>(clip).clipBehavior,
        Clip.hardEdge,
      );
    });

    // Scatter.js:259, :459-478: the row spread over its point.
    testWidgets("a row's own fill paints its scatter point", (tester) async {
      await _chart(tester, {
        'chartType': 'scatter',
        'xKey': 'x',
        'showLegend': false,
        'data': [
          {'x': 1, 'y': 2, 'fill': '#ff0000'},
          {'x': 2, 'y': 3},
        ],
      });
      expect(
        tester.renderObject(_drawing),
        paints
          ..circle(color: const Color(0xffff0000))
          ..circle(color: _standard.color(A2uiColorToken.chart1)),
      );
    });
  });
}

void _dataTests() {
  group('reading the data (getValueByDataKey, hasDuplicate)', () {
    // Text.js:66-68 (`isRenderableText`): booleans are written.
    testWidgets('a boolean value is labelled; React writes nothing for it in '
        'the tooltip', (tester) async {
      await _chart(tester, {
        'chartType': 'line',
        'xKey': 'k',
        'showLegend': false,
        'showValueLabels': true,
        'series': ['v'],
        'yAxis': {'min': 0, 'max': 2},
        'data': [
          {'k': 'a', 'v': true},
          {'k': 'b', 'v': 1},
        ],
      });
      final scene = _scene<RechartsScene>(tester);
      expect([for (final l in scene.labels) l.text], ['true', '1']);
      await _hover(
        tester,
        _global(tester, scene.plot.topLeft + const Offset(1, 1)),
      );
      expect(find.text('v : '), findsOneWidget);
    });

    // DataUtils.js:72-86: `String(value)` keys of a plain object.
    for (final (name, values) in [
      ('5 and "5"', <Object>[5, '5']),
      ('an inherited name', <Object>['constructor', 'b']),
    ]) {
      testWidgets("$name count as a repeat: the rows' own domain", (
        tester,
      ) async {
        await _chart(tester, {
          'xKey': 'x',
          'showLegend': false,
          'series': ['v'],
          'data': [
            {'x': values[0], 'v': 1},
            {'v': 2},
            {'x': values[1], 'v': 3},
          ],
        }, width: 600);
        expect(_painted(_scene<RechartsScene>(tester).categoryTicks), [
          '${values[0]}',
          'undefined',
          '${values[1]}',
        ]);
      });
    }

    // ChartUtils.js:13-24, es-toolkit get: a missing key with a `.` is a
    // path; CopilotKit's table reads `row[key]` (Chart.tsx:449).
    testWidgets('a dotted series key reads a nested field', (tester) async {
      final handle = tester.ensureSemantics();
      await _chart(tester, {
        'xKey': 'k',
        'showLegend': false,
        'series': ['sales.q1'],
        'yAxis': {'min': 0},
        'data': [
          {
            'k': 'a',
            'sales': {'q1': 5},
          },
        ],
      });
      expect(
        [for (final m in _scene<RechartsScene>(tester).marks) m.value],
        [5],
      );
      expect(
        tableRows(tester),
        tableOf(
          ['k', 'sales.q1'],
          [
            ['a', 'undefined'],
          ],
        ),
      );
      handle.dispose();
    });
  });
}

void _pieTests() {
  group('the pie (computePieSectors, PieLabels)', () {
    // Pie.js:348-374: the padding counts the non-zero slices of a whole
    // turn, and none comes before a 0 slice.
    testWidgets('padding on a whole turn, a 0 slice taking none', (
      tester,
    ) async {
      await _chart(tester, {
        'chartType': 'pie',
        'xKey': 'n',
        'paddingAngle': 10,
        'data': [
          {'n': 'a', 'v': 1},
          {'n': 'b', 'v': 0},
          {'n': 'c', 'v': 1},
        ],
      });
      final slices = _scene<RechartsPieScene>(tester).slices;
      // 360 - 2 × 10 = 340 for two non-zero slices.
      expect(slices[0].endAngle - slices[0].startAngle, closeTo(-170, 1e-9));
      expect(slices[1].startAngle, slices[0].endAngle);
      expect(slices[2].startAngle, closeTo(slices[1].endAngle - 10, 1e-9));
    });

    testWidgets('three equal slices on a padded whole turn', (tester) async {
      await _chart(tester, {
        'chartType': 'pie',
        'xKey': 'n',
        'paddingAngle': 10,
        'data': [
          {'n': 'a', 'v': 1},
          {'n': 'b', 'v': 1},
          {'n': 'c', 'v': 1},
        ],
      });
      final slices = _scene<RechartsPieScene>(tester).slices;
      for (final slice in slices) {
        expect(slice.endAngle - slice.startAngle, closeTo(-110, 1e-9));
      }
    });

    // Pie.js:142-150 (`getTextAnchor`): right of the centre starts there,
    // left of it ends there.
    testWidgets('slice labels anchor away from the centre', (tester) async {
      await _chart(tester, {
        'chartType': 'pie',
        'xKey': 'n',
        'showLegend': false,
        'showValueLabels': true,
        'data': [
          {'n': 'a', 'v': 1},
          {'n': 'b', 'v': 1},
        ],
      });
      final labels = _scene<RechartsPieScene>(tester).labels;
      expect(labels[0].anchor, RechartsTextAnchor.start);
      expect(labels[1].anchor, RechartsTextAnchor.end);
    });

    // Pie.js:253, :395-414: a key `value` reads the sector's value, 0 for
    // a missing one.
    testWidgets("a series named value is labelled with the sector's value", (
      tester,
    ) async {
      await _chart(tester, {
        'chartType': 'pie',
        'xKey': 'n',
        'showLegend': false,
        'showValueLabels': true,
        'series': ['value'],
        'data': [
          {'n': 'a', 'value': 3},
          {'n': 'b'},
        ],
      });
      expect(
        [for (final l in _scene<RechartsPieScene>(tester).labels) l.text],
        ['3', '0'],
      );
    });

    // DefaultTooltipContent.js:112-116: no name or separator for a null
    // name.
    testWidgets('a null name shows only the value', (tester) async {
      await _chart(tester, {
        'chartType': 'pie',
        'xKey': 'n',
        'showLegend': false,
        'data': [
          {'n': null, 'v': 10},
        ],
      });
      final pie = _scene<RechartsPieScene>(tester);
      await _hover(tester, _global(tester, pie.center));
      expect(find.text('10'), findsOneWidget);
      expect(find.textContaining(' : '), findsNothing);
    });

    // Pie.js:165 (`getPercentValue(innerRadius, max, 0)`).
    testWidgets('an inner radius recharts cannot read is 0', (tester) async {
      await _chart(tester, {
        'chartType': 'donut',
        'xKey': 'n',
        'innerRadius': 'abc',
        'data': [
          {'n': 'a', 'v': 1},
        ],
      });
      expect(_scene<RechartsPieScene>(tester).innerRadius, 0);
    });
  });
}

void _paintTests() {
  group('what is painted', () {
    // Chart.tsx:317-325, Rectangle.js:37-73: a negative bar rounds its
    // value end, the bottom.
    testWidgets('a negative bar rounds its bottom corners', (tester) async {
      await _chart(tester, {
        'xKey': 'k',
        'showLegend': false,
        'yAxis': {'min': -50, 'max': 50},
        'data': [
          {'k': 'a', 'v': -40},
        ],
      });
      final bar = _scene<RechartsScene>(tester).marks.single.rect;
      expect(
        tester.renderObject(_drawing),
        paints..something(
          paintedRRect(
            rrect: RRect.fromRectAndCorners(
              bar,
              bottomLeft: const Radius.circular(4),
              bottomRight: const Radius.circular(4),
            ),
          ),
        ),
      );
    });

    // Dots.js:38-46: a one-point line draws its dot with the Line's
    // `fill: '#fff'` and 2px stroke.
    testWidgets('a one-point line draws a white dot ringed in its colour', (
      tester,
    ) async {
      await _chart(tester, {
        'chartType': 'line',
        'xKey': 'k',
        'showLegend': false,
        'data': [
          {'k': 'a', 'v': 2},
        ],
      });
      expect(
        tester.renderObject(_drawing),
        paints
          ..something(paintedCircle(radius: 3, color: const Color(0xffffffff)))
          ..something(
            paintedCircle(
              radius: 3,
              color: _standard.color(A2uiColorToken.chart1),
              strokeWidth: 2,
              style: PaintingStyle.stroke,
            ),
          ),
      );
    });

    // Dots.js:65-75: an area's dots keep its 20% fill opacity.
    testWidgets("an area's dots are at its 20% opacity", (tester) async {
      await _chart(tester, {
        'chartType': 'area',
        'xKey': 'k',
        'showLegend': false,
        'showDots': true,
        'data': [
          {'k': 'a', 'v': 2},
          {'k': 'b', 'v': 3},
        ],
      });
      final c = _standard.color(A2uiColorToken.chart1);
      expect(
        tester.renderObject(_drawing),
        paints..something(
          paintedCircle(radius: 3, color: c.withValues(alpha: c.a * .2)),
        ),
      );
    });

    // Cursor.js:93-97 `#ccc`; Pie.js:559 `#fff`; SVG black for a colour
    // the browser cannot read.
    testWidgets("recharts' own colours: the line cursor #ccc", (tester) async {
      await _chart(tester, {
        'chartType': 'line',
        'xKey': 'k',
        'showLegend': false,
        'data': [
          {'k': 'a', 'v': 2},
          {'k': 'b', 'v': 3},
        ],
      });
      final scene = _scene<RechartsScene>(tester);
      await _hover(tester, _global(tester, scene.plot.center));
      expect(
        tester.renderObject(_drawing),
        paints..something(
          paintedLine(color: const Color(0xffcccccc), strokeWidth: 1),
        ),
      );
    });

    testWidgets("recharts' own colours: the pie's #fff edge", (tester) async {
      await _chart(tester, {
        'chartType': 'pie',
        'xKey': 'n',
        'data': [
          {'n': 'a', 'v': 1},
          {'n': 'b', 'v': 2},
        ],
      });
      expect(
        tester.renderObject(_drawing),
        paints..something(
          paintedPath(
            color: const Color(0xffffffff),
            style: PaintingStyle.stroke,
          ),
        ),
      );
    });

    testWidgets("recharts' own colours: SVG's black for an unreadable "
        'colour', (tester) async {
      await _chart(tester, {
        'xKey': 'k',
        'showLegend': false,
        'series': [
          {'key': 'v', 'color': 'not-a-colour'},
        ],
        'yAxis': {'min': 0},
        'data': [
          {'k': 'a', 'v': 2},
        ],
      });
      expect(
        tester.renderObject(_drawing),
        paints..something(paintedRRect(color: const Color(0xff000000))),
      );
    });

    // BUG(port) INV-028: the box stays white in the dark, its label in the
    // surface's text colour.
    testWidgets('the dark tooltip: a white box, a light label', (tester) async {
      await _chart(
        tester,
        {'xKey': 'week', 'showLegend': false, 'data': _signups},
        theme: _standardDark,
        brightness: Brightness.dark,
        width: 600,
      );
      await _hover(tester, _global(tester, const Offset(64 + 132 * 1.5, 100)));
      await tester.pumpAndSettle();
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RechartsTooltip),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((box.decoration! as BoxDecoration).color, const Color(0xffffffff));
      final title = tester.widget<RichText>(
        find
            .descendant(
              of: find.byType(RechartsTooltip),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect((title.text as TextSpan).toPlainText(), 'W2');
      expect(
        title.text.style?.color,
        _standardDark.color(A2uiColorToken.textDefault),
      );
    });
  });
}
