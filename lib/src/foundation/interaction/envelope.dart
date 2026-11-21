import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart' show KitNode;
import 'package:flutter/foundation.dart';

/// What a component's accessibility envelope gives it: its `label` and
/// `description` (its name), and its `hidden` state and `live` region, as
/// a2ui_flutter 0.4.0's `NodeView` reads them (node_view.dart:138-213).
///
/// CopilotKit's standard components spread the envelope's ARIA onto their
/// own element (`useGenerativeUIAccessibility`, react-core
/// generative-ui/accessibility.ts:36-40): a `<button aria-label>`, an
/// `<img aria-label>`. `NodeView` instead puts the label and the
/// description on a semantics node of its own around every component, and
/// a2ui_kit cannot take them off it (RULEBOOK section 1: the engine is
/// never patched). So a component that spreads the envelope onto one
/// element keeps that element's semantics in `NodeView`'s node while
/// `NodeView` puts one there ([wrapped], its own rule: a name, a
/// description, a live region or `hidden`): no node of its own, and none of its
/// content's text in the name when the envelope gives a [label] (an
/// `aria-label` replaces the name the content would give). One node then
/// carries the element's role and the envelope's name, as upstream's
/// element does (RULEBOOK section 0: the envelope's name goes only on the
/// components upstream spreads it onto). A labelled control's `Field`
/// (inputs.tsx:190-213) is a named group around the control, which is
/// what `NodeView`'s node is: there the control keeps its own node and
/// takes the name too ([label], [description]), as `controlAria` gives it.
/// [hidden] and [live] are `NodeView`'s to apply (upstream's wrapper,
/// SurfaceView.tsx:1138-1166); a component reads them only for what it
/// shows outside that node (the Image's lightbox, lightbox.tsx:45-47), or
/// for a node it draws itself rather than through `NodeView` (a Table's
/// rows and cells, [KitEnvelope.ofNode]: upstream's `accessibility:
/// "self"`, packages/shared/src/generative-ui/standard/data.ts:157-171).
///
/// A value is read as `NodeView` reads it (a string, a number or a boolean,
/// as JavaScript's `String()` writes it; empty is none), so a component
/// merges into `NodeView`'s node exactly when that node is there. A value
/// that is itself binding-shaped data, which `NodeView` resolves a second
/// time (accessibility.test.ts:14, queued), names nothing here (upstream's
/// reading; `NodeView` then names its node and the component keeps a node
/// of its own under it).
// TODO(port): RULEBOOK section 0 (the envelope's name only on the
// components upstream spreads it onto) is pending for the others: NodeView
// names its node around every component (node_view.dart:145-150, :161-166),
// a Title's or a Badge's too, reads a bound number as text (:197-200,
// `ComponentProps.asString`; upstream's `readAccessibility` drops it,
// accessibility.ts:38-48) and resolves a binding-shaped value again
// (:179-189). None of it can be undone from a builder: queued in
// dynamic_values_test.dart and accessibility_test.dart (INV-261).
@immutable
class KitEnvelope {
  /// An envelope of [label], [description], [hidden] and [live].
  const KitEnvelope({
    this.label,
    this.description,
    this.hidden = false,
    this.live = false,
  });

  /// The envelope of a component's resolved [props]: the `@accessibility`
  /// mixin, or the legacy bare `accessibility`, as `NodeView` reads it.
  factory KitEnvelope.of(ComponentProps props) {
    final envelope =
        props.value('@accessibility') ?? props.value('accessibility');
    if (envelope is! Map) return none;
    Object? read(String key) {
      final value = ComponentProps.unwrap(envelope[key]);
      return value is Map ? null : value;
    }

    String? text(String key) {
      final text = ComponentProps.asString(read(key));
      return text == null || text.isEmpty ? null : text;
    }

    return KitEnvelope(
      label: text('label'),
      description: text('description'),
      hidden: ComponentProps.asBoolean(read('hidden')) ?? false,
      live: switch (text('live')) {
        'polite' || 'assertive' => true,
        _ => false,
      },
    );
  }

  /// The envelope of [node], read from its resolved props as [KitEnvelope.of]
  /// reads them: for a node a component draws without building it (a
  /// Table's sections, rows and cells). The envelope's bound `label`,
  /// `description` and `hidden` are resolved props, so a change of their
  /// data is a change of [node]'s props.
  factory KitEnvelope.ofNode(KitNode node) =>
      KitEnvelope.of(ComponentProps(node.props.peek()));

  /// No envelope.
  static const KitEnvelope none = KitEnvelope();

  /// The envelope's `label`: the element's accessible name.
  final String? label;

  /// The envelope's `description`: the element's accessible description.
  final String? description;

  /// Whether the envelope hides the component from assistive technologies.
  final bool hidden;

  /// Whether the envelope makes the component a live region (`polite` or
  /// `assertive`).
  final bool live;

  /// Whether the envelope gives the element a name (or a description): an
  /// image it names is an image even with no alt text of its own.
  bool get names => label != null || description != null;

  /// Whether `NodeView` puts a semantics node of its own above the
  /// component: exactly its `container` rule (a2ui_flutter 0.4.0
  /// node_view.dart:164: a label, a description, a live region or
  /// `hidden`). A component that spreads the envelope onto its element
  /// gives that node the element's role (a `Semantics` that is no
  /// container) while it is there, so one node carries both. A hidden
  /// node's subtree has no semantics at all (`ExcludeSemantics`, :161).
  bool get wrapped => label != null || description != null || live || hidden;

  @override
  bool operator ==(Object other) =>
      other is KitEnvelope &&
      other.label == label &&
      other.description == description &&
      other.hidden == hidden &&
      other.live == live;

  @override
  int get hashCode => Object.hash(label, description, hidden, live);
}

// PORT STATUS: confidence=medium todos=1 upstream=packages/core/src/generative-ui/accessibility.ts, packages/react-core/src/v2/generative-ui/SurfaceView.tsx
