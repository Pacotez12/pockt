import 'package:flutter/material.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';

class OnboardingBudgetsStep extends StatelessWidget {
  final TextEditingController foodBudgetCtrl;
  final TextEditingController superBudgetCtrl;
  final TextEditingController outingsBudgetCtrl;
  final VoidCallback onContinue;

  const OnboardingBudgetsStep({
    super.key,
    required this.foodBudgetCtrl,
    required this.superBudgetCtrl,
    required this.outingsBudgetCtrl,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
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

          OnboardingBudgetInputRow(
            icon: 'fork-knife',
            name: 'Comida',
            controller: foodBudgetCtrl,
          ),
          const SizedBox(height: 14),
          OnboardingBudgetInputRow(
            icon: 'shopping-cart',
            name: 'Supermercado',
            controller: superBudgetCtrl,
          ),
          const SizedBox(height: 14),
          OnboardingBudgetInputRow(
            icon: 'martini',
            name: 'Salidas y ocio',
            controller: outingsBudgetCtrl,
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

class OnboardingBudgetInputRow extends StatelessWidget {
  final String icon;
  final String name;
  final TextEditingController controller;

  const OnboardingBudgetInputRow({
    super.key,
    required this.icon,
    required this.name,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
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
}
