// The one reading of a component's accessibility envelope, KitEnvelope
// (foundation/interaction/envelope.dart): whether a2ui_flutter 0.4.0's
// NodeView puts a node of its own above the component follows its own
// `container` rule (node_view.dart:164: a label, a description, a live
// region or `hidden`), and a component that spreads the envelope onto its
// element merges into that node exactly then.

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/interaction/envelope.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

KitEnvelope _of(Map<String, Object?> accessibility) =>
    KitEnvelope.of(ComponentProps({'accessibility': accessibility}));

void main() {
  group("KitEnvelope.wrapped is NodeView's container rule", () {
    test('none: no node', () {
      expect(KitEnvelope.of(const ComponentProps({})).wrapped, isFalse);
      expect(_of(const {}).wrapped, isFalse);
      // An empty label or description is none, `off` no live region,
      // `hidden: false` not hidden.
      expect(
        _of(const {
          'label': '',
          'description': '',
          'live': 'off',
          'hidden': false,
        }).wrapped,
        isFalse,
      );
    });

    test('a label, a description, a live region or hidden: a node', () {
      expect(_of(const {'label': 'Totals'}).wrapped, isTrue);
      expect(_of(const {'description': 'The totals'}).wrapped, isTrue);
      expect(_of(const {'live': 'polite'}).wrapped, isTrue);
      expect(_of(const {'live': 'assertive'}).wrapped, isTrue);
      expect(_of(const {'hidden': true}).wrapped, isTrue);
    });

    test('names is a label or a description only', () {
      expect(_of(const {'label': 'Totals'}).names, isTrue);
      expect(_of(const {'description': 'The totals'}).names, isTrue);
      expect(_of(const {'live': 'polite'}).names, isFalse);
      expect(_of(const {'hidden': true}).names, isFalse);
    });
  });

  group("a Button merges into NodeView's node exactly when it is there", () {
    /// The button nodes.
    List<SemanticsNode> buttons() => find.semantics
        .byPredicate((node) => node.flagsCollection.isButton)
        .evaluate()
        .toList();

    Future<void> button(
      WidgetTester tester,
      Map<String, Object?> accessibility,
    ) => renderStandard(tester, [
      {
        'id': 'root',
        'component': 'Button',
        'label': 'Send',
        'accessibility': accessibility,
      },
    ]);

    testWidgets('a live region: one node, the button and the region', (
      tester,
    ) async {
      await button(tester, {'live': 'polite'});
      final node = buttons().single;
      expect(node.flagsCollection.isLiveRegion, isTrue);
      expect(node.label, 'Send');
    });

    testWidgets('a label: one node, the button named by it', (tester) async {
      await button(tester, {'label': 'Send it'});
      expect(buttons().single.label, 'Send it');
      expect(find.semantics.byLabel('Send'), findsNothing);
    });

    testWidgets('a description: one node, the button described', (
      tester,
    ) async {
      await button(tester, {'description': 'To the agent'});
      final node = buttons().single;
      expect(node.label, 'Send');
      expect(node.hint, 'To the agent');
    });

    testWidgets('hidden: no node at all', (tester) async {
      await button(tester, {'hidden': true});
      expect(buttons(), isEmpty);
      expect(find.text('Send'), findsOneWidget);
    });

    testWidgets('none: the button is a node of its own', (tester) async {
      await button(tester, {});
      final node = buttons().single;
      expect(node.label, 'Send');
      expect(node.flagsCollection.isLiveRegion, isFalse);
    });
  });
}
