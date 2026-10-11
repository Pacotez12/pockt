import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/home/ui/heat_calendar.dart';

void main() {
  testWidgets('octubre 2026 empieza en jueves: 3 celdas vacías antes del 1', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeatCalendar(
              year: 2026,
              month: 10,
              levels: const {},
              todayLocal: DateTime(2026, 10, 8),
              onDayTap: (_) {},
            ),
          ),
        ),
      ),
    );

    // Las celdas del calendario
    final dayCells = t.widgetList<HeatCalendarDayCell>(find.byType(HeatCalendarDayCell)).toList();

    // Octubre 2026 tiene 1 jueves -> 3 celdas vacías (L, M, M) antes del 1
    // y 31 celdas numeradas para los 31 días
    expect(dayCells.length, equals(3 + 31));

    // Primeras 3 celdas sin número
    for (var i = 0; i < 3; i++) {
      expect(dayCells[i].day, isNull, reason: 'Celda $i debería ser vacía');
    }

    // La 4ª celda (índice 3) dice '1'
    expect(dayCells[3].day, equals(1));
    expect(find.text('1'), findsOneWidget);

    // La última celda dice '31'
    expect(dayCells.last.day, equals(31));
    expect(find.text('31'), findsOneWidget);
  });

  testWidgets('días futuros punteados y hoy con borde', (t) async {
    int? tappedDay;
    await t.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeatCalendar(
              year: 2026,
              month: 10,
              levels: const {24: 3},
              todayLocal: DateTime(2026, 10, 24),
              onDayTap: (day) => tappedDay = day,
            ),
          ),
        ),
      ),
    );

    final dayCells = t.widgetList<HeatCalendarDayCell>(find.byType(HeatCalendarDayCell)).toList();
    // Encontrar la celda del 24 y del 25
    final cell24 = dayCells.firstWhere((c) => c.day == 24);
    final cell25 = dayCells.firstWhere((c) => c.day == 25);

    expect(cell24.isToday, isTrue);
    expect(cell24.isFuture, isFalse);

    expect(cell25.isToday, isFalse);
    expect(cell25.isFuture, isTrue);

    // Tap en el día 24 llama a onDayTap
    await t.tap(find.text('24'));
    expect(tappedDay, equals(24));

    // Tap en día futuro no hace nada
    tappedDay = null;
    await t.tap(find.text('25'));
    expect(tappedDay, isNull);

    // Tap en día pasado llama a onDayTap
    await t.tap(find.text('10'));
    expect(tappedDay, equals(10));
  });

  testWidgets('nivel 4 tiene degradé en oscuro y en claro en celdas', (t) async {
    for (final theme in [buildDarkTheme(), buildLightTheme()]) {
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HeatCalendar(
                year: 2026,
                month: 10,
                levels: const {5: 4},
                todayLocal: DateTime(2026, 10, 8),
                onDayTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      // Celda nivel 4
      final cell5Container = t.widget<Container>(find.descendant(
        of: find.ancestor(of: find.text('5'), matching: find.byType(HeatCalendarDayCell)),
        matching: find.byType(Container),
      ).first);
      final cellBox = cell5Container.decoration as BoxDecoration;
      expect(cellBox.gradient, isNotNull, reason: 'Celda nivel 4 debe tener degradé');
      expect((cellBox.gradient as LinearGradient).colors, [theme.extension<PocktColors>()!.brandStart, theme.extension<PocktColors>()!.brandEnd]);
    }
  });

  testWidgets('hoy usa borde con color textPrimary en ambos temas', (t) async {
    for (final theme in [buildDarkTheme(), buildLightTheme()]) {
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HeatCalendar(
                year: 2026,
                month: 10,
                levels: const {},
                todayLocal: DateTime(2026, 10, 8),
                onDayTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      final todayContainer = t.widget<Container>(find.descendant(
        of: find.ancestor(of: find.text('8'), matching: find.byType(HeatCalendarDayCell)),
        matching: find.byType(Container),
      ).first);
      final box = todayContainer.decoration as BoxDecoration;
      expect(box.border?.top.color, equals(theme.extension<PocktColors>()!.textPrimary));
    }
  });

  testWidgets('contraste del número sobre cada nivel >= 4.5:1 en ambos temas', (t) async {
    double contrastRatio(Color fg, Color bg) {
      final l1 = fg.computeLuminance();
      final l2 = bg.computeLuminance();
      final brightest = l1 > l2 ? l1 : l2;
      final darkest = l1 > l2 ? l2 : l1;
      return (brightest + 0.05) / (darkest + 0.05);
    }

    Color compositeOver(Color fg, Color bg) {
      final alpha = fg.a;
      final invAlpha = 1.0 - alpha;
      return Color.from(
        alpha: 1.0,
        red: fg.r * alpha + bg.r * invAlpha,
        green: fg.g * alpha + bg.g * invAlpha,
        blue: fg.b * alpha + bg.b * invAlpha,
      );
    }

    for (final theme in [buildDarkTheme(), buildLightTheme()]) {
      final colors = theme.extension<PocktColors>()!;
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HeatCalendar(
                year: 2026,
                month: 10,
                levels: const {1: 0, 2: 1, 3: 2, 4: 3, 5: 4},
                todayLocal: DateTime(2026, 10, 8),
                onDayTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      for (var day = 1; day <= 5; day++) {
        final level = day - 1;
        final textWidget = t.widget<Text>(find.text('$day'));
        final textColor = textWidget.style!.color!;

        final Color bg;
        if (level == 4) {
          final bgStart = colors.brandStart;
          final bgEnd = colors.brandEnd;
          expect(contrastRatio(textColor, bgStart), greaterThanOrEqualTo(4.5),
              reason: 'Día $day (nivel $level) en ${theme.brightness} no tiene contraste 4.5:1 contra brandStart');
          expect(contrastRatio(textColor, bgEnd), greaterThanOrEqualTo(4.5),
              reason: 'Día $day (nivel $level) en ${theme.brightness} no tiene contraste 4.5:1 contra brandEnd');
          continue;
        } else {
          bg = compositeOver(colors.heat[level], colors.background);
        }

        final effectiveText = compositeOver(textColor, bg);
        expect(contrastRatio(effectiveText, bg), greaterThanOrEqualTo(4.5),
            reason: 'Día $day (nivel $level) en ${theme.brightness} no tiene contraste >= 4.5:1');
      }
    }
  });
}
