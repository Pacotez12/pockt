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
                  fontSize: 22,
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
                child: Icon(
                  uiIcon('check'),
                  size: 32,
                  color: colors.positive,
                ),
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

class _SuggestionCard extends ConsumerWidget {
  final SuggestionView item;

  const _SuggestionCard({super.key, required this.item});

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(suggestionsRepositoryProvider);
    await repo.confirm(item.suggestion.id);
    Haptics.save();
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    Category? category = item.category;
    if (category == null) {
      final db = ref.read(databaseProvider);
      final catList = await (db.select(db.categories)
            ..where((c) => c.kind.equalsValue(
                  item.suggestion.type == TxType.income
                      ? CategoryKind.income
                      : CategoryKind.expense,
                ))
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
      type: item.suggestion.type,
      initialAmount:
          item.suggestion.amount > 0 ? item.suggestion.amount : null,
      initialDate: toLocal(item.suggestion.occurredAt),
      initialMerchant: item.suggestion.merchant,
      onSaveOverride: ({
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = item.category != null
        ? Color(isDark ? item.category!.colorDark : item.category!.colorLight)
        : (item.suggestion.type == TxType.income
            ? colors.positive
            : colors.brandStart);
    final canConfirmDirectly =
        item.suggestion.amount > 0 && item.category != null;

    final title = item.suggestion.merchant?.isNotEmpty == true
        ? item.suggestion.merchant!
        : (item.category?.name ?? 'Movimiento sugerido');

    return Dismissible(
      key: ValueKey('dismiss-${item.suggestion.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
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
                    color: catColor.withValues(alpha: isDark ? 0.22 : 0.14),
                  ),
                  child: Center(
                    child: categoryIcon(
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
                      Text(
                        formatTxWhen(
                          toLocal(item.suggestion.occurredAt),
                          toLocal(DateTime.now()),
                        ),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
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
                        ? colors.textPrimary
                        : colors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Pressable(
                  key: ValueKey('edit-${item.suggestion.id}'),
                  onTap: () => _edit(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.glassFill,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colors.glassBorder,
                        width: 1,
                      ),
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
                  onTap: canConfirmDirectly ? () => _confirm(context, ref) : null,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: canConfirmDirectly ? 1.0 : 0.4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: catColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Confirmar',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: catColor.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
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
