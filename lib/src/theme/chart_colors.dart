import 'package:a2ui_kit/src/foundation/css/css_color.dart';
import 'package:a2ui_kit/src/theme/shadows.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The colours the playground's charts hand to their drawing rather than to
/// a class: `--a2-chart-*`, `--a2-heat-*` and `--a2-tooltip-*` in the
/// playground's `renderers.css`, and the shimmer of an empty chart
/// (`.a2-shimmer` in `motion.css`).
///
/// The series colours are `A2uiPlaygroundTokens.chart` (`--ts-chart-*`).
@immutable
class A2uiChartColors with Diagnosticable {
  /// Colours with every value given.
  const A2uiChartColors({
    required this.foreground,
    required this.muted,
    required this.grid,
    required this.label,
    required this.focus,
    required this.mute,
    required this.heatLow,
    required this.heatLegendLow,
    required this.heatInkHigh,
    required this.heatInkLow,
    required this.tooltipBackground,
    required this.tooltipForeground,
    required this.tooltipBorder,
    required this.tooltipShadow,
    required this.shimmer,
    required this.deltaNeutralFill,
  });

  /// The playground's light chart colours.
  factory A2uiChartColors.light() => A2uiChartColors(
    foreground: oklch(.28, .01, 285),
    muted: oklch(.52, .012, 285),
    grid: oklch(.21, .012, 285, .1),
    label: oklch(.34, .01, 285),
    focus: oklch(.21, .012, 285),
    mute: [
      oklch(.8, .008, 285),
      oklch(.74, .008, 285),
      oklch(.86, .008, 285),
      oklch(.7, .008, 285),
    ],
    heatLow: oklch(.965, .006, 285),
    heatLegendLow: oklch(.965, .006, 285),
    heatInkHigh: oklch(.2, .02, 292),
    heatInkLow: oklch(.32, .01, 285),
    tooltipBackground: oklch(1, 0, 0, .97),
    tooltipForeground: oklch(.22, .008, 285),
    tooltipBorder: oklch(.21, .012, 285, .1),
    tooltipShadow: [cssShadow(0, 12, 32, oklch(.21, .012, 285, .14))],
    // `color-mix(in oklch, var(--gen-strong) 12%, transparent)`.
    shimmer: const Color(0xff6c6c6c).withValues(alpha: .12),
    // charts.tsx:1035: `bg-black/5`.
    deltaNeutralFill: const Color(0xff000000).withValues(alpha: .05),
  );

  /// The playground's dark chart colours.
  factory A2uiChartColors.dark() => A2uiChartColors(
    foreground: oklch(.93, .004, 285),
    muted: oklch(.6, .012, 285),
    grid: oklch(1, 0, 0, .065),
    label: oklch(.86, .008, 285),
    focus: oklch(.97, 0, 0),
    mute: [
      oklch(.47, .012, 285),
      oklch(.4, .012, 285),
      oklch(.54, .012, 285),
      oklch(.36, .012, 285),
    ],
    heatLow: oklch(.27, .01, 285),
    heatLegendLow: oklch(.24, .008, 285),
    heatInkHigh: oklch(.18, .02, 292),
    heatInkLow: oklch(.86, .01, 285),
    tooltipBackground: oklch(.2, .006, 285, .94),
    tooltipForeground: oklch(.95, .004, 285),
    tooltipBorder: oklch(1, 0, 0, .1),
    tooltipShadow: [cssShadow(0, 12, 32, oklch(0, 0, 0, .45))],
    shimmer: const Color(0xffa3a3a3).withValues(alpha: .12),
    // charts.tsx:1035: `dark:bg-white/5`.
    deltaNeutralFill: const Color(0xffffffff).withValues(alpha: .05),
  );

  /// Value labels and the stronger chart text (`--a2-chart-fg`).
  final Color foreground;

  /// Axis ticks and quiet chart text (`--a2-chart-muted`).
  final Color muted;

  /// Grid lines (`--a2-chart-grid`).
  final Color grid;

  /// Labels drawn beside marks (`--a2-chart-label`).
  final Color label;

  /// The outline round a focused cell (`--a2-chart-focus`).
  final Color focus;

  /// The greys of the other series while one is highlighted
  /// (`--a2-chart-mute-1` to `-4`).
  final List<Color> mute;

  /// The empty end of a heat ramp (`--a2-heat-low`).
  final Color heatLow;

  /// The empty end of a heat legend (`--a2-heat-legend-low`).
  final Color heatLegendLow;

  /// A value on a strong heat cell (`--a2-heat-ink-hi`).
  final Color heatInkHigh;

  /// A value on a weak heat cell (`--a2-heat-ink-lo`).
  final Color heatInkLow;

  /// The tooltip's fill (`--a2-tooltip-bg`).
  final Color tooltipBackground;

  /// The tooltip's text (`--a2-tooltip-fg`).
  final Color tooltipForeground;

  /// The tooltip's 1px border (`--a2-tooltip-border`).
  final Color tooltipBorder;

  /// The tooltip's shadow (`--a2-tooltip-shadow`).
  final List<BoxShadow> tooltipShadow;

  /// The pulsing bar of an empty chart (`.a2-shimmer`).
  final Color shimmer;

  /// The Sparkline's neutral delta pill: the playground's `bg-black/5`
  /// (black at 5%), and in the dark look its `dark:bg-white/5` (white at
  /// 5%) (charts.tsx:1035).
  final Color deltaNeutralFill;

  /// The grey of the [index]th other series while one is highlighted.
  Color muteAt(int index) => mute.isEmpty
      ? muted
      : mute[(index % mute.length + mute.length) % mute.length];

  /// A copy with the given values replaced.
  A2uiChartColors copyWith({
    Color? foreground,
    Color? muted,
    Color? grid,
    Color? label,
    Color? focus,
    List<Color>? mute,
    Color? heatLow,
    Color? heatLegendLow,
    Color? heatInkHigh,
    Color? heatInkLow,
    Color? tooltipBackground,
    Color? tooltipForeground,
    Color? tooltipBorder,
    List<BoxShadow>? tooltipShadow,
    Color? shimmer,
    Color? deltaNeutralFill,
  }) => A2uiChartColors(
    foreground: foreground ?? this.foreground,
    muted: muted ?? this.muted,
    grid: grid ?? this.grid,
    label: label ?? this.label,
    focus: focus ?? this.focus,
    mute: mute ?? this.mute,
    heatLow: heatLow ?? this.heatLow,
    heatLegendLow: heatLegendLow ?? this.heatLegendLow,
    heatInkHigh: heatInkHigh ?? this.heatInkHigh,
    heatInkLow: heatInkLow ?? this.heatInkLow,
    tooltipBackground: tooltipBackground ?? this.tooltipBackground,
    tooltipForeground: tooltipForeground ?? this.tooltipForeground,
    tooltipBorder: tooltipBorder ?? this.tooltipBorder,
    tooltipShadow: tooltipShadow ?? this.tooltipShadow,
    shimmer: shimmer ?? this.shimmer,
    deltaNeutralFill: deltaNeutralFill ?? this.deltaNeutralFill,
  );

  /// The colours between [a] and [b] at [t].
  // ignore: prefer_constructors_over_static_methods (Flutter's lerp is static)
  static A2uiChartColors lerp(A2uiChartColors a, A2uiChartColors b, double t) {
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return A2uiChartColors(
      foreground: c(a.foreground, b.foreground),
      muted: c(a.muted, b.muted),
      grid: c(a.grid, b.grid),
      label: c(a.label, b.label),
      focus: c(a.focus, b.focus),
      mute: [
        for (var i = 0; i < a.mute.length && i < b.mute.length; i++)
          c(a.mute[i], b.mute[i]),
      ],
      heatLow: c(a.heatLow, b.heatLow),
      heatLegendLow: c(a.heatLegendLow, b.heatLegendLow),
      heatInkHigh: c(a.heatInkHigh, b.heatInkHigh),
      heatInkLow: c(a.heatInkLow, b.heatInkLow),
      tooltipBackground: c(a.tooltipBackground, b.tooltipBackground),
      tooltipForeground: c(a.tooltipForeground, b.tooltipForeground),
      tooltipBorder: c(a.tooltipBorder, b.tooltipBorder),
      tooltipShadow: BoxShadow.lerpList(a.tooltipShadow, b.tooltipShadow, t)!,
      shimmer: c(a.shimmer, b.shimmer),
      deltaNeutralFill: c(a.deltaNeutralFill, b.deltaNeutralFill),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is A2uiChartColors &&
      other.foreground == foreground &&
      other.muted == muted &&
      other.grid == grid &&
      other.label == label &&
      other.focus == focus &&
      listEquals(other.mute, mute) &&
      other.heatLow == heatLow &&
      other.heatLegendLow == heatLegendLow &&
      other.heatInkHigh == heatInkHigh &&
      other.heatInkLow == heatInkLow &&
      other.tooltipBackground == tooltipBackground &&
      other.tooltipForeground == tooltipForeground &&
      other.tooltipBorder == tooltipBorder &&
      listEquals(other.tooltipShadow, tooltipShadow) &&
      other.shimmer == shimmer &&
      other.deltaNeutralFill == deltaNeutralFill;

  @override
  int get hashCode => Object.hash(
    foreground,
    muted,
    grid,
    label,
    focus,
    Object.hashAll(mute),
    heatLow,
    heatLegendLow,
    heatInkHigh,
    heatInkLow,
    tooltipBackground,
    tooltipForeground,
    tooltipBorder,
    Object.hashAll(tooltipShadow),
    shimmer,
    deltaNeutralFill,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('muted', muted))
      ..add(ColorProperty('grid', grid))
      ..add(ColorProperty('tooltipBackground', tooltipBackground));
  }
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/renderers.css, charts.tsx
