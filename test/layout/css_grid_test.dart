// Rectangles of the CSS grid render object for CopilotKit's Grid template:
// repeat(auto-fit, minmax(min(100%, max(T, (100% - (n - 1) * gap) / n)), 1fr))
// with T = round(max(120, 520 / n)).

import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_grid.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _cell(String name, {double height = 10}) =>
    SizedBox(key: ValueKey(name), height: height);

Future<void> _pump(
  WidgetTester tester,
  double width,
  GridColumns columns,
  List<Widget> children, {
  double gap = 16,
  A2uiAlign? align,
}) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: CssGrid(
          columns: columns,
          rowGap: gap,
          columnGap: gap,
          align: align,
          children: children,
        ),
      ),
    ),
  ),
);

Rect _rect(WidgetTester tester, String name) =>
    tester.getRect(find.byKey(ValueKey(name)));

const _two = GridColumns.autoFit(count: 2, minTrack: 260);

void main() {
  group('auto-fit columns', () {
    test('count the columns that fit, at most n', () {
      // 600: (600 - 16) / 2 = 292 > 260, two columns.
      expect(_two.widths(600, 16), [292, 292]);
      // 520: (520 - 16) / 2 = 252 < 260, and 536 / 276 < 2, one column.
      expect(_two.widths(520, 16), [520]);
      // 536: (536 - 16) / 2 = 260, two columns.
      expect(_two.widths(536, 16), [260, 260]);
      const three = GridColumns.autoFit(count: 3, minTrack: 173);
      expect(three.widths(400, 16), hasLength(2));
      expect(three.widths(320, 16), hasLength(1));
    });

    testWidgets('two children share a wide row', (tester) async {
      await _pump(tester, 600, _two, [_cell('a'), _cell('b')]);
      expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 0, 292, 10));
      expect(_rect(tester, 'b'), const Rect.fromLTWH(308, 0, 292, 10));
    });

    testWidgets('a narrow grid has one column', (tester) async {
      await _pump(tester, 320, _two, [_cell('a'), _cell('b')]);
      expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 0, 320, 10));
      expect(_rect(tester, 'b'), const Rect.fromLTWH(0, 26, 320, 10));
    });

    testWidgets('empty columns collapse: one child fills the row', (
      tester,
    ) async {
      await _pump(tester, 600, _two, [_cell('a')]);
      expect(_rect(tester, 'a').width, 600);
    });

    testWidgets('a third child starts the next row in the first column', (
      tester,
    ) async {
      await _pump(tester, 600, _two, [_cell('a'), _cell('b'), _cell('c')]);
      expect(_rect(tester, 'c'), const Rect.fromLTWH(0, 26, 292, 10));
    });
  });

  group('rows', () {
    testWidgets('children of a row stretch to the tallest', (tester) async {
      await _pump(tester, 600, _two, [_cell('a'), _cell('b', height: 40)]);
      expect(_rect(tester, 'a').height, 40);
    });

    testWidgets('align start keeps their own height', (tester) async {
      await _pump(tester, 600, _two, [
        _cell('a'),
        _cell('b', height: 40),
      ], align: A2uiAlign.start);
      expect(_rect(tester, 'a').height, 10);
    });

    testWidgets('align center centres them in the row', (tester) async {
      await _pump(tester, 600, _two, [
        _cell('a'),
        _cell('b', height: 40),
      ], align: A2uiAlign.center);
      expect(_rect(tester, 'a').top, 15);
    });
  });

  group('spans', () {
    testWidgets('a span that covers every column fills the row', (
      tester,
    ) async {
      await _pump(tester, 600, _two, [
        _cell('a'),
        const CssGridItem(
          placement: GridPlacement(span: 2),
          child: SizedBox(key: ValueKey('wide'), height: 10),
        ),
      ]);
      expect(_rect(tester, 'wide'), const Rect.fromLTWH(0, 26, 600, 10));
    });

    testWidgets('a span wider than the rendered columns is clamped', (
      tester,
    ) async {
      await _pump(tester, 320, _two, [
        const CssGridItem(
          placement: GridPlacement(span: 3),
          child: SizedBox(key: ValueKey('wide'), height: 10),
        ),
      ]);
      expect(_rect(tester, 'wide').width, 320);
    });

    testWidgets('a row span spreads over the rows it covers', (tester) async {
      const three = GridColumns.tracks([
        GridTrack(fraction: 1),
        GridTrack(fraction: 1),
      ]);
      await _pump(tester, 216, three, [
        const CssGridItem(
          placement: GridPlacement(rowSpan: 2),
          child: SizedBox(key: ValueKey('tall'), height: 10),
        ),
        _cell('b'),
        _cell('c'),
      ]);
      expect(_rect(tester, 'tall'), const Rect.fromLTWH(0, 0, 100, 36));
      expect(_rect(tester, 'c'), const Rect.fromLTWH(116, 26, 100, 10));
    });
  });

  group('templates', () {
    test('auto-fill keeps empty columns', () {
      const fill = GridColumns.autoFill(minTrack: 100);
      expect(fill.widths(500, 16), [113, 113, 113, 113]);
    });

    test('fixed and fr tracks', () {
      const tracks = GridColumns.tracks([
        GridTrack(pixels: 100),
        GridTrack(fraction: 1),
        GridTrack(fraction: 2),
      ]);
      expect(tracks.widths(410, 5), [100, 100, 200]);
    });

    testWidgets('an auto track is as wide as its widest child; fr tracks '
        'share the rest (TanStack tooltip rows)', (tester) async {
      const tracks = GridColumns.tracks([
        GridTrack(pixels: 8.8),
        GridTrack(fraction: 1),
        GridTrack.auto(),
      ]);
      await _pump(tester, 200, tracks, gap: 6.4, [
        _cell('swatch'),
        _cell('label'),
        const SizedBox(key: ValueKey('value'), width: 40, height: 10),
        _cell('swatch2'),
        _cell('label2'),
        const SizedBox(key: ValueKey('value2'), width: 30, height: 10),
      ]);
      expect(
        _rect(tester, 'value'),
        rectMoreOrLessEquals(const Rect.fromLTWH(160, 0, 40, 10)),
      );
      expect(
        _rect(tester, 'label').width,
        closeTo(200 - 8.8 - 40 - 12.8, 1e-9),
      );
      // A wider grid than its content asks only what its tracks hold.
      final grid = tester.renderObject<RenderCssGrid>(find.byType(CssGrid));
      expect(
        grid.getMaxIntrinsicWidth(double.infinity),
        closeTo(8.8 + 40 + 12.8, 1e-9),
      );
      expect(tracks.widths(200, 6.4), [8.8, 200 - 8.8 - 12.8, 0]);
    });
  });

  // CSS Grid Level 1, section 11 (inferred from the spec's text: no local
  // copy). Test text uses the test font, whose glyphs are 1em squares:
  // "aaaa bbbb" at 10px has a min-content of 40 and a max-content of 90.
  group('track sizing (review 2a regen Q4, Q5)', () {
    Widget text(String name, String content) => Text(
      content,
      key: ValueKey(name),
      style: const TextStyle(fontSize: 10, height: 1),
    );

    RenderCssGrid grid(WidgetTester tester) =>
        tester.renderObject<RenderCssGrid>(find.byType(CssGrid));

    testWidgets('auto tracks stretch over the free space no fr track takes', (
      tester,
    ) async {
      // §11.8: with no flexible track, the auto track takes the rest (a
      // max-content track would stay 40).
      await _pump(
        tester,
        200,
        gap: 0,
        const GridColumns.tracks([GridTrack(pixels: 10), GridTrack.auto()]),
        [
          const SizedBox(key: ValueKey('swatch'), width: 10, height: 10),
          const SizedBox(key: ValueKey('value'), width: 40, height: 10),
        ],
      );
      expect(_rect(tester, 'value'), const Rect.fromLTWH(10, 0, 190, 10));
      // Two auto tracks share it equally: 40 + 50 and 60 + 50.
      await _pump(
        tester,
        200,
        gap: 0,
        const GridColumns.tracks([GridTrack.auto(), GridTrack.auto()]),
        [
          const SizedBox(key: ValueKey('a'), width: 40, height: 10),
          const SizedBox(key: ValueKey('b'), width: 60, height: 10),
        ],
      );
      expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 0, 90, 10));
      expect(_rect(tester, 'b'), const Rect.fromLTWH(90, 0, 110, 10));
    });

    testWidgets('an auto track starts from its min-content: a wrappable cell '
        'wraps in a tight grid', (tester) async {
      // §11.5: base 40 (min-content), growth limit 90 (max-content); §11.6:
      // 150 - 100 - 40 leaves 10, so the track grows to 50 and the text
      // wraps onto two lines (a max-content track would be 90, one line,
      // overflowing the grid).
      await _pump(
        tester,
        150,
        gap: 0,
        const GridColumns.tracks([GridTrack.auto(), GridTrack(pixels: 100)]),
        [text('a', 'aaaa bbbb'), _cell('b')],
      );
      expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 0, 50, 20));
      expect(_rect(tester, 'b'), const Rect.fromLTWH(50, 0, 100, 20));
    });

    testWidgets('auto 1fr: the auto track is its content, the fr track takes '
        'the rest', (tester) async {
      // A 24px icon and a paragraph at 320: the auto track's base and growth
      // limit are 24; the 1fr track, frozen in §11.6, takes 296 in §11.7.
      await _pump(
        tester,
        320,
        gap: 0,
        const GridColumns.tracks([GridTrack.auto(), GridTrack(fraction: 1)]),
        [
          const SizedBox(key: ValueKey('icon'), width: 24, height: 24),
          text('p', 'A paragraph long enough to wrap in its column'),
        ],
      );
      expect(_rect(tester, 'icon').width, 24);
      expect(_rect(tester, 'p').left, 24);
      expect(_rect(tester, 'p').width, 296);
    });

    testWidgets('min-content and max-content tracks', (tester) async {
      await _pump(
        tester,
        300,
        gap: 0,
        const GridColumns.tracks([
          GridTrack.minContent(),
          GridTrack.maxContent(),
          GridTrack(fraction: 1),
        ]),
        [text('min', 'aaaa bbbb'), text('max', 'aaaa bbbb'), _cell('rest')],
      );
      // The min-content column wraps; the row is two lines tall.
      expect(_rect(tester, 'min'), const Rect.fromLTWH(0, 0, 40, 20));
      expect(_rect(tester, 'max'), const Rect.fromLTWH(40, 0, 90, 20));
      expect(_rect(tester, 'rest'), const Rect.fromLTWH(130, 0, 170, 20));
    });

    test('fr factors summing under 1 take only that share (§11.7.1); an auto '
        'track stretches over the rest', () {
      expect(
        const GridColumns.tracks([GridTrack(fraction: .5)]).widths(200, 0),
        [100],
      );
      expect(
        const GridColumns.tracks([
          GridTrack(fraction: .5),
          GridTrack.auto(),
        ]).widths(200, 0),
        [100, 100],
      );
    });

    testWidgets('intrinsic widths place items as layout does: spans and full '
        'rows', (tester) async {
      // Row 1: one item over both tracks; row 2: 10 in the fixed track and
      // 30 in the auto one. Placing by index (i % 2) would put the 30 in the
      // fixed track and the 10 in the auto one: 20.
      for (final placement in const [
        GridPlacement(span: 2),
        GridPlacement(fullRow: true),
      ]) {
        await _pump(
          tester,
          200,
          gap: 0,
          const GridColumns.tracks([GridTrack(pixels: 10), GridTrack.auto()]),
          [
            CssGridItem(
              placement: placement,
              child: const SizedBox(key: ValueKey('wide'), width: 20),
            ),
            const SizedBox(key: ValueKey('a'), width: 10, height: 10),
            const SizedBox(key: ValueKey('b'), width: 30, height: 10),
          ],
        );
        expect(grid(tester).getMaxIntrinsicWidth(double.infinity), 40);
        expect(grid(tester).getMinIntrinsicWidth(double.infinity), 40);
      }
    });

    testWidgets("the min-content width counts no fr track's content "
        '(minmax(0, 1fr)); the max-content width does', (tester) async {
      await _pump(
        tester,
        200,
        gap: 0,
        const GridColumns.tracks([GridTrack(fraction: 1), GridTrack.auto()]),
        [
          text('label', 'aaaa bbbb'),
          const SizedBox(key: ValueKey('value'), width: 30, height: 10),
        ],
      );
      // Under a min-content constraint the flex fraction is 0 (§11.7): 30,
      // not 40 + 30.
      expect(grid(tester).getMinIntrinsicWidth(double.infinity), 30);
      // Under a max-content one the label's 90 sets the fr size.
      expect(grid(tester).getMaxIntrinsicWidth(double.infinity), 120);
    });

    testWidgets('the max-content width gives every fr track the fr size that '
        'fits each item, times its factor', (tester) async {
      // 1fr 2fr with two 100px items: the fr size is max(100 / 1, 100 / 2),
      // so the tracks are 100 and 200 (not 100 and 100).
      await _pump(
        tester,
        400,
        gap: 0,
        const GridColumns.tracks([
          GridTrack(fraction: 1),
          GridTrack(fraction: 2),
        ]),
        [
          const SizedBox(key: ValueKey('a'), width: 100, height: 10),
          const SizedBox(key: ValueKey('b'), width: 100, height: 10),
        ],
      );
      expect(grid(tester).getMaxIntrinsicWidth(double.infinity), 300);
      expect(grid(tester).getMinIntrinsicWidth(double.infinity), 0);
    });
  });
}
