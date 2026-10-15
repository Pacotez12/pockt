import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/reports/domain/weekly_summary.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionsRepository txRepo;
  late SettingsRepository settingsRepo;
  late FakeNotifier notifier;
  late String comidaId;
  late String transporteId;

  setUp(() async {
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    txRepo = TransactionsRepository(db);
    settingsRepo = SettingsRepository(db);
    notifier = FakeNotifier();

    final cats = await db.select(db.categories).get();
    comidaId = cats.firstWhere((c) => c.name == 'Comida').id;
    transporteId = cats.firstWhere((c) => c.name == 'Transporte').id;
  });

  tearDown(() async {
    await db.close();
  });

  group('calculateWeeklySummary & text', () {
    test(
      'calcula total de la semana, variación porcentual y categoría principal',
      () {
        final catComida = Category(
          id: comidaId,
          name: 'Comida',
          icon: 'fork-knife',
          colorDark: 0xFFFFAA00,
          colorLight: 0xFFFF8800,
          kind: CategoryKind.expense,
          sortOrder: 0,
          archived: false,
        );
        final catTransporte = Category(
          id: transporteId,
          name: 'Transporte',
          icon: 'bus',
          colorDark: 0xFF00AAFF,
          colorLight: 0xFF0088DD,
          kind: CategoryKind.expense,
          sortOrder: 1,
          archived: false,
        );

        final now = DateTime(2026, 10, 18, 12, 0); // Domingo

        final currentWeekTxs = [
          TxView(
            tx: Transaction(
              id: '1',
              type: TxType.expense,
              amount: 120000,
              currency: 'PYG',
              categoryId: comidaId,
              occurredAt: DateTime(2026, 10, 13, 12, 0),
              createdAt: now,
              updatedAt: now,
              source: TxSource.manual,
              isExtra: false,
            ),
            category: catComida,
          ),
          TxView(
            tx: Transaction(
              id: '2',
              type: TxType.expense,
              amount: 80000,
              currency: 'PYG',
              categoryId: transporteId,
              occurredAt: DateTime(2026, 10, 15, 12, 0),
              createdAt: now,
              updatedAt: now,
              source: TxSource.manual,
              isExtra: false,
            ),
            category: catTransporte,
          ),
        ];

        final previousWeekTxs = [
          TxView(
            tx: Transaction(
              id: '3',
              type: TxType.expense,
              amount: 160000,
              currency: 'PYG',
              categoryId: comidaId,
              occurredAt: DateTime(2026, 10, 6, 12, 0),
              createdAt: now,
              updatedAt: now,
              source: TxSource.manual,
              isExtra: false,
            ),
            category: catComida,
          ),
        ];

        final summary = calculateWeeklySummary(
          currentWeekTxs: currentWeekTxs,
          previousWeekTxs: previousWeekTxs,
          weekStart: DateTime(2026, 10, 12),
          weekEnd: DateTime(2026, 10, 18),
        );

        // Total actual: 120.000 + 80.000 = 200.000
        // Total anterior: 160.000
        // Variación: (200.000 - 160.000) / 160.000 = +25%
        expect(summary.currentWeekTotal, equals(200000));
        expect(summary.previousWeekTotal, equals(160000));
        expect(summary.percentageDiff, equals(25));
        expect(summary.topCategoryName, equals('Comida'));

        final text = buildWeeklySummaryNotificationBody(summary);
        expect(text, contains('Gs. 200.000'));
        expect(text, contains('+25%'));
        expect(text, contains('Comida'));
      },
    );

    test('texto amigable cuando no hubo gastos en la semana', () {
      final summary = calculateWeeklySummary(
        currentWeekTxs: [],
        previousWeekTxs: [],
        weekStart: DateTime(2026, 10, 12),
        weekEnd: DateTime(2026, 10, 18),
      );

      final text = buildWeeklySummaryNotificationBody(summary);
      expect(text, contains('Sin gastos'));
    });
  });

  group('nextSundayAt19 & quiet hours', () {
    test('un miércoles calcula el próximo domingo a las 19:00', () {
      final wednesday = DateTime(2026, 10, 14, 10, 0); // Miércoles
      final scheduled = nextSundayAt19(wednesday);

      expect(scheduled.weekday, equals(DateTime.sunday));
      expect(scheduled.day, equals(18));
      expect(scheduled.hour, equals(19));
      expect(scheduled.minute, equals(0));
    });

    test('un domingo antes de las 19:00 programa para hoy', () {
      final sundayMorning = DateTime(2026, 10, 18, 10, 0);
      final scheduled = nextSundayAt19(sundayMorning);

      expect(scheduled.day, equals(18));
      expect(scheduled.hour, equals(19));
    });

    test(
      'un domingo después de las 19:00 programa para el domingo siguiente',
      () {
        final sundayNight = DateTime(2026, 10, 18, 20, 0);
        final scheduled = nextSundayAt19(sundayNight);

        expect(scheduled.day, equals(25));
        expect(scheduled.hour, equals(19));
      },
    );

    test('si las 19:00 caen en silencio se ajusta al fin del silencio', () {
      final wednesday = DateTime(2026, 10, 14, 10, 0);
      final scheduled = nextSundayAt19(
        wednesday,
        quietStart: (h: 18, m: 0),
        quietEnd: (h: 20, m: 0),
      );

      expect(scheduled.hour, equals(20));
      expect(scheduled.minute, equals(0));
    });
  });

  group('scheduleWeeklySummary integration', () {
    test('programa notificación con payload reports para el domingo', () async {
      final now = DateTime(2026, 10, 16, 12, 0); // Viernes

      // Cargar gastos en la semana
      await txRepo.add(
        type: TxType.expense,
        amount: 150000,
        categoryId: comidaId,
        occurredAt: DateTime(2026, 10, 14, 12, 0),
      );

      await scheduleWeeklySummary(
        db: db,
        notifier: notifier,
        settingsRepo: settingsRepo,
        nowLocal: now,
      );

      expect(notifier.scheduled.length, equals(1));
      final item = notifier.scheduled.first;
      expect(item.title, equals('Resumen semanal'));
      expect(item.body, contains('Gs. 150.000'));
      expect(item.atLocal.weekday, equals(DateTime.sunday));
      expect(item.payload, equals('reports'));
    });

    test(
      'si weeklySummary está deshabilitado en ajustes no programa',
      () async {
        await settingsRepo.set(SettingsKeys.weeklySummaryEnabled, 'false');

        final now = DateTime(2026, 10, 16, 12, 0);
        await scheduleWeeklySummary(
          db: db,
          notifier: notifier,
          settingsRepo: settingsRepo,
          nowLocal: now,
        );

        expect(notifier.scheduled, isEmpty);
      },
    );
  });
}
