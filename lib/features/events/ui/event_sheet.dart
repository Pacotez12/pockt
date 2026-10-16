import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/events/data/events_repository.dart';

Future<void> showEventSheet(
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
