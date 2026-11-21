import 'dart:async';

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/icons/lucide.dart';
import 'package:a2ui_kit/src/foundation/interaction/focus_visible.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// The playground `Alert`: an inline status with an icon, a `title`
/// (13px semibold) and a `message` (12.5px).
///
/// `tone` is `info` (the default, sky), `success` (emerald), `warning`
/// (amber) or `error` (rose), Tailwind's palette at the playground's
/// strengths; the icons are Info, CircleCheck, TriangleAlert and CircleX.
/// Screen readers get it as a status.
Widget buildAlert(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = AlertProps(props);
  final tokens = playgroundTokens(context);
  final tone = view.tone ?? AlertTone.info;
  final colors = tokens.alerts[tone]!;
  // `ALERT[tone].icon` (`renderers/feedback.tsx:15-36`): lucide-react
  // 1.57.0's `Info`, `CheckCircle2`, `AlertTriangle` and `XCircle`, the
  // last three aliases of CircleCheck, TriangleAlert and CircleX.
  final icon = lucideImport(switch (tone) {
    AlertTone.info => 'Info',
    AlertTone.success => 'CheckCircle2',
    AlertTone.warning => 'AlertTriangle',
    AlertTone.error => 'XCircle',
  }, LucideRelease.playground);
  final message = view.message;
  return Semantics(
    container: true,
    role: SemanticsRole.status,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: LucideGlyph(icon, size: 16, color: colors.icon),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  view.title ?? '',
                  style: playgroundText(
                    13,
                    weight: FontWeight.w600,
                    height: 1.375,
                    color: colors.foreground,
                  ),
                ),
                if (message != null && message.isNotEmpty)
                  Text(
                    message,
                    style: playgroundText(
                      12.5,
                      height: 1.625,
                      color: colors.foreground.withValues(
                        alpha: colors.foreground.a * .8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// The playground `Callout`: a highlighted tip in a violet gradient card,
/// with a lightbulb tile, an optional `title` (13px semibold) and the
/// `text` (12.5px).
///
/// The button (`actionLabel`) shows only when the model bound `onAction`,
/// and sends it with no arguments. The `icon` prop is ignored, as in the
/// playground (the tile always shows a lightbulb).
Widget buildCallout(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = CalloutProps(props);
  final tokens = playgroundTokens(context);
  final colors = tokens.callout;
  final title = view.title;
  final actionLabel = view.actionLabel;
  final action = view.onAction;
  final text = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (title != null && title.isNotEmpty)
        Text(
          title,
          style: playgroundText(
            13,
            weight: FontWeight.w600,
            color: tokens.foreground,
          ),
        ),
      Text(
        view.text ?? '',
        style: playgroundText(
          12.5,
          height: 1.625,
          color: tokens.foreground.withValues(alpha: tokens.foreground.a * .8),
        ),
      ),
    ],
  );
  final tile = Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: colors.icon,
      borderRadius: BorderRadius.circular(10),
    ),
    // `<Lightbulb className="size-4" />` (`renderers/feedback.tsx:70`).
    child: LucideGlyph(
      lucideImport('Lightbulb', LucideRelease.playground),
      size: 16,
      color: colors.foreground,
    ),
  );
  return Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          colors.background,
          colors.backgroundEnd ?? colors.background,
          colors.background.withValues(alpha: 0),
        ],
      ),
      border: Border.all(color: colors.border),
      borderRadius: BorderRadius.circular(tokens.radius),
    ),
    child: CssFlex(
      flex: const A2uiFlexStyle(
        direction: Axis.horizontal,
        wrap: A2uiWrap.wrap,
        rowGap: 12,
        columnGap: 12,
      ),
      box: const A2uiBoxStyle(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      children: [
        // `size-8 flex-none`: a definite height, so the row does not
        // stretch it.
        CssFlexItem(
          style: const A2uiFlexItemStyle(
            shrink: 0,
            width: A2uiLength.px(32),
            height: A2uiLength.px(32),
          ),
          child: tile,
        ),
        CssFlexItem(
          style: const A2uiFlexItemStyle(
            grow: 1,
            basis: A2uiLength.percent(0),
            minWidth: A2uiLength.px(160),
          ),
          child: text,
        ),
        if (actionLabel != null && actionLabel.isNotEmpty && action != null)
          CssFlexItem(
            style: const A2uiFlexItemStyle(alignSelf: A2uiAlign.center),
            child: PlaygroundSecondaryButton(
              label: actionLabel,
              onPressed: () => unawaited(action()),
            ),
          ),
      ],
    ),
  );
}

/// The playground's shadcn `Button` with `variant="secondary"` and
/// `size="sm"`: 28px high, 10px side padding, 12.8px medium text on the
/// secondary fill, 8px corners.
class PlaygroundSecondaryButton extends StatefulWidget {
  /// A button labelled [label].
  const PlaygroundSecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// The text.
  final String label;

  /// Called on a click, Enter or Space.
  final VoidCallback onPressed;

  @override
  State<PlaygroundSecondaryButton> createState() =>
      _PlaygroundSecondaryButtonState();
}

class _PlaygroundSecondaryButtonState extends State<PlaygroundSecondaryButton> {
  /// The `<button>`'s focus: a press gives it, and its ring shows by
  /// `:focus-visible` (RULEBOOK section 2, the focus outline row).
  late final FocusNode _node = FocusNode(debugLabel: 'a2ui playground button');
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
  Widget build(BuildContext context) {
    final tokens = playgroundTokens(context);
    final radius = BorderRadius.circular(8);
    return Semantics(
      button: true,
      container: true,
      child: FocusableActionDetector(
        focusNode: _node,
        mouseCursor: SystemMouseCursors.click,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onPressed(),
          ),
        },
        child: _focus.listen(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: FocusRing(
              visible: _focus.visible,
              borderRadius: radius,
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.secondary,
                  borderRadius: radius,
                  border: Border.all(color: const Color(0x00000000)),
                ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  softWrap: false,
                  style: playgroundText(
                    12.8,
                    weight: FontWeight.w500,
                    color: tokens.secondaryForeground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/feedback.tsx
