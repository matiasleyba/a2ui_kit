import 'package:a2ui_kit/src/foundation/css/css_color.dart';
import 'package:a2ui_kit/src/theme/shadows.dart';
import 'package:flutter/painting.dart';

/// A colour token of CopilotKit's standard components: the CSS variable
/// `--a2ui-color-<wire>` (`--a2ui-chart-<n>` for the chart series).
///
/// The colour props of A2UI (`color`, `background`, `borderColor`) name
/// these tokens; `A2uiKitTheme` maps them to
/// colours.
enum A2uiColorToken {
  /// Body text.
  textDefault('text-default'),

  /// Prose text, the same as [textDefault] by default.
  textProse('text-prose'),

  /// Primary text, the same as [textDefault] by default.
  textPrimary('text-primary'),

  /// Emphasized text.
  textEmphasis('text-emphasis'),

  /// Secondary text: captions and labels.
  textSecondary('text-secondary'),

  /// Tertiary text: placeholders.
  textTertiary('text-tertiary'),

  /// Success text.
  textSuccess('text-success'),

  /// Information text.
  textInfo('text-info'),

  /// Warning text.
  textWarning('text-warning'),

  /// Caution text, the same as [textWarning] by default.
  textCaution('text-caution'),

  /// Danger text.
  textDanger('text-danger'),

  /// Discovery text.
  textDiscovery('text-discovery'),

  /// The surface.
  surface('surface'),

  /// A secondary surface.
  surfaceSecondary('surface-secondary'),

  /// A tertiary surface.
  surfaceTertiary('surface-tertiary'),

  /// An elevated surface (menus, popovers).
  surfaceElevated('surface-elevated'),

  /// A secondary elevated surface.
  surfaceElevatedSecondary('surface-elevated-secondary'),

  /// The inverted surface (tooltips, neutral solid badges).
  surfaceInverted('surface-inverted'),

  /// A soft surface.
  surfaceSoft('surface-soft'),

  /// The information tint.
  info('info'),

  /// The warning tint.
  warning('warning'),

  /// The caution tint.
  caution('caution'),

  /// The success tint.
  success('success'),

  /// The danger tint.
  danger('danger'),

  /// The discovery tint.
  discovery('discovery'),

  /// The lighter information tint of a panel inside a Card.
  infoSoft('info-soft'),

  /// The lighter warning tint of a panel inside a Card.
  warningSoft('warning-soft'),

  /// The lighter caution tint of a panel inside a Card.
  cautionSoft('caution-soft'),

  /// The lighter success tint of a panel inside a Card.
  successSoft('success-soft'),

  /// The lighter danger tint of a panel inside a Card.
  dangerSoft('danger-soft'),

  /// The lighter discovery tint of a panel inside a Card.
  discoverySoft('discovery-soft'),

  /// The solid information fill.
  infoSolid('info-solid'),

  /// The solid warning fill.
  warningSolid('warning-solid'),

  /// The solid caution fill.
  cautionSolid('caution-solid'),

  /// The solid success fill.
  successSolid('success-solid'),

  /// The solid danger fill.
  dangerSolid('danger-solid'),

  /// The solid discovery fill.
  discoverySolid('discovery-solid'),

  /// The default border.
  borderDefault('border-default'),

  /// A subtle border (dividers).
  borderSubtle('border-subtle'),

  /// A strong border.
  borderStrong('border-strong'),

  /// The information border.
  borderInfo('border-info'),

  /// The warning border.
  borderWarning('border-warning'),

  /// The caution border.
  borderCaution('border-caution'),

  /// The success border.
  borderSuccess('border-success'),

  /// The danger border.
  borderDanger('border-danger'),

  /// The discovery border.
  borderDiscovery('border-discovery'),

  /// The border of a control (inputs, selects).
  borderControl('border-control'),

  /// The accent: primary buttons, checked controls.
  accent('accent'),

  /// Text on the accent and on solid fills.
  onAccent('on-accent'),

  /// The inner panel of a Card.
  panel('panel'),

  /// The fill of a control.
  control('control'),

  /// The focus ring.
  focus('focus'),

  /// The browser's own focus outline round a focusable element that sets no
  /// focus style of its own (recharts' `<svg>`, the pie's `<g>`, TanStack's
  /// `<svg>`): the outline colour CopilotKit gives every element,
  /// `outline-ring/50` (react-core `src/v2/styles/globals.css:144-146`;
  /// the playground's `src/app/globals.css:131-133`).
  outlineRing('outline-ring'),

  /// The moving highlight of a shimmer.
  shimmer('shimmer'),

  /// The hover band behind a chart column.
  chartCursor('chart-cursor'),

  /// The track of a slider.
  sliderTrack('slider-track'),

  /// The fill of a neutral soft badge.
  badgeSecondary('badge-secondary'),

  /// The green text highlight.
  highlightGreen('highlight-green'),

  /// The orange text highlight.
  highlightOrange('highlight-orange'),

  /// The pink text highlight.
  highlightPink('highlight-pink'),

  /// The scrim behind a lightbox.
  backdrop('backdrop'),

  /// The scrim behind a modal.
  overlay('overlay'),

  /// The filled star of a rating.
  rating('rating'),

  /// Chart series 1 (`--a2ui-chart-1`).
  chart1('chart-1'),

  /// Chart series 2.
  chart2('chart-2'),

  /// Chart series 3.
  chart3('chart-3'),

  /// Chart series 4.
  chart4('chart-4'),

  /// Chart series 5.
  chart5('chart-5'),

  /// Chart series 6.
  chart6('chart-6'),

  /// recharts' cursor stroke, `#ccc` (`es6/component/Cursor.js:94`). This
  /// and the tokens after it are a library's literal colours, named after
  /// the library default (RULEBOOK §1), not CopilotKit variables: no prop
  /// names them.
  rechartsCursorStroke('recharts-cursor-stroke'),

  /// recharts' default text fill, `#808080` (`es6/component/Text.js:188`
  /// `DEFAULT_FILL`): value labels.
  rechartsTextFill('recharts-text-fill'),

  /// recharts' tooltip box, `#fff` (`es6/component/DefaultTooltipContent.js:
  /// 34`, `contentStyle.backgroundColor`).
  rechartsTooltipBackground('recharts-tooltip-background'),

  /// The edge round recharts' pie slices, `#fff` (`es6/polar/Pie.js:559`,
  /// `defaultPieProps.stroke`).
  rechartsPieStroke('recharts-pie-stroke'),

  /// The ring of recharts' active dot, `#fff` (`es6/component/
  /// ActivePoints.js:36`).
  rechartsActiveDotStroke('recharts-active-dot-stroke'),

  /// recharts' `Line` fill, `#fff` (`es6/cartesian/Line.js:126`): the dot a
  /// line of one point draws without `dot` (`es6/component/Dots.js:38-46`).
  rechartsLineFill('recharts-line-fill'),

  /// TanStack Charts' tooltip swatch ring, `rgb(0 0 0 / .12)` (@tanstack/
  /// charts 1.1.0 `dist/tooltip.js:578`, an `inset 0 0 0 1px` shadow).
  tanstackTooltipSwatchRing('tanstack-tooltip-swatch-ring'),

  /// SVG's initial `fill`, black: what a shape whose `fill` the browser
  /// cannot read paints.
  svgInitialFill('svg-initial-fill'),

  /// The border of CopilotKit's default node fallback, `#fca5a5`
  /// (react-core `src/v2/generative-ui/host.tsx:128`): the box shown in
  /// place of a component that cannot be shown. This and the next two are
  /// the host's literal colours, the same in every look.
  copilotkitFallbackBorder('copilotkit-fallback-border'),

  /// The background of CopilotKit's default node fallback, `#fef2f2`
  /// (host.tsx:129).
  copilotkitFallbackBackground('copilotkit-fallback-background'),

  /// The text of CopilotKit's default node fallback, `#991b1b`
  /// (host.tsx:130).
  copilotkitFallbackText('copilotkit-fallback-text'),

  /// KaTeX's `errorColor`, `#cc0000` (katex 0.16.27 `src/Settings.js:
  /// 134-136`): the colour of a formula KaTeX cannot parse and of a command
  /// it does not know, with `throwOnError: false` (the Math component).
  katexErrorColor('katex-error-color');

  const A2uiColorToken(this.wire);

  /// The token's name in CSS, after `--a2ui-color-`, and as the A2UI colour
  /// props write it, after `text-` or `border-` for those groups.
  final String wire;

  /// The token named [wire], or null.
  static A2uiColorToken? fromWire(String wire) => _byWire[wire];

  static final Map<String, A2uiColorToken> _byWire = {
    for (final token in values) token.wire: token,
  };
}

/// A shadow token of the standard components (`--a2ui-shadow-*`).
enum A2uiShadowToken {
  /// `0 1px 2px` at 12%: controls.
  xs,

  /// `0 1px 3px` at 12%: the `shadow` layout prop, Card `shadowStyle: sm`.
  sm,

  /// `0 1px 3px` at 6%: an elevated Card.
  soft,

  /// `0 4px 12px` at 8%: Card `shadowStyle: md`, tooltips.
  md,
}

Color _rgba(int r, int g, int b, double a) =>
    Color.from(alpha: a, red: r / 255, green: g / 255, blue: b / 255);

/// CopilotKit's light colours: the fallbacks in its components.
final Map<A2uiColorToken, Color> standardLightColors = {
  A2uiColorToken.textDefault: const Color(0xff0d0d0d),
  A2uiColorToken.textProse: const Color(0xff0d0d0d),
  A2uiColorToken.textPrimary: const Color(0xff0d0d0d),
  A2uiColorToken.textEmphasis: const Color(0xff000000),
  A2uiColorToken.textSecondary: const Color(0xff5d5d5d),
  A2uiColorToken.textTertiary: const Color(0xff8e8e8e),
  A2uiColorToken.textSuccess: const Color(0xff00805d),
  A2uiColorToken.textInfo: const Color(0xff0068bc),
  A2uiColorToken.textWarning: const Color(0xff946200),
  A2uiColorToken.textCaution: const Color(0xff946200),
  A2uiColorToken.textDanger: const Color(0xffc1322c),
  A2uiColorToken.textDiscovery: const Color(0xff7040c1),
  A2uiColorToken.surface: const Color(0xffffffff),
  A2uiColorToken.surfaceSecondary: const Color(0xfff7f7f8),
  A2uiColorToken.surfaceTertiary: const Color(0xffececec),
  A2uiColorToken.surfaceElevated: const Color(0xffffffff),
  A2uiColorToken.surfaceElevatedSecondary: const Color(0xfff7f7f8),
  A2uiColorToken.surfaceInverted: const Color(0xff0d0d0d),
  A2uiColorToken.surfaceSoft: const Color(0xfffcfcfc),
  A2uiColorToken.info: _rgba(0, 104, 188, .08),
  A2uiColorToken.warning: _rgba(148, 98, 0, .08),
  A2uiColorToken.caution: _rgba(148, 98, 0, .08),
  A2uiColorToken.success: _rgba(0, 128, 93, .08),
  A2uiColorToken.danger: _rgba(193, 50, 44, .08),
  A2uiColorToken.discovery: _rgba(112, 64, 193, .08),
  A2uiColorToken.infoSoft: _rgba(0, 104, 188, .06),
  A2uiColorToken.warningSoft: _rgba(148, 98, 0, .06),
  A2uiColorToken.cautionSoft: _rgba(148, 98, 0, .06),
  A2uiColorToken.successSoft: _rgba(0, 128, 93, .06),
  A2uiColorToken.dangerSoft: _rgba(193, 50, 44, .06),
  A2uiColorToken.discoverySoft: _rgba(112, 64, 193, .06),
  A2uiColorToken.infoSolid: const Color(0xff0068bc),
  A2uiColorToken.warningSolid: const Color(0xff946200),
  A2uiColorToken.cautionSolid: const Color(0xff946200),
  A2uiColorToken.successSolid: const Color(0xff00805d),
  A2uiColorToken.dangerSolid: const Color(0xffc1322c),
  A2uiColorToken.discoverySolid: const Color(0xff7040c1),
  A2uiColorToken.borderDefault: _rgba(0, 0, 0, .1),
  A2uiColorToken.borderSubtle: _rgba(0, 0, 0, .05),
  A2uiColorToken.borderStrong: const Color(0xffcdcdcd),
  A2uiColorToken.borderInfo: const Color(0xff9cc4ea),
  A2uiColorToken.borderWarning: const Color(0xffe6c98a),
  A2uiColorToken.borderCaution: const Color(0xffe6c98a),
  A2uiColorToken.borderSuccess: const Color(0xff9ad9c3),
  A2uiColorToken.borderDanger: const Color(0xffeeaaa6),
  A2uiColorToken.borderDiscovery: const Color(0xffc8b4ea),
  A2uiColorToken.borderControl: _rgba(0, 0, 0, .15),
  A2uiColorToken.accent: const Color(0xff0d0d0d),
  A2uiColorToken.onAccent: const Color(0xffffffff),
  A2uiColorToken.panel: const Color(0xfffcfcfc),
  A2uiColorToken.control: const Color(0xffffffff),
  A2uiColorToken.focus: const Color(0xff0285ff),
  // `--ring: oklch(0.708 0 0)` (globals.css:28) at 50%.
  A2uiColorToken.outlineRing: oklch(.708, 0, 0, .5),
  A2uiColorToken.shimmer: _rgba(255, 255, 255, .55),
  A2uiColorToken.chartCursor: _rgba(0, 0, 0, .04),
  A2uiColorToken.sliderTrack: _rgba(0, 0, 0, .04),
  A2uiColorToken.badgeSecondary: _rgba(0, 0, 0, .05),
  A2uiColorToken.highlightGreen: const Color(0xffd3f5e4),
  A2uiColorToken.highlightOrange: const Color(0xffffe7c7),
  A2uiColorToken.highlightPink: const Color(0xfffde0ef),
  A2uiColorToken.backdrop: _rgba(0, 0, 0, .8),
  A2uiColorToken.overlay: _rgba(0, 0, 0, .65),
  A2uiColorToken.rating: const Color(0xfff5a524),
  A2uiColorToken.chart1: const Color(0xff7fb0f2),
  A2uiColorToken.chart2: const Color(0xff2f6fd1),
  A2uiColorToken.chart3: const Color(0xffb7cff7),
  A2uiColorToken.chart4: const Color(0xff8bb5a8),
  A2uiColorToken.chart5: const Color(0xffd9b36b),
  A2uiColorToken.chart6: const Color(0xffc08bb0),
  // Library literals, the same in the dark (recharts has no dark look).
  A2uiColorToken.rechartsCursorStroke: const Color(0xffcccccc),
  A2uiColorToken.rechartsTextFill: const Color(0xff808080),
  A2uiColorToken.rechartsTooltipBackground: const Color(0xffffffff),
  A2uiColorToken.rechartsPieStroke: const Color(0xffffffff),
  A2uiColorToken.rechartsActiveDotStroke: const Color(0xffffffff),
  A2uiColorToken.rechartsLineFill: const Color(0xffffffff),
  A2uiColorToken.tanstackTooltipSwatchRing: _rgba(0, 0, 0, .12),
  A2uiColorToken.svgInitialFill: const Color(0xff000000),
  // CopilotKit's host fallback (host.tsx:128-130), the same in the dark.
  A2uiColorToken.copilotkitFallbackBorder: const Color(0xfffca5a5),
  A2uiColorToken.copilotkitFallbackBackground: const Color(0xfffef2f2),
  A2uiColorToken.copilotkitFallbackText: const Color(0xff991b1b),
  // KaTeX has no dark look: the same in the dark.
  A2uiColorToken.katexErrorColor: const Color(0xffcc0000),
};

/// CopilotKit's dark colours: `DARK_THEME` over the light fallbacks.
final Map<A2uiColorToken, Color> standardDarkColors = {
  ...standardLightColors,
  A2uiColorToken.textDefault: const Color(0xffececec),
  A2uiColorToken.textProse: const Color(0xffececec),
  A2uiColorToken.textPrimary: const Color(0xffececec),
  A2uiColorToken.textEmphasis: const Color(0xffffffff),
  A2uiColorToken.textSecondary: const Color(0xffb4b4b4),
  A2uiColorToken.textTertiary: const Color(0xff8e8e8e),
  A2uiColorToken.textSuccess: const Color(0xff4fd1a5),
  A2uiColorToken.textInfo: const Color(0xff6cb6ff),
  A2uiColorToken.textWarning: const Color(0xffe3b341),
  A2uiColorToken.textCaution: const Color(0xffe3b341),
  A2uiColorToken.textDanger: const Color(0xffff7b72),
  A2uiColorToken.textDiscovery: const Color(0xffbc9cff),
  A2uiColorToken.surface: const Color(0xff1f1f1f),
  A2uiColorToken.surfaceSecondary: const Color(0xff2a2a2a),
  A2uiColorToken.surfaceTertiary: const Color(0xff3a3a3a),
  A2uiColorToken.surfaceElevated: const Color(0xff262626),
  A2uiColorToken.surfaceElevatedSecondary: const Color(0xff2f2f2f),
  A2uiColorToken.surfaceInverted: const Color(0xfff2f2f2),
  A2uiColorToken.surfaceSoft: const Color(0xff232323),
  A2uiColorToken.info: _rgba(80, 160, 255, .14),
  A2uiColorToken.warning: _rgba(240, 180, 60, .14),
  A2uiColorToken.caution: _rgba(240, 180, 60, .14),
  A2uiColorToken.success: _rgba(60, 200, 150, .14),
  A2uiColorToken.danger: _rgba(255, 110, 100, .14),
  A2uiColorToken.discovery: _rgba(170, 130, 255, .14),
  A2uiColorToken.infoSoft: _rgba(80, 160, 255, .08),
  A2uiColorToken.warningSoft: _rgba(240, 180, 60, .08),
  A2uiColorToken.cautionSoft: _rgba(240, 180, 60, .08),
  A2uiColorToken.successSoft: _rgba(60, 200, 150, .08),
  A2uiColorToken.dangerSoft: _rgba(255, 110, 100, .08),
  A2uiColorToken.discoverySoft: _rgba(170, 130, 255, .08),
  A2uiColorToken.infoSolid: const Color(0xff3b8eea),
  A2uiColorToken.warningSolid: const Color(0xffc99a2e),
  A2uiColorToken.cautionSolid: const Color(0xffc99a2e),
  A2uiColorToken.successSolid: const Color(0xff2fae86),
  A2uiColorToken.dangerSolid: const Color(0xffe5534b),
  A2uiColorToken.discoverySolid: const Color(0xff9a6ff0),
  A2uiColorToken.borderDefault: _rgba(255, 255, 255, .12),
  A2uiColorToken.borderSubtle: _rgba(255, 255, 255, .06),
  A2uiColorToken.borderStrong: const Color(0xff4a4a4a),
  A2uiColorToken.borderInfo: const Color(0xff2f5f8f),
  A2uiColorToken.borderWarning: const Color(0xff6b5420),
  A2uiColorToken.borderCaution: const Color(0xff6b5420),
  A2uiColorToken.borderSuccess: const Color(0xff1f5f4b),
  A2uiColorToken.borderDanger: const Color(0xff7a2f2b),
  A2uiColorToken.borderDiscovery: const Color(0xff4f3a80),
  A2uiColorToken.borderControl: _rgba(255, 255, 255, .2),
  A2uiColorToken.accent: const Color(0xfff2f2f2),
  A2uiColorToken.onAccent: const Color(0xff0d0d0d),
  A2uiColorToken.panel: const Color(0xff262626),
  A2uiColorToken.control: const Color(0xff2f2f2f),
  A2uiColorToken.focus: const Color(0xff3b9bff),
  // The dark `--ring: oklch(0.556 0 0)` (globals.css:65) at 50%.
  A2uiColorToken.outlineRing: oklch(.556, 0, 0, .5),
  A2uiColorToken.shimmer: _rgba(255, 255, 255, .12),
  A2uiColorToken.chartCursor: _rgba(255, 255, 255, .06),
  A2uiColorToken.sliderTrack: _rgba(255, 255, 255, .1),
  A2uiColorToken.badgeSecondary: _rgba(255, 255, 255, .08),
  A2uiColorToken.highlightGreen: const Color(0xff1d4a37),
  A2uiColorToken.highlightOrange: const Color(0xff4d3418),
  A2uiColorToken.highlightPink: const Color(0xff4d2338),
};

/// The playground's `playgroundTheme` over CopilotKit's light colours
/// (`src/a2ui/catalog/catalog.ts`).
final Map<A2uiColorToken, Color> playgroundLightColors = {
  ...standardLightColors,
  A2uiColorToken.surface: oklch(1, 0, 0),
  A2uiColorToken.surfaceSecondary: oklch(.97, .003, 285),
  A2uiColorToken.surfaceElevated: oklch(1, 0, 0),
  A2uiColorToken.surfaceSoft: oklch(.21, .012, 285, .03),
  A2uiColorToken.panel: oklch(1, 0, 0),
  A2uiColorToken.borderDefault: oklch(.21, .012, 285, .09),
  A2uiColorToken.borderSubtle: oklch(.21, .012, 285, .06),
  A2uiColorToken.borderStrong: oklch(.21, .012, 285, .15),
  A2uiColorToken.textDefault: oklch(.2, .008, 285),
  A2uiColorToken.textSecondary: oklch(.47, .014, 285),
  A2uiColorToken.accent: oklch(.52, .2, 292),
  A2uiColorToken.onAccent: oklch(.985, .005, 292),
  // A surface keeps the app's `--ring: oklch(0.5 0.2 292 / 50%)`
  // (src/app/globals.css:53-54, :76), at 50% (`outline-ring/50`, :132).
  A2uiColorToken.outlineRing: oklch(.5, .2, 292, .25),
  A2uiColorToken.chart1: oklch(.55, .2, 292),
  A2uiColorToken.chart2: oklch(.58, .13, 230),
  A2uiColorToken.chart3: oklch(.6, .14, 162),
  A2uiColorToken.chart4: oklch(.7, .15, 72),
  A2uiColorToken.chart5: oklch(.6, .2, 18),
  A2uiColorToken.chart6: oklch(.6, .03, 285),
};

/// The playground's dark `playgroundTheme` values over CopilotKit's dark
/// colours.
final Map<A2uiColorToken, Color> playgroundDarkColors = {
  ...standardDarkColors,
  A2uiColorToken.surface: oklch(.172, .005, 285),
  A2uiColorToken.surfaceSecondary: oklch(.205, .006, 285),
  A2uiColorToken.surfaceElevated: oklch(.205, .006, 285),
  A2uiColorToken.surfaceSoft: oklch(1, 0, 0, .03),
  A2uiColorToken.panel: oklch(.172, .005, 285),
  A2uiColorToken.borderDefault: oklch(1, 0, 0, .075),
  A2uiColorToken.borderSubtle: oklch(1, 0, 0, .05),
  A2uiColorToken.borderStrong: oklch(1, 0, 0, .12),
  A2uiColorToken.textDefault: oklch(.97, .003, 285),
  A2uiColorToken.textSecondary: oklch(.68, .012, 285),
  A2uiColorToken.accent: oklch(.72, .17, 292),
  A2uiColorToken.onAccent: oklch(.16, .02, 292),
  // The dark `--ring: oklch(0.72 0.17 292 / 60%)` (:114) at 50%.
  A2uiColorToken.outlineRing: oklch(.72, .17, 292, .3),
  A2uiColorToken.chart1: oklch(.72, .17, 292),
  A2uiColorToken.chart2: oklch(.76, .12, 225),
  A2uiColorToken.chart3: oklch(.79, .15, 162),
  A2uiColorToken.chart4: oklch(.83, .14, 78),
  A2uiColorToken.chart5: oklch(.71, .18, 12),
  A2uiColorToken.chart6: oklch(.7, .03, 285),
};

/// CopilotKit's shadows in light mode.
final Map<A2uiShadowToken, List<BoxShadow>> standardLightShadows = {
  A2uiShadowToken.xs: [cssShadow(0, 1, 2, _rgba(0, 0, 0, .12))],
  A2uiShadowToken.sm: [cssShadow(0, 1, 3, _rgba(0, 0, 0, .12))],
  A2uiShadowToken.soft: [cssShadow(0, 1, 3, _rgba(0, 0, 0, .06))],
  A2uiShadowToken.md: [cssShadow(0, 4, 12, _rgba(0, 0, 0, .08))],
};

/// CopilotKit's shadows in dark mode.
final Map<A2uiShadowToken, List<BoxShadow>> standardDarkShadows = {
  A2uiShadowToken.xs: [cssShadow(0, 1, 2, _rgba(0, 0, 0, .5))],
  A2uiShadowToken.sm: [cssShadow(0, 1, 3, _rgba(0, 0, 0, .5))],
  A2uiShadowToken.soft: [cssShadow(0, 1, 3, _rgba(0, 0, 0, .3))],
  A2uiShadowToken.md: [cssShadow(0, 4, 12, _rgba(0, 0, 0, .4))],
};

// PORT STATUS: confidence=high todos=0 upstream=packages/shared/src/generative-ui/standard/tokens.ts, examples/showcases/a2ui-playground/src/app/globals.css
