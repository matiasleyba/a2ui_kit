import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/svg/svg_drawing.dart';

/// The components whose root takes CopilotKit's shared layout props
/// (`layoutStyle`), and so their flex item props too.
const Set<String> layoutContainerTypes = {
  'Box', 'Column', 'Row', 'Grid', 'GridItem', 'Card', 'Flow', 'FlowItem', //
  'Carousel', 'CarouselItem', 'CarouselMediaItem', 'Pressable', 'Form',
};

/// How [child] takes part in the flex container around it, from its type
/// and props, as its React renderer styles its root element.
///
/// Numbers are lengths of [step] pixels; `em` lengths resolve against
/// [fontSize].
A2uiFlexItemStyle flexItemStyleOf(
  KitNode child, {
  double step = 4,
  double fontSize = 16,
}) {
  final props = ComponentProps(child.props.peek());
  A2uiLength? steps(Object? value) {
    final length = A2uiLength.steps(value, step: step);
    return length is A2uiEm
        ? A2uiLength.px(length.resolve(fontSize: fontSize))
        : length;
  }

  final weight = props.number('weight');
  switch (child.type) {
    case final type when layoutContainerTypes.contains(type):
      final flex = props.number('flex');
      final overflow =
          (props.boolean('scrollable') ?? false) ||
          (props.boolean('clip') ?? false);
      final fixed = type == 'CarouselItem' || type == 'CarouselMediaItem';
      final grows = flex != null && flex >= 0;
      return A2uiFlexItemStyle(
        grow: fixed ? 0 : (weight ?? (grows ? flex : 0)),
        shrink: fixed ? 0 : 1,
        basis: grows && !fixed ? const A2uiLength.percent(0) : null,
        width: steps(props.value('width')),
        height: steps(props.value('height')),
        minWidth:
            steps(props.value('minWidth') ?? props.value('minSize')) ??
            A2uiLength.zero,
        maxWidth:
            steps(props.value('maxWidth') ?? props.value('maxSize')) ??
            const A2uiLength.percent(1),
        minHeight:
            steps(props.value('minHeight') ?? props.value('minSize')) ??
            (overflow ? A2uiLength.zero : null),
        maxHeight: steps(props.value('maxHeight') ?? props.value('maxSize')),
      );
    case 'Text':
      final clipped = _clipsText(props);
      if (props.boolean('inline') ?? false) {
        return A2uiFlexItemStyle(
          width: steps(props.value('width')),
          minWidth: clipped ? A2uiLength.zero : null,
        );
      }
      return A2uiFlexItemStyle(
        grow: weight ?? 0,
        width: steps(props.value('width')),
        minWidth: A2uiLength.zero,
      );
    case 'Title' || 'Label':
      return A2uiFlexItemStyle(
        width: steps(props.value('width')),
        minWidth: _clipsText(props) ? A2uiLength.zero : null,
      );
    case 'Caption':
      return A2uiFlexItemStyle(
        minWidth: _clipsText(props) ? A2uiLength.zero : null,
      );
    case 'Badge':
      return A2uiFlexItemStyle(
        shrink: 0,
        maxWidth: steps(props.value('maxWidth')),
        minWidth: A2uiLength.zero,
      );
    case 'Spacer':
      final min = steps(props.value('minSize') ?? 2);
      return A2uiFlexItemStyle(
        grow: 1,
        basis: const A2uiLength.percent(0),
        minWidth: min,
        minHeight: min,
      );
    case 'Divider':
      final vertical = props.value('axis') == 'vertical';
      return A2uiFlexItemStyle(
        grow: weight ?? 0,
        shrink: 0,
        alignSelf: A2uiAlign.stretch,
        width: vertical ? null : const A2uiLength.percent(1),
      );
    case 'Button':
      // inline-flex, or flex at 100% with `block`; never wider than its
      // container.
      return A2uiFlexItemStyle(
        grow: weight ?? 0,
        width: (props.boolean('block') ?? false)
            ? const A2uiLength.percent(1)
            : null,
        maxWidth: const A2uiLength.percent(1),
      );
    case 'TextField' || 'TextArea' || 'DateTimeInput':
      // The field's wrapper: `width: 100%; min-width: 0; flex-grow: weight`.
      return A2uiFlexItemStyle(
        grow: weight ?? 0,
        width: const A2uiLength.percent(1),
        minWidth: A2uiLength.zero,
      );
    case 'Select':
      // Select's wrapper takes no weight.
      return const A2uiFlexItemStyle(
        width: A2uiLength.percent(1),
        minWidth: A2uiLength.zero,
      );
    case 'RadioGroup':
      return const A2uiFlexItemStyle(minWidth: A2uiLength.zero);
    case 'Icon':
      return A2uiFlexItemStyle(grow: weight ?? 0, shrink: 0);
    case 'Svg':
      // The `<svg>`'s width and height attributes (media.tsx:506-507):
      // pixels for a number, unlike the 4px steps of the layout props.
      return A2uiFlexItemStyle(
        width: svgLengthOf(
          props.value('width') ?? props.value('size') ?? '100%',
        ),
        height: svgLengthOf(props.value('height') ?? props.value('size')),
      );
    case 'Table':
      // `.a2ui-std-table-wrap{width:100%;max-width:100%;min-width:0}`
      // (styles.ts:73).
      return const A2uiFlexItemStyle(
        width: A2uiLength.percent(1),
        minWidth: A2uiLength.zero,
        maxWidth: A2uiLength.percent(1),
      );
    case 'Image':
      final variant = props.value('variant');
      final variantWidth = switch (variant) {
        'icon' => const A2uiLength.px(24),
        'avatar' => const A2uiLength.px(40),
        'smallFeature' ||
        'largeFeature' ||
        'header' => const A2uiLength.percent(1),
        _ => null,
      };
      return A2uiFlexItemStyle(
        grow: weight ?? 0,
        width:
            steps(props.value('width')) ??
            (props.value('aspectRatio') != null
                ? const A2uiLength.percent(1)
                : variantWidth),
        height:
            steps(props.value('height')) ??
            switch (variant) {
              'icon' => const A2uiLength.px(24),
              'avatar' => const A2uiLength.px(40),
              _ => null,
            },
        minWidth: steps(props.value('minWidth')),
        minHeight: steps(props.value('minHeight')),
        maxWidth:
            steps(props.value('maxWidth')) ??
            (variant == 'smallFeature'
                ? const A2uiLength.px(160)
                : const A2uiLength.percent(1)),
        maxHeight: steps(props.value('maxHeight')),
      );
    case 'Stat':
      // `w-full min-w-0 flex-1`.
      return const A2uiFlexItemStyle(
        grow: 1,
        basis: A2uiLength.percent(0),
        width: A2uiLength.percent(1),
        minWidth: A2uiLength.zero,
      );
    case 'StatGroup' || 'KeyValueList' || 'Section' || 'Alert' || 'Callout':
      // `w-full min-w-0`.
      return const A2uiFlexItemStyle(
        width: A2uiLength.percent(1),
        minWidth: A2uiLength.zero,
      );
    case 'Heading':
      return const A2uiFlexItemStyle(minWidth: A2uiLength.zero);
    default:
      return A2uiFlexItemStyle(grow: weight ?? 0);
  }
}

/// Whether [child]'s root has a preferred aspect ratio (CSS `aspect-ratio`),
/// which a grid's `normal` alignment keeps rather than stretching it (CSS
/// Grid 1, section 6.2): a FlowItem's (`1 / 1` unless set, react-core
/// standard/layout.tsx:563-567) or a layout container's `aspectRatio`
/// (`layoutStyle`, shared standard/style-helpers.ts:165), when CSS reads it.
bool hasAspectRatio(KitNode child) {
  final props = ComponentProps(child.props.peek());
  final ratio = child.type == 'FlowItem'
      ? props.value('aspectRatio') ?? '1 / 1'
      : layoutContainerTypes.contains(child.type)
      ? props.value('aspectRatio')
      : null;
  return cssAspectRatio(ratio) != null;
}

/// Whether [child]'s root is inline-level, so that in a block container
/// (a Table cell) it sits on a line with the text around it rather than
/// on a line of its own: a Badge (`inline-flex`, text.tsx:337-339), a Link
/// (an `<a>`, or `inline-flex`, text.tsx:452-493), a Button that is not
/// `block` (`inline-flex`, inputs.tsx:303), a Text or Icon with `inline`
/// (text.tsx:176, media.tsx:427), a Bold, Italic, Underline or
/// Strikethrough (a `<strong>`, `<em>`, `<u>`, `<s>`, text.tsx:257-298),
/// and a Math that is not `block` (a `<span>`, text.tsx:395-417). Every
/// other component's root is a block (a `div`, or `display: block`).
bool isInlineLevel(KitNode child) {
  final props = ComponentProps(child.props.peek());
  return switch (child.type) {
    'Badge' || 'Link' => true,
    'Bold' || 'Italic' || 'Underline' || 'Strikethrough' => true,
    'Button' || 'Math' => !(props.boolean('block') ?? false),
    'Text' || 'Icon' => props.boolean('inline') ?? false,
    _ => false,
  };
}

/// Whether text props clip their text (`overflow: hidden`), which drops a
/// flex item's automatic minimum size to zero.
bool _clipsText(ComponentProps props) =>
    (props.boolean('truncate') ?? false) || (props.number('maxLines') ?? 0) > 0;

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/layout.tsx
