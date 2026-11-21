import 'dart:math' as math;

import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The parent data of a child of [RenderCssFlex]: its [A2uiFlexItemStyle].
class CssFlexParentData extends ContainerBoxParentData<RenderBox> {
  /// How the child takes part in the layout.
  A2uiFlexItemStyle style = A2uiFlexItemStyle.normal;
}

/// Gives a child of [CssFlex] its CSS flex item style.
class CssFlexItem extends ParentDataWidget<CssFlexParentData> {
  /// Gives [child] the item [style].
  const CssFlexItem({required this.style, required super.child, super.key});

  /// The child's `flex`, sizes and `align-self`.
  final A2uiFlexItemStyle style;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as CssFlexParentData;
    if (data.style != style) {
      data.style = style;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => CssFlex;
}

/// A box laid out as a CSS flex container: CopilotKit's containers (Box,
/// Column, Row, Card, GridItem) render through it.
///
/// Unlike Flutter's [Flex], children shrink below their content
/// (`flex-shrink` with automatic minimum sizes), wrap onto more lines, take
/// gaps, and stretch on the cross axis; a container that cannot fit its
/// content lets it overflow, as CSS does, and never reports an error.
class CssFlex extends MultiChildRenderObjectWidget {
  /// A flex container of [children] (wrap each in a [CssFlexItem] to give it
  /// a style other than CSS's default).
  const CssFlex({
    required this.flex,
    this.box = const A2uiBoxStyle(),
    super.children,
    super.key,
  });

  /// The flex layout.
  final A2uiFlexStyle flex;

  /// The container's own box.
  final A2uiBoxStyle box;

  @override
  RenderCssFlex createRenderObject(BuildContext context) => RenderCssFlex(
    flex: flex,
    box: box,
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    configuration: createLocalImageConfiguration(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderCssFlex renderObject) {
    renderObject
      ..flex = flex
      ..box = box
      ..textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr
      ..configuration = createLocalImageConfiguration(context);
  }
}

/// Sizes a child: with a real layout, a dry layout, or its intrinsic sizes.
abstract class _Sizer {
  const _Sizer();

  Size size(RenderBox child, BoxConstraints constraints);

  double? baseline(RenderBox child, BoxConstraints constraints);
}

class _LayoutSizer extends _Sizer {
  const _LayoutSizer();

  @override
  Size size(RenderBox child, BoxConstraints constraints) {
    child.layout(constraints, parentUsesSize: true);
    return child.size;
  }

  @override
  double? baseline(RenderBox child, BoxConstraints constraints) =>
      child.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true);
}

class _DrySizer extends _Sizer {
  const _DrySizer();

  @override
  Size size(RenderBox child, BoxConstraints constraints) =>
      child.getDryLayout(constraints);

  @override
  double? baseline(RenderBox child, BoxConstraints constraints) =>
      child.getDryBaseline(constraints, TextBaseline.alphabetic);
}

class _IntrinsicSizer extends _Sizer {
  const _IntrinsicSizer();

  @override
  Size size(RenderBox child, BoxConstraints constraints) {
    final width = constraints.hasTightWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(
            child.getMaxIntrinsicWidth(double.infinity),
          );
    final height = constraints.hasTightHeight
        ? constraints.maxHeight
        : constraints.constrainHeight(child.getMaxIntrinsicHeight(width));
    return Size(width, height);
  }

  @override
  double? baseline(RenderBox child, BoxConstraints constraints) => null;
}

class _Item {
  _Item(this.child, this.style);

  final RenderBox child;
  final A2uiFlexItemStyle style;

  A2uiAlign align = A2uiAlign.stretch;
  bool stretch = false;
  double base = 0;
  double hypothetical = 0;
  double minMain = 0;
  double maxMain = double.infinity;
  double main = 0;
  double violation = 0;
  bool frozen = false;
  double? crossSpec;
  double minCross = 0;
  double maxCross = double.infinity;
  double cross = 0;
  double? ascent;
  Size size = Size.zero;
  BoxConstraints constraints = const BoxConstraints();
  Offset offset = Offset.zero;
}

class _Outcome {
  _Outcome(this.size, this.items);

  final Size size;
  final List<_Item> items;
}

double? _finite(double value) => value.isFinite ? value : null;

/// The render object of [CssFlex]: the CSS flexible box layout algorithm
/// (CSS Flexible Box Layout Module Level 1, section 9) over Flutter boxes.
///
/// A child's max-content width is its maximum intrinsic width, its
/// min-content width its minimum intrinsic width, and its content height
/// the height it takes at its used width.
class RenderCssFlex extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CssFlexParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CssFlexParentData> {
  /// A flex container with [flex] and [box].
  RenderCssFlex({
    required A2uiFlexStyle flex,
    required A2uiBoxStyle box,
    required TextDirection textDirection,
    ImageConfiguration configuration = ImageConfiguration.empty,
  }) : _flex = flex,
       _box = box,
       _textDirection = textDirection,
       _configuration = configuration;

  /// The flex layout.
  A2uiFlexStyle get flex => _flex;
  A2uiFlexStyle _flex;
  set flex(A2uiFlexStyle value) {
    if (value == _flex) return;
    _flex = value;
    markNeedsLayout();
  }

  /// The container's own box.
  A2uiBoxStyle get box => _box;
  A2uiBoxStyle _box;
  set box(A2uiBoxStyle value) {
    if (value == _box) return;
    if (value.decoration != _box.decoration) {
      _painter?.dispose();
      _painter = null;
    }
    _box = value;
    markNeedsLayout();
  }

  /// The direction `start` and `end` follow.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  /// The image configuration the decoration paints with.
  ImageConfiguration get configuration => _configuration;
  ImageConfiguration _configuration;
  set configuration(ImageConfiguration value) {
    if (value == _configuration) return;
    _configuration = value;
    markNeedsPaint();
  }

  BoxPainter? _painter;
  final LayerHandle<ClipRRectLayer> _clipLayer = LayerHandle<ClipRRectLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! CssFlexParentData) {
      child.parentData = CssFlexParentData();
    }
  }

  @override
  void detach() {
    _painter?.dispose();
    _painter = null;
    super.detach();
  }

  @override
  void dispose() {
    _painter?.dispose();
    _painter = null;
    _clipLayer.layer = null;
    super.dispose();
  }

  List<_Item> _items() {
    final items = <_Item>[];
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as CssFlexParentData;
      items.add(_Item(child, data.style));
      child = data.nextSibling;
    }
    return items;
  }

  bool get _horizontal => _flex.direction == Axis.horizontal;

  // ---- Intrinsic sizes ----

  double? _px(A2uiLength? length) => length?.resolve();

  /// The width of the box from its own `width`, clamped, or null when it
  /// has none in pixels.
  double? _ownWidth() {
    final width = _px(_box.width);
    if (width == null) return null;
    return clampCss(
      width,
      _px(_box.minWidth) ?? 0,
      _px(_box.maxWidth) ?? double.infinity,
    );
  }

  double _intrinsicWidth({required bool minimum}) {
    final own = _ownWidth();
    if (own != null) return own;
    final summed = _horizontal && !(minimum && _flex.wrap != A2uiWrap.nowrap);
    var content = 0.0;
    var count = 0;
    for (final item in _items()) {
      final style = item.style;
      final spec = _px(style.width);
      var contribution =
          spec ??
          (minimum
              ? item.child.getMinIntrinsicWidth(double.infinity)
              : item.child.getMaxIntrinsicWidth(double.infinity));
      contribution = clampCss(
        contribution,
        _px(style.minWidth) ?? 0,
        _px(style.maxWidth) ?? double.infinity,
      );
      content = summed
          ? content + contribution
          : math.max(content, contribution);
      count++;
    }
    if (summed && count > 1) content += _flex.columnGap * (count - 1);
    return clampCss(
      content + _box.insets.horizontal,
      _px(_box.minWidth) ?? 0,
      _px(_box.maxWidth) ?? double.infinity,
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsicWidth(minimum: true);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsicWidth(minimum: false);

  double _intrinsicHeight(double width) {
    final constraints = width.isFinite
        ? BoxConstraints.tightFor(width: width)
        : const BoxConstraints();
    return _run(constraints, const _IntrinsicSizer()).size.height;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  // ---- Layout ----

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _run(constraints, const _DrySizer()).size;

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final outcome = _run(constraints, const _DrySizer());
    for (final item in outcome.items) {
      final distance = item.child.getDryBaseline(item.constraints, baseline);
      if (distance != null) return distance + item.offset.dy;
    }
    return null;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void performLayout() {
    final outcome = _run(constraints, const _LayoutSizer());
    size = outcome.size;
    for (final item in outcome.items) {
      (item.child.parentData! as CssFlexParentData).offset = item.offset;
    }
  }

  /// The CSS flex layout of the children under [constraints], sizing them
  /// with [sizer].
  _Outcome _run(BoxConstraints constraints, _Sizer sizer) {
    final box = _box;
    final flex = _flex;
    final horizontal = _horizontal;
    final insets = box.insets;
    final hInset = insets.horizontal;
    final vInset = insets.vertical;

    // The box's own size: definite when the parent fixes it, when the box
    // sets it, or (for the width of a block) when space is offered.
    final percentWidth = _finite(constraints.maxWidth);
    final percentHeight = constraints.hasTightHeight
        ? constraints.maxHeight
        : null;
    final minW = box.minWidth?.resolve(percentBase: percentWidth) ?? 0;
    final maxW =
        box.maxWidth?.resolve(percentBase: percentWidth) ?? double.infinity;
    final minH = box.minHeight?.resolve(percentBase: percentHeight) ?? 0;
    final maxH =
        box.maxHeight?.resolve(percentBase: percentHeight) ?? double.infinity;

    double? outerW;
    if (constraints.hasTightWidth) {
      outerW = constraints.maxWidth;
    } else {
      final spec = box.width?.resolve(percentBase: percentWidth);
      if (spec != null) {
        outerW = constraints.constrainWidth(clampCss(spec, minW, maxW));
      } else if (box.fill && constraints.hasBoundedWidth) {
        outerW = constraints.constrainWidth(
          clampCss(constraints.maxWidth, minW, maxW),
        );
      }
    }
    double? outerH;
    if (constraints.hasTightHeight) {
      outerH = constraints.maxHeight;
    } else {
      final spec = box.height?.resolve(percentBase: percentHeight);
      if (spec != null) {
        outerH = constraints.constrainHeight(clampCss(spec, minH, maxH));
      }
    }
    // aspect-ratio: a definite width gives a preferred height that the
    // content may still exceed; a definite height gives the width.
    double? ratioHeight;
    final ratio = box.aspectRatio;
    if (ratio != null) {
      if (outerW != null && outerH == null) {
        ratioHeight = clampCss(outerW / ratio, minH, maxH);
      } else if (outerH != null && outerW == null) {
        outerW = constraints.constrainWidth(
          clampCss(outerH * ratio, minW, maxW),
        );
      }
    }

    final innerW = outerW == null ? null : math.max<double>(0, outerW - hInset);
    final innerH = outerH == null ? null : math.max<double>(0, outerH - vInset);
    final availW =
        innerW ??
        math.max<double>(0, math.min(constraints.maxWidth, maxW) - hInset);
    final availH = innerH ?? math.max<double>(0, maxH - vInset);
    final minInnerW = math.max<double>(
      0,
      math.max(minW, constraints.minWidth) - hInset,
    );
    final minInnerH = math.max<double>(
      0,
      math.max(minH, constraints.minHeight) - vInset,
    );

    final items = _items();
    final mainGap = flex.mainGap;
    final crossGap = flex.crossGap;

    // ---- Each item's sizes ----
    for (final item in items) {
      final style = item.style;
      final mainBase = horizontal ? innerW : innerH;
      final crossBase = horizontal ? innerH : innerW;
      item
        ..maxMain =
            (horizontal ? style.maxWidth : style.maxHeight)?.resolve(
              percentBase: mainBase,
            ) ??
            double.infinity
        ..minCross =
            (horizontal ? style.minHeight : style.minWidth)?.resolve(
              percentBase: crossBase,
            ) ??
            0
        ..maxCross =
            (horizontal ? style.maxHeight : style.maxWidth)?.resolve(
              percentBase: crossBase,
            ) ??
            double.infinity;
      final crossSpec = (horizontal ? style.height : style.width)?.resolve(
        percentBase: crossBase,
      );
      item.crossSpec = crossSpec == null
          ? null
          : clampCss(crossSpec, item.minCross, item.maxCross);
      var align = style.alignSelf ?? flex.align ?? A2uiAlign.stretch;
      // Baselines are not parallel to a column's cross axis.
      if (align == A2uiAlign.baseline && !horizontal) align = A2uiAlign.start;
      item
        ..align = align
        ..stretch = align == A2uiAlign.stretch && item.crossSpec == null;
    }

    // A column's width comes first: a stretched child takes the column's
    // width, the others their fit-content width.
    var innerCross = horizontal ? innerH : innerW;
    if (!horizontal) {
      if (innerCross == null) {
        var widest = 0.0;
        for (final item in items) {
          widest = math.max(widest, _fitCross(item, availW));
        }
        innerCross = clampCss(widest, minInnerW, availW);
      }
      for (final item in items) {
        item.cross = item.stretch
            ? clampCss(innerCross, item.minCross, item.maxCross)
            : (item.crossSpec ?? _fitCross(item, innerCross));
      }
    }

    // ---- Flex base and hypothetical main sizes ----
    for (final item in items) {
      final style = item.style;
      final mainBase = horizontal ? innerW : innerH;
      final mainSpec = (horizontal ? style.width : style.height)?.resolve(
        percentBase: mainBase,
      );
      final basis = style.basis?.resolve(percentBase: mainBase);
      final minSpec = (horizontal ? style.minWidth : style.minHeight)?.resolve(
        percentBase: mainBase,
      );
      if (horizontal) {
        item.base =
            basis ??
            mainSpec ??
            item.child.getMaxIntrinsicWidth(double.infinity);
        item.minMain =
            minSpec ??
            math.min(
              item.child.getMinIntrinsicWidth(double.infinity),
              mainSpec ?? double.infinity,
            );
      } else {
        // A column child's content height at its width.
        final measure = BoxConstraints(
          minWidth: item.cross,
          maxWidth: item.cross,
        );
        item
          ..size = sizer.size(item.child, measure)
          ..constraints = measure;
        final content = item.size.height;
        item
          ..base = basis ?? mainSpec ?? content
          ..minMain = minSpec ?? math.min(content, mainSpec ?? double.infinity);
      }
      item.hypothetical = clampCss(item.base, item.minMain, item.maxMain);
    }

    // ---- Lines ----
    final lines = <List<_Item>>[];
    final availMain = horizontal ? availW : availH;
    if (flex.wrap == A2uiWrap.nowrap || !availMain.isFinite) {
      if (items.isNotEmpty) lines.add(items);
    } else {
      var line = <_Item>[];
      var used = 0.0;
      for (final item in items) {
        final next = used + (line.isEmpty ? 0 : mainGap) + item.hypothetical;
        if (line.isNotEmpty && next > availMain + 1e-9) {
          lines.add(line);
          line = [item];
          used = item.hypothetical;
        } else {
          line.add(item);
          used = next;
        }
      }
      if (line.isNotEmpty) lines.add(line);
    }

    double lineLength(List<_Item> line) =>
        line.fold<double>(0, (sum, item) => sum + item.hypothetical) +
        mainGap * (line.length - 1);

    // ---- The container's main size ----
    var mainSize = horizontal ? innerW : innerH;
    if (mainSize == null) {
      var longest = 0.0;
      for (final line in lines) {
        longest = math.max(longest, lineLength(line));
      }
      if (!horizontal && ratioHeight != null) {
        longest = math.max(longest, ratioHeight - vInset);
      }
      mainSize = clampCss(
        longest,
        horizontal ? minInnerW : minInnerH,
        horizontal ? availW : availH,
      );
    }

    for (final line in lines) {
      _resolveFlexibleLengths(line, mainSize, mainGap);
    }

    // ---- Cross sizes ----
    final lineCrosses = <double>[];
    for (final line in lines) {
      var lineCross = 0.0;
      var maxAscent = 0.0;
      var maxDescent = 0.0;
      for (final item in line) {
        if (horizontal) {
          final constraints = BoxConstraints(
            minWidth: item.main,
            maxWidth: item.main,
            minHeight: item.crossSpec ?? item.minCross,
            maxHeight: item.crossSpec ?? item.maxCross,
          );
          item
            ..size = sizer.size(item.child, constraints)
            ..constraints = constraints
            ..cross = item.size.height;
          if (item.align == A2uiAlign.baseline) {
            final ascent =
                sizer.baseline(item.child, constraints) ?? item.size.height;
            item.ascent = ascent;
            maxAscent = math.max(maxAscent, ascent);
            maxDescent = math.max(maxDescent, item.size.height - ascent);
          }
        } else if (item.size.height != item.main ||
            item.size.width != item.cross) {
          final constraints = BoxConstraints.tightFor(
            width: item.cross,
            height: item.main,
          );
          item
            ..size = sizer.size(item.child, constraints)
            ..constraints = constraints;
        }
        lineCross = math.max(lineCross, item.cross);
      }
      lineCrosses.add(math.max(lineCross, maxAscent + maxDescent));
    }

    final crossCount = lineCrosses.length;
    final crossGaps = crossGap * math.max(0, crossCount - 1);
    double containerCross;
    if (horizontal) {
      if (innerCross != null && crossCount == 1) {
        lineCrosses[0] = innerCross;
      }
      var total = lineCrosses.fold<double>(0, (a, b) => a + b) + crossGaps;
      if (ratioHeight != null) {
        total = math.max(total, ratioHeight - vInset);
      }
      containerCross =
          innerCross ?? clampCss(total, minInnerH, math.max(minInnerH, availH));
      if (crossCount == 1) lineCrosses[0] = containerCross;
    } else {
      containerCross = innerCross!;
      if (crossCount == 1) lineCrosses[0] = containerCross;
    }
    // align-content: normal stretches the lines over a definite cross size.
    if (crossCount > 1) {
      final extra =
          containerCross - lineCrosses.fold(0.0, (a, b) => a + b) - crossGaps;
      if (extra > 0 && (horizontal ? innerH != null : innerW != null)) {
        for (var i = 0; i < crossCount; i++) {
          lineCrosses[i] += extra / crossCount;
        }
      }
    }

    // ---- Stretch ----
    for (var l = 0; l < lines.length; l++) {
      for (final item in lines[l]) {
        if (!item.stretch) continue;
        final target = clampCss(lineCrosses[l], item.minCross, item.maxCross);
        if (horizontal) {
          if (item.size.height == target) continue;
          final constraints = BoxConstraints.tightFor(
            width: item.main,
            height: target,
          );
          item
            ..size = sizer.size(item.child, constraints)
            ..constraints = constraints
            ..cross = target;
        } else if (crossCount > 1 && item.size.width != target) {
          final constraints = BoxConstraints.tightFor(
            width: target,
            height: item.main,
          );
          item
            ..size = sizer.size(item.child, constraints)
            ..constraints = constraints
            ..cross = target;
        }
      }
    }

    // ---- Positions ----
    final reverse = flex.wrap == A2uiWrap.wrapReverse;
    final rtl = _textDirection == TextDirection.rtl;
    var lineStart = 0.0;
    for (var l = 0; l < lines.length; l++) {
      final line = lines[l];
      final lineCross = lineCrosses[l];
      final lineOffset = reverse
          ? containerCross - lineStart - lineCross
          : lineStart;
      lineStart += lineCross + crossGap;

      final used =
          line.fold<double>(0, (sum, item) => sum + item.main) +
          mainGap * (line.length - 1);
      final free = mainSize - used;
      final autoItems = line.where((i) => i.style.autoMarginStart).length;
      var lead = 0.0;
      var between = mainGap;
      var autoShare = 0.0;
      if (autoItems > 0 && free > 0) {
        autoShare = free / autoItems;
      } else {
        (lead, between) = _justify(flex.justify, free, line.length, mainGap);
      }
      var cursor = lead;
      var maxAscent = 0.0;
      for (final item in line) {
        if (item.ascent != null) maxAscent = math.max(maxAscent, item.ascent!);
      }
      for (final item in line) {
        if (item.style.autoMarginStart) cursor += autoShare;
        final mainPos = cursor;
        cursor += item.main + between;
        final childCross = horizontal ? item.size.height : item.size.width;
        var crossPos = switch (item.align) {
          A2uiAlign.end => lineCross - childCross,
          A2uiAlign.center => (lineCross - childCross) / 2,
          A2uiAlign.baseline => maxAscent - (item.ascent ?? 0),
          A2uiAlign.start || A2uiAlign.stretch => 0.0,
        };
        // wrap-reverse swaps cross-start and cross-end.
        if (reverse) crossPos = lineCross - childCross - crossPos;
        crossPos += lineOffset;
        final double x;
        final double y;
        if (horizontal) {
          x = rtl ? mainSize - mainPos - item.size.width : mainPos;
          y = crossPos;
        } else {
          x = rtl ? containerCross - crossPos - item.size.width : crossPos;
          y = mainPos;
        }
        item.offset = Offset(insets.left + x, insets.top + y);
      }
    }

    // ---- The container's size ----
    final contentW = horizontal ? mainSize : containerCross;
    final contentH = horizontal ? containerCross : mainSize;
    var height = outerH ?? contentH + vInset;
    if (outerH == null && ratioHeight != null) {
      height = math.max(height, ratioHeight);
    }
    final size = constraints.constrain(
      Size(outerW ?? contentW + hInset, height),
    );
    return _Outcome(size, items);
  }

  /// The fit-content cross size of a column child in [available] width:
  /// its max-content width, but no less than its min-content width.
  double _fitCross(_Item item, double available) {
    if (item.crossSpec != null) return item.crossSpec!;
    final child = item.child;
    final maxContent = child.getMaxIntrinsicWidth(double.infinity);
    var fit = maxContent;
    if (available.isFinite && available < maxContent) {
      fit = math.max(child.getMinIntrinsicWidth(double.infinity), available);
    }
    return clampCss(fit, item.minCross, item.maxCross);
  }

  /// CSS 9.7, "Resolving Flexible Lengths": grows or shrinks the items of
  /// [line] to fill [space], freezing those that hit a minimum or maximum.
  static void _resolveFlexibleLengths(
    List<_Item> line,
    double space,
    double gap,
  ) {
    final gaps = gap * (line.length - 1);
    final hypotheticalSum =
        line.fold<double>(0, (sum, item) => sum + item.hypothetical) + gaps;
    if (!space.isFinite) {
      for (final item in line) {
        item.main = item.hypothetical;
      }
      return;
    }
    final growing = hypotheticalSum < space;
    for (final item in line) {
      final factor = growing ? item.style.grow : item.style.shrink;
      item
        ..main = item.hypothetical
        ..frozen =
            factor <= 0 ||
            (growing && item.base > item.hypothetical) ||
            (!growing && item.base < item.hypothetical);
    }
    double used() =>
        line.fold<double>(0, (sum, i) => sum + (i.frozen ? i.main : i.base)) +
        gaps;
    final initialFree = space - used();
    for (var round = 0; round <= line.length; round++) {
      final unfrozen = line.where((i) => !i.frozen).toList();
      if (unfrozen.isEmpty) break;
      var free = space - used();
      final factorSum = unfrozen.fold<double>(
        0,
        (sum, i) => sum + (growing ? i.style.grow : i.style.shrink),
      );
      if (factorSum < 1) {
        final scaled = initialFree * factorSum;
        if (scaled.abs() < free.abs()) free = scaled;
      }
      if (free == 0) {
        for (final item in unfrozen) {
          item.main = item.base;
        }
      } else if (growing) {
        for (final item in unfrozen) {
          item.main = item.base + free * item.style.grow / factorSum;
        }
      } else {
        final scaledSum = unfrozen.fold<double>(
          0,
          (sum, i) => sum + i.style.shrink * i.base,
        );
        for (final item in unfrozen) {
          item.main = scaledSum == 0
              ? item.base
              : item.base + free * (item.style.shrink * item.base) / scaledSum;
        }
      }
      var violation = 0.0;
      for (final item in unfrozen) {
        final clamped = clampCss(item.main, item.minMain, item.maxMain);
        item
          ..violation = clamped - item.main
          ..main = clamped;
        violation += item.violation;
      }
      for (final item in unfrozen) {
        if (violation == 0 ||
            (violation > 0 && item.violation > 0) ||
            (violation < 0 && item.violation < 0)) {
          item.frozen = true;
        }
      }
    }
    for (final item in line) {
      item.main = math.max<double>(0, item.main);
    }
  }

  /// The space before the first item and between items for `justify` with
  /// [free] space left on a line of [count] items.
  static (double, double) _justify(
    A2uiJustify? justify,
    double free,
    int count,
    double gap,
  ) {
    switch (justify) {
      case A2uiJustify.end:
        return (free, gap);
      case A2uiJustify.center:
        return (free / 2, gap);
      case A2uiJustify.spaceBetween:
        if (free <= 0 || count < 2) return (0, gap);
        return (0, gap + free / (count - 1));
      case A2uiJustify.spaceAround:
        if (free <= 0 || count < 2) return (free / 2, gap);
        return (free / count / 2, gap + free / count);
      case A2uiJustify.spaceEvenly:
        if (free <= 0 || count < 2) return (free / 2, gap);
        return (free / (count + 1), gap + free / (count + 1));
      case A2uiJustify.start:
      case A2uiJustify.stretch:
      case null:
        return (0, gap);
    }
  }

  // ---- Paint and hit testing ----

  @override
  void paint(PaintingContext context, Offset offset) {
    final decoration = _box.decoration;
    if (decoration != null) {
      _painter ??= decoration.createBoxPainter(markNeedsPaint);
      _painter!.paint(
        context.canvas,
        offset,
        configuration.copyWith(size: size, textDirection: _textDirection),
      );
    }
    if (_box.clip) {
      final clip = _overflowClip;
      _clipLayer.layer = context.pushClipRRect(
        needsCompositing,
        offset,
        clip.outerRect,
        clip,
        defaultPaint,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
      defaultPaint(context, offset);
    }
  }

  /// Where `overflow: hidden` clips the content (RULEBOOK section 2, the
  /// overflow row): the padding box, inside the border (CSS Overflow 3,
  /// section 3.1, "the overflow clip edge" is the padding edge), whose
  /// corners are the border's less that side's border width, never below
  /// zero (CSS Backgrounds 3, section 5.3, "the inner border radius").
  RRect get _overflowClip {
    final radius =
        _box.decoration?.borderRadius?.resolve(_textDirection) ??
        BorderRadius.zero;
    final border = _box.borderWidth;
    Radius inner(Radius outer) => Radius.elliptical(
      math.max(0, outer.x - border),
      math.max(0, outer.y - border),
    );
    return RRect.fromRectAndCorners(
      (Offset.zero & size).deflate(border),
      topLeft: inner(radius.topLeft),
      topRight: inner(radius.topRight),
      bottomRight: inner(radius.bottomRight),
      bottomLeft: inner(radius.bottomLeft),
    );
  }

  /// A clipped box hit-tests its content only inside its clip: content cut
  /// off by `overflow: hidden` takes no hit there, as in a browser.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_box.clip && !_overflowClip.contains(position)) return false;
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<Axis>('direction', _flex.direction))
      ..add(EnumProperty<A2uiWrap>('wrap', _flex.wrap))
      ..add(EnumProperty<A2uiJustify>('justify', _flex.justify))
      ..add(EnumProperty<A2uiAlign>('align', _flex.align))
      ..add(DoubleProperty('rowGap', _flex.rowGap))
      ..add(DoubleProperty('columnGap', _flex.columnGap))
      ..add(DiagnosticsProperty<EdgeInsets>('padding', _box.padding));
  }
}

// PORT STATUS: confidence=medium todos=0 upstream=none
