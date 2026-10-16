import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/entry/data/entry_shortcuts_repository.dart';
import 'package:pockt/features/entry/domain/entry_shortcut.dart';
import 'package:pockt/features/events/data/events_repository.dart';

class ActiveEventChip extends ConsumerWidget {
  const ActiveEventChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeEventAsync = ref.watch(activeEventProvider);
    final activeEvent = activeEventAsync.value;
    if (activeEvent == null) return const SizedBox.shrink();

    final colors = context.pockt;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
      child: Container(
        key: const ValueKey('active-event-chip'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: colors.brandAt(0).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(PocktRadii.m),
          border: Border.all(color: colors.brandAt(0).withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              uiIcon(activeEvent.icon, filled: true),
              size: 14,
              color: colors.brandAt(0),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Evento activo: ${activeEvent.name}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.brandAt(0),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EntryShortcutsBar extends ConsumerWidget {
  final ValueChanged<EntryShortcutItem> onShortcutTapped;

  const EntryShortcutsBar({super.key, required this.onShortcutTapped});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortcutsAsync = ref.watch(entryShortcutsProvider);
    final shortcuts = shortcutsAsync.value ?? const [];
    if (shortcuts.isEmpty) return const SizedBox.shrink();

    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: shortcuts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = shortcuts[index];
              final catColor = isDark ? item.colorDark : item.colorLight;

              return Pressable(
                semanticLabel: 'Atajo ${item.label}, ${formatGs(item.amount)}',
                onTap: () {
                  Haptics.tick();
                  onShortcutTapped(item);
                },
                onLongPress: () {
                  Haptics.save();
                  _showShortcutOptions(context, ref, item);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.glassFill,
                    borderRadius: BorderRadius.circular(PocktRadii.xl),
                    border: Border.all(
                      color: item.isPinned
                          ? colors.brandAt(0).withValues(alpha: 0.5)
                          : colors.glassBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(catColor).withValues(alpha: 0.2),
                        ),
                        child: Center(
                          child: Icon(
                            uiIcon(item.categoryIcon),
                            size: 11,
                            color: Color(catColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '·',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatGs(item.amount),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      if (item.isPinned) ...[
                        const SizedBox(width: 4),
                        Icon(
                          uiIcon('push-pin'),
                          size: 12,
                          color: colors.brandAt(0),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showShortcutOptions(
    BuildContext context,
    WidgetRef ref,
    EntryShortcutItem item,
  ) {
    final colors = context.pockt;
    final repo = ref.read(entryShortcutsRepositoryProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.sheetSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PocktRadii.xl),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${formatGs(item.amount)} · ${item.categoryName}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  item.isPinned ? uiIcon('push-pin-slash') : uiIcon('push-pin'),
                  color: colors.textPrimary,
                ),
                title: Text(
                  item.isPinned ? 'Desfijar atajo' : 'Fijar atajo arriba',
                  style: TextStyle(color: colors.textPrimary),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  if (item.isPinned) {
                    await repo.unpinShortcut(item.id);
                  } else {
                    await repo.pinShortcut(item);
                  }
                },
              ),
              ListTile(
                leading: Icon(uiIcon('x'), color: colors.danger),
                title: Text(
                  'Quitar de sugerencias',
                  style: TextStyle(color: colors.danger),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await repo.dismissShortcut(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
