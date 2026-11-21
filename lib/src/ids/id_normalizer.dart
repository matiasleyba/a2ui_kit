import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/src/catalog.dart';

/// Rewrites component ids that `a2ui_core` rejects into ones it accepts,
/// and back.
///
/// CopilotKit accepts any string as a component id, and its own data uses
/// hyphens (`spacer-l`, `mapCard-title`). `a2ui_core` 0.8.0 validates A2UI
/// 1.0 strictly: an id must be a UAX #31 identifier, so such a surface
/// fails validation. Feed the agent's messages through [normalizeMessages]
/// and map what goes back to the agent with [outboundAction],
/// [outboundError] and [outboundValue]:
///
/// ```dart
/// final ids = A2uiIdNormalizer();
/// processor.processMessages(ids.normalizeMessages(fromAgent));
/// processor.model.onAction.subscribe(
///   (action) => toAgent(ids.outboundAction(action).toJson()),
/// );
/// processor.model.onError.subscribe(
///   (error) => toAgent(ids.outboundError(error).toJson()),
/// );
/// ```
///
/// An id that is already an identifier stays as it is. Any other becomes
/// one by replacing each character an identifier cannot hold with `_`
/// (`spacer-l` is `spacer_l`), with `_2`, `_3`… added if that name is
/// taken; a leading digit gets a `_` before it. The mapping is kept for the
/// normalizer's life, so one normalizer serves one conversation: the same
/// id always maps the same way, and two ids never map to one.
///
/// Ids are rewritten where the catalog's schemas put child references (a
/// child id, a child list or template, ids inside arrays of objects such as
/// `tabs[].child`), in each component's `id`, and where a Table shows a
/// component, as CopilotKit's Table reads one: the `componentId` (or `id`)
/// of a `columns` entry, and of a cell of its `rows`, given in the props or
/// in the data its `rows` binding reads. A Table's data is rewritten from
/// the message that defines the Table on, so the agent sends the Table
/// before or with its data, as it does. No other data is touched.
///
/// The keys of a component's `metadata.extensions` (`acme.track`) are
/// rewritten the same way, for the same reason: CopilotKit takes any key
/// there and reads none, `a2ui_core` rejects the component for one that is
/// no identifier. They stay rewritten in the node's `metadata`; none goes
/// back to the agent.
///
/// On the way out, a Table cell's id goes back only when the way in wrote
/// it into a Table cell or column of the same surface, since that surface
/// was created. [outboundValue] is given the surface and the data path, and
/// maps back only the cells under a Table's `rows` binding. An action's
/// context keeps no data path, so in it every map shaped as a Table cell
/// (its `componentId`, else its `id`) whose id the way in wrote into a
/// Table cell or column of the action's surface goes back with the agent's
/// id, an agent's own record of that shape included.
class A2uiIdNormalizer {
  /// A normalizer that finds child references through [catalog]'s schemas:
  /// the playground catalog's when null.
  A2uiIdNormalizer({Catalog<ComponentApi, FunctionApi>? catalog})
    : _refs = (catalog ?? playgroundCatalogApi).refMap;

  final ComponentRefMap _refs;
  final Map<String, String> _toLocal = {};
  final Map<String, String> _toAgent = {};

  /// The data paths a Table's `rows` binding reads, by surface: absolute,
  /// or relative (inside a template).
  final Map<String, Set<String>> _rowsPaths = {};

  /// The local ids the way in wrote into a Table cell or column (in props or
  /// data) in place of an agent's id, by surface: the only ids the way out
  /// maps back inside values. Forgotten with the surface, as [_rowsPaths]
  /// is.
  final Map<String, Set<String>> _cellIds = {};

  static final RegExp _notContinue = RegExp(
    r'[^\p{XID_Continue}]',
    unicode: true,
  );
  static final RegExp _start = RegExp(r'^[\p{XID_Start}_]', unicode: true);

  /// The id `a2ui_core` sees for the agent's [id].
  String localId(String id) {
    final known = _toLocal[id];
    if (known != null) return known;
    var local = isValidUax31Identifier(id) ? id : _sanitize(id);
    final base = local;
    for (var n = 2; _toAgent.containsKey(local) && _toAgent[local] != id; n++) {
      local = '${base}_$n';
    }
    _toLocal[id] = local;
    _toAgent[local] = id;
    return local;
  }

  /// The agent's id for an id [localId] made, or [local] itself when it
  /// made none.
  String agentId(String local) => _toAgent[local] ?? local;

  /// The ids that were rewritten, agent id to local id.
  Map<String, String> get rewritten => {
    for (final entry in _toLocal.entries)
      if (entry.key != entry.value) entry.key: entry.value,
  };

  static String _sanitize(String id) {
    var out = id.replaceAll(_notContinue, '_');
    if (out.isEmpty || !_start.hasMatch(out)) out = '_$out';
    return out;
  }

  /// [messages] (server-to-client A2UI messages: maps, or JSON text of
  /// them) with their component ids rewritten. The originals are not
  /// changed.
  List<Object?> normalizeMessages(List<Object?> messages) => [
    for (final message in messages) normalizeMessage(message),
  ];

  /// One server-to-client [message] with its component ids rewritten.
  Object? normalizeMessage(Object? message) {
    final decoded = message is String ? _tryDecode(message) : message;
    if (decoded is! Map) return message;
    final out = <String, Object?>{
      for (final entry in decoded.entries) '${entry.key}': entry.value,
    };
    final delete = out['deleteSurface'];
    if (delete case {'surfaceId': final String id}) _forget(id);
    final create = out['createSurface'];
    if (create is Map) {
      if (create['surfaceId'] case final String id) _forget(id);
      out['createSurface'] = _withComponents(create, dataKey: 'dataModel');
    }
    final update = out['updateComponents'];
    if (update is Map) out['updateComponents'] = _withComponents(update);
    final data = out['updateDataModel'];
    if (data is Map && data.containsKey('value')) {
      final path = data['path'];
      final surfaceId = data['surfaceId'];
      out['updateDataModel'] = {
        for (final entry in data.entries) '${entry.key}': entry.value,
        'value': _rowsData(
          surfaceId,
          path is String ? path : '/',
          data['value'],
          _cellsIn(surfaceId),
        ),
      };
    }
    return out;
  }

  /// Forgets what the way in recorded about surface [id]'s Tables.
  void _forget(String id) {
    _rowsPaths.remove(id);
    _cellIds.remove(id);
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> _withComponents(
    Map<Object?, Object?> body, {
    String? dataKey,
  }) {
    final out = <String, Object?>{
      for (final entry in body.entries) '${entry.key}': entry.value,
    };
    final surfaceId = out['surfaceId'];
    final components = out['components'];
    if (components is List) {
      out['components'] = [
        for (final c in components) _component(c, surfaceId),
      ];
    }
    if (dataKey != null && out.containsKey(dataKey)) {
      out[dataKey] = _rowsData(
        surfaceId,
        '/',
        out[dataKey],
        _cellsIn(surfaceId),
      );
    }
    return out;
  }

  Object? _component(Object? component, Object? surfaceId) {
    if (component is! Map) return component;
    final out = <String, Object?>{
      for (final entry in component.entries) '${entry.key}': entry.value,
    };
    final id = out['id'];
    if (id is String) out['id'] = localId(id);
    for (final key in const ['metadata', '@metadata']) {
      if (out[key] case {
        'extensions': final Map<Object?, Object?> extensions,
      }) {
        out[key] = {
          for (final entry in (out[key]! as Map).entries)
            '${entry.key}': entry.value,
          'extensions': _extensionKeys(extensions),
        };
      }
    }
    final type = out['component'];
    if (type is String) {
      _rewriteProps(out, type, surfaceId, skip: const {'id', 'component'});
    } else if (type is Map && type.length == 1) {
      // The v0.9 shape: {"component": {"Text": {...props}}}.
      final name = '${type.keys.single}';
      final props = type.values.single;
      if (props is Map) {
        final rewritten = <String, Object?>{
          for (final entry in props.entries) '${entry.key}': entry.value,
        };
        _rewriteProps(rewritten, name, surfaceId);
        out['component'] = {name: rewritten};
      }
    }
    return out;
  }

  /// [extensions] (a component's `metadata.extensions`) with each key that
  /// is not a UAX #31 identifier rewritten as an id is ([_sanitize], then
  /// `_2`, `_3`… past a key taken), its value kept. CopilotKit accepts any
  /// key there (validate-operation.ts:373-379) and reads none of it
  /// (`A2UI_COMPONENT_ENVELOPE_KEYS`); `a2ui_core` 0.8.0 rejects the whole
  /// component for one such key (validator.dart:527-543). Nothing maps them
  /// back: no extension reaches the agent.
  static Map<String, Object?> _extensionKeys(Map<Object?, Object?> extensions) {
    bool valid(Object? key) => key is String && isValidUax31Identifier(key);
    final taken = {
      for (final key in extensions.keys)
        if (valid(key)) key! as String,
    };
    final out = <String, Object?>{};
    for (final MapEntry(:key, :value) in extensions.entries) {
      if (valid(key)) {
        out[key! as String] = value;
        continue;
      }
      final base = _sanitize('$key');
      var name = base;
      for (var n = 2; taken.contains(name); n++) {
        name = '${base}_$n';
      }
      taken.add(name);
      out[name] = value;
    }
    return out;
  }

  void _rewriteProps(
    Map<String, Object?> props,
    String type,
    Object? surfaceId, {
    Set<String> skip = const {},
  }) {
    final fields = _refs.fieldsFor(type);
    for (final key in props.keys.toList()) {
      if (skip.contains(key)) continue;
      final kind = fields[key];
      if (kind != null) {
        props[key] = _refsOf(props[key], kind);
      } else if (type == 'Table' && key == 'columns') {
        props[key] = _tableColumns(props[key], _cellsIn(surfaceId));
      } else if (type == 'Table' && key == 'rows') {
        final rows = props[key];
        if (rows case {'@path': final String path}) {
          if (surfaceId is String) {
            (_rowsPaths[surfaceId] ??= {}).add(
              path.length > 1 && path.endsWith('/')
                  ? path.substring(0, path.length - 1)
                  : path,
            );
          }
        } else {
          props[key] = _tableRows(rows, _cellsIn(surfaceId));
        }
      }
    }
  }

  /// The component id a Table cell or column shows, as CopilotKit's
  /// `cellComponentId` reads it: a `componentId` string, else an `id`
  /// string; the map with that id rewritten, its other keys kept.
  Object? _tableCell(Object? cell, String Function(String id) map) {
    if (cell is! Map) return cell;
    final key = _cellKey(cell);
    if (key == null) return cell;
    return {
      for (final entry in cell.entries) '${entry.key}': entry.value,
      key: map(cell[key]! as String),
    };
  }

  /// The key of a cell's component id, as CopilotKit's `cellComponentId`
  /// reads it: `componentId` when it is a string, else `id`; null for none.
  static String? _cellKey(Map<Object?, Object?> cell) =>
      cell['componentId'] is String
      ? 'componentId'
      : cell['id'] is String
      ? 'id'
      : null;

  /// The way in's map for a cell's id on [surfaceId]: [localId], with each
  /// id it changed remembered as one of that surface's cell ids.
  String Function(String id) _cellsIn(Object? surfaceId) => (id) {
    final local = localId(id);
    if (local != id && surfaceId is String) {
      (_cellIds[surfaceId] ??= {}).add(local);
    }
    return local;
  };

  /// The way out's map for a cell's id on [surfaceId]: the agent's id for
  /// one the way in wrote into a cell of that surface, any other id as it
  /// is.
  String Function(String id) _cellsOut(String surfaceId) {
    final known = _cellIds[surfaceId] ?? const <String>{};
    return (id) => known.contains(id) ? agentId(id) : id;
  }

  /// A Table's `columns`: a `{label, componentId}` entry shows the
  /// component after the label, and a `{componentId}` or `{id}` entry
  /// shows the component alone. An `id` beside a `label` is no reference:
  /// CopilotKit's schema drops it.
  Object? _tableColumns(Object? columns, String Function(String id) map) {
    if (columns is! List) return columns;
    return [
      for (final column in columns)
        if (column is! Map || !column.containsKey('label'))
          _tableCell(column, map)
        else if (column['componentId'] case final String id)
          {
            for (final entry in column.entries) '${entry.key}': entry.value,
            'componentId': map(id),
          }
        else
          column,
    ];
  }

  Object? _tableRows(Object? rows, String Function(String id) map) {
    if (rows is! List) return rows;
    return [for (final row in rows) _tableRow(row, map)];
  }

  Object? _tableRow(Object? row, String Function(String id) map) {
    if (row is! List) return row;
    return [for (final cell in row) _tableCell(cell, map)];
  }

  /// [value], at [path] of [surfaceId]'s data model, with the id of each
  /// cell of a Table's `rows` data in it passed through [map]: the way in's
  /// [_cellsIn] or the way out's [_cellsOut].
  Object? _rowsData(
    Object? surfaceId,
    String path,
    Object? value,
    String Function(String id) map,
  ) {
    final patterns = surfaceId is String ? _rowsPaths[surfaceId] : null;
    if (patterns == null || patterns.isEmpty) return value;
    bool isRows(String at) => patterns.any(
      (rows) => rows.startsWith('/') ? at == rows : at.endsWith('/$rows'),
    );
    final base = path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : (path.isEmpty ? '/' : path);
    // A write of one row, or of one cell, of a Table's rows.
    final segments = base == '/' ? <String>[] : base.substring(1).split('/');
    if (segments.isNotEmpty &&
        isRows(_pointer(segments.sublist(0, segments.length - 1)))) {
      return _tableRow(value, map);
    }
    if (segments.length > 1 &&
        isRows(_pointer(segments.sublist(0, segments.length - 2)))) {
      return _tableCell(value, map);
    }
    Object? walk(Object? node, String at) {
      if (isRows(at)) return _tableRows(node, map);
      if (node is Map) {
        return {
          for (final entry in node.entries)
            '${entry.key}': walk(entry.value, _childPath(at, '${entry.key}')),
        };
      }
      if (node is List) {
        return [
          for (var i = 0; i < node.length; i++)
            walk(node[i], _childPath(at, '$i')),
        ];
      }
      return node;
    }

    return walk(value, base);
  }

  static String _pointer(List<String> segments) =>
      segments.isEmpty ? '/' : '/${segments.join('/')}';

  static String _childPath(String at, String key) {
    final escaped = key.replaceAll('~', '~0').replaceAll('/', '~1');
    return at == '/' ? '/$escaped' : '$at/$escaped';
  }

  /// [value] with the ids a reference of [kind] holds rewritten.
  Object? _refsOf(Object? value, RefKind kind) {
    switch (kind) {
      case SingleRef():
        return value is String ? localId(value) : value;
      case ListRef():
        if (value is List) {
          return [
            for (final id in value)
              if (id is String) localId(id) else id,
          ];
        }
        if (value is Map && value['componentId'] is String) {
          return {
            for (final entry in value.entries) '${entry.key}': entry.value,
            'componentId': localId(value['componentId']! as String),
          };
        }
        return value;
      case NestedRef(:final fields, :final includesIds):
        if (value is! List) return value;
        return [
          for (final item in value)
            if (item is String && includesIds)
              localId(item)
            else if (item is Map)
              {
                for (final entry in item.entries)
                  '${entry.key}': switch (fields['${entry.key}']) {
                    final RefKind inner => _refsOf(entry.value, inner),
                    null => entry.value,
                  },
              }
            else
              item,
        ];
    }
  }

  /// [value] going back to the agent from an action's context, where no
  /// data path survives, with the id of each map shaped as a Table cell
  /// (its `componentId` string, else its `id` string, as [_tableCell] reads
  /// it) passed through [map] (the way out's [_cellsOut]). Any other `id`
  /// or `componentId` goes back as it is. Data bindings and calls are left
  /// alone.
  Object? _cellsBack(Object? value, String Function(String id) map) {
    if (value is List) {
      return [for (final item in value) _cellsBack(item, map)];
    }
    if (value is! Map) return value;
    if (value.containsKey('@path') || value.containsKey('@call')) {
      return value;
    }
    final key = _cellKey(value);
    return {
      for (final entry in value.entries)
        '${entry.key}': switch (entry.value) {
          final String id when entry.key == key => map(id),
          final inner => _cellsBack(inner, map),
        },
    };
  }

  /// [action] as the agent knows it: its source component's id mapped
  /// back, and, in its context (a Table row it sends), the id of each map
  /// shaped as a Table cell that the way in wrote into a Table cell or
  /// column of the action's surface. The context holds no data path, so an
  /// agent's own record there whose `componentId` (else `id`) equals such
  /// an id is mapped back too.
  A2uiRendererAction outboundAction(A2uiRendererAction action) {
    final mapped = _cellsBack(action.context, _cellsOut(action.surfaceId));
    return A2uiRendererAction(
      name: action.name,
      surfaceId: action.surfaceId,
      sourceComponentId: agentId(action.sourceComponentId),
      timestamp: action.timestamp,
      context: (mapped! as Map).cast(),
      userMessage: action.userMessage,
      catalogId: action.catalogId,
      metadata: action.metadata,
    );
  }

  /// [error] as the agent knows it: rewritten ids mapped back in its
  /// message (where `a2ui_core` quotes them), in the segments of its path
  /// that name a component (`/components/<id>`), and in its details. The
  /// message, path and details of a data error speak of the agent's data
  /// and are never changed.
  A2uiRendererError outboundError(A2uiRendererError error) {
    final changed = rewritten.map((agent, local) => MapEntry(local, agent));
    if (changed.isEmpty) return error;
    final isData = _dataErrorCodes.contains(error.code);
    var message = error.message;
    if (!isData) {
      for (final MapEntry(key: local, value: agent) in changed.entries) {
        message = message
            .replaceAll("'$local'", "'$agent'")
            .replaceAll('"$local"', '"$agent"');
      }
    }
    return A2uiRendererError(
      code: error.code,
      surfaceId: error.surfaceId,
      message: message,
      path: isData ? error.path : _componentPath(error.path, changed),
      functionCallId: error.functionCallId,
      details: isData ? error.details : _back(error.details, changed),
      additionalProperties: error.additionalProperties,
    );
  }

  /// The codes of errors whose path is a data model path.
  static const Set<String> _dataErrorCodes = {
    'DATA_ERROR',
    'MISSING_DATA_BINDING',
  };

  /// [path], a pointer into a message, with each segment after a
  /// `components` segment that is a rewritten id (not an index) mapped
  /// back.
  static String? _componentPath(String? path, Map<String, String> changed) {
    if (path == null) return null;
    final segments = path.split('/');
    for (var i = 1; i < segments.length; i++) {
      if (segments[i - 1] == 'components') {
        segments[i] = changed[segments[i]] ?? segments[i];
      }
    }
    return segments.join('/');
  }

  /// [value], read at [path] of [surfaceId]'s data model (the whole model
  /// at `/`, as a2ui_core's `getRendererDataModel` gives it), as the agent
  /// knows it: under a Table's `rows` binding on that surface, each cell's
  /// id (its `componentId` string, else its `id` string) that the way in
  /// wrote into a Table cell of the surface goes back to the agent's id.
  /// Nothing else changes, so an agent's own record elsewhere goes back as
  /// it is, whatever its ids.
  Object? outboundValue(
    Object? value, {
    required String surfaceId,
    String path = '/',
  }) => _rowsData(surfaceId, path, value, _cellsOut(surfaceId));

  Object? _back(Object? value, Map<String, String> changed) => switch (value) {
    final String s => changed[s] ?? s,
    final List<Object?> l => [for (final v in l) _back(v, changed)],
    final Map<Object?, Object?> m => {
      for (final e in m.entries) e.key: _back(e.value, changed),
    },
    _ => value,
  };
}

// PORT STATUS: confidence=medium todos=0 upstream=none
