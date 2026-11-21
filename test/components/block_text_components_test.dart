// Widget tests of the standard Blockquote and Code, after react-core
// standard/text.tsx:269-284 and :374-393, the standard stylesheet's focus
// ring for a scroll container (shared standard/styles.ts:44) and the
// browser's scroll keys (Chromium 159.0.8154.13 keyboard_event_manager.cc).

import 'dart:ui' show Tristate;

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/text/code.dart';
import 'package:a2ui_kit/src/foundation/platform.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';
import '../helpers/paint_calls.dart';
import '../helpers/parity.dart' show paintedPage, renderStandard;

/// Each look and brightness, by name.
final Map<String, A2uiKitTheme> _looks = {
  'standard light': A2uiKitTheme.standard(Brightness.light),
  'standard dark': A2uiKitTheme.standard(Brightness.dark),
  'playground light': A2uiKitTheme.playground(Brightness.light),
  'playground dark': A2uiKitTheme.playground(Brightness.dark),
};

/// `--a2ui-color-border-strong` in each look, as ARGB32 (tokens.dart).
final Map<String, int> _borderStrong = {
  'standard light': 0xffcdcdcd,
  'standard dark': 0xff4a4a4a,
  'playground light': oklch(.21, .012, 285, .15).toARGB32(),
  'playground dark': oklch(1, 0, 0, .12).toARGB32(),
};

/// `--a2ui-color-text-secondary` in each look, as ARGB32.
final Map<String, int> _secondary = {
  'standard light': 0xff5d5d5d,
  'standard dark': 0xffb4b4b4,
  'playground light': oklch(.47, .014, 285).toARGB32(),
  'playground dark': oklch(.68, .012, 285).toARGB32(),
};

/// `--a2ui-color-surface-secondary` in each look, as ARGB32.
final Map<String, int> _surfaceSecondary = {
  'standard light': 0xfff7f7f8,
  'standard dark': 0xff2a2a2a,
  'playground light': oklch(.97, .003, 285).toARGB32(),
  'playground dark': oklch(.205, .006, 285).toARGB32(),
};

/// `--a2ui-color-focus` in each look, as ARGB32.
final Map<String, int> _focus = {
  'standard light': 0xff0285ff,
  'standard dark': 0xff3b9bff,
  'playground light': 0xff0285ff,
  'playground dark': 0xff3b9bff,
};

Map<String, Object?> _root(Map<String, Object?> props) => {
  'id': 'root',
  ...props,
};

/// The style of the run whose text is [text], with what its RichText
/// inherits and every ancestor span's style merged in.
TextStyle _runStyle(WidgetTester tester, String text) {
  final finder = find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(text),
  );
  final rich = tester.widget<RichText>(finder.last);
  TextStyle? found;
  void visit(InlineSpan span, TextStyle style) {
    final merged = style.merge(span.style);
    if (span is! TextSpan) return;
    if (span.text == text) found = merged;
    for (final child in span.children ?? const <InlineSpan>[]) {
      visit(child, merged);
    }
  }

  visit(rich.text, DefaultTextStyle.of(tester.element(finder.last)).style);
  return found!;
}

/// The box the Blockquote draws: the one with a left border.
final Finder _quote = find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).border is Border &&
      ((w.decoration as BoxDecoration).border! as Border).left.width > 0,
);

/// The decoration of the Blockquote's box.
BoxDecoration _quoteBox(WidgetTester tester) =>
    tester.widget<DecoratedBox>(_quote).decoration as BoxDecoration;

/// The Code's box: the DecoratedBox right inside its focus ring.
Finder _codeBox() => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).borderRadius != null &&
      (w.decoration as BoxDecoration).color != null,
);

/// The Code's own scroll position.
ScrollPosition _codeScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: _codeBox(), matching: find.byType(Scrollable)).first,
    )
    .position;

/// A Code block on a page that scrolls, below a tall Text, so the page has
/// somewhere to scroll.
List<Map<String, Object?>> _codeOnPage(String code) => [
  {
    'id': 'root',
    'component': 'Column',
    'children': ['k', 'tall'],
  },
  {'id': 'k', 'component': 'Code', 'text': code},
  {
    'id': 'tall',
    'component': 'Text',
    'text': List.filled(400, 'word').join(' '),
  },
];

/// A line wider than any test surface.
final String _wide =
    'final speed = ${List.filled(40, 'distance').join(' + ')};';

/// Whether the page paints the focus ring round a box of [size] with
/// corners of 8px in [color]: a 2px stroke 2px outside it (the outline's
/// centre 3px out, its corners 3px rounder).
PaintPattern _ring(Size size, int color) => paints
  ..something(
    paintedRRect(
      rrect: RRect.fromLTRBR(
        -3,
        -3,
        size.width + 3,
        size.height + 3,
        const Radius.circular(11),
      ),
      color: Color(color),
    ),
  );

void main() {
  group('Blockquote', () {
    for (final MapEntry(key: name, value: theme) in _looks.entries) {
      testWidgets('in the $name look: a 3px line in the strong border colour '
          'on its left, 12px to the text, the text secondary', (tester) async {
        await pumpComponents(
          tester,
          theme: theme,
          brightness: theme.brightness,
          [
            _root({'component': 'Blockquote', 'text': 'Work is force times'}),
          ],
        );
        final box = _quoteBox(tester);
        final border = box.border! as Border;
        expect(border.left.width, 3);
        expect(border.left.style, BorderStyle.solid);
        expect(border.left.color.toARGB32(), _borderStrong[name]);
        expect(border.top, BorderSide.none);
        expect(border.right, BorderSide.none);
        expect(border.bottom, BorderSide.none);
        expect(box.color, isNull);
        final quote = tester.getRect(_quote);
        final text = rectOfText(tester, 'Work is force times');
        expect(text.left - quote.left, 3 + 12);
        expect(text.top, quote.top);
        expect(text.bottom, quote.bottom);
        expect(
          _runStyle(tester, 'Work is force times').color!.toARGB32(),
          _secondary[name],
        );
      });
    }

    testWidgets('renders inline markdown: bold, italic, code and a link', (
      tester,
    ) async {
      final opened = <Uri>[];
      await renderStandard(
        tester,
        options: A2uiKitOptions(
          look: A2uiKitLook.standard,
          onOpenUrl: opened.add,
        ),
        [
          _root({
            'component': 'Blockquote',
            'text':
                'A **force** is a *push* or `pull`, see '
                '[NCERT](https://ncert.nic.in)',
          }),
        ],
      );
      expect(_runStyle(tester, 'force').fontWeight, FontWeight.w700);
      expect(_runStyle(tester, 'push').fontStyle, FontStyle.italic);
      expect(_runStyle(tester, 'pull').fontFamily, 'monospace');
      TextSpan? link;
      tester.widget<RichText>(find.byType(RichText).last).text.visitChildren((
        span,
      ) {
        if (span is TextSpan && span.text == 'NCERT') link = span;
        return link == null;
      });
      (link!.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
      expect(opened, [Uri.parse('https://ncert.nic.in')]);
    });

    testWidgets('collapses its white space and keeps the inherited size', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Text',
          'text': 'Quote:',
          'size': 'lg',
          'children': ['q'],
        },
        {'id': 'q', 'component': 'Blockquote', 'text': '  one \n\n  two  '},
      ]);
      expect(find.text('one two', findRichText: true), findsOneWidget);
      expect(_runStyle(tester, 'one two').fontSize, 18);
    });

    // Its required `text` (`z.string()`, shared standard/text.ts:82-84)
    // bound to a missing value is unset, so the render check fails and the
    // invalid-props fallback takes its place (SurfaceView.tsx:686-753;
    // upstream's surface-view.test.tsx:565-573).
    testWidgets('with text bound to a missing value shows the invalid-props '
        'fallback', (tester) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Blockquote',
          'text': {'@path': '/missing'},
        }),
      ]);
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Couldn’t display this part: invalid props (text:'),
        findsOne,
      );
    });

    for (final (name, Object text) in [('""', ''), ('"   "', '   ')]) {
      testWidgets('with text $name it holds no line', (tester) async {
        await pumpComponents(tester, [
          {
            'id': 'root',
            'component': 'Column',
            'gap': 0,
            'children': ['a', 'q', 'b'],
          },
          {'id': 'a', 'component': 'Text', 'text': 'above'},
          {'id': 'q', 'component': 'Blockquote', 'text': text},
          {'id': 'b', 'component': 'Text', 'text': 'below'},
        ]);
        expect(tester.takeException(), isNull);
        expect(
          rectOfText(tester, 'below').top,
          rectOfText(tester, 'above').bottom,
        );
      });
    }

    testWidgets('a long quote wraps at 320px and text scale 2, in both '
        'looks', (tester) async {
      for (final theme in [
        A2uiKitTheme.standard(Brightness.light),
        A2uiKitTheme.playground(Brightness.light),
      ]) {
        await pumpComponents(tester, width: 320, textScale: 2, theme: theme, [
          _root({
            'component': 'Blockquote',
            'text':
                'Supercalifragilisticexpialidocious: the rate of change of '
                'momentum of a body is directly proportional to the '
                '**applied force** and takes place in its direction.',
          }),
        ]);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(find.byType(RichText).last).right, 320);
      }
    });

    testWidgets('is read as its text', (tester) async {
      await pumpComponents(tester, [
        _root({'component': 'Blockquote', 'text': 'A **bold** claim'}),
      ]);
      expect(find.semantics.byLabel('A bold claim'), findsOne);
    });
  });

  group('Code', () {
    for (final MapEntry(key: name, value: theme) in _looks.entries) {
      testWidgets('in the $name look its font list ends with a monospace '
          'font every app bundles', (tester) async {
        // On Flutter web only the app's fonts exist: `monospace`, Menlo,
        // Consolas and Courier New all miss there, and the code would fall
        // to a proportional font without flutter_math_fork's
        // KaTeX_Typewriter.
        await pumpComponents(
          tester,
          theme: theme,
          brightness: theme.brightness,
          [
            _root({'component': 'Code', 'text': 'x\t= 1'}),
          ],
        );
        final text = find.text('x       = 1', findRichText: true);
        final style = DefaultTextStyle.of(
          tester.element(text),
        ).style.merge(tester.widget<RichText>(text).text.style);
        expect(style.fontFamily, 'monospace');
        expect(
          style.fontFamilyFallback!.last,
          'packages/flutter_math_fork/KaTeX_Typewriter',
        );
      });
    }

    testWidgets('inline in a Text in a Row, its bottom is its baseline: '
        'measured, it never throws', (tester) async {
      // The Row measures the Text, the Text its line, the line the Code's
      // box: the scroll view inside has no dry baseline, which throws in a
      // debug build unless the box answers for it.
      await pumpComponents(tester, width: 320, textScale: 2, [
        {
          'id': 'root',
          'component': 'Row',
          'children': ['t'],
        },
        {
          'id': 't',
          'component': 'Text',
          'text': 'Run',
          'children': ['k'],
        },
        {'id': 'k', 'component': 'Code', 'text': 'print(1)'},
      ]);
      expect(tester.takeException(), isNull);
      expect(rectOfText(tester, 'print(1)').width, greaterThan(0));
    });

    for (final MapEntry(key: name, value: theme) in _looks.entries) {
      testWidgets('in the $name look: the secondary surface, 8px corners, '
          '12px of padding and the mono font', (tester) async {
        await pumpComponents(
          tester,
          theme: theme,
          brightness: theme.brightness,
          [
            _root({'component': 'Code', 'text': 'x = 1', 'language': 'py'}),
          ],
        );
        final decoration =
            tester.widget<DecoratedBox>(_codeBox()).decoration as BoxDecoration;
        expect(decoration.color!.toARGB32(), _surfaceSecondary[name]);
        expect(decoration.borderRadius, BorderRadius.circular(8));
        final box = tester.getRect(_codeBox());
        final text = rectOfText(tester, 'x = 1');
        expect(text.topLeft - box.topLeft, const Offset(12, 12));
        expect(box.bottom - text.bottom, 12);
        final style = _runStyle(tester, 'x = 1');
        expect(style.fontFamily, 'monospace');
        // .8125em of 16px, and in the standard look Chromium's 13/16 for a
        // `monospace` element sized relative to the default size.
        expect(
          style.fontSize,
          name.startsWith('standard') ? 16 * .8125 * 13 / 16 : 16 * .8125,
        );
      });
    }

    testWidgets('keeps spaces, line breaks and tab stops, and never wraps', (
      tester,
    ) async {
      await pumpComponents(tester, width: 320, [
        _root({'component': 'Code', 'text': 'if a:\n\tb  =  1\nab\tc\n'}),
      ]);
      final rich = tester.widget<RichText>(find.byType(RichText).last);
      expect(rich.text.toPlainText(), 'if a:\n        b  =  1\nab      c');
      // Three lines: as many as the text has, none wrapped.
      final size = rectOfText(tester, rich.text.toPlainText());
      final style = _runStyle(tester, rich.text.toPlainText());
      final line = style.fontSize! * (style.height ?? 1);
      // (Observed: the engine draws each 19.5px line 20px tall.)
      expect(size.height, greaterThanOrEqualTo(3 * line));
      expect(size.height, lessThan(3 * line + 3));
    });

    test('preformattedText: tab stops every 8 columns, one final line break '
        'dropped', () {
      expect(preformattedText('\tx'), '        x');
      expect(preformattedText('1234567\tx'), '1234567 x');
      expect(preformattedText('12345678\tx'), '12345678        x');
      expect(preformattedText('a\n\tb'), 'a\n        b');
      expect(preformattedText('x\n'), 'x');
      expect(preformattedText('x\n\n'), 'x\n');
      expect(preformattedText('\n'), '');
      expect(preformattedText(''), '');
    });

    testWidgets('a final line break adds no line; an empty Code is its '
        'padding tall', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b', 'c', 'd'],
        },
        {'id': 'a', 'component': 'Code', 'text': 'x'},
        {'id': 'b', 'component': 'Code', 'text': 'x\n'},
        {'id': 'c', 'component': 'Code', 'text': ''},
        {'id': 'd', 'component': 'Code', 'text': '\n'},
      ]);
      expect(tester.takeException(), isNull);
      final boxes = [
        for (final element in _codeBox().evaluate())
          tester.getSize(find.byWidget(element.widget)).height,
      ];
      expect(boxes, hasLength(4));
      expect(boxes[0], greaterThan(24));
      expect(boxes[1], boxes[0]);
      expect(boxes[2], 24);
      expect(boxes[3], boxes[0]);
    });

    // Its required `text` (`z.string()`, shared standard/text.ts:102-105)
    // bound to a missing value is unset: the invalid-props fallback takes
    // its place (SurfaceView.tsx:686-753; surface-view.test.tsx:565-573).
    testWidgets('with text bound to a missing value shows the invalid-props '
        'fallback', (tester) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Code',
          'text': {'@path': '/missing'},
        }),
      ]);
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Couldn’t display this part: invalid props (text:'),
        findsOne,
      );
    });

    testWidgets('a line wider than the block scrolls sideways, within the '
        'block, at 320px and text scale 2', (tester) async {
      for (final theme in [
        A2uiKitTheme.standard(Brightness.light),
        A2uiKitTheme.playground(Brightness.dark),
      ]) {
        await pumpComponents(tester, width: 320, textScale: 2, theme: theme, [
          _root({'component': 'Code', 'text': _wide}),
        ]);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(_codeBox()).width, 320);
        expect(_codeScroll(tester).maxScrollExtent, greaterThan(0));
      }
    });

    for (final MapEntry(key: name, value: theme) in _looks.entries) {
      testWidgets('in the $name look Tab focuses it and shows the focus '
          'ring; the arrows scroll it', (tester) async {
        await pumpComponents(
          tester,
          theme: theme,
          brightness: theme.brightness,
          _codeOnPage(_wide),
        );
        final size = tester.getSize(_codeBox());
        expect(paintedPage(tester), isNot(_ring(size, _focus[name]!)));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(paintedPage(tester), _ring(size, _focus[name]!));
        final code = _codeScroll(tester);
        expect(code.pixels, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(code.pixels, greaterThan(0));
        final moved = code.pixels;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(code.pixels, lessThan(moved));
      });
    }

    testWidgets('Down, Space and End scroll the page, not the code, and keep '
        'the focus', (tester) async {
      await pumpComponents(tester, _codeOnPage(_wide));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus;
      final page = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final code = _codeScroll(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(page.pixels, greaterThan(0));
      expect(code.pixels, 0);
      final afterDown = page.pixels;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(page.pixels, greaterThan(afterDown));
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(page.pixels, page.maxScrollExtent);
      expect(code.pixels, 0);
      expect(FocusManager.instance.primaryFocus, focused);
    });

    testWidgets('Shift with an arrow, and Ctrl with Down, scroll nothing', (
      tester,
    ) async {
      await pumpComponents(tester, _codeOnPage(_wide));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final page = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final code = _codeScroll(tester);
      for (final modifier in [
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.controlLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(modifier);
        await tester.pumpAndSettle();
      }
      expect(page.pixels, 0);
      expect(code.pixels, 0);
    });

    testWidgets('a mouse press focuses it with no ring until a key is '
        'pressed; Ctrl alone shows none', (tester) async {
      await pumpComponents(tester, _codeOnPage('x = 1'));
      final size = tester.getSize(_codeBox());
      final gesture = await tester.startGesture(
        tester.getCenter(_codeBox()),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(
        find.descendant(
          of: find.byWidget(
            FocusManager.instance.primaryFocus!.context!.widget,
          ),
          matching: find.text('x = 1', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(paintedPage(tester), isNot(_ring(size, 0xff0285ff)));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(paintedPage(tester), isNot(_ring(size, 0xff0285ff)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(paintedPage(tester), _ring(size, 0xff0285ff));
    });

    testWidgets('on the web an arrow that Flutter would move to another box '
        'is scrolled here; one it moves the same way goes on', (tester) async {
      debugKitIsWebOverride = true;
      addTearDown(() => debugKitIsWebOverride = null);
      await pumpComponents(tester, _codeOnPage(_wide));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final code = _codeScroll(tester);
      final page = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      // Right: Flutter's web shortcut would look for the nearest scrollable
      // round the focus, the page, which does not scroll sideways; the box
      // scrolls itself, as the browser scrolls the focused `<pre>`.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(code.pixels, greaterThan(0));
      // Down: Flutter's web shortcut scrolls the page as the browser does,
      // so the key goes on. On the VM no shortcut scrolls with it, so the
      // page staying put shows the box did not scroll it itself.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(page.pixels, 0);
    });

    testWidgets('Enter does nothing and Tab moves on', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['k', 'b'],
        },
        {'id': 'k', 'component': 'Code', 'text': 'x = 1'},
        {
          'id': 'b',
          'component': 'Button',
          'child': 'l',
          'action': {
            'event': {'name': 'go'},
          },
        },
        {'id': 'l', 'component': 'Text', 'text': 'Go'},
      ]);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final code = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, code);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNot(code));
    });

    testWidgets('is a focusable node holding its code', (tester) async {
      await pumpComponents(tester, [
        _root({'component': 'Code', 'text': 'x = 1', 'language': 'py'}),
      ]);
      final focusable = find.semantics
          .byPredicate(
            (node) =>
                node.getSemanticsData().flagsCollection.isFocused !=
                Tristate.none,
          )
          .evaluate()
          .single;
      final labels = <String>[];
      bool collect(SemanticsNode node) {
        labels.add(node.label);
        node.visitChildren(collect);
        return true;
      }

      collect(focusable);
      // `language` reaches nothing a student gets: only the code is read.
      expect(labels.where((label) => label.isNotEmpty), ['x = 1']);
    });

    testWidgets('its focus node goes with it', (tester) async {
      final surfaces = await pumpComponents(tester, [
        _root({'component': 'Code', 'text': 'x = 1'}),
      ]);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'a2ui scroll box');
      surfaces.apply([
        {
          'version': '1.0',
          'updateComponents': {
            'surfaceId': testSurfaceId,
            'components': [
              _root({'component': 'Text', 'text': 'gone'}),
            ],
          },
        },
      ]);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('a2ui scroll box'),
      );
    });
  });
}
