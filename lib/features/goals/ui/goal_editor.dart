import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';

class GoalEditorScreen extends ConsumerStatefulWidget {
  final String? goalId;

  const GoalEditorScreen({super.key, this.goalId});

  @override
  ConsumerState<GoalEditorScreen> createState() => _GoalEditorScreenState();
}

class _GoalEditorScreenState extends ConsumerState<GoalEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  String _selectedIcon = 'target';
  DateTime? _targetDate;
  bool _hasTargetDate = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _amountController = TextEditingController();
    _nameController.addListener(_onTextChanged);
    _amountController.addListener(_onTextChanged);

    if (widget.goalId != null) {
      _loadGoal();
    }
  }

  Future<void> _loadGoal() async {
    final repo = ref.read(goalsRepositoryProvider);
    final goal = await repo.getGoal(widget.goalId!);
    if (goal != null && mounted) {
      setState(() {
        _nameController.text = goal.name;
        _amountController.text = formatGs(goal.targetAmount, symbol: false);
        _selectedIcon = goal.icon;
        _targetDate = goal.targetDate;
        _hasTargetDate = goal.targetDate != null;
      });
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  bool get _canSave {
    final rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(rawAmount) ?? 0;
    return !_isLoading && _nameController.text.trim().isNotEmpty && amount > 0;
  }

  @override
  void dispose() {
    _nameController.removeListener(_onTextChanged);
    _amountController.removeListener(_onTextChanged);
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    Haptics.tick();
    final now = DateTime.now();
    final initial = _targetDate ?? now.add(const Duration(days: 180));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null && mounted) {
      setState(() {
        _targetDate = picked;
        _hasTargetDate = true;
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(rawAmount) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un nombre para la meta')),
      );
      return;
    }

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto objetivo debe ser mayor a 0')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(goalsRepositoryProvider);

    try {
      if (widget.goalId == null) {
        await repo.createGoal(
          name: name,
          icon: _selectedIcon,
          targetAmount: amount,
          targetDate: _hasTargetDate ? _targetDate : null,
        );
      } else {
        await repo.updateGoal(
          id: widget.goalId!,
          name: name,
          icon: _selectedIcon,
          targetAmount: amount,
          targetDate: _hasTargetDate ? _targetDate : null,
        );
      }
      Haptics.save();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isEditing = widget.goalId != null;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isEditing ? 'Editar meta' : 'Nueva meta',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(uiIcon('arrow-left'), color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre
              Text(
                'Nombre',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: PocktType.caption,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              GlassCard(
                borderRadius: BorderRadius.circular(PocktRadii.l),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  key: const ValueKey('goal-name-input'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ej. Fondo de emergencia, Viaje...',
                    hintStyle: TextStyle(color: colors.textTertiary),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Monto objetivo
              Text(
                'Monto objetivo',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: PocktType.caption,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              GlassCard(
                borderRadius: BorderRadius.circular(PocktRadii.l),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      'Gs.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.brandAt(0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('goal-amount-input'),
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [ThousandsInputFormatter()],
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(color: colors.textTertiary),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Ícono
              Text(
                'Ícono',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: PocktType.caption,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kGoalIconKeys.map((iconKey) {
                  final isSelected = _selectedIcon == iconKey;
                  return Pressable(
                    key: ValueKey('goal-icon-$iconKey'),
                    semanticLabel: 'Ícono $iconKey',
                    onTap: () {
                      Haptics.tick();
                      setState(() => _selectedIcon = iconKey);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? colors.brandAt(0).withValues(alpha: 0.2)
                            : colors.glassFill,
                        border: Border.all(
                          color: isSelected
                              ? colors.brandAt(0)
                              : colors.glassBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          uiIcon(iconKey, filled: isSelected),
                          size: 22,
                          color: isSelected
                              ? colors.brandAt(0)
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Fecha objetivo (opcional)
              GlassCard(
                borderRadius: BorderRadius.circular(PocktRadii.l),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              uiIcon('calendar'),
                              size: 20,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Fecha objetivo',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _hasTargetDate,
                          onChanged: (val) {
                            Haptics.tick();
                            setState(() {
                              _hasTargetDate = val;
                              if (val && _targetDate == null) {
                                _targetDate = DateTime.now().add(
                                  const Duration(days: 180),
                                );
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    if (_hasTargetDate) ...[
                      Divider(height: 20, color: colors.glassBorder),
                      Pressable(
                        semanticLabel: 'Elegir fecha',
                        onTap: _pickDate,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _targetDate != null
                                  ? formatShortDate(_targetDate!)
                                  : 'Elegir fecha',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                color: colors.brandAt(0),
                                fontWeight: FontWeight.w600,
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
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Botón Guardar
              Pressable(
                key: const ValueKey('goal-save-button'),
                semanticLabel: isEditing ? 'Guardar cambios' : 'Crear meta',
                onTap: _canSave ? _save : null,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PocktRadii.xl),
                    gradient: _canSave
                        ? LinearGradient(
                            colors: [colors.brandStart, colors.brandEnd],
                          )
                        : null,
                    color: _canSave ? null : colors.glassFill,
                    border: _canSave
                        ? null
                        : Border.all(color: colors.glassBorder),
                    boxShadow: _canSave
                        ? [
                            BoxShadow(
                              color: colors.brandStart.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEditing ? 'Guardar cambios' : 'Crear meta',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _canSave
                                  ? Colors.white
                                  : colors.textTertiary,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
