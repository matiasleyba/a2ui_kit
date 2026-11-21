// Parity tests of CopilotKit's standard inputs, ported from
// packages/react-core/src/v2/generative-ui/standard/__tests__/
// inputs-parity.test.tsx (MIT, (c) Atai Barkai), itself ported from the
// a2ui-renderer standard catalog. Each test names its upstream file and
// line.
//
// ignore: lines_longer_than_80_chars (port_status.dart reads this line whole)
// Parity for: Badge, Button, CheckBox, Form, RadioGroup, Select, Text, TextField, Column
// Signals for: Slider, SegmentedControl, TextArea, DateTimeInput, Pressable
//
// Upstream's queries map as in inputs_test.dart: `getByText(text)` is a
// text on screen that reads `text` (not what a text field holds),
// `findByPlaceholderText` the text field with that placeholder, a select
// the Select's Material menu (RULEBOOK section 2) with its items as
// `select.options`, and a radio the semantics node of that name in a
// mutually exclusive group.
//
// Not ported (bound to internals):
// - :64 `container.querySelector("select")` and `("form")`: DOM tags. The
//   behaviour, that a Select and a Form render, is tested as a node with
//   the form role and, inside it, the Select's own button node valued by
//   its chosen option.
// - :109 `input[type="radio"][value="enterprise"]`: a DOM query. Tested as
//   the radio named "enterprise" (a string option's label is its value).
// - :158 `select.style.width` ("100%") and `select.style.paddingLeft` (not
//   empty): inline styles. The behaviours, that the Select fills its field
//   and leaves room for its icon, are tested as the Select's width against
//   its field's and as its text starting after the icon.
//
// Translated (upstream reads inline style strings; the test reads what is
// drawn, so it counts as ported):
// - :241 "renders primary buttons and solid badges with token colours, not
//   literals": inline `color` strings (`var(--a2ui-color-on-accent,
//   #fff)`), read as a primary Button's and a solid Badge's text drawn in
//   the theme's on-accent token, in both looks.
//
// Later phase (no Dart yet):
// - :35, its Slider half: a change of the range input to 12 shows "12"
//   (Slider).
// - :64, its TextArea (`textarea`), DateTimeInput (`input[type="date"]`)
//   and SegmentedControl parts.
// - :109, its SegmentedControl half: "Ent seg" is checked once the Select
//   changes, and a click on "Team seg" sets the Select to "team".
// - :177, its Pressable half: "P1" and "P2" (Pressable).
// - :201 "ListItem action inside a Pressable dispatches only the ListItem
//   action": the ListItem is built, but the test is about the Pressable
//   around it (Pressable).
// - :221 "Pressable tooltip, ariaPressed and insetBorder apply"
//   (Pressable).
// - :259 "Popover sideOffset moves the content and a block trigger fills
//   the width" and :276 "Popover with showOnHover and hoverOpenDelay opens
//   after the delay" (Popover, PopoverTrigger, PopoverContent).
// - :304 "PulseIndicator takes endScale and startOpacity"
//   (PulseIndicator).

import 'dart:ui' show CheckedState;

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// The field that [label] heads: CopilotKit's `Field`.
Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(FieldFrame));

/// The Select labelled [label]: upstream's `findByLabelText(label)` of a
/// `<select>`, which is a Material menu here.
Finder _select(String label) =>
    find.descendant(of: _field(label), matching: find.byType(MenuAnchor));

/// The texts of the options in the open Select menu, in order: the text of
/// upstream's `select.options`.
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

/// The radios named [name]: upstream's radio inputs of that value.
SemanticsFinder _radios(String name) => _nodes(
  'radios named "$name"',
  (node) =>
      node.flagsCollection.isInMutuallyExclusiveGroup && node.label == name,
);

/// The checked state of the one node [finder] finds: the input's `checked`.
CheckedState _checkedState(SemanticsFinder finder) {
  expect(finder, findsOne);
  return finder.evaluate().single.flagsCollection.isChecked;
}

/// The text field whose placeholder is [placeholder]: upstream's
/// `findByPlaceholderText(placeholder)`.
Finder _withPlaceholder(String placeholder) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == placeholder,
);

/// The texts on screen that read [text], without what a text field holds:
/// upstream's `findByText(text)`, which skips an input's value.
Finder _shownText(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText() == text,
);

/// inputs-parity.test.tsx:64's surface: a Form holding a Select, a
/// RadioGroup, a SegmentedControl, a TextArea and a DateTimeInput, the last
/// three later-phase.
const List<Map<String, Object?>> _formOfInputs = [
  {
    'id': 'root',
    'component': 'Form',
    'children': ['s', 'r', 'g', 'a', 'd'],
    'onSubmit': {
      'event': {'name': 'submit'},
    },
  },
  {
    'id': 's',
    'component': 'Select',
    'value': {'@path': '/plan'},
    'options': [
      {'value': 'team', 'label': 'Team'},
      'enterprise',
    ],
  },
  {
    'id': 'r',
    'component': 'RadioGroup',
    'value': {'@path': '/plan'},
    'options': ['team', 'enterprise'],
    'label': 'Plan',
  },
  {
    'id': 'g',
    'component': 'SegmentedControl',
    'value': {'@path': '/plan'},
    'options': ['team', 'enterprise'],
  },
  {
    'id': 'a',
    'component': 'TextArea',
    'value': {'@path': '/notes'},
    'rows': 2,
  },
  {
    'id': 'd',
    'component': 'DateTimeInput',
    'value': {'@path': '/when'},
  },
];

void main() {
  group('standard catalog: inputs (parity)', () {
    // inputs-parity.test.tsx:15
    testWidgets('TextField writes to the data model and Text reflects it', (
      tester,
    ) async {
      await renderStandard(
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
            'value': {'@path': '/name'},
            'placeholder': 'Your name',
          },
          {
            'id': 't',
            'component': 'Text',
            'text': {'@path': '/name'},
          },
        ],
        data: {'name': ''},
      );
      await tester.enterText(_withPlaceholder('Your name'), 'Ada');
      await tester.pump();
      expect(_shownText('Ada'), findsOneWidget);
    });

    // inputs-parity.test.tsx:35
    testWidgets('Slider and CheckBox bind and render their labels', (
      tester,
    ) async {
      await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['s', 'c', 't'],
          },
          {
            'id': 's',
            'component': 'Slider',
            'value': {'@path': '/seats'},
            'min': 1,
            'max': 50,
            'step': 1,
          },
          {
            'id': 'c',
            'component': 'CheckBox',
            'value': {'@path': '/annual'},
            'label': 'Annual',
          },
          {
            'id': 't',
            'component': 'Text',
            'text': {'@path': '/seats'},
          },
        ],
        data: {'seats': 8, 'annual': false},
      );
      expect(find.text('Annual'), findsOneWidget);
      // Later phase (Slider): a change of the range input to 12 shows "12".
      // The Slider draws nothing yet; when this fails, it is built: port
      // that half.
      expect(find.byType(Slider), findsNothing);
      expect(
        _nodes('sliders', (node) => node.flagsCollection.isSlider),
        findsNothing,
      );
    });

    // inputs-parity.test.tsx:64
    testWidgets(
      'Select, RadioGroup, SegmentedControl, TextArea, DateTimeInput, Form '
      'render',
      (tester) async {
        await renderStandard(
          tester,
          _formOfInputs,
          data: {'plan': 'team', 'notes': '', 'when': ''},
        );
        expect(find.text('Plan'), findsOneWidget);
        // `querySelector("form")`: the Form, a node with the form role.
        final form = _nodes('forms', (node) => node.role == SemanticsRole.form);
        expect(form, findsOne);
        // `querySelector("select")`, a node of its own inside the form: the
        // test below.
        // Later phase: the `textarea` (TextArea), the `input[type="date"]`
        // (DateTimeInput) and the SegmentedControl's radios draw nothing
        // yet. Counted by the kinds of control they would add: no text
        // field, no slider, and only the RadioGroup's two radios, under its
        // radio-group node. When one of these fails, a later-phase control
        // was built: port its part.
        expect(find.byType(EditableText), findsNothing);
        expect(
          _nodes('text fields', (node) => node.flagsCollection.isTextField),
          findsNothing,
        );
        expect(
          _nodes('sliders', (node) => node.flagsCollection.isSlider),
          findsNothing,
        );
        final radios = _nodes(
          'radios',
          (node) => node.flagsCollection.isInMutuallyExclusiveGroup,
        );
        expect(radios, findsNWidgets(2));
        expect(
          find.semantics.descendant(
            of: _nodes(
              'radio groups',
              (node) => node.role == SemanticsRole.radioGroup,
            ),
            matching: radios,
          ),
          findsNWidgets(2),
        );
      },
    );

    // inputs-parity.test.tsx:64, :103-105: the `select` inside the `form`.
    testWidgets(
      'Select, RadioGroup, SegmentedControl, TextArea, DateTimeInput, Form '
      'render: the Select is a node of its own inside the form',
      (tester) async {
        await renderStandard(
          tester,
          _formOfInputs,
          data: {'plan': 'team', 'notes': '', 'when': ''},
        );
        // The Select's button, valued by its chosen option, under the form
        // node and not the form node itself.
        final form = _nodes('forms', (node) => node.role == SemanticsRole.form);
        expect(form, findsOne);
        expect(
          find.semantics.descendant(
            of: form,
            matching: _nodes(
              'the select',
              (node) => node.flagsCollection.isButton && node.value == 'Team',
            ),
          ),
          findsOne,
        );
      },
    );

    // inputs-parity.test.tsx:109
    testWidgets('Select change propagates to RadioGroup and SegmentedControl', (
      tester,
    ) async {
      await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['s', 'r', 'g'],
          },
          {
            'id': 's',
            'component': 'Select',
            'value': {'@path': '/plan'},
            'options': ['team', 'enterprise'],
          },
          {
            'id': 'r',
            'component': 'RadioGroup',
            'value': {'@path': '/plan'},
            'options': ['team', 'enterprise'],
          },
          {
            'id': 'g',
            'component': 'SegmentedControl',
            'value': {'@path': '/plan'},
            'options': [
              {'value': 'team', 'label': 'Team seg'},
              {'value': 'enterprise', 'label': 'Ent seg'},
            ],
          },
        ],
        data: {'plan': 'team'},
      );
      // Later phase (SegmentedControl): `findByText("Ent seg")`.
      await tester.tap(find.byType(MenuAnchor));
      await tester.pumpAndSettle();
      await _pick(tester, 'enterprise');
      expect(_checkedState(_radios('enterprise')), CheckedState.isTrue);
      // Later phase (SegmentedControl): "Ent seg" is checked, and a click on
      // "Team seg" sets the Select to "team". The SegmentedControl draws
      // nothing yet; when this fails, it is built: port that half.
      expect(find.text('Ent seg', findRichText: true), findsNothing);
      expect(find.text('Team seg', findRichText: true), findsNothing);
    });

    // inputs-parity.test.tsx:158
    testWidgets(
      'Select shows clearLabel on the empty option, an icon and full width',
      (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Select',
            'label': 'Plan',
            'clearable': true,
            'clearLabel': 'Any plan',
            'icon': 'search',
            'block': true,
            'options': ['team'],
          },
        ]);
        final select = _select('Plan');
        // `select.style.width` is "100%": the Select fills its field.
        expect(
          tester.getSize(select).width,
          tester.getSize(find.byType(FieldFrame)).width,
        );
        // `select.style.paddingLeft` is set: the text starts after the icon.
        final icon = find.descendant(
          of: select,
          matching: find.byType(LucideGlyph),
        );
        expect(icon, findsOneWidget);
        expect(
          tester.getRect(icon).right,
          lessThanOrEqualTo(tester.getRect(find.text('Any plan')).left),
        );
        await tester.tap(select);
        await tester.pumpAndSettle();
        expect(_menuOptions(tester).first, 'Any plan');
      },
    );

    // inputs-parity.test.tsx:177
    testWidgets('Pressable and Form repeat a template child per data item', (
      tester,
    ) async {
      await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['p', 'f'],
          },
          {
            'id': 'p',
            'component': 'Pressable',
            'children': {'componentId': 'pr', 'path': '/a'},
          },
          {
            'id': 'pr',
            'component': 'Text',
            'text': {'@path': 'name'},
          },
          {
            'id': 'f',
            'component': 'Form',
            'children': {'componentId': 'fr', 'path': '/b'},
          },
          {
            'id': 'fr',
            'component': 'Text',
            'text': {'@path': 'name'},
          },
        ],
        data: {
          'a': [
            {'name': 'P1'},
            {'name': 'P2'},
          ],
          'b': [
            {'name': 'F1'},
          ],
        },
      );
      expect(find.text('F1'), findsOneWidget);
      // Later phase (Pressable): "P1" and "P2". The Pressable draws nothing
      // yet; when this fails, it is built: port that half.
      expect(find.text('P1', findRichText: true), findsNothing);
      expect(find.text('P2', findRichText: true), findsNothing);
    });

    // `var(--a2ui-color-on-accent, #fff)`: the theme's on-accent token. The
    // light token is white, the very literal ruled out, so the dark look
    // (on-accent 0xff0d0d0d) is rendered too: a hard-coded white fails
    // there. Each look gets a test of its own (MaterialApp animates a theme
    // change).
    for (final brightness in [Brightness.light, Brightness.dark]) {
      // inputs-parity.test.tsx:241 (translated: the colour drawn)
      testWidgets(
        'renders primary buttons and solid badges with token colours, not '
        'literals ($brightness)',
        (tester) async {
          await renderStandard(tester, brightness: brightness, [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['b', 'g'],
            },
            {
              'id': 'b',
              'component': 'Button',
              'label': 'Go',
              'variant': 'primary',
              'onClick': {
                'event': {'name': 'go'},
              },
            },
            {
              'id': 'g',
              'component': 'Badge',
              'label': 'New',
              'variant': 'solid',
            },
          ]);
          final onAccent = A2uiKitTheme.standard(
            brightness,
          ).color(A2uiColorToken.onAccent);
          // The colour each label paints: its RichText's root style, what
          // it inherits merged with its own.
          Color? painted(String text) => tester
              .widget<RichText>(find.text(text, findRichText: true))
              .text
              .style
              ?.color;
          expect(painted('Go'), onAccent, reason: '$brightness');
          expect(painted('New'), onAccent, reason: '$brightness');
          if (brightness == Brightness.dark) {
            expect(onAccent, isNot(const Color(0xffffffff)));
          }
        },
      );
    }
  });
}
