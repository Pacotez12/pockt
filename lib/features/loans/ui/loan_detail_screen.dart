
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/domain/loan_progress.dart';
import 'package:pockt/features/loans/ui/loan_editor.dart';
import 'package:pockt/features/loans/ui/loan_detail_buttons.dart';
import 'package:pockt/features/loans/ui/loan_detail_cards.dart';
import 'package:pockt/features/loans/ui/loan_payment_sheet.dart';

export 'package:pockt/features/loans/ui/loan_detail_buttons.dart';
export 'package:pockt/features/loans/ui/loan_detail_cards.dart';
export 'package:pockt/features/loans/ui/loan_payment_sheet.dart';

class LoanDetailScreen extends ConsumerWidget {
  final String loanId;

  const LoanDetailScreen({super.key, required this.loanId});

  String formatGs(int amount) => formatGs(amount);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(loansRepositoryProvider);
    final loanAsync = ref.watch(loanProvider(loanId));
    final paymentsAsync = ref.watch(loanPaymentsProvider(loanId));

    final loan = loanAsync.value;
    if (loan == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(uiIcon('arrow-left'), color: colors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: loanAsync.isLoading
              ? const SizedBox()
              : Text(
                  'Préstamo no encontrado',
                  style: TextStyle(color: colors.textSecondary),
                ),
        ),
      );
    }

    final payments = paymentsAsync.value ?? [];
    final installmentsAsync = ref.watch(loanInstallmentsProvider(loanId));
    final schedule = installmentsAsync.value ?? [];
    final progress = calculateLoanProgress(
      loan: loan,
      payments: payments,
      schedule: schedule,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          loan.name,
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
        actions: [
          IconButton(
            icon: Icon(uiIcon('pencil-simple'), color: colors.textSecondary),
            onPressed: () {
              Haptics.tick();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoanEditorScreen(loanId: loanId),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(uiIcon('gear'), color: colors.textSecondary),
            color: colors.sheetSurface,
            onSelected: (val) async {
              if (val == 'toggle_close') {
                Haptics.save();
                if (loan.closedAt == null) {
                  await repo.closeLoan(loanId);
                } else {
                  await repo.reopenLoan(loanId);
                }
              } else if (val == 'delete') {
                Haptics.danger();
                final confirm = await _confirmDelete(context);
                if (confirm == true) {
                  await repo.deleteLoan(loanId);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'toggle_close',
                child: Text(
                  loan.closedAt == null
                      ? 'Marcar como terminado'
                      : 'Reabrir préstamo',
                  style: TextStyle(color: colors.textPrimary),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Eliminar préstamo',
                  style: TextStyle(color: colors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Contraparte si existe
            if (loan.counterparty != null && loan.counterparty!.isNotEmpty) ...[
              Center(
                child: Text(
                  loan.direction == LoanDirection.owe
                      ? 'Acreedor: ${loan.counterparty}'
                      : 'Prestatario: ${loan.counterparty}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Tarjeta principal con anillo y saldo
            LoanHeroCard(loan: loan, progress: progress),
            if (schedule.isNotEmpty && !progress.isClosed) ...[
              const SizedBox(height: 12),
              LoanNextInstallmentCard(loan: loan, progress: progress),
            ],
            if (schedule.isNotEmpty) ...[
              const SizedBox(height: 12),
              LoanScheduleCard(
                loan: loan,
                progress: progress,
                schedule: schedule,
              ),
            ],
            const SizedBox(height: 16),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: LoanPrimaryActionButton(
                    label: 'Registrar pago',
                    icon: 'plus',
                    color: colors.brandStart,
                    onTap: () => _showPaymentSheet(
                      context: context,
                      ref: ref,
                      loan: loan,
                      progress: progress,
                      isExtra: false,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: LoanSecondaryActionButton(
                    label: 'Pago extra / adelanto',
                    icon: 'sparkle',
                    onTap: () => _showPaymentSheet(
                      context: context,
                      ref: ref,
                      loan: loan,
                      progress: progress,
                      isExtra: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Historial de pagos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HISTORIAL DE PAGOS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: colors.textTertiary,
                  ),
                ),
                Text(
                  '${payments.length} movimiento${payments.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (progress.paidBeforeCount > 0)
              LoanPaidBeforeRow(
                count: progress.paidBeforeCount,
                amount: progress.paidBeforeAmount,
              ),
            if (payments.isEmpty && progress.paidBeforeCount == 0)
              GlassCard(
                padding: const EdgeInsets.symmetric(
                  vertical: 36,
                  horizontal: 20,
                ),
                borderRadius: BorderRadius.circular(PocktRadii.l),
                child: Center(
                  child: Text(
                    'Aún no registraste pagos para este préstamo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              ...payments.map((p) => LoanPaymentRow(tx: p)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showPaymentSheet({
    required BuildContext context,
    required WidgetRef ref,
    required Loan loan,
    required LoanProgress progress,
    required bool isExtra,
  }) {
    Haptics.tick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          LoanPaymentSheet(loan: loan, progress: progress, isExtra: isExtra),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    final colors = context.pockt;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.sheetSurface,
        title: Text(
          '¿Eliminar préstamo?',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          'El préstamo se eliminará. Los pagos ya registrados se conservarán como movimientos generales.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Eliminar',
              style: TextStyle(
                color: colors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
