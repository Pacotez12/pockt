import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';
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

Future<bool?> showAmountKeypad(
  BuildContext context, {
  required Category category,
  required TxType type,
  TxView? editing,
  int? initialAmount,
  DateTime? initialDate,
  String? initialMerchant,
  Future<void> Function({
    required int amount,
    required Category category,
    required DateTime occurredAt,
    String? merchant,
    String? note,
  })? onSaveOverride,
}) {
  return Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, _) => AmountKeypadScreen(
        category: category,
        type: type,
        editing: editing,
        initialAmount: initialAmount,
        initialDate: initialDate,
        initialMerchant: initialMerchant,
        onSaveOverride: onSaveOverride,
      ),
      transitionsBuilder: entrySpringTransitionsBuilder,
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
  final TextEditingController _naturalController = TextEditingController();
  ParsedEntry? _proposal;
  StreamSubscription<List<Category>>? _categoriesSub;
  List<Category> _activeCategories = const [];
  Map<String, String> _keywordMap = const {};

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
    _subscribeCategories();
    _loadKeywords();
  }

  void _loadKeywords() async {
    final kwRepo = ref.read(keywordsRepositoryProvider);
    final map = await kwRepo.keywordMap();
    if (mounted) {
      setState(() => _keywordMap = map);
    }
  }

  @override
  void dispose() {
    _naturalController.dispose();
    _categoriesSub?.cancel();
    super.dispose();
  }

  void _subscribeCategories() {
    _categoriesSub?.cancel();
    final repo = ref.read(categoriesRepositoryProvider);
    final kind = _currentType == TxType.expense
        ? CategoryKind.expense
        : CategoryKind.income;
    _categoriesSub = repo.watchActive(kind).listen((cats) {
      if (mounted) {
        setState(() => _activeCategories = cats);
      }
    });
  }

  void _onNaturalInputChanged(String text) {
    if (text.trim().isEmpty) {
      if (_proposal != null) {
        setState(() => _proposal = null);
      }
      return;
    }
    final now = toLocal(DateTime.now());
    final keywords = _keywordMap.isNotEmpty
        ? _keywordMap
        : buildKeywordToCategoryIdMap(_activeCategories);
    final parsed = parseNaturalEntry(
      text,
      nowLocal: now,
      keywordToCategoryId: keywords,
    );
    setState(() => _proposal = parsed);
  }

  Future<void> _openFromProposal(
    ParsedEntry proposal,
    Category category,
  ) async {
    Haptics.tick();
    final saved = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, _, _) => AmountKeypadScreen(
          category: category,
          type: _currentType,
          initialAmount: proposal.amount,
          initialDate: combineDayWithNow(proposal.occurredLocalDay, DateTime.now()),
          initialMerchant: proposal.merchant,
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
    if (saved == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Category? proposedCategory;
    if (_proposal?.categoryId != null) {
      proposedCategory = _activeCategories
          .where((c) => c.id == _proposal!.categoryId)
          .firstOrNull;
    }

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
                          setState(() {
                            _currentType = type;
                            _proposal = null;
                            _naturalController.clear();
                          });
                          _subscribeCategories();
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
                const SizedBox(height: 14),
                // Natural text input field in GlassCard
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    child: Row(
                      children: [
                        Icon(
                          uiIcon('sparkle'),
                          size: 18,
                          color: colors.textSecondary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _naturalController,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: colors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: _currentType == TxType.expense
                                  ? 'Ej. bolt 28.500, super 230 mil ayer'
                                  : 'Ej. sueldo 8.500.000, extra 300 mil',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: colors.textSecondary
                                    .withValues(alpha: 0.5),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: _onNaturalInputChanged,
                          ),
                        ),
                        if (_naturalController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _naturalController.clear();
                              _onNaturalInputChanged('');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                uiIcon('x'),
                                size: 16,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Smooth animated proposal card
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: _proposal != null && proposedCategory != null
                      ? Padding(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            top: 8,
                          ),
                          child: Pressable(
                            key: const ValueKey('natural-proposal-card'),
                            onTap: () => _openFromProposal(
                              _proposal!,
                              proposedCategory!,
                            ),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(
                                        isDark
                                            ? proposedCategory.colorDark
                                            : proposedCategory.colorLight,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: categoryIcon(
                                      proposedCategory.icon,
                                      size: 22,
                                      color: const Color(0xFF141414),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          proposedCategory.name,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        if (_proposal!.merchant != null &&
                                            _proposal!.merchant!
                                                    .toLowerCase() !=
                                                proposedCategory.name
                                                    .toLowerCase())
                                          Text(
                                            _proposal!.merchant!,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatGs(_proposal!.amount),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    uiIcon('caret-right'),
                                    size: 16,
                                    color: colors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
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
