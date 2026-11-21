// failedFunctionValueOf: the problem CopilotKit's renderer finds in a
// component's props when a function value cannot be computed
// (packages/react-core/src/v2/generative-ui/SurfaceView.tsx:457-538,
// `useModelDataProps`), which the invalid-props fallback names
// (dynamic-values.test.tsx:130, :203: "text: value must be a number").
// Each test asks it of the node as the node guard does. The node is the only
// child of a Column whose override keeps it: the node guard shows a failing
// node's fallback without calling its builder, so the node can't be read
// from an override of its own component.

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart' show KitNode;
import 'package:a2ui_kit/src/functions/failed_value.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// Renders [components] with the one whose id is `root` as the only child
/// of a Column, and gives what [failedFunctionValueOf] says of that child's
/// node when called (its data read at that time).
Future<(ParitySurface, String? Function())> _render(
  WidgetTester tester,
  List<Map<String, Object?>> components, {
  Map<String, Object?>? data,
}) async {
  KitNode? subject;
  final view = await renderStandard(
    tester,
    [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['subject'],
      },
      for (final component in components)
        if (component['id'] == 'root')
          {...component, 'id': 'subject'}
        else
          component,
    ],
    data: data,
    options: A2uiKitOptions(
      look: A2uiKitLook.standard,
      overrides: {
        'Column': (context, node, props, buildChild) {
          subject = props.children('children').single;
          return const SizedBox();
        },
      },
    ),
  );
  return (view, () => failedFunctionValueOf(subject!));
}

void main() {
  testWidgets('names the prop and the message of a function value that '
      'fails', (tester) async {
    final (_, problem) = await _render(tester, [
      {
        'id': 'root',
        'component': 'Text',
        'text': {
          '@call': 'formatNumber',
          'args': {'value': 'many'},
        },
      },
    ]);
    expect(problem(), 'text: value must be a number');
  });

  testWidgets('gives none once the data the value read arrives', (
    tester,
  ) async {
    final (view, problem) = await _render(
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
    expect(problem(), 'text: value must be a number');
    await view.update([agentWrite('/price', 1234)]);
    expect(problem(), isNull);
  });

  testWidgets("gives the message of the call that failed first, an arg's own", (
    tester,
  ) async {
    final (_, problem) = await _render(tester, [
      {
        'id': 'root',
        'component': 'Text',
        'text': {
          '@call': 'pluralize',
          'args': {
            'value': {
              '@call': 'formatNumber',
              'args': {'value': 'x'},
            },
            'other': 'items',
          },
        },
      },
    ]);
    expect(problem(), 'text: value must be a number');
  });

  testWidgets('takes the props in the order the agent wrote them', (
    tester,
  ) async {
    final (_, problem) = await _render(tester, [
      {
        'id': 'root',
        'component': 'TextField',
        'placeholder': {
          '@call': 'formatString',
          'args': {'value': r'${'},
        },
        'label': {
          '@call': 'formatNumber',
          'args': {'value': 'x'},
        },
      },
    ]);
    expect(problem(), r'placeholder: formatString: unclosed ${');
  });

  testWidgets('takes @index outside a template for no failure', (tester) async {
    final (_, problem) = await _render(tester, [
      {
        'id': 'root',
        'component': 'Text',
        'text': {'@call': '@index'},
      },
    ]);
    expect(problem(), isNull);
  });

  testWidgets('leaves the events and the envelope out, and opens nothing', (
    tester,
  ) async {
    final launcher = fakeUrlLauncher();
    final (_, problem) = await _render(tester, [
      {
        'id': 'root',
        'component': 'Button',
        'label': 'Docs',
        'onClick': {
          'functionCall': {
            '@call': 'openUrl',
            'args': {'url': 'https://example.com/'},
          },
        },
        'accessibility': {
          'label': {
            '@call': 'formatNumber',
            'args': {'value': 'x'},
          },
        },
      },
    ]);
    expect(problem(), isNull);
    await tester.pump();
    expect(launcher.launches, isEmpty);
  });

  // dynamic-values.test.tsx:130's alert (SurfaceView.tsx:740-753): the
  // node guard shows the problem in the component's place. Its report is
  // checked by the queued parity test, which waits on the engine's own.
  testWidgets('is the invalid-props fallback the node guard shows', (
    tester,
  ) async {
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
    expect(
      alertsContaining('invalid props (text: value must be a number)'),
      findsOne,
    );
    expect(find.text('Retry'), findsNothing);
    expect(textsOutsideAlerts(tester), isEmpty);
    expect(
      view.errors.map((error) => error.message),
      contains(
        "Component 'root' has invalid props: text: value must be a number",
      ),
    );
  });

  testWidgets('names a failing check condition as a problem of checks', (
    tester,
  ) async {
    final (_, problem) = await _render(tester, [
      {
        'id': 'root',
        'component': 'TextField',
        'label': 'Code',
        'checks': [
          {
            'condition': {
              '@call': 'regex',
              'args': {'value': 'a', 'pattern': '('},
            },
            'message': 'Bad',
          },
        ],
      },
    ]);
    expect(problem(), 'checks: "(" is not a regular expression');
  });
}
