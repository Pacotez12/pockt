import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/income/domain/pay_split.dart';
import 'package:pockt/features/income/domain/salary_deduction.dart';
import 'package:pockt/features/income/ui/deduction_dialog.dart';
import 'package:pockt/features/income/ui/schedule_form_sections.dart';
import 'package:pockt/features/income/ui/schedule_preview_cards.dart';
import 'package:pockt/features/income/ui/schedule_split_and_deductions.dart';

export 'package:pockt/features/income/ui/deduction_dialog.dart';
export 'package:pockt/features/income/ui/schedule_form_sections.dart';
export 'package:pockt/features/income/ui/schedule_preview_cards.dart';
export 'package:pockt/features/income/ui/schedule_split_and_deductions.dart';

class IncomeScheduleScreen extends ConsumerStatefulWidget {
  final DateTime? nowLocal;

  const IncomeScheduleScreen({super.key, this.nowLocal});

  @override
  ConsumerState<IncomeScheduleScreen> createState() =>
      _IncomeScheduleScreenState();
}

class _IncomeScheduleScreenState extends ConsumerState<IncomeScheduleScreen> {
  PayMode _mode = PayMode.biweekly;
  int _day1 = 15;
  int _day2 = -1;
  int _monthlyDay = -1;
  PayDayRule _day1Rule = PayDayRule.either;
  PayDayRule _day2Rule = PayDayRule.previous;
  PayDayRule _monthlyRule = PayDayRule.previous;
  int? _monthlyAmount;
  int _splitPercent1 = 50;
  String _incomeCategoryId = '018f0000-0000-7000-8000-000000000011';
  List<SalaryDeductionItem> _deductions = [];
  StreamSubscription<IncomeSchedule?>? _scheduleSub;
  StreamSubscription<DateTime?>? _lastSalarySub;
  DateTime? _lastSalaryDate;

  DateTime get _today => widget.nowLocal ?? toLocal(DateTime.now());

  List<int> get _payDays {
    if (_mode == PayMode.biweekly) {
      return [_day1, _day2];
    } else {
      return [_monthlyDay];
    }
  }

  List<PayDayRule> get _payDayRules {
    if (_mode == PayMode.biweekly) {
      return [_day1Rule, _day2Rule];
    } else {
      return [_monthlyRule];
    }
  }

  PayWindow? get _nextPayWindow {
    return nextPayWindow(
      _today,
      _payDays,
      _payDayRules,
      lastConfirmedSalaryDate: _lastSalaryDate,
    );
  }

  @override
  void initState() {
    super.initState();
    _scheduleSub = ref
        .read(incomeScheduleRepositoryProvider)
        .watchCurrent()
        .listen((schedule) async {
          if (!mounted || schedule == null) return;
          _lastSalarySub?.cancel();
          _lastSalarySub = ref
              .read(transactionsRepositoryProvider)
              .watchLastConfirmedSalaryDate(
                categoryId: schedule.categoryId,
                beforeOrOnLocalDay: _today,
              )
              .listen((date) {
                if (mounted) {
                  setState(() => _lastSalaryDate = date);
                }
              });
          try {
            final parsedDays = parsePayDays(schedule.payDays);
            final parsedRules = parsePayDayRules(
              schedule.payDayRules,
              parsedDays,
            );
            final parsedSplits = parsePaySplitPercents(
              schedule.paySplitPercents,
              count: parsedDays.length,
            );
            final deds = await ref
                .read(incomeScheduleRepositoryProvider)
                .getDeductionsFor(schedule.id);
            if (!mounted) return;
            setState(() {
              _mode = schedule.mode == 'monthly'
                  ? PayMode.monthly
                  : PayMode.biweekly;
              _monthlyAmount = schedule.monthlyAmount;
              _incomeCategoryId = schedule.categoryId;
              _deductions = deds
                  .map(
                    (d) => SalaryDeductionItem(
                      id: d.id,
                      scheduleId: d.scheduleId,
                      name: d.name,
                      kind: d.kind,
                      value: d.value,
                    ),
                  )
                  .toList();
              if (parsedSplits.isNotEmpty) {
                _splitPercent1 = parsedSplits[0];
              }
              if (_mode == PayMode.biweekly && parsedDays.length >= 2) {
                _day1 = parsedDays[0];
                _day2 = parsedDays[1];
                if (parsedRules.length >= 2) {
                  _day1Rule = parsedRules[0];
                  _day2Rule = parsedRules[1];
                }
              } else if (parsedDays.isNotEmpty) {
                _monthlyDay = parsedDays[0];
                if (parsedRules.isNotEmpty) {
                  _monthlyRule = parsedRules[0];
                }
              }
            });
          } catch (_) {}
        });
  }

  @override
  void dispose() {
    _scheduleSub?.cancel();
    _lastSalarySub?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(incomeScheduleRepositoryProvider);
    final List<int> splits = _mode == PayMode.biweekly
        ? [_splitPercent1, 100 - _splitPercent1]
        : const [100];

    if (_monthlyAmount != null) {
      try {
        netPayAmounts(_monthlyAmount!, splits, _deductions);
      } on ArgumentError {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Los descuentos superan el cobro de fin de mes. Ajustá el sueldo, el reparto o los descuentos.',
            ),
          ),
        );
        return;
      }
    }

    await repo.setSchedule(
      mode: _mode,
      payDays: _payDays,
      payDayRules: _payDayRules,
      monthlyAmount: _monthlyAmount,
      paySplitPercents: splits,
      categoryId: _incomeCategoryId,
      deductions: _deductions,
    );

    Haptics.save();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _editMonthlyAmount() async {
    final db = ref.read(databaseProvider);
    var cat = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(_incomeCategoryId))).getSingleOrNull();
    if (cat == null) {
      final list =
          await (db.select(db.categories)
                ..where((c) => c.kind.equalsValue(CategoryKind.income))
                ..limit(1))
              .get();
      if (list.isNotEmpty) cat = list.first;
    }
    if (cat == null || !mounted) return;

    await showAmountKeypad(
      context,
      category: cat,
      type: TxType.income,
      initialAmount: _monthlyAmount,
      onSaveOverride:
          ({
            required int amount,
            required Category category,
            required DateTime occurredAt,
            String? merchant,
            String? note,
          }) async {
            setState(() {
              _monthlyAmount = amount;
              _incomeCategoryId = category.id;
            });
          },
    );
  }

  Future<void> _openDeductionDialog({
    SalaryDeductionItem? initial,
    int? index,
  }) async {
    final result = await showSalaryDeductionDialog(
      context,
      initial: initial,
      index: index,
      monthlyAmount: _monthlyAmount,
      mode: _mode,
      splitPercent1: _splitPercent1,
      currentDeductions: _deductions,
    );
    if (result != null && mounted) {
      setState(() {
        if (index != null && index < _deductions.length) {
          _deductions[index] = result;
        } else {
          _deductions.add(result);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Pressable(
                    semanticLabel: 'Volver',
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.glassFill,
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: Center(
                        child: Icon(
                          uiIcon('arrow-left'),
                          size: 18,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sueldo y cobros',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Cuándo, cuánto y qué cobrás de verdad',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ScheduleModeSelector(
                    mode: _mode,
                    onModeChanged: (m) => setState(() => _mode = m),
                  ),
                  const SizedBox(height: 16),
                  ScheduleDaysSelector(
                    mode: _mode,
                    day1: _day1,
                    day2: _day2,
                    monthlyDay: _monthlyDay,
                    day1Rule: _day1Rule,
                    day2Rule: _day2Rule,
                    monthlyRule: _monthlyRule,
                    onDay1Changed: (d) => setState(() => _day1 = d),
                    onDay2Changed: (d) => setState(() => _day2 = d),
                    onMonthlyDayChanged: (d) => setState(() => _monthlyDay = d),
                    onDay1RuleChanged: (r) => setState(() => _day1Rule = r),
                    onDay2RuleChanged: (r) => setState(() => _day2Rule = r),
                    onMonthlyRuleChanged: (r) =>
                        setState(() => _monthlyRule = r),
                  ),
                  const SizedBox(height: 16),
                  ScheduleMonthlyAmountTile(
                    monthlyAmount: _monthlyAmount,
                    onTap: _editMonthlyAmount,
                  ),
                  if (_mode == PayMode.biweekly) ...[
                    const SizedBox(height: 16),
                    ScheduleSplitSelector(
                      day1: _day1,
                      day2: _day2,
                      splitPercent1: _splitPercent1,
                      splitPreviewText: formatSplitPreviewText(
                        day1: _day1,
                        day2: _day2,
                        monthlyAmount: _monthlyAmount,
                        splitPercent1: _splitPercent1,
                      ),
                      onSplitChanged: (s) => setState(() => _splitPercent1 = s),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ScheduleDeductionsSection(
                    deductions: _deductions,
                    monthlyAmount: _monthlyAmount,
                    onAdd: () => _openDeductionDialog(),
                    onEdit: (item, i) =>
                        _openDeductionDialog(initial: item, index: i),
                    onDelete: (i) {
                      Haptics.tick();
                      setState(() {
                        _deductions.removeAt(i);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ScheduleNetSummaryCard(
                    monthlyAmount: _monthlyAmount,
                    mode: _mode,
                    day1: _day1,
                    day2: _day2,
                    splitPercent1: _splitPercent1,
                    deductions: _deductions,
                  ),
                  const SizedBox(height: 20),
                  ScheduleLivePreviewCard(
                    nextPayDateText: formatNextPayDateText(_nextPayWindow),
                  ),
                  const SizedBox(height: 24),
                  ScheduleSaveButton(onSave: _save),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
