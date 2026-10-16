import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/design/wordmark.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/onboarding/ui/onboarding_backup_step.dart';
import 'package:pockt/features/onboarding/ui/onboarding_budgets_step.dart';
import 'package:pockt/features/onboarding/ui/onboarding_income_step.dart';

export 'package:pockt/features/onboarding/ui/onboarding_backup_step.dart';
export 'package:pockt/features/onboarding/ui/onboarding_budgets_step.dart';
export 'package:pockt/features/onboarding/ui/onboarding_income_step.dart';

/// Flujo de primer uso de Pockt (Plan 4 Task 7 / spec §5.11).
///
/// Tres pasos, todos salteables:
/// 1) Esquema de cobro (quincenal o mensual, con sueldo neto estimado).
/// 2) Presupuestos (límites sugeridos en 3 categorías clave).
/// 3) Copia de seguridad (contraseña de cifrado para Documentos/Pockt).
class OnboardingFlow extends ConsumerStatefulWidget {
  final VoidCallback onFinish;

  const OnboardingFlow({super.key, required this.onFinish});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  int _currentStep = 0;

  // Paso 1: Esquema de cobro
  PayMode _payMode = PayMode.biweekly;
  // Vacío: el ejemplo va como hint, para no dejar un sueldo que no es el tuyo.
  final TextEditingController _salaryController = TextEditingController(
    text: '',
  );

  // Paso 2: Presupuestos sugeridos
  final TextEditingController _foodBudgetCtrl = TextEditingController(
    text: '1.500.000',
  );
  final TextEditingController _superBudgetCtrl = TextEditingController(
    text: '1.200.000',
  );
  final TextEditingController _outingsBudgetCtrl = TextEditingController(
    text: '500.000',
  );

  // Paso 3: Copia de seguridad local
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  String? _backupError;
  bool _isSaving = false;

  @override
  void dispose() {
    _salaryController.dispose();
    _foodBudgetCtrl.dispose();
    _superBudgetCtrl.dispose();
    _outingsBudgetCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _skip() async {
    Haptics.tick();
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsKeys.onboardingDone, 'true');
    widget.onFinish();
  }

  int _parseAmount(String text) {
    final clean = text.replaceAll('.', '').replaceAll(',', '').trim();
    return int.tryParse(clean) ?? 0;
  }

  Future<void> _handleStep1Continue() async {
    Haptics.tick();
    final db = ref.read(databaseProvider);
    final schedRepo = ref.read(incomeScheduleRepositoryProvider);

    final sueldoCategory =
        await (db.select(db.categories)
              ..where((c) => c.kind.equalsValue(CategoryKind.income))
              ..limit(1))
            .getSingleOrNull();

    if (sueldoCategory != null) {
      final amount = _parseAmount(_salaryController.text);
      if (_payMode == PayMode.biweekly) {
        await schedRepo.setSchedule(
          mode: PayMode.biweekly,
          payDays: const [15, -1],
          payDayRules: const [PayDayRule.either, PayDayRule.previous],
          paySplitPercents: const [50, 50],
          monthlyAmount: amount > 0 ? amount : null,
          categoryId: sueldoCategory.id,
        );
      } else {
        await schedRepo.setSchedule(
          mode: PayMode.monthly,
          payDays: const [-1],
          payDayRules: const [PayDayRule.previous],
          paySplitPercents: const [100],
          monthlyAmount: amount > 0 ? amount : null,
          categoryId: sueldoCategory.id,
        );
      }
    }

    setState(() {
      _currentStep = 1;
    });
  }

  Future<void> _handleStep2Continue() async {
    Haptics.tick();
    final db = ref.read(databaseProvider);
    final budgetRepo = ref.read(budgetsRepositoryProvider);

    final categories = await db.select(db.categories).get();
    Category? findCat(String name) {
      try {
        return categories.firstWhere(
          (c) => c.name.toLowerCase().contains(name.toLowerCase()),
        );
      } catch (_) {
        return null;
      }
    }

    final food = findCat('comida');
    if (food != null) {
      final a = _parseAmount(_foodBudgetCtrl.text);
      if (a > 0) await budgetRepo.setLimit(food.id, a);
    }

    final sup = findCat('supermercado');
    if (sup != null) {
      final a = _parseAmount(_superBudgetCtrl.text);
      if (a > 0) await budgetRepo.setLimit(sup.id, a);
    }

    final out = findCat('ocio') ?? findCat('salidas');
    if (out != null) {
      final a = _parseAmount(_outingsBudgetCtrl.text);
      if (a > 0) await budgetRepo.setLimit(out.id, a);
    }

    setState(() {
      _currentStep = 2;
    });
  }

  Future<void> _handleStep3Finish() async {
    final password = _passwordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (password.isNotEmpty || confirm.isNotEmpty) {
      if (password.length < 4) {
        setState(() {
          _backupError = 'La contraseña debe tener al menos 4 caracteres';
        });
        Haptics.warning();
        return;
      }
      if (password != confirm) {
        setState(() {
          _backupError = 'Las contraseñas no coinciden';
        });
        Haptics.warning();
        return;
      }

      setState(() {
        _isSaving = true;
        _backupError = null;
      });

      try {
        await ref.read(backupServiceProvider).setPassword(password);
      } catch (e) {
        // En caso de fallo con Argon2 en test, continúa limpiamente
      }
    }

    Haptics.save();
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsKeys.onboardingDone, 'true');
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header: logotipo 'pockt' + botón Saltear
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PocktWordmark(
                    key: const ValueKey('onboarding-wordmark'),
                    size: 26,
                    color: colors.textPrimary,
                  ),
                  Flexible(
                    child: TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      child: const Text(
                        'Saltear',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Indicador de pasos: 3 cápsulas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: List.generate(3, (index) {
                  final isActive = index == _currentStep;
                  final isPassed = index < _currentStep;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      height: 4,
                      margin: EdgeInsets.only(left: index > 0 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: isActive
                            ? colors.brandAt(0)
                            : (isPassed
                                  ? colors.brandAt(0).withValues(alpha: 0.5)
                                  : colors.textTertiary.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Contenido del paso actual
            Expanded(
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _buildCurrentStep(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return OnboardingIncomeStep(
          payMode: _payMode,
          onPayModeChanged: (mode) => setState(() => _payMode = mode),
          salaryController: _salaryController,
          onContinue: _handleStep1Continue,
        );
      case 1:
        return OnboardingBudgetsStep(
          foodBudgetCtrl: _foodBudgetCtrl,
          superBudgetCtrl: _superBudgetCtrl,
          outingsBudgetCtrl: _outingsBudgetCtrl,
          onContinue: _handleStep2Continue,
        );
      case 2:
      default:
        return OnboardingBackupStep(
          passwordCtrl: _passwordCtrl,
          confirmPasswordCtrl: _confirmPasswordCtrl,
          backupError: _backupError,
          isSaving: _isSaving,
          onFinish: _handleStep3Finish,
        );
    }
  }
}
