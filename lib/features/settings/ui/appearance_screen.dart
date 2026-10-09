import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(settingsRepositoryProvider);
    final appearanceAsync = repo.watch(SettingsKeys.appearance);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Pressable(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apariencia',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Tema visual de la aplicación',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<String?>(
                stream: appearanceAsync,
                builder: (context, snapshot) {
                  final currentSetting = snapshot.data ?? 'system';

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        borderRadius: BorderRadius.circular(22),
                        child: Column(
                          children: [
                            _AppearanceOptionTile(
                              key: const ValueKey('appearance-option-system'),
                              checkKey: const ValueKey('check-system'),
                              title: 'Sistema',
                              subtitle: 'Sigue el ajuste del teléfono',
                              iconKey: 'device-mobile',
                              isSelected: currentSetting == 'system',
                              onTap: () async {
                                Haptics.tick();
                                await repo.set(SettingsKeys.appearance, 'system');
                              },
                            ),
                            Divider(color: colors.glassBorder, height: 1),
                            _AppearanceOptionTile(
                              key: const ValueKey('appearance-option-light'),
                              checkKey: const ValueKey('check-light'),
                              title: 'Claro',
                              subtitle: 'Fondo blanco esmerilado',
                              iconKey: 'sun',
                              isSelected: currentSetting == 'light',
                              onTap: () async {
                                Haptics.tick();
                                await repo.set(SettingsKeys.appearance, 'light');
                              },
                            ),
                            Divider(color: colors.glassBorder, height: 1),
                            _AppearanceOptionTile(
                              key: const ValueKey('appearance-option-dark'),
                              checkKey: const ValueKey('check-dark'),
                              title: 'Oscuro',
                              subtitle: 'Fondo negro puro con resplandor',
                              iconKey: 'moon',
                              isSelected: currentSetting == 'dark',
                              onTap: () async {
                                Haptics.tick();
                                await repo.set(SettingsKeys.appearance, 'dark');
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
          ],
        ),
      ),
    );
  }
}

class _AppearanceOptionTile extends StatelessWidget {
  final Key? checkKey;
  final String title;
  final String subtitle;
  final String iconKey;
  final bool isSelected;
  final VoidCallback onTap;

  const _AppearanceOptionTile({
    super.key,
    this.checkKey,
    required this.title,
    required this.subtitle,
    required this.iconKey,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.brandStart.withValues(alpha: isDark ? 0.16 : 0.12),
              ),
              child: Center(
                child: Icon(
                  uiIcon(iconKey),
                  size: 18,
                  color: colors.brandStart,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Check animado sin saltos de layout
            SizedBox(
              width: 24,
              height: 24,
              child: AnimatedScale(
                scale: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: isSelected
                      ? Icon(
                          uiIcon('check'),
                          key: checkKey,
                          size: 18,
                          color: colors.brandStart,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
