import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/amounts_privacy.dart';
import 'package:pockt/features/home/data/home_providers.dart';
import 'package:pockt/features/income/ui/income_schedule_screen.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';

/// Tarjeta compacta "Podés gastar hoy" para la portada con Arco por categoría:
/// - Título y monto en la misma fila.
/// - Barrita de lo gastado hoy vs el permitido del día con degradé de marca.
/// - Fila chica: "gastaste hoy Gs. X · cobrás en N días".
/// - Sin esquema de cobro: invitación a configurarlo ("Configurá cuándo cobrás…").
class CompactSafeToSpendCard extends ConsumerWidget {
  final DateTime nowLocal;

  const CompactSafeToSpendCard({
    super.key,
    required this.nowLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final obscure = ref.watch(shouldObscureAmountsProvider);
    final safe = ref.watch(safeToSpendProvider).value;
    final periodSummary = ref.watch(homePeriodSummaryProvider(nowLocal));

    if (safe == null || !safe.hasIncomeSchedule) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Pressable(
          key: const ValueKey('home-setup-payday'),
          semanticLabel: 'Configurá cuándo cobrás',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const IncomeScheduleScreen()),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Configurá cuándo cobrás para ver cuánto te queda',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: PocktType.caption,
                    color: colors.textSecondary,
                  ),
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

    final double ratio;
    if (safe.todayAllowance > 0) {
      ratio = (safe.spentToday / safe.todayAllowance).clamp(0.0, 1.0);
    } else {
      ratio = safe.spentToday > 0 ? 1.0 : 0.0;
    }

    final String payDayText;
    if (periodSummary.periodLine != null) {
      payDayText = periodSummary.periodLine!.payDayText;
    } else if (safe.daysUntilPay > 0) {
      payDayText = 'cobrás en ${safe.daysUntilPay} días';
    } else {
      payDayText = '';
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Podés gastar hoy',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                obscure ? '••••' : formatGs(safe.todayAllowance),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(
            height: 5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: colors.glassBorder.withValues(alpha: isDark ? 0.20 : 0.10),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: [colors.brandStart, colors.brandEnd],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'gastaste hoy ${obscure ? "••••" : formatGs(safe.spentToday)}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: colors.textTertiary,
                ),
              ),
              if (payDayText.isNotEmpty)
                Text(
                  payDayText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
