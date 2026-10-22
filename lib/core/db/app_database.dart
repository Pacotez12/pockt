import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';
import 'package:pockt/features/income/domain/salary_deduction.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    Transactions,
    SuggestedTransactions,
    RecurringRules,
    IncomeSchedules,
    Budgets,
    DayMarks,
    Settings,
    CategoryKeywords,
    MerchantMemory,
    SalaryDeductions,
    Loans,
    LoanInstallments,
    Goals,
    GoalContributions,
    EntryShortcuts,
    Events,
    CounterpartyRules,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _seedCategories();
        await _seedCategoryKeywords();
        // Instalaciones nuevas: el mismo índice único que crea la migración v3.
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_suggested_transactions_source_source_ref_occurred_at '
          'ON suggested_transactions (source, source_ref, occurred_at);',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_suggested_transactions_fingerprint '
          'ON suggested_transactions (fingerprint);',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_counterparty_rules_name_direction '
          'ON counterparty_rules (name_key, direction);',
        );
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(categoryKeywords);
          await m.createTable(merchantMemory);
          await _seedCategoryKeywords();
          await _preloadMerchantMemory();
        }
        if (from < 3) {
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_suggested_transactions_source_source_ref_occurred_at '
            'ON suggested_transactions (source, source_ref, occurred_at);',
          );
        }
        if (from < 4) {
          await customStatement('''
            CREATE TABLE income_schedules_new (
              id TEXT NOT NULL PRIMARY KEY,
              mode TEXT NOT NULL,
              pay_days TEXT NOT NULL,
              pay_day_rules TEXT NOT NULL,
              expected_amount INTEGER,
              category_id TEXT NOT NULL REFERENCES categories(id),
              effective_from INTEGER NOT NULL
            );
          ''');

          final rows = await customSelect(
            'SELECT id, mode, pay_days, expected_amount, category_id, effective_from FROM income_schedules;',
          ).get();

          for (final row in rows) {
            final id = row.read<String>('id');
            final mode = row.read<String>('mode');
            final payDaysStr = row.read<String>('pay_days');
            final expectedAmount = row.readNullable<int>('expected_amount');
            final categoryId = row.read<String>('category_id');
            final effectiveFromRaw = row.data['effective_from'];

            final payDaysList = (jsonDecode(payDaysStr) as List)
                .map((e) => (e as num).toInt())
                .toList();
            final rulesList = payDaysList
                .map((d) => d == -1 ? 'previous' : 'either')
                .toList();
            final rulesStr = jsonEncode(rulesList);

            await customStatement(
              'INSERT INTO income_schedules_new (id, mode, pay_days, pay_day_rules, expected_amount, category_id, effective_from) '
              'VALUES (?, ?, ?, ?, ?, ?, ?);',
              [
                id,
                mode,
                payDaysStr,
                rulesStr,
                expectedAmount,
                categoryId,
                effectiveFromRaw,
              ],
            );
          }

          await customStatement('DROP TABLE income_schedules;');
          await customStatement(
            'ALTER TABLE income_schedules_new RENAME TO income_schedules;',
          );
        }
        if (from < 5) {
          await customStatement('''
            CREATE TABLE income_schedules_new (
              id TEXT NOT NULL PRIMARY KEY,
              mode TEXT NOT NULL,
              pay_days TEXT NOT NULL,
              pay_day_rules TEXT NOT NULL,
              monthly_amount INTEGER,
              pay_split_percents TEXT NOT NULL,
              category_id TEXT NOT NULL REFERENCES categories(id),
              effective_from INTEGER NOT NULL
            );
          ''');

          final rows = await customSelect(
            'SELECT id, mode, pay_days, pay_day_rules, expected_amount, category_id, effective_from FROM income_schedules;',
          ).get();

          for (final row in rows) {
            final id = row.read<String>('id');
            final mode = row.read<String>('mode');
            final payDaysStr = row.read<String>('pay_days');
            final payDayRulesStr = row.read<String>('pay_day_rules');
            final expectedAmount = row.readNullable<int>('expected_amount');
            final categoryId = row.read<String>('category_id');
            final effectiveFromRaw = row.data['effective_from'];

            final payDaysList = (jsonDecode(payDaysStr) as List)
                .map((e) => (e as num).toInt())
                .toList();
            final count = payDaysList.length;

            final int? monthlyAmount = (expectedAmount != null)
                ? expectedAmount * count
                : null;

            final List<int> splits;
            if (count == 2) {
              splits = const [50, 50];
            } else if (count == 1) {
              splits = const [100];
            } else if (count > 2) {
              final each = 100 ~/ count;
              splits = List.filled(count, each);
              splits[count - 1] = 100 - (each * (count - 1));
            } else {
              splits = const [100];
            }
            final paySplitPercentsStr = jsonEncode(splits);

            await customStatement(
              'INSERT INTO income_schedules_new (id, mode, pay_days, pay_day_rules, monthly_amount, pay_split_percents, category_id, effective_from) '
              'VALUES (?, ?, ?, ?, ?, ?, ?, ?);',
              [
                id,
                mode,
                payDaysStr,
                payDayRulesStr,
                monthlyAmount,
                paySplitPercentsStr,
                categoryId,
                effectiveFromRaw,
              ],
            );
          }

          await customStatement('DROP TABLE income_schedules;');
          await customStatement(
            'ALTER TABLE income_schedules_new RENAME TO income_schedules;',
          );
        }
        if (from < 6) {
          await m.createTable(salaryDeductions);
        }
        if (from < 7) {
          for (final update in _kFactoryCategoryColorUpdates) {
            await customStatement(
              'UPDATE categories SET color_dark = ?, color_light = ? '
              'WHERE id = ? AND color_dark = ? AND color_light = ?;',
              [
                update.newDark,
                update.newLight,
                update.id,
                update.oldDark,
                update.oldLight,
              ],
            );
          }
        }
        if (from < 8) {
          await m.createTable(loans);
          await m.addColumn(transactions, transactions.loanId);
          final existing = await customSelect(
            'SELECT id FROM categories WHERE name = ? LIMIT 1;',
            variables: [Variable.withString('Préstamos')],
          ).get();
          if (existing.isEmpty) {
            await into(categories).insert(
              const CategoriesCompanion(
                id: Value('018f0000-0000-7000-8000-000000000014'),
                name: Value('Préstamos'),
                icon: Value('coins'),
                colorDark: Value(0xFF8BA4B5),
                colorLight: Value(0xFF3D6176),
                kind: Value(CategoryKind.expense),
                sortOrder: Value(10),
              ),
            );
          }
        }
        if (from < 9) {
          await m.addColumn(transactions, transactions.isExtra);
          // Pagos extra viejos: los marcaba la nota. Solo los ligados a un préstamo.
          await customStatement(
            'UPDATE transactions SET is_extra = 1 '
            'WHERE loan_id IS NOT NULL '
            "AND (LOWER(note) LIKE '%extra%' OR LOWER(note) LIKE '%adelanto%');",
          );
          // Préstamos tenía un color casi igual a Otros: tono propio, solo si
          // conserva el color de fábrica (no pisa uno elegido por el usuario).
          await customStatement(
            'UPDATE categories SET color_dark = ?, color_light = ? '
            'WHERE id = ? AND color_dark = ? AND color_light = ?;',
            [
              _kPrestamosDark,
              _kPrestamosLight,
              _kPrestamosId,
              _kPrestamosOldDark,
              _kPrestamosOldLight,
            ],
          );
        }
        if (from < 10) {
          await m.createTable(goals);
          await m.createTable(goalContributions);
        }
        if (from < 11) {
          await m.createTable(entryShortcuts);
          await m.createTable(events);
          await m.addColumn(transactions, transactions.eventId);
        }
        if (from < 12) {
          final hasMerchantMemory = (await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='merchant_memory';",
          ).get()).isNotEmpty;
          if (hasMerchantMemory) {
            final cols = await customSelect(
              'PRAGMA table_info(merchant_memory);',
            ).get();
            final hasAutoConfirm = cols.any(
              (r) => r.read<String>('name') == 'auto_confirm',
            );
            if (!hasAutoConfirm) {
              await m.addColumn(merchantMemory, merchantMemory.autoConfirm);
            }
          } else {
            await m.createTable(merchantMemory);
          }

          final hasSuggested = (await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='suggested_transactions';",
          ).get()).isNotEmpty;
          if (hasSuggested) {
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_suggested_transactions_fingerprint '
              'ON suggested_transactions (fingerprint);',
            );
          }
        }
        if (from < 13) {
          final hasCategories = (await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='categories';",
          ).get()).isNotEmpty;

          if (hasCategories) {
            final existing = await customSelect(
              'SELECT id FROM categories WHERE name = ? LIMIT 1;',
              variables: [Variable.withString('Tarjetas')],
            ).get();

            String tarjetasId = _kTarjetasId;
            if (existing.isEmpty) {
              await into(categories).insert(
                const CategoriesCompanion(
                  id: Value(_kTarjetasId),
                  name: Value('Tarjetas'),
                  icon: Value('credit-card'),
                  colorDark: Value(_kTarjetasDark),
                  colorLight: Value(_kTarjetasLight),
                  kind: Value(CategoryKind.expense),
                  sortOrder: Value(11),
                ),
              );
            } else {
              tarjetasId = existing.first.read<String>('id');
            }

            final hasCategoryKeywords = (await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='category_keywords';",
            ).get()).isNotEmpty;

            if (hasCategoryKeywords) {
              final keywords = kSeedCategoryKeywords['Tarjetas'] ?? [];
              if (keywords.isNotEmpty) {
                const uuid = Uuid();
                final existingKws = (await customSelect(
                  'SELECT keyword FROM category_keywords WHERE category_id = ?;',
                  variables: [Variable.withString(tarjetasId)],
                ).get()).map((r) => r.read<String>('keyword')).toSet();

                final companionList = <CategoryKeywordsCompanion>[];
                for (final kw in keywords) {
                  final norm = normalizeKeyword(kw);
                  if (norm.isNotEmpty && !existingKws.contains(norm)) {
                    companionList.add(
                      CategoryKeywordsCompanion.insert(
                        id: uuid.v4(),
                        categoryId: tarjetasId,
                        keyword: norm,
                        source: KeywordSource.seed,
                      ),
                    );
                    existingKws.add(norm);
                  }
                }
                if (companionList.isNotEmpty) {
                  await batch((b) {
                    b.insertAll(categoryKeywords, companionList);
                  });
                }
              }
            }

            final hasTransactions = (await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='transactions';",
            ).get()).isNotEmpty;
            if (hasTransactions) {
              await customStatement(
                'UPDATE transactions SET type = ?, category_id = ? WHERE type = ?;',
                ['expense', tarjetasId, 'transfer'],
              );
            }

            final hasSuggested = (await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='suggested_transactions';",
            ).get()).isNotEmpty;
            if (hasSuggested) {
              await customStatement(
                'UPDATE suggested_transactions SET type = ?, category_id = ? WHERE type = ?;',
                ['expense', tarjetasId, 'transfer'],
              );
            }
          }
        }
        if (from < 14) {
          final hasCounterpartyRules = (await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='counterparty_rules';",
          ).get()).isNotEmpty;
          if (!hasCounterpartyRules) {
            await m.createTable(counterpartyRules);
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_counterparty_rules_name_direction '
              'ON counterparty_rules (name_key, direction);',
            );
          }

          final hasSuggested = (await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='suggested_transactions';",
          ).get()).isNotEmpty;
          if (hasSuggested) {
            final hasCaptureMeta = (await customSelect(
              "SELECT name FROM pragma_table_info('suggested_transactions') WHERE name = 'capture_meta';",
            ).get()).isNotEmpty;
            if (!hasCaptureMeta) {
              await m.addColumn(
                suggestedTransactions,
                suggestedTransactions.captureMeta,
              );
            }
          }
        }
        if (from < 15) {
          final hasLoanInstallments = (await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='loan_installments';",
          ).get()).isNotEmpty;
          if (!hasLoanInstallments) {
            await m.createTable(loanInstallments);
          }
        }
        if (from < 16) {
          final hasPaidBefore = (await customSelect(
            "SELECT name FROM pragma_table_info('loans') WHERE name = 'paid_before_count';",
          ).get()).isNotEmpty;
          if (!hasPaidBefore) {
            await m.addColumn(loans, loans.paidBeforeCount);
          }
        }
      },
    );
  }

  Future<void> _seedCategoryKeywords() async {
    final cats = await select(categories).get();
    final companionList = <CategoryKeywordsCompanion>[];
    const uuid = Uuid();

    for (final cat in cats) {
      final list = kSeedCategoryKeywords[cat.name];
      if (list != null) {
        final seen = <String>{};
        for (final kw in list) {
          final norm = normalizeKeyword(kw);
          if (norm.isNotEmpty && seen.add(norm)) {
            companionList.add(
              CategoryKeywordsCompanion.insert(
                id: uuid.v4(),
                categoryId: cat.id,
                keyword: norm,
                source: KeywordSource.seed,
              ),
            );
          }
        }
      }
    }

    if (companionList.isNotEmpty) {
      await batch((b) {
        b.insertAll(categoryKeywords, companionList);
      });
    }
  }

  Future<void> _preloadMerchantMemory() async {
    // Solo las columnas que existen desde la v1: esta migración corre antes de
    // que se agreguen las columnas nuevas (loan_id, is_extra, ...).
    final rows =
        await (selectOnly(transactions)
              ..addColumns([
                transactions.merchant,
                transactions.categoryId,
                transactions.occurredAt,
              ])
              ..where(
                transactions.merchant.isNotNull() &
                    transactions.deletedAt.isNull(),
              ))
            .get();

    final counts = <(String, String), ({int uses, DateTime lastUsedAt})>{};

    for (final row in rows) {
      final m = row.read(transactions.merchant)?.trim();
      if (m == null || m.isEmpty) continue;
      final norm = normalizeKeyword(m);
      if (norm.isEmpty) continue;

      final categoryId = row.read(transactions.categoryId)!;
      final occurredAt = row.read(transactions.occurredAt)!;
      final pair = (norm, categoryId);
      final current = counts[pair];
      if (current == null) {
        counts[pair] = (uses: 1, lastUsedAt: occurredAt);
      } else {
        final newest = occurredAt.isAfter(current.lastUsedAt)
            ? occurredAt
            : current.lastUsedAt;
        counts[pair] = (uses: current.uses + 1, lastUsedAt: newest);
      }
    }

    if (counts.isNotEmpty) {
      final companions = counts.entries.map((e) {
        return MerchantMemoryCompanion.insert(
          merchantKey: e.key.$1,
          categoryId: e.key.$2,
          uses: e.value.uses,
          lastUsedAt: e.value.lastUsedAt,
        );
      }).toList();

      await batch((b) {
        b.insertAll(merchantMemory, companions);
      });
    }
  }

  /// Borra todos los datos del usuario y restaura las categorías de fábrica.
  Future<void> wipeAllData() async {
    await transaction(() async {
      await delete(transactions).go();
      await delete(loanInstallments).go();
      await delete(loans).go();
      await delete(goalContributions).go();
      await delete(goals).go();
      await delete(entryShortcuts).go();
      await delete(events).go();
      await delete(suggestedTransactions).go();
      await delete(merchantMemory).go();
      await delete(budgets).go();
      await delete(salaryDeductions).go();
      await delete(incomeSchedules).go();
      await delete(recurringRules).go();
      await delete(dayMarks).go();
      await delete(categoryKeywords).go();
      await delete(categories).go();
      await delete(settings).go();

      await _seedCategories();
      await _seedCategoryKeywords();
    });
  }

  Future<void> _seedCategories() async {
    final seed = <CategoriesCompanion>[
      // 10 categorías de gasto
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000001'),
        name: Value('Comida'),
        icon: Value('fork-knife'),
        colorDark: Value(0xFFE4A067),
        colorLight: Value(0xFF9A5505),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(0),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000002'),
        name: Value('Transporte'),
        icon: Value('car-profile'),
        colorDark: Value(0xFF6BBAF0),
        colorLight: Value(0xFF0070A6),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(1),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000003'),
        name: Value('Hogar'),
        icon: Value('house-line'),
        colorDark: Value(0xFF93C179),
        colorLight: Value(0xFF49782A),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(2),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000004'),
        name: Value('Salud'),
        icon: Value('heartbeat'),
        colorDark: Value(0xFF49C7C0),
        colorLight: Value(0xFF007E78),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(3),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000005'),
        name: Value('Ocio'),
        icon: Value('popcorn'),
        colorDark: Value(0xFFC19FE9),
        colorLight: Value(0xFF7955A0),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(4),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000006'),
        name: Value('Servicios'),
        icon: Value('lightning'),
        colorDark: Value(0xFF8FB0F8),
        colorLight: Value(0xFF4665AE),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(5),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000007'),
        name: Value('Educación'),
        icon: Value('graduation-cap'),
        colorDark: Value(0xFFAAA7F4),
        colorLight: Value(0xFF635DAB),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(6),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000008'),
        name: Value('Regalos'),
        icon: Value('gift'),
        colorDark: Value(0xFFDD96CD),
        colorLight: Value(0xFF924B84),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(7),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000009'),
        name: Value('Ropa'),
        icon: Value('t-shirt'),
        colorDark: Value(0xFFC1B35B),
        colorLight: Value(0xFF796900),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(8),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000010'),
        name: Value('Otros'),
        icon: Value('package'),
        colorDark: Value(0xFF9BA6B1),
        colorLight: Value(0xFF606A74),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(9),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000014'),
        name: Value('Préstamos'),
        icon: Value('coins'),
        colorDark: Value(_kPrestamosDark),
        colorLight: Value(_kPrestamosLight),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(10),
      ),
      const CategoriesCompanion(
        id: Value(_kTarjetasId),
        name: Value('Tarjetas'),
        icon: Value('credit-card'),
        colorDark: Value(_kTarjetasDark),
        colorLight: Value(_kTarjetasLight),
        kind: Value(CategoryKind.expense),
        sortOrder: Value(11),
      ),

      // 3 categorías de ingreso
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000011'),
        name: Value('Sueldo'),
        icon: Value('briefcase'),
        colorDark: Value(0xFF74C692),
        colorLight: Value(0xFF187C49),
        kind: Value(CategoryKind.income),
        sortOrder: Value(0),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000012'),
        name: Value('Extra'),
        icon: Value('sparkle'),
        colorDark: Value(0xFF47C5D2),
        colorLight: Value(0xFF007B89),
        kind: Value(CategoryKind.income),
        sortOrder: Value(1),
      ),
      const CategoriesCompanion(
        id: Value('018f0000-0000-7000-8000-000000000013'),
        name: Value('Otros ingresos'),
        icon: Value('arrow-circle-down'),
        colorDark: Value(0xFF9BA6B1),
        colorLight: Value(0xFF606A74),
        kind: Value(CategoryKind.income),
        sortOrder: Value(2),
      ),
    ];

    await batch((b) {
      b.insertAll(categories, seed);
    });
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'pockt');
  }
}

const _kPrestamosId = '018f0000-0000-7000-8000-000000000014';
// Paleta OKLCH §6.2b, matiz ~170 (verde azulado): L 0,76 C 0,11 oscuro / L 0,52 C 0,12 claro.
const _kPrestamosDark = 0xFF5FC8A6;
const _kPrestamosLight = 0xFF007E5E;
// Color de fábrica de la v8 (casi igual a "Otros").
const _kPrestamosOldDark = 0xFF8BA4B5;
const _kPrestamosOldLight = 0xFF3D6176;

const _kTarjetasId = '018f0000-0000-7000-8000-000000000015';
// Paleta OKLCH §6.2b, matiz ~15 (carmesí / coral suave): L 0,76 C 0,11 oscuro / L 0,52 C 0,12 claro.
const _kTarjetasDark = 0xFFE88A96;
const _kTarjetasLight = 0xFF9E3D4D;

const _kFactoryCategoryColorUpdates = [
  (
    id: '018f0000-0000-7000-8000-000000000001',
    oldDark: 0xFFFF9F43,
    oldLight: 0xFFD9771A,
    newDark: 0xFFE4A067,
    newLight: 0xFF9A5505,
  ),
  (
    id: '018f0000-0000-7000-8000-000000000002',
    oldDark: 0xFF54A0FF,
    oldLight: 0xFF1F6FD1,
    newDark: 0xFF6BBAF0,
    newLight: 0xFF0070A6,
  ),
  (
    id: '018f0000-0000-7000-8000-000000000003',
    oldDark: 0xFF1DD1A1,
    oldLight: 0xFF0E9673,
    newDark: 0xFF93C179,
    newLight: 0xFF49782A,
  ),
  (
    id: '018f0000-0000-7000-8000-000000000004',
    oldDark: 0xFFFF6B6B,
    oldLight: 0xFFD64545,
    newDark: 0xFF49C7C0,
    newLight: 0xFF007E78,
  ),
  (
    id: '018f0000-0000-7000-8000-000000000005',
    oldDark: 0xFFC56CF0,
    oldLight: 0xFF9B3FC9,
    newDark: 0xFFC19FE9,
    newLight: 0xFF7955A0,
  ),
  (
    id: '018f0000-0000-7000-8000-000000000006',
    oldDark: 0xFF48DBFB,
    oldLight: 0xFF0E9CBF,
    newDark: 0xFF8FB0F8,
    newLight: 0xFF4665AE,
  ),
  (
    id: '018f0000-0000-7000-8000-000000000007',
    oldDark: 0xFFA4B0BE,
    oldLight: 0xFF5D6B7A,
    newDark: 0xFFAAA7F4,
    newLight: 0xFF635DAB,
  ),
  (
    id: '018f0000-0000-7000-8000-000000000008',
    oldDark: 0xFFFECA57,
    oldLight: 0xFFC9921A,
    newDark: 0xFFDD96CD,
    newLight: 0xFF924B84,
  ),
  (
    id: '018f0000-0000-7000-8000-000000000009',
    oldDark: 0xFFF368E0,
    oldLight: 0xFFC43BB2,
    newDark: 0xFFC1B35B,
    newLight: 0xFF796900,
  ),
  (
    id: '018f0000-0000-7000-8000-000000000010',
    oldDark: 0xFF8395A7,
    oldLight: 0xFF556677,
    newDark: 0xFF9BA6B1,
    newLight: 0xFF606A74,
  ),
  (
    id: '018f0000-0000-7000-8000-000000000011',
    oldDark: 0xFF10B981,
    oldLight: 0xFF059669,
    newDark: 0xFF74C692,
    newLight: 0xFF187C49,
  ),
  (
    id: '018f0000-0000-7000-8000-000000000012',
    oldDark: 0xFF06B6D4,
    oldLight: 0xFF0891B2,
    newDark: 0xFF47C5D2,
    newLight: 0xFF007B89,
  ),
  (
    id: '018f0000-0000-7000-8000-000000000013',
    oldDark: 0xFF6366F1,
    oldLight: 0xFF4338CA,
    newDark: 0xFF9BA6B1,
    newLight: 0xFF606A74,
  ),
];
