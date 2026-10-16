
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/loans/domain/loan_progress.dart';
import 'package:pockt/features/loans/ui/loan_detail_buttons.dart';

class LoanHeroCard extends StatelessWidget {
  final Loan loan;
  final LoanProgress progress;

  const LoanHeroCard({super.key, required this.loan, required this.progress});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        children: [
          // Anillo con porcentaje en el centro
          SizedBox(
            width: 130,
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: progress.percent,
                    strokeWidth: 10,
                    backgroundColor: colors.glassBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress.isClosed ? colors.positive : colors.brandStart,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(progress.percent * 100).toInt()}%',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      progress.isClosed ? 'Completado' : 'Pagado',
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
          ),
          const SizedBox(height: 18),

          // Saldo pendiente
          Text(
            'Saldo pendiente',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatGs(progress.balance),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Métricas en 3 columnas
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: BorderRadius.circular(PocktRadii.l),
              border: Border.all(color: colors.glassBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: LoanMetricItem(
                    label: 'Total',
                    value: formatGs(loan.totalAmount),
                  ),
                ),
                Container(width: 1, height: 28, color: colors.glassBorder),
                Expanded(
                  child: LoanMetricItem(
                    label: 'Pagado',
                    value: formatGs(progress.paid),
                  ),
                ),
                Container(width: 1, height: 28, color: colors.glassBorder),
                Expanded(
                  child: LoanMetricItem(
                    label: 'Cuotas',
                    // Terminado con adelantos: no mostrar cuotas faltantes.
                    value: progress.isClosed
                        ? 'Pagado'
                        : loan.installmentsTotal != null
                        ? '${progress.installmentsPaid} de ${loan.installmentsTotal}'
                        : '${progress.installmentsPaid} pag.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Próximo vencimiento y fin estimado
          if (progress.nextDueDate != null || progress.estimatedEndDate != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (progress.nextDueDate != null) ...[
                  Icon(uiIcon('calendar'), size: 14, color: colors.brandStart),
                  const SizedBox(width: 6),
                  Text(
                    'Vence: ${DateFormat('dd/MM/yyyy').format(progress.nextDueDate!)}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                if (progress.nextDueDate != null &&
                    progress.estimatedEndDate != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '·',
                      style: TextStyle(color: colors.textTertiary),
                    ),
                  ),
                if (progress.estimatedEndDate != null)
                  Text(
                    'Fin est: ${formatMonthYear(progress.estimatedEndDate!)}',
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

class LoanPaymentRow extends StatelessWidget {
  final Transaction tx;

  const LoanPaymentRow({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isExtra = isLoanExtraPayment(tx);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: BorderRadius.circular(PocktRadii.l),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isExtra
                    ? colors.warning.withValues(alpha: 0.16)
                    : colors.brandStart.withValues(alpha: 0.16),
              ),
              child: Center(
                child: Icon(
                  isExtra ? uiIcon('sparkle') : uiIcon('check'),
                  size: 16,
                  color: isExtra ? colors.warning : colors.brandStart,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(tx.occurredAt),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (isExtra) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.warning.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(PocktRadii.s),
                          ),
                          child: Text(
                            'Extra',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (tx.note != null && tx.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      tx.note!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              formatGs(tx.amount),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
