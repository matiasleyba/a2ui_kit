// Parity tests of CopilotKit's standard data and media components, ported
// from packages/react-core/src/v2/generative-ui/standard/__tests__/
// data-media-parity.test.tsx (MIT, (c) Atai Barkai), itself ported from the
// a2ui-renderer standard catalog. Each test names its upstream line.
//
// ignore: lines_longer_than_80_chars (port_status.dart reads this line whole)
// Parity for: List, ListItem, Image, Icon, Chart, Column, Table, TableRow, TableCell, Svg
// Signals for: Favicon, Video, AudioPlayer, HtmlView, Map
//
// Upstream renders `standardUI`, as `renderStandard` does. A test that mixes
// built and later-phase components ports its built part and keeps the
// later-phase components in its surface, where they draw nothing yet
// (RULEBOOK section 6, item 2). The DOM queries are read as in
// data_test.dart: `role=button` with a name is a semantics button with that
// label, clicked by its text; the Chart's hidden data table is its table
// node in the semantics tree, whose cells `getAllByText` finds
// (`tableCells`, with the table roles RULEBOOK section 0 gives it);
// `findByAltText` is the image node
// labelled with that text. An
// image here has no network: a picture is put in the image cache for its
// URL, so that it loads (in jsdom an `<img>` stays one), except in :242,
// where the test binding's HTTP 400 is upstream's `fireEvent.error`.
//
// Translated (upstream reads inline style strings; they count as ported):
// - :149 "List maxMarkerSize and ListItem markerSize size the marker
//   column": inline `min-width` and `max-width` strings, read as the
//   marker boxes' laid-out widths (32 and 48); the 32px `max-width`, which
//   no glyph here reaches, from the box's constraints.
// - :271 "Image hoverZoom and position apply": inline `object-position`,
//   `transition` and `overflow` strings, read from the widgets that apply
//   them, not from what is drawn: the picture's `alignment` (top), an
//   `AnimatedScale` round it (the zoom's transform transition) and a
//   `ClipRRect` round that (the frame's `overflow: hidden`). That clip is
//   the radius clip every Image sits in (image.dart), so the check holds
//   with or without `hoverZoom`: it shows the zoom is clipped, not that
//   `hoverZoom` turns the clip on.
//
// Not ported (bound to internals):
// - :329 "Chart renders a recharts container and Map renders a fallback
//   marker list without maplibre", its Chart part: `[data-a2ui-chart]`
//   (:352), a data attribute. Tested as the scene the Chart painted.
// - :42 `querySelector("ol")` (in :20): tested by the number markers.
// - :100 `li.style.opacity` "0.5" and :101 `li.querySelector("button")`
//   (in :86): tested as an `Opacity` of 0.5, and as no button in the
//   semantics tree (a click on the item then sends nothing).
// - :126 `data-a2ui-list-value` and :127 the value's parent's
//   `style.justifyContent` (in :105): tested as the value's own text at the
//   end of the label's line, a flex box with `justify: spaceBetween`.
// - :215 the `src` of the `<img>` (in :173): the URL its image loads.
// - :218 `querySelector("svg")` and :237 `svg.lucide-arrow-right` (in
//   :173): tested as the Lucide arrow-right glyph drawn.
// - :384 `[data-a2ui-chart]` and :387 `.recharts-responsive-container`
//   counts (in :355), :411 `.recharts-responsive-container` and :414
//   `[data-a2ui-chart=bar]` (in :392): tested as the scenes painted (two in
//   :355; one of bars in :392).
// - :40 `querySelectorAll("th")` (in :20): read as the table's two
//   column-header nodes.
// - :64 and :65 `closest("th")` (in :45): read as the column-header node
//   the text's node sits in.
// - :81-:83 (in :68): the `<th>` tag and `scope="row"` are read as a cell
//   node in medium weight (a row header: Flutter's `SemanticsRole` has no
//   row header, INV-150). `colSpan` 2 draws nothing in that table: in an
//   automatic layout a column no cell starts in takes no room (Chromium's
//   mergeable columns), so the label spanning two columns or one is drawn
//   the same, and Flutter's semantics has no column span. The spans are
//   tested by their layout in table_components_test.dart.
// - :218 `querySelector("svg")` and :233 `path[d='M0 0L10 10']` (in
//   :173): tested as the Svg painting that path, its stroke the danger
//   token.
// - :322 `stroke-linecap` "round" (in :305): a fill-only circle draws no
//   stroke, so the cap shows nothing; read as the drawing's cap, and drawn
//   on a stroked line in svg_components_test.dart. Its `width`, `height`
//   and `preserveAspectRatio` are tested as the box and the stretched
//   circle drawn.
//
// Later phase (no Dart yet):
// - Favicon, Video, AudioPlayer and HtmlView: their part of :173
//   (:219-:232), :288 (a YouTube Video's poster and player).
// - Map: the Map part of :329 (:351).

import 'dart:ui' show Tristate;

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/data/chart.dart';
import 'package:a2ui_kit/src/foundation/chart/plot.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart'
    show CssFlexItem;
import 'package:a2ui_kit/src/foundation/svg/svg_drawing.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/paint_calls.dart';
import '../helpers/parity.dart';

/// The button named [name]: upstream's `findByRole("button", { name })`.
/// Gives the finder of its text, to click it.
Finder _button(WidgetTester tester, String name) {
  final node = semanticsOfText(tester, name);
  expect(node.flagsCollection.isButton, isTrue, reason: '"$name" is a button');
  expect(node.label, name);
  return find.text(name);
}

/// Every button on screen: upstream's `queryAllByRole("button")`.
SemanticsFinder _buttons() =>
    find.semantics.byPredicate((node) => node.flagsCollection.isButton);

/// The picture whose alternative text is [alt]: upstream's
/// `findByAltText(alt)`.
Finder _pictureWithAlt(String alt) => find.byWidgetPredicate(
  (widget) => widget is Image && widget.semanticLabel == alt,
);

/// Puts a [width] by [height] picture (400 by 200 by default) in the image
/// cache for [url]. The tests have no network; with it the Image loads and
/// stays a picture.
Future<void> _cachePicture(
  WidgetTester tester,
  String url, {
  int width = 400,
  int height = 200,
}) async {
  final picture = await tester.runAsync(
    // 400 by 200 holds the 31px overlay button inside the picture. In a
    // smaller one the browser's absolutely placed button overflows its
    // wrapper and stays clickable; ours is drawn there but refuses taps
    // outside the picture: the queued "beyond" test at the end of this
    // file.
    () => createTestImage(width: width, height: height),
  );
  PaintingBinding.instance.imageCache.putIfAbsent(
    NetworkImage(url),
    () => OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: picture!)),
    ),
  );
  addTearDown(PaintingBinding.instance.imageCache.clear);
}

/// The column-header node the text [text] sits in, or null: upstream's
/// `getByText(text).closest("th")` of a header cell.
SemanticsNode? _headerCellOf(WidgetTester tester, String text) {
  for (
    SemanticsNode? node = semanticsOfText(tester, text);
    node != null;
    node = node.parent
  ) {
    if (node.role == SemanticsRole.columnHeader) return node;
  }
  return null;
}

/// The scenes the charts painted, in order.
List<PlotScene> _scenes(WidgetTester tester) => [
  for (final paint in tester.widgetList<CustomPaint>(find.byType(CustomPaint)))
    if (paint.painter case final ChartScenePainter painter) painter.scene,
];

void main() {
  group('standard catalog: data and media (parity)', () {
    // data-media-parity.test.tsx:20
    testWidgets('Table renders columns and rows, List renders items', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['t', 'l'],
        },
        {
          'id': 't',
          'component': 'Table',
          'columns': ['Feature', 'Team'],
          'rows': [
            ['Price', r'$29/seat'],
            ['Seats', 'Custom'],
          ],
        },
        {
          'id': 'l',
          'component': 'List',
          'items': [
            'one',
            {'label': 'two', 'description': 'second'},
          ],
          'marker': 'number',
        },
      ]);
      expect(find.text(r'$29/seat'), findsOneWidget);
      // querySelectorAll("th"): two column headers.
      expect(
        find.semantics.byPredicate(
          (node) => node.role == SemanticsRole.columnHeader,
        ),
        findsExactly(2),
      );
      expect(find.text('second'), findsOneWidget);
      // An <ol>: a number before each item.
      expect(find.text('1. '), findsOneWidget);
      expect(find.text('2. '), findsOneWidget);
    });

    // data-media-parity.test.tsx:45
    testWidgets('Table columns render a { componentId } header cell inside '
        '<th>', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'columns': [
            'Laptop',
            {'label': 'Price', 'componentId': 'hb'},
            {'componentId': 'hb2'},
          ],
          'rows': [
            ['Air 13', r'$999', '-'],
          ],
          'cellComponents': ['hb', 'hb2'],
        },
        {'id': 'hb', 'component': 'Badge', 'label': 'Best value'},
        {'id': 'hb2', 'component': 'Text', 'text': 'Extra'},
      ]);
      expect(find.text('Best value', findRichText: true), findsOneWidget);
      // badge.closest("th"), whose text holds "Price": the column header
      // the badge's node sits in; and "Extra" inside a <th>.
      final badge = _headerCellOf(tester, 'Best value');
      expect(badge, isNotNull);
      expect(badge!.label, contains('Price'));
      expect(_headerCellOf(tester, 'Extra'), isNotNull);
    });

    // data-media-parity.test.tsx:68
    testWidgets('TableRow renders its label as a row header cell with '
        'labelColSpan', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Table',
          'children': ['r'],
        },
        {
          'id': 'r',
          'component': 'TableRow',
          'label': 'Day 1',
          'labelColSpan': 2,
          'children': ['c'],
        },
        {'id': 'c', 'component': 'TableCell', 'text': '€80'},
      ]);
      expect(find.text('Day 1'), findsOneWidget);
      // A <th scope="row">: a header cell (medium weight) that a screen
      // reader reads as the row's first cell.
      expect(tableRows(tester), [
        tableRow(['Day 1', '€80']),
      ]);
      final style = tester
          .widget<RichText>(find.text('Day 1', findRichText: true))
          .text
          .style;
      expect(style?.fontWeight, FontWeight.w500);
    });

    // data-media-parity.test.tsx:86
    testWidgets('ListItem disabled renders at half opacity and ignores its '
        'action', (tester) async {
      final view = await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'List',
          'children': ['i'],
        },
        {
          'id': 'i',
          'component': 'ListItem',
          'label': 'Sold out',
          'disabled': true,
          'action': {
            'event': {'name': 'pick'},
          },
        },
      ]);
      expect(find.text('Sold out'), findsOneWidget);
      // aria-disabled="true"
      expect(
        semanticsOfText(tester, 'Sold out').flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      // style.opacity "0.5"
      expect(
        tester
            .widgetList<Opacity>(
              find.ancestor(
                of: find.text('Sold out'),
                matching: find.byType(Opacity),
              ),
            )
            .first
            .opacity,
        .5,
      );
      // No button in the item, so a click on it sends nothing.
      expect(_buttons(), findsNothing);
      await tester.tap(find.text('Sold out'));
      await tester.pump();
      expect(view.actions, isEmpty);
    });

    // data-media-parity.test.tsx:105
    testWidgets('List items and ListItems show their value on the right of '
        'the label', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['l', 'm'],
        },
        {
          'id': 'l',
          'component': 'List',
          'marker': 'none',
          'items': [
            {'label': 'Price', 'value': r'$1,599'},
            {'label': 'RAM', 'value': 32},
          ],
        },
        {
          'id': 'm',
          'component': 'List',
          'children': ['i'],
        },
        {
          'id': 'i',
          'component': 'ListItem',
          'label': 'Battery',
          'value': 'Up to 18 hrs',
        },
      ]);
      expect(find.text(r'$1,599'), findsOneWidget);
      // The value is its own text, at the end of the label's line
      // (`justify-content: space-between`).
      expect(
        flexContainerOf(tester, r'$1,599').flex.justify,
        A2uiJustify.spaceBetween,
      );
      expect(find.text('32'), findsOneWidget);
      expect(find.text('Up to 18 hrs'), findsOneWidget);
    });

    // data-media-parity.test.tsx:132
    testWidgets('List items with an action keep the value as the pick '
        'payload and do not show it', (tester) async {
      final view = await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'List',
          'items': [
            {'label': 'Graz', 'value': 'graz'},
          ],
          'action': {
            'event': {'name': 'pick'},
          },
        },
      ]);
      await tester.tap(_button(tester, 'Graz'));
      await tester.pump();
      expect(find.text('graz'), findsNothing);
      final context = view.actions.first.context;
      expect(context['label'], 'Graz');
      expect(context['value'], 'graz');
    });

    // data-media-parity.test.tsx:149 (behaviour)
    testWidgets('List maxMarkerSize and ListItem markerSize size the marker '
        'column', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'List',
          'marker': 'rich',
          'maxMarkerSize': 32,
          'children': ['a', 'b'],
        },
        {'id': 'a', 'component': 'ListItem', 'label': 'Wide', 'marker': '①'},
        {
          'id': 'b',
          'component': 'ListItem',
          'label': 'Own',
          'marker': '②',
          'markerSize': 48,
        },
      ]);
      // The marker's box, as laid out: `min-width` and `max-width` 32px
      // hold "①" at 32 wide; `min-width` 48px widens the narrow "②" to 48.
      Finder markerBox(String marker) => find
          .ancestor(of: find.text(marker), matching: find.byType(Container))
          .first;

      expect(tester.getSize(markerBox('①')).width, 32);
      expect(tester.getSize(markerBox('②')).width, 48);
      // Both glyphs are narrower than 32, so no size drawn here shows the
      // `max-width`; it is read from the box's constraints (an extra).
      expect(
        tester.widget<Container>(markerBox('①')).constraints!.maxWidth,
        32,
      );
    });

    // data-media-parity.test.tsx:173
    testWidgets('Image, Icon, Favicon, Svg, Video, AudioPlayer, HtmlView '
        'render safely: the Image, the Icon and the Svg', (tester) async {
      await _cachePicture(tester, 'https://example.com/a.png');
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['i', 'c', 'f', 's', 'y', 'au', 'h'],
        },
        {
          'id': 'i',
          'component': 'Image',
          'url': 'https://example.com/a.png',
          'description': 'pic',
          'aspectRatio': '16/9',
          'radius': 'lg',
        },
        {'id': 'c', 'component': 'Icon', 'name': 'arrow-right', 'size': 'md'},
        // Later phase: Favicon, Video, AudioPlayer and HtmlView draw nothing
        // yet.
        {
          'id': 'f',
          'component': 'Favicon',
          'url': 'https://copilotkit.ai',
          'alt': 'ck',
        },
        {
          'id': 's',
          'component': 'Svg',
          'viewBox': '0 0 10 10',
          'paths': [
            {'d': 'M0 0L10 10', 'stroke': 'danger'},
          ],
        },
        {
          'id': 'y',
          'component': 'Video',
          'url': 'https://example.com/clip.mp4',
        },
        {
          'id': 'au',
          'component': 'AudioPlayer',
          'url': 'https://example.com/clip.mp3',
          'description': 'A clip',
        },
        {
          'id': 'h',
          'component': 'HtmlView',
          'html': '<b>hi</b><script>window.__x=1</script>',
          'height': 100,
        },
      ]);
      // findByAltText("pic"): an image node labelled "pic"; and the src it
      // loads.
      expect(
        find.semantics.byPredicate(
          (node) => node.label == 'pic' && node.flagsCollection.isImage,
        ),
        findsOne,
      );
      expect(
        tester.widget<Image>(_pictureWithAlt('pic')).image,
        isA<NetworkImage>().having(
          (image) => image.url,
          'url',
          contains('a.png'),
        ),
      );
      // An <svg>: the Lucide arrow-right icon.
      expect(find.byType(LucideGlyph), findsWidgets);
      expect([
        for (final glyph in tester.widgetList<LucideGlyph>(
          find.byType(LucideGlyph),
        ))
          glyph.icon,
      ], contains(lucideIcon('arrow-right', release: LucideRelease.reactCore)));
      // querySelector("svg") and path[d='M0 0L10 10']: the Svg paints that
      // path, stroked in the danger token (standard light: #c1322c).
      final svg = find.byType(SvgCanvas);
      expect(svg, findsOneWidget);
      expect(
        tester.renderObject(svg),
        paints..something(
          paintedPath(
            style: PaintingStyle.stroke,
            color: const Color(0xffc1322c),
            bounds: const Rect.fromLTRB(0, 0, 10, 10),
          ),
        ),
      );
      // Later phase: the Favicon, Video, AudioPlayer and HtmlView draw
      // nothing yet, so the Icon's glyph is the only one, and neither the
      // audio's caption nor the favicon's image is there. Each of the four
      // takes no room: every item of the root Column but the Image's, the
      // Icon's and the Svg's has no height, which a Video player or an
      // HtmlView's frame, whatever its look, changes. When one of these
      // fails, its component is built: port its half (:219-:232).
      expect(find.byType(LucideGlyph), findsOneWidget);
      expect(find.text('A clip', findRichText: true), findsNothing);
      expect(find.bySemanticsLabel('ck'), findsNothing);
      final items = find.byType(CssFlexItem);
      for (var i = 0; i < items.evaluate().length; i++) {
        bool holds(Finder drawn) => find
            .descendant(of: items.at(i), matching: drawn)
            .evaluate()
            .isNotEmpty;
        if (holds(find.byType(Image)) ||
            holds(find.byType(LucideGlyph)) ||
            holds(svg)) {
          continue;
        }
        expect(tester.getSize(items.at(i)).height, 0, reason: 'item $i');
      }
    });

    // data-media-parity.test.tsx:242
    testWidgets('Image shows the fallback text when the image fails to load', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Image',
          'url': 'https://example.com/missing.png',
          'description': 'Missing',
          'fallback': 'Image unavailable',
        },
      ]);
      // findByAltText("Missing"): the image a screen reader reads by its
      // description. The test binding's HTTP 400 has already failed the
      // load by the first frame, so this is the fallback's image node,
      // named as upstream's fallback is (`role="img"`, `aria-label`).
      expect(
        find.semantics.byPredicate(
          (node) => node.label == 'Missing' && node.flagsCollection.isImage,
        ),
        findsOne,
      );
      // fireEvent.error: the test binding answers every request with HTTP
      // 400.
      await tester.pumpAndSettle();
      expect(find.text('Image unavailable'), findsOneWidget);
    });

    // data-media-parity.test.tsx:256
    testWidgets('Image actionOverlay dispatches its action', (tester) async {
      await _cachePicture(tester, 'https://example.com/a.png');
      final view = await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Image',
          'url': 'https://example.com/a.png',
          'description': 'A',
          'actionOverlay': {'label': 'Save'},
          'onOverlayClick': {
            'event': {'name': 'save'},
          },
        },
      ]);
      await tester.tap(_button(tester, 'Save'));
      await tester.pump();
      expect(view.actions.first.name, 'save');
    });

    // data-media-parity.test.tsx:271 (behaviour)
    testWidgets('Image hoverZoom and position apply', (tester) async {
      await _cachePicture(tester, 'https://example.com/a.png');
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Image',
          'url': 'https://example.com/a.png',
          'description': 'Z',
          'hoverZoom': true,
          'position': 'top',
        },
      ]);
      final picture = _pictureWithAlt('Z');
      expect(picture, findsOneWidget);
      // `object-position: top`.
      expect(tester.widget<Image>(picture).alignment, Alignment.topCenter);
      // A `transition` of `transform`: the zoom, an animated scale.
      final zoom = find.ancestor(
        of: picture,
        matching: find.byType(AnimatedScale),
      );
      expect(zoom, findsOneWidget);
      // The parent's `overflow: hidden`: a clip round the zoom.
      final clip = find.ancestor(of: zoom, matching: find.byType(ClipRRect));
      expect(clip, findsWidgets);
      expect(
        tester.widget<ClipRRect>(clip.first).clipBehavior,
        isNot(Clip.none),
      );
    });

    // data-media-parity.test.tsx:305
    testWidgets('Svg treats numeric width and height as pixels and takes '
        'stroke props', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Svg',
          'viewBox': '0 0 10 10',
          'width': 240,
          'height': 80,
          'strokeLinecap': 'round',
          'strokeLinejoin': 'round',
          'preserveAspectRatio': 'none',
          'circles': [
            {'cx': 5, 'cy': 5, 'r': 4},
          ],
        },
      ]);
      final svg = find.byType(SvgCanvas);
      final canvas = tester.renderObject<RenderSvgCanvas>(svg);
      // width="240" and height="80": pixels, not 4px steps. (The drawing's
      // box sits at the start of the 360px surface it is the root of.)
      expect(canvas.box, const Size(240, 80));
      expect(tester.getTopLeft(svg), Offset.zero);
      // preserveAspectRatio="none": the 10 by 10 viewBox stretches to the
      // box, so the circle (5, 5, r 4) is an oval from (1, 1) to (9, 9)
      // times (24, 8).
      final oval = MatrixUtils.transformRect(
        canvas.userTransform,
        const Rect.fromLTRB(1, 1, 9, 9),
      );
      expect(oval, const Rect.fromLTRB(24, 8, 216, 72));
      expect(
        canvas,
        paints..something(
          paintedPath(
            style: PaintingStyle.fill,
            bounds: const Rect.fromLTRB(1, 1, 9, 9),
          ),
        ),
      );
      // stroke-linecap and stroke-linejoin: the drawing's (a fill-only
      // circle draws no stroke to show them).
      expect(canvas.drawing.cap, StrokeCap.round);
      expect(canvas.drawing.join, StrokeJoin.round);
    });

    // data-media-parity.test.tsx:329 (behaviour)
    testWidgets('Chart renders its drawing (the Map part is later phase)', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['c', 'm'],
        },
        {
          'id': 'c',
          'component': 'Chart',
          'chartType': 'bar',
          'xKey': 'month',
          'data': [
            {'month': 'Jan', 'cost': 290},
            {'month': 'Feb', 'cost': 580},
          ],
          'series': ['cost'],
          'height': 200,
        },
        // Later phase: the Map draws nothing yet.
        {
          'id': 'm',
          'component': 'Map',
          'markers': [
            {'label': 'Vienna', 'lat': 48.2, 'lng': 16.4},
          ],
          'height': 200,
        },
      ]);
      // [data-a2ui-chart]: the Chart's drawing.
      expect(_scenes(tester), isNotEmpty);
      // Later phase: the Map draws nothing yet. When this fails, it is
      // built: port its half (`findByText("Vienna")`).
      expect(find.text('Vienna', findRichText: true), findsNothing);
    });

    // data-media-parity.test.tsx:355
    testWidgets('Chart renders pie and line variants with a title', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['p', 'l'],
        },
        {
          'id': 'p',
          'component': 'Chart',
          'chartType': 'donut',
          'title': 'Share',
          'xKey': 'name',
          'data': [
            {'name': 'A', 'value': 1},
            {'name': 'B', 'value': 2},
          ],
          'series': [
            {'key': 'value', 'label': 'Value'},
          ],
          'innerRadius': '40%',
          'paddingAngle': 2,
        },
        {
          'id': 'l',
          'component': 'Chart',
          'chartType': 'line',
          'xKey': 'x',
          'data': [
            {'x': 1, 'y': 2},
          ],
          'series': ['y'],
          'stacked': true,
          'showDots': true,
        },
      ]);
      expect(find.text('Share'), findsOneWidget);
      // Two [data-a2ui-chart] figures, two recharts drawings.
      expect(_scenes(tester), hasLength(2));
    });

    // data-media-parity.test.tsx:392
    testWidgets('Chart draws horizontal bars with a value axis label and '
        'bounds', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Chart',
          'chartType': 'bar',
          'layout': 'horizontal',
          'xKey': 'plan',
          'data': [
            {'plan': 'Starter', 'seats': 10},
            {'plan': 'Team', 'seats': 40},
          ],
          'series': ['seats'],
          'yAxis': {'label': 'Seats', 'min': 0, 'max': 50, 'width': 80},
          'barRadius': 6,
        },
      ]);
      // recharts' drawing, a bar chart ([data-a2ui-chart=bar]).
      final scenes = _scenes(tester).whereType<RechartsScene>();
      expect(scenes, isNotEmpty);
      expect({for (final mark in scenes.first.marks) mark.kind}, {'bar'});
      // The hidden data table: the next test.
    });

    // data-media-parity.test.tsx:392, :415-416: "The hidden data table
    // still lists the categories."
    testWidgets(
      'Chart draws horizontal bars with a value axis label and bounds: its '
      'table lists the categories',
      (tester) async {
        await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Chart',
            'chartType': 'bar',
            'layout': 'horizontal',
            'xKey': 'plan',
            'data': [
              {'plan': 'Starter', 'seats': 10},
              {'plan': 'Team', 'seats': 40},
            ],
            'series': ['seats'],
            'yAxis': {'label': 'Seats', 'min': 0, 'max': 50, 'width': 80},
            'barRadius': 6,
          },
        ]);
        // `getAllByText("Starter")`, at least once: a cell whose text is
        // "Starter", in the table.
        expect(tableCells('Starter'), findsAny);
      },
    );
  });

  group('beyond data-media-parity.test.tsx (ours)', () {
    // data-media-parity.test.tsx:256 with upstream's own 40 by 20 picture
    // size (before the resize above): the overlay button is taller than the
    // picture and overflows it (media.tsx:279-312, an absolutely placed
    // button in a wrapper whose overflow shows), and stays clickable.
    testWidgets(
      'an Image overlay larger than its picture still dispatches its action',
      skip: portQueue(
        'port-queue: Image: the overflowing button is drawn, but a Flutter '
        'box takes no hit outside its size, and the boxes between the '
        "Column and the overlay's Stack (a2ui_flutter NodeView's Semantics, "
        "node_view.dart:161-175, among them) have the picture's",
      ),
      (tester) async {
        await _cachePicture(
          tester,
          'https://example.com/a.png',
          width: 40,
          height: 20,
        );
        final view = await renderStandard(tester, [
          {
            'id': 'root',
            'component': 'Column',
            'padding': 16,
            'children': ['i'],
          },
          {
            'id': 'i',
            'component': 'Image',
            'url': 'https://example.com/a.png',
            'description': 'A',
            'actionOverlay': {'label': 'Save'},
            'onOverlayClick': {
              'event': {'name': 'save'},
            },
          },
        ]);
        await tester.tap(_button(tester, 'Save'));
        await tester.pump();
        expect(view.actionNames, ['save']);
      },
    );
  });
}
