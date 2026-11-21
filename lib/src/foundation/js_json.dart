/// JavaScript's `JSON.stringify` of a JSON value (ECMA-262, 25.5.2.2):
/// the text CopilotKit shows for a value it writes out as JSON (a Table
/// cell holding an object or a list, data.tsx:114-118).
library;

import 'package:a2ui_kit/src/foundation/js_object_keys.dart';
import 'package:a2ui_kit/src/functions/calc.dart' show jsNumberString;

/// [value] as JavaScript's `JSON.stringify(value)` writes it, with no
/// indentation: `null`, `true`, numbers as `String()` writes them (a
/// non-finite one as `null`), strings quoted as `QuoteJSONString` quotes
/// them (lone surrogates escaped, ECMA-262 25.5.2.3), lists, and maps
/// with their keys in `Object.keys` order ([jsObjectKeys]). A value JSON
/// cannot hold is `null`.
String jsonStringifyJs(Object? value) {
  final out = StringBuffer();
  _write(out, value);
  return out.toString();
}

void _write(StringBuffer out, Object? value) {
  switch (value) {
    case null:
      out.write('null');
    case final bool b:
      out.write('$b');
    case final num n:
      out.write(n.isFinite ? jsNumberString(n) : 'null');
    case final String s:
      _quote(out, s);
    case final List<Object?> list:
      out.write('[');
      for (var i = 0; i < list.length; i++) {
        if (i > 0) out.write(',');
        _write(out, list[i]);
      }
      out.write(']');
    case final Map<Object?, Object?> map:
      out.write('{');
      var first = true;
      for (final key in jsObjectKeys(map)) {
        if (!first) out.write(',');
        first = false;
        _quote(out, '$key');
        out.write(':');
        _write(out, map[key]);
      }
      out.write('}');
    default:
      out.write('null');
  }
}

void _quote(StringBuffer out, String text) {
  out.write('"');
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    switch (unit) {
      case 0x08:
        out.write(r'\b');
      case 0x09:
        out.write(r'\t');
      case 0x0a:
        out.write(r'\n');
      case 0x0c:
        out.write(r'\f');
      case 0x0d:
        out.write(r'\r');
      case 0x22:
        out.write(r'\"');
      case 0x5c:
        out.write(r'\\');
      default:
        final lead = unit >= 0xd800 && unit <= 0xdbff;
        final trail = unit >= 0xdc00 && unit <= 0xdfff;
        final paired =
            (lead &&
                i + 1 < text.length &&
                (text.codeUnitAt(i + 1) & 0xfc00) == 0xdc00) ||
            (trail && i > 0 && (text.codeUnitAt(i - 1) & 0xfc00) == 0xd800);
        if (unit < 0x20 || ((lead || trail) && !paired)) {
          out.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
        } else {
          out.writeCharCode(unit);
        }
    }
  }
  out.write('"');
}

// PORT STATUS: confidence=high todos=0 upstream=none
