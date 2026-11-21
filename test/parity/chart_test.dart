// Parity tests of CopilotKit's standard Chart, ported from
// packages/react-core/src/v2/generative-ui/standard/__tests__/chart.test.tsx
// and the Chart helpers of
// packages/shared/src/generative-ui/standard/__tests__/standard-helpers.test.ts
// (MIT, (c) Atai Barkai). Each test names its upstream file and line.
//
// Parity for: Chart
//
// The React tests read recharts' SVG; these read the scene the Flutter
// Chart painted (the same labels, leader lines and slices).
//
// Translated (upstream reads the chart.js config of the Angular renderer;
// the tests read the Flutter Chart, so they count as ported):
// - standard-helpers.test.ts:198 "maps a bar chart to chart.js labels,
//   datasets and colors", :229 "maps a pie chart to one dataset with a
//   palette color for each slice", :257 "paints with the color that the
//   element's custom property sets" and :268 "adds the value labels plugin
//   only when showValueLabels is set": the categories, the series label
//   and value, the first palette colour, a 4px bar radius, a palette colour
//   per slice, a theme colour overriding the palette, value labels only
//   when asked, each tested through the Flutter Chart below.
//
// Not ported (bound to internals):
// - standard-helpers.test.ts:319-339 (`resolveCssColor`, `withAlpha`):
//   CSS custom properties and hex strings for a canvas; the theme holds
//   resolved colours in Flutter.

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/data/chart.dart';
import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:a2ui_kit/src/foundation/chart/recharts.dart';
import 'package:a2ui_kit/src/foundation/format/chart_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/paint_calls.dart';
import '../helpers/parity.dart';

/// The scene the Chart painted.
T _scene<T>(WidgetTester tester) {
  final paint = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .firstWhere((p) => p.painter is ChartScenePainter);
  return (paint.painter! as ChartScenePainter).scene as T;
}

final _standard = A2uiKitTheme.standard(Brightness.light);

/// Upstream's `renderSurface(standardUI, [{ component: "Chart", ... }])`.
Future<ParitySurface> _pumpChart(
  WidgetTester tester,
  Map<String, Object?> props, {
  double width = 320,
}) => renderStandard(tester, width: width, [
  {'id': 'root', 'component': 'Chart', ...props},
]);

/// Upstream's `rerender` of the Chart with [props].
Future<void> _rerender(ParitySurface view, Map<String, Object?> props) =>
    view.update([
      agentComponents([
        {'id': 'root', 'component': 'Chart', ...props},
      ]),
    ]);

const List<Map<String, Object>> _data = [
  {'name': 'First', 'amount': 0.4},
  {'name': 'Second', 'amount': 0.35},
  {'name': 'Third', 'amount': 0.25},
];

List<String> _sliceLabels(WidgetTester tester) => [
  for (final label in _scene<RechartsPieScene>(tester).labels) label.text,
];

void main() {
  for (final chartType in ['donut', 'pie']) {
    group('Chart $chartType slice labels', () {
      // chart.test.tsx:42
      final props = <String, Object?>{
        'chartType': chartType,
        'data': _data,
        'xKey': 'name',
        'series': ['amount'],
        'showLegend': false,
        'showTooltip': false,
        'showValueLabels': true,
      };

      // chart.test.tsx:52
      testWidgets('formats fractional values as percentages', (tester) async {
        await _pumpChart(tester, {...props, 'format': 'percent'});
        expect(_sliceLabels(tester), ['40%', '35%', '25%']);
        expect(_scene<RechartsPieScene>(tester).labelLines, hasLength(3));
      });

      // chart.test.tsx:63
      testWidgets('uses the requested currency for the slice values', (
        tester,
      ) async {
        await _pumpChart(tester, {
          ...props,
          'data': [
            for (final row in _data)
              {...row, 'amount': (row['amount']! as double) * 100},
          ],
          'format': 'currency',
          'currency': 'EUR',
        });
        expect(_sliceLabels(tester), ['€40', '€35', '€25']);
      });

      // chart.test.tsx:80
      testWidgets(
        'preserves raw values and label positions when formatting is absent',
        (tester) async {
          final view = await _pumpChart(tester, props);
          expect(_sliceLabels(tester), ['0.4', '0.35', '0.25']);
          List<(Offset, RechartsTextAnchor)> positions() => [
            for (final label in _scene<RechartsPieScene>(tester).labels)
              (label.at, label.anchor),
          ];
          final originalPositions = positions();
          final originalLines = [
            ..._scene<RechartsPieScene>(tester).labelLines,
          ];

          await _rerender(view, {...props, 'format': 'percent'});

          expect(_sliceLabels(tester).first, '40%');
          expect(positions(), originalPositions);
          expect(_scene<RechartsPieScene>(tester).labelLines, originalLines);
        },
      );

      // chart.test.tsx:110
      for (final showValueLabels in [false, null]) {
        testWidgets('hides labels and leader lines when showValueLabels is '
            '$showValueLabels', (tester) async {
          // `showValueLabels={undefined}` leaves the prop out.
          await _pumpChart(tester, {
            for (final entry in props.entries)
              if (entry.key != 'showValueLabels') entry.key: entry.value,
            'format': 'percent',
            'showValueLabels': ?showValueLabels,
          });
          final scene = _scene<RechartsPieScene>(tester);
          expect(scene.slices, hasLength(3));
          expect(scene.labels, isEmpty);
          expect(scene.labelLines, isEmpty);
        });
      }

      // chart.test.tsx:133
      testWidgets('can hide leader lines while keeping formatted labels', (
        tester,
      ) async {
        await _pumpChart(tester, {
          ...props,
          'format': 'percent',
          'showLabelLines': false,
        });
        expect(_sliceLabels(tester), ['40%', '35%', '25%']);
        expect(_scene<RechartsPieScene>(tester).labelLines, isEmpty);
      });
    });
  }

  group('normalizeSeries', () {
    // standard-helpers.test.ts:278
    test(
      'charts every number field except the x key when no series is set',
      () {
        expect(
          normalizeChartSeries(
            // Upstream passes `undefined`; the Chart reads a missing
            // `series` as an empty list (ChartProps.series), and both take
            // the same branch (Chart.tsx:79).
            const [],
            const [
              {'day': 'Mon', 'food': 3, 'rent': 10, 'note': 'x'},
            ],
            'day',
            _standard,
          ),
          [
            StandardChartSeries(
              'food',
              'food',
              _standard.color(A2uiColorToken.chart1),
            ),
            StandardChartSeries(
              'rent',
              'rent',
              _standard.color(A2uiColorToken.chart2),
            ),
          ],
        );
      },
    );
  });

  group('makeFormatter', () {
    // standard-helpers.test.ts:293
    test('gives no formatter when no format is set', () {
      expect(standardChartFormatter(null, null), isNull);
    });

    // standard-helpers.test.ts:297
    test('formats currency in USD by default, compact from 10,000', () {
      final format = standardChartFormatter(ChartFormat.currency, null)!;
      expect(format(290), r'$290');
      expect(format(16000), r'$16K');
    });

    // standard-helpers.test.ts:303
    test('formats a fraction as a percentage and uses the requested '
        'currency', () {
      expect(standardChartFormatter(ChartFormat.percent, null)!(0.25), '25%');
      expect(standardChartFormatter(ChartFormat.currency, 'EUR')!(40), '€40');
    });

    // standard-helpers.test.ts:308
    test('falls back to plain numbers for an unknown currency code', () {
      expect(
        standardChartFormatter(ChartFormat.currency, 'not-a-code')!(1290),
        '1,290',
      );
    });

    // standard-helpers.test.ts:312
    test('prints a value that is not a number as text', () {
      final format = standardChartFormatter(ChartFormat.number, null)!;
      expect(format('n/a'), 'n/a');
      expect(format(null), '');
    });
  });

  group('the chart.js config behaviours, through the Flutter Chart', () {
    // standard-helpers.test.ts:198 (behaviour)
    testWidgets('a bar chart: categories, the series, values and colours', (
      tester,
    ) async {
      await _pumpChart(tester, {
        'xKey': 'month',
        'data': [
          {'month': 'Jan', 'cost': 290},
          {'month': 'Feb', 'cost': 580},
        ],
        'series': [
          {'key': 'cost', 'label': 'Monthly cost'},
        ],
        'showLegend': false,
      });
      final scene = _scene<RechartsScene>(tester);
      expect(
        [for (final (_, label) in scene.categoryTicks) label],
        ['Jan', 'Feb'],
      );
      expect([for (final mark in scene.marks) mark.value], [290, 580]);
      expect(scene.series.single.label, 'Monthly cost');
      expect(scene.series.single.color, const Color(0xff7fb0f2));
      expect(scene.labels, isEmpty);
      // `indexAxis: "x"` (standard-helpers.test.ts:220-224): the bars stand
      // on the bottom axis, one category per band along x.
      final jan = scene.marks.first.rect;
      final feb = scene.marks.last.rect;
      expect(jan.bottom, scene.plot.bottom);
      expect(feb.bottom, scene.plot.bottom);
      expect(feb.left, greaterThan(jan.right));
      // `borderRadius: 4` (ib.): the bar painted with its value end rounded
      // 4px and its base square.
      final painted = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ChartScenePainter,
      );
      // `paints..rrect` would compare the next rrect painted only: the
      // predicate finds Jan's bar among every call (RULEBOOK section 6,
      // item 3).
      expect(
        tester.renderObject(painted),
        paints..something(
          paintedRRect(
            rrect: RRect.fromRectAndCorners(
              jan,
              topLeft: const Radius.circular(4),
              topRight: const Radius.circular(4),
            ),
          ),
        ),
      );
    });

    // standard-helpers.test.ts:229 (behaviour)
    testWidgets('a pie chart: a palette colour for each slice', (tester) async {
      await _pumpChart(tester, {
        'chartType': 'pie',
        'xKey': 'name',
        'data': [
          {'name': 'A', 'share': 0.6},
          {'name': 'B', 'share': 0.4},
        ],
      });
      final scene = _scene<RechartsPieScene>(tester);
      expect([for (final s in scene.slices) s.name], ['A', 'B']);
      expect([for (final s in scene.slices) s.value], [0.6, 0.4]);
      expect(
        [for (final s in scene.slices) s.color],
        const [Color(0xff7fb0f2), Color(0xff2f6fd1)],
      );
      // `cutout: 0, radius: "80%"`, a whole turn. The pie keeps 5px margins;
      // the legend under it holds the bottom one.
      expect(scene.innerRadius, 0);
      final box = Size(320 - 10, scene.size.height - 5);
      expect(scene.outerRadius, closeTo(box.shortestSide / 2 * .8, 1e-9));
      expect(
        (scene.slices.last.endAngle - scene.slices.first.startAngle).abs(),
        360,
      );
    });

    // standard-helpers.test.ts:257 (behaviour)
    testWidgets("paints with the theme's chart colour", (tester) async {
      await renderStandard(
        tester,
        theme: _standard.withColors({
          A2uiColorToken.chart1: const Color(0xffff0000),
        }),
        [
          {
            'id': 'root',
            'component': 'Chart',
            'xKey': 'q',
            'data': [
              {'q': 'Q1', 'a': 1},
            ],
          },
        ],
      );
      expect(_scene<RechartsScene>(tester).marks.single.series, 'a');
      expect(
        _scene<RechartsScene>(tester).series.single.color,
        const Color(0xffff0000),
      );
    });

    // standard-helpers.test.ts:268 (behaviour)
    testWidgets('value labels only when showValueLabels is set', (
      tester,
    ) async {
      await _pumpChart(tester, {
        'xKey': 'q',
        'data': [
          {'q': 'Q1', 'a': 1},
        ],
        'showValueLabels': true,
      });
      expect(
        [for (final label in _scene<RechartsScene>(tester).labels) label.text],
        ['1'],
      );
    });
  });
}
