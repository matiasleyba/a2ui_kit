// Parity tests of CopilotKit's standard catalog, layout and text, ported
// from layout-parity.test.tsx in
// packages/react-core/src/v2/generative-ui/standard/__tests__/
// (MIT, (c) Atai Barkai). Each test names its upstream file and line.
//
// ignore: lines_longer_than_80_chars (port_status.dart reads this line whole)
// Parity for: Badge, Box, Caption, Card, Column, Divider, Flow, Grid, GridItem, Label, Link, Markdown, Row, Spacer, Text, Blockquote, Code, Italic, Underline, Strikethrough
//
// Upstream renders `standardUI`, the standard catalog: here
// `renderStandard` (test/helpers/parity.dart). Its `spacing(n)`
// (`calc(var(--spacing, 0.25rem) * n)`) is 4n px.
//
// Not ported (bound to internals):
// - layout-parity.test.tsx:25 the tag name `hr`: Flutter's SemanticsRole
//   has no separator, so the rule is read as the Divider's line. Its `h1`
//   and `li` have counterparts: a level 1 heading node and a list-item node
//   (tested, and the texts after them are drawn).
// - layout-parity.test.tsx:102 `data-a2ui-row` and the `STANDARD_CSS` text
//   `[data-a2ui-row="spaceBetween"]>[data-a2ui-text]:last-child:not(
//   :first-child){text-align:right`: the stylesheet hook and the rule's
//   source. What the rule does (the last Text of a spaceBetween Row, when
//   not also its first, is set right and pushed to the Row's end; a lone
//   Text is neither) and the Row's justify are tested.
// - layout-parity.test.tsx:296 `gridItemColumn(2, undefined)` ("span 2"
//   without a known column count): a GridItem's span acts only inside a
//   CssGrid, which always knows its track count. The other five cases are
//   tested as the widths the spans give.
//
// `role="group"` (layout-parity.test.tsx:179) is ported: Flutter's
// SemanticsRole has no group, so a group is read as in layout_test.dart
// (layout.test.tsx:159), a semantics node of its own, here the Card's,
// whose box it covers. The flush
// padding and the removed gap are tested beside it.
//
// Translated (upstream reads tag names and an inline style string; the
// tests read what is drawn):
// - layout-parity.test.tsx:25 `closest("blockquote")` and `closest("pre")`:
//   "quote" drawn inside the Blockquote's box (its 3px left line in the
//   strong border colour, no other side) and "x = 1" inside the Code's box
//   (its secondary surface fill).
// - layout-parity.test.tsx:60 the tag names EM, U and S: the runs drawn
//   italic, underlined and struck through.
// - layout-parity.test.tsx:72 STRONG and `style.borderLeft` "3px solid":
//   "bold" drawn `bolder` (700 over 400) inside a box whose left side is a
//   3px solid line.
//
// Later phase (no Dart yet):
// - layout-parity.test.tsx:83 `it.each` case "Carousel" of "%s repeats a
//   template child per data item".
// - layout-parity.test.tsx:132 "Carousel renders previous/next arrows with
//   custom labels" and :153 "Carousel writes the snapped slide to a bound
//   activeIndex" (Carousel, CarouselItem).
// - layout-parity.test.tsx:280 "Tooltip hugs its trigger instead of
//   stretching across the column" (Tooltip).

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// Upstream's `spacing(steps)`: `calc(var(--spacing, 0.25rem) * steps)`.
int _spacing(int steps) => 4 * steps;

/// A padding of `spacing(steps)` on every side.
EdgeInsets _padding(int steps) => EdgeInsets.all(_spacing(steps).toDouble());

/// A standard Text.
Map<String, Object?> _text(String id, String text) => {
  'id': id,
  'component': 'Text',
  'text': text,
};

/// The surface's content: the outermost container around [text]. Finders
/// scoped to it skip the app's own widgets.
Finder _surfaceAround(WidgetTester tester, String text) =>
    find.byWidget(flexContainersAround(tester, text).last);

/// The width of the container around [text].
double _widthAround(WidgetTester tester, String text) =>
    tester.getSize(find.byWidget(flexContainerOf(tester, text))).width;

/// Finds the boxes drawn with a [BoxDecoration] [test] accepts.
Finder _boxWith(bool Function(BoxDecoration decoration) test) =>
    find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          test(widget.decoration as BoxDecoration),
    );

/// A Blockquote's line: `border-left: 3px solid` in the strong border
/// colour, and no other side.
bool _quoteRule(BoxDecoration decoration) => switch (decoration.border) {
  Border(:final top, :final right, :final bottom, :final left) =>
    left.width == 3 &&
        left.style == BorderStyle.solid &&
        left.color.toARGB32() ==
            standardLight.color(A2uiColorToken.borderStrong).toARGB32() &&
        top == BorderSide.none &&
        right == BorderSide.none &&
        bottom == BorderSide.none,
  _ => false,
};

/// The style of the run of [text] in the RichText that draws it, with the
/// style that RichText inherits and every ancestor span's merged in.
TextStyle _runStyle(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(
    find
        .byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains(text),
        )
        .last,
  );
  TextStyle? found;
  void visit(InlineSpan span, TextStyle style) {
    final merged = style.merge(span.style);
    if (span is! TextSpan) return;
    if (span.text == text) found = merged;
    for (final child in span.children ?? const <InlineSpan>[]) {
      visit(child, merged);
    }
  }

  visit(rich.text, const TextStyle());
  return found!;
}

/// The flex item style of the child holding [text] in its container.
A2uiFlexItemStyle _itemStyleOf(WidgetTester tester, String text) => tester
    .widget<CssFlexItem>(
      find
          .ancestor(
            of: find.text(text, findRichText: true),
            matching: find.byType(CssFlexItem),
          )
          .first,
    )
    .style;

void main() {
  group('standard catalog: layout and text (parity)', () {
    // layout-parity.test.tsx:25
    testWidgets('Badge, Caption, Label, Divider, Spacer, Blockquote, Code, '
        'Link, Markdown render', (tester) async {
      final opened = <Uri>[];
      await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['b', 'c', 'l', 'd', 's', 'q', 'k', 'a', 'm'],
          },
          {'id': 'b', 'component': 'Badge', 'label': 'New', 'color': 'success'},
          {'id': 'c', 'component': 'Caption', 'text': 'cap'},
          {'id': 'l', 'component': 'Label', 'text': 'lab'},
          {'id': 'd', 'component': 'Divider'},
          {'id': 's', 'component': 'Spacer', 'minSize': 8},
          {'id': 'q', 'component': 'Blockquote', 'text': 'quote'},
          {'id': 'k', 'component': 'Code', 'text': 'x = 1'},
          {
            'id': 'a',
            'component': 'Link',
            'text': 'docs',
            'href': 'https://copilotkit.ai',
          },
          {'id': 'm', 'component': 'Markdown', 'text': '# H\n\n- one'},
        ],
        options: A2uiKitOptions(
          look: A2uiKitLook.standard,
          onOpenUrl: opened.add,
        ),
      );
      await tester.pump();
      expect(find.text('New', findRichText: true), findsOneWidget);
      // href: the link opens https://copilotkit.ai.
      await tester.tap(find.text('docs', findRichText: true));
      await tester.pump();
      expect(opened, [Uri.parse('https://copilotkit.ai')]);
      // An `hr`: the Divider's line, one box with a top border and no other
      // side (a Blockquote's or Code's box, once drawn, is not one).
      expect(
        find.descendant(
          of: _surfaceAround(tester, 'New'),
          matching: find.byWidgetPredicate(
            (w) => switch (w) {
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    :final top,
                    :final right,
                    :final bottom,
                    :final left,
                  ),
                ),
              ) =>
                top.width > 0 &&
                    top.style == BorderStyle.solid &&
                    right == BorderSide.none &&
                    bottom == BorderSide.none &&
                    left == BorderSide.none,
              _ => false,
            },
          ),
        ),
        findsOneWidget,
      );
      // The `h1` reads "H" (its heading node: the test below).
      expect(find.text('H', findRichText: true), findsOneWidget);
      // The `li` reads "one": the text after the item's bullet (its
      // list-item node: the test below).
      final texts = richTexts(tester);
      expect(
        [
          for (var i = 0; i + 1 < texts.length; i++)
            if (texts[i] == '•') texts[i + 1],
        ],
        ['one'],
      );
      // getByText("quote").closest("blockquote"): "quote" inside the
      // Blockquote's box, a 3px solid line on its left only.
      expect(
        find.ancestor(
          of: find.text('quote', findRichText: true),
          matching: _boxWith(_quoteRule),
        ),
        findsOneWidget,
      );
      // getByText("x = 1").closest("pre"): "x = 1" inside the Code's box,
      // filled with the secondary surface.
      expect(
        find.ancestor(
          of: find.text('x = 1', findRichText: true),
          matching: _boxWith(
            (decoration) =>
                decoration.color?.toARGB32() ==
                standardLight.color(A2uiColorToken.surfaceSecondary).toARGB32(),
          ),
        ),
        findsOneWidget,
      );
    });

    // layout-parity.test.tsx:25, :54-57: the Markdown's `h1` "H" and `li`
    // "one", as a screen reader gets them.
    testWidgets('Markdown renders: a level 1 heading "H"', (tester) async {
      await renderStandard(tester, [
        {'id': 'root', 'component': 'Markdown', 'text': '# H\n\n- one'},
      ]);
      final heading = find.semantics.byPredicate(
        (node) =>
            node.getSemanticsData().flagsCollection.isHeader &&
            node.headingLevel == 1,
      );
      expect(heading, findsOne);
      expect(heading.evaluate().single.label, 'H');
    });

    // layout-parity.test.tsx:25, :57: the `li` "one".
    testWidgets('Markdown renders: a list item "one"', (tester) async {
      await renderStandard(tester, [
        {'id': 'root', 'component': 'Markdown', 'text': '# H\n\n- one'},
      ]);
      expect(
        find.semantics.byPredicate(
          (node) => node.role == SemanticsRole.listItem && node.label == 'one',
        ),
        findsOne,
      );
    });

    // layout-parity.test.tsx:60
    testWidgets('Italic, Underline and Strikethrough render as inline '
        'elements', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Text',
          'text': 'Was',
          'children': ['i', 'u', 's'],
        },
        {'id': 'i', 'component': 'Italic', 'text': 'it'},
        {'id': 'u', 'component': 'Underline', 'text': 'un'},
        {'id': 's', 'component': 'Strikethrough', 'text': 'st'},
      ]);
      final text = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().startsWith('Was'),
        ),
      );
      // Inline: each is words of the Text's own line, after "Was" and its
      // space, as `<span>Was <em>it</em><u>un</u><s>st</s></span>` reads
      // (the elements' words continue the line, RULEBOOK section 2), never
      // a box of its own.
      expect(text.text.toPlainText(), 'Was itunst');
      // findByText("it").tagName === "EM": italic.
      expect(_runStyle(tester, 'it').fontStyle, FontStyle.italic);
      // getByText("un").tagName === "U": underlined.
      expect(_runStyle(tester, 'un').decoration, TextDecoration.underline);
      // getByText("st").tagName === "S": struck through.
      expect(_runStyle(tester, 'st').decoration, TextDecoration.lineThrough);
      // Each only its own: "Was" is none of them.
      final was = _runStyle(tester, 'Was');
      expect(was.fontStyle, isNot(FontStyle.italic));
      expect(was.decoration ?? TextDecoration.none, TextDecoration.none);
    });

    // layout-parity.test.tsx:72
    testWidgets('Blockquote renders inline markdown in its text', (
      tester,
    ) async {
      await renderStandard(tester, [
        {'id': 'root', 'component': 'Blockquote', 'text': 'A **bold** claim'},
      ]);
      // findByText("bold").tagName === "STRONG": bolder, 700 over 400.
      expect(_runStyle(tester, 'bold').fontWeight, FontWeight.w700);
      expect(_runStyle(tester, 'A ').fontWeight, isNot(FontWeight.w700));
      // strong.closest("blockquote").style.borderLeft contains "3px solid".
      expect(
        find.ancestor(
          of: find.text('A bold claim', findRichText: true),
          matching: _boxWith(_quoteRule),
        ),
        findsOneWidget,
      );
    });

    for (final component in ['Column', 'Grid', 'Card', 'Row', 'Box', 'Flow']) {
      // layout-parity.test.tsx:83
      testWidgets('$component repeats a template child per data item', (
        tester,
      ) async {
        await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': component,
              'children': {'componentId': 'row', 'path': '/items'},
            },
            {
              'id': 'row',
              'component': 'Text',
              'text': {'@path': 'name'},
            },
          ],
          data: {
            'items': [
              {'name': 'Alpha'},
              {'name': 'Beta'},
            ],
          },
        );
        expect(find.text('Alpha', findRichText: true), findsOneWidget);
        expect(find.text('Beta', findRichText: true), findsOneWidget);
      });
    }

    // layout-parity.test.tsx:102
    testWidgets('centres Row children by default and keeps text from '
        'stretching', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['r1', 'r2', 'r3'],
        },
        {
          'id': 'r1',
          'component': 'Row',
          'justify': 'spaceBetween',
          'children': ['k', 'val'],
        },
        _text('k', 'Price'),
        {
          'id': 'val',
          'component': 'Text',
          'text': r'$29.00',
          'tabularNums': true,
        },
        {
          'id': 'r2',
          'component': 'Row',
          'align': 'start',
          'children': ['s'],
        },
        _text('s', 'top'),
        // `:last-child:not(:first-child)`: a lone Text is not set right.
        {
          'id': 'r3',
          'component': 'Row',
          'justify': 'spaceBetween',
          'children': ['o'],
        },
        _text('o', 'alone'),
      ]);
      final row = flexContainerOf(tester, r'$29.00').flex;
      expect(row.align, A2uiAlign.center);
      // data-a2ui-row: "spaceBetween".
      expect(row.justify, A2uiJustify.spaceBetween);
      // flex: 0 1 auto.
      final item = _itemStyleOf(tester, r'$29.00');
      expect(item.grow, 0);
      expect(item.shrink, 1);
      expect(item.basis, isNull);
      // min-width: 0.
      expect(item.minWidth, A2uiLength.zero);
      // No width.
      expect(item.width, isNull);
      final value = tester.widget<Text>(find.text(r'$29.00'));
      // font-variant-numeric: tabular-nums.
      expect(
        value.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      // align-items: flex-start.
      expect(flexContainerOf(tester, 'top').flex.align, A2uiAlign.start);
      // The STANDARD_CSS rule: the last Text of a spaceBetween Row, when not
      // also its first, is set right; the first is not.
      expect(value.textAlign, TextAlign.right);
      expect(
        tester.widget<Text>(find.text('Price')).textAlign,
        isNot(TextAlign.right),
      );
      expect(
        flexContainerOf(tester, 'alone').flex.justify,
        A2uiJustify.spaceBetween,
      );
      expect(
        tester.widget<Text>(find.text('alone')).textAlign,
        isNot(TextAlign.right),
      );
      // Where they sit: the rule's `margin-inline-start: auto` pushes the
      // last Text to the Row's end; a lone Text stays at its start.
      Rect rectOf(String text) =>
          tester.getRect(find.text(text, findRichText: true));
      Rect rowOf(String text) =>
          tester.getRect(find.byWidget(flexContainerOf(tester, text)));
      expect(rectOf(r'$29.00').right, rowOf(r'$29.00').right);
      expect(rectOf('alone').left, rowOf('alone').left);
    });

    // layout-parity.test.tsx:179
    testWidgets('layout props: flush removes padding, disableAutoSpacing '
        'removes the default gap, role is applied', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['c'],
        },
        {
          'id': 'c',
          'component': 'Card',
          'flush': true,
          'disableAutoSpacing': true,
          'role': 'group',
          'children': ['t'],
        },
        _text('t', 'Inside'),
      ]);
      final card = flexContainerOf(tester, 'Inside');
      expect(card.box.padding, EdgeInsets.zero);
      expect(card.flex.rowGap, 0);
      expect(card.flex.columnGap, 0);
    });

    // layout-parity.test.tsx:179
    testWidgets(
      'role is applied: a group Card is a semantics node of its own',
      (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['c', 'a'],
          },
          {
            'id': 'c',
            'component': 'Card',
            'role': 'group',
            'children': ['t'],
          },
          _text('t', 'Inside'),
          // A sibling, so the root Column is not the Card's size.
          _text('a', 'After'),
        ]);
        // A node of the Card's own size holds the text's node: the group.
        final card = tester.getSize(
          find.byWidget(flexContainerOf(tester, 'Inside')),
        );
        final group = <SemanticsNode>[];
        for (
          SemanticsNode? node = tester.getSemantics(
            find.text('Inside', findRichText: true),
          );
          node != null;
          node = node.parent
        ) {
          if (node.rect.size == card) group.add(node);
        }
        expect(group, hasLength(1));
      },
    );

    // layout-parity.test.tsx:198
    testWidgets('minSize and maxSize set both dimensions of a container', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Box',
          'minSize': 10,
          'maxSize': 40,
          'children': ['t'],
        },
        _text('t', 'Sized'),
      ]);
      final box = flexContainerOf(tester, 'Sized').box;
      expect(box.minWidth, A2uiLength.px(_spacing(10).toDouble()));
      expect(box.minHeight, A2uiLength.px(_spacing(10).toDouble()));
      expect(box.maxWidth, A2uiLength.px(_spacing(40).toDouble()));
      expect(box.maxHeight, A2uiLength.px(_spacing(40).toDouble()));
    });

    // layout-parity.test.tsx:216
    testWidgets('Card size and shadowStyle presets apply', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Card',
          'size': 'sm',
          'shadowStyle': 'md',
          'children': ['t'],
        },
        _text('t', 'Small'),
      ]);
      // padding: spacing(2), as drawn: the text sits that far inside the
      // Card's border on the top and the left.
      final card = flexContainerOf(tester, 'Small');
      final inset =
          tester.getTopLeft(find.text('Small', findRichText: true)) -
          tester.getTopLeft(find.byWidget(card));
      final border = card.box.borderWidth;
      expect(
        inset,
        Offset(_padding(2).left + border, _padding(2).top + border),
      );
      // var(--a2ui-shadow-md): each of its shadows, painted.
      for (final shadow in standardLight.shadow(A2uiShadowToken.md)) {
        expect(paintedPage(tester), paints..something(paintedShadow(shadow)));
      }
    });

    // layout-parity.test.tsx:232
    testWidgets('Text fontSize, lineHeight and minLines', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Text',
          'text': 'Tall',
          'fontSize': 18,
          'lineHeight': 1.2,
          'minLines': 3,
        },
      ]);
      // The style the text is drawn in: its RichText's root style, what
      // it inherits merged with its own.
      final style = tester
          .widget<RichText>(find.text('Tall', findRichText: true))
          .text
          .style;
      // font-size: 18px.
      expect(style?.fontSize, 18);
      // line-height: 1.2.
      expect(style?.height, 1.2);
      // min-height: 4.5em, of 18px; one 21.6px line is shorter.
      expect(tester.getSize(find.text('Tall', findRichText: true)).height, 81);
    });

    // layout-parity.test.tsx:249
    testWidgets('onVisible dispatches once when the container becomes '
        'visible', (tester) async {
      // Upstream's observer reports the container visible twice. Here it
      // shows, then is checked twice more while it stays visible: after a
      // scroll (a tall Box makes the 600px page scroll) and after the agent
      // re-sends it (a rebuild). A VisibleOnce that forgot it had fired
      // would send "seen" again on either.
      Map<String, Object?> column(int gap) => {
        'id': 'root',
        'component': 'Column',
        'gap': gap,
        'onVisible': {
          'event': {'name': 'seen'},
        },
        'children': ['t', 'tall'],
      };
      final view = await renderStandard(tester, [
        column(2),
        _text('t', 'Hi'),
        {'id': 'tall', 'component': 'Box', 'minSize': 250},
      ]);
      expect(find.text('Hi', findRichText: true), findsOneWidget);
      await tester.pump();
      expect(view.actionNames, ['seen']);
      final scrollable = find.byType(Scrollable).first;
      final before = tester.state<ScrollableState>(scrollable).position.pixels;
      await tester.drag(scrollable, const Offset(0, -20));
      await tester.pump();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(before),
      );
      await view.update([
        agentComponents([column(4)]),
      ]);
      await tester.pump();
      expect(view.actions, hasLength(1));
      expect(view.actions.first.name, 'seen');
    });
  });

  group('standard catalog: GridItem span (parity)', () {
    // layout-parity.test.tsx:296
    testWidgets('clamps spans that cover every column to the full row', (
      tester,
    ) async {
      // gridItemColumn(span, columns) read as the width of the GridItem in
      // a Grid 632px wide, where every one of the `columns` tracks shows:
      // 200px tracks for 3 (632 = 3 × 200 + 2 × 16), 308px for 2, 632px for
      // 1. Two cells after the item keep auto-fit from collapsing the tracks
      // the item leaves free.
      for (final (span, columns, width) in <(int?, int, double)>[
        // undefined: no grid-column, one cell.
        (null, 3, 200),
        // "span 2": two tracks and the gap between them.
        (2, 3, 416),
        // "1 / -1": the full row.
        (3, 3, 632),
        (5, 2, 632),
        (2, 1, 632),
      ]) {
        await renderStandard(tester, width: 632, [
          {
            'id': 'root',
            'component': 'Grid',
            'columns': columns,
            'children': ['item', 'f1', 'f2'],
          },
          {
            'id': 'item',
            'component': 'GridItem',
            'span': ?span,
            'children': ['t'],
          },
          _text('t', 'Item'),
          _text('f1', 'Fill one'),
          _text('f2', 'Fill two'),
        ]);
        expect(
          _widthAround(tester, 'Item'),
          width,
          reason: 'gridItemColumn($span, $columns)',
        );
      }
    });

    // layout-parity.test.tsx:305
    testWidgets('GridItem with span > columns fills the row instead of '
        'overflowing', (tester) async {
      // Two 308px tracks 16px apart, as in the test above.
      await renderStandard(tester, width: 632, [
        {
          'id': 'root',
          'component': 'Grid',
          'columns': 2,
          'children': ['a', 'b'],
        },
        {
          'id': 'a',
          'component': 'GridItem',
          'span': 4,
          'children': ['ta'],
        },
        _text('ta', 'Wide'),
        {
          'id': 'b',
          'component': 'GridItem',
          'span': 1,
          'children': ['tb'],
        },
        _text('tb', 'Narrow'),
      ]);
      // gridColumn "1 / -1".
      expect(_widthAround(tester, 'Wide'), 632);
      // gridColumn "span 1".
      expect(_widthAround(tester, 'Narrow'), 308);
    });
  });
}
