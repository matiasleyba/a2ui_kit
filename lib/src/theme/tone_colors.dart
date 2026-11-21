import 'package:a2ui_kit/src/foundation/css/css_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The colours of a tinted panel: its border, fill, text and icon, as the
/// playground's Alert and Callout draw them with Tailwind palette classes.
@immutable
class A2uiToneColors with Diagnosticable {
  /// Colours of a tinted panel.
  const A2uiToneColors({
    required this.border,
    required this.background,
    required this.foreground,
    required this.icon,
    this.backgroundEnd,
  });

  /// The 1px border.
  final Color border;

  /// The fill; with [backgroundEnd] the start of a left-to-right gradient
  /// (through [backgroundEnd] to transparent).
  final Color background;

  /// The middle stop of the fill's gradient, or null for a flat fill.
  final Color? backgroundEnd;

  /// The text.
  final Color foreground;

  /// The icon (or the icon tile's fill, for a Callout).
  final Color icon;

  /// The colours between [a] and [b] at [t].
  // ignore: prefer_constructors_over_static_methods (Flutter's lerp is static)
  static A2uiToneColors lerp(A2uiToneColors a, A2uiToneColors b, double t) =>
      A2uiToneColors(
        border: Color.lerp(a.border, b.border, t)!,
        background: Color.lerp(a.background, b.background, t)!,
        backgroundEnd: Color.lerp(a.backgroundEnd, b.backgroundEnd, t),
        foreground: Color.lerp(a.foreground, b.foreground, t)!,
        icon: Color.lerp(a.icon, b.icon, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is A2uiToneColors &&
      other.border == border &&
      other.background == background &&
      other.backgroundEnd == backgroundEnd &&
      other.foreground == foreground &&
      other.icon == icon;

  @override
  int get hashCode =>
      Object.hash(border, background, backgroundEnd, foreground, icon);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('border', border))
      ..add(ColorProperty('background', background))
      ..add(ColorProperty('foreground', foreground));
  }
}

/// Tailwind 4's palette colours that the playground's Alert and Callout
/// use (`sky`, `emerald`, `amber`, `rose`, `violet`), by shade.
abstract final class TailwindPalette {
  /// `sky-100` to `sky-800`.
  static final Map<int, Color> sky = {
    100: oklch(.951, .026, 236.824),
    200: oklch(.901, .058, 230.902),
    300: oklch(.828, .111, 230.318),
    400: oklch(.746, .16, 232.661),
    600: oklch(.588, .158, 241.966),
    800: oklch(.443, .11, 240.79),
  };

  /// `emerald-100` to `emerald-800`.
  static final Map<int, Color> emerald = {
    100: oklch(.95, .052, 163.051),
    200: oklch(.905, .093, 164.15),
    300: oklch(.845, .143, 164.978),
    400: oklch(.765, .177, 163.223),
    600: oklch(.596, .145, 163.225),
    800: oklch(.432, .095, 166.913),
  };

  /// `amber-100` to `amber-800`.
  static final Map<int, Color> amber = {
    100: oklch(.962, .059, 95.617),
    200: oklch(.924, .12, 95.746),
    300: oklch(.879, .169, 91.605),
    400: oklch(.828, .189, 84.429),
    600: oklch(.666, .179, 58.318),
    800: oklch(.473, .137, 46.201),
  };

  /// `rose-100` to `rose-800`.
  static final Map<int, Color> rose = {
    100: oklch(.941, .03, 12.58),
    200: oklch(.892, .058, 10.001),
    300: oklch(.81, .117, 11.638),
    400: oklch(.712, .194, 13.428),
    600: oklch(.586, .253, 17.585),
    800: oklch(.455, .188, 13.697),
  };

  /// `violet-200` to `violet-800`.
  static final Map<int, Color> violet = {
    200: oklch(.894, .057, 293.283),
    400: oklch(.702, .183, 293.541),
    500: oklch(.606, .25, 292.717),
    800: oklch(.432, .232, 292.759),
  };
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/feedback.tsx
