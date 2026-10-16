import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/events/ui/events_screen.dart';
import 'package:pockt/features/goals/ui/goals_screen.dart';
import 'package:pockt/features/income/ui/income_schedule_screen.dart';
import 'package:pockt/features/loans/ui/loans_screen.dart';
import 'package:pockt/features/recurring/ui/recurring_screen.dart';
import 'package:pockt/features/capture/ui/capture_settings_screen.dart';
import 'package:pockt/features/settings/ui/category_keywords_screen.dart';
import 'package:pockt/features/settings/ui/settings_tiles.dart';

List<Widget> moneySettingsItems(BuildContext context, WidgetRef ref) {
  final colors = context.pockt;
  final repo = ref.watch(settingsRepositoryProvider);
  final scheduleAsync = ref
      .watch(incomeScheduleRepositoryProvider)
      .watchCurrent();
  return [
    StreamBuilder(
      stream: scheduleAsync,
      builder: (context, snapshot) {
        final schedule = snapshot.data;
        final subtitle = schedule != null
            ? (schedule.mode == 'biweekly' ? 'Quincenal' : 'Mensual')
            : 'Configurar cuándo cobrás';
        return SettingsTile(
          key: const ValueKey('settings-income-schedule-tile'),
          icon: 'calendar',
          title: 'Sueldo y cobros',
          subtitle: subtitle,
          iconColor: colors.brandAt(0),
          onTap: () {
            Haptics.tick();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const IncomeScheduleScreen()),
            );
          },
        );
      },
    ),
    SettingsSegmentTile<MonthStartMode>(
      key: const ValueKey('settings-period-month-start'),
      icon: 'clock',
      title: 'Inicio del mes',
      subtitle: 'Período para cálculos y presupuestos',
      iconColor: colors.brandAt(0),
      selectedValue:
          ref.watch(monthStartModeProvider).value ?? MonthStartMode.calendar,
      options: const [
        (value: MonthStartMode.calendar, label: 'Calendario'),
        (value: MonthStartMode.payday, label: 'Desde el cobro'),
      ],
      onSelected: (mode) => repo.set(SettingsKeys.periodMonthStart, mode.name),
    ),
    SettingsTile(
      key: const ValueKey('settings-categories-tile'),
      icon: 'tag',
      title: 'Categorías',
      subtitle: 'Personalizar y palabras clave',
      iconColor: colors.brandAt(0),
      onTap: () {
        Haptics.tick();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CategoryKeywordsScreen()),
        );
      },
    ),
    SettingsTile(
      key: const ValueKey('settings-recurring-tile'),
      icon: 'sparkle',
      title: 'Recurrentes',
      subtitle: 'Gastos fijos y suscripciones',
      iconColor: colors.brandAt(0),
      onTap: () {
        Haptics.tick();
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const RecurringScreen()));
      },
    ),
    SettingsTile(
      key: const ValueKey('settings-loans-tile'),
      icon: 'hand-coins',
      title: 'Préstamos y cuotas',
      subtitle: 'Deudas, cuotas y préstamos otorgados',
      iconColor: colors.brandAt(0),
      onTap: () {
        Haptics.tick();
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const LoansScreen()));
      },
    ),
    SettingsTile(
      key: const ValueKey('settings-goals-tile'),
      icon: 'target',
      title: 'Metas',
      subtitle: 'Ahorro para objetivos con proyección',
      iconColor: colors.brandAt(0),
      onTap: () {
        Haptics.tick();
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const GoalsScreen()));
      },
    ),
    SettingsTile(
      key: const ValueKey('settings-events-tile'),
      icon: 'calendar-star',
      title: 'Eventos',
      subtitle: 'Viajes, fiestas y gastos agrupados',
      iconColor: colors.brandAt(0),
      onTap: () {
        Haptics.tick();
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const EventsScreen()));
      },
    ),
    SettingsTile(
      key: const ValueKey('settings-capture-tile'),
      icon: 'chat-text',
      title: 'Captura automática',
      subtitle: 'Avisos por SMS de Itaú',
      iconColor: colors.brandAt(0),
      onTap: () {
        Haptics.tick();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CaptureSettingsScreen()),
        );
      },
    ),
  ];
}
