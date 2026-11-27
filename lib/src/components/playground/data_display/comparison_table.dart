import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/icons/lucide.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/theme/playground_tokens.dart';
import 'package:flutter/widgets.dart';

/// The playground `ComparisonTable`: options compared feature by feature.
///
/// A card with an optional title. The first column is the feature name;
/// each option is a centred header. `highlight` tints that column with the
/// accent and marks it "Recommended" (0 is the first option). A `true` cell
/// is a positive check, `false` is an X, an empty cell is "-", and a number
/// is grouped en-US.
Widget buildComparisonTable(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = ComparisonTableProps(props);
  final tokens = playgroundTokens(context);
  final title = view.title;
  final options = [
    for (final raw in view.options)
      playgroundString(ComponentProps.unwrap(raw)),
  ];
  final highlightValue = view.highlight;
  final highlight =
      highlightValue != null && highlightValue == highlightValue.roundToDouble()
      ? highlightValue.toInt()
      : -1;
  final accent = tokens.toneColor(A2uiTone.accent);
  final tint = accent.withValues(alpha: .07);
  return InlineSizeContainer(
    inset: 2,
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: playgroundCardDecoration(tokens),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null && title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: playgroundText(
                    13,
                    weight: FontWeight.w600,
                    trackingEm: -.025,
                    color: tokens.foreground,
                  ),
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final featureWidth = 168.0 * scale;
              final minOption = 112.0 * scale;
              final optionCount = options.length;
              final minTable = featureWidth + minOption * optionCount;
              final viewport = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : minTable;
              final tableWidth = viewport > minTable ? viewport : minTable;
              final extra = tableWidth - minTable;
              final optionWidth = optionCount == 0
                  ? minOption
                  : minOption + extra / optionCount;
              final firstWidth = optionCount == 0 ? tableWidth : featureWidth;
              final rows = [for (final raw in view.rows) ?_map(raw)];
              final line = BorderSide(color: tokens.line);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _band(
                        border: Border(
                          top: title != null && title.isNotEmpty
                              ? line
                              : BorderSide.none,
                          bottom: line,
                        ),
                        children: [
                          _headerCell('Feature', tokens, width: firstWidth),
                          for (final (index, option) in options.indexed)
                            _optionHeader(
                              option,
                              tokens,
                              width: optionWidth,
                              scale: scale,
                              featured: index == highlight,
                              accent: accent,
                              tint: tint,
                            ),
                        ],
                      ),
                      for (final (index, row) in rows.indexed)
                        _band(
                          border: Border(
                            bottom: index == rows.length - 1
                                ? BorderSide.none
                                : line,
                          ),
                          children: [
                            _featureCell(
                              playgroundString(
                                ComponentProps.unwrap(row['feature']),
                              ),
                              tokens,
                              width: firstWidth,
                            ),
                            for (final (column, _) in options.indexed)
                              _valueCell(
                                _valueAt(row['values'], column),
                                tokens,
                                width: optionWidth,
                                featured: column == highlight,
                                tint: tint,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// One row. Every cell stretches to the row's height, so a highlight
/// fills the cell even when its mark is shorter than a neighbour's.
Widget _band({required Border border, required List<Widget> children}) {
  return DecoratedBox(
    decoration: BoxDecoration(border: border),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

Widget _headerCell(
  String text,
  A2uiPlaygroundTokens tokens, {
  required double width,
}) {
  return SizedBox(
    width: width,
    child: Container(
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Text(
        text,
        style: playgroundText(
          11.5,
          weight: FontWeight.w500,
          color: tokens.mutedForeground,
        ),
      ),
    ),
  );
}

Widget _optionHeader(
  String option,
  A2uiPlaygroundTokens tokens, {
  required double width,
  required double scale,
  required bool featured,
  required Color accent,
  required Color tint,
}) {
  return SizedBox(
    width: width,
    child: Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: featured ? tint : null,
        border: featured
            ? Border(top: BorderSide(color: accent, width: 2))
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (featured)
            Container(
              margin: EdgeInsets.only(bottom: 4 * scale),
              constraints: BoxConstraints(minHeight: 20 * scale),
              padding: EdgeInsets.symmetric(horizontal: 8 * scale),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .14),
                border: Border.all(color: accent.withValues(alpha: .26)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  'Recommended',
                  maxLines: 1,
                  softWrap: false,
                  style: playgroundText(
                    11,
                    weight: FontWeight.w500,
                    color: accent,
                  ),
                ),
              ),
            ),
          Text(
            option,
            textAlign: TextAlign.center,
            style: playgroundText(
              12.5,
              weight: FontWeight.w600,
              color: featured
                  ? tokens.foreground
                  : tokens.foreground.withValues(
                      alpha: tokens.foreground.a * .8,
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _featureCell(
  String feature,
  A2uiPlaygroundTokens tokens, {
  required double width,
}) {
  return SizedBox(
    width: width,
    child: Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        feature,
        style: playgroundText(
          12.5,
          color: tokens.foreground.withValues(alpha: tokens.foreground.a * .85),
        ),
      ),
    ),
  );
}

Widget _valueCell(
  Object? value,
  A2uiPlaygroundTokens tokens, {
  required double width,
  required bool featured,
  required Color tint,
}) {
  final positive = tokens.toneColor(A2uiTone.positive);
  final Widget child;
  if (value == true) {
    child = Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: positive.withValues(alpha: .16),
      ),
      child: LucideGlyph(
        lucideImport('Check', LucideRelease.playground),
        size: 12,
        strokeWidth: 3,
        color: positive,
        label: 'Yes',
      ),
    );
  } else if (value == false) {
    child = LucideGlyph(
      lucideImport('X', LucideRelease.playground),
      size: 14,
      color: tokens.mutedForeground.withValues(alpha: .45),
      label: 'No',
    );
  } else if (value == null || value == '') {
    child = Text(
      '-',
      style: playgroundText(
        13,
        color: tokens.mutedForeground.withValues(alpha: .4),
      ),
    );
  } else if (value is num) {
    child = Text(
      formatPlaygroundNumber(value),
      style: playgroundText(
        12.5,
        tabular: true,
        color: tokens.foreground.withValues(alpha: tokens.foreground.a * .9),
      ),
    );
  } else {
    child = Text(
      playgroundString(value),
      textAlign: TextAlign.center,
      style: playgroundText(
        12.5,
        tabular: true,
        color: tokens.foreground.withValues(alpha: tokens.foreground.a * .9),
      ),
    );
  }
  return SizedBox(
    width: width,
    child: Container(
      color: featured ? tint : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.center,
      child: child,
    ),
  );
}

Object? _valueAt(Object? raw, int index) {
  final values = ComponentProps.unwrap(raw);
  if (values is! List || index >= values.length) return null;
  return ComponentProps.unwrap(values[index]);
}

Map<String, Object?>? _map(Object? raw) {
  final value = ComponentProps.unwrap(raw);
  if (value is! Map) return null;
  return {for (final entry in value.entries) '${entry.key}': entry.value};
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/data.tsx
