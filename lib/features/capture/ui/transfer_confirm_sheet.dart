import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/capture/data/counterparty_rules_repository.dart';
import 'package:pockt/features/capture/domain/itau_email_parser.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/recurring/ui/suggestion_category_picker.dart';

Future<bool?> showTransferConfirmSheet(
  BuildContext context,
  SuggestedTransaction suggestion,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => TransferConfirmSheet(suggestion: suggestion),
  );
}

class TransferConfirmSheet extends ConsumerStatefulWidget {
  final SuggestedTransaction suggestion;

  const TransferConfirmSheet({super.key, required this.suggestion});

  @override
  ConsumerState<TransferConfirmSheet> createState() =>
      _TransferConfirmSheetState();
}

enum _InOption { income, loanRepayment, ignore }
enum _OutOption { expense, loanLent, loanPayment, ignore }

class _TransferConfirmSheetState extends ConsumerState<TransferConfirmSheet> {
  late bool _isTransferIn;
  late String _person;
  String? _selectedCategoryId;
  String? _selectedLoanId;

  _InOption _inOption = _InOption.income;
  _OutOption _outOption = _OutOption.expense;

  bool _loading = true;
  List<Category> _availableCategories = const [];
  List<Loan> _availableLoans = const [];

  @override
  void initState() {
    super.initState();
    final meta = _parseMeta();
    final kindStr = meta['kind'] as String?;
    _isTransferIn = kindStr == 'transferIn' || widget.suggestion.type == TxType.income;
    _person = (meta['counterparty'] as String?)?.trim() ??
        (widget.suggestion.merchant?.trim() ?? '');
    if (_person.isEmpty) {
      _person = 'Desconocido';
    }

    _selectedCategoryId = widget.suggestion.categoryId;

    if (meta['action'] == 'ignore') {
      _inOption = _InOption.ignore;
      _outOption = _OutOption.ignore;
    }

    _loadData();
  }

  Map<String, dynamic> _parseMeta() {
    if (widget.suggestion.captureMeta == null ||
        widget.suggestion.captureMeta!.trim().isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(widget.suggestion.captureMeta!);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final rulesRepo = ref.read(counterpartyRulesRepositoryProvider);

    final catKind = _isTransferIn ? CategoryKind.income : CategoryKind.expense;
    final cats = await (db.select(db.categories)
          ..where((c) => c.kind.equalsValue(catKind))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();

    final loanDir = _isTransferIn ? LoanDirection.lent : LoanDirection.owe;
    final loans = await (db.select(db.loans)
          ..where((l) => l.closedAt.isNull() & l.direction.equals(loanDir.name))
          ..orderBy([
            (l) => OrderingTerm.asc(l.dueDay),
            (l) => OrderingTerm.asc(l.startDate),
          ]))
        .get();

    final dir = _isTransferIn
        ? TransferDirection.incoming
        : TransferDirection.outgoing;
    final rule = await rulesRepo.find(normalizePersonKey(_person), dir);

    if (mounted) {
      setState(() {
        _availableCategories = cats;
        _availableLoans = loans;

        if (rule != null) {
          if (_selectedCategoryId == null && rule.categoryId != null) {
            _selectedCategoryId = rule.categoryId;
          }
          if (_selectedLoanId == null && rule.loanId != null) {
            _selectedLoanId = rule.loanId;
          }
          if (_isTransferIn) {
            switch (rule.action) {
              case CounterpartyAction.income:
                _inOption = _InOption.income;
                break;
              case CounterpartyAction.loanRepayment:
                _inOption = _InOption.loanRepayment;
                break;
              case CounterpartyAction.ignore:
                _inOption = _InOption.ignore;
                break;
              default:
                break;
            }
          } else {
            switch (rule.action) {
              case CounterpartyAction.expense:
                _outOption = _OutOption.expense;
                break;
              case CounterpartyAction.loanLent:
                _outOption = _OutOption.loanLent;
                break;
              case CounterpartyAction.loanPayment:
                _outOption = _OutOption.loanPayment;
                break;
              case CounterpartyAction.ignore:
                _outOption = _OutOption.ignore;
                break;
              default:
                break;
            }
          }
        }

        if (loans.isNotEmpty && _selectedLoanId == null) {
          _selectedLoanId = loans.first.id;
        }
        _loading = false;
      });
    }
  }

  Future<void> _pickCategory() async {
    if (_availableCategories.isEmpty) return;
    final picked = await showSuggestionCategoryPicker(context, _availableCategories);
    if (picked != null && mounted) {
      setState(() {
        _selectedCategoryId = picked.id;
      });
    }
  }

  Future<void> _confirm() async {
    final sug = widget.suggestion;
    final normKey = normalizePersonKey(_person);
    final sugRepo = ref.read(suggestionsRepositoryProvider);
    final rulesRepo = ref.read(counterpartyRulesRepositoryProvider);
    final loansRepo = ref.read(loansRepositoryProvider);
    final db = ref.read(databaseProvider);

    if (_isTransferIn) {
      switch (_inOption) {
        case _InOption.income:
          await sugRepo.confirm(
            sug.id,
            categoryId: _selectedCategoryId,
            occurredAt: sug.occurredAt,
          );
          await rulesRepo.upsert(
            nameKey: normKey,
            direction: TransferDirection.incoming,
            action: CounterpartyAction.income,
            categoryId: _selectedCategoryId,
            autoApply: true,
          );
          break;

        case _InOption.loanRepayment:
          if (_selectedLoanId != null) {
            await loansRepo.recordPayment(
              loanId: _selectedLoanId!,
              amount: sug.amount,
              date: sug.occurredAt,
              note: sug.rawText,
            );
          }
          await (db.update(db.suggestedTransactions)
                ..where((t) => t.id.equals(sug.id)))
              .write(SuggestedTransactionsCompanion(
                status: Value('confirmed'),
              ));
          await rulesRepo.upsert(
            nameKey: normKey,
            direction: TransferDirection.incoming,
            action: CounterpartyAction.loanRepayment,
            loanId: _selectedLoanId,
            autoApply: true,
          );
          break;

        case _InOption.ignore:
          await sugRepo.dismiss(sug.id);
          await rulesRepo.upsert(
            nameKey: normKey,
            direction: TransferDirection.incoming,
            action: CounterpartyAction.ignore,
            autoApply: true,
          );
          break;
      }
    } else {
      switch (_outOption) {
        case _OutOption.expense:
          await sugRepo.confirm(
            sug.id,
            categoryId: _selectedCategoryId,
            occurredAt: sug.occurredAt,
          );
          await rulesRepo.upsert(
            nameKey: normKey,
            direction: TransferDirection.outgoing,
            action: CounterpartyAction.expense,
            categoryId: _selectedCategoryId,
            autoApply: false,
          );
          break;

        case _OutOption.loanLent:
          await loansRepo.createLoan(
            name: _person,
            direction: LoanDirection.lent,
            kind: LoanKind.loan,
            totalAmount: sug.amount,
            startDate: sug.occurredAt,
            recordInitialDisbursement: true,
          );
          await (db.update(db.suggestedTransactions)
                ..where((t) => t.id.equals(sug.id)))
              .write(SuggestedTransactionsCompanion(
                status: Value('confirmed'),
              ));
          await rulesRepo.upsert(
            nameKey: normKey,
            direction: TransferDirection.outgoing,
            action: CounterpartyAction.loanLent,
            autoApply: false,
          );
          break;

        case _OutOption.loanPayment:
          if (_selectedLoanId != null) {
            await loansRepo.recordPayment(
              loanId: _selectedLoanId!,
              amount: sug.amount,
              date: sug.occurredAt,
              note: sug.rawText,
            );
          }
          await (db.update(db.suggestedTransactions)
                ..where((t) => t.id.equals(sug.id)))
              .write(SuggestedTransactionsCompanion(
                status: Value('confirmed'),
              ));
          await rulesRepo.upsert(
            nameKey: normKey,
            direction: TransferDirection.outgoing,
            action: CounterpartyAction.loanPayment,
            loanId: _selectedLoanId,
            autoApply: false,
          );
          break;

        case _OutOption.ignore:
          await sugRepo.dismiss(sug.id);
          await rulesRepo.upsert(
            nameKey: normKey,
            direction: TransferDirection.outgoing,
            action: CounterpartyAction.ignore,
            autoApply: false,
          );
          break;
      }
    }

    Haptics.save();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _isTransferIn
        ? 'Transferencia recibida'
        : 'Transferencia enviada';
    final amountText = formatGs(widget.suggestion.amount);

    final selectedCat = _availableCategories
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(colors.glassFill, colors.background),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(PocktRadii.xl),
        ),
        border: Border.all(color: colors.glassBorder),
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
      child: SafeArea(
        top: false,
        child: _loading
            ? const SizedBox(height: 200)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_isTransferIn ? colors.positive : colors.brandStart)
                              .withValues(alpha: isDark ? 0.22 : 0.14),
                        ),
                        child: Center(
                          child: Icon(
                            uiIcon('envelope-simple'),
                            color: _isTransferIn ? colors.positive : colors.brandStart,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_person · $amountText',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '¿Cómo querés registrarla?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_isTransferIn) ...[
                    _buildOptionCard(
                      title: 'Ingreso',
                      selected: _inOption == _InOption.income,
                      onTap: () {
                        setState(() => _inOption = _InOption.income);
                        if (_selectedCategoryId == null) _pickCategory();
                      },
                      subtitle: selectedCat?.name ?? 'Elegí una categoría',
                      onActionTap: _pickCategory,
                      actionLabel: selectedCat != null
                          ? 'Cambiar categoría'
                          : 'Elegir categoría',
                    ),
                    const SizedBox(height: 8),
                    _buildOptionCard(
                      title: 'Me pagaron un préstamo',
                      selected: _inOption == _InOption.loanRepayment,
                      onTap: () => setState(() => _inOption = _InOption.loanRepayment),
                      child: _inOption == _InOption.loanRepayment
                          ? _buildLoanSelector(_availableLoans)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    _buildOptionCard(
                      title: 'No contar',
                      selected: _inOption == _InOption.ignore,
                      onTap: () => setState(() => _inOption = _InOption.ignore),
                    ),
                  ] else ...[
                    _buildOptionCard(
                      title: 'Gasto',
                      selected: _outOption == _OutOption.expense,
                      onTap: () {
                        setState(() => _outOption = _OutOption.expense);
                        if (_selectedCategoryId == null) _pickCategory();
                      },
                      subtitle: selectedCat?.name ?? 'Elegí una categoría',
                      onActionTap: _pickCategory,
                      actionLabel: selectedCat != null
                          ? 'Cambiar categoría'
                          : 'Elegir categoría',
                    ),
                    const SizedBox(height: 8),
                    _buildOptionCard(
                      title: 'Le presté a alguien',
                      selected: _outOption == _OutOption.loanLent,
                      onTap: () => setState(() => _outOption = _OutOption.loanLent),
                      subtitle: 'Crea un préstamo a $_person',
                    ),
                    const SizedBox(height: 8),
                    _buildOptionCard(
                      title: 'Pagué una deuda',
                      selected: _outOption == _OutOption.loanPayment,
                      onTap: () => setState(() => _outOption = _OutOption.loanPayment),
                      child: _outOption == _OutOption.loanPayment
                          ? _buildLoanSelector(_availableLoans)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    _buildOptionCard(
                      title: 'No contar',
                      selected: _outOption == _OutOption.ignore,
                      onTap: () => setState(() => _outOption = _OutOption.ignore),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final canConfirm = (_isTransferIn && _inOption == _InOption.income) ||
                              (!_isTransferIn && _outOption == _OutOption.expense)
                          ? _selectedCategoryId != null
                          : true;
                      return ElevatedButton(
                        onPressed: canConfirm ? _confirm : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.brandStart,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              colors.brandStart.withValues(alpha: 0.35),
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(PocktRadii.l),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Confirmar',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required bool selected,
    required VoidCallback onTap,
    String? subtitle,
    VoidCallback? onActionTap,
    String? actionLabel,
    Widget? child,
  }) {
    final colors = context.pockt;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? colors.brandStart.withValues(alpha: 0.12)
              : colors.glassFill,
          borderRadius: BorderRadius.circular(PocktRadii.m),
          border: Border.all(
            color: selected ? colors.brandStart : colors.glassBorder,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.brandStart : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? colors.brandStart
                          : colors.textSecondary.withValues(alpha: 0.5),
                      width: selected ? 2.0 : 1.5,
                    ),
                  ),
                  child: selected
                      ? Center(
                          child: Icon(
                            uiIcon('check'),
                            size: 12,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (actionLabel != null && selected) ...[
                  TextButton(
                    onPressed: onActionTap,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      actionLabel,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.brandStart,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (subtitle != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 4),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
            if (child != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 8),
                child: child,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoanSelector(List<Loan> loans) {
    final colors = context.pockt;
    if (loans.isEmpty) {
      return Text(
        'No tenés préstamos activos',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: colors.textSecondary,
        ),
      );
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedLoanId,
        isDense: true,
        dropdownColor: colors.background,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: colors.textPrimary,
        ),
        items: [
          for (final loan in loans)
            DropdownMenuItem(
              value: loan.id,
              child: Text('${loan.name} (${formatGs(loan.totalAmount)})'),
            ),
        ],
        onChanged: (val) {
          if (val != null) setState(() => _selectedLoanId = val);
        },
      ),
    );
  }
}
