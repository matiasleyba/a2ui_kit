// Parity tests of CopilotKit's checks on the standard inputs, ported from
// packages/react-core/src/v2/generative-ui/standard/__tests__/checks.test.tsx
// (MIT, (c) Atai Barkai). Each test names its upstream file and line.
//
// Parity for: Button, CheckBox, TextField, Column
// Signals for: Slider
//
// Upstream's queries map as follows (see also inputs_test.dart):
// - `getAllByRole("alert" | "status")` and their `textContent`: the labels
//   of the semantics nodes with the alert or the status role, which the
//   message of a failed check under a control has;
// - `aria-invalid` of a field: the validation result of its semantics node,
//   `invalid` for "true" and `none` when the attribute is absent;
// - `button.disabled`: the button's semantics are not enabled (and a click
//   sends nothing); `title`: the message of the Tooltip around it;
// - `fireEvent.blur(control)`: the focus moves into the control and out;
// - `reportError`: `ParitySurface.errors`.
//
// Not ported (bound to internals):
// - :157 the `data-a2ui-check-severity` and `data-a2ui-check-code`
//   attributes of the status. The behaviour, that the status keeps the
//   failed check's severity and code, is tested on the check that its
//   CheckMessage shows.
//
// Later phase (no Dart yet):
// - :15 "makes an empty required ChoicePicker fail the Form's validation
//   until a choice is made" and :44 "does not let a disabled required
//   ChoicePicker block the Form" (ChoicePicker).
// - :241, its Slider half: the Slider's "At most 50" alert, after the
//   CheckBox's (Slider). Upstream's lists are ["Please accept",
//   "At most 50"], then ["At most 50"]; until the Slider is built it draws
//   nothing, so this file expects the CheckBox's part of each.

import 'dart:ui' show CheckedState, Tristate;

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// `requiredName` (checks.test.tsx:6).
Map<String, Object?> _requiredName() => {
  'condition': {
    '@call': 'required',
    'args': {
      'value': {'@path': '/form/name'},
    },
  },
  'message': 'Name is required',
};

/// The field that [label] heads: CopilotKit's `Field`.
Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(FieldFrame));

/// The text field labelled [label]: upstream's `findByLabelText(label)`.
Finder _textField(String label) =>
    find.descendant(of: _field(label), matching: find.byType(TextField));

/// The one semantics node [finder] finds: upstream's `getBy` queries.
SemanticsNode _single(SemanticsFinder finder) {
  expect(finder, findsOne);
  return finder.evaluate().single;
}

/// The button named [name]: upstream's `getByRole("button", { name })`.
SemanticsNode _button(String name) => _single(
  find.semantics.byPredicate(
    (node) => node.flagsCollection.isButton && node.label == name,
    describeMatch: (_) => 'buttons named "$name"',
  ),
);

/// Whether the button named [name] is enabled: upstream's `!disabled`.
Tristate _enabled(String name) => _button(name).flagsCollection.isEnabled;

/// Clicks the button named [name]: upstream's `fireEvent.click(button)`.
Future<void> _click(WidgetTester tester, String name) async {
  _button(name);
  await tester.tap(find.text(name));
  await tester.pump();
}

/// The tooltip a screen reader gets for the button showing [text], or
/// null: upstream's `button.getAttribute("title")`. Read from the
/// semantics tree, on the button's node or the nearest node above it that
/// carries one.
String? _titleOf(WidgetTester tester, String text) {
  for (
    SemanticsNode? node = tester.getSemantics(find.text(text));
    node != null;
    node = node.parent
  ) {
    final tooltip = node.getSemanticsData().tooltip;
    if (tooltip.isNotEmpty) return tooltip;
  }
  return null;
}

/// The check box named [name]: upstream's `findByLabelText(name)` of a
/// checkbox.
SemanticsNode _checkBox(String name) => _single(
  find.semantics.byPredicate(
    (node) =>
        node.flagsCollection.isChecked != CheckedState.none &&
        !node.flagsCollection.isInMutuallyExclusiveGroup &&
        node.label == name,
    describeMatch: (_) => 'check boxes named "$name"',
  ),
);

/// The semantics node of the one text field: upstream's `textbox`, whose
/// `aria-invalid` is the node's validation result.
SemanticsNode _textbox() => _single(
  find.semantics.byPredicate(
    (node) => node.flagsCollection.isTextField,
    describeMatch: (_) => 'text fields',
  ),
);

/// The labels of the semantics nodes with [role], in tree order: upstream's
/// `getAllByRole(role).map((element) => element.textContent)`.
List<String> _textsWithRole(SemanticsRole role) {
  final nodes = find.semantics.byPredicate((node) => node.role == role);
  return [for (final node in nodes.evaluate()) node.label];
}

/// The texts of the alerts: the messages of the failed error checks shown.
List<String> _alerts() => _textsWithRole(SemanticsRole.alert);

/// The texts of the statuses: the messages of the failed warning and info
/// checks shown.
List<String> _statuses() => _textsWithRole(SemanticsRole.status);

/// Moves the focus into the control that [node] focuses and out again:
/// upstream's `fireEvent.blur(control)`, which marks the control touched.
Future<void> _blur(WidgetTester tester, FocusNode node) async {
  node.requestFocus();
  await tester.pump();
  node.unfocus();
  // The focus change lands in a microtask of this pump; the rebuild it asks
  // for is drawn in the next one.
  await tester.pump();
  await tester.pump();
}

void main() {
  group('standard catalog: checks', () {
    // checks.test.tsx:65
    testWidgets(
      'shows the message of a failed check once the field was touched, and '
      'clears it when valid',
      (tester) async {
        final view = await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'TextField',
              'label': 'Name',
              'value': {'@path': '/form/name'},
              'checks': [_requiredName()],
            },
          ],
          data: {
            'form': {'name': ''},
          },
        );
        final input = _textField('Name');
        expect(input, findsOneWidget);
        // A fresh form is not red.
        expect(_alerts(), isEmpty);
        expect(_textbox().validationResult, SemanticsValidationResult.none);
        await _blur(tester, tester.widget<TextField>(input).focusNode!);
        expect(_alerts(), ['Name is required']);
        expect(_textbox().validationResult, SemanticsValidationResult.invalid);
        await tester.enterText(input, 'Ada');
        await tester.pump();
        expect(_alerts(), isEmpty);
        expect(_textbox().validationResult, SemanticsValidationResult.none);
        expect(view.errors, isEmpty);
      },
    );

    // checks.test.tsx:92
    testWidgets(
      'uses the default message of the validator when the check has none',
      (tester) async {
        await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'TextField',
              'label': 'Email',
              'value': {'@path': '/email'},
              'checks': [
                {
                  'condition': {
                    '@call': 'email',
                    'args': {
                      'value': {'@path': '/email'},
                    },
                  },
                },
              ],
            },
          ],
          data: {'email': 'not-an-email'},
        );
        // A field with a value shows its error without a blur.
        expect(_alerts(), ['Invalid email address']);
      },
    );

    // checks.test.tsx:119
    testWidgets(
      'disables a Button while a check fails and enables it when the data '
      'becomes valid',
      (tester) async {
        final view = await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['f', 'b'],
            },
            {
              'id': 'f',
              'component': 'TextField',
              'label': 'Name',
              'value': {'@path': '/form/name'},
            },
            {
              'id': 'b',
              'component': 'Button',
              'label': 'Send',
              'checks': [_requiredName()],
              'onClick': {
                'event': {'name': 'send'},
              },
            },
          ],
          data: {
            'form': {'name': ''},
          },
        );
        expect(_enabled('Send'), Tristate.isFalse);
        expect(_titleOf(tester, 'Send'), 'Name is required');
        await _click(tester, 'Send');
        expect(view.actions, isEmpty);
        await tester.enterText(_textField('Name'), 'Ada');
        await tester.pump();
        expect(_enabled('Send'), Tristate.isTrue);
        await _click(tester, 'Send');
        expect(view.actions, isNotEmpty);
      },
    );

    // checks.test.tsx:157
    testWidgets(
      'shows a warning or an info without making the control invalid or '
      'disabling the Button, and keeps the code',
      (tester) async {
        final view = await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['f', 'b'],
            },
            {
              'id': 'f',
              'component': 'TextField',
              'label': 'Coupon',
              'value': {'@path': '/coupon'},
              'checks': [
                {
                  'condition': {'@path': '/couponCheck'},
                },
              ],
            },
            {
              'id': 'b',
              'component': 'Button',
              'label': 'Apply',
              'checks': [
                {
                  'condition': {'@path': '/couponCheck'},
                },
              ],
              'onClick': {
                'event': {'name': 'apply'},
              },
            },
          ],
          data: {
            'coupon': 'OLD10',
            'couponCheck': {
              'valid': false,
              'message': 'This coupon expires today',
              'code': 'EXPIRING',
              'severity': 'warning',
            },
          },
        );
        expect(_statuses(), ['This coupon expires today']);
        // `data-a2ui-check-severity` is "warning" and `data-a2ui-check-code`
        // is "EXPIRING": the status shows the failed check with both.
        expect(
          tester.widget<CheckMessage>(find.byType(CheckMessage)).check,
          const FailedCheck(
            message: 'This coupon expires today',
            severity: A2uiCheckSeverity.warning,
            code: 'EXPIRING',
          ),
        );
        expect(_alerts(), isEmpty);
        expect(_textbox().validationResult, SemanticsValidationResult.none);
        expect(_enabled('Apply'), Tristate.isTrue);
        expect(_titleOf(tester, 'Apply'), 'This coupon expires today');
        // An error from the same data blocks again.
        await view.update([
          agentWrite('/couponCheck', {
            'valid': false,
            'message': 'Expired',
            'severity': 'error',
          }),
        ]);
        expect(_alerts(), ['Expired']);
        expect(_enabled('Apply'), Tristate.isFalse);
      },
    );

    // checks.test.tsx:217
    testWidgets(
      'shows the error and blocks when a warning comes before it in the checks',
      (tester) async {
        await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'Button',
              'label': 'Apply',
              'checks': [
                {
                  'condition': {'@path': '/warn'},
                },
                {'condition': false, 'message': 'Name is required'},
              ],
              'onClick': {
                'event': {'name': 'apply'},
              },
            },
          ],
          data: {
            'warn': {
              'valid': false,
              'message': 'Expires soon',
              'severity': 'warning',
            },
          },
        );
        expect(_enabled('Apply'), Tristate.isFalse);
        expect(_titleOf(tester, 'Apply'), 'Name is required');
      },
    );

    // checks.test.tsx:241
    testWidgets(
      'takes a boolean binding as a condition, and a numeric check on a Slider',
      (tester) async {
        await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['c', 's'],
            },
            {
              'id': 'c',
              'component': 'CheckBox',
              'label': 'Accept the terms',
              'value': {'@path': '/accepted'},
              'checks': [
                {
                  'condition': {'@path': '/accepted'},
                  'message': 'Please accept',
                },
              ],
            },
            {
              'id': 's',
              'component': 'Slider',
              'label': 'Seats',
              'min': 0,
              'max': 100,
              'value': {'@path': '/seats'},
              'checks': [
                {
                  'condition': {
                    '@call': 'numeric',
                    'args': {
                      'value': {'@path': '/seats'},
                      'min': 1,
                      'max': 50,
                    },
                  },
                },
              ],
            },
          ],
          data: {'accepted': false, 'seats': 80},
        );
        _checkBox('Accept the terms');
        final label = tester.element(find.text('Accept the terms'));
        await _blur(tester, Focus.of(label, createDependency: false));
        // Later phase (Slider): "At most 50" follows; upstream expects
        // ["Please accept", "At most 50"].
        expect(_alerts(), ['Please accept']);
        await tester.tap(find.text('Accept the terms'));
        await tester.pump();
        // Later phase (Slider): upstream expects ["At most 50"].
        expect(_alerts(), isEmpty);
      },
    );
  });
}
