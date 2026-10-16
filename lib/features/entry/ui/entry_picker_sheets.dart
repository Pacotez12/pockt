import 'package:flutter/material.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/entry/ui/category_grid.dart';

enum LoanPickerChoiceType { loan, general, cancel }

class LoanPickerChoice {
  final LoanPickerChoiceType type;
  final Loan? loan;

  const LoanPickerChoice._(this.type, this.loan);
  factory LoanPickerChoice.loan(Loan loan) =>
      LoanPickerChoice._(LoanPickerChoiceType.loan, loan);
  factory LoanPickerChoice.general() =>
      const LoanPickerChoice._(LoanPickerChoiceType.general, null);
  factory LoanPickerChoice.cancel() =>
      const LoanPickerChoice._(LoanPickerChoiceType.cancel, null);
}

Future<LoanPickerChoice> showLoanPickerSheet(
  BuildContext context, {
  required List<Loan> loans,
}) async {
  final result = await showModalBottomSheet<LoanPickerChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final colors = sheetContext.pockt;
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

      return Container(
        decoration: BoxDecoration(
          color: colors.sheetSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: SafeArea(
          top: false,
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
              const SizedBox(height: 18),
              Text(
                '¿A qué préstamo corresponde?',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Vinculá este movimiento a una deuda o cuota activa',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: loans.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final loan = loans[index];
                    final subtitle = loan.installmentAmount != null
                        ? 'Cuota: ${formatGs(loan.installmentAmount!)}'
                        : 'Total: ${formatGs(loan.totalAmount)}';

                    return Pressable(
                      onTap: () {
                        Haptics.tick();
                        Navigator.of(sheetContext)
                            .pop(LoanPickerChoice.loan(loan));
                      },
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        borderRadius: BorderRadius.circular(PocktRadii.l),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colors
                                    .brandAt(0)
                                    .withValues(alpha: isDark ? 0.2 : 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  uiIcon('hand-coins'),
                                  size: 18,
                                  color: colors.brandAt(0),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loan.name,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              uiIcon('caret-right'),
                              size: 14,
                              color: colors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Pressable(
                onTap: () {
                  Haptics.tick();
                  Navigator.of(sheetContext).pop(LoanPickerChoice.general());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PocktRadii.l),
                    border: Border.all(color: colors.glassBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Ninguno / Gasto general',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  return result ?? LoanPickerChoice.cancel();
}

Future<Category?> showCategoryPickerSheet(
  BuildContext context, {
  required TxType type,
}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final colors = sheetContext.pockt;
      return Container(
        height: MediaQuery.of(sheetContext).size.height * 0.7,
        decoration: BoxDecoration(
          color: colors.sheetSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              type == TxType.expense
                  ? 'Categoría de gasto'
                  : 'Categoría de ingreso',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: CategoryGrid(
                currentType: type,
                onCategorySelected: (cat) {
                  Haptics.tick();
                  Navigator.of(sheetContext).pop(cat);
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class TypeToggle extends StatelessWidget {
  final TxType currentType;
  final ValueChanged<TxType> onTypeChanged;

  const TypeToggle({
    super.key,
    required this.currentType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(PocktRadii.xl),
        border: Border.all(color: colors.glassBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TypePill(
            title: 'Gasto',
            isSelected: currentType == TxType.expense,
            onTap: () => onTypeChanged(TxType.expense),
          ),
          _TypePill(
            title: 'Ingreso',
            isSelected: currentType == TxType.income,
            onTap: () => onTypeChanged(TxType.income),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypePill({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(PocktRadii.l),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? colors.background : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
