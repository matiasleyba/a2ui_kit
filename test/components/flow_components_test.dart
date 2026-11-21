// Widget tests of the standard Flow and FlowItem (react-core
// standard/layout.tsx:553-567): the Grid's auto-fit columns (3 by default),
// dense packing, the columns a wide span adds, the cells' aspect ratio,
// the container props, both looks and both brightnesses, and the fit at
// 320px and text scale 2.0.

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_grid.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';
import '../helpers/parity.dart';

/// A FlowItem [id] showing a Text [id], with [props].
List<Map<String, Object?>> _item(
  String id, [
  Map<String, Object?> props = const {},
]) => [
  {
    'id': id,
    'component': 'FlowItem',
    'children': ['${id}_t'],
    ...props,
  },
  {'id': '${id}_t', 'component': 'Text', 'text': id},
];

/// The box of the FlowItem showing [text]: its grid cell.
Rect _cell(WidgetTester tester, String text) => tester.getRect(
  find
      .ancestor(
        of: find.text(text, findRichText: true),
        matching: find.byType(CssGridItem),
      )
      .first,
);

/// A Flow of [items] with [props], [width] wide.
Future<ParitySurface> _flow(
  WidgetTester tester,
  List<List<Map<String, Object?>>> items, {
  Map<String, Object?> props = const {},
  double width = 600,
  double textScale = 1,
}) => renderStandard(
  tester,
  [
    {
      'id': 'root',
      'component': 'Flow',
      'children': [for (final item in items) item.first['id']],
      ...props,
    },
    for (final item in items) ...item,
  ],
  width: width,
  textScale: textScale,
);

void main() {
  group('columns', () {
    testWidgets('three columns 16px apart by default, square cells', (
      tester,
    ) async {
      await _flow(tester, [_item('a'), _item('b'), _item('c')]);
      // (600 - 2 × 16) / 3 = 189.33 > round(max(120, 520 / 3)) = 173.
      const width = (600 - 32) / 3;
      expect(_cell(tester, 'a').width, closeTo(width, 1e-6));
      expect(_cell(tester, 'b').left, closeTo(width + 16, 1e-6));
      expect(_cell(tester, 'c').left, closeTo(2 * (width + 16), 1e-6));
      // aspect-ratio 1 / 1.
      expect(_cell(tester, 'a').height, closeTo(width, 1e-6));
    });

    testWidgets('collapses towards one column on a narrow screen', (
      tester,
    ) async {
      await _flow(tester, [_item('a'), _item('b'), _item('c')], width: 390);
      // A 173px track and its gap fit twice into 406: two columns.
      expect(_cell(tester, 'a').width, closeTo((390 - 16) / 2, 1e-6));
      expect(_cell(tester, 'c').left, 0);
      expect(_cell(tester, 'c').top, greaterThan(_cell(tester, 'a').bottom));
    });

    testWidgets('`columns` and `gap` (4px steps)', (tester) async {
      await _flow(
        tester,
        [_item('a'), _item('b')],
        props: {'columns': 2, 'gap': 2},
      );
      expect(_cell(tester, 'a').width, closeTo((600 - 8) / 2, 1e-6));
      expect(_cell(tester, 'b').left, closeTo((600 - 8) / 2 + 8, 1e-6));
    });

    testWidgets('a span wider than the columns shown adds a column, as CSS '
        'adds an auto one', (tester) async {
      await _flow(tester, [
        _item('a'),
        _item('wide', {'span': 3}),
        _item('b'),
      ], width: 390);
      // Two 1fr columns and an empty auto one, each gap kept: the wide cell
      // takes the row, a one-column cell (390 - 2 × 16 - 0) / 2.
      expect(_cell(tester, 'wide').width, closeTo(390, 1e-6));
      expect(_cell(tester, 'a').width, closeTo(179, 1e-6));
      expect(_cell(tester, 'b').left, closeTo(179 + 16, 1e-6));
    });
  });

  group('packing', () {
    List<List<Map<String, Object?>>> items() => [
      _item('a'),
      _item('wide', {'span': 2}),
      _item('c'),
    ];

    testWidgets('"pack" (the default) fills a hole a wide cell left', (
      tester,
    ) async {
      await _flow(tester, items(), props: {'columns': 2});
      // a | c, then the wide cell: `grid-auto-flow: dense`.
      expect(_cell(tester, 'c').top, _cell(tester, 'a').top);
      expect(_cell(tester, 'c').left, greaterThan(0));
      expect(_cell(tester, 'wide').top, greaterThan(_cell(tester, 'a').top));
    });

    testWidgets('"fixed" keeps the cells in order', (tester) async {
      await _flow(tester, items(), props: {'columns': 2, 'layout': 'fixed'});
      // a, the wide cell on the next row, then c after it.
      expect(_cell(tester, 'c').left, 0);
      expect(_cell(tester, 'c').top, greaterThan(_cell(tester, 'wide').top));
    });

    testWidgets('rowSpan spans rows', (tester) async {
      await _flow(
        tester,
        [
          _item('tall', {'rowSpan': 2}),
          _item('b'),
          _item('c'),
        ],
        props: {'columns': 2, 'align': 'stretch'},
      );
      // b beside tall, c under b; stretched, tall fills its two rows.
      expect(_cell(tester, 'c').left, _cell(tester, 'b').left);
      expect(_cell(tester, 'c').top, greaterThan(_cell(tester, 'b').top));
      expect(
        _cell(tester, 'tall').bottom,
        closeTo(_cell(tester, 'c').bottom, 1e-6),
      );
    });

    // Tier 1 data review 3: a span or row span past what the grid can hold
    // is cssGridMaxTracks (Chromium clamps at 10,000,000 lines,
    // grid_area.h:45), where it froze the layout or ran out of memory.
    testWidgets('a span and a row span of a billion are clamped, and lay out '
        'at once', (tester) async {
      await _flow(tester, [
        _item('a', {'span': 1000000000, 'rowSpan': 1000000000}),
        _item('b'),
      ]);
      expect(tester.takeException(), isNull);
      final a = tester.widget<CssGridItem>(
        find.ancestor(of: find.text('a'), matching: find.byType(CssGridItem)),
      );
      expect(
        a.placement,
        const GridPlacement(
          span: cssGridMaxTracks,
          rowSpan: cssGridMaxTracks,
          hasAspectRatio: true,
        ),
      );
      // 1,000 columns, 999 gaps of 16px between them: far past the box,
      // as the browser's implicit grid runs past it.
      expect(_cell(tester, 'a').width, greaterThan(999 * 16));
      // `b` goes on in the next free row, at the start.
      expect(_cell(tester, 'b').left, _cell(tester, 'a').left);
    });

    test('the span CopilotKit writes, as CSS reads `span <n>`', () {
      // No declaration: falsy.
      expect(cssGridSpanOf(null), isNull);
      expect(cssGridSpanOf(0), isNull);
      expect(cssGridSpanOf(double.nan), isNull);
      // Dropped: no positive CSS integer in `String(n)`.
      expect(cssGridSpanOf(-2), isNull);
      expect(cssGridSpanOf(.5), isNull);
      expect(cssGridSpanOf(2.5), isNull);
      expect(cssGridSpanOf(1e21), isNull);
      expect(cssGridSpanOf(double.infinity), isNull);
      // Kept, at most cssGridMaxTracks.
      expect(cssGridSpanOf(1), 1);
      expect(cssGridSpanOf(3), 3);
      expect(cssGridSpanOf(1000), 1000);
      expect(cssGridSpanOf(1001), cssGridMaxTracks);
      expect(cssGridSpanOf(1e20), cssGridMaxTracks);
      expect(cssGridMaxTracks, 1000);
    });

    testWidgets('a span that is no positive whole number is one column', (
      tester,
    ) async {
      await _flow(
        tester,
        [
          _item('half', {'span': 2.5}),
          _item('none', {'span': 0}),
          _item('two', {'span': 2}),
        ],
        props: {'columns': 3},
      );
      // `grid-column: span 2.5` is invalid CSS, and CopilotKit sets none
      // for 0: each takes one column.
      final one = _cell(tester, 'half').width;
      expect(_cell(tester, 'none').width, closeTo(one, 1e-6));
      expect(_cell(tester, 'two').width, closeTo(2 * one + 16, 1e-6));
    });
  });

  group('cells', () {
    testWidgets('a cell keeps its aspect ratio, unstretched by a taller '
        'neighbour', (tester) async {
      await _flow(
        tester,
        [
          _item('square'),
          _item('tall', {'aspectRatio': '1 / 2'}),
        ],
        props: {'columns': 2},
      );
      final square = _cell(tester, 'square');
      final tall = _cell(tester, 'tall');
      expect(square.height, closeTo(square.width, 1e-6));
      expect(tall.height, closeTo(tall.width * 2, 1e-6));
      // `align-self: normal` starts a cell with an aspect ratio.
      expect(square.top, tall.top);
    });

    testWidgets('`align: "stretch"` stretches every cell to its row', (
      tester,
    ) async {
      await _flow(
        tester,
        [
          _item('square'),
          _item('tall', {'aspectRatio': '1 / 2'}),
        ],
        props: {'columns': 2, 'align': 'stretch'},
      );
      expect(
        _cell(tester, 'square').height,
        closeTo(_cell(tester, 'tall').height, 1e-6),
      );
    });

    testWidgets('a cell grows past its ratio to hold its content', (
      tester,
    ) async {
      await _flow(
        tester,
        [
          _item('wide', {'aspectRatio': '10 / 1'}),
          [
            {
              'id': 'full',
              'component': 'FlowItem',
              'aspectRatio': '30 / 1',
              'children': ['long'],
            },
            {
              'id': 'long',
              'component': 'Text',
              'text':
                  'v² = u² + 2as, from v = u + at and s = ut + ½at², '
                  'with t eliminated',
            },
          ],
        ],
        props: {'columns': 1},
      );
      final content = tester.getSize(find.textContaining('eliminated'));
      final cell = tester.getRect(
        find
            .ancestor(
              of: find.textContaining('eliminated'),
              matching: find.byType(CssGridItem),
            )
            .first,
      );
      // 600 / 30 = 20px of ratio; two lines of text need more.
      expect(content.height, greaterThan(20));
      expect(cell.height, greaterThanOrEqualTo(content.height));
      // A cell whose content fits keeps its ratio: 600 / 10.
      expect(_cell(tester, 'wide').height, closeTo(60, 1e-6));
    });

    // RULEBOOK section 2 (the node guard row): a cyclic reference's fallback
    // is a cell, as upstream's fallback `<div>` is a grid item
    // (SurfaceView.tsx:314-340); a child that has not arrived draws nothing
    // (`NodePlaceholder`, boundaries.tsx:16-18), so it takes no cell.
    testWidgets("a cycle's fallback takes a cell; a child not yet sent takes "
        'none', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['f'],
        },
        {
          'id': 'f',
          'component': 'Flow',
          'children': ['later', 'a', 'root'],
        },
        ..._item('a'),
      ], width: 600);
      final fallback = find.textContaining('cyclic reference to root');
      expect(fallback, findsOneWidget);
      expect(alertsContaining('cyclic reference to root'), findsOne);
      // `later` took no cell: `a` is the first, and the fallback the
      // second, in the next column, 16px on.
      final a = _cell(tester, 'a');
      final flow = tester.getRect(find.byType(CssGrid));
      expect(a.left, flow.left);
      final cell = tester.getRect(
        find.ancestor(of: fallback, matching: find.byType(CssGridItem)).first,
      );
      expect(cell.left, closeTo(a.right + 16, 1e-6));
      expect(cell.top, a.top);
    });

    testWidgets("a FlowItem's container props: padding, background", (
      tester,
    ) async {
      await _flow(tester, [
        _item('a', {'padding': 3, 'background': 'surface-secondary'}),
      ]);
      expect(
        tester.getTopLeft(find.text('a')).dx - _cell(tester, 'a').left,
        12,
      );
      expect(
        tester.renderObject(
          find
              .ancestor(of: find.text('a'), matching: find.byType(CssGridItem))
              .first,
        ),
        paints..something(
          paintedFill(standardLightColors[A2uiColorToken.surfaceSecondary]!),
        ),
      );
    });
  });

  group('container', () {
    testWidgets('a known role becomes semantics; onVisible fires once', (
      tester,
    ) async {
      final view = await _flow(
        tester,
        [_item('a')],
        props: {
          'role': 'list',
          'onVisible': {
            'event': {'name': 'seen'},
          },
        },
      );
      await tester.pump();
      expect(
        find.semantics.byPredicate((node) => node.role == SemanticsRole.list),
        findsOne,
      );
      expect(view.actionNames, ['seen']);
      await tester.pump();
      expect(view.actionNames, ['seen']);
    });

    for (final brightness in Brightness.values) {
      testWidgets('a background token in the playground look, '
          '${brightness.name}', (tester) async {
        final theme = A2uiKitTheme.playground(brightness);
        await pumpComponents(
          tester,
          [
            {
              'id': 'root',
              'component': 'Flow',
              'background': 'surface-secondary',
              'children': ['a'],
            },
            ..._item('a'),
          ],
          brightness: brightness,
          theme: theme,
        );
        // The Flow's own box, around its grid.
        expect(
          tester.renderObject(
            find
                .ancestor(
                  of: find.byType(CssGrid),
                  matching: find.byType(CssFlex),
                )
                .first,
          ),
          paints..something(
            paintedFill(theme.color(A2uiColorToken.surfaceSecondary)),
          ),
        );
      });
    }

    testWidgets('fits at 320px and text scale 2.0', (tester) async {
      await _flow(
        tester,
        [
          for (final (i, step) in [
            'v = u + at',
            's = ut + ½at²',
            'v² = u² + 2as',
          ].indexed)
            [
              {
                'id': 'step$i',
                'component': 'FlowItem',
                'aspectRatio': '2 / 1',
                'children': ['text$i'],
              },
              {'id': 'text$i', 'component': 'Text', 'text': 'Step: $step'},
            ],
        ],
        width: 320,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
