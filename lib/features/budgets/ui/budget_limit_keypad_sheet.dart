import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/budgets/ui/budget_ring_card.dart';

/// Hoja con teclado numérico para fijar o editar el tope mensual de una categoría.
class BudgetLimitKeypadSheet extends ConsumerStatefulWidget {
  final Category category;
  final int initialLimit;

  const BudgetLimitKeypadSheet({
    super.key,
    required this.category,
    required this.initialLimit,
  });

  @override
  ConsumerState<BudgetLimitKeypadSheet> createState() =>
      _BudgetLimitKeypadSheetState();
}

class _BudgetLimitKeypadSheetState
    extends ConsumerState<BudgetLimitKeypadSheet> {
  late String _digits;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _digits = widget.initialLimit > 0 ? widget.initialLimit.toString() : '';
  }

  void _onKey(String key) {
    Haptics.key();
    setState(() {
      _digits = keypadAppend(_digits, key);
    });
  }

  Future<void> _onSave() async {
    final amount = keypadValue(_digits);
    if (amount <= 0 || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(budgetsRepositoryProvider)
          .setLimit(widget.category.id, amount);
      Haptics.save();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = getBudgetCategoryColor(widget.category, isDark);
    final amount = keypadValue(_digits);
    final canSave = amount > 0 && !_isSaving;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: colors.sheetSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(color: colors.glassBorder, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 32,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.textTertiary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Pastilla de categoría
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(
                            alpha: isDark ? 0.22 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(PocktRadii.xl),
                          border: Border.all(
                            color: categoryColor.withValues(
                              alpha: isDark ? 0.45 : 0.30,
                            ),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            categoryIcon(
                              widget.category.icon,
                              size: 18,
                              color: colors.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.category.name,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Monto formateado
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatGs(amount),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.0,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tope mensual para ${widget.category.name}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Grilla de teclado
                      _KeypadGrid(onKey: _onKey),
                      const SizedBox(height: 14),

                      // Botón Guardar tope
                      Pressable(
                        onTap: canSave ? _onSave : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: canSave ? 1.0 : 0.4,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: categoryColor,
                              borderRadius: BorderRadius.circular(
                                PocktRadii.xl,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Guardar tope',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: categoryColor.computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeypadGrid extends StatelessWidget {
  final ValueChanged<String> onKey;

  const _KeypadGrid({required this.onKey});

  static const List<String> _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '000',
    '0',
    '⌫',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: _KeypadBtn(
                    label: _keys[row * 3 + col],
                    onTap: () => onKey(_keys[row * 3 + col]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _KeypadBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeypadBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: colors.glassFill,
          borderRadius: BorderRadius.circular(PocktRadii.l),
          border: Border.all(color: colors.glassBorder, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: label == '000' ? 18 : 22,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool?> showBudgetLimitKeypad(
  BuildContext context, {
  required Category category,
  required int initialLimit,
}) {
  return Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, _) => BudgetLimitKeypadSheet(
        category: category,
        initialLimit: initialLimit,
      ),
      transitionsBuilder: (context, animation, _, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: SpringCurve(spring: PocktSprings.soft),
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    ),
  );
}
