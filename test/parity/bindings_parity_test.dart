// Parity tests of the standard catalog's data-model bindings on literal
// props, ported from packages/react-core/src/v2/generative-ui/standard/
// __tests__/bindings-parity.test.tsx (MIT, (c) Atai Barkai), itself ported
// from the a2ui-renderer standard catalog. Each test names its upstream
// line.
//
// Parity for: Chart, Select, RadioGroup, List, TextField, Column, Table
// Signals for: SegmentedControl, DateTimeInput
//
// Upstream renders `standardUI`, as `renderStandard` does, and mocks
// recharts away so that the Chart shows its data-table fallback. The
// Flutter Chart has no fallback and always draws; the bound values are
// read from its data table in the semantics tree (`tableCells`: a cell
// whose text is the value, inside the table node, with the table roles
// RULEBOOK section 0 gives it). `reportError` not called is `errors`
// empty, read after a pump.
// A test that mixes built and later-phase components ports its built part
// and keeps the later-phase components in its surface, where they draw
// nothing yet (RULEBOOK section 6, item 2).
//
// Not ported (bound to internals):
// - :166 the native `<select>`'s option values (in :131): the Select is a
//   Material menu (a documented difference). An option's value is read as
//   what choosing its menu item writes to the bound path.
// - :172 `input[type="radio"]` (in :131): read as the radios of the
//   semantics tree (in a mutually exclusive group) under the RadioGroup's
//   radio-group node; a SegmentedControl's `role="radio"` buttons are no
//   `input[type="radio"]`.
// - :207 `getByPlaceholderText` (in :175): read as the field's hint text.
// - :100 `querySelectorAll("tbody tr")` (in :79): read as the table's row
//   nodes after its header row.
//
// Later phase (no Dart yet):
// - Slider: :23 (min, max, step, label, unit and marks bound), :57 (its
//   defaults when the bound paths are missing).
// - FollowUp and ImageGrid: :215 (items and images bound).
// - SegmentedControl, the third control of :131; DateTimeInput and its
//   bound `min` and `max` (:208-:212), the third control of :175.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// The value of each option of the one Select on screen, in order:
/// upstream's `Array.from(select.options).map((o) => o.value)`. The Select
/// is a menu, so an option's value is what choosing its menu item writes at
/// [path] of [view]'s data model.
Future<List<Object?>> _selectOptionValues(
  WidgetTester tester,
  ParitySurface view,
  String path,
) async {
  final items = find.byType(MenuItemButton);
  Future<void> open() async {
    await tester.tap(find.byType(MenuAnchor));
    await tester.pumpAndSettle();
  }

  await open();
  final values = List<Object?>.filled(items.evaluate().length, null);
  // From the last option up. Choosing the option already chosen writes
  // nothing, and the value at the path is then still that option's.
  for (var i = values.length - 1; i >= 0; i--) {
    if (items.evaluate().isEmpty) await open();
    await tester.tap(items.at(i));
    await tester.pumpAndSettle();
    values[i] = view.dataAt(path);
  }
  return values;
}

void main() {
  group('standard catalog: data-model bindings on literal props (parity)', () {
    // bindings-parity.test.tsx:79
    testWidgets('Table rows and columns resolve from data paths', (
      tester,
    ) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Table',
            'columns': {'@path': '/cols'},
            'rows': {'@path': '/rows'},
          },
        ],
        data: {
          'cols': [
            'Plan',
            {'label': 'Price', 'align': 'end'},
          ],
          'rows': [
            ['Team', r'$29'],
            ['Enterprise', r'$99'],
          ],
        },
      );
      expect(find.text('Enterprise'), findsOneWidget);
      await tester.pump();
      expect(view.errors, isEmpty);
      expect(find.text('Price'), findsOneWidget);
      // `tbody tr`: two body rows, after the header row.
      final rows = tableRows(tester);
      expect(rows, hasLength(3));
      expect(rows.skip(1), [
        tableRow(['Team', r'$29']),
        tableRow(['Enterprise', r'$99']),
      ]);
    });

    // bindings-parity.test.tsx:103
    testWidgets('Chart data and series resolve from data paths', (
      tester,
    ) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Chart',
            'chartType': 'bar',
            'data': {'@path': '/sales'},
            'xKey': 'month',
            'series': {'@path': '/series'},
            'title': 'Sales',
          },
        ],
        data: {
          'sales': [
            {'month': 'Jan', 'revenue': 10},
            {'month': 'Feb', 'revenue': 20},
          ],
          'series': [
            {'key': 'revenue', 'label': 'Revenue'},
          ],
        },
      );
      expect(find.text('Sales'), findsOneWidget);
      expect(view.errors, isEmpty);
    });

    // bindings-parity.test.tsx:103, :126-128: "Revenue", "Feb" and "20" in
    // the Chart's data table.
    testWidgets(
      'Chart data and series resolve from data paths: the cells of its '
      'table',
      (tester) async {
        await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'Chart',
              'chartType': 'bar',
              'data': {'@path': '/sales'},
              'xKey': 'month',
              'series': {'@path': '/series'},
              'title': 'Sales',
            },
          ],
          data: {
            'sales': [
              {'month': 'Jan', 'revenue': 10},
              {'month': 'Feb', 'revenue': 20},
            ],
            'series': [
              {'key': 'revenue', 'label': 'Revenue'},
            ],
          },
        );
        // `findAllByText("Revenue")`, `getAllByText("Feb")` and
        // `getAllByText("20")`, each at least once: a cell (the series
        // label a column header) whose text is the value, in the table.
        expect(tableCells('Revenue'), findsAny);
        expect(tableCells('Feb'), findsAny);
        expect(tableCells('20'), findsAny);
      },
    );

    // bindings-parity.test.tsx:131
    testWidgets('Select, RadioGroup and SegmentedControl options resolve '
        'from data paths: the Select and the RadioGroup', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['s', 'r', 'g'],
          },
          {
            'id': 's',
            'component': 'Select',
            'value': {'@path': '/plan'},
            'options': {'@path': '/plans'},
            'label': {'@path': '/copy/plan'},
          },
          {
            'id': 'r',
            'component': 'RadioGroup',
            'value': {'@path': '/plan'},
            'options': {'@path': '/plans'},
          },
          // Later phase: the SegmentedControl draws nothing yet.
          {
            'id': 'g',
            'component': 'SegmentedControl',
            'value': {'@path': '/plan'},
            'options': {'@path': '/plans'},
          },
        ],
        data: {
          'plan': 'team',
          'plans': [
            {'value': 'team', 'label': 'Team'},
            {'value': 'enterprise', 'label': 'Enterprise'},
          ],
          'copy': {'plan': 'Choose a plan'},
        },
      );
      expect(find.text('Choose a plan'), findsOneWidget);
      expect(view.errors, isEmpty);
      // The <select>'s option values, the empty ones left out.
      final values = await _selectOptionValues(tester, view, '/plan');
      expect(
        [
          for (final value in values)
            if (value != null && value != '') value,
        ],
        ['team', 'enterprise'],
      );
      // Two radio inputs: the RadioGroup's.
      final radios = find.semantics.byPredicate(
        (node) => node.flagsCollection.isInMutuallyExclusiveGroup,
      );
      expect(
        find.semantics.descendant(
          of: find.semantics.byPredicate(
            (node) => node.role == SemanticsRole.radioGroup,
          ),
          matching: radios,
        ),
        findsNWidgets(2),
      );
      // Later phase: the SegmentedControl draws nothing yet, so these are
      // all the radios. When this fails, it is built: port its part.
      expect(radios, findsNWidgets(2));
    });

    // bindings-parity.test.tsx:175
    testWidgets('List items, text-field labels and DateTimeInput bounds '
        'resolve from data paths: the List and the TextField', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['l', 'f', 'd'],
          },
          {
            'id': 'l',
            'component': 'List',
            'items': {'@path': '/todos'},
          },
          {
            'id': 'f',
            'component': 'TextField',
            'value': {'@path': '/name'},
            'label': {'@path': '/copy/name'},
            'placeholder': {'@path': '/copy/hint'},
          },
          // Later phase: the DateTimeInput draws nothing yet.
          {
            'id': 'd',
            'component': 'DateTimeInput',
            'value': {'@path': '/when'},
            'min': {'@path': '/range/from'},
            'max': {'@path': '/range/to'},
          },
        ],
        data: {
          'todos': [
            'Write tests',
            {'label': 'Ship it'},
          ],
          'name': '',
          'copy': {'name': 'Name', 'hint': 'Your name'},
          'when': '2026-01-05',
          'range': {'from': '2026-01-01', 'to': '2026-01-31'},
        },
      );
      expect(find.text('Ship it'), findsOneWidget);
      expect(view.errors, isEmpty);
      expect(find.text('Write tests'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      // getByPlaceholderText("Your name"): the field's hint.
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration?.hintText,
        'Your name',
      );
      // Later phase: the DateTimeInput draws nothing yet, so the TextField
      // is the one input and no node reads its dates. When this fails, it
      // is built: port its bound `min` and `max` (:208-:212).
      expect(find.byType(EditableText), findsOneWidget);
      expect(
        find.semantics.byPredicate(
          (node) => '${node.label} ${node.value}'.contains('2026'),
        ),
        findsNothing,
      );
    });
  });
}
