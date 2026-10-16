import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/budgets/data/budgets_repository.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/home/domain/home_period_summary.dart';
import 'package:pockt/features/home/ui/month_glow.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/transactions/ui/tx_row.dart';

/// Helper para crear un stream que reacciona de forma inmediata a cambios en el ajuste
/// de inicio de mes ('calendar' | 'payday') o en el esquema de cobro, manteniendo
/// una única suscripción reactiva a Drift sin retrasos de múltiples saltos en Riverpod.
Stream<T> _watchMonthWithPeriod<T>({
  required Ref ref,
  required ({int year, int month, DateTime nowLocal}) args,
  required Stream<T> Function(DatePeriod period) buildStream,
}) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final schedRepo = ref.watch(incomeScheduleRepositoryProvider);

  late StreamController<T> controller;
  StreamSubscription? settingsSub;
  StreamSubscription? schedSub;
  StreamSubscription? targetSub;

  MonthStartMode currentMode = MonthStartMode.calendar;
  IncomeSchedule? currentSched;
  bool isListening = false;

  void updateQuery() {
    if (!isListening) return;
    targetSub?.cancel();
    final isCurrent =
        args.year == args.nowLocal.year && args.month == args.nowLocal.month;
    final day = isCurrent ? args.nowLocal : DateTime(args.year, args.month, 15);
    final period = periodFor(day, mode: currentMode, schedule: currentSched);
    targetSub = buildStream(period).listen(
      (data) {
        if (!controller.isClosed) controller.add(data);
      },
      onError: (err, st) {
        if (!controller.isClosed) controller.addError(err, st);
      },
    );
  }

  controller = StreamController<T>(
    onListen: () {
      isListening = true;
      schedSub = schedRepo.watchCurrent().listen((sched) {
        currentSched = sched;
        updateQuery();
      });
      settingsSub = settingsRepo
          .watch(SettingsKeys.periodMonthStart)
          .map(MonthStartMode.parse)
          .listen((mode) {
            currentMode = mode;
            updateQuery();
          });
    },
    onCancel: () {
      isListening = false;
      settingsSub?.cancel();
      schedSub?.cancel();
      targetSub?.cancel();
    },
  );

  ref.onDispose(() {
    controller.close();
  });

  return controller.stream;
}

/// Período de fechas correspondiente a [args] (año, mes, nowLocal) respetando el ajuste
/// de inicio de mes ('calendar' vs 'payday') y el esquema de cobro vigente.
final homePeriodProvider =
    Provider.family<DatePeriod, ({int year, int month, DateTime nowLocal})>((
      ref,
      args,
    ) {
      final mode =
          ref.watch(monthStartModeProvider).value ?? MonthStartMode.calendar;
      final schedule = ref.watch(currentIncomeScheduleProvider).value;
      final isCurrent =
          args.year == args.nowLocal.year && args.month == args.nowLocal.month;
      final day =
          isCurrent ? args.nowLocal : DateTime(args.year, args.month, 15);
      return periodFor(day, mode: mode, schedule: schedule);
    });

/// Total de gastos del mes para el trío (año, mes, nowLocal).
final homeMonthTotalProvider =
    StreamProvider.family<int, ({int year, int month, DateTime nowLocal})>((
      ref,
      args,
    ) {
      final repo = ref.watch(transactionsRepositoryProvider);
      return _watchMonthWithPeriod<int>(
        ref: ref,
        args: args,
        buildStream: (period) => repo.watchMonthTotal(
          args.year,
          args.month,
          TxType.expense,
          period: period,
        ),
      );
    });

/// Totales por categoría del mes para el trío (año, mes, nowLocal).
final homeCategoryTotalsProvider = StreamProvider.family<
  List<CategoryTotal>,
  ({int year, int month, DateTime nowLocal})
>((ref, args) {
  final repo = ref.watch(transactionsRepositoryProvider);
  return _watchMonthWithPeriod<List<CategoryTotal>>(
    ref: ref,
    args: args,
    buildStream: (period) => repo.watchMonthCategoryTotals(
      args.year,
      args.month,
      period: period,
    ),
  );
});

/// Totales diarios de gasto del mes para el calendario de calor.
final homeDailyTotalsProvider = StreamProvider.family<
  Map<int, int>,
  ({int year, int month, DateTime nowLocal})
>((ref, args) {
  final repo = ref.watch(transactionsRepositoryProvider);
  return _watchMonthWithPeriod<Map<int, int>>(
    ref: ref,
    args: args,
    buildStream: (period) => repo.watchDailyExpenseTotals(
      args.year,
      args.month,
      period: period,
    ),
  );
});

/// Cantidad de movimientos recientes a mostrar en Inicio (§7b Inicio y apariencia).
final homeRecentCountProvider = StreamProvider<int>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return settingsRepo
      .watch(SettingsKeys.homeRecentCount)
      .map((v) => int.tryParse(v ?? '') ?? 5);
});

/// Lista combinada de últimos movimientos (transacciones y aportes a metas).
final homeRecentMovementsProvider = StreamProvider<List<MovementEntry>>((ref) {
  final count = ref.watch(homeRecentCountProvider).value ?? 5;
  final txRepo = ref.watch(transactionsRepositoryProvider);
  final goalsRepo = ref.watch(goalsRepositoryProvider);
  return combineMovements(
    txStream: txRepo.watchRecent(limit: count),
    contribStream: goalsRepo.watchContributionsWithGoal(limit: count),
    limit: count,
  );
});

/// Sugerencias pendientes de confirmación.
final homePendingSuggestionsProvider =
    StreamProvider<List<SuggestionView>>((ref) {
      final repo = ref.watch(suggestionsRepositoryProvider);
      return repo.watchPending();
    });

/// Presupuestos configurados vigentes.
final homeBudgetsProvider = StreamProvider<List<BudgetView>>((ref) {
  final repo = ref.watch(budgetsRepositoryProvider);
  return repo.watchAll();
});

/// Deducciones asociadas al esquema de cobro vigente.
final homePayDeductionsProvider = StreamProvider<List<SalaryDeduction>>((ref) {
  final sched = ref.watch(currentIncomeScheduleProvider).value;
  if (sched == null) return Stream.value(const []);
  final schedRepo = ref.watch(incomeScheduleRepositoryProvider);
  return schedRepo.watchDeductionsFor(sched.id);
});

/// Fecha del último salario confirmado antes o en el día [nowLocal].
final homeLastSalaryDateProvider = StreamProvider.family<DateTime?, DateTime>((
  ref,
  nowLocal,
) {
  final sched = ref.watch(currentIncomeScheduleProvider).value;
  if (sched == null) return Stream.value(null);
  final txRepo = ref.watch(transactionsRepositoryProvider);
  return txRepo.watchLastConfirmedSalaryDate(
    categoryId: sched.categoryId,
    beforeOrOnLocalDay: nowLocal,
  );
});

/// Fecha de inicio del período contable actual (calculada a partir de esquema, ventana previa y salario).
final homePeriodStartProvider = Provider.family<DateTime?, DateTime>((
  ref,
  nowLocal,
) {
  final sched = ref.watch(currentIncomeScheduleProvider).value;
  if (sched == null) return null;
  final payDays = parsePayDays(sched.payDays);
  final rules = parsePayDayRules(sched.payDayRules, payDays);
  final prevWindow = previousPayWindow(nowLocal, payDays, rules);
  if (prevWindow == null) return null;

  final salaryDate = ref.watch(homeLastSalaryDateProvider(nowLocal)).value;
  DateTime periodStart = prevWindow.earliest;
  if (salaryDate != null) {
    final cleanSalary = DateTime(
      salaryDate.year,
      salaryDate.month,
      salaryDate.day,
    );
    if (!cleanSalary.isBefore(prevWindow.earliest)) {
      periodStart = cleanSalary;
    }
  }
  return periodStart;
});

/// Total de ingresos desde el inicio del período actual de cobro.
final homePayIncomeProvider = StreamProvider.family<int, DateTime>((
  ref,
  periodStart,
) {
  final txRepo = ref.watch(transactionsRepositoryProvider);
  return txRepo.watchTotalSince(periodStart, TxType.income);
});

/// Total de gastos desde el inicio del período actual de cobro.
final homePayExpenseProvider = StreamProvider.family<int, DateTime>((
  ref,
  periodStart,
) {
  final txRepo = ref.watch(transactionsRepositoryProvider);
  return txRepo.watchTotalSince(periodStart, TxType.expense);
});

/// Total de aportes a metas desde el inicio del período actual de cobro.
final homePayContributionsProvider = StreamProvider.family<int, DateTime>((
  ref,
  periodStart,
) {
  final goalsRepo = ref.watch(goalsRepositoryProvider);
  return goalsRepo.watchContributionsTotalSince(periodStart);
});

/// Saldo arrastrado acumulado antes del inicio del período actual.
final homePayCarryOverProvider = StreamProvider.family<int, DateTime>((
  ref,
  periodStart,
) {
  final schedRepo = ref.watch(incomeScheduleRepositoryProvider);
  return schedRepo.watchCarryOverBefore(periodStart);
});

/// Resumen derivado puro del período actual de cobro (quedan, inicio de período, etc.).
final homePeriodSummaryProvider = Provider.family<
  HomePeriodSummary,
  DateTime
>((ref, nowLocal) {
  final sched = ref.watch(currentIncomeScheduleProvider).value;
  final periodStart = ref.watch(homePeriodStartProvider(nowLocal));
  if (sched == null || periodStart == null) {
    return HomePeriodSummary(schedule: sched);
  }

  final salaryDate = ref.watch(homeLastSalaryDateProvider(nowLocal)).value;
  final carryOver =
      ref.watch(homePayCarryOverProvider(periodStart)).value ?? 0;
  final incomeSincePay =
      ref.watch(homePayIncomeProvider(periodStart)).value ?? 0;
  final expenseSincePay =
      ref.watch(homePayExpenseProvider(periodStart)).value ?? 0;
  final contributionsSincePay =
      ref.watch(homePayContributionsProvider(periodStart)).value ?? 0;
  final deductions = ref.watch(homePayDeductionsProvider).value ?? const [];

  return calculateHomePeriodSummary(
    todayLocal: nowLocal,
    schedule: sched,
    lastConfirmedSalaryDate: salaryDate,
    carryOver: carryOver,
    incomeSincePay: incomeSincePay,
    expenseSincePay: expenseSincePay,
    contributionsSincePay: contributionsSincePay,
    deductions: deductions,
  );
});

/// Tinte reactivo del resplandor de fondo calculado según gasto y presupuestos.
final homeGlowColorProvider = Provider.family<
  Color,
  ({int year, int month, DateTime nowLocal, bool isDark, Color brandStart})
>((ref, args) {
  final totals =
      ref
          .watch(
            homeCategoryTotalsProvider((
              year: args.year,
              month: args.month,
              nowLocal: args.nowLocal,
            )),
          )
          .value ??
      const [];
  final baseColor = totals.isNotEmpty
      ? Color(
          args.isDark
              ? totals.first.category.colorDark
              : totals.first.category.colorLight,
        )
      : args.brandStart;

  final reactsToBudget = ref.watch(glowReactsToBudgetProvider).value ?? true;
  final budgets = ref.watch(homeBudgetsProvider).value ?? const [];
  final monthTotal =
      ref
          .watch(
            homeMonthTotalProvider((
              year: args.year,
              month: args.month,
              nowLocal: args.nowLocal,
            )),
          )
          .value ??
      0;

  final totalBudget = budgets.fold<int>(
    0,
    (sum, b) => sum + b.budget.monthlyLimit,
  );
  final spentRatio = (reactsToBudget && totalBudget > 0)
      ? monthTotal / totalBudget
      : null;
  return glowTint(baseColor, spentRatio);
});
