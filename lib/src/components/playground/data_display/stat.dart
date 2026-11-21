import 'dart:math' as math;

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/components/playground/data_display/kpi.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/icons/lucide.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_grid.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/theme/playground_tokens.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The playground `Stat`: one KPI in a card.
///
/// The label (12px, medium, muted, one line) sits over the value, with the
/// Lucide `icon` in a 24px tile on the right (tinted by `tone`, grey for
/// `default`). The value's size follows the card's width (up to 26px, see
/// [KpiValue]); the `delta` follows it on the same line when it fits, with
/// an arrow from `trend` or its sign. The `caption` is 11px, at most two
/// lines. A `tone` other than `default` colours the value.
Widget buildStat(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = StatProps(props);
  final tokens = playgroundTokens(context);
  final tone = view.tone ?? A2uiTone.default_;
  // `iconFor(props.icon)` (`renderers/data.tsx:738`), in lucide-react
  // 1.57.0's `icons`.
  final icon = lucideIcon(view.icon, release: LucideRelease.playground);
  final caption = view.caption;
  // `black/[.04]`, `dark:white/[.04]`.
  final neutral = A2uiKitScope.themeOf(context).brightness == Brightness.dark
      ? const Color(0xffffffff)
      : const Color(0xff000000);
  return InlineSizeContainer(
    inset: 34,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: playgroundCardDecoration(tokens),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: tokens.foreground),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    playgroundString(props.value('label')),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: playgroundText(
                      12,
                      weight: FontWeight.w500,
                      color: tokens.mutedForeground,
                    ),
                  ),
                ),
                if (icon != null)
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tone == A2uiTone.default_
                          ? neutral.withValues(alpha: .04)
                          : _soft(tokens, tone),
                      border: Border.all(
                        color: tone == A2uiTone.default_
                            ? neutral.withValues(alpha: .08)
                            : _softBorder(tokens, tone),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: LucideGlyph(
                      icon,
                      size: 14,
                      color: tone == A2uiTone.default_
                          ? tokens.mutedForeground
                          : tokens.toneColor(tone),
                    ),
                  ),
              ],
            ),
            KpiLine(
              value: KpiValue(
                value: props.value('value'),
                maxFontSize: 26,
                color: tone == A2uiTone.default_
                    ? null
                    : tokens.toneColor(tone),
              ),
              delta: view.delta == null || view.delta!.isEmpty
                  ? null
                  : KpiDelta(delta: view.delta, trend: view.trend),
            ),
            if (caption != null && caption.isNotEmpty)
              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: playgroundText(
                  11,
                  height: 1.375,
                  color: tokens.mutedForeground.withValues(
                    alpha: tokens.mutedForeground.a * .8,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// A tone's `soft` fill: the tone at 13% (14% for the accent).
Color _soft(A2uiPlaygroundTokens tokens, A2uiTone tone) => tokens
    .toneColor(tone)
    .withValues(alpha: tone == A2uiTone.accent ? .14 : .13);

/// A tone's `soft` border: the tone at 24% (26% for the accent).
Color _softBorder(A2uiPlaygroundTokens tokens, A2uiTone tone) => tokens
    .toneColor(tone)
    .withValues(alpha: tone == A2uiTone.accent ? .26 : .24);

/// The playground `StatGroup`: KPIs in one card, in as many 132px-or-wider
/// columns as fit, split by 1px lines. Each cell has its label, its value
/// (up to 22px) and its delta. Without items it is an empty 80px card.
Widget buildStatGroup(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final tokens = playgroundTokens(context);
  final items = [
    for (final raw in StatGroupProps(props).items)
      if (ComponentProps.unwrap(raw) case final Map<Object?, Object?> item)
        item,
  ];
  Widget cell(Map<Object?, Object?> item) {
    final delta = ComponentProps.unwrap(item['delta']);
    return InlineSizeContainer(
      inset: 32,
      child: ColoredBox(
        color: tokens.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(
                playgroundString(ComponentProps.unwrap(item['label'])),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: playgroundText(
                  12,
                  weight: FontWeight.w500,
                  color: tokens.mutedForeground,
                ),
              ),
              KpiValue(
                value: ComponentProps.unwrap(item['value']),
                maxFontSize: 22,
              ),
              if (delta is String && delta.isNotEmpty)
                KpiDelta(
                  delta: delta,
                  trend: A2uiTrend.fromWire(
                    ComponentProps.unwrap(item['trend']),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  final Widget grid = items.isEmpty
      ? SizedBox(height: 80, child: ColoredBox(color: tokens.surface))
      : CssGrid(
          columns: const GridColumns.autoFit(count: 1 << 20, minTrack: 132),
          rowGap: 1,
          columnGap: 1,
          children: [
            for (final item in items)
              CssGridItem(placement: GridPlacement.cell, child: cell(item)),
          ],
        );
  return InlineSizeContainer(
    inset: 2,
    child: Container(
      decoration: playgroundCardDecoration(tokens),
      clipBehavior: Clip.antiAlias,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: tokens.foreground),
        // The grid's gaps show its line-coloured background.
        child: ColoredBox(color: tokens.line, child: grid),
      ),
    ),
  );
}

/// A KPI value and its delta on one baseline, `gap-x-2`, the delta on the
/// next line (`gap-y-1`) when both do not fit. The value is measured
/// against the full width, which is its container's (the KPI's font follows
/// it).
class KpiLine extends MultiChildRenderObjectWidget {
  /// The [value] and its [delta].
  KpiLine({required Widget value, Widget? delta, super.key})
    : super(children: [value, ?delta]);

  @override
  RenderKpiLine createRenderObject(BuildContext context) => RenderKpiLine();
}

/// The parent data of [RenderKpiLine].
class KpiLineParentData extends ContainerBoxParentData<RenderBox> {}

/// The render object of [KpiLine].
class RenderKpiLine extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, KpiLineParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, KpiLineParentData> {
  static const double _gapX = 8;
  static const double _gapY = 4;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! KpiLineParentData) {
      child.parentData = KpiLineParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    var width = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      width = math.max(width, child.getMinIntrinsicWidth(height));
    }
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var width = 0.0;
    var count = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      width += child.getMaxIntrinsicWidth(height);
      count++;
    }
    return width + _gapX * math.max(0, count - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _layout(BoxConstraints(maxWidth: width), dry: true).$1.height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _layout(BoxConstraints(maxWidth: width), dry: true).$1.height;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true).$1;

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => _layout(constraints, dry: true).$2;

  @override
  void performLayout() => size = _layout(constraints, dry: false).$1;

  /// The size, and the value's alphabetic baseline.
  (Size, double?) _layout(BoxConstraints constraints, {required bool dry}) {
    final width = constraints.maxWidth;
    final childConstraints = BoxConstraints(maxWidth: width);
    final value = firstChild;
    if (value == null) return (constraints.constrain(Size.zero), null);
    final delta = childAfter(value);
    Size sizeOf(RenderBox child) => dry
        ? child.getDryLayout(childConstraints)
        : (child..layout(childConstraints, parentUsesSize: true)).size;
    double baselineOf(RenderBox child, Size size) =>
        (dry
            ? child.getDryBaseline(childConstraints, TextBaseline.alphabetic)
            : child.getDistanceToBaseline(TextBaseline.alphabetic)) ??
        size.height;
    final valueSize = sizeOf(value);
    final valueBaseline = baselineOf(value, valueSize);
    if (delta == null) {
      if (!dry) (value.parentData! as KpiLineParentData).offset = Offset.zero;
      return (constraints.constrain(valueSize), valueBaseline);
    }
    final deltaSize = sizeOf(delta);
    final deltaBaseline = baselineOf(delta, deltaSize);
    final oneLine = valueSize.width + _gapX + deltaSize.width <= width;
    Offset valueAt;
    Offset deltaAt;
    double height;
    if (oneLine) {
      final baseline = math.max(valueBaseline, deltaBaseline);
      valueAt = Offset(0, baseline - valueBaseline);
      deltaAt = Offset(valueSize.width + _gapX, baseline - deltaBaseline);
      height = math.max(
        valueAt.dy + valueSize.height,
        deltaAt.dy + deltaSize.height,
      );
    } else {
      valueAt = Offset.zero;
      deltaAt = Offset(0, valueSize.height + _gapY);
      height = deltaAt.dy + deltaSize.height;
    }
    if (!dry) {
      (value.parentData! as KpiLineParentData).offset = valueAt;
      (delta.parentData! as KpiLineParentData).offset = deltaAt;
    }
    final contentWidth = oneLine
        ? valueSize.width + _gapX + deltaSize.width
        : math.max(valueSize.width, deltaSize.width);
    return (
      constraints.constrain(
        Size(constraints.hasBoundedWidth ? width : contentWidth, height),
      ),
      valueAt.dy + valueBaseline,
    );
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}

// PORT STATUS: confidence=medium todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/data.tsx
