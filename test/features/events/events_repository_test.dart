import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/events/data/events_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionsRepository txRepo;
  late EventsRepository eventsRepo;
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
    eventsRepo = EventsRepository(db);

    final cats = await db.select(db.categories).get();
    comidaId = cats.firstWhere((c) => c.name == 'Comida').id;
    transporteId = cats.firstWhere((c) => c.name == 'Transporte').id;
  });

  tearDown(() async {
    await db.close();
  });

  test('crear evento y listar', () async {
    final id = await eventsRepo.createEvent(
      name: 'Viaje a Encarnación',
      icon: 'airplane',
      startDate: DateTime(2026, 10, 20),
    );

    final list = await eventsRepo.watchEvents().first;
    expect(list.length, equals(1));
    expect(list.first.id, equals(id));
    expect(list.first.name, equals('Viaje a Encarnación'));
    expect(list.first.isActive, isFalse);
  });

  test(
    'marcar activo asigna automáticamente gastos nuevos al evento',
    () async {
      final eventId = await eventsRepo.createEvent(
        name: 'Cumpleaños',
        icon: 'cake',
        startDate: DateTime(2026, 10, 15),
        isActive: true,
      );

      final active = await eventsRepo.getActiveEvent();
      expect(active?.id, equals(eventId));

      // Crear un gasto normal
      final txId = await txRepo.add(
        type: TxType.expense,
        amount: 85000,
        categoryId: comidaId,
        merchant: 'Torta',
        occurredAt: DateTime(2026, 10, 15, 14, 0),
      );

      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      expect(tx.eventId, equals(eventId));
    },
  );

  test('solo un evento puede estar activo a la vez', () async {
    final ev1 = await eventsRepo.createEvent(
      name: 'Evento 1',
      icon: 'beer-bottle',
      startDate: DateTime(2026, 10, 15),
      isActive: true,
    );
    final ev2 = await eventsRepo.createEvent(
      name: 'Evento 2',
      icon: 'confetti',
      startDate: DateTime(2026, 10, 16),
      isActive: true,
    );

    final active = await eventsRepo.getActiveEvent();
    expect(active?.id, equals(ev2));

    final list = await eventsRepo.watchEvents().first;
    final row1 = list.firstWhere((e) => e.id == ev1);
    final row2 = list.firstWhere((e) => e.id == ev2);
    expect(row1.isActive, isFalse);
    expect(row2.isActive, isTrue);
  });

  test('watchEventDetail calcula total y desglose por categoría', () async {
    final eventId = await eventsRepo.createEvent(
      name: 'Asado',
      icon: 'beer-bottle',
      startDate: DateTime(2026, 10, 15),
      isActive: true,
    );

    // 2 gastos en comida
    await txRepo.add(
      type: TxType.expense,
      amount: 120000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 15),
    );
    await txRepo.add(
      type: TxType.expense,
      amount: 80000,
      categoryId: comidaId,
      occurredAt: DateTime(2026, 10, 15),
    );
    // 1 gasto en transporte
    await txRepo.add(
      type: TxType.expense,
      amount: 50000,
      categoryId: transporteId,
      occurredAt: DateTime(2026, 10, 15),
    );

    final detail = await eventsRepo.watchEventDetail(eventId).first;
    expect(detail.total, equals(250000));
    expect(detail.count, equals(3));
    expect(detail.categoryBreakdown.length, equals(2));

    final comidaBreakdown = detail.categoryBreakdown.firstWhere(
      (b) => b.category.id == comidaId,
    );
    expect(comidaBreakdown.total, equals(200000));
    expect(comidaBreakdown.count, equals(2));
    expect(comidaBreakdown.percentage, equals(80.0));
  });
}
