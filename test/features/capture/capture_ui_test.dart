import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/capture/data/capture_service.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/recurring/ui/inbox_screen.dart';
import 'package:pockt/features/settings/ui/settings_screen.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/transactions/ui/tx_row.dart';

void main() {
  late AppDatabase testDb;
  late FakeNotifier notifier;
  late FakeSmsSource fakeSms;
  late SuggestionsRepository sugRepo;

  const comidaId = '018f0000-0000-7000-8000-000000000001';
  const otrosId = '018f0000-0000-7000-8000-000000000010';

  setUp(() async {
    setLocalZone('America/Asuncion');
    PackageInfo.setMockInitialValues(
      appName: 'Pockt',
      packageName: 'app.pockt',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    testDb = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    notifier = FakeNotifier();
    fakeSms = FakeSmsSource(permissionsGranted: true);
    sugRepo = SuggestionsRepository(testDb);
  });

  tearDown(() async {
    fakeSms.dispose();
    await testDb.close();
  });

  Future<void> pumpInbox(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          notifierProvider.overrideWithValue(notifier),
          smsSourceProvider.overrideWithValue(fakeSms),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const InboxScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'InboxScreen muestra ícono chat-text, Ver mensaje y Confirmar siempre este comercio',
    (tester) async {
      await tester.runAsync(() async {
        await sugRepo.createIfAbsent(
          type: TxType.expense,
          amount: 34500,
          categoryId: comidaId,
          merchant: 'PIZZA HUT-MULTIPLAZA',
          occurredAt: DateTime(2026, 10, 15, 12, 15, 51),
          source: TxSource.capture,
          rawText: 'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****34.500 por PIZZA HUT-MULTIPLAZA al 15/10/2026 12:15:51',
          fingerprint: 'sms:20261015121551:34500',
        );
      });

      await pumpInbox(tester);

      expect(find.text('PIZZA HUT-MULTIPLAZA'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.chatText), findsOneWidget);
      expect(find.text('Ver mensaje'), findsOneWidget);

      // El texto original está plegado al inicio
      expect(
        find.textContaining('Registramos un debito en tu Cuenta ****XXXX'),
        findsNothing,
      );

      // Desplegar "Ver mensaje"
      await tester.tap(find.text('Ver mensaje'));
      await tester.pump();
      expect(
        find.textContaining('Registramos un debito en tu Cuenta ****XXXX'),
        findsOneWidget,
      );

      // Activar "Confirmar siempre este comercio" y confirmar
      await tester.tap(find.text('Confirmar siempre este comercio'));
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text('Confirmar'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final memRows = await tester.runAsync(
        () => testDb.select(testDb.merchantMemory).get(),
      );
      expect(memRows, isNotNull);
      expect(memRows!.any((m) => m.autoConfirm), isTrue);
    },
  );

  testWidgets(
    'InboxScreen muestra Posible duplicado con botones Es el mismo y Es otro',
    (tester) async {
      const manualTxId = 'manual-tx-1';
      await tester.runAsync(() async {
        final now = DateTime(2026, 10, 15, 12, 0);
        await testDb
            .into(testDb.transactions)
            .insert(
              TransactionsCompanion.insert(
                id: manualTxId,
                type: TxType.expense,
                amount: 45000,
                categoryId: comidaId,
                merchant: const Value('PedidosYa manual'),
                occurredAt: now,
                createdAt: now,
                updatedAt: now,
                source: TxSource.manual,
              ),
            );
        await sugRepo.createIfAbsent(
          type: TxType.expense,
          amount: 45000,
          categoryId: comidaId,
          merchant: 'PEDIDOS YA',
          occurredAt: DateTime(2026, 10, 15, 12, 30),
          source: TxSource.capture,
          sourceRef: 'dup:$manualTxId',
          rawText: 'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.*****45.000 por PEDIDOS YA al 15/10/2026 12:30:00',
          fingerprint: 'sms:20261015123000:45000',
        );
      });

      await pumpInbox(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Posible duplicado'), findsOneWidget);
      expect(find.textContaining('PedidosYa manual'), findsOneWidget);
      expect(find.text('Es el mismo'), findsOneWidget);
      expect(find.text('Es otro'), findsOneWidget);

      // Tocar "Es el mismo" descarta la sugerencia y une al movimiento manual sin duplicar
      await tester.runAsync(() async {
        await tester.tap(find.text('Es el mismo'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final txs = await tester.runAsync(
        () => testDb.select(testDb.transactions).get(),
      );
      expect(txs!.length, 1);
      expect(txs.first.id, manualTxId);
      expect(txs.first.suggestionId, isNotNull);
    },
  );

  testWidgets(
    'InboxScreen permite confirmar Posible duplicado con Es otro creando segundo movimiento',
    (tester) async {
      const manualTxId = 'manual-tx-2';
      await tester.runAsync(() async {
        final now = DateTime(2026, 10, 15, 14, 0);
        await testDb
            .into(testDb.transactions)
            .insert(
              TransactionsCompanion.insert(
                id: manualTxId,
                type: TxType.expense,
                amount: 30000,
                categoryId: comidaId,
                merchant: const Value('Café'),
                occurredAt: now,
                createdAt: now,
                updatedAt: now,
                source: TxSource.manual,
              ),
            );
        await sugRepo.createIfAbsent(
          type: TxType.expense,
          amount: 30000,
          categoryId: comidaId,
          merchant: 'BIGGIE-DE LA VICTORIA',
          occurredAt: DateTime(2026, 10, 15, 14, 20),
          source: TxSource.capture,
          sourceRef: 'dup:$manualTxId',
          fingerprint: 'sms:20261015142000:30000',
        );
      });

      await pumpInbox(tester);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.runAsync(() async {
        await tester.tap(find.text('Es otro'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final txs = await tester.runAsync(
        () => testDb.select(testDb.transactions).get(),
      );
      expect(txs!.length, 2);
    },
  );

  testWidgets(
    'Ajustes -> Tu dinero -> Captura automática: apagado por defecto no pide permisos; al encender pide permisos y gestiona comercios automáticos',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await testDb
            .into(testDb.merchantMemory)
            .insert(
              MerchantMemoryCompanion.insert(
                merchantKey: 'pizza hut-multiplaza',
                categoryId: comidaId,
                uses: 2,
                lastUsedAt: DateTime(2026, 10, 15),
                autoConfirm: const Value(true),
              ),
            );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
            notifierProvider.overrideWithValue(notifier),
            smsSourceProvider.overrideWithValue(fakeSms),
          ],
          child: MaterialApp(
            theme: buildDarkTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Tu dinero'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Captura automática'), findsOneWidget);
      await tester.tap(find.text('Captura automática'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Interruptor apagado por defecto: NO pidió permisos al abrir la pantalla
      expect(fakeSms.requestPermissionCalls, 0);
      expect(find.text('Leer SMS de Itaú'), findsOneWidget);
      expect(find.text('15/10/2026'), findsOneWidget);
      expect(find.textContaining('pizza hut-multiplaza'), findsOneWidget);

      // Si se niega el permiso al tocar el interruptor, queda apagado
      fakeSms.permissionsGranted = false;
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('capture-sms-switch')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(fakeSms.requestPermissionCalls, 1);
      final enabledAfterDeny = await tester.runAsync(
        () => SettingsRepository(testDb).get(SettingsKeys.captureSmsEnabled),
      );
      expect(enabledAfterDeny, isNot('true'));

      // Si se concede el permiso, queda activo
      fakeSms.permissionsGranted = true;
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('capture-sms-switch')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(fakeSms.requestPermissionCalls, 2);
      final enabledAfterGrant = await tester.runAsync(
        () => SettingsRepository(testDb).get(SettingsKeys.captureSmsEnabled),
      );
      expect(enabledAfterGrant, 'true');

      // Quitar comercio con confirmación automática
      await tester.runAsync(() async {
        await tester.tap(
          find.byKey(const ValueKey('remove-autoconfirm-pizza hut-multiplaza')),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final memAfter = await tester.runAsync(
        () => testDb.select(testDb.merchantMemory).getSingle(),
      );
      expect(memAfter!.autoConfirm, isFalse);
    },
  );

  testWidgets(
    'TxRow renderiza movimiento de tipo transferencia con estilo neutro',
    (tester) async {
      final cat = await tester.runAsync(
        () => (testDb.select(
          testDb.categories,
        )..where((c) => c.id.equals(otrosId))).getSingle(),
      );
      final now = DateTime(2026, 10, 15, 16, 0);
      final tx = Transaction(
        id: 'tx-transfer-1',
        type: TxType.transfer,
        amount: 950000,
        currency: 'PYG',
        categoryId: otrosId,
        merchant: 'Bancop Pago de tarjeta con cedula',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        source: TxSource.capture,
        isExtra: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(testDb)],
          child: MaterialApp(
            theme: buildDarkTheme(),
            home: Scaffold(
              body: TxRow(
                view: TxView(tx: tx, category: cat!),
                subtitle: 'Transferencia · 16:00',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final amountText = tester.widget<Text>(find.text('950.000'));
      expect(amountText.style?.color, PocktColors.dark.textSecondary);
      expect(find.byIcon(PhosphorIconsFill.arrowsLeftRight), findsOneWidget);
    },
  );

  testWidgets(
    'InboxScreen muestra pago de tarjeta como transferencia neutra y la confirma con un toque',
    (tester) async {
      await tester.runAsync(() async {
        await sugRepo.createIfAbsent(
          type: TxType.transfer,
          amount: 1200000,
          categoryId: otrosId,
          merchant: 'Bancop Pago de tarjeta con cedula',
          occurredAt: DateTime(2026, 10, 15, 17, 0),
          source: TxSource.capture,
          rawText: 'Itau informa: Registramos un debito en tu Cuenta ****XXXX de Gs.**1.200.000 por Bancop Pago de tarjeta con cedula al 15/10/2026 17:00:00',
          fingerprint: 'sms:20261015170000:1200000',
        );
      });

      await pumpInbox(tester);

      expect(
        find.textContaining('Transferencia · No suma en gastos'),
        findsOneWidget,
      );
      expect(find.byIcon(PhosphorIconsFill.arrowsLeftRight), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Confirmar'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final txs = await tester.runAsync(
        () => testDb.select(testDb.transactions).get(),
      );
      expect(txs!.length, 1);
      expect(txs.first.type, TxType.transfer);
      expect(txs.first.amount, 1200000);
    },
  );
}
