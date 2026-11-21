// The id normaliser: CopilotKit's own data (hyphenated ids) through
// a2ui_core's strict A2UI 1.0 validation, without the tests' own rewrite.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

Map<String, Object?> _surface(List<Map<String, Object?>> components) => {
  'version': '1.0',
  'createSurface': {
    'surfaceId': testSurfaceId,
    'catalogId': kA2uiPlaygroundCatalogId,
    'components': components,
  },
};

Map<String, Object?> _table(Object? rows, {Object? columns}) => {
  'version': '1.0',
  'updateComponents': {
    'surfaceId': 's',
    'components': [
      {
        'id': 'tbl',
        'component': 'Table',
        'columns': ?columns,
        'rows': rows,
        'cellComponents': ['hdr-icon', 'badge-ok'],
      },
    ],
  },
};

Object? _dataValue(A2uiIdNormalizer ids, String path, Object? value) =>
    ((ids.normalizeMessage({
              'version': '1.0',
              'updateDataModel': {
                'surfaceId': 's',
                'path': path,
                'value': value,
              },
            })!
            as Map)['updateDataModel']!
        as Map)['value'];

void main() {
  group('A2uiIdNormalizer and Tables', () {
    test('rewrites the components of columns and of literal rows', () {
      final ids = A2uiIdNormalizer();
      final out = ids.normalizeMessage(
        _table(
          [
            [
              {'id': 'badge-ok'},
              {'componentId': 'badge-ok', 'note': 'kept'},
              {'other': 'x-1'},
              'Ada',
            ],
          ],
          columns: [
            {'label': 'Status', 'componentId': 'hdr-icon', 'align': 'end'},
            {'id': 'hdr-icon'},
            {'label': 'Name', 'id': 'not-a-ref'},
            'Name',
          ],
        ),
      )!;
      final table =
          (((out as Map)['updateComponents']! as Map)['components']! as List)
                  .single
              as Map;
      expect(table['columns'], [
        {'label': 'Status', 'componentId': 'hdr_icon', 'align': 'end'},
        {'id': 'hdr_icon'},
        {'label': 'Name', 'id': 'not-a-ref'},
        'Name',
      ]);
      expect(table['rows'], [
        [
          {'id': 'badge_ok'},
          {'componentId': 'badge_ok', 'note': 'kept'},
          {'other': 'x-1'},
          'Ada',
        ],
      ]);
      expect(table['cellComponents'], ['hdr_icon', 'badge_ok']);
    });

    test('rewrites only the data a rows binding reads', () {
      final ids = A2uiIdNormalizer()
        ..normalizeMessage(_table({'@path': '/table/rows'}));
      const cell = {'componentId': 'badge-ok'};
      expect(
        _dataValue(ids, '/', {
          'table': {
            'rows': [
              [cell, 'Ada'],
            ],
          },
          'other': [cell],
        }),
        {
          'table': {
            'rows': [
              [
                {'componentId': 'badge_ok'},
                'Ada',
              ],
            ],
          },
          'other': [cell],
        },
      );
      // One row, and one cell.
      expect(_dataValue(ids, '/table/rows/3', [cell]), [
        {'componentId': 'badge_ok'},
      ]);
      expect(_dataValue(ids, '/table/rows/3/0', cell), {
        'componentId': 'badge_ok',
      });
      expect(_dataValue(ids, '/elsewhere', cell), cell);
    });

    test('follows a relative rows binding inside a template', () {
      final ids = A2uiIdNormalizer()
        ..normalizeMessage(_table({'@path': 'rows'}));
      expect(
        _dataValue(ids, '/teams', [
          {
            'rows': [
              [
                {'id': 'badge-ok'},
              ],
            ],
          },
        ]),
        [
          {
            'rows': [
              [
                {'id': 'badge_ok'},
              ],
            ],
          },
        ],
      );
    });

    test('forgets a Table when its surface is deleted', () {
      final ids = A2uiIdNormalizer()
        ..normalizeMessage(_table({'@path': '/rows'}))
        ..normalizeMessage({
          'version': '1.0',
          'deleteSurface': {'surfaceId': 's'},
        });
      const rows = [
        [
          {'componentId': 'badge-ok'},
        ],
      ];
      expect(_dataValue(ids, '/rows', rows), rows);
    });

    test('leaves a componentId map whole outside a Table', () {
      final ids = A2uiIdNormalizer();
      final out =
          ((ids.normalizeMessage({
                        'version': '1.0',
                        'updateComponents': {
                          'surfaceId': 's',
                          'components': [
                            {
                              'id': 'chart',
                              'component': 'Text',
                              'text': 'x',
                              'extra': {'componentId': 'a-b', 'label': 'L'},
                            },
                          ],
                        },
                      })!
                      as Map)['updateComponents']!
                  as Map)['components']!
              as List;
      expect((out.single as Map)['extra'], {
        'componentId': 'a-b',
        'label': 'L',
      });
    });
  });

  group('A2uiIdNormalizer metadata', () {
    // validate-operation.ts:373-379 takes any extension key; a2ui_core
    // rejects a component for one that is no identifier.
    test('rewrites extension keys that are no identifiers, keeping values '
        'and the other keys', () {
      final ids = A2uiIdNormalizer();
      final out =
          ids.normalizeMessage(
                _surface([
                  {
                    'id': 'root',
                    'component': 'Text',
                    'text': 'x',
                    'metadata': {
                      'extensions': {
                        'acme.track': 'totals',
                        'acme_track': 'kept',
                        'plain': 1,
                        'a-b': true,
                      },
                    },
                  },
                ]),
              )!
              as Map<String, Object?>;
      final component =
          ((out['createSurface']! as Map)['components']! as List).single as Map;
      final extensions = (component['metadata']! as Map)['extensions']! as Map;
      // `acme_track` is taken by a key that is one already.
      expect(extensions, {
        'acme_track_2': 'totals',
        'acme_track': 'kept',
        'plain': 1,
        'a_b': true,
      });
      for (final key in extensions.keys) {
        expect(isValidUax31Identifier(key as String), isTrue);
      }
      // The component's own props are untouched.
      expect(component['text'], 'x');
    });

    test('a component with such a key is taken, with no error', () {
      List<ErrorMessage> process(List<Object?> messages) {
        final surfaces = TestSurfaces();
        addTearDown(surfaces.dispose);
        return surfaces.processor.processMessagesWithErrors(messages);
      }

      final messages = [
        _surface([
          {
            'id': 'root',
            'component': 'Text',
            'text': 'x',
            '@metadata': {
              'extensions': {'acme.track': 'totals'},
            },
          },
        ]),
      ];
      // a2ui_core alone refuses it.
      expect(process(messages), isNotEmpty);
      expect(process(A2uiIdNormalizer().normalizeMessages(messages)), isEmpty);
    });
  });

  group('A2uiIdNormalizer ids', () {
    test('keeps identifiers and rewrites the rest consistently', () {
      final ids = A2uiIdNormalizer();
      expect(ids.localId('root'), 'root');
      expect(ids.localId('spacer-l'), 'spacer_l');
      expect(ids.localId('spacer-l'), 'spacer_l');
      expect(ids.localId('mapCard-title'), 'mapCard_title');
      expect(ids.localId('2col'), '_2col');
      expect(ids.localId('a b.c'), 'a_b_c');
      expect(ids.agentId('spacer_l'), 'spacer-l');
      expect(ids.agentId('root'), 'root');
      expect(ids.rewritten, {
        'spacer-l': 'spacer_l',
        'mapCard-title': 'mapCard_title',
        '2col': '_2col',
        'a b.c': 'a_b_c',
      });
    });

    test('never maps two ids to one', () {
      final ids = A2uiIdNormalizer();
      expect(ids.localId('a-b'), 'a_b');
      // A real `a_b` arriving later takes another name.
      expect(ids.localId('a_b'), 'a_b_2');
      expect(ids.localId('a.b'), 'a_b_3');
      expect(ids.agentId('a_b'), 'a-b');
      expect(ids.agentId('a_b_2'), 'a_b');
      expect(ids.agentId('a_b_3'), 'a.b');
      for (final id in ['a-b', 'a_b', 'a.b']) {
        expect(isValidUax31Identifier(ids.localId(id)), isTrue);
      }
    });

    test('rewrites ids, child lists, single children, templates, nested '
        'children and cells, and nothing else', () {
      final ids = A2uiIdNormalizer();
      final out =
          ids.normalizeMessage({
                'version': '1.0',
                'updateComponents': {
                  'surfaceId': 's',
                  'components': [
                    {
                      'id': 'root-col',
                      'component': 'Column',
                      'children': ['a-1', 'b-2'],
                    },
                    {
                      'id': 'a-1',
                      'component': 'Card',
                      'child': 'card-head',
                      'children': {'componentId': 'row-t', 'path': '/rows'},
                    },
                    {
                      'id': 'b-2',
                      'component': 'Tabs',
                      'tabs': [
                        {'title': 'Spec-a', 'child': 'tab-a'},
                      ],
                    },
                    {
                      'id': 'tbl',
                      'component': 'Table',
                      'rows': [
                        [
                          'x-1',
                          {'componentId': 'cell-a'},
                        ],
                      ],
                    },
                    {'id': 'txt', 'component': 'Text', 'text': 'a-1'},
                  ],
                },
              })!
              as Map;
      final components =
          ((out['updateComponents']! as Map)['components']! as List)
              .cast<Map<Object?, Object?>>();
      expect(components[0]['id'], 'root_col');
      expect(components[0]['children'], ['a_1', 'b_2']);
      expect(components[1]['child'], 'card_head');
      expect(components[1]['children'], {
        'componentId': 'row_t',
        'path': '/rows',
      });
      expect(components[2]['tabs'], [
        {'title': 'Spec-a', 'child': 'tab_a'},
      ]);
      expect(components[3]['rows'], [
        [
          'x-1',
          {'componentId': 'cell_a'},
        ],
      ]);
      // Text is text, even when it looks like an id.
      expect(components[4]['text'], 'a-1');
    });

    test("rewrites a Table's rows data and maps it back", () {
      final ids = A2uiIdNormalizer()
        ..normalizeMessage(_table({'@path': '/rows'}));
      final value = _dataValue(ids, '/rows', [
        [
          {'componentId': 'cell-a'},
          'plain-text',
        ],
      ]);
      expect(value, [
        [
          {'componentId': 'cell_a'},
          'plain-text',
        ],
      ]);
      expect(ids.outboundValue(value, surfaceId: 's', path: '/rows'), [
        [
          {'componentId': 'cell-a'},
          'plain-text',
        ],
      ]);
      // The whole model, as getRendererDataModel gives it.
      expect(ids.outboundValue({'rows': value}, surfaceId: 's'), {
        'rows': [
          [
            {'componentId': 'cell-a'},
            'plain-text',
          ],
        ],
      });
    });

    test('maps an action and an error back to the agent ids', () {
      // `send-btn` is a Table cell's component, in the rows data.
      final ids = A2uiIdNormalizer()
        ..normalizeMessage(_table({'@path': '/rows'}));
      _dataValue(ids, '/rows', [
        [
          {'componentId': 'send-btn'},
        ],
      ]);
      final action = ids.outboundAction(
        A2uiRendererAction(
          name: 'send',
          surfaceId: 's',
          sourceComponentId: 'send_btn',
          timestamp: DateTime.utc(2026),
          context: const {
            'a': 1,
            'row': [
              {'componentId': 'send_btn'},
              {'id': 'send_btn'},
              'send_btn',
            ],
            'whole': {'componentId': 'send_btn', 'label': 'L'},
            'bound': {'@path': '/send_btn'},
          },
        ),
      );
      expect(action.sourceComponentId, 'send-btn');
      // Every Table cell form the way in rewrites comes back: a lone
      // `componentId`, an `id`, and either beside other keys.
      expect(action.context, {
        'a': 1,
        'row': [
          {'componentId': 'send-btn'},
          {'id': 'send-btn'},
          'send_btn',
        ],
        'whole': {'componentId': 'send-btn', 'label': 'L'},
        'bound': {'@path': '/send_btn'},
      });
      // One cell, and one row, of the Table's rows data.
      expect(
        ids.outboundValue(
          {'componentId': 'send_btn', 'label': 'L'},
          surfaceId: 's',
          path: '/rows/0/0',
        ),
        {'componentId': 'send-btn', 'label': 'L'},
      );
      expect(
        ids.outboundValue(
          [
            {'id': 'send_btn', 'label': 'L'},
            {'id': 'order_7'},
          ],
          surfaceId: 's',
          path: '/rows/0',
        ),
        [
          {'id': 'send-btn', 'label': 'L'},
          {'id': 'order_7'},
        ],
      );
      final error = ids.outboundError(
        A2uiRendererError(
          code: 'MISSING',
          surfaceId: 's',
          message: "Component 'send_btn' is missing a child.",
          details: {'id': 'send_btn', 'other': 'keep'},
        ),
      );
      expect(error.message, "Component 'send-btn' is missing a child.");
      expect(error.details, {'id': 'send-btn', 'other': 'keep'});
    });

    // Review 2a A1: only ids the way in wrote into a Table cell go back.
    test("leaves the agent's own ids alone, even equal to a rewritten "
        "component's", () {
      // `user-id` is a component, never a Table cell.
      final ids = A2uiIdNormalizer()
        ..normalizeMessage({
          'version': '1.0',
          'updateComponents': {
            'surfaceId': 's',
            'components': [
              {'id': 'user-id', 'component': 'Text', 'text': 'x'},
            ],
          },
        });
      expect(ids.localId('user-id'), 'user_id');
      final action = ids.outboundAction(
        A2uiRendererAction(
          name: 'save',
          surfaceId: 's',
          sourceComponentId: 'user_id',
          timestamp: DateTime.utc(2026),
          context: const {
            'record': {'id': 'user_id'},
          },
        ),
      );
      // The source component maps back; the agent's record does not.
      expect(action.sourceComponentId, 'user-id');
      expect(action.context, {
        'record': {'id': 'user_id'},
      });
      expect(
        ids.outboundValue({'id': 'user_id'}, surfaceId: 's', path: '/rec'),
        {'id': 'user_id'},
      );
      // A cell reads `componentId` before `id`: only that one went in.
      ids
        ..normalizeMessage(_table({'@path': '/rows'}))
        ..normalizeMessage({
          'version': '1.0',
          'updateDataModel': {
            'surfaceId': 's',
            'path': '/rows',
            'value': [
              [
                {'componentId': 'cell-a', 'id': 'cell-a'},
              ],
            ],
          },
        });
      expect(
        ids.outboundValue(
          {'componentId': 'cell_a', 'id': 'cell_a'},
          surfaceId: 's',
          path: '/rows/0/0',
        ),
        {'componentId': 'cell-a', 'id': 'cell_a'},
      );
      // The same map anywhere but under the rows binding is the agent's.
      expect(
        ids.outboundValue(
          {'componentId': 'cell_a'},
          surfaceId: 's',
          path: '/elsewhere',
        ),
        {'componentId': 'cell_a'},
      );
    });

    // Review 2a regen Q2 (RR28): by place, not by value.
    test("maps back only a Table's rows data, not the agent's record that "
        'equals a once-seen cell id', () {
      // `user-id` was a Table cell on surface `s`, in its rows data.
      final ids = A2uiIdNormalizer()
        ..normalizeMessage(_table({'@path': '/rows'}));
      _dataValue(ids, '/rows', [
        [
          {'componentId': 'user-id'},
        ],
      ]);
      // The agent's own record `/rec` is not under the rows binding.
      expect(
        ids.outboundValue({'id': 'user_id'}, surfaceId: 's', path: '/rec'),
        {'id': 'user_id'},
      );
      // The whole model: the rows cell goes back, the record does not.
      const rows = [
        [
          {'componentId': 'user_id'},
        ],
      ];
      const model = {
        'rec': {'id': 'user_id'},
        'rows': rows,
      };
      expect(ids.outboundValue(model, surfaceId: 's'), {
        'rec': {'id': 'user_id'},
        'rows': [
          [
            {'componentId': 'user-id'},
          ],
        ],
      });
      // Another surface never had the Table: nothing goes back there.
      expect(ids.outboundValue(rows, surfaceId: 't', path: '/rows'), rows);
      A2uiRendererAction save(String surfaceId) => ids.outboundAction(
        A2uiRendererAction(
          name: 'save',
          surfaceId: surfaceId,
          sourceComponentId: 'btn',
          timestamp: DateTime.utc(2026),
          context: const {
            'record': {'id': 'user_id'},
          },
        ),
      );
      expect(save('t').context, {
        'record': {'id': 'user_id'},
      });
      // The residual rule: an action's context keeps no data path, so on
      // the surface whose Table had the cell, a cell-shaped map maps back.
      expect(save('s').context, {
        'record': {'id': 'user-id'},
      });
      // Deleting the surface forgets its cells; so does re-creating it.
      ids.normalizeMessage({
        'version': '1.0',
        'deleteSurface': {'surfaceId': 's'},
      });
      expect(save('s').context, {
        'record': {'id': 'user_id'},
      });
      ids
        ..normalizeMessage(_table({'@path': '/rows'}))
        ..normalizeMessage({
          'version': '1.0',
          'updateDataModel': {
            'surfaceId': 's',
            'path': '/rows',
            'value': [
              [
                {'componentId': 'user-id'},
              ],
            ],
          },
        })
        ..normalizeMessage({
          'version': '1.0',
          'createSurface': {
            'surfaceId': 's',
            'catalogId': kA2uiPlaygroundCatalogId,
            'components': <Object?>[],
          },
        });
      expect(save('s').context, {
        'record': {'id': 'user_id'},
      });
    });

    test("never maps an error's data path, only component segments", () {
      final ids = A2uiIdNormalizer()
        ..localId('first-name')
        ..localId('send-btn');
      A2uiRendererError error(String code, String path) => ids.outboundError(
        A2uiRendererError(
          code: code,
          surfaceId: 's',
          message: "Value 'first_name' at \"first_name\"",
          path: path,
          details: code == 'DATA_ERROR' ? const {'value': 'first_name'} : null,
        ),
      );
      expect(error('DATA_ERROR', '/user/first_name').path, '/user/first_name');
      expect(error('DATA_ERROR', '/user/first_name').details, {
        'value': 'first_name',
      });
      // A data error's message quotes the agent's data, not component ids.
      for (final code in ['DATA_ERROR', 'MISSING_DATA_BINDING']) {
        expect(
          error(code, '/user/first_name').message,
          "Value 'first_name' at \"first_name\"",
        );
      }
      expect(
        error('VALIDATION_FAILED', '/components/x').message,
        "Value 'first-name' at \"first-name\"",
      );
      expect(
        error('VALIDATION_FAILED', '/user/first_name').path,
        '/user/first_name',
      );
      expect(
        error('VALIDATION_FAILED', '/components/send_btn/child').path,
        '/components/send-btn/child',
      );
      expect(
        error('VALIDATION_FAILED', '/components/0/first_name').path,
        '/components/0/first_name',
      );
    });

    test('leaves JSON text it cannot read alone', () {
      expect(A2uiIdNormalizer().normalizeMessage('not json'), 'not json');
    });

    test('reads a message given as JSON text', () {
      final out =
          A2uiIdNormalizer().normalizeMessage(
                '{"version":"1.0","updateComponents":{"surfaceId":"s",'
                '"components":[{"id":"a-b","component":"Text","text":"x"}]}}',
              )!
              as Map;
      expect(
        ((out['updateComponents']! as Map)['components']! as List).single,
        {'id': 'a_b', 'component': 'Text', 'text': 'x'},
      );
    });
  });

  group('playground data without the test rewrite', () {
    testWidgets('a hyphenated surface fails a2ui_core without the '
        'normaliser and renders with it', (tester) async {
      final components = [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['title-1', 'send-btn'],
        },
        {'id': 'title-1', 'component': 'Title', 'text': 'Hello'},
        {
          'id': 'send-btn',
          'component': 'Button',
          'label': 'Send',
          'onClick': {
            'event': {'name': 'send'},
          },
        },
      ];
      final raw = TestSurfaces()..apply([_surface(components)]);
      addTearDown(raw.dispose);
      expect(raw.errors, isNotEmpty);

      final ids = A2uiIdNormalizer();
      final surfaces = TestSurfaces()
        ..apply(ids.normalizeMessages([_surface(components)]));
      addTearDown(surfaces.dispose);
      expect(surfaces.errors, isEmpty);
      await tester.pumpWidget(surfaceApp(surfaces.surface));
      expect(find.text('Hello', findRichText: true), findsOneWidget);
      await tester.tap(find.text('Send', findRichText: true));
      await tester.pump();
      expect(surfaces.actions, hasLength(1));
      expect(surfaces.actions.single.sourceComponentId, 'send_btn');
      expect(
        ids.outboundAction(surfaces.actions.single).sourceComponentId,
        'send-btn',
      );
    });

    testWidgets('standard-all.json renders with no error', (tester) async {
      final standardAll = fixture('standard-all.json')! as Map;
      final ids = A2uiIdNormalizer();
      final surfaces = TestSurfaces()
        ..apply(
          ids.normalizeMessages([
            {
              'version': '1.0',
              'createSurface': {
                'surfaceId': testSurfaceId,
                'catalogId': kA2uiPlaygroundCatalogId,
                'components': standardAll['components'],
                'dataModel': standardAll['data'],
              },
            },
          ]),
        );
      addTearDown(surfaces.dispose);
      expect(ids.rewritten, containsPair('spacer-l', 'spacer_l'));
      await tester.pumpWidget(surfaceApp(surfaces.surface, width: 320));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(surfaces.errors, isEmpty);
      expect(find.text('Standard catalog fixture'), findsOneWidget);
    });

    testWidgets('every frame of the tokyo-trip replay validates and renders', (
      tester,
    ) async {
      final frames =
          ((fixture('replays/tokyo-trip.json')! as Map)['frames']! as List)
              .cast<Map<String, Object?>>();
      for (final frame in frames) {
        final ids = A2uiIdNormalizer();
        final surfaces = TestSurfaces()
          ..apply(ids.normalizeMessages(frame['ops']! as List));
        addTearDown(surfaces.dispose);
        if (surfaces.surfaces.isEmpty) continue;
        await tester.pumpWidget(
          surfaceApp(surfaces.surfaces.values.first, width: 320),
        );
        expect(tester.takeException(), isNull);
        // Blueprint stand-ins are not in the catalog, and one mid-stream
        // Agenda fails its schema (see the port notes); no id is refused.
        for (final error in surfaces.errors) {
          expect(error.message, isNot(contains('UAX #31')));
        }
      }
      final last = A2uiIdNormalizer();
      final surfaces = TestSurfaces()
        ..apply(last.normalizeMessages(frames.last['ops']! as List));
      addTearDown(surfaces.dispose);
      expect(last.rewritten, containsPair('mapCard-title', 'mapCard_title'));
      await tester.pumpWidget(
        surfaceApp(surfaces.surfaces.values.first, width: 720),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Tokyo', findRichText: true), findsWidgets);
    });
  });
}
