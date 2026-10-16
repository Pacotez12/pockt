import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pockt/core/design/icons.dart';

void main() {
  test('todos los íconos que usa la app existen (ninguno cae en "?")', () {
    final used = <String>{};
    final pattern = RegExp(r"uiIcon\('([a-z0-9-]+)'");
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in pattern.allMatches(f.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    final missing = used
        .where(
          (k) => k != 'question' && uiIcon(k) == PhosphorIconsRegular.question,
        )
        .toList();
    expect(missing, isEmpty);
  });
}
