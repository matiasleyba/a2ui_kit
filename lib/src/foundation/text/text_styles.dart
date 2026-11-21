import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:flutter/painting.dart';

/// The weight of a `fontWeight` prop: normal 400, medium 500, semibold 600,
/// bold 700.
FontWeight fontWeightOf(A2uiFontWeight weight) => switch (weight) {
  A2uiFontWeight.normal => FontWeight.w400,
  A2uiFontWeight.medium => FontWeight.w500,
  A2uiFontWeight.semibold => FontWeight.w600,
  A2uiFontWeight.bold => FontWeight.w700,
};

/// CSS `font-weight: bolder` over [parent]: 400 below 350, 700 below 550,
/// else 900.
FontWeight bolder(FontWeight parent) {
  final value = parent.value;
  if (value < 350) return FontWeight.w400;
  if (value < 550) return FontWeight.w700;
  return FontWeight.w900;
}

/// CopilotKit's text scale (`TEXT_SCALE`): the size in em and the line
/// height of each text size.
(double, double) textScale(A2uiTextSize size) => switch (size) {
  A2uiTextSize.threeXs => (.625, 1.2),
  A2uiTextSize.twoXs => (.6875, 1.273),
  A2uiTextSize.xs => (.75, 1.333),
  A2uiTextSize.sm => (.875, 1.429),
  A2uiTextSize.md => (1, 1.625),
  A2uiTextSize.lg => (1.125, 1.556),
};

/// The line height, as a multiple of [fontSize], of a CSS `line-height`
/// value: a unitless ratio (a number or a numeric string), a length or a
/// percentage. Null for `normal` and anything unreadable.
double? lineHeightOf(Object? value, double fontSize) {
  if (value is num) {
    return value > 0 && value.isFinite ? value.toDouble() : null;
  }
  if (value is! String) return null;
  final css = value.trim();
  final ratio = double.tryParse(css);
  if (ratio != null) return ratio > 0 ? ratio : null;
  final length = A2uiLength.parse(css);
  if (length == null || fontSize <= 0) return null;
  final pixels = length.resolve(percentBase: fontSize, fontSize: fontSize);
  return pixels == null || pixels <= 0 ? null : pixels / fontSize;
}

/// The [TextAlign] of a `textAlign` prop.
TextAlign textAlignOf(A2uiTextAlign align) => switch (align) {
  A2uiTextAlign.start => TextAlign.start,
  A2uiTextAlign.center => TextAlign.center,
  A2uiTextAlign.end => TextAlign.end,
};

// PORT STATUS: confidence=high todos=0 upstream=packages/shared/src/generative-ui/standard/tokens.ts
