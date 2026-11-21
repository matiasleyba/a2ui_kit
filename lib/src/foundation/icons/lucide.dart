// Lucide icons as CopilotKit draws them: lucide-react's own icon nodes, from
// lucide-react 0.525.0 (react-core's renderers) and lucide-react 1.57.0 (the
// A2UI playground's own renderers), generated into `lucide_icons.g.dart` by
// `tool/generate.dart`, and stroked on the 24px grid as lucide-react's
// `<svg>` is (0.525.0's `dist/esm/defaultAttributes.js:13-17`: no fill, a
// round-capped, round-joined stroke 2 wide, and `Icon.js:16-30`: `color` is
// the stroke, `strokeWidth` scales with the icon; 1.57.0's
// `shared/src/build/defaultAttributes.mjs` and `buildLucideIconNode.mjs`, the
// same). The lookup by name
// ports react-core's `standard/media.tsx` (`kebabToPascal`, `A2UI_ICONS`,
// `LucideIcon`); each element's path follows Chromium 159.0.8154.13's
// `AsPath` (`core/svg/svg_{circle,ellipse,rect,line,poly,polygon,
// polyline}_element.cc`).

import 'dart:math' as math;

import 'package:a2ui_kit/src/foundation/svg/svg_path.dart';
import 'package:flutter/widgets.dart';

part 'lucide_icons.g.dart';

/// The icon names of the A2UI basic catalog and the Lucide icon of each, as
/// CopilotKit maps them (`A2UI_ICONS` in react-core's `media.tsx:332-392`).
const Map<String, String> a2uiIconNames = {
  'accountCircle': 'circle-user',
  'add': 'plus',
  'arrowBack': 'arrow-left',
  'arrowForward': 'arrow-right',
  'attachFile': 'paperclip',
  'calendarToday': 'calendar',
  'call': 'phone',
  'camera': 'camera',
  'check': 'check',
  'close': 'x',
  'delete': 'trash-2',
  'download': 'download',
  'edit': 'pencil',
  'event': 'calendar-days',
  'error': 'circle-alert',
  'fastForward': 'fast-forward',
  'favorite': 'heart',
  'favoriteOff': 'heart-off',
  'folder': 'folder',
  'help': 'circle-question-mark',
  'home': 'house',
  'info': 'info',
  'locationOn': 'map-pin',
  'lock': 'lock',
  'lockOpen': 'lock-open',
  'mail': 'mail',
  'menu': 'menu',
  'moreVert': 'ellipsis-vertical',
  'moreHoriz': 'ellipsis',
  'notificationsOff': 'bell-off',
  'notifications': 'bell',
  'pause': 'pause',
  'payment': 'credit-card',
  'person': 'user',
  'phone': 'phone',
  'photo': 'image',
  'play': 'play',
  'print': 'printer',
  'refresh': 'refresh-cw',
  'rewind': 'rewind',
  'search': 'search',
  'send': 'send',
  'settings': 'settings',
  'share': 'share-2',
  'shoppingCart': 'shopping-cart',
  'skipNext': 'skip-forward',
  'skipPrevious': 'skip-back',
  'star': 'star',
  'starHalf': 'star-half',
  'starOff': 'star-off',
  'stop': 'square',
  'upload': 'upload',
  'visibility': 'eye',
  'visibilityOff': 'eye-off',
  'volumeDown': 'volume-1',
  'volumeMute': 'volume-x',
  'volumeOff': 'volume-off',
  'volumeUp': 'volume-2',
  'warning': 'triangle-alert',
};

/// A lucide-react release CopilotKit draws icons with.
///
/// Each renderer draws the release its own package resolves, whatever the
/// look: react-core's standard components, the Icon among them, draw
/// [reactCore] in the playground too, since the playground installs the
/// published `@copilotkit/react-core@1.85.0`, whose lucide-react is 0.525.0
/// (the playground's `pnpm-lock.yaml:6058`).
enum LucideRelease {
  /// lucide-react 0.525.0: react-core's (`packages/react-core/package.json`
  /// asks `^0.525.0`; the repo's `pnpm-lock.yaml:3245-3247` resolves it).
  /// The standard components draw it.
  reactCore(_reactCoreVersion, _reactCoreIcons, _reactCoreAliases),

  /// lucide-react 1.57.0: the A2UI playground's
  /// (`examples/showcases/a2ui-playground/package.json:38`, its
  /// `pnpm-lock.yaml:62-64`). The playground's own components draw it.
  playground(_playgroundVersion, _playgroundIcons, _playgroundAliases);

  const LucideRelease(this.version, this._icons, this._aliases);

  /// The npm version.
  final String version;

  final Map<String, int> _icons;

  final Map<String, String> _aliases;

  /// The names of the release's `icons` map (`import { icons } from
  /// "lucide-react"`), the map CopilotKit looks names up in.
  Iterable<String> get iconNames => _icons.keys;

  /// The other names the release exports an icon by (`AlertTriangle` for
  /// `TriangleAlert`), each with its [iconNames] name. A renderer that
  /// imports an icon by such a name draws it ([lucideImport]); a lookup by
  /// name ([lucideIcon]) does not reach them, as `icons` has none.
  Map<String, String> get aliases => _aliases;

  LucideIconNode? _node(String name) {
    final index = _icons[name];
    return index == null ? null : LucideIconNode._(name, this, _nodes[index]);
  }
}

/// The name CopilotKit looks a Lucide icon up by: each `-`, `_` or space
/// separated part capitalised (`kebabToPascal`, `media.tsx:64-70`:
/// "arrow-down-0-1" gives "ArrowDown01", "arrowRight" gives "ArrowRight").
String lucidePascalName(String name) => name
    .split(RegExp(r'[-_\s]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join();

/// The icon [release] draws for [name], as CopilotKit's `LucideIcon` looks
/// it up (`media.tsx:134-136`): `icons[kebabToPascal(name)] ?? icons[name]`
/// in the release's `icons` map. The name is kebab-case (`arrow-right`),
/// PascalCase (`ArrowRight`) or anything `kebabToPascal` reads the same; with
/// [a2uiNames] an A2UI basic catalog name (`arrowBack`) maps first
/// (`lucideNameOf`, `media.tsx:395-397`). Null for an empty or unknown name,
/// which draws nothing, as in CopilotKit (`media.tsx:136`).
///
/// The playground's `iconFor` (`renderers/data.tsx:184-193`) reads names the
/// same way in [LucideRelease.playground], without the `?? icons[name]`,
/// which never finds what the first lookup missed: every `icons` name is its
/// own `kebabToPascal`.
LucideIconNode? lucideIcon(
  String? name, {
  required LucideRelease release,
  bool a2uiNames = false,
}) {
  if (name == null || name.isEmpty) return null;
  final lucideName = a2uiNames ? (a2uiIconNames[name] ?? name) : name;
  return release._node(lucidePascalName(lucideName)) ??
      release._node(lucideName);
}

/// The icon a renderer imports by [name] from [release]
/// (`import { AlertTriangle } from "lucide-react"`): an `icons` name or one
/// of the release's [LucideRelease.aliases].
///
/// Throws [ArgumentError] when the release exports no icon by [name]: the
/// import would not compile.
LucideIconNode lucideImport(String name, LucideRelease release) =>
    release._node(name) ??
    release._node(release._aliases[name] ?? '') ??
    (throw ArgumentError.value(
      name,
      'name',
      'lucide-react ${release.version} exports no icon by this name',
    ));

/// One Lucide icon: the SVG elements of its node in one release, on
/// lucide-react's 24px grid (`viewBox="0 0 24 24"`).
@immutable
class LucideIconNode {
  const LucideIconNode._(this.name, this.release, this.elements);

  /// The icon's name in [release]'s `icons` map (`ArrowRight`).
  final String name;

  /// The release the node is from.
  final LucideRelease release;

  /// The elements, in the node's order: the order they are painted in.
  final List<LucideElement> elements;

  /// Two nodes are equal when they have the same name and draw the same
  /// elements, from whichever release.
  @override
  bool operator ==(Object other) =>
      other is LucideIconNode &&
      other.name == name &&
      identical(other.elements, elements);

  @override
  int get hashCode => Object.hash(name, identityHashCode(elements));

  @override
  String toString() => 'LucideIconNode($name, lucide-react ${release.version})';
}

/// One element of a Lucide icon node, on the 24px grid, painted as Chromium
/// builds its shape (`AsPath`).
@immutable
sealed class LucideElement {
  const LucideElement({this.filled = false});

  /// Whether it is filled with `currentColor` (`fill="currentColor"`, on some
  /// dots); every other element takes the `<svg>`'s `fill="none"`.
  final bool filled;

  /// Paints it on [canvas], in grid units, with [paint].
  void paint(Canvas canvas, Paint paint);
}

/// A `<path>`: its data parsed by `path_parsing` (a port of Chromium's SVG
/// path parser), once.
final class LucidePath extends LucideElement {
  /// A path of SVG path data [d].
  const LucidePath(this.d, {super.filled});

  /// The path data.
  final String d;

  static final Expando<Path> _paths = Expando('LucidePath');

  /// The path [d] draws; empty when it cannot be read. It is built once and
  /// shared: draw it, don't change it.
  Path get path => _paths[this] ??= svgPathOf(d);

  @override
  void paint(Canvas canvas, Paint paint) => canvas.drawPath(path, paint);

  @override
  bool operator ==(Object other) =>
      other is LucidePath && other.d == d && other.filled == filled;

  @override
  int get hashCode => Object.hash(d, filled);

  @override
  String toString() => 'LucidePath($d)';
}

/// A `<circle>`: an ellipse of radius [r] round ([cx], [cy])
/// (`svg_circle_element.cc:70-76`; the table holds no `r` of 0 or less).
final class LucideCircle extends LucideElement {
  /// A circle.
  const LucideCircle(this.cx, this.cy, this.r, {super.filled});

  /// The centre's x.
  final double cx;

  /// The centre's y.
  final double cy;

  /// The radius.
  final double r;

  @override
  void paint(Canvas canvas, Paint paint) =>
      canvas.drawCircle(Offset(cx, cy), r, paint);

  @override
  bool operator ==(Object other) =>
      other is LucideCircle &&
      other.cx == cx &&
      other.cy == cy &&
      other.r == r &&
      other.filled == filled;

  @override
  int get hashCode => Object.hash(cx, cy, r, filled);

  @override
  String toString() => 'LucideCircle($cx, $cy, $r)';
}

/// An `<ellipse>` of radii [rx] and [ry] round ([cx], [cy])
/// (`svg_ellipse_element.cc:92-115`; the table holds both radii, above 0).
final class LucideEllipse extends LucideElement {
  /// An ellipse.
  const LucideEllipse(this.cx, this.cy, this.rx, this.ry, {super.filled});

  /// The centre's x.
  final double cx;

  /// The centre's y.
  final double cy;

  /// The horizontal radius.
  final double rx;

  /// The vertical radius.
  final double ry;

  @override
  void paint(Canvas canvas, Paint paint) => canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, cy), width: 2 * rx, height: 2 * ry),
    paint,
  );

  @override
  bool operator ==(Object other) =>
      other is LucideEllipse &&
      other.cx == cx &&
      other.cy == cy &&
      other.rx == rx &&
      other.ry == ry &&
      other.filled == filled;

  @override
  int get hashCode => Object.hash(cx, cy, rx, ry, filled);

  @override
  String toString() => 'LucideEllipse($cx, $cy, $rx, $ry)';
}

/// A `<rect>`, its corners rounded by [rx] and [ry] (`auto` when null) as
/// `svg_rect_element.cc:95-115` rounds them: an `auto` radius takes the
/// other's value (both `auto`: square corners), and each is at most half
/// the side it runs along. The table holds no size or radius of 0 or less.
final class LucideRect extends LucideElement {
  /// A rectangle.
  const LucideRect(
    this.x,
    this.y,
    this.width,
    this.height, {
    this.rx,
    this.ry,
    super.filled,
  });

  /// The left edge.
  final double x;

  /// The top edge.
  final double y;

  /// The width.
  final double width;

  /// The height.
  final double height;

  /// The corners' horizontal radius; `auto` when null.
  final double? rx;

  /// The corners' vertical radius; `auto` when null.
  final double? ry;

  /// The corner radii drawn: `(rx, ry)` after the `auto` rule and the clamp
  /// to half the width and height.
  (double, double) get radii {
    // `if (style.Rx().IsAuto() ...) radii.set_x(std::max(0.f, radii.y()))`,
    // with `auto` read as 0 in the max; then `if (style.Ry().IsAuto() ...)
    // radii.set_y(radii.x())`.
    final x = rx ?? math.max<double>(0, ry ?? 0);
    final y = ry ?? x;
    // `radii.SetToMin(gfx::ScaleVector2d(size, 0.5))`.
    return (math.min(x, width / 2), math.min(y, height / 2));
  }

  @override
  void paint(Canvas canvas, Paint paint) {
    final rect = Rect.fromLTWH(x, y, width, height);
    final (radiusX, radiusY) = radii;
    if (radiusX > 0 || radiusY > 0) {
      canvas.drawRRect(RRect.fromRectXY(rect, radiusX, radiusY), paint);
    } else {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LucideRect &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height &&
      other.rx == rx &&
      other.ry == ry &&
      other.filled == filled;

  @override
  int get hashCode => Object.hash(x, y, width, height, rx, ry, filled);

  @override
  String toString() => 'LucideRect($x, $y, $width, $height, $rx, $ry)';
}

/// A `<line>` from ([x1], [y1]) to ([x2], [y2]) (`svg_line_element.cc:67-79`:
/// a move, then a line).
final class LucideLine extends LucideElement {
  /// A line.
  const LucideLine(this.x1, this.y1, this.x2, this.y2, {super.filled});

  /// The start's x.
  final double x1;

  /// The start's y.
  final double y1;

  /// The end's x.
  final double x2;

  /// The end's y.
  final double y2;

  @override
  void paint(Canvas canvas, Paint paint) =>
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);

  @override
  bool operator ==(Object other) =>
      other is LucideLine &&
      other.x1 == x1 &&
      other.y1 == y1 &&
      other.x2 == x2 &&
      other.y2 == y2 &&
      other.filled == filled;

  @override
  int get hashCode => Object.hash(x1, y1, x2, y2, filled);

  @override
  String toString() => 'LucideLine($x1, $y1, $x2, $y2)';
}

/// A `<polyline>`: a move to its first point, then a line to each next one
/// (`svg_poly_element.cc:51-63`, `svg_polyline_element.cc:31-33`).
final class LucidePolyline extends LucideElement {
  /// A polyline through [points] (x, y, x, y, …).
  const LucidePolyline(this.points, {super.filled});

  /// The points' coordinates, x then y; an even number of them.
  final List<double> points;

  static final Expando<Path> _paths = Expando('LucidePolyline');

  /// The path drawn, built once and shared: draw it, don't change it.
  Path get path => _paths[this] ??= _polyPath(points, close: false);

  @override
  void paint(Canvas canvas, Paint paint) => canvas.drawPath(path, paint);

  @override
  bool operator ==(Object other) =>
      other is LucidePolyline &&
      _sameList(other.points, points) &&
      other.filled == filled;

  @override
  int get hashCode => Object.hash(Object.hashAll(points), filled);

  @override
  String toString() => 'LucidePolyline($points)';
}

/// A `<polygon>`: a polyline, closed (`svg_polygon_element.cc:31-33`).
final class LucidePolygon extends LucideElement {
  /// A polygon through [points] (x, y, x, y, …).
  const LucidePolygon(this.points, {super.filled});

  /// The points' coordinates, x then y; an even number of them.
  final List<double> points;

  static final Expando<Path> _paths = Expando('LucidePolygon');

  /// The path drawn, built once and shared: draw it, don't change it.
  Path get path => _paths[this] ??= _polyPath(points, close: true);

  @override
  void paint(Canvas canvas, Paint paint) => canvas.drawPath(path, paint);

  @override
  bool operator ==(Object other) =>
      other is LucidePolygon &&
      _sameList(other.points, points) &&
      other.filled == filled;

  @override
  int get hashCode => Object.hash(Object.hashAll(points), filled);

  @override
  String toString() => 'LucidePolygon($points)';
}

bool _sameList(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Path _polyPath(List<double> points, {required bool close}) {
  final path = Path();
  if (points.length < 2) return path;
  path.moveTo(points[0], points[1]);
  for (var i = 2; i + 1 < points.length; i += 2) {
    path.lineTo(points[i], points[i + 1]);
  }
  if (close) path.close();
  return path;
}

/// A Lucide icon [size] pixels square, stroked as lucide-react's `<svg>`
/// strokes it (`fill="none"`, `stroke-linecap` and `stroke-linejoin`
/// `round`, on a `0 0 24 24` view box): hidden from screen readers unless it
/// has a [label].
class LucideGlyph extends StatelessWidget {
  /// The icon [icon].
  const LucideGlyph(
    this.icon, {
    this.size = 20,
    this.color,
    this.stroke,
    this.strokeWidth = 2,
    this.baseline,
    this.label,
    this.description,
    super.key,
  });

  /// The icon.
  final LucideIconNode icon;

  /// The width and height in pixels.
  final double size;

  /// The CSS `color` the icon is in, which `currentColor` reads: the text
  /// colour around it when null. The elements that are filled take it.
  final Color? color;

  /// The `stroke` (lucide-react's `color` prop): [color] when null, as
  /// lucide-react's default `currentColor` is.
  final Color? stroke;

  /// The stroke width on the 24px grid (lucide-react's `strokeWidth`, default
  /// 2): it scales with the icon, as it is not `absoluteStrokeWidth`.
  final double strokeWidth;

  /// The distance from the top to the icon's baseline in pixels; its bottom
  /// edge when null, so a baseline alignment puts the bottom on the line.
  final double? baseline;

  /// What the icon means, for screen readers.
  final String? label;

  /// A longer description for screen readers.
  final String? description;

  @override
  Widget build(BuildContext context) {
    // CSS's initial `color` is black (`canvastext` on a light page).
    final current =
        color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xff000000);
    final glyph = _LucideGlyphBox(
      elements: icon.elements,
      size: size,
      color: current,
      stroke: stroke ?? current,
      strokeWidth: strokeWidth,
      baseline: baseline,
    );
    if (label == null) return ExcludeSemantics(child: glyph);
    return Semantics(
      label: label,
      hint: description,
      image: true,
      container: true,
      child: ExcludeSemantics(child: glyph),
    );
  }
}

class _LucideGlyphBox extends LeafRenderObjectWidget {
  const _LucideGlyphBox({
    required this.elements,
    required this.size,
    required this.color,
    required this.stroke,
    required this.strokeWidth,
    required this.baseline,
  });

  final List<LucideElement> elements;
  final double size;
  final Color color;
  final Color stroke;
  final double strokeWidth;
  final double? baseline;

  @override
  RenderLucideGlyph createRenderObject(BuildContext context) =>
      RenderLucideGlyph(
        elements: elements,
        size: size,
        color: color,
        stroke: stroke,
        strokeWidth: strokeWidth,
        baseline: baseline,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLucideGlyph renderObject,
  ) {
    renderObject
      ..elements = elements
      ..glyphSize = size
      ..color = color
      ..stroke = stroke
      ..strokeWidth = strokeWidth
      ..baseline = baseline;
  }
}

/// The render object of [LucideGlyph]: the node's elements on a 24px view
/// box scaled to its size.
class RenderLucideGlyph extends RenderBox {
  /// Draws [elements] [size] pixels square.
  RenderLucideGlyph({
    required List<LucideElement> elements,
    required double size,
    required Color color,
    required Color stroke,
    required double strokeWidth,
    double? baseline,
  }) : _elements = elements,
       _size = size,
       _color = color,
       _stroke = stroke,
       _strokeWidth = strokeWidth,
       _baseline = baseline;

  List<LucideElement> _elements;

  /// The elements, painted in order.
  List<LucideElement> get elements => _elements;
  set elements(List<LucideElement> value) {
    if (identical(value, _elements)) return;
    _elements = value;
    markNeedsPaint();
  }

  double _size;

  /// The width and height in pixels.
  double get glyphSize => _size;
  set glyphSize(double value) {
    if (value == _size) return;
    _size = value;
    markNeedsLayout();
  }

  Color _color;

  /// The fill of the filled elements (`currentColor`).
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  Color _stroke;

  /// The stroke.
  Color get stroke => _stroke;
  set stroke(Color value) {
    if (value == _stroke) return;
    _stroke = value;
    markNeedsPaint();
  }

  double _strokeWidth;

  /// The stroke width on the 24px grid.
  double get strokeWidth => _strokeWidth;
  set strokeWidth(double value) {
    if (value == _strokeWidth) return;
    _strokeWidth = value;
    markNeedsPaint();
  }

  double? _baseline;

  /// The distance from the top to the baseline; the bottom edge when null.
  double? get baseline => _baseline;
  set baseline(double? value) {
    if (value == _baseline) return;
    _baseline = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _size;

  @override
  double computeMaxIntrinsicWidth(double height) => _size;

  @override
  double computeMinIntrinsicHeight(double width) => _size;

  @override
  double computeMaxIntrinsicHeight(double width) => _size;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(Size.square(_size));

  // A block `<svg>` has no baseline of its own; its bottom edge stands in, as
  // Flutter's fallback for a box without one would. (A null here makes a
  // proxy parent's dry baseline throw in debug: `RenderProxyBoxMixin`'s
  // falls back to `RenderBox.computeDryBaseline`, which asserts.)
  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => _baseline ?? computeDryLayout(constraints).height;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _baseline ?? size.height;

  @override
  void performLayout() => size = computeDryLayout(constraints);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    // `preserveAspectRatio`'s default, `xMidYMid meet`: the view box scaled
    // to fit and centred.
    final scale = math.min(size.width, size.height) / 24;
    final canvas = context.canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      // An `<svg>` in a page clips what it draws to its box: Chromium's
      // `svg:not(:root) { overflow: hidden }` with `overflow-clip-margin:
      // content-box` (`core/css/svg.css:47-53`).
      ..clipRect(Offset.zero & size)
      ..translate((size.width - 24 * scale) / 2, (size.height - 24 * scale) / 2)
      ..scale(scale);
    final fill = Paint()..color = _color;
    // A stroke width of 0 paints no stroke (SVG); Flutter's 0 is a hairline.
    final stroke = _strokeWidth > 0
        ? (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _strokeWidth
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = _stroke)
        : null;
    // Each element is filled, then stroked, before the next one (SVG's
    // painting order).
    for (final element in _elements) {
      if (element.filled) element.paint(canvas, fill);
      if (stroke != null) element.paint(canvas, stroke);
    }
    canvas.restore();
  }
}

/// An icon of one SVG path on a 24px grid, filled in [color]: the Icon
/// component's `{"svgPath"}` name.
class SvgPathGlyph extends LeafRenderObjectWidget {
  /// Draws [pathData] [size] pixels square.
  const SvgPathGlyph({
    required this.pathData,
    required this.size,
    required this.color,
    this.baseline,
    super.key,
  });

  /// The SVG path data (`d`).
  final String pathData;

  /// The width and height in pixels.
  final double size;

  /// The fill.
  final Color color;

  /// The distance from the top to the baseline in pixels; the bottom edge
  /// when null.
  final double? baseline;

  @override
  RenderSvgPathGlyph createRenderObject(BuildContext context) =>
      RenderSvgPathGlyph(
        pathData: pathData,
        size: size,
        color: color,
        baseline: baseline,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSvgPathGlyph renderObject,
  ) {
    renderObject
      ..pathData = pathData
      ..glyphSize = size
      ..color = color
      ..baseline = baseline;
  }
}

/// The render object of [SvgPathGlyph].
class RenderSvgPathGlyph extends RenderBox {
  /// Draws [pathData] [size] pixels square in [color].
  RenderSvgPathGlyph({
    required String pathData,
    required double size,
    required Color color,
    double? baseline,
  }) : _pathData = pathData,
       _size = size,
       _color = color,
       _baseline = baseline;

  String _pathData;
  Path? _path;

  /// The SVG path data.
  String get pathData => _pathData;
  set pathData(String value) {
    if (value == _pathData) return;
    _pathData = value;
    _path = null;
    markNeedsPaint();
  }

  double _size;

  /// The width and height in pixels.
  double get glyphSize => _size;
  set glyphSize(double value) {
    if (value == _size) return;
    _size = value;
    markNeedsLayout();
  }

  Color _color;

  /// The fill.
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  double? _baseline;

  /// The distance from the top to the baseline; the bottom edge when null.
  double? get baseline => _baseline;
  set baseline(double? value) {
    if (value == _baseline) return;
    _baseline = value;
    markNeedsLayout();
  }

  /// The parsed path: up to the first error when the data has one, as SVG
  /// draws it ([svgPathOf], shared with the Svg component).
  Path get path => _path ??= svgPathOf(_pathData);

  @override
  double computeMinIntrinsicWidth(double height) => _size;

  @override
  double computeMaxIntrinsicWidth(double height) => _size;

  @override
  double computeMinIntrinsicHeight(double width) => _size;

  @override
  double computeMaxIntrinsicHeight(double width) => _size;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(Size.square(_size));

  // The bottom edge when no baseline is set, as [RenderLucideGlyph]'s.
  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => _baseline ?? computeDryLayout(constraints).height;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _baseline ?? size.height;

  @override
  void performLayout() => size = computeDryLayout(constraints);

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..scale(_size / 24)
      ..drawPath(path, Paint()..color = _color)
      ..restore();
  }
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/media.tsx; lucide-react 0.525.0 and 1.57.0 (dist/esm); Chromium 159.0.8154.13 core/svg, core/css/svg.css
