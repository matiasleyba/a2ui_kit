// SVG path data (`d`) read through path_parsing: the one parser of the
// Icon's `{svgPath}` and Lucide paths and the Svg component's `paths`
// (RULEBOOK section 1, "SVG path data").

import 'package:flutter/painting.dart';
import 'package:path_parsing/path_parsing.dart';

/// The path that the SVG path data [data] draws.
///
/// Path data with an error draws up to the command that holds the first
/// error, as SVG 2 says a user agent renders it (SVG 2, section 9.5.4,
/// "Error handling in path data"): path_parsing emits each segment once it
/// has read it whole, and stops at the first error, so what it emitted is
/// that prefix. Empty or missing data draws nothing.
Path svgPathOf(String? data) {
  final proxy = _PathProxy();
  try {
    writeSvgPathDataToPath(data, proxy);
    // ignore: avoid_catching_errors (path_parsing reports bad data so)
  } on StateError {
    // path_parsing reports every error in the data as a StateError
    // (path_parsing.dart:222-407); the segments before it stay.
  }
  return proxy.path;
}

class _PathProxy extends PathProxy {
  final Path path = Path();

  @override
  void close() => path.close();

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}

// PORT STATUS: confidence=high todos=0 upstream=none
