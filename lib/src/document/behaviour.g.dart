// GENERATED CODE. Do not edit by hand: run `dart run tool/generate.dart`.
// Source: CopilotKit (MIT, (c) Atai Barkai), commit ff6f3b03, the A2UI
// Playground export. See NOTICE.md.

/// The props each component writes back to the data model when
/// the payload binds them with `{"@path"}`: the `writable` lists
/// of CopilotKit's declarations, which the exported catalog
/// leaves out. A written path becomes the user's: later agent
/// writes at or below it are ignored.
const Map<String, Set<String>> writableProps = {
  'TextField': {'value'},
  'TextArea': {'value'},
  'Select': {'value'},
  'CheckBox': {'value'},
  'RadioGroup': {'value'},
  'Slider': {'value'},
  'SegmentedControl': {'value'},
  'ChoicePicker': {'value'},
  'DateTimeInput': {'value'},
  'Tabs': {'selectedIndex'},
  'Carousel': {'activeIndex'},
  'Popover': {'open'},
  'Modal': {'open'},
  'Map': {'selected'},
  'Combobox': {'value'},
  'Switch': {'value'},
  'DatePicker': {'value'},
  'ButtonGroup': {'value'},
  'ChipSelect': {'value'},
};

/// The arguments each event sends, by component and event prop:
/// the `parameters` of CopilotKit's event declarations. They go
/// into the event's context, where the binding's own context
/// entries win. An empty list is no arguments.
const Map<String, Map<String, List<String>>> eventArguments = {
  'Box': {'onVisible': []},
  'Column': {'onVisible': []},
  'Row': {'onVisible': []},
  'Grid': {'onVisible': []},
  'GridItem': {'onVisible': []},
  'Card': {'onVisible': []},
  'Flow': {'onVisible': []},
  'FlowItem': {'onVisible': []},
  'Carousel': {'onVisible': []},
  'CarouselItem': {'onVisible': []},
  'CarouselMediaItem': {'onClick': [], 'onVisible': []},
  'Button': {'onClick': []},
  'Pressable': {'onClick': [], 'onVisible': []},
  'Form': {'onSubmit': []},
  'List': {
    'action': ['index', 'label', 'value'],
  },
  'ListItem': {'action': []},
  'Image': {'onOverlayClick': []},
  'LinkCard': {'onClick': []},
  'FollowUp': {
    'onFollowUp': ['message'],
  },
  'EntityCard': {
    'onAction': ['label'],
    'onClick': [],
  },
  'Callout': {'onAction': []},
  'EmptyState': {'onAction': []},
  'EventCard': {'onAction': []},
};
