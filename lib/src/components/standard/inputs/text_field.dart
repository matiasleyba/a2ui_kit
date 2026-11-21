import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/interaction/checks.dart';
import 'package:a2ui_kit/src/foundation/interaction/envelope.dart';
import 'package:a2ui_kit/src/foundation/interaction/form_scope.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The standard `TextField`: a labelled text input that writes what the
/// user types to the path `value` is bound to, always as a string (also
/// for `number`). `longText` is a three-row text area.
///
/// The default size is `xl` (40px), a pill. `checks` show under the field
/// once it was left or holds a value. In a Form, `required` and the
/// `email` and `url` variants are checked before the Form submits, and
/// Enter submits it. `name` and `mask` are accepted and ignored, as in
/// CopilotKit (there is no native form post).
Widget buildTextField(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = TextFieldProps(props);
  return KitTextControl(
    label: view.label,
    placeholder: view.placeholder,
    value: asInputText(props.value('value')),
    rawValue: props.value('value'),
    variant: view.variant,
    required: view.required ?? false,
    disabled: view.disabled ?? false,
    invalid: view.invalid ?? false,
    autoSelect: view.autoSelect ?? false,
    size: view.size,
    pill: view.pill,
    check: firstFailedCheck(node),
    write: valueWriter(node, props, 'value'),
    envelope: KitEnvelope.of(props),
  );
}

/// A text input or text area with CopilotKit's control look: the shared
/// control of TextField (and later TextArea).
class KitTextControl extends StatefulWidget {
  /// A text control.
  const KitTextControl({
    required this.value,
    required this.variant,
    required this.size,
    required this.pill,
    this.rawValue,
    this.label,
    this.placeholder,
    this.required = false,
    this.disabled = false,
    this.invalid = false,
    this.autoSelect = false,
    this.check,
    this.write,
    this.rows = 3,
    this.maxRows,
    this.autoResize = false,
    this.envelope = KitEnvelope.none,
    super.key,
  });

  /// The name the component's accessibility envelope gives it: the field's
  /// `Field` is then a group of that name (inputs.tsx:190-213, `NodeView`'s
  /// node here), and the input takes it too (`controlAria`, :536), as
  /// ARIA names do not inherit.
  final KitEnvelope envelope;

  /// The visible label.
  final String? label;

  /// Shown while the field is empty.
  final String? placeholder;

  /// The text the props give.
  final String value;

  /// The value as the props give it, for the checks' "has a value" rule.
  final Object? rawValue;

  /// The kind of input.
  final TextFieldVariant variant;

  /// Whether a Form needs it filled in.
  final bool required;

  /// Whether it is greyed out and does not take input.
  final bool disabled;

  /// Whether it draws as invalid.
  final bool invalid;

  /// Whether focusing it selects its text.
  final bool autoSelect;

  /// The control size.
  final A2uiControlSize size;

  /// Pill corners (single-line only; a text area has 8px corners).
  final bool pill;

  /// The failed check of the field's `checks`.
  final FailedCheck? check;

  /// Writes an edit to the bound path, or null for a literal value.
  final bool Function(Object? value)? write;

  /// The rows of a text area.
  final double rows;

  /// The most rows a text area grows to.
  final double? maxRows;

  /// Whether a text area grows with its text.
  final bool autoResize;

  @override
  State<KitTextControl> createState() => _KitTextControlState();
}

class _KitTextControlState extends State<KitTextControl>
    implements FormFieldValidity {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  late final FocusNode _focus = FocusNode(debugLabel: 'a2ui TextField');
  A2uiFormController? _form;
  bool _touched = false;
  String? _reported;

  /// Whether the user edited a field with a literal value.
  bool _edited = false;

  /// The value this field last wrote to its path, until its data changes.
  String? _written;

  bool get _multiline => widget.variant == TextFieldVariant.longText;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final form = A2uiFormScope.maybeOf(context);
    if (form != _form) {
      _form?.removeField(this);
      _form = form?..addField(this);
    }
  }

  @override
  void didUpdateWidget(KitTextControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A bound field shows its data, except the value it wrote itself (a
    // number field writes "" for "-" and keeps showing "-"). A literal one
    // follows the literal until the user edits it; the edit then wins, as
    // CopilotKit's local overrides do until the field is remounted.
    final follows = widget.write != null
        ? widget.value != _written
        : !_edited && widget.value != oldWidget.value;
    if (follows && widget.value != _controller.text) {
      _written = null;
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _form?.removeField(this);
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus && widget.autoSelect) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    }
    // Leaving the field marks it touched, so its checks show.
    setState(() => _touched |= !_focus.hasFocus);
  }

  bool get _number => widget.variant == TextFieldVariant.number;

  void _onChanged(String text) {
    // A number input's value is "" while its text is not a number.
    final value = _number && !isHtmlNumber(text) ? '' : text;
    final write = widget.write;
    if (write == null) {
      _edited = true;
    } else if (write(value)) {
      _written = value;
    } else {
      _controller.text = widget.value;
    }
    setState(() => _reported = null);
  }

  @override
  bool get blocksImplicitSubmission => !_multiline;

  @override
  String? get validationMessage {
    if (widget.disabled) return null;
    final text = _controller.text;
    if (widget.required && text.isEmpty) return FormValidationMessages.fillOut;
    if (text.isEmpty) return null;
    if (_number && !isHtmlNumber(text)) return FormValidationMessages.number;
    return switch (widget.variant) {
      TextFieldVariant.email when !htmlEmail.hasMatch(text.trim()) =>
        FormValidationMessages.email,
      TextFieldVariant.url when !isHtmlUrl(text) => FormValidationMessages.url,
      _ => null,
    };
  }

  @override
  void reportValidity(String message) {
    setState(() {
      _reported = message;
      _touched = true;
    });
    _focus.requestFocus();
  }

  TextInputType get _keyboard => switch (widget.variant) {
    TextFieldVariant.longText => TextInputType.multiline,
    TextFieldVariant.number => const TextInputType.numberWithOptions(
      signed: true,
      decimal: true,
    ),
    TextFieldVariant.email => TextInputType.emailAddress,
    TextFieldVariant.url => TextInputType.url,
    TextFieldVariant.tel => TextInputType.phone,
    _ => TextInputType.text,
  };

  @override
  Widget build(BuildContext context) {
    final theme = A2uiKitScope.themeOf(context);
    final base = baseFontSize(context);
    final size = widget.size;
    final fontSize = base * controlFontEm(size);
    final padX = controlPadX(size);
    final check = widget.check;
    final shown = check != null && (_touched || hasCheckValue(widget.rawValue))
        ? check
        : null;
    final reported = _reported == null
        ? null
        : FailedCheck(message: _reported!, severity: A2uiCheckSeverity.error);
    // Only the `invalid` prop draws the danger border (`controlStyle`); a
    // failed check shows its message alone.
    final invalid = widget.invalid;
    final pill = !_multiline && widget.pill;
    final radius = BorderRadius.circular(
      pill ? 9999 : (theme.radius('md') ?? 8),
    );
    final textColor = theme.color(A2uiColorToken.textDefault);
    final obscured = widget.variant == TextFieldVariant.obscured;
    final number = widget.variant == TextFieldVariant.number;
    final label = widget.label;
    final hasLabel = label != null && label.isNotEmpty;
    final lineHeight = _multiline ? 1.5 : null;

    Widget field = TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: !widget.disabled,
      obscureText: obscured,
      autocorrect: !obscured && !number,
      enableSuggestions: !obscured && !number,
      keyboardType: _keyboard,
      textInputAction: _multiline ? TextInputAction.newline : null,
      inputFormatters: number ? [_numberFormatter] : null,
      minLines: _multiline ? widget.rows.round().clamp(1, 1000) : null,
      maxLines: _multiline
          ? (widget.autoResize
                ? widget.maxRows?.round().clamp(1, 1000)
                : widget.rows.round().clamp(1, 1000))
          : 1,
      cursorColor: textColor,
      style: TextStyle(
        fontSize: fontSize,
        color: textColor,
        height: lineHeight,
      ),
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration.collapsed(
        hintText: widget.placeholder,
        hintStyle: TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          color: theme.color(A2uiColorToken.textTertiary),
        ),
      ).copyWith(isDense: true),
      onChanged: _onChanged,
      onSubmitted: _multiline ? null : (_) => _form?.submitImplicitly(),
    );
    // The `<input>` is an element of its own, named by its `<label>` (or
    // its placeholder, inputs.tsx:528), or by the envelope (`controlAria`).
    final envelope = widget.envelope;
    field = Semantics(
      container: true,
      label: envelope.label ?? (hasLabel ? label : widget.placeholder),
      hint: envelope.description,
      // `aria-invalid={props.invalid || check.invalid || undefined}`
      // (inputs.tsx:531, :568): the prop, or a failed error check shown.
      validationResult: checkValidation(shown, invalid: invalid),
      child: field,
    );
    Widget control = Container(
      constraints: BoxConstraints(minHeight: controlHeight(size)),
      padding: _multiline
          ? EdgeInsets.symmetric(horizontal: padX, vertical: padX / 2)
          : EdgeInsets.symmetric(horizontal: padX),
      decoration: controlDecoration(theme, pill: pill, invalid: invalid),
      alignment: _multiline ? Alignment.topLeft : Alignment.centerLeft,
      child: withMaterialLocalizations(
        context,
        Material(type: MaterialType.transparency, child: field),
      ),
    );
    control = FocusRing(
      visible: _focus.hasFocus,
      borderRadius: radius,
      child: control,
    );
    // Always present (one tree shape, RULEBOOK §2): a wrapper that came and
    // went with `disabled` would remount the editor and lose its focus.
    control = Opacity(opacity: widget.disabled ? .5 : 1, child: control);
    return FieldFrame(label: label, check: reported ?? shown, control: control);
  }
}

/// Accepts an edit that leaves a number or the start of one (`-`, `1.`),
/// or that only deletes: the text a number input takes.
final TextInputFormatter _numberFormatter = TextInputFormatter.withFunction(
  (oldValue, newValue) =>
      RegExp(
            r'^[-+]?\d*\.?\d*(e[-+]?\d*)?$',
            caseSensitive: false,
          ).hasMatch(newValue.text) ||
          newValue.text.length < oldValue.text.length
      ? newValue
      : oldValue,
);

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/inputs.tsx
