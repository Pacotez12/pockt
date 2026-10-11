import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pockt/core/design/icons.dart';

void main() {
  group('kCategoryIconKeys', () {
    test('tiene al menos 40 claves curadas sin duplicados', () {
      expect(kCategoryIconKeys.length, greaterThanOrEqualTo(40));
      expect(kCategoryIconKeys.toSet().length, equals(kCategoryIconKeys.length));
    });

    test('todas las claves de kCategoryIconKeys resuelven a un ícono real', () {
      for (final key in kCategoryIconKeys) {
        final iconWidget = categoryIcon(key) as PhosphorIcon;
        if (key != 'package') {
          expect(
            iconWidget.icon,
            isNot(equals(PhosphorIconsDuotone.package)),
            reason: 'La clave $key resolvió indebidamente al ícono de respaldo package',
          );
        }
      }
    });

    test('las 13 claves del seed están en kCategoryIconKeys', () {
      const seedKeys = [
        'fork-knife',
        'car-profile',
        'house-line',
        'heartbeat',
        'popcorn',
        'lightning',
        'graduation-cap',
        'gift',
        't-shirt',
        'package',
        'briefcase',
        'sparkle',
        'arrow-circle-down',
      ];
      for (final key in seedKeys) {
        expect(kCategoryIconKeys, contains(key),
            reason: 'kCategoryIconKeys debe incluir la clave de seed: $key');
      }
    });
  });

  group('categoryIcon', () {
    test('clave desconocida devuelve el ícono de respaldo package', () {
      final iconWidget = categoryIcon('clave-desconocida-1234') as PhosphorIcon;
      expect(iconWidget.icon, equals(PhosphorIconsDuotone.package));
    });

    testWidgets('renderiza con el tamaño y color indicados', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: categoryIcon(
                'fork-knife',
                size: 32,
                color: const Color(0xFFFF9F43),
              ),
            ),
          ),
        ),
      );

      final iconFinder = find.byType(PhosphorIcon);
      expect(iconFinder, findsOneWidget);
      final phosphorIcon = tester.widget<PhosphorIcon>(iconFinder);
      expect(phosphorIcon.size, equals(32));
      expect(phosphorIcon.color, equals(const Color(0xFFFF9F43)));
      expect(phosphorIcon.icon, equals(PhosphorIconsDuotone.forkKnife));
    });
  });

  group('uiIcon', () {
    test('devuelve variante regular por defecto y fill con filled: true', () {
      expect(uiIcon('plus'), equals(PhosphorIconsRegular.plus));
      expect(uiIcon('plus', filled: true), equals(PhosphorIconsFill.plus));
      expect(uiIcon('x'), equals(PhosphorIconsRegular.x));
      expect(uiIcon('x', filled: true), equals(PhosphorIconsFill.x));
    });

    test('clave desconocida devuelve question como respaldo', () {
      expect(uiIcon('desconocido'), equals(PhosphorIconsRegular.question));
      expect(uiIcon('desconocido', filled: true), equals(PhosphorIconsFill.question));
    });

    test('claves nuevas para backup y restauración resuelven a íconos reales', () {
      const newKeys = [
        'clock-counter-clockwise',
        'cloud-slash',
        'eye',
        'eye-slash',
        'receipt',
        'stack',
        'warning',
        'warning-circle',
      ];
      for (final key in newKeys) {
        expect(uiIcon(key), isNot(equals(PhosphorIconsRegular.question)),
            reason: 'uiIcon($key) en regular debe resolver a un ícono real');
        expect(uiIcon(key, filled: true), isNot(equals(PhosphorIconsFill.question)),
            reason: 'uiIcon($key) en fill debe resolver a un ícono real');
      }
    });

    test('no hay Icons.* de Material en lib/', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final violations = <String>[];
      final regex = RegExp(r'\bIcons\.[a-zA-Z0-9_]+');

      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (regex.hasMatch(line)) {
            violations.add('${file.path}:${i + 1}: ${line.trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'No deben usarse Icons.* de Material en lib/. Usar uiIcon(...) de Phosphor:\n${violations.join('\n')}',
      );
    });
  });
}
