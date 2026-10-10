import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

/// Distancia desde el borde inferior para que el aviso flote sobre la barra
/// de navegación de vidrio (18 de margen + 64 de barra + aire).
const double _kSnackBottomClearance = 96;

/// Borra (soft delete) y muestra "Movimiento borrado · Deshacer" durante 5 s en
/// el [ScaffoldMessenger] raíz, para que el aviso sobreviva a cambios de
/// pestaña y al cierre de hojas. El repositorio se captura antes del `await`
/// para que "Deshacer" funcione aunque el widget que borró ya no exista.
Future<void> deleteWithUndo(BuildContext context, WidgetRef ref, String txId) async {
  final repo = ref.read(transactionsRepositoryProvider);
  final messenger = context.findRootAncestorStateOfType<ScaffoldMessengerState>() ??
      ScaffoldMessenger.of(context);
  final colors = context.pockt;

  Haptics.tick();
  await repo.softDelete(txId);

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        persist: false,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, _kSnackBottomClearance),
        elevation: 0,
        backgroundColor: Color.alphaBlend(colors.glassFill, colors.background),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.glassBorder),
        ),
        content: Row(
          children: [
            Icon(uiIcon('trash'), size: 16, color: colors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Movimiento borrado',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: colors.brandStart,
          onPressed: () {
            Haptics.tick();
            repo.restore(txId);
          },
        ),
      ),
    );
}

/// Título de una fila: comercio, nota o, si no hay, el nombre de la categoría.
String txTitle(TxView v) {
  final merchant = v.tx.merchant?.trim();
  if (merchant != null && merchant.isNotEmpty) return merchant;
  final note = v.tx.note?.trim();
  if (note != null && note.isNotEmpty) return note;
  return v.category.name;
}

/// Fila visual de un movimiento: ícono de categoría, título, subtítulo y monto.
class TxRow extends StatelessWidget {
  final TxView view;
  final String subtitle;
  final EdgeInsetsGeometry padding;

  const TxRow({
    super.key,
    required this.view,
    required this.subtitle,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = Color(isDark ? view.category.colorDark : view.category.colorLight);
    final isIncome = view.tx.type == TxType.income;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: catColor.withValues(alpha: isDark ? 0.16 : 0.12),
            ),
            child: Center(
              child: categoryIcon(view.category.icon, size: 17, color: catColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  txTitle(view),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isIncome
                ? '+${formatGs(view.tx.amount, symbol: false)}'
                : formatGs(view.tx.amount, symbol: false),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isIncome ? colors.positive : colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila deslizable: hacia la izquierda borra (con deshacer), hacia la derecha
/// abre la edición. El fondo de acción ocupa la fila entera y sigue el radio
/// de las esquinas de la tarjeta sin recortes.
class SwipeableTxRow extends ConsumerStatefulWidget {
  final TxView view;
  final String subtitle;
  final bool? isFirst;
  final bool? isLast;
  final double cardRadius;
  final EdgeInsetsGeometry? padding;

  SwipeableTxRow({
    required this.view,
    required this.subtitle,
    this.isFirst,
    this.isLast,
    this.cardRadius = 24.0,
    this.padding,
  }) : super(key: ValueKey('tx-row-${view.tx.id}'));

  @override
  ConsumerState<SwipeableTxRow> createState() => _SwipeableTxRowState();
}

class _SwipeableTxRowState extends ConsumerState<SwipeableTxRow> {
  bool _gone = false;

  @override
  void didUpdateWidget(SwipeableTxRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // "Deshacer" cambia updatedAt: si el mismo movimiento vuelve, se muestra.
    if (oldWidget.view.tx.updatedAt != widget.view.tx.updatedAt) {
      _gone = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final BorderRadius rowRadius;
    if (widget.isFirst == null && widget.isLast == null) {
      rowRadius = BorderRadius.circular(16);
    } else {
      rowRadius = BorderRadius.vertical(
        top: (widget.isFirst ?? false) ? Radius.circular(widget.cardRadius) : Radius.zero,
        bottom: (widget.isLast ?? false) ? Radius.circular(widget.cardRadius) : Radius.zero,
      );
    }

    Widget actionBackground({
      required Key key,
      required Alignment alignment,
      required Color color,
      required IconData icon,
      required Color iconColor,
    }) {
      return Container(
        key: key,
        decoration: BoxDecoration(
          color: color,
          borderRadius: rowRadius,
        ),
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(icon, size: 20, color: iconColor),
      );
    }

    final rowBackground = Color.alphaBlend(colors.glassFill, colors.background);

    return Dismissible(
      key: ValueKey('dismiss-${widget.view.tx.id}'),
      dismissThresholds: const {
        DismissDirection.endToStart: 0.35,
        DismissDirection.startToEnd: 0.25,
      },
      background: actionBackground(
        key: const ValueKey('tx-action-bg-edit'),
        alignment: Alignment.centerLeft,
        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
        icon: uiIcon('pencil-simple'),
        iconColor: colors.textPrimary,
      ),
      secondaryBackground: actionBackground(
        key: const ValueKey('tx-action-bg-delete'),
        alignment: Alignment.centerRight,
        color: colors.brandEnd.withValues(alpha: 0.85),
        icon: uiIcon('trash'),
        iconColor: Colors.white,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          Haptics.tick();
          await showEntryFlow(context, editing: widget.view);
          return false;
        }
        return true;
      },
      onDismissed: (_) {
        setState(() => _gone = true);
        deleteWithUndo(context, ref, widget.view.tx.id);
      },
      child: Container(
        decoration: BoxDecoration(
          color: rowBackground,
          borderRadius: rowRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: TxRow(
          view: widget.view,
          subtitle: widget.subtitle,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    );
  }
}

/// Tarjeta de vidrio para agrupar filas de movimientos en una sola tarjeta visual
/// sin recortes en los bordes y asegurando esquinas continuas.
class TxGroupCard extends StatelessWidget {
  final List<TxView> items;
  final String Function(TxView view) subtitleBuilder;
  final double cardRadius;
  final Widget? emptyPlaceholder;

  const TxGroupCard({
    super.key,
    required this.items,
    required this.subtitleBuilder,
    this.cardRadius = 24.0,
    this.emptyPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      if (emptyPlaceholder != null) {
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          borderRadius: BorderRadius.circular(cardRadius),
          child: Center(child: emptyPlaceholder),
        );
      }
      return const SizedBox.shrink();
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(cardRadius),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++)
            SwipeableTxRow(
              view: items[i],
              subtitle: subtitleBuilder(items[i]),
              isFirst: i == 0,
              isLast: i == items.length - 1,
              cardRadius: cardRadius,
            ),
        ],
      ),
    );
  }
}
