// The playground's Sparkline, after `Sparkline` in the playground's
// `charts.tsx` (MIT, (c) Atai Barkai), which draws it with TanStack Charts.

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/charts/chart_kit.dart';
import 'package:a2ui_kit/src/components/playground/charts/pie_sparkline.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/format/chart_format.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:flutter/widgets.dart';

/// The playground `Sparkline`: a label, a value and a tiny trend in a
/// card row.
///
/// - The value is `value`, else the last of `values` in compact form
///   (18px semibold); `delta` follows in a pill tinted by the tone.
/// - The tone is `tone`, else positive when the last value is at least the
///   first, negative otherwise; it colours the 1.75px smooth line (else
///   the first chart colour), its gradient (30% to clear) and its end dot.
/// - The chart is 44px tall and takes the rest of the row; with fewer than
///   two values a pulsing bar stands in for it. The pointer shows the
///   nearest value (a 3.5px dot of the line's colour) in a tooltip; the
///   keyboard and a click as the LineChart's.
/// - The label and value keep their width, as `shrink-0` does: a label too
///   long for the card runs past it, as in the browser.
///
/// A `CustomPaint` draws it (no axes, the playground's monotone cubic).
///
/// Differences from CopilotKit: TanStack's own SVG transitions are not
/// drawn; the playground's CSS wipe-in is (700ms, none under reduced
/// motion). A pinned tooltip ignores the pointer (TanStack's takes it, so
/// its text can be selected). Chart
/// text in goldens: painted text: alchemist's CI goldens draw it as black
/// blocks. Chart accessibility: every chart is an image named by its
/// title, followed by hidden rows that read each cell after its column.
Widget buildSparkline(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = SparklineProps(props);
  final tokens = playgroundTokens(context);
  final values = [
    for (final raw in view.values)
      if (ComponentProps.unwrap(raw) case final num n when n.isFinite)
        n.toDouble(),
  ];
  final first = values.isEmpty ? null : values.first;
  final last = values.isEmpty ? null : values.last;
  final tone =
      view.tone ??
      (values.length > 1
          ? (last! >= first! ? SparklineTone.positive : SparklineTone.negative)
          : SparklineTone.default_);
  final stroke = switch (tone) {
    SparklineTone.positive => tokens.toneColor(A2uiTone.positive),
    SparklineTone.negative => tokens.toneColor(A2uiTone.negative),
    SparklineTone.default_ => paletteAt(tokens, 0),
  };
  // `color-mix(in oklch, var(--a2-positive) 14%, transparent)`; neutral
  // `bg-black/5`, `dark:bg-white/5` (charts.tsx:1035: a playground colour
  // that differs per look, so a chart colour, not a library token).
  final (deltaText, deltaFill) = switch (tone) {
    SparklineTone.default_ => (
      tokens.mutedForeground,
      tokens.charts.deltaNeutralFill,
    ),
    _ => (stroke, stroke.withValues(alpha: stroke.a * .14)),
  };
  final label = view.label;
  final delta = view.delta;
  final valueText =
      view.value ??
      (last == null ? '' : fmtValue(last, A2uiValueFormat.compact));
  // `<div class="min-w-0 shrink-0">`: a block of the label line and the
  // value's flex line, not a flex box.
  final info = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label != null && label.isNotEmpty)
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: playgroundText(11.5, color: tokens.mutedForeground),
        ),
      // `mt-0.5 flex items-baseline gap-2`.
      CssFlex(
        flex: const A2uiFlexStyle(
          direction: Axis.horizontal,
          align: A2uiAlign.baseline,
          columnGap: 8,
        ),
        box: const A2uiBoxStyle(padding: EdgeInsets.only(top: 2), fill: false),
        children: [
          Text(
            valueText,
            maxLines: 1,
            softWrap: false,
            style: playgroundText(
              18,
              weight: FontWeight.w600,
              trackingEm: -.025,
              color: tokens.foreground,
              tabular: true,
            ),
          ),
          if (delta != null && delta.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: deltaFill,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                delta,
                maxLines: 1,
                softWrap: false,
                style: playgroundText(
                  11,
                  weight: FontWeight.w500,
                  color: deltaText,
                  tabular: true,
                ),
              ),
            ),
        ],
      ),
    ],
  );
  final chart = values.length > 1
      ? PlaygroundPlot(
          height: 44,
          // `rows` is `useMemo`'d on `values` (charts.tsx:944-948).
          rowsKey: view.values,
          label: label ?? 'Sparkline',
          columns: const ['index', 'value'],
          rows: [
            for (var i = 0; i < values.length; i++)
              ['${i + 1}', fmtValue(values[i])],
          ],
          scene: (size, style) => SparklineScene(
            size: size,
            style: style,
            values: values,
            stroke: stroke,
            surface: tokens.surface,
            label: label,
          ),
        )
      // `a2-shimmer mt-5 h-1 rounded-full`.
      : const Padding(
          padding: EdgeInsets.only(top: 20),
          child: Align(
            alignment: Alignment.topCenter,
            child: ChartShimmer(height: 4),
          ),
        );
  return Container(
    decoration: playgroundCardDecoration(tokens),
    child: DefaultTextStyle.merge(
      style: TextStyle(color: tokens.chartInk),
      // `flex w-full min-w-0 items-center gap-4 px-4 py-3`.
      child: CssFlex(
        flex: const A2uiFlexStyle(
          direction: Axis.horizontal,
          align: A2uiAlign.center,
          columnGap: 16,
        ),
        box: const A2uiBoxStyle(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        children: [
          CssFlexItem(
            style: const A2uiFlexItemStyle(
              shrink: 0,
              minWidth: A2uiLength.zero,
            ),
            child: info,
          ),
          CssFlexItem(
            style: const A2uiFlexItemStyle(
              grow: 1,
              basis: A2uiLength.zero,
              minWidth: A2uiLength.zero,
              height: A2uiPx(44),
            ),
            child: chart,
          ),
        ],
      ),
    ),
  );
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/charts.tsx
