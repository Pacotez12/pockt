import 'dart:async';
import 'dart:convert';
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
  bool _shiftToBusinessDay = true;
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

  DateTime? get _nextPayDate {
    return nextPayDay(
      _today,
      _payDays,
      shiftToPreviousBusinessDay: _shiftToBusinessDay,
    );
  }

  String get _nextPayDateText {
    final next = _nextPayDate;
    if (next == null) return 'Sin fecha de cobro';
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
        final parsedDays = (jsonDecode(schedule.payDays) as List)
            .map((e) => (e as num).toInt())
            .toList();
        setState(() {
          _mode = schedule.mode == 'monthly' ? PayMode.monthly : PayMode.biweekly;
          _shiftToBusinessDay = schedule.shiftToPreviousBusinessDay;
          _expectedAmount = schedule.expectedAmount;
          _incomeCategoryId = schedule.categoryId;
          if (_mode == PayMode.biweekly && parsedDays.length >= 2) {
            _day1 = parsedDays[0];
            _day2 = parsedDays[1];
          } else if (parsedDays.isNotEmpty) {
            _monthlyDay = parsedDays[0];
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
      shiftToPreviousBusinessDay: _shiftToBusinessDay,
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
                  _buildBusinessDaySwitch(context),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1er cobro: día $_day1',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
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
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2º cobro: ${_day2 == -1 ? "Último" : "día $_day2"}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
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
                    ],
                  ),
                ),
              ],
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
            const SizedBox(height: 12),
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
          ],
        ),
      );
    }
  }

  Widget _buildBusinessDaySwitch(BuildContext context) {
    final colors = context.pockt;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Corrimiento a día hábil',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Si cae sábado o domingo, cobrar el viernes anterior',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            key: const ValueKey('shift-business-day-switch'),
            value: _shiftToBusinessDay,
            activeTrackColor: colors.brandStart,
            onChanged: (val) {
              Haptics.tick();
              setState(() => _shiftToBusinessDay = val);
            },
          ),
        ],
      ),
    );
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
                      color: _expectedAmount != null && _expectedAmount! > 0
                          ? colors.positive
                          : colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              uiIcon('pencil-simple'),
              size: 18,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
