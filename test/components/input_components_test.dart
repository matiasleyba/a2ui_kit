// Widget tests of the standard inputs, after CopilotKit's react-core
// standard/__tests__/inputs.test.tsx and checks.test.tsx.

import 'dart:ui' show CheckedState, Tristate;

import 'package:a2ui_flutter/a2ui_flutter.dart' show A2uiSurface;
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/inputs/choices.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OpacityLayer;
import 'package:flutter/semantics.dart'
    show SemanticsData, SemanticsNode, SemanticsRole, SemanticsValidationResult;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

final _playground = A2uiKitTheme.playground(Brightness.light);

Map<String, Object?> _root(Map<String, Object?> props) => {
  'id': 'root',
  ...props,
};

Map<String, Object?> _column(List<String> children) => {
  'id': 'root',
  'component': 'Column',
  'children': children,
};

/// The decoration of the nearest decorated box around [finder].
BoxDecoration _decorationAround(WidgetTester tester, Finder finder) {
  final container = tester.widget<Container>(
    find.ancestor(of: finder, matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

Map<String, Object?> _event(String name, [Map<String, Object?>? context]) => {
  'event': {'name': name, 'context': ?context},
};

void main() {
  group('Button', () {
    testWidgets('sends onClick and draws each variant', (tester) async {
      final surfaces = await pumpComponents(tester, theme: _playground, [
        _column(['a', 'b', 'c', 'd']),
        {
          'id': 'a',
          'component': 'Button',
          'label': 'Primary',
          'variant': 'primary',
          'onClick': _event('go'),
        },
        {'id': 'b', 'component': 'Button', 'text': 'Outlined'},
        {
          'id': 'c',
          'component': 'Button',
          'label': 'Soft',
          'variant': 'soft',
          'color': 'danger',
        },
        {
          'id': 'd',
          'component': 'Button',
          'label': 'Plain',
          'variant': 'borderless',
        },
      ]);
      final primary = _decorationAround(tester, find.text('Primary'));
      expect(primary.color, _playground.color(A2uiColorToken.accent));
      final outlined = _decorationAround(tester, find.text('Outlined'));
      expect(outlined.color, isNull);
      expect(
        (outlined.border! as Border).top.color,
        _playground.color(A2uiColorToken.borderDefault),
      );
      expect(
        tester.widget<Text>(find.text('Soft')).style!.color,
        _playground.color(A2uiColorToken.textDanger),
      );
      expect(_decorationAround(tester, find.text('Plain')).border, isNull);
      // A pill, 36px tall by default (size lg).
      expect(primary.borderRadius, BorderRadius.circular(9999));
      final box = tester.getSize(
        find
            .ancestor(
              of: find.text('Primary'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(box.height, 36);

      await tester.tap(find.text('Primary'));
      await tester.pump();
      expect(surfaces.actions.map((a) => a.name), ['go']);
    });

    testWidgets('a failing error check disables it and is its tooltip', (
      tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        [
          _root({
            'component': 'Button',
            'label': 'Send',
            'onClick': _event('send'),
            'checks': [
              {
                'condition': {
                  '@call': 'required',
                  'args': {
                    'value': {'@path': '/name'},
                  },
                },
                'message': 'Name first',
              },
            ],
          }),
        ],
        data: {'name': ''},
      );
      expect(find.byType(Tooltip), findsOneWidget);
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'Name first',
      );
      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(surfaces.actions, isEmpty);

      surfaces.setData('/name', 'Ada');
      await tester.pump();
      expect(find.byType(Tooltip), findsNothing);
      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(surfaces.actions, hasLength(1));
    });

    testWidgets('a warning check informs but does not disable', (tester) async {
      final surfaces = await pumpComponents(tester, [
        _root({
          'component': 'Button',
          'label': 'Send',
          'onClick': _event('send'),
          'checks': [
            {
              'condition': {'valid': false, 'severity': 'warning'},
              'message': 'Are you sure?',
            },
          ],
        }),
      ]);
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'Are you sure?',
      );
      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(surfaces.actions, hasLength(1));
    });

    testWidgets('disabled and loading send nothing', (tester) async {
      final surfaces = await pumpComponents(tester, [
        _column(['a', 'b']),
        {
          'id': 'a',
          'component': 'Button',
          'label': 'Off',
          'disabled': true,
          'onClick': _event('x'),
        },
        {
          'id': 'b',
          'component': 'Button',
          'label': 'Busy',
          'loading': true,
          'onClick': _event('y'),
        },
      ]);
      await tester.tap(find.text('Off'));
      await tester.tap(find.text('Busy'));
      await tester.pump();
      expect(surfaces.actions, isEmpty);
      expect(
        tester
            .widgetList<Opacity>(
              find.ancestor(
                of: find.text('Off'),
                matching: find.byType(Opacity),
              ),
            )
            .first
            .opacity,
        .5,
      );
    });

    testWidgets('href opens the URL instead of onClick', (tester) async {
      final opened = <Uri>[];
      final surfaces = await pumpComponents(
        tester,
        [
          _root({
            'component': 'Button',
            'label': 'Docs',
            'href': ' https://example.com/docs ',
            'onClick': _event('x'),
          }),
        ],
        catalog: a2uiKitCatalog(options: A2uiKitOptions(onOpenUrl: opened.add)),
      );
      await tester.tap(find.text('Docs'));
      await tester.pump();
      expect(opened, [Uri.parse('https://example.com/docs')]);
      expect(surfaces.actions, isEmpty);
    });

    testWidgets('copy copies and shows a check mark for 1.5s', (tester) async {
      final copied = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') copied.add(call.arguments);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final surfaces = await pumpComponents(tester, [
        _root({
          'component': 'Button',
          'label': 'Copy',
          'copy': 'npm i a2ui',
          'onClick': _event('x'),
        }),
      ]);
      expect(find.byType(LucideGlyph), findsNothing);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copied, [
        {'text': 'npm i a2ui'},
      ]);
      expect(find.byType(LucideGlyph), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byType(LucideGlyph), findsNothing);
      expect(surfaces.actions, isEmpty);
    });

    testWidgets('its children replace the label; the icon comes first', (
      tester,
    ) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Button',
          'label': 'Hidden',
          'icon': 'send',
          'child': 'c',
        }),
        {'id': 'c', 'component': 'Text', 'text': 'Child text'},
      ]);
      expect(find.text('Hidden'), findsNothing);
      expect(find.text('Child text', findRichText: true), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(LucideGlyph)).dx,
        lessThan(
          tester.getTopLeft(find.text('Child text', findRichText: true)).dx,
        ),
      );
    });

    testWidgets('Enter on a focused button presses it', (tester) async {
      final surfaces = await pumpComponents(tester, [
        _root({'component': 'Button', 'label': 'Go', 'onClick': _event('go')}),
      ]);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(surfaces.actions.map((a) => a.name), ['go']);
    });
  });

  group('Form', () {
    List<Map<String, Object?>> form({bool required = true}) => [
      {
        'id': 'root',
        'component': 'Form',
        'label': 'Sign up',
        'onSubmit': _event('submit', {
          'name': {'@path': '/name'},
        }),
        'children': ['name', 'send'],
      },
      {
        'id': 'name',
        'component': 'TextField',
        'label': 'Name',
        'required': required,
        'value': {'@path': '/name'},
        'checks': [
          {
            'condition': {
              '@call': 'length',
              'args': {
                'value': {'@path': '/name'},
                'min': 3,
              },
            },
          },
        ],
      },
      {
        'id': 'send',
        'component': 'Button',
        'label': 'Send',
        'submit': true,
        'onClick': _event('clicked'),
      },
    ];

    testWidgets('a submit button sends onSubmit with the context, not '
        'onClick', (tester) async {
      final surfaces = await pumpComponents(tester, form(), data: {'name': ''});
      await tester.enterText(find.byType(TextField), 'Ada Lovelace');
      await tester.pump();
      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(surfaces.actions.map((a) => a.name), ['submit']);
      expect(surfaces.actions.single.context, {'name': 'Ada Lovelace'});
    });

    testWidgets('an empty required field blocks it and says so', (
      tester,
    ) async {
      final surfaces = await pumpComponents(tester, form(), data: {'name': ''});
      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(surfaces.actions, isEmpty);
      expect(find.text(FormValidationMessages.fillOut), findsOneWidget);
      // The field takes the focus.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
      await tester.enterText(find.byType(TextField), 'Al');
      await tester.pump();
      expect(find.text(FormValidationMessages.fillOut), findsNothing);
    });

    testWidgets('checks never block a Form', (tester) async {
      final surfaces = await pumpComponents(
        tester,
        form(required: false),
        data: {'name': 'Al'},
      );
      // The length check fails ("At least 3 characters") and shows, as the
      // field holds a value.
      expect(find.text('At least 3 characters'), findsOneWidget);
      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(surfaces.actions.map((a) => a.name), ['submit']);
    });

    testWidgets('Enter in a field submits it', (tester) async {
      final surfaces = await pumpComponents(tester, form(), data: {'name': ''});
      await tester.enterText(find.byType(TextField), 'Grace');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(surfaces.actions.map((a) => a.name), ['submit']);
    });

    testWidgets('a submit button outside a Form sends onClick', (tester) async {
      final surfaces = await pumpComponents(tester, [
        _root({
          'component': 'Button',
          'label': 'Alone',
          'submit': true,
          'onClick': _event('clicked'),
        }),
      ]);
      await tester.tap(find.text('Alone'));
      await tester.pump();
      expect(surfaces.actions.map((a) => a.name), ['clicked']);
    });

    testWidgets('is a named form for screen readers, 16px apart', (
      tester,
    ) async {
      await pumpComponents(tester, form(), data: {'name': ''});
      expect(find.bySemanticsLabel('Sign up'), findsOneWidget);
      final field = tester.getRect(find.byType(TextField));
      final button = tester.getRect(find.text('Send'));
      expect(button.top, greaterThan(field.bottom + 16));
    });
  });

  group('TextField', () {
    testWidgets('writes every edit to its path as a string', (tester) async {
      final surfaces = await pumpComponents(
        tester,
        [
          _root({
            'component': 'TextField',
            'label': 'Seats',
            'variant': 'number',
            'value': {'@path': '/seats'},
          }),
        ],
        data: {'seats': 4},
      );
      expect(find.text('4'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      expect(surfaces.surface.dataModel.get('/seats'), '12');
    });

    testWidgets('only invalid draws the danger border, not a failed check', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _playground, [
        _column(['a', 'b']),
        {
          'id': 'a',
          'component': 'TextField',
          'label': 'Checked',
          'value': 'x',
          'checks': [
            {'condition': false, 'message': 'Never valid'},
          ],
        },
        {
          'id': 'b',
          'component': 'TextField',
          'label': 'Flagged',
          'invalid': true,
        },
      ]);
      expect(find.text('Never valid'), findsOneWidget);
      Color border(int index) {
        final box = tester
            .widgetList<Container>(
              find.ancestor(
                of: find.byType(TextField).at(index),
                matching: find.byType(Container),
              ),
            )
            .first;
        return ((box.decoration! as BoxDecoration).border! as Border).top.color;
      }

      expect(border(0), _playground.color(A2uiColorToken.borderControl));
      expect(border(1), _playground.color(A2uiColorToken.borderDanger));
    });

    testWidgets('a literal value keeps an edit', (tester) async {
      await pumpComponents(tester, [
        _root({'component': 'TextField', 'label': 'Name', 'value': 'Ada'}),
      ]);
      await tester.enterText(find.byType(TextField), 'Grace');
      await tester.pump();
      expect(find.text('Grace'), findsOneWidget);
    });

    testWidgets('shows a check after the field is left', (tester) async {
      await pumpComponents(
        tester,
        [
          _column(['f', 'g']),
          {
            'id': 'f',
            'component': 'TextField',
            'label': 'Email',
            'value': {'@path': '/email'},
            'checks': [
              {
                'condition': {
                  '@call': 'required',
                  'args': {
                    'value': {'@path': '/email'},
                  },
                },
              },
            ],
          },
          {'id': 'g', 'component': 'TextField', 'label': 'Other'},
        ],
        data: {'email': ''},
      );
      expect(find.text('Required'), findsNothing);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.tap(find.byType(TextField).last);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('variants: obscured, email keyboard, longText rows', (
      tester,
    ) async {
      await pumpComponents(tester, [
        _column(['p', 'e', 'l']),
        {
          'id': 'p',
          'component': 'TextField',
          'label': 'Password',
          'variant': 'obscured',
        },
        {
          'id': 'e',
          'component': 'TextField',
          'label': 'Email',
          'variant': 'email',
        },
        {
          'id': 'l',
          'component': 'TextField',
          'label': 'Notes',
          'variant': 'longText',
        },
      ]);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[0].obscureText, isTrue);
      expect(fields[1].keyboardType, TextInputType.emailAddress);
      expect(fields[2].minLines, 3);
      expect(fields[2].maxLines, 3);
    });

    testWidgets('is 40px tall (size xl) with the label above', (tester) async {
      await pumpComponents(tester, theme: _playground, [
        _root({
          'component': 'TextField',
          'label': 'Name',
          'placeholder': 'Your name',
        }),
      ]);
      final box = tester.getSize(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(box.height, 40);
      expect(
        tester.getRect(find.text('Name')).bottom,
        lessThan(tester.getRect(find.byType(TextField)).top),
      );
      expect(find.text('Your name'), findsOneWidget);
    });

    // Review 2a regen Q3 (RR29): the half-opacity wrapper stays in the tree,
    // as CopilotKit sets the opacity on the same element (inputs.tsx:137).
    testWidgets('keeps its editor and text when its own disabled flips', (
      tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        [
          _root({
            'component': 'TextField',
            'label': 'Seats',
            'value': {'@path': '/seats'},
            'disabled': {'@path': '/locked'},
          }),
        ],
        data: {'seats': '', 'locked': false},
      );
      // Half opacity is painted as an opacity layer of alpha 128.
      bool dimmed() => tester.layers.whereType<OpacityLayer>().any(
        (layer) => layer.alpha == 128,
      );
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      expect(dimmed(), isFalse);
      surfaces.setData('/locked', true);
      await tester.pumpAndSettle();
      expect(dimmed(), isTrue);
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(editor),
      );
      expect(editor.textEditingValue.text, '12');
      surfaces.setData('/locked', false);
      await tester.pumpAndSettle();
      expect(dimmed(), isFalse);
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(editor),
      );
      expect(editor.textEditingValue.text, '12');
      // Typing goes on in the same field.
      await tester.enterText(find.byType(TextField), '13');
      await tester.pump();
      expect(surfaces.surface.dataModel.get('/seats'), '13');
    });
  });

  group('Select', () {
    List<Map<String, Object?>> select({Object? value}) => [
      _root({
        'component': 'Select',
        'label': 'Plan',
        'placeholder': 'Pick one',
        'options': [
          'Free',
          {'value': 'team', 'label': 'Team'},
        ],
        'value': {'@path': '/plan'},
      }),
    ];

    testWidgets('shows the chosen label and writes the chosen value', (
      tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        select(),
        data: {'plan': 'Free'},
      );
      expect(find.text('Free'), findsOneWidget);
      await tester.tap(find.text('Free'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Team').last);
      await tester.pumpAndSettle();
      expect(surfaces.surface.dataModel.get('/plan'), 'team');
      expect(find.text('Team'), findsOneWidget);
    });

    // Phase 1 review 7: Chrome's `<select>` is a combobox, collapsed or
    // expanded, its chosen `<option>` selected (inputs.tsx:1119-1150); here
    // a button with that state, and option buttons (INV-003).
    testWidgets('a screen reader hears it expanded while open, and the '
        'chosen option selected', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponents(tester, select(), data: {'plan': 'Free'});

      /// What a screen reader gets of the one node named [label] (its data
      /// with its merged descendants'): the control "Plan", or an option.
      SemanticsData node(String label) {
        final found = find.semantics.byPredicate(
          (n) => !n.isMergedIntoParent && n.getSemanticsData().label == label,
        );
        expect(found, findsOne, reason: label);
        return found.evaluate().single.getSemanticsData();
      }

      expect(node('Plan').flagsCollection.isExpanded, Tristate.isFalse);
      expect(node('Plan').value, 'Free');
      await tester.tap(find.text('Free'));
      await tester.pumpAndSettle();
      expect(node('Plan').flagsCollection.isExpanded, Tristate.isTrue);
      expect(node('Free').flagsCollection.isSelected, Tristate.isTrue);
      expect(node('Team').flagsCollection.isSelected, isNot(Tristate.isTrue));
      expect(
        node('Pick one').flagsCollection.isSelected,
        isNot(Tristate.isTrue),
      );
      await tester.tap(find.text('Team').last);
      await tester.pumpAndSettle();
      expect(node('Plan').flagsCollection.isExpanded, Tristate.isFalse);
      expect(node('Plan').value, 'Team');
      handle.dispose();
    });

    testWidgets('an empty value shows the placeholder option', (tester) async {
      await pumpComponents(tester, select(), data: {'plan': ''});
      expect(find.text('Pick one'), findsOneWidget);
    });

    testWidgets('the arrow keys change the value without opening it', (
      tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        select(),
        data: {'plan': 'Free'},
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(surfaces.surface.dataModel.get('/plan'), 'team');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      // The empty option is first, as the placeholder adds it.
      expect(surfaces.surface.dataModel.get('/plan'), '');
    });
  });

  group('CheckBox', () {
    testWidgets('toggles and writes a bool; lineThrough strikes the label', (
      tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        [
          _root({
            'component': 'CheckBox',
            'label': 'Buy milk',
            'lineThrough': true,
            'value': {'@path': '/done'},
          }),
        ],
        data: {'done': false},
      );
      expect(
        tester.widget<Text>(find.text('Buy milk')).style!.decoration,
        isNull,
      );
      await tester.tap(find.text('Buy milk'));
      await tester.pump();
      expect(surfaces.surface.dataModel.get('/done'), isTrue);
      expect(
        tester.widget<Text>(find.text('Buy milk')).style!.decoration,
        TextDecoration.lineThrough,
      );
      final semantics = tester.getSemantics(find.byType(CheckMark).first);
      expect(semantics.flagsCollection.isChecked, CheckedState.isTrue);
    });

    testWidgets('a required box must be checked before a Form submits', (
      tester,
    ) async {
      final surfaces = await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Form',
          'onSubmit': _event('ok'),
          'children': ['cb', 'go'],
        },
        {
          'id': 'cb',
          'component': 'CheckBox',
          'label': 'I agree',
          'required': true,
        },
        {'id': 'go', 'component': 'Button', 'label': 'Go', 'submit': true},
      ]);
      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(surfaces.actions, isEmpty);
      expect(find.text(FormValidationMessages.checkBox), findsOneWidget);
      await tester.tap(find.text('I agree'));
      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(surfaces.actions.map((a) => a.name), ['ok']);
    });
  });

  group('RadioGroup', () {
    testWidgets('chooses and writes the option value; arrows move', (
      tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        [
          _root({
            'component': 'RadioGroup',
            'label': 'Size',
            'variant': 'pills',
            'options': [
              'S',
              {'value': 'm', 'label': 'M', 'description': 'Medium'},
              'L',
            ],
            'value': {'@path': '/size'},
          }),
        ],
        data: {'size': 'S'},
      );
      expect(find.text('Medium'), findsOneWidget);
      await tester.tap(find.text('L'));
      await tester.pump();
      expect(surfaces.surface.dataModel.get('/size'), 'L');
      final chosen = _decorationAround(tester, find.text('L'));
      expect(
        (chosen.border! as Border).top.color,
        A2uiKitTheme.playground(Brightness.light).color(A2uiColorToken.accent),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(surfaces.surface.dataModel.get('/size'), isNot('L'));
    });
  });

  // A choice control's `aria-invalid` is `check.invalid` (inputs.tsx:1126,
  // :1228, :1313): a failed check shown (touched, or with a value) whose
  // severity is an error (standard/checks.ts:21-24).
  group('aria-invalid', () {
    /// The Select, the CheckBox and the RadioGroup, each failing the check
    /// at `/check`.
    List<Map<String, Object?>> controls() {
      const checks = [
        {
          'condition': {'@path': '/check'},
        },
      ];
      return [
        _column(['sel', 'box', 'radios']),
        {
          'id': 'sel',
          'component': 'Select',
          'label': 'Plan',
          'options': ['Free', 'Team'],
          'value': {'@path': '/plan'},
          'checks': checks,
        },
        {
          'id': 'box',
          'component': 'CheckBox',
          'label': 'Accept',
          'value': {'@path': '/accepted'},
          'checks': checks,
        },
        {
          'id': 'radios',
          'component': 'RadioGroup',
          'label': 'Size',
          'options': ['S', 'M'],
          'value': {'@path': '/size'},
          'checks': checks,
        },
      ];
    }

    /// Each control with a value (so its check shows untouched) unless
    /// [empty], and the check at `/check` failing with [severity].
    Map<String, Object?> data(String severity, {bool empty = false}) => {
      'plan': empty ? '' : 'Free',
      'accepted': !empty,
      'size': empty ? '' : 'S',
      'check': {'valid': false, 'message': 'Not that', 'severity': severity},
    };

    SemanticsNode single(bool Function(SemanticsNode node) test) {
      final found = find.semantics.byPredicate(test);
      expect(found, findsOne);
      return found.evaluate().single;
    }

    /// The validation results of the `<select>`, the checkbox `<input>`
    /// and the `<fieldset>`.
    List<SemanticsValidationResult> results() => [
      single(
        (n) => n.flagsCollection.isButton && n.label == 'Plan',
      ).validationResult,
      single(
        (n) =>
            n.flagsCollection.isChecked != CheckedState.none &&
            !n.flagsCollection.isInMutuallyExclusiveGroup &&
            n.label == 'Accept',
      ).validationResult,
      single((n) => n.role == SemanticsRole.radioGroup).validationResult,
    ];

    const invalid = SemanticsValidationResult.invalid;
    const none = SemanticsValidationResult.none;

    testWidgets('a shown error check makes each invalid', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponents(tester, controls(), data: data('error'));
      expect(find.text('Not that'), findsNWidgets(3));
      expect(results(), [invalid, invalid, invalid]);
      handle.dispose();
    });

    testWidgets('a warning or an info shows but leaves each valid', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final surfaces = await pumpComponents(
        tester,
        controls(),
        data: data('warning'),
      );
      expect(find.text('Not that'), findsNWidgets(3));
      expect(results(), [none, none, none]);
      surfaces.setData('/check/severity', 'info');
      await tester.pump();
      expect(find.text('Not that'), findsNWidgets(3));
      expect(results(), [none, none, none]);
      handle.dispose();
    });

    testWidgets('an empty control is valid until it is left', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponents(
        tester,
        controls(),
        data: data('error', empty: true),
      );
      expect(find.text('Not that'), findsNothing);
      expect(results(), [none, none, none]);
      // Tab into each control and out of it: each is touched.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      await tester.pump();
      expect(find.text('Not that'), findsNWidgets(3));
      expect(results(), [invalid, invalid, invalid]);
      handle.dispose();
    });
  });

  group("a Form's constraints", () {
    List<Map<String, Object?>> formWith(
      List<Map<String, Object?>> fields, {
      List<Map<String, Object?>>? buttons,
    }) {
      final buttonList =
          buttons ??
          [
            {
              'id': 'send',
              'component': 'Button',
              'label': 'Send',
              'submit': true,
            },
          ];
      return [
        {
          'id': 'root',
          'component': 'Form',
          'onSubmit': _event('submit'),
          'children': [
            for (final field in fields) field['id']! as String,
            for (final button in buttonList) button['id']! as String,
          ],
        },
        ...fields,
        ...buttonList,
      ];
    }

    Future<List<String>> submitted(
      WidgetTester tester,
      TestSurfaces surfaces,
    ) async {
      await tester.tap(find.text('Send'));
      await tester.pump();
      return [for (final action in surfaces.actions) action.name];
    }

    testWidgets('a required RadioGroup must have a choice', (tester) async {
      final surfaces = await pumpComponents(
        tester,
        formWith([
          {
            'id': 'size',
            'component': 'RadioGroup',
            'required': true,
            'options': ['S', 'M'],
            'value': {'@path': '/size'},
          },
        ]),
        data: {'size': ''},
      );
      expect(await submitted(tester, surfaces), isEmpty);
      expect(find.text(FormValidationMessages.selectOption), findsOneWidget);
      await tester.tap(find.text('M'));
      await tester.pump();
      expect(await submitted(tester, surfaces), ['submit']);
    });

    testWidgets('a required Select needs a value one of its options has', (
      tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        formWith([
          {
            'id': 'plan',
            'component': 'Select',
            'required': true,
            'options': ['Free', 'Team'],
            'value': {'@path': '/plan'},
          },
        ]),
        data: {'plan': 'Gold'},
      );
      expect(await submitted(tester, surfaces), isEmpty);
      expect(find.text(FormValidationMessages.selectItem), findsOneWidget);
      surfaces.setData('/plan', '');
      await tester.pump();
      expect(await submitted(tester, surfaces), isEmpty);
      surfaces.setData('/plan', 'Team');
      await tester.pump();
      expect(await submitted(tester, surfaces), ['submit']);
    });

    testWidgets('email and url fields need an address', (tester) async {
      final surfaces = await pumpComponents(
        tester,
        formWith([
          {
            'id': 'mail',
            'component': 'TextField',
            'variant': 'email',
            'value': {'@path': '/mail'},
          },
          {
            'id': 'site',
            'component': 'TextField',
            'variant': 'url',
            'value': {'@path': '/site'},
          },
        ]),
        data: {'mail': 'ada', 'site': 'example.com'},
      );
      expect(await submitted(tester, surfaces), isEmpty);
      expect(find.text(FormValidationMessages.email), findsOneWidget);
      surfaces.setData('/mail', 'ada@example.com');
      await tester.pump();
      expect(await submitted(tester, surfaces), isEmpty);
      expect(find.text(FormValidationMessages.url), findsOneWidget);
      surfaces.setData('/site', 'https://example.com');
      await tester.pump();
      expect(await submitted(tester, surfaces), ['submit']);
    });

    testWidgets('a number field that holds no number writes "" and blocks', (
      tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        formWith([
          {
            'id': 'age',
            'component': 'TextField',
            'variant': 'number',
            'value': {'@path': '/age'},
          },
        ]),
        data: {'age': '12'},
      );
      for (final text in ['-', '1e', '.']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump();
        expect(surfaces.surface.dataModel.get('/age'), '', reason: text);
        // The text stays as typed.
        expect(find.text(text), findsOneWidget, reason: text);
        expect(await submitted(tester, surfaces), isEmpty, reason: text);
        expect(find.text(FormValidationMessages.number), findsOneWidget);
      }
      await tester.enterText(find.byType(TextField), '-1.5e3');
      await tester.pump();
      expect(surfaces.surface.dataModel.get('/age'), '-1.5e3');
      expect(await submitted(tester, surfaces), ['submit']);
    });

    testWidgets('Enter does not submit when the default button is disabled', (
      tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        formWith(
          [
            {
              'id': 'name',
              'component': 'TextField',
              'value': {'@path': '/name'},
            },
          ],
          buttons: [
            {
              'id': 'send',
              'component': 'Button',
              'label': 'Send',
              'submit': true,
              'disabled': true,
            },
          ],
        ),
        data: {'name': ''},
      );
      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(surfaces.actions, isEmpty);
    });

    testWidgets('the default button is the first submit button in the tree', (
      tester,
    ) async {
      final name = {
        'id': 'name',
        'component': 'TextField',
        'value': {'@path': '/name'},
      };
      final later = {
        'id': 'later',
        'component': 'Button',
        'label': 'Later',
        'submit': true,
      };
      final surfaces = await pumpComponents(
        tester,
        formWith([name], buttons: [later]),
        data: {'name': ''},
      );
      // The student is typing when the update arrives.
      await tester.enterText(find.byType(TextField), 'Ad');
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      // A disabled submit button arrives before the first one: it joins the
      // form after it, but comes first in the tree.
      surfaces.apply([
        {
          'version': '1.0',
          'updateComponents': {
            'surfaceId': testSurfaceId,
            'components': formWith(
              [name],
              buttons: [
                {
                  'id': 'first',
                  'component': 'Button',
                  'label': 'First',
                  'submit': true,
                  'disabled': true,
                },
                later,
              ],
            ),
          },
        },
      ]);
      // The container lays its children out again a frame later; the field
      // keeps its editor, its text and its keyboard connection, as
      // CopilotKit keeps the input's DOM node (INV-032: FocusRing used to
      // change its tree when the ring came or went, remounting the field).
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(editor),
      );
      expect(editor.textEditingValue.text, 'Ad');
      expect(tester.testTextInput.hasAnyClients, isTrue);
      // Typing goes on through the same connection.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Ada',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pump();
      // The text reached the field, so Enter is a real implicit submission.
      expect(surfaces.surface.dataModel.get('/name'), 'Ada');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(surfaces.actions, isEmpty);
    });

    // A component that arrives after a later sibling joins the form after
    // it, while the tree has it first: the form must go by the tree.
    List<Map<String, Object?>> formWithPending(List<String> children) => [
      {
        'id': 'root',
        'component': 'Form',
        'onSubmit': _event('submit'),
        'children': children,
      },
    ];

    Map<String, Object?> update(List<Map<String, Object?>> components) => {
      'version': '1.0',
      'updateComponents': {
        'surfaceId': testSurfaceId,
        'components': components,
      },
    };

    testWidgets('a late field above another reports first', (tester) async {
      final surfaces = await pumpComponents(
        tester,
        [
          ...formWithPending(['first', 'second', 'send']),
          {
            'id': 'second',
            'component': 'TextField',
            'label': 'Second',
            'required': true,
            'value': {'@path': '/second'},
          },
          {
            'id': 'send',
            'component': 'Button',
            'label': 'Send',
            'submit': true,
          },
        ],
        data: {'first': '', 'second': ''},
      );
      expect(find.text('Second'), findsOneWidget);
      // The first field's component comes after the second one is mounted.
      surfaces.apply([
        update([
          {
            'id': 'first',
            'component': 'TextField',
            'label': 'First',
            'required': true,
            'value': {'@path': '/first'},
          },
        ]),
      ]);
      await tester.pump();
      expect(find.text('First'), findsOneWidget);

      expect(await submitted(tester, surfaces), isEmpty);
      final message = find.text(FormValidationMessages.fillOut);
      expect(message, findsOneWidget);
      // The message is the first field's: above the second field's label.
      expect(
        tester.getRect(message).top,
        lessThan(tester.getRect(find.text('Second')).top),
      );
    });

    testWidgets('a late submit button above another is the default one', (
      tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        [
          ...formWithPending(['name', 'first', 'later']),
          {
            'id': 'name',
            'component': 'TextField',
            'value': {'@path': '/name'},
          },
          {
            'id': 'later',
            'component': 'Button',
            'label': 'Later',
            'submit': true,
          },
        ],
        data: {'name': ''},
      );
      expect(find.text('Later'), findsOneWidget);
      // A disabled submit button arrives after the enabled one, above it.
      surfaces.apply([
        update([
          {
            'id': 'first',
            'component': 'Button',
            'label': 'First',
            'submit': true,
            'disabled': true,
          },
        ]),
      ]);
      await tester.pump();
      // The container lays its children out again a frame later.
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Ada');
      // The text reached the field, so Enter is a real implicit submission.
      expect(surfaces.surface.dataModel.get('/name'), 'Ada');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      // The default button is disabled, so Enter does not submit.
      expect(surfaces.actions, isEmpty);
      // The enabled button still submits.
      await tester.tap(find.text('Later'));
      await tester.pump();
      expect([for (final action in surfaces.actions) action.name], ['submit']);
    });
  });

  // RULEBOOK section 2, the focus outline row: Chromium's `:focus-visible`
  // (selector_checker.cc:3893-3902). A press focuses the control, as a
  // browser's press focuses a `<button>`, a checkbox, a radio or a link,
  // with no ring until a key goes down with Ctrl, Alt and Meta up; focus
  // that Tab gives shows the ring at once. Pressed with a mouse in
  // Flutter's traditional highlight mode, where Flutter alone would show a
  // ring after the press.
  group(':focus-visible', () {
    final controls = <String, (Map<String, Object?>, String)>{
      'Button': ({'component': 'Button', 'label': 'Go'}, 'Go'),
      'CheckBox': ({'component': 'CheckBox', 'label': 'Terms'}, 'Terms'),
      'RadioGroup': (
        {
          'component': 'RadioGroup',
          'options': ['Team', 'Solo'],
        },
        'Solo',
      ),
      'Select': (
        {
          'component': 'Select',
          'label': 'Plan',
          'options': ['Team', 'Solo'],
          'value': 'Team',
        },
        'Team',
      ),
      'Link': (
        {'component': 'Link', 'text': 'docs', 'href': 'mailto:a@b.c'},
        'docs',
      ),
      'List item': (
        {
          'component': 'List',
          'items': ['Pick me'],
          'action': _event('pick'),
        },
        'Pick me',
      ),
    };

    bool ringShows(WidgetTester tester) => tester
        .widgetList<FocusRing>(find.byType(FocusRing))
        .any((ring) => ring.visible);

    /// Whether the focus is on an element inside the surface around [text]
    /// (not the route's own scope, which is around everything).
    bool focusedAround(WidgetTester tester, String text) {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused == null) return false;
      final element = find.byElementPredicate((e) => identical(e, focused));
      return find
              .descendant(of: find.byType(A2uiSurface), matching: element)
              .evaluate()
              .isNotEmpty &&
          find
              .ancestor(
                of: find.text(text, findRichText: true).first,
                matching: element,
              )
              .evaluate()
              .isNotEmpty;
    }

    for (final MapEntry(key: name, value: (props, text)) in controls.entries) {
      testWidgets('$name: a mouse press focuses it with no ring until a key', (
        tester,
      ) async {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.automatic,
        );
        await pumpComponents(tester, [
          _column(['c']),
          {'id': 'c', ...props},
        ]);
        expect(focusedAround(tester, text), isFalse);
        await tester.tap(
          find.text(text, findRichText: true).first,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        if (name == 'Select') {
          // The press opens the native list's stand-in, a menu; close it.
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          // Escape is a key with Ctrl, Alt and Meta up: the ring shows.
          expect(ringShows(tester), isTrue);
          return;
        }
        expect(focusedAround(tester, text), isTrue);
        expect(ringShows(tester), isFalse);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();
        expect(ringShows(tester), isFalse);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(ringShows(tester), isTrue);
      });

      testWidgets('$name: Tab focuses it with the ring', (tester) async {
        await pumpComponents(tester, [
          _column(['c']),
          {'id': 'c', ...props},
        ]);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        // A RadioGroup with no choice: the first radio is its tab stop.
        expect(
          focusedAround(tester, name == 'RadioGroup' ? 'Team' : text),
          isTrue,
        );
        expect(ringShows(tester), isTrue);
      });
    }
  });
}
