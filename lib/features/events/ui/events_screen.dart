import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/events/data/events_repository.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(eventsRepositoryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Pressable(
                    semanticLabel: 'Volver',
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.glassFill,
                          border: Border.all(color: colors.glassBorder),
                        ),
                        child: Center(
                          child: Icon(
                            uiIcon('arrow-left'),
                            size: 18,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Eventos',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Pressable(
                    key: const ValueKey('create-event-btn'),
                    semanticLabel: 'Crear evento',
                    onTap: () => _showEventSheet(context, ref),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.brandAt(0).withValues(alpha: 0.15),
                          border: Border.all(
                            color: colors.brandAt(0).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            uiIcon('plus'),
                            size: 18,
                            color: colors.brandAt(0),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Events list or empty state
            Expanded(
              child: StreamBuilder<List<Event>>(
                stream: repo.watchEvents(),
                builder: (context, snapshot) {
                  final events = snapshot.data ?? [];

                  if (events.isEmpty) {
                    return _EmptyEventsView(
                      onCreate: () => _showEventSheet(context, ref),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return _EventCard(
                        event: event,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  EventDetailScreen(eventId: event.id),
                            ),
                          );
                        },
                        onToggleActive: (val) async {
                          Haptics.tick();
                          await repo.setActive(event.id, val);
                        },
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
}

class _EmptyEventsView extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyEventsView({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.brandAt(0).withValues(alpha: 0.15),
                border: Border.all(
                  color: colors.brandAt(0).withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: Icon(
                  uiIcon('calendar-star', filled: true),
                  size: 32,
                  color: colors.brandAt(0),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No tenés eventos',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrupá los gastos de un viaje, una fiesta o un fin de semana especial para ver el total y en qué gastaste.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Pressable(
              key: const ValueKey('create-event-empty-btn'),
              onTap: onCreate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.brandAt(0),
                  borderRadius: BorderRadius.circular(PocktRadii.m),
                ),
                child: Text(
                  'Crear evento',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleActive;

  const _EventCard({
    required this.event,
    required this.onTap,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dateStr = event.endDate != null
        ? '${DateFormat('dd/MM/yyyy').format(event.startDate)} – ${DateFormat('dd/MM/yyyy').format(event.endDate!)}'
        : 'Desde ${DateFormat('dd/MM/yyyy').format(event.startDate)}';

    return Pressable(
      key: ValueKey('event-card-${event.id}'),
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: BorderRadius.circular(PocktRadii.l),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: event.isActive
                    ? colors.brandAt(0).withValues(alpha: isDark ? 0.25 : 0.15)
                    : colors.glassFill,
                border: Border.all(
                  color: event.isActive
                      ? colors.brandAt(0).withValues(alpha: 0.5)
                      : colors.glassBorder,
                ),
              ),
              child: Center(
                child: Icon(
                  uiIcon(event.icon, filled: event.isActive),
                  size: 22,
                  color: event.isActive
                      ? colors.brandAt(0)
                      : colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          event.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (event.isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.brandAt(0).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(PocktRadii.s),
                            border: Border.all(
                              color: colors.brandAt(0).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'Activo',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: PocktType.caption,
                              fontWeight: FontWeight.w700,
                              color: colors.brandAt(0),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              key: ValueKey('event-active-toggle-${event.id}'),
              value: event.isActive,
              activeTrackColor: colors.brandAt(0),
              onChanged: onToggleActive,
            ),
          ],
        ),
      ),
    );
  }
}

class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(eventsRepositoryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: StreamBuilder<EventDetail>(
          stream: repo.watchEventDetail(eventId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(colors.brandAt(0)),
                ),
              );
            }

            final detail = snapshot.data!;
            final event = detail.event;

            return Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Pressable(
                        semanticLabel: 'Volver',
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.glassFill,
                            border: Border.all(color: colors.glassBorder),
                          ),
                          child: Center(
                            child: Icon(
                              uiIcon('arrow-left'),
                              size: 18,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          event.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        key: const ValueKey('event-menu-btn'),
                        icon: Icon(
                          uiIcon('dots-three-vertical'),
                          color: colors.textSecondary,
                        ),
                        onSelected: (action) async {
                          if (action == 'edit') {
                            _showEventSheet(context, ref, existing: event);
                          } else if (action == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('¿Eliminar evento?'),
                                content: const Text(
                                  'Los movimientos vinculados no se borrarán, solo dejarán de pertenecer a este evento.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    key: const ValueKey(
                                      'confirm-delete-event-btn',
                                    ),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: Text(
                                      'Eliminar',
                                      style: TextStyle(color: colors.danger),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && context.mounted) {
                              await repo.deleteEvent(event.id);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            key: const ValueKey('edit-event-btn'),
                            value: 'edit',
                            child: const Text('Editar evento'),
                          ),
                          PopupMenuItem(
                            key: const ValueKey('delete-event-btn'),
                            value: 'delete',
                            child: Text(
                              'Eliminar evento',
                              style: TextStyle(color: colors.danger),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      // Header summary card
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        borderRadius: BorderRadius.circular(PocktRadii.xl),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors
                                    .brandAt(0)
                                    .withValues(alpha: 0.15),
                                border: Border.all(
                                  color: colors
                                      .brandAt(0)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  uiIcon(event.icon, filled: true),
                                  size: 28,
                                  color: colors.brandAt(0),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Total gastado',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatGs(detail.total),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${detail.count} ${detail.count == 1 ? "movimiento" : "movimientos"}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: colors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            // Active status switch
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Asignar gastos nuevos',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      event.isActive
                                          ? 'Activo · Los nuevos gastos se vinculan aquí'
                                          : 'Pausado · No se asignan gastos',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: PocktType.caption,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch.adaptive(
                                  key: const ValueKey(
                                    'event-detail-active-switch',
                                  ),
                                  value: event.isActive,
                                  activeTrackColor: colors.brandAt(0),
                                  onChanged: (val) async {
                                    Haptics.tick();
                                    await repo.setActive(event.id, val);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Desglose por categoría
                      Text(
                        'Desglose por categoría',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (detail.categoryBreakdown.isEmpty)
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          borderRadius: BorderRadius.circular(PocktRadii.l),
                          child: Center(
                            child: Text(
                              'Todavía no hay gastos asignados a este evento.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          borderRadius: BorderRadius.circular(PocktRadii.l),
                          child: Column(
                            children: detail.categoryBreakdown.map((item) {
                              final isDark =
                                  Theme.of(context).brightness ==
                                  Brightness.dark;
                              final catColor = Color(
                                isDark
                                    ? item.category.colorDark
                                    : item.category.colorLight,
                              );

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: catColor.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                          child: Center(
                                            child: categoryIcon(
                                              item.category.icon,
                                              size: 16,
                                              color: catColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            item.category.name,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          formatGs(item.total),
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${item.percentage.toStringAsFixed(0)} %',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: (item.percentage / 100).clamp(
                                          0.0,
                                          1.0,
                                        ),
                                        minHeight: 4,
                                        backgroundColor: colors.glassBorder,
                                        valueColor: AlwaysStoppedAnimation(
                                          catColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 24),
                      // Movimientos del evento
                      Text(
                        'Movimientos (${detail.transactions.length})',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (detail.transactions.isEmpty)
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          borderRadius: BorderRadius.circular(PocktRadii.l),
                          child: Center(
                            child: Text(
                              'Sin movimientos',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: detail.transactions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final row = detail.transactions[index];
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final catColor = Color(
                              isDark
                                  ? row.category.colorDark
                                  : row.category.colorLight,
                            );

                            final label =
                                row.tx.merchant != null &&
                                    row.tx.merchant!.trim().isNotEmpty
                                ? row.tx.merchant!
                                : row.category.name;

                            final note =
                                row.tx.note != null &&
                                    row.tx.note!.trim().isNotEmpty
                                ? row.tx.note!
                                : DateFormat('dd/MM HH:mm')
                                      .format(row.tx.occurredAt.toLocal());

                            return GlassCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              borderRadius: BorderRadius.circular(PocktRadii.m),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: catColor.withValues(alpha: 0.2),
                                    ),
                                    child: Center(
                                      child: categoryIcon(
                                        row.category.icon,
                                        size: 18,
                                        color: catColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          label,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: colors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          note,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: PocktType.caption,
                                            color: colors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatGs(row.tx.amount),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<void> _showEventSheet(
  BuildContext context,
  WidgetRef ref, {
  Event? existing,
}) async {
  final nameController = TextEditingController(text: existing?.name ?? '');
  var selectedIcon = existing?.icon ?? 'calendar-star';
  var startDate = existing?.startDate ?? DateTime.now();
  DateTime? endDate = existing?.endDate;
  var isActive = existing?.isActive ?? true;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final colors = sheetContext.pockt;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: colors.sheetSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(PocktRadii.xl),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    existing == null ? 'Nuevo evento' : 'Editar evento',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('event-name-input'),
                    controller: nameController,
                    autofocus: true,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ej. Viaje a Encarnación, Cumpleaños',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: colors.textSecondary.withValues(alpha: 0.6),
                      ),
                      labelText: 'Nombre del evento',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PocktRadii.m),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Icon picker
                  Text(
                    'Ícono',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: PocktType.caption,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kEventIconKeys.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final key = kEventIconKeys[index];
                        final isSelected = key == selectedIcon;

                        return Pressable(
                          semanticLabel: 'Ícono $key',
                          onTap: () {
                            Haptics.tick();
                            setSheetState(() => selectedIcon = key);
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? colors.brandAt(0)
                                  : colors.glassFill,
                              border: Border.all(
                                color: isSelected
                                    ? colors.brandAt(0)
                                    : colors.glassBorder,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                uiIcon(key, filled: isSelected),
                                size: 20,
                                color: isSelected
                                    ? Colors.white
                                    : colors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Active switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Marcar como evento activo',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                      ),
                      Switch.adaptive(
                        value: isActive,
                        activeTrackColor: colors.brandAt(0),
                        onChanged: (val) {
                          setSheetState(() => isActive = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Pressable(
                          semanticLabel: 'Cancelar',
                          onTap: () => Navigator.of(sheetContext).pop(),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.glassFill,
                              borderRadius: BorderRadius.circular(
                                PocktRadii.xl,
                              ),
                              border: Border.all(color: colors.glassBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Pressable(
                          key: const ValueKey('save-event-btn'),
                          semanticLabel: 'Guardar evento',
                          onTap: () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;

                            final repo = ref.read(eventsRepositoryProvider);
                            if (existing != null) {
                              await repo.updateEvent(
                                existing.id,
                                name: name,
                                icon: selectedIcon,
                                startDate: startDate,
                                endDate: endDate,
                              );
                              if (isActive != existing.isActive) {
                                await repo.setActive(existing.id, isActive);
                              }
                            } else {
                              await repo.createEvent(
                                name: name,
                                icon: selectedIcon,
                                startDate: startDate,
                                endDate: endDate,
                                isActive: isActive,
                              );
                            }
                            Haptics.save();
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [colors.brandStart, colors.brandEnd],
                              ),
                              borderRadius: BorderRadius.circular(
                                PocktRadii.xl,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.brandStart.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Guardar',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
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
        },
      );
    },
  );
}
