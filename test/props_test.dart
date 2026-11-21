import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/document/props.g.dart' show propEnumValues;
import 'package:flutter_test/flutter_test.dart';

import 'helpers/harness.dart';

String _wire(Enum value) =>
    // The generated enums all have `wire`; Enum does not declare it.
    (value as dynamic).wire as String;

void main() {
  group('generated enums', () {
    test('every value has a distinct wire name', () {
      expect(propEnumValues, isNotEmpty);
      for (final values in propEnumValues) {
        final wires = values.map(_wire).toList();
        expect(wires.toSet(), hasLength(wires.length), reason: '$values');
      }
    });

    test('wire names of the shared enums', () {
      expect(A2uiRadius.values.map((v) => v.wire), [
        '2xs', 'xs', 'sm', 'md', 'lg', 'xl', '2xl', '3xl', '4xl', 'full', //
      ]);
      expect(A2uiWrap.wrapReverse.wire, 'wrap-reverse');
      expect(A2uiJustify.spaceBetween.wire, 'spaceBetween');
      expect(CardVariant.default_.wire, 'default');
      expect(HeadingLevel.one.wire, '1');
      expect(TitleSize.fiveXl.wire, '5xl');
    });

    test('fromWire reads wire names and nothing else', () {
      for (final value in A2uiAlign.values) {
        expect(A2uiAlign.fromWire(value.wire), value);
      }
      expect(A2uiAlign.fromWire('middle'), isNull);
      expect(A2uiAlign.fromWire(3), isNull);
      expect(A2uiAlign.fromWire(null), isNull);
    });
  });

  group('typed props', () {
    ComponentProps props(Map<String, Object?> values) => ComponentProps(values);

    test('apply the defaults the schema descriptions state', () {
      final empty = props(const {});
      expect(BoxProps(empty).direction, BoxDirection.col);
      expect(CardProps(empty).size, A2uiSize.md);
      expect(CardProps(empty).variant, isNull);
      expect(TitleProps(empty).size, TitleSize.md);
      expect(TitleProps(empty).strong, isTrue);
      expect(TextProps(empty).strong, isFalse);
      expect(CaptionProps(empty).size, A2uiSize.lg);
      expect(CaptionProps(empty).fontWeight, A2uiFontWeight.normal);
      expect(LabelProps(empty).size, A2uiTextSize.sm);
      expect(LabelProps(empty).fontWeight, A2uiFontWeight.medium);
      expect(BadgeProps(empty).color, A2uiBadgeColor.secondary);
      expect(BadgeProps(empty).variant, BadgeVariant.soft);
      expect(BadgeProps(empty).pill, isTrue);
      expect(DividerProps(empty).axis, DividerAxis.horizontal);
      expect(CarouselProps(empty).previousLabel, 'Previous');
    });

    test('fall back on wrong types without throwing', () {
      final wrong = props(const {
        'direction': 5,
        'gap': true,
        'border': 'yes',
        'text': ['x'],
        'span': 'two',
      });
      expect(BoxProps(wrong).direction, BoxDirection.col);
      expect(BoxProps(wrong).gap, isTrue);
      expect(BoxProps(wrong).border, isNull);
      expect(TextProps(wrong).text, isNull);
      expect(GridItemProps(wrong).span, isNull);
    });

    test('read through bindings', () {
      final bound = props({
        'text': const ResolvedBinding<Object?>(42),
        'size': const ResolvedBinding<Object?>('sm'),
      });
      expect(TextProps(bound).text, '42');
      expect(
        A2uiTextSize.fromWire(TextProps(bound).raw.value('size')),
        A2uiTextSize.sm,
      );
    });

    test('child lists are empty when absent', () {
      expect(BoxProps(props(const {})).children, isEmpty);
      expect(CardProps(props(const {})).child, isNull);
    });
  });

  testWidgets('every enum value of the phase 1a components renders', (
    tester,
  ) async {
    var n = 0;
    final components = <Map<String, Object?>>[];
    final ids = <String>[];
    void add(Map<String, Object?> component) {
      final id = 'c${n++}';
      ids.add(id);
      components.add({'id': id, ...component});
    }

    Map<String, Object?> label(String id) => {
      'id': id,
      'component': 'Label',
      'text': id,
    };

    for (final value in TitleSize.values) {
      add({'component': 'Title', 'text': value.wire, 'size': value.wire});
    }
    for (final value in A2uiTextSize.values) {
      add({'component': 'Text', 'text': value.wire, 'size': value.wire});
      add({'component': 'Label', 'text': value.wire, 'size': value.wire});
    }
    for (final value in A2uiSize.values) {
      add({'component': 'Caption', 'text': value.wire, 'size': value.wire});
      add({'component': 'Badge', 'label': value.wire, 'size': value.wire});
      add({'component': 'Card', 'size': value.wire, 'children': <String>[]});
    }
    for (final value in A2uiFontWeight.values) {
      add({'component': 'Text', 'text': 'w', 'fontWeight': value.wire});
    }
    for (final value in A2uiTextAlign.values) {
      add({'component': 'Caption', 'text': 'a', 'textAlign': value.wire});
    }
    for (final variant in BadgeVariant.values) {
      for (final color in A2uiBadgeColor.values) {
        add({
          'component': 'Badge',
          'label': 'b',
          'variant': variant.wire,
          'color': color.wire,
        });
      }
    }
    for (final variant in CardVariant.values) {
      for (final shadow in CardShadowStyle.values) {
        add({
          'component': 'Card',
          'variant': variant.wire,
          'shadowStyle': shadow.wire,
          'children': <String>[],
        });
      }
    }
    for (final axis in DividerAxis.values) {
      for (final color in A2uiBorderColor.values) {
        add({'component': 'Divider', 'axis': axis.wire, 'color': color.wire});
      }
    }
    for (final radius in A2uiRadius.values) {
      add({
        'component': 'Box',
        'radius': radius.wire,
        'border': true,
        'borderColor': 'strong',
        'children': <String>[],
      });
    }
    var k = 0;
    for (final direction in BoxDirection.values) {
      for (final align in A2uiAlign.values) {
        for (final justify in A2uiJustify.values) {
          for (final wrap in A2uiWrap.values) {
            final a = 'l${k++}';
            final b = 'l${k++}';
            components
              ..add(label(a))
              ..add(label(b));
            add({
              'component': 'Box',
              'direction': direction.wire,
              'align': align.wire,
              'justify': justify.wire,
              'wrap': wrap.wire,
              'children': [a, b],
            });
          }
        }
      }
    }
    final surfaces = await pumpComponents(tester, [
      {'id': 'root', 'component': 'Column', 'children': ids},
      ...components,
    ], width: 320);
    expect(tester.takeException(), isNull);
    expect(surfaces.errors, isEmpty);
  });
}
