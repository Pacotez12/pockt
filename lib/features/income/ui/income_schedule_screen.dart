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
import 'package:pockt/features/income/domain/pay_split.dart';
import 'package:pockt/features/income/domain/salary_deduction.dart';

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
  int? _monthlyAmount;
  int _splitPercent1 = 50;
  String _incomeCategoryId = '018f0000-0000-7000-8000-000000000011';
  List<SalaryDeductionItem> _deductions = [];
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

  String get _splitPreviewText {
    final d1 = _day1 == -1 ? 'A fin de mes' : 'El $_day1';
    final day2Label = _day2 == -1 ? 'a fin de mes' : 'el $_day2';

    if (_monthlyAmount != null && _monthlyAmount! > 0) {
      final splits = splitAmounts(_monthlyAmount!, [_splitPercent1, 100 - _splitPercent1]);
      return '$d1 cobrás ~${formatGs(splits[0])} · $day2Label ~${formatGs(splits[1])}';
    } else {
      return '$d1: $_splitPercent1 % · $day2Label: ${100 - _splitPercent1} %';
    }
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
    _scheduleSub = ref.read(incomeScheduleRepositoryProvider).watchCurrent().listen((schedule) async {
      if (!mounted || schedule == null) return;
      try {
        final parsedDays = parsePayDays(schedule.payDays);
        final parsedRules = parsePayDayRules(schedule.payDayRules, parsedDays);
        final parsedSplits = parsePaySplitPercents(schedule.paySplitPercents, count: parsedDays.length);
        final deds = await ref.read(incomeScheduleRepositoryProvider).getDeductionsFor(schedule.id);
        if (!mounted) return;
        setState(() {
          _mode = schedule.mode == 'monthly' ? PayMode.monthly : PayMode.biweekly;
          _monthlyAmount = schedule.monthlyAmount;
          _incomeCategoryId = schedule.categoryId;
          _deductions = deds
              .map((d) => SalaryDeductionItem(
                    id: d.id,
                    scheduleId: d.scheduleId,
                    name: d.name,
                    kind: d.kind,
                    value: d.value,
                  ))
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
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(incomeScheduleRepositoryProvider);
    final List<int> splits = _mode == PayMode.biweekly
        ? [_splitPercent1, 100 - _splitPercent1]
        : const [100];

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
      initialAmount: _monthlyAmount,
      onSaveOverride: ({
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
                  _buildModeSelector(context),
                  const SizedBox(height: 16),
                  _buildDaysSelector(context),
                  const SizedBox(height: 16),
                  _buildMonthlyAmountTile(context),
                  if (_mode == PayMode.biweekly) ...[
                    const SizedBox(height: 16),
                    _buildSplitSelector(context),
                  ],
                  const SizedBox(height: 16),
                  _buildDeductionsSection(context),
                  const SizedBox(height: 16),
                  _buildNetSummaryCard(context),
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

  Widget _buildMonthlyAmountTile(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      key: const ValueKey('schedule-monthly-amount-tile'),
      onTap: _editMonthlyAmount,
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
                    'Sueldo mensual',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _monthlyAmount != null && _monthlyAmount! > 0
                        ? formatGs(_monthlyAmount!)
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

  Widget _buildSplitSelector(BuildContext context) {
    final colors = context.pockt;

    return GlassCard(
      key: const ValueKey('schedule-split-section'),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reparto',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$_splitPercent1 % / ${100 - _splitPercent1} %',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.brandStart,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colors.brandStart,
              inactiveTrackColor: colors.glassBorder,
              thumbColor: colors.brandStart,
              overlayColor: colors.brandStart.withValues(alpha: 0.16),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              key: const ValueKey('schedule-split-slider'),
              value: _splitPercent1.toDouble(),
              min: 5,
              max: 95,
              divisions: 18,
              onChanged: (value) {
                final stepped = (value / 5).round() * 5;
                if (stepped != _splitPercent1) {
                  Haptics.tick();
                  setState(() {
                    _splitPercent1 = stepped;
                  });
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_day1 == -1 ? "Fin de mes" : "Día $_day1"}: $_splitPercent1 %',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: colors.textTertiary,
                  ),
                ),
                Text(
                  '${_day2 == -1 ? "Fin de mes" : "Día $_day2"}: ${100 - _splitPercent1} %',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.glassBorder),
            ),
            child: Row(
              children: [
                Icon(
                  uiIcon('coins'),
                  size: 16,
                  color: colors.brandStart,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _splitPreviewText,
                    key: const ValueKey('schedule-split-preview-text'),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionsSection(BuildContext context) {
    final colors = context.pockt;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'DESCUENTOS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: colors.textTertiary,
                  ),
                ),
              ),
              Pressable(
                key: const ValueKey('add-deduction-button'),
                onTap: () => _showDeductionDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.brandStart.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(uiIcon('plus'), size: 12, color: colors.brandStart),
                      const SizedBox(width: 4),
                      Text(
                        'Agregar',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.brandStart,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_deductions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Sin descuentos (IPS, seguro médico, aportes). Los descuentos se restan del último cobro del mes.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: colors.textTertiary,
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < _deductions.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 16,
                      thickness: 0.5,
                      color: colors.glassBorder,
                    ),
                  _buildDeductionRow(context, _deductions[i], i),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDeductionRow(BuildContext context, SalaryDeductionItem d, int index) {
    final colors = context.pockt;

    final String subtitle;
    if (d.kind == 'percent') {
      final pct = d.value / 100.0;
      final pctStr = pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 2);
      final approx = _monthlyAmount != null && _monthlyAmount! > 0
          ? (_monthlyAmount! * (d.value / 10000.0)).round()
          : null;
      subtitle = '$pctStr % del bruto${approx != null ? ' (~${formatGs(approx)})' : ''}';
    } else {
      subtitle = '${formatGs(d.value)} fijo';
    }

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.brandEnd.withValues(alpha: 0.12),
          ),
          child: Center(
            child: Icon(
              uiIcon('tag'),
              size: 15,
              color: colors.brandEnd,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.name,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Pressable(
          key: ValueKey('edit-deduction-$index'),
          onTap: () => _showDeductionDialog(initial: d, index: index),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              uiIcon('paint-brush'),
              size: 16,
              color: colors.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Pressable(
          key: ValueKey('delete-deduction-$index'),
          onTap: () {
            Haptics.tick();
            setState(() {
              _deductions.removeAt(index);
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              uiIcon('trash'),
              size: 16,
              color: colors.danger,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDeductionDialog({
    SalaryDeductionItem? initial,
    int? index,
  }) async {
    final colors = context.pockt;
    final nameController = TextEditingController(text: initial?.name ?? '');
    String kind = initial?.kind ?? 'percent';
    String initialValueStr = '';
    if (initial != null) {
      if (initial.kind == 'percent') {
        final p = initial.value / 100.0;
        initialValueStr = p.toStringAsFixed(p.truncateToDouble() == p ? 0 : 2);
      } else {
        initialValueStr = initial.value.toString();
      }
    }
    final valueController = TextEditingController(text: initialValueStr);
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void validateAndSave() {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                setDialogState(() => errorMessage = 'Ingresá un nombre');
                return;
              }

              final valStr = valueController.text.trim().replaceAll(',', '.');
              final parsed = double.tryParse(valStr);
              if (parsed == null || parsed <= 0) {
                setDialogState(() => errorMessage = 'Ingresá un valor válido mayor a 0');
                return;
              }

              final int deductionValue;
              if (kind == 'percent') {
                deductionValue = (parsed * 100).round();
              } else {
                deductionValue = parsed.round();
              }

              final newDeduction = SalaryDeductionItem(
                id: initial?.id ?? '',
                scheduleId: initial?.scheduleId ?? '',
                name: name,
                kind: kind,
                value: deductionValue,
              );

              if (_monthlyAmount != null && _monthlyAmount! > 0) {
                final simulatedList = List<SalaryDeductionItem>.from(_deductions);
                if (index != null && index < simulatedList.length) {
                  simulatedList[index] = newDeduction;
                } else {
                  simulatedList.add(newDeduction);
                }

                final splits = _mode == PayMode.biweekly
                    ? [_splitPercent1, 100 - _splitPercent1]
                    : const [100];

                try {
                  netPayAmounts(_monthlyAmount!, splits, simulatedList);
                } catch (e) {
                  setDialogState(() {
                    errorMessage = 'El descuento deja el cobro de fin de mes en negativo';
                  });
                  return;
                }
              }

              Haptics.tick();
              setState(() {
                if (index != null && index < _deductions.length) {
                  _deductions[index] = newDeduction;
                } else {
                  _deductions.add(newDeduction);
                }
              });
              Navigator.of(dialogCtx).pop();
            }

            return AlertDialog(
              backgroundColor: colors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: colors.glassBorder),
              ),
              title: Text(
                initial == null ? 'Agregar descuento' : 'Editar descuento',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tipo de descuento',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Pressable(
                            key: const ValueKey('deduction-kind-percent'),
                            onTap: () {
                              setDialogState(() {
                                kind = 'percent';
                                errorMessage = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: kind == 'percent'
                                    ? colors.brandStart
                                    : colors.glassFill,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: kind == 'percent'
                                      ? Colors.transparent
                                      : colors.glassBorder,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Porcentaje (%)',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: kind == 'percent'
                                      ? Colors.white
                                      : colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Pressable(
                            key: const ValueKey('deduction-kind-fixed'),
                            onTap: () {
                              setDialogState(() {
                                kind = 'fixed';
                                errorMessage = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: kind == 'fixed'
                                    ? colors.brandStart
                                    : colors.glassFill,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: kind == 'fixed'
                                      ? Colors.transparent
                                      : colors.glassBorder,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Monto fijo (Gs.)',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: kind == 'fixed'
                                      ? Colors.white
                                      : colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nombre',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const ValueKey('deduction-name-input'),
                      controller: nameController,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ej: IPS, Seguro médico',
                        hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          color: colors.textTertiary,
                        ),
                        filled: true,
                        fillColor: colors.glassFill,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.glassBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      kind == 'percent' ? 'Porcentaje del sueldo bruto' : 'Monto en Guaraníes',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const ValueKey('deduction-value-input'),
                      controller: valueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: kind == 'percent' ? 'Ej: 9' : 'Ej: 40000',
                        hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          color: colors.textTertiary,
                        ),
                        filled: true,
                        fillColor: colors.glassFill,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.glassBorder),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.danger,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('save-deduction-dialog-button'),
                  onPressed: validateAndSave,
                  child: Text(
                    'Guardar',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      color: colors.brandStart,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNetSummaryCard(BuildContext context) {
    final colors = context.pockt;

    if (_monthlyAmount == null || _monthlyAmount! <= 0) {
      return GlassCard(
        key: const ValueKey('schedule-net-summary-card'),
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LO QUE COBRÁS',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresá tu sueldo bruto para ver el desglose neto real.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    final splits = _mode == PayMode.biweekly
        ? [_splitPercent1, 100 - _splitPercent1]
        : const [100];

    List<int> netList;
    try {
      netList = netPayAmounts(_monthlyAmount!, splits, _deductions);
    } catch (_) {
      netList = splitAmounts(_monthlyAmount!, splits);
    }

    final totalNet = netList.fold<int>(0, (sum, val) => sum + val);
    final totalDeductions = _monthlyAmount! - totalNet;

    return GlassCard(
      key: const ValueKey('schedule-net-summary-card'),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LO QUE COBRÁS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: colors.textTertiary,
                  ),
                ),
              ),
              if (totalDeductions > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.brandEnd.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '−${formatGs(totalDeductions)} en desc.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.brandEnd,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_mode == PayMode.biweekly && netList.length >= 2) ...[
            _buildNetRow(
              context,
              label: '1ª quincena (${_day1 == -1 ? 'Fin de mes' : 'Día $_day1'})',
              grossAmount: splitAmounts(_monthlyAmount!, splits)[0],
              netAmount: netList[0],
              deductionsApplied: 0,
            ),
            const SizedBox(height: 10),
            _buildNetRow(
              context,
              label: '2ª quincena (${_day2 == -1 ? 'Fin de mes' : 'Día $_day2'})',
              grossAmount: splitAmounts(_monthlyAmount!, splits)[1],
              netAmount: netList[1],
              deductionsApplied: totalDeductions,
            ),
          ] else ...[
            _buildNetRow(
              context,
              label: 'Cobro mensual',
              grossAmount: _monthlyAmount!,
              netAmount: netList[0],
              deductionsApplied: totalDeductions,
            ),
          ],
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 0.5,
            color: colors.glassBorder,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total neto mensual',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                formatGs(totalNet),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.positive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetRow(
    BuildContext context, {
    required String label,
    required int grossAmount,
    required int netAmount,
    required int deductionsApplied,
  }) {
    final colors = context.pockt;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            if (deductionsApplied > 0)
              Text(
                'Bruto ${formatGs(grossAmount)} − ${formatGs(deductionsApplied)}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: colors.textTertiary,
                ),
              ),
          ],
        ),
        Text(
          formatGs(netAmount),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
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
