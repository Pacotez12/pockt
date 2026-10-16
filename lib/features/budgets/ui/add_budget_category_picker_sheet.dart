import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/budgets/ui/budget_ring_card.dart';

/// Hoja para seleccionar una categoría de gasto sin presupuesto asignado.
class AddBudgetCategoryPickerSheet extends ConsumerWidget {
  final Set<String> existingCategoryIds;

  const AddBudgetCategoryPickerSheet({
    super.key,
    required this.existingCategoryIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.70,
              ),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle
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
                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nuevo presupuesto',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Elegí una categoría para asignarle un tope',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Pressable(
                            semanticLabel: 'Cerrar',
                            onTap: () => Navigator.of(context).pop(),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                uiIcon('x'),
                                size: 20,
                                color: colors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: StreamBuilder<List<Category>>(
                          stream: ref
                              .watch(categoriesRepositoryProvider)
                              .watchActive(CategoryKind.expense),
                          builder: (context, snapshot) {
                            final allCategories = snapshot.data ?? const [];
                            final available = allCategories
                                .where(
                                  (c) => !existingCategoryIds.contains(c.id),
                                )
                                .toList();

                            if (available.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Text(
                                    'Todas las categorías de gasto ya tienen un presupuesto asignado.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: colors.textTertiary,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: available.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final cat = available[index];
                                final catColor = getBudgetCategoryColor(
                                  cat,
                                  isDark,
                                );

                                return Pressable(
                                  onTap: () => Navigator.of(context).pop(cat),
                                  child: GlassCard(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: catColor.withValues(
                                              alpha: isDark ? 0.22 : 0.12,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: categoryIcon(
                                            cat.icon,
                                            size: 20,
                                            color: catColor,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            cat.name,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: colors.textPrimary,
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
                              },
                            );
                          },
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

Future<Category?> showAddBudgetCategoryPicker(
  BuildContext context, {
  required Set<String> existingCategoryIds,
}) {
  return Navigator.of(context).push<Category>(
    PageRouteBuilder<Category>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, _) => AddBudgetCategoryPickerSheet(
        existingCategoryIds: existingCategoryIds,
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
