// Parity tests of how a surface renders its components, ported from
// packages/react-core/src/v2/generative-ui/__tests__/surface-view.test.tsx
// (MIT, (c) Atai Barkai). Each test names its upstream line.
//
// Parity for: Button, Column, Text, TextField, Title, (engine)
//
// Upstream renders test-made components (Grid, Card, Label, TextField,
// Section, Position, Counter, Bomb) through CopilotKit's `SurfaceView`, the
// same view its standard components render through. Here the README's app
// (`ReadmeApp`: today a2ui_flutter's `A2uiSurface` over a2ui_core's
// resolver) renders this package's standard catalog (`renderStandard`),
// and those components map to standard ones:
// Grid and Section to a Column, Card to a Button or a TextField (a stateful
// child), Label and Position to a Text, Counter to a Title bound to the
// wrong type. Bomb, a component that throws on demand, and Racer, which
// writes data as the surface mounts, are test-only builders put in place of
// the Badge through `A2uiKitOptions.overrides` (the catalog's own schema
// stays). What upstream reads maps as follows:
// `screen.getByText` is a text drawn; `getByRole("alert")` and
// `alertText()` the one node with the alert role and its label (upstream's
// fallbacks, which RULEBOOK section 0 makes ours: "Couldn’t display this
// part: <message>", U+2019 in "Couldn’t" (host.tsx:139), with a Retry only
// for a component that threw (boundaries.tsx:459-471); the cycle and
// invalid-props fallbacks pass none (SurfaceView.tsx:316-323, :1124-1131));
// `mounts.get(id)` and a card's click count
// the State of a TextField's editor and the text typed into it;
// `forwardEvent` `view.actions`; `reportError` `view.errors`, read after a
// pump (an error's kind, `render` or `props`, has no field here yet: a
// report is matched by the component it names).
//
// Not ported (bound to internals): none whole. :543 "does not lose a data
// write that lands between commit and effect flush" names React's phases;
// the behaviour it guards, a data write while the surface mounts is not
// lost, is tested through an override that writes in its first frame.
//
// Not ours (CopilotKit's machinery this package does not provide):
// - :371, :714, :733: functions the app declares (`createGenerativeUI`'s
//   `functions`, `useGenerativeUIFunction`) and events matched to them.
// - :419, the look of its custom `errorFallback` ("retry: <message>"): an
//   option of CopilotKit's runtime. The default fallback upstream draws in
//   its place (host.tsx:125-150), with its Retry, is ported, queued.
// - :576, :587, :599, :632, :646, :661, :679, "bound props": CopilotKit's
//   app state bound to props by name or selector (`bind`,
//   `useGenerativeUIState`), and the render counts of those selectors.
// - :939, :957: `invokeBoundEvent`, CopilotKit's event dispatcher.
// - :1037, :1042: `useGenerativeUIState`'s state schema.

import 'package:a2ui_core/a2ui_core.dart'
    show A2uiRendererError, ComponentModel;
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// Whether the test-only Bomb throws: upstream's `bombArmed`.
bool _bombArmed = false;

/// The standard catalog with a Bomb in place of the Badge: upstream's
/// `Bomb`, which throws "exploded <label>" while armed and shows "survived
/// <label>" otherwise.
A2uiKitOptions _withBomb() => A2uiKitOptions(
  look: A2uiKitLook.standard,
  overrides: {
    'Badge': (context, node, props, buildChild) {
      final label = props.string('label') ?? '';
      if (_bombArmed) throw StateError('exploded $label');
      return Text('survived $label');
    },
  },
);

/// Arms the Bomb for the rest of the test.
void _armBomb() {
  _bombArmed = true;
  addTearDown(() => _bombArmed = false);
}

/// Upstream's `alertText()` contains [text]: there is one alert node, and
/// its label holds [text].
void _expectAlert(String text) {
  expect(alerts(), findsOne);
  expect(alertsContaining(text), findsOne);
}

/// The errors the surface reported that name the component [id], as a
/// whole word of the message or the path: upstream's `reportError` calls
/// with that `componentId`. a2ui_core's `A2uiRendererError` has no
/// component field (code, surfaceId, message, path, functionCallId,
/// details), and upstream's `kind`, `render` or `props`, has no field here
/// yet; check `error.code` once the fix names one.
List<A2uiRendererError> _reportsFor(ParitySurface view, String id) {
  final word = RegExp(
    '(^|[^A-Za-z0-9_-])${RegExp.escape(id)}(\$|[^A-Za-z0-9_-])',
  );
  return [
    for (final error in view.errors)
      if (word.hasMatch(error.message) || word.hasMatch(error.path ?? ''))
        error,
  ];
}

/// The text in each text field, in order: upstream's `inputs()` values.
List<String> _fieldTexts(WidgetTester tester) => [
  for (final field in tester.widgetList<EditableText>(
    find.byType(EditableText),
  ))
    field.controller.text,
];

/// Upstream's `texts(element)`: the text of each text in the container
/// around [text], in order.
List<String> _textsAround(WidgetTester tester, String text) => [
  for (final rich in tester.widgetList<RichText>(
    find.descendant(
      of: find.byWidget(flexContainerOf(tester, text)),
      matching: find.byType(RichText),
    ),
  ))
    rich.text.toPlainText(),
];

/// A Column whose children are the template [componentId] over [path]:
/// upstream's `grid({ componentId, path })`.
Map<String, Object?> _grid(String componentId, String path) => {
  'id': 'root',
  'component': 'Column',
  'children': {'componentId': componentId, 'path': path},
};

/// A Text bound to [path]: upstream's `label(id, path)`.
Map<String, Object?> _label(String id, String path) => {
  'id': id,
  'component': 'Text',
  'text': {'@path': path},
};

void main() {
  group('SurfaceView', () {
    // surface-view.test.tsx:347
    testWidgets('streams children into a column without remounting earlier '
        'ones', (tester) async {
      Map<String, Object?> field(String id, String label) => {
        'id': id,
        'component': 'TextField',
        'label': label,
      };
      final view = await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b', 'c'],
        },
      ]);
      // A child that has not streamed yet draws nothing, not a placeholder:
      // the Column holds no item at all.
      expect(find.byType(CssFlexItem), findsNothing);
      expect(find.byType(EditableText), findsNothing);
      expect(find.text('Alpha', findRichText: true), findsNothing);
      await view.update([
        agentComponents([field('a', 'Alpha')]),
      ]);
      // The card's click: what the student types into the first field.
      await tester.enterText(find.byType(EditableText), 'typed');
      await tester.pump();
      final editor = tester.state(find.byType(EditableText));
      await view.update([
        agentComponents([field('b', 'Beta')]),
      ]);
      await view.update([
        agentComponents([field('c', 'Gamma'), field('a', 'Alpha 2')]),
      ]);
      expect(find.text('Alpha 2', findRichText: true), findsOneWidget);
      expect(_fieldTexts(tester), ['typed', '', '']);
      // Mounted once: the first field keeps its editor.
      expect(tester.state(find.byType(EditableText).first), same(editor));
      // No placeholder after streaming either: the root Column holds the
      // three fields and nothing else.
      expect(
        flexContainersAround(tester, 'Alpha 2').last.children,
        hasLength(3),
      );
      expect(view.errors, isEmpty);
    });

    // surface-view.test.tsx:392
    testWidgets('forwards event bindings to the agent with resolved '
        'context', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Button',
            'label': 'pick root',
            'onClick': {
              'event': {
                'name': 'more',
                'context': {
                  'selected': {'@path': '/sel'},
                },
              },
            },
          },
        ],
        data: {'sel': 'x'},
      );
      await tester.tap(find.text('pick root'));
      await tester.pump();
      final action = view.actions.single;
      expect(action.name, 'more');
      expect(action.surfaceId, testSurfaceId);
      expect(action.sourceComponentId, 'root');
      // `timestamp: expect.any(String)`: a DateTime, by its type. The
      // Card's own `productId` is a test-made component's argument.
      expect(action.context, {'selected': 'x'});
      // The exact event has no `userMessage`.
      expect(action.userMessage, isNull);
    });

    // surface-view.test.tsx:419, the containment
    testWidgets('isolates a throwing component and keeps its siblings', (
      tester,
    ) async {
      _armBomb();
      await renderStandard(tester, options: _withBomb(), _bombAndSibling);
      // Flutter's report of the throw, if it got that far (a fix that
      // catches it in our layer leaves none).
      tester.takeException();
      // The Bomb drew nothing of its own; the rest of the surface is built.
      expect(find.text('survived b1'), findsNothing);
      expect(find.text('pick ok'), findsOneWidget);
    });

    // surface-view.test.tsx:419, the sibling still usable
    testWidgets('keeps the siblings of a throwing component usable', (
      tester,
    ) async {
      _armBomb();
      final view = await renderStandard(
        tester,
        options: _withBomb(),
        _bombAndSibling,
      );
      tester.takeException();
      await tester.tap(find.text('pick ok'));
      await tester.pump();
      expect(view.actionNames, ['pick']);
    });

    // surface-view.test.tsx:419, the report
    testWidgets('reports a throwing component to the host', (tester) async {
      _armBomb();
      final view = await renderStandard(
        tester,
        options: _withBomb(),
        _bombAndSibling,
      );
      tester.takeException();
      await tester.pump();
      // `reportError` with `kind: "render"` and `componentId: "bomb"`.
      expect(_reportsFor(view, 'bomb'), isNotEmpty);
    });

    // surface-view.test.tsx:419, the retry (upstream's default fallback
    // offers it too: boundaries.tsx:459-476, host.tsx:140-148)
    testWidgets('retries a throwing component from its fallback', (
      tester,
    ) async {
      _armBomb();
      await renderStandard(tester, options: _withBomb(), _bombAndSibling);
      tester.takeException();
      _expectAlert('exploded b1');
      _bombArmed = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.text('survived b1'), findsOneWidget);
    });

    // surface-view.test.tsx:452, the recovery
    testWidgets('resets a failed component when the agent sends a new '
        'revision of it', (tester) async {
      _armBomb();
      final view = await renderStandard(tester, options: _withBomb(), [
        {'id': 'root', 'component': 'Badge', 'label': 'v1'},
      ]);
      // Flutter's report of the throw, if it got that far.
      tester.takeException();
      expect(find.text('survived v1'), findsNothing);
      _bombArmed = false;
      await view.update([
        agentComponents([
          {'id': 'root', 'component': 'Badge', 'label': 'v2'},
        ]),
      ]);
      expect(find.text('survived v2'), findsOneWidget);
    });

    // surface-view.test.tsx:452, the fallback
    testWidgets('shows the error of a failed component in an alert', (
      tester,
    ) async {
      _armBomb();
      await renderStandard(tester, options: _withBomb(), [
        {'id': 'root', 'component': 'Badge', 'label': 'v1'},
      ]);
      tester.takeException();
      await tester.pump();
      _expectAlert('exploded v1');
    });

    // surface-view.test.tsx:462
    testWidgets(
      'gives an @index prop outside of a template no value, without an '
      'error',
      skip: portQueue(
        'port-queue: (surface): engine: a2ui_core 0.8.0 evaluates @index '
        'before any catalog (data_context.dart:844-848) and throws outside a '
        'template (:780-786, "… can only be evaluated inside a collection '
        'template iteration scope."), and its binder reports that to the '
        'surface (component_context.dart:54-55)',
      ),
      (tester) async {
        final view = await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Text',
            'text': {'@call': '@index'},
          },
        ]);
        await tester.pump();
        // Position's "none" (`index` undefined): the Text draws an empty
        // text, not "NaN", "null" or the raw "@index".
        expect(richTexts(tester), ['']);
        expect(view.errors, isEmpty);
      },
    );

    // surface-view.test.tsx:475
    testWidgets('shows a local fallback when bound data has the wrong type', (
      tester,
    ) async {
      // Counter's `value: z.number()` bound to "many": here Title's
      // `text: z.string()` (shared/standard/text.ts:28) bound to 42. It
      // must not draw "42", nor stay blank: upstream's alert names the
      // prop, and a props report is made.
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Title',
            'text': {'@path': '/n'},
          },
        ],
        data: {'n': 42},
      );
      await tester.pump();
      // `alertText()` toMatch(/value/): the prop's name, here `text`.
      _expectAlert('text');
      // The invalid-props fallback passes no retry
      // (SurfaceView.tsx:1124-1131).
      expect(find.text('Retry'), findsNothing);
      expect(textsOutsideAlerts(tester), isEmpty);
      expect(_reportsFor(view, 'root'), isNotEmpty);
    });

    // surface-view.test.tsx:487
    testWidgets('shows a local fallback instead of recursing on a '
        'self-referencing slot', (tester) async {
      final view = await renderStandard(tester, []);
      // Injected into the model, past the processor's checks, as upstream
      // does to exercise the renderer's own defence.
      view.surface.componentsModel.addComponent(
        ComponentModel('root', 'Column', {
          'children': ['root'],
        }),
      );
      await view.update([agentWrite('/tick', 1)]);
      _expectAlert('cyclic reference to root');
      // The cycle's fallback passes no retry (SurfaceView.tsx:316-323).
      expect(find.text('Retry'), findsNothing);
    });

    // surface-view.test.tsx:500, the rest of the tree
    testWidgets('cuts an A -> B -> A cycle without freezing and keeps the '
        'rest of the tree', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'ok'],
        },
        {
          'id': 'a',
          'component': 'Column',
          'children': ['b'],
        },
        {
          'id': 'b',
          'component': 'Column',
          'children': ['a'],
        },
        {'id': 'ok', 'component': 'Text', 'text': 'Fine'},
      ]);
      expect(find.text('Fine', findRichText: true), findsOneWidget);
    });

    // surface-view.test.tsx:500, the alert
    testWidgets('names the cycle it cut in an alert', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'ok'],
        },
        {
          'id': 'a',
          'component': 'Column',
          'children': ['b'],
        },
        {
          'id': 'b',
          'component': 'Column',
          'children': ['a'],
        },
        {'id': 'ok', 'component': 'Text', 'text': 'Fine'},
      ]);
      _expectAlert('cyclic reference to a');
      // The cycle's fallback passes no retry (SurfaceView.tsx:316-323).
      expect(find.text('Retry'), findsNothing);
    });

    // surface-view.test.tsx:514
    testWidgets('renders a repeated child id once', (tester) async {
      final view = await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['x', 'x'],
        },
        {'id': 'x', 'component': 'Text', 'text': 'Once'},
      ]);
      expect(find.text('Once', findRichText: true), findsOneWidget);
      // No duplicate-key warning: no error, nothing thrown.
      await tester.pump();
      expect(view.errors, isEmpty);
    });

    // surface-view.test.tsx:531
    testWidgets('updates every mount of the same surface synchronously', (
      tester,
    ) async {
      Map<String, Object?> card(String name) => {
        'id': 'root',
        'component': 'Text',
        'text': name,
      };
      final view = await renderStandard(tester, [card('Before')]);
      // A second mount of the same surface: an app may show one surface
      // twice (a chat card and its expanded view).
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [standardLight]),
          home: Scaffold(
            body: Column(children: [view.surfaceView(), view.surfaceView()]),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Before', findRichText: true), findsNWidgets(2));
      await view.update([
        agentComponents([card('After')]),
      ]);
      expect(find.text('After', findRichText: true), findsNWidgets(2));
      expect(find.text('Before', findRichText: true), findsNothing);
    });

    // surface-view.test.tsx:543 (the behaviour it guards: see the header)
    testWidgets('does not lose a data write that lands while the surface '
        'mounts', (tester) async {
      // Racer's layout effect writes `/n` after React commits and before its
      // effects subscribe; here a test-only builder writes it right after
      // the first frame, once its siblings are mounted. The wrong result
      // this rules out: a node that reads its data while it builds and
      // subscribes to changes a frame later (say, in a post-frame
      // callback) misses this write and keeps drawing "1". a2ui_flutter's
      // NodeView subscribes while it builds (node_view.dart:120-127), so
      // today's code passes; a later write after the first frame, which
      // any node that reacts to data at all draws, would not tell them
      // apart.
      var raced = false;
      final options = A2uiKitOptions(
        look: A2uiKitLook.standard,
        overrides: {
          'Badge': (context, node, props, buildChild) {
            if (!raced) {
              raced = true;
              final data = node.context?.dataContext.dataModel;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => data?.set('/n', 9),
              );
            }
            return const SizedBox.shrink();
          },
        },
      );
      await renderStandard(
        tester,
        options: options,
        data: {'n': 1},
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['counter', 'racer'],
          },
          {
            'id': 'counter',
            'component': 'Text',
            'text': {'@path': '/n'},
          },
          {'id': 'racer', 'component': 'Badge', 'label': 'racer'},
        ],
      );
      await tester.pump();
      expect(raced, isTrue);
      expect(find.text('9', findRichText: true), findsOneWidget);
    });

    // surface-view.test.tsx:558
    testWidgets('keeps rendering when the host error reporter throws', (
      tester,
    ) async {
      final view = await renderStandard(tester, [], options: _withBomb());
      // The host's reporter throws: here the app's listener on the
      // surface's errors. a2ui_core's `emit` catches a listener's throw
      // and logs it (event_notifier.dart:54-66), so this half can't fail
      // here; the test tells right from wrong by its two alerts. If the
      // fix adds an error callback of our own (an `A2uiKitOptions`
      // reporter), that callback is the one to make throw.
      view.surface.onError.subscribe((_) {
        throw StateError('host onError exploded');
      });
      _armBomb();
      // Counter's required `value` bound to a missing path: a Title's
      // required `text` (shared/standard/text.ts:28).
      await view.update([
        agentComponents([
          {
            'id': 'root',
            'component': 'Column',
            'children': ['bomb', 'bad'],
          },
          {'id': 'bomb', 'component': 'Badge', 'label': 'b1'},
          {
            'id': 'bad',
            'component': 'Title',
            'text': {'@path': '/missing'},
          },
        ]),
      ]);
      tester.takeException();
      await tester.pump();
      expect(view.errors, isNotEmpty);
      expect(alerts(), findsNWidgets(2));
    });
  });

  group('writable props', () {
    // surface-view.test.tsx:757
    testWidgets('writes a path-bound prop to the data model, and keeps it '
        'over an agent write', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'TextField',
            'value': {'@path': '/form/email'},
          },
        ],
        data: {
          'form': {'email': 'agent@x.io'},
        },
      );
      await tester.enterText(find.byType(EditableText), 'me@x.io');
      await tester.pump();
      expect(view.dataAt('/form/email'), 'me@x.io');

      await view.update([agentWrite('/form/email', 'other@x.io')]);
      expect(_fieldTexts(tester), ['me@x.io']);
      expect(view.dataAt('/form/email'), 'me@x.io');
    });

    // surface-view.test.tsx:775
    testWidgets("keeps a literal prop's value local to the node", (
      tester,
    ) async {
      final view = await renderStandard(tester, [
        {'id': 'root', 'component': 'TextField', 'value': 'agent'},
      ]);
      await tester.enterText(find.byType(EditableText), 'me');
      await tester.pump();
      expect(_fieldTexts(tester), ['me']);
      // `describeSurfaces` lists no owned value: nothing was written for
      // the agent to keep away from.
      expect(A2uiUserOwnedData.ownedValuesOf(view.surface), isEmpty);
    });
  });

  group('template slots', () {
    // surface-view.test.tsx:792
    testWidgets('renders the component once per item, with relative '
        'bindings', (tester) async {
      final view = await renderStandard(
        tester,
        [_grid('row', '/items'), _label('row', 'name')],
        data: {
          'items': [
            {'name': 'A'},
            {'name': 'B'},
            {'name': 'C'},
          ],
        },
      );
      expect(_textsAround(tester, 'A'), ['A', 'B', 'C']);

      await view.update([
        agentWrite('/items', [
          {'name': 'A'},
        ]),
      ]);
      expect(_textsAround(tester, 'A'), ['A']);
      expect(find.text('B', findRichText: true), findsNothing);
      expect(find.text('C', findRichText: true), findsNothing);
    });

    // surface-view.test.tsx:805
    testWidgets('resolves a nested template path against the outer item', (
      tester,
    ) async {
      // Section's own `title: {"@path": "title"}` is kept as a Text before
      // the rows (a Column takes one children slot), so the outer item's
      // own relative binding is read beside the nested template.
      await renderStandard(
        tester,
        [
          _grid('group', '/groups'),
          {
            'id': 'group',
            'component': 'Column',
            'children': ['title', 'rows'],
          },
          _label('title', 'title'),
          {
            'id': 'rows',
            'component': 'Column',
            'children': {'componentId': 'row', 'path': 'rows'},
          },
          _label('row', 'name'),
        ],
        data: {
          'groups': [
            {
              'title': 'G1',
              'rows': [
                {'name': 'a'},
                {'name': 'b'},
              ],
            },
            {
              'title': 'G2',
              'rows': [
                {'name': 'c'},
              ],
            },
          ],
        },
      );
      expect(_textsAround(tester, 'a'), ['a', 'b']);
      expect(_textsAround(tester, 'c'), ['c']);
      // `section-G1` and `section-G2`: each group under its own title.
      expect(richTexts(tester), ['G1', 'a', 'b', 'G2', 'c']);
    });

    // surface-view.test.tsx:825
    testWidgets('writes a writable prop of a template item to the item '
        'path', (tester) async {
      final view = await renderStandard(
        tester,
        [
          _grid('field', '/items'),
          {
            'id': 'field',
            'component': 'TextField',
            'value': {'@path': 'name'},
          },
        ],
        data: {
          'items': [
            {'name': 'A'},
            {'name': 'B'},
          ],
        },
      );
      await tester.enterText(find.byType(EditableText).at(1), 'B2');
      await tester.pump();
      expect(view.dataAt('/items'), [
        {'name': 'A'},
        {'name': 'B2'},
      ]);
      expect(_fieldTexts(tester), ['A', 'B2']);
    });

    // surface-view.test.tsx:843
    testWidgets('gives an @index prop the item index plus the offset', (
      tester,
    ) async {
      await renderStandard(
        tester,
        [
          _grid('pos', '/items'),
          {
            'id': 'pos',
            'component': 'Text',
            'text': {
              '@call': '@index',
              'args': {'offset': 1},
            },
          },
        ],
        data: {
          'items': [
            {'name': 'A'},
            {'name': 'B'},
          ],
        },
      );
      expect(_textsAround(tester, '1'), ['1', '2']);
    });

    // surface-view.test.tsx:857
    testWidgets('forwards the userMessage of an item, read from a relative '
        '@path', (tester) async {
      final view = await renderStandard(
        tester,
        [
          _grid('card', '/items'),
          {
            'id': 'card',
            'component': 'Button',
            'label': 'pick p1',
            'onClick': {
              'event': {
                'name': 'pick',
                'userMessage': {'@path': 'note'},
              },
            },
          },
        ],
        data: {
          'items': [
            {'note': 'I pick A'},
            {'note': 'I pick B'},
          ],
        },
      );
      await tester.tap(find.text('pick p1').at(1));
      await tester.pump();
      final action = view.actions.single;
      expect(action.name, 'pick');
      expect(action.surfaceId, testSurfaceId);
      expect(action.sourceComponentId, 'card');
      expect(action.userMessage, 'I pick B');
      // Upstream's `{ productId: "p1" }` is the Card's own argument.
      expect(action.context, isEmpty);
    });

    for (final (label, data) in [
      ('missing', null),
      ('empty', {'items': <Object?>[]}),
    ]) {
      // surface-view.test.tsx:887
      testWidgets('renders nothing for a $label list', (tester) async {
        await renderStandard(tester, data: data, [
          _grid('row', '/items'),
          _label('row', 'name'),
        ]);
        // `childElementCount` 0: the Column holds no child.
        expect(find.byType(CssFlex), findsOneWidget);
        expect(find.byType(CssFlexItem), findsNothing);
        expect(find.byType(RichText), findsNothing);
      });
    }

    // surface-view.test.tsx:900, the other items
    testWidgets('cuts a cycle between two templates and keeps the other '
        'items', (tester) async {
      await renderStandard(
        tester,
        _templateCycle,
        data: {
          'items': [
            {'name': 'A'},
          ],
        },
      );
      expect(find.text('A', findRichText: true), findsOneWidget);
    });

    // surface-view.test.tsx:900, the alert
    testWidgets('names the cycle between two templates in an alert', (
      tester,
    ) async {
      await renderStandard(
        tester,
        _templateCycle,
        data: {
          'items': [
            {'name': 'A'},
          ],
        },
      );
      _expectAlert('cyclic reference to b');
      // The cycle's fallback passes no retry (SurfaceView.tsx:316-323).
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('beyond surface-view.test.tsx (ours)', () {
    // surface-view.test.tsx:347 with the keyboard: a field the student is
    // typing in keeps its focus while the agent streams its siblings and a
    // new revision of it (INV-032: a remounted editor drops the keyboard).
    testWidgets('a focused field keeps its focus while siblings stream in', (
      tester,
    ) async {
      final view = await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b'],
        },
        {'id': 'a', 'component': 'TextField', 'label': 'Alpha'},
      ]);
      await tester.enterText(find.byType(EditableText), 'typed');
      await tester.pump();
      final focus = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      expect(focus.hasFocus, isTrue);
      await view.update([
        agentComponents([
          {'id': 'b', 'component': 'TextField', 'label': 'Beta'},
          {'id': 'a', 'component': 'TextField', 'label': 'Alpha 2'},
        ]),
      ]);
      expect(
        tester.widget<EditableText>(find.byType(EditableText).first).focusNode,
        same(focus),
      );
      expect(focus.hasFocus, isTrue);
      expect(_fieldTexts(tester), ['typed', '']);
    });
  });
}

/// surface-view.test.tsx:419: a Bomb beside a Card that sends an event (a
/// Button here; upstream's calls an app function, not ours).
const List<Map<String, Object?>> _bombAndSibling = [
  {
    'id': 'root',
    'component': 'Column',
    'children': ['bomb', 'ok'],
  },
  {'id': 'bomb', 'component': 'Badge', 'label': 'b1'},
  {
    'id': 'ok',
    'component': 'Button',
    'label': 'pick ok',
    'onClick': {
      'event': {'name': 'pick'},
    },
  },
];

/// surface-view.test.tsx:900: two Sections whose templates name each other
/// (Columns here), beside a Text read from the first item.
const List<Map<String, Object?>> _templateCycle = [
  {
    'id': 'root',
    'component': 'Column',
    'children': ['a', 'ok'],
  },
  {
    'id': 'a',
    'component': 'Column',
    'children': {'componentId': 'b', 'path': '/items'},
  },
  {
    'id': 'b',
    'component': 'Column',
    'children': {'componentId': 'a', 'path': '/items'},
  },
  {
    'id': 'ok',
    'component': 'Text',
    'text': {'@path': '/items/0/name'},
  },
];
