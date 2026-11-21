import 'dart:math' as math;

import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The CSS box of an A2UI container: its padding, border, fill, sizes and
/// clipping, as CopilotKit's `layoutStyle` computes them.
@immutable
class A2uiBoxStyle {
  /// A box; every value is optional.
  const A2uiBoxStyle({
    this.padding = EdgeInsets.zero,
    this.borderWidth = 0,
    this.decoration,
    this.width,
    this.height,
    this.minWidth,
    this.minHeight,
    this.maxWidth,
    this.maxHeight,
    this.aspectRatio,
    this.fill = true,
    this.clip = false,
  });

  /// The padding inside the border.
  final EdgeInsets padding;

  /// The width of the border on every side (CSS `border-box` sizing: the
  /// border is inside the box's size).
  final double borderWidth;

  /// The fill, border, radius and shadow.
  final BoxDecoration? decoration;

  /// The width, or null for `auto`.
  final A2uiLength? width;

  /// The height, or null for `auto`.
  final A2uiLength? height;

  /// The minimum width, or null for none.
  final A2uiLength? minWidth;

  /// The minimum height, or null for none.
  final A2uiLength? minHeight;

  /// The maximum width, or null for none.
  final A2uiLength? maxWidth;

  /// The maximum height, or null for none.
  final A2uiLength? maxHeight;

  /// The width divided by the height, or null for none.
  final double? aspectRatio;

  /// Whether the box takes all the width it is offered when its width is
  /// `auto`, as a block does, rather than the width of its content, as an
  /// `inline-flex` box does.
  final bool fill;

  /// Whether the content is clipped to the box (`overflow: hidden`).
  final bool clip;

  /// The space between the box's edge and its content.
  EdgeInsets get insets => padding + EdgeInsets.all(borderWidth);

  @override
  bool operator ==(Object other) =>
      other is A2uiBoxStyle &&
      other.padding == padding &&
      other.borderWidth == borderWidth &&
      other.decoration == decoration &&
      other.width == width &&
      other.height == height &&
      other.minWidth == minWidth &&
      other.minHeight == minHeight &&
      other.maxWidth == maxWidth &&
      other.maxHeight == maxHeight &&
      other.aspectRatio == aspectRatio &&
      other.fill == fill &&
      other.clip == clip;

  @override
  int get hashCode => Object.hash(
    padding,
    borderWidth,
    decoration,
    width,
    height,
    minWidth,
    minHeight,
    maxWidth,
    maxHeight,
    aspectRatio,
    fill,
    clip,
  );
}

/// How an A2UI flex container lays its children out: CSS `flex-direction`,
/// `flex-wrap`, `justify-content`, `align-items` and the gaps.
@immutable
class A2uiFlexStyle {
  /// A flex layout.
  const A2uiFlexStyle({
    this.direction = Axis.vertical,
    this.wrap = A2uiWrap.nowrap,
    this.justify,
    this.align,
    this.rowGap = 0,
    this.columnGap = 0,
  });

  /// [Axis.horizontal] for `row`, [Axis.vertical] for `column`.
  final Axis direction;

  /// Whether the children wrap onto more lines.
  final A2uiWrap wrap;

  /// The distribution of free space on the main axis; null is `start`.
  final A2uiJustify? justify;

  /// The cross-axis alignment of the children; null is `stretch` (CSS
  /// `normal`).
  final A2uiAlign? align;

  /// The vertical space between children or lines (CSS `row-gap`).
  final double rowGap;

  /// The horizontal space between children or lines (CSS `column-gap`).
  final double columnGap;

  /// The gap along the main axis.
  double get mainGap => direction == Axis.horizontal ? columnGap : rowGap;

  /// The gap between lines.
  double get crossGap => direction == Axis.horizontal ? rowGap : columnGap;

  @override
  bool operator ==(Object other) =>
      other is A2uiFlexStyle &&
      other.direction == direction &&
      other.wrap == wrap &&
      other.justify == justify &&
      other.align == align &&
      other.rowGap == rowGap &&
      other.columnGap == columnGap;

  @override
  int get hashCode =>
      Object.hash(direction, wrap, justify, align, rowGap, columnGap);
}

/// How one child takes part in a flex container: CSS `flex-grow`,
/// `flex-shrink`, `flex-basis`, its sizes, `align-self` and an auto start
/// margin.
@immutable
class A2uiFlexItemStyle {
  /// An item; the defaults are CSS's: `flex: 0 1 auto`, automatic minimum
  /// sizes.
  const A2uiFlexItemStyle({
    this.grow = 0,
    this.shrink = 1,
    this.basis,
    this.width,
    this.height,
    this.minWidth,
    this.minHeight,
    this.maxWidth,
    this.maxHeight,
    this.alignSelf,
    this.autoMarginStart = false,
  });

  /// A CSS default item.
  static const A2uiFlexItemStyle normal = A2uiFlexItemStyle();

  /// The share of positive free space the item takes.
  final double grow;

  /// How much the item gives up when space is short, weighted by its base
  /// size.
  final double shrink;

  /// The flex basis, or null for `auto` (the item's size or content).
  final A2uiLength? basis;

  /// The width, or null for `auto`.
  final A2uiLength? width;

  /// The height, or null for `auto`.
  final A2uiLength? height;

  /// The minimum width, or null for `auto`: on the main axis, the content's
  /// minimum (its longest word for text); on the cross axis, zero.
  final A2uiLength? minWidth;

  /// The minimum height, or null for `auto` (see [minWidth]).
  final A2uiLength? minHeight;

  /// The maximum width, or null for none.
  final A2uiLength? maxWidth;

  /// The maximum height, or null for none.
  final A2uiLength? maxHeight;

  /// The item's cross-axis alignment, or null for the container's.
  final A2uiAlign? alignSelf;

  /// Whether the item has `margin-inline-start: auto` (in a row: it takes
  /// the free space before it, so it sits flush right).
  final bool autoMarginStart;

  /// A copy with the given values replaced.
  A2uiFlexItemStyle copyWith({
    double? grow,
    double? shrink,
    A2uiAlign? alignSelf,
    bool? autoMarginStart,
  }) => A2uiFlexItemStyle(
    grow: grow ?? this.grow,
    shrink: shrink ?? this.shrink,
    basis: basis,
    width: width,
    height: height,
    minWidth: minWidth,
    minHeight: minHeight,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    alignSelf: alignSelf ?? this.alignSelf,
    autoMarginStart: autoMarginStart ?? this.autoMarginStart,
  );

  @override
  bool operator ==(Object other) =>
      other is A2uiFlexItemStyle &&
      other.grow == grow &&
      other.shrink == shrink &&
      other.basis == basis &&
      other.width == width &&
      other.height == height &&
      other.minWidth == minWidth &&
      other.minHeight == minHeight &&
      other.maxWidth == maxWidth &&
      other.maxHeight == maxHeight &&
      other.alignSelf == alignSelf &&
      other.autoMarginStart == autoMarginStart;

  @override
  int get hashCode => Object.hash(
    grow,
    shrink,
    basis,
    width,
    height,
    minWidth,
    minHeight,
    maxWidth,
    maxHeight,
    alignSelf,
    autoMarginStart,
  );

  @override
  String toString() =>
      'A2uiFlexItemStyle(flex: $grow $shrink ${basis ?? 'auto'}'
      '${alignSelf == null ? '' : ', align-self: ${alignSelf!.wire}'})';
}

/// [value] clamped to [min] and [max]. When they cross, [min] wins, as
/// `min-width` wins over `max-width` in CSS.
double clampCss(double value, double min, double max) =>
    math.max(min, math.min(value, max));

// PORT STATUS: confidence=high todos=0 upstream=packages/shared/src/generative-ui/standard/layout.ts (layoutStyle)
