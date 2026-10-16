import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';

class EmptyEventsView extends StatelessWidget {
  final VoidCallback onCreate;

  const EmptyEventsView({super.key, required this.onCreate});

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

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleActive;

  const EventCard({
    super.key,
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
