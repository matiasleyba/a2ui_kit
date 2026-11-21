// The browser's default for a key pressed on a focused element that takes no
// text input (a `<pre tabindex=0>`, a scroll container, a chart's `<svg>`):
// which keys scroll, how far, and which box they scroll (RULEBOOK section 2,
// the interaction row), on the web and off it. The one home of these rules:
// the chart plot, the focusable scroll box (Code, the scrollable containers,
// the Table's wrapper) and every other focusable element that takes no text
// input use it.
//
// From Chromium 159.0.8154.13 (BSD, $A2UI_THIRDPARTY_SRC/
// chromium@159.0.8154.13/, read, never ported as code): third_party/blink/
// renderer/core/input/keyboard_event_manager.cc `MapKeyCodeForScroll`
// (:67-188) and `DefaultSpaceEventHandler` (:493-525); core/input/
// scroll_manager.cc, the scroll chain (`RecomputeScrollChain` :98-146,
// `CanScroll` :148-190, `LogicalScroll` :192-314, `BubblingScroll`
// :316-333).

import 'package:a2ui_kit/src/foundation/platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The keys a browser may scroll with.
final Set<LogicalKeyboardKey> browserScrollKeys = {
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.pageUp,
  LogicalKeyboardKey.pageDown,
  LogicalKeyboardKey.home,
  LogicalKeyboardKey.end,
  LogicalKeyboardKey.space,
};

/// How far a browser's scroll key scrolls.
enum BrowserScrollBy {
  /// A line (`kScrollByLine`).
  line,

  /// A page (`kScrollByPage`).
  page,

  /// To the start or the end (`kScrollByDocument`).
  document,
}

/// A browser's scroll for a key: its `direction`, how far (`by`), and
/// whether Flutter's web shortcuts map the key to the same `ScrollIntent`
/// (`webShortcut`).
typedef BrowserScroll = ({
  AxisDirection direction,
  BrowserScrollBy by,
  bool webShortcut,
});

/// The scroll a browser makes for [key] on an element that takes no text
/// input, or null for none, on Windows and Linux.
// keyboard_event_manager.cc `MapKeyCodeForScroll` (:67-188): Shift or Meta
// stops every key (:72-74); Ctrl lets only Home and End through (:110-120, off
// macOS); Alt is a system key on Windows and Linux, which
// `DefaultNavigationKeyEventHandler` returns on before the map (:551-552;
// macOS's Alt+Up/Down paging, :99-108, is not ported); an arrow is a line,
// Home and End the document, Page Up and Down a page (:136-186).
// `DefaultSpaceEventHandler` (:493-525): Space pages forward in the block
// direction, Shift+Space back; Ctrl, Alt or Meta stops it (:498).
// TODO(port): third_party/blink/renderer/core/scroll/scrollable_area.cc not
// fetched: a line's and a page's length are Flutter's `ScrollAction`'s (50px,
// 80% of the viewport, or the scrollable's `incrementCalculator`).
BrowserScroll? browserScrollFor(
  LogicalKeyboardKey key, {
  required bool shift,
  required bool control,
  required bool alt,
  required bool meta,
}) {
  if (key == LogicalKeyboardKey.space) {
    if (control || alt || meta) return null;
    return (
      direction: shift ? AxisDirection.up : AxisDirection.down,
      by: BrowserScrollBy.page,
      webShortcut: false,
    );
  }
  if (shift || meta || alt) return null;
  final home = key == LogicalKeyboardKey.home;
  if (control && !home && key != LogicalKeyboardKey.end) return null;
  return switch (key) {
    LogicalKeyboardKey.arrowUp => (
      direction: AxisDirection.up,
      by: BrowserScrollBy.line,
      webShortcut: true,
    ),
    LogicalKeyboardKey.arrowDown => (
      direction: AxisDirection.down,
      by: BrowserScrollBy.line,
      webShortcut: true,
    ),
    LogicalKeyboardKey.arrowLeft => (
      direction: AxisDirection.left,
      by: BrowserScrollBy.line,
      webShortcut: true,
    ),
    LogicalKeyboardKey.arrowRight => (
      direction: AxisDirection.right,
      by: BrowserScrollBy.line,
      webShortcut: true,
    ),
    LogicalKeyboardKey.pageUp => (
      direction: AxisDirection.up,
      by: BrowserScrollBy.page,
      webShortcut: true,
    ),
    LogicalKeyboardKey.pageDown => (
      direction: AxisDirection.down,
      by: BrowserScrollBy.page,
      webShortcut: true,
    ),
    LogicalKeyboardKey.home || LogicalKeyboardKey.end => (
      direction: home ? AxisDirection.up : AxisDirection.down,
      by: BrowserScrollBy.document,
      webShortcut: false,
    ),
    _ => null,
  };
}

/// Where [scroll] takes [state]'s position, clamped to its extents; null
/// where its physics take no user offset (`ScrollAction` skips it too,
/// flutter 3.47.9 widgets/scrollable_helpers.dart:503-506).
double? browserScrollEnd(ScrollableState state, BrowserScroll scroll) {
  final position = state.position;
  if (!position.hasPixels || !position.hasContentDimensions) return null;
  final physics = state.resolvedPhysics;
  if (physics != null && !physics.shouldAcceptUserOffset(position)) {
    return null;
  }
  final double end;
  if (scroll.by == BrowserScrollBy.document) {
    end = scroll.direction == state.axisDirection
        ? position.maxScrollExtent
        : position.minScrollExtent;
  } else {
    end =
        position.pixels +
        ScrollAction.getDirectionalIncrement(
          state,
          ScrollIntent(
            direction: scroll.direction,
            type: scroll.by == BrowserScrollBy.page
                ? ScrollIncrementType.page
                : ScrollIncrementType.line,
          ),
        );
  }
  return end.clamp(position.minScrollExtent, position.maxScrollExtent);
}

/// Whether [state] scrolls along [scroll]'s axis and can still move that way.
bool _canMove(ScrollableState state, BrowserScroll scroll) {
  if (axisDirectionToAxis(state.axisDirection) !=
      axisDirectionToAxis(scroll.direction)) {
    return false;
  }
  final end = browserScrollEnd(state, scroll);
  return end != null && end != state.position.pixels;
}

/// The scrollable a browser moves for [scroll] pressed on the element at
/// [context]: the element's [own] scrollers first (one box that scrolls
/// both ways may be two Flutter scroll views, one per axis), then the
/// nearest ancestor that scrolls on the key's axis and can still move that
/// way, passing outward past one at its end; null when none can.
// scroll_manager.cc: the chain starts at the focused element and holds only
// boxes that scroll on the key's axis (`RecomputeScrollChain`, :98-146;
// `CanScroll`, :148-190), innermost first, and the first that scrolls takes
// the key (`LogicalScroll`, :192-314; `BubblingScroll`, :316-333). Never
// Flutter's nearest scrollable of any axis.
ScrollableState? browserScrollTarget(
  BuildContext context,
  BrowserScroll scroll, {
  Iterable<ScrollableState> own = const [],
}) {
  for (final state in own) {
    if (_canMove(state, scroll)) return state;
  }
  final axis = axisDirectionToAxis(scroll.direction);
  var state = Scrollable.maybeOf(context, axis: axis);
  while (state != null) {
    if (_canMove(state, scroll)) return state;
    state = Scrollable.maybeOf(state.context, axis: axis);
  }
  return null;
}

/// The scrollable Flutter's `ScrollAction` would move for [scroll] from
/// [context], or null when it would move none: the nearest scrollable of
/// any axis (else the `PrimaryScrollController`'s), and only along its own
/// axis.
// flutter 3.47.9 widgets/scrollable_helpers.dart:461-517 (`ScrollAction.
// invoke`), :452-459 (`getDirectionalIncrement`: 0 off its axis)
ScrollableState? flutterScrollTarget(
  BuildContext context,
  BrowserScroll scroll,
) {
  var state = Scrollable.maybeOf(context);
  if (state == null) {
    final primary = PrimaryScrollController.maybeOf(context);
    if (primary != null && primary.positions.length == 1) {
      final notification = primary.position.context.notificationContext;
      if (notification != null) state = Scrollable.maybeOf(notification);
    }
  }
  if (state == null || !_canMove(state, scroll)) return null;
  return state;
}

/// The browser's default for [event] on a focused element at [context]
/// that takes no text input and does nothing with keys itself (a
/// `<pre tabindex=0>`, a `<div tabindex=0>` scroll container, an `<svg>`): a
/// scroll key scrolls ([browserScrollFor], [browserScrollTarget], [own]
/// first); Enter does nothing (no such element has an activation
/// behaviour, and CopilotKit's clickable boxes act only on a key aimed at
/// themselves, `event.target === event.currentTarget`, inputs.tsx:421-426,
/// composites.tsx:512-518); any other key goes on, as it bubbles in the
/// browser.
///
/// On the web the key goes on (`ignored`) only where Flutter's web shortcuts
/// give the browser's default exactly: an unmodified arrow or Page Up or Down
/// (`WidgetsApp._defaultWebShortcuts`, flutter 3.47.9 widgets/app.dart:
/// 1308-1343) whose `ScrollAction` moves the scrollable the browser would
/// ([flutterScrollTarget]). The rest is done here and kept (`handled`):
/// Home, End, Space and Shift+Space, which those shortcuts lack or activate
/// with, and an arrow whose nearest scrollable is not the one the browser
/// scrolls. Off the web Flutter's defaults are not a browser's (an arrow
/// moves the focus, Space and Enter activate, Ctrl and an arrow scroll):
/// every scroll key is done here and kept, so the focus stays as a
/// browser's does.
KeyEventResult browserKeyDefault(
  BuildContext context,
  KeyEvent event, {
  Iterable<ScrollableState> own = const [],
}) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter) {
    return KeyEventResult.handled;
  }
  final keyboard = HardwareKeyboard.instance;
  final scroll = browserScrollFor(
    key,
    shift: keyboard.isShiftPressed,
    control: keyboard.isControlPressed,
    alt: keyboard.isAltPressed,
    meta: keyboard.isMetaPressed,
  );
  if (scroll == null) {
    // A scroll key the browser does nothing with (a modified arrow): off the
    // web, a default of Flutter's for it (Ctrl and an arrow scroll,
    // app.dart:1285-1297) is one the browser lacks.
    if (!kitIsWeb &&
        browserScrollKeys.contains(key) &&
        WidgetsApp.defaultShortcuts.keys.any(
          (activator) => activator.accepts(event, keyboard),
        )) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
  final target = browserScrollTarget(context, scroll, own: own);
  if (kitIsWeb &&
      scroll.webShortcut &&
      flutterScrollTarget(context, scroll) == target) {
    return KeyEventResult.ignored;
  }
  if (target != null) {
    // As ScrollAction moves it (scrollable_helpers.dart:512-516).
    target.position.moveTo(
      browserScrollEnd(target, scroll)!,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
    );
  }
  return KeyEventResult.handled;
}

// PORT STATUS: confidence=high todos=1 upstream=chromium@159.0.8154.13 third_party/blink/renderer/core/input/keyboard_event_manager.cc, core/input/scroll_manager.cc
