import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/notifications/notifier.dart' show notifierProvider;
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';
import 'package:pockt/features/backup/ui/backup_screen.dart';
import 'package:pockt/features/home/ui/home_cards_screen.dart';
import 'package:pockt/features/goals/ui/goals_screen.dart';
import 'package:pockt/features/income/ui/income_schedule_screen.dart';
import 'package:pockt/features/loans/ui/loans_screen.dart';
import 'package:pockt/features/recurring/ui/recurring_screen.dart';
import 'package:pockt/features/reminders/ui/reminders_screen.dart';
import 'package:pockt/features/security/app_lock.dart';
import 'package:pockt/features/settings/domain/export_csv.dart';
import 'package:pockt/features/settings/domain/wipe_data.dart';
import 'package:pockt/features/widget/home_widget_bridge.dart';
import 'package:pockt/features/safe_to_spend/domain/tone.dart';
import 'package:pockt/features/settings/ui/appearance_screen.dart';
import 'package:pockt/features/settings/ui/category_keywords_screen.dart';

/// Hub principal de Ajustes (spec §7b).
/// Organizado en cinco secciones con tarjetas de vidrio y controles en línea:
/// 1. Tu dinero
/// 2. Carga
/// 3. Inicio y apariencia
/// 4. Avisos
/// 5. Privacidad y datos
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
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
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SettingsGroup(
                    children: [
                      _SectionEntry(
                        key: const ValueKey('settings-section-money'),
                        icon: 'coins',
                        title: 'Tu dinero',
                        subtitle: 'Sueldo, inicio del mes, categorías, recurrentes y préstamos',
                        color: colors.brandAt(0),
                        builder: _moneyItems,
                      ),
                      _SectionEntry(
                        key: const ValueKey('settings-section-entry'),
                        icon: 'keyboard',
                        title: 'Carga',
                        subtitle: 'Orden de categorías, tecla rápida, nota y vibración',
                        color: colors.brandAt(1),
                        builder: _entryItems,
                      ),
                      _SectionEntry(
                        key: const ValueKey('settings-section-home'),
                        icon: 'paint-brush',
                        title: 'Inicio y apariencia',
                        subtitle:
                            'Tema, tarjetas, aurora, semana y animaciones',
                        color: colors.brandAt(2),
                        builder: _homeItems,
                      ),
                      _SectionEntry(
                        key: const ValueKey('settings-section-alerts'),
                        icon: 'bell',
                        title: 'Avisos',
                        subtitle: 'Recordatorios y alertas de presupuesto',
                        color: colors.brandAt(3),
                        builder: _alertsItems,
                      ),
                      _SectionEntry(
                        key: const ValueKey('settings-section-privacy'),
                        icon: 'lock',
                        title: 'Privacidad y datos',
                        subtitle: 'Bloqueo, montos ocultos, backup, exportar y borrar',
                        color: colors.brandAt(3),
                        builder: _privacyItems,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _moneyItems(BuildContext context, WidgetRef ref) {
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
          return _SettingsTile(
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
      _SettingsSegmentTile<MonthStartMode>(
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
        onSelected: (mode) =>
            repo.set(SettingsKeys.periodMonthStart, mode.name),
      ),
      _SettingsTile(
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
      _SettingsTile(
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
      _SettingsTile(
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
      _SettingsTile(
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
    ];
  }

  List<Widget> _entryItems(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(settingsRepositoryProvider);
    return [
      _SettingsSegmentTile<CategoryOrder>(
        key: const ValueKey('settings-category-order'),
        icon: 'sort-ascending',
        title: 'Orden de categorías',
        subtitle: 'Disposición de la grilla de carga',
        iconColor: colors.brandAt(1),
        selectedValue:
            ref.watch(categoryOrderProvider).value ?? CategoryOrder.mostUsed,
        options: const [
          (value: CategoryOrder.mostUsed, label: 'Más usadas'),
          (value: CategoryOrder.manual, label: 'Manual'),
        ],
        onSelected: (val) =>
            repo.set(SettingsKeys.entryCategoryOrder, val.name),
      ),
      _SettingsSegmentTile<String>(
        key: const ValueKey('settings-quick-key'),
        icon: 'keyboard',
        title: 'Tecla rápida',
        subtitle: 'Acceso en el teclado numérico',
        iconColor: colors.brandAt(1),
        selectedValue: ref.watch(quickKeyProvider).value ?? '000',
        options: const [
          (value: '000', label: '000'),
          (value: '00', label: '00'),
        ],
        onSelected: (val) => repo.set(SettingsKeys.entryQuickKey, val),
      ),
      _SettingsSwitchTile(
        key: const ValueKey('settings-ask-note-switch'),
        icon: 'note-pencil',
        title: 'Pedir nota al guardar',
        subtitle: 'Muestra campo de nota antes de guardar',
        iconColor: colors.brandAt(1),
        value: ref.watch(askNoteProvider).value ?? false,
        onChanged: (val) => repo.set(SettingsKeys.entryAskNote, val.toString()),
      ),
      _SettingsSwitchTile(
        key: const ValueKey('settings-haptics-switch'),
        icon: 'waveform',
        title: 'Vibración',
        subtitle: 'Respuesta táctil al presionar botones',
        iconColor: colors.brandAt(1),
        value: ref.watch(hapticsEnabledProvider).value ?? true,
        onChanged: (val) =>
            repo.set(SettingsKeys.feedbackHaptics, val.toString()),
      ),
    ];
  }

  List<Widget> _homeItems(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(settingsRepositoryProvider);
    return [
      Consumer(
        builder: (context, ref, _) {
          final appearanceAsync = ref.watch(appearanceProvider);
          final mode = appearanceAsync.value ?? ThemeMode.system;
          final subtitle = switch (mode) {
            ThemeMode.dark => 'Oscuro',
            ThemeMode.light => 'Claro',
            ThemeMode.system => 'Sistema',
          };
          return _SettingsTile(
            key: const ValueKey('settings-appearance-tile'),
            icon: 'paint-brush',
            title: 'Apariencia',
            subtitle: subtitle,
            iconColor: colors.brandAt(2),
            onTap: () {
              Haptics.tick();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppearanceScreen()),
              );
            },
          );
        },
      ),
      _SettingsTile(
        key: const ValueKey('settings-home-cards-tile'),
        icon: 'cards',
        title: 'Tarjetas del Inicio',
        subtitle: 'Reordenar arrastrando y ocultar',
        iconColor: colors.brandAt(2),
        onTap: () {
          Haptics.tick();
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const HomeCardsScreen()));
        },
      ),
      _SettingsSegmentTile<HomeHeadline>(
        key: const ValueKey('settings-home-headline'),
        icon: 'gauge',
        title: 'Número principal',
        subtitle: 'Información destacada en la portada',
        iconColor: colors.brandAt(2),
        selectedValue:
            ref.watch(homeHeadlineProvider).value ?? HomeHeadline.safeToSpend,
        options: const [
          (value: HomeHeadline.safeToSpend, label: 'Podés gastar hoy'),
          (value: HomeHeadline.monthSpent, label: 'Gastado en el mes'),
        ],
        onSelected: (val) => repo.set(SettingsKeys.homeHeadline, val.name),
      ),
      _SettingsSegmentTile<int>(
        key: const ValueKey('settings-recent-count'),
        icon: 'list-numbers',
        title: 'Movimientos recientes',
        subtitle: 'Cantidad mostrada en el Inicio',
        iconColor: colors.brandAt(2),
        selectedValue: ref.watch(recentCountProvider).value ?? 5,
        options: const [
          (value: 5, label: '5'),
          (value: 10, label: '10'),
          (value: 20, label: '20'),
        ],
        onSelected: (val) =>
            repo.set(SettingsKeys.homeRecentCount, val.toString()),
      ),
      _SettingsSegmentTile<GlowMode>(
        key: const ValueKey('settings-glow-mode'),
        icon: 'sun',
        title: 'Resplandor aurora',
        subtitle: 'Intensidad del resplandor de fondo',
        iconColor: colors.brandAt(2),
        selectedValue: ref.watch(glowModeProvider).value ?? GlowMode.subtle,
        options: const [
          (value: GlowMode.off, label: 'Apagada'),
          (value: GlowMode.subtle, label: 'Sutil'),
          (value: GlowMode.full, label: 'Plena'),
        ],
        onSelected: (mode) => repo.set(SettingsKeys.glowMode, mode.name),
      ),
      _SettingsSwitchTile(
        key: const ValueKey('settings-glow-reacts-switch'),
        icon: 'gauge',
        title: 'Aurora reacciona al presupuesto',
        subtitle: 'Vira a ámbar o rojo según el gasto',
        iconColor: colors.brandAt(2),
        value: ref.watch(glowReactsToBudgetProvider).value ?? true,
        onChanged: (val) =>
            repo.set(SettingsKeys.glowReactsToBudget, val.toString()),
      ),
      _SettingsSegmentTile<WeekStart>(
        key: const ValueKey('settings-week-start'),
        icon: 'calendar-blank',
        title: 'La semana empieza',
        subtitle: 'Primer día en los calendarios',
        iconColor: colors.brandAt(2),
        selectedValue: ref.watch(weekStartProvider).value ?? WeekStart.monday,
        options: const [
          (value: WeekStart.monday, label: 'Lunes'),
          (value: WeekStart.sunday, label: 'Domingo'),
        ],
        onSelected: (val) => repo.set(SettingsKeys.calendarWeekStart, val.name),
      ),
      _SettingsSwitchTile(
        key: const ValueKey('settings-motion-reduce-switch'),
        icon: 'film-strip',
        title: 'Reducir animaciones',
        subtitle: 'Desactiva efectos de movimiento en Pockt',
        iconColor: colors.brandAt(2),
        value: ref.watch(motionReduceProvider).value ?? false,
        onChanged: (val) => repo.set(SettingsKeys.motionReduce, val.toString()),
      ),
    ];
  }

  List<Widget> _alertsItems(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(settingsRepositoryProvider);
    return [
      StreamBuilder<String?>(
        stream: repo.watch(SettingsKeys.remindersIntensity),
        builder: (context, snapshot) {
          final intensity = snapshot.data ?? 'normal';
          final subtitle = switch (intensity) {
            'off' => 'Apagado',
            'soft' => 'Suave (21:00)',
            'insistent' => 'Insistente',
            _ => 'Normal (13:00 y 21:00)',
          };
          return _SettingsTile(
            key: const ValueKey('settings-reminders-tile'),
            icon: 'bell',
            title: 'Recordatorios',
            subtitle: subtitle,
            iconColor: colors.brandAt(3),
            onTap: () {
              Haptics.tick();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RemindersScreen()),
              );
            },
          );
        },
      ),
      _SettingsSwitchTile(
        key: const ValueKey('settings-budget-alerts-switch'),
        icon: 'bell-ringing',
        title: 'Alertas de presupuesto',
        subtitle: 'Avisar al acercarse al límite mensual',
        iconColor: colors.brandAt(3),
        value: ref.watch(budgetAlertsEnabledProvider).value ?? true,
        onChanged: (val) =>
            repo.set(SettingsKeys.budgetAlertsEnabled, val.toString()),
      ),
      _SettingsSegmentTile<int>(
        key: const ValueKey('settings-alert-low'),
        icon: 'warning',
        title: 'Umbral de advertencia',
        subtitle: 'Porcentaje para el primer aviso',
        iconColor: colors.brandAt(3),
        selectedValue: ref.watch(budgetAlertLowProvider).value ?? 80,
        options: const [
          (value: 70, label: '70 %'),
          (value: 80, label: '80 %'),
          (value: 90, label: '90 %'),
        ],
        onSelected: (val) =>
            repo.set(SettingsKeys.budgetAlertLow, val.toString()),
      ),
      _SettingsSegmentTile<int>(
        key: const ValueKey('settings-alert-high'),
        icon: 'warning-octagon',
        title: 'Umbral de límite',
        subtitle: 'Porcentaje para el aviso de exceso',
        iconColor: colors.brandAt(3),
        selectedValue: ref.watch(budgetAlertHighProvider).value ?? 100,
        options: const [
          (value: 100, label: '100 %'),
          (value: 110, label: '110 %'),
        ],
        onSelected: (val) =>
            repo.set(SettingsKeys.budgetAlertHigh, val.toString()),
      ),
      _SettingsSegmentTile<ToneLevel>(
        key: const ValueKey('settings-tone-level'),
        icon: 'sparkle',
        title: 'Tono de los avisos',
        subtitle: 'Estilo de los mensajes del simulador ¿Lo compro?',
        iconColor: colors.brandAt(3),
        selectedValue: ref.watch(toneLevelProvider).value ?? ToneLevel.normal,
        options: const [
          (value: ToneLevel.soft, label: 'Suave'),
          (value: ToneLevel.normal, label: 'Normal'),
          (value: ToneLevel.spicy, label: 'Picante'),
        ],
        onSelected: (val) => repo.set(SettingsKeys.toneLevel, val.key),
      ),
    ];
  }

  List<Widget> _privacyItems(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final repo = ref.watch(settingsRepositoryProvider);
    return [
      const _LockSettingsTile(),
      _SettingsSegmentTile<int>(
        key: const ValueKey('settings-lock-after'),
        icon: 'timer',
        title: 'Tiempo hasta bloquear',
        subtitle: 'Espera en segundo plano antes de pedir huella',
        iconColor: colors.brandAt(3),
        selectedValue: ref.watch(securityLockAfterProvider).value ?? 1,
        options: const [
          (value: 0, label: 'Al instante'),
          (value: 1, label: '1 min'),
          (value: 5, label: '5 min'),
          (value: 15, label: '15 min'),
        ],
        onSelected: (val) =>
            ref.read(appLockControllerProvider).setLockAfter(val),
      ),
      _SettingsSwitchTile(
        key: const ValueKey('settings-hide-amounts-switch'),
        icon: 'eye-slash',
        title: 'Ocultar montos',
        subtitle: 'Muestra •••• hasta tocar el total',
        iconColor: colors.brandAt(3),
        value: ref.watch(privacyHideAmountsProvider).value ?? false,
        onChanged: (val) =>
            repo.set(SettingsKeys.privacyHideAmounts, val.toString()),
      ),
      StreamBuilder<BackupStatus>(
        stream: ref.watch(backupServiceProvider).watchStatus(),
        builder: (context, snapshot) {
          final status = snapshot.data;
          final isOverdue = status?.isOverdue ?? false;
          final subtitle = status?.lastSuccessAt != null
              ? 'Último: ${DateFormat('dd/MM/yyyy').format(status!.lastSuccessAt!)}'
              : 'Respaldo automático y cifrado';
          return _SettingsTile(
            key: const ValueKey('settings-backup-tile'),
            icon: 'cloud-arrow-up',
            title: 'Copia de seguridad',
            subtitle: subtitle,
            iconColor: isOverdue ? colors.warning : colors.brandAt(3),
            onTap: () {
              Haptics.tick();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const BackupScreen()));
            },
          );
        },
      ),
      _SettingsTile(
        key: const ValueKey('settings-export-csv-tile'),
        icon: 'file-csv',
        title: 'Exportar a CSV',
        subtitle: 'Movimientos en formato Excel (; y UTF-8)',
        iconColor: colors.brandAt(3),
        onTap: () async {
          Haptics.tick();
          final txRepo = ref.read(transactionsRepositoryProvider);
          final items = await txRepo.getAllActive();
          await exportAndShareCsv(items);
        },
      ),
      _SettingsTile(
        key: const ValueKey('settings-wipe-data-tile'),
        icon: 'trash',
        title: 'Borrar todos los datos',
        subtitle: 'Restablecer movimientos y ajustes a fábrica',
        iconColor: colors.danger,
        onTap: () {
          Haptics.danger();
          _showWipeDataDialog(context, ref);
        },
      ),
      _SettingsTile(
        key: const ValueKey('settings-about-tile'),
        icon: 'info',
        title: 'Acerca de Pockt',
        subtitle: 'Versión, licencias y código',
        iconColor: colors.brandAt(3),
        onTap: () {
          Haptics.tick();
          _showAboutPocktDialog(context);
        },
      ),
    ];
  }

  void _showWipeDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _WipeDataDialog(ref: ref),
    );
  }

  void _showAboutPocktDialog(BuildContext context) async {
    String version = '1.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}

    if (!context.mounted) return;
    final colors = context.pockt;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.sheetSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PocktRadii.xl),
        ),
        title: Row(
          children: [
            Icon(uiIcon('info'), color: colors.brandAt(3), size: 22),
            const SizedBox(width: 10),
            Text(
              'Acerca de Pockt',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pockt — Finanzas personales',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Versión $version',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Privado, sin servidores ni publicidad. Tus datos viven solo en tu teléfono.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              showLicensePage(
                context: context,
                applicationName: 'Pockt',
                applicationVersion: version,
              );
            },
            child: Text(
              'Licencias',
              style: TextStyle(color: colors.brandAt(3)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
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
      child: _TileShell(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        borderRadius: BorderRadius.circular(PocktRadii.xl),
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
                child: Icon(uiIcon(icon), size: 18, color: iconColor),
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
            Icon(uiIcon('caret-right'), size: 16, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Pressable(
      onTap: () {
        Haptics.tick();
        onChanged(!value);
      },
      child: _TileShell(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        borderRadius: BorderRadius.circular(PocktRadii.xl),
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
                child: Icon(uiIcon(icon), size: 18, color: iconColor),
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
            Switch(
              value: value,
              onChanged: (val) {
                Haptics.tick();
                onChanged(val);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSegmentTile<T> extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final T selectedValue;
  final List<({T value, String label})> options;
  final ValueChanged<T> onSelected;

  const _SettingsSegmentTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _TileShell(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: isDark ? 0.16 : 0.12),
                ),
                child: Center(
                  child: Icon(uiIcon(icon), size: 18, color: iconColor),
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
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: BorderRadius.circular(PocktRadii.m),
              border: Border.all(color: colors.glassBorder),
            ),
            child: Row(
              children: [
                for (final opt in options) ...[
                  Expanded(
                    child: Pressable(
                      onTap: () {
                        if (opt.value != selectedValue) {
                          Haptics.tick();
                          onSelected(opt.value);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: opt.value == selectedValue
                              ? iconColor.withValues(
                                  alpha: isDark ? 0.28 : 0.18,
                                )
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            opt.label,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: opt.value == selectedValue
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: opt.value == selectedValue
                                  ? colors.textPrimary
                                  : colors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockSettingsTile extends ConsumerStatefulWidget {
  const _LockSettingsTile();

  @override
  ConsumerState<_LockSettingsTile> createState() => _LockSettingsTileState();
}

class _LockSettingsTileState extends ConsumerState<_LockSettingsTile> {
  AppLockAvailability? _availability;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final controller = ref.read(appLockControllerProvider);
    final avail = await controller.availability();
    if (mounted) {
      setState(() {
        _availability = avail;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final controller = ref.watch(appLockControllerProvider);
    final isEnabled = controller.isLockEnabled;

    final isReady = _availability == AppLockAvailability.ready;
    final isNoDeviceLock = _availability == AppLockAvailability.noDeviceLock;
    final isUnsupported = _availability == AppLockAvailability.unsupported;

    final String subtitle;
    if (_availability == null) {
      subtitle = 'Comprobando seguridad...';
    } else if (isNoDeviceLock) {
      subtitle =
          'El dispositivo no tiene bloqueo configurado (PIN, patrón o huella)';
    } else if (isUnsupported) {
      subtitle = 'No soportado en este dispositivo';
    } else if (isEnabled) {
      subtitle = 'Activo (huella o PIN)';
    } else {
      subtitle = 'Pedir huella o PIN al abrir la app';
    }

    return _TileShell(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.brandAt(3).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(PocktRadii.m),
            ),
            child: Center(
              child: Icon(
                uiIcon('fingerprint'),
                size: 20,
                color: colors.brandAt(3),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bloqueo con huella',
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
                    color: isNoDeviceLock
                        ? colors.warning
                        : colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const ValueKey('settings-lock-switch'),
            value: isEnabled,
            onChanged: isReady
                ? (val) async {
                    Haptics.tick();
                    await controller.setLockEnabled(val);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _WipeDataDialog extends StatefulWidget {
  final WidgetRef ref;
  const _WipeDataDialog({required this.ref});

  @override
  State<_WipeDataDialog> createState() => _WipeDataDialogState();
}

class _WipeDataDialogState extends State<_WipeDataDialog> {
  final _controller = TextEditingController();
  bool _canDelete = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return AlertDialog(
      backgroundColor: colors.sheetSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PocktRadii.xl),
      ),
      title: Row(
        children: [
          Icon(uiIcon('warning'), color: colors.danger, size: 22),
          const SizedBox(width: 10),
          Text(
            'Borrar todos los datos',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Esta acción eliminará todos los movimientos, presupuestos, esquemas y ajustes, restaurando las categorías de fábrica. No se puede deshacer.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Escribí BORRAR para confirmar:',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('wipe-confirm-field'),
            controller: _controller,
            autofocus: true,
            style: TextStyle(color: colors.textPrimary, fontFamily: 'Inter'),
            decoration: InputDecoration(
              hintText: 'BORRAR',
              hintStyle: TextStyle(color: colors.textTertiary),
              filled: true,
              fillColor: colors.glassFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PocktRadii.m),
                borderSide: BorderSide(color: colors.glassBorder),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _canDelete = val.trim() == 'BORRAR';
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
        FilledButton(
          key: const ValueKey('wipe-confirm-button'),
          style: FilledButton.styleFrom(backgroundColor: colors.danger),
          onPressed: _canDelete
              ? () async {
                  Haptics.danger();
                  await wipeAllUserData(
                    db: widget.ref.read(databaseProvider),
                    notifier: widget.ref.read(notifierProvider),
                    homeWidget: widget.ref.read(homeWidgetPlatformProvider),
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Datos borrados exitosamente'),
                      ),
                    );
                  }
                }
              : null,
          child: const Text('Borrar todo'),
        ),
      ],
    );
  }
}

/// Marca que un tile está dentro de un [_SettingsGroup]: el grupo dibuja el
/// vidrio y los separadores, el tile solo su contenido.
class _InGroup extends InheritedWidget {
  const _InGroup({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InGroup>() != null;

  @override
  bool updateShouldNotify(_InGroup oldWidget) => false;
}

/// Contenedor de un tile: tarjeta propia suelta, o fila plana dentro de un grupo.
class _TileShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const _TileShell({required this.child, this.padding, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? const EdgeInsets.all(16);
    if (_InGroup.of(context)) {
      return Padding(padding: pad, child: child);
    }
    return GlassCard(
      padding: pad,
      borderRadius: borderRadius ?? BorderRadius.circular(PocktRadii.xl),
      child: child,
    );
  }
}

/// Una sola tarjeta de vidrio con filas separadas por líneas finas
/// (lista agrupada, como Ajustes de iOS).
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            color: colors.glassBorder,
          ),
        );
      }
      rows.add(children[i]);
    }
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: _InGroup(
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

typedef _SectionItemsBuilder = List<Widget> Function(
  BuildContext context,
  WidgetRef ref,
);

/// Fila de la portada de Ajustes que abre una sección.
class _SectionEntry extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final _SectionItemsBuilder builder;

  const _SectionEntry({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      iconColor: color,
      onTap: () {
        Haptics.tick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _SettingsSectionPage(
              title: title,
              color: color,
              builder: builder,
            ),
          ),
        );
      },
    );
  }
}

/// Pantalla de una sección de Ajustes: encabezado y sus opciones en un grupo.
class _SettingsSectionPage extends ConsumerWidget {
  final String title;
  final Color color;
  final _SectionItemsBuilder builder;

  const _SettingsSectionPage({
    required this.title,
    required this.color,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
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
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: PocktType.title,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [_SettingsGroup(children: builder(context, ref))],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
