import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/icons/lucide.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/theme/playground_tokens.dart';
import 'package:flutter/widgets.dart';

/// The playground `Timeline`: a vertical rail of steps in a card.
///
/// Each item shows a 20px node, the title (13px), an optional time on the
/// right, and an optional description. `status` defaults to `done` (a
/// positive check and a positive connector). `current` is an accent ring
/// with a halo, and `upcoming` is a muted dot with a quieter title. An
/// `icon` replaces the mark. A connector runs from each node but the last.
Widget buildTimeline(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = TimelineProps(props);
  final tokens = playgroundTokens(context);
  final items = [for (final raw in view.items) ?_map(raw)];
  return InlineSizeContainer(
    inset: 34,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: playgroundCardDecoration(tokens),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, item) in items.indexed)
            _TimelineItem(
              item: item,
              tokens: tokens,
              last: index == items.length - 1,
            ),
        ],
      ),
    ),
  );
}

/// One step of a [buildTimeline].
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.item,
    required this.tokens,
    required this.last,
  });

  final Map<String, Object?> item;
  final A2uiPlaygroundTokens tokens;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final status = _text(item['status']) ?? 'done';
    final time = _text(item['time']);
    final description = _text(item['description']);
    final upcoming = status == 'upcoming';
    final titleColor = upcoming
        ? tokens.foreground.withValues(alpha: tokens.foreground.a * .65)
        : tokens.foreground;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: _Rail(
              status: status,
              tokens: tokens,
              last: last,
              iconName: _text(item['icon']),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          playgroundString(
                            ComponentProps.unwrap(item['title']),
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: playgroundText(
                            13,
                            weight: FontWeight.w500,
                            color: titleColor,
                          ),
                        ),
                      ),
                      if (time != null && time.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          time,
                          style: playgroundText(
                            11,
                            tabular: true,
                            color: tokens.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (description != null && description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        description,
                        style: playgroundText(
                          12.5,
                          height: 1.625,
                          color: tokens.mutedForeground,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The node and the connector under it.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.status,
    required this.tokens,
    required this.last,
    required this.iconName,
  });

  final String status;
  final A2uiPlaygroundTokens tokens;
  final bool last;
  final String? iconName;

  @override
  Widget build(BuildContext context) {
    final positive = tokens.toneColor(A2uiTone.positive);
    return Stack(
      children: [
        if (!last)
          Positioned(
            top: 24,
            bottom: -2,
            left: 9.5,
            child: ColoredBox(
              color: status == 'done'
                  ? positive.withValues(alpha: .45)
                  : tokens.lineStrong,
              child: const SizedBox(width: 1),
            ),
          ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _Node(status: status, tokens: tokens, iconName: iconName),
          ),
        ),
      ],
    );
  }
}

/// The 20px status mark.
class _Node extends StatelessWidget {
  const _Node({
    required this.status,
    required this.tokens,
    required this.iconName,
  });

  final String status;
  final A2uiPlaygroundTokens tokens;
  final String? iconName;

  @override
  Widget build(BuildContext context) {
    final positive = tokens.toneColor(A2uiTone.positive);
    final accent = tokens.toneColor(A2uiTone.accent);
    final icon = lucideIcon(iconName, release: LucideRelease.playground);
    final done = status == 'done';
    final current = status == 'current';
    final upcoming = status == 'upcoming';
    late final Color foreground;
    late final BoxDecoration decoration;
    if (done) {
      foreground = positive;
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        color: positive.withValues(alpha: .18),
        border: Border.all(color: const Color(0x00000000)),
      );
    } else if (current) {
      foreground = accent;
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: .16),
        border: Border.all(color: accent),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: .12), spreadRadius: 4),
        ],
      );
    } else if (upcoming) {
      foreground = tokens.mutedForeground;
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        color: tokens.surface,
        border: Border.all(color: tokens.lineStrong),
      );
    } else {
      foreground = tokens.mutedForeground;
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: tokens.line),
      );
    }
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: decoration,
      child: icon != null
          ? LucideGlyph(icon, size: 12, color: foreground)
          : done
          ? LucideGlyph(
              lucideImport('Check', LucideRelease.playground),
              size: 12,
              strokeWidth: 2.75,
              color: positive,
            )
          : Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: current
                    ? accent
                    : tokens.mutedForeground.withValues(alpha: .4),
              ),
            ),
    );
  }
}

Map<String, Object?>? _map(Object? raw) {
  final value = ComponentProps.unwrap(raw);
  if (value is! Map) return null;
  return {for (final entry in value.entries) '${entry.key}': entry.value};
}

String? _text(Object? raw) {
  final value = ComponentProps.unwrap(raw);
  if (value == null) return null;
  return playgroundString(value);
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/data.tsx
