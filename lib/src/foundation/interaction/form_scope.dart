import 'dart:async';

import 'package:flutter/widgets.dart';

/// A control of a Form that takes part in its validation: an HTML form's
/// constraint validation, which runs before a form submits.
abstract interface class FormFieldValidity {
  /// The message of the constraint the field breaks (an empty required
  /// field, an email field without an email address), or null when it
  /// holds. A disabled field holds.
  String? get validationMessage;

  /// Shows [message] at the field and moves the focus to it, as a browser
  /// does with the first invalid field of a form it does not submit.
  void reportValidity(String message);

  /// Whether pressing Enter in the field submits the form (a single-line
  /// text field), HTML's "field that blocks implicit submission".
  bool get blocksImplicitSubmission;

  /// The field's place in the tree, which orders the fields as a browser
  /// does; a `State` has it already.
  BuildContext get context;
}

/// A submit button of a Form (a Button with `submit: true`).
abstract interface class FormSubmitButton {
  /// Whether the button can be pressed.
  bool get isEnabled;

  /// The button's place in the tree: the first submit button in tree
  /// order is the form's default button. A `State` has it already.
  BuildContext get context;
}

/// What a Form knows of its controls: CopilotKit's `<form>` element, whose
/// submit runs the native constraint validation, then sends `onSubmit`.
class A2uiFormController {
  /// A controller that calls [onSubmit] when the form submits.
  A2uiFormController({this.onSubmit});

  /// Sends the Form's `onSubmit`, when bound.
  Future<void> Function()? onSubmit;

  /// The Form's context. With it, the fields and buttons are taken in the
  /// order of the tree below it; without it, in the order they joined.
  BuildContext? formContext;

  final List<FormFieldValidity> _fields = [];
  final List<FormSubmitButton> _buttons = [];

  /// The fields, in the order of the tree.
  List<FormFieldValidity> get fields => List.unmodifiable(
    _inTreeOrder<FormFieldValidity>(_fields, (field) => field.context),
  );

  /// The submit buttons, in the order of the tree: the first is the
  /// form's default button.
  List<FormSubmitButton> get submitButtons => List.unmodifiable(
    _inTreeOrder<FormSubmitButton>(_buttons, (button) => button.context),
  );

  /// [items] in the order their contexts come in a walk of the tree below
  /// [formContext]. A control joins when it is mounted, so one added later
  /// above another joins after it.
  List<T> _inTreeOrder<T extends Object>(
    List<T> items,
    BuildContext Function(T item) contextOf,
  ) {
    final root = formContext;
    if (root == null || !root.mounted || items.length < 2) return items;
    final byElement = <Element, T>{
      for (final item in items)
        if (contextOf(item) case final Element element) element: item,
    };
    final ordered = <T>[];
    void visit(Element element) {
      final item = byElement[element];
      if (item != null) ordered.add(item);
      element.visitChildElements(visit);
    }

    (root as Element).visitChildElements(visit);
    return [
      ...ordered,
      for (final item in items)
        if (!ordered.contains(item)) item,
    ];
  }

  /// Adds [field].
  void addField(FormFieldValidity field) => _fields.add(field);

  /// Removes [field].
  void removeField(FormFieldValidity field) => _fields.remove(field);

  /// Adds the submit [button].
  void addSubmitButton(FormSubmitButton button) => _buttons.add(button);

  /// Removes the submit [button].
  void removeSubmitButton(FormSubmitButton button) => _buttons.remove(button);

  /// Submits the form: the first field whose constraint fails reports it,
  /// and the form does not submit; otherwise `onSubmit` is sent. Returns
  /// whether it submitted.
  ///
  /// `checks` never hold a form back, as in CopilotKit.
  Future<bool> submit() async {
    for (final field in fields) {
      final message = field.validationMessage;
      if (message != null) {
        field.reportValidity(message);
        return false;
      }
    }
    await onSubmit?.call();
    return true;
  }

  /// Enter in a single-line field: HTML's implicit submission. With a
  /// submit button the form submits unless its first one is disabled;
  /// without one, only when the field is the form's one single-line field.
  void submitImplicitly() {
    if (_buttons.isNotEmpty) {
      if (submitButtons.first.isEnabled) unawaited(submit());
      return;
    }
    final blocking = _fields.where((f) => f.blocksImplicitSubmission).length;
    if (blocking == 1) unawaited(submit());
  }
}

/// Publishes the [A2uiFormController] of a Form to its controls.
class A2uiFormScope extends InheritedWidget {
  /// Publishes [controller] to [child].
  const A2uiFormScope({
    required this.controller,
    required super.child,
    super.key,
  });

  /// The form's controller.
  final A2uiFormController controller;

  /// The controller of the Form around [context], or null outside a Form.
  static A2uiFormController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<A2uiFormScope>()?.controller;

  @override
  bool updateShouldNotify(A2uiFormScope oldWidget) =>
      controller != oldWidget.controller;
}

/// The messages of a browser's constraint validation (Chrome's, in
/// English), which CopilotKit leaves to the browser.
abstract final class FormValidationMessages {
  /// An empty required text field or select.
  static const String fillOut = 'Please fill out this field.';

  /// A required select with no option chosen.
  static const String selectItem = 'Please select an item in the list.';

  /// A required checkbox that is not checked.
  static const String checkBox =
      'Please check this box if you want to proceed.';

  /// A required radio group with no option chosen.
  static const String selectOption = 'Please select one of these options.';

  /// An email field that holds no email address.
  static const String email = 'Please enter an email address.';

  /// A URL field that holds no URL.
  static const String url = 'Please enter a URL.';

  /// A number field that holds no number.
  static const String number = 'Please enter a number.';
}

/// Whether [text] is an HTML valid floating-point number, the text an
/// `<input type=number>` takes as its value; for any other text (`-`,
/// `1e`, `.`) the value is "" and the input is a bad input.
bool isHtmlNumber(String text) => _htmlNumber.hasMatch(text);

final RegExp _htmlNumber = RegExp(
  r'^-?(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][-+]?\d+)?$',
);

/// HTML's valid email address (the `type=email` rule).
final RegExp htmlEmail = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}"
  r'[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
);

/// Whether [value] is a valid absolute URL for an `<input type=url>`: a
/// scheme and something after it.
bool isHtmlUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && uri.hasScheme && uri.toString().length > 1;
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/inputs.tsx (Form)
