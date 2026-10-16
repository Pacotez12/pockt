import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/domain/loan_progress.dart';

class LoanPaymentSheet extends ConsumerStatefulWidget {
  final Loan loan;
  final LoanProgress progress;
  final bool isExtra;

  const LoanPaymentSheet({
    super.key,
    required this.loan,
    required this.progress,
    required this.isExtra,
  });

  @override
  ConsumerState<LoanPaymentSheet> createState() => LoanPaymentSheetState();
}

class LoanPaymentSheetState extends ConsumerState<LoanPaymentSheet> {
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
                prefixText: 'Gs. ',
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
