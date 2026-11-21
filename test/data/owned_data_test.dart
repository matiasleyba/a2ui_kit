// User-owned data, after CopilotKit's surface-manager.test.ts: what the
// user enters wins over the agent's later writes.

import 'dart:convert';
import 'dart:ui' show CheckedState;

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/inputs/choices.dart';
import 'package:a2ui_kit/src/data/owned_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

Map<String, Object?> _data(String path, Object? value) => {
  'version': '1.0',
  'updateDataModel': {'surfaceId': testSurfaceId, 'path': path, 'value': value},
};

Map<String, Object?> _components(List<Map<String, Object?>> components) => {
  'version': '1.0',
  'updateComponents': {'surfaceId': testSurfaceId, 'components': components},
};

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  group('agent writes after the user typed', () {
    Future<(TestSurfaces, A2uiUserOwnedData)> pumpNameField(
      WidgetTester tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        [
          {
            'id': 'root',
            'component': 'TextField',
            'label': 'Name',
            'value': {'@path': '/form/name'},
          },
        ],
        data: {
          'form': {'name': '', 'plan': 'free'},
        },
      );
      return (surfaces, A2uiUserOwnedData(surfaces.processor));
    }

    testWidgets('a write above the field keeps what the user typed', (
      tester,
    ) async {
      final (surfaces, owned) = await pumpNameField(tester);
      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.pump();

      surfaces.apply(
        owned.filterMessages([
          _data('/form', {'name': '', 'plan': 'team'}),
        ]),
      );
      await tester.pump();
      expect(surfaces.surface.dataModel.get('/form'), {
        'name': 'Ada',
        'plan': 'team',
      });
      expect(_fieldText(tester), 'Ada');
    });

    testWidgets('a write to the path, or below it, is dropped', (tester) async {
      final (surfaces, owned) = await pumpNameField(tester);
      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.pump();

      final kept = owned.filterMessages([
        _data('/form/name', 'Bob'),
        _data('/form/name/first', 'B'),
        _data('/form/plan', 'team'),
      ]);
      expect(kept, hasLength(1));
      surfaces.apply(kept);
      await tester.pump();
      expect(surfaces.surface.dataModel.get('/form/name'), 'Ada');
      expect(surfaces.surface.dataModel.get('/form/plan'), 'team');
      expect(_fieldText(tester), 'Ada');
    });

    testWidgets('a root write and a delete keep it too', (tester) async {
      final (surfaces, owned) = await pumpNameField(tester);
      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.pump();

      surfaces.apply(
        owned.filterMessages([
          {
            'version': '1.0',
            'updateDataModel': {
              'surfaceId': testSurfaceId,
              'value': {'other': 1},
            },
          },
        ]),
      );
      expect(surfaces.surface.dataModel.get('/'), {
        'other': 1,
        'form': {'name': 'Ada'},
      });
      surfaces.apply(owned.filterMessages([_data('/form', null)]));
      expect(surfaces.surface.dataModel.get('/form'), {'name': 'Ada'});
    });

    testWidgets('JSON text messages are filtered as maps', (tester) async {
      final (surfaces, owned) = await pumpNameField(tester);
      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.pump();
      expect(
        owned.filterMessages([jsonEncode(_data('/form/name', 'Bob'))]),
        isEmpty,
      );
    });

    testWidgets('without a user edit, the agent writes freely', (tester) async {
      final (surfaces, owned) = await pumpNameField(tester);
      surfaces.apply(owned.filterMessages([_data('/form/name', 'Bob')]));
      await tester.pump();
      expect(_fieldText(tester), 'Bob');
      expect(A2uiUserOwnedData.ownedValuesOf(surfaces.surface), isEmpty);
    });

    testWidgets('ownership ends when the surface is deleted', (tester) async {
      final (surfaces, owned) = await pumpNameField(tester);
      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.pump();
      expect(A2uiUserOwnedData.ownedValuesOf(surfaces.surface), {
        '/form/name': 'Ada',
      });

      final kept = owned.filterMessages([
        {
          'version': '1.0',
          'deleteSurface': {'surfaceId': testSurfaceId},
        },
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': testSurfaceId,
            'catalogId': kA2uiPlaygroundCatalogId,
          },
        },
        _data('/form/name', 'Bob'),
      ]);
      expect(kept, hasLength(3));
      surfaces.apply(kept);
      expect(surfaces.surface.dataModel.get('/form/name'), 'Bob');
      expect(A2uiUserOwnedData.ownedValuesOf(surfaces.surface), isEmpty);
    });

    testWidgets('a createSurface for a surface that exists keeps ownership', (
      tester,
    ) async {
      final (surfaces, owned) = await pumpNameField(tester);
      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.pump();

      // a2ui_core refuses the second create, so the surface the user typed
      // into stays, and so does what they typed (CopilotKit resets owned
      // values on deleteSurface only).
      final kept = owned.filterMessages([
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': testSurfaceId,
            'catalogId': kA2uiPlaygroundCatalogId,
          },
        },
        _data('/form/name', 'Bob'),
      ]);
      expect(kept, hasLength(1));
      surfaces.apply(kept);
      await tester.pump();
      expect(surfaces.errors, isNotEmpty);
      expect(surfaces.surface.dataModel.get('/form/name'), 'Ada');
      expect(_fieldText(tester), 'Ada');
      expect(A2uiUserOwnedData.ownedValuesOf(surfaces.surface), {
        '/form/name': 'Ada',
      });
    });

    testWidgets('a v1.0 write without a value passes as sent', (tester) async {
      final (surfaces, owned) = await pumpNameField(tester);
      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.pump();

      final noValue = {
        'version': '1.0',
        'updateDataModel': {'surfaceId': testSurfaceId, 'path': '/form'},
      };
      final kept = owned.filterMessages([noValue]);
      expect(kept, [same(noValue)]);
      surfaces.apply(kept);
      await tester.pump();
      // The processor refuses it: from v1.0 a deletion sends `value: null`.
      expect(surfaces.errors, isNotEmpty);
      expect(surfaces.surface.dataModel.get('/form'), {
        'name': 'Ada',
        'plan': 'free',
      });
    });
  });

  testWidgets('setOwnedValue writes and marks a path for an override', (
    tester,
  ) async {
    final surfaces = await pumpComponents(tester, [
      {'id': 'root', 'component': 'Text', 'text': 'x'},
    ]);
    A2uiUserOwnedData.setOwnedValue(surfaces.surface, '/picked/', 3);
    expect(surfaces.surface.dataModel.get('/picked'), 3);
    final owned = A2uiUserOwnedData(surfaces.processor);
    expect(owned.filterMessages([_data('/picked', 4)]), isEmpty);
  });

  group('a literal value the user edited', () {
    testWidgets('a TextField keeps the edit when the literal changes', (
      tester,
    ) async {
      final surfaces = await pumpComponents(tester, [
        {'id': 'root', 'component': 'TextField', 'value': 'Ada'},
      ]);
      surfaces.apply([
        _components([
          {'id': 'root', 'component': 'TextField', 'value': 'Grace'},
        ]),
      ]);
      await tester.pump();
      expect(_fieldText(tester), 'Grace');

      await tester.enterText(find.byType(TextField), 'Mine');
      await tester.pump();
      surfaces.apply([
        _components([
          {'id': 'root', 'component': 'TextField', 'value': 'Bob'},
        ]),
      ]);
      await tester.pump();
      expect(_fieldText(tester), 'Mine');
    });

    testWidgets('a Select keeps the choice when the literal changes', (
      tester,
    ) async {
      Map<String, Object?> select(String value) => {
        'id': 'root',
        'component': 'Select',
        'options': ['Free', 'Team', 'Pro'],
        'value': value,
      };
      final surfaces = await pumpComponents(tester, [select('Free')]);
      await tester.tap(find.text('Free'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Team').last);
      await tester.pumpAndSettle();
      surfaces.apply([
        _components([select('Pro')]),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Pro'), findsNothing);
    });

    testWidgets('a CheckBox and a RadioGroup keep theirs', (tester) async {
      List<Map<String, Object?>> components({
        required bool agreed,
        required String size,
      }) => [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['box', 'radio'],
        },
        {
          'id': 'box',
          'component': 'CheckBox',
          'label': 'Agree',
          'value': agreed,
        },
        {
          'id': 'radio',
          'component': 'RadioGroup',
          'options': ['S', 'M', 'L'],
          'value': size,
        },
      ];
      final surfaces = await pumpComponents(
        tester,
        components(agreed: false, size: 'S'),
      );
      await tester.tap(find.text('Agree'));
      await tester.tap(find.text('M'));
      await tester.pump();
      surfaces.apply([_components(components(agreed: false, size: 'L'))]);
      await tester.pump();
      expect(
        tester.widget<CheckMark>(find.byType(CheckMark).first).checked,
        isTrue,
      );
      expect(
        tester.getSemantics(find.text('M')).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
    });
  });

  group('choosing the option already chosen', () {
    testWidgets('a Select writes nothing', (tester) async {
      final surfaces = await pumpComponents(
        tester,
        [
          {
            'id': 'root',
            'component': 'Select',
            'options': ['Free', 'Team'],
            'value': {'@path': '/plan'},
          },
        ],
        data: {'plan': 'Free'},
      );
      await tester.tap(find.text('Free'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free').last);
      await tester.pumpAndSettle();
      expect(A2uiUserOwnedData.ownedValuesOf(surfaces.surface), isEmpty);
    });

    testWidgets('a RadioGroup writes nothing', (tester) async {
      final surfaces = await pumpComponents(
        tester,
        [
          {
            'id': 'root',
            'component': 'RadioGroup',
            'options': ['S', 'M'],
            'value': {'@path': '/size'},
          },
        ],
        data: {'size': 'S'},
      );
      await tester.tap(find.text('S'));
      await tester.pump();
      expect(A2uiUserOwnedData.ownedValuesOf(surfaces.surface), isEmpty);
      await tester.tap(find.text('M'));
      await tester.pump();
      expect(A2uiUserOwnedData.ownedValuesOf(surfaces.surface), {'/size': 'M'});
    });
  });

  group('the merge, as CopilotKit writes it', () {
    test('normalizes paths and finds what is at or below one', () {
      expect(normalizePath('/a/b/'), '/a/b');
      expect(normalizePath(''), '/');
      expect(normalizePath('/'), '/');
      expect(isAtOrBelow('/a/b', '/a'), isTrue);
      expect(isAtOrBelow('/a', '/a'), isTrue);
      expect(isAtOrBelow('/ab', '/a'), isFalse);
      expect(isAtOrBelow('/x', '/'), isTrue);
    });

    test('writes owned values back into a write above them', () {
      final owned = {'/form/name': 'Ada', '/list/1': 'b'};
      expect(mergeOwnedValues(owned, '/form/name', 'Bob'), isNull);
      expect(mergeOwnedValues(owned, '/form/name/x', 1), isNull);
      expect(mergeOwnedValues(owned, '/form', {'age': 3})!.value, {
        'age': 3,
        'name': 'Ada',
      });
      expect(mergeOwnedValues(owned, '/list', ['x'])!.value, ['x', 'b']);
      expect(mergeOwnedValues(owned, '/', null)!.value, {
        'form': {'name': 'Ada'},
        'list': [null, 'b'],
      });
    });
  });
}
