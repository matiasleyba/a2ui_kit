// The scenes of the playground's PieChart and Sparkline: their TanStack
// Charts definitions in the playground's `charts.tsx` (MIT, (c) Atai
// Barkai), drawn as @tanstack/charts 1.1.0 draws them (MIT, (c) Tanner
// Linsley): `dist/polar-pie.js` and `dist/polar.js` (`radialArc`, d3-shape
// 3.2.0's `arc`) for the pie, `dist/area.js`, `dist/line.js` and
// `dist/dot.js` for the Sparkline. See NOTICE.md.

import 'dart:math' as math;

import 'package:a2ui_kit/src/components/playground/charts/cartesian.dart';
import 'package:a2ui_kit/src/components/playground/charts/chart_kit.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/chart/arc.dart';
import 'package:a2ui_kit/src/foundation/chart/curve.dart';
import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_guides.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_interaction.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_scale.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_stack.dart';
import 'package:a2ui_kit/src/foundation/format/chart_format.dart';
import 'package:a2ui_kit/src/functions/calc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// One slice of a PieChart: `{label, value}` with a value of 0 or more.
@immutable
class PieRow {
  /// A slice.
  const PieRow(this.label, this.value);

  /// The name.
  final String label;

  /// The value.
  final double value;
}

/// A slice laid out by TanStack's pie.
class _Slice {
  _Slice(this.index, this.slice, this.color, this.path);

  final int index;
  final TanstackPieSlice slice;
  final Color color;
  final Path path;
}

/// The scene of a PieChart: TanStack's own pie in data order from 12
/// o'clock, 6px inside its box; a .025 rad gap after every slice with a
/// value (with more than one row); a donut's hole 64% of the radius;
/// corners 4px (2px on a pie); colours by label; the slices other than
/// the focused one fade to 35%; no focus ring.
class PieScene extends TanstackScene {
  /// The scene of [rows] at [size].
  PieScene({
    required Size size,
    required PlaygroundChartStyle style,
    required this.rows,
    required this.colors,
    required this.donut,
    required this.format,
    required this.unit,
  }) : super(size, style) {
    _build();
  }

  /// The slices' data.
  final List<PieRow> rows;

  /// The colour of each row's slice.
  final List<Color> colors;

  /// Whether there is a hole.
  final bool donut;

  /// The value format.
  final A2uiValueFormat? format;

  /// The value unit.
  final String? unit;

  final List<_Slice> _slices = [];
  late Offset _center;
  late double _outer;
  late double _inner;

  /// The outer radius.
  double get outerRadius => _outer;

  /// The inner radius.
  double get innerRadius => _inner;

  /// The slices' angles (radians, clockwise from 12 o'clock), for tests.
  List<(double, double)> get sliceAngles => [
    for (final s in _slices) (s.slice.startAngle, s.slice.endAngle),
  ];

  /// A PieChart has no focus strategy: the slice under the pointer.
  @override
  TanstackFocus? get focusStrategy => null;

  void _build() {
    // `margin: 0`, `guides: false`: the plot is the whole box; `polar({inset:
    // 6})`. @tanstack/charts 1.1.0 dist/polar.js:1527-1532
    _center = size.center(Offset.zero);
    _outer = math.max(0, math.min(size.width, size.height) / 2 - 6);
    _inner = donut ? _outer * .64 : 0;
    final slices = tanstackPie([
      for (final r in rows) r.value,
    ], gapAngle: rows.length > 1 ? .025 : 0);
    for (var i = 0; i < rows.length; i++) {
      final slice = slices[i];
      // @tanstack/charts 1.1.0 dist/polar.js:178: d3's arc with the pie's
      // pad angle, 0.
      final path = d3ArcPath(
        center: _center,
        innerRadius: _inner,
        outerRadius: _outer,
        startAngle: slice.startAngle,
        endAngle: slice.endAngle,
        cornerRadius: donut ? 4 : 2,
      );
      _slices.add(_Slice(i, slice, colors[i], path));
      // dist/polar.js:220-242: the point at the arc's centroid.
      final at = d3ArcPoint(
        _center,
        (_inner + _outer) / 2,
        slice.startAngle,
        slice.endAngle,
      );
      points.add(
        TanstackPoint(
          // charts.tsx: `radialArc(slices, {key: "label"})`, so the datum
          // key is the label, repeats and all (dist/mark.js:88-90); no `z`.
          // @tanstack/charts 1.1.0 dist/polar.js:159-161, :203
          key: tanstackPointKey('polar-0:arc-0', null, rows[i].label),
          markId: 'polar-0:arc-0',
          group: null,
          datum: i,
          x: at.dx,
          y: at.dy,
          xValue: (slice.startAngle + slice.endAngle) / 2,
          yValue: (_inner + _outer) / 2,
          color: colors[i],
        ),
      );
    }
  }

  /// The slices' paths, for tests.
  List<Path> get slicePaths => [for (final s in _slices) s.path];

  /// Whether the numbers [slice]'s path is made of are finite: d3's arc
  /// writes them into the slice's `d`, and the browser draws nothing from
  /// the first it can't parse (SVG 2, Paths, "Error handling in path
  /// data"). The arc's path can't be read back command by command, so a
  /// slice with any such number is left out whole.
  bool _finite(_Slice slice) =>
      _center.isFinite &&
      _outer.isFinite &&
      _inner.isFinite &&
      slice.slice.startAngle.isFinite &&
      slice.slice.endAngle.isFinite;

  @override
  void paint(Canvas canvas, PlotFocus? focus) {
    final primary = focus == null ? null : primaryOf(focus);
    for (final slice in _slices) {
      if (!_finite(slice)) continue;
      // charts.tsx: `{when: {focus: "unmatched"}, style: {opacity: .35}}`.
      final dim =
          primary != null &&
          !tanstackSameFocusedPoint(points[slice.index], primary);
      final color = slice.color;
      canvas.drawPath(
        slice.path,
        Paint()..color = color.withValues(alpha: color.a * (dim ? .35 : 1)),
      );
    }
  }

  /// The slice under [position]: a slice's affinity is its geometry, so
  /// only a slice that holds the pointer focuses (the last painted first).
  /// A slice whose numbers are not all finite holds nothing.
  // @tanstack/charts 1.1.0 dist/polar.js:248 (`affinity: "geometry"`) and
  // dist/nearest.js:21-66; a boundary point that is not finite is left out
  // of the slice's box (:357-370), and with none left the slice is no
  // target (:119-120).
  @override
  PlotFocus? focusAt(Offset position) {
    for (var i = _slices.length; i-- > 0;) {
      if (!_finite(_slices[i])) continue;
      if (_slices[i].path.contains(position)) return focusOn(points[i]);
    }
    return null;
  }

  @override
  ChartTooltipContent? tooltipOf(PlotFocus focus) {
    final primary = primaryOf(focus);
    if (primary == null) return null;
    final row = rows[primary.datum];
    final fraction = _slices[primary.datum].slice.fraction;
    return ChartTooltipContent(
      title: row.label,
      rows: [
        ChartTooltipRow(
          label: 'Value',
          value: fmtValue(row.value, format, unit),
          color: primary.color,
        ),
        ChartTooltipRow(
          label: 'Share',
          value: '${jsToFixed(fraction * 100, 1)}%',
        ),
      ],
    );
  }
}

/// The scene of a Sparkline: no axes; linear scales over the indexes and
/// the values (4px above and right, 2px below and left), a gradient from
/// the lowest value (30% to clear), a smooth 1.75px line and a 2.75px end
/// dot ringed by the surface; the focus a 3.5px dot of the line's colour.
class SparklineScene extends TanstackScene {
  /// The scene of [values] at [size].
  SparklineScene({
    required Size size,
    required PlaygroundChartStyle style,
    required this.values,
    required this.stroke,
    required this.surface,
    this.label,
  }) : super(size, style) {
    _build();
  }

  /// The values.
  final List<double> values;

  /// The line's colour.
  final Color stroke;

  /// The surface (the end dot's ring).
  final Color surface;

  /// The tooltip's row name.
  final String? label;

  final List<Offset> _at = [];
  final List<Offset> _base = [];
  final List<TanstackPoint> _areaPoints = [];
  final List<TanstackPoint> _linePoints = [];
  final List<TanstackPoint> _dotPoints = [];

  /// The points, for tests.
  List<Offset> get positions => List.unmodifiable(_at);

  // charts.tsx: `focus: "nearest-x"`, `maxFocusDistance: Infinity`.
  @override
  TanstackFocus get focusStrategy => TanstackFocus.nearestX;

  @override
  double get maxFocusDistance => double.infinity;

  void _build() {
    if (values.isEmpty) return;
    // `margin: {top: 4, right: 4, bottom: 2, left: 2}`, no guides.
    // @tanstack/charts 1.1.0 dist/scene.js:566-572
    final chart = Rect.fromLTWH(
      2,
      4,
      math.max(1, size.width - 2 - 4),
      math.max(1, size.height - 4 - 2),
    );
    final minimum = values.reduce(math.min);
    final x = tanstackLinearScale([
      for (var i = 0; i < values.length; i++) i.toDouble(),
    ]);
    // The y channel: the area's y2 and y1 (the lowest value), the line's
    // and the dot's.
    final y = tanstackLinearScale([
      ...values,
      for (final _ in values) minimum,
      ...values,
      values.last,
    ]);
    final n = values.length;
    for (var i = 0; i < n; i++) {
      _at.add(
        Offset(
          x.map(i.toDouble(), chart.left, chart.right),
          y.map(values[i], chart.bottom, chart.top),
        ),
      );
      _base.add(Offset(_at[i].dx, y.map(minimum, chart.bottom, chart.top)));
    }
    // The rows are `{i, v}` (charts.tsx) and every mark's x is `i`, unique:
    // the datum key is the index, and no mark has a `z` (dist/area.js:
    // 43-48, dist/line.js:60-65, dist/dot.js:41-46; the dot's data is the
    // last row alone, `rows.slice(-1)`, whose `i` is its key all the same).
    final keys = tanstackInferredKeys(
      [for (var i = 0; i < n; i++) null],
      [
        [for (var i = 0; i < n; i++) i],
      ],
    );
    TanstackPoint point(String markId, int i) => TanstackPoint(
      key: tanstackPointKey(markId, null, keys[i]),
      markId: markId,
      group: null,
      datum: i,
      x: _at[i].dx,
      y: _at[i].dy,
      xValue: i.toDouble(),
      yValue: values[i],
      color: stroke,
    );
    for (var i = 0; i < n; i++) {
      _areaPoints.add(point('area-y-0', i));
      _linePoints.add(point('line-1', i));
    }
    _dotPoints.add(point('dot-2', n - 1));
    points
      ..addAll(_areaPoints)
      ..addAll(_linePoints)
      ..addAll(_dotPoints);
    targets
      ..add(
        TanstackTarget.area(
          [..._at, ..._base.reversed],
          affinity: TanstackAffinity.x,
          points: _areaPoints,
        ),
      )
      ..add(
        TanstackTarget.polyline(
          _at,
          affinity: TanstackAffinity.x,
          strokeWidth: 1.75,
          points: _linePoints,
        ),
      )
      ..add(
        TanstackTarget.dot(
          _at.last,
          2.75,
          affinity: TanstackAffinity.xy,
          point: _dotPoints.single,
        ),
      );
  }

  @override
  void paint(Canvas canvas, PlotFocus? focus) {
    marks.clear();
    if (_at.isEmpty) return;
    // Each path up to its first point that is not finite (a value at the
    // end of a y domain whose span overflows a double): the area
    // (chart-kit.tsx:161-168, `smoothCurve.area`: the top, then the bottom
    // back, closed; curve.dart's `monotoneArea`), then the line
    // ([tanstackSvgPath]).
    final area = tanstackSvgPath((path) {
      addMonotonePath(path, _at);
      addMonotonePath(path, _base.reversed.toList(), move: false);
      path.close();
    });
    if (area != null) {
      final bounds = area.getBounds();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              stroke.withValues(alpha: stroke.a * .3),
              stroke.withValues(alpha: 0),
            ],
          ).createShader(bounds),
      );
    }
    final line = tanstackSvgPath((path) => addMonotonePath(path, _at));
    if (line != null) {
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.75
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = stroke,
      );
    }
    // The end dot's `<circle>` at NaN is not drawn (RULEBOOK section 6
    // item 3).
    if (_at.last.isFinite) {
      canvas
        ..drawCircle(_at.last, 2.75, Paint()..color = stroke)
        ..drawCircle(
          _at.last,
          2.75,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = surface,
        );
    }
    // `focusRing: {radius: 3.5, fill: stroke, strokeWidth: 0}`, for each
    // mark's focused point.
    for (final entry in [_areaPoints, _linePoints, _dotPoints]) {
      paintFocusRings(
        canvas,
        focus,
        entry,
        radius: 3.5,
        strokeWidth: 0,
        fill: stroke,
      );
    }
  }

  @override
  ChartTooltipContent? tooltipOf(PlotFocus focus) {
    final ordered = tanstackTooltipOrder(focusPoints(focus));
    if (ordered.isEmpty) return null;
    return ChartTooltipContent(
      rows: [
        for (final p in ordered.take(1))
          ChartTooltipRow(
            label: label ?? kSeriesFallback,
            value: fmtValue(values[p.datum]),
            color: stroke,
          ),
      ],
    );
  }
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/charts.tsx
