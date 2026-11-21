// Parity tests of CopilotKit's calc and series, ported from
// packages/core/src/generative-ui/__tests__/calc.test.ts (MIT, (c) Atai
// Barkai). Each test names its upstream line; every upstream assertion is
// here with its own expectation (`toBeCloseTo(x, d)` is `_closeTo(x, d)`:
// a difference under 0.5 * 10^-d, strictly, vitest's bound).
//
// Parity for: Text, (functions)
//
// Not ported (bound to internals): none. Every test of calc.test.ts is
// ported.
//
// The group "beyond calc.test.ts" at the end holds our own vectors for
// the same functions (JavaScript's `%`, `Math.round` and `Math.log10`,
// RULEBOOK section 2), which upstream does not assert.

import 'dart:convert';
import 'dart:math' as math;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/src/functions/calc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart' show agentWrite, renderStandard;

/// vitest's `toThrow(text)` (the message contains [message]) or
/// `toThrow(/re/)`, for an [A2uiExpressionError], CopilotKit's
/// `ExpressionError`.
Matcher _throwsCalc(Object message) => throwsA(
  isA<A2uiExpressionError>().having(
    (e) => e.message,
    'message',
    message is RegExp ? matches(message) : contains(message as String),
  ),
);

/// vitest's `toBeCloseTo(expected, digits)`: `|expected - actual|` under
/// 10^-digits / 2, strictly (`closeTo` would accept the bound itself).
Matcher _closeTo(num expected, int digits) => predicate<num>(
  (actual) => (expected - actual).abs() < math.pow(10, -digits) / 2,
  'within ${math.pow(10, -digits) / 2} of $expected (exclusive)',
);

void main() {
  group('calc', () {
    // calc.test.ts:6
    test('follows operator precedence and parentheses', () {
      expect(evaluateCalc('1 + 2 * 3', {}), 7);
      expect(evaluateCalc('(1 + 2) * 3', {}), 9);
      expect(evaluateCalc('10 - 4 - 3', {}), 3);
      expect(evaluateCalc('2 * 3 % 4', {}), 2);
      expect(evaluateCalc('-seats * 2', {'seats': 3}), -6);
    });

    // calc.test.ts:14
    test('reads the args by name and coerces numeric text', () {
      expect(calc({'expression': 'seats * 29', 'seats': 10}), 290);
      expect(calc({'expression': 'seats * 29', 'seats': '10'}), 290);
      expect(calc({'expression': 'a + b', 'a': true, 'b': 1}), 2);
    });

    // calc.test.ts:20
    test('compares, combines booleans and picks with ?:', () {
      expect(
        evaluateCalc('seats > 5 && annual', {'seats': 10, 'annual': true}),
        true,
      );
      expect(evaluateCalc('seats >= 10 || false', {'seats': 9}), false);
      expect(evaluateCalc("plan == 'team'", {'plan': 'team'}), true);
      expect(evaluateCalc("plan != 'team'", {'plan': 'team'}), false);
      expect(evaluateCalc("seats == '10'", {'seats': 10}), true);
      expect(evaluateCalc('!annual', {'annual': false}), true);
      expect(
        evaluateCalc('seats * 29 * (annual ? 0.8 : 1)', {
          'seats': 10,
          'annual': true,
        }),
        _closeTo(232, 2),
      );
      expect(
        evaluateCalc("a > b ? 'a' : b > 3 ? 'b' : 'c'", {'a': 1, 'b': 5}),
        'b',
      );
    });

    // calc.test.ts:40
    test('does not evaluate the branch it does not take, so a condition can '
        'guard a value', () {
      expect(evaluateCalc('n == 0 ? 0 : 10 / n', {'n': 0}), 0);
      expect(evaluateCalc('n == 0 ? 0 : 10 / n', {'n': 5}), 2);
      expect(evaluateCalc('n != 0 && 10 / n > 2', {'n': 0}), false);
      expect(evaluateCalc('n == 0 || 10 / n > 2', {'n': 0}), true);
      expect(evaluateCalc('has ? missing : 1', {'has': false}), 1);
      // A syntax error is still an error, taken or not.
      expect(
        () => evaluateCalc('n == 0 ? 0 : (10 / n', {'n': 0}),
        _throwsCalc('expected ")"'),
      );
    });

    // calc.test.ts:52
    test('has min, max, round, floor, ceil and abs', () {
      expect(evaluateCalc('min(seats, 50) + max(1, 2, 3)', {'seats': 80}), 53);
      expect(evaluateCalc('round(2.345, 2)', {}), 2.35);
      expect(evaluateCalc('round(2.5)', {}), 3);
      expect(evaluateCalc('floor(2.9) + ceil(2.1) + abs(-1)', {}), 6);
    });

    // calc.test.ts:61
    test('concatenates text with +', () {
      expect(evaluateCalc("'M' + m", {'m': 3}), 'M3');
      expect(evaluateCalc("name + ' x' + 2", {'name': 'Ada'}), 'Ada x2');
    });

    // calc.test.ts:66
    test('refuses what the language does not have', () {
      expect(
        () => evaluateCalc('seats * 29', {}),
        _throwsCalc('unknown name seats'),
      );
      // Object.prototype keys are not constants.
      for (final name in ['constructor', '__proto__', 'toString']) {
        expect(() => evaluateCalc(name, {}), _throwsCalc('unknown name $name'));
      }
      expect(() => evaluateCalc('1 / 0', {}), _throwsCalc('division by zero'));
      expect(
        () => evaluateCalc('sin(4)', {}),
        _throwsCalc('unknown function sin'),
      );
      expect(
        () => evaluateCalc('a.b', {'a': <String, Object?>{}}),
        throwsA(isA<A2uiExpressionError>()),
      );
      expect(
        () => evaluateCalc('x = 1', {'x': 1}),
        throwsA(isA<A2uiExpressionError>()),
      );
      expect(
        () => evaluateCalc('list * 2', {
          'list': [1],
        }),
        _throwsCalc('not a number, text or boolean'),
      );
      expect(() => evaluateCalc("'abc' * 2", {}), _throwsCalc('not a number'));
      expect(() => evaluateCalc('(1 + 2', {}), _throwsCalc('expected ")"'));
      expect(
        () => evaluateCalc('', {}),
        _throwsCalc('expression must be a string'),
      );
      expect(() => calc({}), _throwsCalc('expression must be a string'));
    });
  });

  group('calc powers, roots, logs and constants', () {
    // calc.test.ts:87
    test('computes a monthly loan payment with ^ and pow', () {
      final scope = {'loan': 250000, 'rate': 6.5, 'years': 30};
      final payment =
          evaluateCalc(
                'loan * (rate / 1200) / (1 - (1 + rate / 1200) ^ -(years * 12))',
                scope,
              )!
              as double;
      expect(payment, _closeTo(1580.17, 2));
      expect(
        evaluateCalc(
          'loan * (rate / 1200) / (1 - pow(1 + rate / 1200, -(years * 12)))',
          scope,
        ),
        _closeTo(payment, 10),
      );
    });

    // calc.test.ts:102
    test('binds ^ tighter than * and unary minus, right to left', () {
      expect(evaluateCalc('2 * 3 ^ 2', {}), 18);
      expect(evaluateCalc('-2 ^ 2', {}), -4);
      expect(evaluateCalc('2 ^ 3 ^ 2', {}), 512);
    });

    // calc.test.ts:108
    test('has sqrt, exp, ln, log10, pi and e, and lets an arg shadow a '
        'constant', () {
      expect(evaluateCalc('sqrt(16) + log10(1000)', {}), 7);
      expect(evaluateCalc('ln(exp(2))', {}), _closeTo(2, 12));
      expect(evaluateCalc('round(pi * 100) / 100', {}), 3.14);
      expect(evaluateCalc('e', {}), _closeTo(math.e, 12));
      expect(evaluateCalc('e * 2', {'e': 5}), 10);
    });

    // calc.test.ts:116
    test('has no ambiguous log, and rejects a wrong number of args', () {
      expect(
        () => evaluateCalc('log(1000)', {}),
        _throwsCalc(RegExp('unknown function log')),
      );
      expect(
        () => evaluateCalc('ln(8, 2)', {}),
        _throwsCalc(RegExp('ln takes 1 argument')),
      );
      expect(
        () => evaluateCalc('pow(2)', {}),
        _throwsCalc(RegExp('pow takes 2 arguments')),
      );
      expect(
        () => evaluateCalc('round(1.234, 2, 3)', {}),
        _throwsCalc(RegExp('round takes 1 or 2 arguments')),
      );
      expect(evaluateCalc('max(1, 5, 3)', {}), 5);
    });

    // calc.test.ts:126
    test('fails clearly instead of returning NaN or Infinity', () {
      expect(
        () => evaluateCalc('sqrt(-1)', {}),
        throwsA(isA<A2uiExpressionError>()),
      );
      expect(
        () => evaluateCalc('ln(0)', {}),
        _throwsCalc(RegExp('no finite result')),
      );
    });
  });

  group('series', () {
    // calc.test.ts:133
    test('builds count items with the loop variable and the other args', () {
      expect(
        series({
          'count': 3,
          'variable': 'm',
          'item': {'month': r'M${m}', 'cost': r'${m * monthly}'},
          'monthly': 290,
        }),
        [
          {'month': 'M1', 'cost': 290},
          {'month': 'M2', 'cost': 580},
          {'month': 'M3', 'cost': 870},
        ],
      );
    });

    // calc.test.ts:148
    test('defaults to i from 1, takes a start, and keeps literal parts of '
        'the item', () {
      expect(series({'count': 2, 'item': r'${i}'}), [1, 2]);
      expect(
        series({
          'count': 2,
          'start': 0,
          'item': {
            'n': r'${i}',
            'fixed': 7,
            'tags': [r'${i * 2}'],
          },
        }),
        [
          {
            'n': 0,
            'fixed': 7,
            'tags': [0],
          },
          {
            'n': 1,
            'fixed': 7,
            'tags': [2],
          },
        ],
      );
      expect(series({'count': 0, 'item': r'${i}'}), equals(<Object?>[]));
    });

    // calc.test.ts:163
    test('refuses a bad count, a bad variable, or no item', () {
      expect(
        () => series({'count': 2.5, 'item': 1}),
        _throwsCalc('whole number'),
      );
      expect(
        () => series({'count': 5000, 'item': 1}),
        _throwsCalc('at most 1000'),
      );
      expect(
        () => series({'count': 1, 'item': 1, 'variable': '1x'}),
        _throwsCalc('variable must be a name'),
      );
      expect(() => series({'count': 1}), _throwsCalc('item is required'));
    });
  });

  group('beyond calc.test.ts (ours)', () {
    test("JavaScript's % takes the sign of the dividend", () {
      expect(evaluateCalc('-7 % 3', {}), -1);
      expect(evaluateCalc('7 % -3', {}), 1);
      expect(evaluateCalc('-7 % -3', {}), -1);
      expect(evaluateCalc('-7.5 % 2', {}), -1.5);
    });

    test('round rounds halves up, towards positive infinity', () {
      expect(evaluateCalc('round(-2.5)', {}), -2);
    });

    test('text + a fraction writes it as JavaScript does', () {
      expect(evaluateCalc("'v' + 0.5", {}), 'v0.5');
    });

    test('log10 is exact for powers of ten, as Math.log10 is', () {
      expect(evaluateCalc('floor(log10(1000))', {}), 3);
      expect(evaluateCalc('log10(0.001)', {}), -3);
      expect(evaluateCalc('log10(1e15)', {}), 15);
      expect(evaluateCalc('log10(2)', {}), closeTo(0.30103, 1e-5));
    });

    test('gives whole numbers as ints, so JSON writes 0, not 0.0', () {
      expect(
        jsonEncode(
          series({
            'count': 2,
            'start': 0,
            'item': {'n': r'${i}', 'half': r'${i / 2}'},
          }),
        ),
        '[{"n":0,"half":0},{"n":1,"half":0.5}]',
      );
      expect(jsonEncode(calc({'expression': '1 + 2'})), '3');
      expect(jsonEncode(calc({'expression': '-0'})), '0');
    });

    test('writes whole numbers without a decimal point', () {
      expect(jsNumberString(3), '3');
      expect(jsNumberString(3.0), '3');
      expect(jsNumberString(.5), '0.5');
      expect(jsNumberString(-0.25), '-0.25');
    });

    test('reads text as Number() does', () {
      expect(jsNumberOf(' 12 '), 12);
      expect(jsNumberOf('0x10'), 16);
      expect(jsNumberOf('1e3'), 1000);
      expect(jsNumberOf('12px').isNaN, isTrue);
    });

    testWidgets('a Text bound to calc updates with the data', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Text',
            'text': {
              '@call': 'calc',
              'args': {
                'expression': "'Total: ' + seats * 29",
                'seats': {'@path': '/seats'},
              },
            },
          },
        ],
        data: {'seats': 10},
      );
      await tester.pump();
      expect(view.errors, isEmpty);
      expect(find.text('Total: 290', findRichText: true), findsOneWidget);
      await view.update([agentWrite('/seats', 2)]);
      expect(find.text('Total: 58', findRichText: true), findsOneWidget);
    });
  });
}
