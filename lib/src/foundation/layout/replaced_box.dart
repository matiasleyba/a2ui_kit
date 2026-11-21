import 'dart:math' as math;

import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The CSS sizes of a replaced element (an `<img>`): its `width`,
/// `height`, their limits and `aspect-ratio`.
@immutable
class ReplacedSizing {
  /// Sizes; null is `auto` (or `none` for a maximum).
  const ReplacedSizing({
    this.width,
    this.height,
    this.minWidth,
    this.minHeight,
    this.maxWidth,
    this.maxHeight,
    this.aspectRatio,
    this.fontSize = 16,
  });

  /// `width`.
  final A2uiLength? width;

  /// `height`.
  final A2uiLength? height;

  /// `min-width`.
  final A2uiLength? minWidth;

  /// `min-height`.
  final A2uiLength? minHeight;

  /// `max-width`.
  final A2uiLength? maxWidth;

  /// `max-height`.
  final A2uiLength? maxHeight;

  /// `aspect-ratio`, width over height; the image's own ratio when null.
  final double? aspectRatio;

  /// The font size `em` lengths resolve against.
  final double fontSize;

  @override
  bool operator ==(Object other) =>
      other is ReplacedSizing &&
      other.width == width &&
      other.height == height &&
      other.minWidth == minWidth &&
      other.minHeight == minHeight &&
      other.maxWidth == maxWidth &&
      other.maxHeight == maxHeight &&
      other.aspectRatio == aspectRatio &&
      other.fontSize == fontSize;

  @override
  int get hashCode => Object.hash(
    width,
    height,
    minWidth,
    minHeight,
    maxWidth,
    maxHeight,
    aspectRatio,
    fontSize,
  );
}

/// Sizes [child] as CSS sizes an image: from [sizing] and the image's
/// [naturalSize], keeping the ratio when only one side is given or a
/// limit applies, and following a width its parent imposes.
class ReplacedBox extends SingleChildRenderObjectWidget {
  /// Sizes [child].
  const ReplacedBox({
    required this.sizing,
    this.naturalSize,
    super.child,
    super.key,
  });

  /// The CSS sizes.
  final ReplacedSizing sizing;

  /// The image's own size, once known.
  final Size? naturalSize;

  @override
  RenderReplacedBox createRenderObject(BuildContext context) =>
      RenderReplacedBox(sizing: sizing, naturalSize: naturalSize);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderReplacedBox renderObject,
  ) {
    renderObject
      ..sizing = sizing
      ..naturalSize = naturalSize;
  }
}

/// The render object of [ReplacedBox].
class RenderReplacedBox extends RenderProxyBox {
  /// Sizes its child by [sizing] and [naturalSize].
  RenderReplacedBox({required ReplacedSizing sizing, Size? naturalSize})
    : _sizing = sizing,
      _naturalSize = naturalSize;

  ReplacedSizing _sizing;

  /// The CSS sizes.
  ReplacedSizing get sizing => _sizing;
  set sizing(ReplacedSizing value) {
    if (value == _sizing) return;
    _sizing = value;
    markNeedsLayout();
  }

  Size? _naturalSize;

  /// The image's own size.
  Size? get naturalSize => _naturalSize;
  set naturalSize(Size? value) {
    if (value == _naturalSize) return;
    _naturalSize = value;
    markNeedsLayout();
  }

  double? get _ratio {
    final ratio = _sizing.aspectRatio;
    if (ratio != null && ratio > 0) return ratio;
    final natural = _naturalSize;
    if (natural == null || natural.height <= 0) return null;
    return natural.width / natural.height;
  }

  double? _resolve(A2uiLength? length, double? base) =>
      length?.resolve(percentBase: base, fontSize: _sizing.fontSize);

  /// The CSS size at [constraints].
  Size _sizeFor(BoxConstraints constraints) {
    final s = _sizing;
    final widthBase = constraints.hasBoundedWidth ? constraints.maxWidth : null;
    final heightBase = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : null;
    final ratio = _ratio;
    final natural = _naturalSize;
    final givenWidth = _resolve(s.width, widthBase);
    final givenHeight = _resolve(s.height, heightBase);
    final autoWidth = givenWidth == null;
    final autoHeight = givenHeight == null;
    double width;
    double height;
    if (givenWidth == null && givenHeight == null) {
      width = natural?.width ?? 0;
      height = ratio != null ? width / ratio : natural?.height ?? 0;
    } else if (givenWidth == null) {
      height = givenHeight!;
      width = ratio != null ? height * ratio : natural?.width ?? 0;
    } else {
      width = givenWidth;
      height =
          givenHeight ?? (ratio != null ? width / ratio : natural?.height ?? 0);
    }
    final minW = _resolve(s.minWidth, widthBase) ?? 0;
    final maxW = _resolve(s.maxWidth, widthBase) ?? double.infinity;
    final minH = _resolve(s.minHeight, heightBase) ?? 0;
    final maxH = _resolve(s.maxHeight, heightBase) ?? double.infinity;
    double clampW(double value) => math.max(minW, math.min(value, maxW));
    double clampH(double value) => math.max(minH, math.min(value, maxH));
    var w = clampW(width);
    var h = clampH(height);
    // A side that follows the ratio follows a clamped other side.
    if (ratio != null) {
      if (autoHeight && w != width) h = clampH(w / ratio);
      if (autoWidth && h != height) w = clampW(h * ratio);
    }
    // A width the parent imposes (a stretched or shrunk flex item) carries
    // the ratio to an auto height.
    final imposed = constraints.constrainWidth(w);
    if (imposed != w && autoHeight && ratio != null) {
      h = clampH(imposed / ratio);
    }
    return constraints.constrain(Size(imposed, h));
  }

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsicWidth();

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsicWidth();

  double _intrinsicWidth() {
    final width = _sizing.width;
    // A percentage width contributes nothing to its container's size.
    if (width is A2uiPercent) return 0;
    return _sizeFor(const BoxConstraints()).width;
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

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => null;

  @override
  void performLayout() {
    size = _sizeFor(constraints);
    child?.layout(BoxConstraints.tight(size));
  }
}

// PORT STATUS: confidence=high todos=0 upstream=none
