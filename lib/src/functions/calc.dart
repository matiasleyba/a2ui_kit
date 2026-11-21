// A port of CopilotKit's `calc` and `series` (packages/core/src/
// generative-ui/calc.ts, MIT, (c) Atai Barkai): the two value functions
// that A2UI 1.0 lacks.

import 'dart:math' as math;

import 'package:a2ui_core/a2ui_core.dart';

/// The most items `series` makes.
const int maxSeriesLength = 1000;

/// The truth of [value] as JavaScript's `Boolean()` gives it, except that a
/// validation result counts as its `valid`.
bool calcTruth(Object? value) => switch (value) {
  null => false,
  final bool b => b,
  final num n => n != 0 && !n.isNaN,
  final String s => s.isNotEmpty,
  _ => ValidationResult.validityOf(value) ?? true,
};

/// [value] as JavaScript's `String()` writes a number: `3` for 3.0, `0.5`,
/// `1e+21`.
String jsNumberString(num value) {
  if (value is int) return '$value';
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value > 0 ? 'Infinity' : '-Infinity';
  if (value == value.truncateToDouble() && value.abs() < 1e21) {
    return value.toInt().toString();
  }
  final text = value.toString();
  // Dart writes 1e21 as "1e+21", as JavaScript does; small exponents match.
  return text;
}

/// [value] as JavaScript's `Number()` reads a string: trimmed, decimal,
/// `0x`, `0o` or `0b` prefixed, or empty for 0. NaN when unreadable.
double jsNumberOf(String value) {
  final text = value.trim();
  if (text.isEmpty) return 0;
  final prefixed = RegExp(r'^0([xXoObB])([0-9a-fA-F]+)$').firstMatch(text);
  if (prefixed != null) {
    final radix = switch (prefixed[1]!.toLowerCase()) {
      'x' => 16,
      'o' => 8,
      _ => 2,
    };
    return int.tryParse(prefixed[2]!, radix: radix)?.toDouble() ?? double.nan;
  }
  if (text == 'Infinity' || text == '+Infinity') return double.infinity;
  if (text == '-Infinity') return double.negativeInfinity;
  if (!RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$').hasMatch(text)) {
    return double.nan;
  }
  return double.parse(text);
}

/// JavaScript's `Number.prototype.toFixed(digits)` (ECMA-262, 21.1.3.3):
/// the exact value rounded half up at [digits] decimals, a minus only for
/// a value below 0 (so -0 is "0.0"); a value of 1e21 or more is written as
/// `String()` writes it.
String jsToFixed(double value, int digits) {
  if (!value.isFinite) return jsNumberString(value);
  if (value.abs() >= 1e21) return jsNumberString(value);
  // `x < 0` is false for -0: no sign.
  return (value == 0 ? 0.0 : value).toStringAsFixed(digits);
}

/// JavaScript's `parseFloat` (ECMA-262 21.1.2.12): leading white space and
/// line terminators skipped, then the longest prefix that is a decimal
/// literal (`Infinity` included; no `0x`); NaN when there is none.
/// `parseFloat("40%")` is 40, `parseFloat("1e")` is 1.
double jsParseFloat(String value) {
  final match = _floatPrefix.firstMatch(value.replaceFirst(_jsSpace, ''));
  if (match == null) return double.nan;
  final literal = match[0]!;
  if (literal.endsWith('Infinity')) {
    return literal.startsWith('-') ? double.negativeInfinity : double.infinity;
  }
  return double.parse(literal);
}

// ECMA-262 12.2 (WhiteSpace: TAB, VT, FF, ZWNBSP and the Zs spaces) and
// 12.3 (LineTerminator: LF, CR, LS, PS).
final RegExp _jsSpace = RegExp(
  '^[\t\n\v\f\r    -     　'
  '﻿]+',
);
final RegExp _floatPrefix = RegExp(
  r'^[+-]?(Infinity|(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?)',
);

A2uiExpressionError _error(String message) => A2uiExpressionError(message);

/// The number of [value] in a calculation: numbers, booleans (1 and 0) and
/// numeric text. Throws for anything else.
double _numberOf(Object? value, String what) {
  if (value is num) {
    if (!value.isFinite) throw _error('calc: $what is not finite');
    return value.toDouble();
  }
  if (value is bool) return value ? 1 : 0;
  if (value is String && value.trim().isNotEmpty) {
    final parsed = jsNumberOf(value);
    if (parsed.isFinite) return parsed;
  }
  if (value == null) throw _error('calc: $what has no value');
  throw _error('calc: $what is not a number');
}

String _describe(Object? value) => switch (value) {
  final String s => '"$s"',
  null => 'null',
  final num n => jsNumberString(n),
  _ => '$value',
};

/// JavaScript's `Math.round` (ECMA-262 21.3.2.28): halves round up, towards
/// positive infinity; `Math.round(-2.5)` is -2. One difference: for x in
/// [-0.5, 0) JavaScript returns -0 and this returns 0 (they compare equal;
/// only a division by the result or `Object.is` tells them apart).
double jsMathRound(double x) {
  if (!x.isFinite) return x;
  final floor = x.floorToDouble();
  return x - floor >= .5 ? floor + 1 : floor;
}

double _jsPow(double x, double y) => math.pow(x, y).toDouble();

final Map<String, double Function(List<double> args)> _math = {
  'min': (args) => args.reduce(math.min),
  'max': (args) => args.reduce(math.max),
  'abs': (args) => args.first.abs(),
  'floor': (args) => args.first.floorToDouble(),
  'ceil': (args) => args.first.ceilToDouble(),
  'round': (args) {
    final decimals = args.length > 1 ? args[1] : 0.0;
    final factor = _jsPow(10, decimals.truncateToDouble());
    return jsMathRound(args.first * factor) / factor;
  },
  'pow': (args) => _jsPow(args[0], args[1]),
  'sqrt': (args) => args.first < 0 ? double.nan : math.sqrt(args.first),
  'exp': (args) => math.exp(args.first),
  'ln': (args) => math.log(args.first),
  'log10': (args) => jsLog10(args.first),
};

/// JavaScript's `Math.log10`, exact for powers of ten: `log10(1000)` is 3,
/// where `ln(x) / ln(10)` gives 2.9999999999999996.
double jsLog10(double x) {
  final log = math.log(x) / math.ln10;
  if (!log.isFinite) return log;
  final whole = log.roundToDouble();
  return _jsPow(10, whole) == x ? whole : log;
}

/// [value] as JSON writes a JavaScript number: a whole number within
/// 2^53 is an int, so it encodes as `0`, not `0.0`.
Object? jsonNumber(Object? value) {
  if (value is double &&
      value.isFinite &&
      value == value.truncateToDouble() &&
      value.abs() <= 9007199254740992) {
    return value.toInt();
  }
  return value;
}

/// How many args a function takes, at least and at most; min and max take
/// any number.
const Map<String, (int, int)> _arity = {
  'abs': (1, 1),
  'floor': (1, 1),
  'ceil': (1, 1),
  'round': (1, 2),
  'pow': (2, 2),
  'sqrt': (1, 1),
  'exp': (1, 1),
  'ln': (1, 1),
  'log10': (1, 1),
};

/// Named constants, when no arg of the same name is passed.
const Map<String, double> _constants = {'pi': math.pi, 'e': math.e};

const List<String> _operators = [
  '&&', '||', '==', '!=', '<=', '>=', '<', '>', '+', '-', '*', '/', '%', //
  '^', '(', ')', ',', '?', ':', '!',
];

sealed class _Token {
  const _Token();
}

final class _NumberToken extends _Token {
  const _NumberToken(this.value);
  final double value;
}

final class _StringToken extends _Token {
  const _StringToken(this.value);
  final String value;
}

final class _NameToken extends _Token {
  const _NameToken(this.value);
  final String value;
}

final class _OpToken extends _Token {
  const _OpToken(this.value);
  final String value;
}

final class _EndToken extends _Token {
  const _EndToken();
}

final RegExp _space = RegExp(r'\s');
final RegExp _numberStart = RegExp('[0-9.]');
final RegExp _number = RegExp(r'^\d*\.?\d+(?:[eE][-+]?\d+)?|^\d+\.?');
final RegExp _nameStart = RegExp('[A-Za-z_]');
final RegExp _name = RegExp('^[A-Za-z_][A-Za-z0-9_]*');

List<_Token> _tokenize(String source) {
  final tokens = <_Token>[];
  var i = 0;
  while (i < source.length) {
    final char = source[i];
    if (_space.hasMatch(char)) {
      i++;
      continue;
    }
    if (_numberStart.hasMatch(char)) {
      final match = _number.firstMatch(source.substring(i));
      if (match == null) {
        final end = math.min(source.length, i + 8);
        throw _error('calc: bad number at "${source.substring(i, end)}"');
      }
      tokens.add(_NumberToken(double.parse(match[0]!)));
      i += match[0]!.length;
      continue;
    }
    if (char == "'" || char == '"') {
      final value = StringBuffer();
      i++;
      while (i < source.length && source[i] != char) {
        if (source[i] == r'\' && i + 1 < source.length) i++;
        value.write(source[i++]);
      }
      if (i >= source.length) throw _error('calc: unclosed string');
      i++;
      tokens.add(_StringToken(value.toString()));
      continue;
    }
    if (_nameStart.hasMatch(char)) {
      final match = _name.firstMatch(source.substring(i))!;
      tokens.add(_NameToken(match[0]!));
      i += match[0]!.length;
      continue;
    }
    final op = _operators.where((o) => source.startsWith(o, i)).firstOrNull;
    if (op == null) throw _error('calc: unexpected "$char"');
    tokens.add(_OpToken(op));
    i += op.length;
  }
  tokens.add(const _EndToken());
  return tokens;
}

/// A recursive descent parser that evaluates as it parses, as CopilotKit's
/// does: the branch a condition does not take is parsed (so its syntax is
/// checked) but not evaluated, so `n == 0 ? 0 : 10 / n` is a valid guard.
class _CalcParser {
  _CalcParser(this.tokens, this.scope, this.source);

  final List<_Token> tokens;
  final Map<String, Object?> scope;
  final String source;
  int _pos = 0;

  /// Above 0 while parsing a part whose value is not needed.
  int _skipDepth = 0;

  _Token get _peek => _pos < tokens.length ? tokens[_pos] : const _EndToken();

  Object? parse() {
    final value = _ternary();
    if (_peek is! _EndToken) _fail('unexpected "${_text(_peek)}"');
    return value;
  }

  Never _fail(String what) => throw _error('calc: $what in "$source"');

  String _text(_Token token) => switch (token) {
    _EndToken() => 'end',
    _NumberToken(:final value) => jsNumberString(value),
    _StringToken(:final value) => value,
    _NameToken(:final value) => value,
    _OpToken(:final value) => value,
  };

  String? _peekOp(List<String> ops) {
    final token = _peek;
    return token is _OpToken && ops.contains(token.value) ? token.value : null;
  }

  void _expectOp(String op) {
    if (_peekOp([op]) == null) {
      _fail('expected "$op" but found "${_text(_peek)}"');
    }
    _pos++;
  }

  Object? _skipped(Object? Function() parse) {
    _skipDepth++;
    try {
      parse();
    } finally {
      _skipDepth--;
    }
    return null;
  }

  double _num(Object? value, String what) =>
      _skipDepth > 0 ? 0 : _numberOf(value, what);

  Object? _ternary() {
    final condition = _or();
    if (_peekOp(['?']) == null) return condition;
    _pos++;
    final takesFirst = calcTruth(condition);
    final whenTrue = takesFirst ? _ternary() : _skipped(_ternary);
    _expectOp(':');
    final whenFalse = takesFirst ? _skipped(_ternary) : _ternary();
    return takesFirst ? whenTrue : whenFalse;
  }

  Object? _or() {
    var left = _and();
    while (_peekOp(['||']) != null) {
      _pos++;
      if (calcTruth(left)) {
        _skipped(_and);
        left = true;
      } else {
        left = calcTruth(_and());
      }
    }
    return left;
  }

  Object? _and() {
    var left = _equality();
    while (_peekOp(['&&']) != null) {
      _pos++;
      if (!calcTruth(left)) {
        _skipped(_equality);
        left = false;
      } else {
        left = calcTruth(_equality());
      }
    }
    return left;
  }

  Object? _equality() {
    var left = _comparison();
    for (
      var op = _peekOp(['==', '!=']);
      op != null;
      op = _peekOp(['==', '!='])
    ) {
      _pos++;
      final right = _comparison();
      final isEqual = left is num || right is num
          ? _num(left, 'the left side of ==') ==
                _num(right, 'the right side of ==')
          : left == right;
      left = op == '==' ? isEqual : !isEqual;
    }
    return left;
  }

  Object? _comparison() {
    var left = _additive();
    const ops = ['<', '<=', '>', '>='];
    for (var op = _peekOp(ops); op != null; op = _peekOp(ops)) {
      _pos++;
      final a = _num(left, 'the left side of $op');
      final b = _num(_additive(), 'the right side of $op');
      left = switch (op) {
        '<' => a < b,
        '<=' => a <= b,
        '>' => a > b,
        _ => a >= b,
      };
    }
    return left;
  }

  Object? _additive() {
    var left = _multiplicative();
    for (var op = _peekOp(['+', '-']); op != null; op = _peekOp(['+', '-'])) {
      _pos++;
      final right = _multiplicative();
      if (op == '+' && (left is String || right is String)) {
        left = '${_concat(left)}${_concat(right)}';
      } else {
        final a = _num(left, 'the left side of $op');
        final b = _num(right, 'the right side of $op');
        left = op == '+' ? a + b : a - b;
      }
    }
    return left;
  }

  /// A value in a text concatenation, as JavaScript writes it; null is
  /// empty, as CopilotKit's `?? ""` makes it.
  String _concat(Object? value) => switch (value) {
    null => '',
    final num n => jsNumberString(n),
    _ => '$value',
  };

  Object? _multiplicative() {
    var left = _unary();
    const ops = ['*', '/', '%'];
    for (var op = _peekOp(ops); op != null; op = _peekOp(ops)) {
      _pos++;
      final a = _num(left, 'the left side of $op');
      final b = _num(_unary(), 'the right side of $op');
      if (op != '*' && b == 0 && _skipDepth == 0) _fail('division by zero');
      left = switch (op) {
        '*' => a * b,
        '/' => a / b,
        _ => a.remainder(b),
      };
    }
    return left;
  }

  Object? _unary() {
    if (_peekOp(['-']) != null) {
      _pos++;
      return -_num(_unary(), 'the operand of -');
    }
    if (_peekOp(['!']) != null) {
      _pos++;
      return !calcTruth(_unary());
    }
    return _power();
  }

  /// `a ^ b`: binds tighter than `*` and unary minus, right to left.
  Object? _power() {
    final base = _primary();
    if (_peekOp(['^']) == null) return base;
    _pos++;
    final exponent = _unary();
    if (_skipDepth > 0) return null;
    return _finite(
      _jsPow(
        _num(base, 'the left side of ^'),
        _num(exponent, 'the right side of ^'),
      ),
      '^',
    );
  }

  double _finite(double value, String what) {
    if (!value.isFinite) _fail('$what has no finite result');
    return value;
  }

  Object? _primary() {
    final token = _peek;
    _pos++;
    switch (token) {
      case _NumberToken(:final value):
        return value;
      case _StringToken(:final value):
        return value;
      case _NameToken(:final value):
        return _named(value);
      case _OpToken(:final value):
        if (value == '(') {
          final inner = _ternary();
          _expectOp(')');
          return inner;
        }
        _fail('unexpected "$value"');
      case _EndToken():
        _fail('missing value');
    }
  }

  Object? _named(String name) {
    if (name == 'true') return true;
    if (name == 'false') return false;
    if (name == 'null') return null;
    if (_peekOp(['(']) != null) {
      _pos++;
      final args = <double>[];
      if (_peekOp([')']) == null) {
        for (;;) {
          args.add(_num(_ternary(), 'an argument of $name'));
          if (_peekOp([',']) == null) break;
          _pos++;
        }
      }
      _expectOp(')');
      if (_skipDepth > 0) return null;
      final function = _math[name];
      if (function == null) _fail('unknown function $name');
      if (args.isEmpty) _fail('$name needs an argument');
      final (least, most) = _arity[name] ?? (1, 1 << 30);
      if (args.length < least || args.length > most) {
        final count = least == most ? '$least' : '$least or $most';
        _fail('$name takes $count argument${most == 1 ? '' : 's'}');
      }
      return _finite(function(args), name);
    }
    if (_skipDepth > 0) return null;
    if (!scope.containsKey(name)) {
      final constant = _constants[name];
      if (constant != null) return constant;
      _fail('unknown name $name; pass it as an arg');
    }
    final value = scope[name];
    if (value != null && value is! num && value is! String && value is! bool) {
      _fail('$name is not a number, text or boolean (${_describe(value)})');
    }
    return value is int ? value.toDouble() : value;
  }
}

/// Evaluates [expression] with the names in [scope]: a number (a double),
/// a string, a bool or null.
///
/// Throws an [A2uiExpressionError] for a bad expression or a missing name.
Object? evaluateCalc(Object? expression, Map<String, Object?> scope) {
  if (expression is! String || expression.trim().isEmpty) {
    throw _error('calc: expression must be a string');
  }
  return _CalcParser(_tokenize(expression), scope, expression).parse();
}

/// The `calc` function: `args['expression']` evaluated with the other args
/// as its names.
Object? calc(Map<String, Object?> args) {
  final scope = Map<String, Object?>.of(args)..remove('expression');
  return jsonNumber(evaluateCalc(args['expression'], scope));
}

final RegExp _wholeExpression = RegExp(r'^\$\{([^}]*)\}$');
final RegExp _innerExpression = RegExp(r'\$\{([^}]*)\}');

/// [item] for one iteration: a string that is one `${...}` gives the typed
/// value of the expression, a string with `${...}` in it is interpolated as
/// text, and lists and maps are walked.
Object? _fillItem(Object? item, Map<String, Object?> scope) {
  if (item is String) {
    final whole = _wholeExpression.firstMatch(item);
    if (whole != null) return jsonNumber(evaluateCalc(whole[1], scope));
    return item.replaceAllMapped(_innerExpression, (match) {
      final value = evaluateCalc(match[1], scope);
      return switch (value) {
        null => '',
        final num n => jsNumberString(n),
        _ => '$value',
      };
    });
  }
  if (item is List) return [for (final entry in item) _fillItem(entry, scope)];
  if (item is Map) {
    return <String, Object?>{
      for (final entry in item.entries)
        '${entry.key}': _fillItem(entry.value, scope),
    };
  }
  return item;
}

final RegExp _variableName = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// The `series` function: `count` copies of `item`, with the loop variable
/// (`variable`, `i` by default) counting from `start` (1 by default) and the
/// other args in scope of the item's `${...}` expressions.
List<Object?> series(Map<String, Object?> args) {
  final length = _numberOf(args['count'], 'count');
  if (length != length.truncateToDouble() || length < 0) {
    throw _error('series: count must be a whole number');
  }
  if (length > maxSeriesLength) {
    throw _error('series: count is at most $maxSeriesLength');
  }
  // An absent arg is JavaScript's undefined; a null one is a value.
  if (!args.containsKey('item')) throw _error('series: item is required');
  final item = args['item'];
  final name = args.containsKey('variable') ? args['variable'] : 'i';
  if (name is! String || !_variableName.hasMatch(name)) {
    throw _error('series: variable must be a name');
  }
  final first = args.containsKey('start')
      ? _numberOf(args['start'], 'start')
      : 1.0;
  final scope = Map<String, Object?>.of(args)
    ..remove('count')
    ..remove('item')
    ..remove('variable')
    ..remove('start');
  return [
    for (var index = 0; index < length; index++)
      _fillItem(item, {...scope, name: first + index}),
  ];
}

// PORT STATUS: confidence=high todos=0 upstream=packages/core/src/generative-ui/calc.ts
