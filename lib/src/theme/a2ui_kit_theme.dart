import 'dart:ui' show lerpDouble;

import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_color.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/theme/playground_tokens.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:a2ui_kit/src/theme/typography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Which of the shipped looks a theme starts from.
enum A2uiKitLook {
  /// The hosted A2UI Playground (a2ui.open.bot): a violet accent, zinc
  /// tinted surfaces and 14px large radii.
  playground,

  /// CopilotKit's library defaults: a near-black accent and neutral greys.
  standard,
}

/// The look of a2ui_kit surfaces: colours, radii, shadows, spacing and
/// type.
///
/// It holds both token layers of CopilotKit's catalog: the `--a2ui-*`
/// tokens of the 69 standard components ([colors], [radii], [shadows],
/// [typography]) and the `--a2-*` tokens of the playground's 52 components
/// ([playground]).
///
/// Add it to a [ThemeData] to restyle every surface below it:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: [A2uiKitTheme.playground(Brightness.light)],
///   ),
///   darkTheme: ThemeData(
///     brightness: Brightness.dark,
///     extensions: [A2uiKitTheme.playground(Brightness.dark)],
///   ),
/// );
/// ```
///
/// Without one, surfaces use [A2uiKitTheme.playground] (or the look the
/// catalog's options name) in the brightness of the ambient [Theme].
@immutable
class A2uiKitTheme extends ThemeExtension<A2uiKitTheme> with Diagnosticable {
  /// A theme with every token given.
  const A2uiKitTheme({
    required this.brightness,
    required this.colors,
    required this.radii,
    required this.shadows,
    required this.typography,
    required this.playground,
    this.spacingStep = 4,
    this.keyValueRows = false,
    this.tableEdges = false,
  });

  /// The hosted playground's look in [brightness]: CopilotKit's tokens with
  /// the playground's `playgroundTheme` over them.
  factory A2uiKitTheme.playground(Brightness brightness) =>
      brightness == Brightness.dark ? _playgroundDark : _playgroundLight;

  /// CopilotKit's library look in [brightness].
  factory A2uiKitTheme.standard(Brightness brightness) =>
      brightness == Brightness.dark ? _standardDark : _standardLight;

  /// The [look] in [brightness].
  factory A2uiKitTheme.fromLook(A2uiKitLook look, Brightness brightness) =>
      switch (look) {
        A2uiKitLook.playground => A2uiKitTheme.playground(brightness),
        A2uiKitLook.standard => A2uiKitTheme.standard(brightness),
      };

  /// A theme from a Material [scheme], as the playground's Material design
  /// system maps Material's colour roles onto the tokens (`themes.ts` and
  /// `design-systems.css` in the playground):
  ///
  /// - text on-surface, secondary text on-surface-variant, tertiary the
  ///   outline; surfaces the surface containers; borders the outline
  ///   variant and the outline; the accent and focus the primary;
  /// - info is the primary, danger the error, discovery the tertiary;
  ///   success and warning, which Material has no roles for, are the
  ///   design system's own greens and ambers;
  /// - a tone's border is its container in the dark and its tone 80 in the
  ///   light (exact for info, the inverse primary; mixed from the container
  ///   for the others);
  /// - Material 3's corners: 12px medium, 16px large, 28px extra large;
  /// - the playground components get the surface, the outline variant as
  ///   their line, 12px card corners and no card shadow.
  ///
  /// The font and the type stay the app's.
  factory A2uiKitTheme.fromColorScheme(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    final base = A2uiKitTheme.standard(scheme.brightness);
    final success = dark ? const Color(0xff6ddba7) : const Color(0xff006c49);
    final warning = dark ? const Color(0xffffb875) : const Color(0xff8d4f00);
    // Tone 30 (the container) in the dark, tone 80 in the light.
    final successBorder = dark
        ? const Color(0xff005236)
        : const Color(0xff6ddba7);
    final warningBorder = dark
        ? const Color(0xff6b3b00)
        : const Color(0xffffb875);
    final tint = dark ? .12 : .08;
    final soft = dark ? .08 : .05;
    Color toneBorder(Color tone, Color container) =>
        dark ? container : Color.lerp(container, tone, .2)!;
    final tones = <String, (Color, Color)>{
      'info': (
        scheme.primary,
        dark ? scheme.primaryContainer : scheme.inversePrimary,
      ),
      'warning': (warning, warningBorder),
      'caution': (warning, warningBorder),
      'success': (success, successBorder),
      'danger': (scheme.error, toneBorder(scheme.error, scheme.errorContainer)),
      'discovery': (
        scheme.tertiary,
        toneBorder(scheme.tertiary, scheme.tertiaryContainer),
      ),
    };
    final colors = <A2uiColorToken, Color>{
      ...base.colors,
      A2uiColorToken.textDefault: scheme.onSurface,
      A2uiColorToken.textProse: scheme.onSurface,
      A2uiColorToken.textPrimary: scheme.onSurface,
      A2uiColorToken.textEmphasis: scheme.onSurface,
      A2uiColorToken.textSecondary: scheme.onSurfaceVariant,
      A2uiColorToken.textTertiary: scheme.outline,
      A2uiColorToken.surface: scheme.surfaceContainer,
      A2uiColorToken.surfaceSecondary: scheme.surfaceContainerHigh,
      A2uiColorToken.surfaceTertiary: scheme.surfaceContainerHighest,
      A2uiColorToken.surfaceElevated: scheme.surfaceContainerHigh,
      A2uiColorToken.surfaceElevatedSecondary: scheme.surfaceContainerHighest,
      A2uiColorToken.surfaceInverted: scheme.inverseSurface,
      A2uiColorToken.surfaceSoft: scheme.surfaceContainerLow,
      A2uiColorToken.borderDefault: scheme.outlineVariant,
      A2uiColorToken.borderSubtle: scheme.surfaceContainerHighest,
      A2uiColorToken.borderStrong: scheme.outline,
      A2uiColorToken.borderControl: scheme.outline,
      A2uiColorToken.accent: scheme.primary,
      A2uiColorToken.onAccent: scheme.onPrimary,
      A2uiColorToken.panel: scheme.surfaceContainer,
      A2uiColorToken.control: scheme.surfaceContainerHighest,
      A2uiColorToken.focus: scheme.primary,
      A2uiColorToken.shimmer: scheme.onSurface.withValues(alpha: .08),
      A2uiColorToken.chartCursor: scheme.onSurface.withValues(alpha: .06),
      A2uiColorToken.sliderTrack: scheme.outlineVariant,
      A2uiColorToken.badgeSecondary: scheme.surfaceContainerHighest,
      A2uiColorToken.chart1: scheme.primary,
      A2uiColorToken.chart2: success,
      A2uiColorToken.chart3: warning,
      A2uiColorToken.chart4: scheme.tertiary,
      A2uiColorToken.chart5: scheme.error,
      A2uiColorToken.chart6: scheme.secondary,
      for (final MapEntry(key: name, value: (color, border))
          in tones.entries) ...{
        A2uiColorToken.fromWire('text-$name')!: color,
        A2uiColorToken.fromWire(name)!: color.withValues(alpha: tint),
        A2uiColorToken.fromWire('$name-soft')!: color.withValues(alpha: soft),
        A2uiColorToken.fromWire('$name-solid')!: color,
        A2uiColorToken.fromWire('border-$name')!: border,
      },
    };
    final ink = scheme.onSurface;
    return A2uiKitTheme(
      brightness: scheme.brightness,
      colors: Map.unmodifiable(colors),
      radii: const {
        A2uiRadius.twoXs: 4,
        A2uiRadius.xs: 8,
        A2uiRadius.sm: 8,
        A2uiRadius.md: 12,
        A2uiRadius.lg: 16,
        A2uiRadius.xl: 20,
        A2uiRadius.twoXl: 28,
        A2uiRadius.threeXl: 28,
        A2uiRadius.fourXl: 28,
        A2uiRadius.full: 9999,
      },
      shadows: base.shadows,
      typography: const A2uiKitTypography.playground(),
      playground: base.playground.copyWith(
        ink: ink,
        foreground: scheme.onSurface,
        mutedForeground: scheme.onSurfaceVariant,
        surface: scheme.surface,
        surface2: scheme.surfaceContainer,
        line: scheme.outlineVariant,
        lineStrong: scheme.outline,
        radius: 12,
        tones: {
          A2uiTone.default_: scheme.onSurface,
          A2uiTone.accent: scheme.primary,
          A2uiTone.positive: success,
          A2uiTone.negative: scheme.error,
          A2uiTone.warning: warning,
          A2uiTone.info: scheme.primary,
        },
        chart: [
          scheme.primary,
          success,
          scheme.tertiary,
          warning,
          scheme.secondary,
          scheme.onSurfaceVariant,
        ],
        chartInk: dark ? scheme.outlineVariant : scheme.onSurfaceVariant,
        cardShadow: const [],
        cardSheen: const Color(0x00000000),
        secondary: scheme.secondaryContainer,
        secondaryForeground: scheme.onSecondaryContainer,
      ),
    );
  }

  static final A2uiKitTheme _playgroundLight = A2uiKitTheme(
    brightness: Brightness.light,
    colors: Map.unmodifiable(playgroundLightColors),
    radii: _playgroundRadii,
    shadows: Map.unmodifiable(standardLightShadows),
    typography: const A2uiKitTypography.playground(),
    playground: A2uiPlaygroundTokens.light(),
  );

  static final A2uiKitTheme _playgroundDark = A2uiKitTheme(
    brightness: Brightness.dark,
    colors: Map.unmodifiable(playgroundDarkColors),
    radii: _playgroundRadii,
    shadows: Map.unmodifiable(standardDarkShadows),
    typography: const A2uiKitTypography.playground(),
    playground: A2uiPlaygroundTokens.dark(),
  );

  static final A2uiKitTheme _standardLight = A2uiKitTheme(
    brightness: Brightness.light,
    colors: Map.unmodifiable(standardLightColors),
    radii: standardRadii,
    shadows: Map.unmodifiable(standardLightShadows),
    // A browser's link colour in a page without styles.
    typography: const A2uiKitTypography.standard(linkColor: Color(0xff0000ee)),
    keyValueRows: true,
    tableEdges: true,
    playground: A2uiPlaygroundTokens.light(),
  );

  static final A2uiKitTheme _standardDark = A2uiKitTheme(
    brightness: Brightness.dark,
    colors: Map.unmodifiable(standardDarkColors),
    radii: standardRadii,
    shadows: Map.unmodifiable(standardDarkShadows),
    typography: const A2uiKitTypography.standard(linkColor: Color(0xff9e9eff)),
    keyValueRows: true,
    tableEdges: true,
    playground: A2uiPlaygroundTokens.dark(),
  );

  /// CopilotKit's radii in pixels (`--a2ui-radius-*`).
  static const Map<A2uiRadius, double> standardRadii = {
    A2uiRadius.twoXs: 2,
    A2uiRadius.xs: 4,
    A2uiRadius.sm: 6,
    A2uiRadius.md: 8,
    A2uiRadius.lg: 12,
    A2uiRadius.xl: 16,
    A2uiRadius.twoXl: 20,
    A2uiRadius.threeXl: 24,
    A2uiRadius.fourXl: 32,
    A2uiRadius.full: 9999,
  };

  /// The playground's radii: CopilotKit's, with `lg` at 14px.
  static const Map<A2uiRadius, double> _playgroundRadii = {
    A2uiRadius.twoXs: 2,
    A2uiRadius.xs: 4,
    A2uiRadius.sm: 6,
    A2uiRadius.md: 8,
    A2uiRadius.lg: 14,
    A2uiRadius.xl: 16,
    A2uiRadius.twoXl: 20,
    A2uiRadius.threeXl: 24,
    A2uiRadius.fourXl: 32,
    A2uiRadius.full: 9999,
  };

  /// The theme for [context]: the [A2uiKitTheme] extension of the ambient
  /// [Theme], or else the [look] (the playground's by default) in the
  /// [Theme]'s brightness.
  // ignore: prefer_constructors_over_static_methods (Flutter's `of` is static)
  static A2uiKitTheme of(
    BuildContext context, {
    A2uiKitLook look = A2uiKitLook.playground,
  }) {
    final theme = Theme.of(context);
    return theme.extension<A2uiKitTheme>() ??
        A2uiKitTheme.fromLook(look, theme.brightness);
  }

  /// Light or dark.
  final Brightness brightness;

  /// The colour of each token. A token the map lacks falls back to
  /// CopilotKit's colour in [brightness].
  final Map<A2uiColorToken, Color> colors;

  /// The radius of each radius token, in pixels.
  final Map<A2uiRadius, double> radii;

  /// The shadows of each shadow token.
  final Map<A2uiShadowToken, List<BoxShadow>> shadows;

  /// The type.
  final A2uiKitTypography typography;

  /// The tokens of the playground's own components.
  final A2uiPlaygroundTokens playground;

  /// The pixels of one spacing step: a layout length of 3 is 3 steps.
  final double spacingStep;

  /// Whether the last Text of a `spaceBetween` Row (not its only child)
  /// sits flush right: CopilotKit's standard stylesheet rule for key/value
  /// rows. True in [A2uiKitTheme.standard]; the playground wraps every
  /// component in an element of its own, which the rule's selector does
  /// not see through, so it is false there and in
  /// [A2uiKitTheme.fromColorScheme], the playground's Material system.
  final bool keyValueRows;

  /// Whether the TableCells of a Table built from `children` take
  /// CopilotKit's standard stylesheet's structural rules
  /// (`.a2ui-std-cell:first-child` and `:last-child`, no padding at the
  /// row's outer edges; `.a2ui-std-table>tbody:last-child>tr:last-child`,
  /// no divider under the last row; styles.ts:75-78). True in
  /// [A2uiKitTheme.standard]. The playground wraps every component in an
  /// element of its own (a `display: contents` span, catalog.ts:93-110),
  /// which those selectors do not see through: each TableCell is then the
  /// first and last child of its wrapper (no padding at either side), and
  /// the last row keeps its divider. So it is false there and in
  /// [A2uiKitTheme.fromColorScheme].
  final bool tableEdges;

  /// The colour of [token].
  Color color(A2uiColorToken token) =>
      colors[token] ??
      (brightness == Brightness.dark
          ? standardDarkColors[token]!
          : standardLightColors[token]!);

  /// The shadows of [token].
  List<BoxShadow> shadow(A2uiShadowToken token) =>
      shadows[token] ??
      (brightness == Brightness.dark
          ? standardDarkShadows[token]!
          : standardLightShadows[token]!);

  /// The pixels of [step] spacing steps.
  double space(num step) => step * spacingStep;

  static const Set<String> _textTokens = {
    'default', 'prose', 'primary', 'emphasis', 'secondary', 'tertiary', //
    'success', 'info', 'warning', 'caution', 'danger', 'discovery',
  };

  static const Set<String> _backgroundTokens = {
    'surface', 'surface-secondary', 'surface-tertiary', 'surface-elevated', //
    'surface-elevated-secondary', 'surface-inverted', 'surface-soft', 'info',
    'warning', 'caution', 'success', 'danger', 'discovery', 'info-solid',
    'warning-solid', 'caution-solid', 'success-solid', 'danger-solid',
    'discovery-solid',
  };

  static const Set<String> _borderTokens = {
    'default', 'subtle', 'strong', 'info', 'warning', 'caution', 'success', //
    'danger', 'discovery',
  };

  static const Map<String, A2uiColorToken> _softTints = {
    'info': A2uiColorToken.infoSoft,
    'warning': A2uiColorToken.warningSoft,
    'caution': A2uiColorToken.cautionSoft,
    'success': A2uiColorToken.successSoft,
    'danger': A2uiColorToken.dangerSoft,
    'discovery': A2uiColorToken.discoverySoft,
  };

  /// The colour of a text colour prop: a token (`secondary`) or a CSS colour.
  /// Null when [value] is null, empty or unreadable.
  Color? textColor(String? value) {
    if (value == null || value.isEmpty) return null;
    if (_textTokens.contains(value)) {
      return color(A2uiColorToken.fromWire('text-$value')!);
    }
    return parseCssColor(value);
  }

  /// The colour of a background prop: a surface or tint token
  /// (`surface-secondary`, `info`, `danger-solid`) or a CSS colour.
  Color? backgroundColor(String? value) {
    if (value == null || value.isEmpty) return null;
    if (_backgroundTokens.contains(value)) {
      return color(A2uiColorToken.fromWire(value)!);
    }
    return parseCssColor(value);
  }

  /// The colour of a border colour prop: a token (`subtle`) or a CSS colour.
  Color? borderColor(String? value) {
    if (value == null || value.isEmpty) return null;
    if (_borderTokens.contains(value)) {
      return color(A2uiColorToken.fromWire('border-$value')!);
    }
    return parseCssColor(value);
  }

  /// The background of a panel inside a Card: a neutral surface becomes
  /// the inner panel, a tint gets lighter, anything else is
  /// [backgroundColor].
  Color? panelBackground(String? value) {
    if (value == null || value.isEmpty) return null;
    const neutral = {
      'surface-secondary',
      'surface-soft',
      'surface-elevated-secondary',
    };
    if (neutral.contains(value)) return color(A2uiColorToken.panel);
    final soft = _softTints[value];
    if (soft != null) return color(soft);
    return backgroundColor(value);
  }

  /// The pixels of a radius prop: a token (`md`), a number of pixels, or a
  /// CSS length. Null when [value] is unreadable.
  double? radius(Object? value, {double fontSize = 16}) {
    if (value is num) return value.isFinite ? value.toDouble() : null;
    if (value is! String) return null;
    final token = A2uiRadius.fromWire(value);
    if (token != null) return radii[token] ?? standardRadii[token];
    return A2uiLength.parse(value)?.resolve(fontSize: fontSize);
  }

  @override
  A2uiKitTheme copyWith({
    Brightness? brightness,
    Map<A2uiColorToken, Color>? colors,
    Map<A2uiRadius, double>? radii,
    Map<A2uiShadowToken, List<BoxShadow>>? shadows,
    A2uiKitTypography? typography,
    A2uiPlaygroundTokens? playground,
    double? spacingStep,
    bool? keyValueRows,
    bool? tableEdges,
  }) => A2uiKitTheme(
    brightness: brightness ?? this.brightness,
    colors: colors ?? this.colors,
    radii: radii ?? this.radii,
    shadows: shadows ?? this.shadows,
    typography: typography ?? this.typography,
    playground: playground ?? this.playground,
    spacingStep: spacingStep ?? this.spacingStep,
    keyValueRows: keyValueRows ?? this.keyValueRows,
    tableEdges: tableEdges ?? this.tableEdges,
  );

  /// A copy whose [colors] are these with [overrides] on top.
  A2uiKitTheme withColors(Map<A2uiColorToken, Color> overrides) =>
      copyWith(colors: {...colors, ...overrides});

  @override
  A2uiKitTheme lerp(covariant A2uiKitTheme? other, double t) {
    if (other == null) return this;
    return A2uiKitTheme(
      brightness: t < .5 ? brightness : other.brightness,
      colors: {
        for (final token in A2uiColorToken.values)
          token: Color.lerp(color(token), other.color(token), t)!,
      },
      radii: {
        for (final token in A2uiRadius.values)
          token: lerpDouble(
            radii[token] ?? standardRadii[token],
            other.radii[token] ?? standardRadii[token],
            t,
          )!,
      },
      shadows: {
        for (final token in A2uiShadowToken.values)
          token: BoxShadow.lerpList(shadow(token), other.shadow(token), t)!,
      },
      typography: A2uiKitTypography.lerp(typography, other.typography, t),
      playground: A2uiPlaygroundTokens.lerp(playground, other.playground, t),
      spacingStep: lerpDouble(spacingStep, other.spacingStep, t)!,
      keyValueRows: t < .5 ? keyValueRows : other.keyValueRows,
      tableEdges: t < .5 ? tableEdges : other.tableEdges,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is A2uiKitTheme &&
      other.brightness == brightness &&
      mapEquals(other.colors, colors) &&
      mapEquals(other.radii, radii) &&
      _shadowsEqual(other.shadows, shadows) &&
      other.typography == typography &&
      other.playground == playground &&
      other.spacingStep == spacingStep &&
      other.keyValueRows == keyValueRows &&
      other.tableEdges == tableEdges;

  static bool _shadowsEqual(
    Map<A2uiShadowToken, List<BoxShadow>> a,
    Map<A2uiShadowToken, List<BoxShadow>> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!listEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    brightness,
    Object.hashAllUnordered(colors.entries.map((e) => (e.key, e.value))),
    Object.hashAllUnordered(radii.entries.map((e) => (e.key, e.value))),
    Object.hashAllUnordered(
      shadows.entries.map((e) => (e.key, Object.hashAll(e.value))),
    ),
    typography,
    playground,
    spacingStep,
    keyValueRows,
    tableEdges,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<Brightness>('brightness', brightness))
      ..add(ColorProperty('accent', color(A2uiColorToken.accent)))
      ..add(DoubleProperty('spacingStep', spacingStep))
      ..add(
        FlagProperty(
          'keyValueRows',
          value: keyValueRows,
          ifTrue: 'key/value rows',
        ),
      )
      ..add(
        FlagProperty('tableEdges', value: tableEdges, ifTrue: 'table edges'),
      )
      ..add(DiagnosticsProperty<A2uiKitTypography>('typography', typography));
  }
}

// PORT STATUS: confidence=high todos=0 upstream=packages/shared/src/generative-ui/standard/theme.ts, examples/showcases/a2ui-playground/src/design-systems/themes.ts
