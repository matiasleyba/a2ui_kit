// Parity tests of CopilotKit's standard data components, ported from
// packages/react-core/src/v2/generative-ui/standard/__tests__/data.test.tsx
// (MIT, (c) Atai Barkai). Each test names its upstream line.
//
// Parity for: List, ListItem, Chart, Table, TableSection, TableRow, TableCell
//
// Upstream renders the data components alone (`dataComponents`) with a
// test-only `Label` leaf; these tests render the standard catalog
// (`renderStandard`). The `Label` leaf maps to the standard `Text`; only the
// Table tests use it. Upstream's Label is an inline `<span>`, the Text a
// block, so a header's label and a Text after it are two lines here: the
// cell's node reads them with a newline between (`"Pick\n(1)"` for
// upstream's `textContent` "Pick(1)").
//
// A Table is read from the semantics tree, as the Chart's data table is:
// `getByRole("table", { name })` is the node with the table role and that
// label, upstream's `rowTexts` its row nodes and their cells' labels
// (`tableRows`, test/helpers/parity.dart), `getAllByRole("columnheader")`
// its column-header nodes. A row header (`th scope="row"`,
// `getByRole("rowheader")`) is read as a cell: Flutter's `SemanticsRole`
// has no row header (INV-150).
//
// The DOM queries are read as follows. `role=list` is the semantics node of
// role list. `getAllByRole("listitem")` is the nodes of the list-item role,
// and an item's `textContent` the texts of
// its item body in order (its marker is no part of it, as in CSS).
// `role=button` with a name is a semantics button with that label, clicked
// by its text. The Chart's data table is read from the semantics tree:
// `findByRole("table")` and the rows upstream's `rowTexts` reads are the
// node with the table role, its row nodes and their cells, the header
// row's cells column headers (`tableRows`, test/helpers/parity.dart), the
// table roles RULEBOOK section 0 gives the Chart's data table (INV-034,
// port/inventory.tsv). The manifest test (:49) reads the catalog document:
// the standard catalog's names in order, and each component's description,
// slots (its
// `ChildList` and `ComponentId` props, as CopilotKit's `exportA2UICatalog`
// writes slots) and events (its `Action` props).
//
// Not ported (bound to internals):
// - :360 `useStableValue` "keeps the previous object while the content is
//   equal": a React hook that keeps recharts from drawing again when an
//   equal chart is sent again. The Flutter Chart keeps no state keyed by
//   the data's identity (and has no grow-in), so nothing can be observed.
// - :251 `list.tagName` "OL" (in :240): the tag of a numbered list. Its
//   behaviour, a number before each item, is tested in :240 by the markers
//   "1. " and "2. ".
// - :332 `.recharts-responsive-container` (in :315): recharts' class name,
//   tested as the Chart's painted scene.
//
// - :98 `headers[0].getAttribute("scope")` "col" (in :78): what it means,
//   a header of its column, is the column-header role, tested.
// - :122 `cell.parentElement?.tagName` "TR" and :124 no
//   `[data-a2ui-accessibility]` element (in :107): tested as the cell's
//   node being a child of its row's node, with no node between.
// - :151 `table > tbody > tr` (in :128), each row in a row group of its
//   own: the row groups are DOM elements; the two rows are tested.
// - :167 `city.closest("thead")` (in :156): tested as City's row coming
//   first, a row of column headers.
// - :235 `getAttribute("colspan")` "2" (in :224): tested as the empty
//   label's cell spanning both columns, the table's width.
//
// :335's `role=figure` named by its `figcaption` "Cost" (in :315) is a
// node labelled "Cost" that holds the table node (INV-034's figure group),
// in the test with the table below (:394).
//
// Later phase (no Dart yet):
// - Map: :375 (the list of places without maplibre-gl; a pick writes the
//   bound path).
// - The map style filter guard, Map's helpers `guardNumericFilter` and
//   `guardStyleFilters`: :410, :423, :432.

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/data/chart.dart';
import 'package:a2ui_kit/src/components/standard/data/list.dart';
import 'package:a2ui_kit/src/document/catalog_document.g.dart';
import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:a2ui_kit/src/foundation/layout/html_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// The schema of the component [name] in the catalog document.
Map<String, Object?> _schemaOf(String name) {
  final components =
      a2uiKitCatalogDocument['components']! as Map<String, Object?>;
  return components[name]! as Map<String, Object?>;
}

/// The prop schemas of the component [name].
Map<String, Object?> _propertiesOf(String name) =>
    _schemaOf(name)['properties']! as Map<String, Object?>;

/// The `$ref` of a prop [schema], or null.
String? _refOf(Object? schema) => switch (schema) {
  <String, Object?>{r'$ref': final String ref} => ref,
  _ => null,
};

/// The slot kind of a prop [schema], as CopilotKit's manifest names it: a
/// `ChildList` holds many children, a `ComponentId` one.
String? _slotKind(Object? schema) => switch (_refOf(schema)) {
  final String ref when ref.endsWith('/ChildList') => 'multiple',
  final String ref when ref.endsWith('/ComponentId') => 'single',
  _ => null,
};

/// The slots of the component [name]: upstream's
/// `manifestComponents[name].slots`.
Map<String, String> _slotsOf(String name) => {
  for (final MapEntry(:key, :value) in _propertiesOf(name).entries)
    key: ?_slotKind(value),
};

/// The events of the component [name], its `Action` props: upstream's
/// `Object.keys(manifestComponents[name].events)`.
List<String> _eventsOf(String name) => [
  for (final MapEntry(:key, :value) in _propertiesOf(name).entries)
    if (_refOf(value)?.endsWith('/Action') ?? false) key,
];

/// Each list item's text, in order: upstream's
/// `getAllByRole("listitem").map((item) => item.textContent)`.
List<String> _itemTexts(WidgetTester tester) {
  final items = find.byType(ListItemBody);
  return [
    for (var i = 0; i < items.evaluate().length; i++)
      [
        for (final text in tester.widgetList<RichText>(
          find.descendant(of: items.at(i), matching: find.byType(RichText)),
        ))
          text.text.toPlainText(),
      ].join(),
  ];
}

/// The label of each node with the list-item role, in order: what
/// upstream's `getAllByRole("listitem")` finds.
List<String> _listItemLabels(WidgetTester tester) => [
  for (final node
      in find.semantics
          .byPredicate((node) => node.role == SemanticsRole.listItem)
          .evaluate())
    node.label,
];

/// The button named [name]: upstream's `findByRole("button", { name })`.
/// Gives the finder of its text, to click it.
Finder _button(WidgetTester tester, String name) {
  final node = semanticsOfText(tester, name);
  expect(node.flagsCollection.isButton, isTrue, reason: '"$name" is a button');
  expect(node.label, name);
  return find.text(name);
}

/// Every button on screen: upstream's `queryAllByRole("button")`.
SemanticsFinder _buttons() =>
    find.semantics.byPredicate((node) => node.flagsCollection.isButton);

/// The scenes the charts painted, in order.
List<PlotScene> _scenes(WidgetTester tester) => [
  for (final paint in tester.widgetList<CustomPaint>(find.byType(CustomPaint)))
    if (paint.painter case final ChartScenePainter painter) painter.scene,
];

void main() {
  group('dataComponents', () {
    // data.test.tsx:49
    test('is valid input for createGenerativeUI, with a description for '
        'every component', () {
      // The standard catalog with the data components builds.
      expect(a2uiKitStandardCatalog, returnsNormally);
      // The standard catalog lists its groups in CopilotKit's order; the
      // data group runs from Table to Map.
      final names = standardComponentNames.sublist(
        standardComponentNames.indexOf('Table'),
        standardComponentNames.indexOf('Map') + 1,
      );
      expect(names, [
        'Table',
        'TableSection',
        'TableRow',
        'TableCell',
        'List',
        'ListItem',
        'Chart',
        'Map',
      ]);
      // `toEqual` on the group's keys fails on an extra member too: the
      // next group (media) starts right after Map.
      expect(
        standardComponentNames[standardComponentNames.indexOf('Map') + 1],
        'Image',
      );
      for (final name in names) {
        expect(
          _schemaOf(name)['description'],
          matches(RegExp(r'\S')),
          reason: name,
        );
      }
      expect(_slotsOf('Table'), {
        'children': 'multiple',
        'cellComponents': 'multiple',
      });
      expect(_eventsOf('List'), ['action']);
      expect(_eventsOf('ListItem'), ['action']);
    });
  });

  group('Table', () {
    // data.test.tsx:78
    testWidgets('renders columns as column headers and rows as cells', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'caption': 'Plans',
          'columns': [
            'Feature',
            {'label': 'Team', 'align': 'end'},
          ],
          'rows': [
            ['Price', r'$29/seat'],
            ['Seats', 10],
          ],
        },
      ]);
      expect(find.text(r'$29/seat'), findsOneWidget);
      // getByRole("table", { name: "Plans" }).
      expect(
        find.semantics.byPredicate(
          (node) => node.role == SemanticsRole.table && node.label == 'Plans',
        ),
        findsOne,
      );
      // getAllByRole("columnheader"): their text.
      expect(
        [
          for (final node
              in find.semantics
                  .byPredicate(
                    (node) => node.role == SemanticsRole.columnHeader,
                  )
                  .evaluate())
            node.label,
        ],
        ['Feature', 'Team'],
      );
      expect(
        tableRows(tester),
        tableOf(
          ['Feature', 'Team'],
          [
            ['Price', r'$29/seat'],
            ['Seats', '10'],
          ],
        ),
      );
      // `style.textAlign` "end": the drawn "10" ends at the table's end,
      // the last cell having no end padding.
      final ten = tester.renderObject<RenderParagraph>(find.text('10'));
      expect(ten.textAlign, TextAlign.end);
      final boxes = ten.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 2),
      );
      expect(
        ten.localToGlobal(Offset(boxes.last.right, 0)).dx,
        closeTo(360, 0.5),
      );
    });

    // data.test.tsx:107
    testWidgets('applies the envelope of a TableCell to the cell itself, '
        'with no element in between', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['r'],
        },
        {
          'id': 'r',
          'component': 'TableRow',
          'children': ['c'],
        },
        {
          'id': 'c',
          'component': 'TableCell',
          'children': ['t'],
          'accessibility': {'label': 'Total', 'description': 'Incl. VAT'},
        },
        {'id': 't', 'component': 'Text', 'text': '42'},
      ]);
      expect(find.text('42', findRichText: true), findsOneWidget);
      final cells = find.semantics
          .byPredicate((node) => node.role == SemanticsRole.cell)
          .evaluate()
          .toList();
      expect(cells, hasLength(1));
      final cell = cells.single;
      // aria-label and aria-description on the cell.
      expect(cell.label, 'Total');
      expect(cell.hint, 'Incl. VAT');
      // The cell's parent is its row, and the row's the table: no node in
      // between (no wrapper element).
      expect(cell.parent?.role, SemanticsRole.row);
      expect(cell.parent?.parent?.role, SemanticsRole.table);
    });

    // data.test.tsx:128
    testWidgets('repeats a TableRow template for each item at /rows', (
      tester,
    ) async {
      await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Table',
            'children': {'componentId': 'row', 'path': '/rows'},
          },
          {
            'id': 'row',
            'component': 'TableRow',
            'children': ['name', 'price'],
          },
          {
            'id': 'name',
            'component': 'TableCell',
            'text': {'@path': 'name'},
          },
          {
            'id': 'price',
            'component': 'TableCell',
            'text': {'@path': 'price'},
          },
        ],
        data: {
          'rows': [
            {'name': 'Alpha', 'price': 10},
            {'name': 'Beta', 'price': 20},
          ],
        },
      );
      expect(find.text('Beta'), findsOneWidget);
      expect(tableRows(tester), [
        tableRow(['Alpha', '10']),
        tableRow(['Beta', '20']),
      ]);
    });

    // data.test.tsx:156
    testWidgets('renders a header TableSection with column header cells', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['head', 'body'],
        },
        {
          'id': 'head',
          'component': 'TableSection',
          'header': true,
          'children': ['h'],
        },
        {
          'id': 'h',
          'component': 'TableRow',
          'children': ['hc'],
        },
        {'id': 'hc', 'component': 'TableCell', 'text': 'City'},
        {
          'id': 'body',
          'component': 'TableSection',
          'children': ['r'],
        },
        {
          'id': 'r',
          'component': 'TableRow',
          'children': ['c'],
        },
        {'id': 'c', 'component': 'TableCell', 'header': true, 'text': 'Vienna'},
      ]);
      // findByRole("columnheader", { name: "City" }) in the header row, the
      // first; getByRole("rowheader", { name: "Vienna" }): a cell.
      expect(tableRows(tester), [
        [(SemanticsRole.columnHeader, 'City')],
        [(SemanticsRole.cell, 'Vienna')],
      ]);
    });

    // data.test.tsx:171
    testWidgets('shows the component of a { componentId } cell and column '
        'from cellComponents', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'columns': [
            'Laptop',
            {'label': 'Pick', 'componentId': 'hint'},
          ],
          'rows': [
            [
              'Air 13',
              {'componentId': 'best'},
            ],
            [
              'Pro 14',
              {'id': 'best'},
            ],
          ],
          'cellComponents': ['best', 'hint'],
        },
        {'id': 'best', 'component': 'Text', 'text': 'Best value'},
        {'id': 'hint', 'component': 'Text', 'text': '(1)'},
      ]);
      expect(find.text('Best value', findRichText: true), findsNWidgets(2));
      expect(
        tableRows(tester),
        tableOf(
          ['Laptop', 'Pick\n(1)'],
          [
            ['Air 13', 'Best value'],
            ['Pro 14', 'Best value'],
          ],
        ),
      );
      // `textContent` without "componentId": no text shows the cell's JSON.
      expect(
        richTexts(tester).where((text) => text.contains('componentId')),
        isEmpty,
      );
    });

    // data.test.tsx:195
    testWidgets('reads rows bound to a data path, with component cells', (
      tester,
    ) async {
      await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Table',
            'columns': {'@path': '/columns'},
            'rows': {'@path': '/rows'},
            'cellComponents': ['top'],
          },
          {'id': 'top', 'component': 'Text', 'text': 'Top pick'},
        ],
        data: {
          'columns': ['Laptop', 'Tag'],
          'rows': [
            [
              'Air 13',
              {'componentId': 'top'},
            ],
            ['Pro 14', null],
          ],
        },
      );
      expect(find.text('Top pick', findRichText: true), findsOneWidget);
      expect(
        tableRows(tester),
        tableOf(
          ['Laptop', 'Tag'],
          [
            ['Air 13', 'Top pick'],
            ['Pro 14', ''],
          ],
        ),
      );
    });

    // data.test.tsx:224
    testWidgets('shows the empty label when there are no rows', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'columns': ['A', 'B'],
          'rows': <Object?>[],
          'emptyLabel': 'Nothing yet',
        },
      ]);
      expect(find.text('Nothing yet'), findsOneWidget);
      // colspan="2": its cell spans both columns, the 360px table.
      final cell = find
          .ancestor(
            of: find.text('Nothing yet'),
            matching: find.byType(HtmlTableCell),
          )
          .first;
      expect(tester.getRect(cell).left, 0);
      expect(tester.getRect(cell).width, 360);
    });
  });

  group('List', () {
    // data.test.tsx:240
    testWidgets('renders items as a numbered list', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'List',
          'marker': 'number',
          'items': [
            'one',
            {'label': 'two', 'description': 'second'},
          ],
        },
      ]);
      expect(find.text('second'), findsOneWidget);
      expect(
        find.semantics.byPredicate((node) => node.role == SemanticsRole.list),
        findsOne,
      );
      // An <ol>: a number before each item.
      expect(find.text('1. '), findsOneWidget);
      expect(find.text('2. '), findsOneWidget);
      expect(_itemTexts(tester), ['one', 'twosecond']);
      // Without an action, items are not buttons.
      expect(_buttons(), findsNothing);
    });

    // data.test.tsx:240, :253 `getAllByRole("listitem")`: by their role.
    testWidgets('renders items as a numbered list: two list items', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'List',
          'marker': 'number',
          'items': [
            'one',
            {'label': 'two', 'description': 'second'},
          ],
        },
      ]);
      // `["one", "twosecond"]`: an item's `textContent`; a Flutter node
      // that merges its texts joins them with a newline.
      expect(_listItemLabels(tester), ['one', 'two\nsecond']);
    });

    // data.test.tsx:259, :275 `getAllByRole("listitem")`: by their role.
    testWidgets(
      'repeats a ListItem template for each item at /todos: two list items',
      (tester) async {
        await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'List',
              'marker': 'none',
              'children': {'componentId': 'item', 'path': '/todos'},
            },
            {
              'id': 'item',
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
        expect(_listItemLabels(tester), ['Buy milk', 'Walk dog']);
      },
    );

    // data.test.tsx:259
    testWidgets('repeats a ListItem template for each item at /todos', (
      tester,
    ) async {
      await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'List',
            'marker': 'none',
            'children': {'componentId': 'item', 'path': '/todos'},
          },
          {
            'id': 'item',
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
      expect(find.text('Walk dog'), findsOneWidget);
      expect(_itemTexts(tester), ['Buy milk', 'Walk dog']);
    });

    // data.test.tsx:279
    testWidgets('sends the List action with the index, label and value of '
        'the picked item', (tester) async {
      final view = await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'List',
          'items': [
            'Vienna',
            {'label': 'Graz', 'value': 'graz'},
          ],
          'action': {
            'event': {
              'name': 'pick',
              'context': {'source': 'list'},
            },
          },
        },
      ]);
      await tester.tap(_button(tester, 'Graz'));
      await tester.pump();
      expect(view.actions, hasLength(1));
      final action = view.actions.single;
      expect(action.name, 'pick');
      expect(action.context['index'], 1);
      expect(action.context['label'], 'Graz');
      expect(action.context['value'], 'graz');
      expect(action.context['source'], 'list');
    });

    // data.test.tsx:296
    testWidgets('sends the ListItem action when the user picks the item', (
      tester,
    ) async {
      final view = await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'List',
          'children': ['a'],
        },
        {
          'id': 'a',
          'component': 'ListItem',
          'label': 'Open details',
          'action': {
            'event': {
              'name': 'open',
              'context': {'id': '7'},
            },
          },
        },
      ]);
      await tester.tap(_button(tester, 'Open details'));
      await tester.pump();
      expect(view.actions.first.name, 'open');
      expect(view.actions.first.context['id'], '7');
    });
  });

  group('Chart', () {
    // data.test.tsx:315
    testWidgets('draws the chart and gives the series data as a table', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Chart',
          'title': 'Cost',
          'xKey': 'month',
          'format': 'currency',
          'data': [
            {'month': 'Jan', 'cost': 290},
            {'month': 'Feb', 'cost': 580},
          ],
          'series': [
            {'key': 'cost', 'label': 'Monthly cost'},
          ],
        },
      ]);
      // recharts' drawing: the scene the Chart painted.
      expect(_scenes(tester).whereType<RechartsScene>(), isNotEmpty);
      // The figure's caption, drawn. The figure and the table: the next
      // test.
      expect(find.text('Cost'), findsOneWidget);
    });

    // data.test.tsx:315, :335-341: the figure named "Cost", and `rowTexts`,
    // in the tree.
    testWidgets(
      'draws the chart and gives the series data as a table: a table with '
      'a header row',
      (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Chart',
            'title': 'Cost',
            'xKey': 'month',
            'format': 'currency',
            'data': [
              {'month': 'Jan', 'cost': 290},
              {'month': 'Feb', 'cost': 580},
            ],
            'series': [
              {'key': 'cost', 'label': 'Monthly cost'},
            ],
          },
        ]);
        expect(
          tableRows(tester),
          tableOf(
            ['month', 'Monthly cost'],
            [
              ['Jan', r'$290'],
              ['Feb', r'$580'],
            ],
          ),
        );
        // `getByRole("figure")` and its `figcaption` "Cost": a node
        // labelled "Cost" that holds the table node.
        final table = find.semantics.byPredicate(
          (node) => node.role == SemanticsRole.table,
        );
        expect(
          find.semantics.ancestor(
            of: table,
            matching: find.semantics.byPredicate(
              (node) => node.label == 'Cost',
            ),
          ),
          findsOne,
        );
      },
    );

    // data.test.tsx:344, :354-355: `findByRole("table")` and `rowTexts`.
    testWidgets(
      'charts every number field except xKey when series is not set: a '
      'table with a header row',
      (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Chart',
            'chartType': 'line',
            'xKey': 'day',
            'data': [
              {'day': 'Mon', 'food': 3, 'rent': 10, 'note': 'x'},
            ],
          },
        ]);
        expect(
          tableRows(tester),
          tableOf(
            ['day', 'food', 'rent'],
            [
              ['Mon', '3', '10'],
            ],
          ),
        );
      },
    );
  });
}
