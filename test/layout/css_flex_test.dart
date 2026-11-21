// Rectangles of the CSS flex render object, computed by hand from the rules
// of CSS Flexible Box Layout Level 1 (section 9). Test text uses the test
// font, whose glyphs are 1em squares: "aaaa" at 10px is 40 x 10.

import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const ValueKey<String> _key = ValueKey('flex');

Widget _box(String name, {double? width, double? height}) =>
    SizedBox(key: ValueKey(name), width: width, height: height);

Widget _text(String name, String text, {double size = 10}) => Text(
  text,
  key: ValueKey(name),
  style: TextStyle(fontSize: size, height: 1),
);

Widget _item(
  Widget child, [
  A2uiFlexItemStyle style = A2uiFlexItemStyle.normal,
]) => CssFlexItem(style: style, child: child);

Future<void> _pump(
  WidgetTester tester,
  double width,
  CssFlex flex, {
  TextDirection direction = TextDirection.ltr,
}) => tester.pumpWidget(
  Directionality(
    textDirection: direction,
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: KeyedSubtree(key: _key, child: flex),
      ),
    ),
  ),
);

Rect _rect(WidgetTester tester, String name) =>
    tester.getRect(find.byKey(ValueKey(name)));

A2uiFlexItemStyle _fixed(double width, {double shrink = 1, double grow = 0}) =>
    A2uiFlexItemStyle(width: A2uiLength.px(width), shrink: shrink, grow: grow);

void main() {
  group('main axis', () {
    testWidgets('places items with the gap from the start', (tester) async {
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(direction: Axis.horizontal, columnGap: 10),
          children: [
            for (final n in ['a', 'b', 'c'])
              _item(_box(n, width: 50, height: 10), _fixed(50)),
          ],
        ),
      );
      expect(_rect(tester, 'a').left, 0);
      expect(_rect(tester, 'b').left, 60);
      expect(_rect(tester, 'c').left, 120);
      expect(tester.getSize(find.byKey(_key)), const Size(200, 10));
    });

    final cases = <A2uiJustify, List<double>>{
      A2uiJustify.start: [0, 50],
      A2uiJustify.end: [100, 150],
      A2uiJustify.center: [50, 100],
      A2uiJustify.spaceBetween: [0, 150],
      A2uiJustify.spaceAround: [25, 125],
      A2uiJustify.spaceEvenly: [33.333, 116.667],
      A2uiJustify.stretch: [0, 50],
    };
    for (final MapEntry(key: justify, value: lefts) in cases.entries) {
      testWidgets('justify ${justify.wire}', (tester) async {
        await _pump(
          tester,
          200,
          CssFlex(
            flex: A2uiFlexStyle(direction: Axis.horizontal, justify: justify),
            children: [
              _item(_box('a', width: 50, height: 10), _fixed(50)),
              _item(_box('b', width: 50, height: 10), _fixed(50)),
            ],
          ),
        );
        expect(
          _rect(tester, 'a').left,
          moreOrLessEquals(lefts[0], epsilon: .01),
        );
        expect(
          _rect(tester, 'b').left,
          moreOrLessEquals(lefts[1], epsilon: .01),
        );
      });
    }

    testWidgets('one item: spaceBetween is start, spaceAround centers', (
      tester,
    ) async {
      for (final (justify, left) in [
        (A2uiJustify.spaceBetween, 0.0),
        (A2uiJustify.spaceAround, 75.0),
        (A2uiJustify.spaceEvenly, 75.0),
      ]) {
        await _pump(
          tester,
          200,
          CssFlex(
            flex: A2uiFlexStyle(direction: Axis.horizontal, justify: justify),
            children: [_item(_box('a', width: 50, height: 10), _fixed(50))],
          ),
        );
        expect(_rect(tester, 'a').left, left, reason: justify.wire);
      }
    });

    testWidgets('right to left starts at the right', (tester) async {
      await _pump(
        tester,
        200,
        direction: TextDirection.rtl,
        CssFlex(
          flex: const A2uiFlexStyle(direction: Axis.horizontal, columnGap: 10),
          children: [
            _item(_box('a', width: 50, height: 10), _fixed(50)),
            _item(_box('b', width: 50, height: 10), _fixed(50)),
          ],
        ),
      );
      expect(_rect(tester, 'a').right, 200);
      expect(_rect(tester, 'b').right, 140);
    });
  });

  group('flexible lengths', () {
    testWidgets('grow takes the free space', (tester) async {
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(direction: Axis.horizontal),
          children: [
            _item(_box('a', height: 10), _fixed(50, grow: 1)),
            _item(_box('b', height: 10), _fixed(50)),
          ],
        ),
      );
      expect(_rect(tester, 'a').width, 150);
      expect(_rect(tester, 'b').width, 50);
    });

    testWidgets('flex: 1 (basis 0%) splits the space equally', (tester) async {
      const equal = A2uiFlexItemStyle(grow: 1, basis: A2uiLength.percent(0));
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(direction: Axis.horizontal),
          children: [
            _item(_text('a', 'a'), equal),
            _item(_text('b', 'bbbbbbbb'), equal),
          ],
        ),
      );
      expect(_rect(tester, 'a').width, 100);
      expect(_rect(tester, 'b').width, 100);
    });

    testWidgets('weights share the free space after the content', (
      tester,
    ) async {
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(direction: Axis.horizontal),
          children: [
            _item(_text('a', 'aaaa'), const A2uiFlexItemStyle(grow: 1)),
            _item(_text('b', 'bb'), const A2uiFlexItemStyle(grow: 3)),
          ],
        ),
      );
      // Free space 200 - 60 = 140: a gets 35, b 105.
      expect(_rect(tester, 'a').width, 75);
      expect(_rect(tester, 'b').width, 125);
    });

    testWidgets('shrink is weighted by the base size', (tester) async {
      await _pump(
        tester,
        100,
        CssFlex(
          flex: const A2uiFlexStyle(direction: Axis.horizontal),
          children: [
            _item(
              _box('a', height: 10),
              const A2uiFlexItemStyle(
                width: A2uiLength.px(100),
                minWidth: A2uiLength.zero,
              ),
            ),
            _item(
              _box('b', height: 10),
              const A2uiFlexItemStyle(
                width: A2uiLength.px(50),
                minWidth: A2uiLength.zero,
              ),
            ),
          ],
        ),
      );
      expect(_rect(tester, 'a').width, moreOrLessEquals(66.667, epsilon: .01));
      expect(_rect(tester, 'b').width, moreOrLessEquals(33.333, epsilon: .01));
    });

    testWidgets('an automatic minimum stops shrinking at the longest word', (
      tester,
    ) async {
      // "aaaa bbb": max-content 80, min-content 40. With the 100px box the
      // line is 180 in 80: text would get 32.9, under its 40 minimum, so it
      // freezes at 40 and the box takes the rest, 40.
      await _pump(
        tester,
        80,
        CssFlex(
          flex: const A2uiFlexStyle(direction: Axis.horizontal),
          children: [
            _item(_text('a', 'aaaa bbb')),
            _item(
              _box('b', height: 10),
              const A2uiFlexItemStyle(
                width: A2uiLength.px(100),
                minWidth: A2uiLength.zero,
              ),
            ),
          ],
        ),
      );
      expect(_rect(tester, 'a').width, 40);
      expect(_rect(tester, 'b').width, 40);
      // The text wrapped onto two lines.
      expect(_rect(tester, 'a').height, 20);
    });

    testWidgets('min-width: 0 lets text shrink below its longest word', (
      tester,
    ) async {
      await _pump(
        tester,
        50,
        CssFlex(
          flex: const A2uiFlexStyle(direction: Axis.horizontal),
          children: [
            _item(
              _text('a', 'aaaaaaaa'),
              const A2uiFlexItemStyle(minWidth: A2uiLength.zero),
            ),
          ],
        ),
      );
      expect(_rect(tester, 'a').width, 50);
      expect(tester.takeException(), isNull);
    });

    testWidgets('flex-shrink 0 overflows without an error', (tester) async {
      await _pump(
        tester,
        50,
        CssFlex(
          flex: const A2uiFlexStyle(direction: Axis.horizontal),
          children: [_item(_box('a', height: 10), _fixed(80, shrink: 0))],
        ),
      );
      expect(_rect(tester, 'a').width, 80);
      expect(tester.takeException(), isNull);
    });

    testWidgets('max-width 100% caps an item at the container', (tester) async {
      await _pump(
        tester,
        100,
        CssFlex(
          flex: const A2uiFlexStyle(direction: Axis.horizontal),
          children: [
            _item(
              _box('a', height: 10),
              const A2uiFlexItemStyle(
                width: A2uiLength.px(300),
                shrink: 0,
                maxWidth: A2uiLength.percent(1),
              ),
            ),
          ],
        ),
      );
      expect(_rect(tester, 'a').width, 100);
    });
  });

  group('wrap', () {
    testWidgets('breaks lines and spaces them by the row gap', (tester) async {
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(
            direction: Axis.horizontal,
            wrap: A2uiWrap.wrap,
            columnGap: 10,
            rowGap: 5,
          ),
          children: [
            for (final n in ['a', 'b', 'c'])
              _item(_box(n, height: 10), _fixed(80)),
          ],
        ),
      );
      expect(_rect(tester, 'a').topLeft, Offset.zero);
      expect(_rect(tester, 'b').topLeft, const Offset(90, 0));
      expect(_rect(tester, 'c').topLeft, const Offset(0, 15));
      expect(tester.getSize(find.byKey(_key)), const Size(200, 25));
    });

    testWidgets('wrap-reverse stacks the lines from the bottom', (
      tester,
    ) async {
      await _pump(
        tester,
        100,
        CssFlex(
          flex: const A2uiFlexStyle(
            direction: Axis.horizontal,
            wrap: A2uiWrap.wrapReverse,
          ),
          children: [
            _item(_box('a', height: 10), _fixed(80)),
            _item(_box('b', height: 20), _fixed(80)),
          ],
        ),
      );
      expect(_rect(tester, 'a').top, 20);
      expect(_rect(tester, 'b').top, 0);
    });
  });

  group('cross axis', () {
    testWidgets('stretches children of a column to its width', (tester) async {
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(rowGap: 8),
          children: [_item(_text('a', 'aa')), _item(_text('b', 'bbb'))],
        ),
      );
      expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 0, 200, 10));
      expect(_rect(tester, 'b'), const Rect.fromLTWH(0, 18, 200, 10));
    });

    testWidgets('centers fit-content children of a column', (tester) async {
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(align: A2uiAlign.center),
          children: [_item(_text('a', 'aaaa'))],
        ),
      );
      expect(_rect(tester, 'a'), const Rect.fromLTWH(80, 0, 40, 10));
    });

    testWidgets('a long text in a centered column wraps at the width', (
      tester,
    ) async {
      await _pump(
        tester,
        60,
        CssFlex(
          flex: const A2uiFlexStyle(align: A2uiAlign.center),
          children: [_item(_text('a', 'aaaa bbbb'))],
        ),
      );
      expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 0, 60, 20));
    });

    testWidgets('stretches row children to the tallest one', (tester) async {
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(direction: Axis.horizontal),
          children: [
            _item(_box('a', width: 20)),
            _item(_box('b', width: 20, height: 30)),
          ],
        ),
      );
      expect(_rect(tester, 'a').height, 30);
    });

    for (final (align, top) in [
      (A2uiAlign.start, 0.0),
      (A2uiAlign.center, 10.0),
      (A2uiAlign.end, 20.0),
    ]) {
      testWidgets('align ${align.wire} in a row', (tester) async {
        await _pump(
          tester,
          200,
          CssFlex(
            flex: A2uiFlexStyle(direction: Axis.horizontal, align: align),
            children: [
              _item(_box('a', width: 20, height: 10)),
              _item(_box('b', width: 20, height: 30)),
            ],
          ),
        );
        expect(_rect(tester, 'a').top, top);
        expect(_rect(tester, 'a').height, 10);
      });
    }

    testWidgets('baseline aligns the text baselines', (tester) async {
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(
            direction: Axis.horizontal,
            align: A2uiAlign.baseline,
          ),
          children: [_item(_text('a', 'a')), _item(_text('b', 'b', size: 20))],
        ),
      );
      // The test font's baseline is at 0.75em.
      expect(_rect(tester, 'a').top + 7.5, _rect(tester, 'b').top + 15);
    });

    testWidgets('align-self overrides the container', (tester) async {
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(
            direction: Axis.horizontal,
            align: A2uiAlign.start,
          ),
          children: [
            _item(
              _box('a', width: 20),
              const A2uiFlexItemStyle(alignSelf: A2uiAlign.stretch),
            ),
            _item(_box('b', width: 20, height: 30)),
          ],
        ),
      );
      expect(_rect(tester, 'a').height, 30);
    });
  });

  group('box', () {
    testWidgets('padding and border inset the content', (tester) async {
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(),
          box: A2uiBoxStyle(
            padding: const EdgeInsets.all(8),
            borderWidth: 1,
            decoration: BoxDecoration(border: Border.all()),
          ),
          children: [_item(_box('a', height: 10))],
        ),
      );
      expect(_rect(tester, 'a'), const Rect.fromLTWH(9, 9, 182, 10));
      expect(tester.getSize(find.byKey(_key)), const Size(200, 28));
    });

    testWidgets('an inline container fits its content', (tester) async {
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(direction: Axis.horizontal),
          box: const A2uiBoxStyle(fill: false),
          children: [_item(_text('a', 'aaa'))],
        ),
      );
      expect(tester.getSize(find.byKey(_key)), const Size(30, 10));
    });

    testWidgets('aspect ratio gives the height', (tester) async {
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(),
          box: const A2uiBoxStyle(aspectRatio: 2),
          children: [_item(_box('a', height: 10))],
        ),
      );
      expect(tester.getSize(find.byKey(_key)), const Size(200, 100));
    });

    testWidgets('max-height shrinks a column', (tester) async {
      await _pump(
        tester,
        200,
        CssFlex(
          flex: const A2uiFlexStyle(),
          box: const A2uiBoxStyle(maxHeight: A2uiLength.px(30)),
          children: [
            _item(
              _box('a', height: 40),
              const A2uiFlexItemStyle(minHeight: A2uiLength.zero),
            ),
            _item(
              _box('b', height: 20),
              const A2uiFlexItemStyle(minHeight: A2uiLength.zero),
            ),
          ],
        ),
      );
      expect(tester.getSize(find.byKey(_key)).height, 30);
      expect(_rect(tester, 'a').height, 20);
      expect(_rect(tester, 'b').height, 10);
    });

    // CSS Overflow 3, 3.1 (the overflow clip edge is the padding edge); CSS
    // Backgrounds 3, 5.3 (the inner radius is the outer one less the
    // border width, at least 0). A 100 by 60 box with a 4px border, 10px
    // and 2px corners, holding a child larger than itself.
    Future<List<String>> clipped(
      WidgetTester tester, {
      bool clip = true,
    }) async {
      final taps = <String>[];
      await _pump(
        tester,
        100,
        CssFlex(
          flex: const A2uiFlexStyle(),
          box: A2uiBoxStyle(
            borderWidth: 4,
            clip: clip,
            height: const A2uiLength.px(60),
            decoration: BoxDecoration(
              border: Border.all(width: 4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(2),
                bottomRight: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          children: [
            _item(
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => taps.add('${details.localPosition}'),
                child: const SizedBox(key: ValueKey('a'), height: 200),
              ),
              const A2uiFlexItemStyle(shrink: 0),
            ),
          ],
        ),
      );
      return taps;
    }

    testWidgets('overflow hidden clips at the padding box with inner radii', (
      tester,
    ) async {
      await clipped(tester);
      expect(
        tester.renderObject(find.byKey(_key)),
        paints..clipRRect(
          rrect: RRect.fromRectAndCorners(
            const Rect.fromLTRB(4, 4, 96, 56),
            topLeft: const Radius.circular(6),
            // The top right, 2px less 4px, is no corner at all (the
            // default, zero).
            bottomRight: const Radius.circular(6),
            bottomLeft: const Radius.circular(6),
          ),
        ),
      );
    });

    testWidgets('overflow hidden takes no hit outside its clip', (
      tester,
    ) async {
      final taps = await clipped(tester);
      final box = tester.getRect(find.byKey(_key));
      // On the border: outside the padding box.
      await tester.tapAt(box.topLeft + const Offset(50, 2));
      // In the rounded corner's cut, inside the border box's square.
      await tester.tapAt(box.topLeft + const Offset(5, 5));
      // Below the box, where the child overflows.
      await tester.tapAt(box.topLeft + const Offset(50, 70));
      expect(taps, isEmpty);
      // Just inside the padding edge, and in the middle.
      await tester.tapAt(box.topLeft + const Offset(50, 4.5));
      await tester.tapAt(box.topLeft + const Offset(50, 30));
      expect(taps, hasLength(2));
    });

    testWidgets('without overflow hidden, the corner takes the hit', (
      tester,
    ) async {
      final taps = await clipped(tester, clip: false);
      final box = tester.getRect(find.byKey(_key));
      await tester.tapAt(box.topLeft + const Offset(5, 5));
      expect(taps, hasLength(1));
    });
  });

  group('intrinsic sizes', () {
    testWidgets('a row reports its content widths', (tester) async {
      await _pump(
        tester,
        400,
        CssFlex(
          flex: const A2uiFlexStyle(direction: Axis.horizontal, columnGap: 10),
          children: [_item(_text('a', 'aa bbbb')), _item(_text('b', 'cc'))],
        ),
      );
      final box = tester.renderObject<RenderCssFlex>(find.byType(CssFlex));
      expect(box.getMaxIntrinsicWidth(double.infinity), 70 + 10 + 20);
      expect(box.getMinIntrinsicWidth(double.infinity), 40 + 10 + 20);
      expect(box.getMaxIntrinsicHeight(60), 20);
      expect(box.getDryLayout(const BoxConstraints(maxWidth: 60)).height, 20);
    });

    testWidgets('a column inside IntrinsicWidth takes its widest child', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: IntrinsicWidth(
              child: CssFlex(
                key: _key,
                flex: const A2uiFlexStyle(),
                children: [_item(_text('a', 'aa')), _item(_text('b', 'bbbbb'))],
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(_key)), const Size(50, 20));
    });
  });
}
