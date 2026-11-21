import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/check_upstream.dart' show compareCatalogs;
import '../tool/src/generator.dart' show catalogFixturePath;

/// The drift report of tool/check_upstream.dart, offline.
void main() {
  Map<String, Object?> fixture() =>
      jsonDecode(File(catalogFixturePath).readAsStringSync())
          as Map<String, Object?>;

  test('a document matches itself, whatever its key order', () {
    final a = fixture();
    final b = {for (final key in a.keys.toList().reversed) key: a[key]};
    expect(compareCatalogs(a, b), isEmpty);
  });

  test('names added, removed and changed components and props', () {
    final local = fixture();
    final live = fixture();
    final components = (live['components']! as Map).cast<String, Object?>()
      ..remove('Kbd')
      ..['Sticker'] = {'type': 'object'};
    final stat = (components['Stat']! as Map).cast<String, Object?>();
    (stat['properties']! as Map)['sparkline'] = {'type': 'array'};
    live['title'] = 'Another title';
    expect(
      compareCatalogs(local, live),
      unorderedEquals([
        '"title" changed',
        'components: Sticker added',
        'components: Stat changed (+sparkline)',
        'components: Kbd removed',
      ]),
    );
  });
}
