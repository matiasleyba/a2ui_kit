import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/foundation/text/text_styles.dart';
import 'package:a2ui_kit/src/functions/validators.dart' show validationScope;
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// The failed check a control shows: CopilotKit's `FailedCheck`.
@immutable
class FailedCheck {
  /// A failed check with [message] and [severity].
  const FailedCheck({required this.message, required this.severity, this.code});

  /// What to show.
  final String message;

  /// `error` blocks a Button; `warning` and `info` only inform.
  final A2uiCheckSeverity severity;

  /// The validation result's code, when it had one.
  final String? code;

  /// Whether the check is an error.
  bool get isError => severity == A2uiCheckSeverity.error;

  @override
  bool operator ==(Object other) =>
      other is FailedCheck &&
      other.message == message &&
      other.severity == severity &&
      other.code == code;

  @override
  int get hashCode => Object.hash(message, severity, code);

  @override
  String toString() => 'FailedCheck(${severity.wire}: $message)';
}

/// The message a check without one shows, as in CopilotKit.
const String defaultCheckMessage = 'Invalid value';

/// The failed check of [node] to show, or null when every check passes: a
/// port of CopilotKit's `firstFailedCheck`.
///
/// It reads the component's `checks` as the agent wrote them and resolves
/// each `condition` and `message`. A condition that is not known yet (null,
/// such as a binding to data that is not there) passes. A false condition
/// is an error with the check's message. A failed validation result is a
/// failure of its own severity (an error when it names none), and the
/// check's message wins over the result's: the built-in validators always
/// have one, and the check is where the agent puts its own wording. The
/// first error is returned, else the first warning or info, so a warning
/// never hides an error after it.
///
/// Called while a component builds, it rebuilds the component when a
/// condition changes.
FailedCheck? firstFailedCheck(KitNode node) {
  final context = node.context;
  if (context == null) return null;
  final properties = context.componentModel.properties;
  final rules = properties['@checks'] ?? properties['checks'];
  if (rules is! List || rules.isEmpty) return null;
  final resolved = _resolvedRules(context, rules);
  FailedCheck? first;
  for (final (:condition, :message) in resolved) {
    final failed = _failureOf(condition?.value, message?.value);
    if (failed == null) continue;
    if (failed.isError) return failed;
    first ??= failed;
  }
  return first;
}

typedef _ResolvedRule = ({
  ReadonlySignal<Object?>? condition,
  ReadonlySignal<Object?>? message,
});

/// The rules of a component, resolved once per list of rules.
final Expando<(List<Object?>, List<_ResolvedRule>)> _rulesByContext = Expando();

List<_ResolvedRule> _resolvedRules(
  ComponentContext context,
  List<Object?> rules,
) {
  final cached = _rulesByContext[context];
  if (cached != null && identical(cached.$1, rules)) return cached.$2;
  final data = context.dataContext;
  // The engine resolves the same conditions and reports their errors and
  // missing data; this context stays quiet so each is reported once. Under
  // a validation scope, a validator called in a condition keeps its
  // validation result (its message and code), as CopilotKit's resolver
  // keeps it for a check's condition alone.
  final quiet = ComponentContext(
    context.surface,
    context.componentModel,
    basePath: data.path,
    index: data.index,
    parentDataContext: validationScope(data),
    onError: (_) {},
    onMissingData: (_) {},
  ).dataContext;
  ReadonlySignal<Object?>? resolve(Object? value) =>
      value == null ? null : quiet.resolveSignal(value);
  final resolved = [
    for (final rule in rules)
      if (rule is Map)
        (
          condition: resolve(rule['condition']),
          message: resolve(rule['message']),
        )
      else
        (condition: null, message: null),
  ];
  _rulesByContext[context] = (rules, resolved);
  return resolved;
}

/// The failure of one check whose condition resolved to [condition], or
/// null when it passes or is not known yet.
FailedCheck? _failureOf(Object? condition, Object? message) {
  final own = message is String ? message : null;
  if (condition == null) return null;
  if (condition is bool) {
    return condition
        ? null
        : FailedCheck(
            message: own ?? defaultCheckMessage,
            severity: A2uiCheckSeverity.error,
          );
  }
  final (valid, resultMessage, severity, code) = switch (condition) {
    ValidationResult(
      :final valid,
      :final message,
      :final severity,
      :final code,
    ) =>
      (valid, message, severity, code),
    {'valid': final bool valid} && final Map<Object?, Object?> map => (
      valid,
      map['message'],
      map['severity'],
      map['code'],
    ),
    // CopilotKit's schema takes only a boolean or a validation result.
    _ => (true, null, null, null),
  };
  if (valid) return null;
  return FailedCheck(
    message:
        own ?? (resultMessage is String ? resultMessage : defaultCheckMessage),
    severity: A2uiCheckSeverity.fromWire(severity) ?? A2uiCheckSeverity.error,
    code: code is String ? code : null,
  );
}

/// Whether [value] counts as filled in for showing checks (CopilotKit's
/// `useChecks`): not null, "", false or an empty list.
bool hasCheckValue(Object? value) =>
    value != null &&
    value != '' &&
    value != false &&
    !(value is List && value.isEmpty);

/// The `aria-invalid` of a control whose failed check [shown] shows (null
/// when none shows): invalid while that check is an error, or while
/// [invalid] (TextField's `invalid` prop) holds. CopilotKit's `useChecks`
/// gives `invalid: isShown && failed.severity === "error"`
/// (standard/checks.ts:21-24), which each control writes into its element's
/// `aria-invalid` (inputs.tsx:531, :568, :830, :1034, :1126, :1228, :1313);
/// a warning or an info shows its message and leaves the control valid.
SemanticsValidationResult checkValidation(
  FailedCheck? shown, {
  bool invalid = false,
}) => invalid || (shown?.isError ?? false)
    ? SemanticsValidationResult.invalid
    : SemanticsValidationResult.none;

/// The message of a failed check under a control: an error is an alert in
/// the danger colour; a warning (warning colour) or an info (secondary) is
/// a status. Nothing when [check] is null.
class CheckMessage extends StatelessWidget {
  /// Shows [check].
  const CheckMessage(this.check, {super.key});

  /// The check to show, or null.
  final FailedCheck? check;

  @override
  Widget build(BuildContext context) {
    final check = this.check;
    if (check == null) return const SizedBox.shrink();
    final theme = A2uiKitScope.themeOf(context);
    final base =
        DefaultTextStyle.of(context).style.fontSize ??
        theme.typography.fontSize;
    final (em, lineHeight) = textScale(A2uiTextSize.sm);
    final color = theme.color(switch (check.severity) {
      A2uiCheckSeverity.error => A2uiColorToken.textDanger,
      A2uiCheckSeverity.warning => A2uiColorToken.textWarning,
      A2uiCheckSeverity.info => A2uiColorToken.textSecondary,
    });
    // An alert or a status is announced when it appears; Flutter forbids a
    // live region on top of either role.
    return Semantics(
      container: true,
      role: check.isError ? SemanticsRole.alert : SemanticsRole.status,
      child: Text(
        check.message,
        style: TextStyle(fontSize: base * em, height: lineHeight, color: color),
      ),
    );
  }
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/checks.ts
