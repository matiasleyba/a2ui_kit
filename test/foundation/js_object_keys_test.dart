import 'package:a2ui_kit/src/foundation/js_object_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('jsObjectKeys (ECMA-262 OrdinaryOwnPropertyKeys)', () {
    test('array-index keys first, ascending, then insertion order', () {
      expect(
        jsObjectKeys(<String, Object?>{'region': 'N', '2024': 5, '2023': 3}),
        ['2023', '2024', 'region'],
      );
      expect(jsObjectKeys(<String, Object?>{'b': 1, '10': 1, 'a': 1, '9': 1}), [
        '9',
        '10',
        'b',
        'a',
      ]);
    });

    test('only canonical integers up to 2^32 - 2 are indexes', () {
      expect(isJsArrayIndex('0'), isTrue);
      expect(isJsArrayIndex('4294967294'), isTrue);
      expect(isJsArrayIndex('4294967295'), isFalse);
      expect(isJsArrayIndex('07'), isFalse);
      expect(isJsArrayIndex('-1'), isFalse);
      expect(isJsArrayIndex('1.0'), isFalse);
      expect(isJsArrayIndex(''), isFalse);
      expect(isJsArrayIndex('1e3'), isFalse);
      expect(
        jsObjectKeys(<String, Object?>{
          '4294967295': 1,
          '07': 1,
          '7': 1,
          '-1': 1,
        }),
        ['7', '4294967295', '07', '-1'],
      );
    });

    test('an empty map and non-string keys', () {
      expect(jsObjectKeys(<String, Object?>{}), isEmpty);
      expect(jsObjectKeys(<Object?, Object?>{2: 'a', '1': 'b'}), ['1', 2]);
    });
  });
}
