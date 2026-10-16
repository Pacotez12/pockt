import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/events/data/events_repository.dart';
import 'package:pockt/features/events/ui/event_detail_header.dart';
import 'package:pockt/features/events/ui/event_detail_widgets.dart';

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
                EventDetailAppBar(event: event),
                // Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      // Header summary card
                      EventSummaryCard(event: event, detail: detail),
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
                      EventCategoryBreakdownCard(detail: detail),
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
                      EventTransactionsList(detail: detail),
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
