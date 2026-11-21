// The app the README's "Setup" builds: the one place the parity tests build
// it (RULEBOOK section 6, item 2: the harness ingests messages and mounts
// surfaces through one helper that follows the README).
//
// README, "Setup": a `MessageProcessor` over the catalog, and an
// `A2uiSurface` for each surface the agent creates. "Operations CopilotKit
// refuses": the agent's messages pass an `A2uiOperationValidator` first.
// "Component ids from CopilotKit agents": they pass an `A2uiIdNormalizer`
// next, and the actions and errors the app sends to the agent are mapped
// back through it. "What the user typed stays": they pass an
// `A2uiUserOwnedData` last.
//
// A fix that changes the setup (a processor option such as a
// `validationConfig`, a stage before the processor, our own surface widget)
// changes the README and this file together, never a test.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart' show A2uiSurface;
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:flutter/widgets.dart';

/// An app with this package over one catalog, set up as the README's
/// "Setup" says.
class ReadmeApp {
  /// The app over [catalog]. [toAgent] gets what the processor itself sends
  /// to the agent (the answers to `callRendererFunction`), the channel the
  /// README's `sendToAgent` stands for.
  ReadmeApp(CatalogImplementation catalog, {OutboundMessageListener? toAgent})
    : processor = MessageProcessor<ComponentImplementation>(
        catalogs: [catalog],
        outboundListener: toAgent,
      ) {
    owned = A2uiUserOwnedData(processor);
    checks = A2uiOperationValidator(processor);
    processor.model.onSurfaceCreated.subscribe((surface) {
      surfaces[surface.id] = surface;
    });
    // As the README's listeners: the group forwards each surface's actions
    // and errors (surface_group_model.dart, `addSurface`).
    processor.model.onAction.subscribe(_actions.add);
    processor.model.onError.subscribe(_errors.add);
  }

  /// The README's `processor`.
  final MessageProcessor<ComponentImplementation> processor;

  /// The README's `ids`: one normalizer per conversation.
  final A2uiIdNormalizer ids = A2uiIdNormalizer();

  /// The README's `owned`.
  late final A2uiUserOwnedData owned;

  /// The README's `checks`.
  late final A2uiOperationValidator checks;

  /// The surfaces the agent created, by id.
  final Map<String, SurfaceModel<ComponentImplementation>> surfaces = {};

  final List<A2uiRendererAction> _actions = [];
  final List<A2uiRendererError> _errors = [];

  /// Passes [messagesFromAgent] to the processor as the app does: through
  /// [checks], [ids], then [owned]. Returns the errors the processor
  /// emitted for them at once; every error, [checks]' refusals included,
  /// also reaches [errors], at once or a microtask later.
  List<ErrorMessage> receive(List<Object?> messagesFromAgent) =>
      processor.processMessagesWithErrors(
        owned.filterMessages(
          ids.normalizeMessages(checks.filterMessages(messagesFromAgent)),
        ),
      );

  /// The actions the app sends to the agent: `ids.outboundAction(action)`.
  List<A2uiRendererAction> get actions => [
    for (final action in _actions) ids.outboundAction(action),
  ];

  /// The errors the app sends to the agent: `ids.outboundError(error)`.
  /// a2ui_core reports them a microtask late, so a check that none came
  /// reads this after a pump.
  List<A2uiRendererError> get errors => [
    for (final error in _errors) ids.outboundError(error),
  ];

  /// The widget the app shows [surface] with.
  Widget view(SurfaceModel<ComponentImplementation> surface) =>
      A2uiSurface(surface: surface);

  /// Releases the processor.
  void dispose() => processor.dispose();
}
