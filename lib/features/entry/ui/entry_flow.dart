import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/entry/ui/amount_keypad.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

Widget entrySpringTransitionsBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return child;
  }
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
    child: FadeTransition(
      opacity: curved,
      child: child,
    ),
  );
}

Future<void> showEntryFlow(
  BuildContext context, {
  TxType initialType = TxType.expense,
  String? initialCategoryId,
  TxView? editing,
}) async {
  if (editing != null) {
    await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, _, _) => AmountKeypadScreen(
          category: editing.category,
          type: editing.tx.type,
          editing: editing,
        ),
        transitionsBuilder: entrySpringTransitionsBuilder,
      ),
    );
    return;
  }

  if (initialCategoryId != null) {
    final container = ProviderScope.containerOf(context);
    final db = container.read(databaseProvider);
    final category = await (db.select(db.categories)
          ..where((c) => c.id.equals(initialCategoryId)))
        .getSingleOrNull();
    if (category != null && context.mounted) {
      await Navigator.of(context).push<bool>(
        PageRouteBuilder<bool>(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, _, _) => AmountKeypadScreen(
            category: category,
            type: initialType,
          ),
          transitionsBuilder: entrySpringTransitionsBuilder,
        ),
      );
      return;
    }
  }

  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, _) => EntryCategoryPickerScreen(
        initialType: initialType,
      ),
      transitionsBuilder: entrySpringTransitionsBuilder,
    ),
  );
}

class EntryCategoryPickerScreen extends ConsumerStatefulWidget {
  final TxType initialType;

  const EntryCategoryPickerScreen({
    super.key,
    this.initialType = TxType.expense,
  });

  @override
  ConsumerState<EntryCategoryPickerScreen> createState() =>
      _EntryCategoryPickerScreenState();
}

class _EntryCategoryPickerScreenState
    extends ConsumerState<EntryCategoryPickerScreen> {
  late TxType _currentType;

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient brand glow behind title
            Positioned(
              top: -80,
              left: -40,
              right: -40,
              height: 380,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.brandEnd.withValues(alpha: isDark ? 0.30 : 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top bar: Close [✕] and Type Toggle [Gasto | Ingreso]
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(uiIcon('x'), size: 22),
                        color: colors.textSecondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      _TypeToggle(
                        currentType: _currentType,
                        onTypeChanged: (type) {
                          Haptics.tick();
                          setState(() => _currentType = type);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _currentType == TxType.expense
                        ? '¿En qué gastaste?'
                        : '¿De qué es el ingreso?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 18),
                // Category Grid
                Expanded(
                  child: _CategoryGrid(
                    currentType: _currentType,
                    onCategorySelected: (category) async {
                      Haptics.tick();
                      final saved = await Navigator.of(context).push<bool>(
                        PageRouteBuilder<bool>(
                          transitionDuration:
                              const Duration(milliseconds: 350),
                          reverseTransitionDuration:
                              const Duration(milliseconds: 300),
                          pageBuilder: (context, _, _) => AmountKeypadScreen(
                            category: category,
                            type: _currentType,
                          ),
                          transitionsBuilder: (context, animation, _, child) {
                            if (MediaQuery.disableAnimationsOf(context)) {
                              return child;
                            }
                            final curved = CurvedAnimation(
                              parent: animation,
                              curve: SpringCurve(spring: PocktSprings.soft),
                              reverseCurve: Curves.easeInCubic,
                            );
                            return FadeTransition(
                              opacity: curved,
                              child: child,
                            );
                          },
                        ),
                      );
                      if (saved == true && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends ConsumerStatefulWidget {
  final TxType currentType;
  final ValueChanged<Category> onCategorySelected;

  const _CategoryGrid({
    required this.currentType,
    required this.onCategorySelected,
  });

  @override
  ConsumerState<_CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends ConsumerState<_CategoryGrid> {
  StreamSubscription<List<Category>>? _subscription;
  List<Category> _categories = const [];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(_CategoryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentType != widget.currentType) {
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    final repo = ref.read(categoriesRepositoryProvider);
    final kind = widget.currentType == TxType.expense
        ? CategoryKind.expense
        : CategoryKind.income;
    _subscription = repo.watchActive(kind).listen((data) {
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
    final categories = _categories;

        return GridView.builder(
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
                  Hero(
                    tag: 'cat-${cat.id}',
                    createRectTween: (begin, end) =>
                        SpringRectTween(begin: begin, end: end),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: catColor,
                          boxShadow: [
                            BoxShadow(
                              color: catColor.withValues(
                                  alpha: isDark ? 0.35 : 0.20),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: categoryIcon(
                          cat.icon,
                          size: 28,
                          color: const Color(0xFF141414),
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
        );
  }
}

class _TypeToggle extends StatelessWidget {
  final TxType currentType;
  final ValueChanged<TxType> onTypeChanged;

  const _TypeToggle({
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
        borderRadius: BorderRadius.circular(20),
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
          borderRadius: BorderRadius.circular(16),
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
