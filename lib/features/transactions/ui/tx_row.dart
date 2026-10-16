import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/amounts_privacy.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/ui/goal_detail_screen.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

/// Distancia desde el borde inferior para que el aviso flote sobre la barra
/// de navegación de vidrio (18 de margen + 64 de barra + aire).
const double _kSnackBottomClearance = 96;

/// Borra (soft delete) y muestra "Movimiento borrado · Deshacer" durante 5 s en
/// el [ScaffoldMessenger] raíz, para que el aviso sobreviva a cambios de
/// pestaña y al cierre de hojas. El repositorio se captura antes del `await`
/// para que "Deshacer" funcione aunque el widget que borró ya no exista.
Future<void> deleteWithUndo(
  BuildContext context,
  WidgetRef ref,
  String txId,
) async {
  final repo = ref.read(transactionsRepositoryProvider);
  final messenger =
      context.findRootAncestorStateOfType<ScaffoldMessengerState>() ??
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
          borderRadius: BorderRadius.circular(PocktRadii.l),
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
    final catColor = Color(
      isDark ? view.category.colorDark : view.category.colorLight,
    );
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
              child: categoryIcon(
                view.category.icon,
                size: 17,
                color: catColor,
              ),
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
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Consumer(
            builder: (context, ref, _) {
              final obscure = ref.watch(shouldObscureAmountsProvider);
              final text = obscure
                  ? '••••'
                  : (isIncome
                        ? '+${formatGs(view.tx.amount, symbol: false)}'
                        : formatGs(view.tx.amount, symbol: false));
              return Text(
                text,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isIncome ? colors.positive : colors.textPrimary,
                ),
              );
            },
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

    final BorderRadius rowRadius;
    if (widget.isFirst == null && widget.isLast == null) {
      rowRadius = BorderRadius.circular(PocktRadii.l);
    } else {
      rowRadius = BorderRadius.vertical(
        top: (widget.isFirst ?? false)
            ? Radius.circular(widget.cardRadius)
            : Radius.zero,
        bottom: (widget.isLast ?? false)
            ? Radius.circular(widget.cardRadius)
            : Radius.zero,
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
        decoration: BoxDecoration(color: color, borderRadius: rowRadius),
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
        color: colors.keypadKey,
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
          padding:
              widget.padding ??
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    );
  }
}

sealed class MovementEntry {
  DateTime get date;
}

class TxMovementEntry extends MovementEntry {
  final TxView view;
  TxMovementEntry(this.view);

  @override
  DateTime get date => view.tx.occurredAt;
}

class GoalContributionMovementEntry extends MovementEntry {
  final GoalContributionWithGoal item;
  GoalContributionMovementEntry(this.item);

  @override
  DateTime get date => item.contribution.date;
}

class GoalContributionRow extends ConsumerWidget {
  final GoalContributionWithGoal item;
  final String subtitle;
  final EdgeInsetsGeometry padding;

  const GoalContributionRow({
    super.key,
    required this.item,
    required this.subtitle,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isWithdraw = item.contribution.amount < 0;
    final title = isWithdraw
        ? 'Retiro · ${item.goal.name}'
        : 'Aporte · ${item.goal.name}';
    final obscure = ref.watch(shouldObscureAmountsProvider);
    final absAmount = item.contribution.amount.abs();
    final amountStr = obscure ? '••••' : formatGs(absAmount, symbol: false);

    return Pressable(
      key: ValueKey('goal-contrib-${item.contribution.id}'),
      semanticLabel: '$title, $amountStr, $subtitle',
      onTap: () {
        Haptics.tick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GoalDetailScreen(goalId: item.goal.id),
          ),
        );
      },
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.glassFill,
                border: Border.all(color: colors.glassBorder),
              ),
              child: Center(
                child: Icon(
                  uiIcon(item.goal.icon, filled: true),
                  size: 17,
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: PocktType.body,
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
                      fontSize: PocktType.caption,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amountStr,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: PocktType.body,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de vidrio para agrupar filas de movimientos en una sola tarjeta visual
/// sin recortes en los bordes y asegurando esquinas continuas.
class TxGroupCard extends StatelessWidget {
  final List<MovementEntry> entries;
  final String Function(TxView view)? subtitleBuilder;
  final String Function(GoalContributionWithGoal item)? contribSubtitleBuilder;
  final double cardRadius;
  final Widget? emptyPlaceholder;

  TxGroupCard({
    super.key,
    List<TxView>? items,
    List<MovementEntry>? entries,
    this.subtitleBuilder,
    this.contribSubtitleBuilder,
    this.cardRadius = 24.0,
    this.emptyPlaceholder,
  }) : entries =
           entries ?? (items?.map(TxMovementEntry.new).toList() ?? const []);

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
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
          for (int i = 0; i < entries.length; i++) ...[
            switch (entries[i]) {
              TxMovementEntry(:final view) => SwipeableTxRow(
                view: view,
                subtitle: subtitleBuilder != null ? subtitleBuilder!(view) : '',
                isFirst: i == 0,
                isLast: i == entries.length - 1,
                cardRadius: cardRadius,
              ),
              GoalContributionMovementEntry(:final item) => GoalContributionRow(
                item: item,
                subtitle: contribSubtitleBuilder != null
                    ? contribSubtitleBuilder!(item)
                    : (item.contribution.note?.isNotEmpty == true
                          ? item.contribution.note!
                          : ''),
              ),
            },
          ],
        ],
      ),
    );
  }
}

/// Combina movimientos normales y aportes a metas en un único flujo ordenado
/// cronológicamente de forma descendente.
Stream<List<MovementEntry>> combineMovements({
  required Stream<List<TxView>> txStream,
  required Stream<List<GoalContributionWithGoal>> contribStream,
  String? query,
  TxType? typeFilter,
  int? limit,
}) {
  late StreamController<List<MovementEntry>> controller;
  List<TxView> lastTxs = const [];
  List<GoalContributionWithGoal> lastContribs = const [];
  StreamSubscription? sub1;
  StreamSubscription? sub2;

  void emit() {
    final entries = <MovementEntry>[];
    for (final tx in lastTxs) {
      entries.add(TxMovementEntry(tx));
    }
    // Los aportes no son gastos de categoría ni ingresos: solo se muestran si no hay filtro de tipo
    if (typeFilter == null) {
      for (final c in lastContribs) {
        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim().toLowerCase();
          final matchesGoal = c.goal.name.toLowerCase().contains(q);
          final matchesNote =
              c.contribution.note?.toLowerCase().contains(q) ?? false;
          if (!matchesGoal && !matchesNote) continue;
        }
        entries.add(GoalContributionMovementEntry(c));
      }
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    if (limit != null && entries.length > limit) {
      controller.add(entries.sublist(0, limit));
    } else {
      controller.add(entries);
    }
  }

  controller = StreamController<List<MovementEntry>>(
    onListen: () {
      sub1 = txStream.listen((txs) {
        lastTxs = txs;
        emit();
      }, onError: controller.addError);

      sub2 = contribStream.listen((contribs) {
        lastContribs = contribs;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () {
      sub1?.cancel();
      sub2?.cancel();
    },
  );

  return controller.stream;
}
