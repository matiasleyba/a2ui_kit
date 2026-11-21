import 'dart:math' as math;

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The playground `KeyValueList`: label and value rows in a card, such as
/// specs or order details.
///
/// An optional `title` (13px semibold) heads it. Each row has the label
/// (12.5px, muted) on the left and the value (13px medium, numbers in en-US
/// with grouping) and its `hint` (11px) on the right, on one baseline, with
/// a dashed line under every row but the last. In a card narrower than
/// 256px the label sits over the value. `columns` (1 to 3) splits the rows
/// into two columns from a 448px card and three from 672px, 24px apart.
Widget buildKeyValueList(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = KeyValueListProps(props);
  final tokens = playgroundTokens(context);
  final columns = (view.columns ?? 1).round().clamp(1, 3);
  final title = view.title;
  final children = <Widget>[];
  for (final raw in view.items) {
    final item = ComponentProps.unwrap(raw);
    if (item is! Map) continue;
    final value = ComponentProps.unwrap(item['value']);
    final hint = ComponentProps.asString(item['hint']);
    final valueText = value is num
        ? formatPlaygroundNumber(value)
        : playgroundString(value);
    final valueStyle = playgroundText(
      13,
      weight: FontWeight.w500,
      color: tokens.foreground,
      tabular: true,
    );
    final hintStyle = playgroundText(
      11,
      color: tokens.mutedForeground.withValues(
        alpha: tokens.mutedForeground.a * .8,
      ),
    );
    Widget valueColumn({required bool end}) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          valueText,
          textAlign: end ? TextAlign.right : TextAlign.left,
          style: valueStyle,
        ),
        if (hint != null && hint.isNotEmpty)
          Text(
            hint,
            textAlign: end ? TextAlign.right : TextAlign.left,
            style: hintStyle,
          ),
      ],
    );
    children
      ..add(
        Text(
          playgroundString(ComponentProps.unwrap(item['label'])),
          style: playgroundText(12.5, color: tokens.mutedForeground),
        ),
      )
      ..add(valueColumn(end: true))
      ..add(valueColumn(end: false));
  }
  return InlineSizeContainer(
    inset: 34,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: playgroundCardDecoration(tokens),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          if (title != null && title.isNotEmpty)
            Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: playgroundText(
                  13,
                  weight: FontWeight.w600,
                  trackingEm: -.025,
                  color: tokens.foreground,
                ),
              ),
            ),
          KeyValueGrid(
            columns: columns,
            lineColor: tokens.line,
            children: children,
          ),
        ],
      ),
    ),
  );
}

/// The rows of a KeyValueList: three children per row (the label, the
/// value aligned to the end, the value aligned to the start), laid out by
/// the list's width as the playground's container queries do.
class KeyValueGrid extends MultiChildRenderObjectWidget {
  /// Rows of [children], three per row.
  const KeyValueGrid({
    required this.columns,
    required this.lineColor,
    super.children,
    super.key,
  });

  /// The most columns (1 to 3).
  final int columns;

  /// The colour of the dashed lines between rows.
  final Color lineColor;

  @override
  RenderKeyValueGrid createRenderObject(BuildContext context) =>
      RenderKeyValueGrid(columns: columns, lineColor: lineColor);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderKeyValueGrid renderObject,
  ) {
    renderObject
      ..columns = columns
      ..lineColor = lineColor;
  }
}

/// The parent data of [RenderKeyValueGrid].
class KeyValueGridParentData extends ContainerBoxParentData<RenderBox> {
  /// Whether the child shows in the current layout.
  bool visible = true;
}

/// The render object of [KeyValueGrid].
class RenderKeyValueGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, KeyValueGridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, KeyValueGridParentData> {
  /// A grid of at most [columns] columns.
  RenderKeyValueGrid({required int columns, required Color lineColor})
    : _columns = columns,
      _lineColor = lineColor;

  int _columns;

  /// The most columns.
  int get columns => _columns;
  set columns(int value) {
    if (value == _columns) return;
    _columns = value;
    markNeedsLayout();
  }

  Color _lineColor;

  /// The colour of the dashed lines.
  Color get lineColor => _lineColor;
  set lineColor(Color value) {
    if (value == _lineColor) return;
    _lineColor = value;
    markNeedsPaint();
  }

  /// The bottoms of the rows' cells that draw a line: (left, right, y).
  final List<(double, double, double)> _lines = [];

  static const double _columnGap = 24;
  static const double _labelGap = 16;
  static const double _rowPadding = 8;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! KeyValueGridParentData) {
      child.parentData = KeyValueGridParentData();
    }
  }

  /// The columns at [width]: two from 448px (28rem), three from 672px
  /// (42rem), up to [columns].
  int columnsAt(double width) {
    if (_columns >= 3 && width >= 672) return 3;
    if (_columns >= 2 && width >= 448) return 2;
    return 1;
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) {
    var width = 0.0;
    var child = firstChild;
    while (child != null) {
      final label = child.getMaxIntrinsicWidth(height);
      final end = childAfter(child)!;
      final value = end.getMaxIntrinsicWidth(height);
      width = math.max(width, label + _labelGap + value);
      child = childAfter(childAfter(end)!);
    }
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _layout(BoxConstraints(maxWidth: width), dry: true).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _layout(BoxConstraints(maxWidth: width), dry: true).height;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => null;

  @override
  void performLayout() => size = _layout(constraints, dry: false);

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : computeMaxIntrinsicWidth(double.infinity);
    final cols = columnsAt(width);
    final stacked = width < 256;
    final colWidth = math.max<double>(
      0,
      (width - _columnGap * (cols - 1)) / cols,
    );
    if (!dry) _lines.clear();

    Size place(RenderBox child, BoxConstraints c, Offset at) {
      final data = child.parentData! as KeyValueGridParentData;
      if (dry) return child.getDryLayout(c);
      child.layout(c, parentUsesSize: true);
      data
        ..offset = at
        ..visible = true;
      return child.size;
    }

    double baseline(RenderBox child, BoxConstraints c, Size size) =>
        (dry
            ? child.getDryBaseline(c, TextBaseline.alphabetic)
            : child.getDistanceToBaseline(TextBaseline.alphabetic)) ??
        size.height;

    final cells = <({RenderBox label, RenderBox end, RenderBox start})>[];
    var child = firstChild;
    while (child != null) {
      final end = childAfter(child)!;
      final start = childAfter(end)!;
      cells.add((label: child, end: end, start: start));
      child = childAfter(start);
    }

    var y = 0.0;
    for (var row = 0; row * cols < cells.length; row++) {
      var rowHeight = 0.0;
      final placed = <(int, double, double)>[];
      for (var col = 0; col < cols; col++) {
        final index = row * cols + col;
        if (index >= cells.length) break;
        final cell = cells[index];
        final x = col * (colWidth + _columnGap);
        double contentHeight;
        if (stacked) {
          final c = BoxConstraints.tightFor(width: colWidth);
          final labelSize = place(cell.label, c, Offset(x, y + _rowPadding));
          final valueSize = place(
            cell.start,
            c,
            Offset(x, y + _rowPadding + labelSize.height + 2),
          );
          if (!dry) {
            (cell.end.parentData! as KeyValueGridParentData).visible = false;
          }
          contentHeight = labelSize.height + 2 + valueSize.height;
        } else {
          final labelMax = cell.label.getMaxIntrinsicWidth(double.infinity);
          final labelWidth = math.min(
            labelMax,
            math.max<double>(0, colWidth - _labelGap),
          );
          final valueWidth = math.max<double>(
            0,
            colWidth - _labelGap - labelWidth,
          );
          final labelC = BoxConstraints.tightFor(width: labelWidth);
          final valueC = BoxConstraints.tightFor(width: valueWidth);
          final labelSize = dry
              ? cell.label.getDryLayout(labelC)
              : (cell.label..layout(labelC, parentUsesSize: true)).size;
          final valueSize = dry
              ? cell.end.getDryLayout(valueC)
              : (cell.end..layout(valueC, parentUsesSize: true)).size;
          final labelBase = baseline(cell.label, labelC, labelSize);
          final valueBase = baseline(cell.end, valueC, valueSize);
          final line = math.max(labelBase, valueBase);
          if (!dry) {
            (cell.label.parentData! as KeyValueGridParentData)
              ..offset = Offset(x, y + _rowPadding + line - labelBase)
              ..visible = true;
            (cell.end.parentData! as KeyValueGridParentData)
              ..offset = Offset(
                x + labelWidth + _labelGap,
                y + _rowPadding + line - valueBase,
              )
              ..visible = true;
            (cell.start.parentData! as KeyValueGridParentData).visible = false;
          }
          contentHeight = math.max(
            line - labelBase + labelSize.height,
            line - valueBase + valueSize.height,
          );
        }
        final height = contentHeight + _rowPadding * 2;
        rowHeight = math.max(rowHeight, height);
        placed.add((index, x, colWidth));
      }
      y += rowHeight;
      if (!dry) {
        for (final (index, x, w) in placed) {
          // `last:border-b-0`: every item but the last has a line.
          if (index != cells.length - 1) _lines.add((x, x + w, y - .5));
        }
      }
    }
    if (!dry) {
      // The value of the other mode is hidden, but still laid out.
      for (final cell in cells) {
        (stacked ? cell.end : cell.start).layout(
          BoxConstraints(maxWidth: colWidth),
        );
      }
    }
    return constraints.constrain(Size(width, y));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final data = child.parentData! as KeyValueGridParentData;
      if (data.visible) {
        final hit = result.addWithPaintOffset(
          offset: data.offset,
          position: position,
          hitTest: (result, transformed) =>
              child!.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitChildren((child) {
      if ((child.parentData! as KeyValueGridParentData).visible) {
        visitor(child);
      }
    });
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final paint = Paint()
      ..color = _lineColor
      ..strokeWidth = 1;
    for (final (left, right, y) in _lines) {
      // A dashed CSS border: dashes about three times the width.
      for (var x = left; x < right; x += 6) {
        context.canvas.drawLine(
          offset + Offset(x, y),
          offset + Offset(math.min(x + 3, right), y),
          paint,
        );
      }
    }
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as KeyValueGridParentData;
      if (data.visible) context.paintChild(child, offset + data.offset);
      child = data.nextSibling;
    }
  }
}

// PORT STATUS: confidence=medium todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/data.tsx
