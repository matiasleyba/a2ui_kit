// The harness of the parity tests in test/parity/: the Flutter side of
// CopilotKit's `renderSurface` (react-core
// standard/__tests__/render.tsx), which renders one surface of the
// standard catalog through the real engine.
//
// Every surface is built by the README's app (`ReadmeApp`,
// test/helpers/readme_app.dart: the processor, the `A2uiIdNormalizer`, the
// `A2uiUserOwnedData` and the surface widget), so a fix that changes the
// setup changes the README and that helper, never a test.
//
// Upstream's `renderSurface(ui, components, data)` maps to
// [renderStandard]; its `view.update(...operations)` (an agent's later
// operations, applied inside `act`) to [ParitySurface.update], which hands
// them to the app as an agent's messages, then pumps a frame; its
// `view.dataAt(path)` to [ParitySurface.dataAt]; its `forwardEvent` spy to
// [ParitySurface.actions]; its `reportError` spy to
// [ParitySurface.errors]; its `window.open` spy to [fakeUrlLauncher].

import 'dart:io' show Platform;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'harness.dart';
import 'readme_app.dart';

export 'harness.dart' show testSurfaceId;
export 'readme_app.dart' show ReadmeApp;

/// The `skip` of a ported test that our code fails (RULEBOOK section 6,
/// item 2), for a `test` and a `testWidgets` alike:
/// `skip: portQueue('port-queue: <subject>: <one line>')`, where
/// `grep -rn "port-queue:" test` finds it. (`testWidgets` takes a bool, and
/// `test` a bool or a string, so one bool serves both.)
///
/// With the environment variable `A2UI_RUN_QUEUED` set, every queued test
/// runs instead of skipping: the queue's own check, which shows each still
/// failing for its stated reason (or a fix that made one pass).
bool portQueue(String reason) {
  assert(reason.startsWith('port-queue: '), 'a port-queue skip names it');
  return !Platform.environment.containsKey('A2UI_RUN_QUEUED');
}

/// The standard look, light: CopilotKit's standard tokens and their
/// fallback values, which upstream's standard tests render with.
final A2uiKitTheme standardLight = A2uiKitTheme.standard(Brightness.light);

/// A url_launcher platform that records every launch: upstream's
/// `window.open` spy, for the opener an app gets without `onOpenUrl`.
class FakeUrlLauncher extends UrlLauncherPlatform {
  /// Every launch, in order: the URL and the options it was launched with.
  final List<({String url, LaunchOptions options})> launches = [];

  /// Each launch as (URL, mode, window name): upstream's
  /// `open(url, target, features)` calls, where the window name `_blank`
  /// is the target.
  List<(String, PreferredLaunchMode, String?)> get opened => [
    for (final launch in launches)
      (launch.url, launch.options.mode, launch.options.webOnlyWindowName),
  ];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches.add((url: url, options: options));
    return true;
  }
}

/// Puts a [FakeUrlLauncher] in place of the platform's url_launcher for
/// the rest of the test.
FakeUrlLauncher fakeUrlLauncher() {
  final previous = UrlLauncherPlatform.instance;
  final fake = FakeUrlLauncher();
  UrlLauncherPlatform.instance = fake;
  addTearDown(() => UrlLauncherPlatform.instance = previous);
  return fake;
}

/// What upstream's `open(url, "_blank", "noopener,noreferrer")` is for a
/// [FakeUrlLauncher]: [url] in a new tab (`webOnlyWindowName: '_blank'`),
/// in the browser or mail app off the web. The `noopener,noreferrer`
/// features are url_launcher_web's own.
(String, PreferredLaunchMode, String?) openedInNewTab(String url) =>
    (url, PreferredLaunchMode.externalApplication, '_blank');

/// A surface of the standard catalog, rendered as upstream's
/// `renderSurface` renders one, in the README's app.
class ParitySurface {
  ParitySurface._(this._tester, this.app);

  final WidgetTester _tester;

  /// The app the surface lives in, set up as the README says.
  final ReadmeApp app;

  /// The processor.
  MessageProcessor<ComponentImplementation> get processor => app.processor;

  /// The surface.
  SurfaceModel<ComponentImplementation> get surface =>
      app.surfaces[testSurfaceId]!;

  /// The widget the app shows the surface with: a second mount of the same
  /// surface uses it too.
  Widget surfaceView() => app.view(surface);

  /// The actions the surface sent, as the agent gets them: upstream's
  /// `forwardEvent` calls.
  List<A2uiRendererAction> get actions => app.actions;

  /// The names of the actions sent, in order: upstream's
  /// `sentEventNames(view)`.
  List<String> get actionNames => [for (final a in actions) a.name];

  /// The errors the surface reported, as the agent gets them: upstream's
  /// `reportError` calls. a2ui_core reports them a microtask late, so a
  /// check that none came reads this after a pump.
  List<A2uiRendererError> get errors => app.errors;

  /// The data model's value at [path]: upstream's `view.dataAt(path)`.
  Object? dataAt(String path) => surface.dataModel.get(path);

  /// Hands an agent's later [messages] to the app and pumps a frame:
  /// upstream's `view.update(...operations)`, which applies them inside
  /// `act`.
  Future<void> update(List<Map<String, Object?>> messages) async {
    app.receive(messages);
    await _tester.pump();
  }
}

/// An agent write of [value] at [path] of the test surface: upstream's
/// `agentWrite(path, value)` (inputs.test.tsx:42).
Map<String, Object?> agentWrite(String path, Object? value) => {
  'version': '1.0',
  'updateDataModel': {'surfaceId': testSurfaceId, 'path': path, 'value': value},
};

/// An agent's `updateComponents` of the test surface.
Map<String, Object?> agentComponents(List<Map<String, Object?>> components) => {
  'version': '1.0',
  'updateComponents': {'surfaceId': testSurfaceId, 'components': components},
};

/// Renders [components] (with a component of id "root") as a surface of
/// the standard catalog under [kA2uiStandardCatalogId], with [data] written
/// at "/", in the standard look ([brightness], light by default), [width]
/// pixels wide. The messages reach the README's app as an agent's do
/// ([ReadmeApp.receive]), so CopilotKit's ids (`s-layout`) are taken as
/// they are.
///
/// [options] are the catalog's options (an `onOpenUrl` spy, overrides);
/// [theme] replaces the standard look of [brightness] (a theme that sets a
/// token, as upstream's custom properties do); [host] is the page's type
/// ([copilotKitHost] when null).
Future<ParitySurface> renderStandard(
  WidgetTester tester,
  List<Map<String, Object?>> components, {
  Map<String, Object?>? data,
  double width = 360,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  A2uiKitTheme? theme,
  TextStyle? host,
  A2uiKitOptions options = const A2uiKitOptions(look: A2uiKitLook.standard),
}) async {
  final app = ReadmeApp(a2uiKitStandardCatalog(options: options));
  addTearDown(app.dispose);
  app.receive(
    createMessages(components, data: data, catalogId: kA2uiStandardCatalogId),
  );
  final view = ParitySurface._(tester, app);
  await tester.pumpWidget(
    surfaceApp(
      view.surface,
      width: width,
      textScale: textScale,
      brightness: brightness,
      theme: theme ?? A2uiKitTheme.standard(brightness),
      host: host,
      view: view.surfaceView(),
    ),
  );
  await tester.pump();
  return view;
}

/// The CSS flex containers around the text [text], nearest first: upstream's
/// `label.parentElement`, then its parent, and so on.
List<CssFlex> flexContainersAround(WidgetTester tester, String text) => tester
    .widgetList<CssFlex>(
      find.ancestor(
        of: find.text(text, findRichText: true),
        matching: find.byType(CssFlex),
      ),
    )
    .toList();

/// The nearest CSS flex container around the text [text]: upstream's
/// `parentOf(view, text)` (layout.test.tsx:24).
CssFlex flexContainerOf(WidgetTester tester, String text) =>
    flexContainersAround(tester, text).first;

/// The semantics node of the widget showing [text].
SemanticsNode semanticsOfText(WidgetTester tester, String text) =>
    tester.getSemantics(find.text(text, findRichText: true).first);

/// Upstream's `findByRole("table")` and `rowTexts(view)` in the semantics
/// tree: the one node with the table role, and each of its row nodes as the
/// role and label of each cell (a column header or a cell), in order.
/// RULEBOOK section 0: a table, the Chart's hidden data table included,
/// carries these roles (INV-034's rows that read each cell after its column
/// are overruled).
List<List<(SemanticsRole, String)>> tableRows(WidgetTester tester) {
  final tables = find.semantics
      .byPredicate((node) => node.role == SemanticsRole.table)
      .evaluate()
      .toList();
  expect(tables, hasLength(1), reason: 'findByRole("table")');
  final rows = <List<(SemanticsRole, String)>>[];
  bool visitRow(SemanticsNode node) {
    if (node.role != SemanticsRole.row) {
      node.visitChildren(visitRow);
      return true;
    }
    final cells = <(SemanticsRole, String)>[];
    bool visitCell(SemanticsNode cell) {
      if (cell.role == SemanticsRole.cell ||
          cell.role == SemanticsRole.columnHeader) {
        cells.add((cell.role, cell.label));
      } else {
        cell.visitChildren(visitCell);
      }
      return true;
    }

    node.visitChildren(visitCell);
    rows.add(cells);
    return true;
  }

  tables.single.visitChildren(visitRow);
  return rows;
}

/// A header row of [labels] (column-header cells), then a data row per
/// list of [rows] (cells): what [tableRows] gives for upstream's
/// `rowTexts`, the header row first. A row's first cell is upstream's
/// `<th scope="row">` (Chart.tsx:443), read as a cell: Flutter's
/// `SemanticsRole` has no row header.
List<List<(SemanticsRole, String)>> tableOf(
  List<String> labels,
  List<List<String>> rows,
) => [
  [for (final label in labels) (SemanticsRole.columnHeader, label)],
  for (final row in rows) tableRow(row),
];

/// A data row of [cells], as [tableRows] gives it.
List<(SemanticsRole, String)> tableRow(List<String> cells) => [
  for (final cell in cells) (SemanticsRole.cell, cell),
];

/// The cells of a table (column headers included) whose text is exactly
/// [text]: upstream's `getAllByText(text)` of a cell in a table, which
/// section 0 makes a node with the cell or column-header role inside a
/// node with the table role.
SemanticsFinder tableCells(String text) => find.semantics.byPredicate((node) {
  if (node.label != text) return false;
  if (node.role != SemanticsRole.cell &&
      node.role != SemanticsRole.columnHeader) {
    return false;
  }
  for (var parent = node.parent; parent != null; parent = parent.parent) {
    if (parent.role == SemanticsRole.table) return true;
  }
  return false;
});

/// Every semantics node with the alert role: upstream's
/// `getAllByRole("alert")`.
SemanticsFinder alerts() =>
    find.semantics.byPredicate((node) => node.role == SemanticsRole.alert);

/// The nodes with the alert role whose label contains [text]: upstream's
/// `alertText()` containing it.
SemanticsFinder alertsContaining(String text) => find.semantics.byPredicate(
  (node) => node.role == SemanticsRole.alert && node.label.contains(text),
);

/// The plain text of every `RichText` drawn outside an alert: what is left
/// of the components when a fallback alert takes a component's place. A
/// text is inside an alert when its semantics node, or a node above it, has
/// the alert role, however that role is given.
List<String> textsOutsideAlerts(WidgetTester tester) {
  bool inAlert(SemanticsNode? node) {
    for (var at = node; at != null; at = at.parent) {
      if (at.role == SemanticsRole.alert) return true;
    }
    return false;
  }

  final texts = find.byType(RichText);
  return [
    for (var i = 0; i < texts.evaluate().length; i++)
      if (!inAlert(tester.getSemantics(texts.at(i))))
        tester.widget<RichText>(texts.at(i)).text.toPlainText(),
  ];
}

/// What the surface paints: the paint calls of the page it sits on, for
/// `expect(paintedPage(tester), paints..something(...))`.
RenderObject paintedPage(WidgetTester tester) =>
    tester.renderObject(find.byType(Scaffold));

/// A box filled with [color] (compared as ARGB32): a `drawRect` or a
/// `drawRRect` in a fill of that colour, whichever the box draws.
PaintPatternPredicate paintedFill(Color color) => (method, args) {
  if (method != #drawRect && method != #drawRRect) return false;
  if (args.length < 2 || args[1] is! Paint) return false;
  final paint = args[1] as Paint;
  return paint.style == PaintingStyle.fill &&
      paint.color.toARGB32() == color.toARGB32();
};

/// A painted [shadow]: a box drawn in its colour through its blur, as
/// `BoxShadow.toPaint` makes the paint (with no blur while
/// `debugDisableShadows` is on, as flutter_test sets it).
PaintPatternPredicate paintedShadow(BoxShadow shadow) => (method, args) {
  if (method != #drawRect && method != #drawRRect && method != #drawPath) {
    return false;
  }
  if (args.isEmpty || args.last is! Paint) return false;
  final paint = args.last as Paint;
  final blur = debugDisableShadows
      ? null
      : MaskFilter.blur(shadow.blurStyle, shadow.blurSigma);
  return paint.color.toARGB32() == shadow.color.toARGB32() &&
      paint.maskFilter == blur;
};

/// A `drawRRect` with these four corner radii, wherever it sits: a box
/// drawn with that `border-radius`.
PaintPatternPredicate paintedCorners({
  required Radius topLeft,
  required Radius topRight,
  required Radius bottomRight,
  required Radius bottomLeft,
}) => (method, args) {
  if (method != #drawRRect || args.isEmpty || args.first is! RRect) {
    return false;
  }
  final rrect = args.first as RRect;
  return rrect.tlRadius == topLeft &&
      rrect.trRadius == topRight &&
      rrect.brRadius == bottomRight &&
      rrect.blRadius == bottomLeft;
};

/// The plain text of every `RichText` on screen, in tree order.
List<String> richTexts(WidgetTester tester) => [
  for (final text in tester.widgetList<RichText>(find.byType(RichText)))
    text.text.toPlainText(),
];
