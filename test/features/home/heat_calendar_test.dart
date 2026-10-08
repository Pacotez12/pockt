import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/design/theme.dart';
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
}
