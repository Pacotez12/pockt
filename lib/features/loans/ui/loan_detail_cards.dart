
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/motion.dart';
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

class LoanPaidBeforeRow extends StatelessWidget {
  final int count;
  final int amount;

  const LoanPaidBeforeRow({
    super.key,
    required this.count,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final label = count == 1
        ? 'Cuota 1 · antes de Pockt'
        : 'Cuotas 1–$count · antes de Pockt';

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
                color: colors.textSecondary.withValues(alpha: 0.12),
              ),
              child: Center(
                child: Icon(
                  uiIcon('clock-counter-clockwise'),
                  size: 16,
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Text(
              formatGs(amount),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoanNextInstallmentCard extends StatelessWidget {
  final Loan loan;
  final LoanProgress progress;

  const LoanNextInstallmentCard({
    super.key,
    required this.loan,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final nextInst = progress.nextInstallment;
    if (nextInst == null) return const SizedBox.shrink();

    final k = nextInst.number;
    final total = loan.installmentsTotal ?? k;
    final amountFormatted = formatGs(nextInst.amount);
    final dueFormatted =
        '${nextInst.dueDate.day.toString().padLeft(2, '0')}/${nextInst.dueDate.month.toString().padLeft(2, '0')}';

    final days = progress.daysUntilNextDue;
    final String daysText;
    if (days != null) {
      if (days > 1) {
        daysText = 'en $days días';
      } else if (days == 1) {
        daysText = 'mañana';
      } else if (days == 0) {
        daysText = 'hoy';
      } else {
        daysText = 'hace ${-days} días';
      }
    } else {
      daysText = '';
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(PocktRadii.xl),
        border: Border.all(
          color: colors.brandStart.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Próxima cuota · $k de $total',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              if (daysText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.textPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(PocktRadii.s),
                  ),
                  child: Text(
                    daysText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                amountFormatted,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                'vence $dueFormatted',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LoanScheduleCard extends StatefulWidget {
  final Loan loan;
  final LoanProgress progress;
  final List<LoanInstallment> schedule;

  const LoanScheduleCard({
    super.key,
    required this.loan,
    required this.progress,
    required this.schedule,
  });

  @override
  State<LoanScheduleCard> createState() => _LoanScheduleCardState();
}

class _LoanScheduleCardState extends State<LoanScheduleCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final schedule = widget.schedule;
    if (schedule.isEmpty) return const SizedBox.shrink();

    final totalCount = schedule.length;
    final currentIdx = widget.progress.installmentsPaid;

    List<LoanInstallment> visibleItems;
    if (_isExpanded || totalCount <= 5) {
      visibleItems = schedule;
    } else {
      final startIndex = max(0, min(currentIdx - 2, totalCount - 5));
      visibleItems = schedule.sublist(startIndex, startIndex + 5);
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cronograma',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  '$totalCount cuotas',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (int i = 0; i < visibleItems.length; i++) ...[
                  _buildInstallmentRow(visibleItems[i], colors),
                  if (i < visibleItems.length - 1)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: colors.glassBorder,
                    ),
                ],
              ],
            ),
          ),
          if (totalCount > 5) ...[
            const SizedBox(height: 4),
            Pressable(
              onTap: () {
                Haptics.tick();
                setState(() => _isExpanded = !_isExpanded);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    _isExpanded ? 'Ver menos' : 'Ver las $totalCount',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.brandStart,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstallmentRow(LoanInstallment inst, PocktColors colors) {
    final isPaid = inst.number <= widget.progress.installmentsPaid;
    final isNext = !widget.progress.isClosed &&
        inst.number == widget.progress.installmentsPaid + 1;

    final dateStr =
        '${inst.dueDate.day.toString().padLeft(2, '0')}/${inst.dueDate.month.toString().padLeft(2, '0')}/${inst.dueDate.year}';
    final amountStr = formatGs(inst.amount, symbol: false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Dot indicator
          if (isPaid)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.positive.withValues(alpha: 0.20),
              ),
              child: Center(
                child: Icon(
                  uiIcon('check'),
                  size: 12,
                  color: colors.positive,
                ),
              ),
            )
          else if (isNext)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.brandStart, width: 2),
              ),
            )
          else
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.textPrimary.withValues(alpha: 0.20),
                  width: 1.2,
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cuota ${inst.number} · $dateStr',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: isNext ? FontWeight.w600 : FontWeight.w400,
                color: isPaid
                    ? colors.textTertiary
                    : (isNext ? colors.textPrimary : colors.textSecondary),
              ),
            ),
          ),
          Text(
            amountStr,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
              decoration: isPaid ? TextDecoration.lineThrough : null,
              decorationColor: colors.textTertiary,
              color: isPaid
                  ? colors.textTertiary
                  : (isNext ? colors.textPrimary : colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
