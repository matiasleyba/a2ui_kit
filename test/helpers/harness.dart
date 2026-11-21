import 'dart:convert';
import 'dart:io';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The surface id every test surface uses.
const String testSurfaceId = 's';

/// The JSON of the fixture at [name] under `test/fixtures/copilotkit/`.
Object? fixture(String name) =>
    jsonDecode(File('test/fixtures/copilotkit/$name').readAsStringSync());

/// [messages] with every component id that is not a UAX #31 identifier
/// (`spacer-l`) rewritten (`spacer_l`), in the ids and in every string that
/// names one.
///
/// CopilotKit accepts such ids; a2ui_core's v1.0 validation rejects them
/// (see PORT_PLAN.md, Port notes). The fixtures keep CopilotKit's ids, so
/// the tests rewrite them.
Object? withIdentifierIds(Object? messages) {
  final ids = <String>{};
  void collect(Object? node) {
    if (node is Map) {
      final id = node['id'];
      if (id is String && node.containsKey('component')) ids.add(id);
      node.values.forEach(collect);
    } else if (node is List) {
      node.forEach(collect);
    }
  }

  collect(messages);
  String fix(String id) => id.replaceAll(RegExp('[^A-Za-z0-9_]'), '_');
  final bad = {
    for (final id in ids)
      if (fix(id) != id) id: fix(id),
  };
  Object? rewrite(Object? node) => switch (node) {
    final String s => bad[s] ?? s,
    final Map<Object?, Object?> m => <String, Object?>{
      for (final e in m.entries) e.key! as String: rewrite(e.value),
    },
    final List<Object?> l => [for (final e in l) rewrite(e)],
    _ => node,
  };
  return rewrite(messages);
}

/// The messages that create [testSurfaceId] under [catalogId] with
/// [components] and, when given, the [data] model.
List<Map<String, Object?>> createMessages(
  List<Map<String, Object?>> components, {
  Object? data,
  String catalogId = kA2uiPlaygroundCatalogId,
}) => [
  {
    'version': '1.0',
    'createSurface': {'surfaceId': testSurfaceId, 'catalogId': catalogId},
  },
  {
    'version': '1.0',
    'updateComponents': {'surfaceId': testSurfaceId, 'components': components},
  },
  if (data != null)
    {
      'version': '1.0',
      'updateDataModel': {'surfaceId': testSurfaceId, 'value': data},
    },
];

/// A processor with the a2ui_kit catalog, its surfaces, and every action
/// and error they send.
class TestSurfaces {
  /// A processor over [catalog] (the playground catalog by default).
  TestSurfaces({CatalogImplementation? catalog})
    : processor = MessageProcessor<ComponentImplementation>(
        catalogs: [catalog ?? a2uiKitCatalog()],
        reportErrorsOnly: true,
      ) {
    processor.model.onSurfaceCreated.subscribe((surface) {
      surfaces[surface.id] = surface;
      // Errors in a surface's messages go to the surface, not the group.
      surface.onError.subscribe(errors.add);
    });
    processor.model.onAction.subscribe(actions.add);
    processor.model.onError.subscribe(errors.add);
  }

  /// The processor.
  final MessageProcessor<ComponentImplementation> processor;

  /// The surfaces created, by id.
  final Map<String, SurfaceModel<ComponentImplementation>> surfaces = {};

  /// The actions the surfaces sent.
  final List<A2uiRendererAction> actions = [];

  /// The errors the surfaces reported.
  final List<A2uiRendererError> errors = [];

  /// The surface [testSurfaceId].
  SurfaceModel<ComponentImplementation> get surface => surfaces[testSurfaceId]!;

  /// Creates [testSurfaceId] with [components] and the [data] model.
  void create(
    List<Map<String, Object?>> components, {
    Object? data,
    String catalogId = kA2uiPlaygroundCatalogId,
  }) => apply(createMessages(components, data: data, catalogId: catalogId));

  /// Applies [messages], and returns the errors the processor emitted for
  /// them at once (a surface also reports each one on its `onError`, a
  /// microtask later).
  List<ErrorMessage> apply(List<Object?> messages) =>
      processor.processMessagesWithErrors(messages);

  /// Sets [value] at [path] of the data model.
  void setData(String path, Object? value) => processor.processMessages([
    {
      'version': '1.0',
      'updateDataModel': {
        'surfaceId': testSurfaceId,
        'path': path,
        'value': value,
      },
    },
  ]);

  /// Releases the processor.
  void dispose() => processor.dispose();
}

/// The type of the page a test surface sits in, a CopilotKit chat's: 16px
/// text in CopilotKit's default ink of [brightness] (`--a2ui-color-text-
/// default`'s fallbacks), over the app's own. The standard look takes it
/// (`.a2ui-surface{font:inherit;color:inherit}`); the playground look sets
/// its own.
TextStyle copilotKitHost(Brightness brightness) => TextStyle(
  fontSize: 16,
  color: brightness == Brightness.light
      ? const Color(0xff0d0d0d)
      : const Color(0xffececec),
);

/// An app that shows [surface] [width] pixels wide, scrolled vertically,
/// in [brightness] at [textScale], in the page type [host]
/// ([copilotKitHost] when null). [view] is the widget that shows the
/// surface: the parity tests pass the README app's (`ReadmeApp.view`,
/// test/helpers/readme_app.dart); a2ui_flutter's `A2uiSurface` when null.
Widget surfaceApp(
  SurfaceModel<ComponentImplementation> surface, {
  double width = 360,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  A2uiKitTheme? theme,
  TextStyle? host,
  Widget? view,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(brightness: brightness, extensions: [?theme]),
  home: MediaQuery.withClampedTextScaling(
    minScaleFactor: textScale,
    maxScaleFactor: textScale,
    child: Scaffold(
      body: DefaultTextStyle.merge(
        style: host ?? copilotKitHost(brightness),
        child: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: view ?? A2uiSurface(surface: surface),
            ),
          ),
        ),
      ),
    ),
  ),
);

/// Pumps [components] as a surface [width] wide and returns the surfaces.
Future<TestSurfaces> pumpComponents(
  WidgetTester tester,
  List<Map<String, Object?>> components, {
  Object? data,
  double width = 360,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  A2uiKitTheme? theme,
  CatalogImplementation? catalog,
}) async {
  final surfaces = TestSurfaces(catalog: catalog)
    ..create(components, data: data);
  addTearDown(surfaces.dispose);
  await tester.pumpWidget(
    surfaceApp(
      surfaces.surface,
      width: width,
      textScale: textScale,
      brightness: brightness,
      theme: theme,
    ),
  );
  await tester.pump();
  return surfaces;
}

/// The rectangle of the widget showing [text], in global coordinates.
Rect rectOfText(WidgetTester tester, String text) =>
    tester.getRect(find.text(text, findRichText: true));
