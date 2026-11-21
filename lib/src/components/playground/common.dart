import 'package:a2ui_kit/src/foundation/format/decimal.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/functions/calc.dart';
import 'package:a2ui_kit/src/theme/playground_tokens.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The playground's tokens at [context].
A2uiPlaygroundTokens playgroundTokens(BuildContext context) =>
    A2uiKitScope.themeOf(context).playground;

/// The playground's `.a2-card`: the surface (under a faint top sheen in the
/// dark), a 1px line, its 14px radius and its shadow.
BoxDecoration playgroundCardDecoration(A2uiPlaygroundTokens tokens) {
  final sheen = Color.alphaBlend(tokens.cardSheen, tokens.surface);
  return BoxDecoration(
    color: tokens.surface,
    gradient: tokens.cardSheen.a == 0
        ? null
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [sheen, tokens.surface],
            stops: const [0, .4],
          ),
    border: Border.all(color: tokens.line),
    borderRadius: BorderRadius.circular(tokens.radius),
    boxShadow: tokens.cardShadow,
  );
}

/// A playground text style: [size] pixels (Tailwind's `text-[13px]`),
/// with an optional weight, line height (a multiple of the size) and
/// letter spacing in em (`tracking-tight` is -0.025).
TextStyle playgroundText(
  double size, {
  Color? color,
  FontWeight? weight,
  double? height,
  double? trackingEm,
  bool tabular = false,
}) => TextStyle(
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height,
  letterSpacing: trackingEm == null ? null : trackingEm * size,
  fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
);

/// The playground's `.a2-label`: 12.5px, medium, muted.
TextStyle playgroundLabelStyle(A2uiPlaygroundTokens tokens) => playgroundText(
  12.5,
  weight: FontWeight.w500,
  color: tokens.mutedForeground,
);

/// The playground's `formatNumber` with the default format: en-US, digit
/// grouping, at most 2 decimals (`format.ts`), as `Intl.NumberFormat`
/// writes it.
///
/// ICU rounds the shortest decimal that reads back as the number, half
/// away from zero, so 1.005 is "1.01" (`toStringAsFixed` gives "1.00"); a
/// number of 1e21 or more is written out in full; a negative number that
/// rounds to zero is "-0".
String formatPlaygroundNumber(num value) {
  if (!value.isFinite) return jsNumberString(value);
  final (:whole, fraction: digits) = roundedDecimalDigits(value.abs(), 2);
  final fraction = digits.replaceFirst(RegExp(r'0+$'), '');
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }
  final sign = value.isNegative ? '-' : '';
  return '$sign$grouped${fraction.isEmpty ? '' : '.$fraction'}';
}

/// The playground's `str`: text of a string, number or bool; "" for null,
/// lists and maps.
String playgroundString(Object? value) => switch (value) {
  null => '',
  final String s => s,
  final num n => jsNumberString(n),
  final bool b => '$b',
  _ => '',
};

/// A CSS container with `container-type: inline-size` (Tailwind's
/// `@container`): its content does not size it along the inline axis, so
/// its intrinsic widths are only [inset], its padding and border.
class InlineSizeContainer extends SingleChildRenderObjectWidget {
  /// Contains [child].
  const InlineSizeContainer({
    required this.inset,
    required super.child,
    super.key,
  });

  /// The horizontal padding and border around the content.
  final double inset;

  @override
  RenderInlineSizeContainer createRenderObject(BuildContext context) =>
      RenderInlineSizeContainer(inset);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderInlineSizeContainer renderObject,
  ) => renderObject.inset = inset;
}

/// The render object of [InlineSizeContainer].
class RenderInlineSizeContainer extends RenderProxyBox {
  /// A container with [inset] around its content.
  RenderInlineSizeContainer(this._inset);

  double _inset;

  /// The horizontal padding and border around the content.
  double get inset => _inset;
  set inset(double value) {
    if (value == _inset) return;
    _inset = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _inset;

  @override
  double computeMaxIntrinsicWidth(double height) => _inset;
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/app/globals.css
