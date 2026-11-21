// The page's URL on the web: the browser's `location.href`, which
// CopilotKit's openUrl resolves a URL against (packages/core/src/
// generative-ui/functions.ts:390-401, `pageBase`: `host.location?.href`).

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// The browser's `location.href`, or null when the global has no location
/// (a worker without one).
String? browserPageHref() {
  try {
    final location = globalContext.getProperty<JSObject>('location'.toJS);
    return location.getProperty<JSString>('href'.toJS).toDart;
  } on Object {
    return null;
  }
}

// PORT STATUS: confidence=high todos=0 upstream=packages/core/src/generative-ui/functions.ts
