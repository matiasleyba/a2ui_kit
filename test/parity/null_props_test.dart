// Parity tests of props set to null, ported from
// packages/react-core/src/v2/generative-ui/__tests__/null-props.test.tsx
// (MIT, (c) Atai Barkai). Each test names its upstream line.
//
// Parity for: Select, Text, Column, Button, (engine)
//
// Upstream renders test-made leaves (Note, Pick, Coupon) through
// `renderSurface`; agents send `null` for an optional field, and the
// student must still see the component. Here the leaves map to standard
// components of the standard catalog (`renderStandard`): Note's optional
// `text` to a Text's optional `color` (the Text drawn in its default
// colour is Note's "unset", on the surface and inside a primary Button,
// whose text inherits the Button's on-accent), Pick's writable optional
// `selected` to a
// Select's `value` (no option chosen is Pick's "none"). `reportError` not
// called is `view.errors` empty after a pump; upstream's alert "invalid
// props" is a node with the alert role.
//
// Not ported (no subject here):
// - null-props.test.tsx:58 "keeps null for a prop whose schema accepts
//   it": no prop of the catalog document is nullable (no `"type": "null"`
//   in it).
// - :75 "drops only the top-level nulls that the schema rejected": a test
//   of CopilotKit's helper `withoutRejectedNulls`, whose counterpart here
//   is private to `A2uiOperationValidator`; :40 tests its outcome.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

void main() {
  group('props set to null', () {
    // null-props.test.tsx:40
    testWidgets('reads a literal null on an optional prop as an unset prop', (
      tester,
    ) async {
      // Note's "unset": the Text drawn as one without `color` is, beside
      // it. The colour each paints (its text's style after what it
      // inherits) is compared. The wrong fix this rules out: reading
      // `color: null` as an explicit default colour (`textDefault`). On
      // the surface that paints what "Ho" inherits, so the pair inside a
      // primary Button tells them apart: the Button hands its on-accent
      // down (button.dart's `DefaultTextStyle.merge`), which "Out"
      // paints and an explicit default would not.
      final view = await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['n', 'u', 'bn', 'bu'],
        },
        {'id': 'n', 'component': 'Text', 'text': 'Hi', 'color': null},
        {'id': 'u', 'component': 'Text', 'text': 'Ho'},
        {
          'id': 'bn',
          'component': 'Button',
          'variant': 'primary',
          'child': 'tn',
        },
        {'id': 'tn', 'component': 'Text', 'text': 'In', 'color': null},
        {
          'id': 'bu',
          'component': 'Button',
          'variant': 'primary',
          'child': 'tu',
        },
        {'id': 'tu', 'component': 'Text', 'text': 'Out'},
      ]);
      expect(find.text('Hi', findRichText: true), findsOneWidget);
      expect(_paintedColor(tester, 'Hi'), _paintedColor(tester, 'Ho'));
      expect(find.text('In', findRichText: true), findsOneWidget);
      expect(_paintedColor(tester, 'In'), _paintedColor(tester, 'Out'));
      await tester.pump();
      expect(view.errors, isEmpty);
    });

    // null-props.test.tsx:48
    testWidgets('reads a binding to a null value as an unset prop', (
      tester,
    ) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Select',
            'options': ['a', 'b'],
            'value': {'@path': '/selected'},
          },
        ],
        data: {'selected': null},
      );
      // Pick's "none": no option shows as chosen.
      expect(find.byType(MenuAnchor), findsOneWidget);
      expect(find.text('a'), findsNothing);
      expect(find.text('b'), findsNothing);
      await tester.pump();
      expect(view.errors, isEmpty);
    });

    // null-props.test.tsx:65
    testWidgets('still rejects a wrong value that is not null', (tester) async {
      await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Select',
            'options': ['a', 'b'],
            'value': {'@path': '/selected'},
          },
        ],
        data: {'selected': 42},
      );
      // `findByText(/invalid props/)`; the Pick is not mounted.
      expect(alertsContaining('invalid props'), findsOne);
      expect(find.byType(MenuAnchor), findsNothing);
    });
  });
}

/// The colour the text [text] paints in: its RichText's root style, which
/// holds what it inherits merged with its own.
Color? _paintedColor(WidgetTester tester, String text) => tester
    .widget<RichText>(find.text(text, findRichText: true))
    .text
    .style
    ?.color;
