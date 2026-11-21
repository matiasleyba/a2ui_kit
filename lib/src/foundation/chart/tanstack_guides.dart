// TanStack Charts' guides: the axes' tick labels and titles, their
// thinning, the grid, and the margins they push out round the plot. The
// guides of the playground's LineChart, AreaChart, BarChart and
// ScatterChart.
//
// Ported from the published source of @tanstack/charts 1.1.0 (MIT, (c)
// Tanner Linsley): `dist/scene.js` (`resolveSceneLayout`, `createAxes`,
// `createGrid`, `createTickLabelCandidates`, `thinTickLabels`) and
// `dist/guide-layout.js` (`measureSceneLabelBounds`, `rotateBounds`). See
// NOTICE.md.
//
// TanStack measures a label by the canvas' painted bounds
// (`dist/dom-text.js` `paintedBounds`: `actualBoundingBox*`). Flutter has
// no ink metrics, so the advance width and the font's ascent and descent
// stand in for them (port/inventory.tsv INV-040).

import 'dart:math' as math;

import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:flutter/painting.dart';

/// The horizontal anchor of a TanStack label (SVG's `text-anchor`).
enum TanstackAnchor {
  /// The label starts at its point.
  start,

  /// The label is centred on its point.
  middle,

  /// The label ends at its point.
  end,
}

/// The vertical baseline of a TanStack label (SVG's `dominant-baseline`).
enum TanstackBaseline {
  /// The alphabetic baseline is at the point (`auto`).
  alphabetic,

  /// The middle of the text is at the point.
  middle,

  /// The hanging baseline is at the point.
  hanging,
}

/// A label of a TanStack scene (`kind: "label"`): [text] anchored at
/// ([x], [y]), turned by [rotate] degrees about that point.
class TanstackLabel {
  /// A label.
  TanstackLabel({
    required this.text,
    required this.x,
    required this.y,
    required this.fontSize,
    required this.color,
    this.anchor = TanstackAnchor.start,
    this.baseline = TanstackBaseline.alphabetic,
    this.rotate,
    this.fontWeight,
  });

  /// The text.
  final String text;

  /// The anchor point's x.
  double x;

  /// The anchor point's y.
  double y;

  /// The size in pixels (already text-scaled).
  final double fontSize;

  /// The weight, or null for the surface's.
  final FontWeight? fontWeight;

  /// The colour, its opacity included.
  final Color color;

  /// How the text sits on [x].
  final TanstackAnchor anchor;

  /// How the text sits on [y].
  final TanstackBaseline baseline;

  /// The rotation in degrees, or null for none.
  final double? rotate;
}

/// Measures and paints [TanstackLabel]s in a font family, as TanStack's
/// DOM text measurer does in the chart's font (`dist/dom-text.js`).
class TanstackText {
  /// Text in [fontFamily] (and [fontFamilyFallback]), its sizes scaled by
  /// [textScaler].
  TanstackText({
    required this.textScaler,
    this.fontFamily,
    this.fontFamilyFallback,
  });

  /// The family, or null for the default.
  final String? fontFamily;

  /// The fallback families.
  final List<String>? fontFamilyFallback;

  /// The text scale applied to every CSS size ([size]).
  final TextScaler textScaler;

  /// The pixel size of a CSS [cssSize] at the text scale.
  double size(double cssSize) => textScaler.scale(cssSize);

  TextPainter _painter(
    String text,
    double fontSize,
    FontWeight? weight, [
    Color? color,
  ]) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSize: fontSize,
        fontWeight: weight,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
    maxLines: 1,
  )..layout();

  /// The bounds of [text] round its anchor point (0, 0), as
  /// `measureText` returns them: x by the [anchor], y by the [baseline].
  // @tanstack/charts 1.1.0 dist/dom-text.js:55-74 (the canvas'
  // `textBaseline`: 'middle' is the middle of the em square there, which
  // the line box's middle stands in for), :75-93 (`paintedBounds`), the
  // canvas' ink bounds stood in for by the advance and the font's ascent
  // and descent; dist/guide-layout.js:18-22 (`logicalTextAnchorOffset`)
  Rect measure(
    String text,
    double fontSize, {
    FontWeight? fontWeight,
    TanstackAnchor anchor = TanstackAnchor.start,
    TanstackBaseline baseline = TanstackBaseline.alphabetic,
  }) {
    if (text.isEmpty) return Rect.zero;
    final painter = _painter(text, fontSize, fontWeight);
    final width = painter.width;
    final height = painter.height;
    final ascent = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    painter.dispose();
    final x = switch (anchor) {
      TanstackAnchor.start => 0.0,
      TanstackAnchor.middle => -width / 2,
      TanstackAnchor.end => -width,
    };
    final y = switch (baseline) {
      TanstackBaseline.alphabetic => -ascent,
      TanstackBaseline.middle => -height / 2,
      TanstackBaseline.hanging => -ascent + _hanging(ascent),
    };
    return Rect.fromLTWH(x, y, width, height);
  }

  /// How far the hanging baseline is above the alphabetic one.
  // A browser takes a font's hanging baseline from its tables, or 80% of
  // its ascent when they have none; Flutter has no hanging baseline.
  static double _hanging(double ascent) => ascent * .8;

  /// How far SVG's `middle` baseline is above the alphabetic one: half the
  /// font's x-height (CSS Inline 3's x-middle baseline). Flutter has no
  /// x-height, so half an em stands in for the x-height (INV-040).
  static double _xMiddle(double fontSize) => fontSize * .5 / 2;

  /// The bounds of [label] on the scene, rotated when it is.
  // @tanstack/charts 1.1.0 dist/guide-layout.js:46-71
  // (`measureSceneLabelBounds`)
  Rect labelBounds(TanstackLabel label) {
    final measured = measure(
      label.text,
      label.fontSize,
      fontWeight: label.fontWeight,
      anchor: label.anchor,
      baseline: label.baseline,
    );
    final bounds = measured.shift(Offset(label.x, label.y));
    final rotate = label.rotate;
    if (rotate == null || rotate == 0) return bounds;
    return rotateBounds(bounds, label.x, label.y, rotate);
  }

  /// Paints [label] on [canvas]; nothing when its anchor is not finite.
  // dist/svg-renderer.js:64-71 writes `x`, `y` and the rotation's centre as
  // they are (`number(NaN)` is "NaN", dist/markup-internal.js:1-3); the
  // browser draws nothing for a coordinate it can't parse (RULEBOOK
  // section 6 item 3).
  void paint(Canvas canvas, TanstackLabel label) {
    if (label.text.isEmpty) return;
    if (!label.x.isFinite || !label.y.isFinite) return;
    final painter = _painter(
      label.text,
      label.fontSize,
      label.fontWeight,
      label.color,
    );
    final width = painter.width;
    final ascent = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final left = switch (label.anchor) {
      TanstackAnchor.start => 0.0,
      TanstackAnchor.middle => -width / 2,
      TanstackAnchor.end => -width,
    };
    // dist/svg-renderer.js:63-70: `dominant-baseline` on the SVG `<text>`,
    // placed by its baseline (RULEBOOK section 2): the alphabetic baseline
    // half an x-height below a `middle` point (dist/scene.js:1223, the y
    // tick labels; :1071-1079, the y title).
    final top = switch (label.baseline) {
      TanstackBaseline.alphabetic => -ascent,
      TanstackBaseline.middle => -ascent + _xMiddle(label.fontSize),
      TanstackBaseline.hanging => -ascent + _hanging(ascent),
    };
    final rotate = label.rotate;
    if (rotate == null || rotate == 0) {
      painter.paint(canvas, Offset(label.x + left, label.y + top));
    } else {
      canvas
        ..save()
        ..translate(label.x, label.y)
        ..rotate(rotate * math.pi / 180);
      painter.paint(canvas, Offset(left, top));
      canvas.restore();
    }
    painter.dispose();
  }
}

/// [bounds] turned [degrees] about ([originX], [originY]): the box round
/// the turned box.
// @tanstack/charts 1.1.0 dist/guide-layout.js:163-179 (`rotateBounds`)
Rect rotateBounds(Rect bounds, double originX, double originY, double degrees) {
  final radians = degrees * math.pi / 180;
  final cosine = math.cos(radians);
  final sine = math.sin(radians);
  final centerX = bounds.left + bounds.width / 2 - originX;
  final centerY = bounds.top + bounds.height / 2 - originY;
  final width = (bounds.width * cosine).abs() + (bounds.height * sine).abs();
  final height = (bounds.width * sine).abs() + (bounds.height * cosine).abs();
  final rotatedCenterX = centerX * cosine - centerY * sine + originX;
  final rotatedCenterY = centerX * sine + centerY * cosine + originY;
  return Rect.fromLTWH(
    rotatedCenterX - width / 2,
    rotatedCenterY - height / 2,
    width,
    height,
  );
}

/// A tick of a resolved TanStack scale: its value, position and text.
class TanstackTick {
  /// A tick.
  const TanstackTick(this.value, this.position, this.label);

  /// The value.
  final Object value;

  /// The position along the axis, in pixels.
  final double position;

  /// The text.
  final String label;
}

/// A tick label that may be shown, with its bounds.
class TanstackLabelCandidate {
  /// A candidate.
  const TanstackLabelCandidate(this.value, this.label, this.bounds);

  /// The tick's value.
  final Object value;

  /// The label.
  final TanstackLabel label;

  /// Its bounds on the scene.
  final Rect bounds;
}

/// TanStack's tick label thinning: [candidates] that would come within 4px
/// of one already kept are left out. Kept first: the first and last of a
/// band or point x axis ([categoricalX]), then the rest in bisection order
/// (the middle, then the middles of the halves, …).
// @tanstack/charts 1.1.0 dist/scene.js:1238-1263 (`thinTickLabels`; no
// tick is `hard`, as no axis keeps values)
List<TanstackLabelCandidate> thinTickLabels(
  List<TanstackLabelCandidate> candidates, {
  required bool categoricalX,
  double minGap = 4,
}) {
  if (candidates.length < 2) return [...candidates];
  final selected = <TanstackLabelCandidate>[];
  final soft = candidates;
  if (categoricalX && soft.isNotEmpty) {
    final first = soft.first;
    final last = soft.last;
    if (!_collidesWithAny(first, selected, minGap)) selected.add(first);
    if (!identical(last, first) && !_collidesWithAny(last, selected, minGap)) {
      selected.add(last);
    }
  }
  final ordered = distributedCandidates([
    for (final candidate in soft)
      if (!selected.contains(candidate)) candidate,
  ]);
  for (final candidate in ordered) {
    if (!_collidesWithAny(candidate, selected, minGap)) selected.add(candidate);
  }
  final kept = selected.toSet();
  return [
    for (final candidate in candidates)
      if (kept.contains(candidate)) candidate,
  ];
}

/// [candidates] in bisection order: the middle one, then the middles of
/// the two halves, breadth first.
// @tanstack/charts 1.1.0 dist/scene.js:1264-1276 (`distributedCandidates`)
List<T> distributedCandidates<T>(List<T> candidates) {
  if (candidates.length < 3) return [...candidates];
  final result = <T>[];
  final queue = <List<T>>[candidates];
  while (queue.isNotEmpty) {
    final range = queue.removeAt(0);
    if (range.isEmpty) continue;
    final middle = range.length ~/ 2;
    result.add(range[middle]);
    queue
      ..add(range.sublist(0, middle))
      ..add(range.sublist(middle + 1));
  }
  return result;
}

// @tanstack/charts 1.1.0 dist/scene.js:1277-1281 (`collidesWithAny`)
bool _collidesWithAny(
  TanstackLabelCandidate candidate,
  List<TanstackLabelCandidate> selected,
  double gap,
) =>
    selected.any((other) => boundsCollide(candidate.bounds, other.bounds, gap));

/// Whether [left] and [right] come within [gap] of each other.
// @tanstack/charts 1.1.0 dist/scene.js:1282-1284 (`boundsCollide`)
bool boundsCollide(Rect left, Rect right, double gap) =>
    !(left.left + left.width + gap <= right.left ||
        right.left + right.width + gap <= left.left ||
        left.top + left.height + gap <= right.top ||
        right.top + right.height + gap <= left.top);

/// The margins round a plot: top, right, bottom, left.
typedef TanstackMargin = ({
  double top,
  double right,
  double bottom,
  double left,
});

/// TanStack's automatic inset round a plot with guides.
// @tanstack/charts 1.1.0 dist/scene.js:540
const double tanstackGuideInset = 4;

/// The title of a TanStack axis (`axis.label`).
class TanstackAxisTitle {
  /// A title of [text] at [fontSize] CSS pixels and [fontWeight].
  const TanstackAxisTitle(this.text, {this.fontSize, this.fontWeight});

  /// The text.
  final String text;

  /// The CSS size, or null for TanStack's (10 under a 360px chart, else 11).
  final double? fontSize;

  /// The weight, or null for TanStack's 600.
  final FontWeight? fontWeight;
}

/// One axis of a TanStack cartesian chart: its ticks for a plot box
/// ([ticks]), the gap between them and their labels ([padding]), whether
/// it is a band or point axis ([categorical]) and its [title].
class TanstackAxisGuide {
  /// An axis.
  const TanstackAxisGuide({
    required this.ticks,
    this.padding = 8,
    this.categorical = false,
    this.title,
  });

  /// The ticks for a plot box.
  final List<TanstackTick> Function(Rect chart) ticks;

  /// The tick padding (`ticks.padding`); the tick size is 0.
  final double padding;

  /// Whether the scale is a band or point scale.
  final bool categorical;

  /// The title, or null.
  final TanstackAxisTitle? title;
}

/// A TanStack cartesian chart's layout: the plot box, the visible tick
/// labels and titles, and the margins they needed.
class TanstackCartesianLayout {
  TanstackCartesianLayout._(
    this.chart,
    this.margin,
    this.xTicks,
    this.yTicks,
    this.xLabels,
    this.yLabels,
    this.xTitle,
    this.yTitle,
    this._guideMargin,
  );

  /// Lays out a chart [size] with a bottom [x] axis and a left [y] axis:
  /// the margins start at 4 and grow to every label's bounds plus 4, in up
  /// to 4 passes.
  // @tanstack/charts 1.1.0 dist/scene.js:543-566 (`resolveSceneLayout`)
  factory TanstackCartesianLayout.resolve({
    required Size size,
    required TanstackText text,
    required Color tickColor,
    required Color titleColor,
    TanstackAxisGuide? x,
    TanstackAxisGuide? y,
  }) {
    TanstackCartesianLayout compile(TanstackMargin margin) =>
        TanstackCartesianLayout._compile(
          size: size,
          margin: margin,
          text: text,
          tickColor: tickColor,
          titleColor: titleColor,
          x: x,
          y: y,
        );
    final hasGuides = x != null || y != null;
    final inset = hasGuides ? tanstackGuideInset : 0.0;
    var margin = (top: inset, right: inset, bottom: inset, left: inset);
    var safeMargin = margin;
    // @tanstack/charts 1.1.0 dist/scene.js:541 (`layoutPassLimit`)
    for (var pass = 0; pass < 4; pass += 1) {
      final resolved = compile(margin);
      final next = resolved._guideMargin;
      safeMargin = _maxMargin(safeMargin, next);
      if (_marginsEqual(margin, next)) return resolved;
      margin = next;
    }
    var resolved = compile(safeMargin);
    final finalMargin = _maxMargin(safeMargin, resolved._guideMargin);
    if (!_marginsEqual(safeMargin, finalMargin)) {
      resolved = compile(finalMargin);
    }
    return resolved;
  }

  // @tanstack/charts 1.1.0 dist/scene.js:566-667 (`compileSceneLayout`)
  // and 859-1107 (`createAxes`, with no axis line and ticks of size 0)
  factory TanstackCartesianLayout._compile({
    required Size size,
    required TanstackMargin margin,
    required TanstackText text,
    required Color tickColor,
    required Color titleColor,
    TanstackAxisGuide? x,
    TanstackAxisGuide? y,
  }) {
    final width = size.width;
    final chart = Rect.fromLTWH(
      margin.left,
      margin.top,
      math.max(1, width - margin.left - margin.right),
      math.max(1, size.height - margin.top - margin.bottom),
    );
    final guideInset = x != null || y != null ? tanstackGuideInset : 0.0;
    var top = guideInset;
    var right = guideInset;
    var bottom = guideInset;
    var left = guideInset;
    // @tanstack/charts 1.1.0 dist/scene.js:756-767 (`includeBoundsMargin`)
    void include(Rect bounds) {
      top = math.max(top, chart.top - bounds.top + tanstackGuideInset);
      right = math.max(right, bounds.right - chart.right + tanstackGuideInset);
      bottom = math.max(
        bottom,
        bounds.bottom - chart.bottom + tanstackGuideInset,
      );
      left = math.max(left, chart.left - bounds.left + tanstackGuideInset);
    }

    // @tanstack/charts 1.1.0 dist/scene.js:1184 (`defaultFontSize`)
    final fontSize = text.size(width < 360 ? 10 : 11);
    List<TanstackTick>? xTicks;
    List<TanstackTick>? yTicks;
    var xLabels = <TanstackLabel>[];
    var yLabels = <TanstackLabel>[];
    TanstackLabel? xTitle;
    TanstackLabel? yTitle;
    if (x != null) {
      // `renderXAxis` on the bottom side.
      final axisY = chart.bottom;
      final ticks = x.ticks(chart);
      xTicks = ticks;
      // @tanstack/charts 1.1.0 dist/scene.js:1183-1234
      // (`createTickLabelCandidates`)
      final candidates = [
        for (final tick in ticks)
          _candidate(
            text,
            tick,
            TanstackLabel(
              text: tick.label,
              x: tick.position,
              y: axisY + (0 + x.padding + fontSize * .8),
              fontSize: fontSize,
              color: tickColor,
              anchor: TanstackAnchor.middle,
            ),
          ),
      ];
      final visible = thinTickLabels(candidates, categoricalX: x.categorical);
      var tickOuter = axisY;
      for (final candidate in visible) {
        include(candidate.bounds);
        tickOuter = math.max(tickOuter, candidate.bounds.bottom);
      }
      xLabels = [for (final candidate in visible) candidate.label];
      final title = x.title;
      if (title != null && title.text.isNotEmpty) {
        // @tanstack/charts 1.1.0 dist/scene.js:982-1005
        final label = TanstackLabel(
          text: title.text,
          x: chart.left + chart.width / 2,
          y: tickOuter + 8,
          fontSize: text.size(title.fontSize ?? (width < 360 ? 10 : 11)),
          fontWeight: title.fontWeight ?? FontWeight.w600,
          color: titleColor,
          anchor: TanstackAnchor.middle,
          baseline: TanstackBaseline.hanging,
        );
        include(text.labelBounds(label));
        xTitle = label;
      }
    }
    if (y != null) {
      // `renderYAxis` on the left side.
      final axisX = chart.left;
      final ticks = y.ticks(chart);
      yTicks = ticks;
      final candidates = [
        for (final tick in ticks)
          _candidate(
            text,
            tick,
            TanstackLabel(
              text: tick.label,
              x: axisX - (0 + y.padding),
              y: tick.position,
              fontSize: fontSize,
              color: tickColor,
              anchor: TanstackAnchor.end,
              baseline: TanstackBaseline.middle,
            ),
          ),
      ];
      // A y axis never keeps its ends first (dist/scene.js:1045).
      final visible = thinTickLabels(candidates, categoricalX: false);
      var tickOuter = axisX;
      for (final candidate in visible) {
        include(candidate.bounds);
        tickOuter = math.min(tickOuter, candidate.bounds.left);
      }
      yLabels = [for (final candidate in visible) candidate.label];
      final title = y.title;
      if (title != null && title.text.isNotEmpty) {
        // @tanstack/charts 1.1.0 dist/scene.js:1067-1098
        final label = TanstackLabel(
          text: title.text,
          x: axisX,
          y: chart.top + chart.height / 2,
          fontSize: text.size(title.fontSize ?? 11),
          fontWeight: title.fontWeight ?? FontWeight.w600,
          color: titleColor,
          anchor: TanstackAnchor.middle,
          baseline: TanstackBaseline.middle,
          rotate: -90,
        );
        final local = text.labelBounds(
          TanstackLabel(
            text: label.text,
            x: 0,
            y: 0,
            fontSize: label.fontSize,
            fontWeight: label.fontWeight,
            color: titleColor,
            anchor: label.anchor,
            baseline: label.baseline,
            rotate: label.rotate,
          ),
        );
        label.x = tickOuter - 8 - (local.left + local.width);
        include(text.labelBounds(label));
        yTitle = label;
      }
    }
    return TanstackCartesianLayout._(
      chart,
      margin,
      xTicks,
      yTicks,
      xLabels,
      yLabels,
      xTitle,
      yTitle,
      (top: top, right: right, bottom: bottom, left: left),
    );
  }

  /// The plot box.
  final Rect chart;

  /// The margins the layout used.
  final TanstackMargin margin;

  /// The x axis' ticks (null without an x axis).
  final List<TanstackTick>? xTicks;

  /// The y axis' ticks (null without a y axis).
  final List<TanstackTick>? yTicks;

  /// The x tick labels shown.
  final List<TanstackLabel> xLabels;

  /// The y tick labels shown.
  final List<TanstackLabel> yLabels;

  /// The x axis title, or null.
  final TanstackLabel? xTitle;

  /// The y axis title, or null.
  final TanstackLabel? yTitle;

  final TanstackMargin _guideMargin;

  static TanstackLabelCandidate _candidate(
    TanstackText text,
    TanstackTick tick,
    TanstackLabel label,
  ) => TanstackLabelCandidate(tick.value, label, text.labelBounds(label));

  // @tanstack/charts 1.1.0 dist/scene.js:780-786 (`mergeMarginLocks`, with
  // no locks)
  static TanstackMargin _maxMargin(TanstackMargin a, TanstackMargin b) => (
    top: math.max(a.top, b.top),
    right: math.max(a.right, b.right),
    bottom: math.max(a.bottom, b.bottom),
    left: math.max(a.left, b.left),
  );

  // @tanstack/charts 1.1.0 dist/scene.js:787-791 (`marginsEqual`; the
  // tolerance is `layoutTolerance`, dist/scene.js:542)
  static bool _marginsEqual(TanstackMargin a, TanstackMargin b) =>
      (a.top - b.top).abs() <= .25 &&
      (a.right - b.right).abs() <= .25 &&
      (a.bottom - b.bottom).abs() <= .25 &&
      (a.left - b.left).abs() <= .25;
}

/// Paints TanStack's grid rules at [positions] across [chart]: dashed
/// `2 4`, 1px, in [grid] at 11% of its own opacity (the grid group's
/// `strokeOpacity`, which the rules inherit). [vertical] rules for an x
/// axis. A rule with an end that is not finite (a tick at NaN, a plot
/// whose margins are NaN) is not drawn.
// @tanstack/charts 1.1.0 dist/scene.js:818-858 (`createGrid`; its `<line>`
// gets the numbers as they are, dist/svg-renderer.js:49-50, and the browser
// draws nothing for a coordinate it can't parse: RULEBOOK section 6 item
// 3); the dash is the playground's `GRID` (chart-kit.tsx)
void paintTanstackGrid(
  Canvas canvas,
  Rect chart,
  Iterable<double> positions,
  Color grid, {
  bool vertical = false,
}) {
  final paint = Paint()
    ..color = grid.withValues(alpha: grid.a * .11)
    ..strokeWidth = 1;
  for (final at in positions) {
    final a = vertical ? Offset(at, chart.top) : Offset(chart.left, at);
    final b = vertical ? Offset(at, chart.bottom) : Offset(chart.right, at);
    if (!a.isFinite || !b.isFinite) continue;
    paintDashedLine(canvas, a, b, paint, dash: 2, gap: 4);
  }
}

/// The path [build] adds, as a browser draws the SVG path data TanStack
/// writes for it: up to the first command holding a number that is not
/// finite, which draws nothing, nor does any command after it. Null when
/// that is the first command.
///
/// TanStack writes a mark's numbers into its `d` as they are: the
/// playground's curves with `${y}` (chart-kit.tsx:128-159, `monotonePath`),
/// TanStack's own polylines with `number()` (dist/svg-renderer.js:51-58,
/// 77-81; `number(NaN)` is "NaN", dist/markup-internal.js:1-3). Neither it
/// nor the playground drops a point whose position is not finite: the
/// marks keep every row whose values are finite (dist/line.js:134-155,
/// dist/area.js:123-135), and a value at the end of a domain whose span
/// overflows a double maps to NaN (dist/scales/linear.js:76-81). SVG 2,
/// Paths, "Error handling in path data": the user agent renders a path up
/// to, but not including, the command holding the first error.
// The curves are built into a recording path and replayed: a `dart:ui`
// path can't be read back command by command, and its box is no test of a
// NaN point (the engine may report an empty box for such a path).
Path? tanstackSvgPath(void Function(Path path) build) {
  final recorder = _PathCommands();
  build(recorder);
  final path = Path();
  var drawn = 0;
  for (final (:verb, :numbers) in recorder.commands) {
    if (!numbers.every((n) => n.isFinite)) break;
    switch (verb) {
      case _PathVerb.move:
        path.moveTo(numbers[0], numbers[1]);
      case _PathVerb.line:
        path.lineTo(numbers[0], numbers[1]);
      case _PathVerb.cubic:
        path.cubicTo(
          numbers[0],
          numbers[1],
          numbers[2],
          numbers[3],
          numbers[4],
          numbers[5],
        );
      case _PathVerb.close:
        path.close();
    }
    drawn++;
  }
  return drawn == 0 ? null : path;
}

enum _PathVerb { move, line, cubic, close }

/// A [Path] that only records the commands the curves add to it (moves,
/// lines, cubics and a close); anything else is unsupported.
class _PathCommands implements Path {
  final List<({_PathVerb verb, List<double> numbers})> commands = [];

  @override
  void moveTo(double x, double y) =>
      commands.add((verb: _PathVerb.move, numbers: [x, y]));

  @override
  void lineTo(double x, double y) =>
      commands.add((verb: _PathVerb.line, numbers: [x, y]));

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => commands.add((verb: _PathVerb.cubic, numbers: [x1, y1, x2, y2, x3, y3]));

  @override
  void close() => commands.add((verb: _PathVerb.close, numbers: const []));

  @override
  Never noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'A recorded TanStack path takes moves, lines, cubics and a close only',
  );
}

// PORT STATUS: confidence=high todos=0 upstream=@tanstack/charts@1.1.0
