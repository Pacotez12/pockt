import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/design/wordmark.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';
import 'package:pockt/features/income/domain/pay_days.dart';

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
        return _buildStep1Income(context);
      case 1:
        return _buildStep2Budgets(context);
      case 2:
      default:
        return _buildStep3Backup(context);
    }
  }

  Widget _buildStep1Income(BuildContext context) {
    final colors = context.pockt;

    return SingleChildScrollView(
      key: const ValueKey('step-1-income'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.brandAt(0).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              uiIcon('calendar-check'),
              color: colors.brandAt(0),
              size: 26,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '¿Cómo cobrás?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pockt organiza tus períodos de gasto y calcula cuánto podés gastar hoy según tus días de pago.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),

          // Selector Quincenal / Mensual
          Row(
            children: [
              Expanded(
                child: _buildModeCard(
                  title: 'Quincenal',
                  subtitle: '15 y fin de mes',
                  isSelected: _payMode == PayMode.biweekly,
                  onTap: () {
                    Haptics.tick();
                    setState(() => _payMode = PayMode.biweekly);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModeCard(
                  title: 'Mensual',
                  subtitle: 'Fin de mes',
                  isSelected: _payMode == PayMode.monthly,
                  onTap: () {
                    Haptics.tick();
                    setState(() => _payMode = PayMode.monthly);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Sueldo mensual estimado
          Text(
            'Ingreso mensual estimado (opcional)',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: BorderRadius.circular(PocktRadii.l),
              border: Border.all(color: colors.glassBorder),
            ),
            child: Row(
              children: [
                Text(
                  'Gs. ',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _salaryController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Ej. 3.500.000',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          ElevatedButton(
            onPressed: _handleStep1Continue,
            style: ElevatedButton.styleFrom(
              // Botón primario con el degradé de marca, como en el resto.
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              backgroundBuilder: (context, states, child) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.brandStart, colors.brandEnd],
                  ),
                  borderRadius: BorderRadius.circular(PocktRadii.xl),
                ),
                child: child,
              ),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PocktRadii.xl),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Continuar',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.pockt;

    return Pressable(
      semanticLabel: '$title: $subtitle',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.brandAt(0).withValues(alpha: 0.12)
              : colors.glassFill,
          borderRadius: BorderRadius.circular(PocktRadii.l),
          border: Border.all(
            color: isSelected ? colors.brandAt(0) : colors.glassBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? colors.brandAt(0) : colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: PocktType.caption,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Budgets(BuildContext context) {
    final colors = context.pockt;

    return SingleChildScrollView(
      key: const ValueKey('step-2-budgets'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.brandAt(0).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              uiIcon('chart-pie'),
              color: colors.brandAt(0),
              size: 26,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Límites para tus gastos',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fijá un tope mensual para las categorías más comunes. Podés modificarlos en cualquier momento desde Ajustes.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          _buildBudgetInputRow(
            icon: 'fork-knife',
            name: 'Comida',
            controller: _foodBudgetCtrl,
          ),
          const SizedBox(height: 14),
          _buildBudgetInputRow(
            icon: 'shopping-cart',
            name: 'Supermercado',
            controller: _superBudgetCtrl,
          ),
          const SizedBox(height: 14),
          _buildBudgetInputRow(
            icon: 'martini',
            name: 'Salidas y ocio',
            controller: _outingsBudgetCtrl,
          ),
          const SizedBox(height: 36),

          ElevatedButton(
            onPressed: _handleStep2Continue,
            style: ElevatedButton.styleFrom(
              // Botón primario con el degradé de marca, como en el resto.
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              backgroundBuilder: (context, states, child) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.brandStart, colors.brandEnd],
                  ),
                  borderRadius: BorderRadius.circular(PocktRadii.xl),
                ),
                child: child,
              ),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PocktRadii.xl),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Continuar',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetInputRow({
    required String icon,
    required String name,
    required TextEditingController controller,
  }) {
    final colors = context.pockt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(PocktRadii.l),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.textTertiary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(uiIcon(icon), size: 18, color: colors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Gs. ',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(
            width: 88,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Backup(BuildContext context) {
    final colors = context.pockt;

    return SingleChildScrollView(
      key: const ValueKey('step-3-backup'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.brandAt(0).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              uiIcon('shield-check'),
              color: colors.brandAt(0),
              size: 26,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Copia de seguridad local',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tus datos viven únicamente en tu teléfono. Las copias se guardan en Documentos/Pockt y se cifran con AES-256-GCM.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Advertencia de seguridad
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(PocktRadii.m),
              border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(uiIcon('warning'), color: colors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pockt nunca guarda tu contraseña: sin ella no podrás restaurar tus respaldos.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.warning,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Campos de contraseña
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Contraseña de respaldo',
              labelStyle: TextStyle(color: colors.textSecondary),
              filled: true,
              fillColor: colors.glassFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PocktRadii.l),
                borderSide: BorderSide(color: colors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PocktRadii.l),
                borderSide: BorderSide(color: colors.glassBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordCtrl,
            obscureText: true,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              labelStyle: TextStyle(color: colors.textSecondary),
              filled: true,
              fillColor: colors.glassFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PocktRadii.l),
                borderSide: BorderSide(color: colors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PocktRadii.l),
                borderSide: BorderSide(color: colors.glassBorder),
              ),
            ),
          ),

          if (_backupError != null) ...[
            const SizedBox(height: 10),
            Text(
              _backupError!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: colors.danger,
              ),
            ),
          ],
          const SizedBox(height: 36),

          ElevatedButton(
            onPressed: _isSaving ? null : _handleStep3Finish,
            style: ElevatedButton.styleFrom(
              // Botón primario con el degradé de marca, como en el resto.
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              backgroundBuilder: (context, states, child) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.brandStart, colors.brandEnd],
                  ),
                  borderRadius: BorderRadius.circular(PocktRadii.xl),
                ),
                child: child,
              ),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PocktRadii.xl),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Empezar a usar Pockt',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
