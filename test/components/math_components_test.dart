// Widget tests of the standard Math, after react-core standard/text.tsx:
// 395-417 and KaTeX 0.16.27's source (dist/katex.css, src/buildHTML.js,
// katex.js, src/Parser.js, src/Settings.js, src/functions/).

import 'dart:math';

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/text/math.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/ast.dart' show SpaceNode;
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

/// Each look and brightness, by name.
final Map<String, A2uiKitTheme> _looks = {
  'standard light': A2uiKitTheme.standard(Brightness.light),
  'standard dark': A2uiKitTheme.standard(Brightness.dark),
  'playground light': A2uiKitTheme.playground(Brightness.light),
  'playground dark': A2uiKitTheme.playground(Brightness.dark),
};

/// The text body colour of each look, as ARGB32.
final Map<String, int> _ink = {
  'standard light': 0xff0d0d0d,
  'standard dark': 0xffececec,
  'playground light': oklch(.2, .008, 285).toARGB32(),
  'playground dark': oklch(.97, .003, 285).toARGB32(),
};

/// KaTeX's `errorColor`, #cc0000 (src/Settings.js:134-136).
const int _katexRed = 0xffcc0000;

Map<String, Object?> _root(Map<String, Object?> props) => {
  'id': 'root',
  ...props,
};

/// The glyph runs the formula draws, each with its style: flutter_math_fork
/// draws each symbol as a RichText.
List<({String text, TextStyle style, Rect rect})> _glyphs(
  WidgetTester tester, {
  Finder? within,
}) {
  final math = within == null
      ? find.byType(Math)
      : find.descendant(of: within, matching: find.byType(Math));
  final finder = find.descendant(of: math, matching: find.byType(RichText));
  return [
    for (final element in finder.evaluate())
      (
        text: (element.widget as RichText).text.toPlainText(),
        style: (element.widget as RichText).text.style ?? const TextStyle(),
        rect: tester.getRect(find.byWidget(element.widget)),
      ),
  ];
}

/// The box the first [length] characters of the Text whose text starts with
/// [start] are drawn in, in global coordinates.
Rect _runBox(WidgetTester tester, String start, int length) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().startsWith(start),
    ),
  );
  return paragraph
      .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: length))
      .first
      .toRect()
      .shift(paragraph.localToGlobal(Offset.zero));
}

/// The text the formula draws in [color], in order.
String _drawnIn(WidgetTester tester, int color) => [
  for (final glyph in _glyphs(tester))
    if (glyph.style.color?.toARGB32() == color) glyph.text,
].join();

void main() {
  group('inline', () {
    testWidgets('is 1.21 times the surrounding size, in its colour, never '
        'bold', (tester) async {
      await pumpComponents(
        tester,
        theme: A2uiKitTheme.standard(Brightness.light),
        [
          {
            'id': 'root',
            'component': 'Text',
            'text': 'So',
            'strong': true,
            'size': 'lg',
            'color': 'secondary',
            'children': ['m'],
          },
          {'id': 'm', 'component': 'Math', 'value': 'x'},
        ],
      );
      final x = _glyphs(tester).single;
      expect(x.text, 'x');
      // `size: "lg"` is 18px; `.katex { font: normal 1.21em }`.
      expect(x.style.fontSize, 18 * 1.21);
      expect(x.style.color!.toARGB32(), 0xff5d5d5d);
      // `font: normal`: not the strong Text's 600 (KaTeX_Math's italic x).
      expect(x.style.fontWeight, isNot(FontWeight.w600));
      expect(x.style.fontWeight, isNot(FontWeight.w700));
    });

    testWidgets("sits on the Text's baseline", (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Text',
          'text': 'Energy',
          'children': ['m'],
        },
        {'id': 'm', 'component': 'Math', 'value': 'K'},
      ]);
      // A laid-out box's baseline, read outside layout: Flutter asserts that
      // only a parent asks for it while laying out, unless the intrinsics
      // flag says the question is a measurement.
      double baselineOf(Finder finder) {
        final box = tester.renderObject<RenderBox>(finder);
        RenderObject.debugCheckingIntrinsics = true;
        try {
          return box.localToGlobal(Offset.zero).dy +
              box.getDistanceToBaseline(TextBaseline.alphabetic)!;
        } finally {
          RenderObject.debugCheckingIntrinsics = false;
        }
      }

      final text = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().startsWith('Energy'),
      );
      // The formula's baseline (flutter_math_fork's, from KaTeX's metrics;
      // its glyphs sit on it by those metrics, which the test font does not
      // have). SkParagraph places the formula's box about 0.23px above the
      // baseline it reports (observed here, flutter 3.47.9): a sub-pixel
      // difference, listed for the pre-release pass; a formula placed by its
      // top or bottom instead is off by a whole line part, which this
      // separates.
      expect(baselineOf(find.byType(Math)), closeTo(baselineOf(text), .5));
    });

    testWidgets('breaks after a top-level relation or operator when the line '
        'is full, never inside a piece', (tester) async {
      await pumpComponents(tester, width: 160, [
        _root({
          'component': 'Math',
          'value': r'E = mc^2 + \frac{1}{2}mv^2 + mgh',
        }),
      ]);
      expect(tester.takeException(), isNull);
      final glyphs = _glyphs(tester);
      final tops = {for (final glyph in glyphs) glyph.rect.top.round()};
      // More than one line ...
      final e = glyphs.firstWhere((g) => g.text == 'E');
      final h = glyphs.lastWhere((g) => g.text == 'h');
      expect(h.rect.top, greaterThan(e.rect.bottom));
      expect(tops.length, greaterThan(1));
      // ... each within the 160px, each break after "=" or "+".
      for (final glyph in glyphs) {
        expect(glyph.rect.right, lessThanOrEqualTo(160 + 1e-6));
      }
      final pieces = find
          .descendant(of: find.byType(KitMath), matching: find.byType(Math))
          .evaluate()
          .length;
      // `E =`, `mc^2 +`, `\frac12 mv^2 +`, `mgh`.
      expect(pieces, 4);
    });

    testWidgets('keeps the space after an operator it may break at, as the '
        'whole formula has it', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['i', 'b'],
        },
        {'id': 'i', 'component': 'Math', 'value': 'a = b + c'},
        {'id': 'b', 'component': 'Math', 'value': 'a = b + c', 'block': true},
      ]);
      final inline = find.byType(KitMath).first;
      final block = find.byType(KitMath).last;
      List<double> gaps(Finder formula) {
        final glyphs = _glyphs(tester, within: formula);
        return [
          for (var i = 0; i + 1 < glyphs.length; i++)
            glyphs[i + 1].rect.left - glyphs[i].rect.right,
        ];
      }

      // a, =, b, +, c: thick spaces round "=", medium round "+", 5/18 and
      // 4/18 of the formula's 19.36px (within the engine's single-precision
      // layout).
      final inlineGaps = gaps(inline);
      expect(inlineGaps, hasLength(4));
      for (var i = 0; i < 4; i++) {
        expect(inlineGaps[i], closeTo(gaps(block)[i], 1e-4), reason: '$i');
      }
      expect(inlineGaps[0], closeTo(16 * 1.21 * 5 / 18, 1e-4));
      expect(inlineGaps[1], closeTo(16 * 1.21 * 5 / 18, 1e-4));
      expect(inlineGaps[2], closeTo(16 * 1.21 * 4 / 18, 1e-4));
      expect(inlineGaps[3], closeTo(16 * 1.21 * 4 / 18, 1e-4));
    });

    testWidgets('a formula line is at least a .katex line tall: 1.2 of its '
        '1.21em', (tester) async {
      // The standard look's text has the font's own line height, under
      // 1.2 of 1.21em, and \cdot is short: only the strut makes the line
      // that tall.
      await pumpComponents(
        tester,
        theme: A2uiKitTheme.standard(Brightness.light),
        [
          _root({'component': 'Math', 'value': r'\cdot'}),
        ],
      );
      expect(
        tester.getSize(find.byType(Math)).height,
        lessThan(16 * 1.21 * 1.2),
      );
      expect(
        tester.getSize(find.byType(KitMath)).height,
        greaterThanOrEqualTo(16 * 1.21 * 1.2),
      );
    });

    testWidgets('an empty formula draws nothing, no line tall', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'gap': 0,
          'children': ['a', 'm', 'b'],
        },
        {'id': 'a', 'component': 'Text', 'text': 'above'},
        {'id': 'm', 'component': 'Math', 'value': ''},
        {'id': 'b', 'component': 'Text', 'text': 'below'},
      ]);
      expect(
        rectOfText(tester, 'below').top,
        rectOfText(tester, 'above').bottom,
      );
    });

    testWidgets("inside a Text, a formula continues the Text's line", (
      tester,
    ) async {
      // KaTeX's `.katex` is an inline span in the Text's span: its first
      // piece fills the Text's first line after "Speed is", the rest
      // breaks to the next. The wrong layout this rules out: the whole
      // formula on a line of its own below "Speed is".
      await pumpComponents(tester, width: 240, [
        {
          'id': 'root',
          'component': 'Text',
          'text': 'Speed is',
          'children': ['m'],
        },
        {
          'id': 'm',
          'component': 'Math',
          'value': r'v = \frac{d}{t} = \frac{100}{20} = 5',
        },
      ]);
      final v = _glyphs(tester).firstWhere((g) => g.text == 'v');
      final speed = _runBox(tester, 'Speed is', 5);
      expect(v.rect.top, lessThan(speed.bottom));
    });

    testWidgets("inside a Text, its pieces break with the Text's line, each "
        "unbroken, after the Text's words", (tester) async {
      // Four pieces (`E =`, `mc^2 +`, `\frac12 mv^2 +`, `mgh`) on lines of
      // the Text's own paragraph, the first after "So". The wrong layouts
      // this rules out: the formula a box of its own (no piece of the
      // Text's paragraph) or broken inside a piece.
      await pumpComponents(tester, width: 160, [
        {
          'id': 'root',
          'component': 'Text',
          'text': 'So',
          'children': ['m'],
        },
        {
          'id': 'm',
          'component': 'Math',
          'value': r'E = mc^2 + \frac{1}{2}mv^2 + mgh',
        },
      ]);
      expect(tester.takeException(), isNull);
      final line = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().startsWith('So'),
      );
      final pieces = find.descendant(of: line, matching: find.byType(Math));
      expect(pieces, findsNWidgets(4));
      final so = _runBox(tester, 'So', 2);
      final e = _glyphs(tester).firstWhere((g) => g.text == 'E');
      expect(e.rect.top, lessThan(so.bottom));
      expect(e.rect.left, greaterThan(so.right));
      final h = _glyphs(tester).lastWhere((g) => g.text == 'h');
      expect(h.rect.top, greaterThan(e.rect.bottom));
      // `mgh` is one piece: its glyphs share a line.
      final m = _glyphs(tester).lastWhere((g) => g.text == 'm');
      expect(m.rect.top, h.rect.top);
    });

    testWidgets('inside a Text, a line holding a piece is at least a .katex '
        'line tall', (tester) async {
      // The standard look's text has the font's own line height (1em in the
      // test font), under 1.2 of 1.21em, and \cdot is short: only the
      // `.katex` strut makes the Text's line that tall.
      await pumpComponents(
        tester,
        theme: A2uiKitTheme.standard(Brightness.light),
        [
          {
            'id': 'root',
            'component': 'Text',
            'text': 'Dot',
            'children': ['m'],
          },
          {'id': 'm', 'component': 'Math', 'value': r'\cdot'},
        ],
      );
      final line = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().startsWith('Dot'),
      );
      expect(tester.getSize(find.byType(Math)).height, lessThan(16 * 1.21));
      expect(
        tester.getSize(line).height,
        greaterThanOrEqualTo(16 * 1.21 * 1.2),
      );
    });

    testWidgets('inside a Text it grows with the text scale once', (
      tester,
    ) async {
      // The same formula alone and in a Text, at text scale 2: drawn the
      // same size (both scaled by their line), not twice it (scaled again
      // by the Text) or half (not at all).
      await pumpComponents(tester, textScale: 2, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['t', 'a'],
        },
        {
          'id': 't',
          'component': 'Text',
          'text': 'So',
          'children': ['m'],
        },
        {'id': 'm', 'component': 'Math', 'value': 'x'},
        {'id': 'a', 'component': 'Math', 'value': 'x'},
      ]);
      final glyphs = _glyphs(tester);
      expect(glyphs, hasLength(2));
      final alone = _glyphs(tester, within: find.byType(KitMath)).single;
      final inText = glyphs.firstWhere((g) => g.rect != alone.rect);
      expect(inText.style.fontSize, 16 * 1.21);
      expect(inText.rect.size, alone.rect.size);
      expect(alone.rect.height, greaterThan(16 * 1.21 * 1.5));
    });

    testWidgets("inside a Text, screen readers get the formula's TeX, not "
        'each glyph', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Text',
          'text': 'Speed is',
          'children': ['m'],
        },
        {'id': 'm', 'component': 'Math', 'value': r'v = \frac{d}{t}'},
      ]);
      expect(find.semantics.byLabel(r'v = \frac{d}{t}'), findsOne);
      expect(find.semantics.byLabel('d'), findsNothing);
    });

    testWidgets('inside a Text, invalid TeX is one box of the line: its '
        'source in KaTeX red, its spaces kept at its ends', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Text',
          'text': 'See',
          'children': ['m'],
        },
        {'id': 'm', 'component': 'Math', 'value': r' \frac{a '},
      ]);
      expect(tester.takeException(), isNull);
      final error = find.text(r' \frac{a ');
      expect(error, findsOneWidget);
      expect(
        find.ancestor(
          of: error,
          matching: find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().startsWith('See'),
          ),
        ),
        findsOneWidget,
      );
      final style = DefaultTextStyle.of(
        tester.element(error),
      ).style.merge(tester.widget<Text>(error).style);
      expect(style.color!.toARGB32(), _katexRed);
    });
  });

  group('block', () {
    testWidgets('a display formula centred on its own line, 1em above and '
        'below, in the display style', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'gap': 0,
          'children': ['a', 'm', 'b'],
        },
        {'id': 'a', 'component': 'Text', 'text': 'above'},
        {
          'id': 'm',
          'component': 'Math',
          'value': r'\frac{1}{v} - \frac{1}{u} = \frac{1}{f}',
          'block': true,
        },
        {'id': 'b', 'component': 'Text', 'text': 'below'},
      ]);
      final math = tester.getRect(find.byType(Math));
      expect(math.center.dx, closeTo(180, 1e-6));
      expect(math.top - rectOfText(tester, 'above').bottom, 16);
      expect(rectOfText(tester, 'below').top - math.bottom, 16);
      // \frac in the display style: its numbers at the formula's size,
      // 1.21em (the text style would set them at 0.7 of it).
      final one = _glyphs(tester).firstWhere((g) => g.text == '1');
      expect(one.style.fontSize, 16 * 1.21);
    });

    testWidgets('the margin is of the surrounding size and grows with the '
        'text scale', (tester) async {
      await pumpComponents(tester, textScale: 2, [
        {
          'id': 'root',
          'component': 'Column',
          'gap': 0,
          'children': ['a', 'm'],
        },
        {'id': 'a', 'component': 'Text', 'text': 'above'},
        {'id': 'm', 'component': 'Math', 'value': 'x', 'block': true},
      ]);
      final math = tester.getRect(find.byType(Math));
      expect(math.top - rectOfText(tester, 'above').bottom, 32);
    });

    testWidgets('a formula wider than its line starts at the line start and '
        'scrolls sideways, at 320px and text scale 2', (tester) async {
      await pumpComponents(tester, width: 320, textScale: 2, [
        _root({
          'component': 'Math',
          'value':
              r'\sum_{n=1}^{\infty} \frac{1}{n^2} = '
              r'1 + \frac{1}{4} + \frac{1}{9} + \frac{1}{16} + '
              r'\frac{1}{25} + \cdots = \frac{\pi^2}{6}',
          'block': true,
        }),
      ]);
      expect(tester.takeException(), isNull);
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(KitMath),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      expect(tester.getRect(find.byType(Math)).left, 0);
    });

    testWidgets('an empty display formula is its one margin tall', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'gap': 0,
          'children': ['a', 'm', 'b'],
        },
        {'id': 'a', 'component': 'Text', 'text': 'above'},
        {'id': 'm', 'component': 'Math', 'value': '', 'block': true},
        {'id': 'b', 'component': 'Text', 'text': 'below'},
      ]);
      expect(
        rectOfText(tester, 'below').top - rectOfText(tester, 'above').bottom,
        16,
      );
    });

    testWidgets('inside a Text it takes a line of its own', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Text',
          'text': 'Lens formula',
          'children': ['m'],
        },
        {
          'id': 'm',
          'component': 'Math',
          'value': r'\frac{1}{f} = \frac{1}{v} - \frac{1}{u}',
          'block': true,
        },
      ]);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(Math)).top,
        greaterThan(_runBox(tester, 'Lens formula', 4).bottom),
      );
    });
  });

  group('errors', () {
    for (final block in [false, true]) {
      testWidgets('invalid TeX (block: $block) shows its source in KaTeX red, '
          'in the surrounding type, at the start of its line', (tester) async {
        await pumpComponents(tester, [
          _root({
            'component': 'Math',
            'value': r'\frac{a}  {b',
            'block': block,
          }),
        ]);
        expect(tester.takeException(), isNull);
        final error = find.text(r'\frac{a} {b');
        expect(error, findsOneWidget);
        final style = DefaultTextStyle.of(
          tester.element(error),
        ).style.merge(tester.widget<Text>(error).style);
        expect(style.color!.toARGB32(), _katexRed);
        expect(style.fontSize, 16);
        // No display block round it: no margin, no centring.
        expect(
          tester.getRect(error).topLeft,
          tester.getRect(find.byType(KitMath)).topLeft,
        );
        expect(
          find.semantics.byPredicate(
            (node) => node.tooltip.startsWith(
              "ParseError: KaTeX parse error: Expected '}', got 'EOF'",
            ),
          ),
          findsOne,
        );
      });
    }

    for (final MapEntry(key: name, value: theme) in _looks.entries) {
      testWidgets('in the $name look an unknown command shows its name in '
          'KaTeX red, the rest typeset in the body colour', (tester) async {
        await pumpComponents(
          tester,
          theme: theme,
          brightness: theme.brightness,
          [
            _root({'component': 'Math', 'value': r'\ce{H} + \foo x'}),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(_drawnIn(tester, _katexRed), r'\ce\foo');
        expect(_drawnIn(tester, _ink[name]!), 'H+x');
      });
    }

    testWidgets('an untrusted command shows its name, its arguments gone '
        '(trust: false)', (tester) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Math',
          'value': r'\href{https://ncert.nic.in}{NCERT} + \url{x.y} + 1',
        }),
      ]);
      expect(_drawnIn(tester, _katexRed), r'\href\url');
      final ink = _drawnIn(tester, _ink['playground light']!);
      expect(ink, '++1');
    });

    test('parseKatex stands in only for a command of the source', () {
      const red = Color(_katexRed);
      expect(parseKatex('x^2', errorColor: red).error, isNull);
      expect(parseKatex(r'\frac{a', errorColor: red).tree, isNull);
      expect(parseKatex(r'\foo', errorColor: red).tree, isNotNull);
      // An untrusted command whose argument never closes is left to the
      // parser, which fails on it.
      expect(parseKatex(r'\href{x', errorColor: red).tree, isNull);
      // A control symbol is not stood in for.
      expect(parseKatex(r'\{x\}', errorColor: red).error, isNull);
    });
  });

  group('looks, semantics and fit', () {
    for (final MapEntry(key: name, value: theme) in _looks.entries) {
      testWidgets('in the $name look it draws in the body colour', (
        tester,
      ) async {
        await pumpComponents(
          tester,
          theme: theme,
          brightness: theme.brightness,
          [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['i', 'b'],
            },
            {'id': 'i', 'component': 'Math', 'value': r'K = \frac12 mv^2'},
            {'id': 'b', 'component': 'Math', 'value': 'a^2', 'block': true},
          ],
        );
        for (final glyph in _glyphs(tester)) {
          expect(glyph.style.color!.toARGB32(), _ink[name], reason: glyph.text);
        }
      });
    }

    testWidgets('screen readers get the TeX, not each glyph', (tester) async {
      await pumpComponents(tester, [
        _root({'component': 'Math', 'value': r'\frac{a}{b}'}),
      ]);
      expect(find.semantics.byLabel(r'\frac{a}{b}'), findsOne);
      expect(find.semantics.byLabel('a'), findsNothing);
    });

    for (final look in ['standard', 'playground']) {
      testWidgets('long inline and block formulas fit at 320px and text '
          'scale 2 in the $look look', (tester) async {
        await pumpComponents(
          tester,
          width: 320,
          textScale: 2,
          theme: look == 'standard'
              ? A2uiKitTheme.standard(Brightness.light)
              : A2uiKitTheme.playground(Brightness.light),
          [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['t', 'i', 'b'],
            },
            {
              'id': 't',
              'component': 'Text',
              'text': 'Kinetic energy',
              'children': ['m'],
            },
            {
              'id': 'm',
              'component': 'Math',
              'value': r'K = \frac{1}{2}mv^2 = \frac{p^2}{2m}',
            },
            {
              'id': 'i',
              'component': 'Math',
              'value': 'v^2 = u^2 + 2as + 2a(s_2 - s_1) + 3b + 4c + 5d',
            },
            {
              'id': 'b',
              'component': 'Math',
              'value': r'\int_0^{\infty} e^{-x^2}\,dx = \frac{\sqrt{\pi}}{2}',
              'block': true,
            },
          ],
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets("a formula line is 1.2 of its 1.21em, KaTeX's leading split "
        'evenly above and below', (tester) async {
      // An x (0.43em tall by KaTeX's metrics, no depth) is inside the
      // strut: the `.katex` box is 1.2 of 19.36px, its leading half above
      // and half below the test font's ascent and descent (0.75em and
      // 0.25em), so 16.46px above the baseline and 6.78px below. The line
      // takes the taller of it and the surface's own line on each side
      // (CSS 2.1 section 10.8.1); SkParagraph rounds the line's height to
      // the pixel. Leading split by ascent and descent (Flutter's default)
      // puts the baseline at 17.4px; a 1.5 line height makes the line 29px
      // or more; a strutStyle with the surface's 1.4 makes it 30px.
      await pumpComponents(
        tester,
        theme: A2uiKitTheme.standard(Brightness.light),
        [
          _root({'component': 'Math', 'value': 'x'}),
        ],
      );
      const em = 16 * 1.21;
      const above = (em * 1.2 + em * .75 - em * .25) / 2;
      const below = em * 1.2 - above;
      final paragraph = find
          .descendant(of: find.byType(KitMath), matching: find.byType(RichText))
          .first;
      final line = tester.renderObject<RenderParagraph>(paragraph);
      // The surface's line, as its style gives it: its leading split as its
      // style says.
      final surface = DefaultTextStyle.of(tester.element(paragraph)).style;
      final size = surface.fontSize!;
      final leading = size * (surface.height ?? 1) - size;
      final even = surface.leadingDistribution == TextLeadingDistribution.even;
      final surfaceAbove = size * .75 + (even ? leading / 2 : leading * .75);
      final surfaceBelow = size * .25 + (even ? leading / 2 : leading * .25);
      expect(
        line.size.height,
        (max(above, surfaceAbove) + max(below, surfaceBelow)).roundToDouble(),
      );
      // The piece's own box, the strut round the x: exactly the `.katex`
      // box, its baseline the strut's.
      final piece = line.firstChild!;
      expect(piece.size.height, closeTo(em * 1.2, 1e-6));
      RenderObject.debugCheckingIntrinsics = true;
      try {
        expect(
          piece.getDistanceToBaseline(TextBaseline.alphabetic),
          // The font's metrics come in single precision.
          closeTo(above, 1e-3),
        );
      } finally {
        RenderObject.debugCheckingIntrinsics = false;
      }
    });
  });

  group('where a formula breaks, and its lines', () {
    List<String> pieces(String tex) => [
      for (final piece in katexPieces(
        parseKatex(tex, errorColor: const Color(_katexRed)).tree!,
      ))
        piece.greenRoot.encodeTeX(),
    ];

    test('never after a minus KaTeX makes ordinary: at the start, after a '
        'relation or an opening', () {
      // buildHTML.js:24-28, :106-117: such a minus is an ordinary atom, no
      // break point. A port of flutter_math_fork's texBreak would give
      // three pieces for the first and second, two for the third.
      expect(pieces(r'-1.6\times10^{-19}\,\text{C}'), hasLength(2));
      expect(
        pieces(r'-1.6\times10^{-19}\,\text{C}').first,
        startsWith('{-1.6'),
      );
      expect(pieces(r's = -\tfrac{1}{2}'), hasLength(2));
      expect(pieces('(-x)'), hasLength(1));
      // A minus between two ordinary atoms is a binary operator: a break.
      expect(pieces('a - b'), hasLength(2));
      // A minus before a relation is ordinary too.
      expect(pieces('a - = b'), hasLength(2));
    });

    test('the glue after an operator stays with it; a nobreak in it keeps '
        'the line whole', () {
      // flutter_math_fork's TeX encoder writes no space nodes: count them.
      final first = katexPieces(
        parseKatex(r'a = \, b', errorColor: const Color(_katexRed)).tree!,
      ).first;
      expect(first.greenRoot.children.whereType<SpaceNode>(), hasLength(1));
      expect(pieces(r'a = \nobreak b'), hasLength(1));
      // No break inside a font group: KaTeX builds \mathrm{…} as one atom
      // (font.js); a style switch leaves its atoms on the top level.
      expect(
        pieces(r'\mathrm{N_2 + 3H_2 \rightleftharpoons 2NH_3}'),
        hasLength(1),
      );
      expect(pieces(r'\displaystyle a + b'), hasLength(2));
    });

    testWidgets('a negative value in a narrow column keeps its minus with '
        'its number', (tester) async {
      // 40px at text scale 2 breaks at every break point there is: after
      // the "×" only, never after the leading minus.
      await pumpComponents(tester, width: 40, textScale: 2, [
        _root({'component': 'Math', 'value': r'-1.6\times10^{-19}\,\text{C}'}),
      ]);
      expect(tester.takeException(), isNull);
      final glyphs = _glyphs(tester);
      final minus = glyphs.firstWhere((g) => g.text == '−' || g.text == '-');
      final one = glyphs.firstWhere((g) => g.text == '1');
      expect(one.rect.bottom, closeTo(minus.rect.bottom, 1));
      final ten = glyphs.lastWhere((g) => g.text == '1');
      expect(ten.rect.top, greaterThan(one.rect.bottom));
    });

    testWidgets(r'inline, \\ starts a new line of the formula', (tester) async {
      await pumpComponents(tester, [
        _root({'component': 'Math', 'value': r'F = ma \\ a = \frac{F}{m}'}),
      ]);
      expect(tester.takeException(), isNull);
      expect(_drawnIn(tester, _katexRed), isEmpty);
      final glyphs = _glyphs(tester);
      final f = glyphs.firstWhere((g) => g.text == 'F');
      final a = glyphs.lastWhere((g) => g.text == 'a');
      expect(a.rect.top, greaterThan(f.rect.bottom));
      expect(a.rect.left, 0);
    });

    testWidgets(r'inside a Text, \newline starts a new line of the Text', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Text',
          'text': 'So',
          'children': ['m'],
        },
        {'id': 'm', 'component': 'Math', 'value': r'x = 1 \newline y = 2'},
      ]);
      expect(tester.takeException(), isNull);
      final x = _glyphs(tester).firstWhere((g) => g.text == 'x');
      final y = _glyphs(tester).firstWhere((g) => g.text == 'y');
      expect(y.rect.top, greaterThan(x.rect.bottom));
      expect(y.rect.left, 0);
    });

    testWidgets(r'as a block, \\ makes lines of their own, each centred', (
      tester,
    ) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Math',
          'value': r'x + y = 5 \\ x - y = 1',
          'block': true,
        }),
      ]);
      expect(tester.takeException(), isNull);
      expect(_drawnIn(tester, _katexRed), isEmpty);
      final lines = find.descendant(
        of: find.byType(KitMath),
        matching: find.byType(Math),
      );
      expect(lines, findsNWidgets(2));
      final first = tester.getRect(lines.first);
      final second = tester.getRect(lines.last);
      expect(second.top, greaterThanOrEqualTo(first.bottom));
      expect(first.center.dx, closeTo(180, 1e-6));
      expect(second.center.dx, closeTo(180, 1e-6));
    });
  });

  group("KaTeX's display environments and tags", () {
    testWidgets('align* typesets its rows, aligned at the &', (tester) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Math',
          'block': true,
          'value':
              r'\begin{align*} v &= u + at \\ s &= ut + \tfrac12 at^2 '
              r'\end{align*}',
        }),
      ]);
      expect(tester.takeException(), isNull);
      expect(_drawnIn(tester, _katexRed), isEmpty);
      final glyphs = _glyphs(tester);
      final equals = [
        for (final g in glyphs)
          if (g.text == '=') g.rect,
      ];
      expect(equals, hasLength(2));
      expect(equals.last.top, greaterThan(equals.first.bottom));
      expect(equals.last.left, closeTo(equals.first.left, .01));
      // No equation number.
      expect(glyphs.where((g) => g.text == '('), isEmpty);
    });

    for (final env in ['gather*', 'gathered', 'split', 'equation*']) {
      testWidgets('$env typesets, with no number', (tester) async {
        await pumpComponents(tester, [
          _root({
            'component': 'Math',
            'block': true,
            'value': env == 'equation*'
                ? r'\begin{equation*} a = b \end{equation*}'
                : '\\begin{$env} a = b \\\\ c = d \\end{$env}',
          }),
        ]);
        expect(tester.takeException(), isNull);
        expect(_drawnIn(tester, _katexRed), isEmpty);
        expect(_glyphs(tester).where((g) => g.text == '('), isEmpty);
      });
    }

    testWidgets('an unstarred align numbers its rows at the right edge, on '
        r"each row's baseline; \nonumber and \tag change one", (tester) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Math',
          'block': true,
          'value':
              r'\begin{align} v &= u + at \\ w &= c \nonumber \\ '
              r's &= ut \tag{K} \\ x &= y \end{align}',
        }),
      ]);
      expect(tester.takeException(), isNull);
      expect(_drawnIn(tester, _katexRed), isEmpty);
      final glyphs = _glyphs(tester);
      Rect first(String text) => glyphs.firstWhere((g) => g.text == text).rect;
      // (1) on v's row, none on w's, (K) on s's, (2) on x's: numbers count
      // only the rows that take one.
      expect(first('1').bottom, closeTo(first('v').bottom, 1));
      expect(first('K').bottom, closeTo(first('s').bottom, 1));
      expect(first('2').bottom, closeTo(first('x').bottom, 1));
      // At the right edge of the 360px line.
      final closes = [
        for (final g in glyphs)
          if (g.text == ')') g.rect,
      ];
      expect(closes, hasLength(3));
      expect(closes.map((r) => r.right).reduce(max), closeTo(360, .01));
    });

    testWidgets(r'equation numbers its one line; \tag puts its own', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['e', 't'],
        },
        {
          'id': 'e',
          'component': 'Math',
          'block': true,
          'value': r'\begin{equation} F = ma \end{equation}',
        },
        {
          'id': 't',
          'component': 'Math',
          'block': true,
          'value': r'x^2 \tag{2.1}',
        },
      ]);
      expect(tester.takeException(), isNull);
      expect(_drawnIn(tester, _katexRed), isEmpty);
      // The tag's glyphs (its phantom of the line draws nothing, at 0
      // opacity).
      String tagOf(Finder formula) => [
        for (final element
            in find
                .descendant(of: formula, matching: find.byType(RichText))
                .evaluate())
          if (tester.getRect(find.byWidget(element.widget)).left > 250 &&
              find
                  .ancestor(
                    of: find.byWidget(element.widget),
                    matching: find.byWidgetPredicate(
                      (w) => w is Opacity && w.opacity == 0,
                    ),
                  )
                  .evaluate()
                  .isEmpty)
            (element.widget as RichText).text.toPlainText(),
      ].join();
      final formulas = find.byType(KitMath);
      expect(tagOf(formulas.first), '(1)');
      expect(tagOf(formulas.last), '(2.1)');
      final glyphs = _glyphs(tester, within: formulas.first);
      final one = glyphs.firstWhere((g) => g.text == '1').rect;
      final f = glyphs.firstWhere((g) => g.text == 'F').rect;
      expect(one.bottom, closeTo(f.bottom, 1));
      expect(one.right, lessThanOrEqualTo(360));
    });

    for (final (tex, message) in [
      (
        r'\begin{align*} a &= b \end{align*}',
        '{align*} can be used only in display mode.',
      ),
      (r'x \tag{1}', r'\tag works only in display equations'),
    ]) {
      testWidgets('inline, $tex is the error KaTeX gives', (tester) async {
        await pumpComponents(tester, [
          _root({'component': 'Math', 'value': tex}),
        ]);
        expect(tester.takeException(), isNull);
        expect(
          find.semantics.byPredicate(
            (node) => node.tooltip == 'ParseError: KaTeX parse error: $message',
          ),
          findsOne,
        );
      });
    }

    testWidgets(r'\AA, \degree, \emph and \smash typeset, as KaTeX has them', (
      tester,
    ) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Math',
          'value': r'1\,\AA + 25\degree + \text{\emph{so}} + \smash[b]{y}',
        }),
      ]);
      expect(tester.takeException(), isNull);
      expect(_drawnIn(tester, _katexRed), isEmpty);
      expect(_glyphs(tester).map((g) => g.text).join(), contains('°'));
    });
  });

  group('measured by its container', () {
    const formulas = [
      'F = ma',
      r'\vec{F}',
      r'\sqrt{2gh}',
      r'\left(\frac{a}{b}\right)',
    ];
    final viewings = [(390.0, 1.0), (320.0, 2.0)];

    // Short words: the test font draws every glyph 1em wide, so "Formula"
    // and "Second" at text scale 2 would make the table's min-content width
    // 383px, and a 320px table would scroll sideways (as Chromium's would)
    // with the formula past the window's edge.
    List<Map<String, Object?>> inTable(String tex) => [
      {
        'id': 'root',
        'component': 'Table',
        'columns': ['No.', 'Law'],
        'rows': [
          [
            '2',
            {'componentId': 'm'},
          ],
        ],
        'cellComponents': ['m'],
      },
      {'id': 'm', 'component': 'Math', 'value': tex},
    ];

    List<Map<String, Object?>> inRow(String tex) => [
      {
        'id': 'root',
        'component': 'Row',
        'children': ['l', 'm'],
      },
      {'id': 'l', 'component': 'Text', 'text': 'So'},
      {'id': 'm', 'component': 'Math', 'value': tex},
    ];

    List<Map<String, Object?>> textInRow(String tex) => [
      {
        'id': 'root',
        'component': 'Row',
        'children': ['t'],
      },
      {
        'id': 't',
        'component': 'Text',
        'text': 'So',
        'children': ['m'],
      },
      {'id': 'm', 'component': 'Math', 'value': tex},
    ];

    List<Map<String, Object?>> centred(String tex) => [
      {
        'id': 'root',
        'component': 'Column',
        'align': 'center',
        'children': ['m', 'b'],
      },
      {'id': 'm', 'component': 'Math', 'value': tex},
      {'id': 'b', 'component': 'Math', 'value': tex, 'block': true},
    ];

    for (final (name, payload) in [
      ('a Table cell', inTable),
      ('a Row', inRow),
      ('a Text in a Row', textInRow),
      ('a centred Column', centred),
    ]) {
      for (final tex in formulas) {
        for (final (width, scale) in viewings) {
          testWidgets(
            '$tex in $name at ${width}px, text scale $scale: no throw, one '
            'line, its whole width',
            (tester) async {
              await pumpComponents(
                tester,
                width: width,
                textScale: scale,
                payload(tex),
              );
              expect(tester.takeException(), isNull);
              final glyphs = _glyphs(tester);
              expect(glyphs, isNotEmpty);
              for (final glyph in glyphs) {
                expect(glyph.rect.right, lessThanOrEqualTo(width + 1e-6));
              }
              // On one line: a container that measured the formula short
              // would break it at its "=".
              final fs = [
                for (final g in glyphs)
                  if (g.text == 'F') g.rect,
              ];
              final as = [
                for (final g in glyphs)
                  if (g.text == 'a') g.rect,
              ];
              if (tex == 'F = ma') {
                for (var i = 0; i < fs.length; i++) {
                  expect(as[i].bottom, closeTo(fs[i].bottom, 1));
                }
              }
            },
          );
        }
      }
    }

    testWidgets('a Row sizes a formula to its whole width, the glue round '
        'its relation included', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['r', 'a'],
        },
        {
          'id': 'r',
          'component': 'Row',
          'children': ['m'],
        },
        {'id': 'm', 'component': 'Math', 'value': 'F = ma'},
        {'id': 'a', 'component': 'Math', 'value': 'F = ma'},
      ]);
      final formulas = find.byType(KitMath);
      // The Row's item is as wide as the formula's pieces laid out alone:
      // the intrinsic width flutter_math_fork reports leaves the two thick
      // spaces out, 10.76px short.
      final pieces = find.descendant(
        of: formulas.last,
        matching: find.byType(Math),
      );
      final alone = [
        for (final piece in pieces.evaluate())
          tester.getSize(find.byWidget(piece.widget)).width,
      ].reduce((a, b) => a + b);
      expect(tester.getSize(formulas.first).width, closeTo(alone, .01));
      expect(alone, greaterThan(16 * 1.21 * 4));
    });

    testWidgets('an inline piece wider than its line scrolls sideways, at '
        '320px and text scale 2', (tester) async {
      await pumpComponents(tester, width: 320, textScale: 2, [
        _root({
          'component': 'Math',
          'value': r'd = \sqrt{(x_2-x_1)^2+(y_2-y_1)^2}',
        }),
      ]);
      expect(tester.takeException(), isNull);
      final scrolls = tester.stateList<ScrollableState>(
        find.descendant(
          of: find.byType(KitMath),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        scrolls.where((s) => s.position.maxScrollExtent > 0),
        hasLength(1),
      );
    });
  });

  group('the formulas a tutor writes', () {
    // JEE, NEET and SSC answers' TeX (the running review's probe of 160,
    // tex_coverage_probe_test.dart): each typesets, nothing red, nothing
    // thrown, at 320px and text scale 2.
    const formulas = [
      r'\begin{align*} v^2 &= u^2 + 2as \\ &= 0 + 2(3.53)(5) \end{align*}',
      r'\begin{align} F &= ma \\ a &= \frac{F}{m} \end{align}',
      r'\begin{gather*} x + y = 5 \\ x - y = 1 \end{gather*}',
      r'\begin{equation} E = mc^2 \end{equation}',
      r'\begin{split} a &= b + c \\ &= d \end{split}',
      r'\begin{alignat}{2} a &= b &\quad c &= d \end{alignat}',
      r'x + y = 5 \\ x - y = 1',
      r'PV = nRT \tag{1}',
      r'9.8\,\text{m/s}^2',
      r'g = 9.8\,\mathrm{m\,s^{-2}}',
      r'\vec{F} = m\vec{a}',
      r'\hat{i} + \hat{j} + \hat{k}',
      r'\begin{bmatrix} 1 & 2 \\ 3 & 4 \end{bmatrix}',
      r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}',
      r'\begin{cases} x, & x > 0 \\ -x, & x < 0 \end{cases}',
      r'A \rightarrow B',
      r'\mathrm{N_2 + 3H_2 \rightleftharpoons 2NH_3}',
      r'\mathrm{H_2SO_4}',
      r'A \xrightarrow{\Delta} B',
      r'\Delta_r H^\circ = -890\,\text{kJ mol}^{-1}',
      r'25^\circ\text{C}',
      r'1\,\AA = 10^{-10}\,\text{m}',
      r'-1.6\times10^{-19}\,\text{C}',
      r'd = \sqrt{(x_2-x_1)^2+(y_2-y_1)^2}',
      r'\int_0^\infty e^{-x^2}\,dx = \frac{\sqrt{\pi}}{2}',
      r'\lim_{x \to 0} \frac{\sin x}{x} = 1',
      r'\sum_{i=1}^{n} i = \frac{n(n+1)}{2}',
      r'\sin^2\theta + \cos^2\theta = 1',
      r'\left( \frac{a}{b} \right)^2',
      r'\binom{n}{r} = \frac{n!}{r!(n-r)!}',
      r'\overline{AB} \parallel \overline{CD}',
      r'\therefore x = 2',
      r'\boxed{v = u + at}',
      r'\frac{1}{2}mv^2 + mgh',
      r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}',
      r'\text{Profit} = \text{SP} - \text{CP}',
      r'50\% \text{ of } 240 = 120',
      r'\text{₹}\,500',
      r'\lambda = \frac{h}{mv}',
      r'\mu_k N',
    ];

    for (final block in [false, true]) {
      testWidgets('typeset ${block ? 'as blocks' : 'inline'}, at 320px and '
          'text scale 2: none red, none thrown', (tester) async {
        await pumpComponents(tester, width: 320, textScale: 2, [
          {
            'id': 'root',
            'component': 'Column',
            'children': [for (var i = 0; i < formulas.length; i++) 'm$i'],
          },
          for (final (i, tex) in formulas.indexed)
            {'id': 'm$i', 'component': 'Math', 'value': tex, 'block': block},
        ]);
        expect(tester.takeException(), isNull);
        // Inline, the display environments and \tag are KaTeX's errors
        // too: only those may be red.
        final red = <String>[
          for (final (i, tex) in formulas.indexed)
            if (find
                .descendant(
                  of: find.byType(KitMath).at(i),
                  matching: find.byWidgetPredicate(
                    (w) =>
                        (w is RichText &&
                            w.text.style?.color?.toARGB32() == _katexRed) ||
                        (w is Text && w.style?.color?.toARGB32() == _katexRed),
                  ),
                )
                .evaluate()
                .isNotEmpty)
              tex,
        ];
        expect(red, block ? isEmpty : formulas.sublist(0, 6) + [formulas[7]]);
      });
    }
  });
}
