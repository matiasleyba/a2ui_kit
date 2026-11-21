// An outer `<svg>` element of primitive shapes, as a browser lays it out and
// paints it: the replaced element's size (CSS 2.1, sections 10.3.2 and
// 10.6.2), the viewBox and preserveAspectRatio mapping (SVG 2, section 8.2,
// "Equivalent transform of an SVG viewport"), the fill and stroke
// properties with their initial values and inheritance (SVG 2, sections
// 13.2-13.5), and `<text>` placed by its baseline and `text-anchor` (SVG 2,
// section 11.10.1). The specs' normative text was read for these; no
// engine source is ported.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/svg/svg_path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A length of an SVG presentation attribute (`width`, `height`): a number
/// is pixels; a string is a CSS length, where a unitless number is pixels
/// too (presentation attributes take unitless lengths, SVG 2 section 6.6).
/// Null for anything else, which the browser ignores (the property stays
/// `auto`).
A2uiLength? svgLengthOf(Object? value) {
  if (value is num) {
    return value.isFinite && value >= 0
        ? A2uiLength.px(value.toDouble())
        : null;
  }
  if (value is! String) return null;
  final number = double.tryParse(value.trim());
  if (number != null) {
    return number.isFinite && number >= 0 ? A2uiLength.px(number) : null;
  }
  return A2uiLength.parse(value);
}

/// The `viewBox` of an `<svg>`: its user-space rectangle.
///
/// Null when [value] is not four numbers (separated by white space and/or
/// a comma) or its width or height is not positive: a negative size is an
/// error and a zero one disables the drawing (SVG 2, section 8.6); either
/// way the box maps nothing.
Rect? svgViewBoxOf(String? value) {
  if (value == null) return null;
  final parts = value
      .trim()
      .split(RegExp(r'[\s,]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length != 4) return null;
  final numbers = [for (final part in parts) double.tryParse(part)];
  if (numbers.any((n) => n == null || !n.isFinite)) return null;
  final [x!, y!, width!, height!] = numbers;
  if (width <= 0 || height <= 0) return null;
  return Rect.fromLTWH(x, y, width, height);
}

/// An SVG `preserveAspectRatio`: how the viewBox maps onto the viewport.
@immutable
class SvgAspect {
  /// The mapping: [x] and [y] are 0 (min), .5 (mid) or 1 (max); null for
  /// `none`, which stretches.
  const SvgAspect({this.x = .5, this.y = .5, this.slice = false});

  /// `none`: the viewBox stretches to the viewport.
  const SvgAspect.none() : x = null, y = null, slice = false;

  /// The aspect of [value]: `<align> [meet | slice]`, the initial value
  /// when it does not parse (a browser drops an invalid attribute).
  factory SvgAspect.parse(String? value) {
    if (value == null) return initial;
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.length > 2) return initial;
    final slice = switch (parts.length == 2 ? parts[1] : 'meet') {
      'meet' => false,
      'slice' => true,
      _ => null,
    };
    if (slice == null) return initial;
    if (parts[0] == 'none') return const SvgAspect.none();
    final match = RegExp(
      r'^x(Min|Mid|Max)Y(Min|Mid|Max)$',
    ).firstMatch(parts[0]);
    if (match == null) return initial;
    double align(String part) => switch (part) {
      'Min' => 0,
      'Mid' => .5,
      _ => 1,
    };
    return SvgAspect(x: align(match[1]!), y: align(match[2]!), slice: slice);
  }

  /// The initial value, `xMidYMid meet`.
  static const SvgAspect initial = SvgAspect();

  /// The alignment along x, or null for `none`.
  final double? x;

  /// The alignment along y, or null for `none`.
  final double? y;

  /// `slice` (cover) rather than `meet` (contain).
  final bool slice;

  /// The transform from user space ([viewBox]) to a viewport of [size]
  /// (SVG 2 section 8.2): the scales, equal unless `none`, then the
  /// alignment's share of the space left.
  Matrix4 transform(Rect viewBox, Size size) {
    var sx = size.width / viewBox.width;
    var sy = size.height / viewBox.height;
    final ax = x;
    final ay = y;
    if (ax != null && ay != null) {
      sx = sy = slice ? math.max(sx, sy) : math.min(sx, sy);
    }
    var tx = -viewBox.left * sx;
    var ty = -viewBox.top * sy;
    if (ax != null && ay != null) {
      tx += (size.width - viewBox.width * sx) * ax;
      ty += (size.height - viewBox.height * sy) * ay;
    }
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(sx, sy, 1, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is SvgAspect &&
      other.x == x &&
      other.y == y &&
      other.slice == slice;

  @override
  int get hashCode => Object.hash(x, y, slice);
}

/// One shape of an [SvgDrawing], its paints resolved: a null fill or
/// stroke paints nothing.
@immutable
sealed class SvgShape {
  const SvgShape();
}

/// A `<rect>`, `<circle>`, `<path>` or `<line>`: a geometry filled, then
/// stroked (SVG's `paint-order: normal`).
@immutable
class SvgGeometry extends SvgShape {
  /// A geometry; [kind] and [values] describe it ([path] for a path).
  const SvgGeometry({
    required this.kind,
    this.values = const [],
    this.path,
    this.fill,
    this.stroke,
    this.strokeWidth = 1,
  });

  /// `rect` (x, y, width, height, rx), `circle` (cx, cy, r), `path` or
  /// `line` (x1, y1, x2, y2).
  final String kind;

  /// The numbers of the geometry, in the order [kind] names them.
  final List<double> values;

  /// The path data of a `path`.
  final String? path;

  /// The fill.
  final Color? fill;

  /// The stroke.
  final Color? stroke;

  /// The stroke's width, in user units.
  final double strokeWidth;

  /// The outline in user units, or null when the shape renders nothing (a
  /// rect or circle whose size is not positive, SVG 2 sections 10.2, 10.3).
  Path? outline() {
    switch (kind) {
      case 'rect':
        final [x, y, width, height, rx] = values;
        if (width <= 0 || height <= 0) return null;
        final rect = Rect.fromLTWH(x, y, width, height);
        if (rx <= 0) return Path()..addRect(rect);
        // `ry` is auto, so it takes `rx`; each is at most half the side.
        final radius = Radius.elliptical(
          math.min(rx, width / 2),
          math.min(rx, height / 2),
        );
        return Path()..addRRect(RRect.fromRectAndRadius(rect, radius));
      case 'circle':
        final [cx, cy, r] = values;
        if (r <= 0) return null;
        return Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      case 'line':
        final [x1, y1, x2, y2] = values;
        return Path()
          ..moveTo(x1, y1)
          ..lineTo(x2, y2);
      default:
        return svgPathOf(path);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SvgGeometry &&
      other.kind == kind &&
      listEquals(other.values, values) &&
      other.path == path &&
      other.fill == fill &&
      other.stroke == stroke &&
      other.strokeWidth == strokeWidth;

  @override
  int get hashCode => Object.hash(
    kind,
    Object.hashAll(values),
    path,
    fill,
    stroke,
    strokeWidth,
  );
}

/// A `<text>`: [text] with its baseline at ([x], [y]), anchored at its
/// start, middle or end.
@immutable
class SvgText extends SvgShape {
  /// A text.
  const SvgText({
    required this.x,
    required this.y,
    required this.text,
    required this.fill,
    this.fontSize,
    this.anchor = 0,
  });

  /// The anchor point's x, in user units.
  final double x;

  /// The baseline's y, in user units.
  final double y;

  /// What it says.
  final String text;

  /// The font size, in user units; null inherits the surrounding text's
  /// (the `<svg>`'s CSS `font-size`, which user units then scale).
  final double? fontSize;

  /// The fill; null paints nothing.
  final Color? fill;

  /// The share of the text's advance before the anchor: 0 (`start`), .5
  /// (`middle`) or 1 (`end`).
  final double anchor;

  @override
  bool operator ==(Object other) =>
      other is SvgText &&
      other.x == x &&
      other.y == y &&
      other.text == text &&
      other.fontSize == fontSize &&
      other.fill == fill &&
      other.anchor == anchor;

  @override
  int get hashCode => Object.hash(x, y, text, fontSize, fill, anchor);
}

/// The size, mapping and shapes of an outer `<svg>`.
@immutable
class SvgDrawing {
  /// A drawing.
  const SvgDrawing({
    required this.shapes,
    this.width,
    this.height,
    this.viewBox,
    this.aspect = SvgAspect.initial,
    this.cap = StrokeCap.butt,
    this.join = StrokeJoin.miter,
  });

  /// The shapes in paint order.
  final List<SvgShape> shapes;

  /// The `width`, or null for `auto`.
  final A2uiLength? width;

  /// The `height`, or null for `auto`.
  final A2uiLength? height;

  /// The user-space rectangle, or null for none (user units are pixels).
  final Rect? viewBox;

  /// The `preserveAspectRatio`.
  final SvgAspect aspect;

  /// The `stroke-linecap` every shape inherits.
  final StrokeCap cap;

  /// The `stroke-linejoin` every shape inherits.
  final StrokeJoin join;

  @override
  bool operator ==(Object other) =>
      other is SvgDrawing &&
      listEquals(other.shapes, shapes) &&
      other.width == width &&
      other.height == height &&
      other.viewBox == viewBox &&
      other.aspect == aspect &&
      other.cap == cap &&
      other.join == join;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(shapes),
    width,
    height,
    viewBox,
    aspect,
    cap,
    join,
  );
}

/// Draws an [SvgDrawing]: sized as CSS sizes a replaced element, its
/// content clipped to its box (the UA's `svg:not(:root) { overflow:
/// hidden }`), texts in [textStyle].
class SvgCanvas extends LeafRenderObjectWidget {
  /// Draws [drawing].
  const SvgCanvas({
    required this.drawing,
    required this.textStyle,
    this.textScaler = TextScaler.noScaling,
    super.key,
  });

  /// What is drawn.
  final SvgDrawing drawing;

  /// The font the texts inherit (family, weight); its size is the size of
  /// a text without one, and `em` lengths resolve against it.
  final TextStyle textStyle;

  /// How the texts grow with the text scale.
  final TextScaler textScaler;

  @override
  RenderSvgCanvas createRenderObject(BuildContext context) => RenderSvgCanvas(
    drawing: drawing,
    textStyle: textStyle,
    textScaler: textScaler,
  );

  @override
  void updateRenderObject(BuildContext context, RenderSvgCanvas renderObject) {
    renderObject
      ..drawing = drawing
      ..textStyle = textStyle
      ..textScaler = textScaler;
  }
}

/// The render object of [SvgCanvas].
class RenderSvgCanvas extends RenderBox
    with RelayoutWhenSystemFontsChangeMixin {
  /// Draws [drawing].
  RenderSvgCanvas({
    required SvgDrawing drawing,
    required TextStyle textStyle,
    required TextScaler textScaler,
  }) : _drawing = drawing,
       _textStyle = textStyle,
       _textScaler = textScaler;

  SvgDrawing _drawing;

  /// What is drawn.
  SvgDrawing get drawing => _drawing;
  set drawing(SvgDrawing value) {
    if (value == _drawing) return;
    final resized =
        value.width != _drawing.width ||
        value.height != _drawing.height ||
        value.viewBox != _drawing.viewBox;
    _drawing = value;
    _clearCaches();
    resized ? markNeedsLayout() : markNeedsPaint();
  }

  TextStyle _textStyle;

  /// The font the texts inherit.
  TextStyle get textStyle => _textStyle;
  set textStyle(TextStyle value) {
    if (value == _textStyle) return;
    _textStyle = value;
    _clearCaches();
    markNeedsLayout();
  }

  TextScaler _textScaler;

  /// How the texts grow with the text scale.
  TextScaler get textScaler => _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _clearCaches();
    markNeedsPaint();
  }

  List<Path?>? _outlines;
  final Map<int, TextPainter> _texts = {};

  void _clearCaches() {
    _outlines = null;
    for (final painter in _texts.values) {
      painter.dispose();
    }
    _texts.clear();
  }

  @override
  void systemFontsDidChange() {
    super.systemFontsDidChange();
    _clearCaches();
    markNeedsPaint();
  }

  @override
  void dispose() {
    _clearCaches();
    super.dispose();
  }

  double get _fontSize => _textStyle.fontSize ?? 16;

  /// The intrinsic ratio: the viewBox's, else that of a width and a height
  /// that are both absolute; null for none.
  double? get _ratio {
    final box = _drawing.viewBox;
    if (box != null) return box.width / box.height;
    final width = _absolute(_drawing.width);
    final height = _absolute(_drawing.height);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  double? _absolute(A2uiLength? length) =>
      length is A2uiPercent ? null : length?.resolve(fontSize: _fontSize);

  /// The drawing's box at [constraints], its used size (CSS 2.1, sections
  /// 10.3.2 and 10.6.2): a percentage resolves against a bounded width (and
  /// a fixed height); an auto side follows the other through the ratio,
  /// else the CSS default object size (300 by 150); both auto with a ratio
  /// fill the width offered.
  ///
  /// A fixed width is the width a flex container resolved for it (CSS
  /// flex, its `width` and stretch, item_styles.dart), and carries the
  /// ratio to an auto height; or the width of the block it sits in (the
  /// surface), which an absolute width narrower than it keeps, at its
  /// start (CSS 2.1, 10.3.4), as no flex container stretches an item
  /// with a definite width.
  Size _boxFor(BoxConstraints constraints) {
    final widthBase = constraints.hasBoundedWidth ? constraints.maxWidth : null;
    final heightBase = constraints.hasTightHeight
        ? constraints.maxHeight
        : null;
    final ratio = _ratio;
    var width = _drawing.width?.resolve(
      percentBase: widthBase,
      fontSize: _fontSize,
    );
    var height = _drawing.height?.resolve(
      percentBase: heightBase,
      fontSize: _fontSize,
    );
    if (constraints.hasTightWidth) {
      final absolute = _absolute(_drawing.width);
      width = absolute != null && absolute < constraints.maxWidth
          ? absolute
          : constraints.maxWidth;
    }
    if (width != null && height == null) {
      height = ratio != null ? width / ratio : 150;
    } else if (height != null && width == null) {
      width = ratio != null ? height * ratio : 300;
    } else if (width == null && height == null) {
      width = ratio != null && widthBase != null ? widthBase : 300;
      height = ratio != null ? width / ratio : 150;
    }
    final box = Size(width!, height!);
    // The box never leaves what the constraints allow; a tight width it
    // keeps narrower than stays its own.
    return Size(
      width < constraints.minWidth && constraints.hasTightWidth
          ? width
          : constraints.constrainWidth(box.width),
      constraints.constrainHeight(box.height),
    );
  }

  /// This render box's size: the drawing's box, or the fixed width it
  /// sits at the start of.
  Size _sizeFor(BoxConstraints constraints) =>
      constraints.constrain(_boxFor(constraints));

  /// The drawing's box: where the viewport is and what it clips to, at
  /// this box's top left.
  Size get box => _box;
  Size _box = Size.zero;

  @override
  double computeMinIntrinsicWidth(double height) {
    // A percentage width (the default 100%) is compressible: it adds
    // nothing to its container's min-content (CSS Sizing 3, section 5.2.2).
    final width = _absolute(_drawing.width);
    if (width != null) return width;
    if (_drawing.width is A2uiPercent) return 0;
    return _intrinsicWidth();
  }

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _absolute(_drawing.width) ?? _intrinsicWidth();

  double _intrinsicWidth() {
    final height = _absolute(_drawing.height);
    final ratio = _ratio;
    if (height != null && ratio != null) return height * ratio;
    return 300;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _heightAt(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _heightAt(width);

  double _heightAt(double width) => _sizeFor(
    width.isFinite
        ? BoxConstraints.tightFor(width: width)
        : const BoxConstraints(),
  ).height;

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  // An `<svg>` is a replaced element: its baseline is its bottom edge (CSS
  // 2.1 section 10.8.1, an inline replaced element's bottom margin edge; a
  // flex or grid item synthesizes it from its border box), whatever text it
  // draws. The same at layout and dry: a null here makes a proxy parent's
  // dry baseline throw in debug (`RenderProxyBoxMixin` falls back to
  // `RenderBox.computeDryBaseline`, which asserts), as lucide.dart's
  // glyph also answers.
  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => _sizeFor(constraints).height;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => size.height;

  @override
  void performLayout() {
    _box = _boxFor(constraints);
    size = constraints.constrain(_box);
  }

  /// The transform from user units to this box: the viewBox mapping onto
  /// the drawing's [box], or none without a viewBox.
  Matrix4 get userTransform {
    final viewBox = _drawing.viewBox;
    if (viewBox == null) return Matrix4.identity();
    return _drawing.aspect.transform(viewBox, _box);
  }

  TextPainter _textPainter(int index, SvgText text) =>
      _texts[index] ??= TextPainter(
        text: TextSpan(
          text: text.text,
          style: _textStyle.copyWith(
            fontSize: text.fontSize ?? _fontSize,
            color: text.fill,
            // SVG text is one line, placed by its baseline: no line box.
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: _textScaler,
        maxLines: 1,
      )..layout();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_box.isEmpty) return;
    final canvas = context.canvas
      ..save()
      ..clipRect(offset & _box)
      ..translate(offset.dx, offset.dy)
      ..transform(userTransform.storage);
    final shapes = _drawing.shapes;
    final outlines = _outlines ??= [
      for (final shape in shapes)
        if (shape is SvgGeometry) shape.outline() else null,
    ];
    for (var i = 0; i < shapes.length; i++) {
      switch (shapes[i]) {
        case final SvgGeometry shape:
          final outline = outlines[i];
          if (outline == null) continue;
          final fill = shape.fill;
          // A line has no interior to fill.
          if (fill != null && shape.kind != 'line') {
            canvas.drawPath(outline, Paint()..color = fill);
          }
          final stroke = shape.stroke;
          if (stroke != null && shape.strokeWidth > 0) {
            canvas.drawPath(
              outline,
              Paint()
                ..style = PaintingStyle.stroke
                ..color = stroke
                ..strokeWidth = shape.strokeWidth
                ..strokeCap = _drawing.cap
                ..strokeJoin = _drawing.join,
            );
          }
        case final SvgText text:
          if (text.fill == null || text.text.isEmpty) continue;
          final painter = _textPainter(i, text);
          final baseline = painter.computeDistanceToActualBaseline(
            ui.TextBaseline.alphabetic,
          );
          painter.paint(
            canvas,
            Offset(text.x - painter.width * text.anchor, text.y - baseline),
          );
      }
    }
    canvas.restore();
  }

  @override
  bool hitTestSelf(Offset position) => false;
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/media.tsx
