// Where the kit runs: in a browser or not. Some behaviour follows the
// browser's defaults, which Flutter gives on the web and the kit gives itself
// elsewhere (RULEBOOK section 2: a key the library doesn't prevent keeps the
// browser's default); a test on the VM reaches the web path through
// [debugKitIsWebOverride] (RULEBOOK section 6 item 2), read only in a debug
// build, as Flutter reads its own `debugDefaultTargetPlatformOverride`
// (flutter 3.47.9 foundation/_platform_io.dart:35, `if (kDebugMode && …)`;
// foundation/platform.dart:106-110, its setter throws outside debug). On the
// web the kit also has a page, whose URL ([kitPageHref]) a test on the VM
// gives with [debugKitPageHrefOverride].

import 'package:a2ui_kit/src/foundation/page_href.dart'
    if (dart.library.js_interop) 'package:a2ui_kit/src/foundation/page_href_web.dart';
import 'package:flutter/foundation.dart';

/// Whether the kit runs in a browser: [kIsWeb], unless a debug build's test
/// set [debugKitIsWebOverride].
bool get kitIsWeb {
  if (kDebugMode) {
    if (_debugKitIsWebOverride case final override?) return override;
  }
  return kIsWeb;
}

/// Makes [kitIsWeb] answer `true` (the web path) or `false` (the path off the
/// web) in a test on the VM; null leaves [kIsWeb]'s answer. A test that sets
/// it resets it to null in `tearDown` (or `addTearDown`), so no other test
/// sees it.
///
/// Read only in a debug build; setting it in a profile or release build
/// throws a [FlutterError].
@visibleForTesting
bool? get debugKitIsWebOverride => _debugKitIsWebOverride;

@visibleForTesting
// ignore: avoid_positional_boolean_parameters (a setter's value is positional)
set debugKitIsWebOverride(bool? value) {
  if (!kDebugMode) {
    throw FlutterError(
      'Cannot modify debugKitIsWebOverride in non-debug builds.',
    );
  }
  _debugKitIsWebOverride = value;
}

bool? _debugKitIsWebOverride;

/// The URL of the page the kit runs in, when [kitIsWeb]: the browser's
/// `location.href`, unless a debug build's test set
/// [debugKitPageHrefOverride]. Null off the web, where there is no page, and
/// on the VM's web path when the test gave none.
String? get kitPageHref {
  if (!kitIsWeb) return null;
  if (kDebugMode) {
    if (_debugKitPageHrefOverride case final override?) return override;
  }
  return browserPageHref();
}

/// The page URL [kitPageHref] gives on the web path, in a test on the VM
/// (with [debugKitIsWebOverride] `true`); null leaves the browser's. A test
/// that sets it resets it to null in `tearDown` (or `addTearDown`).
///
/// Read only in a debug build; setting it in a profile or release build
/// throws a [FlutterError].
@visibleForTesting
String? get debugKitPageHrefOverride => _debugKitPageHrefOverride;

@visibleForTesting
set debugKitPageHrefOverride(String? value) {
  if (!kDebugMode) {
    throw FlutterError(
      'Cannot modify debugKitPageHrefOverride in non-debug builds.',
    );
  }
  _debugKitPageHrefOverride = value;
}

String? _debugKitPageHrefOverride;

// PORT STATUS: confidence=high todos=0 upstream=none
