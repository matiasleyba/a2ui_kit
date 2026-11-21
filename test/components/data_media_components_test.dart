// Widget tests of List, ListItem, Image, Icon, Link and Markdown, after
// CopilotKit's react-core standard/__tests__/{data,media,text}.test.tsx.

import 'dart:ui' as ui;

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/components/standard/media/image.dart';
import 'package:a2ui_kit/src/components/standard/text/math.dart' show KitMath;
import 'package:a2ui_kit/src/foundation/icons/lucide.dart' show SvgPathGlyph;
import 'package:a2ui_kit/src/foundation/interaction/actions.dart';
import 'package:a2ui_kit/src/foundation/layout/replaced_box.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OpacityLayer, RenderParagraph;
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

Map<String, Object?> _root(Map<String, Object?> props) => {
  'id': 'root',
  ...props,
};

void main() {
  group('List', () {
    testWidgets('items: bullets, labels, values and descriptions', (
      tester,
    ) async {
      await pumpComponents(tester, [
        _root({
          'component': 'List',
          'items': [
            'Plain',
            {'label': 'Price', 'value': 1599},
            {'label': 'Ship', 'description': 'In 2 days', 'icon': 'truck'},
          ],
        }),
      ]);
      expect(find.text('Plain'), findsOneWidget);
      expect(find.text('1599'), findsOneWidget);
      expect(find.text('In 2 days'), findsOneWidget);
      expect(find.text('• '), findsNWidgets(3));
      expect(find.byType(LucideGlyph), findsOneWidget);
      // The value sits on the right, on the label's line.
      expect(
        tester.getRect(find.text('1599')).right,
        closeTo(tester.getRect(find.text('Price')).right, 400),
      );
      expect(
        tester.getRect(find.text('1599')).left,
        greaterThan(tester.getRect(find.text('Price')).right),
      );
    });

    testWidgets('numbers from start; rich and none draw no marker', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['n', 'r'],
        },
        {
          'id': 'n',
          'component': 'List',
          'marker': 'number',
          'start': 3,
          'items': ['a', 'b'],
        },
        {
          'id': 'r',
          'component': 'List',
          'marker': 'rich',
          'items': ['c'],
        },
      ]);
      expect(find.text('3. '), findsOneWidget);
      expect(find.text('4. '), findsOneWidget);
      expect(find.text('• '), findsNothing);
    });

    // Running review B6: the browser's outside marker "1. " keeps its space
    // before the label (CSS Counter Styles 3, `decimal`'s suffix; the
    // marker's `white-space: pre`), in the list's `padding-inline-start:
    // 1.5em` (data.tsx:381), an em that grows with the text scale.
    for (final scale in [1.0, 2.0]) {
      testWidgets('a number keeps its space before the label, in a 1.5em '
          'column, at text scale $scale', (tester) async {
        await pumpComponents(tester, textScale: scale, [
          _root({
            'component': 'List',
            'marker': 'number',
            'items': ['Compound interest', 'Simple'],
          }),
        ]);
        final label = tester.getRect(find.text('Compound interest'));
        // The list's font size (the marker's: `md` is 1em), scaled; the
        // surface starts at x = 0.
        final em = MediaQuery.textScalerOf(
          tester.element(find.text('1. ')),
        ).scale(tester.widget<Text>(find.text('1. ')).style!.fontSize!);
        expect(em, 16 * scale);
        expect(label.left, closeTo(1.5 * em, 1e-6));
        // "1." then its space, the marker ending where the label starts.
        final marker = tester.renderObject<RenderParagraph>(find.text('1. '));
        double caret(int offset) => marker
            .getOffsetForCaret(TextPosition(offset: offset), Rect.zero)
            .dx;
        expect(caret(3), greaterThan(caret(2)));
        expect(
          marker.localToGlobal(Offset.zero).dx + caret(3),
          closeTo(label.left, 1e-6),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a pick sends the index, label and value in the context', (
      tester,
    ) async {
      final surfaces = await pumpComponents(tester, [
        _root({
          'component': 'List',
          'items': [
            'First',
            {'label': 'Second', 'value': 42},
          ],
          'action': {
            'event': {
              'name': 'pick',
              'context': {'from': 'list'},
            },
          },
        }),
      ]);
      // With an action, the value is the payload, not shown.
      expect(find.text('42'), findsNothing);
      await tester.tap(find.text('Second'));
      await tester.pump();
      expect(surfaces.actions.single.name, 'pick');
      expect(surfaces.actions.single.context, {
        'index': 1,
        'label': 'Second',
        'value': '42',
        'from': 'list',
      });
      await tester.tap(find.text('First'));
      await tester.pump();
      expect(surfaces.actions.last.context, {
        'index': 0,
        'label': 'First',
        'from': 'list',
      });
    });

    test('a functionCall gets the arguments in its args, its own winning', () {
      expect(
        withCallArgs(
          {
            'call': 'openUrl',
            'args': {'url': 'https://a.example', 'label': 'own'},
          },
          {'index': 1, 'label': 'Second', 'value': '42'},
        ),
        {
          'call': 'openUrl',
          'args': {
            'index': 1,
            'label': 'own',
            'value': '42',
            'url': 'https://a.example',
          },
        },
      );
    });

    testWidgets('a pick runs a functionCall binding from the gesture', (
      tester,
    ) async {
      final opened = <Uri>[];
      final surfaces = await pumpComponents(
        tester,
        [
          _root({
            'component': 'List',
            'items': ['Docs'],
            'action': {
              'functionCall': {
                '@call': 'openUrl',
                'args': {'url': 'https://docs.example.com'},
              },
            },
          }),
        ],
        catalog: a2uiKitCatalog(options: A2uiKitOptions(onOpenUrl: opened.add)),
      );
      await tester.tap(find.text('Docs'));
      await tester.pump();
      // openUrl opens the URL CopilotKit opens: with no path, the path is
      // "/" (functions.ts:369-373, parseUrl off the web; WHATWG URL's
      // serializer on it).
      expect(opened, [Uri.parse('https://docs.example.com/')]);
      expect(surfaces.errors, isEmpty);
    });

    testWidgets("the binding's own context wins over the arguments", (
      tester,
    ) async {
      final surfaces = await pumpComponents(tester, [
        _root({
          'component': 'List',
          'items': ['Only'],
          'action': {
            'event': {
              'name': 'pick',
              'context': {'label': 'fixed'},
            },
          },
        }),
      ]);
      await tester.tap(find.text('Only'));
      await tester.pump();
      expect(surfaces.actions.single.context['label'], 'fixed');
      expect(surfaces.actions.single.context['index'], 0);
    });

    testWidgets('ListItem children from a template, numbered', (tester) async {
      await pumpComponents(
        tester,
        [
          _root({
            'component': 'List',
            'marker': 'number',
            'children': {'componentId': 'li', 'path': '/todos'},
          }),
          {
            'id': 'li',
            'component': 'ListItem',
            'label': {'@path': 'title'},
          },
        ],
        data: {
          'todos': [
            {'title': 'Buy milk'},
            {'title': 'Walk dog'},
          ],
        },
      );
      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.text('1. '), findsOneWidget);
      expect(find.text('2. '), findsOneWidget);
    });

    testWidgets('horizontal lists scroll and draw no markers', (tester) async {
      await pumpComponents(tester, width: 200, [
        _root({
          'component': 'List',
          'direction': 'horizontal',
          'items': ['Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo'],
        }),
      ]);
      expect(find.text('• '), findsNothing);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    // data.tsx:550, :589-591: each entry and each ListItem in a List is an
    // `<li>`. Flutter asserts that a list item's parent node is a list, so
    // these also check that the items sit right under the list's node: in
    // a horizontal list (whose scroll view has a node of its own), and for
    // a ListItem whose envelope puts a node of its own around it.
    testWidgets('items are list items of the list, in every layout', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponents(tester, width: 200, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['across', 'down'],
        },
        {
          'id': 'across',
          'component': 'List',
          'direction': 'horizontal',
          'items': ['Alpha', 'Bravo'],
        },
        {
          'id': 'down',
          'component': 'List',
          'children': ['named', 'plain', 'note'],
        },
        {
          'id': 'named',
          'component': 'ListItem',
          'label': 'Kept',
          'accessibility': {'live': 'polite'},
        },
        {'id': 'plain', 'component': 'ListItem', 'label': 'Plain'},
        // Not a ListItem: a child of the list, no list item.
        {'id': 'note', 'component': 'Text', 'text': 'Note'},
      ]);
      expect(tester.takeException(), isNull);
      final items = find.semantics
          .byPredicate((node) => node.role == SemanticsRole.listItem)
          .evaluate()
          .toList();
      expect(items, hasLength(4));
      for (final item in items) {
        expect(item.parent!.role, SemanticsRole.list);
      }
      expect(
        find.semantics.byPredicate(
          (node) => node.role == SemanticsRole.listItem && node.label == 'Note',
        ),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('a connector draws a 2px start border', (tester) async {
      await pumpComponents(tester, [
        _root({
          'component': 'List',
          'marker': 'none',
          'connector': 'solid',
          'items': ['One'],
        }),
      ]);
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text('One'), matching: find.byType(Container))
            .first,
      );
      final border =
          (container.decoration! as BoxDecoration).border! as BorderDirectional;
      expect(border.start.width, 2);
    });

    testWidgets('a value wider than the row lays out as CSS, at 320px and '
        'text scale 2', (tester) async {
      await pumpComponents(tester, width: 320, textScale: 2, [
        _root({
          'component': 'List',
          'items': [
            {
              'label': 'Order reference number',
              'value': 'ORD-2026-11-18-000123456789',
            },
            {'label': 'Total due now', 'value': r'$12'},
          ],
        }),
      ]);
      expect(tester.takeException(), isNull);
      // The value never wraps or shrinks (flex: none): one line, wider
      // than the row.
      final value = tester.getRect(find.text('ORD-2026-11-18-000123456789'));
      final label = tester.getRect(find.text('Total due now'));
      final total = tester.getRect(find.text(r'$12'));
      expect(value.height, closeTo(total.height, .5));
      expect(value.width, greaterThan(320));
      // A value that fits keeps its line; the label wraps to make room.
      expect(total.right, closeTo(320, 1));
      expect(label.right, lessThanOrEqualTo(total.left - 12 + .01));
      expect(label.height, greaterThan(total.height));
    });
  });

  group('ListItem', () {
    testWidgets('an action makes it a button; disabled ignores it', (
      tester,
    ) async {
      final surfaces = await pumpComponents(tester, [
        _root({
          'component': 'List',
          'marker': 'none',
          'children': ['a', 'b'],
        }),
        {
          'id': 'a',
          'component': 'ListItem',
          'label': 'Open',
          'value': 'hidden',
          'action': {
            'event': {'name': 'open'},
          },
        },
        {
          'id': 'b',
          'component': 'ListItem',
          'label': 'Locked',
          'disabled': true,
          'action': {
            'event': {'name': 'locked'},
          },
        },
      ]);
      expect(find.text('hidden'), findsNothing);
      await tester.tap(find.text('Open'));
      await tester.tap(find.text('Locked'));
      await tester.pump();
      expect(surfaces.actions.map((a) => a.name), ['open']);
      expect(surfaces.actions.single.context, isEmpty);
    });

    testWidgets('disabled reads as disabled, with no button, tap or focus', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponents(tester, [
        _root({
          'component': 'List',
          'marker': 'none',
          'children': ['a', 'b'],
        }),
        {
          'id': 'a',
          'component': 'ListItem',
          'label': 'Open',
          'action': {
            'event': {'name': 'open'},
          },
        },
        {
          'id': 'b',
          'component': 'ListItem',
          'label': 'Locked',
          'disabled': true,
          'action': {
            'event': {'name': 'locked'},
          },
        },
      ]);
      expect(
        tester.getSemantics(find.text('Open')),
        isSemantics(isButton: true, hasTapAction: true, isFocusable: true),
      );
      // CopilotKit: `aria-disabled` on the item, and no <button>.
      expect(
        tester.getSemantics(find.text('Locked')),
        isSemantics(
          hasEnabledState: true,
          isEnabled: false,
          isButton: false,
          hasTapAction: false,
          isFocusable: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('an enabled item without an action states no enabled state, '
        'button, tap or focus', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponents(tester, [
        _root({
          'component': 'List',
          'marker': 'none',
          'children': ['a'],
        }),
        {'id': 'a', 'component': 'ListItem', 'label': 'Plain'},
      ]);
      expect(
        tester.getSemantics(find.text('Plain')),
        isSemantics(
          hasEnabledState: false,
          isButton: false,
          hasTapAction: false,
          isFocusable: false,
        ),
      );
      handle.dispose();
    });

    // Review 2a regen Q3 (RR29): CopilotKit sets `aria-disabled` and the
    // opacity on the item's own element (data.tsx:598-603), so a child the
    // student is typing in keeps its input when `disabled` flips.
    testWidgets('a child keeps its editor, text and focus when disabled '
        'flips', (tester) async {
      final surfaces = await pumpComponents(
        tester,
        [
          _root({
            'component': 'List',
            'marker': 'none',
            'children': ['item'],
          }),
          {
            'id': 'item',
            'component': 'ListItem',
            'label': 'Quantity',
            'disabled': {'@path': '/saving'},
            'children': ['qty'],
          },
          {
            'id': 'qty',
            'component': 'TextField',
            'value': {'@path': '/qty'},
          },
        ],
        data: {'qty': '', 'saving': false},
      );
      // Half opacity is painted as an opacity layer of alpha 128.
      bool dimmed() => tester.layers.whereType<OpacityLayer>().any(
        (layer) => layer.alpha == 128,
      );
      await tester.enterText(find.byType(TextField), '3');
      await tester.pump();
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      expect(dimmed(), isFalse);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      for (final saving in [true, false]) {
        surfaces.setData('/saving', saving);
        await tester.pumpAndSettle();
        expect(dimmed(), saving);
        expect(
          tester.state<EditableTextState>(find.byType(EditableText)),
          same(editor),
        );
        expect(editor.textEditingValue.text, '3');
        expect(editor.widget.focusNode.hasFocus, isTrue);
        expect(tester.testTextInput.hasAnyClients, isTrue);
      }
      // Typing goes on through the same connection.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '34',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      expect(surfaces.surface.dataModel.get('/qty'), '34');
    });

    testWidgets('an own marker replaces the bullet', (tester) async {
      await pumpComponents(tester, [
        _root({
          'component': 'List',
          'children': ['a'],
        }),
        {'id': 'a', 'component': 'ListItem', 'label': 'Step', 'marker': '→'},
      ]);
      expect(find.text('• '), findsNothing);
      expect(find.text('→'), findsOneWidget);
    });
  });

  group('Icon', () {
    LucideIconNode reactCore(String name) =>
        lucideIcon(name, release: LucideRelease.reactCore)!;

    testWidgets('Lucide names, A2UI names; an unknown one draws nothing', (
      tester,
    ) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Row',
          'children': ['a', 'b', 'c', 'd', 'n', 'e'],
        },
        {'id': 'a', 'component': 'Icon', 'name': 'arrow-right'},
        {'id': 'b', 'component': 'Icon', 'name': 'arrowBack', 'size': 'xl'},
        {'id': 'c', 'component': 'Icon', 'name': 'triangle-alert', 'size': 12},
        {'id': 'd', 'component': 'Icon', 'name': 'no-such-icon'},
        // New in lucide-react 1.57.0: react-core's 0.525.0 has no `ad`.
        {'id': 'n', 'component': 'Icon', 'name': 'ad'},
        {
          'id': 'e',
          'component': 'Icon',
          'name': {'svgPath': 'M0 0h24v24H0z'},
          'label': 'Square',
        },
      ]);
      final glyphs = tester.widgetList<LucideGlyph>(find.byType(LucideGlyph));
      expect(glyphs.map((g) => g.icon), [
        reactCore('arrow-right'),
        reactCore('arrow-left'),
        reactCore('triangle-alert'),
      ]);
      expect(glyphs.map((g) => g.size), [20, 32, 12]);
      expect(find.bySemanticsLabel('Square'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('strokeWeight is the stroke width on the 24px grid', (
      tester,
    ) async {
      final weights = [null, 'normal', 'medium', 'semibold', 'bold'];
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Row',
          'children': [for (var i = 0; i < weights.length; i++) 'i$i'],
        },
        for (final (i, weight) in weights.indexed)
          {
            'id': 'i$i',
            'component': 'Icon',
            'name': 'minus',
            'strokeWeight': ?weight,
          },
      ]);
      final glyphs = find.byType(LucideGlyph);
      // ICON_STROKE (media.tsx:56-61); lucide-react's own 2 when unset.
      expect(tester.widgetList<LucideGlyph>(glyphs).map((g) => g.strokeWidth), [
        2,
        2,
        2.25,
        2.5,
        3,
      ]);
      // What is painted: minus is "M5 12h14" (0.525.0).
      for (final (i, width) in [2.0, 2.0, 2.25, 2.5, 3.0].indexed) {
        expect(
          glyphs.at(i),
          paints..path(strokeWidth: width, style: PaintingStyle.stroke),
        );
      }
    });

    testWidgets('color is the stroke; a filled dot keeps the text colour', (
      tester,
    ) async {
      final theme = A2uiKitTheme.playground(Brightness.light);
      await pumpComponents(tester, theme: theme, [
        _root({'component': 'Icon', 'name': 'tag', 'color': 'success'}),
      ]);
      final glyph = find.byType(LucideGlyph);
      final success = theme.color(A2uiColorToken.textSuccess);
      final text = DefaultTextStyle.of(tester.element(glyph)).style.color!;
      expect(text.toARGB32(), isNot(success.toARGB32()));
      // lucide-react's `color` prop sets the `<svg>`'s stroke; its
      // `fill="currentColor"` dot reads the CSS colour around it.
      expect(
        glyph,
        paints
          ..path(color: success, style: PaintingStyle.stroke)
          ..circle(x: 7.5, y: 7.5, color: text, style: PaintingStyle.fill)
          ..circle(x: 7.5, y: 7.5, color: success, style: PaintingStyle.stroke),
      );
    });

    Future<void> heart(WidgetTester tester, A2uiKitTheme theme) async {
      await pumpComponents(tester, theme: theme, [
        {
          'id': 'root',
          'component': 'Row',
          'children': ['i', 's'],
        },
        {'id': 'i', 'component': 'Icon', 'name': 'favorite'},
        {
          'id': 's',
          'component': 'Stat',
          'label': 'Likes',
          'value': '12',
          'icon': 'heart',
        },
      ]);
      final glyphs = find.byType(LucideGlyph);
      final playgroundHeart = lucideIcon(
        'heart',
        release: LucideRelease.playground,
      )!;
      // The Icon is react-core's renderer, so lucide-react 0.525.0 in either
      // look; the Stat is the playground's own, so 1.57.0.
      expect(tester.widgetList<LucideGlyph>(glyphs).map((g) => g.icon), [
        reactCore('heart'),
        playgroundHeart,
      ]);
      Path pathOf(LucideIconNode node) =>
          (node.elements.single as LucidePath).path;
      expect(
        glyphs.first,
        paints..something(
          (method, args) =>
              method == #drawPath &&
              identical(args.first, pathOf(reactCore('heart'))),
        ),
      );
      expect(
        glyphs.last,
        paints..something(
          (method, args) =>
              method == #drawPath &&
              identical(args.first, pathOf(playgroundHeart)),
        ),
      );
    }

    testWidgets(
      'each renderer draws its own release: the playground look',
      (tester) => heart(tester, A2uiKitTheme.playground(Brightness.light)),
    );

    testWidgets(
      'each renderer draws its own release: the standard look',
      (tester) => heart(tester, A2uiKitTheme.standard(Brightness.light)),
    );

    testWidgets('inline: 1em, its bottom 0.125em below the baseline', (
      tester,
    ) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Text',
          'text': 'Go',
          'size': 'lg',
          'children': ['i', 'p', 'n'],
        }),
        {'id': 'i', 'component': 'Icon', 'name': 'arrow-right', 'inline': true},
        {
          'id': 'p',
          'component': 'Icon',
          'name': {'svgPath': 'M0 0h24v24H0z'},
          'inline': true,
        },
        {
          'id': 'n',
          'component': 'Icon',
          'name': 'check',
          'inline': true,
          'size': 12,
        },
      ]);
      final paragraph = tester.renderObject<RenderParagraph>(
        find
            .ancestor(
              of: find.byType(LucideGlyph),
              matching: find.byType(RichText),
            )
            .first,
      );
      // The em the Icon reads: the Text's size, which its children inherit.
      final fontSize = DefaultTextStyle.of(
        tester.element(find.byType(LucideGlyph).first),
      ).style.fontSize!;
      final baseline =
          paragraph.localToGlobal(Offset.zero).dy +
          paragraph.getDryBaseline(
            paragraph.constraints,
            TextBaseline.alphabetic,
          )!;
      final glyphs = [
        find.byType(LucideGlyph).first,
        find.byType(SvgPathGlyph),
        find.byType(LucideGlyph).last,
      ];
      expect(glyphs.map((g) => tester.getRect(g).height), [
        fontSize,
        fontSize,
        12,
      ]);
      // 0.125 of the text's em, whatever the icon's size: without a baseline
      // the bottom would sit on the line, 2.25px higher, and 0.125 of the
      // 12px icon would be 1.5px. (SkParagraph places a placeholder within
      // 0.01px of the line's reported baseline.)
      for (final glyph in glyphs) {
        expect(
          tester.getRect(glyph).bottom,
          moreOrLessEquals(baseline + 0.125 * fontSize, epsilon: .01),
        );
      }
    });

    testWidgets('inline at text scale 2: the em and its eighth grow with the '
        'text, once', (tester) async {
      await pumpComponents(tester, textScale: 2, [
        _root({
          'component': 'Text',
          'text': 'Go',
          'children': ['i'],
        }),
        {'id': 'i', 'component': 'Icon', 'name': 'arrow-right', 'inline': true},
      ]);
      final glyph = find.byType(LucideGlyph);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.ancestor(of: glyph, matching: find.byType(RichText)).first,
      );
      final fontSize = DefaultTextStyle.of(
        tester.element(glyph),
      ).style.fontSize!;
      final baseline =
          paragraph.localToGlobal(Offset.zero).dy +
          paragraph.getDryBaseline(
            paragraph.constraints,
            TextBaseline.alphabetic,
          )!;
      // Scaled once (the paragraph scales its inline children; the Icon
      // inside reads no scale of its own): twice the em, not four times.
      expect(tester.getRect(glyph).height, moreOrLessEquals(2 * fontSize));
      expect(
        tester.getRect(glyph).bottom,
        moreOrLessEquals(baseline + 0.125 * 2 * fontSize, epsilon: .02),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('in a Text at text scale 2, a size in px stays its px, its '
        'eighth em below the baseline growing', (tester) async {
      // A browser's text size leaves `width="24"` alone; Flutter's line
      // scales the box holding the icon by 2, which a px icon undoes. The
      // wrong sizes this rules out: 48 (scaled with the line) and 12 (undone
      // twice). A Column inside the Text holds the last two: the line's
      // scale reaches through it.
      await pumpComponents(tester, textScale: 2, [
        _root({
          'component': 'Text',
          'text': 'Go',
          'children': ['n', 'b', 'c'],
        }),
        {
          'id': 'n',
          'component': 'Icon',
          'name': 'check',
          'inline': true,
          'size': 24,
        },
        {'id': 'b', 'component': 'Icon', 'name': 'arrow-right', 'size': 'lg'},
        {
          'id': 'c',
          'component': 'Column',
          'children': ['d'],
        },
        {
          'id': 'd',
          'component': 'Icon',
          'name': {'svgPath': 'M0 0h24v24H0z'},
          'size': 'sm',
        },
      ]);
      final inline = find.byType(LucideGlyph).first;
      final paragraph = tester.renderObject<RenderParagraph>(
        find.ancestor(of: inline, matching: find.byType(RichText)).first,
      );
      final fontSize = DefaultTextStyle.of(
        tester.element(inline),
      ).style.fontSize!;
      final baseline =
          paragraph.localToGlobal(Offset.zero).dy +
          paragraph.getDryBaseline(
            paragraph.constraints,
            TextBaseline.alphabetic,
          )!;
      expect(tester.getRect(inline).size, const Size(24, 24));
      expect(
        tester.getRect(inline).bottom,
        moreOrLessEquals(baseline + 0.125 * 2 * fontSize, epsilon: .02),
      );
      // `size: "lg"` is 24px, `sm` 16px tall, inline or not (the Column
      // stretches the svg path's box across, a matter of its own).
      expect(
        tester.getRect(find.byType(LucideGlyph).last).size,
        const Size(24, 24),
      );
      expect(tester.getRect(find.byType(SvgPathGlyph)).height, 16);
      expect(tester.takeException(), isNull);
    });
  });

  group('Image', () {
    test('reads the natural size, then disposes the image info', () async {
      final image = await createTestImage(width: 20, height: 10);
      final info = ImageInfo(image: image, scale: 2);
      expect(naturalSizeOf(info), const Size(10, 5));
      expect(image.debugDisposed, isTrue);
    });

    testWidgets('Tab reaches the overlay button and Enter presses it', (
      tester,
    ) async {
      // The picture comes from the image cache, as the test has no network.
      final picture = await tester.runAsync(
        () => createTestImage(width: 40, height: 20),
      );
      PaintingBinding.instance.imageCache.putIfAbsent(
        const NetworkImage('https://example.com/a.png'),
        () => OneFrameImageStreamCompleter(
          SynchronousFuture(ImageInfo(image: picture!)),
        ),
      );
      addTearDown(PaintingBinding.instance.imageCache.clear);
      final surfaces = await pumpComponents(tester, [
        _root({
          'component': 'Image',
          'url': 'https://example.com/a.png',
          'description': 'A photo',
          'actionOverlay': {'label': 'Open'},
          'onOverlayClick': {
            'event': {'name': 'overlay'},
          },
        }),
      ]);
      expect(find.text('Open'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(surfaces.actions.map((a) => a.name), ['overlay']);
    });

    // media.tsx:268-277: the overlay's wrapper hides its overflow only with
    // `hoverZoom`. The 31px button overflows a 40 by 20 picture: it is drawn
    // whole while the overflow shows, and clipped to the picture once
    // `hoverZoom` hides it. (A tap on its overflowing part is queued in
    // data_media_parity_test.dart.)
    for (final hoverZoom in [false, true]) {
      testWidgets('the overlay button overflowing a small picture is drawn '
          'unless hoverZoom hides the overflow ($hoverZoom)', (tester) async {
        final picture = await tester.runAsync(
          () => createTestImage(width: 40, height: 20),
        );
        PaintingBinding.instance.imageCache.putIfAbsent(
          const NetworkImage('https://example.com/a.png'),
          () => OneFrameImageStreamCompleter(
            SynchronousFuture(ImageInfo(image: picture!)),
          ),
        );
        addTearDown(PaintingBinding.instance.imageCache.clear);
        await pumpComponents(tester, [
          {
            'id': 'root',
            'component': 'Column',
            'padding': 16,
            'children': ['i'],
          },
          {
            'id': 'i',
            'component': 'Image',
            'url': 'https://example.com/a.png',
            'description': 'A photo',
            'hoverZoom': hoverZoom,
            'actionOverlay': {'label': 'Open'},
          },
        ]);
        final stack = find.ancestor(
          of: find.text('Open'),
          matching: find.byType(Stack),
        );
        final box = tester.getRect(stack.first);
        // The button's text starts above the picture's top edge.
        expect(tester.getRect(find.text('Open')).top, lessThan(box.top));
        // The wrapper clips its children to its box only with `hoverZoom`.
        final clip = paints..clipRect(rect: Offset.zero & box.size);
        expect(
          tester.renderObject(stack.first),
          hoverZoom ? clip : isNot(clip),
        );
      });
    }

    // lightbox.tsx:93-99: a modal dialog named by the description; a
    // portal, it takes the image's envelope `hidden` itself (:45-47).
    for (final hidden in [false, true]) {
      testWidgets('the lightbox is a dialog named by the description '
          '(envelope hidden: $hidden)', (tester) async {
        final handle = tester.ensureSemantics();
        final picture = await tester.runAsync(
          () => createTestImage(width: 40, height: 20),
        );
        PaintingBinding.instance.imageCache.putIfAbsent(
          const NetworkImage('https://example.com/a.png'),
          () => OneFrameImageStreamCompleter(
            SynchronousFuture(ImageInfo(image: picture!)),
          ),
        );
        addTearDown(PaintingBinding.instance.imageCache.clear);
        await pumpComponents(tester, [
          _root({
            'component': 'Image',
            'url': 'https://example.com/a.png',
            'description': 'A photo',
            'accessibility': {'hidden': hidden},
          }),
        ]);
        await tester.tap(find.byType(Image));
        await tester.pumpAndSettle();
        final dialog = find.semantics.byPredicate(
          (node) =>
              node.role == SemanticsRole.dialog &&
              node.label == 'A photo' &&
              node.flagsCollection.scopesRoute,
        );
        expect(dialog, hidden ? findsNothing : findsOne);
        // The lightbox is open either way: its close button is drawn.
        expect(find.text('×'), findsOneWidget);
        handle.dispose();
      });
    }

    test('an image info with no pixels and no element is 300×150', () {
      expect(naturalSizeOf(_NoPixels()), const Size(300, 150));
    });

    testWidgets('a failed image shows its fallback text', (tester) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Image',
          'url': 'https://example.com/missing.png',
          'description': 'A chart',
          'fallback': 'No preview',
        }),
      ]);
      // The test binding answers every request with HTTP 400.
      await tester.pumpAndSettle();
      expect(find.text('No preview'), findsOneWidget);
      expect(find.bySemanticsLabel('A chart'), findsOneWidget);
    });

    testWidgets('hideOnFailure hides it', (tester) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Image',
          'url': 'https://example.com/missing.png',
          'description': 'Gone',
          'hideOnFailure': true,
        }),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Gone'), findsNothing);
      expect(find.bySemanticsLabel('Gone'), findsNothing);
    });
  });

  group("replaced box (an image's CSS sizing)", () {
    Future<Size> sizeOf(
      WidgetTester tester,
      ReplacedSizing sizing, {
      Size? natural,
      double width = 360,
    }) async {
      await tester.pumpWidget(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: Align(
              alignment: Alignment.topLeft,
              child: ReplacedBox(sizing: sizing, naturalSize: natural),
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(ReplacedBox));
    }

    testWidgets('fixed sizes, percentages and the aspect ratio', (
      tester,
    ) async {
      // avatar: 40 by 40.
      expect(
        await sizeOf(
          tester,
          const ReplacedSizing(
            width: A2uiLength.px(40),
            height: A2uiLength.px(40),
          ),
        ),
        const Size(40, 40),
      );
      // header: the full width at 3:1.
      expect(
        await sizeOf(
          tester,
          const ReplacedSizing(width: A2uiLength.percent(1), aspectRatio: 3),
        ),
        const Size(360, 120),
      );
    });

    testWidgets('the natural size, kept within max-width with its ratio', (
      tester,
    ) async {
      const natural = Size(800, 400);
      expect(
        await sizeOf(
          tester,
          const ReplacedSizing(maxWidth: A2uiLength.percent(1)),
          natural: natural,
        ),
        const Size(360, 180),
      );
      expect(
        await sizeOf(
          tester,
          const ReplacedSizing(maxWidth: A2uiLength.px(160)),
          natural: const Size(100, 50),
        ),
        const Size(100, 50),
      );
      // A height alone takes the width from the ratio.
      expect(
        await sizeOf(
          tester,
          const ReplacedSizing(height: A2uiLength.px(100)),
          natural: natural,
        ),
        const Size(200, 100),
      );
    });
  });

  group('Link', () {
    testWidgets('opens a safe URL; shows text only for an unsafe one', (
      tester,
    ) async {
      final opened = <Uri>[];
      await pumpComponents(
        tester,
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['a', 'b', 'c'],
          },
          {
            'id': 'a',
            'component': 'Link',
            'text': 'Docs',
            'href': 'https://docs.example.com',
          },
          {
            'id': 'b',
            'component': 'Link',
            'text': 'Bad',
            'href': 'javascript:x',
          },
          {'id': 'c', 'component': 'Link', 'href': 'mailto:a@b.co', 'text': ''},
        ],
        catalog: a2uiKitCatalog(options: A2uiKitOptions(onOpenUrl: opened.add)),
      );
      await tester.tap(find.text('Docs'));
      await tester.tap(find.text('Bad'));
      await tester.pump();
      expect(opened, [Uri.parse('https://docs.example.com')]);
      // Without text, the href is the label.
      expect(find.text('mailto:a@b.co'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Docs (opens in a new tab)'),
        findsOneWidget,
      );
      final theme = A2uiKitTheme.playground(Brightness.light);
      expect(
        tester.widget<Text>(find.text('Docs')).style!.color,
        theme.color(A2uiColorToken.textInfo),
      );
    });

    testWidgets('Tab reaches a Link and an inline link; Enter opens them', (
      tester,
    ) async {
      final opened = <Uri>[];
      await pumpComponents(
        tester,
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['a', 't'],
          },
          {
            'id': 'a',
            'component': 'Link',
            'text': 'Docs',
            'href': 'https://docs.example.com',
          },
          {
            'id': 't',
            'component': 'Text',
            'text': 'See [the guide](https://guide.example.com) now',
          },
        ],
        catalog: a2uiKitCatalog(options: A2uiKitOptions(onOpenUrl: opened.add)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened, [Uri.parse('https://docs.example.com')]);
      // The focused Link shows the focus ring.
      expect(
        find.ancestor(of: find.text('Docs'), matching: find.byType(FocusRing)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FocusRing>(
              find.ancestor(
                of: find.text('Docs'),
                matching: find.byType(FocusRing),
              ),
            )
            .visible,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // The focused inline link is tinted.
      TextSpan? guide;
      tester
          .widget<RichText>(
            find.textContaining('the guide', findRichText: true),
          )
          .text
          .visitChildren((span) {
            if (span is TextSpan && span.text == 'the guide') guide = span;
            return true;
          });
      expect(guide!.style!.backgroundColor, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened.last, Uri.parse('https://guide.example.com'));
    });
  });

  group('Markdown', () {
    testWidgets('renders GFM blocks', (tester) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Markdown',
          'text':
              '## Markdown heading\n\n- item a\n- item b\n\n'
              '| a | b |\n|---|---|\n| 1 | 2 |\n\n~~gone~~ and **bold**',
        }),
      ]);
      expect(find.text('Markdown heading', findRichText: true), findsOneWidget);
      expect(find.text('item a', findRichText: true), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(r'typesets $$ math', (tester) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Markdown',
          'text':
              r'Euler: $$e^{i\pi} + 1 = 0$$'
              '\n\n'
              r'$$'
              '\n'
              r'\int_0^1 x\,dx'
              '\n'
              r'$$',
        }),
      ]);
      // Two formulas, as the Math component typesets them: the inline one
      // in KaTeX's three pieces (after "+" and "="), the display one whole.
      expect(find.byType(KitMath), findsNWidgets(2));
      expect(find.byType(Math), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens only safe links', (tester) async {
      final opened = <Uri>[];
      await pumpComponents(
        tester,
        [
          _root({
            'component': 'Markdown',
            'text': '[ok](https://a.example) [no](javascript:alert(1))',
          }),
        ],
        catalog: a2uiKitCatalog(options: A2uiKitOptions(onOpenUrl: opened.add)),
      );
      await tester.tapOnText(find.textRange.ofSubstring('ok'));
      await tester.tapOnText(find.textRange.ofSubstring('no'));
      await tester.pump();
      expect(opened, [Uri.parse('https://a.example')]);
    });

    testWidgets('streaming closes markdown that is still arriving', (
      tester,
    ) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Markdown',
          'text': 'Half **bold',
          'streaming': true,
        }),
      ]);
      expect(find.textContaining('**', findRichText: true), findsNothing);
      expect(find.textContaining('bold', findRichText: true), findsOneWidget);
    });
  });
}

/// The image info of the web's `<img>` fallback, as the VM sees it: no
/// pixels, and no element to read.
class _NoPixels implements ImageInfo {
  @override
  ui.Image get image => throw UnsupportedError('no pixels');

  @override
  double get scale => 1;

  @override
  String? get debugLabel => null;

  @override
  ImageInfo clone() => this;

  @override
  void dispose() {}

  @override
  bool isCloneOf(ImageInfo other) => identical(other, this);

  @override
  int get sizeBytes => 0;
}
