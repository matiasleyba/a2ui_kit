// Parity tests of CopilotKit's standard layout components, ported from
// packages/react-core/src/v2/generative-ui/standard/__tests__/layout.test.tsx
// (MIT, (c) Atai Barkai). Each test names its upstream file and line.
//
// ignore: lines_longer_than_80_chars (port_status.dart reads this line whole)
// Parity for: Box, Column, Row, Grid, GridItem, Card, Spacer, Divider, Label, Flow, FlowItem
//
// Upstream renders its containers around a test-only `Label` leaf (a plain
// span); here that leaf is the standard `Label` component. Upstream's
// `parentOf(view, text)` is `flexContainerOf` (test/helpers/parity.dart),
// and its `spacing(n)` (`calc(var(--spacing, 0.25rem) * n)`) is 4n px.
//
// Not ported (bound to internals):
// - layout.test.tsx:32, its last assertion: `Column.props` holds no
//   `children`, because React's manifest moves children into `slots`;
//   A2UI's JSON schema keeps them as a `ChildList` property. The names, the
//   descriptions and the slots are ported.
// - layout.test.tsx:112 `boxSizing: "border-box"`: every Flutter box holds
//   its padding and border inside its size (A2uiBoxStyle). The cards' 260px
//   width, padding and border included, is tested instead.
// - layout.test.tsx:145 `data-a2ui-row`: the stylesheet hook that marks a
//   spaceBetween Row. The Row's justify is tested instead, and the
//   right-aligned last Text the hook enables in layout_parity_test.dart
//   (layout-parity.test.tsx:102).
// - layout.test.tsx:159 the Card's `role="group"`: the Card is hidden, so
//   Flutter's semantics tree has no node of it to carry a role. The named
//   Column's group (a container node of its own) is tested.
// - layout.test.tsx:198 `data-a2ui-card-variant`, :198 and :217
//   `data-a2ui-card` ("top", "nested"): where a Card sits, which the box
//   each Card gets (border, padding, gap) shows and is tested.
// - layout.test.tsx:287 `role="separator"`: Flutter's SemanticsRole has no
//   separator, and a2ui_kit's Divider, like Material's, gives no semantics;
//   the rule's line is tested. `toBeInstanceOf(HTMLDivElement)` is a DOM
//   class.
// - layout.test.tsx:389 `Object.values(style)` holding no `undefined`: a
//   JavaScript style object's keys; a Dart prop left unset is null. The gap
//   it guards is tested.
//
// Later phase (no Dart yet):
// - layout.test.tsx:302 "makes a Carousel a focusable scroll region, named
//   by its label" (Carousel, CarouselItem).
// - layout.test.tsx:337 `it.each` case "Carousel" of "%s repeats a template
//   child for each data item".

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/layout/container_css.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// Upstream's `spacing(steps)`: `calc(var(--spacing, 0.25rem) * steps)`.
int _spacing(int steps) => 4 * steps;

/// A padding of `spacing(steps)` on every side.
EdgeInsets _padding(int steps) => EdgeInsets.all(_spacing(steps).toDouble());

/// The standard Label, upstream's test-only text leaf.
Map<String, Object?> _label(String id, String text) => {
  'id': id,
  'component': 'Label',
  'text': text,
};

/// Upstream's `style.border` containing "1px solid": a 1px solid border on
/// every side.
void _expectSolidBorder(CssFlex container) {
  expect(container.box.borderWidth, 1);
  final border = container.box.decoration?.border;
  expect(border, isA<Border>());
  if (border is! Border) return;
  for (final side in [border.top, border.right, border.bottom, border.left]) {
    expect(side.width, 1);
    expect(side.style, BorderStyle.solid);
  }
}

/// Upstream's style without `border: … solid`: no border drawn.
void _expectNoBorder(CssFlex container) {
  expect(container.box.borderWidth, 0);
  expect(container.box.decoration?.border, isNull);
}

/// The container [text] sits in directly: the nearest CSS flex box or grid
/// around it (upstream's `parentElement`).
Widget _parentOf(WidgetTester tester, String text) => tester
    .widgetList(
      find.ancestor(
        of: find.text(text, findRichText: true),
        matching: find.byWidgetPredicate((w) => w is CssFlex || w is CssGrid),
      ),
    )
    .first;

/// The grid cell around [text]: where its `grid-column` lives.
CssGridItem _gridItemOf(WidgetTester tester, String text) =>
    tester.widget<CssGridItem>(
      find
          .ancestor(
            of: find.text(text, findRichText: true),
            matching: find.byType(CssGridItem),
          )
          .first,
    );

/// The CSS grid around [text]: its template and gap.
CssGrid _gridOf(WidgetTester tester, String text) => tester.widget<CssGrid>(
  find
      .ancestor(
        of: find.text(text, findRichText: true),
        matching: find.byType(CssGrid),
      )
      .first,
);

/// The rectangle of the container around [text].
Rect _rectAround(WidgetTester tester, String text) =>
    tester.getRect(find.byWidget(flexContainerOf(tester, text)));

/// The text of each text in [container], in order: upstream's
/// `[...column.children].map((child) => child.textContent)`.
List<String> _textsIn(WidgetTester tester, CssFlex container) => [
  for (final text in tester.widgetList<RichText>(
    find.descendant(
      of: find.byWidget(container),
      matching: find.byType(RichText),
    ),
  ))
    text.text.toPlainText(),
];

/// The surface's content: the outermost container around [text]. Finders
/// scoped to it skip the app's own widgets (the route's modal barrier).
Finder _surfaceAround(WidgetTester tester, String text) =>
    find.byWidget(flexContainersAround(tester, text).last);

/// The lines Dividers draw in [surface]: a box with a border (upstream's
/// rule).
Finder _rules(Finder surface) => find.descendant(
  of: surface,
  matching: find.byWidgetPredicate(
    (w) => switch (w) {
      DecoratedBox(decoration: BoxDecoration(border: Border())) => true,
      _ => false,
    },
  ),
);

/// The scroll views inside [root] around [text] (`overflow: auto`).
Finder _scrollViewsAround(Finder root, String text) => find.descendant(
  of: root,
  matching: find.ancestor(
    of: find.text(text, findRichText: true),
    matching: find.byType(SingleChildScrollView),
  ),
);

void main() {
  group('layoutComponents', () {
    // layout.test.tsx:32
    test('is valid input for createGenerativeUI, with a description and a '
        'children slot for every container', () {
      // `ui.manifestComponents`: the catalog document the standard catalog
      // writes, as agents get it.
      final components =
          a2uiKitStandardCatalog().toJson()['components']!
              as Map<String, Object?>;
      final names = components.keys.toList();
      final layout = names.take(14).toList();
      expect(layout, [
        'Box',
        'Column',
        'Row',
        'Grid',
        'GridItem',
        'Card',
        'Flow',
        'FlowItem',
        'Carousel',
        'CarouselItem',
        'CarouselMediaItem',
        'Spacer',
        'Divider',
        'Tabs',
      ]);
      // `toEqual` on the group's keys fails on an extra member too: the
      // next group (text) starts right after Tabs.
      expect(names[14], 'Title');
      Map<String, Object?> schemaOf(String name) =>
          components[name]! as Map<String, Object?>;
      for (final name in layout) {
        expect(
          schemaOf(name)['description'],
          matches(RegExp(r'\S')),
          reason: name,
        );
      }
      // The slots of a component, as CopilotKit's manifest names them: a
      // `ChildList` prop holds many children, a `ComponentId` prop one.
      Map<String, String> slotsOf(String name) => {
        for (final MapEntry(:key, :value)
            in (schemaOf(name)['properties']! as Map<String, Object?>).entries)
          if (value case <String, Object?>{r'$ref': final String ref})
            if (ref.endsWith('/ChildList'))
              key: 'multiple'
            else if (ref.endsWith('/ComponentId'))
              key: 'single',
      };
      // slots: { children: "multiple" }.
      expect(slotsOf('Column'), {'children': 'multiple'});
      // No slots.
      expect(slotsOf('Divider'), isEmpty);
    });
  });

  group('standard layout', () {
    // layout.test.tsx:64
    testWidgets('renders Box with gap and padding in 4px steps', (
      tester,
    ) async {
      await renderStandard(tester, [
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
      final box = flexContainerOf(tester, 'Team plan');
      expect(box.flex.rowGap, _spacing(2));
      expect(box.flex.columnGap, _spacing(2));
      expect(box.box.padding, _padding(3));
      // var(--a2ui-radius-lg, 12px).
      expect(box.box.decoration?.borderRadius, BorderRadius.circular(12));
      _expectSolidBorder(box);
    });

    // layout.test.tsx:84
    testWidgets(
      'lays a Row out horizontally and gives a Grid its column count',
      (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['r', 'g'],
          },
          {
            'id': 'r',
            'component': 'Row',
            'justify': 'spaceBetween',
            'children': ['a'],
          },
          _label('a', 'A'),
          {
            'id': 'g',
            'component': 'Grid',
            'columns': 3,
            'children': ['b'],
          },
          {
            'id': 'b',
            'component': 'GridItem',
            'span': 2,
            'children': ['c'],
          },
          _label('c', 'C'),
        ]);
        final row = flexContainerOf(tester, 'A');
        expect(row.flex.direction, Axis.horizontal);
        expect(row.flex.justify, A2uiJustify.spaceBetween);
        // gridColumn: "span 2".
        expect(
          _gridItemOf(tester, 'C').placement,
          const GridPlacement(span: 2),
        );
        // gridTemplateColumns contains "repeat(auto-fit" and "/ 3)".
        expect(
          _gridOf(tester, 'C').columns,
          isA<AutoFitColumns>().having((c) => c.count, 'count', 3),
        );
      },
    );

    // layout.test.tsx:103
    testWidgets('makes a GridItem that spans every column fill the row', (
      tester,
    ) async {
      // gridColumn: "1 / -1": the whole row, whether the two columns show
      // (632px) or collapse into one (360px), with no column added.
      for (final width in <double>[360, 632]) {
        await renderStandard(tester, width: width, [
          {
            'id': 'root',
            'component': 'Grid',
            'columns': 2,
            'children': ['b'],
          },
          {
            'id': 'b',
            'component': 'GridItem',
            'span': 2,
            'children': ['c'],
          },
          _label('c', 'wide'),
        ]);
        final item = _rectAround(tester, 'wide');
        expect(item.left, 0, reason: '$width');
        expect(item.width, width, reason: '$width');
      }
    });

    // layout.test.tsx:112
    testWidgets('collapses a Grid with a column count and keeps containers '
        'inside their parent', (tester) async {
      final components = [
        {
          'id': 'root',
          'component': 'Grid',
          'columns': 2,
          'children': ['a', 'b'],
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
      // gridTemplateColumns: "repeat(auto-fit, minmax(min(100%, max(260px,
      // calc((100% - 1 * calc(var(--spacing, 0.25rem) * 4)) / 2))), 1fr))",
      // read as the tracks it gives: two side by side from 536px (2 × 260 +
      // 16), each card 260px wide with its padding and border; one track
      // below that; never more than two (at 1000px, below).
      await renderStandard(tester, width: 536, components);
      var left = _rectAround(tester, 'Left');
      var right = _rectAround(tester, 'Right');
      expect(left.left, 0);
      expect(left.width, 260);
      expect(right.left, 276);
      expect(right.width, 260);
      expect(right.top, left.top);
      // The `calc((100% - gap) / 2)` term caps the grid at two columns: at
      // 1000px, three cards make two 492px tracks ((1000 - 16) / 2) and a
      // second row. Without the term they would sit in one row of three
      // 322.67px tracks (auto-fit collapses no track with three cards). The
      // test window is made wide enough for a 1000px surface.
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1200, 600);
      addTearDown(tester.view.reset);
      await renderStandard(tester, width: 1000, [
        {
          ...components.first,
          'children': ['a', 'b', 'c'],
        },
        ...components.skip(1),
        {
          'id': 'c',
          'component': 'Card',
          'children': ['tc'],
        },
        _label('tc', 'Third'),
      ]);
      left = _rectAround(tester, 'Left');
      right = _rectAround(tester, 'Right');
      final third = _rectAround(tester, 'Third');
      expect(left.left, 0);
      expect(left.width, 492);
      expect(right.left, 508);
      expect(right.width, 492);
      expect(right.top, left.top);
      expect(third.left, 0);
      expect(third.width, 492);
      expect(third.top, left.bottom + _spacing(4));
      await renderStandard(tester, width: 535, components);
      left = _rectAround(tester, 'Left');
      right = _rectAround(tester, 'Right');
      expect(left.width, 535);
      expect(right.width, 535);
      // gap: spacing(4), between the columns (276 - 260 above) and the rows.
      expect(right.top - left.bottom, _spacing(4));
      final grid = _gridOf(tester, 'Left');
      expect(grid.columnGap, _spacing(4));
      expect(grid.rowGap, _spacing(4));
      // The card's box, then the grid's.
      for (final element in flexContainersAround(tester, 'Left').take(2)) {
        expect(element.box.minWidth, A2uiLength.zero);
        expect(element.box.maxWidth, const A2uiLength.percent(1));
      }
    });

    // layout.test.tsx:133
    testWidgets('spaces Row children 8px apart unless a gap is given', (
      tester,
    ) async {
      await renderStandard(tester, [
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
          'children': ['b'],
        },
        _label('b', 'none'),
      ]);
      final auto = flexContainerOf(tester, 'auto').flex;
      expect(auto.columnGap, _spacing(2));
      expect(auto.rowGap, _spacing(2));
      final none = flexContainerOf(tester, 'none').flex;
      expect(none.columnGap, _spacing(0));
      expect(none.rowGap, _spacing(0));
    });

    // layout.test.tsx:145
    testWidgets('centers Row children by default and keeps an explicit align', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['r1', 'r2'],
        },
        {
          'id': 'r1',
          'component': 'Row',
          'justify': 'spaceBetween',
          'children': ['k'],
        },
        _label('k', 'Price'),
        {
          'id': 'r2',
          'component': 'Row',
          'align': 'start',
          'children': ['s'],
        },
        _label('s', 'top'),
      ]);
      final row = flexContainerOf(tester, 'Price').flex;
      expect(row.align, A2uiAlign.center);
      // data-a2ui-row: "spaceBetween".
      expect(row.justify, A2uiJustify.spaceBetween);
      // align-items: flex-start.
      expect(flexContainerOf(tester, 'top').flex.align, A2uiAlign.start);
    });

    // layout.test.tsx:159
    testWidgets(
      'applies the accessibility of the envelope to a container and a Card',
      (tester) async {
        // Upstream's named Column is the root; here it sits in a root
        // Column beside a sibling, so that it is smaller than the root: a
        // label merged into a node above it then has another size (the
        // wrong result the group check below rules out).
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['o', 'after'],
          },
          {
            'id': 'o',
            'component': 'Column',
            'children': ['c'],
            'accessibility': {'label': 'Order', 'live': 'polite'},
          },
          {
            'id': 'c',
            'component': 'Card',
            'children': ['t'],
            'accessibility': {'description': 'The items', 'hidden': true},
          },
          _label('t', 'inside'),
          _label('after', 'after'),
        ]);
        final around = tester
            .widgetList<Semantics>(
              find.ancestor(
                of: find.text('inside', findRichText: true),
                matching: find.byType(Semantics),
              ),
            )
            .toList();
        // aria-description: "The items".
        final card = around.where((s) => s.properties.hint == 'The items');
        expect(card, hasLength(1));
        // aria-hidden: the Card and its content are out of the semantics
        // tree.
        expect(find.bySemanticsLabel('inside'), findsNothing);
        // aria-label "Order", aria-live "polite".
        final column = around.where((s) => s.properties.label == 'Order');
        expect(column, hasLength(1));
        expect(
          tester.getSemantics(find.byWidget(column.single)),
          isSemantics(label: 'Order', isLiveRegion: true),
        );
        // The Card sits inside the Column.
        expect(
          find.descendant(
            of: find.byWidget(column.single),
            matching: find.byWidget(card.single),
          ),
          findsOneWidget,
        );
        // role "group": a named container is a semantics node of its own,
        // labelled "Order" and of the Column's own size.
        final columnSize = tester.getSize(
          find.byWidget(flexContainersAround(tester, 'inside')[1]),
        );
        expect(
          find.semantics.byPredicate(
            (node) => node.label == 'Order' && node.rect.size == columnSize,
          ),
          findsOne,
        );
      },
    );

    // layout.test.tsx:187
    testWidgets('gives a Card its default padding, radius and border', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Card',
          'children': ['t'],
        },
        _label('t', 'inside'),
      ]);
      final card = flexContainerOf(tester, 'inside');
      expect(card.box.padding, _padding(4));
      // var(--a2ui-radius-xl, 16px).
      expect(card.box.decoration?.borderRadius, BorderRadius.circular(16));
      _expectSolidBorder(card);
    });

    // layout.test.tsx:198
    testWidgets('draws no box for a section Card, and a box for an outline '
        'Card in a Card', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['s', 'p'],
        },
        {
          'id': 's',
          'component': 'Card',
          'variant': 'section',
          'children': ['st'],
        },
        _label('st', 'Section'),
        {
          'id': 'p',
          'component': 'Card',
          'children': ['o'],
        },
        {
          'id': 'o',
          'component': 'Card',
          'variant': 'outline',
          'children': ['ot'],
        },
        _label('ot', 'Outlined'),
      ]);
      final section = flexContainerOf(tester, 'Section');
      _expectNoBorder(section);
      expect(section.box.padding, EdgeInsets.zero);
      expect(section.flex.rowGap, _spacing(4));
      expect(section.flex.columnGap, _spacing(4));
      _expectSolidBorder(flexContainerOf(tester, 'Outlined'));
    });

    // layout.test.tsx:217
    testWidgets('keeps the border of a top-level Card and removes it from a '
        'nested one', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Card',
          'children': ['inner'],
        },
        {
          'id': 'inner',
          'component': 'Card',
          'padding': 4,
          'children': ['t'],
        },
        _label('t', 'nested'),
      ]);
      final [inner, outer, ...] = flexContainersAround(tester, 'nested');
      _expectSolidBorder(outer);
      expect(outer.flex.rowGap, _spacing(4));
      expect(outer.flex.columnGap, _spacing(4));
      _expectNoBorder(inner);
      // box-shadow: none.
      expect(inner.box.decoration?.boxShadow ?? const <BoxShadow>[], isEmpty);
      expect(inner.box.padding, EdgeInsets.zero);
      expect(inner.flex.rowGap, _spacing(3));
      expect(inner.flex.columnGap, _spacing(3));
    });

    // layout.test.tsx:235
    testWidgets('turns a nested Card with a background into the inner panel', (
      tester,
    ) async {
      await renderStandard(tester, [
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
      final neutral = flexContainerOf(tester, 'neutral');
      _expectNoBorder(neutral);
      expect(neutral.box.padding, _padding(3));
      // var(--a2ui-radius-md, 8px).
      expect(neutral.box.decoration?.borderRadius, BorderRadius.circular(8));
      // rgb(252, 252, 252).
      expect(neutral.box.decoration?.color, const Color(0xfffcfcfc));
      // rgba(0, 128, 93, 0.06).
      expect(
        flexContainerOf(tester, 'tinted').box.decoration?.color,
        const Color.from(alpha: .06, red: 0, green: 128 / 255, blue: 93 / 255),
      );
    });

    // layout.test.tsx:257
    testWidgets('renders a bordered Box as the inner panel in a Card, and with '
        'a border outside of one', (tester) async {
      await renderStandard(tester, [
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
      final panel = flexContainerOf(tester, 'panel');
      _expectNoBorder(panel);
      expect(panel.box.padding, _padding(3));
      // var(--a2ui-radius-md, 8px).
      expect(panel.box.decoration?.borderRadius, BorderRadius.circular(8));
      // rgb(252, 252, 252).
      expect(panel.box.decoration?.color, const Color(0xfffcfcfc));
      _expectSolidBorder(flexContainerOf(tester, 'plain'));
    });

    // layout.test.tsx:274
    testWidgets('uses 16px between the groups in a Card and 8px in a group', (
      tester,
    ) async {
      await renderStandard(tester, [
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
      final [inner, group, ...] = flexContainersAround(tester, 'deep');
      expect(group.flex.rowGap, _spacing(4));
      expect(group.flex.columnGap, _spacing(4));
      expect(inner.flex.rowGap, _spacing(2));
      expect(inner.flex.columnGap, _spacing(2));
    });

    // layout.test.tsx:287
    testWidgets(
      'renders a Divider as a rule and hides a Spacer from screen readers',
      (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['d', 's', 't'],
          },
          {'id': 'd', 'component': 'Divider', 'color': 'strong'},
          {'id': 's', 'component': 'Spacer', 'minSize': 8},
          _label('t', 'after'),
        ]);
        expect(find.text('after', findRichText: true), findsOneWidget);
        final surface = _surfaceAround(tester, 'after');
        // border-top in var(--a2ui-color-border-strong).
        expect(
          tester.widget<DecoratedBox>(_rules(surface)).decoration,
          isA<BoxDecoration>().having(
            (d) => d.border,
            'border',
            isA<Border>().having(
              (b) => b.top.color,
              'top colour',
              standardLight.color(A2uiColorToken.borderStrong),
            ),
          ),
        );
        // aria-hidden: the Spacer is out of the semantics tree.
        final spacer = find.descendant(
          of: surface,
          matching: find.byWidgetPredicate(
            (w) => w is ExcludeSemantics && w.excluding,
          ),
        );
        expect(spacer, findsOneWidget);
        // min-height: spacing(8), in a Column with no height to grow into.
        expect(tester.getSize(spacer).height, _spacing(8));
      },
    );

    // layout.test.tsx:321
    testWidgets(
      'makes a scrollable container focusable and leaves others out of the '
      'tab order',
      (tester) async {
        // Upstream's scrolling Column holds one Label; here it holds six in
        // 40px, so that it scrolls. The wrong result this rules out: a tab
        // stop placed where the keys scroll the page around the surface
        // (Flutter scrolls the nearest Scrollable above the focus) instead
        // of the Column the student tabbed to.
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['s', 'p'],
          },
          {
            'id': 's',
            'component': 'Column',
            'scrollable': true,
            'height': '40px',
            'children': ['a', for (var i = 1; i < 6; i++) 'a$i'],
          },
          _label('a', 'scrolls'),
          for (var i = 1; i < 6; i++) _label('a$i', 'scrolls $i'),
          {
            'id': 'p',
            'component': 'Column',
            'children': ['b'],
          },
          _label('b', 'static'),
        ]);
        final root = _surfaceAround(tester, 'scrolls');
        // overflow: auto.
        final scroller = _scrollViewsAround(root, 'scrolls');
        expect(scroller, findsOneWidget);
        expect(_scrollViewsAround(root, 'static'), findsNothing);
        // tabIndex 0 on the scroller, no tabindex on the static Column: the
        // scrolling Column is the one tab stop, so every Tab of a whole
        // cycle lands on it. The focused element is inside the surface (a
        // strict descendant of the root, which holds both Columns) and not
        // around the static Column. Without a tab stop the focus stays on
        // the route's own scope, above the root; a Focus on the root or the
        // whole surface sits around "static" too.
        for (var tab = 0; tab < 4; tab++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focused = FocusManager.instance.primaryFocus?.context;
          expect(focused, isNotNull, reason: 'tab $tab');
          final element = find.byElementPredicate((e) => identical(e, focused));
          expect(
            find.descendant(of: root, matching: element),
            findsOneWidget,
            reason: 'tab $tab: inside the root',
          );
          expect(
            find.ancestor(
              of: find.text('static', findRichText: true),
              matching: element,
            ),
            findsNothing,
            reason: 'tab $tab: not around the static Column',
          );
        }
        // What the tab stop is for: its keys scroll the Column, wherever
        // the focus sits in or around its scroll view. Page Down (an arrow
        // key in a browser; Flutter maps the arrows to focus moves off the
        // web) moves the Column's lines and leaves the page as it was.
        final page = find.byType(Scrollable).first;
        final lines = find
            .ancestor(
              of: find.text('scrolls', findRichText: true),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(lines).position.pixels,
          greaterThan(0),
        );
        expect(tester.state<ScrollableState>(page).position.pixels, 0);
      },
    );

    for (final component in ['Column', 'Grid', 'Card', 'Row', 'Box', 'Flow']) {
      // layout.test.tsx:337
      testWidgets('$component repeats a template child for each data item', (
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
              'component': 'Label',
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
        expect(_parentOf(tester, 'Alpha'), same(_parentOf(tester, 'Beta')));
      });
    }

    // layout.test.tsx:358
    testWidgets('adds a template item to a Column when the list grows', (
      tester,
    ) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': {'componentId': 'row', 'path': '/items'},
          },
          {
            'id': 'row',
            'component': 'Label',
            'text': {'@path': 'name'},
          },
        ],
        data: {
          'items': [
            {'name': 'Alpha'},
          ],
        },
      );
      expect(find.text('Alpha', findRichText: true), findsOneWidget);
      await view.update([
        agentWrite('/items/1', {'name': 'Beta'}),
      ]);
      final column = flexContainerOf(tester, 'Beta');
      expect(_textsIn(tester, column), ['Alpha', 'Beta']);
    });
  });

  group('layoutStyle', () {
    // layout.test.tsx:389
    test('never has an undefined key, so it never resets the gap '
        'shorthand', () {
      final css = ContainerCss.layout(
        const ComponentProps({'gap': 4}),
        theme: standardLight,
        fontSize: 16,
      );
      // "rowGap" in style: false.
      expect(css.rowGap, isNull);
      // spacing(4).
      expect(css.gap, const A2uiLength.px(16));
      // The shorthand reaches both gaps.
      final flex = css.toFlex();
      expect(flex.rowGap, _spacing(4));
      expect(flex.columnGap, _spacing(4));
    });
  });
}
