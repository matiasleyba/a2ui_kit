import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/data/owned_data.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/interaction/checks.dart';
import 'package:a2ui_kit/src/foundation/interaction/focus_visible.dart';
import 'package:a2ui_kit/src/foundation/interaction/links.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/foundation/text/text_styles.dart';
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The height of a control: 28, 32, 36 or 40px.
double controlHeight(A2uiControlSize size) => switch (size) {
  A2uiControlSize.sm => 28,
  A2uiControlSize.md => 32,
  A2uiControlSize.lg => 36,
  A2uiControlSize.xl => 40,
};

/// The text size of a control in em of the surface's size (13, 14, 14 and
/// 16px at a 16px base).
double controlFontEm(A2uiControlSize size) => switch (size) {
  A2uiControlSize.sm => .8125,
  A2uiControlSize.md || A2uiControlSize.lg => .875,
  A2uiControlSize.xl => 1,
};

/// The side padding of a control: 10, 12, 12 or 18px.
double controlPadX(A2uiControlSize size) => switch (size) {
  A2uiControlSize.sm => 10,
  A2uiControlSize.md || A2uiControlSize.lg => 12,
  A2uiControlSize.xl => 18,
};

/// The icon size in a control: 14, 16, 18 or 18px.
double controlIconPx(A2uiControlSize size) => switch (size) {
  A2uiControlSize.sm => 14,
  A2uiControlSize.md => 16,
  A2uiControlSize.lg || A2uiControlSize.xl => 18,
};

/// The control size of a Button size (Buttons have no `xl`).
A2uiControlSize controlSizeOf(A2uiSize size) => switch (size) {
  A2uiSize.sm => A2uiControlSize.sm,
  A2uiSize.md => A2uiControlSize.md,
  A2uiSize.lg => A2uiControlSize.lg,
};

/// The surface's font size at [context]: the size of `1em`.
double baseFontSize(BuildContext context) =>
    DefaultTextStyle.of(context).style.fontSize ??
    A2uiKitScope.themeOf(context).typography.fontSize;

/// The box of a text control (CopilotKit's `controlStyle`): the surface
/// fill, a 1px control border (danger when [invalid]) and pill or 8px
/// corners.
BoxDecoration controlDecoration(
  A2uiKitTheme theme, {
  required bool pill,
  required bool invalid,
}) => BoxDecoration(
  color: theme.color(A2uiColorToken.surface),
  border: Border.all(
    color: theme.color(
      invalid ? A2uiColorToken.borderDanger : A2uiColorToken.borderControl,
    ),
  ),
  borderRadius: BorderRadius.circular(pill ? 9999 : (theme.radius('md') ?? 8)),
);

/// The style of a field's label: the `sm` text size, medium, secondary.
TextStyle fieldLabelStyle(BuildContext context) {
  final theme = A2uiKitScope.themeOf(context);
  final (em, lineHeight) = textScale(A2uiTextSize.sm);
  return TextStyle(
    fontSize: baseFontSize(context) * em,
    height: lineHeight,
    fontWeight: FontWeight.w500,
    color: theme.color(A2uiColorToken.textSecondary),
  );
}

/// A label above a control and the failed check under it, 8px apart:
/// CopilotKit's `Field`.
class FieldFrame extends StatelessWidget {
  /// Frames [control].
  const FieldFrame({required this.control, this.label, this.check, super.key});

  /// The label, or null for none.
  final String? label;

  /// The control.
  final Widget control;

  /// The check to show under the control.
  final FailedCheck? check;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (label != null && label.isNotEmpty)
          ExcludeSemantics(child: Text(label, style: fieldLabelStyle(context))),
        control,
        if (check != null) CheckMessage(check),
      ],
    );
  }
}

/// A control a pointer and a keyboard can both use, as a browser's
/// `<a href>` or `<button>` is: a click or a tap activates it (and, as a
/// browser's press does, focuses it), Tab reaches it, Enter activates it,
/// and a [FocusRing] shows while its focus matches `:focus-visible`
/// ([FocusVisibility]).
class Activatable extends StatefulWidget {
  /// Activates [onActivate] from [child].
  const Activatable({
    required this.onActivate,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  /// Runs on a click, a tap or Enter.
  final VoidCallback onActivate;

  /// The control.
  final Widget child;

  /// The corners of the focus ring.
  final BorderRadius borderRadius;

  @override
  State<Activatable> createState() => _ActivatableState();
}

class _ActivatableState extends State<Activatable> {
  late final FocusNode _node = FocusNode(debugLabel: 'a2ui Activatable');
  late final FocusVisibility _focus = FocusVisibility(_node)
    ..addListener(_changed);

  void _changed() => setState(() {});

  @override
  void dispose() {
    _focus
      ..removeListener(_changed)
      ..dispose();
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    focusNode: _node,
    mouseCursor: SystemMouseCursors.click,
    shortcuts: activateShortcuts,
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onActivate();
          return null;
        },
      ),
    },
    child: _focus.listen(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onActivate,
        child: FocusRing(
          visible: _focus.visible,
          borderRadius: widget.borderRadius,
          child: widget.child,
        ),
      ),
    ),
  );
}

/// A focus ring: a 2px outline in the [color] token, [offset] pixels outside
/// [child], following [borderRadius], while [visible]. CopilotKit's
/// `[data-a2ui-input]:focus-visible` outline by default; the browser's own
/// outline with [A2uiColorToken.outlineRing] at offset 0.
class FocusRing extends StatelessWidget {
  /// Rings [child] while [visible].
  const FocusRing({
    required this.visible,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.offset = 1,
    this.color = A2uiColorToken.focus,
    super.key,
  });

  /// The ring's colour.
  final A2uiColorToken color;

  /// Whether the ring shows.
  final bool visible;

  /// The ringed widget.
  final Widget child;

  /// The corners of [child].
  final BorderRadius borderRadius;

  /// The gap between [child] and the ring.
  final double offset;

  @override
  Widget build(BuildContext context) {
    final color = A2uiKitScope.themeOf(context).color(this.color);
    // One shape whether the ring shows or not: returning [child] bare when
    // hidden would remount it each time the ring comes or goes, and a text
    // field would lose its editor and keyboard connection (INV-032).
    return CustomPaint(
      foregroundPainter: visible
          ? _RingPainter(color, borderRadius, offset)
          : null,
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.color, this.borderRadius, this.offset);

  final Color color;
  final BorderRadius borderRadius;
  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(offset + 1);
    final radius = borderRadius.resolve(TextDirection.ltr);
    Radius grow(Radius r) => r == Radius.zero
        ? r
        : Radius.elliptical(r.x + offset + 1, r.y + offset + 1);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: grow(radius.topLeft),
        topRight: grow(radius.topRight),
        bottomLeft: grow(radius.bottomLeft),
        bottomRight: grow(radius.bottomRight),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.offset != offset;
}

/// Writes a value to the data path the prop [key] of [node] is bound to, or
/// null when the payload gave [key] no path. The path becomes user-owned,
/// as CopilotKit's SurfaceView marks it, so `A2uiUserOwnedData` keeps the
/// agent from overwriting it. A write the data model rejects is reported
/// on the surface and returns false.
bool Function(Object? value)? valueWriter(
  KitNode node,
  ComponentProps props,
  String key,
) {
  final binding = props.writable(key);
  final context = node.context;
  if (binding == null || context == null) return null;
  final surface = context.surface;
  return (value) {
    try {
      binding.set(value);
      A2uiUserOwnedData.markOwned(
        surface,
        context.dataContext.resolvePath(binding.path),
        value,
      );
      return true;
    } on A2uiDataError catch (error) {
      unawaited(
        surface.dispatchError(
          A2uiRendererError(
            code: error.code,
            surfaceId: surface.id,
            message: error.message,
            path: error.path,
          ),
        ),
      );
      return false;
    }
  };
}

/// [child] with Material's default (English) localizations when the app
/// gives none: the text field and the select's menu need them, and a
/// surface may sit in an app that is not a `MaterialApp`.
Widget withMaterialLocalizations(BuildContext context, Widget child) {
  if (Localizations.of<MaterialLocalizations>(context, MaterialLocalizations) !=
      null) {
    return child;
  }
  return Localizations(
    locale: Localizations.maybeLocaleOf(context) ?? const Locale('en', 'US'),
    delegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
    child: child,
  );
}

/// [value] as input text: null is empty, numbers are written as JavaScript
/// writes them (CopilotKit's `asText`).
String asInputText(Object? value) =>
    ComponentProps.asString(value) ?? (value == null ? '' : '$value');

/// An option of a Select or a RadioGroup: a string, or
/// `{value, label?, description?}`.
@immutable
class InputOption {
  /// An option.
  const InputOption({
    required this.value,
    required this.label,
    this.description,
  });

  /// The value written when it is chosen.
  final String value;

  /// What it shows.
  final String label;

  /// More about it, shown as its tooltip or under it.
  final String? description;

  /// CopilotKit's `normalizeOptions`: strings and objects with a string
  /// value; anything else is skipped.
  static List<InputOption> listOf(List<Object?> options) => [
    for (final raw in options)
      if (ComponentProps.unwrap(raw) case final String value)
        InputOption(value: value, label: value)
      else if (ComponentProps.unwrap(raw) case final Map<Object?, Object?> map)
        if (ComponentProps.asString(map['value']) case final String value)
          InputOption(
            value: value,
            label: ComponentProps.asString(map['label']) ?? value,
            description: ComponentProps.asString(map['description']),
          ),
  ];
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/inputs.tsx
