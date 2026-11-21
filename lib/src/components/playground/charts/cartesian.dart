// The scenes of the playground's cartesian charts (LineChart, AreaChart,
// BarChart and ScatterChart): their TanStack Charts definitions in the
// playground's `charts.tsx` (MIT, (c) Atai Barkai), drawn as
// @tanstack/charts 1.1.0 draws them (MIT, (c) Tanner Linsley).
//
// Ported from TanStack's published source at the version the playground's
// lockfile pins: the marks (`dist/line.js`, `dist/area.js`, `dist/bar.js`,
// `dist/dot.js`), the scene and its guides (`dist/scene.js`, through
// `foundation/chart/tanstack_guides.dart`), the scales
// (`tanstack_scale.dart`), the stacks (`tanstack_stack.dart`) and the
// focus, keyboard and tooltip rules (`tanstack_interaction.dart`). Each
// block cites its source line. See NOTICE.md.

import 'dart:math' as math;

import 'package:a2ui_kit/src/components/playground/charts/chart_kit.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/chart/curve.dart';
import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:a2ui_kit/src/foundation/chart/scale.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_guides.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_interaction.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_scale.dart';
import 'package:a2ui_kit/src/foundation/chart/tanstack_stack.dart';
import 'package:a2ui_kit/src/foundation/format/chart_format.dart';
import 'package:a2ui_kit/src/functions/validators.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// The value axes' tick count (`valueAxis`: `ticks.count` 5).
const double _valueTickCount = 5;

/// TanStack's default `maxFocusDistance`.
// @tanstack/charts 1.1.0 dist/renderer.js:910-912
const double _defaultFocusDistance = 48;

/// A tick of an axis: where it is and its text.
@immutable
class AxisTick {
  /// A tick at [position] (pixels) reading [label].
  const AxisTick(this.position, this.label);

  /// The position along the axis, in pixels.
  final double position;

  /// The text.
  final String label;
}

/// A mark the scene drew, for tests: its kind, where it is, its value.
@immutable
class SceneMark {
  /// A mark.
  const SceneMark(this.kind, this.rect, {this.value, this.series, this.color});

  /// What it is: `bar`, `dot`, `point`, `line`, `area`.
  final String kind;

  /// Its box (a dot's centre is the box's centre).
  final Rect rect;

  /// Its data value, or null.
  final double? value;

  /// Its series, or null.
  final String? series;

  /// Its colour, or null.
  final Color? color;
}

/// The x of a cartesian row as the chart's x channel reads it: the number,
/// or its text when not every x is a number (`xOf` in charts.tsx).
Object _xOf(ChartRow row, {required bool numeric}) => switch (row.x) {
  final num n when numeric => n.toDouble(),
  _ => row.xText,
};

/// The series name of a row (`seriesName`).
String _seriesOf(ChartRow row) => row.series ?? kSeriesFallback;

double? _numberOf(Object value) => switch (value) {
  final num n => n.toDouble(),
  _ => null,
};

/// What the playground's TanStack scenes share: the points a focus reads,
/// the targets a pointer hits, the focus strategy, the keyboard order and
/// the tooltip's place.
abstract class TanstackScene extends PlotScene {
  /// A scene of [size] in [style].
  TanstackScene(this.size, this.style);

  @override
  final Size size;

  /// The text and colours.
  final PlaygroundChartStyle style;

  /// The marks drawn, for tests.
  final List<SceneMark> marks = [];

  /// The scene's points, mark by mark (`scene.points`).
  ///
  /// A value at the end of a domain whose span overflows a double (y =
  /// 1e308 with -1e308) maps to NaN (`interpolate`, dist/scales/linear.js:
  /// 76-81), and TanStack hands it to the SVG as it is. The browser draws
  /// nothing for a coordinate it can't parse (RULEBOOK section 6 item 3),
  /// so such a point is drawn nowhere: the painters skip a place that is
  /// not finite. It is a point all the same: the keys and the pointer
  /// reach it as TanStack's own comparisons decide, with JavaScript's NaN
  /// semantics (an axis focus skips a point by `nextDistance >= distance`,
  /// dist/focus.js:16-21, so a NaN distance wins, and every later point
  /// after it; the nearest point keeps one by `<` or `<=`,
  /// dist/nearest.js:14, :42, :55, which a NaN never wins; a NaN difference
  /// falls through `||`), and a focus on it shows its tooltip, its anchor at
  /// NaN where TanStack's is.
  final List<TanstackPoint> points = [];

  /// What a pointer hits, in paint order.
  final List<TanstackTarget> targets = [];

  /// The focus strategy (`focus`), or null for the nearest point.
  TanstackFocus? get focusStrategy;

  /// How far from a point the pointer still focuses it
  /// (`maxFocusDistance`).
  double get maxFocusDistance => _defaultFocusDistance;

  /// The point [focus] names (its primary point), or null.
  TanstackPoint? primaryOf(PlotFocus focus) =>
      focus.group >= 0 && focus.group < points.length
      ? points[focus.group]
      : null;

  /// The points [focus] shows: its primary point, then its group's others.
  // @tanstack/charts 1.1.0 dist/renderer.js:878-882 (`focusPointsForPoint`)
  List<TanstackPoint> focusPoints(PlotFocus focus) {
    final primary = primaryOf(focus);
    return primary == null
        ? const []
        : tanstackFocusGroup(focusStrategy, points, primary);
  }

  /// The focus on [point], or null.
  PlotFocus? focusOn(TanstackPoint? point) {
    if (point == null) return null;
    final index = points.indexOf(point);
    return index < 0 ? null : PlotFocus(index);
  }

  // Every point, drawn or not (@tanstack/charts 1.1.0 dist/renderer.js:
  // 857-873 hands `interactionPoints()`, the scene's points, to the
  // strategy or to `nearestScenePoint`).
  @override
  PlotFocus? focusAt(Offset position) {
    final focused = tanstackPointerFocus(
      focus: focusStrategy,
      targets: targets,
      points: points,
      x: position.dx,
      y: position.dy,
      maxDistance: maxFocusDistance,
    );
    return focused.isEmpty ? null : focusOn(focused.first);
  }

  // @tanstack/charts 1.1.0 dist/renderer.js:658-663: the focus strategy's
  // navigation order, else screen order, over every point (`points =
  // interactionPoints()`, :635), drawn or not.
  @override
  PlotFocus? navigate(PlotFocus? focus, PlotNavigation key) {
    final current = focus == null ? null : primaryOf(focus);
    final tanstackKey = switch (key) {
      PlotNavigation.next => TanstackKey.next,
      PlotNavigation.previous => TanstackKey.previous,
      PlotNavigation.first => TanstackKey.first,
      PlotNavigation.last => TanstackKey.last,
    };
    final strategy = focusStrategy;
    final point = strategy == null
        ? tanstackPointFromSceneOrder(points, current, tanstackKey)
        : tanstackPointFromNavigationOrder(
            tanstackFocusNavigation(strategy, points),
            current,
            tanstackKey,
          );
    return focusOn(point);
  }

  /// The key of the point [focus] names ([TanstackFocusKey]), or null.
  // @tanstack/charts 1.1.0 dist/renderer.js:161-171: a kept focus is found
  // again by its point (`previousFocusedPoint`).
  @override
  TanstackFocusKey? focusKeyOf(PlotFocus focus) {
    final point = primaryOf(focus);
    return point == null ? null : TanstackFocusKey.of(point);
  }

  /// The focus on the point a [TanstackFocusKey] names
  /// ([tanstackRestoreFocusPoint]), drawn or not, or null when there is
  /// none.
  // @tanstack/charts 1.1.0 dist/renderer.js:162-168 and
  // dist/interaction.js:33-47 (`restoreChartFocusPoint`)
  @override
  PlotFocus? focusOfKey(Object key, {bool sameRows = false}) =>
      key is TanstackFocusKey
      ? focusOn(tanstackRestoreFocusPoint(points, key, sameRows: sameRows))
      : null;

  @override
  PlotFocus? step(PlotFocus? focus, int delta) {
    if (delta == 0) {
      return focus != null && primaryOf(focus) != null ? focus : null;
    }
    return navigate(
      focus,
      delta > 0 ? PlotNavigation.next : PlotNavigation.previous,
    );
  }

  /// The tooltip's anchor: the primary point (`anchor: "point"`), at NaN
  /// where the point is.
  // @tanstack/charts 1.1.0 dist/tooltip-model.js:30-38
  @override
  Offset anchorOf(PlotFocus focus) {
    final point = primaryOf(focus);
    return point == null ? Offset.zero : Offset(point.x, point.y);
  }

  /// The tooltip's `left` and `top`, each NaN where TanStack's arithmetic
  /// gives NaN (an anchor at NaN: `Math.max` and `Math.min` keep it).
  // @tanstack/charts 1.1.0 dist/tooltip.js:132-158 (`position`, the scene's
  // box as the boundary), dist/tooltip-placement.js:7-70
  @override
  Offset tooltipPosition(PlotFocus focus, Offset? pointer, Size tooltip) =>
      tanstackTooltipPlacement(anchorOf(focus), tooltip, Offset.zero & size);

  /// The static position of TanStack's tooltip, where an axis whose
  /// `left` or `top` never parsed puts it: the left edge, just below the
  /// chart's `<svg>`, `(0, size.height)`.
  ///
  /// The tooltip is a `<div>` (a block once shown: `hidden` removed,
  /// dist/tooltip.js:48-49) with `position: absolute` and neither `left`
  /// nor `top` until it is placed (:312-326, 184-196: also `right` and
  /// `bottom` `auto`, `margin: 0`), appended last to the chart's
  /// container (:106-113, :184-187; the renderer's own container,
  /// dist/renderer.js:923-924), whose only other child is the `<svg>`
  /// (dist/reconcile.js:25-36, `replaceChildren` of the rendered markup;
  /// no host controls: the playground's definitions set no `controls` and
  /// no colour `legend`, dist/scene.js:237-271, dist/renderer.js:802-822).
  /// The container is `.ts-chart-surface`, `width: 100%; height:
  /// 100%`, no padding (dist/react/RendererChart.js:10-23, inside the host
  /// `.ts-chart-host`, `position: relative`, :100-113), and the renderer
  /// makes it the positioned ancestor (`position: relative` when it is
  /// static, dist/renderer.js:90-96). The `<svg>` is `display:block` and
  /// `height="100%"` (dist/svg-renderer.js:25): a block as tall as the
  /// container, the scene's height. So the tooltip's static position (CSS
  /// 2.1 section 10.3.7 and 10.6.4: where it would sit in normal flow) is
  /// at the container's left, under the `<svg>`.
  @override
  Offset get tooltipStaticPlace => Offset(0, size.height);

  /// Paints the focus ring of every point of [entry] that is [focus]'s
  /// datum: a [radius] circle of [fill] (the surface) ringed [strokeWidth]
  /// in the point's colour (`THEME.focusRing`). A point whose place is not
  /// finite gets none.
  // @tanstack/charts 1.1.0 dist/scene.js:280-316 (the default focus
  // layers, `match: "primary"`) and dist/focus-layer.js:233-255; a ring's
  // `<circle>` at NaN is not drawn (RULEBOOK section 6 item 3)
  void paintFocusRings(
    Canvas canvas,
    PlotFocus? focus,
    List<TanstackPoint> entry, {
    double radius = 4.5,
    double strokeWidth = 2,
    Color? fill,
  }) {
    if (focus == null) return;
    final primary = primaryOf(focus);
    if (primary == null) return;
    for (final point in entry) {
      if (!tanstackSameFocusedPoint(point, primary)) continue;
      final at = Offset(point.x, point.y);
      if (!at.isFinite) continue;
      marks.add(
        SceneMark(
          'ring',
          Rect.fromCircle(center: at, radius: radius),
          series: point.group?.toString(),
          color: point.color,
        ),
      );
      canvas.drawCircle(
        at,
        radius,
        Paint()..color = fill ?? style.tokens.surface,
      );
      if (strokeWidth > 0) {
        canvas.drawCircle(
          at,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..color = point.color,
        );
      }
    }
  }
}

/// The pieces the cartesian scenes share: the layout of the axes, the
/// grid and the labels.
abstract class _CartesianScene extends TanstackScene {
  _CartesianScene(super.size, super.style);

  /// The layout of the plot and its axes.
  late TanstackCartesianLayout layout;

  /// The plot's box.
  Rect get plot => layout.chart;

  /// Every tick of the bottom axis.
  List<AxisTick> bottomTicks = const [];

  /// Every tick of the left axis.
  List<AxisTick> leftTicks = const [];

  /// The bottom tick labels drawn (thinned).
  List<String> get bottomLabels => [for (final l in layout.xLabels) l.text];

  /// The left tick labels drawn (thinned).
  List<String> get leftLabels => [for (final l in layout.yLabels) l.text];

  /// Lays the axes out and keeps their ticks.
  void lay(TanstackAxisGuide x, TanstackAxisGuide y) {
    layout = TanstackCartesianLayout.resolve(
      size: size,
      text: style.text,
      tickColor: style.tickColor,
      titleColor: style.titleColor,
      x: x,
      y: y,
    );
    bottomTicks = [
      for (final t in layout.xTicks ?? const <TanstackTick>[])
        AxisTick(t.position, t.label),
    ];
    leftTicks = [
      for (final t in layout.yTicks ?? const <TanstackTick>[])
        AxisTick(t.position, t.label),
    ];
  }

  /// Paints the axes' labels and titles (the `axes` group, after the
  /// marks: `dist/scene.js:234-236`).
  void paintAxes(Canvas canvas) {
    final text = style.text;
    for (final label in layout.xLabels) {
      text.paint(canvas, label);
    }
    if (layout.xTitle case final TanstackLabel title) text.paint(canvas, title);
    for (final label in layout.yLabels) {
      text.paint(canvas, label);
    }
    if (layout.yTitle case final TanstackLabel title) text.paint(canvas, title);
  }

  /// Paints the grid rules of [ticks] (`vertical` for an x axis).
  void paintGrid(Canvas canvas, List<AxisTick> ticks, {bool vertical = false}) {
    paintTanstackGrid(
      canvas,
      plot,
      [for (final t in ticks) t.position],
      style.tokens.charts.grid,
      vertical: vertical,
    );
  }
}

/// A segment of a series of a line or area mark: its points in data order.
/// A line's series is one segment (every row is complete); an area's ends
/// at a row whose stacked extent is not finite (dist/area.js:128-131).
class _Segment {
  _Segment(this.group, this.color, this.fade);

  /// The series (`z`), or null.
  final String? group;

  /// Its colour.
  final Color color;

  /// The palette colour of its fade.
  final Color fade;

  final List<TanstackPoint> points = [];
  final List<Offset> top = [];
  final List<Offset> bottom = [];
}

/// The kind of a [LineAreaScene].
enum LineAreaKind {
  /// A LineChart.
  line,

  /// An unstacked AreaChart: a fade and a line per series.
  area,

  /// A stacked AreaChart.
  stackedArea,
}

/// The scene of a LineChart or an AreaChart: x a nice linear scale (one
/// tick per 92px, 2 to 8) when every x is a number, else points in
/// first-appearance order (padding .25 for lines, .02 for areas); y a nice
/// linear scale asked for 5 ticks over a dashed grid; monotone curves in data
/// order; the crosshair and the focus ring of the focused point.
class LineAreaScene extends _CartesianScene {
  /// The scene of [rows] at [size].
  LineAreaScene({
    required Size size,
    required PlaygroundChartStyle style,
    required this.kind,
    required this.rows,
    required this.names,
    required this.colors,
    required this.format,
    required this.unit,
    required this.title,
    this.curve = true,
  }) : super(size, style) {
    _build();
  }

  /// What is drawn.
  final LineAreaKind kind;

  /// The rows.
  final List<ChartRow> rows;

  /// The series, in order.
  final List<String> names;

  /// The colour of each series.
  final List<Color> colors;

  /// The value format, or null.
  final A2uiValueFormat? format;

  /// The value unit, or null.
  final String? unit;

  /// The chart's title (a single series' tooltip label).
  final String? title;

  /// Whether lines are smooth (`curve !== false`).
  final bool curve;

  late final bool _numericX = rows.isNotEmpty && rows.every((r) => r.x is num);
  late final bool _single = names.length == 1;

  /// Whether a LineChart's single series gets a fade (`single &&
  /// nonNegative`).
  late final bool _fade =
      kind == LineAreaKind.line && _single && rows.every((r) => r.y >= 0);

  final List<_Segment> _areas = [];
  final List<_Segment> _lines = [];

  /// The points of the area mark, then those of the line mark.
  final List<TanstackPoint> _areaPoints = [];
  final List<TanstackPoint> _linePoints = [];

  /// The stack of a stacked AreaChart's [rows] (`stack({order: names})`):
  /// each row's extent. Throws [TanstackStackError] for two rows of one
  /// series at one x, as TanStack does.
  // @tanstack/charts 1.1.0 dist/area.js:40 (`stackValues`)
  static List<TanstackExtent?> stackOf(
    List<ChartRow> rows,
    List<String> names,
  ) {
    final numeric = rows.isNotEmpty && rows.every((r) => r.x is num);
    return tanstackStackValues(
      [for (final r in rows) _xOf(r, numeric: numeric)],
      [for (final r in rows) r.y],
      [for (final r in rows) _seriesOf(r)],
      order: names,
    );
  }

  @override
  TanstackFocus get focusStrategy => kind == LineAreaKind.line && _single
      ? TanstackFocus.nearestX
      : TanstackFocus.groupX;

  // charts.tsx: `maxFocusDistance: Number.POSITIVE_INFINITY`.
  @override
  double get maxFocusDistance => double.infinity;

  void _build() {
    final extents = kind == LineAreaKind.stackedArea
        ? stackOf(rows, names)
        : null;
    // The y channel: the area's y2 and y1 values, then the line's.
    // @tanstack/charts 1.1.0 dist/area.js:62-69, dist/line.js:83-86
    final yValues = <double>[
      if (extents != null)
        for (final e in extents) ...[?e?.end, ?e?.start]
      else ...[
        if (_fade || kind == LineAreaKind.area) ...[
          for (final r in rows) r.y,
          for (final _ in rows) 0.0,
        ],
        for (final r in rows) r.y,
      ],
    ];
    final yScale = tanstackLinearScale(
      yValues,
      // A stacked area has no y1, so its channel takes in 0.
      includeZero: extents != null,
      niceCount: _valueTickCount,
    );
    final yTick = playgroundTickFormatter(format, unit);
    final xKeys = xDomainOf(rows);
    final xNumbers = [for (final r in rows) ?_numberOf(r.x)];
    TanstackLinearScale xLinear(Rect chart) => tanstackLinearScale(
      xNumbers,
      niceCount: tanstackTickCount(length: chart.width, x: true),
    );
    final xPoints = PointScale(
      xKeys,
      padding: kind == LineAreaKind.line ? .25 : .02,
    );
    lay(
      TanstackAxisGuide(
        categorical: !_numericX,
        ticks: (chart) {
          if (!_numericX) {
            return [
              for (var i = 0; i < xKeys.length; i++)
                TanstackTick(
                  xKeys[i],
                  xPoints.position(i, chart.left, chart.right),
                  xKeys[i],
                ),
            ];
          }
          // A numeric x has no `format`: the scale's own `tickFormat`.
          // @tanstack/charts 1.1.0 dist/configured-scale.js:23-41
          final count = tanstackTickCount(length: chart.width, x: true);
          final scale = xLinear(chart);
          final label = scale.tickFormat(count);
          return [
            for (final t in scale.ticks(count))
              TanstackTick(t, scale.map(t, chart.left, chart.right), label(t)),
          ];
        },
      ),
      TanstackAxisGuide(
        ticks: (chart) => [
          for (final t in yScale.ticks(_valueTickCount))
            TanstackTick(t, yScale.map(t, chart.bottom, chart.top), yTick(t)),
        ],
      ),
    );
    final chart = plot;
    final xScale = _numericX ? xLinear(chart) : null;
    final keyIndex = {for (var i = 0; i < xKeys.length; i++) xKeys[i]: i};
    double xAt(ChartRow r) => xScale == null
        ? xPoints.position(keyIndex[r.xText]!, chart.left, chart.right)
        : xScale.map(_numberOf(r.x)!, chart.left, chart.right);
    double yAt(double v) => yScale.map(v, chart.bottom, chart.top);

    // Each mark's datum keys: the x value when it is unique in its series,
    // else the row's index (dist/area.js:43-48, dist/line.js:60-65).
    final xValues = [for (final r in rows) _xOf(r, numeric: _numericX)];
    // The area mark: the LineChart's fade, or the AreaChart's areas.
    // @tanstack/charts 1.1.0 dist/area.js:49-155 (groups by `z` in first
    // appearance order, rows in data order; the fade has no `z`)
    if (_fade || kind != LineAreaKind.line) {
      final groups = List<String?>.generate(
        rows.length,
        (i) => _fade ? null : _seriesOf(rows[i]),
      );
      final keys = tanstackInferredKeys(groups, [xValues]);
      final byGroup = <String?, List<int>>{};
      for (var i = 0; i < rows.length; i++) {
        (byGroup[groups[i]] ??= []).add(i);
      }
      for (final MapEntry(key: group, value: indices) in byGroup.entries) {
        final series = math.max(
          0,
          names.indexOf(_seriesOf(rows[indices.first])),
        );
        _Segment? segment;
        for (final i in indices) {
          final r = rows[i];
          final y1 = extents?[i]?.start ?? 0;
          final y2 = extents?[i]?.end ?? r.y;
          // dist/area.js:128-131: a row whose stacked y1 or y2 is not finite
          // (a stack whose sum overflows a double) ends the segment and
          // draws no point.
          if (!y1.isFinite || !y2.isFinite) {
            segment = null;
            continue;
          }
          if (segment == null) {
            segment = _Segment(
              group,
              colors[series],
              paletteAt(style.tokens, _fade ? 0 : series),
            );
            _areas.add(segment);
          }
          final at = Offset(xAt(r), yAt(y2));
          segment
            ..top.add(at)
            ..bottom.add(Offset(at.dx, yAt(y1)));
          segment.points.add(
            TanstackPoint(
              key: tanstackPointKey('area-y-0', group, keys[i]),
              markId: 'area-y-0',
              group: group,
              datum: i,
              x: at.dx,
              y: at.dy,
              xValue: xValues[i],
              yValue: r.y,
              // The point's colour is the area's fill: its fade for
              // unstacked areas (`url(#a2-fade-N)`), drawn solid here
              // (INV-042).
              color: segment.color,
              focusY: yAt(r.y),
            ),
          );
        }
      }
      // One area node per segment, each a target for its own points
      // (dist/area.js:101-117).
      for (final segment in _areas) {
        _areaPoints.addAll(segment.points);
        targets.add(
          TanstackTarget.area(
            [...segment.top, ...segment.bottom.reversed],
            affinity: TanstackAffinity.x,
            points: segment.points,
            clip: kind == LineAreaKind.line ? null : chart,
          ),
        );
      }
    }
    // The line mark (`lineY`): one group per series, rows in data order.
    // @tanstack/charts 1.1.0 dist/line.js:92-178
    if (kind != LineAreaKind.stackedArea) {
      final markId = _fade || kind == LineAreaKind.area ? 'line-1' : 'line-0';
      final groups = [for (final r in rows) _seriesOf(r)];
      final keys = tanstackInferredKeys(groups, [xValues]);
      final byGroup = <String, _Segment>{};
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        final group = groups[i];
        final series = math.max(0, names.indexOf(group));
        final segment = byGroup.putIfAbsent(
          group,
          () => _Segment(group, colors[series], colors[series]),
        );
        final at = Offset(xAt(r), yAt(r.y));
        segment.top.add(at);
        segment.points.add(
          TanstackPoint(
            key: tanstackPointKey(markId, group, keys[i]),
            markId: markId,
            group: group,
            datum: i,
            x: at.dx,
            y: at.dy,
            xValue: xValues[i],
            yValue: r.y,
            color: segment.color,
          ),
        );
      }
      _lines.addAll(byGroup.values);
      for (final segment in _lines) {
        _linePoints.addAll(segment.points);
        targets.add(
          TanstackTarget.polyline(
            segment.top,
            affinity: TanstackAffinity.x,
            strokeWidth: kind == LineAreaKind.line ? 2 : 1.75,
            points: segment.points,
            clip: kind == LineAreaKind.line ? null : chart,
          ),
        );
      }
    }
    points
      ..addAll(_areaPoints)
      ..addAll(_linePoints);
  }

  /// A vertical fade over [bounds]: [color] at 34%, 8% at 65%, clear at
  /// the bottom (`FADES`, `objectBoundingBox`).
  Paint _fadePaint(Rect bounds, Color color) =>
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: color.a * .34),
            color.withValues(alpha: color.a * .08),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .65, 1],
        ).createShader(bounds);

  /// A segment's path: the playground's `smoothCurve`, or straight lines
  /// when `curve` is false; up to its first point that is not finite, or
  /// null from the first ([tanstackSvgPath]).
  // @tanstack/charts 1.1.0 dist/line.js:115 (`curve.line(segment)`), else
  // dist/svg-renderer.js:51-53 (`pointsPath`)
  Path? _linePath(List<Offset> points) => tanstackSvgPath((path) {
    if (curve) {
      addMonotonePath(path, points);
    } else {
      addLinearPath(path, points);
    }
  });

  // @tanstack/charts 1.1.0 dist/area.js:101-117: `curve.area(top,
  // bottom)` (chart-kit.tsx:161-168, `smoothCurve.area`: the top, then the
  // bottom back, closed; curve.dart's `monotoneArea`), else the polygon of
  // its points; up to its first point that is not finite
  // ([tanstackSvgPath]).
  Path? _areaPath(_Segment segment) => tanstackSvgPath((path) {
    final back = segment.bottom.reversed.toList();
    if (curve) {
      addMonotonePath(path, segment.top);
      addMonotonePath(path, back, move: false);
    } else {
      addLinearPath(path, segment.top);
      addLinearPath(path, back, move: false);
    }
    path.close();
  });

  @override
  void paint(Canvas canvas, PlotFocus? focus) {
    marks.clear();
    final chart = plot;
    paintGrid(canvas, leftTicks);
    canvas.save();
    // An AreaChart clips its marks to the plot (`clip: true`). A plot box
    // that is not finite (margins made NaN by a tick label at NaN,
    // dist/scene.js:756-767) is a clip the browser can't draw; every mark
    // in it is at NaN too and drawn by none, so the clip goes with them.
    if (kind != LineAreaKind.line && chart.isFinite) canvas.clipRect(chart);
    for (final segment in _areas) {
      if (segment.top.isEmpty) continue;
      final path = _areaPath(segment);
      if (path == null) continue;
      final bounds = path.getBounds();
      if (kind == LineAreaKind.stackedArea) {
        // `fillOpacity: .62`, `stroke: var(--a2-surface)`, `strokeWidth: 1`
        // (SVG's miter joins).
        canvas
          ..drawPath(
            path,
            Paint()
              ..color = segment.color.withValues(alpha: segment.color.a * .62),
          )
          ..drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = style.tokens.surface,
          );
      } else {
        canvas.drawPath(path, _fadePaint(bounds, segment.fade));
      }
      marks.add(
        SceneMark('area', bounds, series: segment.group, color: segment.color),
      );
    }
    // Each series: its points' dots, then its line over them
    // (dist/line.js:134-168).
    final width = kind == LineAreaKind.line ? 2.0 : 1.75;
    for (final segment in _lines) {
      if (kind == LineAreaKind.line && rows.length <= 16) {
        for (final point in segment.points) {
          final at = Offset(point.x, point.y);
          // A `<circle>` at NaN is not drawn (RULEBOOK section 6 item 3).
          if (!at.isFinite) continue;
          // dist/line.js:156-166: radius 2.5, `fill` only.
          canvas.drawCircle(at, 2.5, Paint()..color = segment.color);
          marks.add(
            SceneMark(
              'point',
              Rect.fromCircle(center: at, radius: 2.5),
              value: rows[point.datum].y,
              series: segment.group,
              color: segment.color,
            ),
          );
        }
      }
      final path = _linePath(segment.top);
      if (path == null) continue;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = segment.color,
      );
      marks.add(
        SceneMark(
          'line',
          path.getBounds(),
          series: segment.group,
          color: segment.color,
        ),
      );
    }
    canvas.restore();
    paintAxes(canvas);
    // The focus: the rings of each mark's focused point, then the
    // crosshair over them (dist/focus-layer.js:7-16).
    paintFocusRings(canvas, focus, _areaPoints);
    paintFocusRings(canvas, focus, _linePoints);
    final primary = focus == null ? null : primaryOf(focus);
    // dist/crosshair-resolver.js:103: no rule at an x that is not finite;
    // nor in a plot box that is not, its ends and its clip (RULEBOOK
    // section 6 item 3).
    if (primary != null && primary.x.isFinite && chart.isFinite) {
      // dist/crosshair-resolver.js:122-133: at the primary point's x, the
      // plot's height, clipped to the plot.
      marks.add(
        SceneMark(
          'crosshair',
          Rect.fromLTRB(primary.x, chart.top, primary.x, chart.bottom),
          color: style.crosshairColor,
        ),
      );
      canvas
        ..save()
        ..clipRect(chart)
        ..drawLine(
          Offset(primary.x, chart.top),
          Offset(primary.x, chart.bottom),
          Paint()
            ..color = style.crosshairColor
            ..strokeWidth = 1,
        )
        ..restore();
    }
  }

  @override
  ChartTooltipContent? tooltipOf(PlotFocus focus) {
    // @tanstack/charts 1.1.0 dist/tooltip.js:51-62: the focused points in
    // the tooltip's order, to the playground's `content`.
    final ordered = tanstackTooltipOrder(focusPoints(focus));
    if (ordered.isEmpty) return null;
    final title = jsText(rows[ordered.first.datum].x);
    if (kind == LineAreaKind.line) {
      return ChartTooltipContent(
        title: title,
        rows: [
          for (final p in ordered)
            ChartTooltipRow(
              label: _single
                  ? (this.title ?? kSeriesFallback)
                  : _seriesOf(rows[p.datum]),
              value: fmtValue(rows[p.datum].y, format, unit),
              color: p.color,
            ),
        ],
      );
    }
    // One row per series, then a stack's Total.
    final seen = <String>{};
    final unique = [
      for (final p in ordered)
        if (seen.add(_seriesOf(rows[p.datum]))) p,
    ];
    final total = unique.fold<double>(0, (sum, p) => sum + rows[p.datum].y);
    return ChartTooltipContent(
      title: title,
      rows: [
        for (final p in unique)
          ChartTooltipRow(
            label: _seriesOf(rows[p.datum]),
            value: fmtValue(rows[p.datum].y, format, unit),
            color: p.color,
          ),
        if (kind == LineAreaKind.stackedArea)
          ChartTooltipRow(
            label: 'Total',
            value: fmtValue(total, format, unit),
            active: true,
          ),
      ],
    );
  }
}

/// A bar of a [BarScene].
class _Bar {
  _Bar(this.datum, this.series, this.rect, this.radii);

  /// The row.
  final int datum;

  /// The series' index.
  final int series;

  /// The bar's box.
  final Rect rect;

  /// Its corner radii: top left, top right, bottom right, bottom left.
  final List<double> radii;
}

/// The scene of a BarChart: categories on a band scale (padding .24 with
/// more series, .32 with one), values on a nice linear scale with 0 and 5
/// ticks over a dashed grid; series side by side (`group`, padding .12) or
/// stacked (diverging from 0); bars at most 18px (grouped) or 40px thick,
/// 22px when horizontal; the value end rounded 4px, of a stack only its
/// outer ends.
class BarScene extends _CartesianScene {
  /// The scene of [rows] at [size].
  BarScene({
    required Size size,
    required PlaygroundChartStyle style,
    required this.rows,
    required this.names,
    required this.colors,
    required this.format,
    required this.unit,
    required this.title,
    required this.stacked,
    required this.horizontal,
  }) : super(size, style) {
    _build();
  }

  /// The rows.
  final List<ChartRow> rows;

  /// The series, in order.
  final List<String> names;

  /// The colour of each series.
  final List<Color> colors;

  /// The value format.
  final A2uiValueFormat? format;

  /// The value unit, or null.
  final String? unit;

  /// The chart's title (a single series' tooltip label).
  final String? title;

  /// Whether the props asked for stacking.
  final bool stacked;

  /// Whether the bars run from the left.
  final bool horizontal;

  /// The categories, in the order they first appear.
  late final List<String> categories = xDomainOf(rows);
  late final bool _multi = names.length > 1;
  late final bool _grouped = _multi && !stacked;
  final List<_Bar> _bars = [];

  /// Each bar's corner radii as drawn (top left, top right, bottom right,
  /// bottom left), in data order, for tests.
  List<List<double>> get barRadii => [
    for (final bar in _bars)
      tanstackCornerRadii(bar.radii, bar.rect.width, bar.rect.height),
  ];

  /// The stack of the bars of [rows] when they are not grouped
  /// (`stack({order: names})`; a single series stacks too). Throws
  /// [TanstackStackError] for two rows of one series in one category.
  // @tanstack/charts 1.1.0 dist/bar.js:55 (`stackValues`)
  static List<TanstackExtent?> stackOf(
    List<ChartRow> rows,
    List<String> names,
  ) => tanstackStackValues(
    [for (final r in rows) r.xText],
    [for (final r in rows) r.y],
    [for (final r in rows) _seriesOf(r)],
    order: names,
  );

  @override
  TanstackFocus? get focusStrategy => _multi
      ? (horizontal ? TanstackFocus.groupY : TanstackFocus.groupX)
      : null;

  void _build() {
    final extents = _grouped ? null : stackOf(rows, names);
    final outerEnds = extents == null
        ? null
        : tanstackStackOuterEnds(
            [for (final r in rows) r.xText],
            [for (final r in rows) r.y],
            extents,
          );
    double y1Of(int i) => extents == null ? 0 : extents[i]!.start;
    double y2Of(int i) => extents == null ? rows[i].y : extents[i]!.end;
    // @tanstack/charts 1.1.0 dist/bar.js:81-88: the value channel, with 0.
    final valueScale = tanstackLinearScale(
      [
        for (var i = 0; i < rows.length; i++) y2Of(i),
        for (var i = 0; i < rows.length; i++) y1Of(i),
      ],
      includeZero: true,
      niceCount: _valueTickCount,
    );
    final tick = playgroundTickFormatter(format, unit);
    final band = BandScale.padded(categories, _multi ? .24 : .32);
    List<TanstackTick> valueTicks(double from, double to) => [
      for (final t in valueScale.ticks(_valueTickCount))
        TanstackTick(t, valueScale.map(t, from, to), tick(t)),
    ];
    List<TanstackTick> bandTicks(double from, double to, int max) => [
      for (var i = 0; i < categories.length; i++)
        TanstackTick(
          categories[i],
          band.center(i, from, to),
          shortLabel(categories[i], max),
        ),
    ];
    if (horizontal) {
      lay(
        TanstackAxisGuide(
          ticks: (chart) => valueTicks(chart.left, chart.right),
        ),
        TanstackAxisGuide(
          padding: 10,
          categorical: true,
          // A band y runs top to bottom (dist/configured-scale.js:12).
          ticks: (chart) => bandTicks(chart.top, chart.bottom, 18),
        ),
      );
    } else {
      lay(
        TanstackAxisGuide(
          categorical: true,
          ticks: (chart) => bandTicks(chart.left, chart.right, 12),
        ),
        TanstackAxisGuide(
          ticks: (chart) => valueTicks(chart.bottom, chart.top),
        ),
      );
    }
    final chart = plot;
    final (b0, b1) = horizontal
        ? (chart.top, chart.bottom)
        : (chart.left, chart.right);
    final (v0, v1) = horizontal
        ? (chart.left, chart.right)
        : (chart.bottom, chart.top);
    double valueAt(double v) => valueScale.map(v, v0, v1);
    // @tanstack/charts 1.1.0 dist/bar.js:95-106 (`resolveGroupScale`, a d3
    // band of the series in first-appearance order, padding .12) and
    // 485-497 (`resolveBarThickness`)
    final totalBandwidth = band.bandwidth(b0, b1);
    final groupDomain = seriesNames(rows.map((r) => r.series));
    final group = _grouped ? BandScale.padded(groupDomain, .12) : null;
    final groupBandwidth =
        group?.bandwidth(0, totalBandwidth) ?? totalBandwidth;
    final maxThickness = horizontal ? 22.0 : (_grouped ? 18.0 : 40.0);
    final available = math.max<double>(0, groupBandwidth);
    final thickness = math.min(available, maxThickness);
    final inset = (available - thickness) / 2;
    final markId = horizontal ? 'bar-x-0' : 'bar-y-0';
    // The datum keys: the category when it is unique in its series, else
    // the row's index (dist/bar.js:66-74, :268-276; the group is the
    // series, `z`).
    final groups = [for (final r in rows) _seriesOf(r)];
    final keys = tanstackInferredKeys(groups, [
      [for (final r in rows) r.xText],
    ]);
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      // dist/bar.js:113-114 (and :315-316): a row whose stacked y1 or y2 is
      // not finite (a stack whose sum overflows a double) draws no bar and
      // has no point.
      if (!y1Of(i).isFinite || !y2Of(i).isFinite) continue;
      final category = categories.indexOf(r.xText);
      final seriesIndex = math.max(0, names.indexOf(_seriesOf(r)));
      final groupOffset = group == null
          ? 0.0
          : group.start(groupDomain.indexOf(_seriesOf(r)), 0, totalBandwidth);
      final center = band.center(category, b0, b1);
      final across = center - totalBandwidth / 2 + groupOffset + inset;
      final baselinePosition = valueAt(y1Of(i));
      final valuePosition = valueAt(y2Of(i));
      // dist/bar.js:142-144: a negative value of a diverging stack ends at
      // its start.
      final valueEnd = extents != null && r.y < 0;
      final semanticValue = valueEnd ? baselinePosition : valuePosition;
      final semanticBaseline = valueEnd ? valuePosition : baselinePosition;
      final low = math.min(baselinePosition, valuePosition);
      final length = (baselinePosition - valuePosition).abs();
      final rect = horizontal
          ? Rect.fromLTWH(low, across, length, thickness)
          : Rect.fromLTWH(across, low, thickness, length);
      final radii = _radius(
        semanticValue,
        semanticBaseline,
        stackOuter: outerEnds != null,
        outerEnd: outerEnds?[i],
        stackStart: baselinePosition,
        stackEnd: valuePosition,
      );
      _bars.add(_Bar(i, seriesIndex, rect, radii));
      final slotCenter =
          center - totalBandwidth / 2 + groupOffset + groupBandwidth / 2;
      final color = colors[seriesIndex];
      final key = tanstackPointKey(markId, groups[i], keys[i]);
      // dist/bar.js:165-180 (barY) and 367-382 (barX): the point at the
      // value end, in the middle of the bar's slot; its focus coordinates
      // are its values' positions (dist/scene.js:334-346).
      final point = horizontal
          ? TanstackPoint(
              key: key,
              markId: markId,
              group: _seriesOf(r),
              datum: i,
              x: semanticValue,
              y: slotCenter,
              xValue: r.y,
              yValue: r.xText,
              color: color,
              focusX: valueAt(r.y),
              focusY: center,
            )
          : TanstackPoint(
              key: key,
              markId: markId,
              group: _seriesOf(r),
              datum: i,
              x: slotCenter,
              y: semanticValue,
              xValue: r.xText,
              yValue: r.y,
              color: color,
              focusX: center,
              focusY: valueAt(r.y),
            );
      points.add(point);
      targets.add(
        TanstackTarget.rect(
          rect,
          affinity: horizontal ? TanstackAffinity.y : TanstackAffinity.x,
          point: point,
          cornerRadii: radii,
        ),
      );
    }
  }

  /// The corner radii of a bar (`radius: {end: 4}`, a stack's outer ends
  /// only): top left, top right, bottom right, bottom left.
  // @tanstack/charts 1.1.0 dist/bar.js:440-475 (`resolveBarRadius`)
  List<double> _radius(
    double valuePosition,
    double baselinePosition, {
    required bool stackOuter,
    required ({bool start, bool end})? outerEnd,
    required double stackStart,
    required double stackEnd,
  }) {
    const radius = 4.0;
    if (valuePosition == baselinePosition) return const [0, 0, 0, 0];
    if (stackOuter) {
      if (outerEnd == null) return const [0, 0, 0, 0];
      if (outerEnd.start && outerEnd.end) {
        return const [radius, radius, radius, radius];
      }
      final roundStart = outerEnd.start;
      return _endCornerRadii(
        radius,
        roundStart ? stackStart : stackEnd,
        roundStart ? stackEnd : stackStart,
      );
    }
    return _endCornerRadii(radius, valuePosition, baselinePosition);
  }

  // @tanstack/charts 1.1.0 dist/bar.js:479-484 (`endCornerRadii`)
  List<double> _endCornerRadii(
    double radius,
    double valuePosition,
    double baselinePosition,
  ) {
    if (!horizontal) {
      return valuePosition <= baselinePosition
          ? [radius, radius, 0, 0]
          : [0, 0, radius, radius];
    }
    return valuePosition <= baselinePosition
        ? [radius, 0, 0, radius]
        : [0, radius, radius, 0];
  }

  /// A bar's shape: its box with its corner radii, scaled down where they
  /// would overlap.
  // @tanstack/charts 1.1.0 dist/renderer-rect.js:30-53
  // (`rectCornerRadiiPath`)
  RRect _shape(_Bar bar) {
    final r = tanstackCornerRadii(bar.radii, bar.rect.width, bar.rect.height);
    return RRect.fromRectAndCorners(
      bar.rect,
      topLeft: Radius.circular(r[0]),
      topRight: Radius.circular(r[1]),
      bottomRight: Radius.circular(r[2]),
      bottomLeft: Radius.circular(r[3]),
    );
  }

  @override
  void paint(Canvas canvas, PlotFocus? focus) {
    marks.clear();
    paintGrid(
      canvas,
      horizontal ? bottomTicks : leftTicks,
      vertical: horizontal,
    );
    // The bars in data order (dist/bar.js:108-206).
    for (final bar in _bars) {
      // A bar's path starts at its box's corner (`M${left + r},${top}`,
      // dist/renderer-rect.js:30-53, the corner a `Math.min` of each edge,
      // :63-71): any number of the box that is not finite puts NaN in the
      // path's first command, so nothing is drawn (SVG 2, Paths, "Error
      // handling in path data").
      if (!bar.rect.isFinite) continue;
      final color = colors[bar.series];
      canvas.drawRRect(_shape(bar), Paint()..color = color);
      marks.add(
        SceneMark(
          'bar',
          bar.rect,
          value: rows[bar.datum].y,
          series: names[bar.series],
          color: color,
        ),
      );
    }
    paintAxes(canvas);
    paintFocusRings(canvas, focus, points);
  }

  @override
  ChartTooltipContent? tooltipOf(PlotFocus focus) {
    final ordered = tanstackTooltipOrder(focusPoints(focus));
    if (ordered.isEmpty) return null;
    return ChartTooltipContent(
      title: rows[ordered.first.datum].xText,
      rows: [
        for (final p in ordered)
          ChartTooltipRow(
            label: _multi
                ? _seriesOf(rows[p.datum])
                : (title ?? kSeriesFallback),
            value: fmtValue(rows[p.datum].y, format, unit),
            color: p.color,
          ),
      ],
    );
  }
}

/// One point of a [ScatterScene].
@immutable
class ScatterPoint {
  /// A point.
  const ScatterPoint({
    required this.x,
    required this.y,
    this.label,
    this.size,
    this.series,
  });

  /// The x value.
  final double x;

  /// The y value.
  final double y;

  /// The point's name, or null.
  final String? label;

  /// The bubble size (not negative), or null.
  final double? size;

  /// The series, or null.
  final String? series;
}

/// The scene of a ScatterChart: both axes nice linear scales (x one tick
/// per 92px, 2 to 8; y asked for 5) over dashed grids, x ticks compact from
/// 1,000; dots of radius 5 (or 3.5 + √(size / largest) × 11) filled at
/// 55%, no outline; the focused dot fills at 95% with a focus ring, the
/// others fade to 45%.
class ScatterScene extends _CartesianScene {
  /// The scene of [scatter] at [size].
  ScatterScene({
    required Size size,
    required PlaygroundChartStyle style,
    required this.scatter,
    required this.names,
    required this.format,
    required this.unit,
    this.xLabel,
    this.yLabel,
  }) : super(size, style) {
    _build();
  }

  /// The data points.
  final List<ScatterPoint> scatter;

  /// The series, in order.
  final List<String> names;

  /// The y format.
  final A2uiValueFormat? format;

  /// The y unit.
  final String? unit;

  /// The x axis title.
  final String? xLabel;

  /// The y axis title.
  final String? yLabel;

  final List<double> _radius = [];

  /// A ScatterChart has no focus strategy: the nearest dot.
  @override
  TanstackFocus? get focusStrategy => null;

  void _build() {
    // @tanstack/charts 1.1.0 dist/dot.js:116-123: x and y channels with no
    // zero.
    final xValues = [for (final p in scatter) p.x];
    final yScale = tanstackLinearScale([
      for (final p in scatter) p.y,
    ], niceCount: _valueTickCount);
    TanstackLinearScale xScale(Rect chart) => tanstackLinearScale(
      xValues,
      niceCount: tanstackTickCount(length: chart.width, x: true),
    );
    final xTick = playgroundTickFormatter();
    final yTick = playgroundTickFormatter(format, unit);
    // charts.tsx: axis titles at 11px, weight 500.
    lay(
      TanstackAxisGuide(
        title: xLabel == null
            ? null
            : TanstackAxisTitle(
                xLabel!,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
        ticks: (chart) {
          final count = tanstackTickCount(length: chart.width, x: true);
          final scale = xScale(chart);
          return [
            for (final t in scale.ticks(count))
              TanstackTick(t, scale.map(t, chart.left, chart.right), xTick(t)),
          ];
        },
      ),
      TanstackAxisGuide(
        title: yLabel == null
            ? null
            : TanstackAxisTitle(
                yLabel!,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
        ticks: (chart) => [
          for (final t in yScale.ticks(_valueTickCount))
            TanstackTick(t, yScale.map(t, chart.bottom, chart.top), yTick(t)),
        ],
      ),
    );
    final chart = plot;
    final x = xScale(chart);
    final maxSize = scatter.fold<double>(0, (m, p) => math.max(m, p.size ?? 0));
    // The datum keys: x when unique in its series, else y, else the pair,
    // else the index (dist/dot.js:41-46; the group is the series, `z`).
    final groups = [for (final p in scatter) p.series ?? kSeriesFallback];
    final yValues = [for (final p in scatter) p.y];
    final keys = tanstackInferredKeys(groups, [
      xValues,
      yValues,
      tanstackCompositeKeys([xValues, yValues]),
    ]);
    for (var i = 0; i < scatter.length; i++) {
      final p = scatter[i];
      final at = Offset(
        x.map(p.x, chart.left, chart.right),
        yScale.map(p.y, chart.bottom, chart.top),
      );
      final s = p.size;
      final radius = s == null || maxSize == 0
          ? 5.0
          : 3.5 + math.sqrt(s / maxSize) * 11;
      _radius.add(radius);
      final series = groups[i];
      final point = TanstackPoint(
        key: tanstackPointKey('dot-0', series, keys[i]),
        markId: 'dot-0',
        group: series,
        datum: i,
        x: at.dx,
        y: at.dy,
        xValue: p.x,
        yValue: p.y,
        color: _colorOf(p),
      );
      points.add(point);
      targets.add(
        TanstackTarget.dot(
          at,
          radius,
          affinity: TanstackAffinity.xy,
          point: point,
        ),
      );
    }
  }

  Color _colorOf(ScatterPoint p) => paletteAt(
    style.tokens,
    math.max(0, names.indexOf(p.series ?? kSeriesFallback)),
  );

  @override
  void paint(Canvas canvas, PlotFocus? focus) {
    marks.clear();
    // The grid of x, then of y (dist/scene.js:818-845, in scale order).
    paintGrid(canvas, bottomTicks, vertical: true);
    paintGrid(canvas, leftTicks);
    final primary = focus == null ? null : primaryOf(focus);
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final color = point.color;
      // charts.tsx states: the primary fills at .95, the unmatched fade
      // to .45 (dist/mark-state.js:84-112).
      final matched =
          primary != null && tanstackSameFocusedPoint(point, primary);
      final fill = matched ? .95 : .55;
      final opacity = primary != null && !matched ? .45 : 1.0;
      final at = Offset(point.x, point.y);
      // A `<circle>` at NaN is not drawn (RULEBOOK section 6 item 3).
      if (!at.isFinite) continue;
      // No `stroke` is set, so `strokeWidth: 1.25` draws nothing
      // (dist/dot.js:95-101).
      canvas.drawCircle(
        at,
        _radius[i],
        Paint()..color = color.withValues(alpha: color.a * fill * opacity),
      );
      marks.add(
        SceneMark(
          'dot',
          Rect.fromCircle(center: at, radius: _radius[i]),
          value: scatter[i].y,
          series: scatter[i].series ?? kSeriesFallback,
          color: color,
        ),
      );
    }
    paintAxes(canvas);
    paintFocusRings(canvas, focus, points);
  }

  @override
  ChartTooltipContent? tooltipOf(PlotFocus focus) {
    final primary = primaryOf(focus);
    if (primary == null) return null;
    final p = scatter[primary.datum];
    return ChartTooltipContent(
      title:
          p.label ?? (names.length > 1 ? (p.series ?? kSeriesFallback) : null),
      rows: [
        ChartTooltipRow(
          label: xLabel ?? 'x',
          value: fmtValue(p.x),
          color: primary.color,
        ),
        ChartTooltipRow(
          label: yLabel ?? 'y',
          value: fmtValue(p.y, format, unit),
        ),
        if (p.size != null)
          ChartTooltipRow(
            label: 'Size',
            value: fmtValue(p.size, A2uiValueFormat.compact),
          ),
      ],
    );
  }
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/charts.tsx
