// Widget tests of the standard Table, TableSection, TableRow and TableCell
// (react-core standard/data.tsx:57-357, styles.ts:71-78): the layout
// Chromium gives an HTML table, the dividers, the cells' styles, the
// sticky header, the semantics, both looks and both brightnesses, the fit
// at 320px and text scale 2.0, and updates of the nodes the Table reads.
//
// The test font draws every glyph a font size wide (14px in a cell), so
// widths are counted in glyphs: "AB" is 28px.

import 'package:a2ui_core/a2ui_core.dart' show ComponentModel;
import 'package:a2ui_flutter/a2ui_flutter.dart' show NodeKey;
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/js_json.dart';
import 'package:a2ui_kit/src/foundation/layout/html_table.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderParagraph, RenderRepaintBoundary;
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';
import '../helpers/paint_calls.dart';
import '../helpers/parity.dart';

/// The box of the cell showing [text].
Rect _cell(WidgetTester tester, String text) => tester.getRect(
  find
      .ancestor(
        of: find.text(text, findRichText: true),
        matching: find.byType(HtmlTableCell),
      )
      .first,
);

/// The min-content and max-content widths of the cell showing [text], its
/// padding included: what the table's column sizing reads.
(double, double) _widths(WidgetTester tester, String text) {
  final box = tester.renderObject<RenderBox>(
    find
        .ancestor(
          of: find.text(text, findRichText: true),
          matching: find.byType(HtmlTableCell),
        )
        .first,
  );
  return (
    box.getMinIntrinsicWidth(double.infinity),
    box.getMaxIntrinsicWidth(double.infinity),
  );
}

/// The style of the drawn text [text].
TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<RichText>(find.text(text, findRichText: true)).text.style!;

RenderHtmlTable _table(WidgetTester tester) =>
    tester.renderObject<RenderHtmlTable>(find.byType(HtmlTable));

/// A rows-mode Table of [columns] and [rows] (and [props]).
Map<String, Object?> _rowsTable(
  List<Object?> columns,
  List<List<Object?>> rows, [
  Map<String, Object?> props = const {},
]) => {
  'id': 'root',
  'component': 'Table',
  'columns': columns,
  'rows': rows,
  ...props,
};

final Color _subtle = standardLightColors[A2uiColorToken.borderSubtle]!;

/// The rects [recording] drew in [color] (compared as ARGB32).
List<Rect> _rects(TestRecordingCanvas recording, Color color) => [
  for (final call in recording.invocations)
    if (call.invocation.memberName == #drawRect &&
        (call.invocation.positionalArguments[1] as Paint).color.toARGB32() ==
            color.toARGB32())
      call.invocation.positionalArguments[0] as Rect,
];

void main() {
  group('layout', () {
    testWidgets('automatic layout: columns past their max-content share the '
        'rest by max-content', (tester) async {
      await renderStandard(tester, [
        _rowsTable(
          ['A', 'BBBB'],
          [
            ['C', 'D'],
          ],
        ),
      ]);
      // Column 0: "A" and its 8px end padding; column 1: "BBBB" and its 8px
      // start padding (one word each: min-content is max-content). Both
      // fit: the room left goes by max-content
      // (DistributeInlineSizeToComputedInlineSizeAuto, kAboveMax).
      final a = _widths(tester, 'A').$2;
      final b = _widths(tester, 'BBBB').$2;
      expect(b, greaterThan(a));
      final first = a + (360 - a - b) * a / (a + b);
      expect(_cell(tester, 'A').left, 0);
      expect(_cell(tester, 'A').width, closeTo(first, 1e-6));
      expect(_cell(tester, 'BBBB').left, closeTo(first, 1e-6));
      expect(_cell(tester, 'BBBB').right, closeTo(360, 1e-6));
      // The text sits inside the 8px padding, none at the outer edges.
      expect(tester.getTopLeft(find.text('BBBB')).dx, closeTo(first + 8, 1e-6));
      expect(tester.getTopLeft(find.text('A')).dx, 0);
    });

    testWidgets('automatic layout: short of max-content, each column gets '
        'its min-content and a share by what it lacks', (tester) async {
      await renderStandard(tester, [
        _rowsTable(
          ['A B C D E F G H I J K L', 'M'],
          [
            ['N', 'O'],
          ],
        ),
      ], width: 200);
      // Column 0: min-content one letter, max-content all 23 glyphs;
      // column 1: one letter, its min-content its max-content. The 200px
      // fall between the sums of min and max (kMaxGuess): each column grows
      // from its min by what it lacks, so column 1, lacking nothing, keeps
      // its own width and column 0 takes the rest.
      final (min0, max0) = _widths(tester, 'A B C D E F G H I J K L');
      final (min1, max1) = _widths(tester, 'M');
      expect(min1, max1);
      expect(min0 + min1, lessThan(200));
      expect(max0 + max1, greaterThan(200));
      expect(_cell(tester, 'M').width, closeTo(max1, 1e-6));
      expect(_cell(tester, 'N').width, closeTo(200 - max1, 1e-6));
    });

    testWidgets('scrolls sideways when its min-content is wider than it '
        '(at 320px, text scale 2.0)', (tester) async {
      await renderStandard(
        tester,
        [
          _rowsTable(
            ['Supercalifragilistic', 'Antidisestablishment'],
            [
              ['Pneumonoultramicroscopic', 'Floccinaucinihilipilification'],
            ],
          ),
        ],
        width: 320,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      // The table is as wide as its words, and its wrapper 320px.
      expect(tester.getSize(find.byType(HtmlTable)).width, greaterThan(320));
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(HtmlTableWidth),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      expect(tester.getSize(find.byType(HtmlTableWidth)).width, 320);
    });

    for (final textScale in [1.0, 2.0]) {
      testWidgets('wraps long text in its cell at 320px and text scale '
          '$textScale', (tester) async {
        const long =
            'Chromatin condenses into chromosomes and the spindle forms '
            'while the nuclear envelope breaks down';
        await renderStandard(
          tester,
          [
            _rowsTable(
              ['Phase', 'What happens'],
              [
                ['Prophase', long],
              ],
            ),
          ],
          width: 320,
          textScale: textScale,
        );
        expect(tester.takeException(), isNull);
        // The long cell wraps onto lines; the table is 320px wide unless
        // its words (at 2.0, "chromosomes" beside "Prophase") need more,
        // when it is their width and scrolls.
        final lineHeight = _style(tester, 'Prophase').fontSize! * 1.429;
        expect(
          tester.getSize(find.text(long)).height,
          greaterThan(2 * lineHeight * textScale),
        );
        final words = _widths(tester, 'Prophase').$1 + _widths(tester, long).$1;
        expect(
          tester.getSize(find.byType(HtmlTable)).width,
          closeTo(words > 320 ? words : 320, 1e-6),
        );
        expect(tester.getSize(find.byType(HtmlTableWidth)).width, 320);
      });
    }

    testWidgets('columnSizing "equal": fixed layout shares the width '
        'equally', (tester) async {
      await renderStandard(tester, [
        _rowsTable(
          ['A', 'BBBBBBBB'],
          [
            ['C', 'D'],
          ],
          {'columnSizing': 'equal'},
        ),
      ]);
      expect(_cell(tester, 'A').width, 180);
      expect(_cell(tester, 'BBBBBBBB').left, 180);
    });

    testWidgets('columnSizing "equal": the first row\'s widths hold even '
        'wider than the table, which then scrolls', (tester) async {
      await renderStandard(tester, [
        _rowsTable(
          [
            {'label': 'A', 'width': 60},
            {'label': 'B', 'width': 60},
          ],
          [
            ['C', 'D'],
          ],
          {'columnSizing': 'equal'},
        ),
      ]);
      // Each column 240px of content and 8px of padding: the table's
      // min-content is 496, so it is that wide, past its 360px box.
      expect(_cell(tester, 'A').width, 248);
      expect(tester.getSize(find.byType(HtmlTable)).width, 496);
    });

    testWidgets('a column width holds when there is room to spare', (
      tester,
    ) async {
      await renderStandard(tester, [
        _rowsTable(
          [
            {'label': 'A', 'width': 30},
            'B',
          ],
          [
            ['C', 'D'],
          ],
        ),
      ]);
      // width: spacing(30) = 120px of content, and its 8px end padding (a
      // content-box cell): a constrained column keeps its max; the auto one
      // takes the rest.
      expect(_cell(tester, 'A').width, 128);
      expect(_cell(tester, 'B').left, 128);
    });

    testWidgets('a colSpan cell spans its columns; a rowSpan cell its rows', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['body'],
        },
        // One row group: a row directly in a Table is a group of its own,
        // which a rowspan does not leave.
        {
          'id': 'body',
          'component': 'TableSection',
          'children': ['r1', 'r2', 'r3'],
        },
        {
          'id': 'r1',
          'component': 'TableRow',
          'children': ['wide'],
        },
        {'id': 'wide', 'component': 'TableCell', 'text': 'Wide', 'colSpan': 2},
        {
          'id': 'r2',
          'component': 'TableRow',
          'children': ['tall', 'b'],
        },
        {'id': 'tall', 'component': 'TableCell', 'text': 'Tall', 'rowSpan': 2},
        {'id': 'b', 'component': 'TableCell', 'text': 'B'},
        {
          'id': 'r3',
          'component': 'TableRow',
          'children': ['c'],
        },
        {'id': 'c', 'component': 'TableCell', 'text': 'C'},
      ]);
      expect(_cell(tester, 'Wide').left, 0);
      expect(_cell(tester, 'Wide').width, 360);
      // C, the only cell of the third row, starts after the rowspanned Tall,
      // in the second column, under B.
      expect(_cell(tester, 'C').left, _cell(tester, 'B').left);
      expect(_cell(tester, 'C').left, greaterThan(0));
      expect(_cell(tester, 'C').top, greaterThan(_cell(tester, 'B').top));
    });

    // data.tsx:303-313: the label's `<th colSpan={labelColSpan}>`
    // (data-media-parity.test.tsx:68 asserts `colSpan` 2, which draws
    // nothing in a lone row: see data_media_parity_test.dart's header).
    testWidgets("a TableRow's label spans labelColSpan columns", (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['body'],
        },
        {
          'id': 'body',
          'component': 'TableSection',
          'children': ['r1', 'r2'],
        },
        {
          'id': 'r1',
          'component': 'TableRow',
          'label': 'Day 1',
          'labelColSpan': 2,
          'children': ['x'],
        },
        {'id': 'x', 'component': 'TableCell', 'text': 'X'},
        {
          'id': 'r2',
          'component': 'TableRow',
          'children': ['a', 'b', 'c'],
        },
        {'id': 'a', 'component': 'TableCell', 'text': 'A'},
        {'id': 'b', 'component': 'TableCell', 'text': 'B'},
        {'id': 'c', 'component': 'TableCell', 'text': 'C'},
      ]);
      // The label takes the first two columns: X starts the third, over C.
      expect(_cell(tester, 'Day 1').left, 0);
      expect(_cell(tester, 'Day 1').right, _cell(tester, 'B').right);
      expect(_cell(tester, 'X').left, _cell(tester, 'C').left);
    });

    testWidgets("a colSpan cell's min-content widens the columns it spans", (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['body'],
        },
        {
          'id': 'body',
          'component': 'TableSection',
          'children': ['r1', 'r2'],
        },
        {
          'id': 'r1',
          'component': 'TableRow',
          'children': ['wide'],
        },
        {
          'id': 'wide',
          'component': 'TableCell',
          'text': 'Floccinaucinihilipilification',
          'colSpan': 2,
        },
        {
          'id': 'r2',
          'component': 'TableRow',
          'children': ['a', 'b'],
        },
        {'id': 'a', 'component': 'TableCell', 'text': 'A'},
        {'id': 'b', 'component': 'TableCell', 'text': 'B'},
      ], width: 200);
      // The word cannot break: the two columns it spans together take its
      // min-content (DistributeColspanCellToColumnsAuto), so the table is
      // wider than 200 and scrolls.
      final word = _widths(tester, 'Floccinaucinihilipilification').$1;
      expect(word, greaterThan(200));
      expect(tester.getSize(find.byType(HtmlTable)).width, closeTo(word, 1e-6));
      expect(_cell(tester, 'B').right, closeTo(word, 1e-6));
    });

    testWidgets('a rowspan stops at the end of its row group', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['r2', 'r3'],
        },
        {
          'id': 'r2',
          'component': 'TableRow',
          'children': ['tall', 'b'],
        },
        {
          'id': 'tall',
          'component': 'TableCell',
          'text': 'Tall',
          'rowSpan': 2,
          'vAlign': 'end',
        },
        {'id': 'b', 'component': 'TableCell', 'text': 'B'},
        {
          'id': 'r3',
          'component': 'TableRow',
          'children': ['c'],
        },
        {'id': 'c', 'component': 'TableCell', 'text': 'C'},
      ]);
      // Each row its own `<tbody>` (data.tsx:323-328): C starts the table's
      // first column, under Tall, and Tall's area (whose end it sits at) is
      // its own row's, not the next group's too.
      expect(_cell(tester, 'C').left, 0);
      expect(
        _cell(tester, 'Tall').bottom,
        closeTo(_cell(tester, 'B').bottom, 1e-6),
      );
      expect(_cell(tester, 'Tall').bottom, lessThan(_cell(tester, 'C').top));
    });

    testWidgets('rowSpan 0 spans the rest of its row group', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['body'],
        },
        {
          'id': 'body',
          'component': 'TableSection',
          'children': ['r1', 'r2', 'r3'],
        },
        {
          'id': 'r1',
          'component': 'TableRow',
          'children': ['all', 'a'],
        },
        {'id': 'all', 'component': 'TableCell', 'text': 'All', 'rowSpan': 0},
        {'id': 'a', 'component': 'TableCell', 'text': 'A'},
        {
          'id': 'r2',
          'component': 'TableRow',
          'children': ['b'],
        },
        {'id': 'b', 'component': 'TableCell', 'text': 'B'},
        {
          'id': 'r3',
          'component': 'TableRow',
          'children': ['c'],
        },
        {'id': 'c', 'component': 'TableCell', 'text': 'C'},
      ]);
      // B and C sit beside All, in its second column.
      expect(_cell(tester, 'B').left, _cell(tester, 'A').left);
      expect(_cell(tester, 'C').left, _cell(tester, 'A').left);
    });

    testWidgets('vAlign places a cell in a taller row', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['r'],
        },
        {
          'id': 'r',
          'component': 'TableRow',
          'children': ['tall', 'top', 'mid', 'end'],
        },
        {
          'id': 'tall',
          'component': 'TableCell',
          'text': 'one two three four five six seven',
          'width': 10,
        },
        {'id': 'top', 'component': 'TableCell', 'text': 'Top'},
        {
          'id': 'mid',
          'component': 'TableCell',
          'text': 'Mid',
          'vAlign': 'center',
        },
        {'id': 'end', 'component': 'TableCell', 'text': 'End', 'vAlign': 'end'},
      ]);
      final row = _cell(tester, 'one two three four five six seven');
      final top = _cell(tester, 'Top');
      final mid = _cell(tester, 'Mid');
      final end = _cell(tester, 'End');
      expect(top.top, row.top);
      expect(mid.center.dy, closeTo(row.center.dy, 1e-6));
      expect(end.bottom, closeTo(row.bottom, 1e-6));
    });

    testWidgets('shows the first header group first', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['body', 'head'],
        },
        {
          'id': 'body',
          'component': 'TableSection',
          'children': ['r'],
        },
        {
          'id': 'r',
          'component': 'TableRow',
          'children': ['c'],
        },
        {'id': 'c', 'component': 'TableCell', 'text': 'Vienna'},
        {
          'id': 'head',
          'component': 'TableSection',
          'header': true,
          'children': ['h'],
        },
        {
          'id': 'h',
          'component': 'TableRow',
          'children': ['hc'],
        },
        {'id': 'hc', 'component': 'TableCell', 'text': 'City'},
      ]);
      expect(_cell(tester, 'City').top, lessThan(_cell(tester, 'Vienna').top));
      expect(tableRows(tester), [
        [(SemanticsRole.columnHeader, 'City')],
        tableRow(['Vienna']),
      ]);
    });
  });

  group('cells', () {
    testWidgets('14px text, 8px padding (none at the outer edges), header '
        'cells medium weight', (tester) async {
      await renderStandard(tester, [
        _rowsTable(
          ['Head', 'Tail'],
          [
            ['Body', 'Last'],
          ],
        ),
      ]);
      expect(_style(tester, 'Head').fontSize, 14);
      expect(_style(tester, 'Head').fontWeight, FontWeight.w500);
      expect(_style(tester, 'Body').fontWeight, isNot(FontWeight.w500));
      expect(
        _style(tester, 'Body').color,
        standardLightColors[A2uiColorToken.textDefault],
      );
      // The text's top is 8px below its cell's (a 0.5px collapsed divider
      // above the body row).
      expect(
        tester.getTopLeft(find.text('Head')).dy - _cell(tester, 'Head').top,
        8,
      );
      expect(tester.getTopLeft(find.text('Body')).dx, 0);
      expect(
        tester.getTopRight(find.text('Last')).dx,
        closeTo(360, 1e-6),
        reason: 'the paragraph fills its cell up to the table end',
      );
    });

    testWidgets('a padding prop is 4px steps on every side, the edges '
        'included', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['r'],
        },
        {
          'id': 'r',
          'component': 'TableRow',
          'children': ['c'],
        },
        {'id': 'c', 'component': 'TableCell', 'text': 'Pad', 'padding': 3},
      ]);
      expect(tester.getTopLeft(find.text('Pad')).dx, 12);
    });

    testWidgets('align and the empty label (tertiary, centred)', (
      tester,
    ) async {
      await renderStandard(tester, [
        _rowsTable(['A', 'B'], const []),
      ]);
      final empty = tester.renderObject<RenderParagraph>(find.text('No rows'));
      expect(empty.textAlign, TextAlign.center);
      expect(
        _style(tester, 'No rows').color,
        standardLightColors[A2uiColorToken.textTertiary],
      );
    });

    testWidgets('a cell shows its text, then an inline component on its '
        'line and a block one under it', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['r'],
        },
        {
          'id': 'r',
          'component': 'TableRow',
          'children': ['c'],
        },
        {
          'id': 'c',
          'component': 'TableCell',
          'text': 'Mitosis',
          'children': ['badge', 'note'],
        },
        {'id': 'badge', 'component': 'Badge', 'label': '2n'},
        {'id': 'note', 'component': 'Text', 'text': 'Somatic cells'},
      ]);
      // The text and the Badge (inline-flex) are one paragraph: the Badge
      // follows the text on its line.
      final line = find.textContaining('Mitosis', findRichText: true);
      final paragraph = tester.renderObject<RenderParagraph>(line);
      final word = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 7),
      );
      final wordEnd = paragraph.localToGlobal(Offset(word.last.right, 0)).dx;
      final badge = tester.getRect(find.text('2n', findRichText: true));
      expect(badge.left, greaterThanOrEqualTo(wordEnd - 1e-6));
      expect(badge.top, greaterThanOrEqualTo(tester.getRect(line).top - 1e-6));
      expect(
        badge.bottom,
        lessThanOrEqualTo(tester.getRect(line).bottom + 1e-6),
      );
      // The Text (a block) starts a line of its own, under the paragraph.
      final note = tester.getRect(find.text('Somatic cells'));
      expect(
        note.top,
        greaterThanOrEqualTo(tester.getRect(line).bottom - 1e-6),
      );
    });

    testWidgets('content that is no cell sits in an anonymous cell, with no '
        'padding', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['r'],
        },
        {
          'id': 'r',
          'component': 'TableRow',
          'children': ['loose', 'c'],
        },
        {'id': 'loose', 'component': 'Text', 'text': 'Loose'},
        {'id': 'c', 'component': 'TableCell', 'text': 'Cell'},
      ]);
      expect(tester.getTopLeft(find.text('Loose')).dx, 0);
      // The anonymous cell is the row's first child: the TableCell's start
      // padding stays.
      expect(
        tester.getTopLeft(find.text('Cell')).dx,
        _cell(tester, 'Cell').left + 8,
      );
      expect(tableRows(tester), [
        tableRow(['Loose', 'Cell']),
      ]);
    });

    // text.tsx:257-298: a Bold, an Italic, an Underline and a
    // Strikethrough are a `<strong>`, `<em>`, `<u>` and `<s>`: inline boxes
    // on the cell's line, after its text.
    testWidgets('a Bold, an Italic, an Underline and a Strikethrough sit on '
        "the cell's line", (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['r'],
        },
        {
          'id': 'r',
          'component': 'TableRow',
          'children': ['c', 'd'],
        },
        {
          'id': 'c',
          'component': 'TableCell',
          'text': 'Crossing over in ',
          'children': ['b', 'i', 'u', 's'],
        },
        {'id': 'b', 'component': 'Bold', 'text': 'pachytene'},
        {'id': 'i', 'component': 'Italic', 'text': 'I'},
        {'id': 'u', 'component': 'Underline', 'text': 'U'},
        {'id': 's', 'component': 'Strikethrough', 'text': 'S'},
        {'id': 'd', 'component': 'TableCell', 'text': 'One'},
      ], width: 600);
      // On the line the other cell's text starts, each piece after the last.
      final line = tester.getRect(find.text('One', findRichText: true));
      var left = _cell(tester, 'pachytene').left;
      for (final text in ['pachytene', 'I', 'U', 'S']) {
        final rect = tester.getRect(find.text(text, findRichText: true));
        // Within float rounding: each piece is its own paragraph, set on
        // the line's baseline.
        expect(rect.top, closeTo(line.top, .01), reason: text);
        expect(rect.left, greaterThan(left), reason: text);
        left = rect.left;
      }
      // The text before them keeps its space: "in" and "pachytene" stay
      // apart, the Bold set after the space's caret.
      final paragraph = tester.renderObject<RenderParagraph>(
        find.textContaining('Crossing over in', findRichText: true),
      );
      double caret(int offset) => paragraph
          .getOffsetForCaret(TextPosition(offset: offset), Rect.zero)
          .dx;
      expect(caret(17), greaterThan(caret(16)));
      expect(
        tester.getRect(find.text('pachytene', findRichText: true)).left,
        closeTo(paragraph.localToGlobal(Offset.zero).dx + caret(17), .01),
      );
    });

    // text.tsx:395-417: a Math is a `<span>` unless `block`, a `<div>`.
    testWidgets(
      "an inline Math sits on the cell's line; a block Math on its own",
      (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Table',
            'children': ['r'],
          },
          {
            'id': 'r',
            'component': 'TableRow',
            'children': ['c', 'e'],
          },
          {
            'id': 'c',
            'component': 'TableCell',
            'text': 'Speed ',
            'children': ['m'],
          },
          {'id': 'm', 'component': 'Math', 'value': 'v'},
          {
            'id': 'e',
            'component': 'TableCell',
            'text': 'Speed ',
            'children': ['n'],
          },
          {'id': 'n', 'component': 'Math', 'value': 'v', 'block': true},
        ], width: 600);
        // The cell keys each child it lays out (a `KeyedSubtree`) round the
        // child's own NodeView: one box, found twice.
        final inline = tester.getRect(find.byKey(const NodeKey('m')).first);
        final block = tester.getRect(find.byKey(const NodeKey('n')).first);
        // Each cell's "Speed" is a paragraph of its own: the first holds the
        // inline formula's placeholder, the second stands above the block.
        final texts = find.textContaining('Speed', findRichText: true);
        expect(texts, findsNWidgets(2));
        final line = tester.getRect(texts.first);
        final above = tester.getRect(texts.last);
        expect(inline.top, lessThan(line.bottom));
        expect(inline.left, greaterThan(line.left));
        expect(block.top, greaterThanOrEqualTo(above.bottom - .01));
      },
    );

    // RULEBOOK section 2 (the node guard row): a cyclic reference's or an
    // unknown type's fallback is drawn where upstream's fallback `<div>`
    // lands (SurfaceView.tsx:314-340, host.tsx:116-150). React puts it there
    // through the DOM, so it is content that is no row group, row or cell
    // (CSS 2.1 section 17.2.1): an anonymous cell in a row, an anonymous row
    // and cell in a section or the table, a block in a cell. A child that has
    // not arrived (`later`) draws nothing (boundaries.tsx:16-18): no cell.
    group("a fallback's place", () {
      /// The box of the fallback naming [message], and of its table cell.
      (Rect, Rect) fallback(WidgetTester tester, String message) {
        final text = find.textContaining(message);
        expect(text, findsOneWidget);
        expect(alertsContaining(message), findsOne);
        return (
          tester.getRect(text),
          tester.getRect(
            find.ancestor(of: text, matching: find.byType(HtmlTableCell)).first,
          ),
        );
      }

      testWidgets("in a row: an anonymous cell after the row's cells", (
        tester,
      ) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Table',
            'children': ['r'],
          },
          {
            'id': 'r',
            'component': 'TableRow',
            'children': ['later', 'a', 'root'],
          },
          {'id': 'a', 'component': 'TableCell', 'text': 'A'},
        ]);
        final (_, cell) = fallback(tester, 'cyclic reference to root');
        expect(tableRows(tester), [
          tableRow(['A', '']),
        ]);
        expect(cell.left, _cell(tester, 'A').right);
        expect(cell.top, _cell(tester, 'A').top);
      });

      testWidgets('in a section: an anonymous row after its rows', (
        tester,
      ) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Table',
            'children': ['s'],
          },
          {
            'id': 's',
            'component': 'TableSection',
            'children': ['later', 'r', 'root'],
          },
          {
            'id': 'r',
            'component': 'TableRow',
            'children': ['a'],
          },
          {'id': 'a', 'component': 'TableCell', 'text': 'A'},
        ]);
        final (_, cell) = fallback(tester, 'cyclic reference to root');
        expect(tableRows(tester), [
          tableRow(['A']),
          tableRow(['']),
        ]);
        // Below the row and its divider, at the table's start.
        expect(cell.top, greaterThan(_cell(tester, 'A').bottom));
        expect(cell.left, _cell(tester, 'A').left);
      });

      testWidgets('in the table: an anonymous row group after its rows', (
        tester,
      ) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['t'],
          },
          {
            'id': 't',
            'component': 'Table',
            'children': ['later', 'r', 'root'],
          },
          {
            'id': 'r',
            'component': 'TableRow',
            'children': ['a'],
          },
          {'id': 'a', 'component': 'TableCell', 'text': 'A'},
        ]);
        final (_, cell) = fallback(tester, 'cyclic reference to root');
        expect(tableRows(tester), [
          tableRow(['A']),
          tableRow(['']),
        ]);
        expect(cell.top, greaterThan(_cell(tester, 'A').bottom));
        expect(cell.left, _cell(tester, 'A').left);
      });

      testWidgets('in a cell: a block under its text', (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Table',
            'children': ['r'],
          },
          {
            'id': 'r',
            'component': 'TableRow',
            'children': ['c'],
          },
          {
            'id': 'c',
            'component': 'TableCell',
            'text': 'A',
            'children': ['later', 'root'],
          },
        ]);
        final (box, cell) = fallback(tester, 'cyclic reference to root');
        expect(cell, _cell(tester, 'A'));
        expect(tableRows(tester), hasLength(1));
        expect(
          box.top,
          greaterThanOrEqualTo(
            tester.getRect(find.text('A', findRichText: true)).bottom,
          ),
        );
      });

      // Tier 1 data review 5: upstream renders every node through its
      // render check (SurfaceView.tsx:740-760, :1095-1132), so a section,
      // row or cell whose bound props fail it shows the "invalid props"
      // fallback in its place and is reported, as any node is.
      testWidgets('a cell and a row whose props fail the check: the fallback '
          'in each place, reported', (tester) async {
        final view = await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'Table',
              'children': ['s', 'bad_r'],
            },
            {
              'id': 's',
              'component': 'TableSection',
              'children': ['r'],
            },
            {
              'id': 'r',
              'component': 'TableRow',
              'children': ['a', 'bad_c'],
            },
            {'id': 'a', 'component': 'TableCell', 'text': 'A'},
            {
              'id': 'bad_c',
              'component': 'TableCell',
              'text': 'B',
              'colSpan': {'@path': '/span'},
            },
            {
              'id': 'bad_r',
              'component': 'TableRow',
              'label': {'@path': '/label'},
              'children': <String>[],
            },
          ],
          data: {'span': 'two', 'label': 5},
        );
        await tester.pump();
        expect(alertsContaining('invalid props'), findsExactly(2));
        expect(find.text('B'), findsNothing);
        // The cell's fallback is an anonymous cell after A; the row's an
        // anonymous row below the section.
        final cell = tester.getRect(
          find
              .ancestor(
                of: find.textContaining('colSpan'),
                matching: find.byType(HtmlTableCell),
              )
              .first,
        );
        expect(cell.left, _cell(tester, 'A').right);
        final row = tester.getRect(
          find
              .ancestor(
                of: find.textContaining('label'),
                matching: find.byType(HtmlTableCell),
              )
              .first,
        );
        expect(row.top, greaterThan(_cell(tester, 'A').bottom));
        final reported = [
          for (final error in view.errors)
            if (error.code == 'INVALID_PROPS') error.message,
        ];
        expect(reported, hasLength(2));
        expect(
          reported,
          contains(startsWith("Component 'bad_c' has invalid props")),
        );
        expect(
          reported,
          contains(startsWith("Component 'bad_r' has invalid props")),
        );
        // Valid data: the cell spans its two columns, the row has its label.
        await view.update([
          agentWrite('/span', 2),
          agentWrite('/label', 'Total'),
        ]);
        await tester.pump();
        expect(alertsContaining('invalid props'), findsNothing);
        expect(find.text('B', findRichText: true), findsOneWidget);
        expect(find.text('Total', findRichText: true), findsOneWidget);
      });

      testWidgets("a rows table's cell component of an unknown type: in its "
          'cell', (tester) async {
        final view = await renderStandard(tester, []);
        // The validator refuses an unknown type from the agent, so it is put
        // in the model past it, as surface_components_test.dart does.
        view.surface.componentsModel
          ..addComponent(ComponentModel('x', 'Nope', const {}))
          ..addComponent(
            ComponentModel('root', 'Table', const {
              'columns': ['Name', 'Part'],
              'rows': [
                [
                  'A',
                  {'componentId': 'x'},
                ],
              ],
              'cellComponents': ['x'],
            }),
          );
        await view.update([agentWrite('/tick', 1)]);
        final (_, cell) = fallback(tester, 'unknown component "Nope"');
        expect(cell.left, _cell(tester, 'A').right);
        expect(cell.top, _cell(tester, 'A').top);
      });
    });
  });

  group('dividers', () {
    List<Rect> dividers(WidgetTester tester) {
      final recording = TestRecordingCanvas();
      final context = TestRecordingPaintingContext(recording);
      _table(tester).paint(context, Offset.zero);
      return _rects(recording, _subtle);
    }

    testWidgets('a hairline under the header and between rows, none under '
        'the last', (tester) async {
      await renderStandard(tester, [
        _rowsTable(
          ['A'],
          [
            ['B'],
            ['C'],
          ],
        ),
      ]);
      final lines = dividers(tester);
      expect(lines, hasLength(2));
      for (final line in lines) {
        expect(line.height, 1);
        expect(line.width, 360);
      }
      // Centred on the edge between the rows (collapsed borders).
      expect(lines[0].center.dy, closeTo(_cell(tester, 'A').bottom + .5, 1e-6));
      expect(_table(tester), paints..something(paintedRect(color: _subtle)));
    });

    testWidgets('dividers: false keeps only the header line', (tester) async {
      await renderStandard(tester, [
        _rowsTable(
          ['A'],
          [
            ['B'],
            ['C'],
          ],
          {'dividers': false},
        ),
      ]);
      expect(dividers(tester), hasLength(1));
    });

    testWidgets('standard look: no line under the last row of the last row '
        'group', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['r1', 'r2'],
        },
        {
          'id': 'r1',
          'component': 'TableRow',
          'children': ['a'],
        },
        {'id': 'a', 'component': 'TableCell', 'text': 'A'},
        {
          'id': 'r2',
          'component': 'TableRow',
          'children': ['b'],
        },
        {'id': 'b', 'component': 'TableCell', 'text': 'B'},
      ]);
      expect(dividers(tester), hasLength(1));
    });

    testWidgets('playground look: the last row keeps its line, and no '
        'TableCell has inline padding', (tester) async {
      await pumpComponents(
        tester,
        theme: A2uiKitTheme.playground(Brightness.light),
        [
          {
            'id': 'root',
            'component': 'Table',
            'children': ['r1'],
          },
          {
            'id': 'r1',
            'component': 'TableRow',
            'children': ['a', 'b'],
          },
          {'id': 'a', 'component': 'TableCell', 'text': 'A'},
          {'id': 'b', 'component': 'TableCell', 'text': 'B'},
        ],
      );
      final subtle = A2uiKitTheme.playground(
        Brightness.light,
      ).color(A2uiColorToken.borderSubtle);
      final recording = TestRecordingCanvas();
      _table(
        tester,
      ).paint(TestRecordingPaintingContext(recording), Offset.zero);
      expect(_rects(recording, subtle), hasLength(1));
      expect(tester.getTopLeft(find.text('B')).dx, _cell(tester, 'B').left);
    });

    testWidgets('dark: the subtle border token', (tester) async {
      await renderStandard(tester, [
        _rowsTable(
          ['A'],
          [
            ['B'],
          ],
        ),
      ], brightness: Brightness.dark);
      expect(
        _table(tester),
        paints..something(
          paintedRect(color: standardDarkColors[A2uiColorToken.borderSubtle]),
        ),
      );
    });
  });

  // Running review B1: a cell that needs compositing (a Button's opacity, a
  // Code's scroll view) ended the recording the table had kept, so its
  // dividers and its sticky header drew on a disposed canvas: none showed,
  // and each paint reported an error. Upstream's dividers and sticky `th`s
  // show whatever the cells hold (data.tsx:199-266, styles.ts:77).
  group('paint with composited cells', () {
    /// The ARGB32 colour at the global point [at] of the frame drawn.
    Future<int> pixelAt(WidgetTester tester, Offset at) async {
      // The outermost boundary round the table: the whole page.
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find
            .ancestor(
              of: find.byType(HtmlTable),
              matching: find.byType(RepaintBoundary),
            )
            .last,
      );
      const ratio = 2.0;
      final image = (await tester.runAsync(
        () => boundary.toImage(pixelRatio: ratio),
      ))!;
      final data = (await tester.runAsync(image.toByteData))!;
      final local = boundary.globalToLocal(at) * ratio;
      final index = (local.dy.floor() * image.width + local.dx.floor()) * 4;
      image.dispose();
      return Color.fromARGB(
        data.getUint8(index + 3),
        data.getUint8(index),
        data.getUint8(index + 1),
        data.getUint8(index + 2),
      ).toARGB32();
    }

    for (final sticky in [false, true]) {
      testWidgets('a Button and a Code in cells keep the dividers and the '
          'header (stickyHeader $sticky)', (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Table',
            'stickyHeader': sticky,
            'columns': ['Chapter', 'Practice'],
            'rows': [
              [
                'Motion',
                {'componentId': 'b'},
              ],
              [
                'Energy',
                {'componentId': 'k'},
              ],
            ],
            'cellComponents': ['b', 'k'],
          },
          {'id': 'b', 'component': 'Button', 'label': 'Start', 'size': 'sm'},
          {'id': 'k', 'component': 'Code', 'text': 'print(2)'},
        ]);
        await tester.pumpAndSettle();
        // No paint reported an error (the test fails on one), the header is
        // drawn, and each divider is drawn over the page.
        final header = tester.getRect(find.text('Chapter', findRichText: true));
        final page = await pixelAt(tester, const Offset(355, 590));
        expect(await pixelAt(tester, header.center), isNot(page));
        // A 1px divider ends where the next row's cells start (the collapsed
        // border's half in the row above): its middle is 0.5px above.
        for (final (text, next) in [
          ('Chapter', 'Motion'),
          ('Motion', 'Energy'),
        ]) {
          final edge = _cell(tester, next).top - .5;
          expect(
            await pixelAt(tester, Offset(_cell(tester, text).left + 2, edge)),
            isNot(page),
            reason: 'the divider under $text',
          );
        }
      });
    }
  });

  // Running review B7: a streamed table's row whose cells have not arrived
  // yet (an empty `<tr>`, data.tsx:305-320) has no height; its semantics
  // node would be invisible, which Flutter's tree refuses.
  group('a row with no cell yet', () {
    final cases = <String, List<Map<String, Object?>>>{
      'its cells not sent yet': [
        {
          'id': 'r1',
          'component': 'TableRow',
          'children': ['later'],
        },
      ],
      'no children': [
        {'id': 'r1', 'component': 'TableRow', 'children': <String>[]},
      ],
    };
    for (final MapEntry(key: name, value: second) in cases.entries) {
      testWidgets('has no node until it has a cell: $name', (tester) async {
        final handle = tester.ensureSemantics();
        final view = await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Table',
            'children': ['r0', 'r1'],
          },
          {
            'id': 'r0',
            'component': 'TableRow',
            'children': ['a'],
          },
          {'id': 'a', 'component': 'TableCell', 'text': 'A'},
          ...second,
        ]);
        await tester.pump();
        expect(tableRows(tester), [
          tableRow(['A']),
        ]);
        // Its cell arrives: the row has its node.
        await view.update([
          agentComponents([
            {
              'id': 'r1',
              'component': 'TableRow',
              'children': ['b'],
            },
            {'id': 'b', 'component': 'TableCell', 'text': 'B'},
          ]),
        ]);
        await tester.pump();
        expect(tableRows(tester), [
          tableRow(['A']),
          tableRow(['B']),
        ]);
        handle.dispose();
      });
    }
  });

  group('keyboard', () {
    // RULEBOOK section 0 (the browser decides): Chrome 159 makes a scroll
    // container that holds nothing keyboard-focusable a tab stop
    // (element.cc:9180-9194, `IsKeyboardFocusableScroller`), and an arrow
    // key scrolls it (keyboard_event_manager.cc:67-180).
    testWidgets(
      'Tab reaches a wide table with nothing focusable in it, and an arrow '
      'scrolls it sideways',
      (tester) async {
        await renderStandard(tester, [
          _rowsTable(
            ['Supercalifragilistic', 'Antidisestablishment'],
            [
              ['Pneumonoultramicroscopic', 'Floccinaucinihilipilification'],
            ],
          ),
        ], width: 320);
        final scroll = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(HtmlTableWidth),
            matching: find.byType(Scrollable),
          ),
        );
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, greaterThan(0));
      },
    );

    /// Whether the table's wrapper has the primary focus.
    bool wrapperFocused() =>
        FocusManager.instance.primaryFocus?.debugLabel == 'a2ui scroll box';

    // element.cc:9180-9194: only a scroller that can scroll and holds
    // nothing keyboard-focusable; :9264-9266, never by a press.
    testWidgets('Tab passes a table that fits, and one holding a Button '
        'stops at the Button; a press focuses neither', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['narrow', 'wide'],
        },
        _rowsTable(
          ['A'],
          [
            ['B'],
          ],
        )..['id'] = 'narrow',
        {
          'id': 'wide',
          'component': 'Table',
          'columns': ['Supercalifragilistic', 'Antidisestablishment'],
          'rows': [
            [
              'Pneumonoultramicroscopic',
              {'componentId': 'go'},
            ],
          ],
          'cellComponents': ['go'],
        },
        {'id': 'go', 'component': 'Button', 'label': 'Go'},
      ], width: 320);
      await tester.tap(
        find.text('Pneumonoultramicroscopic', findRichText: true),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(wrapperFocused(), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // Past the narrow table and the wide one's wrapper, to its Button.
      expect(wrapperFocused(), isFalse);
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        find
            .ancestor(
              of: find.byElementPredicate((e) => identical(e, focused)),
              matching: find.byType(HtmlTableCell),
            )
            .evaluate(),
        isNotEmpty,
      );
    });

    testWidgets('a press on a wide table leaves the focus off it', (
      tester,
    ) async {
      await renderStandard(tester, [
        _rowsTable(
          ['Supercalifragilistic', 'Antidisestablishment'],
          [
            ['Pneumonoultramicroscopic', 'Floccinaucinihilipilification'],
          ],
        ),
      ], width: 320);
      for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
        await tester.tap(
          find.text('Pneumonoultramicroscopic', findRichText: true),
          kind: kind,
        );
        await tester.pump();
        expect(wrapperFocused(), isFalse, reason: '$kind');
      }
      // Tab reaches it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(wrapperFocused(), isTrue);
    });
  });

  group('sticky header', () {
    testWidgets('keeps the table within 480px and the header pinned', (
      tester,
    ) async {
      await renderStandard(tester, [
        _rowsTable(
          ['Name'],
          [
            for (var i = 0; i < 40; i++) ['Row $i'],
          ],
          {'stickyHeader': true},
        ),
      ]);
      final box = find.byType(HtmlTableWidth);
      expect(tester.getSize(box).height, 480);
      final header = _cell(tester, 'Name');
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: box, matching: find.byType(Scrollable)).first,
      );
      scroll.position.jumpTo(100);
      await tester.pump();
      // The header moved down by the scroll, so it stays in view, over a
      // surface fill; a body cell went up.
      expect(_table(tester).stickyOffset, 100);
      expect(
        _table(tester),
        paints..something(
          paintedRect(color: standardLightColors[A2uiColorToken.surface]),
        ),
      );
      final hit = tester.hitTestOnBinding(header.center);
      expect(
        hit.path.any(
          (entry) =>
              entry.target is RenderParagraph &&
              (entry.target as RenderParagraph).text.toPlainText() == 'Name',
        ),
        isTrue,
      );
    });
  });

  group('semantics', () {
    testWidgets('a row envelope names the row; a hidden row has no node', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['r1', 'r2'],
        },
        {
          'id': 'r1',
          'component': 'TableRow',
          'children': ['a'],
          'accessibility': {'label': 'Totals', 'live': 'polite'},
        },
        {'id': 'a', 'component': 'TableCell', 'text': 'A'},
        {
          'id': 'r2',
          'component': 'TableRow',
          'children': ['b'],
          'accessibility': {'hidden': true},
        },
        {'id': 'b', 'component': 'TableCell', 'text': 'B'},
      ]);
      final rows = find.semantics
          .byPredicate((node) => node.role == SemanticsRole.row)
          .evaluate()
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single.label, 'Totals');
      expect(rows.single.flagsCollection.isLiveRegion, isTrue);
      expect(find.text('B'), findsOneWidget);
      expect(tableCells('B'), findsNothing);
    });

    testWidgets('a lone TableRow is a table of its own', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['r'],
        },
        {
          'id': 'r',
          'component': 'TableRow',
          'label': 'Day 1',
          'children': ['c'],
        },
        {'id': 'c', 'component': 'TableCell', 'text': '€80'},
      ]);
      expect(tableRows(tester), [
        tableRow(['Day 1', '€80']),
      ]);
    });
  });

  group('updates', () {
    testWidgets('a template row added to the data shows', (tester) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Table',
            'children': {'componentId': 'row', 'path': '/rows'},
          },
          {
            'id': 'row',
            'component': 'TableRow',
            'children': ['name'],
          },
          {
            'id': 'name',
            'component': 'TableCell',
            'text': {'@path': 'name'},
          },
        ],
        data: {
          'rows': [
            {'name': 'Alpha'},
          ],
        },
      );
      await view.update([
        agentWrite('/rows/1', {'name': 'Beta'}),
      ]);
      await tester.pump();
      expect(tableRows(tester), [
        tableRow(['Alpha']),
        tableRow(['Beta']),
      ]);
      await view.update([agentWrite('/rows/0/name', 'Gamma')]);
      await tester.pump();
      expect(tableRows(tester).first, tableRow(['Gamma']));
    });

    testWidgets("a cell's bound envelope label follows the data", (
      tester,
    ) async {
      final view = await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Table',
            'children': ['r'],
          },
          {
            'id': 'r',
            'component': 'TableRow',
            'children': ['c'],
          },
          {
            'id': 'c',
            'component': 'TableCell',
            'text': '42',
            'accessibility': {
              'label': {'@path': '/name'},
            },
          },
        ],
        data: {'name': 'Total'},
      );
      expect(tableCells('Total'), findsOne);
      await view.update([agentWrite('/name', 'Sum')]);
      await tester.pump();
      expect(tableCells('Sum'), findsOne);
    });
  });

  group('helpers', () {
    test('colspan and rowspan parse as HTML parses the attribute', () {
      expect(htmlSpanOf(null, min: 1, max: 1000), 1);
      expect(htmlSpanOf(2.5, min: 1, max: 1000), 2);
      expect(htmlSpanOf(0, min: 1, max: 1000), 1);
      expect(htmlSpanOf(0, min: 0, max: 65534), 0);
      expect(htmlSpanOf(-1, min: 1, max: 1000), 1);
      expect(htmlSpanOf(5000, min: 1, max: 1000), 1000);
      expect(htmlSpanOf(1e21, min: 1, max: 1000), 1);
      expect(htmlSpanOf(double.nan, min: 1, max: 1000), 1);
      expect(htmlSpanOf(' +3x', min: 1, max: 1000), 3);
    });

    test('a cell holding JSON shows JSON.stringify of it', () {
      expect(
        jsonStringifyJs({
          'b': [1, 2.5, true, null],
          '2': 'x"y',
          '1': 1.0,
        }),
        r'{"1":1,"2":"x\"y","b":[1,2.5,true,null]}',
      );
      expect(jsonStringifyJs('\u0001\ud800'), r'"\u0001\ud800"');
    });
  });
}
