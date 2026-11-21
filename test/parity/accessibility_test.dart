// Parity tests of the component envelope's accessibility, ported from
// packages/core/src/generative-ui/__tests__/accessibility.test.ts (MIT, (c)
// Atai Barkai). Each test names its upstream line.
//
// Parity for: Button, Column, (engine)
//
// Upstream reads the envelope with `readAccessibility`, which keeps the
// well-typed fields and drops the rest. Here a2ui_flutter's `NodeView`
// reads the envelope of every component of a surface, so the test renders
// one (`renderStandard`): a Column carrying the envelope, holding a Button
// (a semantics node of its own, so the Column's node carries the envelope
// alone). A field is kept when the Column's node shows it (label, hint,
// live region, presence) and dropped when it does not.
//
// A literal of the wrong type (`description: 7`, `live: "loud"`, `hidden:
// "yes"`) is rejected at ingest on both sides (validate-operation.test.ts
// :295; a2ui_core's envelope schema), so what reaches the reader is a
// bound value of the wrong type: the description and hidden are bound
// here. `live` takes no binding (an enum in the schema), so its wrong
// value cannot reach the reader. `readAccessibility("x")`, an envelope that
// is no object, is refused at ingest the same way: validate-operation's
// :295 (`accessibility: "x"`), ported in validate_operation_test.dart.
//
// A label "still a binding" (accessibility.test.ts:14) is, in a surface, a
// label bound to `/x` where `/x` holds binding-shaped data. `/y` holds a
// string, so the wrong result it rules out is a reader that resolves the
// label twice and names the node; today's NodeView does (queued).
//
// `{hidden: false, live: "off"}` kept: Flutter has no "off" live region and
// no "not hidden" flag, so a dropped field looks like a kept one here; the
// test rules out misreading them (off as a live region, false as hidden).
// (A Flutter live region is no ARIA live region inherited by children.)
//
// Not ported (bound to internals):
// - accessibility.test.ts:24 `accessibilityAttributes`: the ARIA attribute
//   names (`aria-live="off"` written out, `aria-hidden` only when true);
//   the semantics flags below are their counterpart.

import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// A Column carrying [accessibility], holding a Button "inside".
List<Map<String, Object?>> _withEnvelope(Map<String, Object?> accessibility) =>
    [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['b'],
        'accessibility': accessibility,
      },
      {'id': 'b', 'component': 'Button', 'label': 'inside'},
    ];

/// The one node labelled exactly [label].
SemanticsNode _node(String label) {
  final found = find.semantics.byPredicate((node) => node.label == label);
  expect(found, findsOne, reason: 'a node named "$label"');
  return found.evaluate().single;
}

void main() {
  group('readAccessibility', () {
    // accessibility.test.ts:5, the fields of the wrong type dropped
    testWidgets(
      'keeps the well-typed fields and drops the rest',
      skip: portQueue(
        'port-queue: (surface): a2ui_flutter NodeView reads a bound '
        'description of 7 as the hint "7" (ComponentProps.asString), where '
        'upstream drops it',
      ),
      (tester) async {
        await renderStandard(
          tester,
          _withEnvelope({
            'label': 'Totals',
            'description': {'@path': '/d'},
            'hidden': {'@path': '/h'},
          }),
          data: {'d': 7, 'h': 'yes'},
        );
        // `{ label: "Totals" }`: named, no description, not hidden.
        final node = _node('Totals');
        expect(node.hint, isEmpty);
        expect(
          find.semantics.byPredicate((n) => n.label == 'inside'),
          findsOne,
        );
      },
    );

    // accessibility.test.ts:5, a label still a binding
    testWidgets(
      'names nothing for a label that is still a binding',
      skip: portQueue(
        'port-queue: (surface): a2ui_flutter NodeView resolves an envelope '
        'value a second time (node_view.dart:183-187): a2ui_core hands it '
        'the label bound to /x already resolved, and NodeView reads the '
        'binding-shaped data there as a binding to /y, so the Column is '
        'named "Totals"; upstream resolves the label once '
        '(SurfaceView.tsx:500-517) and readAccessibility drops the object',
      ),
      (tester) async {
        // In a surface a binding is resolved, so the label that is "still a
        // binding" is one whose value is itself binding-shaped data: `/x`
        // holds `{"@path": "/y"}`, an object, not a string. `/y` holds a
        // string, so a reader that resolves the label twice names the node.
        await renderStandard(
          tester,
          _withEnvelope({
            'label': {'@path': '/x'},
          }),
          data: {
            'x': {'@path': '/y'},
            'y': 'Totals',
          },
        );
        expect(
          find.semantics.byPredicate(
            (node) => node.label.isNotEmpty && node.label != 'inside',
          ),
          findsNothing,
        );
      },
    );

    // accessibility.test.ts:5, `hidden: false` and `live: "off"` kept
    testWidgets('keeps hidden false and live off', (tester) async {
      await renderStandard(
        tester,
        _withEnvelope({'label': 'Totals', 'hidden': false, 'live': 'off'}),
      );
      // Not hidden: the node and its content are there; off: no live
      // region.
      final node = _node('Totals');
      expect(node.flagsCollection.isLiveRegion, isFalse);
      expect(find.semantics.byPredicate((n) => n.label == 'inside'), findsOne);
    });
  });
}
