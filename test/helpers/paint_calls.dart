// Paint-call predicates for `paints..something(…)`: each finds the first
// call that matches, skipping the others. (`paints..circle()` checks only
// the next circle drawn, so a chart's earlier circles would fail it.)
// Colours compare as 8-bit ARGB, as a Paint keeps them; positions within
// 1e-6.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

bool _near(double a, double? b) => b == null || (a - b).abs() < 1e-6;

bool _rectNear(Rect a, Rect? b) =>
    b == null ||
    _near(a.left, b.left) &&
        _near(a.top, b.top) &&
        _near(a.right, b.right) &&
        _near(a.bottom, b.bottom);

bool _paintIs(
  Paint paint, {
  Color? color,
  double? strokeWidth,
  PaintingStyle? style,
}) =>
    (color == null || paint.color.toARGB32() == color.toARGB32()) &&
    (strokeWidth == null || paint.strokeWidth == strokeWidth) &&
    (style == null || paint.style == style);

/// A `drawCircle` at ([x], [y]) of [radius] in a paint of [color],
/// [strokeWidth] and [style]; a null argument matches anything.
PaintPatternPredicate paintedCircle({
  double? x,
  double? y,
  double? radius,
  Color? color,
  double? strokeWidth,
  PaintingStyle? style,
}) =>
    (method, args) =>
        method == #drawCircle &&
        switch (args) {
          [final Offset c, final double r, final Paint p] =>
            _near(c.dx, x) &&
                _near(c.dy, y) &&
                _near(r, radius) &&
                _paintIs(
                  p,
                  color: color,
                  strokeWidth: strokeWidth,
                  style: style,
                ),
          _ => false,
        };

/// A `drawRect` of [rect] in [color].
PaintPatternPredicate paintedRect({Rect? rect, Color? color}) =>
    (method, args) =>
        method == #drawRect &&
        switch (args) {
          [final Rect r, final Paint p] =>
            _rectNear(r, rect) && _paintIs(p, color: color),
          _ => false,
        };

/// A `drawRRect` of [rrect] (its box and its four radii) in [color].
PaintPatternPredicate paintedRRect({RRect? rrect, Color? color}) =>
    (method, args) =>
        method == #drawRRect &&
        switch (args) {
          [final RRect r, final Paint p] =>
            (rrect == null ||
                    _rectNear(r.outerRect, rrect.outerRect) &&
                        r.tlRadius == rrect.tlRadius &&
                        r.trRadius == rrect.trRadius &&
                        r.brRadius == rrect.brRadius &&
                        r.blRadius == rrect.blRadius) &&
                _paintIs(p, color: color),
          _ => false,
        };

/// A `drawLine` in [color] and [strokeWidth].
PaintPatternPredicate paintedLine({Color? color, double? strokeWidth}) =>
    (method, args) =>
        method == #drawLine &&
        switch (args) {
          [final Offset _, final Offset _, final Paint p] => _paintIs(
            p,
            color: color,
            strokeWidth: strokeWidth,
          ),
          _ => false,
        };

/// A `drawPath` in [color], [style] and [strokeWidth], whose path's
/// bounds (its points' box, control points included) are [bounds].
PaintPatternPredicate paintedPath({
  Color? color,
  PaintingStyle? style,
  double? strokeWidth,
  Rect? bounds,
}) =>
    (method, args) =>
        method == #drawPath &&
        switch (args) {
          [final Path path, final Paint p] =>
            _paintIs(p, color: color, style: style, strokeWidth: strokeWidth) &&
                _rectNear(path.getBounds(), bounds),
          _ => false,
        };
