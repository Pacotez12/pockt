import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/domain/installment_schedule_parser.dart';

class LoanEditorScreen extends ConsumerStatefulWidget {
  final String? loanId;

  const LoanEditorScreen({super.key, this.loanId});

  @override
  ConsumerState<LoanEditorScreen> createState() => _LoanEditorScreenState();
}

enum _InstallmentMode { fixed, schedule }

class _LoanEditorScreenState extends ConsumerState<LoanEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  LoanDirection _direction = LoanDirection.owe;
  LoanKind _kind = LoanKind.installments;
  _InstallmentMode _installmentMode = _InstallmentMode.fixed;

  final _nameController = TextEditingController();
  final _counterpartyController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _installmentAmountController = TextEditingController();
  final _installmentsTotalController = TextEditingController();
  final _dueDayController = TextEditingController();
  final _scheduleController = TextEditingController();
  InstallmentScheduleParseResult? _scheduleResult;
  int _paidBeforeCount = 0;
  Loan? _initialLoan;
  String _initialScheduleText = '';

  DateTime _startDate = DateTime.now();
  int _reminderDays = 2;
  bool _recordInitialDisbursement = false;
  bool _calculateFromInstallments = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.loanId != null) {
      _loadExistingLoan();
    }
  }

  Future<void> _loadExistingLoan() async {
    final loan = await ref
        .read(loansRepositoryProvider)
        .getLoan(widget.loanId!);
    if (loan == null || !mounted) return;

    _initialLoan = loan;
    setState(() {
      _direction = loan.direction;
      _kind = loan.kind;
      _paidBeforeCount = loan.paidBeforeCount;
      _nameController.text = loan.name;
      _counterpartyController.text = loan.counterparty ?? '';
      _totalAmountController.text = loan.totalAmount.toString();
      if (loan.installmentAmount != null) {
        _installmentAmountController.text = loan.installmentAmount.toString();
      }
      if (loan.installmentsTotal != null) {
        _installmentsTotalController.text = loan.installmentsTotal.toString();
      }
      if (loan.dueDay != null) {
        _dueDayController.text = loan.dueDay.toString();
      }
      _startDate = loan.startDate;
      _reminderDays = loan.reminderDays;
    });

    final installments = await ref
        .read(loansRepositoryProvider)
        .getInstallments(widget.loanId!);
    if (installments.isNotEmpty && mounted) {
      setState(() {
        _installmentMode = _InstallmentMode.schedule;
        _scheduleController.text = formatInstallmentSchedule(
          installments
              .map((i) => ParsedInstallment(
                    number: i.number,
                    dueDate: i.dueDate,
                    amount: i.amount,
                  ))
              .toList(),
        );
        _initialScheduleText = _scheduleController.text;
        _scheduleResult = parseInstallmentSchedule(_scheduleController.text);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _counterpartyController.dispose();
    _totalAmountController.dispose();
    _installmentAmountController.dispose();
    _installmentsTotalController.dispose();
    _dueDayController.dispose();
    _scheduleController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    if (widget.loanId == null) {
      return _nameController.text.trim().isNotEmpty ||
          _counterpartyController.text.trim().isNotEmpty ||
          _totalAmountController.text.trim().isNotEmpty ||
          _installmentAmountController.text.trim().isNotEmpty ||
          _installmentsTotalController.text.trim().isNotEmpty ||
          _dueDayController.text.trim().isNotEmpty ||
          _scheduleController.text.trim().isNotEmpty ||
          _paidBeforeCount > 0 ||
          _recordInitialDisbursement ||
          _direction != LoanDirection.owe ||
          _kind != LoanKind.installments ||
          _installmentMode != _InstallmentMode.fixed;
    }
    if (_initialLoan == null) return false;
    return _nameController.text.trim() != _initialLoan!.name ||
        _counterpartyController.text.trim() !=
            (_initialLoan!.counterparty ?? '') ||
        _totalAmountController.text.trim() !=
            _initialLoan!.totalAmount.toString() ||
        _installmentAmountController.text.trim() !=
            (_initialLoan!.installmentAmount?.toString() ?? '') ||
        _installmentsTotalController.text.trim() !=
            (_initialLoan!.installmentsTotal?.toString() ?? '') ||
        _dueDayController.text.trim() !=
            (_initialLoan!.dueDay?.toString() ?? '') ||
        _paidBeforeCount != _initialLoan!.paidBeforeCount ||
        _reminderDays != _initialLoan!.reminderDays ||
        _scheduleController.text.trim() != _initialScheduleText;
  }

  Future<bool> _handlePop() async {
    if (!_hasChanges) return true;
    final colors = context.pockt;
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.sheetSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PocktRadii.xl),
        ),
        title: Text(
          '¿Descartar el préstamo?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'Si salís ahora se pierde lo que cargaste.',
          style: TextStyle(
            fontFamily: 'Inter',
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Seguir editando',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Descartar',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                color: colors.danger,
              ),
            ),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  void _recalculateTotalIfNeeded() {
    _clampPaidBeforeCount();
    if (!_calculateFromInstallments) return;
    final instAmount = int.tryParse(
      _installmentAmountController.text.replaceAll('.', '').trim(),
    );
    final count = int.tryParse(_installmentsTotalController.text.trim());
    if (instAmount != null && count != null && count > 0) {
      final total = instAmount * count;
      _totalAmountController.text = total.toString();
    }
  }

  void _clampPaidBeforeCount() {
    final int maxInstallments;
    if (_installmentMode == _InstallmentMode.schedule) {
      maxInstallments = _scheduleResult?.installments.length ?? 0;
    } else {
      maxInstallments =
          int.tryParse(_installmentsTotalController.text.trim()) ?? 0;
    }
    if (maxInstallments > 0 && _paidBeforeCount > maxInstallments) {
      setState(() => _paidBeforeCount = maxInstallments);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ingresá un nombre')));
      return;
    }

    final isScheduleMode = _kind == LoanKind.installments &&
        _installmentMode == _InstallmentMode.schedule;

    int? totalAmount;
    int? instAmount;
    int? instTotal;
    int? dueDay;
    List<ParsedInstallment>? scheduleToSave;

    if (isScheduleMode) {
      final res = parseInstallmentSchedule(_scheduleController.text);
      if (res.installments.isEmpty && res.lineErrors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pegá el cronograma con al menos una cuota')),
        );
        return;
      }
      if (!res.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Corregí los errores del cronograma antes de guardar')),
        );
        return;
      }
      scheduleToSave = res.installments;
      totalAmount = res.totalAmount;
      instTotal = res.installments.length;
      instAmount = null;
      dueDay = res.installments.first.dueDate.day;
    } else {
      totalAmount = int.tryParse(
        _totalAmountController.text.replaceAll('.', '').trim(),
      );
      if (totalAmount == null || totalAmount <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ingresá un monto válido')));
        return;
      }

      instAmount = int.tryParse(
        _installmentAmountController.text.replaceAll('.', '').trim(),
      );
      instTotal = int.tryParse(_installmentsTotalController.text.trim());
      dueDay = int.tryParse(_dueDayController.text.trim());
    }

    setState(() => _isLoading = true);
    Haptics.save();

    final repo = ref.read(loansRepositoryProvider);

    try {
      final paidBefore = _kind == LoanKind.installments ? _paidBeforeCount : 0;
      if (widget.loanId == null) {
        await repo.createLoan(
          direction: _direction,
          kind: _kind,
          name: name,
          counterparty: _counterpartyController.text.trim().isEmpty
              ? null
              : _counterpartyController.text.trim(),
          totalAmount: totalAmount,
          installmentAmount: instAmount,
          installmentsTotal: instTotal,
          dueDay: dueDay,
          paidBeforeCount: paidBefore,
          startDate: _startDate,
          reminderDays: _reminderDays,
          recordInitialDisbursement: _recordInitialDisbursement,
          schedule: scheduleToSave,
        );
      } else {
        await repo.updateLoan(
          id: widget.loanId!,
          name: name,
          counterparty: _counterpartyController.text.trim().isEmpty
              ? null
              : _counterpartyController.text.trim(),
          totalAmount: totalAmount,
          installmentAmount: instAmount,
          installmentsTotal: instTotal,
          dueDay: dueDay,
          paidBeforeCount: paidBefore,
          reminderDays: _reminderDays,
          // Lista vacía borra el cronograma si se pasó a monto fijo.
          schedule: isScheduleMode ? scheduleToSave : const [],
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canLeave = await _handlePop();
        if (canLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.loanId == null ? 'Nuevo préstamo' : 'Editar préstamo',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          leading: IconButton(
            key: const ValueKey('loan-editor-back'),
            icon: Icon(uiIcon('arrow-left'), color: colors.textPrimary),
            onPressed: () async {
              final canLeave = await _handlePop();
              if (canLeave && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isLoading ? null : _save,
              child: Text(
                'Guardar',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.brandStart,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Segmented Debo / Presté
              if (widget.loanId == null) ...[
                _buildDirectionSelector(colors),
                const SizedBox(height: 16),
              ],

              // Tipo: Préstamo o En cuotas
              _buildKindSelector(colors),
              const SizedBox(height: 16),

              if (_kind == LoanKind.installments) ...[
                _buildInstallmentModeSelector(colors),
                const SizedBox(height: 16),
              ],

              // Nombre y contraparte
              GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(PocktRadii.xl),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: colors.textPrimary, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Nombre o concepto',
                        labelStyle: TextStyle(color: colors.textSecondary),
                        hintText: _kind == LoanKind.installments
                            ? 'Ej: Heladera, Celular'
                            : 'Ej: Préstamo personal',
                        hintStyle: TextStyle(color: colors.textTertiary),
                        border: InputBorder.none,
                      ),
                    ),
                    Divider(color: colors.glassBorder, height: 20),
                    TextField(
                      controller: _counterpartyController,
                      style: TextStyle(color: colors.textPrimary, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: _direction == LoanDirection.owe
                            ? 'Acreedor / Comercio (opcional)'
                            : 'Prestatario (opcional)',
                        labelStyle: TextStyle(color: colors.textSecondary),
                        hintText: _direction == LoanDirection.owe
                            ? 'Ej: Bristol, Banco'
                            : 'Ej: Juan, Mamá',
                        hintStyle: TextStyle(color: colors.textTertiary),
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Montos y cuotas
              if (_kind == LoanKind.installments &&
                  _installmentMode == _InstallmentMode.schedule) ...[
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(PocktRadii.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 2),
                      Text(
                        'Pegá una cuota por línea: número fecha monto',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('schedule-input'),
                        controller: _scheduleController,
                        maxLines: 6,
                        minLines: 4,
                        keyboardType: TextInputType.multiline,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          color: colors.textPrimary,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              '1 02/01/2027 905.000\n2 02/02/2027 805.000\n3 02/03/2027 705.000',
                          hintStyle: TextStyle(
                            color: colors.textTertiary,
                            fontFamily: 'monospace',
                          ),
                          filled: true,
                          fillColor: colors.glassFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(PocktRadii.m),
                            borderSide: BorderSide(color: colors.glassBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(PocktRadii.m),
                            borderSide: BorderSide(color: colors.glassBorder),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _scheduleResult = parseInstallmentSchedule(val);
                            _clampPaidBeforeCount();
                          });
                        },
                      ),
                      if (_scheduleResult != null &&
                          _scheduleResult!.lineErrors.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(PocktRadii.m),
                            border: Border.all(
                              color: colors.danger.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final entry
                                  in _scheduleResult!.lineErrors.entries)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    'Línea ${entry.key}: ${entry.value}',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.danger,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ] else if (_scheduleResult != null &&
                          _scheduleResult!.isValid) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.glassFill,
                            borderRadius: BorderRadius.circular(PocktRadii.m),
                            border: Border.all(color: colors.glassBorder),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Se leyeron',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    _scheduleResult!.installments.length == 1
                                        ? '1 cuota'
                                        : '${_scheduleResult!.installments.length} cuotas',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    formatGs(_scheduleResult!.totalAmount),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Vence',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    'día ${_scheduleResult!.installments.first.dueDate.day} · ${formatMonthYear(_scheduleResult!.installments.first.dueDate)} → ${formatMonthYear(_scheduleResult!.installments.last.dueDate)}',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildPaidBeforeSelector(colors),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(PocktRadii.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_kind == LoanKind.installments) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Calcular total desde cuotas',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: colors.textSecondary,
                              ),
                            ),
                            Switch(
                              value: _calculateFromInstallments,
                              onChanged: (val) {
                                Haptics.tick();
                                setState(() {
                                  _calculateFromInstallments = val;
                                  _recalculateTotalIfNeeded();
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _installmentAmountController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Monto de cuota',
                                  labelStyle: TextStyle(
                                    color: colors.textSecondary,
                                  ),
                                  prefixText: 'Gs. ',
                                  prefixStyle: TextStyle(
                                    color: colors.textPrimary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      PocktRadii.m,
                                    ),
                                  ),
                                ),
                                onChanged: (_) => _recalculateTotalIfNeeded(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _installmentsTotalController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Cant. cuotas',
                                  labelStyle: TextStyle(
                                    color: colors.textSecondary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      PocktRadii.m,
                                    ),
                                  ),
                                ),
                                onChanged: (_) => _recalculateTotalIfNeeded(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _totalAmountController,
                        keyboardType: TextInputType.number,
                        readOnly: _calculateFromInstallments,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              'Monto total a ${_direction == LoanDirection.owe ? 'pagar' : 'cobrar'}',
                          labelStyle: TextStyle(color: colors.textSecondary),
                          prefixText: 'Gs. ',
                          prefixStyle: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(PocktRadii.m),
                          ),
                        ),
                      ),
                      if (_kind == LoanKind.installments)
                        _buildPaidBeforeSelector(colors),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Vencimiento y fechas
              GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(PocktRadii.xl),
                child: Column(
                  children: [
                    if (!(_kind == LoanKind.installments &&
                        _installmentMode == _InstallmentMode.schedule)) ...[
                      TextField(
                        controller: _dueDayController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: colors.textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Día del mes de vencimiento (1 - 31)',
                          labelStyle: TextStyle(color: colors.textSecondary),
                          hintText: 'Ej: 15 para el 15 de cada mes',
                          hintStyle: TextStyle(color: colors.textTertiary),
                          border: InputBorder.none,
                        ),
                      ),
                      Divider(color: colors.glassBorder, height: 20),
                    ],
                    Pressable(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2040),
                        );
                        if (picked != null) {
                          setState(() => _startDate = picked);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Fecha de inicio',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: colors.textSecondary,
                              ),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_startDate),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Si es Presté y es alta nueva: opción de desembolso inicial
              if (widget.loanId == null &&
                  _direction == LoanDirection.lent) ...[
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(PocktRadii.xl),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registrar salida de dinero',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Crea un gasto por el total entregado hoy',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _recordInitialDisbursement,
                        onChanged: (val) {
                          Haptics.tick();
                          setState(() => _recordInitialDisbursement = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildPaidBeforeSelector(PocktColors colors) {
    final int maxInstallments;
    final int paidBeforeGs;

    if (_installmentMode == _InstallmentMode.schedule) {
      maxInstallments = _scheduleResult?.installments.length ?? 0;
      if (_scheduleResult != null && _scheduleResult!.isValid) {
        paidBeforeGs = _scheduleResult!.installments
            .take(_paidBeforeCount)
            .fold<int>(0, (sum, i) => sum + i.amount);
      } else {
        paidBeforeGs = 0;
      }
    } else {
      maxInstallments =
          int.tryParse(_installmentsTotalController.text.trim()) ?? 0;
      final instAmount = int.tryParse(
            _installmentAmountController.text.replaceAll('.', '').trim(),
          ) ??
          0;
      paidBeforeGs = _paidBeforeCount * instAmount;
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cuotas que ya pagaste antes de usar Pockt',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: BorderRadius.circular(PocktRadii.m),
              border: Border.all(color: colors.glassBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Pressable(
                  key: const ValueKey('paid-before-dec'),
                  onTap: _paidBeforeCount > 0
                      ? () {
                          Haptics.tick();
                          setState(() => _paidBeforeCount--);
                        }
                      : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _paidBeforeCount > 0
                          ? colors.textPrimary.withValues(alpha: 0.10)
                          : colors.textPrimary.withValues(alpha: 0.04),
                    ),
                    child: Center(
                      child: Icon(
                        uiIcon('minus'),
                        size: 16,
                        color: _paidBeforeCount > 0
                            ? colors.textPrimary
                            : colors.textTertiary,
                      ),
                    ),
                  ),
                ),
                Text(
                  '$_paidBeforeCount',
                  key: const ValueKey('paid-before-count'),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Pressable(
                  key: const ValueKey('paid-before-inc'),
                  onTap: (maxInstallments == 0 ||
                          _paidBeforeCount < maxInstallments)
                      ? () {
                          Haptics.tick();
                          setState(() => _paidBeforeCount++);
                        }
                      : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (maxInstallments == 0 ||
                              _paidBeforeCount < maxInstallments)
                          ? colors.textPrimary.withValues(alpha: 0.10)
                          : colors.textPrimary.withValues(alpha: 0.04),
                    ),
                    child: Center(
                      child: Icon(
                        uiIcon('plus'),
                        size: 16,
                        color: (maxInstallments == 0 ||
                                _paidBeforeCount < maxInstallments)
                            ? colors.textPrimary
                            : colors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cuentan como pagadas (${formatGs(paidBeforeGs)}) pero no como gasto.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionSelector(PocktColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(PocktRadii.l),
        border: Border.all(color: colors.glassBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SegmentTab(
              title: 'Debo',
              subtitle: 'me prestaron / cuotas',
              selected: _direction == LoanDirection.owe,
              onTap: () {
                Haptics.tick();
                setState(() => _direction = LoanDirection.owe);
              },
            ),
          ),
          Expanded(
            child: _SegmentTab(
              title: 'Presté',
              subtitle: 'me deben',
              selected: _direction == LoanDirection.lent,
              onTap: () {
                Haptics.tick();
                setState(() => _direction = LoanDirection.lent);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKindSelector(PocktColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(PocktRadii.l),
        border: Border.all(color: colors.glassBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SegmentTab(
              title: 'En cuotas',
              selected: _kind == LoanKind.installments,
              onTap: () {
                Haptics.tick();
                setState(() => _kind = LoanKind.installments);
              },
            ),
          ),
          Expanded(
            child: _SegmentTab(
              title: 'Préstamo general',
              selected: _kind == LoanKind.loan,
              onTap: () {
                Haptics.tick();
                setState(() => _kind = LoanKind.loan);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentModeSelector(PocktColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(PocktRadii.l),
        border: Border.all(color: colors.glassBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SegmentTab(
              title: 'Monto fijo',
              selected: _installmentMode == _InstallmentMode.fixed,
              onTap: () {
                Haptics.tick();
                setState(() => _installmentMode = _InstallmentMode.fixed);
              },
            ),
          ),
          Expanded(
            child: _SegmentTab(
              title: 'Cronograma',
              selected: _installmentMode == _InstallmentMode.schedule,
              onTap: () {
                Haptics.tick();
                setState(() => _installmentMode = _InstallmentMode.schedule);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PocktRadii.m),
          color: selected
              ? (isDark
                    ? colors.brandStart.withValues(alpha: 0.20)
                    : colors.brandStart.withValues(alpha: 0.14))
              : Colors.transparent,
          border: selected
              ? Border.all(color: colors.brandStart.withValues(alpha: 0.35))
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? colors.brandStart : colors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? colors.brandStart.withValues(alpha: 0.90)
                        : colors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
