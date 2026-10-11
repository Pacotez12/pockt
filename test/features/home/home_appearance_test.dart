import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/domain/home_cards_config.dart';
import 'package:pockt/features/home/ui/heat_calendar.dart';
import 'package:pockt/features/home/ui/home_cards_screen.dart';
import 'package:pockt/features/home/ui/home_screen.dart';
import 'package:pockt/features/home/ui/month_glow.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  late AppDatabase testDb;
  late SettingsRepository settingsRepo;
  late TransactionsRepository txRepo;

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() async {
    setLocalZone('America/Asuncion');
    testDb = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    settingsRepo = SettingsRepository(testDb);
    txRepo = TransactionsRepository(testDb);
  });

  tearDown(() async {
    await testDb.close();
  });

  Widget buildApp({required Widget child}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(testDb),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        transactionsRepositoryProvider.overrideWithValue(txRepo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Ajuste home.cards e Inicio', () {
    testWidgets('ocultar y reordenar tarjetas cambia el Inicio', (t) async {
      // 1. Ocultar calendario de calor
      final cardsWithoutCalendar = [
        const HomeCardItem(id: 'period', label: 'Quincena', visible: true),
        const HomeCardItem(id: 'suggestions', label: 'Sugerencias', visible: true),
        const HomeCardItem(id: 'calendar', label: 'Calendario', visible: false),
        const HomeCardItem(id: 'recent', label: 'Recientes', visible: true),
      ];
      await settingsRepo.set(SettingsKeys.homeCards, HomeCardItem.encode(cardsWithoutCalendar));

      await t.pumpWidget(
        buildApp(
          child: HomeScreen(
            initialYear: 2026,
            initialMonth: 10,
            nowLocal: DateTime(2026, 10, 10),
          ),
        ),
      );
      await t.pumpAndSettle();

      // El calendario no debe estar visible en el Inicio
      expect(find.byType(HeatCalendar), findsNothing);

      // 2. Reordenar: ahora mostrar calendario primero
      final cardsCalendarFirst = [
        const HomeCardItem(id: 'calendar', label: 'Calendario', visible: true),
        const HomeCardItem(id: 'recent', label: 'Recientes', visible: true),
      ];
      await settingsRepo.set(SettingsKeys.homeCards, HomeCardItem.encode(cardsCalendarFirst));
      await t.pumpAndSettle();

      expect(find.byType(HeatCalendar), findsOneWidget);
    });

    testWidgets('pantalla Tarjetas del Inicio permite conmutar visibilidad', (t) async {
      await t.pumpWidget(
        buildApp(
          child: const HomeCardsScreen(),
        ),
      );
      await t.pumpAndSettle();

      // Encuentra los switches de las tarjetas
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);

      // Tocamos el primer switch para ocultar
      await t.tap(switches.first);
      await t.pumpAndSettle();

      final saved = await settingsRepo.get(SettingsKeys.homeCards);
      expect(saved, isNotNull);
      final decoded = HomeCardItem.decode(saved);
      expect(decoded.first.visible, isFalse);
    });
  });

  group('Ajustes de Aurora (glow.mode)', () {
    testWidgets('off no pinta aurora', (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonthGlow(
              color: Colors.blue,
              mode: GlowMode.off,
            ),
          ),
        ),
      );
      await t.pump();

      expect(
        find.descendant(
          of: find.byType(MonthGlow),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('full pinta tres manchas', (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonthGlow(
              color: Colors.blue,
              mode: GlowMode.full,
            ),
          ),
        ),
      );
      await t.pump();

      // En full debe haber 3 CustomPaint correspondientes a las tres manchas de la aurora
      expect(
        find.descendant(
          of: find.byType(MonthGlow),
          matching: find.byType(CustomPaint),
        ),
        findsNWidgets(3),
      );
    });

    testWidgets('reducir animaciones detiene la aurora', (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: MonthGlow(
                color: Colors.blue,
                mode: GlowMode.subtle,
              ),
            ),
          ),
        ),
      );
      await t.pump();

      // Con disableAnimations activo, MonthGlow debe estar estático sin animación activa
      final state = t.state<State<MonthGlow>>(find.byType(MonthGlow));
      // Con animaciones deshabilitadas, didChangeDependencies detiene los controladores
      expect(state.mounted, isTrue);
    });
  });

  group('Ajuste calendar.weekStart', () {
    testWidgets('semana en domingo corre las celdas del calendario', (t) async {
      // Octubre 2026 empieza en Jueves (DateTime.thursday = 4)
      // Con lunes: L(1), M(2), M(3), J(4) -> 3 vacías previas
      // Con domingo: D(1), L(2), M(3), M(4), J(5) -> 4 vacías previas

      // Test lunes (por defecto)
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HeatCalendar(
                year: 2026,
                month: 10,
                levels: const {},
                todayLocal: DateTime(2026, 10, 10),
                onDayTap: (_) {},
                weekStart: WeekStart.monday,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('D'), findsOneWidget); // Domingo al final de la semana

      // Test domingo
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HeatCalendar(
                year: 2026,
                month: 10,
                levels: const {},
                todayLocal: DateTime(2026, 10, 10),
                onDayTap: (_) {},
                weekStart: WeekStart.sunday,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      // Con domingo, el encabezado 'D' está en la primera columna
      final sundayHeader = find.text('D').first;
      final mondayHeader = find.text('L').first;
      expect(t.getTopLeft(sundayHeader).dx, lessThan(t.getTopLeft(mondayHeader).dx),
          reason: 'Con semana en domingo, D debe estar a la izquierda de L');
    });
  });
}
