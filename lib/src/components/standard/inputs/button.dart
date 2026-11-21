import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/icons/lucide.dart';
import 'package:a2ui_kit/src/foundation/interaction/checks.dart';
import 'package:a2ui_kit/src/foundation/interaction/envelope.dart';
import 'package:a2ui_kit/src/foundation/interaction/focus_visible.dart';
import 'package:a2ui_kit/src/foundation/interaction/form_scope.dart';
import 'package:a2ui_kit/src/foundation/interaction/links.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The standard `Button`.
///
/// A click, Enter or Space runs, in CopilotKit's order: inside a Form, a
/// `submit` button submits the form (and sends no `onClick`); else `href`
/// opens the URL; else `copy` copies its text and shows a check mark for
/// 1.5 seconds; else `onClick` is sent.
///
/// The content is the `child`, else the `children`, else `label` (or
/// `text`), after the Lucide `icon`. The button is disabled while
/// `disabled` or `loading` is set or an error check fails; the first failed
/// check of any severity is its tooltip. `loading` shows no spinner, as in
/// CopilotKit.
Widget buildButton(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = ButtonProps(props);
  final failed = firstFailedCheck(node);
  final single = view.child;
  final children = view.children;
  final content = single != null
      ? KeyedSubtree(key: NodeKey(single.instanceId), child: buildChild(single))
      : children.isNotEmpty
      ? Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            for (final child in children)
              KeyedSubtree(
                key: NodeKey(child.instanceId),
                child: buildChild(child),
              ),
          ],
        )
      : null;
  return KitButton(
    label: view.label ?? view.text ?? '',
    content: content,
    variant: view.variant,
    color: view.color,
    size: controlSizeOf(view.size),
    block: view.block ?? false,
    uniform: view.uniform ?? false,
    pill: view.pill,
    icon: view.icon,
    disabled:
        (view.disabled ?? false) ||
        (view.loading ?? false) ||
        (failed?.isError ?? false),
    tooltip: failed?.message,
    submit: view.submit ?? false,
    href: view.href,
    copy: view.copy,
    onClick: view.onClick,
    envelope: KitEnvelope.of(props),
  );
}

/// The colours of a Button variant: CopilotKit's `buttonVariantStyle`.
({Color? background, Color foreground, Color? border}) buttonColors(
  A2uiKitTheme theme,
  ButtonVariant variant,
  ButtonColor color,
) {
  final accent = switch (color) {
    ButtonColor.danger => theme.color(A2uiColorToken.textDanger),
    ButtonColor.secondary => theme.color(A2uiColorToken.surfaceTertiary),
    ButtonColor.primary => theme.color(A2uiColorToken.accent),
  };
  final foreground = theme.color(
    color == ButtonColor.danger
        ? A2uiColorToken.textDanger
        : A2uiColorToken.textDefault,
  );
  const transparent = Color(0x00000000);
  return switch (variant) {
    ButtonVariant.primary => (
      background: accent,
      foreground: color == ButtonColor.secondary
          ? foreground
          : theme.color(A2uiColorToken.onAccent),
      border: transparent,
    ),
    ButtonVariant.soft => (
      background: theme.color(A2uiColorToken.surfaceSecondary),
      foreground: foreground,
      border: transparent,
    ),
    ButtonVariant.default_ => (
      background: null,
      foreground: foreground,
      border: color == ButtonColor.danger
          ? accent
          : theme.color(A2uiColorToken.borderDefault),
    ),
    ButtonVariant.borderless => (
      background: null,
      foreground: foreground,
      border: null,
    ),
  };
}

/// A Button with CopilotKit's look and click order.
class KitButton extends StatefulWidget {
  /// A button.
  const KitButton({
    required this.label,
    required this.variant,
    required this.color,
    required this.size,
    this.content,
    this.block = false,
    this.uniform = false,
    this.pill = true,
    this.icon,
    this.disabled = false,
    this.tooltip,
    this.submit = false,
    this.href,
    this.copy,
    this.onClick,
    this.envelope = KitEnvelope.none,
    super.key,
  });

  /// The name the component's accessibility envelope gives the button: the
  /// `<button>` takes the envelope's ARIA (inputs.tsx:292, :327).
  final KitEnvelope envelope;

  /// The text, when there is no [content].
  final String label;

  /// Child components shown instead of [label].
  final Widget? content;

  /// The variant.
  final ButtonVariant variant;

  /// The colour.
  final ButtonColor color;

  /// The size.
  final A2uiControlSize size;

  /// Full width.
  final bool block;

  /// A square button.
  final bool uniform;

  /// Pill corners, else 8px.
  final bool pill;

  /// A Lucide icon before the content.
  final String? icon;

  /// Greyed out and inert.
  final bool disabled;

  /// Shown on hover.
  final String? tooltip;

  /// Submits the Form around it.
  final bool submit;

  /// Opens this URL.
  final String? href;

  /// Copies this text.
  final String? copy;

  /// Sent on a click.
  final NodeAction? onClick;

  @override
  State<KitButton> createState() => _KitButtonState();
}

class _KitButtonState extends State<KitButton> implements FormSubmitButton {
  A2uiFormController? _form;
  bool _copied = false;
  Timer? _copyTimer;

  /// The `<button>`'s focus: a press gives it, and its ring shows by
  /// `:focus-visible` (RULEBOOK section 2, the focus outline row).
  late final FocusNode _node = FocusNode(debugLabel: 'a2ui Button');
  late final FocusVisibility _focus = FocusVisibility(_node)
    ..addListener(_focusChanged);

  void _focusChanged() => setState(() {});

  @override
  bool get isEnabled => !widget.disabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachForm();
  }

  @override
  void didUpdateWidget(KitButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.submit != widget.submit) _attachForm(force: true);
  }

  void _attachForm({bool force = false}) {
    final form = widget.submit ? A2uiFormScope.maybeOf(context) : null;
    if (form == _form && !force) return;
    _form?.removeSubmitButton(this);
    _form = form?..addSubmitButton(this);
  }

  @override
  void dispose() {
    _form?.removeSubmitButton(this);
    _copyTimer?.cancel();
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    _node.dispose();
    super.dispose();
  }

  Future<void> _press() async {
    if (widget.disabled) return;
    final form = widget.submit ? A2uiFormScope.maybeOf(context) : null;
    if (form != null) {
      await form.submit();
      return;
    }
    final href = widget.href;
    if (href != null && href.isNotEmpty) {
      await openSafeUrl(context, href);
      return;
    }
    final copy = widget.copy;
    if (copy != null && copy.isNotEmpty) {
      try {
        await Clipboard.setData(ClipboardData(text: copy));
      } on Object {
        return;
      }
      if (!mounted) return;
      setState(() => _copied = true);
      _copyTimer?.cancel();
      _copyTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _copied = false);
      });
      return;
    }
    await widget.onClick?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = A2uiKitScope.themeOf(context);
    final size = widget.size;
    final height = controlHeight(size);
    final colors = buttonColors(theme, widget.variant, widget.color);
    final radius = BorderRadius.circular(
      widget.pill ? 9999 : (theme.radius('md') ?? 8),
    );
    final iconPx = controlIconPx(size);
    final iconData = lucideIcon(
      _copied ? 'check' : widget.icon,
      release: LucideRelease.reactCore,
    );
    final textStyle = TextStyle(
      fontSize: baseFontSize(context) * controlFontEm(size),
      fontWeight: FontWeight.w500,
      height: 1,
      color: colors.foreground,
    );
    final content =
        widget.content ??
        Text(widget.label, textAlign: TextAlign.center, style: textStyle);
    Widget button = Container(
      constraints: BoxConstraints(
        minHeight: height,
        minWidth: widget.uniform ? height : 0,
      ),
      padding: widget.uniform
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(horizontal: controlPadX(size) + 4),
      decoration: BoxDecoration(
        color: colors.background,
        border: colors.border == null
            ? null
            : Border.all(color: colors.border!),
        borderRadius: radius,
      ),
      child: Align(
        widthFactor: widget.block ? null : 1,
        heightFactor: 1,
        child: DefaultTextStyle.merge(
          style: textStyle,
          child: IconTheme.merge(
            data: IconThemeData(color: colors.foreground),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (iconData != null)
                  LucideGlyph(iconData, size: iconPx, color: colors.foreground),
                Flexible(child: content),
              ],
            ),
          ),
        ),
      ),
    );
    button = FocusRing(
      visible: _focus.visible,
      borderRadius: radius,
      child: button,
    );
    // Always present (one tree shape, RULEBOOK §2): a child component keeps
    // its state when `disabled` flips.
    button = Opacity(opacity: widget.disabled ? .5 : 1, child: button);
    // The envelope's label is the button's name in place of its content's
    // ([KitEnvelope]); one tree shape when it comes and goes.
    final envelope = widget.envelope;
    button = ExcludeSemantics(excluding: envelope.label != null, child: button);
    button = FocusableActionDetector(
      focusNode: _node,
      enabled: !widget.disabled,
      mouseCursor: widget.disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => unawaited(_press()),
        ),
      },
      child: _focus.listen(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.disabled ? null : () => unawaited(_press()),
          child: button,
        ),
      ),
    );
    // In NodeView's node while it puts one there ([KitEnvelope.wrapped]).
    button = Semantics(
      button: true,
      enabled: !widget.disabled,
      container: !envelope.wrapped,
      child: button,
    );
    final tooltip = widget.tooltip;
    if (tooltip != null && tooltip.isNotEmpty) {
      button = Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/inputs.tsx
