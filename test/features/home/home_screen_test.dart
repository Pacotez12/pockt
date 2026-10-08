import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/ui/day_detail_sheet.dart';
import 'package:pockt/features/home/ui/home_screen.dart';
import 'package:pockt/features/home/ui/month_glow.dart';
import 'package:pockt/features/settings/ui/category_keywords_screen.dart';
import 'package:pockt/features/shell/ui/app_shell.dart';
import 'package:pockt/features/transactions/data/categories_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  late AppDatabase testDb;
  late CategoriesRepository catRepo;
  late TransactionsRepository txRepo;

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() async {
    setLocalZone('America/Asuncion');
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    catRepo = CategoriesRepository(testDb);
    txRepo = TransactionsRepository(testDb);
  });

  tearDown(() async {
    await testDb.close();
  });

  Future<void> pumpHomeScreen(
    WidgetTester tester, {
    int year = 2026,
    int month = 10,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: HomeScreen(
            initialYear: year,
            initialMonth: month,
            nowLocal: DateTime(year, month, 8, 12, 0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpAppShell(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mes vacío: Gs. 0, sin crash, glow de marca', (t) async {
    await pumpHomeScreen(t);

    expect(find.text('Gs. 0'), findsOneWidget);
    final glow = t.widget<MonthGlow>(find.byType(MonthGlow));
    expect(glow.color, equals(PocktColors.dark.brandStart));
  });

  testWidgets('total y glow siguen a la categoría con más gasto', (t) async {
    final categories = (await t.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
    final hogar = categories.firstWhere((c) => c.name == 'Hogar');
    final comida = categories.firstWhere((c) => c.name == 'Comida');

    await t.runAsync(() async {
      await txRepo.add(
        type: TxType.expense,
        amount: 380000,
        categoryId: hogar.id,
        occurredAt: DateTime.utc(2026, 10, 5, 14, 0),
      );
      await txRepo.add(
        type: TxType.expense,
        amount: 186000,
        categoryId: comida.id,
        occurredAt: DateTime.utc(2026, 10, 6, 14, 0),
      );
    });

    await pumpHomeScreen(t);

    expect(find.text('Gs. 566.000'), findsOneWidget);
    final glow = t.widget<MonthGlow>(find.byType(MonthGlow));
    expect(glow.color, equals(Color(hogar.colorDark)));
  });

  testWidgets('el ＋ abre la carga', (t) async {
    await pumpAppShell(t);

    final plusButton = find.byKey(const ValueKey('shell-plus-button'));
    expect(plusButton, findsOneWidget);

    await t.tap(plusButton);
    await t.pumpAndSettle();

    expect(find.text('Comida'), findsOneWidget);
  });

  testWidgets('tocar un día en el calendario abre el detalle', (t) async {
    final categories = (await t.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
    final comida = categories.firstWhere((c) => c.name == 'Comida');

    await t.runAsync(() async {
      await txRepo.add(
        type: TxType.expense,
        amount: 25000,
        categoryId: comida.id,
        occurredAt: DateTime.utc(2026, 10, 5, 14, 0),
      );
    });

    await pumpHomeScreen(t);

    await t.tap(find.text('5'));
    await t.pumpAndSettle();

    expect(find.byType(DayDetailSheet), findsOneWidget);
    expect(find.text('Lunes 5 de octubre'), findsOneWidget);
  });

  testWidgets('el engranaje abre CategoryKeywordsScreen', (t) async {
    await pumpHomeScreen(t);

    final settingsButton = find.byKey(const ValueKey('home-settings-button'));
    expect(settingsButton, findsOneWidget);

    await t.tap(settingsButton);
    await t.pumpAndSettle();

    expect(find.byType(CategoryKeywordsScreen), findsOneWidget);
    expect(find.text('Palabras clave'), findsOneWidget);
  });

  testWidgets(
      'durante el vuelo (abrir y cerrar) no hay ningún Text descendiente del shuttle',
      (t) async {
    final categories =
        (await t.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
    final comida = categories.firstWhere((c) => c.name == 'Comida');

    await t.runAsync(() async {
      await txRepo.add(
        type: TxType.expense,
        amount: 500000,
        categoryId: comida.id,
        occurredAt: DateTime.utc(2026, 10, 5, 14, 0),
      );
    });

    await pumpHomeScreen(t);

    // 1. Abrir detalle del día 5 y verificar a mitad de vuelo
    await t.tap(find.text('5'));
    await t.pump(); // Inicia el push
    await t.pump(const Duration(milliseconds: 150)); // Mitad de vuelo al abrir (duration: 350ms)

    final openShuttleFinder = find.byKey(const ValueKey('day-detail-flight-shuttle'));
    expect(openShuttleFinder, findsOneWidget);

    // Ningún Text descendiente del shuttle durante el vuelo de apertura (sin texto fantasma)
    expect(find.descendant(of: openShuttleFinder, matching: find.byType(Text)), findsNothing);

    // Completar la apertura: la hoja real muestra su contenido
    await t.pumpAndSettle();
    expect(find.byType(DayDetailSheet), findsOneWidget);
    expect(find.text('Lunes 5 de octubre'), findsOneWidget);

    // 2. Cerrar tocando afuera de la hoja y verificar a mitad de vuelo
    await t.tapAt(const Offset(50, 50));
    await t.pump(); // Inicia el pop
    await t.pump(const Duration(milliseconds: 140)); // Mitad de vuelo al cerrar (reverseDuration: 300ms)

    final closeShuttleFinder = find.byKey(const ValueKey('day-detail-flight-shuttle'));
    expect(closeShuttleFinder, findsOneWidget);

    // El shuttle tiene tamaño intermedio a mitad de vuelo (mucho mayor que la celda de ~40px)
    final shuttleSize = t.getSize(closeShuttleFinder);
    expect(shuttleSize.width, greaterThan(100));
    expect(shuttleSize.height, greaterThan(100));

    // La superficie del shuttle debe ser sheetSurface, NO el color de intensidad de la celda
    final shuttleContainer = t.widget<Container>(closeShuttleFinder);
    final boxDecoration = shuttleContainer.decoration as BoxDecoration;
    expect(
      boxDecoration.color,
      PocktColors.dark.sheetSurface.withValues(alpha: 0.96),
    );

    // Ningún Text descendiente del shuttle durante el vuelo de cierre (sin texto fantasma)
    expect(find.descendant(of: closeShuttleFinder, matching: find.byType(Text)), findsNothing);

    // Completar el cierre
    await t.pumpAndSettle();
    expect(find.byType(DayDetailSheet), findsNothing);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('con reduce motion al abrir y cerrar detalle no hay Hero en vuelo', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(() => t.platformDispatcher.clearAllTestValues());

    final categories =
        (await t.runAsync(() => catRepo.watchActive(CategoryKind.expense).first))!;
    final comida = categories.firstWhere((c) => c.name == 'Comida');

    await t.runAsync(() async {
      await txRepo.add(
        type: TxType.expense,
        amount: 25000,
        categoryId: comida.id,
        occurredAt: DateTime.utc(2026, 10, 5, 14, 0),
      );
    });

    await pumpHomeScreen(t);

    await t.tap(find.text('5'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));

    // Con reduce motion no hay Hero en vuelo
    expect(find.byKey(const ValueKey('day-detail-flight-shuttle')), findsNothing);

    await t.pumpAndSettle();
    expect(find.byType(DayDetailSheet), findsOneWidget);

    await t.tapAt(const Offset(50, 50));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('day-detail-flight-shuttle')), findsNothing);

    await t.pumpAndSettle();
    expect(find.byType(DayDetailSheet), findsNothing);
  });
}
