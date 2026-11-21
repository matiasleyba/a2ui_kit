// Parity tests of CopilotKit's user-owned paths, ported from the
// "user-owned paths" block (lines 822-914) of
// packages/core/src/generative-ui/__tests__/surface-manager.test.ts (MIT,
// (c) Atai Barkai). Each test names its upstream line.
//
// Parity for: (engine)
//
// CopilotKit's `GenerativeUISurfaceManager` keeps what the user entered
// (`setOwnedValue`) over the agent's later writes. Here that is
// `A2uiUserOwnedData`: `setOwnedValue` writes and owns a path, and the
// agent's messages pass through `filterMessages` before the processor
// applies them, as the README's app does (`ReadmeApp`,
// test/helpers/readme_app.dart, whose way in every message here takes).
// Upstream's `surface.clientRejected` (the writes the client refused) is
// the errors the app reports.
//
// Ported elsewhere: the outcomes of surface-manager.test.ts:188, :200, :279,
// :315, :348, :373's "exists" case, :519 and :553's `//app/x`, through the
// same app, in validate_operation_test.dart.
//
// Not ours (CopilotKit's surface manager, not this package's layer): the
// other tests of surface-manager.test.ts (catalog ids, ingesting a growing
// operation list, the wording of rejections, surface ids used once after a
// delete, bound props, state, targets, describeSurfaces' `target`, review
// regressions), and :872 "keeps owned values when the surface is rebuilt":
// the manager rebuilds a surface when a later `ingest` brings an operation
// list that does not extend the earlier one; a2ui_core has no such rebuild
// (an app deletes a surface, which ends ownership, as CopilotKit's delete
// does).
//
// Not ported (bound to internals):
// - surface-manager.test.ts:904 "throws on a prototype path and does not
//   own it": `Object.prototype` pollution through a `__proto__` segment, a
//   hazard of JavaScript objects; a Dart map has no prototype.

import 'package:a2ui_core/a2ui_core.dart' show SurfaceModel;
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart' show ReadmeApp, testSurfaceId;

/// The README's app after upstream's `managerWith([create, ...ops])`.
ReadmeApp _managerWith(List<Map<String, Object?>> operations) {
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
    ...operations,
  ]);
  return app;
}

/// The surface the agent made.
SurfaceModel<ComponentImplementation> _surfaceOf(ReadmeApp app) =>
    app.surfaces[testSurfaceId]!;

/// Upstream's `data(path, value)`: an agent's `updateDataModel`.
Map<String, Object?> _data(String path, Object? value) => {
  'version': '1.0',
  'updateDataModel': {'surfaceId': testSurfaceId, 'path': path, 'value': value},
};

/// Upstream's `surface.clientRejected` is `[]`: nothing was refused or
/// reported, read once a2ui_core has sent its surface errors (a microtask
/// later).
Future<void> _expectNothingRefused(ReadmeApp app) async {
  await pumpEventQueue();
  expect(app.errors, isEmpty);
}

void main() {
  group('user-owned paths', () {
    // surface-manager.test.ts:836
    test('writes the value and ignores agent writes to the path or below '
        'it', () async {
      final app = _managerWith([
        _data('/form', {'email': 'agent@x.io'}),
      ]);
      A2uiUserOwnedData.setOwnedValue(
        _surfaceOf(app),
        '/form/email',
        'me@x.io',
      );
      expect(_surfaceOf(app).dataModel.get('/form/email'), 'me@x.io');

      app.receive([_data('/form/email', 'other@x.io')]);
      expect(_surfaceOf(app).dataModel.get('/form/email'), 'me@x.io');
      await _expectNothingRefused(app);
    });

    // surface-manager.test.ts:847
    test('keeps the owned child when the agent writes a parent, and applies '
        'the rest', () {
      final app = _managerWith([
        _data('/form', {'email': 'agent@x.io'}),
      ]);
      A2uiUserOwnedData.setOwnedValue(
        _surfaceOf(app),
        '/form/email',
        'me@x.io',
      );

      app.receive([
        _data('/form', {'email': 'other@x.io', 'name': 'Ada'}),
      ]);
      expect(_surfaceOf(app).dataModel.get('/form'), {
        'email': 'me@x.io',
        'name': 'Ada',
      });

      app.receive([
        {
          'version': '1.0',
          'updateDataModel': {
            'surfaceId': testSurfaceId,
            'value': {'title': 'New'},
          },
        },
      ]);
      expect(_surfaceOf(app).dataModel.get('/'), {
        'title': 'New',
        'form': {'email': 'me@x.io'},
      });
    });

    // surface-manager.test.ts:881
    test('keeps the owned value when the agent deletes its parent with '
        'null', () async {
      final app = _managerWith([
        _data('/form', {'email': 'agent@x.io', 'name': 'Ada'}),
      ]);
      A2uiUserOwnedData.setOwnedValue(
        _surfaceOf(app),
        '/form/email',
        'me@x.io',
      );

      app.receive([_data('/form', null)]);
      expect(_surfaceOf(app).dataModel.get('/form'), {'email': 'me@x.io'});
      await _expectNothingRefused(app);
    });

    // surface-manager.test.ts:893, the owned values (its `target` is
    // CopilotKit's, not ours)
    test('lists the owned values in describeSurfaces', () {
      final app = _managerWith([]);
      A2uiUserOwnedData.setOwnedValue(
        _surfaceOf(app),
        '/form/email',
        'me@x.io',
      );
      expect(A2uiUserOwnedData.ownedValuesOf(_surfaceOf(app)), {
        '/form/email': 'me@x.io',
      });
    });
  });
}
