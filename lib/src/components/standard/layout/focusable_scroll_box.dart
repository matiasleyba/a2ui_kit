// A focusable scroll container as a browser gives one, the one translation
// of it (RULEBOOK section 2): CopilotKit's `[data-a2ui-scroll]` boxes (a
// `tabIndex=0` element with `overflow: auto`: the Code block, react-core
// standard/text.tsx:378-388, and a scrollable Column, Row, Box, Card, Grid or
// Flow, `scrollAttributes`, layout.tsx:162-167), and the Table's wrapper, a
// scroll container with no tabindex that Chrome makes a tab stop while it
// holds nothing keyboard-focusable (Chromium 159.0.8154.13 core/dom/
// element.cc:9132-9194, `CanBeKeyboardFocusableScroller` and
// `IsKeyboardFocusableScroller`; not mouse-focusable, :9248-9269). A
// keyboard user reaches it with Tab, scrolls it with the browser's scroll
// keys (foundation/interaction/browser_scroll.dart) and sees a focus ring
// round it while its focus matches `:focus-visible`
// (foundation/interaction/focus_visible.dart): `[data-a2ui-scroll]:focus-
// visible{outline:2px solid var(--a2ui-color-focus,#0285ff);outline-offset:
// 2px}` (shared standard/styles.ts:43-44).

import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/foundation/interaction/browser_scroll.dart';
import 'package:a2ui_kit/src/foundation/interaction/focus_visible.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A scroll container's box that takes the keyboard focus as a browser's
/// does, scrolls with the browser's scroll keys ([browserKeyDefault], the
/// box's own scroll views first) and shows CopilotKit's focus ring
/// ([FocusRing], 2px in the focus token, 2px outside, round
/// [borderRadius]) while its focus matches `:focus-visible`
/// ([FocusVisibility]).
///
/// The box's scroll views are the [FocusableScrollBox.scrollView]s inside
/// [child] (one per axis a box that scrolls both ways has).
///
/// A `tabIndex=0` box (the default) is a tab stop, and a press takes the
/// focus unless an element inside it takes it (a mouse press as it goes
/// down, a touch on a tap, never on a drag). With [keyboardScroller], the
/// box is Chrome's keyboard-focusable scroller instead: a tab stop only
/// while it can scroll and holds nothing that takes the keyboard focus
/// (it stays one while it has the focus), and a press never focuses it.
class FocusableScrollBox extends StatefulWidget {
  /// The focusable box [child] of a scroll container, whose corners are
  /// [borderRadius].
  const FocusableScrollBox({
    required this.child,
    this.borderRadius,
    this.keyboardScroller = false,
    super.key,
  });

  /// The box, holding its [FocusableScrollBox.scrollView]s.
  final Widget child;

  /// The box's corners, which the ring follows.
  final BorderRadiusGeometry? borderRadius;

  /// Whether the box is Chrome's keyboard-focusable scroller (no
  /// `tabindex`) rather than a `tabIndex=0` element.
  final bool keyboardScroller;

  /// One of the box's scroll views: [child] scrolled along [axis], with
  /// [controller], which the box's scroll keys move.
  static Widget scrollView({
    required Axis axis,
    required Widget child,
    ScrollController? controller,
  }) => SingleChildScrollView(
    scrollDirection: axis,
    controller: controller,
    child: _OwnScroll(child: child),
  );

  @override
  State<FocusableScrollBox> createState() => _FocusableScrollBoxState();
}

class _FocusableScrollBoxState extends State<FocusableScrollBox> {
  late final FocusNode _node = FocusNode(debugLabel: 'a2ui scroll box');
  late final FocusVisibility _focus = FocusVisibility(_node)
    ..addListener(_changed);

  /// The contexts inside the box's own scroll views.
  final List<BuildContext> _own = [];

  void _changed() => setState(() {});

  @override
  void initState() {
    super.initState();
    _node.skipTraversal = widget.keyboardScroller;
  }

  @override
  void didUpdateWidget(FocusableScrollBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.keyboardScroller) _node.skipTraversal = false;
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_changed)
      ..dispose();
    _node.dispose();
    super.dispose();
  }

  /// The box's own scrollables, innermost first.
  Iterable<ScrollableState> get _scrollables sync* {
    for (final context in _own.reversed) {
      final state = Scrollable.maybeOf(context);
      if (state != null) yield state;
    }
  }

  /// Chrome's keyboard-focusable scroller: a tab stop while it is focused,
  /// or while it can scroll (`IsScrollableNode`: its content overflows) and
  /// holds nothing keyboard-focusable (`ContainsKeyboardFocusableElements
  /// Slow`), element.cc:9180-9194. Checked after each layout.
  void _updateKeyboardScroller() {
    if (!mounted || !widget.keyboardScroller) return;
    final scrolls = _scrollables.any(
      (state) =>
          state.position.hasContentDimensions &&
          state.position.maxScrollExtent > state.position.minScrollExtent,
    );
    final holdsFocusable = _node.descendants.any(
      (node) => node.canRequestFocus && !node.skipTraversal,
    );
    _node.skipTraversal =
        !_node.hasPrimaryFocus && !(scrolls && !holdsFocusable);
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) =>
      browserKeyDefault(node.context!, event, own: _scrollables);

  @override
  Widget build(BuildContext context) {
    if (widget.keyboardScroller) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _updateKeyboardScroller(),
      );
    }
    final Widget box = Focus(
      focusNode: _node,
      onKeyEvent: _key,
      child: FocusRing(
        visible: _focus.visible,
        offset: 2,
        borderRadius:
            widget.borderRadius?.resolve(Directionality.maybeOf(context)) ??
            BorderRadius.zero,
        child: _OwnScrollScope(
          own: _own,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _updateKeyboardScroller();
              return false;
            },
            child: widget.child,
          ),
        ),
      ),
    );
    // A keyboard-focusable scroller is not mouse-focusable (element.cc:
    // 9264-9266): a press leaves the focus, and its presses are still the
    // pointer's for `:focus-visible`.
    return _focus.listen(
      holdsFocusables: true,
      focusOnPress: !widget.keyboardScroller,
      child: box,
    );
  }
}

/// The list of the contexts inside a [FocusableScrollBox]'s scroll views.
class _OwnScrollScope extends InheritedWidget {
  const _OwnScrollScope({required this.own, required super.child});

  final List<BuildContext> own;

  @override
  bool updateShouldNotify(_OwnScrollScope oldWidget) => own != oldWidget.own;
}

/// Marks the inside of one of a box's scroll views, so the box finds it.
class _OwnScroll extends StatefulWidget {
  const _OwnScroll({required this.child});

  final Widget child;

  @override
  State<_OwnScroll> createState() => _OwnScrollState();
}

class _OwnScrollState extends State<_OwnScroll> {
  List<BuildContext>? _list;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final list = context.getInheritedWidgetOfExactType<_OwnScrollScope>()?.own;
    if (!identical(list, _list)) {
      _list?.remove(context);
      _list = list?..add(context);
    }
  }

  @override
  void dispose() {
    _list?.remove(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/shared/src/generative-ui/standard/styles.ts, packages/react-core/src/v2/generative-ui/standard/layout.tsx, packages/react-core/src/v2/generative-ui/standard/text.tsx
