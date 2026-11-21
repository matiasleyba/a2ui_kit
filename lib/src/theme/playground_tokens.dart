import 'dart:ui' show lerpDouble;

import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_color.dart';
import 'package:a2ui_kit/src/theme/chart_colors.dart';
import 'package:a2ui_kit/src/theme/shadows.dart';
import 'package:a2ui_kit/src/theme/tone_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The tokens of the playground's own 52 components (`--a2-*` and
/// `--ts-chart-*` in the playground's `globals.css`).
///
/// The standard components never read these; the playground components
/// (Section, Heading, Stat and the rest) do.
@immutable
class A2uiPlaygroundTokens with Diagnosticable {
  /// Tokens with every value given.
  const A2uiPlaygroundTokens({
    required this.ink,
    required this.foreground,
    required this.mutedForeground,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.lineStrong,
    required this.radius,
    required this.tones,
    required this.chart,
    required this.chartInk,
    required this.cardShadow,
    required this.cardSheen,
    required this.secondary,
    required this.secondaryForeground,
    required this.alerts,
    required this.callout,
    required this.charts,
  });

  /// The playground's light tokens.
  factory A2uiPlaygroundTokens.light() {
    final ink = oklch(.21, .012, 285);
    return A2uiPlaygroundTokens(
      ink: ink,
      foreground: oklch(.2, .008, 285),
      mutedForeground: oklch(.47, .014, 285),
      surface: oklch(1, 0, 0),
      surface2: oklch(.97, .003, 285),
      line: ink.withValues(alpha: .09),
      lineStrong: ink.withValues(alpha: .15),
      radius: 14,
      tones: {
        A2uiTone.default_: oklch(.2, .008, 285),
        A2uiTone.accent: oklch(.52, .2, 292),
        A2uiTone.positive: oklch(.52, .13, 160),
        A2uiTone.negative: oklch(.56, .2, 22),
        A2uiTone.warning: oklch(.53, .14, 62),
        A2uiTone.info: oklch(.52, .13, 235),
      },
      chart: [
        oklch(.55, .2, 292),
        oklch(.58, .13, 230),
        oklch(.6, .14, 162),
        oklch(.7, .15, 72),
        oklch(.6, .2, 18),
        oklch(.6, .03, 285),
      ],
      chartInk: oklch(.45, .012, 285),
      cardShadow: [
        cssShadow(0, 1, 2, ink.withValues(alpha: .06)),
        cssShadow(0, 1, 3, ink.withValues(alpha: .04)),
      ],
      cardSheen: const Color(0x00000000),
      secondary: oklch(.96, .004, 285),
      secondaryForeground: oklch(.2, .008, 285),
      alerts: _alerts(Brightness.light),
      callout: _callout(Brightness.light),
      charts: A2uiChartColors.light(),
    );
  }

  /// The playground's dark tokens.
  factory A2uiPlaygroundTokens.dark() {
    final ink = oklch(1, 0, 0);
    return A2uiPlaygroundTokens(
      ink: ink,
      foreground: oklch(.97, .003, 285),
      mutedForeground: oklch(.68, .012, 285),
      surface: oklch(.172, .005, 285),
      surface2: oklch(.205, .006, 285),
      line: ink.withValues(alpha: .075),
      lineStrong: ink.withValues(alpha: .12),
      radius: 14,
      tones: {
        A2uiTone.default_: oklch(.97, .003, 285),
        A2uiTone.accent: oklch(.72, .17, 292),
        A2uiTone.positive: oklch(.78, .15, 160),
        A2uiTone.negative: oklch(.7, .18, 18),
        A2uiTone.warning: oklch(.83, .14, 78),
        A2uiTone.info: oklch(.76, .12, 225),
      },
      chart: [
        oklch(.72, .17, 292),
        oklch(.76, .12, 225),
        oklch(.79, .15, 162),
        oklch(.83, .14, 78),
        oklch(.71, .18, 12),
        oklch(.7, .03, 285),
      ],
      chartInk: oklch(.78, .01, 285),
      cardShadow: [cssShadow(0, 1, 2, oklch(0, 0, 0, .3))],
      cardSheen: oklch(1, 0, 0, .022),
      secondary: oklch(.24, .006, 285),
      secondaryForeground: oklch(.97, .003, 285),
      alerts: _alerts(Brightness.dark),
      callout: _callout(Brightness.dark),
      charts: A2uiChartColors.dark(),
    );
  }

  /// The Alert tones: Tailwind's sky, emerald, amber and rose at the
  /// playground's alphas (`feedback.tsx`).
  static Map<AlertTone, A2uiToneColors> _alerts(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    A2uiToneColors tone(
      Map<int, Color> palette, {
      required double border,
      required double fill,
      required int darkText,
    }) => A2uiToneColors(
      border: palette[400]!.withValues(alpha: border),
      background: palette[400]!.withValues(alpha: fill),
      foreground: palette[dark ? darkText : 800]!,
      icon: palette[dark ? 300 : 600]!,
    );
    return {
      AlertTone.info: tone(
        TailwindPalette.sky,
        border: .2,
        fill: .06,
        darkText: 200,
      ),
      AlertTone.success: tone(
        TailwindPalette.emerald,
        border: .2,
        fill: .06,
        darkText: 100,
      ),
      AlertTone.warning: tone(
        TailwindPalette.amber,
        border: .25,
        fill: .07,
        darkText: 100,
      ),
      AlertTone.error: tone(
        TailwindPalette.rose,
        border: .25,
        fill: .07,
        darkText: 100,
      ),
    };
  }

  /// The Callout: a violet border and gradient, and a violet icon tile.
  static A2uiToneColors _callout(Brightness brightness) {
    final violet = TailwindPalette.violet;
    return A2uiToneColors(
      border: violet[400]!.withValues(alpha: .2),
      background: violet[500]!.withValues(alpha: .1),
      backgroundEnd: violet[500]!.withValues(alpha: .04),
      foreground: violet[brightness == Brightness.dark ? 200 : 800]!,
      icon: violet[400]!.withValues(alpha: .15),
    );
  }

  /// The colour the overlays and hairlines are drawn in (`--ink`).
  final Color ink;

  /// The text colour (`--foreground`).
  final Color foreground;

  /// Quiet text: labels and captions (`--muted-foreground`).
  final Color mutedForeground;

  /// A card's fill (`--a2-surface`).
  final Color surface;

  /// The secondary fill (`--a2-surface-2`).
  final Color surface2;

  /// The hairline of cards and wells (`--a2-line`).
  final Color line;

  /// The stronger hairline (`--a2-line-strong`).
  final Color lineStrong;

  /// The radius of a card in pixels (`--a2-radius`).
  final double radius;

  /// The colour of each tone (`--a2-accent`, `--a2-positive` and the rest;
  /// `default` is the foreground).
  final Map<A2uiTone, Color> tones;

  /// The chart series colours (`--ts-chart-1` to `--ts-chart-6`).
  final List<Color> chart;

  /// The ink of chart axes and labels (`--a2-chart-ink`).
  final Color chartInk;

  /// A card's shadow (`--a2-card-shadow`).
  final List<BoxShadow> cardShadow;

  /// The faint sheen at the top of a card in dark mode (`--a2-card-sheen`).
  final Color cardSheen;

  /// The fill of a secondary button (`--secondary`).
  final Color secondary;

  /// The text of a secondary button (`--secondary-foreground`).
  final Color secondaryForeground;

  /// The colours of each Alert tone.
  final Map<AlertTone, A2uiToneColors> alerts;

  /// The colours of a Callout: [A2uiToneColors.icon] is its icon tile's
  /// fill and [A2uiToneColors.foreground] the tile's icon.
  final A2uiToneColors callout;

  /// The colours of the charts' axes, grids, tooltips and highlights.
  final A2uiChartColors charts;

  /// The colour of [tone]: `--a2-positive` and the rest; `default` is the
  /// muted foreground, as the tones' `color` entry gives it.
  Color toneColor(A2uiTone tone) =>
      tone == A2uiTone.default_ ? mutedForeground : tones[tone] ?? foreground;

  /// A copy with the given values replaced.
  A2uiPlaygroundTokens copyWith({
    Color? ink,
    Color? foreground,
    Color? mutedForeground,
    Color? surface,
    Color? surface2,
    Color? line,
    Color? lineStrong,
    double? radius,
    Map<A2uiTone, Color>? tones,
    List<Color>? chart,
    Color? chartInk,
    List<BoxShadow>? cardShadow,
    Color? cardSheen,
    Color? secondary,
    Color? secondaryForeground,
    Map<AlertTone, A2uiToneColors>? alerts,
    A2uiToneColors? callout,
    A2uiChartColors? charts,
  }) => A2uiPlaygroundTokens(
    ink: ink ?? this.ink,
    foreground: foreground ?? this.foreground,
    mutedForeground: mutedForeground ?? this.mutedForeground,
    surface: surface ?? this.surface,
    surface2: surface2 ?? this.surface2,
    line: line ?? this.line,
    lineStrong: lineStrong ?? this.lineStrong,
    radius: radius ?? this.radius,
    tones: tones ?? this.tones,
    chart: chart ?? this.chart,
    chartInk: chartInk ?? this.chartInk,
    cardShadow: cardShadow ?? this.cardShadow,
    cardSheen: cardSheen ?? this.cardSheen,
    secondary: secondary ?? this.secondary,
    secondaryForeground: secondaryForeground ?? this.secondaryForeground,
    alerts: alerts ?? this.alerts,
    callout: callout ?? this.callout,
    charts: charts ?? this.charts,
  );

  /// The tokens between [a] and [b] at [t].
  // ignore: prefer_constructors_over_static_methods (Flutter's lerp is static)
  static A2uiPlaygroundTokens lerp(
    A2uiPlaygroundTokens a,
    A2uiPlaygroundTokens b,
    double t,
  ) {
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return A2uiPlaygroundTokens(
      ink: c(a.ink, b.ink),
      foreground: c(a.foreground, b.foreground),
      mutedForeground: c(a.mutedForeground, b.mutedForeground),
      surface: c(a.surface, b.surface),
      surface2: c(a.surface2, b.surface2),
      line: c(a.line, b.line),
      lineStrong: c(a.lineStrong, b.lineStrong),
      radius: lerpDouble(a.radius, b.radius, t)!,
      tones: {
        for (final tone in {...a.tones.keys, ...b.tones.keys})
          tone: Color.lerp(a.tones[tone], b.tones[tone], t)!,
      },
      chart: [
        for (var i = 0; i < a.chart.length && i < b.chart.length; i++)
          c(a.chart[i], b.chart[i]),
      ],
      chartInk: c(a.chartInk, b.chartInk),
      cardShadow: BoxShadow.lerpList(a.cardShadow, b.cardShadow, t)!,
      cardSheen: c(a.cardSheen, b.cardSheen),
      secondary: c(a.secondary, b.secondary),
      secondaryForeground: c(a.secondaryForeground, b.secondaryForeground),
      alerts: {
        for (final tone in AlertTone.values)
          if (a.alerts[tone] != null && b.alerts[tone] != null)
            tone: A2uiToneColors.lerp(a.alerts[tone]!, b.alerts[tone]!, t),
      },
      callout: A2uiToneColors.lerp(a.callout, b.callout, t),
      charts: A2uiChartColors.lerp(a.charts, b.charts, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is A2uiPlaygroundTokens &&
      other.ink == ink &&
      other.foreground == foreground &&
      other.mutedForeground == mutedForeground &&
      other.surface == surface &&
      other.surface2 == surface2 &&
      other.line == line &&
      other.lineStrong == lineStrong &&
      other.radius == radius &&
      mapEquals(other.tones, tones) &&
      listEquals(other.chart, chart) &&
      other.chartInk == chartInk &&
      listEquals(other.cardShadow, cardShadow) &&
      other.cardSheen == cardSheen &&
      other.secondary == secondary &&
      other.secondaryForeground == secondaryForeground &&
      mapEquals(other.alerts, alerts) &&
      other.callout == callout &&
      other.charts == charts;

  @override
  int get hashCode => Object.hash(
    ink,
    foreground,
    mutedForeground,
    surface,
    surface2,
    line,
    lineStrong,
    radius,
    Object.hashAllUnordered(tones.entries.map((e) => (e.key, e.value))),
    Object.hashAll(chart),
    chartInk,
    Object.hashAll(cardShadow),
    cardSheen,
    secondary,
    secondaryForeground,
    Object.hashAllUnordered(alerts.entries.map((e) => (e.key, e.value))),
    callout,
    charts,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('foreground', foreground))
      ..add(ColorProperty('surface', surface))
      ..add(DoubleProperty('radius', radius));
  }
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/app/globals.css
