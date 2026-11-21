// The dry baseline of an Svg and of a Table (tier 1 data review, promoted):
// a baseline-aligned Row and a WidgetSpan ask it of what they hold, and a
// null answer made the proxies above (a2ui_flutter's NodeView semantics, a
// SizedBox) fall back to `RenderBox.computeDryBaseline`, which throws in
// debug (proxy_box.dart:104-107). Each answers the baseline its layout has:
// an `<svg>`'s bottom edge (CSS 2.1 section 10.8.1); a Table's scroll
// wrapper's bottom edge (a scroll container's, CSS Align 3 section 9.1),
// and inside it the table's first cell's (its first line's, else its
// content edge's bottom, CSS 2.1 section 17.5.3).

import 'package:a2ui_flutter/a2ui_flutter.dart' show A2uiSurface;
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/layout/html_table.dart'
    show HtmlTableCellBox, RenderHtmlTable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

const _box = Key('box');

/// [components] as a surface 120px wide, inside [around].
Future<void> _pump(
  WidgetTester tester,
  List<Map<String, Object?>> components,
  Widget Function(Widget surface) around,
) async {
  final surfaces = TestSurfaces()..create(components);
  addTearDown(surfaces.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [A2uiKitTheme.standard(Brightness.light)]),
      home: Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: around(
            SizedBox(
              key: _box,
              width: 120,
              child: A2uiSurface(surface: surfaces.surface),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

const TextStyle _style = TextStyle(fontSize: 20);

Widget _row(Widget surface) => Row(
  crossAxisAlignment: CrossAxisAlignment.baseline,
  textBaseline: TextBaseline.alphabetic,
  children: [
    const Text('Ab', style: _style),
    surface,
  ],
);

Widget _span(Widget surface) => Text.rich(
  key: const Key('line'),
  style: _style,
  TextSpan(
    text: 'Ab ',
    children: [
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: surface,
      ),
    ],
  ),
);

/// Where the line's baseline is, down the page: the top of the paragraph
/// that starts "Ab" and its alphabetic baseline (a paragraph's dry
/// baseline is its laid-out one).
double _textBaseline(WidgetTester tester) {
  final text = find.textContaining('Ab', findRichText: true).first;
  final paragraph = tester.renderObject<RenderParagraph>(text);
  return tester.getTopLeft(text).dy +
      paragraph.getDryBaseline(paragraph.constraints, TextBaseline.alphabetic)!;
}

final List<Map<String, Object?>> _svg = [
  {
    'id': 'root',
    'component': 'Svg',
    'width': 40,
    'height': 20,
    'texts': [
      {'x': 0, 'y': 10, 'text': 'v'},
    ],
  },
];

// The header's first cell is empty: no line, so its content edge's bottom.
final List<Map<String, Object?>> _table = [
  {
    'id': 'root',
    'component': 'Table',
    'columns': ['', 'Mon'],
    'rows': [
      ['Run', '5 km'],
    ],
  },
];

void main() {
  for (final (name, components) in [('Svg', _svg), ('Table', _table)]) {
    group(name, () {
      testWidgets('in a baseline-aligned Row: its bottom on the baseline, '
          'and the dry layout the same', (tester) async {
        await _pump(tester, components, _row);
        expect(
          tester.getBottomLeft(find.byKey(_box)).dy,
          closeTo(_textBaseline(tester), 1e-6),
        );
        final row = tester.renderObject<RenderFlex>(find.byType(Row));
        // Asks each child's dry baseline (it threw in debug), and lays
        // them out as the layout did.
        expect(row.getDryLayout(row.constraints), row.size);
        final box = tester.renderObject<RenderBox>(find.byKey(_box));
        expect(
          box.getDryBaseline(box.constraints, TextBaseline.alphabetic),
          box.size.height,
        );
      });

      testWidgets("as a WidgetSpan: on the line's baseline, and the "
          "paragraph's intrinsics and dry layout the same", (tester) async {
        await _pump(tester, components, _span);
        // Within half a pixel: SkParagraph sets a placeholder on whole
        // pixels of the line (a baseline-aligned box half its height above
        // the line would sit apart by its height, 20px or more).
        expect(
          tester.getBottomLeft(find.byKey(_box)).dy,
          closeTo(_textBaseline(tester), .5),
        );
        final line = tester.renderObject<RenderParagraph>(
          find
              .descendant(
                of: find.byKey(const Key('line')),
                matching: find.byType(RichText),
              )
              .first,
        );
        expect(line.getMaxIntrinsicWidth(double.infinity), greaterThan(120));
        expect(line.getDryLayout(line.constraints), line.size);
      });
    });
  }

  testWidgets("a table's baseline is its first cell's: an empty one's "
      "content edge's bottom", (tester) async {
    await _pump(tester, _table, _row);
    // The empty header cell's content edge is its 8px top padding, its
    // content none: the cell's (and the table's) baseline is 8px down.
    final cell = tester.renderObject<RenderBox>(
      find.byType(HtmlTableCellBox).first,
    );
    expect(cell.size.height, 16);
    expect(cell.getDryBaseline(cell.constraints, TextBaseline.alphabetic), 8);
    final table = tester.renderObject<RenderHtmlTable>(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == 'HtmlTable'),
    );
    expect(table.getDryBaseline(table.constraints, TextBaseline.alphabetic), 8);
  });
}
