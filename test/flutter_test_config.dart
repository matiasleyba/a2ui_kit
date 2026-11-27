import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden tests run as alchemist's CI goldens only: text is drawn as blocks
/// and shadows are off. The images are made on macOS (Apple Silicon), where
/// CI runs them too: other platforms differ a little (anti-aliased edges, and
/// text that falls back to a system font, which can change a sample's size).
/// [_TolerantComparator] accepts a few pixels of edge.
Future<void> testExecutable(FutureOr<void> Function() testMain) {
  final comparator = goldenFileComparator;
  if (comparator is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(
      comparator.basedir.resolve('golden_test.dart'),
    );
  }
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: false),
    ),
    run: () async {
      await testMain();
    },
  );
}

/// A golden comparator that passes an image whose pixels differ from the
/// golden by at most [tolerance] of the image (anti-aliasing between
/// platforms: line_chart and scatter_chart differed by 18 and 4 pixels).
/// A different size, or anything larger, still fails, with the usual
/// failure images in `failures/`.
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  /// 0.1% of the pixels.
  static const double tolerance = 0.001;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
