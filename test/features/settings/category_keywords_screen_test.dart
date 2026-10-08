import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/settings/ui/category_keywords_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
  });

  tearDown(() async {
    await db.close();
  });

  void usePhoneSize(WidgetTester t) {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }

  testWidgets('CategoryKeywordsScreen lista categorías, agrega y borra palabras de usuario', (t) async {
    usePhoneSize(t);

    await t.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: const CategoryKeywordsScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Palabras clave'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);

    // Entrar a la categoría Comida
    await t.tap(find.text('Comida'));
    await t.pumpAndSettle();

    // Verificamos que se ven palabras seed (ej. pizza, cafe)
    expect(find.text('pizza'), findsOneWidget);

    // Agregar palabra personalizada
    final input = find.byKey(const ValueKey('add-keyword-input'));
    expect(input, findsOneWidget);
    await t.enterText(input, 'lomito');
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('add-keyword-button')));
    await t.pumpAndSettle();

    expect(find.text('lomito'), findsOneWidget);
    expect(find.text('tuya'), findsOneWidget);

    // Borrar la palabra recién agregada
    final deleteButton = find.byKey(const ValueKey('delete-keyword-lomito'));
    expect(deleteButton, findsOneWidget);
    await t.tap(deleteButton);
    await t.pumpAndSettle();

    expect(find.text('lomito'), findsNothing);
  });
}
