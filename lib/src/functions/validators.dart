// A port of the five validation functions of CopilotKit's function library
// (`BASIC_FUNCTIONS` in packages/core/src/generative-ui/functions.ts, MIT,
// (c) Atai Barkai), so a failed check shows CopilotKit's message and code,
// and of where their result stays a validation result: only as the
// condition of a check (packages/core/src/generative-ui/resolve.ts:83-187).

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/src/functions/calc.dart';

const ValidationResult _valid = ValidationResult(valid: true);

ValidationResult _invalid(String message, String code) =>
    ValidationResult(valid: false, message: message, code: code);

/// [value] as JavaScript's `String()` writes it; null is empty.
String jsText(Object? value) => switch (value) {
  null => '',
  final String s => s,
  final num n => jsNumberString(n),
  final bool b => '$b',
  final List<Object?> l => l.map((v) => v == null ? '' : jsText(v)).join(','),
  _ => '[object Object]',
};

/// The number of [value] as CopilotKit's `numberOf` reads an arg: a number,
/// or numeric text; NaN otherwise.
double jsNumberArg(Object? value) => switch (value) {
  final num n => n.toDouble(),
  final String s when s.trim().isNotEmpty => jsNumberOf(s),
  _ => double.nan,
};

/// CopilotKit's `optionalNumber`: null when [value] is absent, else its number;
/// throws when it is not one.
double? jsOptionalNumber(Object? value, String name) {
  if (value == null) return null;
  final parsed = jsNumberArg(value);
  if (parsed.isNaN) throw A2uiExpressionError('$name must be a number');
  return parsed;
}

final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// The parent of a data context that resolves the condition of a check (see
/// [validationScope]). It resolves nothing itself.
final class _ValidationScope extends DataContext {
  _ValidationScope(DataContext context)
    : super(context.dataModel, _resolvesNothing, '/', parent: context.parent);
}

Object? _resolvesNothing(
  String name,
  Map<String, dynamic> args,
  DataContext context,
) => throw StateError('a validation scope resolves no function ($name)');

/// The parent to give the data context of a check's conditions, made in
/// place of [context] (the component's data context): its calls then keep a
/// validator's [ValidationResult] ([keepsValidationResults]), as CopilotKit's
/// resolver keeps it for the condition of a check alone
/// (resolve.ts:93-146, `walk`'s `isCondition`; :183-187, `coerce`).
///
/// A context made under it reads the same data and the same template index
/// as one made under [context]'s own parent: the scope's path, `/`, has no
/// index, and its parent is that parent. a2ui_core passes a context's parent
/// on to the context every call runs in (data_context.dart:1579-1604,
/// `_withCallCatalog`), so the calls of the conditions find it there.
DataContext validationScope(DataContext context) => _ValidationScope(context);

/// Whether a validator called in [context] keeps its [ValidationResult]:
/// only under a [validationScope]. Everywhere else it gives the result's
/// `valid`, as CopilotKit's resolver coerces every validator call that is
/// not the condition of a check to its boolean (resolve.ts:83-86, :187).
bool keepsValidationResults(DataContext context) =>
    context.parent is _ValidationScope;

/// [args] with each [ValidationResult] in them, at any depth, replaced by
/// its `valid`: CopilotKit walks a call's args with `keepValidation` false
/// (resolve.ts:183-185), so a validator inside another function's args
/// gives that function its boolean, also in a check's condition.
Map<String, Object?> withValidities(Map<String, Object?> args) {
  bool holds(Object? value) => switch (value) {
    ValidationResult() => true,
    final List<Object?> list => list.any(holds),
    final Map<Object?, Object?> map => map.values.any(holds),
    _ => false,
  };
  Object? replace(Object? value) => switch (value) {
    final ValidationResult result => result.valid,
    final List<Object?> list => [for (final item in list) replace(item)],
    final Map<String, Object?> map => {
      for (final MapEntry(:key, :value) in map.entries) key: replace(value),
    },
    final Map<Object?, Object?> map => {
      for (final MapEntry(:key, :value) in map.entries) key: replace(value),
    },
    _ => value,
  };
  if (!holds(args)) return args;
  return {
    for (final MapEntry(:key, :value) in args.entries) key: replace(value),
  };
}

/// CopilotKit's validators by name: `required`, `regex`, `length`,
/// `numeric` and `email`.
final Map<String, Object? Function(Map<String, Object?> args)>
copilotKitValidators = {
  'required': (args) {
    final value = args['value'];
    final isEmpty =
        value == null || value == '' || (value is List && value.isEmpty);
    return isEmpty ? _invalid('Required', 'required') : _valid;
  },
  'regex': (args) {
    final pattern = args['pattern'];
    if (pattern is! String) {
      throw A2uiExpressionError('pattern must be a string');
    }
    final RegExp expression;
    try {
      expression = RegExp(pattern, unicode: true);
    } on FormatException {
      throw A2uiExpressionError('"$pattern" is not a regular expression');
    }
    return expression.hasMatch(jsText(args['value']))
        ? _valid
        : _invalid('Invalid format', 'pattern');
  },
  'length': (args) {
    final size = jsText(args['value']).length;
    final low = jsOptionalNumber(args['min'], 'min');
    final high = jsOptionalNumber(args['max'], 'max');
    if (low != null && size < low) {
      return _invalid('At least ${jsNumberString(low)} characters', 'tooShort');
    }
    if (high != null && size > high) {
      return _invalid('At most ${jsNumberString(high)} characters', 'tooLong');
    }
    return _valid;
  },
  'numeric': (args) {
    final parsed = jsNumberArg(args['value']);
    if (parsed.isNaN) return _invalid('Must be a number', 'notANumber');
    final low = jsOptionalNumber(args['min'], 'min');
    final high = jsOptionalNumber(args['max'], 'max');
    if (low != null && parsed < low) {
      return _invalid('At least ${jsNumberString(low)}', 'tooSmall');
    }
    if (high != null && parsed > high) {
      return _invalid('At most ${jsNumberString(high)}', 'tooLarge');
    }
    return _valid;
  },
  'email': (args) => _email.hasMatch(jsText(args['value']))
      ? _valid
      : _invalid('Invalid email address', 'email'),
};

// PORT STATUS: confidence=high todos=0 upstream=packages/core/src/generative-ui/functions.ts, packages/core/src/generative-ui/resolve.ts
