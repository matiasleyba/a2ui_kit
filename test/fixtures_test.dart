import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/svg/svg_drawing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'goldens/samples.dart';
import 'helpers/harness.dart';

/// CopilotKit's `standard-all.json`: one surface with all 69 standard
/// components and its data model.
List<Map<String, Object?>> get _standardAll =>
    (withIdentifierIds((fixture('standard-all.json')! as Map)['components'])!
            as List)
        .cast<Map<String, Object?>>();

Object? get _standardAllData => (fixture('standard-all.json')! as Map)['data'];

void main() {
  for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0), (720.0, 1.0)]) {
    for (final brightness in Brightness.values) {
      testWidgets('standard-all renders at $width px, text scale $scale, '
          '${brightness.name}, without an exception', (tester) async {
        final surfaces = await pumpComponents(
          tester,
          _standardAll,
          data: _standardAllData,
          width: width,
          textScale: scale,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        expect(surfaces.errors, isEmpty);
        expect(find.text('Standard catalog fixture'), findsOneWidget);
        expect(find.text('Grid item one', findRichText: true), findsOneWidget);
        // The phase 1b components of the fixture.
        expect(find.text('Markdown heading', findRichText: true), findsOne);
        expect(find.text('CopilotKit'), findsOneWidget);
        // The TextField's label and the second Table's header cell.
        expect(find.text('Name'), findsNWidgets(2));
        expect(find.text('Plan'), findsOneWidget);
        expect(find.text('Annual billing'), findsOneWidget);
        expect(find.text('Size'), findsOneWidget);
        expect(find.text('Submit'), findsOneWidget);
        expect(find.text('Buy milk'), findsOneWidget);
        expect(find.text('First'), findsOneWidget);
        expect(find.byType(LucideGlyph), findsWidgets);
        // The tier 1 data components: a Table from columns and rows, one
        // from sections with a template row at /people, a Flow, an Svg.
        expect(find.text('Feature'), findsOneWidget);
        expect(find.text(r'$29/seat'), findsOneWidget);
        expect(find.text('Score'), findsOneWidget);
        expect(find.text('Linus'), findsOneWidget);
        expect(find.text('91'), findsOneWidget);
        expect(find.text('Flow item'), findsOneWidget);
        expect(find.byType(SvgCanvas), findsOneWidget);
      });
    }
  }

  testWidgets('every golden sample renders at 320 px and text scale 2', (
    tester,
  ) async {
    for (final MapEntry(key: name, value: components)
        in goldenSamples.entries) {
      for (final brightness in Brightness.values) {
        final surfaces = await pumpComponents(
          tester,
          components,
          width: 320,
          textScale: 2,
          brightness: brightness,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: name);
        expect(surfaces.errors, isEmpty, reason: name);
      }
    }
  });

  testWidgets('standard-all renders under the standard catalog too', (
    tester,
  ) async {
    final surfaces = TestSurfaces(catalog: a2uiKitStandardCatalog())
      ..create(
        _standardAll,
        data: _standardAllData,
        catalogId: kA2uiStandardCatalogId,
      );
    addTearDown(surfaces.dispose);
    await tester.pumpWidget(surfaceApp(surfaces.surface));
    expect(tester.takeException(), isNull);
    expect(surfaces.errors, isEmpty);
    expect(find.text('Standard catalog fixture'), findsOneWidget);
  });

  testWidgets('the first worked example renders', (tester) async {
    final examples = fixture('examples.json')! as List;
    final surfaces = TestSurfaces();
    addTearDown(surfaces.dispose);
    surfaces.apply(withIdentifierIds(examples.first)! as List);
    expect(surfaces.surfaces, isNotEmpty);
    await tester.pumpWidget(surfaceApp(surfaces.surfaces.values.first));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Q3 sales by region', findRichText: true), findsOneWidget);
    expect(find.text('Revenue', findRichText: true), findsOneWidget);
    expect(find.bySemanticsLabel(r'$18.4M'), findsOneWidget);
    expect(find.text('Work email', findRichText: true), findsOneWidget);
    expect(find.text('Subscribe', findRichText: true), findsOneWidget);
  });

  for (final replay in ['sales-dashboard', 'tokyo-trip', 'lisbon-weather']) {
    testWidgets('every frame of the $replay replay renders at 320 px', (
      tester,
    ) async {
      final frames =
          ((fixture('replays/$replay.json')! as Map)['frames']! as List)
              .cast<Map<String, Object?>>();
      expect(frames, isNotEmpty);
      // Each frame holds the whole surface so far, from createSurface on.
      for (final frame in frames) {
        final surfaces = TestSurfaces();
        addTearDown(surfaces.dispose);
        surfaces.apply(withIdentifierIds(frame['ops'])! as List);
        if (surfaces.surfaces.isEmpty) continue;
        await tester.pumpWidget(
          surfaceApp(surfaces.surfaces.values.first, width: 320, textScale: 2),
        );
        expect(tester.takeException(), isNull);
      }
      // The last frame's headings, section titles and stat labels show.
      await tester.pumpAndSettle();
      final last = (withIdentifierIds(frames.last['ops'])! as List)
          .cast<Map<Object?, Object?>>();
      final shown = [
        for (final message in last)
          for (final component in [
            ...?((message['updateComponents'] as Map?)?['components'] as List?),
            ...?((message['createSurface'] as Map?)?['components'] as List?),
          ])
            if (component case {
              'component': 'Heading' || 'Section' || 'Stat' || 'BarChart',
            })
              switch (component) {
                {'component': 'Stat', 'label': final String label} => label,
                {'component': 'Section', 'title': final String title} => title,
                {'component': 'Heading', 'text': final String text} => text,
                // Since phase 2a the BarCharts draw, titles and all.
                {'component': 'BarChart', 'title': final String title} => title,
                _ => null,
              },
      ].nonNulls.toSet();
      // (The Lisbon replay has a WeatherCard and a BarChart.)
      for (final text in shown) {
        expect(find.text(text, findRichText: true), findsWidgets, reason: text);
      }
    });
  }
}
