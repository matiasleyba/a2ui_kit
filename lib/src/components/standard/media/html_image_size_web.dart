import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/painting.dart';

/// The natural size of the `<img>` element behind [info]: Flutter's web
/// `WebImageInfo` keeps it in `htmlImage`. Null when [info] has none, or it
/// has not decoded.
Size? htmlImageSize(ImageInfo info) {
  try {
    // WebImageInfo is not exported; its element is read dynamically.
    final element = (info as dynamic).htmlImage as JSObject;
    double read(String name) =>
        element.getProperty<JSNumber>(name.toJS).toDartDouble;
    final width = read('naturalWidth');
    final height = read('naturalHeight');
    if (width <= 0 || height <= 0) return null;
    return Size(width, height);
  } on Object {
    return null;
  }
}

// PORT STATUS: confidence=high todos=0 upstream=none
