import 'package:drift/drift.dart' show OrderingTerm;
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
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';

/// Pantalla de Bandeja de sugerencias pendientes ("Por confirmar").
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTopBar(context),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<SuggestionView>>(
                stream: ref.watch(suggestionsRepositoryProvider).watchPending(),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return _buildEmptyState(context);
                  }
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return const SizedBox(height: 100);
                      }
                      final item = items[index];
                      return _SuggestionCard(
                        key: ValueKey('suggestion-${item.suggestion.id}'),
                        item: item,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final colors = context.pockt;

    return Row(
      children: [
        Pressable(
          semanticLabel: 'Volver',
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.glassFill,
              shape: BoxShape.circle,
              border: Border.all(color: colors.glassBorder, width: 1),
            ),
            child: Center(
              child: Icon(
                uiIcon('arrow-left'),
                size: 20,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Por confirmar',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: PocktType.title,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Movimientos sugeridos',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.pockt;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.glassFill,
                shape: BoxShape.circle,
                border: Border.all(color: colors.glassBorder, width: 1),
              ),
              child: Center(
                child: Icon(uiIcon('check'), size: 32, color: colors.positive),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Todo al día',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No tenés movimientos pendientes por confirmar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Notificador que cuenta confirmaciones consecutivas de sugerencias
/// para disparar un backup automático al confirmar 3 o más sugerencias (Plan 4).
class ConsecutiveConfirmationsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void recordConfirmation() {
    state++;
    if (state >= 3) {
      state = 0;
      ref.read(backupServiceProvider).backupNow();
    }
  }
}

final consecutiveConfirmationsProvider =
    NotifierProvider<ConsecutiveConfirmationsNotifier, int>(
      ConsecutiveConfirmationsNotifier.new,
    );

class _SuggestionCard extends ConsumerStatefulWidget {
  final SuggestionView item;

  const _SuggestionCard({super.key, required this.item});

  @override
  ConsumerState<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends ConsumerState<_SuggestionCard> {
  bool _showRawText = false;
  bool _autoConfirmMerchant = false;

  SuggestionView get item => widget.item;

  Future<void> _confirm(BuildContext context) async {
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

    final picked = await showModalBottomSheet<Category>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final colors = sheetCtx.pockt;
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: Color.alphaBlend(colors.glassFill, colors.background),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PocktRadii.xl),
            ),
            border: Border.all(color: colors.glassBorder),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Elegí una categoría',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: PocktType.title,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cat in categories)
                          Pressable(
                            semanticLabel: cat.name,
                            onTap: () => Navigator.of(sheetCtx).pop(cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.glassFill,
                                borderRadius: BorderRadius.circular(
                                  PocktRadii.m,
                                ),
                                border: Border.all(color: colors.glassBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  categoryIcon(
                                    cat.icon,
                                    size: 16,
                                    color: Color(
                                      isDark ? cat.colorDark : cat.colorLight,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: PocktType.caption,
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
                ),
              ],
            ),
          ),
        );
      },
    );

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTransfer = item.suggestion.type == TxType.transfer;
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

    final catColor = item.category != null
        ? Color(isDark ? item.category!.colorDark : item.category!.colorLight)
        : (item.suggestion.type == TxType.income
              ? colors.positive
              : colors.brandStart);
    final canConfirmDirectly =
        item.suggestion.amount > 0 &&
        (item.category != null || isTransfer || isCapture);

    final title = item.suggestion.merchant?.isNotEmpty == true
        ? item.suggestion.merchant!
        : (item.category?.name ?? 'Movimiento sugerido');

    final whenText = formatTxWhen(
      toLocal(item.suggestion.occurredAt),
      toLocal(DateTime.now()),
    );
    final subtitleText = isTransfer
        ? 'Transferencia · No suma en gastos · $whenText'
        : whenText;

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
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isTransfer
                        ? colors.glassFill
                        : catColor.withValues(alpha: isDark ? 0.22 : 0.14),
                    border: isTransfer
                        ? Border.all(color: colors.glassBorder)
                        : null,
                  ),
                  child: Center(
                    child: isTransfer
                        ? Icon(
                            uiIcon('arrows-left-right', filled: true),
                            size: 20,
                            color: colors.textSecondary,
                          )
                        : categoryIcon(
                            item.category?.icon ??
                                (item.suggestion.type == TxType.income
                                    ? 'arrow-circle-down'
                                    : 'sparkle'),
                            size: 20,
                            color: catColor,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isCapture) ...[
                            Icon(
                              uiIcon('chat-text'),
                              size: 13,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              subtitleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: colors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.suggestion.amount > 0
                      ? formatGs(item.suggestion.amount)
                      : 'Sin monto',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: item.suggestion.amount > 0
                        ? (isTransfer
                              ? colors.textSecondary
                              : colors.textPrimary)
                        : colors.warning,
                  ),
                ),
              ],
            ),
            if (isDuplicate) ...[
              const SizedBox(height: 12),
              _DuplicateWarningBox(
                duplicateTxId: item.suggestion.duplicateTxId!,
              ),
            ],
            if (hasRawText) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Pressable(
                  key: ValueKey('toggle-raw-${item.suggestion.id}'),
                  semanticLabel: _showRawText
                      ? 'Ocultar mensaje'
                      : 'Ver mensaje',
                  onTap: () {
                    Haptics.tick();
                    setState(() => _showRawText = !_showRawText);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          uiIcon(_showRawText ? 'caret-up' : 'caret-down'),
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showRawText ? 'Ocultar mensaje' : 'Ver mensaje',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: PocktType.caption,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_showRawText) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.glassFill,
                    borderRadius: BorderRadius.circular(PocktRadii.m),
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: Text(
                    item.suggestion.rawText!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: PocktType.caption,
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
            if (showAutoConfirmOption) ...[
              const SizedBox(height: 10),
              Pressable(
                key: ValueKey('auto-confirm-${item.suggestion.id}'),
                semanticLabel: 'Confirmar siempre este comercio',
                onTap: () {
                  Haptics.tick();
                  setState(() => _autoConfirmMerchant = !_autoConfirmMerchant);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _autoConfirmMerchant
                              ? colors.brandStart
                              : colors.glassFill,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: _autoConfirmMerchant
                                ? colors.brandStart
                                : colors.glassBorder,
                          ),
                        ),
                        child: _autoConfirmMerchant
                            ? Center(
                                child: Icon(
                                  uiIcon('check'),
                                  size: 12,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Confirmar siempre este comercio',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: PocktType.caption,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (isDuplicate)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Pressable(
                    key: ValueKey('edit-${item.suggestion.id}'),
                    semanticLabel: 'Editar',
                    onTap: () => _edit(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.glassFill,
                        borderRadius: BorderRadius.circular(PocktRadii.l),
                        border: Border.all(color: colors.glassBorder, width: 1),
                      ),
                      child: Text(
                        'Editar',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Pressable(
                    key: ValueKey('dup-same-${item.suggestion.id}'),
                    semanticLabel: 'Es el mismo',
                    onTap: _resolveDuplicateSame,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.glassFill,
                        borderRadius: BorderRadius.circular(PocktRadii.l),
                        border: Border.all(color: colors.glassBorder, width: 1),
                      ),
                      child: Text(
                        'Es el mismo',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Pressable(
                    key: ValueKey('dup-other-${item.suggestion.id}'),
                    semanticLabel: 'Es otro',
                    onTap: canConfirmDirectly ? () => _confirm(context) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.brandStart, colors.brandEnd],
                        ),
                        borderRadius: BorderRadius.circular(PocktRadii.l),
                      ),
                      child: const Text(
                        'Es otro',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Pressable(
                    key: ValueKey('edit-${item.suggestion.id}'),
                    semanticLabel: 'Editar',
                    onTap: () => _edit(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.glassFill,
                        borderRadius: BorderRadius.circular(PocktRadii.l),
                        border: Border.all(color: colors.glassBorder, width: 1),
                      ),
                      child: Text(
                        'Editar',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Pressable(
                    key: ValueKey('confirm-${item.suggestion.id}'),
                    semanticLabel: 'Confirmar',
                    onTap: canConfirmDirectly ? () => _confirm(context) : null,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: canConfirmDirectly ? 1.0 : 0.4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.brandStart, colors.brandEnd],
                          ),
                          borderRadius: BorderRadius.circular(PocktRadii.l),
                        ),
                        child: const Text(
                          'Confirmar',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
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

class _DuplicateWarningBox extends ConsumerWidget {
  const _DuplicateWarningBox({required this.duplicateTxId});

  final String duplicateTxId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<Transaction?>(
      stream:
          (db.select(db.transactions)
                ..where((t) => t.id.equals(duplicateTxId))
                ..limit(1))
              .watchSingleOrNull(),
      builder: (context, snapshot) {
        final tx = snapshot.data;
        final manualLabel = tx != null
            ? '${tx.merchant?.trim().isNotEmpty == true ? tx.merchant! : (tx.note?.trim().isNotEmpty == true ? tx.note! : "Movimiento manual")} · ${formatGs(tx.amount)}'
            : 'Movimiento manual con el mismo monto';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(PocktRadii.m),
            border: Border.all(color: colors.warning.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(uiIcon('warning'), size: 16, color: colors.warning),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Posible duplicado',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: PocktType.caption,
                        fontWeight: FontWeight.w700,
                        color: colors.warning,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ya cargaste: $manualLabel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: PocktType.caption,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
