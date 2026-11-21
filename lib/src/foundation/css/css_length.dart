import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A CSS length that a2ui_kit can lay out: pixels, a percentage of the
/// containing box, or a multiple of the font size.
///
/// Read A2UI props with [A2uiLength.steps] (a number is that many spacing
/// steps of 4px) or [A2uiLength.pixels] (a number is pixels). A string is
/// read as CSS in both: `12px`, `1.5rem`, `2em`, `50%` and `0`. Any other
/// CSS, such as `calc()`, `auto` or a unitless `12`, gives null and is
/// ignored, never thrown. So does a negative length: every prop a2ui_kit
/// reads this way (sizes, padding, gaps, a Divider's spacing) is one CSS
/// refuses a negative value for.
@immutable
sealed class A2uiLength {
  const A2uiLength();

  /// [value] in pixels.
  const factory A2uiLength.px(double value) = A2uiPx;

  /// [fraction] of the containing box (0.5 is `50%`).
  const factory A2uiLength.percent(double fraction) = A2uiPercent;

  /// [value] times the font size (`2em`).
  const factory A2uiLength.em(double value) = A2uiEm;

  /// Zero pixels.
  static const A2uiLength zero = A2uiPx(0);

  /// A layout length: a number is [step] pixels per unit (4px steps), a
  /// string is CSS. Null for anything else.
  static A2uiLength? steps(Object? value, {double step = 4}) => switch (value) {
    final num n when n.isFinite && n >= 0 => A2uiPx(n * step),
    final String s => parse(s),
    _ => null,
  };

  /// A pixel length: a number is pixels, a string is CSS. Null for anything
  /// else.
  static A2uiLength? pixels(Object? value) => switch (value) {
    final num n when n.isFinite && n >= 0 => A2uiPx(n.toDouble()),
    final String s => parse(s),
    _ => null,
  };

  /// The CSS length [css] (`12px`, `1rem`, `2em`, `50%` or `0`), or null
  /// when a2ui_kit cannot lay it out: other units, a unitless number other
  /// than 0 (CSS refuses one), or a negative length.
  ///
  /// A `rem` is 16px, the browser's root font size.
  static A2uiLength? parse(String css) {
    final match = _lengthPattern.firstMatch(css.trim().toLowerCase());
    if (match == null) return null;
    final number = double.tryParse(match[1]!);
    if (number == null || !number.isFinite || number < 0) return null;
    return switch (match[2]) {
      'px' => A2uiPx(number),
      '' => number == 0 ? A2uiLength.zero : null,
      'rem' => A2uiPx(number * 16),
      'em' => A2uiEm(number),
      '%' => A2uiPercent(number / 100),
      _ => null,
    };
  }

  /// The pixels of this length: a percentage of [percentBase], or null when
  /// that is null or infinite; an em of [fontSize].
  double? resolve({double? percentBase, double fontSize = 16});
}

final RegExp _lengthPattern = RegExp(
  r'^([+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?)(px|rem|em|%|)$',
);

/// A length in pixels.
final class A2uiPx extends A2uiLength {
  /// [value] pixels.
  const A2uiPx(this.value);

  /// The pixels.
  final double value;

  @override
  double resolve({double? percentBase, double fontSize = 16}) => value;

  @override
  bool operator ==(Object other) => other is A2uiPx && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '${value}px';
}

/// A percentage of the containing box.
final class A2uiPercent extends A2uiLength {
  /// [fraction] of the containing box.
  const A2uiPercent(this.fraction);

  /// The fraction, 0.5 for `50%`.
  final double fraction;

  @override
  double? resolve({double? percentBase, double fontSize = 16}) =>
      percentBase == null || !percentBase.isFinite
      ? null
      : percentBase * fraction;

  @override
  bool operator ==(Object other) =>
      other is A2uiPercent && other.fraction == fraction;

  @override
  int get hashCode => fraction.hashCode;

  @override
  String toString() => '${fraction * 100}%';
}

/// A multiple of the font size.
final class A2uiEm extends A2uiLength {
  /// [value] em.
  const A2uiEm(this.value);

  /// The multiple of the font size.
  final double value;

  @override
  double resolve({double? percentBase, double fontSize = 16}) =>
      value * fontSize;

  @override
  bool operator ==(Object other) => other is A2uiEm && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '${value}em';
}

/// The insets of a CSS `padding` value: a number of 4px steps for all four
/// sides, or CSS with one to four lengths (`8px 16px`). Percentages and
/// unreadable values give null.
EdgeInsets? cssInsets(Object? value, {double step = 4, double fontSize = 16}) {
  if (value is num) {
    // A negative padding is refused by CSS, as is a non-finite one.
    final px = value.isFinite && value > 0 ? value * step : 0.0;
    return EdgeInsets.all(px);
  }
  if (value is! String) return null;
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.length > 4) return null;
  final sides = <double>[];
  for (final part in parts) {
    final length = A2uiLength.parse(part);
    if (length == null || length is A2uiPercent) return null;
    sides.add(length.resolve(fontSize: fontSize)!);
  }
  final top = sides[0];
  final right = sides.length > 1 ? sides[1] : top;
  final bottom = sides.length > 2 ? sides[2] : top;
  final left = sides.length > 3 ? sides[3] : right;
  return EdgeInsets.fromLTRB(left, top, right, bottom);
}

/// The corners of a CSS `border-radius` value (`3px 4px`, `8px / 4px`), or
/// null when it is no radius a2ui_kit can draw.
///
/// CSS Backgrounds 3, section 5.1: one to four horizontal radii in the
/// order top left, top right, bottom right, bottom left (bottom left
/// omitted is the top right, bottom right omitted the top left, top right
/// omitted the top left), then optionally `/` and one to four vertical radii
/// in the same order; with no `/` each corner's vertical radius is its
/// horizontal one. A negative or unreadable length makes the whole value
/// invalid, as it makes the declaration invalid in CSS.
// TODO(port): a percentage radius is a share of the box's width and height
// (CSS Backgrounds 3, section 5.1); it needs the laid-out box, so it gives
// null here, as a single percentage already did.
BorderRadius? cssBorderRadius(String value, {double fontSize = 16}) {
  final halves = value.trim().split('/');
  if (halves.isEmpty || halves.length > 2) return null;
  List<double>? corners(String half) {
    final parts = half.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.length > 4) return null;
    final radii = <double>[];
    for (final part in parts) {
      final length = A2uiLength.parse(part);
      if (length == null || length is A2uiPercent) return null;
      radii.add(length.resolve(fontSize: fontSize)!);
    }
    final topLeft = radii[0];
    final topRight = radii.length > 1 ? radii[1] : topLeft;
    final bottomRight = radii.length > 2 ? radii[2] : topLeft;
    final bottomLeft = radii.length > 3 ? radii[3] : topRight;
    return [topLeft, topRight, bottomRight, bottomLeft];
  }

  final horizontal = corners(halves.first);
  if (horizontal == null) return null;
  final vertical = halves.length == 2 ? corners(halves.last) : horizontal;
  if (vertical == null) return null;
  Radius corner(int i) => horizontal[i] == vertical[i]
      ? Radius.circular(horizontal[i])
      : Radius.elliptical(horizontal[i], vertical[i]);
  return BorderRadius.only(
    topLeft: corner(0),
    topRight: corner(1),
    bottomRight: corner(2),
    bottomLeft: corner(3),
  );
}

/// The radius of one corner's CSS `border-*-radius` longhand: one length,
/// or a horizontal then a vertical one (CSS Backgrounds 3, section 5.1);
/// null when it is no radius a2ui_kit can draw.
Radius? cssCornerRadius(String value, {double fontSize = 16}) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.length > 2) return null;
  final radii = <double>[];
  for (final part in parts) {
    final length = A2uiLength.parse(part);
    if (length == null || length is A2uiPercent) return null;
    radii.add(length.resolve(fontSize: fontSize)!);
  }
  return radii.length == 1 || radii[0] == radii[1]
      ? Radius.circular(radii[0])
      : Radius.elliptical(radii[0], radii[1]);
}

/// The ratio of a CSS `aspect-ratio` value (`16 / 9`, `1.5`), or null.
double? cssAspectRatio(Object? value) {
  if (value is num) {
    return value > 0 && value.isFinite ? value.toDouble() : null;
  }
  if (value is! String) return null;
  final parts = value.split('/');
  if (parts.isEmpty || parts.length > 2) return null;
  final width = double.tryParse(parts[0].trim());
  final height = parts.length == 2 ? double.tryParse(parts[1].trim()) : 1.0;
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }
  return width / height;
}

// PORT STATUS: confidence=high todos=1 upstream=none
