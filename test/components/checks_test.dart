// CopilotKit's firstFailedCheck (shared standard/checks.ts), as a Button
// shows it: its tooltip is the failed check, and an error blocks it.

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

Map<String, Object?> _button(List<Map<String, Object?>> checks) => {
  'id': 'root',
  'component': 'Button',
  'label': 'Go',
  'onClick': {
    'event': {'name': 'go'},
  },
  'checks': checks,
};

Map<String, Object?> _required(String path) => {
  '@call': 'required',
  'args': {
    'value': {'@path': path},
  },
};

String? _tooltip(WidgetTester tester) {
  final tooltips = find.byType(Tooltip);
  if (tooltips.evaluate().isEmpty) return null;
  return tester.widget<Tooltip>(tooltips).message;
}

Future<int> _actionsAfterTap(WidgetTester tester, TestSurfaces surfaces) async {
  final before = surfaces.actions.length;
  await tester.tap(find.text('Go'));
  await tester.pump();
  return surfaces.actions.length - before;
}

void main() {
  testWidgets('a condition bound to missing data passes until it is known', (
    tester,
  ) async {
    final surfaces = await pumpComponents(tester, [
      _button([
        {
          'condition': {'@path': '/agreed'},
          'message': 'Please agree',
        },
      ]),
    ]);
    expect(_tooltip(tester), isNull);
    expect(await _actionsAfterTap(tester, surfaces), 1);

    surfaces.setData('/agreed', false);
    await tester.pump();
    expect(_tooltip(tester), 'Please agree');
    expect(await _actionsAfterTap(tester, surfaces), 0);

    surfaces.setData('/agreed', true);
    await tester.pump();
    expect(_tooltip(tester), isNull);
    expect(await _actionsAfterTap(tester, surfaces), 1);
  });

  testWidgets('a condition that resolves to null is skipped', (tester) async {
    final surfaces = await pumpComponents(
      tester,
      [
        _button([
          {
            'condition': {'@path': '/agreed'},
            'message': 'Never shown',
          },
        ]),
      ],
      data: {'agreed': null},
    );
    expect(_tooltip(tester), isNull);
    expect(await _actionsAfterTap(tester, surfaces), 1);
  });

  testWidgets('a rule without a condition passes', (tester) async {
    final surfaces = await pumpComponents(tester, [
      _button([
        {'message': 'Never shown'},
      ]),
    ]);
    expect(_tooltip(tester), isNull);
    expect(await _actionsAfterTap(tester, surfaces), 1);
  });

  testWidgets("a false condition shows the check's message, else the default", (
    tester,
  ) async {
    await pumpComponents(tester, [
      _button([
        {'condition': false},
      ]),
    ]);
    expect(_tooltip(tester), 'Invalid value');
  });

  testWidgets("the check's message wins over the validator's", (tester) async {
    await pumpComponents(
      tester,
      [
        _button([
          {'condition': _required('/a'), 'message': 'Fill in A'},
        ]),
      ],
      data: {'a': ''},
    );
    expect(_tooltip(tester), 'Fill in A');
  });

  testWidgets("without a message of its own, the validator's shows", (
    tester,
  ) async {
    await pumpComponents(
      tester,
      [
        _button([
          {'condition': _required('/a')},
        ]),
      ],
      data: {'a': ''},
    );
    expect(_tooltip(tester), 'Required');
  });

  testWidgets('an error after a warning wins; a warning alone informs', (
    tester,
  ) async {
    final surfaces = await pumpComponents(
      tester,
      [
        _button([
          {
            'condition': {'valid': false, 'severity': 'warning'},
            'message': 'Careful',
          },
          {'condition': _required('/a'), 'message': 'Fill in A'},
        ]),
      ],
      data: {'a': ''},
    );
    expect(_tooltip(tester), 'Fill in A');
    expect(await _actionsAfterTap(tester, surfaces), 0);

    surfaces.setData('/a', 'x');
    await tester.pump();
    expect(_tooltip(tester), 'Careful');
    expect(await _actionsAfterTap(tester, surfaces), 1);
  });

  testWidgets('a condition of another type passes, as CopilotKit allows none', (
    tester,
  ) async {
    final surfaces = await pumpComponents(
      tester,
      [
        _button([
          {
            'condition': {'@path': '/name'},
            'message': 'Strings are not conditions',
          },
        ]),
      ],
      data: {'name': ''},
    );
    expect(_tooltip(tester), isNull);
    expect(await _actionsAfterTap(tester, surfaces), 1);
  });

  testWidgets('an override builder reads the failed check, code included', (
    tester,
  ) async {
    FailedCheck? failed;
    await pumpComponents(
      tester,
      [
        _button([
          {
            'condition': {
              'valid': false,
              'severity': 'info',
              'code': 'hint',
              'message': 'From the result',
            },
          },
          {
            'condition': {'valid': false, 'severity': 'warning'},
            'message': 'A later warning',
          },
        ]),
      ],
      catalog: a2uiKitCatalog(
        options: A2uiKitOptions(
          overrides: {
            'Button': (context, node, props, buildChild) {
              failed = firstFailedCheck(node);
              return const SizedBox();
            },
          },
        ),
      ),
    );
    expect(
      failed,
      const FailedCheck(
        message: 'From the result',
        severity: A2uiCheckSeverity.info,
        code: 'hint',
      ),
    );
  });
}
