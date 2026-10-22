import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/recurring/domain/recurrence.dart';
import 'package:pockt/features/recurring/ui/recurring_frequency_card.dart';

void main() {
  Widget buildCard({
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    int? dayOfMonth = 15,
    ValueChanged<RecurrenceFrequency>? onFrequencyChanged,
    ValueChanged<int>? onDayOfMonthChanged,
  }) {
    return MaterialApp(
      theme: buildDarkTheme(),
      home: Scaffold(
        body: RecurringFrequencyCard(
          frequency: frequency,
          dayOfMonth: dayOfMonth,
          onFrequencyChanged: onFrequencyChanged ?? (_) {},
          onDayOfMonthChanged: onDayOfMonthChanged ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('muestra grilla de 1 a 31 días y texto de ayuda en frecuencia mensual', (tester) async {
    int? selectedDay;

    await tester.pumpWidget(buildCard(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 21,
      onDayOfMonthChanged: (d) => selectedDay = d,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Día del mes: 21'), findsOneWidget);

    // Verifica que los días 1 a 31 están presentes en la grilla
    for (int day = 1; day <= 31; day++) {
      expect(find.byKey(ValueKey('day-$day')), findsOneWidget);
    }

    // Texto de ayuda para meses cortos
    expect(
      find.text('29, 30 y 31: en meses más cortos se usa el último día.'),
      findsOneWidget,
    );

    // Tocar el día 31
    await tester.tap(find.byKey(const ValueKey('day-31')));
    expect(selectedDay, 31);
  });
}
