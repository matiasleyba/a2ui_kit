// The kit's platform seam (lib/src/foundation/platform.dart, RC3-14): the
// web override is read in a debug build, as Flutter's own
// `debugDefaultTargetPlatformOverride` is. flutter_test runs in debug, so
// the release guard itself is out of a test's reach.

import 'package:a2ui_kit/src/foundation/platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugKitIsWebOverride = null);

  test('kitIsWeb is kIsWeb until a debug test overrides it', () {
    expect(kDebugMode, isTrue);
    expect(debugKitIsWebOverride, isNull);
    expect(kitIsWeb, kIsWeb);
    debugKitIsWebOverride = !kIsWeb;
    expect(debugKitIsWebOverride, !kIsWeb);
    expect(kitIsWeb, !kIsWeb);
    debugKitIsWebOverride = kIsWeb;
    expect(kitIsWeb, kIsWeb);
    debugKitIsWebOverride = null;
    expect(kitIsWeb, kIsWeb);
  });
}
