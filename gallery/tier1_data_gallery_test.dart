// Pictures of tier 1's data components for the user to look at: each of
// Table, TableSection, TableRow, TableCell, Svg, Flow and FlowItem with
// tutor content (NEET biology, JEE physics), in both looks, light and
// dark, 390px wide, in the fonts a Flutter app on Android draws (Roboto,
// loaded from alchemist's copy; the test font draws every glyph as a
// box). One PNG per component, look and brightness, written to
// `$A2UI_GALLERY_OUT`, else build/gallery/ in the package.
//
// It sits outside test/, so the normal run never runs it:
//   flutter test gallery/tier1_data_gallery_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/harness.dart' show createMessages, testSurfaceId;
import '../test/helpers/readme_app.dart';

final String _out = Platform.environment['A2UI_GALLERY_OUT'] ?? 'build/gallery';

/// Loads every font of the font manifest (Roboto from alchemist, under
/// its plain family name, so Material's default type finds it).
Future<void> _loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<Object?>;
  for (final entry in manifest.cast<Map<String, Object?>>()) {
    var family = entry['family']! as String;
    if (family.startsWith('packages/alchemist/')) {
      family = family.substring('packages/alchemist/'.length);
    }
    final loader = FontLoader(family);
    for (final font
        in (entry['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(font['asset']! as String));
    }
    await loader.load();
  }
}

/// A title, a caption and the first of [nodes]: the scene a tutor's answer
/// shows.
List<Map<String, Object?>> _scene(
  String title,
  String caption,
  List<Map<String, Object?>> nodes,
) => [
  {
    'id': 'root',
    'component': 'Column',
    'children': ['title', 'caption', nodes.first['id']],
  },
  {'id': 'title', 'component': 'Title', 'text': title, 'size': 'lg'},
  {'id': 'caption', 'component': 'Caption', 'text': caption},
  ...nodes,
];

/// The NEET biology comparison of mitosis and meiosis, from `columns` and
/// `rows`.
final List<Map<String, Object?>> _table = _scene(
  'Mitosis vs meiosis',
  'NEET Biology · Cell cycle and cell division',
  [
    {
      'id': 'table',
      'component': 'Table',
      'caption': 'Mitosis compared with meiosis',
      'columns': [
        'Feature',
        'Mitosis',
        {'label': 'Meiosis', 'align': 'start'},
      ],
      'rows': [
        ['Divisions', 'One', 'Two (meiosis I and II)'],
        [
          'Daughter cells',
          '2, same chromosome number as the parent',
          '4, haploid (n)',
        ],
        ['Crossing over', 'Absent', 'In pachytene of prophase I'],
        ['Purpose', 'Growth and repair', 'Gametes and variation'],
      ],
    },
  ],
);

/// The same kind of table from TableSection children: a header section and
/// a body section repeating a row per item of the data.
final List<Map<String, Object?>> _section = _scene(
  'Plant cell vs animal cell',
  'NEET Biology · Cell: the unit of life',
  [
    {
      'id': 'table',
      'component': 'Table',
      'caption': 'Plant and animal cells',
      'children': ['head', 'body'],
    },
    {
      'id': 'head',
      'component': 'TableSection',
      'header': true,
      'children': ['head_row'],
    },
    {
      'id': 'head_row',
      'component': 'TableRow',
      'children': ['h1', 'h2', 'h3'],
    },
    {'id': 'h1', 'component': 'TableCell', 'text': 'Structure'},
    {'id': 'h2', 'component': 'TableCell', 'text': 'Plant cell'},
    {'id': 'h3', 'component': 'TableCell', 'text': 'Animal cell'},
    {
      'id': 'body',
      'component': 'TableSection',
      'children': {'componentId': 'row', 'path': '/cells'},
    },
    {
      'id': 'row',
      'component': 'TableRow',
      'children': ['what', 'plant', 'animal'],
    },
    {
      'id': 'what',
      'component': 'TableCell',
      'text': {'@path': 'what'},
    },
    {
      'id': 'plant',
      'component': 'TableCell',
      'text': {'@path': 'plant'},
    },
    {
      'id': 'animal',
      'component': 'TableCell',
      'text': {'@path': 'animal'},
    },
  ],
);

const Map<String, Object?> _sectionData = {
  'cells': [
    {'what': 'Cell wall', 'plant': 'Present (cellulose)', 'animal': 'Absent'},
    {'what': 'Plastids', 'plant': 'Present', 'animal': 'Absent'},
    {'what': 'Centrioles', 'plant': 'Usually absent', 'animal': 'Present'},
    {'what': 'Vacuole', 'plant': 'One large, central', 'animal': 'Small, many'},
  ],
};

/// TableRows with a row header (`label`) each: the equations of motion.
final List<Map<String, Object?>> _row = _scene(
  'The equations of motion',
  'JEE Physics · Motion in a straight line (uniform a)',
  [
    {
      'id': 'table',
      'component': 'Table',
      'caption': 'The three equations of motion',
      'children': ['head', 'first', 'second', 'third'],
    },
    {
      'id': 'head',
      'component': 'TableRow',
      'header': true,
      'children': ['hn', 'he', 'hr'],
    },
    {'id': 'hn', 'component': 'TableCell', 'text': ''},
    {'id': 'he', 'component': 'TableCell', 'text': 'Equation'},
    {'id': 'hr', 'component': 'TableCell', 'text': 'Leaves out'},
    for (final (id, label, equation, missing) in [
      ('first', '1st', 'v = u + at', 's'),
      ('second', '2nd', 's = ut + ½at²', 'v'),
      ('third', '3rd', 'v² = u² + 2as', 't'),
    ]) ...[
      {
        'id': id,
        'component': 'TableRow',
        'label': label,
        'children': ['${id}_e', '${id}_m'],
      },
      {'id': '${id}_e', 'component': 'TableCell', 'text': equation},
      {'id': '${id}_m', 'component': 'TableCell', 'text': missing},
    ],
  ],
);

/// TableCells that span, align and hold components: meiosis I's stages.
final List<Map<String, Object?>> _cell = _scene(
  'Meiosis I, stage by stage',
  'NEET Biology · Cell cycle and cell division',
  [
    {
      'id': 'table',
      'component': 'Table',
      'caption': 'The stages of meiosis I',
      'children': ['head', 'body'],
    },
    {
      'id': 'head',
      'component': 'TableSection',
      'header': true,
      'children': ['hr'],
    },
    {
      'id': 'hr',
      'component': 'TableRow',
      'children': ['h1', 'h2', 'h3'],
    },
    {'id': 'h1', 'component': 'TableCell', 'text': 'Stage'},
    {'id': 'h2', 'component': 'TableCell', 'text': 'Key event'},
    {'id': 'h3', 'component': 'TableCell', 'text': 'Remember', 'align': 'end'},
    {
      'id': 'body',
      'component': 'TableSection',
      'children': ['r1', 'r2', 'r3', 'r4'],
    },
    {
      'id': 'r1',
      'component': 'TableRow',
      'children': ['pro', 'syn', 'tag'],
    },
    {
      'id': 'pro',
      'component': 'TableCell',
      'text': 'Prophase I',
      'header': true,
      'rowSpan': 2,
      'vAlign': 'center',
    },
    {
      'id': 'syn',
      'component': 'TableCell',
      'text': 'Synapsis in zygotene; crossing over in pachytene',
    },
    {
      'id': 'tag',
      'component': 'TableCell',
      'align': 'end',
      'children': ['badge'],
    },
    {'id': 'badge', 'component': 'Badge', 'label': 'Tetrad', 'color': 'info'},
    {
      'id': 'r2',
      'component': 'TableRow',
      'children': ['chi', 'dip'],
    },
    {
      'id': 'chi',
      'component': 'TableCell',
      'text': 'Chiasmata seen in diplotene',
    },
    {'id': 'dip', 'component': 'TableCell', 'text': 'X-shaped', 'align': 'end'},
    {
      'id': 'r3',
      'component': 'TableRow',
      'children': ['meta', 'line', 'often'],
    },
    {
      'id': 'meta',
      'component': 'TableCell',
      'text': 'Metaphase I',
      'header': true,
    },
    {
      'id': 'line',
      'component': 'TableCell',
      'text': 'Bivalents line up on the equatorial plate',
    },
    {
      'id': 'often',
      'component': 'TableCell',
      'text': 'Spindle attaches',
      'align': 'end',
    },
    {
      'id': 'r4',
      'component': 'TableRow',
      'children': ['next'],
    },
    {
      'id': 'next',
      'component': 'TableCell',
      'text': 'Meiosis II then divides like mitosis',
      'colSpan': 3,
      'align': 'center',
    },
  ],
);

/// A block on a rough incline with its weight, normal force and friction,
/// drawn and labelled: the incline rises at θ = atan(140 / 280) ≈ 26.6°.
final List<Map<String, Object?>> _svg = _scene(
  'Forces on a block on a rough incline',
  'JEE Physics · Laws of motion: free-body diagram',
  [_incline()],
);

Map<String, Object?> _incline() {
  // The slope from C (20, 60) down to B (300, 200): along it (cos θ,
  // sin θ), out of it (sin θ, -cos θ).
  const c = (20.0, 60.0);
  const along = (0.8944, 0.4472);
  const out = (0.4472, -0.8944);
  (double, double) at((double, double) p, (double, double) d, double k) =>
      (p.$1 + d.$1 * k, p.$2 + d.$2 * k);
  String xy((double, double) p) =>
      '${p.$1.toStringAsFixed(1)} ${p.$2.toStringAsFixed(1)}';
  final p = at(c, along, 110);
  final q = at(p, along, 50);
  final r = at(q, out, 50);
  final s = at(p, out, 50);
  final g = ((p.$1 + r.$1) / 2, (p.$2 + r.$2) / 2);
  // An arrow from g along d, k long, with a filled head.
  List<Map<String, Object?>> arrow((double, double) d, double k, String color) {
    final tip = at(g, d, k);
    final back = at(tip, d, -10);
    final side = (-d.$2, d.$1);
    return [
      {'d': 'M${xy(g)}L${xy(back)}', 'stroke': color, 'strokeWidth': 2.5},
      {
        'd':
            'M${xy(tip)}L${xy(at(back, side, 5))}'
            'L${xy(at(back, side, -5))}Z',
        'fill': color,
        'stroke': 'none',
      },
    ];
  }

  return {
    'id': 'svg',
    'component': 'Svg',
    'viewBox': '0 0 320 220',
    'label':
        'A block on an incline at angle theta, with its weight mg down, the '
        'normal force N out of the slope and friction f up the slope',
    'strokeLinecap': 'round',
    'strokeLinejoin': 'round',
    'paths': [
      // The incline.
      {
        'd': 'M20 200L300 200L20 60Z',
        'fill': 'rgba(148, 163, 184, 0.25)',
        'stroke': 'secondary',
        'strokeWidth': 1.5,
      },
      // The block on it.
      {
        'd': 'M${xy(p)}L${xy(q)}L${xy(r)}L${xy(s)}Z',
        'fill': 'rgba(59, 130, 246, 0.35)',
        'stroke': 'info',
        'strokeWidth': 1.5,
      },
      // θ at the foot of the slope.
      {
        'd': 'M270 200A30 30 0 0 1 273.2 186.6',
        'fill': 'none',
        'stroke': 'secondary',
      },
      ...arrow((0, 1), 78, 'danger'),
      ...arrow(out, 72, 'success'),
      ...arrow((-along.$1, -along.$2), 64, 'warning'),
    ],
    'lines': [
      {'x1': 4, 'y1': 200, 'x2': 316, 'y2': 200, 'stroke': 'secondary'},
    ],
    'circles': [
      {'cx': g.$1, 'cy': g.$2, 'r': 3, 'fill': 'default'},
    ],
    'texts': [
      {
        'x': g.$1 + 8,
        'y': g.$2 + 74,
        'text': 'mg',
        'size': 15,
        'fill': 'danger',
      },
      {
        'x': g.$1 + 40,
        'y': g.$2 - 60,
        'text': 'N',
        'size': 15,
        'fill': 'success',
      },
      {
        'x': g.$1 - 62,
        'y': g.$2 - 34,
        'text': 'f',
        'size': 15,
        'fill': 'warning',
        'anchor': 'end',
      },
      {
        'x': 258,
        'y': 194,
        'text': 'θ',
        'size': 14,
        'fill': 'secondary',
        'anchor': 'middle',
      },
    ],
  };
}

/// One step of a derivation: a caption and the equation.
List<Map<String, Object?>> _step(
  int n,
  String what,
  String equation, {
  Map<String, Object?> props = const {},
}) => [
  {
    'id': 'step$n',
    'component': 'FlowItem',
    'aspectRatio': '4 / 3',
    'padding': 3,
    'radius': 'lg',
    'background': 'surface-secondary',
    'gap': 1,
    'children': ['step${n}_c', 'step${n}_e'],
    ...props,
  },
  {'id': 'step${n}_c', 'component': 'Caption', 'text': 'Step $n · $what'},
  {
    'id': 'step${n}_e',
    'component': 'Text',
    'text': equation,
    'fontWeight': 'medium',
  },
];

/// v² = u² + 2as from the first two equations of motion, a step per item.
final List<Map<String, Object?>> _flow = _scene(
  'Deriving v² = u² + 2as',
  'JEE Physics · from v = u + at and s = ut + ½at²',
  [
    {
      // The default 3 columns: two at a phone's width (a 2-column Flow's
      // 260px tracks leave one column and an implicit one there).
      'id': 'flow',
      'component': 'Flow',
      'gap': 3,
      'children': ['step1', 'step2', 'step3', 'step4', 'step5', 'step6'],
    },
    ..._step(1, 'time', 'v = u + at, so t = (v − u) / a'),
    ..._step(2, 'distance', 's = ut + ½at²'),
    ..._step(3, 'put t in', 's = u(v − u)/a + ½a((v − u)/a)²'),
    ..._step(4, 'times 2a', '2as = 2u(v − u) + (v − u)²'),
    ..._step(5, 'expand', '2as = 2uv − 2u² + v² − 2uv + u²'),
    ..._step(
      6,
      'result',
      'v² = u² + 2as',
      props: {'span': 2, 'aspectRatio': '4 / 1', 'background': 'info'},
    ),
  ],
);

/// FlowItems of different spans and ratios, packed: cell organelles and
/// what each does (NCERT Class 11 Biology, Cell: the unit of life).
final List<Map<String, Object?>> _flowItem = _scene(
  'Cell organelles and their jobs',
  'NEET Biology · Cell: the unit of life',
  [
    {
      'id': 'flow',
      'component': 'Flow',
      'columns': 3,
      'gap': 2,
      'children': ['physio', 'genetics', 'plant', 'ecology', 'cell', 'evo'],
    },
    for (final (id, unit, share, props) in [
      ('physio', 'Mitochondria', 'ATP', {'span': 2, 'aspectRatio': '2 / 1'}),
      ('genetics', 'Ribosome', 'Proteins', const <String, Object?>{}),
      (
        'plant',
        'Chloroplast',
        'Sugars',
        {'rowSpan': 2, 'aspectRatio': '1 / 2'},
      ),
      ('ecology', 'Nucleus', 'DNA', const <String, Object?>{}),
      ('cell', 'Lysosome', 'Digestion', const <String, Object?>{}),
      ('evo', 'Golgi body', 'Packaging', const <String, Object?>{}),
    ]) ...[
      {
        'id': id,
        'component': 'FlowItem',
        'padding': 3,
        'radius': 'lg',
        'background': id == 'physio' ? 'success' : 'surface-secondary',
        'justify': 'spaceBetween',
        'children': ['${id}_u', '${id}_s'],
        ...props,
      },
      {'id': '${id}_u', 'component': 'Caption', 'text': unit},
      {'id': '${id}_s', 'component': 'Title', 'text': share, 'size': 'xl'},
    ],
  ],
);

/// Each picture: its name, its scene and its data.
final Map<String, (List<Map<String, Object?>>, Map<String, Object?>?)>
_pictures = {
  'table': (_table, null),
  'table-section': (_section, _sectionData),
  'table-row': (_row, null),
  'table-cell': (_cell, null),
  'svg': (_svg, null),
  'flow': (_flow, null),
  'flow-item': (_flowItem, null),
};

Future<void> _shoot(
  WidgetTester tester,
  String name,
  A2uiKitLook look,
  Brightness brightness,
) async {
  final (components, data) = _pictures[name]!;
  final standard = look == A2uiKitLook.standard;
  final theme = A2uiKitTheme.fromLook(look, brightness);
  final app = ReadmeApp(
    standard
        ? a2uiKitStandardCatalog(
            options: const A2uiKitOptions(look: A2uiKitLook.standard),
          )
        : a2uiKitCatalog(),
  );
  addTearDown(app.dispose);
  app.receive(
    createMessages(
      components,
      data: data,
      catalogId: standard ? kA2uiStandardCatalogId : kA2uiPlaygroundCatalogId,
    ),
  );
  final surface = app.surfaces[testSurfaceId]!;
  tester.view
    ..physicalSize = const Size(390 * 2, 2400 * 2)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: brightness, extensions: [theme]),
      home: Material(
        color: theme.color(A2uiColorToken.surface),
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: theme.color(A2uiColorToken.surface),
              child: SizedBox(
                width: 390,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: app.view(surface),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
  final render =
      tester.renderObject(find.byKey(boundary)) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$_out\\$name-${look.name}-${brightness.name}.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  for (final name in _pictures.keys) {
    for (final look in A2uiKitLook.values) {
      for (final brightness in Brightness.values) {
        testWidgets('$name, ${look.name}, ${brightness.name}', (tester) async {
          await _shoot(tester, name, look, brightness);
        });
      }
    }
  }
}
