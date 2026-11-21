// TanStack Charts' interaction: which point a pointer focuses, the group a
// focus shows, the keyboard's order, and where the tooltip goes. The
// interaction of the playground's charts.
//
// Ported from the published source of @tanstack/charts 1.1.0 (MIT, (c)
// Tanner Linsley): `dist/focus.js`, `dist/nearest.js`, `dist/interaction.js`,
// `dist/focus-layer.js` (`sameFocusedPoint`), `dist/tooltip-model.js`
// (`orderChartTooltipPoints`), `dist/tooltip-placement.js`,
// `dist/rect-radius-internal.js` and `dist/mark.js` (the points' keys). See
// NOTICE.md.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:a2ui_kit/src/foundation/chart/tanstack_stack.dart';
import 'package:flutter/foundation.dart' show immutable;

/// A point of a TanStack scene (`ChartPoint`): where a datum is drawn, what
/// a focus and a tooltip read.
class TanstackPoint {
  /// A point.
  TanstackPoint({
    required this.key,
    required this.markId,
    required this.group,
    required this.datum,
    required this.x,
    required this.y,
    required this.color,
    this.xValue,
    this.yValue,
    double? focusX,
    double? focusY,
  }) : focusX = focusX ?? x,
       focusY = focusY ?? y;

  /// The point's key (`markId:group:datumKey`).
  final String key;

  /// The mark that drew it.
  final String markId;

  /// Its series (`z`), or null.
  final Object? group;

  /// The datum: the index of its row in the chart's data, so the points
  /// of one row in different marks are the same datum.
  final int datum;

  /// Where it is drawn.
  final double x;

  /// Where it is drawn.
  final double y;

  /// Its colour (`point.color`).
  final Color color;

  /// The x value.
  final Object? xValue;

  /// The y value.
  final Object? yValue;

  /// The x a focus strategy measures (`mappedFocusCoordinate`): the x
  /// value's position on its scale when that differs from [x] (a grouped
  /// bar's category centre).
  final double focusX;

  /// The y a focus strategy measures.
  final double focusY;
}

/// TanStack's datum keys of a mark with no `key` option: the first of
/// [candidates] (one value per datum) whose values are all chart keys
/// (text or numbers) and unique within the data's [groups], else each
/// datum's index.
///
/// TanStack tries each datum's `id` and `data.id` first; the playground's
/// rows have neither (`cleanRows`, chart-kit.tsx:24-36; the ScatterChart's
/// `pickRows` and the Sparkline's `{i, v}` rows, charts.tsx), so those
/// candidates are left out.
// @tanstack/charts 1.1.0 dist/mark.js:87-115 (`inferredKeyValues`),
// :125-131 (`normalizeInferredKey`, `isChartKey` at dist/scales.js:75-77)
// and :132-143 (`keysAreUniqueWithinGroups`)
List<Object> tanstackInferredKeys(
  List<Object?> groups,
  List<List<Object?>> candidates,
) {
  for (final candidate in candidates) {
    if (candidate.length != groups.length) continue;
    final normalized = <Object>[];
    for (final value in candidate) {
      if (value is String || value is num) normalized.add(value!);
    }
    if (normalized.length != candidate.length) continue;
    final seen = <(String, String)>{};
    var unique = true;
    for (var index = 0; index < normalized.length; index++) {
      if (!seen.add((
        tanstackValueKey(groups[index]),
        tanstackValueKey(normalized[index]),
      ))) {
        unique = false;
        break;
      }
    }
    if (unique) return normalized;
  }
  return [for (var index = 0; index < groups.length; index++) index];
}

/// TanStack's composite keys of [channels]: at each index, the JSON list of
/// the channels' value keys when every value there is a chart key, else
/// null.
// @tanstack/charts 1.1.0 dist/mark.js:116-124 (`compositeKeyValues`)
List<Object?> tanstackCompositeKeys(List<List<Object?>> channels) {
  final length = channels.isEmpty ? 0 : channels.first.length;
  return List<Object?>.generate(
    length,
    (index) => channels.every((c) => c[index] is String || c[index] is num)
        ? jsonEncode([for (final c in channels) tanstackValueKey(c[index])])
        : null,
  );
}

/// A TanStack point's key: its mark, its group's value key, its datum
/// key's value key.
// @tanstack/charts 1.1.0 dist/line.js:142, dist/area.js:136,
// dist/bar.js:150 and :352, dist/dot.js:71, dist/polar.js:203
String tanstackPointKey(String markId, Object? group, Object datumKey) =>
    '$markId:${tanstackValueKey(group)}:${tanstackValueKey(datumKey)}';

/// What a TanStack focus is kept by across new data: the focused point's
/// [key], with what tells two points of one key apart
/// (`restoreChartFocusPoint`).
///
/// Two of them are equal when their keys are: TanStack keeps a pin as the
/// point's key alone (`pinnedKey = point.key`, dist/renderer.js:609, :647).
@immutable
class TanstackFocusKey {
  /// The key [key] of a point of mark [markId] and series [group] at row
  /// [datum], with its values.
  const TanstackFocusKey({
    required this.key,
    required this.markId,
    required this.datum,
    this.group,
    this.xValue,
    this.yValue,
  });

  /// The key of [point].
  factory TanstackFocusKey.of(TanstackPoint point) => TanstackFocusKey(
    key: point.key,
    markId: point.markId,
    datum: point.datum,
    group: point.group,
    xValue: point.xValue,
    yValue: point.yValue,
  );

  /// The point's key.
  final String key;

  /// Its mark.
  final String markId;

  /// Its series.
  final Object? group;

  /// Its x value.
  final Object? xValue;

  /// Its y value.
  final Object? yValue;

  /// Its row.
  final int datum;

  @override
  bool operator ==(Object other) =>
      other is TanstackFocusKey && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'TanstackFocusKey($key)';
}

/// The point of [points] a focus on [previous] goes back to after a render:
/// the one with its key; of several, while the rows are the same
/// ([sameRows]) the one drawn for its row, else the one of its mark and
/// series with its values, else the one of its mark at its row, else the
/// first; null when no point has the key.
///
/// TanStack's first step takes the point drawn for the very same row object
/// (`point.datum === previous.datum`, :36-41): every playground datum is an
/// object, and a render over the same definition (a new size, loaded fonts)
/// draws the same objects in the same rows. A scene keeps no row objects,
/// so the same rows and the same row index stand for them (the caller
/// knows the rows are the same: `ChartPlot.rowsKey`). Keys are unique in
/// every playground mark but the pie's (its slices are keyed by their
/// labels, which may repeat).
// @tanstack/charts 1.1.0 dist/interaction.js:33-47 (`restoreChartFocusPoint`)
TanstackPoint? tanstackRestoreFocusPoint(
  List<TanstackPoint> points,
  TanstackFocusKey previous, {
  bool sameRows = false,
}) {
  final matches = [
    for (final point in points)
      if (point.key == previous.key) point,
  ];
  if (matches.length < 2) return matches.isEmpty ? null : matches.first;
  if (sameRows) {
    for (final point in matches) {
      if (point.datum == previous.datum) return point;
    }
  }
  for (final point in matches) {
    if (point.markId == previous.markId &&
        point.group == previous.group &&
        _sameChartValue(point.xValue, previous.xValue) &&
        _sameChartValue(point.yValue, previous.yValue)) {
      return point;
    }
  }
  for (final point in matches) {
    if (point.markId == previous.markId && point.datum == previous.datum) {
      return point;
    }
  }
  return matches.first;
}

// JavaScript's `Object.is` for the values of a point: NaN is NaN, 0 is not
// -0. @tanstack/charts 1.1.0 dist/interaction.js:122-124 (`sameChartValue`)
bool _sameChartValue(Object? left, Object? right) {
  if (left is num && right is num) {
    final a = left.toDouble();
    final b = right.toDouble();
    if (a.isNaN || b.isNaN) return a.isNaN && b.isNaN;
    return a == b && a.isNegative == b.isNegative;
  }
  return left == right;
}

/// Whether [left] and [right] are the same focused datum: the same key, or
/// the same row.
// @tanstack/charts 1.1.0 dist/focus-layer.js:251-255 (`sameFocusedPoint`;
// every playground datum is a row object, a reference)
bool tanstackSameFocusedPoint(TanstackPoint left, TanstackPoint right) =>
    identical(left, right) ||
    left.key == right.key ||
    left.datum == right.datum;

/// A TanStack focus strategy (`focus` of a chart definition).
enum TanstackFocus {
  /// `nearest-x`: the point nearest the pointer along x.
  nearestX,

  /// `group-x`: the points at the x nearest the pointer, one per series.
  groupX,

  /// `group-y`: the points at the y nearest the pointer, one per series.
  groupY,
}

double _coordinate(TanstackPoint point, bool x) =>
    x ? point.focusX : point.focusY;

/// The focused points for a pointer at ([x], [y]) under [focus]: the
/// primary point first, then the rest of its group; none when no point is
/// within [maxDistance] along the axis.
// @tanstack/charts 1.1.0 dist/focus.js:11-30 (`axisFocus().resolve`)
List<TanstackPoint> tanstackFocusResolve(
  TanstackFocus focus,
  List<TanstackPoint> points,
  double x,
  double y,
  double maxDistance,
) {
  final axisX = focus != TanstackFocus.groupY;
  final grouped = focus != TanstackFocus.nearestX;
  final target = axisX ? x : y;
  TanstackPoint? nearest;
  var distance = maxDistance;
  for (final point in points) {
    final nextDistance = (_coordinate(point, axisX) - target).abs();
    if (nextDistance >= distance) continue;
    nearest = point;
    distance = nextDistance;
  }
  if (nearest == null) return const [];
  final candidates = _groupPoints(points, nearest, axisX);
  final secondaryTarget = axisX ? y : x;
  double secondary(TanstackPoint point) => axisX ? point.y : point.x;
  var primary = nearest;
  for (final candidate in candidates) {
    if ((secondary(candidate) - secondaryTarget).abs() <
        (secondary(primary) - secondaryTarget).abs()) {
      primary = candidate;
    }
  }
  return grouped
      ? [primary, ...candidates.where((point) => !identical(point, primary))]
      : [primary];
}

/// The focused points when [point] is focused under [focus]: it and, for a
/// group focus, the rest of its group.
// @tanstack/charts 1.1.0 dist/focus.js:31-34 (`axisFocus().group`)
List<TanstackPoint> tanstackFocusGroup(
  TanstackFocus? focus,
  List<TanstackPoint> points,
  TanstackPoint point,
) {
  if (focus == null || focus == TanstackFocus.nearestX) return [point];
  return _groupPoints(points, point, focus != TanstackFocus.groupY);
}

/// The keyboard's order of [points] under [focus]: by x then y (by y then
/// x for `group-y`), one per position for a group focus.
// @tanstack/charts 1.1.0 dist/focus.js:35-46 (`axisFocus().navigation`)
List<TanstackPoint> tanstackFocusNavigation(
  TanstackFocus focus,
  List<TanstackPoint> points,
) {
  final grouped = focus != TanstackFocus.nearestX;
  final axisX = focus != TanstackFocus.groupY;
  final sorted = _stableSort<TanstackPoint>(
    points,
    grouped && !axisX
        ? (l, r) => _compare(l.y - r.y, l.x - r.x)
        : (l, r) => _compare(l.x - r.x, l.y - r.y),
  );
  if (!grouped) return sorted;
  // One per coordinate's value key: every NaN is one (`number:NaN`), and 0
  // is -0.
  final unique = <String, TanstackPoint>{};
  for (final point in sorted) {
    unique.putIfAbsent(
      tanstackValueKey(_coordinate(point, axisX)),
      () => point,
    );
  }
  return [...unique.values];
}

// JavaScript's `first || second` in a sort comparator: NaN is falsy like 0,
// and a NaN result sorts as 0 (ECMAScript, Array.prototype.sort's
// SortCompare).
int _compare(double first, double second) {
  final value = first != 0 && !first.isNaN ? first : second;
  return value < 0
      ? -1
      : value > 0
      ? 1
      : 0;
}

/// [items] sorted by [compare], stably.
// ECMAScript's `Array.prototype.sort` is stable, and the order a comparator
// that is not consistent gives is implementation-defined; no comparator
// here is inconsistent on the points the charts make (on each axis of an
// axis chart the points' coordinates are all finite or all NaN; in the
// Sparkline points sharing an x share a y; pie points are finite, pinned by
// playground_charts_non_finite_test.dart), so a stable sort gives the
// browser's order (RULEBOOK section 0 item 4).
List<T> _stableSort<T>(List<T> items, int Function(T, T) compare) {
  final indexed = [...items.indexed]
    ..sort((l, r) {
      final order = compare(l.$2, r.$2);
      return order != 0 ? order : l.$1 - r.$1;
    });
  return [for (final (_, item) in indexed) item];
}

// @tanstack/charts 1.1.0 dist/focus.js:49-60 (`groupPoints`): the points
// whose coordinate has the same value key (a NaN groups with the NaNs).
List<TanstackPoint> _groupPoints(
  List<TanstackPoint> points,
  TanstackPoint point,
  bool axisX,
) {
  final key = tanstackValueKey(_coordinate(point, axisX));
  final unique = <Object?, TanstackPoint>{point.group: point};
  for (final candidate in points) {
    if (tanstackValueKey(_coordinate(candidate, axisX)) != key) continue;
    unique.putIfAbsent(candidate.group, () => candidate);
  }
  final sorted = _stableSort(
    unique.values.toList(),
    (l, r) => _compare(l.y - r.y, 0),
  );
  return [point, ...sorted.where((candidate) => !identical(candidate, point))];
}

/// How a target answers the distance of a pointer (`interaction.affinity`).
enum TanstackAffinity {
  /// Along x only (a vertical bar, a line).
  x,

  /// Along y only (a horizontal bar).
  y,

  /// In both directions (a dot).
  xy,

  /// Only by containment (a pie slice).
  geometry,
}

/// The shape of a [TanstackTarget].
enum TanstackShape {
  /// A rectangle, its corners rounded by `cornerRadii`.
  rect,

  /// A circle.
  dot,

  /// A closed polygon (an area or a slice outline).
  area,

  /// An open polyline with a stroke.
  polyline,
}

/// A drawn node a pointer can hit (`nearest.js`' targets), in paint order.
class TanstackTarget {
  /// A rectangle [rect] with [cornerRadii] (top left, top right, bottom
  /// right, bottom left).
  TanstackTarget.rect(
    Rect this.rect, {
    required this.affinity,
    this.point,
    this.cornerRadii = const [0, 0, 0, 0],
    this.clip,
  }) : shape = TanstackShape.rect,
       points = const [],
       polygon = const [],
       center = Offset.zero,
       radius = 0,
       strokeWidth = 0;

  /// A circle at [center].
  TanstackTarget.dot(
    this.center,
    this.radius, {
    required this.affinity,
    this.point,
    this.clip,
  }) : shape = TanstackShape.dot,
       rect = null,
       cornerRadii = const [0, 0, 0, 0],
       points = const [],
       polygon = const [],
       strokeWidth = 0;

  /// A closed [polygon] standing for [points].
  TanstackTarget.area(
    this.polygon, {
    required this.affinity,
    this.points = const [],
    this.point,
    this.clip,
  }) : shape = TanstackShape.area,
       rect = null,
       cornerRadii = const [0, 0, 0, 0],
       center = Offset.zero,
       radius = 0,
       strokeWidth = 0;

  /// A polyline through [polygon], [strokeWidth] wide, standing for
  /// [points].
  TanstackTarget.polyline(
    this.polygon, {
    required this.affinity,
    required this.strokeWidth,
    this.points = const [],
    this.clip,
  }) : shape = TanstackShape.polyline,
       point = null,
       rect = null,
       cornerRadii = const [0, 0, 0, 0],
       center = Offset.zero,
       radius = 0;

  /// The shape.
  final TanstackShape shape;

  /// The one point the target stands for (`interaction.point`), or null.
  final TanstackPoint? point;

  /// The points the target stands for (`interaction.points`).
  final List<TanstackPoint> points;

  /// How distance is measured.
  final TanstackAffinity affinity;

  /// A rectangle's box.
  final Rect? rect;

  /// A rectangle's corner radii.
  final List<double> cornerRadii;

  /// A circle's centre.
  final Offset center;

  /// A circle's radius.
  final double radius;

  /// A polygon's or polyline's vertices.
  final List<Offset> polygon;

  /// A polyline's stroke width.
  final double strokeWidth;

  /// The clip of its group (`clip: chart`), or null.
  final Rect? clip;

  /// Its bounds, clipped (`boundsForNode`, `intersectBounds`), or null when
  /// it has none or is clipped away.
  // @tanstack/charts 1.1.0 dist/nearest.js:119-123, 247-277
  Rect? get bounds {
    final local = switch (shape) {
      TanstackShape.rect => rect,
      TanstackShape.dot => Rect.fromCircle(center: center, radius: radius),
      TanstackShape.area => _boundsFromPoints(polygon),
      TanstackShape.polyline => _boundsFromPoints(
        polygon,
      )?.inflate(_strokeRadius),
    };
    if (local == null) return null;
    final c = clip;
    if (c == null) return local;
    return _intersect(local, c);
  }

  double get _strokeRadius => math.max(0, strokeWidth) / 2;

  /// Whether ([x], [y]) is inside the target.
  // @tanstack/charts 1.1.0 dist/nearest.js:159-194 (`containsTarget`)
  bool contains(double x, double y) => switch (shape) {
    TanstackShape.rect => containsRectCornerRadii(rect!, cornerRadii, x, y),
    TanstackShape.dot =>
      (x - center.dx) * (x - center.dx) + (y - center.dy) * (y - center.dy) <=
          math.max(0, radius) * math.max(0, radius),
    TanstackShape.area => _containsPolygon(polygon, x, y),
    TanstackShape.polyline =>
      _squaredDistanceToPolyline(polygon, x, y, closed: false) <=
          _strokeRadius * _strokeRadius,
  };

  /// The squared distance from ([x], [y]) to the target's edge.
  // @tanstack/charts 1.1.0 dist/nearest.js:195-246 (`distanceToTarget`)
  double distance(double x, double y) {
    double distance;
    switch (shape) {
      case TanstackShape.rect:
        distance = squaredDistanceToRectCornerRadii(rect!, cornerRadii, x, y);
      case TanstackShape.dot:
        final dx = x - center.dx;
        final dy = y - center.dy;
        final amount = math.max(
          0,
          math.sqrt(dx * dx + dy * dy) - math.max(0, radius),
        );
        distance = amount * amount.toDouble();
      case TanstackShape.area:
        distance = _squaredDistanceToPolyline(polygon, x, y, closed: true);
      case TanstackShape.polyline:
        final raw = _squaredDistanceToPolyline(polygon, x, y, closed: false);
        final amount = math.max(0, math.sqrt(raw) - _strokeRadius);
        distance = amount * amount.toDouble();
    }
    final c = clip;
    return c == null
        ? distance
        : math.max(distance, _squaredDistanceToBounds(c, x, y));
  }
}

/// The point of [target] nearest ([x], [y]) by its affinity.
// @tanstack/charts 1.1.0 dist/nearest.js:133-154 (`bestInteractionPoint`)
TanstackPoint? _bestInteractionPoint(
  TanstackTarget target,
  double x,
  double y,
) {
  final single = target.point;
  if (single != null) return single;
  TanstackPoint? result;
  var primaryDistance = double.infinity;
  var secondaryDistance = double.infinity;
  for (final point in target.points) {
    final dx = point.x - x;
    final dy = point.y - y;
    final fullDistance = dx * dx + dy * dy;
    final nextPrimary = switch (target.affinity) {
      TanstackAffinity.x => dx * dx,
      TanstackAffinity.y => dy * dy,
      _ => fullDistance,
    };
    if (nextPrimary < primaryDistance ||
        nextPrimary == primaryDistance && fullDistance < secondaryDistance) {
      result = point;
      primaryDistance = nextPrimary;
      secondaryDistance = fullDistance;
    }
  }
  return result;
}

/// The target under ([x], [y]), the last painted first; null when none
/// contains it. The record's point may be null.
// @tanstack/charts 1.1.0 dist/nearest.js:67-84 (`findContainingScenePoint`)
({TanstackPoint? point})? tanstackContainingPoint(
  List<TanstackTarget> targets,
  double x,
  double y,
) {
  for (var index = targets.length; index-- > 0;) {
    final target = targets[index];
    final bounds = target.bounds;
    if (bounds == null) continue;
    if (_containsBounds(bounds, x, y) && target.contains(x, y)) {
      return (point: _bestInteractionPoint(target, x, y));
    }
  }
  return null;
}

/// The point nearest ([x], [y]) within [maxDistance]: the one under the
/// pointer, else the target nearest by its affinity (ties by its shape),
/// else a point no target stands for.
// @tanstack/charts 1.1.0 dist/nearest.js:21-66 (`nearestScenePoint`; with
// no targets, dist/nearest.js:6-20 `nearestPoint`)
TanstackPoint? tanstackNearestPoint(
  List<TanstackTarget> targets,
  List<TanstackPoint> points,
  double x,
  double y,
  double maxDistance,
) {
  final attached = <TanstackPoint>{
    for (final target in targets) ...[?target.point, ...target.points],
  };
  if (targets.isEmpty) {
    TanstackPoint? result;
    var resultDistance = double.infinity;
    for (var index = points.length; index-- > 0;) {
      final point = points[index];
      final dx = point.x - x;
      final dy = point.y - y;
      final distance = dx * dx + dy * dy;
      if (distance <= resultDistance) {
        result = point;
        resultDistance = distance;
      }
    }
    final limit = math.max(0, maxDistance);
    return result != null && resultDistance <= limit * limit ? result : null;
  }
  final contained = tanstackContainingPoint(targets, x, y);
  if (contained != null) return contained.point;
  TanstackPoint? resultPoint;
  TanstackTarget? resultTarget;
  var resultPrimaryDistance = double.infinity;
  var resultGeometryDistance = double.infinity;
  for (final target in targets) {
    final bounds = target.bounds;
    if (bounds == null) continue;
    if (target.affinity == TanstackAffinity.geometry) continue;
    final primaryDistance = switch (target.affinity) {
      TanstackAffinity.x => _squaredAxisDistance(bounds, x, horizontal: true),
      TanstackAffinity.y => _squaredAxisDistance(bounds, y, horizontal: false),
      _ => target.distance(x, y),
    };
    if (primaryDistance > resultPrimaryDistance) continue;
    final geometryDistance =
        target.affinity == TanstackAffinity.x ||
            target.affinity == TanstackAffinity.y
        ? target.distance(x, y)
        : primaryDistance;
    if (primaryDistance < resultPrimaryDistance ||
        primaryDistance == resultPrimaryDistance &&
            geometryDistance < resultGeometryDistance) {
      resultTarget = target;
      resultPoint = null;
      resultPrimaryDistance = primaryDistance;
      resultGeometryDistance = geometryDistance;
    }
  }
  if (resultPrimaryDistance != 0) {
    for (final point in points) {
      if (attached.contains(point)) continue;
      final dx = point.x - x;
      final dy = point.y - y;
      final distance = dx * dx + dy * dy;
      if (distance < resultPrimaryDistance) {
        resultPoint = point;
        resultTarget = null;
        resultPrimaryDistance = distance;
        resultGeometryDistance = distance;
      }
    }
  }
  final limit = math.max(0, maxDistance);
  if (resultPrimaryDistance > limit * limit) return null;
  return resultPoint ??
      (resultTarget == null ? null : _bestInteractionPoint(resultTarget, x, y));
}

/// The points a pointer at ([x], [y]) focuses: under a [focus] strategy,
/// the group of the target under the pointer or of the nearest point
/// along its axis; without one, the nearest point.
// @tanstack/charts 1.1.0 dist/interaction.js:19-29
// (`resolveChartPointerFocus`) and dist/renderer.js:857-873
// (`resolvePointerFocus`)
List<TanstackPoint> tanstackPointerFocus({
  required TanstackFocus? focus,
  required List<TanstackTarget> targets,
  required List<TanstackPoint> points,
  required double x,
  required double y,
  required double maxDistance,
}) {
  if (focus != null) {
    final contained = tanstackContainingPoint(targets, x, y);
    if (contained != null) {
      final point = contained.point;
      return point == null
          ? const []
          : tanstackFocusGroup(focus, points, point);
    }
    return tanstackFocusResolve(focus, points, x, y, maxDistance);
  }
  final point = tanstackNearestPoint(targets, points, x, y, maxDistance);
  return point == null ? const [] : [point];
}

/// A key that moves the keyboard focus of a TanStack chart.
enum TanstackKey {
  /// Arrow right or down.
  next,

  /// Arrow left or up.
  previous,

  /// Home.
  first,

  /// End.
  last,
}

/// The point the [key] moves to from [current] in [points] (in the focus
/// strategy's navigation order): one step, clamped at the ends.
// @tanstack/charts 1.1.0 dist/interaction.js:48-70
// (`chartPointFromNavigationOrder`)
TanstackPoint? tanstackPointFromNavigationOrder(
  List<TanstackPoint> points,
  TanstackPoint? current,
  TanstackKey key,
) {
  final currentIndex = current == null
      ? -1
      : points.indexWhere((point) => _samePointIdentity(point, current));
  final nextIndex = switch (key) {
    TanstackKey.next => math.min(points.length - 1, currentIndex + 1),
    TanstackKey.previous => math.max(
      0,
      currentIndex < 0 ? 0 : currentIndex - 1,
    ),
    TanstackKey.first => 0,
    TanstackKey.last => points.length - 1,
  };
  return nextIndex >= 0 && nextIndex < points.length ? points[nextIndex] : null;
}

/// The point the [key] moves to from [current] in screen order (x, then
/// y, then paint order), for a chart without a focus strategy.
// @tanstack/charts 1.1.0 dist/interaction.js:71-121
// (`chartPointFromSceneOrder`, `navigationExtreme`,
// `compareNavigationPoints`)
TanstackPoint? tanstackPointFromSceneOrder(
  List<TanstackPoint> points,
  TanstackPoint? current,
  TanstackKey key,
) {
  if (points.isEmpty) return null;
  final currentIndex = current == null
      ? -1
      : points.indexWhere((point) => _samePointIdentity(point, current));
  if (current == null ||
      currentIndex < 0 ||
      key == TanstackKey.first ||
      key == TanstackKey.last) {
    return _navigationExtreme(points, maximum: key == TanstackKey.last);
  }
  final direction = key == TanstackKey.next ? 1 : -1;
  TanstackPoint? candidate;
  var candidateIndex = -1;
  for (var index = 0; index < points.length; index += 1) {
    final point = points[index];
    final relative = _compareNavigation(point, index, current, currentIndex);
    if (direction > 0 && relative <= 0 || direction < 0 && relative >= 0) {
      continue;
    }
    if (candidate == null ||
        direction *
                _compareNavigation(point, index, candidate, candidateIndex) <
            0) {
      candidate = point;
      candidateIndex = index;
    }
  }
  return candidate ?? current;
}

TanstackPoint _navigationExtreme(
  List<TanstackPoint> points, {
  required bool maximum,
}) {
  var candidate = points[0];
  var candidateIndex = 0;
  for (var index = 1; index < points.length; index += 1) {
    final point = points[index];
    final comparison = _compareNavigation(
      point,
      index,
      candidate,
      candidateIndex,
    );
    if (maximum && comparison > 0 || !maximum && comparison < 0) {
      candidate = point;
      candidateIndex = index;
    }
  }
  return candidate;
}

double _compareNavigation(
  TanstackPoint left,
  int leftIndex,
  TanstackPoint right,
  int rightIndex,
) {
  final dx = left.x - right.x;
  if (dx != 0 && !dx.isNaN) return dx;
  final dy = left.y - right.y;
  if (dy != 0 && !dy.isNaN) return dy;
  return (leftIndex - rightIndex).toDouble();
}

// @tanstack/charts 1.1.0 dist/interaction.js:30-32 (`sameChartPointIdentity`)
bool _samePointIdentity(TanstackPoint left, TanstackPoint right) =>
    identical(left, right) ||
    left.key == right.key &&
        left.markId == right.markId &&
        left.datum == right.datum;

/// [points] in the tooltip's order: by screen y then x, or by x when they
/// share their y value but not their x value.
// @tanstack/charts 1.1.0 dist/tooltip-model.js:2-16
// (`orderChartTooltipPoints`, no `sort` option)
List<TanstackPoint> tanstackTooltipOrder(List<TanstackPoint> points) {
  if (points.isEmpty) return const [];
  final first = points.first;
  final sharedX = points.every((point) => point.xValue == first.xValue);
  final sharedY = points.every((point) => point.yValue == first.yValue);
  return _stableSort<TanstackPoint>(
    points,
    sharedY && !sharedX
        ? (l, r) => _compare(l.x - r.x, l.y - r.y)
        : (l, r) => _compare(l.y - r.y, l.x - r.x),
  );
}

/// The top left of a [tooltip]-sized tooltip for an [anchor] inside
/// [boundary]: above, below, right or left of it, 10px away, the first
/// that fits (else the one that overflows least), kept 8px inside.
// @tanstack/charts 1.1.0 dist/tooltip-placement.js:7-70
// (`resolveChartTooltipPlacement` with the default placements and offset)
Offset tanstackTooltipPlacement(Offset anchor, Size tooltip, Rect boundary) {
  const edge = 8.0;
  const gap = 10.0;
  final minimumLeft = boundary.left + edge;
  final minimumTop = boundary.top + edge;
  final maxLeft = math.max(minimumLeft, boundary.right - edge - tooltip.width);
  final maxTop = math.max(minimumTop, boundary.bottom - edge - tooltip.height);
  // top, bottom, right, left (dist/tooltip-placement.js:1-6).
  const directions = [(0, -1), (0, 1), (1, 0), (-1, 0)];
  final candidates = [
    for (final (xDirection, yDirection) in directions)
      Offset(
        anchor.dx + (xDirection - 1) * tooltip.width / 2 + xDirection * gap,
        anchor.dy + (yDirection - 1) * tooltip.height / 2 + yDirection * gap,
      ),
  ];
  double overflow(Offset position) =>
      math.max(0, boundary.left + edge - position.dx) +
      math.max(0, position.dx + tooltip.width + edge - boundary.right) +
      math.max(0, boundary.top + edge - position.dy) +
      math.max(0, position.dy + tooltip.height + edge - boundary.bottom);
  var selected = candidates[0];
  var selectedOverflow = overflow(selected);
  for (final candidate in candidates) {
    final candidateOverflow = overflow(candidate);
    if (candidateOverflow == 0) {
      selected = candidate;
      break;
    }
    if (candidateOverflow < selectedOverflow) {
      selected = candidate;
      selectedOverflow = candidateOverflow;
    }
  }
  return Offset(
    math.max(minimumLeft, math.min(maxLeft, selected.dx)),
    math.max(minimumTop, math.min(maxTop, selected.dy)),
  );
}

/// TanStack's corner radii of a rectangle, scaled down together where two
/// on one edge would overlap (as CSS does): top left, top right, bottom
/// right, bottom left.
// @tanstack/charts 1.1.0 dist/renderer-rect.js:1-29
// (`resolveRectCornerRadii`)
List<double> tanstackCornerRadii(
  List<double> radii,
  double width,
  double height,
) {
  double valid(double value) => value.isFinite && value > 0 ? value : 0;
  final resolved = [for (final r in radii) valid(r)];
  final w = width.isFinite ? width.abs() : 0.0;
  final h = height.isFinite ? height.abs() : 0.0;
  double edgeScale(double available, double requested) =>
      requested == 0 ? 1 : available / requested;
  final scale = [
    1.0,
    edgeScale(w, resolved[0] + resolved[1]),
    edgeScale(w, resolved[3] + resolved[2]),
    edgeScale(h, resolved[0] + resolved[3]),
    edgeScale(h, resolved[1] + resolved[2]),
  ].reduce(math.min);
  return scale == 1 ? resolved : [for (final r in resolved) r * scale];
}

/// Whether ([x], [y]) is inside [rect] with corner [radii].
// @tanstack/charts 1.1.0 dist/rect-radius-internal.js:4-49
// (`containsRectCornerRadii`)
bool containsRectCornerRadii(
  Rect rect,
  List<double> radii,
  double x,
  double y,
) {
  final left = rect.left;
  final top = rect.top;
  final right = rect.right;
  final bottom = rect.bottom;
  if (!(x >= left && x <= right && y >= top && y <= bottom)) return false;
  final r = tanstackCornerRadii(radii, rect.width, rect.height);
  bool inside(double cx, double cy, double radius) {
    final dx = x - cx;
    final dy = y - cy;
    return dx * dx + dy * dy <= radius * radius;
  }

  if (x < left + r[0] && y < top + r[0]) {
    return inside(left + r[0], top + r[0], r[0]);
  }
  if (x > right - r[1] && y < top + r[1]) {
    return inside(right - r[1], top + r[1], r[1]);
  }
  if (x > right - r[2] && y > bottom - r[2]) {
    return inside(right - r[2], bottom - r[2], r[2]);
  }
  if (x < left + r[3] && y > bottom - r[3]) {
    return inside(left + r[3], bottom - r[3], r[3]);
  }
  return true;
}

/// The squared distance from ([x], [y]) to [rect] with corner [radii].
// @tanstack/charts 1.1.0 dist/rect-radius-internal.js:50-89
// (`squaredDistanceToRectCornerRadii`)
double squaredDistanceToRectCornerRadii(
  Rect rect,
  List<double> radii,
  double x,
  double y,
) {
  if (containsRectCornerRadii(rect, radii, x, y)) return 0;
  final r = tanstackCornerRadii(radii, rect.width, rect.height);
  final left = rect.left;
  final top = rect.top;
  final right = rect.right;
  final bottom = rect.bottom;
  const fullTurn = math.pi * 2;
  return [
    _segmentDistance(left + r[0], top, right - r[1], top, x, y),
    _segmentDistance(right, top + r[1], right, bottom - r[2], x, y),
    _segmentDistance(right - r[2], bottom, left + r[3], bottom, x, y),
    _segmentDistance(left, bottom - r[3], left, top + r[0], x, y),
    _arcDistance(x, y, left + r[0], top + r[0], r[0], math.pi, math.pi * 1.5),
    _arcDistance(x, y, right - r[1], top + r[1], r[1], math.pi * 1.5, fullTurn),
    _arcDistance(x, y, right - r[2], bottom - r[2], r[2], 0, math.pi * .5),
    _arcDistance(x, y, left + r[3], bottom - r[3], r[3], math.pi * .5, math.pi),
  ].reduce(math.min);
}

double _squaredDistance(double x1, double y1, double x2, double y2) =>
    (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);

// @tanstack/charts 1.1.0 dist/rect-radius-internal.js:150-172
// (`squaredDistanceToArc`)
double _arcDistance(
  double x,
  double y,
  double centerX,
  double centerY,
  double radius,
  double startAngle,
  double endAngle,
) {
  if (radius == 0) return _squaredDistance(x, y, centerX, centerY);
  var angle = math.atan2(y - centerY, x - centerX);
  if (angle < 0) angle += math.pi * 2;
  if (angle >= startAngle && angle <= endAngle) {
    final centerDistance = math.sqrt(_squaredDistance(x, y, centerX, centerY));
    return (centerDistance - radius) * (centerDistance - radius);
  }
  return math.min(
    _squaredDistance(
      x,
      y,
      centerX + math.cos(startAngle) * radius,
      centerY + math.sin(startAngle) * radius,
    ),
    _squaredDistance(
      x,
      y,
      centerX + math.cos(endAngle) * radius,
      centerY + math.sin(endAngle) * radius,
    ),
  );
}

// @tanstack/charts 1.1.0 dist/rect-radius-internal.js:173-183
// (`squaredDistanceToSegment`)
double _segmentDistance(
  double x1,
  double y1,
  double x2,
  double y2,
  double x,
  double y,
) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) return _squaredDistance(x, y, x1, y1);
  final amount = math.max(
    0,
    math.min(1, ((x - x1) * dx + (y - y1) * dy) / lengthSquared),
  );
  return _squaredDistance(x, y, x1 + amount * dx, y1 + amount * dy);
}

// @tanstack/charts 1.1.0 dist/nearest.js:304-314 (`containsPolygon`)
bool _containsPolygon(List<Offset> points, double x, double y) {
  var inside = false;
  for (
    var index = 0, previous = points.length - 1;
    index < points.length;
    previous = index++
  ) {
    final current = points[index];
    final prior = points[previous];
    if ((current.dy > y) != (prior.dy > y) &&
        x <
            (prior.dx - current.dx) *
                    (y - current.dy) /
                    (prior.dy - current.dy) +
                current.dx) {
      inside = !inside;
    }
  }
  return inside;
}

// @tanstack/charts 1.1.0 dist/nearest.js:330-347
// (`squaredDistanceToPolyline`)
double _squaredDistanceToPolyline(
  List<Offset> points,
  double x,
  double y, {
  required bool closed,
}) {
  if (points.isEmpty) return double.infinity;
  if (points.length == 1) {
    final point = points[0];
    return (point.dx - x) * (point.dx - x) + (point.dy - y) * (point.dy - y);
  }
  var distance = double.infinity;
  final segmentCount = closed ? points.length : math.max(0, points.length - 1);
  for (var index = 0; index < segmentCount; index += 1) {
    final start = points[index];
    final end = points[(index + 1) % points.length];
    distance = math.min(
      distance,
      _squaredDistanceToSegment(start.dx, start.dy, end.dx, end.dy, x, y),
    );
  }
  return distance;
}

// @tanstack/charts 1.1.0 dist/nearest.js:348-356
double _squaredDistanceToSegment(
  double x1,
  double y1,
  double x2,
  double y2,
  double x,
  double y,
) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final length = dx * dx + dy * dy;
  final amount = length != 0
      ? math.max(0, math.min(1, ((x - x1) * dx + (y - y1) * dy) / length))
      : 0;
  final offsetX = x - (x1 + amount * dx);
  final offsetY = y - (y1 + amount * dy);
  return offsetX * offsetX + offsetY * offsetY;
}

// @tanstack/charts 1.1.0 dist/nearest.js:357-370 (`boundsFromPoints`)
Rect? _boundsFromPoints(List<Offset> points) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final point in points) {
    if (!point.dx.isFinite || !point.dy.isFinite) continue;
    minX = math.min(minX, point.dx);
    minY = math.min(minY, point.dy);
    maxX = math.max(maxX, point.dx);
    maxY = math.max(maxY, point.dy);
  }
  return minX.isFinite ? Rect.fromLTRB(minX, minY, maxX, maxY) : null;
}

// @tanstack/charts 1.1.0 dist/nearest.js:394-402 (`intersectBounds`)
Rect? _intersect(Rect a, Rect b) {
  final x = math.max(a.left, b.left);
  final y = math.max(a.top, b.top);
  final rightEdge = math.min(a.right, b.right);
  final bottomEdge = math.min(a.bottom, b.bottom);
  return rightEdge < x || bottomEdge < y
      ? null
      : Rect.fromLTRB(x, y, rightEdge, bottomEdge);
}

// @tanstack/charts 1.1.0 dist/nearest.js:403-405 (`containsBounds`)
bool _containsBounds(Rect bounds, double x, double y) =>
    x >= bounds.left &&
    x <= bounds.right &&
    y >= bounds.top &&
    y <= bounds.bottom;

// @tanstack/charts 1.1.0 dist/nearest.js:406-411 (`squaredAxisDistance`)
double _squaredAxisDistance(
  Rect bounds,
  double value, {
  required bool horizontal,
}) {
  final start = horizontal ? bounds.left : bounds.top;
  final size = horizontal ? bounds.width : bounds.height;
  final distance = value < start
      ? start - value
      : value > start + size
      ? value - start - size
      : 0.0;
  return distance * distance;
}

// @tanstack/charts 1.1.0 dist/nearest.js:412-417 (`squaredDistanceToBounds`)
double _squaredDistanceToBounds(Rect bounds, double x, double y) {
  final dx = x < bounds.left
      ? bounds.left - x
      : x > bounds.right
      ? x - bounds.right
      : 0.0;
  final dy = y < bounds.top
      ? bounds.top - y
      : y > bounds.bottom
      ? y - bounds.bottom
      : 0.0;
  return dx * dx + dy * dy;
}

// PORT STATUS: confidence=high todos=0 upstream=@tanstack/charts@1.1.0
