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
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/recurring/domain/recurrence.dart';
import 'package:pockt/features/recurring/ui/recurring_frequency_card.dart';

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
  bool _initializing = false;

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
    Future.microtask(_initCategory);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initCategory() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    final db = ref.read(databaseProvider);
    if (widget.rule?.categoryId != null) {
      _selectedCategory = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(widget.rule!.categoryId))).getSingleOrNull();
    }
    if (_selectedCategory == null) {
      final list =
          await (db.select(db.categories)
                ..where(
                  (c) => c.kind.equalsValue(
                    _type == TxType.income
                        ? CategoryKind.income
                        : CategoryKind.expense,
                  ),
                )
                ..limit(1))
              .get();
      if (list.isNotEmpty) _selectedCategory = list.first;
    }
    _initializing = false;
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  Future<void> _onTypeChanged(TxType newType) async {
    if (_type == newType) return;
    Haptics.tick();
    final db = ref.read(databaseProvider);
    final list =
        await (db.select(db.categories)
              ..where(
                (c) => c.kind.equalsValue(
                  newType == TxType.income
                      ? CategoryKind.income
                      : CategoryKind.expense,
                ),
              )
              ..limit(1))
            .get();
    if (mounted) {
      setState(() {
        _type = newType;
        if (list.isNotEmpty) {
          _selectedCategory = list.first;
        }
      });
    }
  }

  Future<void> _pickCategory() async {
    Haptics.tick();
    final cat = await showCategoryPickerSheet(context, type: _type);
    if (cat != null && mounted) {
      setState(() {
        _selectedCategory = cat;
      });
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
      onSaveOverride:
          ({
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
      final list =
          await (db.select(db.categories)
                ..where(
                  (c) => c.kind.equalsValue(
                    _type == TxType.income
                        ? CategoryKind.income
                        : CategoryKind.expense,
                  ),
                )
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  TypeToggle(currentType: _type, onTypeChanged: _onTypeChanged),
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
                    borderRadius: BorderRadius.circular(PocktRadii.l),
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
                  // Categoría
                  Pressable(
                    key: const ValueKey('recurring-category-button'),
                    onTap: _pickCategory,
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      borderRadius: BorderRadius.circular(PocktRadii.l),
                      child: Row(
                        children: [
                          Text(
                            'Categoría',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedCategory != null) ...[
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(
                                  isDark
                                      ? _selectedCategory!.colorDark
                                      : _selectedCategory!.colorLight,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: categoryIcon(
                                _selectedCategory!.icon,
                                size: 14,
                                color: colors.keypadKey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedCategory!.name,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ] else
                            Text(
                              'Seleccionar',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.textTertiary,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Icon(
                            uiIcon('caret-right'),
                            size: 16,
                            color: colors.textTertiary,
                          ),
                        ],
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
                      borderRadius: BorderRadius.circular(PocktRadii.l),
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
                  RecurringFrequencyCard(
                    frequency: _frequency,
                    dayOfMonth: _dayOfMonth,
                    onFrequencyChanged: (f) => setState(() => _frequency = f),
                    onDayOfMonthChanged: (d) => setState(() => _dayOfMonth = d),
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
                        borderRadius: BorderRadius.circular(PocktRadii.xl),
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
