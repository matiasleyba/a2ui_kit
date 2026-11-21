// Parity tests of the manifest of CopilotKit's feedback group, ported from
// packages/react-core/src/v2/generative-ui/standard/__tests__/
// feedback.test.tsx (MIT, (c) Atai Barkai). Each test names its upstream
// line.
//
// Parity for: (engine)
//
// Every other test of the file renders a later-phase component. The one
// ported test (:56) reads the group object `feedbackComponents`, like the
// manifest tests of media.test.tsx and composites.test.tsx; here its facts
// come from the catalog document: the group is the run of six names in the
// standard catalog's order, and a slot is a child-reference property of a
// component's schema (a "multiple" slot is a ChildList, a2ui_core's
// ListRef).
//
// Not ported (bound to internals): none.
//
// Later phase (no Dart yet):
// - :79 "opens from the keyboard when the trigger is plain text, and keeps
//   a Button trigger as the only control", :120 "does not open when the
//   trigger is a disabled Pressable", :142 "does not open from the
//   keyboard when the trigger is a disabled Button", :165 "closes only the
//   newest overlay on Escape: a lightbox inside the dialog first, then the
//   dialog" (an Image's lightbox over a Modal's dialog), :196 "lets a
//   Button trigger send its own event while the dialog opens" and :245
//   "applies the envelope of a Modal to its dialog, which is a portal":
//   Modal (with Text, Button, Pressable or Image as its trigger or
//   content).
// - :229 "names a PopoverTrigger by its envelope" (an Icon inside it),
//   :347 "opens a dialog named by its trigger, and closes on a second
//   click", :359 "closes on Escape and moves focus back to the trigger",
//   :370 "closes on a pointer press outside of it" and :380 "writes the
//   open state to a bound data path": Popover, PopoverTrigger,
//   PopoverContent.
// - :267 "renders the feedback and overlay components": PulseIndicator,
//   FlashcardFlip, Popover.
// - :288 "names a PulseIndicator only when it has a label" and :298 "keeps
//   a pulse under reduced motion, as a fade without growth":
//   PulseIndicator.
// - :323 "flips to the back on click, and back to the front on a second
//   click" and :334 "flips with the Enter and Space keys": FlashcardFlip.

import 'package:a2ui_core/a2ui_core.dart' show ListRef;
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/document/catalog_document.g.dart';
import 'package:flutter_test/flutter_test.dart';

/// The description of [name] in the standard catalog's document, its
/// export (`ui.manifestComponents[name].description`).
Object? _description(String name) =>
    switch ((a2uiKitStandardCatalog().toJson()['components']! as Map)[name]) {
      final Map<Object?, Object?> component => component['description'],
      _ => null,
    };

void main() {
  group('feedbackComponents', () {
    // feedback.test.tsx:56
    test('is valid input for createGenerativeUI, with a description for '
        'every component', () {
      const names = [
        'PulseIndicator',
        'FlashcardFlip',
        'Popover',
        'PopoverTrigger',
        'PopoverContent',
        'Modal',
      ];
      final start = standardComponentNames.indexOf(names.first);
      expect(
        standardComponentNames.sublist(start, start + names.length),
        names,
      );
      // `toEqual` on the group's keys fails on an extra member too: the
      // next group (data) starts right after Modal.
      expect(standardComponentNames[start + names.length], 'Table');
      for (final name in names) {
        expect(_description(name), matches(RegExp(r'\S')), reason: name);
      }
      final refs = a2uiKitStandardCatalog().refMap;
      for (final name in ['Popover', 'PopoverTrigger', 'PopoverContent']) {
        // slots: { children: "multiple" }.
        final slots = refs.fieldsFor(name);
        expect(slots.keys, ['children'], reason: name);
        expect(slots['children'], isA<ListRef>(), reason: name);
      }
      // FlashcardFlip has no slots.
      expect(refs.fieldsFor('FlashcardFlip'), isEmpty);
    });
  });
}
