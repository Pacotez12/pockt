import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/income/ui/income_schedule_screen.dart';
import 'package:pockt/features/recurring/ui/recurring_screen.dart';
import 'package:pockt/features/settings/ui/category_keywords_screen.dart';

/// Hub principal de Ajustes (spec §5.10):
/// Categorías · Esquema de cobro · Recurrentes
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final scheduleAsync = ref.watch(incomeScheduleRepositoryProvider).watchCurrent();

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
                          'Ajustes',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Preferencias y configuración',
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
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SettingsTile(
                    key: const ValueKey('settings-categories-tile'),
                    icon: 'tag',
                    title: 'Categorías',
                    subtitle: 'Personalizar y palabras clave',
                    iconColor: colors.brandStart,
                    onTap: () {
                      Haptics.tick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategoryKeywordsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder(
                    stream: scheduleAsync,
                    builder: (context, snapshot) {
                      final schedule = snapshot.data;
                      final subtitle = schedule != null
                          ? (schedule.mode == 'biweekly' ? 'Quincenal' : 'Mensual')
                          : 'Configurar cuándo cobrás';

                      return _SettingsTile(
                        key: const ValueKey('settings-income-schedule-tile'),
                        icon: 'calendar',
                        title: 'Esquema de cobro',
                        subtitle: subtitle,
                        iconColor: colors.positive,
                        onTap: () {
                          Haptics.tick();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const IncomeScheduleScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    key: const ValueKey('settings-recurring-tile'),
                    icon: 'sparkle',
                    title: 'Recurrentes',
                    subtitle: 'Gastos fijos y suscripciones',
                    iconColor: colors.brandEnd,
                    onTap: () {
                      Haptics.tick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RecurringScreen(),
                        ),
                      );
                    },
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

class _SettingsTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Pressable(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: isDark ? 0.16 : 0.12),
              ),
              child: Center(
                child: Icon(
                  uiIcon(icon),
                  size: 18,
                  color: iconColor,
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
            Icon(
              uiIcon('caret-right'),
              size: 16,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
