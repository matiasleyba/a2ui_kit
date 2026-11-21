// Parity tests of the operations this package's catalog must accept or
// refuse, ported from the outcome cases of
// packages/shared/src/generative-ui/__tests__/validate-operation.test.ts
// (MIT, (c) Atai Barkai). Each test names its upstream line.
//
// Parity for: Button, Column, Select, Text, (engine)
//
// Upstream checks an operation against a test-made manifest (ProductGrid,
// ProductCard) and reads `"ok"` or a reason. The reason's wording is
// CopilotKit's validator; the outcome is ours, since a false refusal is a
// part of the answer the student never sees. Here the operations go
// through a2ui_core's processor with the standard catalog, as an app's
// messages do, and the outcome is read: "ok" is no error (the app's
// reports, read after they settle) and the component or data in the
// model; a refusal is an error from any stage and nothing applied. The
// test-made components map to standard ones: ProductGrid to a Column,
// ProductCard's data props to a Text's `text` (a Select's `options` or a
// Chart's `data` for a value inside a list), its required `price` to a
// Title's `text`, its event to a Button's `onClick`, Frame's single
// `child` to a Button's. The operations take the README app's way in
// (`ReadmeApp`: the operation validator, the id normalizer, the guard of
// what the user typed, the processor), so a fix that adds a stage there
// reaches these tests.
//
// RULEBOOK section 6, item 2: an operation's outcome is ours, the v0.9
// spellings' too (whether a v0.9 operation reaches the student). Ported
// outcomes, by line:
// - version and kind: :93, :99, :105, :111;
// - createSurface: :124, :129, :153, :159, :171, :188, :197;
// - updateComponents: :207, :227, :252, :258, :268, :274, :295, :327,
//   :343;
// - templates: :406, :412, :426 (its empty segments), :437;
// - data props: :454, :461, :481, :503;
// - events and calls: :580, :593, :608, :619, :631, :668, :683, :689;
// - data writes: :702, :708, :712, :728, :734;
// - :748, the agent's `callRendererFunction` refused while the agent path
//   is off (here every function is `rendererOnly`).
//
// Not ours (CopilotKit's validator and manager options, not this package):
// the reasons' wording; the `createdSurfaces` bookkeeping (:165, :219) and
// the listed catalogs (:135); the target lists (:355-:399); the declared
// app functions (:660, :677, :631's app-function case and the :768 block,
// `describe.skipIf`); prototype keys (:426's `__proto__` segment, :717,
// :931-:956); the `isPathBinding` and `isIndexCall` helpers (:959, :968).
//
// Later phase (no Dart yet): :543-:573, typed child references inside a
// list (Tabs).

import 'package:a2ui_core/a2ui_core.dart'
    show RendererFunctionResponseMessage, RendererToAgentMessage, SurfaceModel;
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart'
    show ReadmeApp, fakeUrlLauncher, portQueue, testSurfaceId;

/// The surface's creation: upstream's `create`.
const Map<String, Object?> _create = {
  'version': '1.0',
  'createSurface': {
    'surfaceId': testSurfaceId,
    'catalogId': kA2uiStandardCatalogId,
  },
};

/// The README's app with the standard catalog after the agent sent
/// [_create] (unless [create] is false) and [operations], once every report
/// has settled. The operations take the app's way in
/// (test/helpers/readme_app.dart), so a stage a fix adds there (before the
/// processor, or a processor option) refuses here too.
Future<ReadmeApp> _ingest(
  List<Map<String, Object?>> operations, {
  bool create = true,
}) async {
  final app = ReadmeApp(a2uiKitStandardCatalog());
  addTearDown(app.dispose);
  app.receive([if (create) _create, ...operations]);
  await pumpEventQueue();
  return app;
}

/// The surface [id] of [app] as its processor holds it now (null once
/// deleted or never made).
SurfaceModel<ComponentImplementation>? _surfaceOf(
  ReadmeApp app, [
  String id = testSurfaceId,
]) => app.processor.model.getSurface(id);

/// Upstream's `reasonOf(...)` is a refusal: the app reported an error, from
/// whatever stage refused (read after it settled), and the component [id]
/// is not in the model.
void _expectRefused(ReadmeApp app, [String id = 'c1']) {
  expect(app.errors, isNotEmpty);
  expect(_surfaceOf(app)?.componentsModel.get(id), isNull);
}

/// An `updateComponents` of [components].
Map<String, Object?> _update(List<Map<String, Object?>> components) => {
  'version': '1.0',
  'updateComponents': {'surfaceId': testSurfaceId, 'components': components},
};

/// An `updateDataModel` of [value] at [path].
Map<String, Object?> _data(String path, Object? value) => {
  'version': '1.0',
  'updateDataModel': {'surfaceId': testSurfaceId, 'path': path, 'value': value},
};

/// Upstream's `reasonOf(...)` is "ok": nothing refused or reported, and
/// each component of [ids] in the model of the surface [surfaceId].
void _expectOk(
  ReadmeApp app, [
  List<String> ids = const [],
  String surfaceId = testSurfaceId,
]) {
  expect(app.errors, isEmpty);
  for (final id in ids) {
    expect(
      _surfaceOf(app, surfaceId)?.componentsModel.get(id),
      isNotNull,
      reason: id,
    );
  }
}

/// One of upstream's refusals: the app refuses [operations] (sent after
/// [_create] unless [create] is false), the component [id] is not in the
/// model, and [unchanged], when given, holds of the app after them (what
/// the refused operation would have changed). [queued] is the
/// `port-queue` reason when our code accepts it.
void _refuses(
  String what,
  List<Map<String, Object?>> operations, {
  String id = 'c1',
  bool create = true,
  void Function(ReadmeApp app)? unchanged,
  String? queued,
}) {
  test('refuses $what', skip: queued != null && portQueue(queued), () async {
    final app = await _ingest(operations, create: create);
    _expectRefused(app, id);
    unchanged?.call(app);
  });
}

/// One of upstream's acceptances: the app takes [operations] (after
/// [_create] unless [create] is false) with no error, each component of
/// [ids] in the surface [surfaceId], and [applied], when given, holds of
/// the app after them. [queued] is the `port-queue` reason when our code
/// refuses it.
void _accepts(
  String what,
  List<Map<String, Object?>> operations, {
  List<String> ids = const [],
  String surfaceId = testSurfaceId,
  bool create = true,
  void Function(ReadmeApp app)? applied,
  String? queued,
}) {
  test('accepts $what', skip: queued != null && portQueue(queued), () async {
    final app = await _ingest(operations, create: create);
    _expectOk(app, ids, surfaceId);
    expect(_surfaceOf(app, surfaceId), isNotNull);
    applied?.call(app);
  });
}

/// A `createSurface` of the second surface, "s2", with [fields].
Map<String, Object?> _create2([Map<String, Object?> fields = const {}]) => {
  'version': '1.0',
  'createSurface': {'surfaceId': 's2', ...fields},
};

/// The surface "s" is still there.
void _surfaceKept(ReadmeApp app) => expect(_surfaceOf(app), isNotNull);

/// No surface "s2" was made.
void _noSurface2(ReadmeApp app) => expect(_surfaceOf(app, 's2'), isNull);

/// A Text whose `text` is [value]: upstream's `card({ name: value })`.
Map<String, Object?> _text(Object? value) => {
  'id': 'c1',
  'component': 'Text',
  'text': value,
};

/// A Button whose `onClick` is the event [event]: upstream's
/// `eventReason(event)`.
Map<String, Object?> _button(Map<String, Object?> event) => {
  'id': 'c1',
  'component': 'Button',
  'label': 'Choose',
  'onClick': {'event': event},
};

void main() {
  group('validateOperation: what our catalog accepts', () {
    // validate-operation.test.ts:227
    test('accepts a container with child references and children with '
        'literal and bound props and a functionCall event', () async {
      _expectOk(
        await _ingest([
          _update([
            {
              'id': 'root',
              'component': 'Column',
              'children': ['c1', 'c2'],
            },
            _text({'@path': '/prices/c1'}),
            {
              'id': 'c2',
              'component': 'Button',
              'label': 'Docs',
              'onClick': {
                'functionCall': {
                  '@call': 'openUrl',
                  'args': {'url': 'https://example.com'},
                },
              },
            },
          ]),
        ]),
        ['root', 'c1', 'c2'],
      );
    });

    // validate-operation.test.ts:274, the catalogId and accessibility
    test('accepts the component envelope: its own catalogId and a bound '
        'accessibility', () async {
      _expectOk(
        await _ingest([
          _update([
            {
              ..._text('Totals'),
              'catalogId': kA2uiStandardCatalogId,
              'accessibility': {
                'label': {'@path': '/name'},
                'description': {
                  '@call': 'formatString',
                  'args': {'value': r'Adds ${/name}'},
                },
                'live': 'polite',
                'hidden': false,
              },
            },
          ]),
        ]),
        ['c1'],
      );
      _expectOk(
        await _ingest([
          _update([
            {..._text('Totals'), 'metadata': <String, Object?>{}},
          ]),
        ]),
        ['c1'],
      );
    });

    // validate-operation.test.ts:274, the metadata extension (a2ui_core
    // refuses the key 'acme.track', not a UAX #31 identifier, and with it
    // the component: the validator passes it and the README's
    // A2uiIdNormalizer rewrites it, its value kept, INV-260)
    test('accepts metadata with an extension', () async {
      final app = await _ingest([
        _update([
          {
            ..._text('Totals'),
            'metadata': {
              'extensions': {'acme.track': 'cart'},
            },
          },
        ]),
      ]);
      _expectOk(app, ['c1']);
      // Nothing of it is lost: the value is kept, under the rewritten key.
      expect(_surfaceOf(app)?.componentsModel.get('c1')?.metadata, {
        'extensions': {'acme_track': 'cart'},
      });
    });

    // validate-operation.test.ts:454
    test('accepts the @index call, with and without an offset', () async {
      _expectOk(
        await _ingest([
          _update([
            _text({'@call': '@index'}),
          ]),
        ]),
        ['c1'],
      );
      _expectOk(
        await _ingest([
          _update([
            _text({
              '@call': '@index',
              'args': {'offset': 1},
            }),
          ]),
        ]),
        ['c1'],
      );
    });

    // validate-operation.test.ts:461
    test('accepts calc and series, the CopilotKit value functions', () async {
      _expectOk(
        await _ingest([
          _update([
            _text({
              '@call': 'calc',
              'args': {
                'expression': 'seats * 29',
                'seats': {'@path': '/seats'},
              },
            }),
          ]),
        ]),
        ['c1'],
      );
      _expectOk(
        await _ingest([
          _update([
            _text({
              '@call': 'series',
              'args': {
                'count': 3,
                'item': {'n': r'${i}'},
              },
            }),
          ]),
        ]),
        ['c1'],
      );
    });

    // validate-operation.test.ts:481
    test('accepts a basic function value, also nested and with bound '
        'args', () async {
      _expectOk(
        await _ingest([
          _update([
            _text({
              '@call': 'formatCurrency',
              'args': {
                'value': {'@path': '/price'},
                'currency': 'EUR',
              },
            }),
          ]),
        ]),
        ['c1'],
      );
      // `name: [{ label: formatString }]`: a Select's option label.
      _expectOk(
        await _ingest([
          _update([
            {
              'id': 'c1',
              'component': 'Select',
              'options': [
                {
                  'value': 'n',
                  'label': {
                    '@call': 'formatString',
                    'args': {'value': r'${/n}'},
                  },
                },
              ],
            },
          ]),
        ]),
        ['c1'],
      );
    });

    // validate-operation.test.ts:580
    test('accepts an event with a userMessage string or binding, and a bound '
        'context', () async {
      _expectOk(
        await _ingest([
          _update([
            _button({
              'name': 'choose',
              'userMessage': 'I pick the Team plan',
              'context': {
                'seats': {'@path': '/seats'},
                'plan': 'team',
              },
            }),
          ]),
        ]),
        ['c1'],
      );
      _expectOk(
        await _ingest([
          _update([
            _button({
              'name': 'choose',
              'userMessage': {'@path': '/message'},
            }),
          ]),
        ]),
        ['c1'],
      );
    });

    // validate-operation.test.ts:619
    test('accepts a function value as the userMessage, not a number', () async {
      _expectOk(
        await _ingest([
          _update([
            _button({
              'name': 'choose',
              'userMessage': {
                '@call': 'formatString',
                'args': {'value': r'Pick ${/n}'},
              },
            }),
          ]),
        ]),
        ['c1'],
      );
      _expectRefused(
        await _ingest([
          _update([
            _button({'name': 'choose', 'userMessage': 1}),
          ]),
        ]),
      );
    });

    // validate-operation.test.ts:631 (its app-function case is not ours)
    test('accepts @index and a basic function in the event context', () async {
      _expectOk(
        await _ingest([
          _update([
            _button({
              'name': 'choose',
              'context': {
                'row': {'@call': '@index'},
              },
            }),
          ]),
        ]),
        ['c1'],
      );
      _expectOk(
        await _ingest([
          _update([
            _button({
              'name': 'choose',
              'context': {
                'label': {
                  '@call': 'formatString',
                  'args': {'value': r'${/name}'},
                },
              },
            }),
          ]),
        ]),
        ['c1'],
      );
    });

    // validate-operation.test.ts:668
    test('accepts a basic function in an event binding', () async {
      _expectOk(
        await _ingest([
          _update([
            {
              'id': 'c1',
              'component': 'Button',
              'label': 'Docs',
              'onClick': {
                'functionCall': {
                  '@call': 'openUrl',
                  'args': {'url': 'https://example.com'},
                },
              },
            },
          ]),
        ]),
        ['c1'],
      );
    });

    // validate-operation.test.ts:708
    test('accepts null to delete the key at a path', () async {
      final app = await _ingest([
        _data('/cart', {'item': 1, 'other': 2}),
        _data('/cart/item', null),
      ]);
      _expectOk(app);
      expect(_surfaceOf(app)!.dataModel.get('/cart'), {'other': 2});
    });

    // validate-operation.test.ts:712
    test('accepts writes under /app like any other data-model path', () async {
      final app = await _ingest([_data('/app/cart', 1)]);
      _expectOk(app);
      expect(_surfaceOf(app)!.dataModel.get('/app/cart'), 1);
      _expectOk(
        await _ingest([
          _data('/', {'app': <String, Object?>{}}),
        ]),
      );
    });
  });

  group('the surface manager on the same operations', () {
    // surface-manager.test.ts:188
    test('rejects an invalid operation and keeps applying its '
        'siblings', () async {
      final app = await _ingest([
        _update([
          {'id': 'x', 'component': 'Nope'},
        ]),
        _update([
          {'id': 'root', 'component': 'Column', 'children': <String>[]},
        ]),
      ]);
      // `clientRejected` is `[{index: 1, reason: 'unknown component
      // "Nope"'}]`: the bad update, named by its component.
      expect(app.errors, hasLength(1));
      expect(app.errors.single.message, contains('Nope'));
      expect(_surfaceOf(app)!.componentsModel.get('x'), isNull);
      expect(_surfaceOf(app)!.componentsModel.get('root'), isNotNull);
    });

    // surface-manager.test.ts:200
    test('rejects a whole update when a literal prop has the wrong '
        'type', () async {
      // ProductCard's `price: z.number()` given "free": a Text's
      // `minLines` (a number, a binding or a call) given "free".
      final app = await _ingest([
        _update([
          {'id': 'c1', 'component': 'Text', 'text': 'A', 'minLines': 2},
        ]),
        _update([
          {'id': 'c1', 'component': 'Text', 'text': 'A', 'minLines': 'free'},
        ]),
      ]);
      expect(
        _surfaceOf(app)!.componentsModel.get('c1')?.properties['minLines'],
        2,
      );
      // `reason` toMatch(/price/): the refusal names the prop.
      expect(app.errors, hasLength(1));
      expect(app.errors.single.message, contains('minLines'));
    });

    // surface-manager.test.ts:348
    test('deletes the key at the path for a null value', () async {
      final app = await _ingest([
        _data('/form', {'email': 'a@x.io', 'name': 'Ada'}),
        _data('/form/name', null),
      ]);
      _expectOk(app);
      expect(_surfaceOf(app)!.dataModel.get('/form'), {'email': 'a@x.io'});
    });

    // surface-manager.test.ts:519
    test('rejects a data write through a primitive without throwing', () async {
      final app = await _ingest([
        _data('/a', 1),
        _data('/a/b', 2),
        _update([
          {'id': 'root', 'component': 'Column', 'children': <String>[]},
        ]),
      ]);
      // `clientRejected` indexes `[2]`: the write through the primitive,
      // not the write of `/a`, which stays 1.
      expect(app.errors, hasLength(1));
      expect(app.errors.single.message, contains('/a/b'));
      expect(_surfaceOf(app)!.dataModel.get('/a'), 1);
      expect(_surfaceOf(app)!.componentsModel.get('root'), isNotNull);
    });
  });

  group('validateOperation: what our catalog refuses', () {
    // validate-operation.test.ts:295, each case: a foreign catalog, a bad
    // accessibility, malformed metadata. The outcome: the component is
    // refused (the wording is CopilotKit's validator's).
    for (final MapEntry(key: what, value: envelope) in {
      'a foreign catalogId': {'catalogId': 'other'},
      'an accessibility that is no object': {'accessibility': 'x'},
      'an unknown accessibility key': {
        'accessibility': {'role': 'img'},
      },
      'a live that is no politeness': {
        'accessibility': {'live': 'loud'},
      },
      'a hidden that is no boolean': {
        'accessibility': {'hidden': 'yes'},
      },
      'a label that is no string': {
        'accessibility': {'label': 1},
      },
      'a v0.9 path binding as the label': {
        'accessibility': {
          'label': {'path': '/name'},
        },
      },
      'openUrl as the label': {
        'accessibility': {
          'label': {'@call': 'openUrl'},
        },
      },
      'metadata extensions that are no object': {
        'metadata': {'extensions': 1},
      },
    }.entries) {
      test('refuses an envelope with $what', () async {
        _expectRefused(
          await _ingest([
            _update([
              {..._text('Totals'), ...envelope},
            ]),
          ]),
        );
      });
    }

    // validate-operation.test.ts:631, its third case
    test('refuses an app function in the event context', () async {
      _expectRefused(
        await _ingest([
          _update([
            _button({
              'name': 'choose',
              'context': {
                'row': {'@call': 'addToCart'},
              },
            }),
          ]),
        ]),
      );
    });

    // validate-operation.test.ts:748 (an `it.skipIf` that runs while the
    // agent path is off, as it is here: every function is
    // `allowedCallers: rendererOnly`)
    test('refuses every callRendererFunction, whatever it names', () async {
      final launcher = fakeUrlLauncher();
      final replies = <RendererToAgentMessage>[];
      final app = ReadmeApp(a2uiKitStandardCatalog(), toAgent: replies.add);
      addTearDown(app.dispose);
      Map<String, Object?> call(String id, Map<String, Object?> function) => {
        'version': '1.0',
        'callRendererFunction': {
          'surfaceId': testSurfaceId,
          'functionCallId': id,
          'callFunction': function,
        },
      };
      final refused = app.receive([
        _create,
        call('f1', {
          '@call': 'addToCart',
          'args': {'productId': 'p1'},
        }),
        call('f2', {'@call': 'formatNumber'}),
        call('f3', <String, Object?>{}),
        // An agent able to call openUrl would open a page with no tap from
        // the student.
        call('f4', {
          '@call': 'openUrl',
          'args': {'url': 'https://example.com'},
        }),
      ]);
      await pumpEventQueue();
      // Each call is refused (an error reply, or refused outright), none
      // answered with a value, and nothing opens.
      final answered = <String>{
        for (final reply in replies)
          if (reply case RendererFunctionResponseMessage(:final response))
            if (response.error == null) response.functionCallId,
      };
      expect(answered, isEmpty);
      final refusedIds = <String>{
        for (final reply in replies)
          if (reply case RendererFunctionResponseMessage(:final response))
            if (response.error != null) response.functionCallId,
      };
      expect(refusedIds.length + refused.length, 4);
      expect(launcher.launches, isEmpty);
    });
  });

  // The rest of upstream's outcomes (RULEBOOK section 6, item 2: an
  // operation's validation outcome is ours). The v0.9 spellings are ours
  // too: whether a v0.9 operation reaches the student is an outcome.
  group('validateOperation: version and kind', () {
    // validate-operation.test.ts:93
    _refuses('the pre-release v1.0 spelling', [
      {
        'version': 'v1.0',
        'deleteSurface': {'surfaceId': testSurfaceId},
      },
    ], unchanged: _surfaceKept);

    // validate-operation.test.ts:99
    _refuses('a v0.9 operation', [
      {
        'version': 'v0.9',
        'deleteSurface': {'surfaceId': testSurfaceId},
      },
    ], unchanged: _surfaceKept);

    // validate-operation.test.ts:105
    _refuses('an operation without a version', [
      {
        'deleteSurface': {'surfaceId': testSurfaceId},
      },
    ], unchanged: _surfaceKept);

    // validate-operation.test.ts:111
    _refuses('an operation with no kind', [
      {'version': '1.0'},
    ]);
    _refuses('an operation with several kinds', [
      {
        'version': '1.0',
        'deleteSurface': {'surfaceId': testSurfaceId},
        'updateDataModel': {'surfaceId': testSurfaceId, 'value': 1},
      },
    ], unchanged: _surfaceKept);
  });

  group('validateOperation: createSurface', () {
    // validate-operation.test.ts:124
    _accepts('a new surface without a catalogId', [_create2()]);
    _accepts("a new surface with the catalog's own catalogId", [
      _create2({'catalogId': kA2uiStandardCatalogId}),
    ]);

    // validate-operation.test.ts:129
    _refuses('a new surface of a foreign catalog', [
      _create2({'catalogId': 'other'}),
    ], unchanged: _noSurface2);

    // validate-operation.test.ts:153
    _refuses('a createSurface without a surfaceId', [
      {
        'version': '1.0',
        'createSurface': {'catalogId': kA2uiStandardCatalogId},
      },
    ]);

    // validate-operation.test.ts:159, surface-manager.test.ts:373 ("exists")
    _refuses(
      'a createSurface of an existing surface',
      [
        _update([
          {'id': 'root', 'component': 'Column', 'children': <String>[]},
        ]),
        _create,
      ],
      unchanged: (app) =>
          expect(_surfaceOf(app)?.componentsModel.get('root'), isNotNull),
    );

    // validate-operation.test.ts:171
    _accepts(
      'inline components and a data model',
      [
        _create2({
          'catalogId': kA2uiStandardCatalogId,
          'dataModel': {
            'products': [
              {'name': 'Lamp'},
            ],
          },
          'components': [
            {
              'id': 'root',
              'component': 'Column',
              'children': {'componentId': 'c1', 'path': '/products'},
            },
          ],
        }),
      ],
      ids: ['root'],
      surfaceId: 's2',
    );

    // surface-manager.test.ts:279: ProductGrid's bound `title` is a Text's
    // bound `text`.
    _accepts(
      'an inline createSurface, applying its data model and components',
      [
        _create2({
          'catalogId': kA2uiStandardCatalogId,
          'dataModel': {'title': 'Picks'},
          'components': [
            {
              'id': 'root',
              'component': 'Text',
              'text': {'@path': '/title'},
            },
          ],
        }),
      ],
      ids: ['root'],
      surfaceId: 's2',
      applied: (app) {
        final surface = _surfaceOf(app, 's2')!;
        expect(surface.dataModel.get('/'), {'title': 'Picks'});
        expect(surface.componentsModel.get('root')?.properties, {
          'text': {'@path': '/title'},
        });
      },
    );

    // validate-operation.test.ts:188
    _refuses('an inline component of an unknown type', [
      _create2({
        'catalogId': kA2uiStandardCatalogId,
        'components': [
          {'id': 'x', 'component': 'Nope'},
        ],
      }),
    ], unchanged: _noSurface2);
    _refuses('an empty list of inline components', [
      _create2({
        'catalogId': kA2uiStandardCatalogId,
        'components': <Object?>[],
      }),
    ], unchanged: _noSurface2);

    // validate-operation.test.ts:197
    for (final (name, dataModel) in [
      ('a list', [1]),
      ('a string', 's'),
      ('null', null),
    ]) {
      _refuses('an inline data model that is $name, not an object', [
        _create2({'catalogId': kA2uiStandardCatalogId, 'dataModel': dataModel}),
      ], unchanged: _noSurface2);
    }

    // surface-manager.test.ts:315: ProductCard's `price: "free"` is a
    // Text's `minLines: "free"`.
    _refuses(
      'an inline createSurface with a bad component, making no surface, '
      'and the update that follows',
      [
        _create2({
          'catalogId': kA2uiStandardCatalogId,
          'dataModel': {'title': 'Picks'},
          'components': [
            {'id': 'c1', 'component': 'Text', 'text': 'A', 'minLines': 'free'},
          ],
        }),
        {
          'version': '1.0',
          'updateComponents': {
            'surfaceId': 's2',
            'components': [
              {'id': 'root', 'component': 'Column', 'children': <String>[]},
            ],
          },
        },
      ],
      unchanged: (app) {
        _noSurface2(app);
        // Both are refused: the create, then the update of no surface.
        expect(app.errors, hasLength(2));
      },
    );
  });

  group('validateOperation: surface updates', () {
    // validate-operation.test.ts:207
    _refuses(
      'an update of a surface that does not exist',
      [
        {
          'version': '1.0',
          'updateComponents': {
            'surfaceId': 'missing',
            'components': [
              {'id': 'root', 'component': 'Column'},
            ],
          },
        },
      ],
      id: 'root',
      unchanged: (app) => expect(_surfaceOf(app, 'missing'), isNull),
    );

    // validate-operation.test.ts:252
    _refuses('a v0.9 path binding in a data prop', [
      _update([
        _text({'path': '/prices/c1'}),
      ]),
    ]);

    // validate-operation.test.ts:258 (its unknown component: the surface
    // manager's :188 above)
    _refuses('an unknown prop', [
      _update([
        {'id': 'c1', 'component': 'Text', 'text': 'A', 'nope': 'red'},
      ]),
    ]);
    // ProductCard's required `price` left out: a Title's required `text`.
    _refuses('a component without a required prop', [
      _update([
        {'id': 'c1', 'component': 'Title'},
      ]),
    ]);

    // validate-operation.test.ts:268
    _refuses(
      'a component without an id',
      [
        _update([
          {'component': 'Column'},
        ]),
      ],
      unchanged: (app) =>
          expect(_surfaceOf(app)?.componentsModel.get('root'), isNull),
    );

    // validate-operation.test.ts:327
    _refuses('a list slot that is no list', [
      _update([
        {'id': 'root', 'component': 'Column', 'children': 'c1'},
      ]),
    ], id: 'root');
    _refuses('a component that is its own child', [
      _update([
        {
          'id': 'root',
          'component': 'Column',
          'children': ['root'],
        },
      ]),
    ], id: 'root');
    // Frame's single `child`: a Button's.
    _refuses('a list in a single slot', [
      _update([
        {
          'id': 'f',
          'component': 'Button',
          'child': ['a'],
        },
        {'id': 'a', 'component': 'Text', 'text': 'A'},
      ]),
    ], id: 'f');

    // validate-operation.test.ts:343
    _refuses('an id twice in one update', [
      _update([
        {'id': 'root', 'component': 'Column'},
        {'id': 'root', 'component': 'Column'},
      ]),
    ], id: 'root');
  });

  group('validateOperation: templates', () {
    Map<String, Object?> grid(Object? children) => _update([
      {'id': 'root', 'component': 'Column', 'children': children},
      {'id': 'card', 'component': 'Text', 'text': 'A'},
    ]);

    // validate-operation.test.ts:406
    for (final path in ['/products', 'items/0/variants']) {
      _accepts(
        'a template with the path $path in a list slot',
        [
          grid({'componentId': 'card', 'path': path}),
        ],
        ids: ['root'],
      );
    }

    // validate-operation.test.ts:412: Frame's single `child`, a Button's.
    _refuses('a template in a single slot', [
      _update([
        {
          'id': 'f',
          'component': 'Button',
          'child': {'componentId': 'card', 'path': '/products'},
        },
        {'id': 'card', 'component': 'Text', 'text': 'A'},
      ]),
    ], id: 'f');

    // validate-operation.test.ts:426, its empty segments (its
    // `__proto__` segment: a prototype key, not ours)
    for (final path in ['/', 'a//b', 'items/']) {
      _refuses('a template path $path with an empty segment', [
        grid({'componentId': 'card', 'path': path}),
      ], id: 'root');
    }

    // validate-operation.test.ts:437
    _refuses('a template with an empty componentId', [
      grid({'componentId': '', 'path': '/products'}),
    ], id: 'root');
    _refuses('a template with an empty path', [
      grid({'componentId': 'card', 'path': ''}),
    ], id: 'root');
    _refuses('a template with an extra key', [
      grid({'componentId': 'card', 'path': '/products', 'limit': 3}),
    ], id: 'root');
    _refuses('a template that repeats the node itself', [
      grid({'componentId': 'root', 'path': '/products'}),
    ], id: 'root');
  });

  group('validateOperation: data props', () {
    // validate-operation.test.ts:503: every other function call in a data
    // prop, ProductCard's `name` a Text's `text`.
    for (final (what, value) in <(String, Object?)>[
      (
        'a function that is not a basic one',
        {'@call': 'formatPrice', 'args': <String, Object?>{}},
      ),
      (
        'an @index offset that is no number',
        {
          '@call': '@index',
          'args': {'offset': '1'},
        },
      ),
      (
        'a function named with "call", not "@call"',
        {'call': 'addToCart', 'args': <String, Object?>{}},
      ),
      (
        'openUrl, which runs only from an event',
        {
          '@call': 'openUrl',
          'args': {'url': 'https://x'},
        },
      ),
      (
        'args that are no object',
        {
          '@call': 'formatNumber',
          'args': [1],
        },
      ),
    ]) {
      _refuses('$what in a data prop', [
        _update([_text(value)]),
      ]);
    }
    // `[{ label: { "@call": "formatPrice" } }]`: a Select's option label.
    _refuses('a function that is not a basic one, nested in a data prop', [
      _update([
        {
          'id': 'c1',
          'component': 'Select',
          'options': [
            {
              'value': 'n',
              'label': {'@call': 'formatPrice'},
            },
          ],
        },
      ]),
    ]);
    // `{ nested: { functionCall } }`: an event binding as a value, in a
    // Chart's data row (whose values are `z.unknown()` upstream, so only
    // the event binding makes it wrong).
    _refuses('an event binding as a value', [
      _update([
        {
          'id': 'c1',
          'component': 'Chart',
          'xKey': 'x',
          'data': [
            {
              'x': 'a',
              'y': {
                'nested': {
                  'functionCall': {'@call': 'addToCart'},
                },
              },
            },
          ],
        },
      ]),
    ]);
  });

  group('validateOperation: event bindings', () {
    // validate-operation.test.ts:593
    _refuses('an event without a name', [
      _update([_button(<String, Object?>{})]),
    ]);
    _refuses('an onClick that is no action object', [
      _update([
        {
          'id': 'c1',
          'component': 'Button',
          'label': 'Choose',
          'onClick': 'addToCart',
        },
      ]),
    ]);

    // validate-operation.test.ts:608
    _refuses('a v0.9 path binding as the userMessage', [
      _update([
        _button({
          'name': 'choose',
          'userMessage': {'path': '/m'},
        }),
      ]),
    ]);
    _refuses('a v0.9 path binding in the event context', [
      _update([
        _button({
          'name': 'choose',
          'context': {
            'seats': {'path': '/seats'},
          },
        }),
      ]),
    ]);
  });

  group('validateOperation: function-call bindings', () {
    Map<String, Object?> call(Map<String, Object?> functionCall) => _update([
      {
        'id': 'c1',
        'component': 'Button',
        'label': 'Choose',
        'onClick': {'functionCall': functionCall},
      },
    ]);

    // validate-operation.test.ts:683
    _refuses('a function call named with "call", not "@call"', [
      call({'call': 'addToCart'}),
    ]);

    // validate-operation.test.ts:689
    _refuses('function-call args that are no object', [
      call({
        '@call': 'addToCart',
        'args': [1],
      }),
    ]);
    _refuses('a v0.9 path binding in function-call args', [
      call({
        '@call': 'addToCart',
        'args': {
          'id': {'path': '/id'},
        },
      }),
    ]);
  });

  group('validateOperation: updateDataModel', () {
    // validate-operation.test.ts:702: a write with no value (upstream asks
    // for `"value": null` to delete).
    _refuses('a data write without a value', [
      _data('/a', 1),
      {
        'version': '1.0',
        'updateDataModel': {'surfaceId': testSurfaceId, 'path': '/a'},
      },
    ], unchanged: (app) => expect(_surfaceOf(app)!.dataModel.get('/a'), 1));

    // validate-operation.test.ts:728, surface-manager.test.ts:553
    for (final path in ['//a/b', '/a//b', '/a/', '//app/x']) {
      _refuses(
        'a data write to $path, a path with an empty segment',
        [_data(path, 1)],
        unchanged: (app) {
          // Nothing written: the data model is as a new surface has it.
          expect(
            _surfaceOf(app)!.dataModel.get('/'),
            anyOf(isNull, equals(<String, Object?>{})),
          );
        },
      );
    }

    // validate-operation.test.ts:734
    for (final (name, value) in <(String, Object?)>[
      ('a number', 5),
      ('a list', [1]),
      ('a string', 's'),
      ('null', null),
    ]) {
      _refuses(
        'a root write at "/" whose value is $name, not an object',
        [
          _data('/', {'kept': 1}),
          _data('/', value),
        ],
        unchanged: (app) =>
            expect(_surfaceOf(app)!.dataModel.get('/'), {'kept': 1}),
      );
      _refuses(
        'a root write with no path whose value is $name, not an object',
        [
          _data('/', {'kept': 1}),
          {
            'version': '1.0',
            'updateDataModel': {'surfaceId': testSurfaceId, 'value': value},
          },
        ],
        unchanged: (app) =>
            expect(_surfaceOf(app)!.dataModel.get('/'), {'kept': 1}),
      );
    }
    _accepts(
      'a root write with no path whose value is an object',
      [
        {
          'version': '1.0',
          'updateDataModel': {
            'surfaceId': testSurfaceId,
            'value': {'items': <Object?>[]},
          },
        },
      ],
      applied: (app) =>
          expect(_surfaceOf(app)!.dataModel.get('/'), {'items': <Object?>[]}),
    );
  });
}
