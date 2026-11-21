// Widget tests of the standard inline text components (Bold, Italic,
// Underline, Strikethrough), after react-core standard/text.tsx:257-298 and
// the user-agent styles of `<strong>`, `<em>`, `<u>` and `<s>` (Chromium
// 159.0.8154.13 html.css:1658-1701).

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

/// Each look and brightness, by name.
final Map<String, A2uiKitTheme> _looks = {
  'standard light': A2uiKitTheme.standard(Brightness.light),
  'standard dark': A2uiKitTheme.standard(Brightness.dark),
  'playground light': A2uiKitTheme.playground(Brightness.light),
  'playground dark': A2uiKitTheme.playground(Brightness.dark),
};

/// The text body colour of each look, as ARGB32 (tokens.dart: CopilotKit's
/// `--a2ui-color-text-default` fallbacks and the playground's).
final Map<String, int> _ink = {
  'standard light': 0xff0d0d0d,
  'standard dark': 0xffececec,
  'playground light': oklch(.2, .008, 285).toARGB32(),
  'playground dark': oklch(.97, .003, 285).toARGB32(),
};

/// The style [text] is drawn in: the style of the RichText showing it, with
/// what it inherits and every ancestor span's style merged in.
TextStyle _style(WidgetTester tester, String text) {
  final finder = find.byWidgetPredicate(
    (w) =>
        w is RichText &&
        w.text.toPlainText(includePlaceholders: false).contains(text),
  );
  final rich = tester.widget<RichText>(finder.last);
  var found = DefaultTextStyle.of(tester.element(finder.last)).style;
  var matched = false;
  void visit(InlineSpan span, TextStyle style) {
    final merged = style.merge(span.style);
    if (span is! TextSpan) return;
    if (!matched && (span.text?.contains(text) ?? false)) {
      found = merged;
      matched = true;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      visit(child, merged);
    }
  }

  visit(rich.text, found);
  return found;
}

/// The exact text the RichText holding [part] draws.
String _shown(WidgetTester tester, String part) => tester
    .widget<RichText>(
      find
          .byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText(includePlaceholders: false).contains(part),
          )
          .last,
    )
    .text
    .toPlainText(includePlaceholders: false);

/// A no-break space (U+00A0), which CSS does not collapse.
final String _nbsp = String.fromCharCode(0xa0);

Map<String, Object?> _root(Map<String, Object?> props) => {
  'id': 'root',
  ...props,
};

/// A Text "Note" with the component [child] (id "c") inline after it, with
/// [text]'s own props.
List<Map<String, Object?>> _inText(
  Map<String, Object?> child, {
  Map<String, Object?> text = const {},
}) => [
  {
    'id': 'root',
    'component': 'Text',
    'text': 'Note',
    ...text,
    'children': ['c'],
  },
  {'id': 'c', ...child},
];

void main() {
  group('Bold', () {
    testWidgets('is font-weight: bolder over what it inherits', (tester) async {
      await pumpComponents(tester, [
        _root({'component': 'Bold', 'text': 'loud'}),
      ]);
      // 700 over the surface's 400.
      expect(_style(tester, 'loud').fontWeight, FontWeight.w700);
    });

    testWidgets('inside a strong Text is bolder than its 600: 900', (
      tester,
    ) async {
      await pumpComponents(
        tester,
        _inText({'component': 'Bold', 'text': 'loud'}, text: {'strong': true}),
      );
      expect(_style(tester, 'Note').fontWeight, FontWeight.w600);
      expect(_style(tester, 'loud').fontWeight, FontWeight.w900);
    });

    for (final (weight, expected) in [
      ('normal', FontWeight.w400),
      ('medium', FontWeight.w500),
      ('semibold', FontWeight.w600),
      ('bold', FontWeight.w700),
    ]) {
      testWidgets('fontWeight $weight sets the weight', (tester) async {
        await pumpComponents(
          tester,
          _inText(
            {'component': 'Bold', 'text': 'loud', 'fontWeight': weight},
            text: {'strong': true},
          ),
        );
        expect(_style(tester, 'loud').fontWeight, expected);
      });
    }

    testWidgets('takes no markdown', (tester) async {
      await pumpComponents(tester, [
        _root({'component': 'Bold', 'text': '**x** and `y`'}),
      ]);
      expect(find.text('**x** and `y`'), findsOneWidget);
    });
  });

  group('Italic, Underline, Strikethrough', () {
    testWidgets('Italic is italic, nothing else', (tester) async {
      await pumpComponents(tester, [
        _root({'component': 'Italic', 'text': 'it'}),
      ]);
      final style = _style(tester, 'it');
      expect(style.fontStyle, FontStyle.italic);
      expect(style.fontWeight, isNot(FontWeight.w700));
      expect(style.decoration ?? TextDecoration.none, TextDecoration.none);
    });

    testWidgets('Underline is underlined, Strikethrough struck through', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['u', 's'],
        },
        {'id': 'u', 'component': 'Underline', 'text': 'un'},
        {'id': 's', 'component': 'Strikethrough', 'text': 'st'},
      ]);
      expect(_style(tester, 'un').decoration, TextDecoration.underline);
      expect(_style(tester, 'st').decoration, TextDecoration.lineThrough);
      expect(_style(tester, 'un').fontStyle, isNot(FontStyle.italic));
    });

    testWidgets('an Underline in a struck-through Text draws both lines: a '
        'decoration propagates to the boxes inside', (tester) async {
      await pumpComponents(
        tester,
        _inText(
          {'component': 'Underline', 'text': 'un'},
          text: {'lineThrough': true},
        ),
      );
      final decoration = _style(tester, 'un').decoration!;
      expect(decoration.contains(TextDecoration.underline), isTrue);
      expect(decoration.contains(TextDecoration.lineThrough), isTrue);
    });

    testWidgets('a Strikethrough in an underlined Text draws both lines', (
      tester,
    ) async {
      await pumpComponents(
        tester,
        _inText(
          {'component': 'Strikethrough', 'text': 'st'},
          text: {'underline': true},
        ),
      );
      final decoration = _style(tester, 'st').decoration!;
      expect(decoration.contains(TextDecoration.underline), isTrue);
      expect(decoration.contains(TextDecoration.lineThrough), isTrue);
    });

    testWidgets('inside a Text they take its size and colour', (tester) async {
      await pumpComponents(
        tester,
        theme: A2uiKitTheme.standard(Brightness.light),
        _inText(
          {'component': 'Italic', 'text': 'it'},
          text: {'size': 'sm', 'color': 'secondary'},
        ),
      );
      final note = _style(tester, 'Note');
      final it = _style(tester, 'it');
      expect(note.fontSize, 14);
      expect(it.fontSize, note.fontSize);
      expect(it.color!.toARGB32(), 0xff5d5d5d);
      expect(it.color, note.color);
    });
  });

  group('white space and missing text', () {
    for (final component in ['Bold', 'Italic', 'Underline', 'Strikethrough']) {
      testWidgets('$component on its own collapses and trims its spaces', (
        tester,
      ) async {
        await pumpComponents(tester, [
          _root({'component': component, 'text': '  two\n\t words  '}),
        ]);
        expect(_shown(tester, 'two'), 'two words');
      });

      testWidgets('$component inside a Text: its spaces collapse with the '
          "line's, one space at each end holding it apart from the words "
          'around it', (tester) async {
        // CSS Text 3 section 4.1.1: a space right after another goes, even
        // across an inline's edge. Kept whole, the line would read
        // "Note   two words  end"; trimmed as a block's, "Note twowords".
        await pumpComponents(tester, [
          {
            'id': 'root',
            'component': 'Text',
            'text': 'Note',
            'children': ['c', 'e'],
          },
          {'id': 'c', 'component': component, 'text': '  two\n words  '},
          // A space at the line's end goes too.
          {'id': 'e', 'component': 'Italic', 'text': 'end '},
        ]);
        expect(_shown(tester, 'two'), 'Note two words end');
      });

      testWidgets('$component inside a preserveWhitespace Text keeps its '
          'spaces: white-space is inherited', (tester) async {
        await pumpComponents(
          tester,
          _inText(
            {'component': component, 'text': '  two\n words '},
            text: {'preserveWhitespace': true},
          ),
        );
        expect(_shown(tester, 'two'), 'Note   two\n words ');
      });

      testWidgets('$component in a Column inside a Text is a block again: '
          'trimmed', (tester) async {
        await pumpComponents(tester, [
          {
            'id': 'root',
            'component': 'Text',
            'text': 'Note',
            'children': ['col'],
          },
          {
            'id': 'col',
            'component': 'Column',
            'children': ['c'],
          },
          {'id': 'c', 'component': component, 'text': ' two words '},
        ]);
        expect(_shown(tester, 'two'), 'two words');
      });

      testWidgets('$component keeps a no-break space at its ends', (
        tester,
      ) async {
        // The text is a no-break space, "x", a no-break space.
        await pumpComponents(tester, [
          _root({'component': component, 'text': ' x '}),
        ]);
        expect(_shown(tester, 'x'), ' x ');
        expect(_shown(tester, 'x'), '${_nbsp}x$_nbsp');
      });

      for (final (name, Object text) in [('""', ''), ('"   "', '   ')]) {
        testWidgets('$component with text $name draws nothing, no line tall', (
          tester,
        ) async {
          await pumpComponents(tester, [
            {
              'id': 'root',
              'component': 'Column',
              'gap': 0,
              'children': ['a', 'c', 'b'],
            },
            {'id': 'a', 'component': 'Text', 'text': 'above'},
            {'id': 'c', 'component': component, 'text': text},
            {'id': 'b', 'component': 'Text', 'text': 'below'},
          ]);
          expect(tester.takeException(), isNull);
          expect(
            rectOfText(tester, 'below').top,
            rectOfText(tester, 'above').bottom,
          );
        });
      }

      // Its required `text` (`z.string()`, shared standard/text.ts:80-81)
      // bound to a missing value is unset, so the render check fails and
      // the invalid-props fallback takes its place (SurfaceView.tsx:686-753;
      // upstream's surface-view.test.tsx:565-573 binds a required prop to
      // "/missing" and expects the alert).
      testWidgets('$component with text bound to a missing value shows the '
          'invalid-props fallback', (tester) async {
        await pumpComponents(tester, [
          _root({
            'component': component,
            'text': {'@path': '/missing'},
          }),
        ]);
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining(
            'Couldn’t display this part: invalid props '
            '(text:',
          ),
          findsOne,
        );
      });
    }
  });

  group('in a line of text', () {
    testWidgets(
      "inside a Text, an inline element's words continue the Text's line",
      (tester) async {
        // The test font draws every letter 1em (16px) wide: "Speed is " fills
        // 144 of the 240px, "at a" fits after it, " constant rate" does
        // not. CSS puts "at a" on the first line and wraps the rest; the
        // wrong layout this rules out moves the whole italic text below.
        await pumpComponents(tester, width: 240, [
          {
            'id': 'root',
            'component': 'Text',
            'text': 'Speed is',
            'children': ['i'],
          },
          {'id': 'i', 'component': 'Italic', 'text': ' at a constant rate'},
        ]);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().startsWith('Speed'),
          ),
        );
        // The space before "at" collapses into the one after "Speed is".
        expect(paragraph.text.toPlainText(), 'Speed is at a constant rate');
        Rect box(String word) {
          final start = paragraph.text.toPlainText().indexOf(word);
          return paragraph
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: start,
                  extentOffset: start + word.length,
                ),
              )
              .first
              .toRect();
        }

        expect(box('at').top, box('Speed').top);
        expect(box('at').left, greaterThan(box('is').right));
        expect(box('constant').top, greaterThanOrEqualTo(box('Speed').bottom));
        // At the line's start (an italic box sits a fraction of a pixel
        // over, by the slant the engine gives it).
        expect(box('constant').left, closeTo(0, 1));
      },
    );

    for (final component in ['Bold', 'Underline', 'Strikethrough']) {
      testWidgets("inside a Text, a $component's words are the Text's own "
          "line's, in the $component's style", (tester) async {
        await pumpComponents(
          tester,
          _inText({'component': component, 'text': 'two words'}),
        );
        // One paragraph, no box (a box would read U+FFFC here).
        expect(_shown(tester, 'Note'), 'Note two words');
        final style = _style(tester, 'two words');
        expect(style.fontWeight, switch (component) {
          'Bold' => FontWeight.w700,
          _ => FontWeight.w400,
        });
        expect(style.decoration ?? TextDecoration.none, switch (component) {
          'Underline' => TextDecoration.underline,
          'Strikethrough' => TextDecoration.lineThrough,
          _ => TextDecoration.none,
        });
        expect(_style(tester, 'Note').fontWeight, FontWeight.w400);
      });
    }

    testWidgets('inside a Text, a Bold bound to data follows the data', (
      tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        data: {'name': 'Ada'},
        _inText({
          'component': 'Bold',
          'text': {'@path': '/name'},
        }),
      );
      expect(_shown(tester, 'Note'), 'Note Ada');
      surfaces.setData('/name', 'Grace');
      await tester.pump();
      expect(_shown(tester, 'Note'), 'Note Grace');
      expect(_style(tester, 'Grace').fontWeight, FontWeight.w700);
    });

    testWidgets('inside a Text, an Italic whose text is bound to a missing '
        'value shows the invalid-props fallback, reported once', (
      tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        _inText({
          'component': 'Italic',
          'text': {'@path': '/missing'},
        }),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Couldn’t display this part: invalid props (text:'),
        findsOne,
      );
      // One report: the harness hears each error twice, from the surface
      // and from its group, as one object.
      expect(
        surfaces.errors.where((e) => e.code == 'INVALID_PROPS').toSet(),
        hasLength(1),
      );
    });

    testWidgets("an app's own Bold inside a Text is its builder's, one box of "
        'the line', (tester) async {
      await pumpComponents(
        tester,
        catalog: a2uiKitCatalog(
          options: A2uiKitOptions(
            overrides: {
              'Bold': (context, node, props, buildChild) =>
                  Text('mine ${props.string('text')}'),
            },
          ),
        ),
        _inText({'component': 'Bold', 'text': 'loud'}),
      );
      expect(find.text('mine loud'), findsOneWidget);
      expect(_shown(tester, 'Note'), 'Note ');
    });
  });

  group('looks', () {
    for (final MapEntry(key: name, value: theme) in _looks.entries) {
      testWidgets('in the $name look they draw in the body colour', (
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
              'children': ['b', 'i', 'u', 's'],
            },
            {'id': 'b', 'component': 'Bold', 'text': 'bold'},
            {'id': 'i', 'component': 'Italic', 'text': 'italic'},
            {'id': 'u', 'component': 'Underline', 'text': 'under'},
            {'id': 's', 'component': 'Strikethrough', 'text': 'struck'},
          ],
        );
        for (final text in ['bold', 'italic', 'under', 'struck']) {
          expect(
            _style(tester, text).color!.toARGB32(),
            _ink[name],
            reason: text,
          );
        }
        expect(_style(tester, 'bold').fontWeight, FontWeight.w700);
        expect(_style(tester, 'italic').fontStyle, FontStyle.italic);
      });
    }
  });

  group('fit and semantics', () {
    const long =
        'Supercalifragilistic words of a very long sentence about the '
        'conservation of mechanical energy in a frictionless system';
    for (final component in ['Bold', 'Italic', 'Underline', 'Strikethrough']) {
      for (final look in ['standard', 'playground']) {
        testWidgets('a long $component wraps at 320px and text scale 2 in '
            'the $look look', (tester) async {
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
                'children': ['c', 't'],
              },
              {'id': 'c', 'component': component, 'text': long},
              {
                'id': 't',
                'component': 'Text',
                'text': 'Also',
                'children': ['d'],
              },
              {'id': 'd', 'component': component, 'text': long},
            ],
          );
          expect(tester.takeException(), isNull);
          final box = tester.getRect(
            find.text(long.replaceAll('  ', ' ')).first,
          );
          expect(box.width, lessThanOrEqualTo(320));
          expect(box.height, greaterThan(32 * 2));
        });
      }

      testWidgets('$component is read as its text', (tester) async {
        await pumpComponents(tester, [
          _root({'component': component, 'text': 'read me'}),
        ]);
        expect(find.semantics.byLabel('read me'), findsOne);
      });
    }
  });
}
