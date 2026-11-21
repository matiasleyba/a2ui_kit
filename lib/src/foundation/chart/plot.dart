import 'dart:math' as math;

import 'package:a2ui_kit/src/foundation/interaction/browser_scroll.dart';
import 'package:a2ui_kit/src/foundation/interaction/focus_visible.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// What a chart has in focus: a group of marks (the points at one x, the
/// bars of one category) and, when one mark of it is meant, its [item].
@immutable
class PlotFocus {
  /// The focus on [group], or on its [item].
  const PlotFocus(this.group, [this.item]);

  /// The index of the group.
  final int group;

  /// The index of the mark in the group, or null for the whole group.
  final int? item;

  @override
  bool operator ==(Object other) =>
      other is PlotFocus && other.group == group && other.item == item;

  @override
  int get hashCode => Object.hash(group, item);

  @override
  String toString() => 'PlotFocus($group${item == null ? '' : ', $item'})';
}

/// One row of a chart tooltip.
@immutable
class ChartTooltipRow {
  /// A row: [label], [value] and the series' [color].
  const ChartTooltipRow({
    required this.label,
    required this.value,
    this.color,
    this.active = false,
    this.named = true,
  });

  /// The row's name.
  final String label;

  /// Whether the name is written (recharts writes no name, nor its
  /// separator, for one that is not text or a number).
  final bool named;

  /// The formatted value.
  final String value;

  /// The swatch, or null for none.
  final Color? color;

  /// Whether the row is stressed (a stack's total).
  final bool active;

  @override
  bool operator ==(Object other) =>
      other is ChartTooltipRow &&
      other.label == label &&
      other.value == value &&
      other.color == color &&
      other.active == active &&
      other.named == named;

  @override
  int get hashCode => Object.hash(label, value, color, active, named);
}

/// What a chart tooltip shows: an optional title over rows.
@immutable
class ChartTooltipContent {
  /// A tooltip.
  const ChartTooltipContent({required this.rows, this.title});

  /// The title, or null for none.
  final String? title;

  /// The rows.
  final List<ChartTooltipRow> rows;
}

/// What a chart draws at one size, and how it answers the pointer.
///
/// A scene is built for a size from the chart's data; [ChartPlot] paints it
/// and moves its focus. Each library places its own tooltip
/// ([tooltipPosition]): recharts by its `translate.js`, TanStack Charts by
/// its `tooltip-placement.js`.
abstract class PlotScene {
  /// The size the scene is laid out for.
  Size get size;

  /// Paints the scene, with [focus] highlighted when not null.
  void paint(Canvas canvas, PlotFocus? focus);

  /// The focus for a pointer at [position], or null for none.
  PlotFocus? focusAt(Offset position);

  /// The focus after [focus] when an arrow key moves by [delta] (-1 or 1),
  /// or null when there is nothing to focus. With [delta] 0, [focus] itself
  /// when the scene has it, else null.
  PlotFocus? step(PlotFocus? focus, int delta);

  /// The focus a navigation [key] moves to from [focus] under
  /// [ChartInteraction.tanstack]; null when there is nothing to focus.
  ///
  /// By default one [step], and the ends for [PlotNavigation.first] and
  /// [PlotNavigation.last].
  PlotFocus? navigate(PlotFocus? focus, PlotNavigation key) => switch (key) {
    PlotNavigation.next => step(focus, 1),
    PlotNavigation.previous => step(focus, -1),
    PlotNavigation.first => step(null, 1),
    PlotNavigation.last => step(null, -1),
  };

  /// The point the tooltip of [focus] belongs to.
  Offset anchorOf(PlotFocus focus);

  /// The point the tooltip of [focus] sits by, [pointer] being where the
  /// pointer is, or null when the keyboard moved the focus (recharts'
  /// `activeCoordinate`); [anchorOf] by default.
  Offset coordinateOf(PlotFocus focus, Offset? pointer) => anchorOf(focus);

  /// recharts' keyboard (`es6/state/keyboardEventsMiddleware.js`): the rows
  /// its index is checked against (`selectTooltipDisplayedData`), 0 by
  /// default.
  int get keyboardRows => 0;

  /// The indexes the arrow keys step through (`tooltipTicks.length ||
  /// displayedData.length`, keyboardEventsMiddleware.js:102).
  int get keyboardLength => keyboardRows;

  /// Whether row [row] is in the tooltip axis' domain (`isValueWithinDomain`,
  /// es6/state/selectors/combiners/combineActiveTooltipIndex.js:26-38).
  bool keyboardInDomain(int row) => true;

  /// 1 when the arrow keys run left to right, -1 otherwise
  /// (`selectChartDirection`: a chart laid out top to bottom steps back on
  /// ArrowRight, es6/state/selectors/axisSelectors.js:1402-1424).
  int get keyboardDirection => 1;

  /// The focus keyboard [index] shows: the index's group, or on a chart of
  /// items the first item's (combineTooltipPayloadConfigurations.js:29-38).
  PlotFocus keyboardFocus(int index) => PlotFocus(index);

  /// The tooltip of [focus], or null for none.
  ChartTooltipContent? tooltipOf(PlotFocus focus);

  /// The box of the focusable element the scene is drawn in (recharts' or
  /// TanStack's `<svg>`), in the scene's coordinates: where the browser's
  /// focus outline goes. The scene's own box by default.
  Rect get outlineBox => Offset.zero & size;

  /// The box of a second focusable element inside it (the pie's `<g>`,
  /// [ChartPlot.tabStops] 2), or null when it has none or is empty.
  Rect? get innerOutlineBox => null;

  /// The key of the point [focus] names, by which a focus is kept across
  /// a render under [ChartInteraction.tanstack] (the point's `key`,
  /// @tanstack/charts 1.1.0 dist/renderer.js:159-177,
  /// `restoreChartFocusPoint`); null when the scene has no such point.
  Object? focusKeyOf(PlotFocus focus) => null;

  /// The focus of the point keyed [key] ([focusKeyOf]) in this scene, or
  /// null when it has none. With [sameRows], the scene's points stand for
  /// the same row objects as the scene the key was taken from
  /// ([ChartPlot.rowsKey]).
  PlotFocus? focusOfKey(Object key, {bool sameRows = false}) => null;

  /// Where the tooltip box sits, in the scene's box, along an axis whose
  /// place was never set or never parsed (CSSOM drops a value that doesn't
  /// parse): its CSS default. recharts' wrapper sets `top: 0; left: 0`
  /// (es6/component/TooltipBoundingBox.js:83-86), so the top left by
  /// default.
  Offset get tooltipStaticPlace => Offset.zero;

  /// The top left corner of the tooltip of [focus], [tooltip] in size, in
  /// the scene's box. [pointer] is where the pointer is, or null when the
  /// keyboard moved the focus.
  ///
  /// By default the tooltip sits 12px right of [anchorOf], centred on it,
  /// flipped left where it would leave the scene, and kept inside it.
  Offset tooltipPosition(PlotFocus focus, Offset? pointer, Size tooltip) {
    const gap = 12.0;
    final anchor = anchorOf(focus);
    var x = anchor.dx + gap;
    if (x + tooltip.width > size.width) {
      x = anchor.dx - gap - tooltip.width;
    }
    final y = anchor.dy - tooltip.height / 2;
    return Offset(
      x.clamp(0, math.max(0, size.width - tooltip.width)),
      y.clamp(0, math.max(0, size.height - tooltip.height)),
    );
  }
}

/// A key that moves a chart's keyboard focus ([PlotScene.navigate]).
enum PlotNavigation {
  /// Arrow right or down.
  next,

  /// Arrow left or up.
  previous,

  /// Home.
  first,

  /// End.
  last,
}

/// How a [ChartPlot] answers the pointer and the keyboard.
enum ChartInteraction {
  /// recharts 3.10.1's (the standard Chart): the pointer's focus and the
  /// keyboard's are kept apart, the pointer's shown while it is over a mark
  /// (`combineTooltipInteractionState.js:22-58`). Taking the keyboard focus
  /// (Tab, or a press in the chart) shows the first index's tooltip the
  /// first time; ArrowLeft and ArrowRight step one index with no wrap,
  /// Enter shows or hides it, losing the focus hides it and keeps its index
  /// (`keyboardEventsMiddleware.js:15-181`); no key is prevented, so each
  /// also gets the browser's default, off the web too (the arrows, Page Up
  /// and Down, Home, End, Space and Shift+Space scroll the nearest box that
  /// scrolls that way; Enter does nothing). Escape, anywhere, hides the
  /// tooltip's box until its point moves (`TooltipBoundingBox.js:38-60`).
  /// The box glides to each new place over 400ms (CSS `ease`), at once
  /// under reduced motion (`TooltipBoundingBox.js:15-24`, `Tooltip.js:
  /// 47-54`).
  recharts,

  /// TanStack Charts' (`dist/renderer.js:516-692`): the pointer moves the
  /// focus; a click (a tap) pins it (the tooltip is sticky) and the next
  /// one, or a press outside the chart, unpins it; taking the keyboard
  /// focus focuses the first point; the arrow keys, Home and End move it;
  /// Enter and Space pin it; Escape only dismisses a pinned focus.
  tanstack,
}

/// The default size of a chart in a box of unbounded width: recharts'
/// `initialDimension` width (CopilotKit's Chart.tsx:203, :335).
const double kChartFallbackWidth = 320;

/// TanStack Charts' starting width, which its host draws at before it
/// measures itself (`initialWidth = 640`, @tanstack/charts 1.1.0
/// dist/react/RendererChart.js:34, dist/renderer.js:789).
const double kTanstackFallbackWidth = 640;

/// An interactive chart drawing: it builds a [PlotScene] for its width and
/// [height], paints it, follows the pointer, a tap and the arrow keys with
/// a focus, and shows the focus's tooltip with [tooltipBuilder].
///
/// The scene's own pixels never take the keyboard focus from a hidden
/// widget: the drawing is one focusable box whose keys move between the
/// scene's points as its [interaction] says.
class ChartPlot extends StatefulWidget {
  /// A plot of the scene [scene] builds, [height] pixels tall (the height
  /// offered when null).
  const ChartPlot({
    required this.scene,
    this.height,
    this.tooltipBuilder,
    this.width,
    this.reveal = true,
    this.interaction = ChartInteraction.recharts,
    this.fallbackWidth = kChartFallbackWidth,
    this.tabStops = 1,
    this.outline,
    this.underlay,
    this.rowsKey,
    super.key,
  });

  /// What the library's points are drawn for, compared with `==` as React
  /// compares a `useMemo`'s dependencies (`Object.is`: a list by identity),
  /// under [ChartInteraction.tanstack]: while it stays equal, a new scene's
  /// points stand for the same row objects as the last one's, so a focus
  /// kept across it goes back first to the point of its own row
  /// (`restoreChartFocusPoint`, @tanstack/charts 1.1.0 dist/interaction.js:
  /// 36-41; [PlotScene.focusOfKey]). The playground's charts pass their
  /// `data` (the rows are `useMemo`'d on it, charts.tsx), and the PieChart
  /// what its slices are made from besides (its definition's `useMemo`,
  /// charts.tsx:540-589).
  final Object? rowsKey;

  /// What the chart's container holds after its drawing, under the
  /// tooltip (the donut's centre total), filling the plot's box; none when
  /// null.
  ///
  /// It paints over the scene and its focus outline and under the tooltip,
  /// whatever the tree order: TanStack's tooltip has a positive `z-index`
  /// (`zIndex: "1"`, @tanstack/charts 1.1.0 dist/tooltip.js:312-326), which
  /// paints after every `z-index: auto` box of its stacking context, the
  /// positioned ones in tree order before it (CSS 2.1 section 9.9.1;
  /// Appendix E, steps 8 and 9; RULEBOOK section 2, stacking order).
  final Widget? underlay;

  /// The browser's own focus outline (`outline: auto` at offset 0), laid
  /// over the focused element's box ([PlotScene.outlineBox], or the pie's
  /// [PlotScene.innerOutlineBox]) while its focus matches `:focus-visible`
  /// by Chrome's heuristic (focus the keyboard gave; focus a press gave
  /// once a key is pressed); none when null. Neither recharts nor TanStack
  /// Charts sets a focus style, so the user agent's shows (INV-049).
  final Widget? outline;

  /// Whether the drawing grows in when it first shows ([ChartReveal]).
  final bool reveal;

  /// How many stops Tab makes in the drawing under
  /// [ChartInteraction.recharts]: 1, or 2 for a pie, whose `<g>` is
  /// focusable inside the focusable `<svg>` (recharts 3.10.1 es6/polar/
  /// Pie.js:556, :595, `rootTabIndex: 0`; es6/container/RootSurface.js:45).
  final int tabStops;

  /// The width the library draws at before it can measure its box: the
  /// width in a box of unbounded width, and the largest intrinsic width
  /// (recharts' 320, [kChartFallbackWidth]; TanStack's 640,
  /// [kTanstackFallbackWidth]).
  final double fallbackWidth;

  /// How the pointer and the keyboard move the focus.
  final ChartInteraction interaction;

  /// The height in pixels; the height offered when null (0 when unbounded).
  final double? height;

  /// The width in pixels; the width offered when null ([fallbackWidth] when
  /// unbounded).
  final double? width;

  /// Builds the scene for a size.
  final PlotScene Function(Size size) scene;

  /// Builds a tooltip, or null for none.
  final Widget Function(BuildContext context, ChartTooltipContent content)?
  tooltipBuilder;

  @override
  State<ChartPlot> createState() => _ChartPlotState();
}

class _ChartPlotState extends State<ChartPlot>
    with SingleTickerProviderStateMixin {
  /// The pointer's focus (TanStack's whole focus).
  PlotFocus? _focus;
  Offset? _pointer;
  final FocusNode _node = FocusNode(debugLabel: 'chart');

  /// The pie's `<g>`, a second stop for Tab ([ChartPlot.tabStops]).
  final FocusNode _inner = FocusNode(debugLabel: 'chart item group');

  /// recharts' `keyboardInteraction`: its index and whether it is shown.
  int? _keyIndex;
  bool _keyActive = false;

  /// Which of [_node] (1) or [_inner] (2) had the primary focus last, or 0.
  int _focusedStop = 0;

  /// recharts' `TooltipBoundingBox` dismissal: Escape hides the box until
  /// the point it sits by moves from [_dismissedAt].
  bool _dismissed = false;
  Offset _dismissedAt = Offset.zero;

  /// The point the tooltip sat by last (recharts keeps it when the tooltip
  /// goes, `combineTooltipInteractionState.js:55-57`), null before any.
  Offset? _lastCoordinate;

  /// The tooltip box's glide (recharts' `transform 400ms ease`).
  late final _TooltipMotion _motion = _TooltipMotion(
    AnimationController(vsync: this, duration: _TooltipMotion.duration),
  );

  @override
  void initState() {
    super.initState();
    // The scene measures its text when it is built (margins, label
    // thinning): a font that arrives later (a web font) rebuilds it, as
    // `RelayoutWhenSystemFontsChangeMixin` relays out a RenderObject.
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
    // The browser's outline follows the focus and `:focus-visible`.
    _outline = FocusVisibility(_node)..addListener(_outlineChanged);
    _innerOutline = FocusVisibility(_inner)..addListener(_outlineChanged);
    if (!_tanstack) {
      _node.addListener(_focusMoved);
      _inner.addListener(_focusMoved);
      // TooltipBoundingBox.js:38-55: a `keydown` listener on `document`.
      HardwareKeyboard.instance.addHandler(_escape);
    }
  }

  void _fontsChanged() {
    // TanStack renders the same definition again when fonts load
    // (`handleFontLoad`, @tanstack/charts 1.1.0 dist/renderer.js:274-278).
    if (mounted) setState(() => _rendering = true);
  }

  // TanStack's `render` (dist/renderer.js:97-182) runs for new options
  // (`update`, :712-745: a new definition, which new data makes), a new
  // size (the ResizeObserver, :232-249) and loaded fonts (:274-278), never
  // for a move of the focus; only then is a kept focus restored (:159-177;
  // RULEBOOK section 6 item 3). A rebuild for the plot's own state renders
  // nothing.

  /// Whether the next scene is one TanStack renders.
  bool _rendering = true;

  /// Whether that scene's points stand for other rows than the last
  /// rendered one's ([ChartPlot.rowsKey] changed).
  bool _newRows = false;

  /// The size the last scene was rendered at.
  Size? _renderedSize;

  @override
  void didUpdateWidget(ChartPlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rendering = true;
    if (widget.rowsKey != oldWidget.rowsKey) _newRows = true;
  }

  // `:focus-visible` as Chrome applies it ([FocusVisibility], the one rule
  // of it; RULEBOOK section 2, the focus outline row): focus the keyboard
  // (or a script) moved here shows the browser's outline; focus a pointer
  // press gave shows none until a key is pressed while the element holds
  // it. The plot moves its focus itself as a press goes down, so neither
  // focuses on a press of its own ([FocusVisibility.listen], `focusOnPress:
  // false`).

  /// The `<svg>`'s `:focus-visible`.
  late final FocusVisibility _outline;

  /// The pie's `<g>`'s `:focus-visible`.
  late final FocusVisibility _innerOutline;

  void _outlineChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    HardwareKeyboard.instance.removeHandler(_escape);
    _outline
      ..removeListener(_outlineChanged)
      ..dispose();
    _innerOutline
      ..removeListener(_outlineChanged)
      ..dispose();
    _node
      ..removeListener(_focusMoved)
      ..dispose();
    _inner
      ..removeListener(_focusMoved)
      ..dispose();
    _motion.dispose();
    super.dispose();
  }

  bool get _tanstack => widget.interaction == ChartInteraction.tanstack;

  // TooltipBoundingBox.js:38-55: Escape anywhere hides the box where it is
  // (the cursor and the active dots stay); the event goes on.
  bool _escape(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        mounted) {
      setState(() {
        _dismissed = true;
        _dismissedAt = _lastCoordinate ?? Offset.zero;
      });
    }
    return false;
  }

  /// recharts' `focusAction` (keyboardEventsMiddleware.js:140-163): the
  /// first focus shows index 0; a later one shows nothing.
  void _focusIn() {
    if (_keyActive || _keyIndex != null) return;
    setState(() {
      _keyIndex = 0;
      _keyActive = true;
    });
  }

  /// recharts' `blurAction` (keyboardEventsMiddleware.js:164-181): the
  /// tooltip goes, its index stays.
  void _blurOut() {
    if (!_keyActive) return;
    setState(() => _keyActive = false);
  }

  // React's `onFocus` and `onBlur` on the wrapper (RechartsWrapper.js:
  // 268-273, :350-352): focus moving between the `<svg>` and the pie's
  // `<g>` is a blur, then a focus.
  void _focusMoved() {
    final now = _node.hasPrimaryFocus
        ? 1
        : _inner.hasPrimaryFocus
        ? 2
        : 0;
    if (now == _focusedStop) return;
    final was = _focusedStop;
    _focusedStop = now;
    if (was != 0) _blurOut();
    if (now != 0) _focusIn();
  }

  /// recharts' `combineActiveTooltipIndex` of keyboard [index] in [scene]:
  /// clamped to its rows, null outside the tooltip axis' domain.
  // es6/state/selectors/combiners/combineActiveTooltipIndex.js:39-70
  int? _resolve(PlotScene scene, int? index) {
    if (index == null) return null;
    final rows = scene.keyboardRows;
    final clamped = rows > 0 ? index.clamp(0, rows - 1) : math.max(0, index);
    if (clamped < rows && !scene.keyboardInDomain(clamped)) return null;
    return clamped;
  }

  // es6/state/keyboardEventsMiddleware.js:39-112: ArrowRight, ArrowLeft and
  // Enter act, every other key (Up and Down among them, :43-45) is left
  // alone, and none is prevented (RechartsWrapper.js:274-276 dispatches the
  // key and calls no `preventDefault`): each then gets the browser's
  // default ([browserKeyDefault]).
  void _rechartsKey(PlotScene scene, LogicalKeyboardKey key) {
    final enter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    final right = key == LogicalKeyboardKey.arrowRight;
    if (!enter && !right && key != LogicalKeyboardKey.arrowLeft) return;
    final current = _resolve(scene, _keyIndex);
    if (enter) {
      // :52-63: Enter shows or hides the tooltip at its index.
      if (current != null) setState(() => _keyActive = !_keyActive);
      return;
    }
    final movement = (right ? 1 : -1) * scene.keyboardDirection;
    int next;
    if (current == null) {
      // :68-99: the first index in the domain, from the end the key
      // points away from.
      next = -1;
      final rows = scene.keyboardRows;
      for (var j = 0; j < rows; j++) {
        final i = movement > 0 ? j : rows - 1 - j;
        if (_resolve(scene, i) != null) {
          next = i;
          break;
        }
      }
      if (next < 0) return;
    } else {
      // :100-106: one step, none past either end.
      next = current + movement;
      final length = scene.keyboardLength;
      if (length == 0 || next >= length || next < 0) return;
    }
    setState(() {
      _keyIndex = next;
      _keyActive = true;
    });
  }

  /// A press in the chart focuses it, as a browser focuses the `<svg>` (or
  /// the pie's slice) it lands in; a press on a slice moves the focus to it
  /// from wherever it was in the chart (a blur, then a focus). A press on
  /// the element that already has the focus fires neither.
  void _pressFocus(PlotScene scene, Offset position) {
    if (widget.tabStops > 1 && scene.focusAt(position) != null) {
      if (_focusedStop == 2) return;
      if (_focusedStop != 0) _blurOut();
      _focusIn();
      _focusedStop = 2;
      _inner.requestFocus();
      return;
    }
    if (!_node.hasPrimaryFocus) _node.requestFocus();
  }

  /// Whether the focus is pinned (TanStack's sticky tooltip, `pinnedKey`).
  bool _pinned = false;

  /// Whether the keyboard moved the focus last (`focusOwner`).
  bool _keyboardOwns = false;

  /// Where the pointer went down, for a click.
  Offset? _down;

  /// The key of [_focus]'s point under [ChartInteraction.tanstack]
  /// ([PlotScene.focusKeyOf]), by which new data finds it again.
  Object? _focusKey;

  /// Where the tooltip box was last placed at a finite place (a
  /// `translate` or `left`/`top` a browser accepted).
  final _LastPlace _lastTooltip = _LastPlace();

  /// TanStack's focus on a render (dist/renderer.js:159-177): the pointer's,
  /// unpinned, is resolved again where the pointer rests, whether or not it
  /// had found a point (`trackedPointer`, :161-162; `pointsAtPointer` keeps
  /// the place either way, :434-437); any other (the keyboard's, a pinned
  /// one) is found again by its point's key, the point of its own row first
  /// while the rows are the same ([sameRows]; `restoreChartFocusPoint`,
  /// dist/interaction.js:33-47); with none found, no focus and no pin
  /// (:171).
  void _restore(PlotScene scene, {required bool sameRows}) {
    final pointer = _pointer;
    final focus = _focus;
    final key = _focusKey;
    final PlotFocus? kept;
    if (!_keyboardOwns && !_pinned && pointer != null) {
      kept = scene.focusAt(pointer);
    } else if (focus == null) {
      return;
    } else if (key != null) {
      kept = scene.focusOfKey(key, sameRows: sameRows);
    } else {
      kept = scene.step(focus, 0) == focus ? focus : null;
    }
    _focus = kept;
    if (kept == null) _pinned = false;
    _focusKey = kept == null ? null : scene.focusKeyOf(kept);
  }

  void _point(PlotScene scene, Offset position) {
    // dist/renderer.js:524: a pinned focus ignores the pointer.
    if (_tanstack && _pinned) return;
    final focus = scene.focusAt(position);
    _keyboardOwns = false;
    if (focus == _focus && position == _pointer) return;
    setState(() {
      _focus = focus;
      _focusKey = focus == null ? null : scene.focusKeyOf(focus);
      _pointer = position;
    });
  }

  // dist/renderer.js:390-400 (`dismissTooltip`), :539-556
  // (`clearPointerFocus`, `clearKeyboardFocus`): the place the pointer
  // rested goes too, a focus or none.
  void _clear() {
    _pointer = null;
    _keyboardOwns = false;
    if (_focus == null && !_pinned) return;
    setState(() {
      _focus = null;
      _focusKey = null;
      _pinned = false;
    });
  }

  // dist/renderer.js:569-618 (`handleClick`; the tooltip is sticky).
  void _click(PlotScene scene, Offset position) {
    final focus = scene.focusAt(position);
    setState(() {
      if (_pinned) {
        _pinned = false;
      } else if (focus != null) {
        _pinned = true;
      }
      _focus = focus;
      _focusKey = focus == null ? null : scene.focusKeyOf(focus);
      _pointer = position;
      _keyboardOwns = false;
    });
  }

  void _pointerUp(PlotScene scene, PointerUpEvent event) {
    final down = _down;
    _down = null;
    if (!_tanstack || down == null) return;
    final slop = event.kind == PointerDeviceKind.touch ? kTouchSlop : 4.0;
    if ((event.localPosition - down).distance <= slop) {
      _click(scene, event.localPosition);
    }
  }

  void _exit() {
    // dist/renderer.js:539-547 (`clearPointerFocus`).
    if (_tanstack && (_pinned || _keyboardOwns)) return;
    _clear();
  }

  void _focusChange(PlotScene scene, {required bool focused}) {
    if (focused) {
      // dist/renderer.js:671-692 (`handleFocus`): the first point.
      if (_focus != null || _pinned) return;
      final first = scene.navigate(null, PlotNavigation.first);
      setState(() {
        _focus = first;
        _focusKey = first == null ? null : scene.focusKeyOf(first);
        _pointer = null;
        _keyboardOwns = true;
      });
    } else if (_keyboardOwns && !_pinned) {
      // dist/renderer.js:548-556 (`clearKeyboardFocus`).
      _clear();
    }
  }

  // dist/renderer.js:619-670 (`handleKeyDown`).
  // Whether TanStack prevents the key's default (`event.preventDefault()`
  // where it acts; a key it returns from before that keeps the browser's,
  // [browserKeyDefault]).
  bool _tanstackKey(PlotScene scene, LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.escape) {
      if (!_pinned) return false;
      _clear();
      return true;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      if (_focus == null) return false;
      setState(() => _pinned = !_pinned);
      return true;
    }
    final navigation = switch (key) {
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.arrowDown => PlotNavigation.next,
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.arrowUp => PlotNavigation.previous,
      LogicalKeyboardKey.home => PlotNavigation.first,
      LogicalKeyboardKey.end => PlotNavigation.last,
      _ => null,
    };
    // dist/renderer.js:664 (`if (point === void 0) return`): a key TanStack
    // does not navigate with keeps the browser's default.
    if (navigation == null) return false;
    // :635-636 (`if (!points.length) return`): with no point to move to,
    // the focus stays and the key keeps the browser's default.
    final next = scene.navigate(_focus, navigation);
    if (next == null) return false;
    setState(() {
      _focus = next;
      _focusKey = scene.focusKeyOf(next);
      _pointer = null;
      _keyboardOwns = true;
    });
    return true;
  }

  KeyEventResult _key(BuildContext context, PlotScene scene, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // A keydown makes the focus here visible ([FocusVisibility] hears it).
    final key = event.logicalKey;
    if (_tanstack) {
      if (_tanstackKey(scene, key)) return KeyEventResult.handled;
    } else {
      _rechartsKey(scene, key);
    }
    // The browser's default for a key the library did not prevent, on an
    // `<svg>` (RULEBOOK section 2, the interaction row): a scroll key
    // scrolls, Enter does nothing, any other key goes on.
    return browserKeyDefault(context, event);
  }

  @override
  Widget build(BuildContext context) => _PlotSizer(
    width: widget.width,
    height: widget.height,
    fallbackWidth: widget.fallbackWidth,
    // The sizer hands the builder tight constraints: the plot's size.
    child: LayoutBuilder(builder: (context, constraints) => _plot(constraints)),
  );

  Widget _plot(BoxConstraints constraints) {
    final size = constraints.biggest;
    // PERF(port): every pointer move rebuilds and re-measures the whole
    // scene; TanStack builds it once per size and repaints only the focus
    // (dist/renderer.js:407-425, `paintFocus`), and recharts re-renders
    // only what the active index feeds. A scene cached per size and data
    // would do the same.
    final scene = widget.scene(size);
    if (_tanstack) {
      if (size != _renderedSize) {
        _renderedSize = size;
        _rendering = true;
      }
      if (_rendering) {
        _rendering = false;
        _restore(scene, sameRows: !_newRows);
        _newRows = false;
      }
    }
    var mouse = _focus;
    if (mouse != null && !_tanstack) {
      // recharts keeps the hover's index and reads it through a selector on
      // every render: a scene with other rows clamps it to them as it does
      // the keyboard's (combineActiveTooltipIndex.js:39-70 reads whichever
      // interaction is active; tooltipSlice resets neither on new data).
      final index = _resolve(scene, mouse.group);
      mouse = index == null ? null : PlotFocus(index, mouse.item);
      if (mouse != null && scene.step(mouse, 0) != mouse) mouse = null;
    }
    PlotFocus? focus;
    Offset? pointer;
    if (_tanstack || mouse != null) {
      focus = mouse;
      pointer = _pointer;
    } else if (_keyActive) {
      // combineTooltipInteractionState.js:30-35: the pointer's interaction
      // while it is active, else the keyboard's.
      final index = _resolve(scene, _keyIndex);
      // A scene with no rows resolves the index to 0, which has no entry: no
      // tooltip and nothing active (combineActiveTooltipIndex.js:55-63,
      // keyboardEventsMiddleware.js:140-163, TooltipBoundingBox.js:93), as
      // a pointer's focus the scene lacks is dropped above. A pie with no
      // slices (no rows, or a sum of 0 or less) is one, and so is a chart
      // whose rows went while it had the keyboard.
      focus = index == null || index >= scene.keyboardRows
          ? null
          : scene.keyboardFocus(index);
    }
    if (!_tanstack) {
      // TooltipBoundingBox.js:56-60: the box comes back once its point
      // moves.
      final coordinate = focus == null
          ? _lastCoordinate
          : scene.coordinateOf(focus, pointer);
      if (focus != null) _lastCoordinate = coordinate;
      if (_dismissed && (coordinate ?? Offset.zero) != _dismissedAt) {
        _dismissed = false;
      }
    }
    final content = focus == null ? null : scene.tooltipOf(focus);
    final tooltip = content == null || widget.tooltipBuilder == null
        ? null
        : widget.tooltipBuilder!(context, content);
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget drawing = SizedBox.fromSize(
      size: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ChartReveal(
              enabled: widget.reveal,
              child: CustomPaint(
                size: size,
                painter: ChartScenePainter(scene, focus),
              ),
            ),
          ),
          // Keyed, so an outline coming or going never moves the tooltip's
          // subtree to another slot (RULEBOOK section 2, one tree shape).
          if (widget.outline case final outline?) ...[
            if (_outline.visible)
              Positioned.fromRect(
                key: const ValueKey('outline'),
                rect: scene.outlineBox,
                child: IgnorePointer(child: outline),
              ),
            if (_innerOutline.visible)
              if (scene.innerOutlineBox case final box?)
                Positioned.fromRect(
                  key: const ValueKey('inner outline'),
                  rect: box,
                  child: IgnorePointer(child: outline),
                ),
          ],
          // Under the tooltip, over the rest ([ChartPlot.underlay]).
          if (widget.underlay case final underlay?)
            Positioned.fill(key: const ValueKey('underlay'), child: underlay),
          if (tooltip != null && focus != null)
            Positioned.fill(
              key: const ValueKey('tooltip'),
              child: IgnorePointer(
                child: CustomSingleChildLayout(
                  delegate: _TooltipLayout(
                    scene,
                    focus,
                    pointer,
                    motion: _tanstack ? null : _motion,
                    animate: !reduced,
                    last: _lastTooltip,
                  ),
                  // `visibility: hidden` while dismissed (TooltipBoundingBox
                  // .js:88-90): laid out, not painted.
                  child: Opacity(
                    opacity: _dismissed && !_tanstack ? 0 : 1,
                    child: tooltip,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (!_tanstack && widget.tabStops > 1) {
      drawing = FocusTraversalOrder(
        order: const NumericFocusOrder(2),
        child: Focus(focusNode: _inner, child: drawing),
      );
    }
    Widget plot = Focus(
      focusNode: _node,
      onKeyEvent: (node, event) => _key(node.context!, scene, event),
      onFocusChange: _tanstack
          ? (focused) => _focusChange(scene, focused: focused)
          : null,
      child: MouseRegion(
        onHover: (event) => _point(scene, event.localPosition),
        onExit: (_) => _exit(),
        // Raw pointer events, not a gesture: a finger moving over the chart
        // moves the focus without taking the drag from a scrolling page,
        // as pointer events do over an SVG.
        // Focus a press moves here is a pointer's: no `:focus-visible` until
        // a key. Both outlines hear the press, the plot moves the focus.
        child: _outline.listen(
          focusOnPress: false,
          child: _innerOutline.listen(
            focusOnPress: false,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                _down = event.localPosition;
                if (_tanstack) {
                  // The `<svg tabindex=0>` takes the focus on a press
                  // (@tanstack/charts 1.1.0 dist/svg-renderer.js:25, dist/
                  // adapter-shared.js:10-12). The focus arrives after the
                  // pointer's point, which `handleFocus` keeps (dist/renderer.js:
                  // 671-692; [_focusChange]); with none it takes the first.
                  if (!_node.hasPrimaryFocus) _node.requestFocus();
                } else {
                  _pressFocus(scene, event.localPosition);
                }
                _point(scene, event.localPosition);
              },
              onPointerMove: (event) => _point(scene, event.localPosition),
              onPointerUp: (event) => _pointerUp(scene, event),
              onPointerCancel: (_) => _down = null,
              child: drawing,
            ),
          ),
        ),
      ),
    );
    if (!_tanstack) {
      if (widget.tabStops > 1) {
        // The `<svg>` first, then the pie's `<g>` inside it.
        plot = FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: FocusTraversalOrder(
            order: const NumericFocusOrder(1),
            child: plot,
          ),
        );
      }
      return plot;
    }
    // dist/renderer.js:557-568 (`dismissPinnedInteractionOutside`).
    return TapRegion(
      onTapOutside: (_) {
        if (_pinned) _clear();
      },
      child: plot,
    );
  }
}

/// Sizes a chart drawing: [width] (the width offered, or [fallbackWidth]
/// when it is unbounded) by [height] (the height offered, or 0), and
/// answers the intrinsic and dry layout questions a CSS flex or grid
/// container asks without running the [LayoutBuilder] below, which cannot
/// answer them.
///
/// Its minimum intrinsic width is 0 (the playground's `min-w-0` plot); its
/// maximum is [width], or [fallbackWidth]: the width the library draws at
/// before a ResizeObserver measures the box, so a shrink-to-fit box settles
/// there in the browser (INV-031).
class _PlotSizer extends SingleChildRenderObjectWidget {
  const _PlotSizer({
    required this.width,
    required this.height,
    required this.fallbackWidth,
    required super.child,
  });

  final double? width;
  final double? height;
  final double fallbackWidth;

  @override
  _RenderPlotSizer createRenderObject(BuildContext context) =>
      _RenderPlotSizer(width, height, fallbackWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderPlotSizer renderObject) {
    renderObject
      ..width = width
      ..height = height
      ..fallbackWidth = fallbackWidth;
  }
}

class _RenderPlotSizer extends RenderProxyBox {
  _RenderPlotSizer(this._width, this._height, this._fallbackWidth);

  double _fallbackWidth;
  double get fallbackWidth => _fallbackWidth;
  set fallbackWidth(double value) {
    if (value == _fallbackWidth) return;
    _fallbackWidth = value;
    markNeedsLayout();
  }

  double? _width;
  double? get width => _width;
  set width(double? value) {
    if (value == _width) return;
    _width = value;
    markNeedsLayout();
  }

  double? _height;
  double? get height => _height;
  set height(double? value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  Size _sizeFor(BoxConstraints constraints) {
    final width =
        _width ??
        (constraints.hasBoundedWidth ? constraints.maxWidth : _fallbackWidth);
    final height =
        _height ?? (constraints.hasBoundedHeight ? constraints.maxHeight : 0);
    return constraints.constrain(Size(math.max(0, width), math.max(0, height)));
  }

  @override
  double computeMinIntrinsicWidth(double height) => _width ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _width ?? _fallbackWidth;

  @override
  double computeMinIntrinsicHeight(double width) => _height ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) => _height ?? 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => null;

  @override
  void performLayout() {
    size = _sizeFor(constraints);
    child?.layout(BoxConstraints.tight(size));
  }
}

/// Paints a [PlotScene]; tests read the [scene] a chart drew.
class ChartScenePainter extends CustomPainter {
  /// Paints [scene] with [focus].
  ChartScenePainter(this.scene, this.focus);

  /// The scene.
  final PlotScene scene;

  /// The focus, or null.
  final PlotFocus? focus;

  @override
  void paint(Canvas canvas, Size size) => scene.paint(canvas, focus);

  @override
  bool shouldRepaint(ChartScenePainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.focus != focus;
}

/// Places a tooltip where its scene says ([PlotScene.tooltipPosition]),
/// gliding there with [motion] when there is one and [animate] is true.
class _TooltipLayout extends SingleChildLayoutDelegate {
  _TooltipLayout(
    this.scene,
    this.focus,
    this.pointer, {
    required this.last,
    this.motion,
    this.animate = true,
  }) : super(relayout: motion?.controller);

  final PlotScene scene;
  final PlotFocus focus;
  final Offset? pointer;
  final _TooltipMotion? motion;
  final bool animate;
  final _LastPlace last;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: math.max(0, constraints.maxWidth));

  // A place that is not finite (a pie slice whose angle is NaN, a point
  // whose y is NaN) makes a CSS value that doesn't parse, and CSSOM drops it
  // (`setProperty`: "If component value list is null, then return"), so the
  // box keeps its last one, property by property: recharts' whole
  // `transform` (es6/util/tooltip/translate.js:31-64, TooltipBoundingBox.js:
  // 74-91; a running glide carries on; none yet, the wrapper's `top: 0;
  // left: 0`), TanStack's `left` and `top` each on its own (@tanstack/charts
  // 1.1.0 dist/tooltip-position.js:17-18; never set, the box's static
  // position, [PlotScene.tooltipStaticPlace]).
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final target = scene.tooltipPosition(focus, pointer, childSize);
    final motion = this.motion;
    if (motion != null) {
      if (!target.dx.isFinite || !target.dy.isFinite) return motion.current;
      return motion.place(target, animate: animate);
    }
    final staticPlace = scene.tooltipStaticPlace;
    if (target.dx.isFinite) last.left = target.dx;
    if (target.dy.isFinite) last.top = target.dy;
    return Offset(last.left ?? staticPlace.dx, last.top ?? staticPlace.dy);
  }

  @override
  bool shouldRelayout(_TooltipLayout oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.focus != focus ||
      oldDelegate.pointer != pointer ||
      oldDelegate.motion != motion ||
      oldDelegate.animate != animate;
}

/// The last `left` and `top` a tooltip box was given that parsed
/// ([_TooltipLayout]); null for one never set.
class _LastPlace {
  double? left;
  double? top;
}

/// recharts' tooltip glide: `transform 400ms ease` while the tooltip is
/// active (the defaults `animationDuration: 400`, `animationEasing:
/// 'ease'`, `isAnimationActive: 'auto'`, which CopilotKit's `TOOLTIP_PROPS`
/// keep), none under reduced motion.
///
/// A CSS transition starts from where the box is: the wrapper's top left
/// the first time (no transform yet), the last place it was shown after
/// that (INV-050).
// recharts 3.10.1 es6/component/Tooltip.js:47-48, :54; es6/component/
// TooltipBoundingBox.js:15-24, :61-82; es6/util/tooltip/translate.js:
// 57-115 (`translate(x, y)`, hidden until measured)
class _TooltipMotion {
  _TooltipMotion(this.controller);

  /// `animationDuration`.
  static const Duration duration = Duration(milliseconds: 400);

  /// CSS `ease`.
  static const Cubic ease = Cubic(.25, .1, .25, 1);

  final AnimationController controller;

  Offset _from = Offset.zero;
  Offset? _to;

  /// Whether a glide to [_to] waits for the frame's end to start.
  bool _pending = false;

  /// Where the box is now.
  Offset get current {
    final to = _to;
    if (to == null || _pending) return _from;
    return Offset.lerp(_from, to, ease.transform(controller.value))!;
  }

  /// Where to lay the box out this frame when its place is now [target]:
  /// where it is, as a glide to [target] starts (CSS starts a transition
  /// from the box's current place), or [target] itself without [animate].
  Offset place(Offset target, {required bool animate}) {
    if (!animate) {
      _from = target;
      _to = null;
      _pending = false;
      controller.stop();
      return target;
    }
    if (target == _to) return current;
    final start = current;
    _from = start;
    _to = target;
    if (!_pending) {
      _pending = true;
      // Layout can't start an animation; the next frame does.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_pending || _disposed) return;
        _pending = false;
        controller.forward(from: 0);
      });
    }
    return start;
  }

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    controller.dispose();
  }
}

/// The playground's chart grow-in (`.a2-chart svg` in `motion.css`): the
/// drawing is wiped in from the left over 700ms, fading from 40% opacity,
/// on `cubic-bezier(.22, 1, .36, 1)`, once, when it first shows. Nothing
/// moves under reduced motion.
class ChartReveal extends StatefulWidget {
  /// Wipes [child] in.
  const ChartReveal({required this.child, this.enabled = true, super.key});

  /// The drawing.
  final Widget child;

  /// Whether to animate; false shows [child] at once (CopilotKit's standard
  /// Chart has no grow-in).
  final bool enabled;

  /// How long the wipe takes.
  static const Duration duration = Duration(milliseconds: 700);

  /// The wipe's easing (`--ease-smooth-out`).
  static const Cubic curve = Cubic(.22, 1, .36, 1);

  @override
  State<ChartReveal> createState() => _ChartRevealState();
}

class _ChartRevealState extends State<ChartReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ChartReveal.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.enabled || reduced) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // One tree shape (RULEBOOK section 2): the clip and the opacity stay, and
  // go inert (a whole clip, full opacity) when the wipe is done.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final done = _controller.isCompleted;
      final t = done ? 1.0 : ChartReveal.curve.transform(_controller.value);
      return ClipRect(
        clipper: done ? null : _WipeClipper(t),
        clipBehavior: done ? Clip.none : Clip.hardEdge,
        child: Opacity(opacity: done ? 1 : .4 + .6 * t, child: child),
      );
    },
    child: widget.child,
  );
}

class _WipeClipper extends CustomClipper<Rect> {
  _WipeClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_WipeClipper oldClipper) => oldClipper.fraction != fraction;
}

/// A chart's data as a table for screen readers, drawn as nothing: one
/// node per row, each reading every cell after its column's name, as
/// CopilotKit's visually hidden `<table>` reads.
class ChartTableSemantics extends StatelessWidget {
  /// A table of [rows] under [columns].
  const ChartTableSemantics({
    required this.columns,
    required this.rows,
    this.caption,
    this.table = false,
    super.key,
  });

  /// Whether the rows are a table read as upstream's `<table>`: a table
  /// node, a row of column headers (`<th scope="col">`), then a row of
  /// cells per data row, each cell its own text (the standard Chart's
  /// visually hidden table, Chart.tsx:424-452). Without it, each row is one
  /// node that reads each cell after its column ([rowLabel]).
  final bool table;

  /// The column headers.
  final List<String> columns;

  /// The cells, row by row.
  final List<List<String>> rows;

  /// What the table is, read first.
  final String? caption;

  /// The text read for [row].
  String rowLabel(List<String> row) => [
    for (var i = 0; i < row.length; i++)
      if (i < columns.length && columns[i].isNotEmpty)
        '${columns[i]}: ${row[i]}'
      else
        row[i],
  ].join(', ');

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: caption,
    explicitChildNodes: true,
    child: table
        ? Semantics(
            role: SemanticsRole.table,
            container: true,
            explicitChildNodes: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tableRow(columns, SemanticsRole.columnHeader),
                // `<th scope="row">` (Chart.tsx:443) is read as a cell:
                // Flutter's roles have no row header.
                for (final row in rows) _tableRow(row, SemanticsRole.cell),
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A visually hidden table is 1px square in CSS: each node is
              // too.
              for (final row in rows)
                Semantics(
                  container: true,
                  label: rowLabel(row),
                  child: const SizedBox(width: 1, height: 1),
                ),
            ],
          ),
  );

  // A `<tr>` of [cells], each a 1px node in [role] (a visually hidden
  // table's cells are 1px square in CSS). A row with no cells (a Chart
  // with no `xKey` and no series) keeps a 1px box, so the table, which
  // upstream always renders (Chart.tsx:424-452), keeps its node.
  static Widget _tableRow(List<String> cells, SemanticsRole role) => Semantics(
    role: SemanticsRole.row,
    container: true,
    explicitChildNodes: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cells.isEmpty) const SizedBox(width: 1, height: 1),
        for (final cell in cells)
          Semantics(
            role: role,
            container: true,
            label: cell,
            child: const SizedBox(width: 1, height: 1),
          ),
      ],
    ),
  );
}

/// Paints a dashed line from [a] to [b] in [paint], [dash] on and [gap] off
/// (SVG's `stroke-dasharray`).
void paintDashedLine(
  Canvas canvas,
  Offset a,
  Offset b,
  Paint paint, {
  required double dash,
  required double gap,
}) {
  final length = (b - a).distance;
  if (length == 0) return;
  final direction = (b - a) / length;
  for (var start = 0.0; start < length; start += dash + gap) {
    final end = math.min(start + dash, length);
    canvas.drawLine(a + direction * start, a + direction * end, paint);
  }
}

/// The index in [positions] nearest to [value], or -1 when there are none.
int nearestIndex(List<double> positions, double value) {
  var best = -1;
  var distance = double.infinity;
  for (var i = 0; i < positions.length; i++) {
    final d = (positions[i] - value).abs();
    if (d < distance) {
      distance = d;
      best = i;
    }
  }
  return best;
}

// PORT STATUS: confidence=medium todos=0 upstream=recharts@3.10.1, @tanstack/charts@1.1.0 (the browser's scroll keys and `:focus-visible` from foundation/interaction/browser_scroll.dart and focus_visible.dart)
