import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/app.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/design/tokens.dart';

void main() {
  testWidgets('el selector de fecha muestra "Cancelar", mes en español y semana desde lunes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'PY'),
          Locale('es'),
        ],
        locale: const Locale('es', 'PY'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDatePicker(
                    context: context,
                    initialDate: DateTime(2026, 10, 10),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                },
                child: const Text('Abrir'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // 1. Botón "Cancelar" en español (no "Cancel")
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('ACEPTAR'), findsOneWidget);

    // 2. Nombre del mes en español (octubre)
    expect(find.textContaining('octubre'), findsWidgets);

    // 3. Semana empieza en lunes (firstDayOfWeekIndex == 1)
    final loc = MaterialLocalizations.of(tester.element(find.byType(CalendarDatePicker)));
    expect(loc.firstDayOfWeekIndex, 1);

    // 4. Tema con los tokens de Pockt
    final darkTheme = buildDarkTheme();
    expect(darkTheme.datePickerTheme.backgroundColor, PocktColors.dark.sheetSurface);
    expect(
      darkTheme.datePickerTheme.dayBackgroundColor?.resolve({WidgetState.selected}),
      PocktColors.dark.brandStart,
    );
    expect(darkTheme.datePickerTheme.headerHeadlineStyle?.fontFamily, 'Inter');
  });

  testWidgets('PocktApp configura el locale es_PY y delegados de localización', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PocktApp()));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('es', 'PY'));
    expect(app.supportedLocales, contains(const Locale('es', 'PY')));
    expect(app.localizationsDelegates, contains(GlobalMaterialLocalizations.delegate));
  });
}
