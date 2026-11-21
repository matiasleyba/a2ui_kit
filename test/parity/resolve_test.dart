// Parity tests of CopilotKit's function values (calc, series, the
// validators, the formatters, and, or, not, formatString), ported from
// packages/core/src/generative-ui/__tests__/resolve.test.ts (MIT, (c) Atai
// Barkai). Each test names its upstream line.
//
// Parity for: Button, (functions)
//
// Upstream calls its resolver `resolveDynamicValue(value, {data,
// basePath})`. Here a2ui_core resolves (it is the engine that binds data
// for this package's catalog, so what it resolves is ours to guarantee)
// and the catalog's own functions run (`a2uiKitStandardCatalog`), through
// a `DataContext` over the same data at the same base path: a one-shot
// `resolveDynamicValue`, as upstream's `resolve` is one-shot. A value that
// must recompute is read through `resolveSignal` (:85, :270). formatString's
// `${...}` expressions are the catalog's port of CopilotKit's own grammar
// (lib/src/functions/format_string.dart), and a validator gives its boolean
// outside a check's condition (lib/src/functions/validators.dart).
//
// Not ported (bound to internals):
// - The `paths` each upstream resolve reports (:43, :49, :67, :85, :128,
//   :211, :236, :270): the resolver's dependency set, which CopilotKit's
//   renderer watches. Here the behaviour it guards, a value recomputing
//   when the data it read changes, is tested through the signal (:85,
//   :270).
// - resolve.test.ts:61 "keeps the identity of a value with nothing dynamic
//   in it": `toBe`, a JavaScript object's identity, which CopilotKit's
//   renderer compares to skip work; nothing a student sees.
// - resolve.test.ts:76 "leaves an event binding alone": a2ui_core's
//   `resolveDynamicValue` does resolve the `@path` inside an event's
//   context. The behaviour the test guards, that an event's context is
//   read when the event fires, is tested through a Button.
// - resolve.test.ts:270 `tryResolveDynamicValue`'s `ok` and `paths`: a
//   value whose function failed recomputes once the data it read arrives,
//   tested through the signal.
// - resolve.test.ts:137, its `{isChecks: true}` and `{keepValidation:
//   true}` calls, and :137 and :160, the values under a `checks` key:
//   options and a key of CopilotKit's resolver, which keeps a validation
//   result for its checks. Here the checks read their conditions
//   themselves (`firstFailedCheck`); that a check keeps the validator's
//   message and code is tested in checks_test.dart (checks.test.tsx:65,
//   :92, :157).
//
// Not ours:
// - resolve.test.ts:281 `containsDynamicValue`: a helper of CopilotKit's
//   surface manager, which this package has no counterpart of.

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/functions/validators.dart' show validationScope;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// Upstream's data (resolve.test.ts:30).
Map<String, Object?> _data() => {
  'price': 1599,
  'qty': 3,
  'name': 'Ada',
  'email': 'ada@example.com',
  'items': [
    {'label': 'A'},
    {'label': 'B'},
  ],
  'flags': {'ok': true},
};

final CatalogImplementation _catalog = a2uiKitStandardCatalog();

/// A context over [model] at [basePath]: upstream's `{data, basePath}`.
DataContext _context(DataModel model, [String basePath = '/']) => DataContext(
  model,
  _catalog.invoke,
  basePath,
  protocolVersion: A2uiProtocolVersion.v1_0,
);

/// Upstream's `resolve(value, context).value`: a one-shot resolution, which
/// throws a function's own error (a signal would wrap it in a
/// `SignalEffectException`) and reads a function's signal once
/// (formatString with expressions gives one; a2ui_core's
/// `resolveDynamicValue` reads it, data_context.dart:431-432).
Object? _resolve(Object? value, {String basePath = '/', DataModel? model}) =>
    _context(model ?? DataModel(_data()), basePath).resolveDynamicValue(value);

/// Upstream's `format(value, context).value`: a formatString call.
Object? _format(String value, {String basePath = '/'}) => _resolve({
  '@call': 'formatString',
  'args': {'value': value},
}, basePath: basePath);

/// vitest's `toThrow(text)` for an [A2uiExpressionError].
Matcher _throwsExpression(String message) => throwsA(
  isA<A2uiExpressionError>().having(
    (e) => e.message,
    'message',
    contains(message),
  ),
);

void main() {
  group('resolveDynamicValue: bindings', () {
    // resolve.test.ts:43
    test('reads a top-level binding', () {
      expect(_resolve({'@path': '/price'}), 1599);
    });

    // resolve.test.ts:49
    test('reads bindings at any depth and keeps the rest of the value', () {
      expect(
        _resolve({
          'rows': [
            {
              'label': 'Price',
              'value': {'@path': '/price'},
            },
            {'label': 'x'},
          ],
          'title': 'Specs',
        }),
        {
          'rows': [
            {'label': 'Price', 'value': 1599},
            {'label': 'x'},
          ],
          'title': 'Specs',
        },
      );
    });

    // resolve.test.ts:67
    test('resolves a relative path against the template item', () {
      expect(_resolve({'@path': 'label'}, basePath: '/items/1'), 'B');
    });

    // resolve.test.ts:76 (behaviour: see the header)
    testWidgets("reads an event binding's context when the event fires", (
      tester,
    ) async {
      final view = await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Button',
          'label': 'Pick',
          'onClick': {
            'event': {
              'name': 'pick',
              'context': {
                'p': {'@path': '/price'},
              },
            },
          },
        },
      ], data: _data());
      // The write lands with no frame between it and the tap: a context
      // resolved at the last build (or kept current by a rebuild) would
      // still send 1599; one read when the event fires sends 1299.
      view.surface.dataModel.set('/price', 1299);
      await tester.tap(find.text('Pick'));
      await tester.pump();
      expect(view.actionNames, ['pick']);
      expect(view.actions.single.context, {'p': 1299});
    });
  });

  group('resolveDynamicValue: function values', () {
    // resolve.test.ts:85
    test('resolves the documented series example to numbers and recomputes '
        'from bound data', () {
      const example = {
        '@call': 'series',
        'args': {
          'count': 6,
          'item': {'month': r'${i}', 'cost': r'${i * monthlyCost}'},
          'monthlyCost': {'@path': '/monthlyCost'},
        },
      };
      // `GENERATIVE_UI_FUNCTIONS.series.description`, as the standard
      // catalog exports it.
      final functions = _catalog.toJson()['functions']! as Map;
      final series = functions['series']! as Map;
      // JSON.stringify(example), which jsonEncode matches: no spaces, the
      // keys in order.
      expect(series['description'], contains(jsonEncode(example)));
      final model = DataModel({'monthlyCost': 75});
      final value = _context(model).resolveSignal(example);
      for (final monthlyCost in [75, 150]) {
        model.set('/monthlyCost', monthlyCost);
        expect(value.value, [
          for (var index = 0; index < 6; index++)
            {'month': index + 1, 'cost': (index + 1) * monthlyCost},
        ]);
      }
    });

    // resolve.test.ts:115, its calls inside a template item
    test('gives the @index of a template item, plus an offset', () {
      expect(_resolve({'@call': '@index'}, basePath: '/items/1'), 1);
      expect(
        _resolve({
          '@call': '@index',
          'args': {'offset': 1},
        }, basePath: '/items/1'),
        2,
      );
    });

    // resolve.test.ts:115, its call outside a template
    test(
      'gives nothing for @index outside a template',
      skip: portQueue(
        'port-queue: (surface): engine: a2ui_core 0.8.0 evaluates @index '
        'before any catalog (data_context.dart:844-848; a catalog cannot '
        'define an @ name) and throws outside a template (:780-786, "@index '
        'function can only be evaluated inside a collection template '
        'iteration scope."), not undefined',
      ),
      () {
        expect(_resolve({'@call': '@index'}), isNull);
      },
    );

    // resolve.test.ts:270 (behaviour: see the header)
    test('recomputes a value whose function failed once the data it read '
        'arrives', () {
      final model = DataModel({'empty': ''});
      final value = _context(model).resolveSignal({
        '@call': 'formatNumber',
        'args': {
          'value': {'@path': '/empty'},
        },
      });
      expect(() => value.value, throwsA(anything));
      model.set('/empty', 1234);
      // ECMA-402 `Intl.NumberFormat("en-US")` with its defaults (§15.1.1
      // SetNumberFormatDigitOptions: maximumFractionDigits 3; useGrouping):
      // CLDR's en decimal pattern "#,##0.###", so "1,234".
      expect(value.value, '1,234');
    });

    // resolve.test.ts:128
    test('formats a bound number as currency and reports the path', () {
      expect(
        _resolve({
          '@call': 'formatCurrency',
          'args': {
            'value': {'@path': '/price'},
            'currency': 'USD',
          },
        }),
        r'$1,599.00',
      );
    });

    // resolve.test.ts:137
    test(
      'coerces a validator result to a boolean in a prop, and keeps it under '
      'a check condition',
      () {
        const check = {
          '@call': 'email',
          'args': {
            'value': {'@path': '/email'},
          },
        };
        expect(_resolve(check), true);
        // A key named condition outside of checks is an ordinary value.
        expect(_resolve({'condition': check}), {'condition': true});
      },
    );

    // resolve.test.ts:160
    test('keeps a validator result only as the condition of a check', () {
      const required = {
        '@call': 'required',
        'args': {'value': ''},
      };
      // An arg that happens to be named condition is a plain boolean.
      expect(
        _resolve({
          '@call': 'calc',
          'args': {'expression': 'condition ? 1 : 0', 'condition': required},
        }),
        0,
      );
      expect(
        _resolve({
          'other': {'condition': required},
        }),
        {
          'other': {'condition': false},
        },
      );
    });

    // resolve.test.ts:179
    test('combines validators with and, or and not', () {
      const required = {
        '@call': 'required',
        'args': {
          'value': {'@path': '/name'},
        },
      };
      const email = {
        '@call': 'email',
        'args': {'value': 'nope'},
      };
      expect(
        _resolve({
          '@call': 'and',
          'args': {
            'values': [required, email],
          },
        }),
        false,
      );
      expect(
        _resolve({
          '@call': 'or',
          'args': {
            'values': [required, email],
          },
        }),
        true,
      );
      expect(
        _resolve({
          '@call': 'not',
          'args': {'value': email},
        }),
        true,
      );
    });

    // resolve.test.ts:196, its formatter call
    test('throws an ExpressionError for bad args', () {
      expect(
        () => _context(DataModel(_data())).resolveDynamicValue({
          '@call': 'formatNumber',
          'args': {'value': 'x'},
        }),
        _throwsExpression('value must be a number'),
      );
    });

    // resolve.test.ts:196, its first call
    test(
      'throws an ExpressionError for an unknown function',
      skip: portQueue(
        "port-queue: (surface): engine: a2ui_core 0.8.0's catalog invoke "
        'throws an A2uiCatalogResolutionError ("Function not found: '
        'formatPrice", data_context.dart:2073-2080) for a name the catalog '
        'lacks, before anything of ours runs, not an expression error',
      ),
      () {
        expect(
          () => _resolve({'@call': 'formatPrice'}),
          throwsA(isA<A2uiExpressionError>()),
        );
      },
    );

    // resolve.test.ts:196, its last call
    test(
      'throws an ExpressionError for openUrl outside a gesture',
      skip: portQueue(
        'port-queue: (surface): engine: a2ui_core 0.8.0 refuses openUrl in '
        'a value before its body runs (data_context.dart:2088-2093, '
        '"Function \'openUrl\' requires user activation context to '
        'execute."), not "… is not a value"; dropping the flag would also '
        "drop the engine's other user-activation checks (processor.dart:987, "
        ':1980)',
      ),
      () {
        expect(
          () => _resolve({
            '@call': 'openUrl',
            'args': {'url': 'https://x'},
          }),
          _throwsExpression('is not a value'),
        );
      },
    );
  });

  group('resolveDynamicValue: formatString', () {
    // resolve.test.ts:211
    test('interpolates absolute and relative paths and literals', () {
      expect(_format(r'Hi ${/name}, ${/qty} items'), 'Hi Ada, 3 items');
      expect(_format(r'${label}!', basePath: '/items/0'), 'A!');
      expect(
        _format(r'''${'a'} ${"b"} ${1.5} ${true} ${null}|'''),
        'a b 1.5 true |',
      );
    });

    // resolve.test.ts:222
    test('calls functions with named args, nested', () {
      expect(
        _format(r"${/qty} × ${formatCurrency(value: /price, currency: 'EUR')}"),
        '3 × €1,599.00',
      );
      expect(
        _format(r"${pluralize(value: /qty, one: 'item', other: 'items')}"),
        'items',
      );
      expect(
        _format(r'${formatNumber(value: 1234.5, decimals: 1)}'),
        '1,234.5',
      );
      expect(_format(r'${@index}', basePath: '/items/1'), '1');
    });

    // resolve.test.ts:236
    test('computes with calc inside formatString and resolves series to a '
        'list', () {
      expect(
        _format(
          r"${formatCurrency(value: calc(expression: 'qty * price * 0.8', "
          "qty: /qty, price: /price), currency: 'EUR')}",
        ),
        '€3,837.60',
      );
      expect(
        _resolve({
          '@call': 'series',
          'args': {
            'count': 2,
            'variable': 'm',
            'item': {'month': r'${m}', 'total': r'${m * price}'},
            'price': {'@path': '/price'},
          },
        }),
        [
          {'month': 1, 'total': 1599},
          {'month': 2, 'total': 3198},
        ],
      );
    });

    // resolve.test.ts:258
    test(r'keeps an escaped \${ literal and reports a bad expression', () {
      expect(_format(r'cost: \${/price}'), r'cost: ${/price}');
      expect(_format(r'''${'it\'s'} ${"a }"}'''), "it's a }");
      expect(() => _format(r'${/price'), _throwsExpression(r'unclosed ${'));
      expect(
        () => _format(r'${formatNumber(1)}'),
        _throwsExpression('expected an argument name'),
      );
      expect(
        () => _format(r'${/price extra}'),
        _throwsExpression('unexpected "extra"'),
      );
    });
  });

  group('beyond resolve.test.ts (ours)', () {
    // resolve.ts:148-188, `call`, inside formatString: @index outside a
    // template is undefined (:158-163), a gesture function is not a value
    // (:178-182), a validator gives its boolean (:187), and a nested
    // formatString interpolates its own template (:164-170).
    test('formatString calls as CopilotKit calls inside it', () {
      expect(_format(r'[${@index}]'), '[]');
      expect(_format(r'${@index(offset: 2)}', basePath: '/items/1'), '3');
      expect(_format(r"${@index(offset: 'x')}", basePath: '/items/1'), '1');
      expect(_format(r"${email(value: 'a@b.co')}"), 'true');
      expect(_format(r"${required(value: '')}"), 'false');
      expect(_format(r"${formatString(value: 'x ${/qty}')}!"), 'x 3!');
      expect(
        () => _format(r"${openUrl(url: 'https://x.y/')}"),
        _throwsExpression(
          '"openUrl" is not a value; bind it as the functionCall of an event',
        ),
      );
      expect(
        () => _format(r'${nope(value: 1)}'),
        _throwsExpression('"nope" is not a basic function'),
      );
    });

    // resolve.ts:262-429: the grammar's other errors, and a failing call
    // failing the whole string (a2ui_core's parser left an empty part).
    test('formatString refuses what its grammar does not take', () {
      expect(
        () => _format(r'${}'),
        _throwsExpression(r'formatString: missing expression in ${}'),
      );
      expect(
        () => _format(r"${'open}"),
        _throwsExpression(r'formatString: unclosed ${'),
      );
      expect(
        () => _format(r'${#}'),
        _throwsExpression(r'formatString: unexpected "#" in ${#}'),
      );
      expect(
        () => _format(r'${calc(expression 1)}'),
        _throwsExpression(
          'formatString: expected ":" after expression in '
          r'${calc(expression 1)}',
        ),
      );
      expect(
        () => _format(r"${calc(expression: '1' x)}"),
        _throwsExpression('formatString: expected "," or ")" after expression'),
      );
      expect(
        () => _format(r'a ${formatNumber(value: /name)} b'),
        _throwsExpression('value must be a number'),
      );
      expect(
        () => _resolve({
          '@call': 'formatString',
          'args': {
            'value': {'@path': '/missing'},
          },
        }),
        _throwsExpression('formatString takes a string value'),
      );
    });

    // resolve.ts:83-146: only a check's condition keeps a validator's
    // result; inside it, another function's args still get the boolean.
    test('keeps a validator result under a validation scope alone', () {
      final model = DataModel(_data());
      final errors = <A2uiExpressionError>[];
      final context = DataContext(
        model,
        _catalog.invoke,
        '/',
        onError: errors.add,
        protocolVersion: A2uiProtocolVersion.v1_0,
        parent: validationScope(_context(model)),
      );
      const email = {
        '@call': 'email',
        'args': {'value': 'nope'},
      };
      expect(
        context.resolveDynamicValue(email),
        const ValidationResult(
          valid: false,
          message: 'Invalid email address',
          code: 'email',
        ),
      );
      expect(
        context.resolveDynamicValue({
          '@call': 'calc',
          'args': {'expression': 'ok ? 1 : 0', 'ok': email},
        }),
        0,
      );
      expect(
        context.resolveDynamicValue({
          '@call': 'and',
          'args': {
            'values': [email, true],
          },
        }),
        false,
      );
      expect(errors, isEmpty);
      expect(_resolve(email), false);
    });

    // resolve.test.ts:196's last call, without its wording: openUrl in a
    // value (an agent's prop) is refused and opens nothing. Only the
    // user-activation flag our DocumentFunction passes on keeps it from
    // opening a URL as the surface renders.
    test('refuses openUrl in a value and opens nothing', () async {
      final launcher = fakeUrlLauncher();
      expect(
        () => _resolve({
          '@call': 'openUrl',
          'args': {'url': 'https://x'},
        }),
        throwsA(isA<A2uiExpressionError>()),
      );
      // Nothing opens, even a microtask later.
      await pumpEventQueue();
      expect(launcher.launches, isEmpty);
    });
  });
}
