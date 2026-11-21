// Parity tests of CopilotKit's standard inputs, ported from
// packages/react-core/src/v2/generative-ui/standard/__tests__/inputs.test.tsx
// (MIT, (c) Atai Barkai). Each test names its upstream file and line.
//
// ignore: lines_longer_than_80_chars (port_status.dart reads this line whole)
// Parity for: Button, CheckBox, Form, RadioGroup, Select, TextField, Column, Row, Text
// Signals for: SegmentedControl
//
// Upstream renders a catalog of its own: the layout and input components
// and a test-only `Label` leaf, a span that shows a data value. These
// render the standard catalog, with the standard `Text` bound to the same
// path in place of that leaf. Upstream's queries map as follows:
// - `findByLabelText(label)` of a TextField or a Select: the control in the
//   field that the label heads, and an input's `value` is the field's text;
//   of a CheckBox: its semantics node of that name, whose checked state is
//   the input's `checked`;
// - `getByRole("button" | "radio" | "form", { name })`: the semantics node
//   that is a button, a radio (in a mutually exclusive group) or has the
//   form role, labelled `name`; `getByRole("group", { name })` of a
//   RadioGroup: the node of that name that holds its radios; of the
//   accessibility envelope: a node of that name and description around the
//   field's own node, not the field itself (Flutter has no group role);
//   `aria-description` is a node's hint, and `aria-hidden` leaves no node;
// - `fireEvent.change` of a TextField: `enterText`; of a select: choosing
//   the option in the Select's menu (RULEBOOK section 2: a native select is
//   a Material menu), whose items are `select.options`;
// - `forwardEvent` calls: `ParitySurface.actions`, where `componentId` is
//   `sourceComponentId` and `SURFACE_ID` is `testSurfaceId`.
//
// Not ported (bound to internals): no whole test. In the ported ones, the
// `narrow(element, HTMLInputElement | HTMLSelectElement)` checks (:125,
// :159, :166, :251, :263) assert the DOM element's class; the finders
// above find a text field, a check box, a Select or a radio instead.
//
// Later phase (no Dart yet):
// - :130 "keeps a literal value in local state and does not write the data
//   model" (TextArea).
// - :171 "writes a Slider value as a number and shows it with the unit"
//   (Slider).
// - :196 "writes a DateTimeInput date and clears it with the clear button"
//   (DateTimeInput).
// - :246, its SegmentedControl half: "Ent seg" is checked once the Select
//   changes, and a click on "Team seg" sets the Select back to "team".
// - :277 "moves the SegmentedControl selection and focus with the arrow
//   keys, as one tab stop" (SegmentedControl).
// - :478 "sends only the innermost event when a control inside a Pressable
//   is used" and :505 "presses a Pressable with Enter, but not when Enter
//   is on a Button inside it" (Pressable).
// - The DateTimeInput tests: its helpers `splitDateTime`,
//   `describeDateTime`, `timeSlots` and `timeInRange` (:538, :551, :571,
//   :701, :718, :771, :787) and the component (:587, :621, :646, :670,
//   :731, :796, :823, :844).

import 'dart:ui' show CheckedState;

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/inputs/button.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/document/catalog_document.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// The schema of [component] in the catalog document.
Map<String, Object?> _schemaOf(String component) {
  final components =
      a2uiKitCatalogDocument['components']! as Map<String, Object?>;
  return components[component]! as Map<String, Object?>;
}

/// The property schemas of [component] in the catalog document.
Map<String, Object?> _propertiesOf(String component) =>
    _schemaOf(component)['properties']! as Map<String, Object?>;

/// The last segment of the `$ref` of the property schema [schema]
/// (`Action`, `ChildList`, `ComponentId`), or null for a plain value.
String? _refOf(Object? schema) => switch (schema) {
  <String, Object?>{r'$ref': final String ref} => ref.split('/').last,
  _ => null,
};

/// The events of [component], its action props: the keys of upstream's
/// `manifestComponents[component].events`.
List<String> _eventsOf(String component) => [
  for (final MapEntry(:key, :value) in _propertiesOf(component).entries)
    if (_refOf(value) == 'Action') key,
];

/// The kind of child slot a prop whose `$ref` ends in [ref] is: CopilotKit's
/// `childRefKind` (shared/src/generative-ui/child-refs.ts:37-44).
String? _slotKind(String? ref) => switch (ref) {
  'ComponentId' => 'single',
  'ChildList' => 'multiple',
  _ => null,
};

/// The child slots of [component]: upstream's
/// `manifestComponents[component].slots`.
Map<String, String> _slotsOf(String component) => {
  for (final MapEntry(:key, :value) in _propertiesOf(component).entries)
    if (_slotKind(_refOf(value)) case final String kind) key: kind,
};

/// The field that [label] heads: CopilotKit's `Field`.
Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(FieldFrame));

/// The text field labelled [label]: upstream's `findByLabelText(label)`.
Finder _textField(String label) =>
    find.descendant(of: _field(label), matching: find.byType(TextField));

/// The text in the text field labelled [label]: the input's `value`.
String _textIn(WidgetTester tester, String label) =>
    tester.widget<TextField>(_textField(label)).controller!.text;

/// The Select labelled [label]: upstream's `findByLabelText(label)` of a
/// `<select>`, which is a Material menu here.
Finder _select(String label) =>
    find.descendant(of: _field(label), matching: find.byType(MenuAnchor));

/// The texts of the options in the open Select menu, in order: the labels
/// of upstream's `select.options`.
List<String?> _menuOptions(WidgetTester tester) {
  final items = find.descendant(
    of: find.byType(MenuItemButton),
    matching: find.byType(Text),
  );
  return [for (final text in tester.widgetList<Text>(items)) text.data];
}

/// Chooses the option [label] in the open Select menu: upstream's
/// `fireEvent.change(select, { target: { value } })`.
Future<void> _pick(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(MenuItemButton),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

/// The semantics nodes that pass [test], described as [what].
SemanticsFinder _nodes(String what, SemanticsNodePredicate test) =>
    find.semantics.byPredicate(test, describeMatch: (_) => what);

/// The buttons named [name]: upstream's `getAllByRole("button", { name })`.
SemanticsFinder _buttons(String name) => _nodes(
  'buttons named "$name"',
  (node) => node.flagsCollection.isButton && node.label == name,
);

/// The radios named [name]: upstream's `getAllByRole("radio", { name })`.
SemanticsFinder _radios(String name) => _nodes(
  'radios named "$name"',
  (node) =>
      node.flagsCollection.isInMutuallyExclusiveGroup && node.label == name,
);

/// The check boxes named [name]: upstream's `getAllByLabelText(name)` of a
/// checkbox.
SemanticsFinder _checkBoxes(String name) => _nodes(
  'check boxes named "$name"',
  (node) =>
      node.flagsCollection.isChecked != CheckedState.none &&
      !node.flagsCollection.isInMutuallyExclusiveGroup &&
      node.label == name,
);

/// The one node [finder] finds: upstream's `getBy` queries.
SemanticsNode _single(SemanticsFinder finder) {
  expect(finder, findsOne);
  return finder.evaluate().single;
}

/// The checked state of the one node [finder] finds: the input's `checked`.
CheckedState _checkedState(SemanticsFinder finder) =>
    _single(finder).flagsCollection.isChecked;

/// Clicks the button named [name]: upstream's
/// `fireEvent.click(getByRole("button", { name }))`.
Future<void> _click(WidgetTester tester, String name) async {
  expect(_buttons(name), findsOne);
  await tester.tap(find.text(name));
  await tester.pump();
}

/// The texts on screen that read [text], without what a text field holds:
/// upstream's `getByText(text)`, which skips an input's value.
Finder _shownText(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText() == text,
);

/// The text of the subtree [finder] finds: upstream's `textContent`.
String _textContent(WidgetTester tester, Finder finder) {
  final texts = find.descendant(of: finder, matching: find.byType(RichText));
  return [
    for (final text in tester.widgetList<RichText>(texts))
      text.text.toPlainText(),
  ].join();
}

/// `PLAN_OPTIONS` (inputs.test.tsx:65).
List<Map<String, Object?>> _planOptions() => [
  {'value': 'team', 'label': 'Team'},
  {'value': 'enterprise', 'label': 'Enterprise'},
];

/// `planControls` (inputs.test.tsx:218).
List<Map<String, Object?>> _planControls() => [
  {
    'id': 'root',
    'component': 'Column',
    'children': ['s', 'r', 'g'],
  },
  {
    'id': 's',
    'component': 'Select',
    'label': 'Plan',
    'value': {'@path': '/plan'},
    'options': {'@path': '/plans'},
  },
  {
    'id': 'r',
    'component': 'RadioGroup',
    'label': 'Plan choice',
    'value': {'@path': '/plan'},
    'options': ['team', 'enterprise'],
  },
  {
    'id': 'g',
    'component': 'SegmentedControl',
    'label': 'Plan segment',
    'value': {'@path': '/plan'},
    'options': [
      {'value': 'team', 'label': 'Team seg'},
      {'value': 'enterprise', 'label': 'Ent seg'},
    ],
  },
];

void main() {
  group('inputComponents', () {
    // inputs.test.tsx:71
    test('is valid input for createGenerativeUI, with a description for every '
        'component', () {
      // `inputComponents` is the standard catalog's run of inputs, from
      // Button on.
      const names = [
        'Button',
        'Pressable',
        'Form',
        'TextField',
        'TextArea',
        'Select',
        'CheckBox',
        'Radio',
        'RadioGroup',
        'Slider',
        'SegmentedControl',
        'ChoicePicker',
        'DateTimeInput',
      ];
      final start = standardComponentNames.indexOf('Button');
      expect(
        standardComponentNames.sublist(start, start + names.length),
        names,
      );
      // `toEqual` on the group's keys fails on an extra member too: the
      // next group (feedback) starts right after DateTimeInput.
      expect(standardComponentNames[start + names.length], 'PulseIndicator');
      for (final name in names) {
        expect(
          _schemaOf(name)['description'],
          matches(RegExp(r'\S')),
          reason: name,
        );
      }
      expect(_eventsOf('Button'), ['onClick']);
      expect(_eventsOf('Form'), ['onSubmit']);
      expect(_slotsOf('Pressable'), {'children': 'multiple'});
    });
  });

  group('standard inputs: values', () {
    // inputs.test.tsx:104
    testWidgets(
      'writes what the user types into a bound path, and an agent write to '
      'that path later does not change it',
      (tester) async {
        final view = await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['f', 't'],
            },
            {
              'id': 'f',
              'component': 'TextField',
              'label': 'Email',
              'value': {'@path': '/form/email'},
            },
            {
              'id': 't',
              'component': 'Text',
              'text': {'@path': '/form/email'},
            },
          ],
          data: {
            'form': {'email': ''},
          },
        );
        await tester.enterText(_textField('Email'), 'ada@example.com');
        await tester.pump();
        expect(view.dataAt('/form/email'), 'ada@example.com');
        expect(_shownText('ada@example.com'), findsOneWidget);

        await view.update([agentWrite('/form/email', 'agent@example.com')]);
        expect(view.dataAt('/form/email'), 'ada@example.com');
        expect(_textIn(tester, 'Email'), 'ada@example.com');
      },
    );

    // inputs.test.tsx:147
    testWidgets('writes a CheckBox state to its value path', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'CheckBox',
            'label': 'Annual billing',
            'value': {'@path': '/annual'},
          },
        ],
        data: {'annual': false},
      );
      expect(
        _checkedState(_checkBoxes('Annual billing')),
        CheckedState.isFalse,
      );
      await tester.tap(find.text('Annual billing'));
      await tester.pump();
      expect(view.dataAt('/annual'), isTrue);
      expect(_checkedState(_checkBoxes('Annual billing')), CheckedState.isTrue);
    });
  });

  group('standard inputs: options', () {
    // inputs.test.tsx:246
    testWidgets(
      'reads options as strings, objects, or a bound path, and shares one '
      'value',
      (tester) async {
        final view = await renderStandard(
          tester,
          _planControls(),
          data: {'plan': 'team', 'plans': _planOptions()},
        );
        await tester.tap(_select('Plan'));
        await tester.pumpAndSettle();
        expect(_menuOptions(tester), ['Team', 'Enterprise']);

        await _pick(tester, 'Enterprise');
        expect(view.dataAt('/plan'), 'enterprise');
        expect(_checkedState(_radios('enterprise')), CheckedState.isTrue);
        // Later phase (SegmentedControl): "Ent seg" is checked, and a click
        // on "Team seg" sets the Select back to "team". The SegmentedControl
        // draws nothing yet; when this fails, it is built: port that half.
        expect(find.text('Ent seg', findRichText: true), findsNothing);
      },
    );

    // inputs.test.tsx:297
    testWidgets(
      'shows option descriptions in a RadioGroup and names the group with '
      'its legend',
      (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'RadioGroup',
            'label': 'Support',
            'variant': 'cards',
            'options': [
              {'value': 'basic', 'label': 'Basic', 'description': 'Email only'},
            ],
          },
        ]);
        // The group: the radio-group node named "Support" that holds the
        // radios (the `fieldset` its `legend` names).
        expect(
          find.semantics.descendant(
            of: find.semantics.byPredicate(
              (node) =>
                  node.role == SemanticsRole.radioGroup &&
                  node.label == 'Support',
            ),
            matching: _radios('Basic'),
          ),
          findsOne,
        );
        expect(find.text('Email only'), findsOneWidget);
      },
    );
  });

  group('standard inputs: events', () {
    // inputs.test.tsx:315
    testWidgets(
      'renders Button text when label is not set, and prefers label',
      (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Row',
            'children': ['a', 'b'],
          },
          {'id': 'a', 'component': 'Button', 'text': 'Request quote'},
          {
            'id': 'b',
            'component': 'Button',
            'label': 'Send',
            'text': 'Ignored',
          },
        ]);
        expect(_buttons('Request quote'), findsOne);
        expect(_buttons('Send'), findsOne);
        expect(find.text('Ignored', findRichText: true), findsNothing);
      },
    );

    // inputs.test.tsx:328
    testWidgets(
      'sends a bound Button event with its context read from the data model '
      'at click time',
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
              'label': 'Email',
              'value': {'@path': '/form/email'},
            },
            {
              'id': 'b',
              'component': 'Button',
              'label': 'Subscribe',
              'onClick': {
                'event': {
                  'name': 'subscribe',
                  'context': {
                    'email': {'@path': '/form/email'},
                    'source': 'footer',
                  },
                },
              },
            },
          ],
          data: {
            'form': {'email': ''},
          },
        );
        await tester.enterText(_textField('Email'), 'ada@example.com');
        await tester.pump();
        await _click(tester, 'Subscribe');
        expect(view.actions, hasLength(1));
        final action = view.actions.single;
        expect(action.name, 'subscribe');
        expect(action.surfaceId, testSurfaceId);
        expect(action.sourceComponentId, 'b');
        // `timestamp: expect.any(String)`: a DateTime, by its type.
        expect(action.context, {
          'email': 'ada@example.com',
          'source': 'footer',
        });
        // `toEqual` on the whole event: it carries no `userMessage`.
        expect(action.userMessage, isNull);
      },
    );

    // inputs.test.tsx:366
    testWidgets(
      'applies the accessibility envelope to a field and to a CheckBox',
      (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['f', 'c'],
          },
          {
            'id': 'f',
            'component': 'TextField',
            'label': 'Email',
            'accessibility': {
              'label': 'Contact email',
              'description': 'Work address',
            },
          },
          {
            'id': 'c',
            'component': 'CheckBox',
            'label': 'Terms',
            'accessibility': {'hidden': true},
          },
        ]);
        bool named(SemanticsNode node) =>
            node.label == 'Contact email' && node.hint == 'Work address';
        // `getByRole("group", { name, description })`: the Field's envelope,
        // a node of its own that is not the text field.
        final group = _nodes(
          'the group "Contact email"',
          (node) => named(node) && !node.flagsCollection.isTextField,
        );
        expect(group, findsOne);
        // The control itself carries the name: ARIA names do not inherit.
        final input = _nodes(
          'the text field "Contact email"',
          (node) => node.flagsCollection.isTextField && named(node),
        );
        expect(input, findsOne);
        // `group.contains(input)`: the group is a node around the input.
        expect(find.semantics.ancestor(of: input, matching: group), findsOne);
        // The hidden CheckBox is drawn, and has no semantics node.
        expect(find.text('Terms'), findsOneWidget);
        expect(find.semantics.byLabel('Terms'), findsNothing);
      },
    );

    // inputs.test.tsx:394
    testWidgets('names a Button by the accessibility label of its envelope', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Button',
          'label': 'Go',
          'accessibility': {
            'label': 'Send the order',
            'description': 'Final step',
          },
        },
      ]);
      final button = _single(_buttons('Send the order'));
      expect(button.hint, 'Final step');
      // One node named so: the button, not also a wrapper around it.
      expect(find.semantics.byLabel('Send the order'), findsOne);
      expect(_textContent(tester, find.byType(KitButton)), 'Go');
    });

    // inputs.test.tsx:408
    testWidgets('does not send the event of a disabled Button', (tester) async {
      final view = await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Button',
          'label': 'Nope',
          'disabled': true,
          'onClick': {
            'event': {'name': 'nope'},
          },
        },
      ]);
      await _click(tester, 'Nope');
      expect(view.actions, isEmpty);
    });

    // inputs.test.tsx:422
    testWidgets(
      'sends only the Form onSubmit when a submit Button inside the Form is '
      'clicked',
      (tester) async {
        final view = await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'Form',
              'label': 'Signup',
              'children': ['f', 'b'],
              'onSubmit': {
                'event': {
                  'name': 'signup',
                  'context': {
                    'email': {'@path': '/form/email'},
                  },
                },
              },
            },
            {
              'id': 'f',
              'component': 'TextField',
              'label': 'Email',
              'value': {'@path': '/form/email'},
            },
            {
              'id': 'b',
              'component': 'Button',
              'label': 'Send',
              'submit': true,
              'onClick': {
                'event': {'name': 'button-click'},
              },
            },
          ],
          data: {
            'form': {'email': ''},
          },
        );
        expect(
          _nodes(
            'forms named "Signup"',
            (node) => node.role == SemanticsRole.form && node.label == 'Signup',
          ),
          findsOne,
        );
        await tester.enterText(_textField('Email'), 'ada@example.com');
        await tester.pump();
        await _click(tester, 'Send');
        expect(view.actionNames, ['signup']);
        expect(view.actions.first.context, {'email': 'ada@example.com'});
      },
    );

    // inputs.test.tsx:464
    testWidgets(
      'sends the onClick of a submit Button that is outside of a Form',
      (tester) async {
        final view = await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Button',
            'label': 'Lone',
            'submit': true,
            'onClick': {
              'event': {'name': 'lone-submit'},
            },
          },
        ]);
        await _click(tester, 'Lone');
        expect(view.actionNames, ['lone-submit']);
      },
    );
  });

  group('beyond inputs.test.tsx (ours)', () {
    // inputs.tsx:327: the <button> takes the envelope's ARIA. With only a
    // description its content still names it; the description describes
    // it. One node: the button.
    testWidgets('describes a Button by the envelope description, named by '
        'its content', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Button',
          'label': 'Go',
          'accessibility': {'description': 'Final step'},
        },
      ]);
      expect(_single(_buttons('Go')).hint, 'Final step');
      expect(find.semantics.byLabel('Go'), findsOne);
    });

    // inputs.tsx:1197, :1230: the CheckBox's <input> takes the envelope's
    // name (`controlAria`); its wrapper takes only hidden and live, so no
    // other node is named. The aria-label is the box's name over its
    // visible label.
    testWidgets('names a CheckBox by the envelope label: one checkbox node', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'CheckBox',
          'label': 'Terms',
          'value': true,
          'accessibility': {
            'label': 'Accept the terms',
            'description': 'Required',
          },
        },
      ]);
      final box = _single(_checkBoxes('Accept the terms'));
      expect(box.hint, 'Required');
      expect(box.flagsCollection.isChecked, CheckedState.isTrue);
      expect(find.semantics.byLabel('Accept the terms'), findsOne);
      expect(find.semantics.byLabel('Terms'), findsNothing);
      expect(find.text('Terms'), findsOneWidget);
    });

    // inputs.tsx:190-213, :1137: a named Select's Field is a group of that
    // name, and the <select> takes the name and description too.
    testWidgets('names a Select and its field group by the envelope', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Select',
          'label': 'Plan',
          'options': _planOptions(),
          'value': 'team',
          'accessibility': {
            'label': 'Billing plan',
            'description': 'Billed monthly',
          },
        },
      ]);
      bool named(SemanticsNode node) =>
          node.label == 'Billing plan' && node.hint == 'Billed monthly';
      final select = _nodes(
        'the select',
        (node) => named(node) && node.flagsCollection.isButton,
      );
      expect(select, findsOne);
      expect(_single(select).value, 'Team');
      final group = _nodes(
        'the group',
        (node) => named(node) && !node.flagsCollection.isButton,
      );
      expect(group, findsOne);
      expect(find.semantics.ancestor(of: select, matching: group), findsOne);
    });
  });
}
