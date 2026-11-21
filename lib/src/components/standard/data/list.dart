import 'dart:async';

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/node_guard.dart' show isDrawnChild;
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/icons/lucide.dart';
import 'package:a2ui_kit/src/foundation/interaction/actions.dart';
import 'package:a2ui_kit/src/foundation/interaction/focus_visible.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/foundation/text/text_styles.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// What a List tells its ListItem children: CopilotKit's `ListContext`.
class _ListScope extends InheritedWidget {
  const _ListScope({
    required this.marker,
    required this.hasConnector,
    required this.maxMarkerSize,
    required this.ordinal,
    required super.child,
  });

  final ListMarker marker;
  final bool hasConnector;
  final double? maxMarkerSize;

  /// The number of this item in a numbered list, or null when the child is
  /// not a list item.
  final int? ordinal;

  static _ListScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ListScope>();

  @override
  bool updateShouldNotify(_ListScope oldWidget) =>
      marker != oldWidget.marker ||
      hasConnector != oldWidget.hasConnector ||
      maxMarkerSize != oldWidget.maxMarkerSize ||
      ordinal != oldWidget.ordinal;
}

bool _isNative(ListMarker marker) =>
    marker == ListMarker.bullet || marker == ListMarker.number;

/// The standard `List`: `items` (strings, or `{label, description?, icon?,
/// value?}`), or else `children` (ListItem ids or a template).
///
/// Vertical lists are a column 4px apart with a disc or a number before
/// each item (`marker`; `rich` and `none` draw none); `start` is the first
/// number. Horizontal lists are a row 12px apart that scrolls sideways,
/// without markers. With `action`, each item is a button that sends the
/// item's `index`, `label` and `value` (as text) in the event's context;
/// an item's value is then not shown. `connector: "solid"` draws a 2px
/// line down the items' start edge.
Widget buildList(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = ListProps(props);
  final theme = A2uiKitScope.themeOf(context);
  final fontSize = baseFontSize(context);
  final marker = view.marker;
  final horizontal = view.direction == A2uiOrientation.horizontal;
  final hasConnector = view.connector == ListConnector.solid;
  final gap =
      A2uiLength.steps(
        props.value('gap') ?? (horizontal ? 3 : 1),
        step: theme.spacingStep,
      )?.resolve(fontSize: fontSize) ??
      0;
  final native = _isNative(marker) && !horizontal;
  final start = (view.start ?? 1).floor();
  final hasAction = view.action != null;

  final entries = <Widget>[];
  final items = view.items;
  if (items.isNotEmpty) {
    for (var index = 0; index < items.length; index++) {
      final raw = ComponentProps.unwrap(items[index]);
      final entry = raw is Map
          ? raw.cast<Object?, Object?>()
          : <Object?, Object?>{'label': ComponentProps.asString(raw)};
      final label = ComponentProps.asString(entry['label']) ?? '';
      final value = ComponentProps.asString(entry['value']);
      final body = ListItemBody(
        label: label,
        value: hasAction ? null : value,
        description: ComponentProps.asString(entry['description']),
        icon: ComponentProps.asString(entry['icon']),
        markerSize: view.maxMarkerSize,
        hasConnector: hasConnector,
        onPick: hasAction
            ? () => unawaited(
                runActionWithArgs(node, props, 'action', {
                  'index': index,
                  'label': label,
                  'value': ?value,
                }),
              )
            : null,
      );
      // Each entry is an `<li>` (data.tsx:550).
      entries.add(
        _listItem(
          native
              ? _NativeMarked(
                  marker: marker,
                  ordinal: start + index,
                  fontSize: fontSize,
                  child: body,
                )
              : body,
        ),
      );
    }
  } else {
    var ordinal = start;
    for (final child in props.children('children')) {
      if (!isDrawnChild(child)) continue;
      final isItem = child.type == 'ListItem';
      Widget built = _ListScope(
        marker: marker,
        hasConnector: hasConnector,
        maxMarkerSize: view.maxMarkerSize,
        ordinal: isItem ? ordinal : null,
        child: buildChild(child),
      );
      if (isItem) ordinal++;
      // Other children sit in the list's padding without a marker.
      if (native && !isItem) {
        built = Padding(
          padding: EdgeInsetsDirectional.only(start: fontSize * 1.5),
          child: built,
        );
      }
      // A ListItem in a List is an `<li>` (data.tsx:589-591). The role sits
      // here, around the child's node, so the item is the list's own child
      // whatever the child's envelope puts around it.
      if (isItem) built = _listItem(built);
      entries.add(KeyedSubtree(key: NodeKey(child.instanceId), child: built));
    }
  }

  // The list's node holds its items' nodes directly (a list item's parent
  // is a list), so in a horizontal list it sits inside the scroll view's
  // own node.
  Widget listOf(Widget items) =>
      Semantics(container: true, role: SemanticsRole.list, child: items);
  if (horizontal) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: listOf(
        Row(
          crossAxisAlignment: _crossOf(view.align, CrossAxisAlignment.start),
          spacing: gap,
          // Each item is as wide as its content, as a flex item in a row.
          children: [for (final entry in entries) IntrinsicWidth(child: entry)],
        ),
      ),
    );
  }
  return listOf(
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _crossOf(view.align, CrossAxisAlignment.stretch),
      spacing: gap,
      children: entries,
    ),
  );
}

/// [child] as an `<li>` of the list: a list item to a screen reader.
Widget _listItem(Widget child) =>
    Semantics(container: true, role: SemanticsRole.listItem, child: child);

CrossAxisAlignment _crossOf(ListAlign? align, CrossAxisAlignment fallback) =>
    switch (align) {
      ListAlign.start => CrossAxisAlignment.start,
      ListAlign.center => CrossAxisAlignment.center,
      ListAlign.end => CrossAxisAlignment.end,
      ListAlign.stretch => CrossAxisAlignment.stretch,
      null => fallback,
    };

/// The standard `ListItem`: a label with an optional value on the right, a
/// description, a Lucide `icon` or a text `marker` before it, and its
/// `children` under it.
///
/// In a bullet or numbered List it takes the List's marker, unless it has
/// its own. With an `action` (and not `disabled`) it is a button that
/// sends `action` with no arguments, and its value is not shown.
/// `disabled` greys it out.
Widget buildListItem(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = ListItemProps(props);
  final list = _ListScope.maybeOf(context);
  final disabled = view.disabled ?? false;
  final action = disabled ? null : view.action;
  final ownMarker = view.marker;
  final children = [
    for (final child in view.children)
      if (isDrawnChild(child))
        KeyedSubtree(key: NodeKey(child.instanceId), child: buildChild(child)),
  ];
  Widget item = ListItemBody(
    label: view.label,
    value: action != null ? null : view.value,
    description: view.description,
    icon: view.icon,
    marker: ownMarker,
    markerSize: view.markerSize ?? list?.maxMarkerSize,
    hasConnector: list?.hasConnector ?? false,
    onPick: action == null ? null : () => unawaited(action()),
    extra: children.isEmpty
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
  );
  if (list != null && _isNative(list.marker)) {
    final fontSize = baseFontSize(context);
    item = ownMarker != null
        // An own marker replaces the bullet or number; the list's padding
        // stays.
        ? Padding(
            padding: EdgeInsetsDirectional.only(
              start: _markerColumn(context, fontSize),
            ),
            child: item,
          )
        : _NativeMarked(
            marker: list.marker,
            ordinal: list.ordinal ?? 1,
            fontSize: fontSize,
            child: item,
          );
  }
  // Always present (one tree shape, RULEBOOK §2): CopilotKit sets
  // `aria-disabled` and the opacity on the item's own element
  // (data.tsx:598-603), so its children keep their state when `disabled`
  // flips. An enabled item states no enabled state, as `aria-disabled` is
  // then absent.
  return Semantics(
    enabled: disabled ? false : null,
    child: Opacity(opacity: disabled ? .5 : 1, child: item),
  );
}

/// A list item with the browser's outside marker: a disc or "n." in the
/// list's 1.5em start padding, on the first line's baseline.
class _NativeMarked extends StatelessWidget {
  const _NativeMarked({
    required this.marker,
    required this.ordinal,
    required this.fontSize,
    required this.child,
  });

  final ListMarker marker;
  final int ordinal;
  final double fontSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = A2uiKitScope.themeOf(context);
    // The `::marker`'s text: `decimal`'s or `disc`'s symbol and its suffix,
    // a space (CSS Counter Styles 3, sections 6.1 and 6.4), which the
    // marker's `white-space: pre` keeps (CSS Lists 3, section 3.1).
    final text = marker == ListMarker.number ? '$ordinal. ' : '• ';
    final (em, lineHeight) = textScale(A2uiTextSize.md);
    // Top-aligned in the item's first-line height, so it sits on the
    // label's baseline. (A baseline Row cannot report its intrinsic size
    // with a flexible child.)
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          // The list's `padding-inline-start: 1.5em` (data.tsx:381), an em
          // that grows with the text scale.
          width: _markerColumn(context, fontSize),
          // An outside marker ends at the item's start, its space kept, and
          // a wide one reaches out past the padding: the text is laid out
          // at its own width (a start-aligned line keeps its trailing
          // space, which an end-aligned one would hang) and set at the
          // column's end.
          child: OverflowBox(
            alignment: AlignmentDirectional.topEnd,
            maxWidth: double.infinity,
            fit: OverflowBoxFit.deferToChild,
            child: ExcludeSemantics(
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: fontSize * em,
                  height: lineHeight,
                  color: theme.color(A2uiColorToken.textDefault),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// The width of a native list's marker column: its `1.5em` start padding
/// (data.tsx:381), at the text scale.
double _markerColumn(BuildContext context, double fontSize) =>
    MediaQuery.textScalerOf(context).scale(fontSize) * 1.5;

/// The body of a List item (CopilotKit's `ItemBody`): an icon or marker
/// column, then the label and value on one line, the description, and
/// [extra]. With [onPick] the whole item is a button.
class ListItemBody extends StatefulWidget {
  /// An item body.
  const ListItemBody({
    this.label,
    this.value,
    this.description,
    this.icon,
    this.marker,
    this.markerSize,
    this.hasConnector = false,
    this.onPick,
    this.extra,
    super.key,
  });

  /// The label.
  final String? label;

  /// The value on the right.
  final String? value;

  /// The description under the label.
  final String? description;

  /// A Lucide icon before the text.
  final String? icon;

  /// A text marker before the text (when there is no [icon]).
  final String? marker;

  /// The width of the marker column (at least 20px when unset).
  final double? markerSize;

  /// Whether a 2px line runs down the start edge.
  final bool hasConnector;

  /// Picks the item.
  final VoidCallback? onPick;

  /// Children under the text.
  final Widget? extra;

  @override
  State<ListItemBody> createState() => _ListItemBodyState();
}

class _ListItemBodyState extends State<ListItemBody> {
  /// The item's `<button>` focus, with an action: a press gives it, and its
  /// ring shows by `:focus-visible` (RULEBOOK section 2, the focus outline
  /// row).
  late final FocusNode _node = FocusNode(debugLabel: 'a2ui List item');
  late final FocusVisibility _focus = FocusVisibility(_node)
    ..addListener(_changed);

  void _changed() => setState(() {});

  @override
  void dispose() {
    _focus
      ..removeListener(_changed)
      ..dispose();
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = A2uiKitScope.themeOf(context);
    final base = baseFontSize(context);
    final (mdEm, mdLine) = textScale(A2uiTextSize.md);
    final (smEm, smLine) = textScale(A2uiTextSize.sm);
    final label = widget.label;
    final value = widget.value;
    final description = widget.description;
    final iconData = lucideIcon(widget.icon, release: LucideRelease.reactCore);
    final marker = widget.marker;
    final hasLeading =
        widget.icon != null ||
        (marker != null && marker != 'bullet' && marker != 'number');
    final secondary = theme.color(A2uiColorToken.textSecondary);

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((label != null && label.isNotEmpty) || value != null)
          // CopilotKit's line: a flex row, space-between, on one baseline,
          // 12px apart. The label is `flex: 0 1 auto` (it wraps to make
          // room) and the value `flex: none` (it never wraps or shrinks: a
          // value wider than the row overflows it, as in a browser).
          CssFlex(
            flex: const A2uiFlexStyle(
              direction: Axis.horizontal,
              justify: A2uiJustify.spaceBetween,
              align: A2uiAlign.baseline,
              columnGap: 12,
            ),
            children: [
              Text(
                label ?? '',
                style: TextStyle(
                  fontSize: base * mdEm,
                  height: mdLine,
                  color: theme.color(A2uiColorToken.textDefault),
                ),
              ),
              if (value != null)
                CssFlexItem(
                  style: const A2uiFlexItemStyle(shrink: 0),
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: base * mdEm,
                      height: mdLine,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: theme.color(A2uiColorToken.textDefault),
                    ),
                  ),
                ),
            ],
          ),
        if (description != null && description.isNotEmpty)
          Text(
            description,
            style: TextStyle(
              fontSize: base * smEm,
              height: smLine,
              color: secondary,
            ),
          ),
        ?widget.extra,
      ],
    );
    Widget row = column;
    if (hasLeading) {
      final size = widget.markerSize;
      final leading = ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(
            minWidth: size ?? 20,
            maxWidth: size ?? double.infinity,
          ),
          padding: const EdgeInsets.only(top: 2),
          alignment: Alignment.center,
          child: iconData != null
              ? LucideGlyph(iconData, size: 16, color: secondary)
              : widget.icon != null
              ? const SizedBox.shrink()
              : Text(marker ?? '', style: TextStyle(color: secondary)),
        ),
      );
      row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          leading,
          Expanded(child: column),
        ],
      );
    }
    if (widget.hasConnector) {
      row = Container(
        padding: const EdgeInsetsDirectional.only(start: 12),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(
              color: theme.color(A2uiColorToken.borderDefault),
              width: 2,
            ),
          ),
        ),
        child: row,
      );
    }
    final onPick = widget.onPick;
    // Not a decoration but upstream's own structure: CopilotKit's ItemBody
    // returns `row` alone without `onPick` and `<button>{row}</button>` with
    // it (data.tsx:509-521), so React remounts `row` and its children when
    // the action comes or goes (with `disabled`). Ported as is (§0).
    if (onPick == null) return row;
    final radius = BorderRadius.circular(theme.radius('xs') ?? 4);
    return Semantics(
      button: true,
      container: true,
      child: FocusableActionDetector(
        focusNode: _node,
        mouseCursor: SystemMouseCursors.click,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => onPick(),
          ),
        },
        child: _focus.listen(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPick,
            child: FocusRing(
              visible: _focus.visible,
              borderRadius: radius,
              child: row,
            ),
          ),
        ),
      ),
    );
  }
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/data.tsx
