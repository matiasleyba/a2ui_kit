import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The HTML heading level a Title renders as: `sm` is an h4, `md` and `lg`
/// an h3, `xl` and up an h2.
enum A2uiHeadingLevel {
  /// `<h2>`: Title sizes xl to 5xl.
  h2,

  /// `<h3>`: Title sizes md and lg.
  h3,

  /// `<h4>`: Title size sm.
  h4,
}

/// The type of one heading level. A null field inherits from the text
/// around the heading, as a heading without styles does in a browser.
@immutable
class A2uiHeadingStyle {
  /// A heading style; null fields inherit.
  const A2uiHeadingStyle({this.fontSizeEm, this.fontWeight, this.lineHeight});

  /// The font size as a multiple of the surrounding font size.
  final double? fontSizeEm;

  /// The font weight.
  final FontWeight? fontWeight;

  /// The line height as a multiple of the font size.
  final double? lineHeight;

  /// The style between [a] and [b] at [t].
  // ignore: prefer_constructors_over_static_methods (Flutter's lerp is static)
  static A2uiHeadingStyle lerp(
    A2uiHeadingStyle a,
    A2uiHeadingStyle b,
    double t,
  ) => A2uiHeadingStyle(
    fontSizeEm: a.fontSizeEm == null || b.fontSizeEm == null
        ? (t < .5 ? a.fontSizeEm : b.fontSizeEm)
        : lerpDouble(a.fontSizeEm, b.fontSizeEm, t),
    fontWeight: FontWeight.lerp(a.fontWeight, b.fontWeight, t),
    lineHeight: a.lineHeight == null || b.lineHeight == null
        ? (t < .5 ? a.lineHeight : b.lineHeight)
        : lerpDouble(a.lineHeight, b.lineHeight, t),
  );

  @override
  bool operator ==(Object other) =>
      other is A2uiHeadingStyle &&
      other.fontSizeEm == fontSizeEm &&
      other.fontWeight == fontWeight &&
      other.lineHeight == lineHeight;

  @override
  int get hashCode => Object.hash(fontSizeEm, fontWeight, lineHeight);
}

/// The monospace font every app has: flutter_math_fork's KaTeX_Typewriter,
/// which the package's dependency bundles. Code takes the page's
/// `monospace` in CopilotKit (the `<pre>`'s user-agent font); Flutter's web
/// engines draw only the app's own fonts and Roboto (CanvasKit and
/// skwasm, `fonts.dart:114-133` of the Flutter 3.47.9 web engine), so there
/// neither `monospace` nor Menlo, Consolas or Courier New is found, and
/// code would fall to a proportional font, its columns and tab stops lost.
/// An app sets its own code font with [A2uiKitTypography.monoFontFamily].
const String kitMonoLastResort = 'packages/flutter_math_fork/KaTeX_Typewriter';

/// The type of a surface: its base font, the heading styles of Title, and
/// the inline markdown marks of Text.
///
/// A surface in CopilotKit inherits the font of the page around it. These
/// values stand in for that page.
@immutable
class A2uiKitTypography with Diagnosticable {
  /// Typography with every value given; null values inherit from the
  /// app's `DefaultTextStyle`.
  const A2uiKitTypography({
    required this.headings,
    this.fontSize = 16,
    this.lineHeight,
    this.fontFamily,
    this.fontFamilyFallback,
    this.monoFontFamily = 'monospace',
    this.monoFontFamilyFallback = const [
      'Menlo',
      'Consolas',
      'Courier New',
      kitMonoLastResort,
    ],
    this.inlineCodeScale = 1,
    this.linkColor,
    this.linkUnderline = false,
    this.inheritsHostType = false,
  });

  /// The playground's type (a2ui.open.bot): 16px text with a 1.5 line
  /// height, headings that keep the surrounding type, and inline links and
  /// code that look like the text around them (Tailwind's preflight).
  const A2uiKitTypography.playground()
    : this(
        headings: const {
          A2uiHeadingLevel.h2: A2uiHeadingStyle(),
          A2uiHeadingLevel.h3: A2uiHeadingStyle(),
          A2uiHeadingLevel.h4: A2uiHeadingStyle(),
        },
        lineHeight: 1.5,
      );

  /// CopilotKit's library type: the host's font, size, line height,
  /// weight and colour ([inheritsHostType]: `.a2ui-surface{font:inherit;
  /// color:inherit}`, shared standard/styles.ts:33), the standard
  /// stylesheet's heading fallbacks (h2 1.5em, h3 1.25em, h4 1em, all 600)
  /// and a browser's inline marks (13px code, underlined links). [fontSize]
  /// stands in only where the host gives no size.
  const A2uiKitTypography.standard({Color? linkColor})
    : this(
        headings: const {
          A2uiHeadingLevel.h2: A2uiHeadingStyle(
            fontSizeEm: 1.5,
            fontWeight: FontWeight.w600,
            lineHeight: 1.3,
          ),
          A2uiHeadingLevel.h3: A2uiHeadingStyle(
            fontSizeEm: 1.25,
            fontWeight: FontWeight.w600,
            lineHeight: 1.3,
          ),
          A2uiHeadingLevel.h4: A2uiHeadingStyle(
            fontSizeEm: 1,
            fontWeight: FontWeight.w600,
            lineHeight: 1.4,
          ),
        },
        inlineCodeScale: 13 / 16,
        linkColor: linkColor,
        linkUnderline: true,
        inheritsHostType: true,
      );

  /// The base font size in pixels: the size of `1em`, where the host gives
  /// none when [inheritsHostType].
  final double fontSize;

  /// Whether a surface takes its font, size, line height, weight and
  /// colour from the host (the app's `DefaultTextStyle` around it), as the
  /// standard look's surface does in CopilotKit, inheriting the chat
  /// prose's; false sets [fontSize], [lineHeight], [fontFamily] and the
  /// text colour token, as the playground's page does.
  final bool inheritsHostType;

  /// The base line height as a multiple of the font size, or null for the
  /// font's own.
  final double? lineHeight;

  /// The font family, or null to keep the app's.
  final String? fontFamily;

  /// Fallback font families, or null to keep the app's.
  final List<String>? fontFamilyFallback;

  /// The font of inline code and Code blocks.
  final String monoFontFamily;

  /// Fallbacks for [monoFontFamily]; by default the platforms' own
  /// monospace fonts, then [kitMonoLastResort].
  final List<String> monoFontFamilyFallback;

  /// The style of each heading level a Title renders as.
  final Map<A2uiHeadingLevel, A2uiHeadingStyle> headings;

  /// The font size of inline code relative to the text around it.
  final double inlineCodeScale;

  /// The colour of inline markdown links, or null to keep the text's.
  final Color? linkColor;

  /// Whether inline markdown links are underlined.
  final bool linkUnderline;

  /// The style of [level], inheriting everything when the map has none.
  A2uiHeadingStyle heading(A2uiHeadingLevel level) =>
      headings[level] ?? const A2uiHeadingStyle();

  /// A copy with the given values replaced.
  A2uiKitTypography copyWith({
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    String? monoFontFamily,
    List<String>? monoFontFamilyFallback,
    Map<A2uiHeadingLevel, A2uiHeadingStyle>? headings,
    double? inlineCodeScale,
    Color? linkColor,
    bool? linkUnderline,
    bool? inheritsHostType,
  }) => A2uiKitTypography(
    inheritsHostType: inheritsHostType ?? this.inheritsHostType,
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    fontFamily: fontFamily ?? this.fontFamily,
    fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
    monoFontFamily: monoFontFamily ?? this.monoFontFamily,
    monoFontFamilyFallback:
        monoFontFamilyFallback ?? this.monoFontFamilyFallback,
    headings: headings ?? this.headings,
    inlineCodeScale: inlineCodeScale ?? this.inlineCodeScale,
    linkColor: linkColor ?? this.linkColor,
    linkUnderline: linkUnderline ?? this.linkUnderline,
  );

  /// The typography between [a] and [b] at [t]. Families and flags switch
  /// at the midpoint.
  // ignore: prefer_constructors_over_static_methods (Flutter's lerp is static)
  static A2uiKitTypography lerp(
    A2uiKitTypography a,
    A2uiKitTypography b,
    double t,
  ) {
    final near = t < .5 ? a : b;
    return A2uiKitTypography(
      fontSize: lerpDouble(a.fontSize, b.fontSize, t)!,
      lineHeight: a.lineHeight == null || b.lineHeight == null
          ? near.lineHeight
          : lerpDouble(a.lineHeight, b.lineHeight, t),
      fontFamily: near.fontFamily,
      fontFamilyFallback: near.fontFamilyFallback,
      monoFontFamily: near.monoFontFamily,
      monoFontFamilyFallback: near.monoFontFamilyFallback,
      headings: {
        for (final level in A2uiHeadingLevel.values)
          level: A2uiHeadingStyle.lerp(a.heading(level), b.heading(level), t),
      },
      inlineCodeScale: lerpDouble(a.inlineCodeScale, b.inlineCodeScale, t)!,
      linkColor: Color.lerp(a.linkColor, b.linkColor, t),
      linkUnderline: near.linkUnderline,
      inheritsHostType: near.inheritsHostType,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is A2uiKitTypography &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      other.fontFamily == fontFamily &&
      listEquals(other.fontFamilyFallback, fontFamilyFallback) &&
      other.monoFontFamily == monoFontFamily &&
      listEquals(other.monoFontFamilyFallback, monoFontFamilyFallback) &&
      mapEquals(other.headings, headings) &&
      other.inlineCodeScale == inlineCodeScale &&
      other.linkColor == linkColor &&
      other.linkUnderline == linkUnderline &&
      other.inheritsHostType == inheritsHostType;

  @override
  int get hashCode => Object.hash(
    fontSize,
    lineHeight,
    fontFamily,
    Object.hashAll(fontFamilyFallback ?? const []),
    monoFontFamily,
    Object.hashAll(monoFontFamilyFallback),
    Object.hashAllUnordered(headings.entries.map((e) => (e.key, e.value))),
    inlineCodeScale,
    linkColor,
    linkUnderline,
    inheritsHostType,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('fontSize', fontSize))
      ..add(DoubleProperty('lineHeight', lineHeight))
      ..add(StringProperty('fontFamily', fontFamily))
      ..add(
        FlagProperty(
          'inheritsHostType',
          value: inheritsHostType,
          ifTrue: 'inherits the host type',
        ),
      );
  }
}

// PORT STATUS: confidence=high todos=0 upstream=packages/shared/src/generative-ui/standard/styles.ts
