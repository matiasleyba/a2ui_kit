/// JavaScript's order of an object's own keys.
///
/// `Object.keys`, `for…in` and `Object.entries` list an object's keys in
/// the order of ECMAScript's `OrdinaryOwnPropertyKeys` (ECMA-262, 10.1.11.1):
/// first every key that is an array index, in ascending numeric order, then
/// the other string keys in the order they were created. A Dart map from
/// JSON keeps only the creation order, so a row `{"region": "N", "2024": 5,
/// "2023": 3}` lists `2023, 2024, region` in JavaScript and `region, 2024,
/// 2023` in Dart. Where CopilotKit iterates a JSON object, the port iterates
/// [jsObjectKeys] (RULEBOOK §2).
library;

/// The keys of [map] in the order JavaScript's `Object.keys` gives an
/// object's: the array-index keys ([isJsArrayIndex]) ascending, then the
/// rest in the map's own (insertion) order.
List<K> jsObjectKeys<K>(Map<K, Object?> map) {
  final indexes = <(int, K)>[];
  final rest = <K>[];
  for (final key in map.keys) {
    final index = key is String ? jsArrayIndex(key) : null;
    if (index == null) {
      rest.add(key);
    } else {
      indexes.add((index, key));
    }
  }
  indexes.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, key) in indexes) key, ...rest];
}

/// The largest array index, 2^32 − 2 (ECMA-262, 6.1.7: an array index is an
/// integer index below 2^32 − 1).
const int kJsMaxArrayIndex = 4294967294;

/// Whether [key] is an array index: the canonical decimal text of an
/// integer from 0 to 2^32 − 2 (so `"7"`, not `"07"`, `"-1"` or `"7.0"`).
bool isJsArrayIndex(String key) => jsArrayIndex(key) != null;

/// The array index [key] names, or null when it names none
/// ([isJsArrayIndex]).
int? jsArrayIndex(String key) {
  if (key.isEmpty || key.length > 10) return null;
  for (var i = 0; i < key.length; i++) {
    final unit = key.codeUnitAt(i);
    if (unit < 0x30 || unit > 0x39) return null;
  }
  // The canonical text of a number has no leading zero.
  if (key.length > 1 && key.codeUnitAt(0) == 0x30) return null;
  final value = int.parse(key);
  return value <= kJsMaxArrayIndex ? value : null;
}

// PORT STATUS: confidence=high todos=0 upstream=none
