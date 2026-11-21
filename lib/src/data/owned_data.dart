// A port of the user-owned values of CopilotKit's surface manager
// (`setOwnedValue`, `mergeOwnedValues`, `isAtOrBelow` and `normalizePath`
// in packages/core/src/generative-ui/surface-manager.ts, MIT, (c) Atai
// Barkai), and of how its SurfaceView marks what an input writes.

import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';

/// Keeps what the user entered from being overwritten by the agent, as
/// CopilotKit's surface manager does.
///
/// When an input writes to its bound path, the path becomes user-owned.
/// Pass the agent's messages through [filterMessages] before the processor
/// sees them: an agent write to a user-owned path, or below one, is
/// dropped, and a write above one keeps the user's values inside it.
/// Ownership ends when the surface is deleted.
///
/// ```dart
/// final owned = A2uiUserOwnedData(processor);
/// processor.processMessages(owned.filterMessages(fromAgent));
/// ```
///
/// With an `A2uiIdNormalizer`, normalise first:
/// `owned.filterMessages(ids.normalizeMessages(fromAgent))`.
///
/// For example, once the user types "Ada" into a field bound to
/// `/form/name`, the agent's `{"path": "/form", "value": {"name": ""}}`
/// writes `{"name": "Ada"}`, and its `{"path": "/form/name", "value":
/// "Bob"}` is dropped.
class A2uiUserOwnedData {
  /// Guards the surfaces of [processor].
  A2uiUserOwnedData(MessageProcessor<ComponentApi> processor)
    : _surfaceOf = processor.model.getSurface;

  final SurfaceModel<ComponentApi>? Function(String id) _surfaceOf;

  static final Expando<Map<String, Object?>> _owned = Expando(
    'a2ui_kit user-owned values',
  );

  /// The values the user wrote to [surface], by absolute path.
  static Map<String, Object?> ownedValuesOf(
    SurfaceModel<ComponentApi> surface,
  ) => Map.unmodifiable(_owned[surface] ?? const <String, Object?>{});

  /// Writes the user's [value] at the absolute [path] of [surface]'s data
  /// model and marks the path user-owned, as CopilotKit's `setOwnedValue`
  /// does. The kit's inputs do this for each edit; an override builder
  /// that writes data does it too.
  ///
  /// Throws an [A2uiDataError] when the data model refuses the write; the
  /// path is then not marked.
  static void setOwnedValue(
    SurfaceModel<ComponentApi> surface,
    String path,
    Object? value,
  ) {
    final normalized = normalizePath(path);
    surface.dataModel.set(normalized, value);
    markOwned(surface, normalized, value);
  }

  /// Marks the absolute [path] of [surface] user-owned with [value], which
  /// the data model already holds.
  static void markOwned(
    SurfaceModel<ComponentApi> surface,
    String path,
    Object? value,
  ) {
    (_owned[surface] ??= {})[normalizePath(path)] = _copy(value);
  }

  /// [messages] from the agent, with writes to user-owned data dropped or
  /// merged. Messages may be maps or JSON text, as the processor takes.
  List<Object?> filterMessages(List<Object?> messages) {
    // A surface deleted earlier in this batch has no owned values left,
    // though the processor still holds it. Only a delete ends ownership, as
    // in CopilotKit: a `createSurface` for a surface that exists is
    // refused, and the old surface keeps what the user entered.
    final deleted = <String>{};
    return [
      for (final message in messages)
        if (_filter(message, deleted) case (:final Object? kept)) kept,
    ];
  }

  /// [message], changed or dropped (null record).
  ({Object? kept})? _filter(Object? message, Set<String> deleted) {
    final decoded = message is String ? _tryDecode(message) : message;
    if (decoded is! Map) return (kept: message);
    if (decoded['deleteSurface'] case {'surfaceId': final String id}) {
      deleted.add(id);
    }
    final update = decoded['updateDataModel'];
    if (update is! Map) return (kept: message);
    // From v1.0 a write without a value is invalid: the processor reports
    // it, so it passes as sent rather than gaining the merged value.
    if (!update.containsKey('value') && _isV1(decoded['version'])) {
      return (kept: message);
    }
    final id = update['surfaceId'];
    if (id is! String || deleted.contains(id)) return (kept: message);
    final surface = _surfaceOf(id);
    final owned = surface == null ? null : _owned[surface];
    if (surface == null || owned == null || owned.isEmpty) {
      return (kept: message);
    }
    final rawPath = update['path'];
    final path = normalizePath(rawPath is String ? rawPath : '/');
    final Object? merged;
    try {
      final result = mergeOwnedValues(owned, path, update['value']);
      if (result == null) return null;
      if (identical(result.value, _unchanged)) return (kept: message);
      merged = result.value;
    } on A2uiDataError catch (error) {
      // CopilotKit rejects a write the user's values do not fit.
      unawaited(
        surface.dispatchError(
          A2uiRendererError(
            code: error.code,
            surfaceId: id,
            message: error.message,
            path: path,
          ),
        ),
      );
      return null;
    }
    return (
      kept: {
        for (final entry in decoded.entries) '${entry.key}': entry.value,
        'updateDataModel': {
          for (final entry in update.entries) '${entry.key}': entry.value,
          'value': merged,
        },
      },
    );
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  /// Whether [version] (a message's `version`) is v1.0 or later; true for
  /// one the processor cannot read, which it refuses anyway.
  static bool _isV1(Object? version) {
    try {
      return A2uiProtocolVersion.fromJson(
        version,
      ).isAtLeast(A2uiProtocolVersion.v1_0);
    } on Object {
      return true;
    }
  }
}

/// "/a/b/" to "/a/b". The root stays "/".
String normalizePath(String path) {
  final trimmed = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  return trimmed.isEmpty ? '/' : trimmed;
}

/// True when [path] is [ancestor] or below it.
bool isAtOrBelow(String path, String ancestor) {
  if (ancestor == '/') return true;
  return path == ancestor || path.startsWith('$ancestor/');
}

const Object _unchanged = Object();

/// The value an agent write of [value] puts at [path], with the [owned]
/// values below [path] written back into it; null when [path] is owned or
/// below an owned path, so the agent cannot write it. The value is
/// [_unchanged] when no owned value is below [path]. Throws an
/// [A2uiDataError] when an owned value does not fit the new value.
({Object? value})? mergeOwnedValues(
  Map<String, Object?> owned,
  String path,
  Object? value,
) {
  final ownedPaths = owned.keys.toList();
  if (ownedPaths.any((ownedPath) => isAtOrBelow(path, ownedPath))) {
    return null;
  }
  final below = [
    for (final ownedPath in ownedPaths)
      if (isAtOrBelow(ownedPath, path)) ownedPath,
  ];
  if (below.isEmpty) return (value: _unchanged);
  // A scratch model under "/value", so a root write merges the same way.
  final scratch = DataModel({'value': value});
  final prefix = path == '/' ? '' : path;
  for (final ownedPath in below) {
    final relative = ownedPath.substring(prefix.length);
    scratch.set('/value$relative', _copy(owned[ownedPath]));
  }
  final merged = scratch.get('/value');
  scratch.dispose();
  return (value: merged);
}

/// A deep copy of a JSON-like [value].
Object? _copy(Object? value) => switch (value) {
  final Map<Object?, Object?> map => {
    for (final entry in map.entries) entry.key: _copy(entry.value),
  },
  final List<Object?> list => [for (final item in list) _copy(item)],
  _ => value,
};

// PORT STATUS: confidence=medium todos=0 upstream=packages/core/src/generative-ui/surface-manager.ts, packages/react-core/src/v2/generative-ui/SurfaceView.tsx
