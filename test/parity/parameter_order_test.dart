// Parity tests of the standard components' calling convention in the
// exported catalog, ported from
// packages/react-core/src/v2/generative-ui/__tests__/parameter-order.test.tsx
// (MIT, (c) Atai Barkai). Each test names its upstream line.
//
// Parity for: (engine)
//
// The calling convention is the order of a component's props in the
// exported document: `component` first, then the props a model writes
// first. `exportA2UICatalog(standardUI)` is the document the standard
// catalog writes (`a2uiKitStandardCatalog().toJson()`), as in
// catalog_export_test.dart; the prompt lists the props in that order.
//
// parameter-order.test.tsx:168 is a catalog-document test: its check of
// every standard component's exported prop order against
// `standardParameterOrder` (packages/shared/src/generative-ui/standard/
// parameter-order.ts:9-155: the component's argument prefix, then its other
// keys in declaration order, the presentation keys last in that order) is
// ported for all 69, as the exact order of CopilotKit's own export of each
// (test/fixtures/copilotkit/catalog.json). Its other assertions, that
// `parameterOrder` holds exactly the manifest's props, slots and events,
// and that an export without `parameterOrder` gives the same schema, test
// `createGenerativeUI`'s manifest: not ours.
//
// Not ours (CopilotKit's `createGenerativeUI` and its `parameterOrder`
// declarations, which this package has no counterpart of):
// parameter-order.test.tsx:11, :29, :54, :101 and :119.

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/document/catalog_document.g.dart'
    show standardComponentNames;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart' show fixture;

/// `STANDARD_ARGUMENT_PREFIXES` (parameter-order.ts:9-80), in its order.
const Map<String, List<String>> _prefixes = {
  'Box': ['children'],
  'Column': ['children'],
  'Row': ['children'],
  'Grid': ['children', 'columns'],
  'GridItem': ['children'],
  'Card': ['children', 'child'],
  'Flow': ['children'],
  'FlowItem': ['children'],
  'Carousel': ['children', 'activeIndex'],
  'CarouselItem': ['children'],
  'CarouselMediaItem': ['url', 'children', 'onClick'],
  'Spacer': ['minSize'],
  'Divider': ['axis'],
  'Tabs': ['tabs', 'selectedIndex'],
  'Title': ['text'],
  'Text': ['text', 'children'],
  'Caption': ['text'],
  'Label': ['text', 'htmlFor'],
  'Bold': ['text'],
  'Italic': ['text'],
  'Underline': ['text'],
  'Strikethrough': ['text'],
  'Badge': ['label'],
  'Blockquote': ['text'],
  'Code': ['text', 'language'],
  'Markdown': ['text'],
  'Math': ['value'],
  'ShimmerText': ['text'],
  'Link': ['text', 'href'],
  'Tooltip': ['trigger', 'content'],
  'Button': ['label', 'onClick'],
  'Pressable': ['children', 'onClick', 'href'],
  'Form': ['children', 'onSubmit'],
  'TextField': ['label', 'value'],
  'TextArea': ['label', 'value'],
  'Select': ['label', 'options', 'value'],
  'CheckBox': ['label', 'value'],
  'Radio': ['label', 'value'],
  'RadioGroup': ['label', 'options', 'value'],
  'Slider': ['label', 'value', 'min', 'max'],
  'SegmentedControl': ['label', 'options', 'value'],
  'ChoicePicker': ['label', 'options', 'value'],
  'DateTimeInput': ['label', 'value'],
  'PulseIndicator': ['label'],
  'FlashcardFlip': ['front', 'back'],
  'Popover': ['children', 'open'],
  'PopoverTrigger': ['children'],
  'PopoverContent': ['children'],
  'Modal': ['trigger', 'content', 'title'],
  'Table': ['columns', 'rows', 'children'],
  'TableSection': ['children'],
  'TableRow': ['children', 'label'],
  'TableCell': ['text', 'children'],
  'List': ['items', 'children', 'action'],
  'ListItem': ['label', 'value', 'action', 'children'],
  'Chart': ['data', 'xKey', 'series', 'chartType'],
  'Map': ['markers', 'selected', 'route'],
  'Image': ['url', 'description', 'onOverlayClick'],
  'Icon': ['name', 'label'],
  'Favicon': ['url', 'alt'],
  'Svg': ['paths', 'viewBox'],
  'Video': ['url', 'title', 'captions'],
  'AudioPlayer': ['url', 'description'],
  'HtmlView': ['html', 'title'],
  'LinkCard': ['href', 'title', 'onClick'],
  'Citation': ['index', 'title', 'url'],
  'FollowUp': ['items', 'onFollowUp', 'title'],
  'EntityCard': ['title', 'actions', 'onAction', 'onClick'],
  'ImageGrid': ['images'],
};

/// The exported prop order of the standard component [name], after
/// `component`: upstream's `Object.keys(exported.components[name]
/// .properties).slice(1)`.
List<String> _exportedOrder(String name) {
  final components =
      a2uiKitStandardCatalog().toJson()['components']! as Map<String, Object?>;
  final schema = components[name]! as Map<String, Object?>;
  final properties = schema['properties']! as Map<String, Object?>;
  return properties.keys.skip(1).toList();
}

void main() {
  group('catalog parameter order', () {
    const conventions = {
      'Text': ['text', 'children'],
      'Column': ['children'],
      'Button': ['label', 'onClick'],
      'TextField': ['label', 'value'],
      'Chart': ['data', 'xKey', 'series', 'chartType'],
      'FollowUp': ['items', 'onFollowUp', 'title'],
    };
    for (final MapEntry(key: name, value: prefix) in conventions.entries) {
      // parameter-order.test.tsx:154
      test('exports the standard $name calling convention', () {
        expect(_exportedOrder(name).take(prefix.length).toList(), prefix);
      });
    }

    // parameter-order.test.tsx:168, the exported order of all 69
    test('declares each of the 69 standard signatures in its exact '
        'order', () {
      expect(_prefixes.keys.toList(), standardComponentNames);
      // CopilotKit's own export of these components
      // (test/fixtures/copilotkit/catalog.json, RULEBOOK section 0 item 2;
      // `jsonDecode` keeps the key order): what
      // `standardParameterOrder(name, definition)` gave it, the argument
      // prefix, then the other keys in declaration order, the
      // presentation keys last in that order (parameter-order.ts:135-155).
      final exported =
          (fixture('catalog.json')! as Map<String, Object?>)['components']!
              as Map<String, Object?>;
      for (final MapEntry(key: name, value: prefix) in _prefixes.entries) {
        final order = _exportedOrder(name);
        // The prefix first, so that a failure names it.
        expect(order.take(prefix.length).toList(), prefix, reason: name);
        // `toEqual(manifest.parameterOrder)`: the whole order.
        final schema = exported[name]! as Map<String, Object?>;
        final properties = schema['properties']! as Map<String, Object?>;
        expect(order, properties.keys.skip(1).toList(), reason: name);
      }
    });
  });
}
