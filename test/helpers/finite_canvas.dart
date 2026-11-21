// RULEBOOK section 6 item 3 (RR2-1): a chart scene painted into
// flutter_test's `TestRecordingCanvas`, with no focus and with each focus
// its keys reach (points that are not drawn included), and every Canvas
// call that got a number that is not finite. A scene's anchor and tooltip
// place may be NaN where the library's are; the laid-out tooltip box is
// checked at widget level.
//
// A `Path` is checked by its `getBounds()`, which is a weak check: the
// engine may report an empty box for a path holding a NaN point. The
// scenes build their paths through `tanstackSvgPath`, which leaves such
// points out before the path is made; the tests check the paths' marks
// besides.

import 'dart:typed_data';

import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// What in [argument] is not finite, or null when all of it is.
String? _nonFinite(Object? argument) {
  switch (argument) {
    case final double value when !value.isFinite:
      return 'double $value';
    case final Offset offset when !offset.isFinite:
      return 'Offset $offset';
    case final Size size when !size.isFinite:
      return 'Size $size';
    case final Rect rect when !rect.isFinite:
      return 'Rect $rect';
    case final RRect rrect
        when !rrect.isFinite ||
            !rrect.tlRadiusX.isFinite ||
            !rrect.tlRadiusY.isFinite ||
            !rrect.trRadiusX.isFinite ||
            !rrect.trRadiusY.isFinite ||
            !rrect.brRadiusX.isFinite ||
            !rrect.brRadiusY.isFinite ||
            !rrect.blRadiusX.isFinite ||
            !rrect.blRadiusY.isFinite:
      return 'RRect $rrect';
    case final Path path when !path.getBounds().isFinite:
      return 'Path bounds ${path.getBounds()}';
    case final Paint paint when !paint.strokeWidth.isFinite:
      return 'Paint strokeWidth ${paint.strokeWidth}';
    case final List<Offset> offsets:
      for (final offset in offsets) {
        if (!offset.isFinite) return 'points with $offset';
      }
    case final Float64List matrix:
      for (final value in matrix) {
        if (!value.isFinite) return 'matrix $matrix';
      }
  }
  return null;
}

/// Paints [scene] with [focus] into a [TestRecordingCanvas] and describes
/// every call that got a number that is not finite (a double, an
/// [Offset], a [Rect], an [RRect], a [Size], a [Path]'s box, a [Paint]'s
/// stroke width, a list of points, a matrix; a paragraph's offset among
/// them). Empty when there is none.
List<String> nonFiniteCalls(PlotScene scene, {PlotFocus? focus}) {
  final canvas = TestRecordingCanvas();
  scene.paint(canvas, focus);
  return [
    for (final call in canvas.invocations)
      for (final argument in [
        ...call.invocation.positionalArguments,
        ...call.invocation.namedArguments.values,
      ])
        if (_nonFinite(argument) case final problem?)
          '${_symbolName(call.invocation.memberName)} got $problem',
  ];
}

/// The calls [scene] makes on a [TestRecordingCanvas] when painted with
/// [focus], by name (`drawCircle`, `drawPath`, …).
List<String> paintCalls(PlotScene scene, {PlotFocus? focus}) {
  final canvas = TestRecordingCanvas();
  scene.paint(canvas, focus);
  return [
    for (final call in canvas.invocations)
      _symbolName(call.invocation.memberName),
  ];
}

String _symbolName(Symbol symbol) {
  // `Symbol("drawCircle")`.
  final text = symbol.toString();
  return text.substring('Symbol("'.length, text.length - 2);
}

/// Every focus the keys of [scene] reach: the first, then each next one
/// until it stops (the last is kept) or comes back.
List<PlotFocus> keyboardFoci(PlotScene scene) {
  final foci = <PlotFocus>[];
  var focus = scene.navigate(null, PlotNavigation.first);
  while (focus != null && !foci.contains(focus) && foci.length < 1000) {
    foci.add(focus);
    focus = scene.navigate(focus, PlotNavigation.next);
  }
  return foci;
}

/// Every Canvas call [scene] makes with a number that is not finite, with
/// no focus and with each focus its keys reach ([keyboardFoci], points
/// that are not drawn included; [nonFiniteCalls]). Empty when there is
/// none.
List<String> nonFiniteScene(PlotScene scene) => [
  for (final problem in nonFiniteCalls(scene)) 'no focus: $problem',
  for (final focus in keyboardFoci(scene))
    for (final problem in nonFiniteCalls(scene, focus: focus))
      '$focus: $problem',
];
