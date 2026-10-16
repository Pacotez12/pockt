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
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/entry/domain/entry_form_logic.dart';
import 'package:pockt/features/entry/domain/entry_shortcut.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';
import 'package:pockt/features/entry/ui/amount_keypad.dart';
import 'package:pockt/features/entry/ui/category_grid.dart';
import 'package:pockt/features/entry/ui/entry_natural_input_bar.dart';
import 'package:pockt/features/entry/ui/entry_picker_sheets.dart';
import 'package:pockt/features/entry/ui/entry_shortcuts_bar.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

export 'package:pockt/features/entry/ui/category_grid.dart';
export 'package:pockt/features/entry/ui/entry_natural_input_bar.dart';
export 'package:pockt/features/entry/ui/entry_picker_sheets.dart';
export 'package:pockt/features/entry/ui/entry_shortcuts_bar.dart';

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
      child: RepaintBoundary(child: child),
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
  String? initialLoanId,
  Future<void> Function({
    required int amount,
    required Category category,
    required DateTime occurredAt,
    String? merchant,
    String? note,
  })?
  onSaveOverride,
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
        initialLoanId: initialLoanId,
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
  int? initialAmount,
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
    final category = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(initialCategoryId))).getSingleOrNull();
    if (category != null && context.mounted) {
      String? loanId;
      int? prefilledAmount;
      if (category.name == 'Préstamos') {
        final activeLoans = await container
            .read(loansRepositoryProvider)
            .getActive(
              direction: initialType == TxType.expense
                  ? LoanDirection.owe
                  : LoanDirection.lent,
            );
        if (activeLoans.isNotEmpty && context.mounted) {
          final choice = await showLoanPickerSheet(context, loans: activeLoans);
          if (choice.type == LoanPickerChoiceType.cancel) return;
          if (choice.type == LoanPickerChoiceType.loan) {
            loanId = choice.loan!.id;
            prefilledAmount = choice.loan!.installmentAmount;
          }
        }
      }
      if (!context.mounted) return;
      await Navigator.of(context).push<bool>(
        PageRouteBuilder<bool>(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, _, _) => AmountKeypadScreen(
            category: category,
            type: initialType,
            initialLoanId: loanId,
            initialAmount: initialAmount ?? prefilledAmount,
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
      pageBuilder: (context, _, _) =>
          EntryCategoryPickerScreen(initialType: initialType),
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
    final order = ref.read(categoryOrderProvider).value ?? CategoryOrder.manual;
    final kind = _currentType == TxType.expense
        ? CategoryKind.expense
        : CategoryKind.income;
    _categoriesSub = repo.watchActive(kind, order: order).listen((cats) {
      if (mounted) {
        setState(() => _activeCategories = cats);
      }
    });
  }

  void _onNaturalInputChanged(String text) {
    final resolved = resolveEntryNaturalProposal(
      text,
      nowLocal: toLocal(DateTime.now()),
      activeCategories: _activeCategories,
      keywordMap: _keywordMap,
    );
    if (text.trim().isEmpty && _proposal == null) return;
    setState(() => _proposal = resolved?.entry);
  }

  Future<void> _openFromProposal(
    ParsedEntry proposal,
    Category category,
  ) async {
    Haptics.tick();
    String? loanId;
    int? amount = proposal.amount > 0 ? proposal.amount : null;
    if (category.name == 'Préstamos') {
      final activeLoans = await ref
          .read(loansRepositoryProvider)
          .getActive(
            direction: _currentType == TxType.expense
                ? LoanDirection.owe
                : LoanDirection.lent,
          );
      if (activeLoans.isNotEmpty && mounted) {
        final choice = await showLoanPickerSheet(context, loans: activeLoans);
        if (choice.type == LoanPickerChoiceType.cancel) return;
        if (choice.type == LoanPickerChoiceType.loan) {
          loanId = choice.loan!.id;
          amount ??= choice.loan!.installmentAmount;
        }
      }
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, _, _) => AmountKeypadScreen(
          category: category,
          type: _currentType,
          initialAmount: amount,
          initialDate: combineDayWithNow(
            proposal.occurredLocalDay,
            DateTime.now(),
          ),
          initialMerchant: proposal.merchant,
          initialLoanId: loanId,
        ),
        transitionsBuilder: _entryFadeTransitionsBuilder,
      ),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onCategorySelected(Category category) async {
    Haptics.tick();
    String? loanId;
    int? prefilledAmount;
    if (category.name == 'Préstamos') {
      final activeLoans = await ref
          .read(loansRepositoryProvider)
          .getActive(
            direction: _currentType == TxType.expense
                ? LoanDirection.owe
                : LoanDirection.lent,
          );
      if (!mounted) return;
      if (activeLoans.isNotEmpty) {
        final choice = await showLoanPickerSheet(context, loans: activeLoans);
        if (!mounted) return;
        if (choice.type == LoanPickerChoiceType.cancel) return;
        if (choice.type == LoanPickerChoiceType.loan) {
          loanId = choice.loan!.id;
          prefilledAmount = choice.loan!.installmentAmount;
        }
      }
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, _, _) => AmountKeypadScreen(
          category: category,
          type: _currentType,
          initialLoanId: loanId,
          initialAmount: prefilledAmount,
        ),
        transitionsBuilder: _entryFadeTransitionsBuilder,
      ),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveFromShortcut(EntryShortcutItem item) async {
    final txRepo = ref.read(transactionsRepositoryProvider);
    final id = await txRepo.add(
      type: TxType.expense,
      amount: item.amount,
      categoryId: item.categoryId,
      merchant: item.merchant,
      note: item.note,
      occurredAt: DateTime.now(),
    );

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(true);

    messenger.showSnackBar(
      SnackBar(
        content: Text('Guardado: ${item.label} · ${formatGs(item.amount)}'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            await txRepo.softDelete(id);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
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
                child: RepaintBoundary(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          colors.brandEnd.withValues(
                            alpha: isDark ? 0.30 : 0.15,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.65],
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(uiIcon('x'), size: 22),
                        color: colors.textSecondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      TypeToggle(
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
                // Natural text input + animated proposal card
                EntryNaturalInputSection(
                  controller: _naturalController,
                  currentType: _currentType,
                  proposal: _proposal,
                  proposedCategory: proposedCategory,
                  onChanged: _onNaturalInputChanged,
                  onClear: () {
                    _naturalController.clear();
                    _onNaturalInputChanged('');
                  },
                  onProposalTapped: _openFromProposal,
                ),
                const SizedBox(height: 12),
                if (_currentType == TxType.expense) ...[
                  const ActiveEventChip(),
                  EntryShortcutsBar(onShortcutTapped: _saveFromShortcut),
                ],
                // Category Grid
                Expanded(
                  child: CategoryGrid(
                    currentType: _currentType,
                    categories: _activeCategories,
                    onCategorySelected: _onCategorySelected,
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

Widget _entryFadeTransitionsBuilder(
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
  return FadeTransition(
    opacity: curved,
    child: RepaintBoundary(child: child),
  );
}
