import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/income/domain/pay_days.dart';

const List<String> _kWeekdaysSpanish = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const List<String> _kMonthsSpanish = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

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
  int? _expectedAmount;
  String _incomeCategoryId = '018f0000-0000-7000-8000-000000000011';
  StreamSubscription<IncomeSchedule?>? _scheduleSub;

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
    );
  }

  String get _nextPayDateText {
    final window = _nextPayWindow;
    if (window == null) return 'Sin fecha de cobro';
    if (window.isRange) {
      final w1 = _kWeekdaysSpanish[window.earliest.weekday - 1];
      final m1 = _kMonthsSpanish[window.earliest.month - 1];
      final w2 = _kWeekdaysSpanish[window.latest.weekday - 1];
      final m2 = _kMonthsSpanish[window.latest.month - 1];
      if (window.earliest.month == window.latest.month) {
        return 'Próximo cobro: entre el $w1 ${window.earliest.day} y el $w2 ${window.latest.day} de $m2';
      }
      return 'Próximo cobro: entre el $w1 ${window.earliest.day} de $m1 y el $w2 ${window.latest.day} de $m2';
    }
    final next = window.earliest;
    final weekday = _kWeekdaysSpanish[next.weekday - 1];
    final month = _kMonthsSpanish[next.month - 1];
    return 'Próximo cobro: $weekday ${next.day} de $month';
  }

  @override
  void initState() {
    super.initState();
    _scheduleSub = ref.read(incomeScheduleRepositoryProvider).watchCurrent().listen((schedule) {
      if (!mounted || schedule == null) return;
      try {
        final parsedDays = parsePayDays(schedule.payDays);
        final parsedRules = parsePayDayRules(schedule.payDayRules, parsedDays);
        setState(() {
          _mode = schedule.mode == 'monthly' ? PayMode.monthly : PayMode.biweekly;
          _expectedAmount = schedule.expectedAmount;
          _incomeCategoryId = schedule.categoryId;
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
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(incomeScheduleRepositoryProvider);
    await repo.setSchedule(
      mode: _mode,
      payDays: _payDays,
      payDayRules: _payDayRules,
      expectedAmount: _expectedAmount,
      categoryId: _incomeCategoryId,
    );

    Haptics.save();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _editExpectedAmount() async {
    final db = ref.read(databaseProvider);
    var cat = await (db.select(db.categories)
          ..where((c) => c.id.equals(_incomeCategoryId)))
        .getSingleOrNull();
    if (cat == null) {
      final list = await (db.select(db.categories)
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
      initialAmount: _expectedAmount,
      onSaveOverride: ({
        required int amount,
        required Category category,
        required DateTime occurredAt,
        String? merchant,
        String? note,
      }) async {
        setState(() {
          _expectedAmount = amount;
          _incomeCategoryId = category.id;
        });
      },
    );
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
                          'Esquema de cobro',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Cuándo y cuánto cobrás',
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
                  _buildModeSelector(context),
                  const SizedBox(height: 16),
                  _buildDaysSelector(context),
                  const SizedBox(height: 16),
                  _buildExpectedAmountTile(context),
                  const SizedBox(height: 20),
                  _buildLivePreviewCard(context),
                  const SizedBox(height: 24),
                  _buildSaveButton(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context) {
    final colors = context.pockt;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModePill(
              key: const ValueKey('schedule-mode-biweekly'),
              title: 'Quincenal',
              isSelected: _mode == PayMode.biweekly,
              onTap: () {
                Haptics.tick();
                setState(() => _mode = PayMode.biweekly);
              },
            ),
          ),
          Expanded(
            child: _ModePill(
              key: const ValueKey('schedule-mode-monthly'),
              title: 'Mensual',
              isSelected: _mode == PayMode.monthly,
              onTap: () {
                Haptics.tick();
                setState(() => _mode = PayMode.monthly);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSelector(BuildContext context) {
    final colors = context.pockt;

    if (_mode == PayMode.biweekly) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Días de cobro',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Primer y segundo cobro de la quincena',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            // Primer cobro
            Text(
              '1er cobro: día $_day1',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [1, 5, 10, 15, 20].map((d) {
                final sel = _day1 == d;
                return _DayChip(
                  text: '$d',
                  isSelected: sel,
                  onTap: () {
                    Haptics.tick();
                    setState(() => _day1 = d);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            _RuleSelector(
              key: const ValueKey('rule-selector-day1'),
              currentRule: _day1Rule,
              onChanged: (r) => setState(() => _day1Rule = r),
            ),
            const SizedBox(height: 20),
            Divider(color: colors.glassBorder, height: 1),
            const SizedBox(height: 20),
            // Segundo cobro
            Text(
              '2º cobro: ${_day2 == -1 ? "Último día" : "día $_day2"}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [25, 28, 30, -1].map((d) {
                final sel = _day2 == d;
                return _DayChip(
                  text: d == -1 ? 'Último' : '$d',
                  isSelected: sel,
                  onTap: () {
                    Haptics.tick();
                    setState(() => _day2 = d);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            _RuleSelector(
              key: const ValueKey('rule-selector-day2'),
              currentRule: _day2Rule,
              onChanged: (r) => setState(() => _day2Rule = r),
            ),
          ],
        ),
      );
    } else {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Día del mes',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Elegí qué día de cada mes cobrás',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [1, 5, 10, 15, 20, 25, 28, 30, -1].map((d) {
                final sel = _monthlyDay == d;
                return _DayChip(
                  text: d == -1 ? 'Último día' : '$d',
                  isSelected: sel,
                  onTap: () {
                    Haptics.tick();
                    setState(() => _monthlyDay = d);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            _RuleSelector(
              key: const ValueKey('rule-selector-monthly'),
              currentRule: _monthlyRule,
              onChanged: (r) => setState(() => _monthlyRule = r),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildExpectedAmountTile(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      key: const ValueKey('schedule-expected-amount-tile'),
      onTap: _editExpectedAmount,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monto esperado',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _expectedAmount != null && _expectedAmount! > 0
                        ? formatGs(_expectedAmount!)
                        : 'Opcional (se sugerirá al cobrar)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              uiIcon('caret-right'),
              size: 16,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard(BuildContext context) {
    final colors = context.pockt;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.positive.withValues(alpha: 0.16),
            ),
            child: Center(
              child: Icon(
                uiIcon('calendar'),
                size: 20,
                color: colors.positive,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _nextPayDateText,
              key: const ValueKey('next-pay-day-text'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      key: const ValueKey('save-schedule-button'),
      onTap: _save,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: colors.brandStart,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: colors.brandStart.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          'Guardar esquema',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _RuleSelector extends StatelessWidget {
  final PayDayRule currentRule;
  final ValueChanged<PayDayRule> onChanged;

  const _RuleSelector({
    super.key,
    required this.currentRule,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Si no es día hábil:',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: _RulePill(
                  title: 'El anterior',
                  isSelected: currentRule == PayDayRule.previous,
                  onTap: () => onChanged(PayDayRule.previous),
                ),
              ),
              Expanded(
                child: _RulePill(
                  title: 'El siguiente',
                  isSelected: currentRule == PayDayRule.next,
                  onTap: () => onChanged(PayDayRule.next),
                ),
              ),
              Expanded(
                child: _RulePill(
                  title: 'Puede variar',
                  isSelected: currentRule == PayDayRule.either,
                  onTap: () => onChanged(PayDayRule.either),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RulePill extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _RulePill({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return GestureDetector(
      onTap: () {
        Haptics.tick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? colors.background : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModePill({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? colors.background : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayChip({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.brandStart
              : colors.glassFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colors.brandStart : colors.glassBorder,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
