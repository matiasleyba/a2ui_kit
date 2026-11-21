import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/icons/lucide.dart';
import 'package:a2ui_kit/src/foundation/interaction/checks.dart';
import 'package:a2ui_kit/src/foundation/interaction/envelope.dart';
import 'package:a2ui_kit/src/foundation/interaction/focus_visible.dart';
import 'package:a2ui_kit/src/foundation/interaction/form_scope.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The standard `Select`: a dropdown of options that writes the chosen
/// option's value to the path `value` is bound to.
///
/// The box takes the control look (default size `xl`, a pill), shows the
/// chosen option's label and a 12px chevron, and an optional 16px Lucide
/// `icon` before it. An empty option comes first when there is a
/// `placeholder`, `clearable` is set or the value is empty; its text is
/// `clearLabel`, else `placeholder`. The list is a menu (CopilotKit keeps
/// the browser's native list); an option's `description` is its tooltip.
/// Up and Down change the value without opening it, as a native select
/// does on the desktop. `searchable` and `name` are ignored, as in
/// CopilotKit.
///
/// Deliberate difference (Chrome exposes a `<select>` as a combobox,
/// collapsed or expanded, its chosen `<option>` selected): for screen
/// readers the control is a button, expanded while its menu is open and
/// valued by the chosen option's label, and each option a button, the
/// chosen one selected: Flutter's combobox role has no semantics checks and
/// fails them in debug (INV-003).
Widget buildSelect(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = SelectProps(props);
  return _SelectView(
    label: view.label,
    options: InputOption.listOf(view.options),
    value: asInputText(props.value('value')),
    rawValue: props.value('value'),
    placeholder: view.placeholder,
    clearable: view.clearable ?? false,
    clearLabel: view.clearLabel,
    required: view.required ?? false,
    disabled: view.disabled ?? false,
    icon: view.icon,
    block: view.block ?? true,
    size: view.size,
    pill: view.pill,
    check: firstFailedCheck(node),
    write: valueWriter(node, props, 'value'),
    envelope: KitEnvelope.of(props),
  );
}

class _SelectView extends StatefulWidget {
  const _SelectView({
    required this.options,
    required this.value,
    required this.size,
    required this.pill,
    required this.block,
    required this.envelope,
    this.rawValue,
    this.label,
    this.placeholder,
    this.clearable = false,
    this.clearLabel,
    this.required = false,
    this.disabled = false,
    this.icon,
    this.check,
    this.write,
  });

  /// The envelope's name: its `Field` is a group of that name (`NodeView`'s
  /// node), and the `<select>` takes it too (`controlAria`,
  /// inputs.tsx:1137).
  final KitEnvelope envelope;

  final String? label;
  final List<InputOption> options;
  final String value;
  final Object? rawValue;
  final String? placeholder;
  final bool clearable;
  final String? clearLabel;
  final bool required;
  final bool disabled;
  final String? icon;
  final bool block;
  final A2uiControlSize size;
  final bool pill;
  final FailedCheck? check;
  final bool Function(Object? value)? write;

  @override
  State<_SelectView> createState() => _SelectViewState();
}

class _SelectViewState extends State<_SelectView> implements FormFieldValidity {
  final MenuController _menu = MenuController();
  late final FocusNode _focus = FocusNode(debugLabel: 'a2ui Select');

  /// The `<select>`'s `:focus-visible`: a press focuses it with no ring
  /// until a key (RULEBOOK section 2, the focus outline row).
  late final FocusVisibility _visibility = FocusVisibility(_focus)
    ..addListener(_visibilityChanged);
  A2uiFormController? _form;
  late String _value = widget.value;
  bool _touched = false;
  String? _reported;

  void _visibilityChanged() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final form = A2uiFormScope.maybeOf(context);
    if (form != _form) {
      _form?.removeField(this);
      _form = form?..addField(this);
    }
  }

  /// Whether the user chose in a Select with a literal value: the choice
  /// then wins over the literal, as CopilotKit's local overrides do.
  bool _edited = false;

  @override
  void didUpdateWidget(_SelectView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.write != null || (!_edited && widget.value != oldWidget.value)) {
      _value = widget.value;
    }
  }

  @override
  void dispose() {
    _form?.removeField(this);
    _visibility
      ..removeListener(_visibilityChanged)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _hasEmptyOption =>
      (widget.placeholder?.isNotEmpty ?? false) ||
      widget.clearable ||
      _value.isEmpty;

  /// The values in list order, the empty option first when there is one.
  List<String> get _values => [
    if (_hasEmptyOption) '',
    for (final option in widget.options) option.value,
  ];

  void _choose(String value) {
    // A native select sends no change for the option already chosen.
    if (value == _value) return;
    final write = widget.write;
    if (write == null) {
      _edited = true;
    } else if (!write(value)) {
      return;
    }
    setState(() {
      _value = value;
      _reported = null;
    });
  }

  void _step(int delta) {
    final values = _values;
    if (values.isEmpty) return;
    final index = values.indexOf(_value);
    final next = (index < 0 ? 0 : index + delta).clamp(0, values.length - 1);
    if (values[next] != _value) _choose(values[next]);
  }

  @override
  bool get blocksImplicitSubmission => false;

  @override
  String? get validationMessage =>
      // A value no option has leaves a native select with no option
      // chosen, so its value is "" too.
      !widget.disabled &&
          widget.required &&
          (_value.isEmpty ||
              !widget.options.any((option) => option.value == _value))
      ? FormValidationMessages.selectItem
      : null;

  @override
  void reportValidity(String message) {
    setState(() {
      _reported = message;
      _touched = true;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = A2uiKitScope.themeOf(context);
    final size = widget.size;
    final padX = controlPadX(size);
    final fontSize = baseFontSize(context) * controlFontEm(size);
    final check = widget.check;
    final shown = check != null && (_touched || hasCheckValue(widget.rawValue))
        ? check
        : null;
    final reported = _reported == null
        ? null
        : FailedCheck(message: _reported!, severity: A2uiCheckSeverity.error);
    final radius = BorderRadius.circular(
      widget.pill ? 9999 : (theme.radius('md') ?? 8),
    );
    final emptyText = widget.clearLabel ?? widget.placeholder ?? '';
    String labelOf(String value) {
      if (value.isEmpty) return emptyText;
      for (final option in widget.options) {
        if (option.value == value) return option.label;
      }
      // A value no option has shows as the empty option, as in a native
      // select.
      return emptyText;
    }

    final textColor = theme.color(A2uiColorToken.textDefault);
    final iconData = lucideIcon(widget.icon, release: LucideRelease.reactCore);
    Widget box = Container(
      constraints: BoxConstraints(minHeight: controlHeight(size)),
      padding: EdgeInsets.only(
        left: iconData != null ? padX + 24 : padX,
        right: 32,
      ),
      // A Select has no `invalid` prop: its border never turns red.
      decoration: controlDecoration(theme, pill: widget.pill, invalid: false),
      alignment: AlignmentDirectional.centerStart,
      // The chosen option is the `<select>`'s value, not part of its name
      // (the node's `value` below).
      child: ExcludeSemantics(
        child: Text(
          labelOf(_value),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: fontSize, color: textColor),
        ),
      ),
    );
    box = Stack(
      children: [
        box,
        if (iconData != null)
          Positioned(
            left: padX,
            top: 0,
            bottom: 0,
            child: Center(
              child: LucideGlyph(
                iconData,
                size: 16,
                color: theme.color(A2uiColorToken.textSecondary),
              ),
            ),
          ),
        const Positioned(
          right: 12,
          top: 0,
          bottom: 0,
          child: Center(child: _Chevron()),
        ),
      ],
    );
    final options = [
      if (_hasEmptyOption) InputOption(value: '', label: emptyText),
      ...widget.options,
    ];
    box = MenuAnchor(
      controller: _menu,
      childFocusNode: _focus,
      alignmentOffset: const Offset(0, 4),
      // The control's expanded state follows the menu.
      onOpen: () => setState(() {}),
      onClose: () {
        if (mounted) setState(() {});
      },
      menuChildren: [
        for (final option in options)
          _optionItem(option, selected: option.value == _value),
      ],
      child: box,
    );
    box = withMaterialLocalizations(context, box);
    box = FocusRing(
      visible: _visibility.visible,
      borderRadius: radius,
      child: box,
    );
    // Always present (one tree shape, RULEBOOK §2): the menu anchor and its
    // focus keep their state when `disabled` flips.
    box = Opacity(opacity: widget.disabled ? .5 : 1, child: box);
    final label = widget.label;
    // The `<select>` is an element of its own (inputs.tsx:1110-1140): its
    // node never merges into a form or group around it.
    box = Semantics(
      container: true,
      button: true,
      enabled: !widget.disabled,
      label:
          widget.envelope.label ??
          (label == null || label.isEmpty ? widget.placeholder : label),
      hint: widget.envelope.description,
      value: labelOf(_value),
      // Chrome's `<select>` is a combobox, collapsed or expanded with its
      // popup; here a button with that state (Flutter's combobox role has
      // no semantics checks and fails them in debug, INV-003).
      expanded: _menu.isOpen,
      // `aria-invalid={check.invalid || undefined}` (inputs.tsx:1126): a
      // failed error check shown. A Select has no `invalid` prop.
      validationResult: checkValidation(shown),
      child: FocusableActionDetector(
        focusNode: _focus,
        enabled: !widget.disabled,
        mouseCursor: widget.disabled
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        onFocusChange: (focused) {
          if (!focused) setState(() => _touched = true);
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowDown): _StepIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowUp): _StepIntent(-1),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _menu.isOpen ? _menu.close() : _menu.open(),
          ),
          _StepIntent: CallbackAction<_StepIntent>(
            onInvoke: (intent) => _step(intent.delta),
          ),
        },
        child: _visibility.listen(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.disabled
                ? null
                : () {
                    _focus.requestFocus();
                    _menu.isOpen ? _menu.close() : _menu.open();
                  },
            child: box,
          ),
        ),
      ),
    );
    if (!widget.block) {
      box = Align(
        widthFactor: 1,
        alignment: AlignmentDirectional.centerStart,
        child: box,
      );
    }
    return FieldFrame(label: label, check: reported ?? shown, control: box);
  }

  Widget _optionItem(InputOption option, {required bool selected}) {
    Widget item = MenuItemButton(
      onPressed: () {
        _choose(option.value);
        _focus.requestFocus();
      },
      trailingIcon: selected
          ? LucideGlyph(
              lucideIcon('check', release: LucideRelease.reactCore)!,
              size: 16,
            )
          : null,
      child: Text(option.label.isEmpty ? ' ' : option.label),
    );
    final description = option.description;
    if (description != null && description.isNotEmpty) {
      item = Tooltip(message: description, child: item);
    }
    // An `<option>` is selected when it is the value (Chrome tells a
    // screen reader so); the check glyph is drawn only. One node: the
    // item's button, its label and that state.
    return MergeSemantics(
      child: Semantics(selected: selected, child: item),
    );
  }
}

class _StepIntent extends Intent {
  const _StepIntent(this.delta);

  final int delta;
}

/// The 12px chevron of a native select without its native look: a grey
/// `M3 4.5 6 7.5 9 4.5` stroke.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size.square(12), painter: _ChevronPainter());
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 12;
    canvas.drawPath(
      Path()
        ..moveTo(3 * scale, 4.5 * scale)
        ..lineTo(6 * scale, 7.5 * scale)
        ..lineTo(9 * scale, 4.5 * scale),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xff8e8e93),
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => false;
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/inputs.tsx
