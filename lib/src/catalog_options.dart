import 'dart:async';

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:flutter/foundation.dart';

/// Opens a link a surface asks for: a markdown link in a Text, or the
/// `openUrl` function. The URL is already checked to be safe.
typedef A2uiOpenUrl = FutureOr<void> Function(Uri url);

/// How an a2ui_kit catalog renders.
@immutable
class A2uiKitOptions {
  /// Options; every one has a default.
  const A2uiKitOptions({
    this.look = A2uiKitLook.playground,
    this.overrides = const {},
    this.onOpenUrl,
    this.locale = 'en-US',
  });

  /// The look a surface takes when the app's `ThemeData` has no
  /// [A2uiKitTheme] extension.
  final A2uiKitLook look;

  /// Builders that replace the catalog's own, by component name, as
  /// CopilotKit's `useOverride` does. The schema stays the catalog's.
  final Map<String, ComponentWidgetBuilder> overrides;

  /// Opens links. Null opens them with `url_launcher`: in a new tab on the
  /// web, in the browser elsewhere.
  final A2uiOpenUrl? onOpenUrl;

  /// The BCP 47 locale of the formatting functions (`formatNumber`,
  /// `formatCurrency`, `formatDate`, `pluralize`).
  final String locale;
}

// PORT STATUS: confidence=high todos=0 upstream=none
