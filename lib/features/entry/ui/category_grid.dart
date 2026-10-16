import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';

class CategoryGrid extends ConsumerStatefulWidget {
  final TxType currentType;
  final List<Category>? categories;
  final ValueChanged<Category> onCategorySelected;

  const CategoryGrid({
    super.key,
    required this.currentType,
    this.categories,
    required this.onCategorySelected,
  });

  @override
  ConsumerState<CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends ConsumerState<CategoryGrid> {
  StreamSubscription<List<Category>>? _subscription;
  List<Category> _categories = const [];
  CategoryOrder _currentOrder = CategoryOrder.manual;

  @override
  void initState() {
    super.initState();
    if (widget.categories == null) {
      final initialOrder =
          ref.read(categoryOrderProvider).value ?? CategoryOrder.manual;
      _subscribe(order: initialOrder);
    }
  }

  @override
  void didUpdateWidget(CategoryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories == null &&
        (oldWidget.currentType != widget.currentType ||
            oldWidget.categories != null)) {
      _subscribe();
    } else if (widget.categories != null && _subscription != null) {
      _subscription?.cancel();
      _subscription = null;
    }
  }

  void _subscribe({CategoryOrder? order}) {
    if (widget.categories != null) return;
    final effectiveOrder = order ?? _currentOrder;
    _currentOrder = effectiveOrder;
    _subscription?.cancel();
    final repo = ref.read(categoriesRepositoryProvider);
    final kind = widget.currentType == TxType.expense
        ? CategoryKind.expense
        : CategoryKind.income;
    _subscription = repo.watchActive(kind, order: effectiveOrder).listen((
      data,
    ) {
      if (mounted) {
        setState(() => _categories = data);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.categories == null) {
      ref.listen<AsyncValue<CategoryOrder>>(categoryOrderProvider, (
        previous,
        next,
      ) {
        final order = next.value ?? CategoryOrder.manual;
        if (order != _currentOrder) {
          _subscribe(order: order);
        }
      });
    }

    final categories = widget.categories ?? _categories;

    return RepaintBoundary(
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 20,
          crossAxisSpacing: 12,
          childAspectRatio: 0.88,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final catColor = Color(isDark ? cat.colorDark : cat.colorLight);

          return Pressable(
            onTap: () => widget.onCategorySelected(cat),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HeroMode(
                  enabled: !MediaQuery.disableAnimationsOf(context),
                  child: Hero(
                    tag: 'cat-${cat.id}',
                    createRectTween: (begin, end) =>
                        SpringRectTween(begin: begin, end: end),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(29),
                          color: catColor,
                          boxShadow: [
                            BoxShadow(
                              color: catColor.withValues(
                                alpha: isDark ? 0.35 : 0.20,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: categoryIcon(
                          cat.icon,
                          size: 28,
                          color: colors.keypadKey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  cat.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
