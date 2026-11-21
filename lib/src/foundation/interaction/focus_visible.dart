// `:focus-visible` as Chromium 159.0.8154.13 matches it (RULEBOOK section 2,
// the focus outline row), for an element a2ui_kit draws a focus ring around.
// Blink sources (BSD, $A2UI_THIRDPARTY_SRC/
// chromium@159.0.8154.13/, read, never ported as code):
// third_party/blink/renderer/core/css/selector_checker.cc:3863-3902
// (`MatchesFocusVisiblePseudoClass`), core/input/keyboard_event_manager.cc:
// 355-359, core/dom/node.cc:3644-3660 (`UpdateHadKeyboardEvent`) and
// core/dom/element.cc:8907-8909; and for when a touch focuses (on a tap),
// core/input/gesture_manager.cc:198-345 with ui/events/gesture_detection/
// gesture_detector.cc, gesture_configuration.h and
// gesture_provider_config_helper.cc. The one home of the `:focus-visible`
// rule: every element a2ui_kit draws a focus ring around uses it, the chart
// plot's `<svg>` and `<g>` included.

import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether the focus of one element matches `:focus-visible`, by
/// Chromium's rule: the element has the focus, and it takes text input, or
/// its focus did not come from a pointer press, or a key went down since
/// (with Ctrl, Alt and Meta all up; Shift and Escape count).
///
/// selector_checker.cc:3893-3902: `is_text_input || !last_focus_from_mouse
/// || had_keyboard_event`; keyboard_event_manager.cc:355-359 counts a
/// keydown towards it only with no Ctrl, Alt or Meta; a mouse focus clears
/// it (element.cc:8907-8909), and a press on the element that already has
/// the focus changes nothing (element.cc:8900-8905). Focus a pointer press
/// gave (mouse, touch or pen) is a mouse focus. Flutter's highlight mode is
/// not this rule (a mouse press never changes it, and desktop starts in
/// `traditional`), so the element tracks how its focus came: wrap it in
/// [listen], which also gives it the focus on a press, as a browser gives
/// it to an element with `tabIndex >= 0` (RULEBOOK section 2).
///
/// Listen to it for [visible]; dispose it with the element.
class FocusVisibility extends ChangeNotifier {
  /// The `:focus-visible` of [node]'s element; [textInput] for one that
  /// takes text input, whose focus always shows.
  FocusVisibility(this.node, {this.textInput = false}) {
    node.addListener(_focusChanged);
    HardwareKeyboard.instance.addHandler(_key);
    _focused = node.hasPrimaryFocus;
  }

  /// The element's focus node.
  final FocusNode node;

  /// Whether the element takes text input (`MayTriggerVirtualKeyboard`).
  final bool textInput;

  bool _focused = false;
  bool _pressing = false;
  bool _fromPointer = false;
  bool _hadKey = false;

  /// Whether the element's focus matches `:focus-visible`.
  bool get visible => _focused && (textInput || !_fromPointer || _hadKey);

  /// [child], the element's box, with its presses tracked: a press focuses
  /// the element (unless [focusOnPress] is false or the node cannot take
  /// the focus), and the focus it gives is a pointer's.
  ///
  /// A mouse (or pen) press focuses on pointer down, as a browser's
  /// `mousedown` does. A touch focuses on a tap, never on a drag: Chromium
  /// focuses from the `mousedown` it makes of a `GestureTap`
  /// (gesture_manager.cc:230-345, `HandleMouseFocus` :333; a tap down makes
  /// none, :198-228), and its gesture detector makes no tap of a touch that
  /// moved past the touch slop, 15px (ui/events/gesture_detection/
  /// gesture_detector.cc:337, :634-673; gesture_configuration.h:247 by way
  /// of gesture_provider_config_helper.cc:34; its 0.05px epsilon, a
  /// platform's own slop and the slop doubled for a touch with no contact
  /// size, gesture_detector.cc:34, :485-492, :657-661, are not ported). So a
  /// finger scrolling the page over the element leaves the focus where it
  /// is, a text field's included.
  ///
  /// A browser focuses the nearest focusable element around the press, so
  /// an element that may hold focusable ones ([holdsFocusables], a
  /// scrollable container) takes the focus only when none of them took
  /// it: its request waits a microtask, after the focus change an inner
  /// element's press asked for (inner listeners hear the press first).
  Widget listen({
    required Widget child,
    bool focusOnPress = true,
    bool holdsFocusables = false,
  }) {
    void focus() {
      if (!focusOnPress) return;
      void request() {
        if (node.canRequestFocus && !node.hasFocus) node.requestFocus();
      }

      if (holdsFocusables) {
        scheduleMicrotask(request);
      } else {
        request();
      }
    }

    return Listener(
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.touch) {
          _touch = (pointer: event.pointer, down: event.position, tap: true);
          // An element that moves its focus itself as a press goes down (a
          // chart's `<svg>`, [focusOnPress] false) has it from the pointer,
          // whatever the pointer.
          if (!focusOnPress) _pressing = true;
          return;
        }
        _pressing = true;
        focus();
      },
      onPointerMove: (event) {
        final touch = _touch;
        if (touch == null || touch.pointer != event.pointer) return;
        if ((event.position - touch.down).distance > touchTapSlop) {
          _touch = (pointer: touch.pointer, down: touch.down, tap: false);
        }
      },
      onPointerUp: (event) {
        final touch = _touch;
        if (touch != null && touch.pointer == event.pointer) {
          _touch = null;
          if (touch.tap && focusOnPress) {
            // The tap's focus is a pointer's until it has landed: the focus
            // change and a container's deferred request run in microtasks.
            _pressing = true;
            focus();
            scheduleMicrotask(() => scheduleMicrotask(() => _pressing = false));
            return;
          }
        }
        _pressing = false;
      },
      onPointerCancel: (event) {
        if (_touch?.pointer == event.pointer) _touch = null;
        _pressing = false;
      },
      child: child,
    );
  }

  /// How far a touch may move and still be a tap: Chromium's touch slop
  /// (ui/events/gesture_detection/gesture_configuration.h:247).
  static const double touchTapSlop = 15;

  /// The touch under way on the element: its pointer, where it went down,
  /// and whether it is still a tap.
  ({int pointer, Offset down, bool tap})? _touch;

  void _set(void Function() change) {
    final was = visible;
    change();
    if (visible != was) notifyListeners();
  }

  void _focusChanged() {
    final focused = node.hasPrimaryFocus;
    // A press on the element that already has the focus changes nothing.
    if (focused == _focused) return;
    _set(() {
      _focused = focused;
      if (focused) {
        _fromPointer = _pressing;
        _hadKey = false;
      }
    });
  }

  bool _key(KeyEvent event) {
    if (event is! KeyDownEvent || !_focused) return false;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return false;
    }
    _set(() => _hadKey = true);
    return false;
  }

  @override
  void dispose() {
    node.removeListener(_focusChanged);
    HardwareKeyboard.instance.removeHandler(_key);
    super.dispose();
  }
}

// PORT STATUS: confidence=medium todos=0 upstream=chromium@159.0.8154.13 third_party/blink/renderer/core/css/selector_checker.cc, core/input/keyboard_event_manager.cc, core/input/gesture_manager.cc, core/dom/node.cc, core/dom/element.cc, ui/events/gesture_detection/gesture_detector.cc
