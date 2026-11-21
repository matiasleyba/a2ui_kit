// Parity tests of CopilotKit's standard Image and Icon, ported from
// packages/react-core/src/v2/generative-ui/standard/__tests__/
// media.test.tsx (MIT, (c) Atai Barkai). Each test names its upstream
// line.
//
// Parity for: Image, Icon, Label, Column, Svg
// Signals for: Svg
//
// Upstream renders the media nodes in a Column, then its test-only `Label`
// leaf ("end"); here that leaf is the standard Label, which shows its
// `text` the same way. The manifest test (:39) reads the group object
// `mediaComponents`; here its facts come from the catalog document: the
// group is the run of seven names in the standard catalog's order.
//
// A browser loads or fails an image when the test says so
// (`fireEvent.error`). Here the image cache holds a loaded picture, or a
// load the test fails by hand, since the test binding answers every
// request with HTTP 400. `findByAltText` reads an image's alt text: here
// the Image widget's semantic label, which is also what a screen reader
// reads when the image is not hidden.
//
// Not ported (bound to internals):
// - :57 the inline-style strings `aspectRatio "16/9"`, `width "100%"` and
//   `borderRadius "var(--a2ui-radius-lg, 12px)"`: the image box's aspect
//   ratio 16/9, its width the Column's 360px, and its clip radius 12 are
//   tested instead.
// - :91 `toBeInstanceOf(HTMLImageElement)`, a DOM class: what it guards,
//   that the failed image without hideOnFailure stays an image a screen
//   reader names by its alt text, is tested as an image node named "kept".
// - :114 which element carries `aria-hidden` and `aria-label` (the wrapper
//   or the <img>) and `querySelector("button")`: that the image and its
//   overlay button are drawn and, with the envelope label, hidden from
//   screen readers together is tested instead.
// - :133 `role="img"` and `aria-label="Sales chart"` on the fallback: with
//   `hidden`, the subtree has no semantics in Flutter to carry a role or a
//   name. That the fallback shows and is hidden is tested.
// - :149 the class `svg.lucide-arrow-right`, the `width="24"` attribute,
//   `aria-hidden`, and the icon set loading on first use (here lucide-react's
//   nodes are a compiled table, drawn on the first frame): the glyph is
//   lucide-react 0.525.0's arrow-right, 24px, and no image node for screen
//   readers.
// - :198 `svg.lucide-check` and the count of `<svg>` elements: one Lucide
//   glyph, the check.
// - :240-:249 (in :228) the `<svg>`'s attributes and children: its box
//   (240 by 80), no node for screen readers (`aria-hidden`), the path drawn
//   in the danger token (`stroke="var(--a2ui-color-text-danger,
//   #c1322c)"`), one circle drawn, and the text "hi" drawn (a paragraph
//   painted, of the drawing's text "hi").
// - :262 `toBeInstanceOf(SVGSVGElement)` (in :252), a DOM class: the image
//   node is the drawing's.
//
// Later phase (no Dart yet):
// - :210 "renders a Favicon from the host of the URL": Favicon.
// - :264, :290, :304 and :354 (YouTube embeds, page links, the native
//   player and its captions, a file that does not load): Video.
// - :375 "renders HtmlView in a fully sandboxed iframe": HtmlView.

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/document/catalog_document.g.dart';
import 'package:a2ui_kit/src/foundation/layout/replaced_box.dart';
import 'package:a2ui_kit/src/foundation/svg/svg_drawing.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsFlag;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/paint_calls.dart';
import '../helpers/parity.dart';

/// Renders [nodes] in a Column, then a Label "end" after them: upstream's
/// `renderInColumn` (media.test.tsx:26).
Future<ParitySurface> _renderInColumn(
  WidgetTester tester,
  List<Map<String, Object?>> nodes,
) => renderStandard(tester, [
  {
    'id': 'root',
    'component': 'Column',
    'children': [for (final node in nodes) node['id'], 'end'],
  },
  ...nodes,
  {'id': 'end', 'component': 'Label', 'text': 'end'},
]);

/// The Image widgets whose alt text is [alt]: upstream's
/// `findByAltText(alt)`, which finds a hidden image too.
Finder _imageWithAlt(String alt) => find.byWidgetPredicate(
  (widget) => widget is Image && widget.semanticLabel == alt,
  description: 'an image with the alt text "$alt"',
);

/// The URL the image with the alt text [alt] loads: its `src`.
String? _srcOf(WidgetTester tester, String alt) =>
    switch (tester.widget<Image>(_imageWithAlt(alt)).image) {
      final NetworkImage image => image.url,
      _ => null,
    };

/// Puts a loaded picture in the image cache for each of [urls], as a
/// browser that loads them.
Future<void> _loaded(WidgetTester tester, List<String> urls) async {
  final picture = (await tester.runAsync(
    () => createTestImage(width: 40, height: 20),
  ))!;
  addTearDown(picture.dispose);
  for (final url in urls) {
    PaintingBinding.instance.imageCache.putIfAbsent(
      NetworkImage(url),
      () => OneFrameImageStreamCompleter(
        SynchronousFuture(ImageInfo(image: picture.clone())),
      ),
    );
  }
  addTearDown(PaintingBinding.instance.imageCache.clear);
}

/// A load of [url] that ends only when the test fails it.
_PendingImage _pending(String url) {
  final load = _PendingImage();
  PaintingBinding.instance.imageCache.putIfAbsent(
    NetworkImage(url),
    () => load,
  );
  addTearDown(PaintingBinding.instance.imageCache.clear);
  return load;
}

/// An image load the test fails by hand.
class _PendingImage extends ImageStreamCompleter {
  /// Fails the load: a browser's `error` event on the `<img>`
  /// (`fireEvent.error(img)`).
  void fail() => reportError(
    exception: Exception('The image failed to load.'),
    silent: true,
  );
}

/// The description of [name] in the catalog document.
Object? _description(String name) =>
    switch ((a2uiKitCatalogDocument['components']! as Map)[name]) {
      final Map<Object?, Object?> component => component['description'],
      _ => null,
    };

void main() {
  group('mediaComponents', () {
    // media.test.tsx:39
    test('is valid input for createGenerativeUI, with a description for '
        'every component', () {
      const names = [
        'Image',
        'Icon',
        'Favicon',
        'Svg',
        'Video',
        'AudioPlayer',
        'HtmlView',
      ];
      final start = standardComponentNames.indexOf(names.first);
      expect(
        standardComponentNames.sublist(start, start + names.length),
        names,
      );
      // `toEqual` on the group's keys fails on an extra member too: the
      // next group (composites) starts right after HtmlView.
      expect(standardComponentNames[start + names.length], 'LinkCard');
      for (final name in names) {
        expect(_description(name), matches(RegExp(r'\S')), reason: name);
      }
    });
  });

  group('standard media', () {
    // media.test.tsx:57
    testWidgets('renders an Image with its alt text, ratio and radius', (
      tester,
    ) async {
      await _loaded(tester, ['https://example.com/a.png']);
      await _renderInColumn(tester, [
        {
          'id': 'i',
          'component': 'Image',
          'url': 'https://example.com/a.png',
          'description': 'pic',
          'aspectRatio': '16/9',
          'radius': 'lg',
        },
      ]);
      expect(find.bySemanticsLabel('pic'), findsOneWidget);
      expect(_srcOf(tester, 'pic'), 'https://example.com/a.png');
      final box = find
          .ancestor(
            of: _imageWithAlt('pic'),
            matching: find.byType(ReplacedBox),
          )
          .first;
      // aspect-ratio: 16/9.
      expect(tester.widget<ReplacedBox>(box).sizing.aspectRatio, 16 / 9);
      // width: 100% of the Column, which is the 360px surface.
      expect(tester.getSize(box).width, 360);
      // border-radius: var(--a2ui-radius-lg, 12px).
      final clip = find
          .ancestor(of: _imageWithAlt('pic'), matching: find.byType(ClipRRect))
          .first;
      expect(
        tester.widget<ClipRRect>(clip).borderRadius,
        BorderRadius.circular(12),
      );
    });

    // media.test.tsx:73
    testWidgets('reads the Image src from the data model', (tester) async {
      await _loaded(tester, ['https://example.com/b.png']);
      await renderStandard(
        tester,
        [
          {
            'id': 'root',
            'component': 'Image',
            'url': {'@path': '/url'},
            'description': 'bound',
          },
        ],
        data: {'url': 'https://example.com/b.png'},
      );
      expect(_srcOf(tester, 'bound'), 'https://example.com/b.png');
    });

    // media.test.tsx:91
    testWidgets(
      'removes an Image that fails to load when hideOnFailure is set',
      (tester) async {
        final load = _pending('https://example.com/broken.png');
        await _renderInColumn(tester, [
          {
            'id': 'a',
            'component': 'Image',
            'url': 'https://example.com/broken.png',
            'description': 'hidden',
            'hideOnFailure': true,
          },
          {
            'id': 'b',
            'component': 'Image',
            'url': 'https://example.com/broken.png',
            'description': 'kept',
          },
        ]);
        expect(_imageWithAlt('hidden'), findsOneWidget);
        // Both images share the URL, so one failed load fails both.
        load.fail();
        await tester.pump();
        expect(_imageWithAlt('hidden'), findsNothing);
        expect(find.bySemanticsLabel(RegExp('hidden')), findsNothing);
        // getByAltText("kept"): the whole name.
        expect(find.bySemanticsLabel('kept'), findsOneWidget);
      },
    );

    // media.test.tsx:91, `toBeInstanceOf(HTMLImageElement)`: without a
    // fallback the failed `<img alt>` stays (media.tsx:247-266), which a
    // screen reader reads as an image named "kept".
    testWidgets(
      'keeps a failed Image without a fallback as an image named by its '
      'description',
      (tester) async {
        final load = _pending('https://example.com/broken.png');
        await _renderInColumn(tester, [
          {
            'id': 'b',
            'component': 'Image',
            'url': 'https://example.com/broken.png',
            'description': 'kept',
          },
        ]);
        load.fail();
        await tester.pump();
        expect(
          find.semantics.byPredicate(
            (node) => node.label == 'kept' && node.flagsCollection.isImage,
          ),
          findsOne,
        );
      },
    );

    // media.test.tsx:114
    testWidgets('hides an Image together with its action overlay', (
      tester,
    ) async {
      await _loaded(tester, ['https://example.com/a.png']);
      await _renderInColumn(tester, [
        {
          'id': 'a',
          'component': 'Image',
          'url': 'https://example.com/a.png',
          'description': 'Chart',
          'actionOverlay': {'label': 'Open'},
          'accessibility': {'hidden': true, 'label': 'Sales chart'},
        },
      ]);
      expect(_imageWithAlt('Chart'), findsOneWidget);
      // The overlay button is drawn inside the hidden wrapper.
      expect(find.text('Open'), findsOneWidget);
      // aria-hidden on the wrapper: the image, its name and its button are
      // hidden from screen readers together.
      expect(find.bySemanticsLabel(RegExp('Chart')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Sales chart')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Open')), findsNothing);
    });

    // media.test.tsx:133
    testWidgets('keeps the accessibility of the envelope on the fallback of '
        'a failed Image', (tester) async {
      final load = _pending('https://example.com/broken.png');
      await _renderInColumn(tester, [
        {
          'id': 'a',
          'component': 'Image',
          'url': 'https://example.com/broken.png',
          'description': 'Chart',
          'fallback': 'No chart',
          'accessibility': {'label': 'Sales chart', 'hidden': true},
        },
      ]);
      expect(_imageWithAlt('Chart'), findsOneWidget);
      load.fail();
      await tester.pump();
      expect(find.text('No chart'), findsOneWidget);
      // aria-hidden="true" on the fallback: neither its name nor its text
      // reaches a screen reader.
      expect(find.bySemanticsLabel(RegExp('Sales chart')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('No chart')), findsNothing);
    });

    // media.test.tsx:149
    testWidgets('loads a lucide Icon on first use and hides it from screen '
        'readers', (tester) async {
      await _renderInColumn(tester, [
        {'id': 'c', 'component': 'Icon', 'name': 'arrow-right', 'size': 'lg'},
      ]);
      final glyph = tester.widget<LucideGlyph>(find.byType(LucideGlyph));
      // svg.lucide-arrow-right: lucide-react 0.525.0's arrow-right node.
      expect(
        glyph.icon,
        lucideIcon('arrow-right', release: LucideRelease.reactCore),
      );
      expect(glyph.icon.name, 'ArrowRight');
      // aria-hidden="true": the icon adds nothing for screen readers, no
      // image node and no label (the Column's "end" is all they read).
      expect(find.semantics.byFlag(SemanticsFlag.isImage), findsNothing);
      expect(
        find.semantics.byPredicate(
          (node) => node.label.isNotEmpty && node.label != 'end',
        ),
        findsNothing,
      );
      // width="24".
      expect(glyph.size, 24);
    });

    // media.test.tsx:166
    testWidgets('names an Icon with a label for screen readers', (
      tester,
    ) async {
      await _renderInColumn(tester, [
        {'id': 'c', 'component': 'Icon', 'name': 'check', 'label': 'Done'},
      ]);
      // findByRole("img", { name: "Done" }), without aria-hidden.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Done')),
        isSemantics(label: 'Done', isImage: true, isHidden: false),
      );
    });

    // media.test.tsx:177, both halves (the Icon's is also pinned on its own
    // in the group below).
    testWidgets(
      'names an Icon and an Svg by the envelope label, like the label prop',
      (tester) async {
        await _renderInColumn(tester, [
          {
            'id': 'i',
            'component': 'Icon',
            'name': 'check',
            'accessibility': {
              'label': 'Done',
              'description': 'The step is complete',
            },
          },
          {
            'id': 's',
            'component': 'Svg',
            'viewBox': '0 0 10 10',
            'circles': [
              {'cx': 5, 'cy': 5, 'r': 4},
            ],
            'accessibility': {'label': 'Dot'},
          },
        ]);
        final icon = tester.getSemantics(find.bySemanticsLabel('Done'));
        // findByRole("img", { name: "Done" }).
        expect(icon, isSemantics(label: 'Done', isImage: true));
        // aria-description.
        expect(icon, isSemantics(hint: 'The step is complete'));
        // findByRole("img", { name: "Dot" }): the <svg>.
        expect(
          find.semantics.byPredicate(
            (node) => node.label == 'Dot' && node.flagsCollection.isImage,
          ),
          findsOne,
        );
      },
    );

    // media.test.tsx:228
    testWidgets('draws an Svg from shapes with token colors and pixel sizes', (
      tester,
    ) async {
      await _renderInColumn(tester, [
        {
          'id': 's',
          'component': 'Svg',
          'viewBox': '0 0 10 10',
          'width': 240,
          'height': 80,
          'paths': [
            {'d': 'M0 0L10 10', 'stroke': 'danger'},
          ],
          'circles': [
            {'cx': 5, 'cy': 5, 'r': 4},
          ],
          'texts': [
            {'x': 1, 'y': 9, 'text': 'hi'},
          ],
        },
      ]);
      expect(find.text('end'), findsOneWidget);
      final svg = find.byType(SvgCanvas);
      // width="240", height="80".
      expect(tester.getSize(svg), const Size(240, 80));
      // aria-hidden="true": no image node, no name (the Column's "end" is
      // all a screen reader reads).
      expect(find.semantics.byFlag(SemanticsFlag.isImage), findsNothing);
      expect(
        find.semantics.byPredicate(
          (node) => node.label.isNotEmpty && node.label != 'end',
        ),
        findsNothing,
      );
      final canvas = tester.renderObject<RenderSvgCanvas>(svg);
      expect(
        canvas,
        paints
          // One circle: filled, (5, 5) r 4.
          ..something(
            paintedPath(
              style: PaintingStyle.fill,
              bounds: const Rect.fromLTRB(1, 1, 9, 9),
            ),
          )
          // The path, stroked in var(--a2ui-color-text-danger, #c1322c).
          ..something(
            paintedPath(
              style: PaintingStyle.stroke,
              color: const Color(0xffc1322c),
              bounds: const Rect.fromLTRB(0, 0, 10, 10),
            ),
          )
          // The text.
          ..paragraph(),
      );
      expect(
        canvas.drawing.shapes.whereType<SvgGeometry>().where(
          (shape) => shape.kind == 'circle',
        ),
        hasLength(1),
      );
      expect(
        [
          for (final text in canvas.drawing.shapes.whereType<SvgText>())
            text.text,
        ],
        ['hi'],
      );
    });

    // media.test.tsx:252
    testWidgets('names an Svg with a label for screen readers', (tester) async {
      await _renderInColumn(tester, [
        {
          'id': 's',
          'component': 'Svg',
          'label': 'Floor plan',
          'rects': [
            {'x': 0, 'y': 0, 'width': 4, 'height': 4},
          ],
        },
      ]);
      // findByRole("img", { name: "Floor plan" }): the drawing's image node.
      expect(
        tester.getSemantics(find.byType(SvgCanvas)),
        isSemantics(label: 'Floor plan', isImage: true),
      );
    });

    // media.test.tsx:198
    testWidgets('renders nothing for an Icon with an unknown name', (
      tester,
    ) async {
      await _renderInColumn(tester, [
        {'id': 'c', 'component': 'Icon', 'name': 'definitely-not-an-icon'},
        {'id': 'k', 'component': 'Icon', 'name': 'check'},
      ]);
      // One glyph (one <svg>), and it is the check.
      final glyphs = tester.widgetList<LucideGlyph>(find.byType(LucideGlyph));
      expect(
        [for (final glyph in glyphs) glyph.icon],
        [lucideIcon('check', release: LucideRelease.reactCore)],
      );
    });
  });

  group('beyond media.test.tsx (ours)', () {
    // media.test.tsx:177's Icon half on its own (the test waits for the
    // Svg): the envelope names the icon like `label` does (media.tsx:
    // 401-402), one image node. Without the envelope's label, the `label`
    // prop names it and the envelope's description describes it.
    testWidgets('names an Icon by the envelope label: one image node', (
      tester,
    ) async {
      await _renderInColumn(tester, [
        {
          'id': 'i',
          'component': 'Icon',
          'name': 'check',
          'label': 'Tick',
          'accessibility': {
            'label': 'Done',
            'description': 'The step is complete',
          },
        },
        {
          'id': 'j',
          'component': 'Icon',
          'name': 'x',
          'label': 'Cross',
          'accessibility': {'description': 'Not done'},
        },
      ]);
      final done = find.semantics.byPredicate(
        (node) => node.label == 'Done' && node.flagsCollection.isImage,
      );
      expect(done, findsOne);
      expect(done.evaluate().single.hint, 'The step is complete');
      expect(find.semantics.byLabel('Done'), findsOne);
      expect(find.semantics.byLabel('Tick'), findsNothing);
      final cross = find.semantics.byPredicate(
        (node) => node.label == 'Cross' && node.flagsCollection.isImage,
      );
      expect(cross, findsOne);
      expect(cross.evaluate().single.hint, 'Not done');
      expect(find.semantics.byFlag(SemanticsFlag.isImage), findsExactly(2));
    });

    // media.test.tsx:114 and :133 without `hidden`, where where the name sits
    // can be heard: upstream's `{...aria}` puts the envelope's label on the
    // `<img>` (over its `alt`) and on the fallback's `role="img"` element
    // (media.tsx:220-225), so a screen reader reads one image, "Sales
    // chart".
    SemanticsFinder salesChartImage() => find.semantics.byPredicate(
      (node) => node.label == 'Sales chart' && node.flagsCollection.isImage,
    );

    testWidgets('names a loaded Image by the envelope label: one image node', (
      tester,
    ) async {
      await _loaded(tester, ['https://example.com/a.png']);
      await _renderInColumn(tester, [
        {
          'id': 'a',
          'component': 'Image',
          'url': 'https://example.com/a.png',
          'description': 'Chart',
          'accessibility': {'label': 'Sales chart'},
        },
      ]);
      expect(salesChartImage(), findsOne);
      expect(find.semantics.byFlag(SemanticsFlag.isImage), findsOne);
      // One node named so: the image, not also a wrapper around it.
      expect(find.semantics.byLabel('Sales chart'), findsOne);
    });

    testWidgets(
      'names the fallback of a failed Image by the envelope label: one '
      'image node',
      (tester) async {
        final load = _pending('https://example.com/broken.png');
        await _renderInColumn(tester, [
          {
            'id': 'a',
            'component': 'Image',
            'url': 'https://example.com/broken.png',
            'description': 'Chart',
            'fallback': 'No chart',
            'accessibility': {'label': 'Sales chart'},
          },
        ]);
        load.fail();
        await tester.pump();
        expect(find.text('No chart'), findsOneWidget);
        expect(salesChartImage(), findsOne);
        expect(find.semantics.byFlag(SemanticsFlag.isImage), findsOne);
        // One node named so: the fallback, not also a wrapper around it.
        expect(find.semantics.byLabel('Sales chart'), findsOne);
      },
    );
  });
}
