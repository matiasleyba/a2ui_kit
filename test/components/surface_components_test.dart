// Widget tests of what a surface shows in place of a part it can't show,
// after CopilotKit's default node fallback (react-core
// src/v2/generative-ui/host.tsx:116-150), and of the operation validator's
// own behaviour beyond the ported outcomes.

import 'package:a2ui_core/a2ui_core.dart' show ComponentModel, ComponentNode;
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/chart/plot.dart' show ChartPlot;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart' show pumpComponents, rectOfText;
import '../helpers/parity.dart';

/// A Title bound to a number: its props fail, so the fallback shows,
/// beside a Text after it.
const List<Map<String, Object?>> _badAndSibling = [
  {
    'id': 'root',
    'component': 'Column',
    'children': ['bad', 'after'],
  },
  {
    'id': 'bad',
    'component': 'Title',
    'text': {'@path': '/n'},
  },
  {'id': 'after', 'component': 'Text', 'text': 'After'},
];

/// The fallback's text.
const String _message =
    'Couldn’t display this part: invalid props (text: Value `42` is not of '
    'type `string` at path #root["text"])';

/// A paint call in a fill or stroke of [color] (compared as ARGB32).
PaintPatternPredicate _paintedIn(Color color) =>
    (method, args) => args.any(
      (arg) => arg is Paint && arg.color.toARGB32() == color.toARGB32(),
    );

/// Whether the test-only Bomb throws.
bool _armed = false;

/// The standard catalog with a Bomb in place of the Badge, which throws
/// while [_armed].
const A2uiKitOptions _withBomb = A2uiKitOptions(
  look: A2uiKitLook.standard,
  overrides: {'Badge': _bomb},
);

/// How many times the Bomb was built.
int _builds = 0;

Widget _bomb(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  _builds++;
  if (_armed) throw StateError('exploded');
  return const Text('survived');
}

void main() {
  group('the node fallback', () {
    // The host's literal colours (host.tsx:128-130), the same in every
    // look and brightness: a test per look (RULEBOOK section 6, item 2).
    for (final (name, theme, brightness) in [
      (
        'standard light',
        A2uiKitTheme.standard(Brightness.light),
        Brightness.light,
      ),
      (
        'standard dark',
        A2uiKitTheme.standard(Brightness.dark),
        Brightness.dark,
      ),
      (
        'playground light',
        A2uiKitTheme.playground(Brightness.light),
        Brightness.light,
      ),
      (
        'playground dark',
        A2uiKitTheme.playground(Brightness.dark),
        Brightness.dark,
      ),
    ]) {
      testWidgets("paints CopilotKit's host colours in the $name look", (
        tester,
      ) async {
        await renderStandard(
          tester,
          _badAndSibling,
          data: {'n': 42},
          theme: theme,
          brightness: brightness,
        );
        expect(
          paintedPage(tester),
          paints
            ..something(paintedFill(const Color(0xfffef2f2)))
            ..something(_paintedIn(const Color(0xfffca5a5))),
        );
        final text = tester.widget<RichText>(
          find.descendant(
            of: find.text(_message),
            matching: find.byType(RichText),
          ),
        );
        expect(text.text.style?.color?.toARGB32(), 0xff991b1b);
        // `fontSize: 13` (host.tsx:132).
        expect(text.text.style?.fontSize, 13);
      });
    }

    testWidgets('is a block: the width of its column, padded 8px by 12px, '
        'with its siblings below it', (tester) async {
      await renderStandard(tester, _badAndSibling, data: {'n': 42});
      final box = tester.getRect(
        find
            .ancestor(
              of: find.text(_message),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final text = tester.getRect(find.text(_message));
      expect(box.width, 360);
      // `padding: 8px 12px` (host.tsx:133), inside a 1px border's box.
      expect(text.left - box.left, 12);
      expect(text.top - box.top, 8);
      expect(box.bottom - text.bottom, 8);
      expect(rectOfText(tester, 'After').top, greaterThan(box.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits 320px at text scale 2.0', (tester) async {
      await renderStandard(
        tester,
        _badAndSibling,
        data: {'n': 42},
        width: 320,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(alertsContaining('invalid props'), findsOne);
      expect(find.text('After', findRichText: true), findsOneWidget);
    });

    testWidgets('retries by keyboard: Tab reaches Retry and Enter presses '
        'it', (tester) async {
      _armed = true;
      addTearDown(() => _armed = false);
      await renderStandard(tester, options: _withBomb, [
        {'id': 'root', 'component': 'Badge', 'label': 'b'},
      ]);
      expect(alertsContaining('exploded'), findsOne);
      _armed = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('survived'), findsOneWidget);
      expect(alerts(), findsNothing);
    });

    // boundaries.tsx:388-395: the boundary resets for a new revision of
    // the node (its wire props), not for new data. The wrong fix this
    // rules out: trying the builder again on every build, which a data
    // write the node reads causes.
    testWidgets('keeps the fallback through a data write, trying the '
        'component once and reporting it once', (tester) async {
      _armed = true;
      _builds = 0;
      addTearDown(() => _armed = false);
      final view = await renderStandard(
        tester,
        options: _withBomb,
        [
          {
            'id': 'root',
            'component': 'Badge',
            'label': {'@path': '/label'},
          },
        ],
        data: {'label': 'one'},
      );
      expect(_builds, 1);
      await view.update([agentWrite('/label', 'two')]);
      await tester.pump();
      expect(_builds, 1);
      expect(alertsContaining('exploded'), findsOne);
      expect([
        for (final error in view.errors)
          if (error.code == 'RENDER_FAILED') error,
      ], hasLength(1));
    });

    // SurfaceView.tsx:327-339: a node of a type no catalog has. The
    // validator refuses one from the agent, so it is put in the model
    // past it, as surface_view_test.dart's self-reference is.
    testWidgets('stands in for a child of an unknown type, beside its '
        'siblings', (tester) async {
      final view = await renderStandard(tester, []);
      view.surface.componentsModel
        ..addComponent(ComponentModel('x', 'Nope', const {}))
        ..addComponent(ComponentModel('ok', 'Text', const {'text': 'Fine'}))
        ..addComponent(
          ComponentModel('root', 'Column', const {
            'children': ['x', 'ok'],
          }),
        );
      await view.update([agentWrite('/tick', 1)]);
      expect(alertsContaining('unknown component "Nope"'), findsOne);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Fine', findRichText: true), findsOneWidget);
    });

    // boundaries.tsx:33-39: "a new revision that throws the same error"
    // is not reported again; a different one is.
    testWidgets('reports a throw once while it comes back the same', (
      tester,
    ) async {
      _armed = true;
      _builds = 0;
      addTearDown(() => _armed = false);
      final view = await renderStandard(tester, options: _withBomb, [
        {'id': 'root', 'component': 'Badge', 'label': 'v1'},
      ]);
      await view.update([
        agentComponents([
          {'id': 'root', 'component': 'Badge', 'label': 'v2'},
        ]),
      ]);
      await tester.pump();
      // The new revision was tried, and threw the same.
      expect(_builds, 2);
      expect([
        for (final error in view.errors)
          if (error.code == 'RENDER_FAILED') error,
      ], hasLength(1));
    });

    testWidgets('names the Retry a button', (tester) async {
      _armed = true;
      addTearDown(() => _armed = false);
      await renderStandard(tester, options: _withBomb, [
        {'id': 'root', 'component': 'Badge', 'label': 'b'},
      ]);
      expect(
        find.semantics.byPredicate(
          (node) => node.flagsCollection.isButton && node.label == 'Retry',
        ),
        findsOne,
      );
    });

    // RULEBOOK section 0: bound chart rows the schema refuses (a string
    // `y`, a missing key: definitions/charts.ts:5-11) show the alert, as
    // CopilotKit's render check does for every component, the
    // playground's included.
    testWidgets('stands in for a chart whose bound rows its schema '
        'refuses', (tester) async {
      await pumpComponents(
        tester,
        [
          {
            'id': 'root',
            'component': 'LineChart',
            'data': {'@path': '/rows'},
          },
        ],
        data: {
          'rows': [
            {'x': 0, 'y': 1},
            {'x': 25, 'y': 'n/a'},
            {'x': 30},
          ],
        },
      );
      await tester.pumpAndSettle();
      // Each issue by its path, as Zod's are (`formatIssues`, shared
      // catalog/schema.ts:92-107): the string `y`, the missing one.
      expect(alertsContaining('invalid props (data.1.y: '), findsOne);
      expect(alertsContaining('; data.2.y: '), findsOne);
      expect(find.byType(ChartPlot), findsNothing);
    });

    // boundaries.tsx:33-39, :91-108: a failure is reported once while it
    // comes back the same. The wrong fix this rules out: reporting on
    // every build, which a write of the bound colour causes while the
    // text stays wrong.
    testWidgets('reports invalid props once while they stay invalid', (
      tester,
    ) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Title',
            'text': {'@path': '/n'},
            'color': {'@path': '/c'},
          },
        ],
        data: {'n': 42, 'c': 'secondary'},
      );
      await view.update([agentWrite('/c', 'danger')]);
      await tester.pump();
      final reports = [
        for (final error in view.errors)
          if (error.message.contains('invalid props')) error,
      ];
      expect(reports, hasLength(1));
      expect(reports.single.code, 'INVALID_PROPS');
      // Valid again, then invalid again: a new report.
      await view.update([agentWrite('/n', 'Totals')]);
      expect(alerts(), findsNothing);
      expect(find.text('Totals', findRichText: true), findsOneWidget);
      await view.update([agentWrite('/n', 7)]);
      await tester.pump();
      expect([
        for (final error in view.errors)
          if (error.message.contains('invalid props')) error,
      ], hasLength(2));
    });
  });

  group('the operation validator (ours)', () {
    test('takes JSON text messages as the processor does', () async {
      final app = ReadmeApp(a2uiKitStandardCatalog());
      addTearDown(app.dispose);
      const create =
          '{"version": "1.0", "createSurface": {"surfaceId": "s", '
          '"catalogId": "$kA2uiStandardCatalogId"}}';
      const update =
          '{"version": "1.0", "updateComponents": {"surfaceId": "s", '
          '"components": [{"id": "c1", "component": "Text", "nope": 1}]}}';
      app.receive([create, update]);
      await pumpEventQueue();
      expect(app.surfaces, contains(testSurfaceId));
      expect(app.errors.single.message, contains('unknown prop "nope"'));
      expect(app.errors.single.code, 'VALIDATION_FAILED');
      expect(app.errors.single.surfaceId, testSurfaceId);
    });

    // validate-operation.test.ts:533 reads the reason; the outcome alone
    // can't tell it there, since its binding calls addToCart, which no
    // data prop may call either. A basic value function inside the
    // binding, in a Chart's data row (any value to a2ui_core), is refused
    // for the binding alone (the wrong fix this rules out: checking only
    // the calls inside it, which leaves the Chart in the model).
    test('refuses an event binding as a value, whatever it calls', () async {
      final app = ReadmeApp(a2uiKitStandardCatalog());
      addTearDown(app.dispose);
      app.receive([
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': testSurfaceId,
            'catalogId': kA2uiStandardCatalogId,
          },
        },
        agentComponents([
          {
            'id': 'c1',
            'component': 'Chart',
            'xKey': 'x',
            'data': [
              {
                'x': 'a',
                'y': {
                  'nested': {
                    'functionCall': {
                      '@call': 'formatNumber',
                      'args': {'value': 1},
                    },
                  },
                },
              },
            ],
          },
        ]),
      ]);
      await pumpEventQueue();
      expect(app.surfaces[testSurfaceId]!.componentsModel.get('c1'), isNull);
      expect(app.errors, hasLength(1));
      expect(
        app.errors.single.message,
        contains('an event binding is not a value'),
      );
    });

    // Each operation of a batch is checked against the surfaces the ones
    // before it leave, as CopilotKit's manager applies them one by one
    // (surface-manager.ts:884-893). The wrong fix this rules out: checking
    // the batch against the surfaces before it, which refuses the second
    // createSurface as one of a surface that exists.
    test('takes a surface deleted and created again in one batch', () async {
      final app = ReadmeApp(a2uiKitStandardCatalog());
      addTearDown(app.dispose);
      final create = {
        'version': '1.0',
        'createSurface': {
          'surfaceId': testSurfaceId,
          'catalogId': kA2uiStandardCatalogId,
        },
      };
      app
        ..receive([create])
        ..receive([
          {
            'version': '1.0',
            'deleteSurface': {'surfaceId': testSurfaceId},
          },
          create,
          agentComponents([
            {'id': 'root', 'component': 'Column', 'children': <String>[]},
          ]),
        ]);
      await pumpEventQueue();
      expect(app.errors, isEmpty);
      expect(
        app.processor.model
            .getSurface(testSurfaceId)
            ?.componentsModel
            .get('root'),
        isNotNull,
      );
    });

    test('refuses an update after its surface is deleted in the same '
        'batch', () async {
      final app = ReadmeApp(a2uiKitStandardCatalog());
      addTearDown(app.dispose);
      app.receive([
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': testSurfaceId,
            'catalogId': kA2uiStandardCatalogId,
          },
        },
        {
          'version': '1.0',
          'deleteSurface': {'surfaceId': testSurfaceId},
        },
        agentComponents([
          {'id': 'root', 'component': 'Column', 'children': <String>[]},
        ]),
      ]);
      await pumpEventQueue();
      expect(app.errors.single.message, contains('does not exist'));
    });

    test('keeps the id an agent wrote in its reasons, before the id '
        'normaliser rewrites it', () async {
      final app = ReadmeApp(a2uiKitStandardCatalog());
      addTearDown(app.dispose);
      app.receive([
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': testSurfaceId,
            'catalogId': kA2uiStandardCatalogId,
          },
        },
        agentComponents([
          {
            'id': 'spacer-l',
            'component': 'Column',
            'children': ['spacer-l'],
          },
        ]),
      ]);
      await pumpEventQueue();
      expect(
        app.errors.single.message,
        'component "spacer-l": children: a component cannot be its own '
        'child',
      );
    });
  });
}
