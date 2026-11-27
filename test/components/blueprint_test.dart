import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

final _light = A2uiKitTheme.playground(Brightness.light);

CatalogImplementation get _catalog =>
    a2uiKitCatalog(options: const A2uiKitOptions(includeBlueprint: true));

Map<String, Object?> _frame(String id, String of, {num? h}) => {
  'id': id,
  'component': 'Blueprint',
  'of': of,
  'state': 'streaming',
  'h': ?h,
};

/// The field opacity of the frame captioned [name].
double _opacity(WidgetTester tester, String name) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(name), matching: find.byType(Opacity)),
    )
    .opacity;

/// The frame captioned [name].
Size _frameOf(WidgetTester tester, String name) {
  final paint = find.ancestor(
    of: find.text(name),
    matching: find.byType(CustomPaint),
  );
  return tester.getSize(paint.first);
}

void main() {
  test('stays out of the exported catalog until asked for', () {
    expect(a2uiKitCatalog().components.containsKey('Blueprint'), isFalse);
    expect(_catalog.components.containsKey('Blueprint'), isTrue);
    expect(_catalog.components, hasLength(122));
  });

  testWidgets('sizes each frame for the component it stands in for', (
    tester,
  ) async {
    await pumpComponents(
      tester,
      [
        {
          'id': 'root',
          'component': 'Column',
          'gap': 3,
          'children': ['head', 'stat', 'chart', 'text', 'short', 'tall', 'id'],
        },
        _frame('head', 'Heading'),
        _frame('stat', 'Stat'),
        _frame('chart', 'BarChart'),
        _frame('text', 'Text'),
        _frame('short', 'Card', h: 10),
        _frame('tall', 'Card', h: 300),
        _frame('id', '#stops'),
      ],
      catalog: _catalog,
      theme: _light,
    );
    expect(tester.takeException(), isNull);
    expect(_frameOf(tester, 'Heading'), const Size(360, 64));
    expect(_frameOf(tester, 'Stat'), const Size(360, 104));
    expect(_frameOf(tester, 'BarChart'), const Size(360, 260));
    // Text's slot is 22px; the frame's minimum is 28.
    expect(_frameOf(tester, 'Text'), const Size(360, 28));
    // `#stops` is an id, not a type: the caption drops the mark, and the
    // height is the unknown-type slot.
    expect(_frameOf(tester, 'stops'), const Size(360, 72));
    expect(find.text('#stops'), findsNothing);
    final cards = find.text('Card');
    expect(
      tester.getSize(
        find
            .ancestor(of: cards.first, matching: find.byType(CustomPaint))
            .first,
      ),
      const Size(360, 28),
    );
    expect(
      tester.getSize(
        find.ancestor(of: cards.last, matching: find.byType(CustomPaint)).first,
      ),
      const Size(360, 300),
    );
  });

  testWidgets('hideName drops the caption and keeps the slot', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpComponents(
      tester,
      [
        {
          'id': 'root',
          'component': 'Blueprint',
          'of': 'BarChart',
          'hideName': true,
          'state': 'streaming',
        },
      ],
      catalog: _catalog,
      theme: _light,
    );
    await tester.pumpAndSettle();
    expect(find.text('BarChart'), findsNothing);
    expect(tester.getSize(find.byType(CustomPaint)), const Size(360, 260));
  });

  testWidgets('traces the outline, then holds the frame', (tester) async {
    await pumpComponents(
      tester,
      [_frame('root', 'BarChart')],
      catalog: _catalog,
      theme: _light,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    final fading = _opacity(tester, 'BarChart');
    expect(fading, greaterThan(0));
    expect(fading, lessThan(1));
    await tester.pump(const Duration(milliseconds: 800));
    expect(_opacity(tester, 'BarChart'), 1);
    expect(_frameOf(tester, 'BarChart'), const Size(360, 260));
    expect(
      tester.widget<Text>(find.text('BarChart')).style!.color,
      const Color(0xff9a9a9a),
    );
  });

  testWidgets('stands fully drawn under reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpComponents(
      tester,
      [_frame('root', 'Stat')],
      catalog: _catalog,
      theme: A2uiKitTheme.playground(Brightness.dark),
      brightness: Brightness.dark,
    );
    await tester.pumpAndSettle();
    expect(_frameOf(tester, 'Stat'), const Size(360, 104));
    expect(_opacity(tester, 'Stat'), 1);
    expect(
      tester.widget<Text>(find.text('Stat')).style!.color,
      const Color(0xff6f6f6f),
    );
  });
}
