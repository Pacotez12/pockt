import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/features/goals/domain/goal_progress.dart';
import 'package:uuid/uuid.dart';

class GoalWithProgress {
  final Goal goal;
  final GoalProgress progress;
  final List<GoalContribution> contributions;

  const GoalWithProgress({
    required this.goal,
    required this.progress,
    this.contributions = const [],
  });
}

class GoalsRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  GoalsRepository(this._db);

  Future<String> createGoal({
    required String name,
    required String icon,
    required int targetAmount,
    DateTime? targetDate,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db
        .into(_db.goals)
        .insert(
          GoalsCompanion.insert(
            id: id,
            name: name,
            icon: icon,
            targetAmount: targetAmount,
            targetDate: Value(targetDate),
            createdAt: now,
          ),
        );
    return id;
  }

  Future<void> updateGoal({
    required String id,
    required String name,
    required String icon,
    required int targetAmount,
    DateTime? targetDate,
  }) async {
    await (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
      GoalsCompanion(
        name: Value(name),
        icon: Value(icon),
        targetAmount: Value(targetAmount),
        targetDate: Value(targetDate),
      ),
    );
  }

  Future<void> archiveGoal(String id, {bool archived = true}) async {
    await (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
      GoalsCompanion(archived: Value(archived)),
    );
  }

  Future<void> deleteGoal(String id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.goalContributions,
      )..where((c) => c.goalId.equals(id))).go();
      await (_db.delete(_db.goals)..where((g) => g.id.equals(id))).go();
    });
  }

  Future<String> addContribution({
    required String goalId,
    required int amount,
    required DateTime date,
    String? note,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db
        .into(_db.goalContributions)
        .insert(
          GoalContributionsCompanion.insert(
            id: id,
            goalId: goalId,
            amount: amount,
            date: date,
            note: Value(note),
            createdAt: now,
          ),
        );
    return id;
  }

  Future<void> deleteContribution(String contributionId) async {
    await (_db.delete(
      _db.goalContributions,
    )..where((c) => c.id.equals(contributionId))).go();
  }

  Future<Goal?> getGoal(String id) async {
    return (_db.select(
      _db.goals,
    )..where((g) => g.id.equals(id))).getSingleOrNull();
  }

  Stream<List<Goal>> watchActive() {
    return (_db.select(_db.goals)
          ..where((g) => g.archived.equals(false))
          ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]))
        .watch();
  }

  Stream<List<Goal>> watchArchived() {
    return (_db.select(_db.goals)
          ..where((g) => g.archived.equals(true))
          ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
        .watch();
  }

  Stream<List<GoalContribution>> watchContributions(String goalId) {
    return (_db.select(_db.goalContributions)
          ..where((c) => c.goalId.equals(goalId))
          ..orderBy([(c) => OrderingTerm.desc(c.date)]))
        .watch();
  }

  Stream<List<GoalWithProgress>> watchActiveWithProgress({DateTime? now}) {
    // Escucha cambios tanto en goals como en goalContributions
    return _db.select(_db.goals).watch().asyncMap((_) async {
      final active =
          await (_db.select(_db.goals)
                ..where((g) => g.archived.equals(false))
                ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]))
              .get();

      final allContributions = await _db.select(_db.goalContributions).get();
      final contribsByGoal = <String, List<GoalContribution>>{};
      for (final c in allContributions) {
        contribsByGoal.putIfAbsent(c.goalId, () => []).add(c);
      }

      return active.map((goal) {
        final contribs = contribsByGoal[goal.id] ?? const [];
        final progress = calculateGoalProgress(
          goal: goal,
          contributions: contribs,
          now: now,
        );
        return GoalWithProgress(
          goal: goal,
          progress: progress,
          contributions: contribs,
        );
      }).toList();
    });
  }

  /// Calcula el total neto aportado (aportes - retiros) desde [since].
  Future<int> getContributionsTotalSince(DateTime since) async {
    final query = _db.select(_db.goalContributions)
      ..where((c) => c.date.isBiggerOrEqualValue(since));
    final rows = await query.get();
    return rows.fold<int>(0, (sum, c) => sum + c.amount);
  }

  /// Vigila el total neto aportado desde [since].
  Stream<int> watchContributionsTotalSince(DateTime since) {
    final query = _db.select(_db.goalContributions)
      ..where((c) => c.date.isBiggerOrEqualValue(since));
    return query.watch().map((rows) {
      return rows.fold<int>(0, (sum, c) => sum + c.amount);
    });
  }
}

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return GoalsRepository(db);
});

final activeGoalsWithProgressProvider = StreamProvider<List<GoalWithProgress>>((
  ref,
) {
  final repo = ref.watch(goalsRepositoryProvider);
  return repo.watchActiveWithProgress();
});
