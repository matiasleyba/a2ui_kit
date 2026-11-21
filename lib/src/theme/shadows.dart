import 'package:flutter/painting.dart';

/// The Flutter shadow of the CSS `box-shadow` [x]px [y]px [blur]px [color].
///
/// CSS blurs with a Gaussian of sigma blur / 2; Flutter turns a blur radius
/// r into sigma r × 0.57735 + 0.5, so the radius is chosen to give the same
/// sigma.
BoxShadow cssShadow(double x, double y, double blur, Color color) {
  final sigma = blur / 2;
  final radius = sigma <= 0.5 ? 0.0 : (sigma - 0.5) / 0.57735;
  return BoxShadow(color: color, offset: Offset(x, y), blurRadius: radius);
}

// PORT STATUS: confidence=high todos=0 upstream=none
