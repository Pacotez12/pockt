import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/home/domain/home_cards_config.dart';

/// Pantalla "Tarjetas del Inicio": permite reordenar arrastrando y
/// mostrar/ocultar quincena, calendario, sugerencias y últimos movimientos.
class HomeCardsScreen extends ConsumerStatefulWidget {
  const HomeCardsScreen({super.key});

  @override
  ConsumerState<HomeCardsScreen> createState() => _HomeCardsScreenState();
}

class _HomeCardsScreenState extends ConsumerState<HomeCardsScreen> {
  List<HomeCardItem>? _cards;

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final currentCards =
        _cards ?? ref.watch(homeCardsConfigProvider).value ?? HomeCardItem.defaultCards();
    final recentCount = ref.watch(recentCountProvider).value ?? 5;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Tarjetas del Inicio',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(uiIcon('arrow-left'), color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Nota fija: El total del mes siempre está primero
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Icon(uiIcon('sparkle'), size: 18, color: colors.brandStart),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'El total del mes siempre se muestra arriba de todo.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ORDEN Y VISIBILIDAD',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: currentCards.length,
              onReorderItem: (oldIndex, newIndex) async {
                Haptics.tick();
                final updated = List<HomeCardItem>.from(currentCards);
                final item = updated.removeAt(oldIndex);
                updated.insert(newIndex, item);
                setState(() => _cards = updated);
                final repo = ref.read(settingsRepositoryProvider);
                await repo.set(SettingsKeys.homeCards, HomeCardItem.encode(updated));
              },
              itemBuilder: (context, index) {
                final card = currentCards[index];
                return Padding(
                  key: ValueKey('card-${card.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              uiIcon('stack'),
                              size: 18,
                              color: colors.textTertiary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            card.label,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: card.visible ? colors.textPrimary : colors.textTertiary,
                            ),
                          ),
                        ),
                        Switch(
                          value: card.visible,
                          onChanged: (val) async {
                            Haptics.tick();
                            final updated = List<HomeCardItem>.from(currentCards);
                            updated[index] = card.copyWith(visible: val);
                            setState(() => _cards = updated);
                            final repo = ref.read(settingsRepositoryProvider);
                            await repo.set(
                                SettingsKeys.homeCards, HomeCardItem.encode(updated));
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'MOVIMIENTOS RECIENTES',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cantidad a mostrar',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [5, 10, 20].map((count) {
                      final isSelected = count == recentCount;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text('$count'),
                            selected: isSelected,
                            onSelected: (selected) async {
                              if (selected) {
                                Haptics.tick();
                                final repo = ref.read(settingsRepositoryProvider);
                                await repo.set(SettingsKeys.homeRecentCount, '$count');
                              }
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
