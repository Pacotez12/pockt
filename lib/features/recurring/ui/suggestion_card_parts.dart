import 'package:flutter/material.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';

class SuggestionHeaderRow extends StatelessWidget {
  final SuggestionView item;

  const SuggestionHeaderRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTransfer = item.suggestion.type == TxType.transfer;
    final isCapture = item.suggestion.source == TxSource.capture;

    final catColor = item.category != null
        ? Color(isDark ? item.category!.colorDark : item.category!.colorLight)
        : (item.suggestion.type == TxType.income
              ? colors.positive
              : colors.brandStart);

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

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isTransfer
                ? colors.glassFill
                : catColor.withValues(alpha: isDark ? 0.22 : 0.14),
            border: isTransfer ? Border.all(color: colors.glassBorder) : null,
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
                    Builder(
                      builder: (context) {
                        final meta = item.suggestion.captureMeta;
                        final isEmail =
                            (meta != null &&
                                meta.contains('"channel":"email"')) ||
                            (item.suggestion.fingerprint?.startsWith('email:') ??
                                false);
                        return Icon(
                          uiIcon(isEmail ? 'envelope-simple' : 'chat-text'),
                          size: 13,
                          color: colors.textSecondary,
                        );
                      },
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
                ? (isTransfer ? colors.textSecondary : colors.textPrimary)
                : colors.warning,
          ),
        ),
      ],
    );
  }
}

class SuggestionRawTextToggle extends StatelessWidget {
  final String suggestionId;
  final String rawText;
  final bool expanded;
  final VoidCallback onToggle;

  const SuggestionRawTextToggle({
    super.key,
    required this.suggestionId,
    required this.rawText,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Pressable(
            key: ValueKey('toggle-raw-$suggestionId'),
            semanticLabel: expanded ? 'Ocultar mensaje' : 'Ver mensaje',
            onTap: () {
              Haptics.tick();
              onToggle();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    uiIcon(expanded ? 'caret-up' : 'caret-down'),
                    size: 14,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    expanded ? 'Ocultar mensaje' : 'Ver mensaje',
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
        if (expanded) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: BorderRadius.circular(PocktRadii.m),
              border: Border.all(color: colors.glassBorder),
            ),
            child: Text(
              rawText,
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
    );
  }
}

class AutoConfirmMerchantToggle extends StatelessWidget {
  final String suggestionId;
  final bool checked;
  final VoidCallback onToggle;

  const AutoConfirmMerchantToggle({
    super.key,
    required this.suggestionId,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    return Pressable(
      key: ValueKey('auto-confirm-$suggestionId'),
      semanticLabel: 'Confirmar siempre este comercio',
      onTap: () {
        Haptics.tick();
        onToggle();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: checked ? colors.brandStart : colors.glassFill,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: checked ? colors.brandStart : colors.glassBorder,
                ),
              ),
              child: checked
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
    );
  }
}

class SuggestionActionRow extends StatelessWidget {
  final SuggestionView item;
  final VoidCallback onEdit;
  final VoidCallback onConfirm;
  final VoidCallback onResolveSame;

  const SuggestionActionRow({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onConfirm,
    required this.onResolveSame,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isTransfer = item.suggestion.type == TxType.transfer;
    final isCapture = item.suggestion.source == TxSource.capture;
    final isDuplicate = item.suggestion.isPossibleDuplicate;
    final canConfirmDirectly =
        item.suggestion.amount > 0 &&
        (item.category != null || isTransfer || isCapture);

    if (isDuplicate) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Pressable(
            key: ValueKey('edit-${item.suggestion.id}'),
            semanticLabel: 'Editar',
            onTap: () => onEdit(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            onTap: onResolveSame,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            onTap: canConfirmDirectly ? () => onConfirm() : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Pressable(
          key: ValueKey('edit-${item.suggestion.id}'),
          semanticLabel: 'Editar',
          onTap: () => onEdit(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          onTap: canConfirmDirectly ? () => onConfirm() : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: canConfirmDirectly ? 1.0 : 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
    );
  }
}
