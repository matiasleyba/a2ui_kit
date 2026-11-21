// Parity tests of dynamic values in props, event bindings and the
// accessibility envelope, ported from
// packages/react-core/src/v2/generative-ui/__tests__/dynamic-values.test.tsx
// (MIT, (c) Atai Barkai). Each test names its upstream line.
//
// Parity for: Button, Chart, Column, Select, Text, TextField, Title, (engine)
//
// Upstream renders test-made components (Text, Rows, Button, Column,
// Panel) through `renderSurface`, the same view its standard components
// render through. Here they map to standard components of the standard
// catalog (`renderStandard`): Text to the Text; Rows to a Chart whose
// table rows hold the bound values (:82, :145; read with the table roles
// RULEBOOK section 0 gives the Chart's data table, which it has), with a
// Select whose option label is bound as
// an extra for :82, and to a Title (:529, a component that does not spread
// the envelope upstream); Button to the Button; Panel,
// which spreads the envelope onto itself, to a Column of a Button (the
// Button is a semantics node of its own, so the Column's node carries the
// envelope alone, as the panel's element does). What upstream reads maps
// as follows: an element's `aria-label`, `aria-description`, `aria-live`
// and `aria-hidden` are its semantics node's label, hint, live-region flag
// and absence from the tree; `forwardEvent` is `view.actions`;
// `reportError` is `view.errors`, read after a pump; `window.open` is a
// fake url_launcher platform (`fakeUrlLauncher`).
//
// Not ported (bound to internals): none whole. Each test's translated
// inputs are named in it.
//
// Not ours (CopilotKit's machinery this package does not provide):
// - dynamic-values.test.tsx:172 "keeps a bound object that has a valid
//   field, and coerces a validator result inside calc": "[object Object]"
//   is JavaScript's `String()` of an object; the validator inside calc is
//   queued in resolve_test.dart (resolve.test.ts:160).
// - :403, :421, :445, :461, :471: CopilotKit's function dispatcher
//   (`createGenerativeUIDispatcher`); a2ui_core refuses the agent's calls
//   here (the document's `allowedCallers: rendererOnly`).

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// The semantics nodes labelled exactly [label].
SemanticsFinder _named(String label) =>
    find.semantics.byPredicate((node) => node.label == label);

/// The one node labelled exactly [label].
SemanticsNode _node(String label) {
  final found = _named(label);
  expect(found, findsOne, reason: 'a node named "$label"');
  return found.evaluate().single;
}

/// Upstream's Panel: a Column that carries [accessibility], holding a
/// Button "Totals" (the panel's title).
List<Map<String, Object?>> _panel(Map<String, Object?> accessibility) => [
  {
    'id': 'root',
    'component': 'Column',
    'children': ['title'],
    'accessibility': accessibility,
  },
  {'id': 'title', 'component': 'Button', 'label': 'Totals'},
];

/// dynamic-values.test.tsx:490's envelope: a bound label and hidden.
const Map<String, Object?> _boundEnvelope = {
  'label': {'@path': '/name'},
  'description': 'The totals of the order',
  'live': 'polite',
  'hidden': {'@path': '/hide'},
};

/// The text each text on screen shows, in order: upstream's
/// `getAllByTestId("text")` contents.
List<String> _texts(WidgetTester tester) => richTexts(tester);

void main() {
  group('dynamic values in props', () {
    // dynamic-values.test.tsx:82
    testWidgets(
      'resolves a binding nested in a list prop and updates when the data '
      'changes',
      (tester) async {
        // Rows' `rows[0].value` (`z.unknown()`, here the number 10): the
        // value of a Chart's first data row, read in its table ("Price: 10"
        // is the row of label Price and value 10).
        final view = await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'Chart',
              'xKey': 'label',
              'series': ['value'],
              'data': [
                {
                  'label': 'Price',
                  'value': {'@path': '/price'},
                },
                {'label': 'Fixed', 'value': 1},
              ],
            },
          ],
          data: {'price': 10},
        );
        expect(
          tableRows(tester),
          tableOf(
            ['label', 'value'],
            [
              ['Price', '10'],
              ['Fixed', '1'],
            ],
          ),
        );
        await view.update([agentWrite('/price', 12)]);
        expect(
          tableRows(tester),
          tableOf(
            ['label', 'value'],
            [
              ['Price', '12'],
              ['Fixed', '1'],
            ],
          ),
        );
        expect(view.errors, isEmpty);
      },
    );

    // dynamic-values.test.tsx:82, on a Select
    testWidgets('resolves a binding nested in a list prop and updates when '
        'the data changes: a Select option label', (tester) async {
      // Rows' `rows[0].value` as the label of a Select's first option, shown
      // as the chosen one. The label is `z.string()` upstream, so the bound
      // value is a string here; a raw `{"@path"}` or a stale label fails.
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Select',
            'value': 'a',
            'options': [
              {
                'value': 'a',
                'label': {'@path': '/price'},
              },
              {'value': 'b', 'label': 'Fixed'},
            ],
          },
        ],
        data: {'price': 'Price: 10'},
      );
      expect(find.text('Price: 10', findRichText: true), findsOneWidget);
      await view.update([agentWrite('/price', 'Price: 12')]);
      expect(find.text('Price: 12', findRichText: true), findsOneWidget);
      expect(find.text('Price: 10', findRichText: true), findsNothing);
      expect(view.errors, isEmpty);
    });

    // dynamic-values.test.tsx:105
    testWidgets('computes a function value from bound data and recomputes '
        'on change', (tester) async {
      // Intl.NumberFormat("en-US", { style: "currency", currency: "EUR" })
      // of 1599: CLDR's en currency pattern "¤#,##0.00", EUR's symbol "€"
      // and its 2 minor digits (ISO 4217), so "€1,599.00".
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Text',
            'text': {
              '@call': 'formatString',
              'args': {
                'value':
                    r"${/qty} × ${formatCurrency(value: /price, currency: 'EUR')}",
              },
            },
          },
        ],
        data: {'qty': 2, 'price': 1599},
      );
      expect(_texts(tester), ['2 × €1,599.00']);
      await view.update([agentWrite('/qty', 3)]);
      expect(_texts(tester), ['3 × €1,599.00']);
    });

    // dynamic-values.test.tsx:130
    testWidgets(
      'falls back and reports when a function value cannot be computed',
      skip: portQueue(
        'port-queue: (surface): engine: the props report naming the prop '
        '("text: value must be a number") is not the first: a2ui_core '
        "0.8.0's binder reports the failed formatNumber first (\"value must "
        "be a number\", through the component's surface reporter, "
        'component_context.dart:54-55)',
      ),
      (tester) async {
        final view = await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Text',
            'text': {
              '@call': 'formatNumber',
              'args': {'value': 'many'},
            },
          },
        ]);
        await tester.pump();
        _expectPropsFallback(tester, view, 'text: value must be a number');
      },
    );

    // dynamic-values.test.tsx:145
    testWidgets('recomputes a series when the data it reads changes', (
      tester,
    ) async {
      // Rows of a series: the rows of a Chart's table ("M2: 116" is the
      // row of label M2 and value 116; upstream reads that row alone).
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Chart',
            'xKey': 'label',
            'series': ['value'],
            'data': {
              '@call': 'series',
              'args': {
                'count': 2,
                'variable': 'm',
                'item': {'label': r'M${m}', 'value': r'${m * seats * 29}'},
                'seats': {'@path': '/seats'},
              },
            },
          },
        ],
        data: {'seats': 2},
      );
      expect(tableRows(tester), contains(equals(tableRow(['M2', '116']))));
      await view.update([agentWrite('/seats', 3)]);
      expect(tableRows(tester), contains(equals(tableRow(['M2', '174']))));
    });

    // dynamic-values.test.tsx:203, the recovery
    testWidgets('recovers once the data that a failed function value read '
        'arrives', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Text',
            'text': {
              '@call': 'formatNumber',
              'args': {
                'value': {'@path': '/price'},
              },
            },
          },
        ],
        data: {'price': ''},
      );
      await tester.pump();
      expect(view.errors, isNotEmpty);
      // Intl.NumberFormat("en-US") of 1234: CLDR's en decimal pattern
      // "#,##0.###" with the grouping separator ",", so "1,234".
      await view.update([agentWrite('/price', 1234)]);
      expect(_texts(tester), ['1,234']);
    });

    // dynamic-values.test.tsx:203, the component left out
    testWidgets(
      'does not render the component while its function value fails',
      skip: portQueue(
        'port-queue: (surface): engine: the props report naming the prop '
        '("text: value must be a number") is not the first: a2ui_core '
        "0.8.0's binder reports the failed formatNumber first (\"value must "
        'be a number", component_context.dart:54-55)',
      ),
      (tester) async {
        final view = await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'Text',
              'text': {
                '@call': 'formatNumber',
                'args': {
                  'value': {'@path': '/price'},
                },
              },
            },
          ],
          data: {'price': ''},
        );
        await tester.pump();
        _expectPropsFallback(tester, view, 'text: value must be a number');
      },
    );

    // dynamic-values.test.tsx:224
    testWidgets('recomputes a value that read a list when an item of the '
        'list changes', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Text',
            'text': {
              '@call': 'formatString',
              'args': {'value': r'${and(values: /flags)}'},
            },
          },
        ],
        data: {
          'flags': [true, true],
        },
      );
      expect(_texts(tester), ['true']);
      await view.update([agentWrite('/flags/0', false)]);
      expect(_texts(tester), ['false']);
    });

    // dynamic-values.test.tsx:248
    testWidgets('resolves a template row again when the template moves to '
        'another list', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': {'componentId': 'row', 'path': '/a'},
          },
          {
            'id': 'row',
            'component': 'Text',
            'text': {'@path': 'name'},
          },
        ],
        data: {
          'a': [
            {'name': 'from a'},
          ],
          'b': [
            {'name': 'from b'},
          ],
        },
      );
      expect(_texts(tester), ['from a']);
      await view.update([
        agentComponents([
          {
            'id': 'root',
            'component': 'Column',
            'children': {'componentId': 'row', 'path': '/b'},
          },
        ]),
      ]);
      expect(_texts(tester), ['from b']);
    });

    // dynamic-values.test.tsx:280
    testWidgets('gives @index to a template item inside a function value', (
      tester,
    ) async {
      await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': {'componentId': 'row', 'path': '/items'},
          },
          {
            'id': 'row',
            'component': 'Text',
            'text': {
              '@call': 'formatString',
              'args': {'value': r'${@index(offset: 1)}. ${label}'},
            },
          },
        ],
        data: {
          'items': [
            {'label': 'a'},
            {'label': 'b'},
          ],
        },
      );
      expect(_texts(tester), ['1. a', '2. b']);
    });
  });

  group('dynamic values in event bindings', () {
    // dynamic-values.test.tsx:308
    testWidgets('opens a URL from a functionCall binding, as a user '
        'gesture', (tester) async {
      final launcher = fakeUrlLauncher();
      final view = await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Button',
          'label': 'Docs',
          'onClick': {
            'functionCall': {
              '@call': 'openUrl',
              'args': {'url': 'https://example.com/docs'},
            },
          },
        },
      ]);
      await tester.tap(find.text('Docs'));
      await tester.pump();
      expect(launcher.opened, [openedInNewTab('https://example.com/docs')]);
      expect(view.actions, isEmpty);
      expect(view.errors, isEmpty);
    });

    // dynamic-values.test.tsx:335
    testWidgets('resolves a context whose only key is named like an action '
        'binding', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Button',
            'label': 'Go',
            'onClick': {
              'event': {
                'name': 'go',
                'context': {
                  'event': {'@path': '/picked'},
                },
              },
            },
          },
        ],
        data: {'picked': 'launch'},
      );
      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(view.actions.first.context, {'event': 'launch'});
    });

    // dynamic-values.test.tsx:357
    testWidgets('resolves function values in the userMessage and the context '
        'of an event', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Button',
            'label': 'Buy',
            'onClick': {
              'event': {
                'name': 'buy',
                'userMessage': {
                  '@call': 'formatString',
                  'args': {'value': r'Buy ${/qty} for ${/name}'},
                },
                'context': {
                  'total': {
                    '@call': 'formatCurrency',
                    'args': {
                      'value': {'@path': '/price'},
                      'currency': 'USD',
                    },
                  },
                  'nested': {
                    'qty': {'@path': '/qty'},
                  },
                },
              },
            },
          },
        ],
        data: {'qty': 2, 'name': 'Ada', 'price': 5},
      );
      await tester.tap(find.text('Buy'));
      await tester.pump();
      final event = view.actions.first;
      expect(event.userMessage, 'Buy 2 for Ada');
      // Intl.NumberFormat("en-US", { style: "currency", currency: "USD" })
      // of 5: CLDR's en currency pattern "¤#,##0.00", USD's symbol "$" and
      // its 2 minor digits (ISO 4217), so "$5.00".
      expect(event.context, {
        'total': r'$5.00',
        'nested': {'qty': 2},
      });
    });
  });

  group('the component envelope', () {
    // dynamic-values.test.tsx:490, the accessibility and the catalogId
    testWidgets('resolves accessibility, gives it to the component, and '
        'keeps catalogId out of the props', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            ..._panel(_boundEnvelope).first,
            'catalogId': 'copilotkit/standard@1',
          },
          ..._panel(const {}).skip(1),
        ],
        data: {'name': 'Order totals', 'hide': false},
      );
      final panel = _node('Order totals');
      expect(panel.hint, 'The totals of the order');
      expect(panel.flagsCollection.isLiveRegion, isTrue);
      // Upstream updates the name and `hide` in one step and reads the label
      // of the hidden element; a hidden node has no semantics here, so the
      // name is read first, then the hiding.
      await view.update([agentWrite('/name', 'Cart totals')]);
      expect(_node('Cart totals').hint, 'The totals of the order');
      await view.update([agentWrite('/hide', true)]);
      // aria-hidden hides the panel and its content: neither its name nor
      // its Button reaches a screen reader, though both are drawn.
      expect(_named('Cart totals'), findsNothing);
      expect(_named('Totals'), findsNothing);
      expect(find.text('Totals'), findsOneWidget);
      expect(view.errors, isEmpty);
    });

    // dynamic-values.test.tsx:490, the metadata (a2ui_core refuses the key
    // 'acme.track', not a UAX #31 identifier, and with it the component:
    // the README's A2uiIdNormalizer rewrites the key, its value kept,
    // INV-260)
    testWidgets('keeps metadata out of the props', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            ..._panel(_boundEnvelope).first,
            'metadata': {
              'extensions': {'acme.track': 'totals'},
            },
          },
          ..._panel(const {}).skip(1),
        ],
        data: {'name': 'Order totals', 'hide': false},
      );
      expect(_node('Order totals').hint, 'The totals of the order');
      expect(find.text('Totals'), findsOneWidget);
      await tester.pump();
      expect(view.errors, isEmpty);
    });

    // dynamic-values.test.tsx:529
    testWidgets('hides and announces a component that does not read the '
        'envelope itself', (tester) async {
      // Rows with one row "a: 1": a Title, which upstream's standard
      // catalog does not spread the envelope onto (text.tsx:150 spreads it
      // on Text only).
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Title',
          'text': 'a: 1',
          'accessibility': {
            'hidden': true,
            'live': 'polite',
            'label': 'Totals',
          },
        },
      ]);
      // The `dl` is still there.
      expect(find.text('a: 1'), findsOneWidget);
      // aria-hidden: nothing of it reaches a screen reader, no name.
      expect(
        find.semantics.byPredicate(
          (node) => node.label.contains('a: 1') || node.label == 'Totals',
        ),
        findsNothing,
      );
    });

    // dynamic-values.test.tsx:529, the name and the live region without
    // `hidden` (a translated input: with upstream's `hidden: true` nothing
    // reaches the semantics tree, so a component named from the envelope
    // passes; without it, a name on the Title shows). RULEBOOK section 0:
    // the envelope's name goes only on the components upstream spreads it
    // onto, and Title is not one (text.tsx:150 spreads it on Text only);
    // the wrapper keeps `aria-live` (SurfaceView.tsx:1154-1166).
    testWidgets(
      'announces a component that does not read the envelope itself, and '
      'names it by its own text only',
      skip: portQueue(
        "port-queue: (surface): a2ui_flutter's NodeView names every "
        'component from the envelope (node_view.dart:163-165); upstream '
        'names only those that spread it',
      ),
      (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Title',
            'text': 'a: 1',
            'accessibility': {'live': 'polite', 'label': 'Totals'},
          },
        ]);
        expect(
          find.semantics.byPredicate((node) => node.label == 'a: 1'),
          findsOne,
        );
        expect(
          find.semantics.byPredicate(
            (node) => node.flagsCollection.isLiveRegion,
          ),
          findsOne,
        );
        expect(
          find.semantics.byPredicate((node) => node.label.contains('Totals')),
          findsNothing,
        );
      },
    );

    // dynamic-values.test.tsx:554
    testWidgets('keeps the component mounted when a bound hidden flips', (
      tester,
    ) async {
      // The Panel holds a TextField here: what the student typed shows the
      // field was not remounted.
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['field'],
            'accessibility': {
              'hidden': {'@path': '/hide'},
            },
          },
          {'id': 'field', 'component': 'TextField', 'label': 'Note'},
        ],
        data: {'hide': false},
      );
      await tester.enterText(find.byType(EditableText), 'kept');
      await tester.pump();
      final editor = tester.state(find.byType(EditableText));
      bool fieldInTree() => find.semantics
          .byPredicate((node) => node.flagsCollection.isTextField)
          .evaluate()
          .isNotEmpty;
      expect(fieldInTree(), isTrue);
      await view.update([agentWrite('/hide', true)]);
      expect(fieldInTree(), isFalse);
      expect(tester.state(find.byType(EditableText)), same(editor));
      await view.update([agentWrite('/hide', false)]);
      expect(fieldInTree(), isTrue);
      expect(tester.state(find.byType(EditableText)), same(editor));
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'kept',
      );
    });

    // dynamic-values.test.tsx:584
    testWidgets('names nothing while a label is a binding to a missing '
        'value, without an error', (tester) async {
      final view = await renderStandard(
        tester,
        _panel({
          'label': {'@path': '/missing'},
        }),
      );
      expect(find.text('Totals'), findsOneWidget);
      // The Column's node, if any, has no name: every label is the
      // Button's.
      expect(
        find.semantics.byPredicate(
          (node) => node.label.isNotEmpty && node.label != 'Totals',
        ),
        findsNothing,
      );
      await tester.pump();
      expect(view.errors, isEmpty);
    });

    // dynamic-values.test.tsx:598
    testWidgets(
      'renders the component when its accessibility cannot be computed yet, '
      'and names it once the data is there',
      skip: portQueue(
        'port-queue: (surface): engine: a2ui_core reports the formatNumber '
        'that fails inside the label\'s formatString ("value must be a '
        "number\", through the DataContext's onError), where upstream "
        'reports nothing; the label itself names nothing until the data is '
        "there (formatString is CopilotKit's since p1-functions)",
      ),
      (tester) async {
        // Upstream's other field is `hidden: true`, whose element still
        // carries the label; a hidden node has no semantics here, so the
        // other field is `live`, which a node keeps.
        final view = await renderStandard(
          tester,
          _panel({
            'label': {
              '@call': 'formatString',
              'args': {'value': r'${formatNumber(value: /count)} items'},
            },
            'live': 'polite',
          }),
        );
        // formatNumber of a missing value fails; the component is not at
        // fault, and the other fields of the envelope still apply.
        expect(find.text('Totals'), findsOneWidget);
        final live = find.semantics.byPredicate(
          (node) => node.flagsCollection.isLiveRegion,
        );
        expect(live, findsOne);
        expect(live.evaluate().single.label, isEmpty);
        await tester.pump();
        expect(view.errors, isEmpty);
        // Intl.NumberFormat("en-US") of 1234: "1,234" (CLDR's en decimal
        // pattern "#,##0.###").
        await view.update([agentWrite('/count', 1234)]);
        expect(_node('1,234 items').flagsCollection.isLiveRegion, isTrue);
      },
    );
  });

  group('ingest', () {
    // dynamic-values.test.tsx:632
    testWidgets('does not reject a prop with a nested binding at ingest', (
      tester,
    ) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Select',
            'options': [
              {
                'value': 'x',
                'label': {'@path': '/x'},
              },
            ],
          },
        ],
        data: {'x': 'one'},
      );
      await tester.pump();
      expect(view.errors, isEmpty);
    });
  });

  group('beyond dynamic-values.test.tsx (ours)', () {
    // RULEBOOK section 0's envelope rule, its other side: upstream's Text
    // spreads the envelope onto its own element (standard/text.tsx:150), so
    // a Text is named by the envelope's label. A fix that drops the name
    // from every component fails here.
    testWidgets('names a Text, which reads the envelope itself, by its '
        'label', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Text',
          'text': 'a: 1',
          'accessibility': {'label': 'Totals'},
        },
      ]);
      expect(
        find.semantics.byPredicate((node) => node.label.contains('Totals')),
        findsOne,
      );
    });
  });
}

/// Upstream's fallback for a prop that can't be read (RULEBOOK section 0;
/// SurfaceView.tsx:1111-1133, host.tsx:125-150): one alert "Couldn’t
/// display this part: invalid props ([problem])" (U+2019 in "Couldn’t",
/// host.tsx:139) in place of the component, so nothing of the component's
/// own is drawn, with no Retry (only a component that threw gets one,
/// boundaries.tsx:459-471; this fallback passes none,
/// SurfaceView.tsx:1124-1131), and the props report of the problem as the
/// first report (`reportError.mock.calls[0][0]`, `Invalid props:
/// [problem]`).
void _expectPropsFallback(
  WidgetTester tester,
  ParitySurface view,
  String problem,
) {
  expect(alerts(), findsOne);
  expect(alertsContaining('invalid props ($problem)'), findsOne);
  expect(find.text('Retry'), findsNothing);
  expect(textsOutsideAlerts(tester), isEmpty);
  expect(view.errors, isNotEmpty);
  expect(view.errors.first.message, contains(problem));
}
