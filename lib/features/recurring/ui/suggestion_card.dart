import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/capture/ui/transfer_confirm_sheet.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/recurring/ui/duplicate_warning_box.dart';
import 'package:pockt/features/recurring/ui/suggestion_card_parts.dart';
import 'package:pockt/features/recurring/ui/suggestion_category_picker.dart';
import 'package:pockt/features/recurring/ui/inbox_screen.dart'
    show consecutiveConfirmationsProvider;

class SuggestionCard extends ConsumerStatefulWidget {
  final SuggestionView item;

  const SuggestionCard({super.key, required this.item});

  @override
  ConsumerState<SuggestionCard> createState() => SuggestionCardState();
}

class SuggestionCardState extends ConsumerState<SuggestionCard> {
  bool _showRawText = false;
  bool _autoConfirmMerchant = false;

  SuggestionView get item => widget.item;

  Future<void> _confirm(BuildContext context) async {
    final meta = item.suggestion.captureMeta;
    final isEmailTransfer = item.suggestion.source == TxSource.capture &&
        meta != null &&
        (meta.contains('"transferIn"') || meta.contains('"transferOut"'));
    if (isEmailTransfer) {
      final confirmed = await showTransferConfirmSheet(context, item.suggestion);
      if (confirmed == true) {
        ref.read(consecutiveConfirmationsProvider.notifier).recordConfirmation();
      }
      return;
    }

    if (item.category == null &&
        item.suggestion.type != TxType.transfer &&
        item.suggestion.source == TxSource.capture &&
        item.suggestion.amount > 0) {
      await _pickCategoryAndConfirm(context);
      return;
    }
    final repo = ref.read(suggestionsRepositoryProvider);
    await repo.confirm(
      item.suggestion.id,
      autoConfirmMerchant: _autoConfirmMerchant,
    );
    Haptics.save();
    ref.read(consecutiveConfirmationsProvider.notifier).recordConfirmation();
  }

  Future<void> _pickCategoryAndConfirm(BuildContext context) async {
    final db = ref.read(databaseProvider);
    final kind = item.suggestion.type == TxType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final categories =
        await (db.select(db.categories)
              ..where((c) => c.kind.equalsValue(kind))
              ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
            .get();
    if (!context.mounted || categories.isEmpty) return;

    final picked = await showSuggestionCategoryPicker(context, categories);

    if (picked == null || !mounted) return;
    final repo = ref.read(suggestionsRepositoryProvider);
    await repo.confirm(
      item.suggestion.id,
      categoryId: picked.id,
      autoConfirmMerchant: _autoConfirmMerchant,
    );
    Haptics.save();
    ref.read(consecutiveConfirmationsProvider.notifier).recordConfirmation();
  }

  Future<void> _resolveDuplicateSame() async {
    final repo = ref.read(suggestionsRepositoryProvider);
    await repo.resolveDuplicateAsSame(item.suggestion.id);
    Haptics.tick();
  }

  Future<void> _edit(BuildContext context) async {
    Category? category = item.category;
    if (category == null) {
      final db = ref.read(databaseProvider);
      final catList =
          await (db.select(db.categories)
                ..where(
                  (c) => c.kind.equalsValue(
                    item.suggestion.type == TxType.income
                        ? CategoryKind.income
                        : CategoryKind.expense,
                  ),
                )
                ..limit(1))
              .get();
      if (catList.isNotEmpty) {
        category = catList.first;
      }
    }
    if (category == null || !context.mounted) return;

    await showAmountKeypad(
      context,
      category: category,
      type: item.suggestion.type == TxType.transfer
          ? TxType.expense
          : item.suggestion.type,
      initialAmount: item.suggestion.amount > 0 ? item.suggestion.amount : null,
      initialDate: toLocal(item.suggestion.occurredAt),
      initialMerchant: item.suggestion.merchant,
      onSaveOverride:
          ({
            required int amount,
            required Category category,
            required DateTime occurredAt,
            String? merchant,
            String? note,
          }) async {
            final repo = ref.read(suggestionsRepositoryProvider);
            await repo.confirm(
              item.suggestion.id,
              amount: amount,
              categoryId: category.id,
              occurredAt: occurredAt,
              autoConfirmMerchant: _autoConfirmMerchant,
            );
            ref
                .read(consecutiveConfirmationsProvider.notifier)
                .recordConfirmation();
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isCapture = item.suggestion.source == TxSource.capture;
    final isDuplicate = item.suggestion.isPossibleDuplicate;
    final hasRawText =
        isCapture &&
        item.suggestion.rawText != null &&
        item.suggestion.rawText!.trim().isNotEmpty;
    final showAutoConfirmOption =
        isCapture &&
        item.suggestion.type == TxType.expense &&
        (item.suggestion.merchant?.trim().isNotEmpty ?? false);

    return Dismissible(
      key: ValueKey('dismiss-${item.suggestion.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(PocktRadii.xl),
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(uiIcon('trash'), color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Descartar',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref
            .read(suggestionsRepositoryProvider)
            .dismiss(item.suggestion.id);
        Haptics.tick();
      },
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SuggestionHeaderRow(item: item),
            if (isDuplicate) ...[
              const SizedBox(height: 12),
              DuplicateWarningBox(
                duplicateTxId: item.suggestion.duplicateTxId!,
              ),
            ],
            if (hasRawText) ...[
              const SizedBox(height: 10),
              SuggestionRawTextToggle(
                suggestionId: item.suggestion.id,
                rawText: item.suggestion.rawText!,
                expanded: _showRawText,
                onToggle: () => setState(() => _showRawText = !_showRawText),
              ),
            ],
            if (showAutoConfirmOption) ...[
              const SizedBox(height: 10),
              AutoConfirmMerchantToggle(
                suggestionId: item.suggestion.id,
                checked: _autoConfirmMerchant,
                onToggle: () => setState(
                  () => _autoConfirmMerchant = !_autoConfirmMerchant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SuggestionActionRow(
              item: item,
              onEdit: () => _edit(context),
              onConfirm: () => _confirm(context),
              onResolveSame: _resolveDuplicateSame,
            ),
          ],
        ),
      ),
    );
  }
}
