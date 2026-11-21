// A port of CopilotKit's formatString and of the resolution of the values in
// it (packages/core/src/generative-ui/resolve.ts: `walk` and `call`,
// :93-188, and the `${...}` grammar, :262-429: `formatString`,
// `matchingBrace` and `ExpressionParser`; MIT, (c) Atai Barkai).
//
// a2ui_core resolves formatString's own args (its `value`) before the body
// runs; the `${...}` expressions are this port's to parse and evaluate. The
// data they read is read through the data model's signals, so a binding
// that resolves a formatString recomputes when that data changes, as
// CopilotKit's renderer does with the paths a resolve reports.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/src/functions/calc.dart' show jsonNumber;
import 'package:a2ui_kit/src/functions/validators.dart' show jsText;

/// The functions a formatString expression calls: CopilotKit's
/// `BASIC_FUNCTIONS` (functions.ts:476-578, resolve.ts:19-29), each a body
/// that takes resolved args, with what the catalog [api] declares of it.
class FormatStringFunctions {
  /// The [bodies] of the functions [api] declares, by name; `formatString`
  /// is evaluated here, and a function that needs a user gesture is
  /// refused before its body is looked up.
  const FormatStringFunctions(this.api, this.bodies);

  /// The catalog's declarations: who needs a gesture (`openUrl`), who gives
  /// a validation result (the validators).
  final CatalogApi api;

  /// The bodies, by name: a validator gives its [ValidationResult].
  final Map<String, Object? Function(Map<String, Object?> args)> bodies;
}

/// formatString's own call (resolve.ts:164-170): [template], its `value`
/// already resolved, interpolated in [context] with [functions].
///
/// Throws an [A2uiExpressionError] for a value that is not a string, an
/// expression that does not parse, and a call that fails.
String formatString(
  Object? template,
  DataContext context,
  FormatStringFunctions functions,
) {
  if (template is! String) {
    throw A2uiExpressionError('formatString takes a string value');
  }
  return _formatString(template, _Walk(context, functions));
}

/// What a resolution reads from: CopilotKit's `Walk` (resolve.ts:88-91).
class _Walk {
  _Walk(this.context, this.functions);

  final DataContext context;
  final FormatStringFunctions functions;

  /// The data at [path], absolute or relative to the template item: the
  /// path state of the parser (resolve.ts:400-404) and a binding's read
  /// (:122-128). The read goes through the path's signal, so a binding
  /// that evaluates this depends on it.
  Object? read(String path) =>
      context.dataModel.watch<Object?>(context.resolvePath(path)).value;
}

/// Where a value sits with respect to `checks` (resolve.ts:93-98).
enum _CheckScope { outside, list, check }

bool _isPathBinding(Map<Object?, Object?> value) =>
    value['@path'] is String && value.length == 1;

bool _isCallBinding(Map<Object?, Object?> value) => value['@call'] is String;

bool _isActionBinding(Map<Object?, Object?> value) =>
    value.length == 1 &&
    (value['functionCall'] is Map || value['event'] is Map);

/// CopilotKit's `walk` (resolve.ts:100-146): [value] with its bindings and
/// calls resolved; a validator's result stays an object only with
/// [keepValidation] (the condition of a check).
Object? _walk(
  Object? value,
  _Walk state,
  bool keepValidation, [
  _CheckScope scope = _CheckScope.outside,
]) {
  if (value is List) {
    final itemScope = scope == _CheckScope.list
        ? _CheckScope.check
        : _CheckScope.outside;
    return [
      for (final item in value) _walk(item, state, keepValidation, itemScope),
    ];
  }
  if (value is! Map) return value;
  if (_isPathBinding(value)) return state.read(value['@path']! as String);
  if (_isCallBinding(value)) return _call(value, state, keepValidation);
  // An event binding is not a value. It is resolved when the event runs.
  if (_isActionBinding(value)) return value;
  return <String, Object?>{
    for (final MapEntry(:key, value: item) in value.entries)
      '$key': _walk(
        item,
        state,
        // Only the condition of a check consumes a ValidationResult as an
        // object.
        keepValidation || (scope == _CheckScope.check && key == 'condition'),
        key == 'checks' ? _CheckScope.list : _CheckScope.outside,
      ),
  };
}

/// CopilotKit's `call` (resolve.ts:148-188).
Object? _call(Map<Object?, Object?> binding, _Walk state, bool keepValidation) {
  final name = binding['@call']! as String;
  // `binding.args ?? {}`: an absent or null args is no args.
  final rawArgs = binding['args'] ?? const <String, Object?>{};
  if (rawArgs is! Map) {
    throw A2uiExpressionError('the args of "$name" must be an object');
  }
  if (name == '@index') {
    // `templateIndex(basePath)`: the index of the template item, none
    // outside of a template.
    final index = state.context.index;
    if (index == null) return null;
    final offset = _walk(rawArgs['offset'], state, false);
    return index + (offset is num ? offset : 0);
  }
  if (name == 'formatString') {
    final template = _walk(rawArgs['value'], state, false);
    if (template is! String) {
      throw A2uiExpressionError('formatString takes a string value');
    }
    return _formatString(template, state);
  }
  final declared = state.functions.api.functions[name];
  final body = state.functions.bodies[name];
  if (declared == null) {
    throw A2uiExpressionError('"$name" is not a basic function');
  }
  // A value is computed whenever the data changes, never from a gesture. A
  // function that needs one (openUrl) runs only as the functionCall of an
  // event, where the gesture is checked.
  if (declared.requiresUserActivation) {
    throw A2uiExpressionError(
      '"$name" is not a value; bind it as the functionCall of an event',
    );
  }
  // Every function the catalog declares has a body here but openUrl and
  // formatString, handled above.
  if (body == null) {
    throw A2uiExpressionError('"$name" is not a basic function');
  }
  // A validator result in an arg becomes its boolean: `and`, `or`, `not` and
  // `calc` all want one, and a validator reads plain values anyway. Args
  // that resolve to something other than an object (an `@path` binding in
  // place of them) give the function no args.
  final walked = _walk(rawArgs, state, false);
  final args = walked is Map
      ? <String, Object?>{
          for (final MapEntry(:key, :value) in walked.entries) '$key': value,
        }
      : <String, Object?>{};
  final result = body(args);
  if (declared.returnType == A2uiReturnType.validationResult &&
      !keepValidation &&
      result is ValidationResult) {
    return result.valid;
  }
  return result;
}

/// The `${...}` grammar of `formatString` (resolve.ts:264-298):
///
///   expression := path | literal | call
///   path       := "/" segments | identifier ("/" segments)*
///   literal    := 'text' | "text" | number | true | false | null
///   call       := identifier "(" [ name ":" expression
///                 ("," name ":" expression)* ] ")"
///
/// A `\${` in the template is a literal `${`.
String _formatString(String template, _Walk state) {
  final out = StringBuffer();
  var index = 0;
  while (index < template.length) {
    final start = template.indexOf(r'${', index);
    if (start == -1) {
      out.write(template.substring(index));
      break;
    }
    if (start > 0 && template[start - 1] == r'\') {
      out
        ..write(template.substring(index, start - 1))
        ..write(r'${');
      index = start + 2;
      continue;
    }
    out.write(template.substring(index, start));
    final end = _matchingBrace(template, start + 2);
    if (end == -1) throw A2uiExpressionError(r'formatString: unclosed ${');
    final expression = template.substring(start + 2, end).trim();
    final value = _ExpressionParser(expression, state).parse();
    // `String(value)`, undefined and null as empty.
    out.write(jsText(value));
    index = end + 1;
  }
  return out.toString();
}

/// The index of the `}` that closes the block opened at [from], or -1
/// (resolve.ts:300-316).
int _matchingBrace(String template, int from) {
  var depth = 1;
  String? quote;
  for (var i = from; i < template.length; i++) {
    final char = template[i];
    if (quote != null) {
      if (char == r'\') {
        i++;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
    } else if (char == '{') {
      depth++;
    } else if (char == '}' && --depth == 0) {
      return i;
    }
  }
  return -1;
}

final RegExp _identifier = RegExp('@?[A-Za-z_][A-Za-z0-9_-]*');
final RegExp _number = RegExp(r'-?\d+(?:\.\d+)?');
final RegExp _pathSegment = RegExp(r'''[^\s,():'"]+''');
final RegExp _space = RegExp(r'\s');

/// CopilotKit's `ExpressionParser` (resolve.ts:322-429): it evaluates as it
/// parses.
class _ExpressionParser {
  _ExpressionParser(this.source, this.state);

  final String source;
  final _Walk state;
  var _pos = 0;

  /// The code unit at [index] as a string, or null past the end:
  /// JavaScript's `this.source[index]`.
  String? _at(int index) => index < source.length ? source[index] : null;

  Object? parse() {
    final value = _expression();
    _skipSpace();
    if (_pos < source.length) {
      throw A2uiExpressionError(
        'formatString: unexpected "${source.substring(_pos)}" in '
        '\${$source}',
      );
    }
    return value;
  }

  Never _fail(String what) =>
      throw A2uiExpressionError('formatString: $what in \${$source}');

  void _skipSpace() {
    while (_pos < source.length && _space.hasMatch(source[_pos])) {
      _pos++;
    }
  }

  /// A sticky match at the parser's place: JavaScript's `y` flag.
  String? _match(RegExp pattern) {
    final found = pattern.matchAsPrefix(source, _pos);
    if (found == null) return null;
    _pos = found.end;
    return found[0];
  }

  Object? _expression() {
    _skipSpace();
    final char = _at(_pos);
    if (char == null) _fail('missing expression');
    if (char == "'" || char == '"') return _quoted(char);
    if (char == '/') return _path(_match(_pathSegment) ?? '/');
    final number = _match(_number);
    // `Number(number)`; a whole number as JSON gives it, an int.
    if (number != null) return jsonNumber(double.parse(number));
    final name = _match(_identifier);
    if (name == null) _fail('unexpected "$char"');
    if (name == 'true') return true;
    if (name == 'false') return false;
    if (name == 'null') return null;
    _skipSpace();
    if (_at(_pos) == '(') return _callExpression(name);
    // A system function such as @index needs no parentheses.
    if (name.startsWith('@')) return _call({'@call': name}, state, false);
    // A relative path: "name" or "name/more".
    final rest = _at(_pos) == '/' ? _match(_pathSegment) : '';
    return _path('$name${rest ?? ''}');
  }

  String _quoted(String quote) {
    final value = StringBuffer();
    _pos++;
    while (_pos < source.length) {
      final char = source[_pos++];
      if (char == r'\' && _pos < source.length) {
        value.write(source[_pos++]);
      } else if (char == quote) {
        return value.toString();
      } else {
        value.write(char);
      }
    }
    return _fail('unclosed string');
  }

  Object? _path(String path) => state.read(path);

  Object? _callExpression(String name) {
    _pos++; // (
    final args = <String, Object?>{};
    _skipSpace();
    if (_at(_pos) == ')') {
      _pos++;
      return _call({'@call': name, 'args': args}, state, false);
    }
    for (;;) {
      _skipSpace();
      final key = _match(_identifier);
      if (key == null) _fail('expected an argument name');
      _skipSpace();
      if (_at(_pos) != ':') _fail('expected ":" after $key');
      _pos++;
      args[key] = _expression();
      _skipSpace();
      final next = _at(_pos++);
      if (next == ')') break;
      if (next != ',') _fail('expected "," or ")" after $key');
    }
    return _call({'@call': name, 'args': args}, state, false);
  }
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/core/src/generative-ui/resolve.ts
