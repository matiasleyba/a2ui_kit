// An HTML table laid out as chromium@159.0.8154.13 lays one out (LayoutNG's
// table layout, BSD-3-Clause, see NOTICE.md), for what CopilotKit's Table
// reaches: `border-collapse: collapse` with no border spacing, no `<col>`
// elements, no `visibility: collapse`, no caption in flow (CopilotKit's is
// visually hidden), no row, section or table height, cells aligned to the
// top, middle or bottom (never the baseline), left to right.
//
// Ported from third_party/blink/renderer/core/layout/table/:
// - table_layout_algorithm_types.cc: `CreateCellInlineConstraint` (:122-196),
//   `CellInlineConstraint::Encompass` (:219-243), `Column::Encompass`
//   (:245-279);
// - table_layout_utils.cc: `ComputeSectionInlineConstraints` (:398-459),
//   `ApplyCellConstraintsToColumnConstraints` (:88-170),
//   `EnsureDistributableColumnExists` (:65-84),
//   `DistributeInlineSizeToComputedInlineSizeAuto` (:466-777),
//   `SynchronizeAssignableTableInlineSizeAndColumnsFixed` (:779-927),
//   `DistributeColspanCellToColumnsFixed` (:929-1008) and `…Auto`
//   (:1010-1124), `DistributeExcessBlockSizeToRows` (:1130-1332),
//   `ComputeMinimumRowBlockSize` (:172-334),
//   `ComputeSectionMinimumRowBlockSizes` (:1490-1576),
//   `FinalizeTableCellLayout` (:1578-1643, the cell's alignment),
//   `ColspanCellTabulator` (:1645-1681), `ComputeGridInlineMinMax`
//   (:1746-1827);
// - table_layout_algorithm.cc: `ComputeEmptyTableInlineSize` (:224-252),
//   `ComputeAssignableTableInlineSize` (:254-291),
//   `ComputeLocationsFromColumns` (:293-332), `ComputeMinMaxSizes`
//   (:735-766);
// - table_layout_algorithm_types.h: `RowspanCell::operator<` (:155-177),
//   `Column::ResolvePercentInlineSize` (:103-109), `kTableMaxInlineSize`
//   (:25);
// - table_borders.cc: `GetCellBorders` (:335-385, half of each collapsed
//   edge to each cell beside it) and `ComputeTableBorders` (:114-200).
//
// Chromium's LayoutUnit is a 1/64 px fixed point; these sizes are doubles,
// so a distribution may differ by under a 64th of a pixel.

import 'dart:math' as math;

import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/functions/calc.dart' show jsNumberString;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// `TableTypes::kTableMaxInlineSize` (table_layout_algorithm_types.h:25).
const double _tableMaxInlineSize = 1000000;

/// The span a `colspan` or `rowspan` attribute set from the number
/// [value] gives (React writes `String(value)`): HTML's rules for parsing
/// a non-negative integer, white space and a leading `+` allowed and
/// anything after the digits ignored, then clamped to [min]..[max]
/// (html_table_cell_element.cc:45-63, html_parser_idioms.cc:174-241:
/// `colspan` 1 to 1000, `rowspan` 0 to 65534, table_constants.h:13-20).
/// A missing value or one that does not parse (a negative number, NaN) is
/// the default, 1.
int htmlSpanOf(Object? value, {required int min, required int max}) {
  final text = switch (value) {
    final num n => jsNumberString(n),
    final String s => s,
    _ => null,
  };
  if (text == null) return 1;
  final match = RegExp(r'^[\t\n\f\r ]*(-0+|\+?(\d+))').firstMatch(text);
  if (match == null) return 1;
  final digits = match[2];
  if (digits == null) return math.max(min, 0);
  final parsed = int.tryParse(digits);
  // Too large for an unsigned int: clamped to the maximum (kOverflowMax).
  if (parsed == null || parsed > 4294967295) return max;
  return parsed.clamp(min, max);
}

/// A row of an [HtmlTable], in display order: its row group and its
/// semantics (the envelope of a `<tr>`).
@immutable
class HtmlTableRow {
  /// A row of row group [group].
  const HtmlTableRow({
    required this.group,
    this.label,
    this.hint,
    this.live = false,
    this.hidden = false,
  });

  /// The row group (`<thead>` or `<tbody>`) in display order; a rowspan
  /// ends with its group.
  final int group;

  /// The row's name for screen readers.
  final String? label;

  /// The row's description for screen readers.
  final String? hint;

  /// Whether the row is a live region.
  final bool live;

  /// Whether the row is hidden from screen readers (`aria-hidden`): it has
  /// no node, and its cells none either.
  final bool hidden;

  @override
  bool operator ==(Object other) =>
      other is HtmlTableRow &&
      other.group == group &&
      other.label == label &&
      other.hint == hint &&
      other.live == live &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(group, label, hint, live, hidden);
}

/// The semantics tag of the nodes of the cells of row [row], so an
/// [HtmlTable] can put each cell's node in its row's node.
@immutable
class HtmlTableRowTag extends SemanticsTag {
  /// The tag of row [row].
  const HtmlTableRowTag(this.row) : super('HtmlTableRowTag');

  /// The row, in display order.
  final int row;

  @override
  bool operator ==(Object other) =>
      other is HtmlTableRowTag && other.row == row;

  @override
  int get hashCode => row.hashCode;
}

/// The parent data of a cell of an [HtmlTable].
class HtmlTableCellData extends ContainerBoxParentData<RenderBox> {
  /// The cell's place and style.
  HtmlTableCellStyle style = const HtmlTableCellStyle(row: 0);
}

/// Where a cell of an [HtmlTable] sits and how it is drawn.
@immutable
class HtmlTableCellStyle {
  /// A cell of row [row].
  const HtmlTableCellStyle({
    required this.row,
    this.colSpan = 1,
    this.rowSpan = 1,
    this.width,
    this.inlinePadding = 0,
    this.vAlign = 0,
    this.divider = false,
    this.sticky = false,
  });

  /// The row, in display order.
  final int row;

  /// The columns it spans, 1 to 1000.
  final int colSpan;

  /// The rows it spans; 0 spans to the end of its row group (HTML's
  /// `rowspan="0"`).
  final int rowSpan;

  /// The CSS `width` of its content box, or null for `auto`.
  final A2uiLength? width;

  /// Its padding left and right, which a content-box width adds to.
  final double inlinePadding;

  /// Where its content sits in a taller cell: 0 top, .5 middle, 1 bottom.
  final double vAlign;

  /// Whether a 1px border runs under it (collapsed with its neighbours').
  final bool divider;

  /// Whether it is a pinned header cell (`position: sticky; top: 0`),
  /// painted over the rows that scroll under it.
  final bool sticky;

  @override
  bool operator ==(Object other) =>
      other is HtmlTableCellStyle &&
      other.row == row &&
      other.colSpan == colSpan &&
      other.rowSpan == rowSpan &&
      other.width == width &&
      other.inlinePadding == inlinePadding &&
      other.vAlign == vAlign &&
      other.divider == divider &&
      other.sticky == sticky;

  @override
  int get hashCode => Object.hash(
    row,
    colSpan,
    rowSpan,
    width,
    inlinePadding,
    vAlign,
    divider,
    sticky,
  );
}

/// Gives a child of an [HtmlTable] its place and style.
class HtmlTableCell extends ParentDataWidget<HtmlTableCellData> {
  /// Places [child] as [style] says.
  const HtmlTableCell({required this.style, required super.child, super.key});

  /// The cell's place and style.
  final HtmlTableCellStyle style;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as HtmlTableCellData;
    if (data.style != style) {
      data.style = style;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => HtmlTable;
}

/// The box of a cell's content, with a cell's baseline: its first line's,
/// else the bottom of its content edge, [bottomPadding] above the box's
/// bottom (CSS 2.1 section 17.5.3), at layout and dry alike, so the
/// proxies above it never fall back to `RenderBox.computeDryBaseline`
/// (which asserts in debug).
class HtmlTableCellBox extends SingleChildRenderObjectWidget {
  /// The content box of a cell padded [bottomPadding] at its bottom.
  const HtmlTableCellBox({
    required this.bottomPadding,
    required super.child,
    super.key,
  });

  /// The padding between the content edge and the box's bottom.
  final double bottomPadding;

  @override
  RenderHtmlTableCellBox createRenderObject(BuildContext context) =>
      RenderHtmlTableCellBox(bottomPadding);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHtmlTableCellBox renderObject,
  ) => renderObject.bottomPadding = bottomPadding;
}

/// The render object of [HtmlTableCellBox].
class RenderHtmlTableCellBox extends RenderProxyBox {
  /// A cell box padded [_bottomPadding] at its bottom.
  RenderHtmlTableCellBox(this._bottomPadding);

  double _bottomPadding;

  /// The padding between the content edge and the box's bottom.
  double get bottomPadding => _bottomPadding;
  set bottomPadding(double value) {
    if (value == _bottomPadding) return;
    _bottomPadding = value;
    markNeedsLayout();
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      child?.getDistanceToActualBaseline(baseline) ??
      math.max(0, size.height - _bottomPadding);

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return 0;
    return child.getDryBaseline(constraints, baseline) ??
        math.max(0, child.getDryLayout(constraints).height - _bottomPadding);
  }
}

/// An HTML table of cells (each an [HtmlTableCell], in row order, row by
/// row): its columns and rows sized as Chromium sizes them, its collapsed
/// row dividers drawn, and the semantics of a table (a table node, a row
/// node per row, a node per cell).
///
/// It is as wide as the width an [HtmlTableWidth] around it is offered
/// (CSS `width: 100%`), or its cells' min-content when that is wider; with
/// [fixed] (`table-layout: fixed`) the first row's widths decide the
/// columns and the rest share the width equally. With no width to take it
/// is as wide as its content.
class HtmlTable extends MultiChildRenderObjectWidget {
  /// A table of [rows] and [children].
  const HtmlTable({
    required this.rows,
    required this.dividerColor,
    this.fixed = false,
    this.caption,
    this.sticky,
    this.stickyBackground,
    super.children,
    super.key,
  });

  /// The rows, in display order.
  final List<HtmlTableRow> rows;

  /// The colour of the row dividers.
  final Color dividerColor;

  /// `table-layout: fixed`.
  final bool fixed;

  /// The table's name for screen readers (its `<caption>`).
  final String? caption;

  /// The scroll the sticky cells stay pinned in, when they are.
  final ScrollController? sticky;

  /// The background of the sticky cells.
  final Color? stickyBackground;

  @override
  RenderHtmlTable createRenderObject(BuildContext context) => RenderHtmlTable(
    rows: rows,
    dividerColor: dividerColor,
    fixed: fixed,
    caption: caption,
    sticky: sticky,
    stickyBackground: stickyBackground,
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
  );

  @override
  void updateRenderObject(BuildContext context, RenderHtmlTable renderObject) {
    renderObject
      ..rows = rows
      ..dividerColor = dividerColor
      ..fixed = fixed
      ..caption = caption
      ..sticky = sticky
      ..stickyBackground = stickyBackground
      ..textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
  }
}

/// Hands an [HtmlTable] inside it the width its `100%` resolves against:
/// the width offered to this box, around the scroll views that give the
/// table an unbounded one. Its own min-content width is zero (a scroll
/// container with `min-width: 0`, styles.ts:73), its max-content the
/// table's.
class HtmlTableWidth extends SingleChildRenderObjectWidget {
  /// Hands the width offered to the table in [child].
  const HtmlTableWidth({required super.child, super.key});

  @override
  RenderHtmlTableWidth createRenderObject(BuildContext context) =>
      RenderHtmlTableWidth();
}

/// The render object of [HtmlTableWidth].
class RenderHtmlTableWidth extends RenderProxyBox {
  RenderHtmlTable? _table;

  @override
  void performLayout() {
    final table = _table;
    final base = constraints.hasBoundedWidth ? constraints.maxWidth : null;
    if (table != null && table._percentBase != base) {
      // The table lays out inside this box's child, after this callback.
      invokeLayoutCallback<BoxConstraints>((_) => table.percentBase = base);
    }
    super.performLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  // The wrapper is a scroll container (`overflow-x: auto`, styles.ts:73):
  // its baseline is its bottom edge, as a scroll container's last baseline
  // is its block-end margin edge (CSS Align 3, section 9.1; an inline-block
  // with overflow, CSS 2.1 section 10.8.1). The same dry: Flutter's scroll
  // viewport inside it answers no dry baseline (it throws in debug), and a
  // null here made a proxy above fall back to `RenderBox.computeDryBaseline`,
  // which throws too.
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => size.height;

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => getDryLayout(constraints).height;
}

class _Cell {
  _Cell(this.child, this.style);

  final RenderBox child;
  final HtmlTableCellStyle style;
  int column = 0;
  int rowSpan = 1;
  double borderTop = 0;
  double borderBottom = 0;
  double x = 0;
  double width = 0;
  double height = 0;
  Offset offset = Offset.zero;
}

/// `TableTypes::CellInlineConstraint`.
class _CellInline {
  _CellInline({
    required this.min,
    required this.max,
    required this.percent,
    required this.percentBorderPadding,
    required this.constrained,
  });

  double min;
  double max;
  double? percent;
  double percentBorderPadding;
  bool constrained;

  /// `CellInlineConstraint::Encompass` (table_layout_algorithm_types.cc:
  /// 219-243).
  void encompass(_CellInline other) {
    if (other.min > min) min = other.min;
    if (constrained == other.constrained) {
      max = math.max(max, other.max);
    } else if (constrained) {
      max = math.max(max, other.min);
    } else {
      max = math.max(min, other.max);
    }
    constrained = constrained || other.constrained;
    if (_greater(other.percent, percent)) {
      percent = other.percent;
      percentBorderPadding = other.percentBorderPadding;
    }
  }
}

/// `std::optional<float>`'s `>`: an empty value is below every value.
bool _greater(double? a, double? b) => a != null && (b == null || a > b);

/// `TableTypes::Column`.
class _Column {
  _Column({required this.tableFixed, required this.mergeable});

  double? min;
  double? max;
  double? percent;
  double percentBorderPadding = 0;
  bool constrained = false;
  final bool tableFixed;
  bool mergeable;

  /// `Column::IsFixed` (table_layout_algorithm_types.h:110-112).
  bool get isFixed => constrained && percent == null && max != null;

  /// `Column::ResolvePercentInlineSize`.
  double resolvePercent(double size) =>
      math.max(min ?? 0, percent! * size / 100 + percentBorderPadding);

  /// `Column::Encompass` (table_layout_algorithm_types.cc:245-279).
  void encompass(_CellInline? cell) {
    if (cell == null) return;
    // Constrained columns in fixed tables take precedence over cells.
    if (constrained && tableFixed) return;
    if (!tableFixed) mergeable = false;
    final min = this.min;
    if (min != null) {
      if (min < cell.min) this.min = cell.min;
      if (constrained) {
        max = cell.constrained
            ? math.max(max!, cell.max)
            : math.max(max!, cell.min);
      } else {
        max = math.max(max ?? 0, cell.max);
      }
    } else {
      this.min = cell.min;
      max = cell.max;
    }
    if (this.min != null && max != null) max = math.max(this.min!, max!);
    if (_greater(cell.percent, percent)) {
      percent = cell.percent;
      percentBorderPadding = cell.percentBorderPadding;
    }
    constrained |= cell.constrained;
  }
}

/// `TableTypes::ColspanCell`.
class _Colspan {
  _Colspan(this.cell, this.start, this.span);

  final _CellInline cell;
  final int start;
  final int span;
}

/// `TableTypes::Row`.
class _Row {
  _Row(this.size, {required this.hasRowspanStart});

  double size;
  final bool hasRowspanStart;
}

/// `TableTypes::RowspanCell`.
class _Rowspan {
  _Rowspan(this.start, this.span, this.size);

  final int start;
  final int span;
  final double size;

  /// `RowspanCell::operator<` (table_layout_algorithm_types.h:155-177).
  bool lessThan(_Rowspan other) {
    bool enclosed(_Rowspan a, _Rowspan b) =>
        a.start >= b.start && a.start + a.span <= b.start + b.span;
    if (start == other.start && span == other.span) return size > other.size;
    if (enclosed(this, other)) return true;
    if (enclosed(other, this)) return false;
    return start < other.start;
  }
}

/// A stable insertion sort by [lessThan], as `std::stable_sort`.
void _stableSort<T>(List<T> items, bool Function(T a, T b) lessThan) {
  for (var i = 1; i < items.length; i++) {
    final item = items[i];
    var j = i - 1;
    while (j >= 0 && lessThan(item, items[j])) {
      items[j + 1] = items[j];
      j--;
    }
    items[j + 1] = item;
  }
}

/// The geometry of a laid-out table.
class _Geometry {
  _Geometry(
    this.size,
    this.cells,
    this.rowTops,
    this.rowSizes,
    this.columns,
    this.edges,
  );

  final Size size;
  final List<_Cell> cells;
  final List<double> rowTops;
  final List<double> rowSizes;

  /// Each column's offset and size (`TableColumnLocation`).
  final List<(double, double)> columns;

  /// The width of each horizontal edge, row line by row line, column by
  /// column.
  final List<List<double>> edges;
}

/// The render object of [HtmlTable].
class RenderHtmlTable extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, HtmlTableCellData>,
        RenderBoxContainerDefaultsMixin<RenderBox, HtmlTableCellData> {
  /// A table of [rows].
  RenderHtmlTable({
    required List<HtmlTableRow> rows,
    required Color dividerColor,
    bool fixed = false,
    String? caption,
    ScrollController? sticky,
    Color? stickyBackground,
    TextDirection textDirection = TextDirection.ltr,
  }) : _rows = rows,
       _dividerColor = dividerColor,
       _fixed = fixed,
       _caption = caption,
       _sticky = sticky,
       _stickyBackground = stickyBackground,
       _textDirection = textDirection;

  /// The direction of the names read for the table and its rows.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsSemanticsUpdate();
  }

  /// The rows, in display order.
  List<HtmlTableRow> get rows => _rows;
  List<HtmlTableRow> _rows;
  set rows(List<HtmlTableRow> value) {
    if (listEquals(value, _rows)) return;
    _rows = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  /// The colour of the row dividers.
  Color get dividerColor => _dividerColor;
  Color _dividerColor;
  set dividerColor(Color value) {
    if (value == _dividerColor) return;
    _dividerColor = value;
    markNeedsPaint();
  }

  /// `table-layout: fixed`.
  bool get fixed => _fixed;
  bool _fixed;
  set fixed(bool value) {
    if (value == _fixed) return;
    _fixed = value;
    markNeedsLayout();
  }

  /// The table's name for screen readers.
  String? get caption => _caption;
  String? _caption;
  set caption(String? value) {
    if (value == _caption) return;
    _caption = value;
    markNeedsSemanticsUpdate();
  }

  /// The scroll the sticky cells stay pinned in.
  ScrollController? get sticky => _sticky;
  ScrollController? _sticky;
  set sticky(ScrollController? value) {
    if (value == _sticky) return;
    if (attached) _sticky?.removeListener(_scrolled);
    _sticky = value;
    if (attached) _sticky?.addListener(_scrolled);
    markNeedsPaint();
  }

  /// The background of the sticky cells.
  Color? get stickyBackground => _stickyBackground;
  Color? _stickyBackground;
  set stickyBackground(Color? value) {
    if (value == _stickyBackground) return;
    _stickyBackground = value;
    markNeedsPaint();
  }

  /// The width `width: 100%` resolves against, from the
  /// [HtmlTableWidth] around the table; null when unknown or unbounded.
  double? get percentBase => _percentBase;
  double? _percentBase;
  set percentBase(double? value) {
    if (value == _percentBase) return;
    _percentBase = value;
    markNeedsLayout();
  }

  RenderHtmlTableWidth? _wrap;

  void _scrolled() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _sticky?.addListener(_scrolled);
    for (var node = parent; node != null; node = node.parent) {
      if (node is RenderHtmlTable) break;
      if (node is RenderHtmlTableWidth) {
        _wrap = node.._table = this;
        _percentBase = node.hasSize ? node.constraints.maxWidth : null;
        break;
      }
    }
  }

  @override
  void detach() {
    _sticky?.removeListener(_scrolled);
    if (_wrap?._table == this) _wrap!._table = null;
    _wrap = null;
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! HtmlTableCellData) {
      child.parentData = HtmlTableCellData();
    }
  }

  List<_Cell> _cells() {
    final cells = <_Cell>[];
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as HtmlTableCellData;
      cells.add(_Cell(child, data.style));
      child = data.nextSibling;
    }
    return cells;
  }

  // ---- Tabulation ----

  /// Each cell's start column and effective rowspan (`ColspanCellTabulator`,
  /// table_layout_utils.cc:1645-1681, run per row group; a rowspan is
  /// clamped to the rows left in its group, :210-216), and the column count:
  /// in automatic layout the last column a cell starts in, in fixed layout
  /// the last a cell spans (`ComputeMaxColumn`, table_layout_utils.h:155).
  int _tabulate(List<_Cell> cells) {
    final rowCount = _rows.length;
    // The rows left in each row's group, itself included.
    final left = List<int>.filled(rowCount, 1);
    for (var r = rowCount - 2; r >= 0; r--) {
      if (_rows[r].group == _rows[r + 1].group) left[r] = left[r + 1] + 1;
    }
    var columns = 0;
    // Rowspanned cells still spanning: (start column, span, rows left).
    var spanning = <(int, int, int)>[];
    var index = 0;
    for (var r = 0; r < rowCount; r++) {
      if (r > 0 && _rows[r].group != _rows[r - 1].group) spanning = [];
      var current = 0;
      while (index < cells.length && cells[index].style.row == r) {
        final cell = cells[index++];
        // FindNextFreeColumn.
        for (final (start, span, _) in spanning) {
          if (start <= current && start + span > current) {
            current = start + span;
          }
        }
        final colSpan = cell.style.colSpan.clamp(1, 1000);
        final rowSpan = cell.style.rowSpan == 0
            ? left[r]
            : math.min(cell.style.rowSpan, left[r]);
        cell
          ..column = current
          ..rowSpan = math.max(1, rowSpan);
        columns = math.max(columns, _fixed ? current + colSpan : current + 1);
        // ProcessCell.
        if (cell.style.rowSpan > 1 || cell.style.rowSpan == 0) {
          spanning.add((current, colSpan, cell.rowSpan));
        }
        current += colSpan;
      }
      // EndRow.
      spanning = [
        for (final (start, span, rows) in spanning)
          if (rows - 1 > 0) (start, span, rows - 1),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
    }
    // Cells of rows the table does not have (a cell placed after them)
    // stay in the last row.
    while (index < cells.length) {
      cells[index++].column = columns;
    }
    return columns;
  }

  // ---- Inline sizes ----

  /// The column constraints (`ComputeColumnConstraints`,
  /// table_layout_utils.cc:1453-1488, with no `<col>`).
  List<_Column> _columnConstraints(List<_Cell> cells, int columnCount) {
    final cellInline = List<_CellInline?>.filled(columnCount, null);
    final colspans = <_Colspan>[];
    for (final cell in cells) {
      // Fixed layout reads the first row of the first row group with rows
      // only (:420-421), and a cell of no row nothing.
      if ((_fixed && cell.style.row != 0) || cell.style.row >= _rows.length) {
        continue;
      }
      final constraint = _cellConstraint(cell);
      final colSpan = cell.style.colSpan.clamp(1, 1000);
      if (colSpan == 1) {
        final existing = cellInline[cell.column];
        if (existing != null) {
          existing.encompass(constraint);
        } else {
          cellInline[cell.column] = constraint;
        }
      } else {
        colspans.add(_Colspan(constraint, cell.column, colSpan));
      }
    }
    final columns = [
      for (var i = 0; i < columnCount; i++)
        _Column(tableFixed: _fixed, mergeable: !_fixed),
    ];
    // EnsureDistributableColumnExists (:65-84).
    for (final colspan in colspans) {
      if (colspan.start < columns.length) {
        columns[colspan.start].mergeable = false;
      }
    }
    for (var i = 0; i < columnCount; i++) {
      columns[i].encompass(cellInline[i]);
    }
    _stableSort<_Colspan>(
      colspans,
      (a, b) => a.span == b.span ? a.start < b.start : a.span < b.span,
    );
    for (final colspan in colspans) {
      if (_fixed) {
        _distributeColspanFixed(colspan, columns);
      } else {
        _distributeColspanAuto(colspan, columns);
      }
    }
    // Column percentages are clamped to 100% (:144-169).
    var total = 0.0;
    for (final column in columns) {
      final percent = column.percent;
      if (percent != null) {
        if (!_fixed && percent + total > 100) column.percent = 100 - total;
        total += column.percent!;
      }
      column
        ..min = column.min ?? 0
        ..max = column.max ?? 0;
    }
    if (_fixed && total > 100) {
      for (final column in columns) {
        if (column.percent != null) {
          column.percent = column.percent! * 100 / total;
        }
      }
    }
    return columns;
  }

  /// `TableTypes::CreateCellInlineConstraint` for a cell whose box is
  /// content-box sized (table_layout_algorithm_types.cc:122-196): the
  /// cell's min-content and max-content widths, border and padding
  /// included, and its CSS width.
  _CellInline _cellConstraint(_Cell cell) {
    final borderPadding = cell.style.inlinePadding;
    double? cssInline;
    double? percent;
    final width = cell.style.width;
    if (width is A2uiPercent) {
      percent = width.fraction * 100;
    } else if (width != null) {
      cssInline = width.resolve()! + borderPadding;
    }
    final contentMin = cell.child.getMinIntrinsicWidth(double.infinity);
    final contentMax = cell.child.getMaxIntrinsicWidth(double.infinity);
    final min = _fixed ? 0.0 : math.max<double>(contentMin, 0);
    final max = math.max(min, cssInline ?? contentMax);
    return _CellInline(
      min: min,
      max: max,
      percent: percent == 0 ? null : percent,
      percentBorderPadding: _fixed && percent != null ? borderPadding : 0,
      constrained: cssInline != null,
    );
  }

  /// `DistributeColspanCellToColumnsFixed` (:929-1008), no border spacing.
  static void _distributeColspanFixed(_Colspan colspan, List<_Column> columns) {
    final end = math.min(colspan.start + colspan.span, columns.length);
    final span = [for (var i = colspan.start; i < end; i++) columns[i]];
    final effective = span.where((c) => !c.mergeable).length;
    if (effective == 0) return;
    final cell = colspan.cell;
    final minSize = cell.constrained ? cell.min : 0.0;
    final maxSize = cell.max;
    var minLeft = minSize;
    var maxLeft = maxSize;
    final newMin = minSize / effective;
    final newMax = maxSize / effective;
    final newPercent = cell.percent == null ? null : cell.percent! / effective;
    _Column? last;
    for (final column in span) {
      if (column.mergeable) continue;
      last = column;
      minLeft -= newMin;
      maxLeft -= newMax;
      if (column.min == null) {
        column
          ..constrained |= cell.constrained
          ..min = newMin;
      }
      if (column.max == null) {
        column
          ..constrained |= cell.constrained
          ..max = newMax;
      }
      // Percentages only get distributed over auto columns.
      if (column.percent == null && !column.constrained && newPercent != null) {
        column.percent = newPercent;
      }
    }
    last!
      ..min = last.min! + minLeft
      ..max = last.max! + maxLeft;
  }

  /// `DistributeColspanCellToColumnsAuto` (:1010-1124), no border spacing.
  static void _distributeColspanAuto(_Colspan colspan, List<_Column> columns) {
    if (columns.isEmpty) return;
    final end = math.min(colspan.start + colspan.span, columns.length);
    final span = [for (var i = colspan.start; i < end; i++) columns[i]];
    final cell = colspan.cell;
    final minSize = math.max(0, cell.min).toDouble();
    final maxSize = math.max(0, cell.max).toDouble();
    final cellPercent = cell.percent;
    if (cellPercent != null) {
      var columnsPercent = 0.0;
      var all = 0;
      var percentColumns = 0;
      var others = 0;
      var othersMax = 0.0;
      for (final column in span) {
        column
          ..max = column.max ?? 0
          ..min = column.min ?? 0;
        if (column.mergeable) continue;
        all++;
        if (column.percent != null) {
          percentColumns++;
          columnsPercent += column.percent!;
        } else {
          others++;
          othersMax += column.max!;
        }
      }
      final surplus = cellPercent - columnsPercent;
      if (surplus > 0 && all > percentColumns) {
        for (final column in span) {
          if (column.percent != null || column.mergeable) continue;
          column.percent = othersMax != 0
              ? surplus * (column.max ?? 0) / othersMax
              : surplus / others;
        }
      }
    }
    for (final column in span) {
      column
        ..min = column.min ?? 0
        ..max = column.max ?? 0;
    }
    var sizes = _distributeAuto(minSize, span, constrainedTarget: true);
    for (var i = 0; i < span.length; i++) {
      span[i].min = math.max(span[i].min!, sizes[i]);
    }
    sizes = _distributeAuto(maxSize, span, constrainedTarget: cell.constrained);
    for (var i = 0; i < span.length; i++) {
      span[i].max = math.max(math.max(span[i].min!, span[i].max!), sizes[i]);
    }
  }

  /// `DistributeInlineSizeToComputedInlineSizeAuto` (:466-777): the width
  /// distribution algorithm of CSS Tables 3 (the min, percentage,
  /// specified and max guesses), with mergeable columns left out.
  static List<double> _distributeAuto(
    double targetSize,
    List<_Column> columns, {
    required bool constrainedTarget,
  }) {
    var target = targetSize;
    const minGuess = 0;
    const percentageGuess = 1;
    const specifiedGuess = 2;
    const maxGuess = 3;
    const aboveMax = 4;
    var percentCount = 0;
    var fixedCount = 0;
    var autoCount = 0;
    final guess = List<double>.filled(4, 0);
    final increase = List<double>.filled(4, 0);
    var totalPercent = 0.0;
    var totalAutoMax = 0.0;
    var totalFixedMax = 0.0;
    for (final column in columns) {
      if (column.mergeable) continue;
      final min = column.min!;
      final max = column.max!;
      if (column.percent != null) {
        percentCount++;
        totalPercent += column.percent!;
        final size = column.resolvePercent(target);
        guess[minGuess] += min;
        guess[percentageGuess] += size;
        guess[specifiedGuess] += size;
        guess[maxGuess] += size;
        increase[percentageGuess] += size - min;
      } else if (column.constrained) {
        fixedCount++;
        totalFixedMax += max;
        guess[minGuess] += min;
        guess[percentageGuess] += min;
        guess[specifiedGuess] += max;
        guess[maxGuess] += max;
        increase[specifiedGuess] += max - min;
      } else {
        autoCount++;
        totalAutoMax += max;
        guess[minGuess] += min;
        guess[percentageGuess] += min;
        guess[specifiedGuess] += min;
        guess[maxGuess] += max;
        increase[maxGuess] += max - min;
      }
    }
    final sizes = List<double>.filled(columns.length, 0);
    target = math.max(target, guess[minGuess]);
    var start = aboveMax;
    for (var i = minGuess; i != aboveMax; i++) {
      if (guess[i] >= target) {
        start = i;
        break;
      }
    }
    int? last;
    double share(double distributable, double part, double whole, int count) =>
        whole > 0 ? distributable * part / whole : distributable / count;
    switch (start) {
      case minGuess:
        for (var i = 0; i < columns.length; i++) {
          if (!columns[i].mergeable) sizes[i] = columns[i].min ?? 0;
        }
      case percentageGuess:
        final distributable = target - guess[minGuess];
        var left = distributable;
        for (var i = 0; i < columns.length; i++) {
          final column = columns[i];
          if (column.mergeable) continue;
          if (column.percent != null) {
            last = i;
            final delta = share(
              distributable,
              column.resolvePercent(target) - column.min!,
              increase[percentageGuess],
              percentCount,
            );
            left -= delta;
            sizes[i] = column.min! + delta;
          } else {
            sizes[i] = column.min!;
          }
        }
        if (left != 0) sizes[last!] += left;
      case specifiedGuess:
        final distributable = target - guess[percentageGuess];
        var left = distributable;
        for (var i = 0; i < columns.length; i++) {
          final column = columns[i];
          if (column.mergeable) continue;
          if (column.percent != null) {
            sizes[i] = column.resolvePercent(target);
          } else if (column.constrained) {
            last = i;
            final delta = share(
              distributable,
              column.max! - column.min!,
              increase[specifiedGuess],
              fixedCount,
            );
            left -= delta;
            sizes[i] = column.min! + delta;
          } else {
            sizes[i] = column.min!;
          }
        }
        if (left != 0) sizes[last!] += left;
      case maxGuess:
        final distributable = target - guess[specifiedGuess];
        // An exact match takes each column's max as it is, so rounding
        // cannot wrap a line (:681-687).
        final exact = target == guess[maxGuess];
        var left = exact ? 0.0 : distributable;
        for (var i = 0; i < columns.length; i++) {
          final column = columns[i];
          if (column.mergeable) continue;
          if (column.percent != null) {
            sizes[i] = column.resolvePercent(target);
          } else if (column.constrained || exact) {
            sizes[i] = column.max!;
          } else {
            last = i;
            final delta = share(
              distributable,
              column.max! - column.min!,
              increase[maxGuess],
              autoCount,
            );
            left -= delta;
            sizes[i] = column.min! + delta;
          }
        }
        if (left != 0) sizes[last!] += left;
      default:
        final distributable = target - guess[maxGuess];
        if (autoCount > 0) {
          var left = distributable;
          for (var i = 0; i < columns.length; i++) {
            final column = columns[i];
            if (column.mergeable) continue;
            if (column.percent != null) {
              sizes[i] = column.resolvePercent(target);
            } else if (column.constrained) {
              sizes[i] = column.max!;
            } else {
              last = i;
              final delta = share(
                distributable,
                column.max!,
                totalAutoMax,
                autoCount,
              );
              left -= delta;
              sizes[i] = column.max! + delta;
            }
          }
          if (left != 0) sizes[last!] += left;
        } else if (fixedCount > 0 && constrainedTarget) {
          var left = distributable;
          for (var i = 0; i < columns.length; i++) {
            final column = columns[i];
            if (column.mergeable) continue;
            if (column.percent != null) {
              sizes[i] = column.resolvePercent(target);
            } else {
              last = i;
              final delta = share(
                distributable,
                column.max!,
                totalFixedMax,
                fixedCount,
              );
              left -= delta;
              sizes[i] = column.max! + delta;
            }
          }
          if (left != 0) sizes[last!] += left;
        } else if (percentCount > 0) {
          var left = distributable;
          for (var i = 0; i < columns.length; i++) {
            final column = columns[i];
            if (column.mergeable || column.percent == null) continue;
            last = i;
            final delta = totalPercent != 0
                ? distributable * column.percent! / totalPercent
                : distributable / percentCount;
            left -= delta;
            sizes[i] = column.resolvePercent(target) + delta;
          }
          // Chromium tests `last_computed_size` as a bool here (:770), so
          // a deficit left when the last percent column is the first column
          // is not given back.
          if (left != 0 && last != null && last != 0) sizes[last] += left;
        }
    }
    return sizes;
  }

  /// `SynchronizeAssignableTableInlineSizeAndColumnsFixed` (:779-927).
  static List<double> _distributeFixed(double target, List<_Column> columns) {
    // Columns of width 0 are treated as auto by all browsers.
    bool treatAsFixed(_Column c) => c.isFixed && c.max != 0;
    bool zeroConstrained(_Column c) => c.constrained && c.max == 0;
    var all = 0;
    var percentCount = 0;
    var autoCount = 0;
    var fixedCount = 0;
    var zeroCount = 0;
    var totalPercent = 0.0;
    var totalFixed = 0.0;
    var assigned = 0.0;
    final sizes = List<double>.filled(columns.length, 0);
    for (final column in columns) {
      all++;
      if (column.percent != null) {
        percentCount++;
        totalPercent += column.resolvePercent(target);
      } else if (treatAsFixed(column)) {
        fixedCount++;
        totalFixed += column.max ?? 0;
      } else if (zeroConstrained(column)) {
        zeroCount++;
      } else {
        autoCount++;
      }
    }
    int? last;
    if (fixedCount > 0) {
      var scale = 1.0;
      var scaleAvailable = true;
      final targetFixed = math.max(0, target - totalPercent).toDouble();
      final scaleUp = totalFixed < targetFixed && autoCount == 0;
      final scaleDown = totalFixed > target;
      if (scaleUp || scaleDown) {
        if (totalFixed != 0) {
          scale = targetFixed / totalFixed;
        } else {
          scaleAvailable = false;
        }
      }
      for (var i = 0; i < columns.length; i++) {
        if (!treatAsFixed(columns[i])) continue;
        last = i;
        sizes[i] = scaleAvailable
            ? scale * (columns[i].max ?? 0)
            : target / fixedCount;
        assigned += sizes[i];
      }
    }
    if (assigned >= target) return sizes;
    if (percentCount > 0) {
      var scale = 1.0;
      var scaleAvailable = true;
      final scaleUp = totalPercent < target - assigned && autoCount == 0;
      final scaleDown = totalPercent > target - assigned;
      if (scaleUp || scaleDown) {
        if (totalPercent != 0) {
          scale = (target - assigned) / totalPercent;
        } else {
          scaleAvailable = false;
        }
      }
      for (var i = 0; i < columns.length; i++) {
        if (columns[i].percent == null) continue;
        last = i;
        sizes[i] = scaleAvailable
            ? scale * columns[i].resolvePercent(target)
            : (target - assigned) / percentCount;
        assigned += sizes[i];
      }
    }
    final distributing = target - assigned;
    final distributeZero = zeroCount == all;
    for (var i = 0; i < columns.length; i++) {
      final column = columns[i];
      if (column.percent != null || treatAsFixed(column)) continue;
      // Zero-width columns only grow if all columns are zero-width.
      if (zeroConstrained(column) && !distributeZero) continue;
      last = i;
      sizes[i] = distributing / (distributeZero ? zeroCount : autoCount);
      assigned += sizes[i];
    }
    sizes[last!] += target - assigned;
    return sizes;
  }

  /// `ComputeGridInlineMinMax` (:1746-1827), with no undistributable
  /// space: GRIDMIN and GRIDMAX. Column percentages count in a layout pass
  /// only: an intrinsic size is asked by a flex box or a grid here, where
  /// Chromium leaves them out (`AllowColumnPercentages`, table_node.cc:59).
  (double, double) _gridMinMax(
    List<_Column> columns, {
    required bool layoutPass,
  }) {
    var min = 0.0;
    var max = 0.0;
    var percentEstimate = 0.0;
    var nonPercentMax = 0.0;
    var percentSum = 0.0;
    for (final column in columns) {
      if (column.min != null) {
        min += _fixed && column.isFixed ? column.max! : column.min!;
        final percent = column.percent;
        if (percent != null && percent > 0) {
          if (column.max! > 0) {
            percentEstimate = math.max(
              percentEstimate,
              100 / percent * (column.max! - column.percentBorderPadding),
            );
          }
        } else {
          nonPercentMax += column.max!;
        }
      }
      if (column.max != null) max += column.max!;
      if (column.percent != null) percentSum += column.percent!;
    }
    percentSum = math.min(percentSum, 100);
    if (percentSum > 0 && layoutPass) {
      var fromPercent = 0.0;
      if (nonPercentMax != 0) {
        fromPercent = percentSum == 100
            ? _tableMaxInlineSize
            : (100 / (100 - percentSum)) * nonPercentMax;
      }
      max = math.max(max, math.max(fromPercent, percentEstimate));
    }
    return (min, math.max(min, max));
  }

  // ---- Layout ----

  /// The column sizes for a table [percentBase] wide (null: as wide as its
  /// content), with their locations; and the table's width.
  (List<(double, double)>, double) _columnLocations(
    List<_Column> columns,
    double? base,
  ) {
    final (gridMin, gridMax) = _gridMinMax(columns, layoutPass: true);
    // `width: 100%`, never below the grid's min-content; with no width to
    // take, the grid's max-content (CSS 2.1, 17.5.2.2's shrink-to-fit).
    final used = base == null || !base.isFinite
        ? gridMax
        : math.max(base, gridMin);
    if (columns.isEmpty) return (const [], used);
    final sizes = _fixed
        ? _distributeFixed(used, columns)
        : _distributeAuto(used, columns, constrainedTarget: true);
    // ComputeLocationsFromColumns: an empty mergeable column takes no room.
    final locations = <(double, double)>[];
    var offset = 0.0;
    for (var i = 0; i < columns.length; i++) {
      if (columns[i].mergeable && sizes[i] == 0) {
        locations.add((offset, 0));
      } else {
        locations.add((offset, sizes[i]));
        offset += sizes[i];
      }
    }
    return (locations, offset);
  }

  /// The collapsed border of each horizontal edge, row by row and column by
  /// column (table_borders.cc: each cell's bottom border merged into the
  /// edge under it, the widest winning), then each cell's half of the
  /// edges above and below it (`GetCellBorders`, :335-385).
  List<List<double>> _edges(List<_Cell> cells, int columnCount) {
    final edges = [
      for (var r = 0; r <= _rows.length; r++)
        List<double>.filled(columnCount, 0),
    ];
    bool placed(_Cell cell) =>
        cell.column < columnCount && cell.style.row < _rows.length;
    for (final cell in cells) {
      if (!cell.style.divider || !placed(cell)) continue;
      final bottom = math.min(cell.style.row + cell.rowSpan, _rows.length);
      final end = math.min(cell.column + cell.style.colSpan, columnCount);
      for (var c = cell.column; c < end; c++) {
        edges[bottom][c] = math.max(edges[bottom][c], 1);
      }
    }
    for (final cell in cells) {
      if (!placed(cell)) continue;
      final top = cell.style.row;
      final bottom = math.min(top + cell.rowSpan, _rows.length);
      final end = math.min(cell.column + cell.style.colSpan, columnCount);
      for (var c = cell.column; c < end; c++) {
        cell
          ..borderTop = math.max(cell.borderTop, edges[top][c] / 2)
          ..borderBottom = math.max(cell.borderBottom, edges[bottom][c] / 2);
      }
    }
    return edges;
  }

  _Geometry _compute(
    BoxConstraints constraints,
    double Function(RenderBox child, double width) heightOf,
  ) {
    final cells = _cells();
    final columnCount = _tabulate(cells);
    final columns = _columnConstraints(cells, columnCount);
    final base = _percentBase ?? constraints.maxWidth;
    final (locations, width) = _columnLocations(
      columns,
      base.isFinite ? base : null,
    );
    final edges = _edges(cells, columnCount);
    // Each cell's width and block size; the rows' sizes, then the
    // rowspanned cells spread over them (ComputeMinimumRowBlockSize,
    // ComputeSectionMinimumRowBlockSizes).
    final rows = <_Row>[
      for (var r = 0; r < _rows.length; r++)
        _Row(
          0,
          hasRowspanStart: cells.any((c) => c.style.row == r && c.rowSpan > 1),
        ),
    ];
    final rowspans = <int, List<_Rowspan>>{};
    for (final cell in cells) {
      if (locations.isEmpty || cell.column >= locations.length) {
        cell
          ..width = 0
          ..height = heightOf(cell.child, 0);
        continue;
      }
      final end = math.min(
        cell.column + cell.style.colSpan - 1,
        locations.length - 1,
      );
      cell
        ..x = locations[cell.column].$1
        ..width =
            locations[end].$1 + locations[end].$2 - locations[cell.column].$1;
      cell.height = heightOf(cell.child, cell.width);
      final block = cell.height + cell.borderTop + cell.borderBottom;
      final r = cell.style.row;
      if (r >= rows.length) continue;
      if (cell.rowSpan > 1) {
        rowspans
            .putIfAbsent(_rows[r].group, () => [])
            .add(_Rowspan(r, cell.rowSpan, block));
      } else {
        rows[r].size = math.max(rows[r].size, block);
      }
    }
    for (final group in rowspans.values) {
      _stableSort<_Rowspan>(group, (a, b) => a.lessThan(b));
      for (final rowspan in group) {
        _distributeRowspan(rowspan, rows);
      }
    }
    // The table's border: half of the outer edges (none on the sides).
    final tableTop = edges.first.fold<double>(0, math.max) / 2;
    final tableBottom = edges.last.fold<double>(0, math.max) / 2;
    final rowTops = <double>[];
    var y = tableTop;
    for (final row in rows) {
      rowTops.add(y);
      y += row.size;
    }
    for (final cell in cells) {
      final r = cell.style.row;
      if (r >= rows.length) continue;
      var height = 0.0;
      for (var i = r; i < r + cell.rowSpan && i < rows.length; i++) {
        height += rows[i].size;
      }
      // FinalizeTableCellLayout: the content moves down by the free space,
      // half of it for `middle`.
      final free = height - cell.borderTop - cell.borderBottom - cell.height;
      cell.offset = Offset(
        cell.x,
        rowTops[r] + cell.borderTop + free * cell.style.vAlign,
      );
    }
    final size = constraints.constrain(Size(width, y + tableBottom));
    return _Geometry(
      size,
      cells,
      rowTops,
      [for (final row in rows) row.size],
      locations,
      edges,
    );
  }

  /// `DistributeRowspanCellToRows` with `DistributeExcessBlockSizeToRows`
  /// (:1130-1332) for a rowspan distribution: no percentage rows, no
  /// constrained rows.
  static void _distributeRowspan(_Rowspan cell, List<_Row> rows) {
    final end = math.min(cell.start + cell.span, rows.length);
    final withRowspan = <int>[];
    final nonEmpty = <int>[];
    final empty = <int>[];
    var total = 0.0;
    for (var i = cell.start; i < end; i++) {
      total += rows[i].size;
      if (i != cell.start && rows[i].hasRowspanStart) withRowspan.add(i);
      if (rows[i].size == 0) {
        empty.add(i);
      } else {
        nonEmpty.add(i);
      }
    }
    final distributable = cell.size - total;
    if (distributable <= 0) return;
    // Step 2: rows where another rowspan starts.
    if (withRowspan.isNotEmpty) {
      var left = distributable;
      for (final i in withRowspan) {
        final delta = distributable / withRowspan.length;
        rows[i].size += delta;
        left -= delta;
      }
      final last = rows[withRowspan.last];
      last.size = math.max(0, last.size + left);
      return;
    }
    // Step 3: unconstrained non-empty rows grow in proportion to their size.
    if (nonEmpty.isNotEmpty) {
      var left = distributable;
      for (final i in nonEmpty) {
        final delta = distributable * rows[i].size / total;
        rows[i].size += delta;
        left -= delta;
      }
      rows[nonEmpty.last].size += left;
      return;
    }
    // Step 4: only empty rows: the last one takes it all.
    if (empty.isNotEmpty) rows[empty.last].size += distributable;
  }

  double _sticky0(_Geometry geometry) {
    final controller = _sticky;
    if (controller == null || !controller.hasClients) return 0;
    var headerBottom = 0.0;
    for (final cell in geometry.cells) {
      if (!cell.style.sticky) continue;
      headerBottom = math.max(
        headerBottom,
        cell.offset.dy + cell.child.size.height + cell.borderBottom,
      );
    }
    final room = math.max(0, geometry.size.height - headerBottom);
    return controller.offset.clamp(0, room).toDouble();
  }

  /// How far the sticky cells are moved down to stay in view.
  double get stickyOffset {
    final geometry = _geometry;
    return geometry == null ? 0 : _sticky0(geometry);
  }

  _Geometry? _geometry;

  static double _layoutHeight(RenderBox child, double width) {
    child.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    return child.size.height;
  }

  static double _dryHeight(RenderBox child, double width) =>
      child.getDryLayout(BoxConstraints.tightFor(width: width)).height;

  static double _intrinsicHeight(RenderBox child, double width) =>
      child.getMaxIntrinsicHeight(width);

  @override
  void performLayout() {
    final geometry = _geometry = _compute(constraints, _layoutHeight);
    size = geometry.size;
    for (final cell in geometry.cells) {
      (cell.child.parentData! as HtmlTableCellData).offset = cell.offset;
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _compute(constraints, _dryHeight).size;

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsicWidths().$1;

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsicWidths().$2;

  /// The table's min-content and max-content (`ComputeMinMaxSizes`,
  /// table_layout_algorithm.cc:735-766): GRIDMIN and GRIDMAX; a fixed
  /// table with a percentage width wants all the room there is.
  (double, double) _intrinsicWidths() {
    final cells = _cells();
    final columns = _columnConstraints(cells, _tabulate(cells));
    final (min, max) = _gridMinMax(columns, layoutPass: false);
    return (min, _fixed ? _tableMaxInlineSize : max);
  }

  @override
  double computeMinIntrinsicHeight(double width) => _heightAt(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _heightAt(width);

  double _heightAt(double width) => _compute(
    width.isFinite
        ? BoxConstraints.tightFor(width: width)
        : const BoxConstraints(),
    _intrinsicHeight,
  ).size.height;

  /// The first cell's baseline, at its place (its content's: an
  /// [HtmlTableCellBox] always has one); a table with no cell that has one
  /// has its bottom edge, as a box without a baseline stands in by.
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline) ?? size.height;

  /// The baseline [computeDistanceToActualBaseline] gives after a layout at
  /// [constraints]. (A null here makes a proxy parent's dry baseline throw
  /// in debug: its fallback is `RenderBox.computeDryBaseline`, which
  /// asserts.)
  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final geometry = _compute(constraints, _dryHeight);
    for (final cell in geometry.cells) {
      final own = cell.child.getDryBaseline(
        BoxConstraints.tightFor(width: cell.width),
        baseline,
      );
      if (own != null) return own + cell.offset.dy;
    }
    return geometry.size.height;
  }

  // ---- Paint and hit testing ----

  bool _isSticky(RenderBox child) =>
      (child.parentData! as HtmlTableCellData).style.sticky;

  @override
  void paint(PaintingContext context, Offset offset) {
    final geometry = _geometry;
    if (geometry == null) return;
    final pinned = _sticky0(geometry);
    // `context.canvas` is read at each draw, never kept: a cell that needs
    // compositing (a Button's opacity, a Code's scroll view) ends the
    // recording it painted after, and a kept canvas is then a disposed one.
    // Each draw lands above what was painted before it, so the order is:
    // the cells, their dividers, then the sticky backgrounds, cells and
    // dividers.
    final edges = geometry.edges;
    final divider = Paint()..color = _dividerColor;
    void paintEdge(int e, {required bool stickyRows}) {
      if (e >= edges.length || geometry.columns.isEmpty) return;
      final y = e < geometry.rowTops.length
          ? geometry.rowTops[e]
          : (geometry.rowTops.isEmpty
                ? 0
                : geometry.rowTops.last + geometry.rowSizes.last);
      // Runs of columns with the same edge width, one rect each.
      var c = 0;
      while (c < edges[e].length) {
        final width = edges[e][c];
        var end = c + 1;
        while (end < edges[e].length && edges[e][end] == width) {
          end++;
        }
        if (width > 0) {
          final left = geometry.columns[c].$1;
          final right =
              geometry.columns[end - 1].$1 + geometry.columns[end - 1].$2;
          context.canvas.drawRect(
            Rect.fromLTRB(
              left,
              y - width / 2,
              right,
              y + width / 2,
            ).shift(offset + Offset(0, stickyRows ? pinned : 0)),
            divider,
          );
        }
        c = end;
      }
    }

    // The edges under the sticky cells' rows move with them.
    final stickyEdges = <int>{
      for (final cell in geometry.cells)
        if (cell.style.sticky) cell.style.row + cell.rowSpan,
    };
    for (final cell in geometry.cells) {
      if (!cell.style.sticky) {
        context.paintChild(cell.child, offset + cell.offset);
      }
    }
    for (var e = 0; e < edges.length; e++) {
      if (!stickyEdges.contains(e)) paintEdge(e, stickyRows: false);
    }
    final background = _stickyBackground;
    for (final cell in geometry.cells) {
      if (!cell.style.sticky) continue;
      final top = geometry.rowTops[cell.style.row];
      if (background != null) {
        var height = 0.0;
        for (var i = cell.style.row; i < cell.style.row + cell.rowSpan; i++) {
          height += geometry.rowSizes[i];
        }
        context.canvas.drawRect(
          Rect.fromLTWH(cell.x, top + pinned, cell.width, height).shift(offset),
          Paint()..color = background,
        );
      }
      context.paintChild(cell.child, offset + cell.offset + Offset(0, pinned));
    }
    for (final e in stickyEdges) {
      paintEdge(e, stickyRows: true);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final data = child.parentData! as HtmlTableCellData;
    final pinned = data.style.sticky ? stickyOffset : 0.0;
    transform.translateByDouble(data.offset.dx, data.offset.dy + pinned, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final pinned = stickyOffset;
    // The sticky cells paint last, over the rows under them.
    var child = lastChild;
    for (final sticky in [true, false]) {
      child = lastChild;
      while (child != null) {
        final data = child.parentData! as HtmlTableCellData;
        if (_isSticky(child) == sticky) {
          final at = data.offset + Offset(0, sticky ? pinned : 0);
          final hit = result.addWithPaintOffset(
            offset: at,
            position: position,
            hitTest: (result, transformed) =>
                child!.hitTest(result, position: transformed),
          );
          if (hit) return true;
        }
        child = data.previousSibling;
      }
    }
    return false;
  }

  // ---- Semantics ----

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true
      ..role = SemanticsRole.table;
    final caption = _caption;
    if (caption != null && caption.isNotEmpty) {
      config
        ..label = caption
        ..textDirection = _textDirection;
    }
  }

  final List<SemanticsNode> _rowNodes = [];

  @override
  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    final byRow = <int, List<SemanticsNode>>{};
    final untagged = <SemanticsNode>[];
    for (final child in children) {
      final tag = child.tags?.whereType<HtmlTableRowTag>().firstOrNull;
      if (tag == null) {
        untagged.add(child);
      } else {
        byRow.putIfAbsent(tag.row, () => []).add(child);
      }
    }
    final geometry = _geometry;
    final pinned = geometry == null ? 0.0 : _sticky0(geometry);
    final stickyRows = <int>{
      for (final cell in geometry?.cells ?? const <_Cell>[])
        if (cell.style.sticky) cell.style.row,
    };
    while (_rowNodes.length > _rows.length) {
      _rowNodes.removeLast();
    }
    Rect rectOf(int r) {
      final top = geometry == null || r >= geometry.rowTops.length
          ? 0.0
          : geometry.rowTops[r];
      final height = geometry == null || r >= geometry.rowSizes.length
          ? 0.0
          : geometry.rowSizes[r];
      return Rect.fromLTWH(
        0,
        top + (stickyRows.contains(r) ? pinned : 0),
        size.width,
        height,
      );
    }

    // A row with no cell to read (one whose cells have not arrived while a
    // table streams in, or an empty `<tr>`: no height, data.tsx:305-320)
    // has no node until it has one: an empty node is invisible, which
    // Flutter's semantics tree refuses.
    bool shows(int r) =>
        !_rows[r].hidden &&
        (byRow[r]?.isNotEmpty ?? false) &&
        !rectOf(r).isEmpty;
    final rowNodes = <SemanticsNode>[];
    var lastShown = -1;
    for (var r = _rows.length - 1; r >= 0; r--) {
      if (shows(r)) {
        lastShown = r;
        break;
      }
    }
    for (var r = 0; r < _rows.length; r++) {
      if (r >= _rowNodes.length) _rowNodes.add(SemanticsNode());
      final row = _rows[r];
      if (!shows(r)) continue;
      final rowNode = _rowNodes[r]..rect = rectOf(r);
      final rowConfig = SemanticsConfiguration()
        ..role = SemanticsRole.row
        ..isSemanticBoundary = true
        ..liveRegion = row.live
        ..textDirection = _textDirection;
      if (row.label != null) rowConfig.label = row.label!;
      if (row.hint != null) rowConfig.hint = row.hint!;
      rowNode.updateWith(
        config: rowConfig,
        childrenInInversePaintOrder: [
          ...?byRow[r],
          // A node no cell tagged (none is expected) stays in the last row,
          // where the table's role allows it.
          if (r == lastShown) ...untagged,
        ],
      );
      rowNodes.add(rowNode);
    }
    node.updateWith(
      config: config,
      childrenInInversePaintOrder: [
        ...rowNodes,
        // With no row to hold them (none is expected).
        if (lastShown < 0) ...untagged,
      ],
    );
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _rowNodes.clear();
  }
}

// PORT STATUS: confidence=medium todos=0 upstream=chromium@159.0.8154.13 third_party/blink/renderer/core/layout/table/
