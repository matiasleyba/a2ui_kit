// Parity tests of CopilotKit's catalog export, ported from
// packages/react-core/src/v2/generative-ui/__tests__/catalog-export.test.ts
// (MIT, (c) Atai Barkai). Each test names its upstream line.
//
// Parity for: (engine)
//
// Upstream exports `standardUI` with `exportA2UICatalog`. Here that is the
// document the standard catalog writes, `a2uiKitStandardCatalog().toJson()`
// (a2ui_core's export of the catalog an app registers): the same object,
// `copilotkit/standard@1` with its 69 components. The playground catalog's
// own document (`a2uiKitCatalogDocument`, 121 components) is checked the
// same way in the group "beyond catalog-export.test.ts (ours)".
//
// Not ours:
// - catalog-export.test.ts:25, the `title` and `instructions`: the options
//   the test passes to CopilotKit's exporter ("Standard", "Use Row and
//   Column for layout."). `toJson` takes no options; the standard catalog
//   has neither (as `standardUI`), and an app that wants them builds its
//   own catalog. The rest of :25 is ported.
//
// Not ours (CopilotKit's exporter run on catalogs this package does not
// have): catalog-export.test.ts:136, :202, :255 and :351 export catalogs
// made with `createGenerativeUI` and Zod schemas in the test, and :430
// tests `argsSchemaFromSignature`, the exporter's reader of TypeScript
// signatures.

import 'dart:convert';

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:flutter_test/flutter_test.dart';

const String _common = r'common_types.json#/$defs/';

/// Upstream's `ref(name)`.
Map<String, Object?> _ref(String name) => {r'$ref': '$_common$name'};

/// A2UI_CHILD_LIST_REF and A2UI_COMPONENT_ID_REF
/// (shared/src/generative-ui/a2ui.ts).
const String _childListRef = r'common_types.json#/$defs/ChildList';
const String _componentIdRef = r'common_types.json#/$defs/ComponentId';

/// `standardUI`: the standard catalog an app registers.
final CatalogImplementation _standardUI = a2uiKitStandardCatalog();

/// `exportA2UICatalog(standardUI)`: the document it writes.
final Map<String, Object?> _catalog = _standardUI.toJson();

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;

List<Object?> _list(Object? value) => value! as List<Object?>;

Map<String, Object?> _component(String name) =>
    _map(_map(_catalog['components'])[name]);

Map<String, Object?> _function(String name) =>
    _map(_map(_catalog['functions'])[name]);

/// catalog-export.test.ts:25 for [catalog], with [id] and [size] its own:
/// a 1.0 document with every component and function listed in `$defs`,
/// which survives JSON.
void _expectListedInDefs(Map<String, Object?> catalog, String id, int size) {
  expect(catalog['protocolVersion'], '1.0');
  expect(catalog['catalogId'], id);
  final names = _map(catalog['components']).keys.toList();
  expect(names, hasLength(size));
  expect(names, isNot(contains('Surface')));
  final defs = _map(catalog[r'$defs']);
  expect(defs['anyComponent'], {
    'oneOf': [
      for (final name in names) {r'$ref': '#/components/$name'},
    ],
    'discriminator': {'propertyName': 'component'},
  });
  expect(
    [
      for (final entry in _list(_map(defs['anyFunction'])['oneOf']))
        _map(entry)[r'$ref'],
    ],
    [for (final name in _map(catalog['functions']).keys) '#/functions/$name'],
  );
  expect(jsonDecode(jsonEncode(catalog)), catalog);
}

void main() {
  group('exportA2UICatalog', () {
    // catalog-export.test.ts:25
    test('is a 1.0 catalog definition with every component and function '
        r'listed in $defs, and survives JSON', () {
      // `catalogId` is `standardUI.id`; the names number
      // `standardUI.components.size`.
      expect(_standardUI.id, 'copilotkit/standard@1');
      expect(_standardUI.components, hasLength(69));
      _expectListedInDefs(
        _catalog,
        _standardUI.id,
        _standardUI.components.length,
      );
    });

    // catalog-export.test.ts:43
    test('writes component as a const, keeps references, and lets every '
        'other prop be a value, a binding or a call', () {
      final tabs = _component('Tabs');
      expect(tabs['type'], 'object');
      expect(tabs['required'], ['component', 'tabs']);
      final properties = _map(tabs['properties']);
      expect(properties['component'], {'const': 'Tabs'});
      // The list of tabs is data, so it can be bound; the panel of a tab is
      // a reference.
      final tabsAnyOf = _list(_map(properties['tabs'])['anyOf']);
      expect(tabsAnyOf[1], _ref('DataBinding'));
      expect(tabsAnyOf[2], _ref('FunctionCall'));
      // Inside the list, each tab is dynamic too, and its title as well;
      // the panel stays a reference.
      final tab = _map(_map(tabsAnyOf[0])['items']);
      final tabAnyOf = _list(tab['anyOf']);
      expect(tabAnyOf[1], _ref('DataBinding'));
      final tabProperties = _map(_map(tabAnyOf[0])['properties']);
      expect(_map(tabProperties['title'])['anyOf'], [
        {'type': 'string'},
        _ref('DataBinding'),
        _ref('FunctionCall'),
      ]);
      final child = _map(tabProperties['child']);
      expect(child.keys, unorderedEquals([r'$ref', 'description']));
      expect(child[r'$ref'], _componentIdRef);
      expect(child['description'], isA<String>());
      // A check condition is a function call at depth two.
      final checks = _map(_map(_component('Button')['properties'])['checks']);
      final items = _map(_map(_list(checks['anyOf'])[0])['items']);
      final rule = _map(_list(items['anyOf'])[0]);
      expect(
        _list(_map(_map(rule['properties'])['condition'])['anyOf'])[2],
        _ref('FunctionCall'),
      );
      final column = _map(_component('Column')['properties']);
      expect(column['children'], {r'$ref': _childListRef});
      expect(_component('Column')['required'], ['component']);
      final button = _map(_component('Button')['properties']);
      expect(button['child'], {r'$ref': _componentIdRef});
      final onClick = _map(button['onClick']);
      expect(onClick.keys, unorderedEquals([r'$ref', 'description']));
      expect(onClick[r'$ref'], '${_common}Action');
      expect(onClick['description'], isA<String>());
      expect(_list(_map(button['label'])['anyOf'])[0], {'type': 'string'});
      expect(_component('Button')['description'], isA<String>());
    });

    // catalog-export.test.ts:83
    test('describes the built-in functions with their return type, callers '
        'and typed args', () {
      expect(_function('required'), {
        'type': 'object',
        // GENERATIVE_UI_FUNCTIONS.required.description
        // (shared/src/generative-ui/basic-functions.ts:104).
        'description': 'Valid when the value is not empty',
        'returnType': 'validationResult',
        'allowedCallers': 'rendererOnly',
        'requiresUserActivation': false,
        'properties': {
          '@call': {'const': 'required'},
          'args': {
            'type': 'object',
            'properties': {'value': _ref('DynamicValue')},
            'required': ['value'],
            'additionalProperties': false,
          },
        },
        'required': ['@call', 'args'],
      });
      final openUrl = _function('openUrl');
      expect(openUrl['returnType'], 'void');
      expect(openUrl['allowedCallers'], 'rendererOnly');
      expect(openUrl['requiresUserActivation'], true);
      // The metaschema's activation rule matches an entry without the key,
      // so every entry writes the value out.
      expect(_function('formatNumber')['requiresUserActivation'], false);
      // A list arg can be bound as a whole.
      final and = _map(_function('and')['properties']);
      expect(_map(_map(and['args'])['properties'])['values'], {
        'anyOf': [
          {'type': 'array', 'items': _ref('DynamicBoolean')},
          _ref('DataBinding'),
          _ref('FunctionCall'),
        ],
      });
      final length = _map(_function('length')['properties']);
      expect(
        _map(_map(length['args'])['properties'])['min'],
        _ref('DynamicNumber'),
      );
      expect(_map(length['args'])['required'], ['value']);
      final calc = _map(_function('calc')['properties']);
      expect(_map(calc['args'])['additionalProperties'], {
        'anyOf': [
          _ref('DynamicNumber'),
          _ref('DynamicString'),
          _ref('DynamicBoolean'),
        ],
      });
      expect(_function('series')['returnType'], 'array');
      // Object.keys(GENERATIVE_UI_FUNCTIONS), in its order.
      expect(_map(_catalog['functions']).keys, [
        'required',
        'regex',
        'length',
        'numeric',
        'email',
        'formatString',
        'formatNumber',
        'formatCurrency',
        'formatDate',
        'pluralize',
        'openUrl',
        'and',
        'or',
        'not',
        'calc',
        'series',
      ]);
    });
  });

  group('beyond catalog-export.test.ts (ours)', () {
    // The playground catalog's document, the other export this package
    // ships, held to catalog-export.test.ts:25 too.
    test('the playground document lists every component and function in '
        r'$defs, and survives JSON', () {
      _expectListedInDefs(
        a2uiKitCatalogDocument,
        kA2uiPlaygroundCatalogId,
        121,
      );
      // The standard components keep the playground's schemas.
      final playground = _map(a2uiKitCatalogDocument['components']);
      for (final MapEntry(key: name, value: schema) in _map(
        _catalog['components'],
      ).entries) {
        expect(schema, playground[name], reason: name);
      }
    });
  });
}
