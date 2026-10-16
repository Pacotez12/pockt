import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/events/data/events_repository.dart';
import 'package:pockt/features/events/ui/event_sheet.dart';

class EventDetailAppBar extends ConsumerWidget {
  final Event event;

  const EventDetailAppBar({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(eventsRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                showEventSheet(context, ref, existing: event);
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
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        key: const ValueKey('confirm-delete-event-btn'),
                        onPressed: () => Navigator.of(ctx).pop(true),
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
    );
  }
}

class EventSummaryCard extends ConsumerWidget {
  final Event event;
  final EventDetail detail;

  const EventSummaryCard({
    super.key,
    required this.event,
    required this.detail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(eventsRepositoryProvider);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.brandAt(0).withValues(alpha: 0.15),
              border: Border.all(
                color: colors.brandAt(0).withValues(alpha: 0.4),
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
                key: const ValueKey('event-detail-active-switch'),
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
    );
  }
}
