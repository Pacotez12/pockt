import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/home/ui/home_screen.dart';
import 'package:pockt/features/security/app_lock.dart';
import 'package:pockt/features/settings/domain/export_csv.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:timezone/data/latest.dart' as tz;

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('Task 6: Privacidad y datos', () {
    late AppDatabase db;
    late SettingsRepository settingsRepo;
    late TransactionsRepository txRepo;

    setUp(() async {
      setLocalZone('America/Asuncion');
      db = AppDatabase.forTesting(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      settingsRepo = SettingsRepository(db);
      txRepo = TransactionsRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'CSV con encabezado y una fila por movimiento con montos enteros',
      () async {
        final comida = await (db.select(
          db.categories,
        )..where((c) => c.name.equals('Comida'))).getSingle();

        await txRepo.add(
          type: TxType.expense,
          amount: 150000,
          categoryId: comida.id,
          occurredAt: DateTime(2026, 10, 10, 14, 30),
          note: 'Almuerzo con amigos',
          merchant: 'Superseis',
        );

        final items = await txRepo.getAllActive();
        expect(items, hasLength(1));

        final csv = generateTransactionsCsv(items);

        // Verificamos prefijo BOM de UTF-8 (\uFEFF)
        expect(csv.startsWith('\uFEFF'), isTrue);

        // Verificamos encabezado con separador punto y coma
        final lines = csv.substring(1).trim().split('\n');
        expect(lines.first, 'Fecha;Tipo;Monto;Categoría;Nota;Comercio');

        // Verificamos fila de movimiento con monto entero
        expect(lines.length, 2);
        expect(
          lines[1],
          '2026-10-10 14:30;Gasto;150000;Comida;Almuerzo con amigos;Superseis',
        );
      },
    );

    test(
      'borrar exige BORRAR y deja la base con las categorías de fábrica',
      () async {
        // 1. Agregamos transacciones y datos
        final comida = await (db.select(
          db.categories,
        )..where((c) => c.name.equals('Comida'))).getSingle();

        await txRepo.add(
          type: TxType.expense,
          amount: 50000,
          categoryId: comida.id,
          occurredAt: DateTime(2026, 10, 10),
        );

        // Agregamos una categoría personalizada
        final customCatId = '018f0000-0000-7000-8000-999999999999';
        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: customCatId,
                name: 'Personalizada',
                icon: 'tag',
                colorDark: 0xFF123456,
                colorLight: 0xFF654321,
                kind: CategoryKind.expense,
                sortOrder: 99,
              ),
            );

        expect(await db.select(db.transactions).get(), isNotEmpty);
        final categoriesBefore = await db.select(db.categories).get();
        expect(categoriesBefore.length, 15); // 14 de fábrica + 1 personalizada

        // 2. Ejecutamos el borrado
        await db.wipeAllData();

        // 3. Verificamos que las transacciones se eliminaron
        final txsAfter = await db.select(db.transactions).get();
        expect(txsAfter, isEmpty);

        // 4. Verificamos que solo quedaron las 14 categorías de fábrica
        final categoriesAfter = await db.select(db.categories).get();
        expect(categoriesAfter.length, 14);
        expect(categoriesAfter.any((c) => c.id == customCatId), isFalse);
        expect(categoriesAfter.any((c) => c.name == 'Comida'), isTrue);
      },
    );

    testWidgets('ocultar montos muestra •••• y al tocar revela', (t) async {
      await settingsRepo.set(SettingsKeys.privacyHideAmounts, 'true');

      final comida = await (db.select(
        db.categories,
      )..where((c) => c.name.equals('Comida'))).getSingle();

      await txRepo.add(
        type: TxType.expense,
        amount: 85000,
        categoryId: comida.id,
        occurredAt: DateTime(2026, 10, 10),
      );

      await t.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
            transactionsRepositoryProvider.overrideWithValue(txRepo),
            homeHeadlineProvider.overrideWith(
              (ref) => Stream.value(HomeHeadline.monthSpent),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HomeScreen(initialYear: 2026, initialMonth: 10),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      // Monto inicialmente oculto como ••••
      expect(
        find.byKey(const ValueKey('spending-total-obscured')),
        findsOneWidget,
      );
      expect(find.text('••••'), findsOneWidget);

      // Al tocar el total, se revela el monto real
      await t.tap(find.text('••••'));
      await t.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('spending-total-obscured')),
        findsNothing,
      );
      expect(find.text('••••'), findsNothing);
      expect(find.text('Gs. 85.000'), findsOneWidget);
    });

    test('el bloqueo respeta el tiempo elegido', () async {
      final mockAuth = MockLocalAuthentication();
      var currentTime = DateTime(2026, 10, 10, 12, 0, 0);

      final controller = AppLockController(
        auth: mockAuth,
        settings: settingsRepo,
        clock: () => currentTime,
      );

      await controller.init();
      await controller.setLockEnabled(true);
      await controller.setLockAfter(5); // 5 minutos

      // Desbloqueamos inicialmente
      when(
        () => mockAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
        ),
      ).thenAnswer((_) async => true);
      await controller.unlock();
      expect(controller.locked, isFalse);

      // Pausamos la app
      controller.onPaused();

      // Pasaron 3 minutos -> no debe bloquearse
      currentTime = currentTime.add(const Duration(minutes: 3));
      controller.onResumed();
      expect(controller.locked, isFalse);

      // Volvemos a pausar y pasan 5 minutos
      controller.onPaused();
      currentTime = currentTime.add(const Duration(minutes: 5));
      controller.onResumed();
      expect(controller.locked, isTrue);

      // Con tiempo 0 (al instante)
      await controller.setLockAfter(0);
      await controller.unlock();
      expect(controller.locked, isFalse);

      controller.onPaused();
      currentTime = currentTime.add(const Duration(seconds: 1));
      controller.onResumed();
      expect(controller.locked, isTrue);
    });
  });
}
