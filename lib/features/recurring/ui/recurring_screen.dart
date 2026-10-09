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
import 'package:pockt/features/recurring/domain/recurrence.dart';

const List<String> _kShortMonths = [
  'ene.',
  'feb.',
  'mar.',
  'abr.',
  'may.',
  'jun.',
  'jul.',
  'ago.',
  'sep.',
  'oct.',
  'nov.',
  'dic.',
];

/// Pantalla de gestión de reglas recurrentes (spec §5.7 / §5.10).
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  void _openAdd(BuildContext context) {
    Haptics.tick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RecurringFormScreen(),
      ),
    );
  }

  void _openEdit(BuildContext context, RecurringRule rule) {
    Haptics.tick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecurringFormScreen(rule: rule),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final rulesAsync = ref.watch(recurringRepositoryProvider).watchAll();

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
                          'Recurrentes',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Gastos fijos y suscripciones',
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
                    key: const ValueKey('add-recurring-button'),
                    onTap: () => _openAdd(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.brandStart.withValues(alpha: 0.18),
                        border: Border.all(
                          color: colors.brandStart.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          uiIcon('plus'),
                          size: 18,
                          color: colors.brandStart,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<RecurringRule>>(
                stream: rulesAsync,
                builder: (context, snapshot) {
                  final rules = snapshot.data ?? const [];

                  if (rules.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: rules.length,
                    itemBuilder: (context, index) {
                      final rule = rules[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecurringRuleCard(
                          rule: rule,
                          onTap: () => _openEdit(context, rule),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.pockt;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.glassFill,
                border: Border.all(color: colors.glassBorder),
              ),
              child: Center(
                child: Icon(
                  uiIcon('sparkle'),
                  size: 28,
                  color: colors.brandStart,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sin recurrentes',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anotá suscripciones o gastos fijos para que te recordemos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Pressable(
              key: const ValueKey('empty-add-recurring-button'),
              onTap: () => _openAdd(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.brandStart,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Agregar recurrente',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringRuleCard extends ConsumerWidget {
  final RecurringRule rule;
  final VoidCallback onTap;

  const _RecurringRuleCard({
    required this.rule,
    required this.onTap,
  });

  String _formatNextDue(DateTime date) {
    final local = toLocal(date);
    return '${local.day} de ${_kShortMonths[local.month - 1]}';
  }

  String _formatFreq(String freq) {
    switch (freq) {
      case 'weekly':
        return 'Semanal';
      case 'yearly':
        return 'Anual';
      case 'monthly':
      default:
        return 'Mensual';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = ref.read(recurringRepositoryProvider);

    return Dismissible(
      key: ValueKey('dismiss-${rule.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(uiIcon('trash'), color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Borrar',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        Haptics.tick();
        repo.delete(rule.id);
      },
      child: Pressable(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.brandStart.withValues(
                    alpha: isDark ? 0.20 : 0.12,
                  ),
                ),
                child: Center(
                  child: Icon(
                    uiIcon('sparkle'),
                    size: 18,
                    color: colors.brandStart,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: rule.active
                            ? colors.textPrimary
                            : colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatFreq(rule.frequency)} · Próximo: ${_formatNextDue(rule.nextDueDate)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatGs(rule.amount),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: rule.active
                          ? colors.textPrimary
                          : colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch.adaptive(
                        key: ValueKey('toggle-active-${rule.id}'),
                        value: rule.active,
                        activeTrackColor: colors.brandStart,
                        onChanged: (active) {
                          Haptics.tick();
                          repo.setActive(rule.id, active);
                        },
                      ),
                      Pressable(
                        key: ValueKey('delete-recurring-${rule.id}'),
                        onTap: () {
                          Haptics.tick();
                          repo.delete(rule.id);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            uiIcon('trash'),
                            size: 16,
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formulario para crear o editar una regla recurrente.
class RecurringFormScreen extends ConsumerStatefulWidget {
  final RecurringRule? rule;

  const RecurringFormScreen({super.key, this.rule});

  @override
  ConsumerState<RecurringFormScreen> createState() =>
      _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  late TextEditingController _nameController;
  late TxType _type;
  late int _amount;
  late RecurrenceFrequency _frequency;
  int? _dayOfMonth;
  Category? _selectedCategory;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rule?.name ?? '');
    _type = widget.rule?.type ?? TxType.expense;
    _amount = widget.rule?.amount ?? 0;
    _frequency = widget.rule != null
        ? RecurrenceFrequency.values.firstWhere(
            (f) => f.name == widget.rule!.frequency,
            orElse: () => RecurrenceFrequency.monthly,
          )
        : RecurrenceFrequency.monthly;
    _dayOfMonth = widget.rule?.dayOfMonth ?? DateTime.now().day;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initCategory() async {
    if (_initialized) return;
    final db = ref.read(databaseProvider);
    if (widget.rule?.categoryId != null) {
      _selectedCategory = await (db.select(db.categories)
            ..where((c) => c.id.equals(widget.rule!.categoryId)))
          .getSingleOrNull();
    }
    if (_selectedCategory == null) {
      final list = await (db.select(db.categories)
            ..where((c) => c.kind.equalsValue(
                  _type == TxType.income
                      ? CategoryKind.income
                      : CategoryKind.expense,
                ))
            ..limit(1))
          .get();
      if (list.isNotEmpty) _selectedCategory = list.first;
    }
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  Future<void> _pickAmount() async {
    final cat = _selectedCategory;
    if (cat == null) return;

    await showAmountKeypad(
      context,
      category: cat,
      type: _type,
      initialAmount: _amount > 0 ? _amount : null,
      onSaveOverride: ({
        required int amount,
        required Category category,
        required DateTime occurredAt,
        String? merchant,
        String? note,
      }) async {
        setState(() {
          _amount = amount;
          _selectedCategory = category;
        });
      },
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    var cat = _selectedCategory;
    if (cat == null) {
      final db = ref.read(databaseProvider);
      final list = await (db.select(db.categories)
            ..where((c) => c.kind.equalsValue(
                  _type == TxType.income
                      ? CategoryKind.income
                      : CategoryKind.expense,
                ))
            ..limit(1))
          .get();
      if (list.isNotEmpty) cat = list.first;
    }
    if (cat == null) return;

    final repo = ref.read(recurringRepositoryProvider);

    if (widget.rule != null) {
      await repo.update(
        widget.rule!.id,
        name: name,
        type: _type,
        amount: _amount,
        categoryId: cat.id,
        frequency: _frequency,
        dayOfMonth: _dayOfMonth,
      );
    } else {
      await repo.add(
        name: name,
        type: _type,
        amount: _amount,
        categoryId: cat.id,
        frequency: _frequency,
        dayOfMonth: _dayOfMonth,
      );
    }

    Haptics.save();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    if (!_initialized) {
      _initCategory();
    }

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
                    child: Text(
                      widget.rule != null
                          ? 'Editar recurrente'
                          : 'Nuevo recurrente',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
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
                  // Nombre
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    child: TextField(
                      key: const ValueKey('recurring-name-input'),
                      controller: _nameController,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nombre (ej. Netflix, Alquiler)...',
                        hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: colors.textTertiary,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Monto
                  Pressable(
                    key: const ValueKey('recurring-amount-button'),
                    onTap: _pickAmount,
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      child: Row(
                        children: [
                          Text(
                            'Monto',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _amount > 0 ? formatGs(_amount) : 'Ingresar monto',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _amount > 0
                                  ? colors.textPrimary
                                  : colors.brandStart,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            uiIcon('pencil-simple'),
                            size: 16,
                            color: colors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Frecuencia
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Frecuencia',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _FreqPill(
                                key: const ValueKey('freq-monthly'),
                                title: 'Mensual',
                                isSelected:
                                    _frequency == RecurrenceFrequency.monthly,
                                onTap: () => setState(
                                  () => _frequency =
                                      RecurrenceFrequency.monthly,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _FreqPill(
                                key: const ValueKey('freq-weekly'),
                                title: 'Semanal',
                                isSelected:
                                    _frequency == RecurrenceFrequency.weekly,
                                onTap: () => setState(
                                  () => _frequency =
                                      RecurrenceFrequency.weekly,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _FreqPill(
                                key: const ValueKey('freq-yearly'),
                                title: 'Anual',
                                isSelected:
                                    _frequency == RecurrenceFrequency.yearly,
                                onTap: () => setState(
                                  () => _frequency =
                                      RecurrenceFrequency.yearly,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_frequency == RecurrenceFrequency.monthly) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Día del mes: ${_dayOfMonth ?? 15}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [1, 5, 10, 15, 20, 25, 28, 30].map((d) {
                              final sel = _dayOfMonth == d;
                              return Pressable(
                                onTap: () => setState(() => _dayOfMonth = d),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? colors.brandStart
                                        : colors.glassFill,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: sel
                                          ? colors.brandStart
                                          : colors.glassBorder,
                                    ),
                                  ),
                                  child: Text(
                                    '$d',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? Colors.white
                                          : colors.textPrimary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Botón Guardar
                  Pressable(
                    key: const ValueKey('save-recurring-button'),
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
                      child: Text(
                        widget.rule != null
                            ? 'Actualizar recurrente'
                            : 'Guardar recurrente',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
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

class _FreqPill extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _FreqPill({
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.textPrimary : colors.glassFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colors.textPrimary : colors.glassBorder,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? colors.background : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
