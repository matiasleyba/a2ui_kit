// Parity tests of CopilotKit's standard text components, ported from
// packages/react-core/src/v2/generative-ui/standard/__tests__/text.test.tsx
// (MIT, (c) Atai Barkai). Each test names its upstream line.
//
// ignore: lines_longer_than_80_chars (port_status.dart reads this line whole)
// Parity for: Title, Text, Caption, Label, Badge, Markdown, Link, Column, Bold, Code, Math
//
// The surfaces are the standard catalog in the standard look
// (renderStandard). Label is the standard Label itself: text.test.tsx
// renders textComponents, with no test-only leaf. The renderInlineMarkdown
// tests read the segments of parseInlineMarkdown, its port, and what a
// standard Text draws from them: each element upstream's HTML holds is a
// run of the Text's RichText in that element's style. A link opens
// through url_launcher, which `fakeUrlLauncher` records as upstream's
// `window.open` spy does.
//
// Translated (upstream reads tag names and inline style strings; the tests
// read what is drawn or what a screen reader gets, so they count as
// ported):
// - :89, the tag names H4, H3, H3 and H2: semantics headers of those
//   levels.
// - :103 and :125, inline style strings (`fontSize: ""`, "0.875em", a
//   `color` naming --a2ui-color-text-secondary, `fontWeight: "500"`): the
//   TextStyle drawn, against the inherited style and the theme's colours.
// - :157, Bold's tag name STRONG: the text drawn `font-weight: bolder`
//   (700 over the surface's 400); Code's `pre` with `tabIndex` 0: the first
//   Tab puts the keyboard focus on the box holding the code, a focusable
//   node for screen readers.
// - :219, KaTeX's markup: its text drawn ("x"); `data-math="inline"` on a
//   SPAN with no `.katex-display`: an inline formula in the text style at
//   the start of its line, with no display margin; its `.katex math` (the
//   MathML screen readers read): a semantics node labelled with the TeX
//   source (README, "Differences": Flutter's semantics has no MathML);
//   `data-math="block"` on a DIV with a `.katex-display` holding an
//   `mfrac`: a display formula centred on its own line, a margin of the
//   surrounding size above it, its fraction's numerator above its
//   denominator at the formula's full size (the display style's).
// - :235, the `katex-error` class: KaTeX's error span, the source drawn in
//   KaTeX's error colour (#cc0000) with KaTeX's message as its tooltip
//   (the span's `title`).
//
// Not ported (bound to internals):
// - text.test.tsx:23, `Text.props` without `children`: createGenerativeUI's
//   manifest keeps a slot out of a component's props. A2UI's catalog
//   document writes a slot as a ChildList property, which the slot check
//   reads.
// - :125's `tagName == "LABEL"`: no counterpart (an HTML label element;
//   `htmlFor` is ignored, as in React).
// - :147, `closest("span[data-a2ui-text]")`: tested as the Text's RichText
//   holding the Badge.
// - :157 and :324, `rel="noopener noreferrer"`: url_launcher_web opens its
//   new tab without an opener; no platform interface carries it. `href`
//   and `target="_blank"` are tested by activating the link: a fake
//   url_launcher platform gets the URL with `webOnlyWindowName: '_blank'`.
// - :182, `tagName == "SPAN"`: tested as no link semantics and nothing
//   opened on a tap.
// - :195, `data-streamdown="strong"`, the wrapper's `style` attribute and
//   the `a2ui-std-list` class: tested as the strong style of the Markdown
//   sheet, the paragraph's type equal to the type it inherits (at the
//   surface's root and inside a Text of another colour and size), and the
//   list's own spacing kept (the class's one rule is `margin: 0`,
//   styles.ts:70): the block gap before the list and its indent, not 0.
//   Streamdown 1.6.11 (the version pnpm-lock.yaml pins, sha512 checked,
//   in $A2UI_THIRDPARTY_SRC/streamdown@1.6.11/) gives its
//   `p` only the class it is passed and its `ul` `list-inside list-disc
//   whitespace-normal` (dist/chunk-JAPRZBRM.js): no colour, size or margin
//   of their own, as these expectations (the queued one inside a Text
//   included) take it. The list's gap and indent have no literal value in
//   the sources (the test's comment says why), so they are checked as not
//   removed.
// - :292, the HTML escaping (`&lt;`, `&amp;`): tested as the text kept as
//   it is.
// - :343's `data-language="js"` on the code block: flutter_markdown keeps
//   no info string on it, and nothing a student gets reads it.
// - :157's `code.dataset.language` ("js" on the Code's `<code>`): a data
//   attribute, which nothing a student gets reads (the Code reads
//   `language` and shows it nowhere, as React does).
//
// Not ours:
// - :334 and :343 test parseBlockMarkdown and renderBlockMarkdown
//   (markdown.tsx:195 and :284), a dependency-free renderer of
//   CopilotKit's that no catalog component calls (Markdown renders with
//   Streamdown) and that this package does not have. Their behaviours are
//   tested through the standard Markdown all the same (`(behaviour)`
//   below).
//
// Later phase (no Dart yet):
// - :243 ShimmerText and reduced motion; :254 Tooltip on focus, hover and
//   Escape.

import 'dart:ui' show Tristate;

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/text/markdown.dart';
import 'package:a2ui_kit/src/components/standard/text/math.dart';
import 'package:a2ui_kit/src/foundation/text/inline_markdown.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// One run of text and the style it is drawn in.
typedef _Run = ({String text, TextStyle style});

/// The Markdown of text.test.tsx:195.
const String _streamdownSample =
    '# Title\n\nSome **bold** text.\n\n- one\n- two\n\n> quoted';

/// The Markdown of text.test.tsx:343.
const String _blockSample =
    '# Title\n\nSome **bold** text.\n\n- one\n- two\n\n1. first\n2. second'
    '\n\n> quoted\n\n```js\nx = 1\n```\n\n---';

/// The RichText showing exactly [text].
RichText _rich(WidgetTester tester, String text) =>
    tester.widget<RichText>(find.text(text, findRichText: true));

/// The RichText whose text, without semantics labels, contains [part].
RichText _richWith(WidgetTester tester, String part) => tester.widget<RichText>(
  find.byWidgetPredicate(
    (widget) =>
        widget is RichText &&
        widget.text.toPlainText(includeSemanticsLabels: false).contains(part),
  ),
);

/// The style the RichText showing exactly [text] draws in: its root style,
/// which `Text` merges over the inherited one.
TextStyle _drawn(WidgetTester tester, String text) =>
    _rich(tester, text).text.style!;

/// The style the RichText showing exactly [text] inherits.
TextStyle _inherited(WidgetTester tester, String text) => DefaultTextStyle.of(
  tester.element(find.text(text, findRichText: true)),
).style;

/// Each run of [rich] with its style, every ancestor span's style merged
/// in.
List<_Run> _runs(RichText rich) {
  final runs = <_Run>[];
  void visit(InlineSpan span, TextStyle inherited) {
    final style = inherited.merge(span.style);
    if (span is! TextSpan) return;
    final text = span.text;
    if (text != null && text.isNotEmpty) {
      runs.add((text: text, style: style));
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      visit(child, style);
    }
  }

  visit(rich.text, const TextStyle());
  return runs;
}

/// The span of [rich] whose text is [text].
TextSpan _span(RichText rich, String text) {
  TextSpan? found;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text == text) found = span;
    return found == null;
  });
  return found!;
}

/// The text of [rich] as the DOM's `textContent` reads it: its runs, with
/// the text of each inline child in its place.
String _textContent(WidgetTester tester, RichText rich) {
  final content = StringBuffer();
  rich.text.visitChildren((span) {
    if (span is TextSpan) {
      content.write(span.text ?? '');
    } else if (span is WidgetSpan) {
      final inner = tester.widgetList<RichText>(
        find.descendant(
          of: find.byWidget(span.child),
          matching: find.byType(RichText),
        ),
      );
      for (final text in inner) {
        content.write(text.text.toPlainText());
      }
    }
    return true;
  });
  return content.toString();
}

/// The texts that follow each bullet [isBullet] accepts, in tree order:
/// the items of a Markdown list, since flutter_markdown sets a bullet
/// before each.
List<String> _itemsAfter(
  WidgetTester tester,
  bool Function(String text) isBullet,
) {
  final texts = richTexts(tester);
  return [
    for (var i = 0; i + 1 < texts.length; i++)
      if (isBullet(texts[i])) texts[i + 1],
  ];
}

/// Whether [text] is the bullet of an unordered list item.
bool _isDisc(String text) => text == '•';

/// Whether [text] is the number of an ordered list item (`1.`).
bool _isNumber(String text) => RegExp(r'^\d+\.$').hasMatch(text);

/// The semantics nodes of a heading of [level].
SemanticsFinder _heading(int level) => find.semantics.byPredicate(
  (node) =>
      node.getSemanticsData().flagsCollection.isHeader &&
      node.headingLevel == level,
);

/// Finds the quote box around [text]: the DecoratedBox flutter_markdown
/// draws with the sheet's [decoration].
Finder _quoteAround(String text, Decoration? decoration) => find.ancestor(
  of: find.text(text, findRichText: true),
  matching: find.byWidgetPredicate(
    (widget) => widget is DecoratedBox && widget.decoration == decoration,
  ),
);

/// Finds the Containers flutter_markdown draws with the sheet's
/// [decoration]: a code block or a rule.
Finder _boxOf(Decoration? decoration) => find.byWidgetPredicate(
  (widget) => widget is Container && widget.decoration == decoration,
);

/// What a standard Text draws for some inline markdown: upstream's
/// `inlineHtml(source)`, the elements renderInlineMarkdown makes.
class _Drawn {
  _Drawn(this.rich, this.base);

  /// The Text's RichText.
  final RichText rich;

  /// The style the Text's runs start from: its inherited style with its
  /// own merged in.
  final TextStyle base;

  /// Each run of the text with the style it is drawn in.
  List<_Run> get runs => _runs(rich);

  /// The style of the one run whose text is [text], over [base].
  TextStyle style(String text) =>
      base.merge(runs.singleWhere((run) => run.text == text).style);

  /// Upstream's `<span>text</span>`: one run, [text] as written, in the
  /// Text's own style, and no link anywhere.
  void expectPlain(String text) {
    expect([for (final run in runs) run.text], [text]);
    expect(base.merge(runs.single.style), base.merge(rich.text.style));
    var links = 0;
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.recognizer != null) links++;
      return true;
    });
    expect(links, 0);
  }
}

/// Renders [source] in a standard Text and returns what it draws.
Future<_Drawn> _drawInline(WidgetTester tester, String source) async {
  await renderStandard(tester, [
    {'id': 'root', 'component': 'Text', 'text': source},
  ]);
  final rich = find.byType(RichText);
  return _Drawn(
    tester.widget<RichText>(rich),
    DefaultTextStyle.of(tester.element(rich)).style,
  );
}

/// Upstream's `<code>text</code>`: [text] in the theme's mono face at its
/// inline code size (`inlineCodeScale` of the Text's).
void _expectCode(_Drawn drawn, String text) {
  final type = standardLight.typography;
  final code = drawn.style(text);
  expect(code.fontFamily, type.monoFontFamily);
  expect(
    code.fontSize,
    drawn.base.merge(drawn.rich.text.style).fontSize! * type.inlineCodeScale,
  );
}

/// The link nodes of the semantics tree labelled exactly [label].
SemanticsFinder _linkNodes(String label) => find.semantics.byPredicate(
  (node) => node.flagsCollection.isLink && node.label == label,
);

/// The hrefs of the links among [segments].
List<String> _hrefs(List<InlineSegment> segments) => [
  for (final segment in segments)
    if (segment is InlineLink) segment.href,
];

/// The slots of a component's schema, as CopilotKit's manifest names them:
/// a child list is a "multiple" slot, a child id a "single" one.
Map<String, String> _slots(Map<String, Object?> schema) {
  final properties = schema['properties']! as Map<String, Object?>;
  return {
    for (final MapEntry(:key, :value) in properties.entries)
      if (value case {r'$ref': final String ref})
        if (ref.endsWith('/ChildList'))
          key: 'multiple'
        else if (ref.endsWith('/ComponentId'))
          key: 'single',
  };
}

void main() {
  group('textComponents', () {
    // text.test.tsx:23
    test('are in the standard catalog, each with a description; Text has a '
        'multiple children slot', () {
      final components =
          a2uiKitStandardCatalog().toJson()['components']!
              as Map<String, Object?>;
      // Object.keys(textComponents), in its order: the catalog document
      // holds every one, built or not.
      const names = [
        'Title',
        'Text',
        'Caption',
        'Label',
        'Bold',
        'Italic',
        'Underline',
        'Strikethrough',
        'Badge',
        'Blockquote',
        'Code',
        'Markdown',
        'Math',
        'ShimmerText',
        'Link',
        'Tooltip',
      ];
      final keys = components.keys.toList();
      final start = keys.indexOf(names.first);
      expect(keys.sublist(start, start + names.length), names);
      // `toEqual` on the group's keys fails on an extra member too: the
      // group runs from after the layout group's Tabs to before the inputs
      // group's Button.
      expect(keys[start - 1], 'Tabs');
      expect(keys[start + names.length], 'Button');
      for (final name in names) {
        final schema = components[name]! as Map<String, Object?>;
        expect(schema['description'], matches(RegExp(r'\S')), reason: name);
      }
      expect(_slots(components['Text']! as Map<String, Object?>), {
        'children': 'multiple',
      });
      expect(_slots(components['Tooltip']! as Map<String, Object?>), {
        'trigger': 'single',
        'content': 'single',
      });
    });
  });

  group('standard text', () {
    // text.test.tsx:58
    testWidgets('renders a Title and a Text with inline markdown', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['t', 'x'],
        },
        {'id': 't', 'component': 'Title', 'text': 'Team plan', 'size': 'xl'},
        {
          'id': 'x',
          'component': 'Text',
          'text': r'Was ~~$39~~ now **$29**',
          'color': 'secondary',
        },
      ]);
      expect(find.text('Team plan', findRichText: true), findsOneWidget);
      final runs = _runs(_richWith(tester, 'Was'));
      // `<s>` draws a line through; `<strong>` is `font-weight: bolder`,
      // 700 over the Text's 400.
      expect(
        runs
            .firstWhere(
              (run) =>
                  run.style.decoration?.contains(TextDecoration.lineThrough) ??
                  false,
            )
            .text,
        r'$39',
      );
      expect(
        runs.firstWhere((run) => run.style.fontWeight == FontWeight.w700).text,
        r'$29',
      );
    });

    // text.test.tsx:74
    testWidgets('updates a Text bound to { "@path" } when the data model '
        'changes', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Text',
            'text': {'@path': '/price'},
          },
        ],
        data: {'price': r'$290'},
      );
      expect(find.text(r'$290', findRichText: true), findsOneWidget);
      await view.update([agentWrite('/price', r'$310')]);
      expect(find.text(r'$310', findRichText: true), findsOneWidget);
      expect(find.text(r'$290', findRichText: true), findsNothing);
    });

    // text.test.tsx:89
    testWidgets('maps Title sizes to heading levels', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b', 'c', 'd'],
        },
        {'id': 'a', 'component': 'Title', 'text': 'small', 'size': 'sm'},
        {'id': 'b', 'component': 'Title', 'text': 'default'},
        {'id': 'c', 'component': 'Title', 'text': 'large', 'size': 'lg'},
        {'id': 'd', 'component': 'Title', 'text': 'huge', 'size': '5xl'},
      ]);
      // H4, H3, H3 and H2.
      for (final (text, level) in [
        ('small', 4),
        ('default', 3),
        ('large', 3),
        ('huge', 2),
      ]) {
        final node = semanticsOfText(tester, text);
        expect(node, isSemantics(isHeader: true), reason: text);
        expect(node.headingLevel, level, reason: text);
      }
    });

    // text.test.tsx:103
    testWidgets('takes the Title size, line height and weight from the host '
        'heading styles', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b'],
        },
        {'id': 'a', 'component': 'Title', 'text': 'Breakdown', 'size': '2xl'},
        {
          'id': 'b',
          'component': 'Title',
          'text': 'Muted',
          'color': 'secondary',
          'textAlign': 'center',
        },
      ]);
      // No type of its own: a 2xl Title is an h2 in the host's h2 style
      // (the standard look's fallback, tokens.test.ts:117).
      final heading = _drawn(tester, 'Breakdown');
      final h2 = standardLight.typography.heading(A2uiHeadingLevel.h2);
      expect(
        heading.fontSize,
        _inherited(tester, 'Breakdown').fontSize! * h2.fontSizeEm!,
      );
      expect(heading.height, h2.lineHeight);
      expect(heading.fontWeight, h2.fontWeight);
      // No margin of its own: the host's heading margin,
      // `var(--a2ui-heading-margin, 0)`.
      final column = flexContainerOf(tester, 'Breakdown');
      final breakdown = tester.getRect(
        find.text('Breakdown', findRichText: true),
      );
      expect(breakdown.topLeft, tester.getRect(find.byWidget(column)).topLeft);
      // ... and none below it: the next Title follows after the Column's
      // row gap alone.
      expect(
        tester.getRect(find.text('Muted', findRichText: true)).top -
            breakdown.bottom,
        column.flex.rowGap,
      );
      expect(
        _drawn(tester, 'Muted').color,
        standardLight.color(A2uiColorToken.textSecondary),
      );
      expect(_rich(tester, 'Muted').textAlign, TextAlign.center);
    });

    // text.test.tsx:125
    testWidgets('lets Text inherit its size unless a size is given, and '
        'sizes Caption and Label in em', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b', 'c', 'd'],
        },
        {'id': 'a', 'component': 'Text', 'text': 'plain'},
        {'id': 'b', 'component': 'Text', 'text': 'small', 'size': 'sm'},
        {'id': 'c', 'component': 'Caption', 'text': 'caption'},
        {'id': 'd', 'component': 'Label', 'text': 'label'},
      ]);
      final plain = _drawn(tester, 'plain');
      final inherited = _inherited(tester, 'plain');
      expect(plain.fontSize, inherited.fontSize);
      expect(plain.height, inherited.height);
      expect(plain.color, inherited.color);
      expect(
        _drawn(tester, 'small').fontSize,
        .875 * _inherited(tester, 'small').fontSize!,
      );
      final caption = _drawn(tester, 'caption');
      expect(caption.fontSize, .875 * _inherited(tester, 'caption').fontSize!);
      expect(caption.color, standardLight.color(A2uiColorToken.textSecondary));
      final label = _drawn(tester, 'label');
      expect(label.fontSize, .875 * _inherited(tester, 'label').fontSize!);
      expect(label.fontWeight, FontWeight.w500);
    });

    // text.test.tsx:147
    testWidgets('renders the children of a Text inline after its text', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Text',
          'text': 'Plan',
          'children': ['b'],
        },
        {'id': 'b', 'component': 'Badge', 'label': 'Pro'},
      ]);
      final text = _richWith(tester, 'Plan');
      expect(
        find.ancestor(of: find.text('Pro'), matching: find.byWidget(text)),
        findsOneWidget,
      );
      expect(_textContent(tester, text), 'Plan Pro');
    });

    // text.test.tsx:157
    testWidgets('renders Badge, Bold, Code and a safe Link', (tester) async {
      final launcher = fakeUrlLauncher();
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['b', 'o', 'k', 'a'],
        },
        {'id': 'b', 'component': 'Badge', 'label': 'New', 'color': 'success'},
        {'id': 'o', 'component': 'Bold', 'text': 'loud'},
        {'id': 'k', 'component': 'Code', 'text': 'x = 1', 'language': 'js'},
        {
          'id': 'a',
          'component': 'Link',
          'text': 'docs',
          'href': 'https://copilotkit.ai',
        },
      ]);
      expect(
        _drawn(tester, 'New').color,
        standardLight.color(A2uiColorToken.textSuccess),
      );
      final link = find.semantics.byLabel('docs (opens in a new tab)');
      expect(link, findsOne);
      expect(
        link.evaluate().single.getSemanticsData().flagsCollection.isLink,
        isTrue,
      );
      // href, target="_blank" (rel="noopener noreferrer" is url_launcher_web's
      // own): the link opens https://copilotkit.ai in a new tab.
      // getByText("loud").tagName === "STRONG": `font-weight: bolder`, 700
      // over the surface's 400.
      final loud = DefaultTextStyle.of(
        tester.element(find.text('loud', findRichText: true)),
      ).style.merge(_drawn(tester, 'loud'));
      expect(_inherited(tester, 'loud').fontWeight, isNot(FontWeight.w700));
      expect(loud.fontWeight, FontWeight.w700);
      // getByText("x = 1").closest("pre").tabIndex === 0: the box holding
      // the code is the first Tab stop (the Badge and the Bold take no
      // focus; the Link comes after it), and a focusable node.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus!.context!.widget;
      expect(
        find.descendant(
          of: find.byWidget(focused),
          matching: find.text('x = 1', findRichText: true),
        ),
        findsOneWidget,
      );
      // The focused node for screen readers holds the code's text.
      final focusedNode = find.semantics
          .byPredicate(
            (node) => node.flagsCollection.isFocused == Tristate.isTrue,
          )
          .evaluate()
          .single;
      final labels = <String>[];
      bool collect(SemanticsNode node) {
        labels.add(node.label);
        node.visitChildren(collect);
        return true;
      }

      collect(focusedNode);
      expect(labels, contains('x = 1'));
      await tester.tap(find.text('docs'));
      await tester.pump();
      expect(launcher.opened, [openedInNewTab('https://copilotkit.ai')]);
    });

    // text.test.tsx:182
    testWidgets('renders a Link with a javascript: href as plain text', (
      tester,
    ) async {
      final launcher = fakeUrlLauncher();
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Link',
          'text': 'bad',
          'href': 'javascript:alert(1)',
        },
      ]);
      expect(find.text('bad'), findsOneWidget);
      expect(
        find.semantics.byPredicate(
          (node) => node.getSemanticsData().flagsCollection.isLink,
        ),
        findsNothing,
      );
      await tester.tap(find.text('bad'));
      await tester.pump();
      expect(launcher.launches, isEmpty);
    });

    // text.test.tsx:195
    testWidgets('renders Markdown: "# Title" is a level 1 heading', (
      tester,
    ) async {
      await renderStandard(tester, [
        {'id': 'root', 'component': 'Markdown', 'text': _streamdownSample},
      ]);
      final heading = _heading(1);
      expect(heading, findsOne);
      expect(heading.evaluate().single.label, 'Title');
    });

    // text.test.tsx:195
    testWidgets("renders Markdown: Streamdown's strong, the list items and "
        'the quote', (tester) async {
      await renderStandard(tester, [
        {'id': 'root', 'component': 'Markdown', 'text': _streamdownSample},
      ]);
      final sheet = markdownStyleSheet(
        tester.element(find.byType(KitMarkdown)),
        standardLight,
      );
      // `data-streamdown="strong"`: the run in the sheet's strong style.
      expect(
        _runs(_richWith(tester, 'Some '))
            .firstWhere(
              (run) => run.style.fontWeight == sheet.strong!.fontWeight,
            )
            .text,
        'bold',
      );
      // `ul li`.
      expect(_itemsAfter(tester, _isDisc), ['one', 'two']);
      expect(
        _quoteAround('quoted', sheet.blockquoteDecoration),
        findsOneWidget,
      );
      // The `ul` is not an `a2ui-std-list`, whose one rule is `margin: 0`
      // (styles.ts:70): the list keeps the spacing it has around it, the
      // block gap before it and its indent, neither of them 0 (a sheet that
      // sets either to 0 fails here). The bullet's box is the sheet's
      // indent plus its bullet padding (flutter_markdown's default, 4px on
      // the right, when the sheet sets none). The sources give no literal
      // values: Streamdown 1.6.11's `ul` is `list-inside list-disc
      // whitespace-normal` and its blocks sit in a `space-y-4` div
      // (dist/chunk-JAPRZBRM.js), unprefixed Tailwind classes that
      // react-core's `cpk`-prefixed build gives no CSS; react-core's own
      // list rules (src/v2/styles/globals.css:199-213) apply only inside a
      // `[data-copilotkit]` root. The spacing is the host page's.
      final some = tester.getRect(
        find.text('Some bold text.', findRichText: true),
      );
      final one = tester.getRect(find.text('one', findRichText: true));
      expect(sheet.blockSpacing, greaterThan(0));
      expect(sheet.listIndent, greaterThan(0));
      expect(one.top - some.bottom, sheet.blockSpacing);
      expect(
        one.left - some.left,
        sheet.listIndent! +
            (sheet.listBulletPadding ?? const EdgeInsets.only(right: 4))
                .horizontal,
      );
    });

    // text.test.tsx:195
    testWidgets('renders Markdown with no typography of its own', (
      tester,
    ) async {
      await renderStandard(tester, [
        {'id': 'root', 'component': 'Markdown', 'text': _streamdownSample},
      ]);
      // The wrapper has no style: the paragraph takes the type around it.
      final inherited = DefaultTextStyle.of(
        tester.element(find.byType(KitMarkdown)),
      ).style;
      final body = _runs(_richWith(tester, 'Some ')).first.style;
      expect(body.fontFamily, inherited.fontFamily);
      expect(body.fontSize, inherited.fontSize);
      expect(body.height, inherited.height);
      expect(body.fontWeight, inherited.fontWeight);
      expect(body.color, inherited.color);
    });

    // text.test.tsx:195 (behaviour)
    testWidgets(
      'renders Markdown with no typography of its own, inside a Text of '
      'another colour and size',
      (tester) async {
        // Upstream's wrapper has no `style`, wherever it sits: the type comes
        // from around it. Inside a secondary, small Text, that type is not
        // the surface root's, so a colour or size the Markdown set itself
        // shows.
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Text',
            'text': 'Note',
            'color': 'secondary',
            'size': 'sm',
            'children': ['m'],
          },
          {'id': 'm', 'component': 'Markdown', 'text': 'Some **bold** text.'},
        ]);
        final inherited = DefaultTextStyle.of(
          tester.element(find.byType(KitMarkdown)),
        ).style;
        expect(
          inherited.color,
          standardLight.color(A2uiColorToken.textSecondary),
        );
        final body = _runs(_richWith(tester, 'Some ')).first.style;
        expect(body.color, inherited.color);
        expect(body.fontSize, inherited.fontSize);
        // `size: "sm"`: 0.875em of the type around the Text, the host's,
        // as the Text "Note" draws it (not the theme's 16px root, which
        // the queued surface fix in tokens_test.dart replaces with the
        // host's).
        expect(body.fontSize, _richWith(tester, 'Note').text.style!.fontSize);
      },
    );

    // text.test.tsx:219
    testWidgets('typesets Math with KaTeX, inline and as a block', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['i', 'b'],
        },
        {'id': 'i', 'component': 'Math', 'value': 'x^2'},
        {
          'id': 'b',
          'component': 'Math',
          'value': r'\frac{a}{b}',
          'block': true,
        },
      ]);
      // findAllByText("x"): KaTeX's text is drawn.
      expect(find.text('x', findRichText: true), findsWidgets);
      final column = tester.getRect(
        find.byWidget(flexContainerOf(tester, 'x')),
      );
      final formulas = find.byType(KitMath);
      final inline = tester.getRect(formulas.first);
      final block = tester.getRect(formulas.last);
      final size = DefaultTextStyle.of(
        tester.element(formulas.last),
      ).style.fontSize!;
      // [data-math="inline"] is a SPAN with no .katex-display: the formula
      // starts its line, at the Column's start and top (no display margin,
      // no centring).
      expect(inline.topLeft, column.topLeft);
      expect(
        tester.getRect(find.text('x', findRichText: true).first).left,
        column.left,
      );
      // Its `.katex math`, what a screen reader reads: the formula's node,
      // labelled with its TeX.
      expect(find.semantics.byLabel('x^2'), findsOne);
      // [data-math="block"] is a DIV holding a .katex-display: centred on a
      // line of its own, 1em (the surrounding size) below the line's top.
      final display = tester.getRect(
        find.descendant(of: formulas.last, matching: find.byType(Math)),
      );
      expect(block.left, column.left);
      expect(block.width, column.width);
      expect(display.center.dx, closeTo(column.center.dx, 1e-9));
      expect(display.top - block.top, size);
      expect(block.bottom - display.bottom, size);
      // ... and an `mfrac` in the display style: a over b, both at the
      // formula's own size (1.21em; the text style would set them at 0.7 of
      // it).
      final a = find.text('a', findRichText: true);
      final b = find.text('b', findRichText: true);
      expect(tester.getRect(a).bottom, lessThan(tester.getRect(b).top));
      expect(tester.widget<RichText>(a).text.style!.fontSize, size * 1.21);
      expect(tester.widget<RichText>(b).text.style!.fontSize, size * 1.21);
      expect(find.semantics.byLabel(r'\frac{a}{b}'), findsOne);
    });

    // text.test.tsx:235
    testWidgets('shows invalid TeX as source text instead of failing', (
      tester,
    ) async {
      await renderStandard(tester, [
        {'id': 'root', 'component': 'Math', 'value': r'\frac{a'},
      ]);
      expect(tester.takeException(), isNull);
      // findByText("\\frac{a").
      final error = find.text(r'\frac{a', findRichText: true);
      expect(error, findsOneWidget);
      // classList.contains("katex-error"): KaTeX's error span, drawn in its
      // `errorColor` (#cc0000, Settings.js:134-136) ...
      final drawn = DefaultTextStyle.of(
        tester.element(error),
      ).style.merge(_drawn(tester, r'\frac{a'));
      expect(drawn.color!.toARGB32(), 0xffcc0000);
      // ... with KaTeX's message as its `title` (katex.js:102).
      expect(
        find.semantics.byPredicate(
          (node) => node.tooltip.startsWith('ParseError: KaTeX parse error: '),
        ),
        findsOne,
      );
    });
  });

  group('renderInlineMarkdown', () {
    // text.test.tsx:283
    testWidgets('renders bold, italic, strikethrough, code and links', (
      tester,
    ) async {
      const source = 'a **b** *c* ~~d~~ `e` [f](https://x.y)';
      final segments = parseInlineMarkdown(source);
      expect(segments, contains(const InlineMarked('b', InlineMark.strong)));
      expect(segments, contains(const InlineMarked('c', InlineMark.emphasis)));
      expect(segments, contains(const InlineMarked('d', InlineMark.strike)));
      expect(segments, contains(const InlineMarked('e', InlineMark.code)));
      expect(_hrefs(segments), contains('https://x.y'));
      // What the Text draws: renderInlineMarkdown's elements.
      final launcher = fakeUrlLauncher();
      final drawn = await _drawInline(tester, source);
      // <strong>b</strong>: font-weight bolder, 700 over the Text's 400.
      expect(drawn.style('b').fontWeight, FontWeight.w700);
      // <em>c</em>.
      expect(drawn.style('c').fontStyle, FontStyle.italic);
      // <s>d</s>.
      expect(
        drawn.style('d').decoration?.contains(TextDecoration.lineThrough),
        isTrue,
      );
      // <code>e</code>: the theme's mono face at its inline code size.
      _expectCode(drawn, 'e');
      // href="https://x.y": a link span that opens it, a link node for
      // screen readers.
      final link = _span(drawn.rich, 'f');
      expect(_linkNodes('f (opens in a new tab)'), findsOne);
      (link.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
      expect(launcher.opened, [openedInNewTab('https://x.y')]);
      // The plain runs carry none of these.
      expect(drawn.style('a ').fontStyle, isNot(FontStyle.italic));
      expect(drawn.style('a ').fontWeight, isNot(FontWeight.w700));
    });

    // text.test.tsx:292
    testWidgets('leaves plain text alone and escapes it once', (tester) async {
      expect(parseInlineMarkdown('1 < 2 & 3'), [
        const InlinePlain('1 < 2 & 3'),
      ]);
      // <span>1 &lt; 2 &amp; 3</span>: one plain run, as written.
      (await _drawInline(tester, '1 < 2 & 3')).expectPlain('1 < 2 & 3');
    });

    // text.test.tsx:296
    testWidgets('does not make a link of a javascript: URL', (tester) async {
      final segments = parseInlineMarkdown('[x](javascript:alert(1))');
      expect(_hrefs(segments), isEmpty);
      expect(segments, [const InlinePlain('x')]);
      // <span>x</span>: no href, no link.
      (await _drawInline(tester, '[x](javascript:alert(1))')).expectPlain('x');
    });

    // text.test.tsx:302
    testWidgets('supports underscore italics and ++underline++', (
      tester,
    ) async {
      final segments = parseInlineMarkdown('_i_ and ++u++');
      expect(segments, contains(const InlineMarked('i', InlineMark.emphasis)));
      expect(segments, contains(const InlineMarked('u', InlineMark.underline)));
      final drawn = await _drawInline(tester, '_i_ and ++u++');
      // <em>i</em>.
      expect(drawn.style('i').fontStyle, FontStyle.italic);
      // <u>u</u>.
      expect(
        drawn.style('u').decoration?.contains(TextDecoration.underline),
        isTrue,
      );
    });

    // text.test.tsx:308
    testWidgets('leaves underscores inside a word alone', (tester) async {
      expect(parseInlineMarkdown('use snake_case_name'), [
        const InlinePlain('use snake_case_name'),
      ]);
      (await _drawInline(
        tester,
        'use snake_case_name',
      )).expectPlain('use snake_case_name');
    });

    // text.test.tsx:314
    testWidgets('keeps code spans literal', (tester) async {
      expect(
        parseInlineMarkdown('`**x**`'),
        contains(const InlineMarked('**x**', InlineMark.code)),
      );
      // <code>**x**</code>.
      _expectCode(await _drawInline(tester, '`**x**`'), '**x**');
    });

    // text.test.tsx:318
    testWidgets('renders unmatched markers as plain text', (tester) async {
      expect(parseInlineMarkdown('2 * 3 = 6 and a ** b'), [
        const InlinePlain('2 * 3 = 6 and a ** b'),
      ]);
      (await _drawInline(
        tester,
        '2 * 3 = 6 and a ** b',
      )).expectPlain('2 * 3 = 6 and a ** b');
    });

    // text.test.tsx:324
    testWidgets('opens links in a new tab, safely, and says so to screen '
        'readers', (tester) async {
      expect(
        _hrefs(parseInlineMarkdown('[m](mailto:a@b.c)')),
        contains('mailto:a@b.c'),
      );
      final launcher = fakeUrlLauncher();
      await renderStandard(tester, [
        {'id': 'root', 'component': 'Text', 'text': '[m](mailto:a@b.c)'},
      ]);
      final link = _span(_richWith(tester, 'm'), 'm');
      // "(opens in a new tab)": what a screen reader hears of the link.
      expect(_linkNodes('m (opens in a new tab)'), findsOne);
      // href and target="_blank" (rel is url_launcher_web's own).
      (link.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
      expect(launcher.opened, [openedInNewTab('mailto:a@b.c')]);
    });
  });

  group('block markdown, through the Markdown component', () {
    // text.test.tsx:334 (behaviour)
    testWidgets('joins paragraph lines, keeps fences verbatim and adds no '
        'empty paragraphs', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Markdown',
          'text': 'a\nb\n\n```\n# not a heading\n```\n\n\n',
        },
      ]);
      final sheet = markdownStyleSheet(
        tester.element(find.byType(KitMarkdown)),
        standardLight,
      );
      expect(richTexts(tester), ['a b', '# not a heading']);
      expect(
        find.ancestor(
          of: find.text('# not a heading', findRichText: true),
          matching: _boxOf(sheet.codeblockDecoration),
        ),
        findsOneWidget,
      );
    });

    // text.test.tsx:343 (behaviour)
    testWidgets('renders "# Title" as a level 1 heading', (tester) async {
      await renderStandard(tester, [
        {'id': 'root', 'component': 'Markdown', 'text': _blockSample},
      ]);
      final heading = _heading(1);
      expect(heading, findsOne);
      expect(heading.evaluate().single.label, 'Title');
    });

    // text.test.tsx:343 (behaviour)
    testWidgets('renders bold text, lists, quotes, code and rules', (
      tester,
    ) async {
      await renderStandard(tester, [
        {'id': 'root', 'component': 'Markdown', 'text': _blockSample},
      ]);
      final sheet = markdownStyleSheet(
        tester.element(find.byType(KitMarkdown)),
        standardLight,
      );
      expect(
        _runs(_richWith(tester, 'Some '))
            .firstWhere(
              (run) => run.style.fontWeight == sheet.strong!.fontWeight,
            )
            .text,
        'bold',
      );
      // `ul li` and `ol li`.
      expect(_itemsAfter(tester, _isDisc), hasLength(2));
      expect(_itemsAfter(tester, _isNumber), hasLength(2));
      expect(
        _quoteAround('quoted', sheet.blockquoteDecoration),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('x = 1', findRichText: true),
          matching: _boxOf(sheet.codeblockDecoration),
        ),
        findsOneWidget,
      );
      // `hr`.
      expect(_boxOf(sheet.horizontalRuleDecoration), findsOneWidget);
    });
  });
}
