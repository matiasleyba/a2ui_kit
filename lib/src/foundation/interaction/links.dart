import 'package:a2ui_kit/src/catalog_options.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

final RegExp _safeUrl = RegExp('^(https?:|mailto:)', caseSensitive: false);

/// Enter activates a focused link or button, whatever the app's shortcuts.
const Map<ShortcutActivator, Intent> activateShortcuts = {
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
};

/// The trimmed [url] when it is an http, https or mailto URL, else null:
/// CopilotKit's `safeHref`.
String? safeHref(String? url) {
  if (url == null) return null;
  final trimmed = url.trim();
  return _safeUrl.hasMatch(trimmed) ? trimmed : null;
}

/// Opens [href] if it is safe, through the catalog's [A2uiOpenUrl] or else
/// `url_launcher` (a new tab on the web).
Future<void> openSafeUrl(BuildContext context, String href) async {
  final safe = safeHref(href);
  if (safe == null) return;
  final uri = Uri.tryParse(safe);
  if (uri == null) return;
  final onOpenUrl = A2uiKitScope.maybeOf(context)?.options.onOpenUrl;
  if (onOpenUrl != null) {
    await onOpenUrl(uri);
    return;
  }
  await launchDefault(uri);
}

/// Opens [uri] with `url_launcher`: in a new tab on the web, in the
/// browser or mail app elsewhere.
Future<void> launchDefault(Uri uri) async {
  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}

/// Opens [href] as written, as [launchDefault] opens a `Uri`: a URL that a
/// Dart `Uri` would write otherwise (a backslash in its query) reaches the
/// platform unchanged, as CopilotKit's `window.open(href)` gets it.
Future<void> launchDefaultHref(String href) async {
  await launchUrlString(
    href,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}

// PORT STATUS: confidence=high todos=0 upstream=packages/shared/src/generative-ui/standard/url.ts
