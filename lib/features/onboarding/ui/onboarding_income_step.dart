import 'package:flutter/material.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/income/domain/pay_days.dart';

class OnboardingIncomeStep extends StatelessWidget {
  final PayMode payMode;
  final ValueChanged<PayMode> onPayModeChanged;
  final TextEditingController salaryController;
  final VoidCallback onContinue;

  const OnboardingIncomeStep({
    super.key,
    required this.payMode,
    required this.onPayModeChanged,
    required this.salaryController,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
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
                child: OnboardingModeCard(
                  title: 'Quincenal',
                  subtitle: '15 y fin de mes',
                  isSelected: payMode == PayMode.biweekly,
                  onTap: () {
                    Haptics.tick();
                    onPayModeChanged(PayMode.biweekly);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OnboardingModeCard(
                  title: 'Mensual',
                  subtitle: 'Fin de mes',
                  isSelected: payMode == PayMode.monthly,
                  onTap: () {
                    Haptics.tick();
                    onPayModeChanged(PayMode.monthly);
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
                    controller: salaryController,
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
            onPressed: onContinue,
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
}

class OnboardingModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const OnboardingModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
}
