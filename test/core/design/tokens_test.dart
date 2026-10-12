import 'package:drift/drift.dart' show DatabaseConnection;
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/design/tokens.dart';

void main() {
  test('oscuro usa negro puro y vidrio 7%/9%', () {
    expect(PocktColors.dark.background, const Color(0xFF000000));
    expect(PocktColors.dark.glassFill, Colors.white.withValues(alpha: 0.07));
    expect(PocktColors.dark.glassBorder, Colors.white.withValues(alpha: 0.09));
    expect(PocktColors.dark.heat, hasLength(5));
    expect(PocktColors.light.heat, hasLength(5));
  });

  test('lerp interpola entre claro y oscuro', () {
    final mid = PocktColors.dark.lerp(PocktColors.light, 0.5);
    expect(mid.background, isNot(PocktColors.dark.background));
    expect(mid.sheetSurface, isNot(PocktColors.dark.sheetSurface));
    expect(mid.keypadKey, isNot(PocktColors.dark.keypadKey));
  });

  test('sheetSurface oscuro es 0xFF18181B y claro es blanco', () {
    expect(PocktColors.dark.sheetSurface, const Color(0xFF18181B));
    expect(PocktColors.light.sheetSurface, const Color(0xFFFFFFFF));
  });

  test('colores heat y brand coinciden con especificación', () {
    expect(PocktColors.dark.brandStart, const Color(0xFFFF8A3D));
    expect(PocktColors.dark.brandEnd, const Color(0xFFFF3D7F));
    expect(PocktColors.dark.positive, const Color(0xFF4AD496));
    expect(PocktColors.light.brandStart, const Color(0xFFFF8A3D));
    expect(PocktColors.light.brandEnd, const Color(0xFFFF3D7F));
    expect(PocktColors.light.positive, const Color(0xFF008856));

    expect(PocktColors.dark.heat, [
      const Color(0x0DFFFFFF),
      const Color(0xFF55263A),
      const Color(0xFF94344D),
      const Color(0xFFDA534F),
      const Color(0xFFFF3D7F),
    ]);

    expect(PocktColors.light.heat, [
      const Color(0x0D000000),
      const Color(0xFFFFE0DA),
      const Color(0xFFFFBDB7),
      const Color(0xFFF98E8F),
      const Color(0xFFFF3D7F),
    ]);
  });

  test('la escala heat es opaca, de la familia de la marca y sube de luminosidad', () {
    for (final (name, colors, rising) in [
      ('oscuro', PocktColors.dark, true),
      ('claro', PocktColors.light, false),
    ]) {
      double? prev;
      for (var i = 1; i <= 4; i++) {
        final c = colors.heat[i];
        expect(c.a, 1.0, reason: '$name heat[$i] debe ser opaco (no marrón sobre el fondo)');
        final hue = HSVColor.fromColor(c).hue;
        expect(hue >= 330 || hue <= 30, isTrue,
            reason: '$name heat[$i] ($c) fuera de la familia rosa-coral de la marca');
        final l = c.computeLuminance();
        if (prev != null) {
          expect(rising ? l > prev : l < prev, isTrue,
              reason: '$name heat[$i] debe ${rising ? 'aclarar' : 'oscurecer'} respecto del anterior');
        }
        prev = l;
      }
    }
  });

  test('el selector de fecha marca hoy con textPrimary', () {
    final darkTheme = buildDarkTheme();
    final lightTheme = buildLightTheme();

    expect(darkTheme.datePickerTheme.todayForegroundColor?.resolve({}), equals(PocktColors.dark.textPrimary));
    expect(darkTheme.datePickerTheme.todayBorder?.color, equals(PocktColors.dark.textPrimary));

    expect(lightTheme.datePickerTheme.todayForegroundColor?.resolve({}), equals(PocktColors.light.textPrimary));
    expect(lightTheme.datePickerTheme.todayBorder?.color, equals(PocktColors.light.textPrimary));
  });

  test('estados nuevos de §6.2b en oscuro y claro', () {
    expect(PocktColors.dark.positive, const Color(0xFF4AD496));
    expect(PocktColors.dark.warning, const Color(0xFFF7B83D));
    expect(PocktColors.dark.danger, const Color(0xFFF4514F));

    expect(PocktColors.light.positive, const Color(0xFF008856));
    expect(PocktColors.light.warning, const Color(0xFFB07100));
    expect(PocktColors.light.danger, const Color(0xFFCC272E));
  });

  test('brandRamp con 4 pasos del degradé y brandAt(0..3)', () {
    expect(PocktColors.dark.brandRamp, hasLength(4));
    expect(PocktColors.dark.brandRamp, const [
      Color(0xFFFF8A3D),
      Color(0xFFFF7053),
      Color(0xFFFF5769),
      Color(0xFFFF3D7F),
    ]);
    expect(PocktColors.light.brandRamp, PocktColors.dark.brandRamp);

    expect(PocktColors.dark.brandAt(0), const Color(0xFFFF8A3D));
    expect(PocktColors.dark.brandAt(1), const Color(0xFFFF7053));
    expect(PocktColors.dark.brandAt(2), const Color(0xFFFF5769));
    expect(PocktColors.dark.brandAt(3), const Color(0xFFFF3D7F));

    expect(PocktColors.light.brandAt(0), const Color(0xFFFF8A3D));
    expect(PocktColors.light.brandAt(1), const Color(0xFFFF7053));
    expect(PocktColors.light.brandAt(2), const Color(0xFFFF5769));
    expect(PocktColors.light.brandAt(3), const Color(0xFFFF3D7F));
  });

  test('superficie keypadKey para reemplazar #141414', () {
    expect(PocktColors.dark.keypadKey, const Color(0xFF141414));
    expect(PocktColors.light.keypadKey, const Color(0xFFE4E4E7));
  });

  test('los estados no coinciden con ningún color de categoría de fábrica', () async {
    final db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    final categories = await db.select(db.categories).get();
    await db.close();

    expect(categories, isNotEmpty);

    final darkStates = {
      PocktColors.dark.positive.toARGB32(),
      PocktColors.dark.warning.toARGB32(),
      PocktColors.dark.danger.toARGB32(),
    };
    final lightStates = {
      PocktColors.light.positive.toARGB32(),
      PocktColors.light.warning.toARGB32(),
      PocktColors.light.danger.toARGB32(),
    };

    for (final cat in categories) {
      expect(
        darkStates.contains(cat.colorDark),
        isFalse,
        reason: 'Estado oscuro coincide con categoría "${cat.name}" (${cat.colorDark.toRadixString(16)})',
      );
      expect(
        lightStates.contains(cat.colorLight),
        isFalse,
        reason: 'Estado claro coincide con categoría "${cat.name}" (${cat.colorLight.toRadixString(16)})',
      );
    }
  });

  test('contraste >= 3:1 de estados y pasos del degradé contra el fondo en ambos temas', () {
    double contrastRatio(Color fg, Color bg) {
      final l1 = fg.computeLuminance();
      final l2 = bg.computeLuminance();
      final brightest = l1 > l2 ? l1 : l2;
      final darkest = l1 > l2 ? l2 : l1;
      return (brightest + 0.05) / (darkest + 0.05);
    }

    // Modo oscuro: estados y pasos del degradé contra fondo negro
    expect(
      contrastRatio(PocktColors.dark.positive, PocktColors.dark.background),
      greaterThanOrEqualTo(3.0),
    );
    expect(
      contrastRatio(PocktColors.dark.warning, PocktColors.dark.background),
      greaterThanOrEqualTo(3.0),
    );
    expect(
      contrastRatio(PocktColors.dark.danger, PocktColors.dark.background),
      greaterThanOrEqualTo(3.0),
    );

    for (var i = 0; i < 4; i++) {
      expect(
        contrastRatio(PocktColors.dark.brandAt(i), PocktColors.dark.background),
        greaterThanOrEqualTo(3.0),
        reason: 'brandAt($i) oscuro no cumple contraste 3:1',
      );
    }

    // Modo claro: estados contra fondo claro
    expect(
      contrastRatio(PocktColors.light.positive, PocktColors.light.background),
      greaterThanOrEqualTo(3.0),
    );
    expect(
      contrastRatio(PocktColors.light.warning, PocktColors.light.background),
      greaterThanOrEqualTo(3.0),
    );
    expect(
      contrastRatio(PocktColors.light.danger, PocktColors.light.background),
      greaterThanOrEqualTo(3.0),
    );
  });

  testWidgets('GlassCard usa radio por defecto de 24', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [PocktColors.dark]),
      home: const Scaffold(
        body: GlassCard(child: SizedBox(width: 50, height: 50)),
      ),
    ));
    final container = tester.widget<Container>(
      find.descendant(of: find.byType(GlassCard), matching: find.byType(Container)),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(24));
  });

  test('no hay colores escritos a mano (Color(0x...)) ni Colors.<tono> fuera de tokens y wordmark', () {
    final libDir = Directory('lib');
    final prohibitedPattern = RegExp(
      r'Color\(0x|Colors\.(red|green|blue|orange|amber|grey|purple|pink|teal|cyan|yellow|lime|indigo|brown|blueGrey)',
    );

    final allowedFiles = {
      'lib/core/design/tokens.dart',
      'lib/core/design/wordmark.dart',
    };

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final normalizedPath = entity.path.replaceAll('\\', '/');
        if (allowedFiles.any((allowed) => normalizedPath.endsWith(allowed))) {
          continue;
        }

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) {
            continue;
          }
          if (prohibitedPattern.hasMatch(line)) {
            violations.add('${entity.path}:${i + 1}: $trimmed');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Se encontraron colores fuera de tokens:\n${violations.join('\n')}',
    );
  });
}
