import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/item_styles.dart';
import 'package:a2ui_kit/src/components/node_guard.dart'
    show hasValidProps, isDrawnChild;
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/components/standard/layout/focusable_scroll_box.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/interaction/envelope.dart';
import 'package:a2ui_kit/src/foundation/js_json.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/layout/html_table.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/foundation/text/inline_element.dart'
    show collapseInlineWhitespace;
import 'package:a2ui_kit/src/foundation/text/text_styles.dart';
import 'package:a2ui_kit/src/functions/calc.dart' show jsNumberString;
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// The standard `Table` (data.tsx:160-272): a data table that scrolls
/// sideways when its columns need more room than it has.
///
/// From `columns` and `rows`: a header row of `columns` (a string, `{label,
/// align, width, componentId}` or `{componentId}`; a header shows its label,
/// then its component), then a row per list of `rows`, each cell a string,
/// a number, a `{componentId}` (or `{id}`) cell showing that component of
/// `cellComponents`, or other JSON written as JSON; a cell takes its
/// column's `align`. No rows shows `emptyLabel` ("No rows") across the
/// columns. From `children` (when there are neither columns nor rows):
/// TableSection and TableRow children, a template among them, each
/// TableRow its own row group; the first header group shows first, as a
/// browser shows the first `<thead>`.
///
/// Cells are 14px text, 8px apart (none at the row's outer edges), top
/// aligned, header cells medium weight. `dividers` (true by default) draws
/// a hairline under each row but the last. `columnSizing: "equal"` is
/// `table-layout: fixed`: the first row's widths decide the columns and the
/// others share the width equally; `"auto"` sizes the columns from their
/// cells, as Chromium does. `stickyHeader` keeps the table within 480px,
/// scrolling, with the `columns` header pinned. `caption` names the table
/// for screen readers and is not shown.
///
/// For screen readers it is a table: a row node per row, a column-header
/// node per header cell of a header row, a cell node per other cell
/// (RULEBOOK section 0). A row header (`<th scope="row">`: a TableRow's
/// `label`, a header TableCell in a body row) is a cell: Flutter's
/// `SemanticsRole` has no row header (INV-150). A TableRow's and a
/// TableCell's envelope name the row's and the cell's node; a
/// TableSection's hides its rows when `hidden`, and its name, description
/// and live region apply to nothing, as Flutter has no row group node
/// (INV-151).
///
/// Its scroll wrapper takes the keyboard focus as Chrome's keyboard-
/// focusable scroller does (INV-152): Tab reaches it while it can scroll
/// and holds nothing that takes the keyboard focus, a press never focuses
/// it, and its scroll keys scroll it ([FocusableScrollBox]).
///
/// Its two scroll views (sideways, and with `stickyHeader` down) put the
/// sideways scrollbar under the table, where CopilotKit's one box scrolls
/// both ways with its scrollbar at the box's bottom (INV-153).
Widget buildTable(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) => _TableView(
  node: node,
  props: props,
  buildChild: buildChild,
  root: _Root.table,
);

/// The standard `TableSection` (data.tsx:274-290): a row group of a
/// Table, its header with `header`; `rowDivider` sets its rows' dividers.
/// In a Table, the Table lays it out; elsewhere it shows as a table of its
/// own, as a browser wraps a lone row group in an anonymous table.
Widget buildTableSection(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) => _TableView(
  node: node,
  props: props,
  buildChild: buildChild,
  root: _Root.section,
);

/// The standard `TableRow` (data.tsx:292-329): a row of TableCell children,
/// header cells with `header` (or in a header TableSection), led by a row
/// header of `label` spanning `labelColSpan` columns. In a Table, the Table
/// lays it out; elsewhere it shows as a table of its own.
Widget buildTableRow(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) => _TableView(
  node: node,
  props: props,
  buildChild: buildChild,
  root: _Root.row,
);

/// The standard `TableCell` (data.tsx:331-357): its `text`, then its
/// children; a header cell with `header` (or in a header row); `colSpan`
/// and `rowSpan` (`rowSpan: 0` spans the rest of its row group, as HTML's
/// does); `align`, `vAlign` (top by default), and `width` and `padding` in
/// 4px steps. In a Table, the Table lays it out; elsewhere it shows as a
/// table of its own.
Widget buildTableCell(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) => _TableView(
  node: node,
  props: props,
  buildChild: buildChild,
  root: _Root.cell,
);

enum _Root { table, section, row, cell }

/// `V_ALIGN` (data.tsx:69): where a cell's content sits in a taller row.
double _vAlignOf(A2uiTextAlign align) => switch (align) {
  A2uiTextAlign.start => 0,
  A2uiTextAlign.center => .5,
  A2uiTextAlign.end => 1,
};

/// The component id of a `{ componentId }` or `{ id }` cell, else null
/// (`cellComponentId`, data.tsx:101-112).
String? _cellComponentId(Object? value) {
  if (value is! Map) return null;
  final id = value['componentId'];
  if (value.containsKey('componentId') && id is String) {
    return id.isEmpty ? null : id;
  }
  final alias = value['id'];
  if (value.containsKey('id') && alias is String) {
    return alias.isEmpty ? null : alias;
  }
  return null;
}

/// `cellText` (data.tsx:114-118): nothing for null, JSON for an object or
/// a list, else `String()`.
String _cellText(Object? value) => switch (value) {
  null => '',
  final Map<Object?, Object?> _ ||
  final List<Object?> _ => jsonStringifyJs(value),
  final num n => jsNumberString(n),
  final String s => s,
  _ => '$value',
};

/// One cell of the table being built.
class _CellSpec {
  _CellSpec({
    required this.key,
    required this.row,
    required this.content,
    this.header = false,
    this.columnHeader = false,
    this.align = A2uiTextAlign.start,
    this.vAlign = 0,
    this.width,
    this.padding,
    this.firstChild = true,
    this.lastChild = true,
    this.colSpan = 1,
    this.rowSpan = 1,
    this.divider = false,
    this.sticky = false,
    this.envelope = KitEnvelope.none,
    this.hidden = false,
    this.tertiary = false,
    this.anonymous = false,
  });

  final Key key;
  int row;

  /// The text and the nodes it shows, in order.
  final List<Object> content;

  /// A `<th>`: medium weight.
  final bool header;

  /// A `<th scope="col">`: a column header for screen readers.
  final bool columnHeader;
  final A2uiTextAlign align;
  final double vAlign;
  final Object? width;

  /// The `padding` prop, or null for the stylesheet's 8px.
  final Object? padding;
  final bool firstChild;
  final bool lastChild;
  final int colSpan;
  final int rowSpan;
  bool divider;
  final bool sticky;
  final KitEnvelope envelope;
  bool hidden;

  /// The empty label: tertiary text, centred.
  final bool tertiary;

  /// An anonymous cell around content that is no cell (CSS 2.1, 17.2.1):
  /// none of the cell styles, middle aligned as its row.
  final bool anonymous;
}

class _RowSpec {
  _RowSpec({this.envelope = KitEnvelope.none, this.hidden = false});

  final KitEnvelope envelope;
  final bool hidden;
  final List<_CellSpec> cells = [];
}

class _GroupSpec {
  _GroupSpec({required this.header, this.tbody = false});

  /// A `<thead>`.
  final bool header;

  /// A `<tbody>` element (not an anonymous row group).
  final bool tbody;
  final List<_RowSpec> rows = [];

  /// Whether its last child element is a `<tr>`.
  bool endsWithRow = true;
}

/// A table being built from its nodes: its row groups, rows and cells, and
/// the nodes it read (whose changes rebuild it).
class _TableModel {
  _TableModel({
    required this.theme,
    required this.tableEdges,
    required this.fontSize,
  });

  final A2uiKitTheme theme;
  final bool tableEdges;
  final double fontSize;
  final List<_GroupSpec> groups = [];
  final List<KitNode> watched = [];
  bool fixed = false;
  bool sticky = false;
  bool scrolls = false;
  String? caption;

  /// The rows mode: `columns` and `rows` (data.tsx:197-272).
  void fromRows(TableProps view) {
    final dividers = view.dividers;
    final columns = [for (final raw in view.columns) _normalizeColumn(raw)];
    final rows = view.rows;
    // `elementsById` (data.tsx:124-133) keys every rendered child by its
    // id, a cyclic reference's or an unknown type's fallback too
    // (SurfaceView.tsx:314-340): it shows in its cell.
    final components = {
      for (final node in view.cellComponents)
        if (isDrawnChild(node)) node.componentId: node,
    };
    Object? componentOf(String? id) => id == null ? null : components[id];
    if (columns.isNotEmpty) {
      final group = _GroupSpec(header: true);
      final row = _RowSpec();
      for (var i = 0; i < columns.length; i++) {
        final column = columns[i];
        row.cells.add(
          _CellSpec(
            key: ValueKey('h$i'),
            row: 0,
            content: [?column.label, ?componentOf(column.componentId)],
            header: true,
            columnHeader: true,
            align: column.align ?? A2uiTextAlign.start,
            width: column.width,
            firstChild: i == 0,
            lastChild: i == columns.length - 1,
            divider: true,
            sticky: sticky,
          ),
        );
      }
      group.rows.add(row);
      groups.add(group);
    }
    final body = _GroupSpec(header: false, tbody: true);
    if (rows.isEmpty) {
      final columnCount = columns.isEmpty ? 1 : columns.length;
      body.rows.add(
        _RowSpec()
          ..cells.add(
            _CellSpec(
              key: const ValueKey('empty'),
              row: 0,
              content: [view.emptyLabel],
              align: A2uiTextAlign.center,
              colSpan: columnCount,
              tertiary: true,
            ),
          ),
      );
    } else {
      for (var r = 0; r < rows.length; r++) {
        final values = switch (ComponentProps.unwrap(rows[r])) {
          final List<Object?> list => list,
          _ => const <Object?>[],
        };
        final row = _RowSpec();
        for (var c = 0; c < values.length; c++) {
          final value = ComponentProps.unwrap(values[c]);
          final id = _cellComponentId(value);
          row.cells.add(
            _CellSpec(
              key: ValueKey('r$r:c$c'),
              row: 0,
              content: [if (id == null) _cellText(value) else ?componentOf(id)],
              align: c < columns.length
                  ? columns[c].align ?? A2uiTextAlign.start
                  : A2uiTextAlign.start,
              firstChild: c == 0,
              lastChild: c == values.length - 1,
              divider: dividers && r < rows.length - 1,
            ),
          );
        }
        body.rows.add(row);
      }
    }
    groups.add(body);
  }

  /// The children mode: TableSection and TableRow children, and anything
  /// else in an anonymous row group (data.tsx:178-195).
  ///
  /// A child that has not arrived draws nothing (`NodePlaceholder` renders
  /// null, boundaries.tsx:16-18). A cyclic reference's or an unknown
  /// type's fallback, a `<div>` (host.tsx:116-150; SurfaceView.tsx:
  /// 314-340), is content that is no row group, row or cell wherever it
  /// lands: in the table or a section it sits in an anonymous row and
  /// cell, in a row in an anonymous cell, in a cell as a block (CSS 2.1
  /// section 17.2.1, as React puts the `<div>` there through the DOM, not
  /// the HTML parser, which would move it out of the table).
  void fromChildren(List<KitNode> children, {required bool dividers}) {
    final strays = <KitNode>[];
    void flushStrays() {
      if (strays.isEmpty) return;
      groups.add(
        _GroupSpec(header: false)
          ..endsWithRow = false
          ..rows.add(_anonymousRow([...strays])),
      );
      strays.clear();
    }

    for (final child in children) {
      if (!isDrawnChild(child)) continue;
      // A section or row whose props fail the render check is built as the
      // node it is: its guard shows the "invalid props" fallback in its
      // place, content that is no row group or row ([hasValidProps]).
      switch (_tablePart(child)) {
        case 'TableSection':
          flushStrays();
          groups.add(_section(child, tableDividers: dividers));
        case 'TableRow':
          flushStrays();
          // A row directly in a table gets its own row group (data.tsx:
          // 323-328).
          watched.add(child);
          final view = TableRowProps(ComponentProps(child.props.peek()));
          final header = view.header ?? false;
          groups.add(
            _GroupSpec(header: header, tbody: !header)
              ..rows.add(_row(child, header: header, dividers: dividers)),
          );
        default:
          strays.add(child);
      }
    }
    flushStrays();
  }

  /// A TableSection's row group.
  _GroupSpec _section(KitNode node, {required bool tableDividers}) {
    watched.add(node);
    final view = TableSectionProps(ComponentProps(node.props.peek()));
    final header = view.header ?? false;
    final dividers = view.rowDivider ?? tableDividers;
    final hidden = KitEnvelope.ofNode(node).hidden;
    final group = _GroupSpec(header: header, tbody: !header);
    final strays = <KitNode>[];
    void flushStrays() {
      if (strays.isEmpty) return;
      group.rows.add(_anonymousRow([...strays], hidden: hidden));
      strays.clear();
    }

    final children = view.children.where(isDrawnChild).toList();
    for (final child in children) {
      if (_tablePart(child) == 'TableRow') {
        flushStrays();
        group.rows.add(
          _row(child, header: header, dividers: dividers, hidden: hidden),
        );
      } else {
        strays.add(child);
      }
    }
    flushStrays();
    group.endsWithRow =
        children.isEmpty || _tablePart(children.last) == 'TableRow';
    return group;
  }

  /// The table part [child] is (`TableSection`, `TableRow`, `TableCell`)
  /// when its props pass the render check, else null: a part that fails is
  /// built as a node, its guard's fallback in its place.
  static String? _tablePart(KitNode child) => switch (child.type) {
    'TableSection' ||
    'TableRow' ||
    'TableCell' when hasValidProps(child) => child.type,
    _ => null,
  };

  /// A row of content that is no row: one anonymous cell holding it.
  _RowSpec _anonymousRow(List<KitNode> nodes, {bool hidden = false}) {
    watched.addAll(nodes);
    return _RowSpec(hidden: hidden)
      ..cells.add(
        _CellSpec(
          key: ValueKey('${nodes.first.instanceId}::anon'),
          row: 0,
          content: nodes,
          vAlign: .5,
          anonymous: true,
          hidden: hidden,
        ),
      );
  }

  /// A TableRow's row (data.tsx:292-321).
  _RowSpec _row(
    KitNode node, {
    required bool header,
    required bool dividers,
    bool hidden = false,
  }) {
    watched.add(node);
    final view = TableRowProps(ComponentProps(node.props.peek()));
    final envelope = KitEnvelope.ofNode(node);
    final isHeader = (view.header ?? false) || header;
    final row = _RowSpec(envelope: envelope, hidden: hidden || envelope.hidden);
    final children = view.children.where(isDrawnChild).toList();
    final label = view.label;
    final hasLabel = label != null && label.isNotEmpty;
    // Each child is one element of the `<tr>`, after the label's `<th>`.
    final elements = children.length + (hasLabel ? 1 : 0);
    if (hasLabel) {
      row.cells.add(
        _CellSpec(
          key: ValueKey('${node.instanceId}::label'),
          row: 0,
          content: [label],
          header: true,
          // The label is the `<tr>`'s first child, and a direct one, in
          // either look.
          lastChild: elements == 1,
          colSpan: htmlSpanOf(view.labelColSpan, min: 1, max: 1000),
          divider: dividers,
          hidden: row.hidden,
        ),
      );
    }
    final strays = <KitNode>[];
    void flushStrays() {
      if (strays.isEmpty) return;
      watched.addAll(strays);
      row.cells.add(
        _CellSpec(
          key: ValueKey('${strays.first.instanceId}::anon'),
          row: 0,
          content: [...strays],
          vAlign: .5,
          anonymous: true,
          hidden: row.hidden,
        ),
      );
      strays.clear();
    }

    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (_tablePart(child) != 'TableCell') {
        strays.add(child);
        continue;
      }
      flushStrays();
      final index = i + (hasLabel ? 1 : 0);
      row.cells.add(
        _cell(
          child,
          rowHeader: isHeader,
          dividers: dividers,
          // In the playground each TableCell is the one child of its
          // wrapper (A2uiKitTheme.tableEdges).
          firstChild: !tableEdges || index == 0,
          lastChild: !tableEdges || index == elements - 1,
          hidden: row.hidden,
        ),
      );
    }
    flushStrays();
    return row;
  }

  /// A TableCell's cell (data.tsx:331-357).
  _CellSpec _cell(
    KitNode node, {
    required bool rowHeader,
    required bool dividers,
    required bool firstChild,
    required bool lastChild,
    bool hidden = false,
  }) {
    watched.add(node);
    final props = ComponentProps(node.props.peek());
    final view = TableCellProps(props);
    final envelope = KitEnvelope.of(props);
    final isHeader = (view.header ?? false) || rowHeader;
    final text = props.value('text');
    final children = view.children.where(isDrawnChild).toList();
    watched.addAll(children);
    return _CellSpec(
      key: ValueKey(node.instanceId),
      row: 0,
      content: [
        if (text is String || text is num) _cellText(text),
        ...children,
      ],
      header: isHeader,
      // A header cell in a header row names a column; else its row.
      columnHeader: isHeader && rowHeader,
      align: view.align ?? A2uiTextAlign.start,
      vAlign: _vAlignOf(view.vAlign),
      width: view.width,
      padding: view.padding,
      firstChild: firstChild,
      lastChild: lastChild,
      colSpan: htmlSpanOf(view.colSpan, min: 1, max: 1000),
      rowSpan: htmlSpanOf(view.rowSpan, min: 0, max: 65534),
      divider: dividers,
      envelope: envelope,
      hidden: hidden || envelope.hidden,
    );
  }

  /// The groups in display order (the first `<thead>` first,
  /// table_layout_algorithm_types.cc:291-305), with each cell's row and
  /// the stylesheet's last-row rule applied; and the rows.
  List<HtmlTableRow> finish({required bool lastRowRule}) {
    // `.a2ui-std-table>tbody:last-child>tr:last-child>.a2ui-std-cell
    // {border-bottom:0}` (styles.ts:78), in the DOM order.
    if (lastRowRule && groups.isNotEmpty) {
      final last = groups.last;
      if (last.tbody && last.endsWithRow && last.rows.isNotEmpty) {
        for (final cell in last.rows.last.cells) {
          if (!cell.anonymous) cell.divider = false;
        }
      }
    }
    final head = groups.indexWhere((group) => group.header);
    if (head > 0) groups.insert(0, groups.removeAt(head));
    final rows = <HtmlTableRow>[];
    for (var g = 0; g < groups.length; g++) {
      for (final row in groups[g].rows) {
        for (final cell in row.cells) {
          cell.row = rows.length;
        }
        rows.add(
          HtmlTableRow(
            group: g,
            label: row.envelope.label,
            hint: row.envelope.description,
            live: row.envelope.live,
            hidden: row.hidden,
          ),
        );
      }
    }
    return rows;
  }

  List<_CellSpec> get cells => [
    for (final group in groups)
      for (final row in group.rows) ...row.cells,
  ];
}

/// A `columns` entry (`normalizeColumn`, data.tsx:149-153).
({String? label, A2uiTextAlign? align, Object? width, String? componentId})
_normalizeColumn(Object? raw) {
  final column = ComponentProps.unwrap(raw);
  if (column is String) {
    return (label: column, align: null, width: null, componentId: null);
  }
  if (column is! Map) {
    return (label: null, align: null, width: null, componentId: null);
  }
  final componentId = _cellComponentId(column);
  if (!column.containsKey('label')) {
    return (label: null, align: null, width: null, componentId: componentId);
  }
  return (
    label: ComponentProps.asString(column['label']),
    align: A2uiTextAlign.fromWire(column['align']),
    width: ComponentProps.unwrap(column['width']),
    componentId: componentId,
  );
}

class _TableView extends StatefulWidget {
  const _TableView({
    required this.node,
    required this.props,
    required this.buildChild,
    required this.root,
  });

  final KitNode node;
  final ComponentProps props;
  final ChildWidgetBuilder buildChild;
  final _Root root;

  @override
  State<_TableView> createState() => _TableViewState();
}

class _TableViewState extends State<_TableView> {
  ScrollController? _sticky;
  List<KitNode> _watched = const [];
  List<void Function()> _unsubscribes = const [];

  void _watch(List<KitNode> nodes) {
    if (listEquals(nodes, _watched)) return;
    _unsubscribe();
    _watched = nodes;
    // A node's props hold its envelope's bound values resolved
    // ([KitEnvelope.ofNode]), so its props are all there is to watch.
    _unsubscribes = [
      for (final node in nodes) listenAfterFirst(node.props, (_) => _changed()),
    ];
  }

  void _unsubscribe() {
    for (final unsubscribe in _unsubscribes) {
      unsubscribe();
    }
    _unsubscribes = const [];
  }

  void _changed() {
    if (!mounted) return;
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    _sticky?.dispose();
    super.dispose();
  }

  _TableModel _model(A2uiKitTheme theme, double fontSize) {
    final model = _TableModel(
      theme: theme,
      tableEdges: theme.tableEdges,
      fontSize: fontSize,
    );
    final node = widget.node;
    switch (widget.root) {
      case _Root.table:
        final view = TableProps(widget.props);
        model
          ..fixed = view.columnSizing == TableColumnSizing.equal
          ..scrolls = view.stickyHeader
          ..caption = view.caption;
        final childrenMode =
            widget.props.value('children') != null &&
            view.rows.isEmpty &&
            view.columns.isEmpty;
        if (childrenMode) {
          model.fromChildren(view.children, dividers: view.dividers);
        } else {
          model
            ..sticky = view.stickyHeader
            ..fromRows(view);
        }
      case _Root.section:
        // A row group outside a table: no table's dividers to take.
        model.groups.add(model._section(node, tableDividers: true));
        model.watched.remove(node);
      case _Root.row:
        final view = TableRowProps(widget.props);
        model.groups.add(
          _GroupSpec(header: false)
            ..rows.add(
              model._row(node, header: view.header ?? false, dividers: true),
            ),
        );
        model.watched.remove(node);
      case _Root.cell:
        model.groups.add(
          _GroupSpec(header: false)
            ..rows.add(
              _RowSpec()
                ..cells.add(
                  model._cell(
                    node,
                    rowHeader: false,
                    dividers: true,
                    firstChild: true,
                    lastChild: true,
                  ),
                ),
            ),
        );
        model.watched.remove(node);
    }
    return model;
  }

  @override
  Widget build(BuildContext context) {
    final theme = A2uiKitScope.themeOf(context);
    final fontSize = baseFontSize(context);
    final model = _model(theme, fontSize);
    _watch(model.watched);
    // The last-row rule needs the `.a2ui-std-table>tbody` chain: children
    // have it in the standard look only, and a lone section, row or cell
    // has no table. (The rows mode's last row has no divider anyway.)
    final rows = model.finish(
      lastRowRule: widget.root == _Root.table && model.tableEdges,
    );
    final sticky = model.sticky ? (_sticky ??= ScrollController()) : null;
    final cellFont = fontSize * textScale(A2uiTextSize.sm).$1;
    Widget table = HtmlTable(
      rows: rows,
      fixed: model.fixed,
      caption: model.caption,
      dividerColor: theme.color(A2uiColorToken.borderSubtle),
      sticky: sticky,
      stickyBackground: sticky == null
          ? null
          : theme.color(A2uiColorToken.surface),
      children: [
        for (final cell in model.cells)
          _cellSlot(cell, theme: theme, baseSize: fontSize, cellSize: cellFont),
      ],
    );
    table = FocusableScrollBox.scrollView(axis: Axis.horizontal, child: table);
    if (model.scrolls) {
      // `max-height: 480px; overflow-y: auto` (data.tsx:171-174).
      table = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: FocusableScrollBox.scrollView(
          axis: Axis.vertical,
          controller: sticky,
          child: table,
        ),
      );
    }
    // The wrapper is a scroll container with no tabindex: Chrome 159 makes
    // it a tab stop while it can scroll and holds nothing keyboard-
    // focusable, and its arrow keys scroll it (element.cc:9132-9194,
    // INV-152).
    return FocusableScrollBox(
      keyboardScroller: true,
      child: HtmlTableWidth(child: table),
    );
  }

  Widget _cellSlot(
    _CellSpec cell, {
    required A2uiKitTheme theme,
    required double baseSize,
    required double cellSize,
  }) {
    final step = theme.spacingStep;
    // `.a2ui-std-cell{padding:8px}`, none at the row's outer edges
    // (styles.ts:74-76); a `padding` prop is an inline style, over them.
    final own = cell.padding == null
        ? null
        : cssInsets(cell.padding, step: step, fontSize: cellSize);
    final padding = cell.anonymous
        ? EdgeInsets.zero
        : own ??
              EdgeInsetsDirectional.fromSTEB(
                cell.firstChild ? 0 : 8,
                8,
                cell.lastChild ? 0 : 8,
                8,
              ).resolve(TextDirection.ltr);
    var width = A2uiLength.steps(cell.width, step: step);
    // An `em` width is the cell's own font size's.
    if (width is A2uiEm) {
      width = A2uiLength.px(width.resolve(fontSize: cellSize));
    }
    final style = cell.anonymous
        ? null
        : TextStyle(
            fontSize: cellSize,
            height: textScale(A2uiTextSize.sm).$2,
            color: theme.color(
              cell.tertiary
                  ? A2uiColorToken.textTertiary
                  : A2uiColorToken.textDefault,
            ),
            fontWeight: cell.header ? FontWeight.w500 : null,
          );
    // A cell's baseline: its first line's, else its content edge's bottom.
    Widget content = HtmlTableCellBox(
      bottomPadding: padding.bottom,
      child: CssFlex(
        flex: const A2uiFlexStyle(),
        box: A2uiBoxStyle(padding: padding),
        children: _flow(cell.content, theme: theme, fontSize: cellSize),
      ),
    );
    content = DefaultTextStyle.merge(
      style: style,
      textAlign: cell.anonymous ? null : textAlignOf(cell.align),
      child: content,
    );
    final envelope = cell.envelope;
    Widget node = Semantics(
      container: true,
      role: cell.columnHeader ? SemanticsRole.columnHeader : SemanticsRole.cell,
      label: envelope.label,
      hint: envelope.description,
      liveRegion: envelope.live ? true : null,
      // An `aria-label` names the cell in place of its content, which stays
      // below it (a node of its own) rather than in the name.
      explicitChildNodes: envelope.label != null,
      child: content,
    );
    // One tree shape whether hidden or not (RULEBOOK section 2).
    node = ExcludeSemantics(excluding: cell.hidden, child: node);
    return KeyedSubtree(
      key: cell.key,
      child: HtmlTableCell(
        style: HtmlTableCellStyle(
          row: cell.row,
          colSpan: cell.colSpan,
          rowSpan: cell.rowSpan,
          width: width,
          inlinePadding: padding.horizontal,
          vAlign: cell.vAlign,
          divider: cell.divider,
          sticky: cell.sticky,
        ),
        child: Semantics(
          tagForChildren: HtmlTableRowTag(cell.row),
          child: node,
        ),
      ),
    );
  }

  /// A cell's content as a block container lays it out: runs of text and
  /// inline-level components ([isInlineLevel]) as one paragraph each, their
  /// white space collapsed as `white-space: normal` collapses it, and each
  /// block-level component on its own line, the cell's width wide.
  List<Widget> _flow(
    List<Object> content, {
    required A2uiKitTheme theme,
    required double fontSize,
  }) {
    final out = <Widget>[];
    final run = <Object>[];
    void flush() {
      if (run.isEmpty) return;
      final spans = <InlineSpan>[];
      var atStart = true;
      for (var i = 0; i < run.length; i++) {
        final item = run[i];
        if (item is String) {
          // Each run collapses as an inline piece does; the line's own edges
          // lose their space below (CSS Text 3, section 4.1.2).
          var text = collapseInlineWhitespace(item, block: false);
          if (atStart && text.startsWith(' ')) text = text.substring(1);
          if (i == run.length - 1 && text.endsWith(' ')) {
            text = text.substring(0, text.length - 1);
          }
          if (text.isEmpty) continue;
          spans.add(TextSpan(text: text));
          atStart = text.endsWith(' ');
        } else if (item is KitNode) {
          spans.add(
            WidgetSpan(
              alignment: item.type == 'Badge'
                  ? PlaceholderAlignment.middle
                  : PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              // The paragraph scales its inline widgets by the text scale,
              // so they must not scale again (RULEBOOK section 2).
              child: KeyedSubtree(
                key: NodeKey(item.instanceId),
                child: MediaQuery.withNoTextScaling(
                  child: widget.buildChild(item),
                ),
              ),
            ),
          );
          atStart = false;
        }
      }
      run.clear();
      if (spans.isEmpty) return;
      out.add(
        spans.length == 1 && spans.single is TextSpan
            ? Text((spans.single as TextSpan).text!)
            : Text.rich(TextSpan(children: spans)),
      );
    }

    for (final item in content) {
      if (item is KitNode && !isInlineLevel(item)) {
        flush();
        out.add(
          KeyedSubtree(
            key: NodeKey(item.instanceId),
            child: CssFlexItem(
              style: flexItemStyleOf(
                item,
                step: theme.spacingStep,
                fontSize: fontSize,
              ),
              child: widget.buildChild(item),
            ),
          ),
        );
      } else {
        run.add(item);
      }
    }
    flush();
    return out;
  }
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/data.tsx
