import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/domain/loan_progress.dart';
import 'package:pockt/features/loans/ui/loan_editor.dart';

class LoanDetailScreen extends ConsumerWidget {
  final String loanId;

  const LoanDetailScreen({super.key, required this.loanId});

  String _formatGs(int amount) {
    final formatter = NumberFormat('#,###', 'es_PY');
    return '₲ ${formatter.format(amount)}';
  }

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
    final progress = calculateLoanProgress(loan: loan, payments: payments);

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
            _buildHeroCard(context, colors, loan, progress),
            const SizedBox(height: 16),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _PrimaryActionButton(
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
                  child: _SecondaryActionButton(
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
            if (payments.isEmpty)
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
              ...payments.map((p) => _buildPaymentRow(colors, p)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    PocktColors colors,
    Loan loan,
    LoanProgress progress,
  ) {
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
            _formatGs(progress.balance),
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
                  child: _MetricItem(
                    label: 'Total',
                    value: _formatGs(loan.totalAmount),
                  ),
                ),
                Container(width: 1, height: 28, color: colors.glassBorder),
                Expanded(
                  child: _MetricItem(
                    label: 'Pagado',
                    value: _formatGs(progress.paid),
                  ),
                ),
                Container(width: 1, height: 28, color: colors.glassBorder),
                Expanded(
                  child: _MetricItem(
                    label: 'Cuotas',
                    value: loan.installmentsTotal != null
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

  Widget _buildPaymentRow(PocktColors colors, Transaction tx) {
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
              _formatGs(tx.amount),
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
          _PaymentModalSheet(loan: loan, progress: progress, isExtra: isExtra),
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

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;

  const _MetricItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: colors.textTertiary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final String icon;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PocktRadii.l),
          color: color,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(uiIcon(icon), size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final String label;
  final String icon;
  final VoidCallback onTap;

  const _SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PocktRadii.l),
          color: colors.glassFill,
          border: Border.all(color: colors.glassBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(uiIcon(icon), size: 16, color: colors.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentModalSheet extends ConsumerStatefulWidget {
  final Loan loan;
  final LoanProgress progress;
  final bool isExtra;

  const _PaymentModalSheet({
    required this.loan,
    required this.progress,
    required this.isExtra,
  });

  @override
  ConsumerState<_PaymentModalSheet> createState() => _PaymentModalSheetState();
}

class _PaymentModalSheetState extends ConsumerState<_PaymentModalSheet> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  DateTime _date = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final defaultAmount = widget.loan.installmentAmount != null
        ? min(
            widget.loan.installmentAmount!,
            max(1, widget.progress.balance),
          ).toString()
        : (widget.progress.balance > 0
              ? widget.progress.balance.toString()
              : '');

    _amountController = TextEditingController(text: defaultAmount);
    _noteController = TextEditingController(
      text: widget.isExtra ? 'Pago extra' : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(
      _amountController.text.replaceAll('.', '').trim(),
    );
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresá un monto válido')));
      return;
    }

    setState(() => _isLoading = true);
    Haptics.save();

    try {
      final repo = ref.read(loansRepositoryProvider);
      await repo.recordPayment(
        loanId: widget.loan.id,
        amount: amount,
        date: _date,
        isExtra: widget.isExtra,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al registrar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.sheetSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isExtra
                  ? 'Registrar pago extra / adelanto'
                  : 'Registrar pago de cuota',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Monto a pagar',
                prefixText: '₲ ',
                prefixStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PocktRadii.l),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nota o referencia (opcional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PocktRadii.l),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fecha del pago:',
                  style: TextStyle(color: colors.textSecondary),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_date),
                    style: TextStyle(
                      color: colors.brandStart,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brandStart,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PocktRadii.l),
                ),
              ),
              child: Text(
                widget.isExtra ? 'Guardar pago extra' : 'Guardar pago',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
