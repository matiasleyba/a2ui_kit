import 'dart:async';

import 'package:alchemist/alchemist.dart';

/// Golden tests run as alchemist's CI goldens only: text is drawn as blocks
/// and shadows are off, so the images are the same on every machine.
Future<void> testExecutable(FutureOr<void> Function() testMain) =>
    AlchemistConfig.runWithConfig(
      config: const AlchemistConfig(
        platformGoldensConfig: PlatformGoldensConfig(enabled: false),
      ),
      run: () async {
        await testMain();
      },
    );
