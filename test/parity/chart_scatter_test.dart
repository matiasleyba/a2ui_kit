// Parity tests of the standard Chart's spacing, ported from
// packages/react-core/src/v2/generative-ui/standard/__tests__/
// chart-scatter.test.tsx (MIT, (c) Atai Barkai). Each test names its
// upstream line.
//
// Parity for: Chart
//
// The React tests mock a 600 × 300 box and read recharts' SVG marks; these
// lay the Chart out 600px wide and 300px tall and read the marks of the
// scene it painted. Nothing upstream is bound to internals beyond the SVG
// class names the marks are found by, so every test is ported.

import 'dart:math' as math;

import 'package:a2ui_kit/src/components/standard/data/chart.dart';
import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

RechartsScene _scene(WidgetTester tester) {
  final paint = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .firstWhere((p) => p.painter is ChartScenePainter);
  return (paint.painter! as ChartScenePainter).scene as RechartsScene;
}

/// chart-scatter.test.tsx:25: the Chart 300px tall, no legend, no tooltip.
Future<RechartsScene> _renderChart(
  WidgetTester tester,
  Map<String, Object?> props,
) async {
  await renderStandard(tester, width: 600, [
    {
      'id': 'root',
      'component': 'Chart',
      'height': 300,
      'showLegend': false,
      'showTooltip': false,
      ...props,
    },
  ]);
  return _scene(tester);
}

/// A point's position along the category axis of [layout].
double _along(Offset point, String layout) =>
    layout == 'horizontal' ? point.dy : point.dx;

List<Offset> _scatterPoints(RechartsScene scene) => [
  for (final mark in scene.marks)
    if (mark.kind == 'point') mark.rect.center,
];

/// Jest's `toBeCloseTo(expected, digits)`: `|expected - actual|` under
/// 10^-digits / 2, strictly (`closeTo` would accept the bound itself).
Matcher _toBeCloseTo(double expected, int digits) => predicate<double>(
  (actual) => (expected - actual).abs() < math.pow(10, -digits) / 2,
  'within ${math.pow(10, -digits) / 2} of $expected (exclusive)',
);

/// chart-scatter.test.tsx:47: the gaps between [coordinates], relative to
/// the first, are [ratios] (`toBeCloseTo(ratio, 5)`).
void _expectGapRatios(List<double> coordinates, List<double> ratios) {
  expect(coordinates, hasLength(ratios.length + 1));
  final firstGap = coordinates[1] - coordinates[0];
  expect(firstGap.abs(), greaterThan(0));
  for (var index = 0; index < ratios.length; index++) {
    expect(
      (coordinates[index + 1] - coordinates[index]) / firstGap,
      _toBeCloseTo(ratios[index], 5),
    );
  }
}

void main() {
  group('Chart scatter spacing', () {
    // chart-scatter.test.tsx:59
    for (final layout in ['vertical', 'horizontal']) {
      testWidgets('spaces numeric xKey values continuously in $layout layout', (
        tester,
      ) async {
        final scene = await _renderChart(tester, {
          'chartType': 'scatter',
          'layout': layout,
          'xKey': 'amount',
          'data': [
            for (final amount in [100, 200, 400, 800])
              {'amount': amount, 'score': 10},
          ],
        });
        final points = _scatterPoints(scene);
        _expectGapRatios(
          [for (final p in points) _along(p, layout)],
          [1, 2, 4],
        );
      });
    }

    // chart-scatter.test.tsx:76
    for (final layout in ['vertical', 'horizontal']) {
      testWidgets(
        'positions unsorted data for multiple series and preserves the value '
        'axis in $layout layout',
        (tester) async {
          final data = [
            for (final amount in [400, 100, 800, 200])
              {
                'amount': amount,
                'first': amount / 1000,
                'second': amount / 2000,
                'ignored': amount * 2,
              },
          ];
          final scene = await _renderChart(tester, {
            'chartType': 'scatter',
            'layout': layout,
            'xKey': 'amount',
            'data': data,
            'series': [
              'first',
              {'key': 'second', 'label': 'Second series'},
            ],
            'yAxis': {'min': 0, 'max': 1, 'width': 72, 'label': 'Share'},
            'format': 'percent',
          });
          final points = _scatterPoints(scene);
          expect(points, hasLength(8));
          for (final (index, key) in ['first', 'second'].indexed) {
            final seriesPoints = points.sublist(index * 4, (index + 1) * 4);
            // Read the marks in data order, then compare by their x value.
            final ordered =
                [
                  for (var row = 0; row < data.length; row++)
                    (row: data[row], point: seriesPoints[row]),
                ]..sort(
                  (a, b) => (a.row['amount']! as int).compareTo(
                    b.row['amount']! as int,
                  ),
                );
            _expectGapRatios(
              [for (final entry in ordered) _along(entry.point, layout)],
              [1, 2, 4],
            );
            for (final (:row, :point) in ordered) {
              final value = row[key]! as double;
              if (layout == 'horizontal') {
                expect(point.dx, _toBeCloseTo(72 + value * (600 - 72 - 8), 5));
              } else {
                expect(point.dy, _toBeCloseTo(270 - value * (270 - 8), 5));
              }
            }
          }
          // The value axis' painted tick labels, and the painted title (the
          // scene records each as it paints it; a title that is not painted
          // leaves `axisTitle` null).
          expect(
            [for (final (_, label) in scene.valueLabelsOnAxis) label].join(),
            contains('100%'),
          );
          expect(scene.axisTitle, 'Share');
        },
      );
    }

    // chart-scatter.test.tsx:129
    for (final layout in ['vertical', 'horizontal']) {
      testWidgets('keeps string xKey values categorical in $layout layout', (
        tester,
      ) async {
        final scene = await _renderChart(tester, {
          'chartType': 'scatter',
          'layout': layout,
          'xKey': 'category',
          'data': [
            for (final category in ['100', '200', '400', '800'])
              {'category': category, 'score': 10},
          ],
        });
        _expectGapRatios(
          [for (final p in _scatterPoints(scene)) _along(p, layout)],
          [1, 1, 1],
        );
      });
    }

    // chart-scatter.test.tsx:150
    testWidgets('keeps mixed numeric and string scatter values categorical', (
      tester,
    ) async {
      final scene = await _renderChart(tester, {
        'chartType': 'scatter',
        'xKey': 'amount',
        'data': [
          for (final amount in <Object>[100, '200', 400, 800])
            {'amount': amount, 'score': 10},
        ],
      });
      _expectGapRatios(
        [for (final p in _scatterPoints(scene)) p.dx],
        [1, 1, 1],
      );
    });

    // chart-scatter.test.tsx:162
    for (final chartType in ['bar', 'line']) {
      testWidgets('keeps numeric xKey values categorical for $chartType '
          'charts', (tester) async {
        final scene = await _renderChart(tester, {
          'chartType': chartType,
          'xKey': 'amount',
          'showDots': true,
          'data': [
            for (final amount in [100, 200, 400, 800])
              {'amount': amount, 'score': 10},
          ],
        });
        final centers = [
          for (final mark in scene.marks)
            if (mark.kind == (chartType == 'bar' ? 'bar' : 'dot'))
              mark.rect.center.dx,
        ];
        _expectGapRatios(centers, [1, 1, 1]);
      });
    }
  });
}
