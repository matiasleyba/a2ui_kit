// The curves of the charts.
//
// `addMonotonePath` ports `monotonePath` of the playground's
// `chart-kit.tsx` (MIT, (c) Atai Barkai): a Fritsch-Carlson monotone cubic,
// which TanStack Charts draws through the playground's `smoothCurve`.
// `addMonotoneXPath` and `addMonotoneYPath` port d3-shape 3.2.0's
// `curveMonotoneX` and `curveMonotoneY` (ISC, (c) Mike Bostock), which
// recharts 3.10.1 draws `type="monotone"` with, X in its horizontal layout
// and Y in its vertical one. See NOTICE.md.

import 'dart:math' as math;
import 'dart:ui';

/// Adds the playground's smooth curve (`smoothCurve` in `chart-kit.tsx`)
/// through [points], in the order given (the scenes pass data order), to
/// [path]: a monotone cubic
/// (Fritsch-Carlson) that never overshoots. Starts with a move, or a line
/// to the first point when [move] is false (an area's way back).
// examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/
// chart-kit.tsx:128-159 (`monotonePath`)
void addMonotonePath(Path path, List<Offset> points, {bool move = true}) {
  final n = points.length;
  if (n == 0) return;
  final first = points.first;
  if (move) {
    path.moveTo(first.dx, first.dy);
  } else {
    path.lineTo(first.dx, first.dy);
  }
  if (n == 1) return;
  if (n == 2) {
    path.lineTo(points[1].dx, points[1].dy);
    return;
  }
  final dx = <double>[];
  final m = <double>[];
  for (var i = 0; i < n - 1; i++) {
    final h = points[i + 1].dx - points[i].dx;
    dx.add(h);
    m.add(h == 0 ? 0 : (points[i + 1].dy - points[i].dy) / h);
  }
  final t = <double>[m[0]];
  for (var i = 1; i < n - 1; i++) {
    t.add(
      m[i - 1] * m[i] <= 0
          ? 0
          : (3 * (dx[i - 1] + dx[i])) /
                ((2 * dx[i] + dx[i - 1]) / m[i - 1] +
                    (dx[i] + 2 * dx[i - 1]) / m[i]),
    );
  }
  t.add(m[n - 2]);
  for (var i = 0; i < n - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final h = dx[i] / 3;
    path.cubicTo(
      a.dx + h,
      a.dy + t[i] * h,
      b.dx - h,
      b.dy - t[i + 1] * h,
      b.dx,
      b.dy,
    );
  }
}

/// The playground's smooth area: [top] left to right, then [bottom] back
/// right to left, both smooth, closed.
// chart-kit.tsx:161-168 (`smoothCurve.area`)
Path monotoneArea(List<Offset> top, List<Offset> bottom) {
  final path = Path();
  if (top.isEmpty) return path;
  addMonotonePath(path, top);
  addMonotonePath(path, bottom.reversed.toList(), move: false);
  return path..close();
}

/// Adds d3's `curveMonotoneX` through [points] to [path], as recharts draws
/// a `monotone` line in its horizontal layout: Steffen's monotone tangents,
/// coincident points skipped. Starts with a move, or a line when [move] is
/// false (the second line of an area, d3's `areaStart`).
void addMonotoneXPath(Path path, List<Offset> points, {bool move = true}) =>
    _monotone(
      points,
      move: move,
      moveTo: path.moveTo,
      lineTo: path.lineTo,
      cubicTo: path.cubicTo,
    );

/// Adds d3's `curveMonotoneY` through [points] to [path], as recharts draws
/// a `monotone` line in its vertical layout (CopilotKit's horizontal
/// Chart): monotone in y, so x is a function of y.
// d3-shape 3.2.0 src/curve/monotone.js:79-96: `MonotoneX` on (y, x), its
// output reflected back through `ReflectContext`.
void addMonotoneYPath(Path path, List<Offset> points, {bool move = true}) =>
    _monotone(
      [for (final p in points) Offset(p.dy, p.dx)],
      move: move,
      moveTo: (x, y) => path.moveTo(y, x),
      lineTo: (x, y) => path.lineTo(y, x),
      cubicTo: (x1, y1, x2, y2, x, y) => path.cubicTo(y1, x1, y2, x2, y, x),
    );

// d3-shape 3.2.0 src/curve/monotone.js:1-77 (`MonotoneX`, one line from
// `lineStart` to `lineEnd`; an area's `_line` state is [move]).
void _monotone(
  List<Offset> points, {
  required bool move,
  required void Function(double x, double y) moveTo,
  required void Function(double x, double y) lineTo,
  required void Function(
    double x1,
    double y1,
    double x2,
    double y2,
    double x,
    double y,
  )
  cubicTo,
}) {
  var state = 0;
  var x0 = double.nan;
  var y0 = double.nan;
  var x1 = double.nan;
  var y1 = double.nan;
  var t0 = double.nan;

  // monotone.js:1-3
  double sign(double x) => x < 0 ? -1 : 1;

  // monotone.js:9-16 (`slope3`); `h0 || h1 < 0 && -0` divides by -0 or 0.
  double slope3(double x2, double y2) {
    final h0 = x1 - x0;
    final h1 = x2 - x1;
    final s0 = (y1 - y0) / (h0 != 0 && !h0.isNaN ? h0 : (h1 < 0 ? -0.0 : 0.0));
    final s1 = (y2 - y1) / (h1 != 0 && !h1.isNaN ? h1 : (h0 < 0 ? -0.0 : 0.0));
    final p = (s0 * h1 + s1 * h0) / (h0 + h1);
    final value =
        (sign(s0) + sign(s1)) *
        math.min(math.min(s0.abs(), s1.abs()), .5 * p.abs());
    return value.isNaN ? 0 : value;
  }

  // monotone.js:19-22 (`slope2`)
  double slope2(double t) {
    final h = x1 - x0;
    return h != 0 && !h.isNaN ? (3 * (y1 - y0) / h - t) / 2 : t;
  }

  // monotone.js:27-34 (`point`)
  void segment(double ta, double tb) {
    final dx = (x1 - x0) / 3;
    cubicTo(x0 + dx, y0 + dx * ta, x1 - dx, y1 - dx * tb, x1, y1);
  }

  // monotone.js:61-76 (`point`)
  for (final point in points) {
    final x = point.dx;
    final y = point.dy;
    var t1 = double.nan;
    if (x == x1 && y == y1) continue;
    switch (state) {
      case 0:
        state = 1;
        if (move) {
          moveTo(x, y);
        } else {
          lineTo(x, y);
        }
      case 1:
        state = 2;
      case 2:
        state = 3;
        t1 = slope3(x, y);
        segment(slope2(t1), t1);
      default:
        t1 = slope3(x, y);
        segment(t0, t1);
    }
    x0 = x1;
    x1 = x;
    y0 = y1;
    y1 = y;
    t0 = t1;
  }
  // monotone.js:53-57 (`lineEnd`)
  switch (state) {
    case 2:
      lineTo(x1, y1);
    case 3:
      segment(t0, slope2(t0));
  }
}

/// Adds a straight polyline through [points] to [path].
void addLinearPath(Path path, List<Offset> points, {bool move = true}) {
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    if (i == 0 && move) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/chart-kit.tsx, d3-shape@3.2.0
