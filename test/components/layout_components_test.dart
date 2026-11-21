// Widget tests of the standard layout components, after CopilotKit's
// react-core standard/__tests__/layout.test.tsx and layout-parity.test.tsx.

import 'package:a2ui_flutter/a2ui_flutter.dart' show A2uiSurface;
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_grid.dart';
import 'package:a2ui_kit/src/foundation/platform.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

/// The CssFlex that lays out the text [text]'s nearest container.
CssFlex _containerOf(WidgetTester tester, String text) => tester
    .widgetList<CssFlex>(
      find.ancestor(
        of: find.text(text, findRichText: true),
        matching: find.byType(CssFlex),
      ),
    )
    .first;

/// The CssFlex nearest above [text], [level] containers up (0 is the
/// nearest).
CssFlex _container(WidgetTester tester, String text, int level) => tester
    .widgetList<CssFlex>(
      find.ancestor(
        of: find.text(text, findRichText: true),
        matching: find.byType(CssFlex),
      ),
    )
    .elementAt(level);

Map<String, Object?> _label(String id, String text) => {
  'id': id,
  'component': 'Label',
  'text': text,
};

final _standard = A2uiKitTheme.standard(Brightness.light);

void main() {
  group('Box', () {
    testWidgets('gap and padding are 4px steps; border and radius', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _standard, [
        {
          'id': 'root',
          'component': 'Box',
          'gap': 2,
          'padding': 3,
          'border': true,
          'radius': 'lg',
          'children': ['a'],
        },
        _label('a', 'Team plan'),
      ]);
      final box = _containerOf(tester, 'Team plan');
      expect(box.flex.direction, Axis.vertical);
      expect(box.flex.rowGap, 8);
      expect(box.box.padding, const EdgeInsets.all(12));
      expect(box.box.borderWidth, 1);
      final decoration = box.box.decoration!;
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(
        (decoration.border! as Border).top.color,
        _standard.color(A2uiColorToken.borderDefault),
      );
    });

    testWidgets('direction "row" lays it out horizontally', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Box',
          'direction': 'row',
          'children': ['a'],
        },
        _label('a', 'x'),
      ]);
      expect(_containerOf(tester, 'x').flex.direction, Axis.horizontal);
    });

    testWidgets('a bordered Box in a Card is the inner panel', (tester) async {
      await pumpComponents(tester, theme: _standard, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['card', 'plain'],
        },
        {
          'id': 'card',
          'component': 'Card',
          'children': ['panel'],
        },
        {
          'id': 'panel',
          'component': 'Box',
          'border': true,
          'children': ['t1'],
        },
        _label('t1', 'panel'),
        {
          'id': 'plain',
          'component': 'Box',
          'border': true,
          'children': ['t2'],
        },
        _label('t2', 'plain'),
      ]);
      final panel = _containerOf(tester, 'panel').box;
      expect(panel.borderWidth, 0);
      expect(panel.padding, const EdgeInsets.all(12));
      expect(panel.decoration!.borderRadius, BorderRadius.circular(8));
      expect(panel.decoration!.color, const Color(0xfffcfcfc));
      expect(_containerOf(tester, 'plain').box.borderWidth, 1);
    });

    testWidgets('flush drops the padding, disableAutoSpacing the gap', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Box',
          'padding': 4,
          'flush': true,
          'disableAutoSpacing': true,
          'children': ['a'],
        },
        _label('a', 'x'),
      ]);
      final box = _containerOf(tester, 'x');
      expect(box.box.padding, EdgeInsets.zero);
      expect(box.flex.rowGap, 0);
    });

    testWidgets('minSize and maxSize bound both dimensions', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Box',
          'minSize': 10,
          'maxSize': '80px',
          'children': ['a'],
        },
        _label('a', 'x'),
      ]);
      final box = _containerOf(tester, 'x').box;
      expect(box.minWidth, const A2uiLength.px(40));
      expect(box.minHeight, const A2uiLength.px(40));
      expect(box.maxWidth, const A2uiLength.px(80));
      expect(box.maxHeight, const A2uiLength.px(80));
    });

    testWidgets('a bound gap follows the data model', (tester) async {
      final surfaces = await pumpComponents(
        tester,
        [
          {
            'id': 'root',
            'component': 'Box',
            'gap': {'@path': '/gap'},
            'children': ['a'],
          },
          _label('a', 'x'),
        ],
        data: {'gap': 1},
      );
      expect(_containerOf(tester, 'x').flex.rowGap, 4);
      surfaces.setData('/gap', 5);
      await tester.pump();
      expect(_containerOf(tester, 'x').flex.rowGap, 20);
    });

    testWidgets('onVisible fires once', (tester) async {
      final surfaces = await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'onVisible': {
            'event': {'name': 'more'},
          },
          'children': ['a'],
        },
        _label('a', 'x'),
      ]);
      await tester.pump();
      expect(surfaces.actions.map((a) => a.name), ['more']);
      await tester.pump();
      await tester.drag(find.byType(Scrollable), const Offset(0, -20));
      await tester.pump();
      expect(surfaces.actions, hasLength(1));
    });

    testWidgets('an off-screen container fires onVisible when scrolled in', (
      tester,
    ) async {
      final surfaces = await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['tall', 'late'],
        },
        {
          'id': 'tall',
          'component': 'Box',
          'height': 200,
          'children': <Object>[],
        },
        {
          'id': 'late',
          'component': 'Box',
          'onVisible': {
            'event': {'name': 'seen'},
          },
          'children': ['a'],
        },
        _label('a', 'x'),
      ]);
      await tester.pump();
      expect(surfaces.actions, isEmpty);
      await tester.drag(find.byType(Scrollable), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(surfaces.actions.map((a) => a.name), ['seen']);
    });

    testWidgets('scrollable scrolls along the main axis', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Row',
          'scrollable': true,
          'children': ['a', 'b'],
        },
        _label('a', 'first label here'),
        _label('b', 'second label here'),
      ], width: 120);
      expect(
        find.descendant(
          of: find.byType(A2uiSurface),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    for (final type in ['Column', 'Card', 'Box', 'Grid']) {
      for (final limit in ['height', 'maxHeight']) {
        testWidgets('a vertical scrollable $type scrolls inside its $limit', (
          tester,
        ) async {
          await pumpComponents(tester, [
            {
              'id': 'root',
              'component': type,
              'scrollable': true,
              limit: '100px',
              if (type == 'Grid') 'columns': 1,
              'children': [for (var i = 0; i < 8; i++) 'l$i'],
            },
            for (var i = 0; i < 8; i++) _label('l$i', 'Line $i'),
          ]);
          final scroll = find.descendant(
            of: find.byType(A2uiSurface),
            matching: find.byType(SingleChildScrollView),
          );
          expect(scroll, findsOneWidget);
          expect(tester.getSize(scroll).height, lessThan(100.01));
          final surface = tester.getRect(find.byType(A2uiSurface));
          expect(surface.height, lessThan(100.01));
          // The last line is below the box until the content scrolls.
          final last = find.text('Line 7', findRichText: true);
          expect(tester.getRect(last).top, greaterThan(surface.bottom));
          await tester.drag(scroll, const Offset(0, -400));
          await tester.pump();
          expect(tester.getRect(last).bottom, lessThan(surface.bottom + 0.01));
          expect(tester.takeException(), isNull);
        });
      }
    }

    // layout.tsx:162-167 (`tabIndex: 0`), styles.ts:43-44 (the ring on
    // `:focus-visible`), Chromium's scroll keys (browser_scroll.dart), the
    // box a FocusableScrollBox.
    group('a scrollable container', () {
      /// A scrollable Column of 8 lines in 100px, then a Button below it.
      Future<void> pump(
        WidgetTester tester, {
        bool withButton = false,
      }) => pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['s'],
        },
        {
          'id': 's',
          'component': 'Column',
          'scrollable': true,
          'height': '100px',
          'children': [for (var i = 0; i < 8; i++) 'l$i', if (withButton) 'b'],
        },
        for (var i = 0; i < 8; i++) _label('l$i', 'Line $i'),
        if (withButton) {'id': 'b', 'component': 'Button', 'label': 'Inside'},
      ]);

      bool ringShows(WidgetTester tester) => tester
          .widgetList<FocusRing>(
            find.ancestor(
              of: find.text('Line 0', findRichText: true),
              matching: find.byType(FocusRing),
            ),
          )
          .any((ring) => ring.visible);

      ScrollPosition lines(WidgetTester tester) => tester
          .state<ScrollableState>(
            find
                .ancestor(
                  of: find.text('Line 0', findRichText: true),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;

      /// Whether the focus is on an element in the surface around [text]:
      /// not the route's scope above the surface, and not one inside the
      /// box.
      bool focusAround(WidgetTester tester, String text) {
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused == null) return false;
        final element = find.byElementPredicate((e) => identical(e, focused));
        return find
                .descendant(of: find.byType(A2uiSurface), matching: element)
                .evaluate()
                .isNotEmpty &&
            find
                .ancestor(
                  of: find.text(text, findRichText: true),
                  matching: element,
                )
                .evaluate()
                .isNotEmpty;
      }

      testWidgets('a mouse press focuses it with no ring until a key, '
          'with Ctrl, Alt and Meta up, goes down', (tester) async {
        await pump(tester);
        expect(focusAround(tester, 'Line 0'), isFalse);
        await tester.tap(
          find.text('Line 1', findRichText: true),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        expect(focusAround(tester, 'Line 0'), isTrue);
        expect(ringShows(tester), isFalse);
        // Ctrl down (a modifier's own keydown carries its flag): no ring.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(ringShows(tester), isFalse);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        // Shift counts.
        await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(ringShows(tester), isTrue);
        // A second press on the focused box changes nothing.
        await tester.tap(
          find.text('Line 1', findRichText: true),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        expect(ringShows(tester), isTrue);
      });

      // Tier 1 text review question 1: Chromium focuses from the mousedown
      // it makes of a tap (gesture_manager.cc:230-345), and a touch that
      // moved past the 15px slop is no tap (gesture_detector.cc:337,
      // gesture_configuration.h:247): a finger scrolling over the box
      // leaves the focus where it is.
      testWidgets('a touch drag over it leaves the focus in a text field; a '
          'touch tap focuses it with no ring', (tester) async {
        await pumpComponents(tester, [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['f', 's'],
          },
          {'id': 'f', 'component': 'TextField', 'label': 'Name'},
          {
            'id': 's',
            'component': 'Column',
            'scrollable': true,
            'height': '100px',
            'children': [for (var i = 0; i < 8; i++) 'l$i'],
          },
          for (var i = 0; i < 8; i++) _label('l$i', 'Line $i'),
        ]);
        await tester.tap(find.byType(TextField));
        await tester.pump();
        final field = FocusManager.instance.primaryFocus;
        expect(field?.debugLabel, 'a2ui TextField');
        final line = tester.getCenter(find.text('Line 1', findRichText: true));
        // Every gesture here is a touch, the tester's default kind.
        final drag = await tester.startGesture(line);
        for (var i = 0; i < 10; i++) {
          await drag.moveBy(const Offset(0, -4));
          await tester.pump();
        }
        await drag.up();
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(field));
        expect(lines(tester).pixels, greaterThan(0));
        // A tap: the box's, a pointer's (no ring).
        await tester.tapAt(line);
        await tester.pump();
        expect(focusAround(tester, 'Line 0'), isTrue);
        expect(ringShows(tester), isFalse);
      });

      testWidgets('a touch that moves within 15px is still a tap', (
        tester,
      ) async {
        await pump(tester);
        final line = tester.getCenter(find.text('Line 1', findRichText: true));
        // Touches, the tester's default kind.
        final touch = await tester.startGesture(line);
        await touch.moveBy(const Offset(9, 12));
        await tester.pump();
        // Not focused while the finger is down: a tap down focuses nothing.
        expect(focusAround(tester, 'Line 0'), isFalse);
        await touch.up();
        await tester.pump();
        expect(focusAround(tester, 'Line 0'), isTrue);
        // 16px away is past the slop: a drag, no focus.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        final far = await tester.startGesture(line);
        await far.moveBy(const Offset(0, 16));
        await far.up();
        await tester.pump();
        expect(focusAround(tester, 'Line 0'), isFalse);
      });

      testWidgets('a press on a Button inside it focuses the Button', (
        tester,
      ) async {
        await pump(tester, withButton: true);
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Inside'), kind: PointerDeviceKind.mouse);
        await tester.pump();
        // The Button's own focus, not the box's around it.
        expect(focusAround(tester, 'Inside'), isTrue);
        expect(focusAround(tester, 'Line 0'), isFalse);
        expect(ringShows(tester), isFalse);
      });

      for (final web in [false, true]) {
        testWidgets('Page Down, End and Home scroll it, not the page '
            '(web: $web)', (tester) async {
          debugKitIsWebOverride = web;
          addTearDown(() => debugKitIsWebOverride = null);
          await pump(tester);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(ringShows(tester), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
          await tester.pumpAndSettle();
          expect(lines(tester).pixels, greaterThan(0));
          await tester.sendKeyEvent(LogicalKeyboardKey.end);
          await tester.pumpAndSettle();
          expect(lines(tester).pixels, lines(tester).maxScrollExtent);
          await tester.sendKeyEvent(LogicalKeyboardKey.home);
          await tester.pumpAndSettle();
          expect(lines(tester).pixels, 0);
          // Space pages forward, Shift+Space back.
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          final paged = lines(tester).pixels;
          expect(paged, greaterThan(0));
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pumpAndSettle();
          expect(lines(tester).pixels, lessThan(paged));
          // The focus stays on the box.
          expect(ringShows(tester), isTrue);
        });
      }
    });
  });

  testWidgets('negative sizes, padding and Divider sizes are ignored, as in '
      'CSS', (tester) async {
    await pumpComponents(tester, [
      {
        'id': 'root',
        'component': 'Column',
        'padding': -3,
        'maxWidth': -10,
        'width': '-20px',
        'gap': -1,
        'children': ['a', 'd', 'v', 'b'],
      },
      _label('a', 'Above'),
      {'id': 'd', 'component': 'Divider', 'size': -2, 'spacing': -4},
      {
        'id': 'v',
        'component': 'Row',
        'height': '40px',
        'children': ['vd'],
      },
      {'id': 'vd', 'component': 'Divider', 'axis': 'vertical', 'size': -1},
      {
        'id': 'b',
        'component': 'Badge',
        'label': 'Tag',
        'padding': -2,
        'maxWidth': -5,
      },
    ]);
    expect(tester.takeException(), isNull);
    // The Column fills the surface, unpadded.
    expect(rectOfText(tester, 'Above').left, 0);
    expect(find.text('Tag'), findsOneWidget);
  });

  group('Column and Row', () {
    testWidgets('Row children are 8px apart and centred unless set', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['r1', 'r2'],
        },
        {
          'id': 'r1',
          'component': 'Row',
          'children': ['a'],
        },
        _label('a', 'auto'),
        {
          'id': 'r2',
          'component': 'Row',
          'gap': 0,
          'align': 'start',
          'children': ['b'],
        },
        _label('b', 'none'),
      ]);
      final auto = _containerOf(tester, 'auto').flex;
      expect(auto.columnGap, 8);
      expect(auto.align, A2uiAlign.center);
      final none = _containerOf(tester, 'none').flex;
      expect(none.columnGap, 0);
      expect(none.align, A2uiAlign.start);
    });

    testWidgets('a top-level Column is 16px apart', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b'],
        },
        _label('a', 'one'),
        _label('b', 'two'),
      ]);
      expect(
        rectOfText(tester, 'two').top - rectOfText(tester, 'one').bottom,
        16,
      );
    });

    testWidgets('16px between the groups in a Card, 8px in a group', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Card',
          'children': ['group'],
        },
        {
          'id': 'group',
          'component': 'Column',
          'children': ['inner'],
        },
        {
          'id': 'inner',
          'component': 'Column',
          'children': ['t'],
        },
        _label('t', 'deep'),
      ]);
      expect(_container(tester, 'deep', 0).flex.rowGap, 8);
      expect(_container(tester, 'deep', 1).flex.rowGap, 16);
    });

    testWidgets('weight grows a child in a Row', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Row',
          'gap': 0,
          'children': ['a', 'b'],
        },
        {
          'id': 'a',
          'component': 'Box',
          'weight': 1,
          'children': ['ta'],
        },
        _label('ta', 'grow'),
        _label('b', 'fix'),
      ], width: 300);
      expect(rectOfText(tester, 'fix').right, 300);
      expect(
        rectOfText(tester, 'grow').width,
        300 - rectOfText(tester, 'fix').width,
      );
    });

    for (final (look, theme, align) in [
      ('standard', _standard, TextAlign.right),
      (
        'playground',
        A2uiKitTheme.playground(Brightness.light),
        TextAlign.start,
      ),
    ]) {
      testWidgets('in the $look look, the last Text of a spaceBetween Row '
          '${align == TextAlign.right ? 'is set right' : 'keeps its align'}', (
        tester,
      ) async {
        await pumpComponents(tester, theme: theme, [
          {
            'id': 'root',
            'component': 'Row',
            'justify': 'spaceBetween',
            'children': ['k', 'v'],
          },
          {'id': 'k', 'component': 'Caption', 'text': 'Total'},
          {
            'id': 'v',
            'component': 'Text',
            'text': r'$29',
            'fontWeight': 'medium',
          },
        ], width: 300);
        expect(rectOfText(tester, 'Total').left, 0);
        expect(rectOfText(tester, r'$29').right, 300);
        final value = tester.widget<RichText>(
          find.descendant(
            of: find.byType(A2uiSurface),
            matching: find.byWidgetPredicate(
              (w) => w is RichText && w.text.toPlainText() == r'$29',
            ),
          ),
        );
        expect(value.textAlign, align);
      });
    }

    testWidgets('a long Row wraps its texts at 320px and scale 2', (
      tester,
    ) async {
      await pumpComponents(
        tester,
        [
          {
            'id': 'root',
            'component': 'Row',
            'children': ['a', 'b', 'c'],
          },
          {
            'id': 'a',
            'component': 'Text',
            'text': 'A long description that has to wrap',
          },
          {'id': 'b', 'component': 'Badge', 'label': 'New'},
          {
            'id': 'c',
            'component': 'Text',
            'text': 'Another long text next to it',
          },
        ],
        width: 320,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(
        rectOfText(tester, 'Another long text next to it').right,
        lessThanOrEqualTo(320),
      );
    });
  });

  group('Card', () {
    testWidgets('a top-level Card: padding 16, radius xl, a 1px border', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _standard, [
        {
          'id': 'root',
          'component': 'Card',
          'children': ['t'],
        },
        _label('t', 'inside'),
      ]);
      final card = _containerOf(tester, 'inside');
      expect(card.box.padding, const EdgeInsets.all(16));
      expect(card.box.borderWidth, 1);
      expect(card.box.decoration!.borderRadius, BorderRadius.circular(16));
      expect(card.box.decoration!.color, isNull);
      expect(card.flex.rowGap, 16);
    });

    for (final (size, padding) in [('sm', 8.0), ('md', 16.0), ('lg', 24.0)]) {
      testWidgets('size $size pads $padding', (tester) async {
        await pumpComponents(tester, [
          {
            'id': 'root',
            'component': 'Card',
            'size': size,
            'children': ['t'],
          },
          _label('t', 'x'),
        ]);
        expect(_containerOf(tester, 'x').box.padding, EdgeInsets.all(padding));
      });
    }

    testWidgets('variants and shadow styles', (tester) async {
      await pumpComponents(tester, theme: _standard, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['soft', 'elevated', 'md', 'clear'],
        },
        {
          'id': 'soft',
          'component': 'Card',
          'variant': 'soft',
          'children': ['a'],
        },
        _label('a', 'soft'),
        {
          'id': 'elevated',
          'component': 'Card',
          'variant': 'elevated',
          'children': ['b'],
        },
        _label('b', 'elevated'),
        {
          'id': 'md',
          'component': 'Card',
          'variant': 'elevated',
          'shadowStyle': 'md',
          'children': ['c'],
        },
        _label('c', 'md'),
        {
          'id': 'clear',
          'component': 'Card',
          'variant': 'transparent',
          'children': ['d'],
        },
        _label('d', 'clear'),
      ]);
      expect(
        _containerOf(tester, 'soft').box.decoration!.color,
        _standard.color(A2uiColorToken.surfaceSecondary),
      );
      expect(
        _containerOf(tester, 'elevated').box.decoration!.boxShadow,
        _standard.shadow(A2uiShadowToken.soft),
      );
      expect(
        _containerOf(tester, 'md').box.decoration!.boxShadow,
        _standard.shadow(A2uiShadowToken.md),
      );
      expect(_containerOf(tester, 'clear').box.borderWidth, 0);
    });

    testWidgets('a section Card draws no box', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Card',
          'variant': 'section',
          'border': true,
          'shadow': true,
          'children': ['t'],
        },
        _label('t', 'Section'),
      ]);
      final card = _containerOf(tester, 'Section');
      expect(card.box.borderWidth, 0);
      expect(card.box.padding, EdgeInsets.zero);
      expect(card.box.decoration?.boxShadow, isNull);
      expect(card.flex.rowGap, 16);
    });

    testWidgets('a nested Card flattens; an outline one keeps its box', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Card',
          'children': ['inner', 'outline'],
        },
        {
          'id': 'inner',
          'component': 'Card',
          'padding': 4,
          'children': ['t'],
        },
        _label('t', 'nested'),
        {
          'id': 'outline',
          'component': 'Card',
          'variant': 'outline',
          'children': ['o'],
        },
        _label('o', 'outlined'),
      ]);
      final inner = _containerOf(tester, 'nested');
      expect(inner.box.borderWidth, 0);
      expect(inner.box.padding, EdgeInsets.zero);
      expect(inner.flex.rowGap, 12);
      expect(_containerOf(tester, 'outlined').box.borderWidth, 1);
      expect(_container(tester, 'nested', 1).box.borderWidth, 1);
    });

    testWidgets('a nested Card with a background is the inner panel', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _standard, [
        {
          'id': 'root',
          'component': 'Card',
          'children': ['a', 'b'],
        },
        {
          'id': 'a',
          'component': 'Card',
          'background': 'surface-secondary',
          'children': ['ta'],
        },
        _label('ta', 'neutral'),
        {
          'id': 'b',
          'component': 'Card',
          'background': 'success',
          'children': ['tb'],
        },
        _label('tb', 'tinted'),
      ]);
      final neutral = _containerOf(tester, 'neutral').box;
      expect(neutral.borderWidth, 0);
      expect(neutral.padding, const EdgeInsets.all(12));
      expect(neutral.decoration!.borderRadius, BorderRadius.circular(8));
      expect(neutral.decoration!.color, const Color(0xfffcfcfc));
      expect(
        _containerOf(tester, 'tinted').box.decoration!.color,
        _standard.color(A2uiColorToken.successSoft),
      );
    });

    testWidgets('the single child comes before the children', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Card',
          'child': 'first',
          'children': ['second'],
        },
        _label('first', 'first'),
        _label('second', 'second'),
      ]);
      expect(
        rectOfText(tester, 'first').top,
        lessThan(rectOfText(tester, 'second').top),
      );
    });
  });

  group('Grid', () {
    List<Map<String, Object?>> grid(Map<String, Object?> props) => [
      {
        'id': 'root',
        'component': 'Grid',
        'children': ['a', 'b'],
        ...props,
      },
      {
        'id': 'a',
        'component': 'Card',
        'children': ['ta'],
      },
      _label('ta', 'Left'),
      {
        'id': 'b',
        'component': 'Card',
        'children': ['tb'],
      },
      _label('tb', 'Right'),
    ];

    testWidgets('two columns side by side when wide', (tester) async {
      await pumpComponents(tester, grid({}), width: 720);
      expect(rectOfText(tester, 'Left').top, rectOfText(tester, 'Right').top);
      final columns = tester.widget<CssGrid>(find.byType(CssGrid)).columns;
      expect(columns, const GridColumns.autoFit(count: 2, minTrack: 260));
    });

    testWidgets('one column when narrow', (tester) async {
      await pumpComponents(tester, grid({}), width: 320);
      expect(
        rectOfText(tester, 'Right').top,
        greaterThan(rectOfText(tester, 'Left').bottom),
      );
    });

    testWidgets('columns: 3 has a 173px minimum track and a 16px gap', (
      tester,
    ) async {
      await pumpComponents(tester, grid({'columns': 3}));
      final widget = tester.widget<CssGrid>(find.byType(CssGrid));
      expect(
        widget.columns,
        const GridColumns.autoFit(count: 3, minTrack: 173),
      );
      expect(widget.columnGap, 16);
      expect(widget.rowGap, 16);
    });

    testWidgets('a string template and minChildWidth', (tester) async {
      await pumpComponents(tester, grid({'columns': '1fr 2fr'}));
      expect(
        tester.widget<CssGrid>(find.byType(CssGrid)).columns,
        const GridColumns.tracks([
          GridTrack(fraction: 1),
          GridTrack(fraction: 2),
        ]),
      );
      await pumpComponents(tester, grid({'minChildWidth': 30}));
      expect(
        tester.widget<CssGrid>(find.byType(CssGrid)).columns,
        const GridColumns.autoFill(minTrack: 120),
      );
    });

    // Review 2a regen Q4 (RR30): `auto` is CSS's auto track, not `1fr`.
    testWidgets('a template "auto 1fr": the auto column fits its icon, the fr '
        'column takes the rest', (tester) async {
      await pumpComponents(tester, width: 320, [
        {
          'id': 'root',
          'component': 'Grid',
          'columns': 'auto 1fr',
          'gap': 0,
          'children': ['icon', 'text'],
        },
        {'id': 'icon', 'component': 'Icon', 'name': 'star', 'size': 'lg'},
        _label('text', 'Beside'),
      ]);
      final icon = tester.getRect(find.byType(LucideGlyph));
      expect(icon.width, 24);
      // Two 1fr columns would put the text 160 from the icon.
      expect(rectOfText(tester, 'Beside').left - icon.left, 24);
      expect(tester.takeException(), isNull);
    });

    testWidgets('min-content and max-content template columns', (tester) async {
      await pumpComponents(tester, width: 320, [
        {
          'id': 'root',
          'component': 'Grid',
          'columns': 'min-content max-content 1fr',
          'gap': 0,
          'children': ['a', 'b', 'c'],
        },
        _label('a', 'aaaa bbbb'),
        _label('b', 'cccc dddd'),
        _label('c', 'end'),
      ]);
      final a = rectOfText(tester, 'aaaa bbbb');
      final b = rectOfText(tester, 'cccc dddd');
      // The test font's glyphs are squares: the min-content column is its
      // longest word (4 glyphs), the max-content one its whole line (9).
      // Three 1fr columns would make them equal.
      expect(a.width * 9, closeTo(b.width * 4, 1));
      expect(b.left - a.left, closeTo(a.width, .01));
      expect(rectOfText(tester, 'end').left - b.left, closeTo(b.width, .01));
    });

    testWidgets('a GridItem spanning every column fills the row', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Grid',
          'columns': 2,
          'children': ['a', 'b'],
        },
        _label('a', 'one'),
        {
          'id': 'b',
          'component': 'GridItem',
          'span': 2,
          'children': ['c'],
        },
        _label('c', 'wide'),
      ], width: 720);
      expect(
        rectOfText(tester, 'wide').top,
        greaterThan(rectOfText(tester, 'one').bottom),
      );
      final item = tester.widget<CssGridItem>(
        find.ancestor(
          of: find.text('wide'),
          matching: find.byType(CssGridItem),
        ),
      );
      expect(item.placement, const GridPlacement(span: 2));
    });

    // Tier 1 data review 7: `normal` keeps a grid item with a preferred
    // aspect ratio at its own height (CSS Grid 1, section 6.2); a GridItem's
    // `aspectRatio` is its `aspect-ratio` (style-helpers.ts:165).
    testWidgets('a GridItem with an aspect ratio keeps it beside a taller '
        'one', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Grid',
          'columns': 2,
          'children': ['sq', 'tall'],
        },
        {
          'id': 'sq',
          'component': 'GridItem',
          'aspectRatio': '1 / 1',
          'children': ['s'],
        },
        _label('s', 'square'),
        {
          'id': 'tall',
          'component': 'GridItem',
          // 100 steps of 4px.
          'height': 100,
          'children': ['t'],
        },
        _label('t', 'tall'),
      ], width: 720);
      Rect cell(String text) => tester.getRect(
        find.ancestor(of: find.text(text), matching: find.byType(CssGridItem)),
      );
      expect(cell('tall').height, 400);
      expect(cell('square').height, closeTo(cell('square').width, 1e-6));
      expect(cell('square').height, lessThan(400));
    });

    // Tier 1 data review 3: a span past what the grid can hold is clamped
    // (cssGridMaxTracks), where it froze the layout or ran out of memory.
    testWidgets('a row span of a billion is clamped, and lays out at once', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Grid',
          'columns': 2,
          'gap': 0,
          'children': ['a'],
        },
        {
          'id': 'a',
          'component': 'GridItem',
          'rowSpan': 1000000000,
          'children': ['t'],
        },
        _label('t', 'many rows'),
      ]);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<CssGridItem>(
              find.ancestor(
                of: find.text('many rows'),
                matching: find.byType(CssGridItem),
              ),
            )
            .placement
            .rowSpan,
        cssGridMaxTracks,
      );
    });

    testWidgets('GridItem has no default gap', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Grid',
          'children': ['b'],
        },
        {
          'id': 'b',
          'component': 'GridItem',
          'children': ['c', 'd'],
        },
        _label('c', 'one'),
        _label('d', 'two'),
      ]);
      expect(_containerOf(tester, 'one').flex.rowGap, 0);
    });
  });

  group('Spacer and Divider', () {
    testWidgets('a Divider is a subtle 1px line with 8px around it', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _standard, [
        {
          'id': 'root',
          'component': 'Column',
          'gap': 0,
          'children': ['a', 'd', 'b'],
        },
        _label('a', 'above'),
        {'id': 'd', 'component': 'Divider'},
        _label('b', 'below'),
      ]);
      expect(
        rectOfText(tester, 'below').top - rectOfText(tester, 'above').bottom,
        17,
      );
      final line = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(A2uiSurface),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).border is Border,
          ),
        ),
      );
      final side = ((line.decoration as BoxDecoration).border! as Border).top;
      expect(side.color, _standard.color(A2uiColorToken.borderSubtle));
      expect(side.width, 1);
    });

    testWidgets('flush, spacing, size and color', (tester) async {
      await pumpComponents(tester, theme: _standard, [
        {
          'id': 'root',
          'component': 'Column',
          'gap': 0,
          'children': ['a', 'd', 'b'],
        },
        _label('a', 'above'),
        {
          'id': 'd',
          'component': 'Divider',
          'flush': true,
          'size': 3,
          'color': 'strong',
        },
        _label('b', 'below'),
      ]);
      expect(
        rectOfText(tester, 'below').top - rectOfText(tester, 'above').bottom,
        3,
      );
    });

    testWidgets('a vertical Divider stretches across a Row', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Row',
          'children': ['a', 'd', 'b'],
        },
        {'id': 'a', 'component': 'Text', 'text': 'one', 'size': 'lg'},
        {'id': 'd', 'component': 'Divider', 'axis': 'vertical'},
        _label('b', 'two'),
      ]);
      final line = tester.getRect(
        find.descendant(
          of: find.byType(A2uiSurface),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 1 && w.height == null,
          ),
        ),
      );
      expect(line.height, rectOfText(tester, 'one').height);
    });

    testWidgets('a Spacer grows and is hidden from screen readers', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Row',
          'gap': 0,
          'children': ['a', 's', 'b'],
        },
        _label('a', 'left'),
        {'id': 's', 'component': 'Spacer'},
        _label('b', 'right'),
      ], width: 300);
      expect(rectOfText(tester, 'left').left, 0);
      expect(rectOfText(tester, 'right').right, 300);
      expect(
        find.descendant(
          of: find.byType(A2uiSurface),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
    });

    testWidgets('a Spacer is at least minSize steps', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'gap': 0,
          'children': ['a', 's', 'b'],
        },
        _label('a', 'above'),
        {'id': 's', 'component': 'Spacer', 'minSize': 8},
        _label('b', 'below'),
      ]);
      expect(
        rectOfText(tester, 'below').top - rectOfText(tester, 'above').bottom,
        32,
      );
    });
  });

  group('robustness', () {
    testWidgets('a component this version does not render draws nothing', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'k'],
        },
        _label('a', 'shown'),
        {
          'id': 'k',
          'component': 'Kbd',
          'keys': ['Ctrl', 'K'],
        },
      ]);
      expect(find.text('shown'), findsOneWidget);
      expect(find.text('Ctrl'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an override replaces a builder', (tester) async {
      await pumpComponents(
        tester,
        catalog: a2uiKitCatalog(
          options: A2uiKitOptions(
            overrides: {
              'Label': (context, node, props, buildChild) =>
                  Text('custom ${props.string('text')}'),
            },
          ),
        ),
        [_label('root', 'x')],
      );
      expect(find.text('custom x'), findsOneWidget);
    });

    testWidgets('the root installs the theme text style', (tester) async {
      await pumpComponents(tester, theme: _standard, [
        {'id': 'root', 'component': 'Text', 'text': 'body'},
      ]);
      final style = DefaultTextStyle.of(
        tester.element(find.text('body', findRichText: true)),
      ).style;
      expect(style.fontSize, 16);
      expect(style.color, _standard.color(A2uiColorToken.textDefault));
    });

    test('item styles keep CSS defaults for unknown children', () {
      expect(A2uiFlexItemStyle.normal.grow, 0);
      expect(A2uiFlexItemStyle.normal.shrink, 1);
      expect(A2uiFlexItemStyle.normal.minWidth, isNull);
    });
  });
}
