import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/interaction/checks.dart';
import 'package:a2ui_kit/src/foundation/interaction/envelope.dart';
import 'package:a2ui_kit/src/foundation/interaction/focus_visible.dart';
import 'package:a2ui_kit/src/foundation/interaction/form_scope.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/foundation/text/text_styles.dart';
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The kind of [CheckMark].
enum CheckMarkKind {
  /// A round checkbox.
  round,

  /// A checkbox with 6px corners.
  square,

  /// A radio button: a ring when chosen.
  radio,
}

/// CopilotKit's 20px checkbox and radio (`.a2ui-std-check`): a strong 1px
/// border on the control fill; a checked box fills with the accent and
/// shows a white check; a chosen radio is a 6px accent ring.
class CheckMark extends StatelessWidget {
  /// A mark of [kind], [checked] or not.
  const CheckMark({required this.kind, required this.checked, super.key});

  /// Box or radio.
  final CheckMarkKind kind;

  /// Checked or chosen.
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final theme = A2uiKitScope.themeOf(context);
    return CustomPaint(
      size: const Size.square(20),
      painter: _CheckMarkPainter(
        kind: kind,
        checked: checked,
        border: theme.color(A2uiColorToken.borderStrong),
        fill: theme.color(A2uiColorToken.control),
        accent: theme.color(A2uiColorToken.accent),
      ),
    );
  }
}

class _CheckMarkPainter extends CustomPainter {
  _CheckMarkPainter({
    required this.kind,
    required this.checked,
    required this.border,
    required this.fill,
    required this.accent,
  });

  final CheckMarkKind kind;
  final bool checked;
  final Color border;
  final Color fill;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = kind == CheckMarkKind.square
        ? const Radius.circular(6)
        : Radius.circular(size.width / 2);
    final outer = RRect.fromRectAndRadius(rect, radius);
    if (kind == CheckMarkKind.radio && checked) {
      // `border: 6px solid accent` on the control fill.
      canvas
        ..drawRRect(outer, Paint()..color = accent)
        ..drawCircle(rect.center, size.width / 2 - 6, Paint()..color = fill);
      return;
    }
    final paintBorder = checked ? accent : border;
    canvas
      ..drawRRect(outer, Paint()..color = paintBorder)
      ..drawRRect(outer.deflate(1), Paint()..color = checked ? accent : fill);
    if (!checked) return;
    // The check, `M20 6 9 17l-5-5` with a stroke of 3 on a 24px grid, drawn
    // 14px wide in the middle.
    const scale = 14 / 24;
    final origin = rect.center - const Offset(7, 7);
    Offset at(double x, double y) => origin + Offset(x * scale, y * scale);
    canvas.drawPath(
      Path()
        ..moveTo(at(20, 6).dx, at(20, 6).dy)
        ..lineTo(at(9, 17).dx, at(9, 17).dy)
        ..lineTo(at(4, 12).dx, at(4, 12).dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xffffffff),
    );
  }

  @override
  bool shouldRepaint(_CheckMarkPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.checked != checked ||
      oldDelegate.border != border ||
      oldDelegate.fill != fill ||
      oldDelegate.accent != accent;
}

/// The `md` body text of a checkbox or radio label.
TextStyle _optionTextStyle(BuildContext context, A2uiKitTheme theme) {
  final (em, lineHeight) = textScale(A2uiTextSize.md);
  return TextStyle(
    fontSize: baseFontSize(context) * em,
    height: lineHeight,
    color: theme.color(A2uiColorToken.textDefault),
  );
}

/// The standard `CheckBox`: a 20px box (round unless `shape` is `square`)
/// and its label, 8px apart; a click anywhere on the row toggles it, and
/// the new state is written as a bool. `lineThrough` strikes the label
/// while checked. A required box must be checked before a Form submits.
Widget buildCheckBox(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = CheckBoxProps(props);
  return _CheckBoxView(
    label: view.label,
    name: view.name,
    value: view.value ?? false,
    rawValue: props.value('value'),
    disabled: view.disabled ?? false,
    required: view.required ?? false,
    shape: view.shape,
    lineThrough: view.lineThrough,
    check: firstFailedCheck(node),
    write: valueWriter(node, props, 'value'),
    envelope: KitEnvelope.of(props),
  );
}

class _CheckBoxView extends StatefulWidget {
  const _CheckBoxView({
    required this.value,
    required this.shape,
    required this.lineThrough,
    required this.envelope,
    this.rawValue,
    this.label,
    this.name,
    this.disabled = false,
    this.required = false,
    this.check,
    this.write,
  });

  /// The envelope's name: the `<input>` takes it (`controlAria`,
  /// inputs.tsx:1230), its wrapper only hidden and live (:1197).
  final KitEnvelope envelope;

  final String? label;
  final String? name;
  final bool value;
  final Object? rawValue;
  final bool disabled;
  final bool required;
  final CheckBoxShape shape;
  final bool lineThrough;
  final FailedCheck? check;
  final bool Function(Object? value)? write;

  @override
  State<_CheckBoxView> createState() => _CheckBoxViewState();
}

class _CheckBoxViewState extends State<_CheckBoxView>
    implements FormFieldValidity {
  late final FocusNode _focus = FocusNode(debugLabel: 'a2ui CheckBox');

  /// The `<input type="checkbox">`'s `:focus-visible`: a press focuses it
  /// with no ring until a key (RULEBOOK section 2, the focus outline row).
  late final FocusVisibility _visibility = FocusVisibility(_focus)
    ..addListener(_visibilityChanged);
  A2uiFormController? _form;
  late bool _checked = widget.value;
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

  /// Whether the user toggled a box with a literal value: the toggle then
  /// wins over the literal, as CopilotKit's local overrides do.
  bool _edited = false;

  @override
  void didUpdateWidget(_CheckBoxView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.write != null || (!_edited && widget.value != oldWidget.value)) {
      _checked = widget.value;
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

  void _toggle() {
    if (widget.disabled) return;
    final next = !_checked;
    final write = widget.write;
    if (write == null) {
      _edited = true;
    } else if (!write(next)) {
      return;
    }
    setState(() {
      _checked = next;
      _reported = null;
    });
  }

  @override
  bool get blocksImplicitSubmission => false;

  @override
  String? get validationMessage =>
      !widget.disabled && widget.required && !_checked
      ? FormValidationMessages.checkBox
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
    final label = widget.label;
    final hasLabel = label != null && label.isNotEmpty;
    final check = widget.check;
    final shown = check != null && (_touched || hasCheckValue(widget.rawValue))
        ? check
        : null;
    final reported = _reported == null
        ? null
        : FailedCheck(message: _reported!, severity: A2uiCheckSeverity.error);
    final kind = widget.shape == CheckBoxShape.square
        ? CheckMarkKind.square
        : CheckMarkKind.round;
    Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        FocusRing(
          visible: _visibility.visible,
          borderRadius: BorderRadius.circular(
            kind == CheckMarkKind.square ? 6 : 10,
          ),
          child: CheckMark(kind: kind, checked: _checked),
        ),
        if (hasLabel)
          Flexible(
            child: Text(
              label,
              style: _optionTextStyle(context, theme).copyWith(
                decoration: widget.lineThrough && _checked
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
      ],
    );
    // Always present (one tree shape, RULEBOOK §2).
    row = Opacity(opacity: widget.disabled ? .5 : 1, child: row);
    // In NodeView's node while it puts one there ([KitEnvelope.wrapped]),
    // named by the envelope's label in place of the box's own.
    final envelope = widget.envelope;
    row = Semantics(
      container: !envelope.wrapped,
      checked: _checked,
      enabled: !widget.disabled,
      label: envelope.label != null
          ? null
          : hasLabel
          ? label
          : widget.name,
      // `aria-invalid={check.invalid || undefined}` on the `<input>`
      // (inputs.tsx:1228): a failed error check shown.
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
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _toggle(),
          ),
        },
        child: _visibility.listen(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.disabled ? null : _toggle,
            child: ExcludeSemantics(child: row),
          ),
        ),
      ),
    );
    final shownCheck = reported ?? shown;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [row, if (shownCheck != null) CheckMessage(shownCheck)],
    );
  }
}

/// The standard `RadioGroup`: a labelled group of radios, in a wrapping
/// row (`direction: "row"`, the default) or a column. `list` options are
/// plain (12px apart); `pills` and `cards` are bordered, the chosen one in
/// the accent. Choosing writes the option's value. The arrow keys move the
/// choice, as native radios do. A disabled group is inert but not greyed
/// out (a disabled fieldset has no style of its own in CopilotKit). A
/// required group needs a choice before a Form submits.
Widget buildRadioGroup(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = RadioGroupProps(props);
  return _RadioGroupView(
    label: view.label,
    options: InputOption.listOf(view.options),
    value: asInputText(props.value('value')),
    rawValue: props.value('value'),
    direction: view.direction,
    variant: view.variant ?? RadioGroupVariant.list,
    disabled: view.disabled ?? false,
    required: view.required ?? false,
    check: firstFailedCheck(node),
    write: valueWriter(node, props, 'value'),
  );
}

class _RadioGroupView extends StatefulWidget {
  const _RadioGroupView({
    required this.options,
    required this.value,
    required this.direction,
    required this.variant,
    this.rawValue,
    this.label,
    this.disabled = false,
    this.required = false,
    this.check,
    this.write,
  });

  final String? label;
  final List<InputOption> options;
  final String value;
  final Object? rawValue;
  final RadioGroupDirection direction;
  final RadioGroupVariant variant;
  final bool disabled;
  final bool required;
  final FailedCheck? check;
  final bool Function(Object? value)? write;

  @override
  State<_RadioGroupView> createState() => _RadioGroupViewState();
}

class _RadioGroupViewState extends State<_RadioGroupView>
    implements FormFieldValidity {
  final List<FocusNode> _nodes = [];

  /// Each radio's `:focus-visible` (RULEBOOK section 2, the focus outline
  /// row): a press focuses it with no ring until a key.
  final List<FocusVisibility> _visibilities = [];
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

  /// Whether the user chose in a group with a literal value: the choice
  /// then wins over the literal, as CopilotKit's local overrides do.
  bool _edited = false;

  @override
  void didUpdateWidget(_RadioGroupView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.write != null || (!_edited && widget.value != oldWidget.value)) {
      _value = widget.value;
    }
  }

  @override
  void dispose() {
    _form?.removeField(this);
    for (final visibility in _visibilities) {
      visibility
        ..removeListener(_visibilityChanged)
        ..dispose();
    }
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _node(int index) {
    while (_nodes.length <= index) {
      final node = FocusNode(debugLabel: 'a2ui Radio ${_nodes.length}');
      _nodes.add(node);
      _visibilities.add(FocusVisibility(node)..addListener(_visibilityChanged));
    }
    return _nodes[index];
  }

  FocusVisibility _visibility(int index) {
    _node(index);
    return _visibilities[index];
  }

  void _choose(String value) {
    // A radio already checked sends no change.
    if (widget.disabled || value == _value) return;
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

  /// Arrow keys: the next or previous option, wrapping, is chosen and
  /// focused.
  void _move(int from, int delta) {
    final count = widget.options.length;
    if (count == 0) return;
    final next = (from + delta + count) % count;
    _choose(widget.options[next].value);
    // The chosen radio becomes the group's tab stop after the rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _node(next).requestFocus();
    });
  }

  @override
  bool get blocksImplicitSubmission => false;

  @override
  String? get validationMessage =>
      !widget.disabled &&
          widget.required &&
          !widget.options.any((o) => o.value == _value)
      ? FormValidationMessages.selectOption
      : null;

  @override
  void reportValidity(String message) {
    setState(() {
      _reported = message;
      _touched = true;
    });
    if (widget.options.isNotEmpty) _node(0).requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = A2uiKitScope.themeOf(context);
    final variant = widget.variant;
    final textStyle = _optionTextStyle(context, theme);
    final (smEm, smLine) = textScale(A2uiTextSize.sm);
    final descriptionStyle = TextStyle(
      fontSize: baseFontSize(context) * smEm,
      height: smLine,
      color: theme.color(A2uiColorToken.textSecondary),
    );
    final selectedIndex = widget.options.indexWhere((o) => o.value == _value);
    // The tab stop is the chosen radio, else the first, as in a browser.
    final tabStop = selectedIndex < 0 ? 0 : selectedIndex;

    Widget option(int index) {
      final item = widget.options[index];
      final isSelected = item.value == _value;
      final description = item.description;
      Widget body = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: variant == RadioGroupVariant.cards
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        spacing: 8,
        children: [
          FocusRing(
            visible: _visibility(index).visible,
            borderRadius: BorderRadius.circular(10),
            child: CheckMark(kind: CheckMarkKind.radio, checked: isSelected),
          ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: textStyle),
                if (description != null && description.isNotEmpty)
                  Text(description, style: descriptionStyle),
              ],
            ),
          ),
        ],
      );
      if (variant != RadioGroupVariant.list) {
        body = Container(
          padding: variant == RadioGroupVariant.cards
              ? const EdgeInsets.all(12)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.color(
                isSelected
                    ? A2uiColorToken.accent
                    : A2uiColorToken.borderDefault,
              ),
            ),
            borderRadius: BorderRadius.circular(
              variant == RadioGroupVariant.pills
                  ? 9999
                  : (theme.radius('lg') ?? 12),
            ),
          ),
          child: body,
        );
      }
      return Semantics(
        container: true,
        inMutuallyExclusiveGroup: true,
        checked: isSelected,
        enabled: !widget.disabled,
        label: item.label,
        hint: description,
        child: FocusableActionDetector(
          focusNode: _node(index),
          enabled: !widget.disabled,
          descendantsAreFocusable: false,
          mouseCursor: widget.disabled
              ? SystemMouseCursors.forbidden
              : SystemMouseCursors.click,
          onFocusChange: (focused) {
            if (!focused) setState(() => _touched = true);
          },
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowRight): _MoveIntent(1),
            SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
            SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveIntent(-1),
            SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) => _choose(item.value),
            ),
            _MoveIntent: CallbackAction<_MoveIntent>(
              onInvoke: (intent) => _move(index, intent.delta),
            ),
          },
          child: ExcludeFocus(
            excluding: index != tabStop && !_visibility(index).visible,
            child: _visibility(index).listen(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.disabled ? null : () => _choose(item.value),
                child: ExcludeSemantics(child: body),
              ),
            ),
          ),
        ),
      );
    }

    final gap = variant == RadioGroupVariant.list ? 12.0 : 8.0;
    final options = [for (var i = 0; i < widget.options.length; i++) option(i)];
    final group = widget.direction == RadioGroupDirection.col
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: gap,
            children: options,
          )
        : Wrap(spacing: gap, runSpacing: gap, children: options);
    final label = widget.label;
    final check = widget.check;
    final shown = check != null && (_touched || hasCheckValue(widget.rawValue))
        ? check
        : null;
    final shownCheck = _reported == null
        ? shown
        : FailedCheck(message: _reported!, severity: A2uiCheckSeverity.error);
    return Semantics(
      container: true,
      role: SemanticsRole.radioGroup,
      label: label,
      // `aria-invalid={check.invalid || undefined}` on the `<fieldset>`
      // (inputs.tsx:1313): a failed error check shown.
      validationResult: checkValidation(shown),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null && label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ExcludeSemantics(
                child: Text(label, style: fieldLabelStyle(context)),
              ),
            ),
          Align(alignment: AlignmentDirectional.centerStart, child: group),
          if (shownCheck != null) CheckMessage(shownCheck),
        ],
      ),
    );
  }
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);

  final int delta;
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/inputs.tsx
