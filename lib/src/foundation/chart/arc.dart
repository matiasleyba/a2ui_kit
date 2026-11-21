// Pie and donut slices.
//
// `d3ArcPath` ports d3-shape 3.2.0's `arc` generator (ISC, (c) Mike
// Bostock), with its pad angle and rounded corners: the playground's
// PieChart (TanStack Charts 1.1.0's `radialArc`) draws its slices with it.
// `rechartsSectorPath` ports recharts 3.10.1's `Sector` (`getSectorPath`,
// `getSectorWithCorner`; MIT, (c) Recharts Group), the slices of
// CopilotKit's standard Chart. Each is ported from the published source,
// cited above it. See NOTICE.md.

import 'dart:math' as math;
import 'dart:ui';

const double _epsilon = 1e-12;
const double _tau = 2 * math.pi;
const double _halfPi = math.pi / 2;

/// d3-path's epsilon (src/path.js:3).
const double _pathEpsilon = 1e-6;

/// d3-shape's `acos`, clamped: 0 above 1, π below -1 (src/math.js:14-16).
double d3Acos(double x) => x > 1
    ? 0
    : x < -1
    ? math.pi
    : math.acos(x);

/// d3-shape's `asin`, clamped: ±π/2 at or past ±1 (src/math.js:18-20).
double d3Asin(double x) => x >= 1
    ? _halfPi
    : x <= -1
    ? -_halfPi
    : math.asin(x);

/// d3-path's `arc(x, y, r, a0, a1, ccw)` on [path], which must have a
/// point: a line to the arc's start ([cx], [cy] plus [r] at [a0]), then,
/// unless [r] is 0, the arc to [a1]: two halves for a whole circle, nothing
/// more for an angle of 1e-6 or less.
// d3-path 3.1.0 src/path.js:100-138 (JavaScript's `%`, which keeps the
// dividend's sign, is Dart's `remainder`)
void d3PathArc(
  Path path,
  double cx,
  double cy,
  double r,
  double a0,
  double a1, {
  required bool ccw,
}) {
  final x0 = cx + r * math.cos(a0);
  final y0 = cy + r * math.sin(a0);
  // The path always has a point here (d3ArcPath moves first), so the line
  // to the arc's start is drawn; a zero-length one draws nothing.
  path.lineTo(x0, y0);
  if (r == 0) return;
  final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
  var da = ccw ? a0 - a1 : a1 - a0;
  if (da < 0) da = da.remainder(_tau) + _tau;
  if (da > _tau - _pathEpsilon) {
    // A whole circle: two halves, so the path closes on itself.
    final sweep = ccw ? -math.pi : math.pi;
    path
      ..arcTo(rect, a0, sweep, false)
      ..arcTo(rect, a0 + sweep, sweep, false);
    return;
  }
  if (!(da > _pathEpsilon)) return;
  path.arcTo(rect, a0, ccw ? -da : da, false);
}

(double, double)? _intersect(
  double x0,
  double y0,
  double x1,
  double y1,
  double x2,
  double y2,
  double x3,
  double y3,
) {
  final x10 = x1 - x0;
  final y10 = y1 - y0;
  final x32 = x3 - x2;
  final y32 = y3 - y2;
  var t = y32 * x10 - x32 * y10;
  if (t * t < _epsilon) return null;
  t = (x32 * (y0 - y2) - y32 * (x0 - x2)) / t;
  return (x0 + t * x10, y0 + t * y10);
}

class _Tangent {
  const _Tangent(this.cx, this.cy, this.x01, this.y01, this.x11, this.y11);
  final double cx;
  final double cy;
  final double x01;
  final double y01;
  final double x11;
  final double y11;
}

/// d3's `cornerTangents`: the circle of radius [rc] in the corner at
/// (x1, y1) of a ring of radius [r1].
_Tangent _cornerTangents(
  double x0,
  double y0,
  double x1,
  double y1,
  double r1,
  double rc, {
  required bool cw,
}) {
  final x01 = x0 - x1;
  final y01 = y0 - y1;
  final lo = (cw ? rc : -rc) / math.sqrt(x01 * x01 + y01 * y01);
  final ox = lo * y01;
  final oy = -lo * x01;
  final x11 = x0 + ox;
  final y11 = y0 + oy;
  final x10 = x1 + ox;
  final y10 = y1 + oy;
  final x00 = (x11 + x10) / 2;
  final y00 = (y11 + y10) / 2;
  final dx = x10 - x11;
  final dy = y10 - y11;
  final d2 = dx * dx + dy * dy;
  final r = r1 - rc;
  final d0 = x11 * y10 - x10 * y11;
  final d = (dy < 0 ? -1 : 1) * math.sqrt(math.max(0, r * r * d2 - d0 * d0));
  var cx0 = (d0 * dy - dx * d) / d2;
  var cy0 = (-d0 * dx - dy * d) / d2;
  final cx1 = (d0 * dy + dx * d) / d2;
  final cy1 = (-d0 * dx + dy * d) / d2;
  final dx0 = cx0 - x00;
  final dy0 = cy0 - y00;
  final dx1 = cx1 - x00;
  final dy1 = cy1 - y00;
  // The closer of the two intersections.
  if (dx0 * dx0 + dy0 * dy0 > dx1 * dx1 + dy1 * dy1) {
    cx0 = cx1;
    cy0 = cy1;
  }
  return _Tangent(cx0, cy0, -ox, -oy, cx0 * (r1 / r - 1), cy0 * (r1 / r - 1));
}

/// The path of a d3 arc centred on [center]: the slice from [startAngle] to
/// [endAngle] (radians, clockwise from 12 o'clock) between [innerRadius]
/// and [outerRadius], narrowed by [padAngle] (as d3's pie gives it, with
/// d3's pad radius) and with corners rounded by [cornerRadius]. TanStack
/// Charts' `radialArc` draws its slices with it (`@tanstack/charts` 1.1.0
/// `dist/polar.js:178`, pad angle 0).
// d3-shape 3.2.0 src/arc.js:88-227 (`arc`), with its clamped `asin` and
// `acos` (src/math.js:14-20); its `context.arc` is d3-path 3.1.0's
// (src/path.js:100-138, [d3PathArc]).
Path d3ArcPath({
  required Offset center,
  required double innerRadius,
  required double outerRadius,
  required double startAngle,
  required double endAngle,
  double padAngle = 0,
  double cornerRadius = 0,
}) {
  final path = Path();
  var r0 = innerRadius;
  var r1 = outerRadius;
  final a0 = startAngle - _halfPi;
  final a1 = endAngle - _halfPi;
  final da = (a1 - a0).abs();
  final cw = a1 > a0;
  if (r1 < r0) (r0, r1) = (r1, r0);
  if (!(r1 > _epsilon)) {
    path.moveTo(0, 0);
  } else if (da > _tau - _epsilon) {
    // A circle or an annulus.
    path.moveTo(r1 * math.cos(a0), r1 * math.sin(a0));
    d3PathArc(path, 0, 0, r1, a0, a1, ccw: !cw);
    if (r0 > _epsilon) {
      path.moveTo(r0 * math.cos(a1), r0 * math.sin(a1));
      d3PathArc(path, 0, 0, r0, a1, a0, ccw: cw);
    }
  } else {
    var a01 = a0;
    var a11 = a1;
    var a00 = a0;
    var a10 = a1;
    var da0 = da;
    var da1 = da;
    final ap = padAngle / 2;
    final rp = ap > _epsilon ? math.sqrt(r0 * r0 + r1 * r1) : 0.0;
    final rc = math.min((r1 - r0).abs() / 2, cornerRadius);
    var rc0 = rc;
    var rc1 = rc;
    // src/arc.js:132-140: a 0 inner radius makes p0 NaN, and the inner
    // side collapses to the middle.
    if (rp > _epsilon) {
      var p0 = d3Asin(rp / r0 * math.sin(ap));
      var p1 = d3Asin(rp / r1 * math.sin(ap));
      if ((da0 -= p0 * 2) > _epsilon) {
        p0 *= cw ? 1 : -1;
        a00 += p0;
        a10 -= p0;
      } else {
        da0 = 0;
        a00 = a10 = (a0 + a1) / 2;
      }
      if ((da1 -= p1 * 2) > _epsilon) {
        p1 *= cw ? 1 : -1;
        a01 += p1;
        a11 -= p1;
      } else {
        da1 = 0;
        a01 = a11 = (a0 + a1) / 2;
      }
    }
    final x01 = r1 * math.cos(a01);
    final y01 = r1 * math.sin(a01);
    final x10 = r0 * math.cos(a10);
    final y10 = r0 * math.sin(a10);
    if (rc > _epsilon) {
      final x11 = r1 * math.cos(a11);
      final y11 = r1 * math.sin(a11);
      final x00 = r0 * math.cos(a00);
      final y00 = r0 * math.sin(a00);
      // The corner radius is limited by the sector's angle; when the edges
      // do not meet, the arc is too small for corners at all.
      if (da < math.pi) {
        final oc = _intersect(x01, y01, x00, y00, x11, y11, x10, y10);
        if (oc != null) {
          final ax = x01 - oc.$1;
          final ay = y01 - oc.$2;
          final bx = x11 - oc.$1;
          final by = y11 - oc.$2;
          final cos =
              (ax * bx + ay * by) /
              (math.sqrt(ax * ax + ay * ay) * math.sqrt(bx * bx + by * by));
          final kc = 1 / math.sin(d3Acos(cos) / 2);
          final lc = math.sqrt(oc.$1 * oc.$1 + oc.$2 * oc.$2);
          rc0 = math.min(rc, (r0 - lc) / (kc - 1));
          rc1 = math.min(rc, (r1 - lc) / (kc + 1));
        } else {
          rc0 = rc1 = 0;
        }
      }
    }
    if (!(da1 > _epsilon)) {
      path.moveTo(x01, y01);
    } else if (rc1 > _epsilon) {
      final t0 = _cornerTangents(
        r0 * math.cos(a00),
        r0 * math.sin(a00),
        x01,
        y01,
        r1,
        rc1,
        cw: cw,
      );
      final t1 = _cornerTangents(
        r1 * math.cos(a11),
        r1 * math.sin(a11),
        x10,
        y10,
        r1,
        rc1,
        cw: cw,
      );
      path.moveTo(t0.cx + t0.x01, t0.cy + t0.y01);
      if (rc1 < rc) {
        // The corners have merged.
        d3PathArc(
          path,
          t0.cx,
          t0.cy,
          rc1,
          math.atan2(t0.y01, t0.x01),
          math.atan2(t1.y01, t1.x01),
          ccw: !cw,
        );
      } else {
        d3PathArc(
          path,
          t0.cx,
          t0.cy,
          rc1,
          math.atan2(t0.y01, t0.x01),
          math.atan2(t0.y11, t0.x11),
          ccw: !cw,
        );
        d3PathArc(
          path,
          0,
          0,
          r1,
          math.atan2(t0.cy + t0.y11, t0.cx + t0.x11),
          math.atan2(t1.cy + t1.y11, t1.cx + t1.x11),
          ccw: !cw,
        );
        d3PathArc(
          path,
          t1.cx,
          t1.cy,
          rc1,
          math.atan2(t1.y11, t1.x11),
          math.atan2(t1.y01, t1.x01),
          ccw: !cw,
        );
      }
    } else {
      path.moveTo(x01, y01);
      d3PathArc(path, 0, 0, r1, a01, a11, ccw: !cw);
    }
    if (!(r0 > _epsilon) || !(da0 > _epsilon)) {
      path.lineTo(x10, y10);
    } else if (rc0 > _epsilon) {
      final t0 = _cornerTangents(
        x10,
        y10,
        r1 * math.cos(a11),
        r1 * math.sin(a11),
        r0,
        -rc0,
        cw: cw,
      );
      final t1 = _cornerTangents(
        x01,
        y01,
        r0 * math.cos(a00),
        r0 * math.sin(a00),
        r0,
        -rc0,
        cw: cw,
      );
      path.lineTo(t0.cx + t0.x01, t0.cy + t0.y01);
      if (rc0 < rc) {
        d3PathArc(
          path,
          t0.cx,
          t0.cy,
          rc0,
          math.atan2(t0.y01, t0.x01),
          math.atan2(t1.y01, t1.x01),
          ccw: !cw,
        );
      } else {
        d3PathArc(
          path,
          t0.cx,
          t0.cy,
          rc0,
          math.atan2(t0.y01, t0.x01),
          math.atan2(t0.y11, t0.x11),
          ccw: !cw,
        );
        d3PathArc(
          path,
          0,
          0,
          r0,
          math.atan2(t0.cy + t0.y11, t0.cx + t0.x11),
          math.atan2(t1.cy + t1.y11, t1.cx + t1.x11),
          ccw: cw,
        );
        d3PathArc(
          path,
          t1.cx,
          t1.cy,
          rc0,
          math.atan2(t1.y11, t1.x11),
          math.atan2(t1.y01, t1.x01),
          ccw: !cw,
        );
      }
    } else {
      d3PathArc(path, 0, 0, r0, a10, a00, ccw: cw);
    }
  }
  path.close();
  return path.shift(center);
}

/// The middle of the d3 arc from [startAngle] to [endAngle] (radians,
/// clockwise from 12 o'clock) at [radius] from [center]: at the mean of
/// the radii, `arc.centroid`.
// d3-shape 3.2.0 src/arc.js:229-233 (`arc.centroid`)
Offset d3ArcPoint(
  Offset center,
  double radius,
  double startAngle,
  double endAngle,
) {
  final a = (startAngle + endAngle) / 2 - _halfPi;
  return center + Offset(math.cos(a), math.sin(a)) * radius;
}

const double _radian = math.pi / 180;

/// recharts' `polarToCartesian`: [angle] in degrees, counterclockwise from
/// 3 o'clock, at [radius] from [center].
// recharts 3.10.1 es6/util/PolarUtils.js:6-12
Offset rechartsPolar(Offset center, double radius, double angle) => Offset(
  center.dx + math.cos(-_radian * angle) * radius,
  center.dy + math.sin(-_radian * angle) * radius,
);

double _sign(double value) => value == 0
    ? 0
    : value > 0
    ? 1
    : -1;

/// The path of a recharts `Sector`: the slice from [startAngle] to
/// [endAngle] (degrees, counterclockwise from 3 o'clock) between
/// [innerRadius] and [outerRadius], its corners rounded by [cornerRadius]
/// (at most half the ring's width). Callers leave out an empty sector,
/// which recharts' `Sector` does not draw (Sector.js:180-182).
// recharts 3.10.1 es6/shape/Sector.js:183-207 (`Sector`: the corner capped
// at the ring's width, then at half of it)
Path rechartsSectorPath({
  required Offset center,
  required double innerRadius,
  required double outerRadius,
  required double startAngle,
  required double endAngle,
  double cornerRadius = 0,
}) {
  final sink = _PathSink();
  _sector(
    sink,
    center,
    innerRadius,
    outerRadius,
    startAngle,
    endAngle,
    cornerRadius,
  );
  return sink.path;
}

/// The tight box of what [rechartsSectorPath] draws for the same
/// arguments (an SVG element's `getBBox`, RULEBOOK section 2): every end of
/// its lines and arcs, and each arc's extremes at the axis angles it sweeps,
/// exactly; null for one that draws nothing.
Rect? rechartsSectorBounds({
  required Offset center,
  required double innerRadius,
  required double outerRadius,
  required double startAngle,
  required double endAngle,
  double cornerRadius = 0,
}) {
  final sink = _BoundsSink();
  _sector(
    sink,
    center,
    innerRadius,
    outerRadius,
    startAngle,
    endAngle,
    cornerRadius,
  );
  return sink.bounds;
}

void _sector(
  _SectorSink sink,
  Offset center,
  double innerRadius,
  double outerRadius,
  double startAngle,
  double endAngle,
  double cornerRadius,
) {
  final delta = outerRadius - innerRadius;
  final corner = math.min(cornerRadius, delta / 2);
  if (corner > 0 && (startAngle - endAngle).abs() < 360) {
    _sectorWithCorner(
      sink,
      center,
      innerRadius,
      outerRadius,
      corner,
      startAngle,
      endAngle,
    );
    return;
  }
  _sectorPath(sink, center, innerRadius, outerRadius, startAngle, endAngle);
}

/// Where a sector's outline goes: the SVG path commands recharts writes.
abstract interface class _SectorSink {
  void moveTo(Offset point);
  void lineTo(Offset point);

  /// SVG's elliptical arc command with a circle of [radius]: `clockwise` is
  /// its sweep flag (positive angles in a y-down plane), as Flutter's
  /// `Path.arcToPoint` reads it.
  void arcTo(
    Offset end,
    double radius, {
    required bool clockwise,
    bool largeArc = false,
  });

  void close();
}

class _PathSink implements _SectorSink {
  final Path path = Path();

  @override
  void moveTo(Offset point) => path.moveTo(point.dx, point.dy);

  @override
  void lineTo(Offset point) => path.lineTo(point.dx, point.dy);

  @override
  void arcTo(
    Offset end,
    double radius, {
    required bool clockwise,
    bool largeArc = false,
  }) => path.arcToPoint(
    end,
    radius: Radius.circular(radius),
    largeArc: largeArc,
    clockwise: clockwise,
  );

  @override
  void close() => path.close();
}

/// The tight box of a sector's outline: its points, and each arc's
/// extremes, from the arc's centre (SVG 2's arc implementation notes,
/// "Conversion from endpoint to center parameterization", with a circle:
/// a radius too small for its chord grows to half the chord, and the centre
/// is the one whose sweep is large or small as the flag says).
class _BoundsSink implements _SectorSink {
  Offset? _current;
  double _left = double.infinity;
  double _top = double.infinity;
  double _right = double.negativeInfinity;
  double _bottom = double.negativeInfinity;

  Rect? get bounds =>
      _left <= _right ? Rect.fromLTRB(_left, _top, _right, _bottom) : null;

  void _take(Offset point) {
    _left = math.min(_left, point.dx);
    _top = math.min(_top, point.dy);
    _right = math.max(_right, point.dx);
    _bottom = math.max(_bottom, point.dy);
  }

  @override
  void moveTo(Offset point) {
    _current = point;
    _take(point);
  }

  @override
  void lineTo(Offset point) {
    _current = point;
    _take(point);
  }

  @override
  void arcTo(
    Offset end,
    double radius, {
    required bool clockwise,
    bool largeArc = false,
  }) {
    final start = _current ?? Offset.zero;
    _current = end;
    _take(end);
    final chord = end - start;
    final half = chord.distance / 2;
    // An arc between one point and itself, or of no radius, draws nothing
    // past its ends.
    if (half == 0 || radius == 0) return;
    final r = math.max(radius.abs(), half);
    final middle = (start + end) / 2;
    final normal = Offset(-chord.dy, chord.dx) / (2 * half);
    final rise = math.sqrt(math.max(0, r * r - half * half));
    for (final side in [1.0, -1.0]) {
      final centre = middle + normal * (rise * side);
      final from = math.atan2(start.dy - centre.dy, start.dx - centre.dx);
      var sweep = math.atan2(end.dy - centre.dy, end.dx - centre.dx) - from;
      if (clockwise) {
        while (sweep <= 0) {
          sweep += 2 * math.pi;
        }
      } else {
        while (sweep >= 0) {
          sweep -= 2 * math.pi;
        }
      }
      if ((sweep.abs() > math.pi) != largeArc && side > 0 && rise > 0) {
        continue;
      }
      // The axis angles the sweep passes, a multiple of a right angle
      // each: the circle's leftmost, topmost, rightmost and bottommost.
      final to = from + sweep;
      final low = math.min(from, to);
      final high = math.max(from, to);
      for (var k = (low / _halfPi).floor() + 1; k * _halfPi < high; k++) {
        final angle = k * _halfPi;
        _take(centre + Offset(math.cos(angle), math.sin(angle)) * r);
      }
      return;
    }
  }

  @override
  void close() {}
}

// recharts 3.10.1 es6/shape/Sector.js:11-15 (`getDeltaAngle`, at most
// 359.999°) and :41-63 (`getSectorPath`: SVG arcs, the sweep flag as
// `clockwise`)
void _sectorPath(
  _SectorSink sink,
  Offset center,
  double innerRadius,
  double outerRadius,
  double startAngle,
  double endAngle,
) {
  final delta = endAngle - startAngle;
  final angle = _sign(delta) * math.min(delta.abs(), 359.999);
  final end = startAngle + angle;
  final outerStart = rechartsPolar(center, outerRadius, startAngle);
  final outerEnd = rechartsPolar(center, outerRadius, end);
  sink
    ..moveTo(outerStart)
    ..arcTo(
      outerEnd,
      outerRadius,
      largeArc: angle.abs() > 180,
      clockwise: startAngle > end,
    );
  if (innerRadius > 0) {
    final innerStart = rechartsPolar(center, innerRadius, startAngle);
    final innerEnd = rechartsPolar(center, innerRadius, end);
    sink
      ..lineTo(innerEnd)
      ..arcTo(
        innerStart,
        innerRadius,
        largeArc: angle.abs() > 180,
        clockwise: startAngle <= end,
      );
  } else {
    sink.lineTo(center);
  }
  sink.close();
}

/// recharts' `getTangentCircle` (`cornerIsExternal` false, as recharts'
/// default).
// recharts 3.10.1 es6/shape/Sector.js:16-40
({Offset circleTangency, Offset lineTangency, double theta}) _tangentCircle(
  Offset center,
  double radius,
  double angle,
  double sign,
  double corner, {
  bool external = false,
}) {
  final centerRadius = corner * (external ? 1 : -1) + radius;
  final theta = math.asin(corner / centerRadius) / _radian;
  final centerAngle = angle + sign * theta;
  final circleTangency = rechartsPolar(center, radius, centerAngle);
  final lineTangency = rechartsPolar(
    center,
    centerRadius * math.cos(theta * _radian),
    angle,
  );
  return (
    circleTangency: circleTangency,
    lineTangency: lineTangency,
    theta: theta,
  );
}

// recharts 3.10.1 es6/shape/Sector.js:64-153 (`getSectorWithCorner`,
// `forceCornerRadius` and `cornerIsExternal` false)
void _sectorWithCorner(
  _SectorSink sink,
  Offset center,
  double innerRadius,
  double outerRadius,
  double corner,
  double startAngle,
  double endAngle,
) {
  final sign = _sign(endAngle - startAngle);
  final so = _tangentCircle(center, outerRadius, startAngle, sign, corner);
  final eo = _tangentCircle(center, outerRadius, endAngle, -sign, corner);
  final outerArc = (startAngle - endAngle).abs() - so.theta - eo.theta;
  if (outerArc < 0) {
    _sectorPath(sink, center, innerRadius, outerRadius, startAngle, endAngle);
    return;
  }
  final sweep = sign < 0;
  sink
    ..moveTo(so.lineTangency)
    ..arcTo(so.circleTangency, corner, clockwise: sweep)
    ..arcTo(
      eo.circleTangency,
      outerRadius,
      largeArc: outerArc > 180,
      clockwise: sweep,
    )
    ..arcTo(eo.lineTangency, corner, clockwise: sweep);
  if (innerRadius > 0) {
    final si = _tangentCircle(
      center,
      innerRadius,
      startAngle,
      sign,
      corner,
      external: true,
    );
    final ei = _tangentCircle(
      center,
      innerRadius,
      endAngle,
      -sign,
      corner,
      external: true,
    );
    final innerArc = (startAngle - endAngle).abs() - si.theta - ei.theta;
    sink
      ..lineTo(ei.lineTangency)
      ..arcTo(ei.circleTangency, corner, clockwise: sweep)
      ..arcTo(
        si.circleTangency,
        innerRadius,
        largeArc: innerArc > 180,
        clockwise: sign > 0,
      )
      ..arcTo(si.lineTangency, corner, clockwise: sweep);
  } else {
    sink.lineTo(center);
  }
  sink.close();
}

// PORT STATUS: confidence=high todos=0 upstream=d3-shape@3.2.0, recharts@3.10.1, @tanstack/charts@1.1.0 (the header names the files)
