import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:uuid/uuid.dart';

class EventCategoryBreakdown {
  final Category category;
  final int total;
  final int count;
  final double percentage;

  const EventCategoryBreakdown({
    required this.category,
    required this.total,
    required this.count,
    required this.percentage,
  });
}

class EventDetail {
  final Event event;
  final int total;
  final int count;
  final List<EventCategoryBreakdown> categoryBreakdown;
  final List<TxView> transactions;

  const EventDetail({
    required this.event,
    required this.total,
    required this.count,
    required this.categoryBreakdown,
    required this.transactions,
  });
}

class EventsRepository {
  final AppDatabase db;

  EventsRepository(this.db);

  Stream<List<Event>> watchEvents() {
    final query = db.select(db.events)
      ..orderBy([
        (t) => OrderingTerm.desc(t.isActive),
        (t) => OrderingTerm.desc(t.startDate),
      ]);
    return query.watch();
  }

  Stream<Event?> watchActiveEvent() {
    final query = db.select(db.events)..where((e) => e.isActive.equals(true));
    return query.watchSingleOrNull();
  }

  Future<Event?> getActiveEvent() {
    final query = db.select(db.events)..where((e) => e.isActive.equals(true));
    return query.getSingleOrNull();
  }

  Future<String> createEvent({
    required String name,
    required String icon,
    required DateTime startDate,
    DateTime? endDate,
    bool isActive = false,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    await db.transaction(() async {
      if (isActive) {
        await (db.update(db.events)..where((e) => e.isActive.equals(true)))
            .write(const EventsCompanion(isActive: Value(false)));
      }

      await db
          .into(db.events)
          .insert(
            EventsCompanion.insert(
              id: id,
              name: name,
              icon: icon,
              startDate: startDate,
              endDate: Value(endDate),
              isActive: Value(isActive),
              createdAt: now,
            ),
          );
    });

    return id;
  }

  Future<void> setActive(String id, bool active) async {
    await db.transaction(() async {
      if (active) {
        await (db.update(db.events)..where((e) => e.isActive.equals(true)))
            .write(const EventsCompanion(isActive: Value(false)));
      }
      await (db.update(db.events)..where((e) => e.id.equals(id))).write(
        EventsCompanion(isActive: Value(active)),
      );
    });
  }

  Future<void> updateEvent(
    String id, {
    String? name,
    String? icon,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async {
    final companion = EventsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      icon: icon != null ? Value(icon) : const Value.absent(),
      startDate: startDate != null ? Value(startDate) : const Value.absent(),
      endDate: clearEndDate
          ? const Value(null)
          : endDate != null
          ? Value(endDate)
          : const Value.absent(),
    );
    await (db.update(
      db.events,
    )..where((e) => e.id.equals(id))).write(companion);
  }

  Future<void> deleteEvent(String id) async {
    await db.transaction(() async {
      // Desvincular transacciones del evento
      await (db.update(db.transactions)..where((t) => t.eventId.equals(id)))
          .write(const TransactionsCompanion(eventId: Value(null)));
      await (db.delete(db.events)..where((e) => e.id.equals(id))).go();
    });
  }

  Stream<EventDetail> watchEventDetail(String eventId) {
    final eventQuery = db.select(db.events)..where((e) => e.id.equals(eventId));
    final txQuery =
        db.select(db.transactions).join([
            innerJoin(
              db.categories,
              db.categories.id.equalsExp(db.transactions.categoryId),
            ),
          ])
          ..where(
            db.transactions.deletedAt.isNull() &
                db.transactions.eventId.equals(eventId),
          )
          ..orderBy([OrderingTerm.desc(db.transactions.occurredAt)]);

    return eventQuery.watchSingle().asyncMap((event) async {
      final rows = await txQuery.get();
      final txs = rows
          .map(
            (r) => TxView(
              tx: r.readTable(db.transactions),
              category: r.readTable(db.categories),
            ),
          )
          .toList();

      var grandTotal = 0;
      final Map<String, ({Category category, int total, int count})> catMap =
          {};

      for (final item in txs) {
        if (item.tx.type == TxType.expense) {
          grandTotal += item.tx.amount;
          final current = catMap[item.category.id];
          if (current == null) {
            catMap[item.category.id] = (
              category: item.category,
              total: item.tx.amount,
              count: 1,
            );
          } else {
            catMap[item.category.id] = (
              category: item.category,
              total: current.total + item.tx.amount,
              count: current.count + 1,
            );
          }
        }
      }

      final breakdown = catMap.values.map((v) {
        final pct = grandTotal > 0 ? (v.total / grandTotal) * 100 : 0.0;
        return EventCategoryBreakdown(
          category: v.category,
          total: v.total,
          count: v.count,
          percentage: pct,
        );
      }).toList();

      breakdown.sort((a, b) => b.total.compareTo(a.total));

      return EventDetail(
        event: event,
        total: grandTotal,
        count: txs.length,
        categoryBreakdown: breakdown,
        transactions: txs,
      );
    });
  }
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(ref.watch(databaseProvider));
});

final activeEventProvider = StreamProvider<Event?>((ref) {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.watchActiveEvent();
});
