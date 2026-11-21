import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/src/catalog_options.dart';
import 'package:a2ui_kit/src/functions/calc.dart';
import 'package:a2ui_kit/src/functions/format_string.dart';
import 'package:a2ui_kit/src/functions/formatting.dart';
import 'package:a2ui_kit/src/functions/open_url.dart';
import 'package:a2ui_kit/src/functions/validators.dart';
import 'package:json_schema_builder/json_schema_builder.dart'
    hide ValidationResult;

/// Runs one function call.
typedef FunctionBody =
    Object? Function(
      Map<String, dynamic> args,
      DataContext context,
      CancellationSignal? cancellationSignal,
    );

/// Args of any shape: CopilotKit's renderer checks no function's args
/// against its schema; each function checks its own and throws for bad
/// ones.
final Schema _anyArgs = Schema.fromMap(const {'type': 'object'});

/// A function of the catalog document, evaluated by a body.
///
/// It keeps the document's own definition (its argument schema, return
/// type and callers), so the catalog validates and exports calls exactly
/// as CopilotKit's export declares them. Resolved args reach the body
/// unchecked, as they reach CopilotKit's functions: `and` of a string is
/// the string's truth, not a schema error.
class DocumentFunction extends FunctionImplementation {
  /// The function [api] of the document, evaluated by [body].
  DocumentFunction(FunctionApi api, FunctionBody body)
    : _body = body,
      super(
        name: api.name,
        argumentSchema: _anyArgs,
        returnType: api.returnType,
        description: api.description,
        allowedCallers: api.declaredAllowedCallers,
        requiresUserActivation: api.declaredRequiresUserActivation,
        definition: api.definition ?? _definitionOf(api),
      );

  final FunctionBody _body;

  @override
  Object? execute(
    Map<String, dynamic> args,
    DataContext context, [
    CancellationSignal? cancellationSignal,
  ]) => _body(args, context, cancellationSignal);
}

/// The v1.0 definition of a function [api] given without one.
Map<String, Object?> _definitionOf(FunctionApi api) => {
  'type': 'object',
  if (api.description != null) 'description': api.description,
  'returnType': api.returnType.jsonValue,
  'properties': {
    '@call': {'const': api.name},
    'args': api.argumentSchema.value,
  },
  'required': ['@call', 'args'],
};

/// The 16 functions of [api], evaluated by ports of CopilotKit's
/// (`BASIC_FUNCTIONS`, packages/core/src/generative-ui/functions.ts:476-578,
/// with `calc`, `series` and `formatString` from resolve.ts:19-29): `calc`,
/// `series`, the validators, the formatters (in the options' locale),
/// `pluralize`, `and`, `or`, `not`, `formatString`, and `openUrl`, which
/// opens only http and https URLs.
///
/// A validator gives its validation result only as the condition of a
/// check (under a `validationScope`); anywhere else it gives the result's
/// `valid`, as CopilotKit's resolver coerces it (resolve.ts:183-187).
List<FunctionImplementation> kitFunctions(
  CatalogApi api,
  A2uiKitOptions options,
) {
  final values = <String, Object? Function(Map<String, Object?> args)>{
    'calc': calc,
    'series': series,
    ...copilotKitValidators,
    ...copilotKitFormatting(options.locale),
  };
  final nested = FormatStringFunctions(api, values);
  Object? valueOf(
    FunctionApi function,
    Object? Function(Map<String, Object?> args) body,
    Map<String, dynamic> args,
    DataContext context,
  ) {
    // Elsewhere a validator gives its boolean, so no arg holds a result.
    final keep = keepsValidationResults(context);
    final result = body(keep ? withValidities(args) : args);
    if (!keep &&
        function.returnType == A2uiReturnType.validationResult &&
        result is ValidationResult) {
      return result.valid;
    }
    return result;
  }

  FunctionBody? bodyOf(FunctionApi function) {
    if (function.name == 'formatString') {
      return (args, context, _) => formatString(args['value'], context, nested);
    }
    if (function.name == 'openUrl') {
      return (args, _, _) => openUrlSafely(args['url'], options);
    }
    final body = values[function.name];
    if (body == null) return null;
    return (args, context, _) => valueOf(function, body, args, context);
  }

  return [
    for (final function in api.functions.values)
      DocumentFunction(
        function,
        bodyOf(function) ??
            (_, _, _) => throw A2uiExpressionError(
              "The function '${function.name}' is not available in this "
              'version of a2ui_kit.',
              code: 'EXECUTION_ERROR',
            ),
      ),
  ];
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/core/src/generative-ui/functions.ts, packages/core/src/generative-ui/resolve.ts
