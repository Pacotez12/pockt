import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/events/data/events_repository.dart';
import 'package:pockt/features/events/ui/event_sheet.dart';
import 'package:pockt/features/events/ui/events_list_widgets.dart';
import 'package:pockt/features/events/ui/event_detail_screen.dart';

export 'package:pockt/features/events/ui/event_detail_header.dart';
export 'package:pockt/features/events/ui/event_detail_screen.dart';
export 'package:pockt/features/events/ui/event_detail_widgets.dart';
export 'package:pockt/features/events/ui/event_sheet.dart';
export 'package:pockt/features/events/ui/events_list_widgets.dart';

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
                    onTap: () => showEventSheet(context, ref),
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
                    return EmptyEventsView(
                      onCreate: () => showEventSheet(context, ref),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return EventCard(
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
