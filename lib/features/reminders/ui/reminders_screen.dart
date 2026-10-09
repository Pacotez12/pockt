import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/reminders/data/reminder_scheduler.dart';
import 'package:pockt/features/reminders/domain/reminder_plan.dart';

/// Id de la notificación de prueba (fuera del rango de los recordatorios diarios).
const kTestReminderId = 99;

/// Pantalla de configuración de Recordatorios (spec §5.8 y §5.10):
/// Intensidad · Horas de silencio · Permisos de notificación.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await ref.read(notifierProvider).ensurePermission();
    if (mounted) {
      setState(() {
        _hasPermission = granted;
      });
    }
  }

  Future<void> _requestPermission() async {
    Haptics.tick();
    final granted = await ref.read(notifierProvider).ensurePermission();
    if (mounted) {
      setState(() {
        _hasPermission = granted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final repo = ref.watch(settingsRepositoryProvider);
    final intensityStream = repo.watch(SettingsKeys.remindersIntensity);
    final quietStartStream = repo.watch(SettingsKeys.remindersQuietStart);
    final quietEndStream = repo.watch(SettingsKeys.remindersQuietEnd);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context, colors),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (!_hasPermission) ...[
                    _buildPermissionAlert(colors),
                    const SizedBox(height: 16),
                  ],
                  _buildSectionTitle('Intensidad', colors),
                  const SizedBox(height: 8),
                  StreamBuilder<String?>(
                    stream: intensityStream,
                    builder: (context, snapshot) {
                      final current = snapshot.data ?? 'normal';
                      return GlassCard(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        child: Column(
                          children: [
                            _IntensityTile(
                              title: 'Apagado',
                              subtitle: 'Sin recordatorios',
                              sample: 'Ninguno',
                              isSelected: current == 'off',
                              onTap: () => _updateIntensity('off'),
                            ),
                            Divider(color: colors.glassBorder, height: 1),
                            _IntensityTile(
                              title: 'Suave',
                              subtitle: '21:00',
                              sample:
                                  '¿Gastaste algo hoy? Anotalo en 10 segundos.',
                              isSelected: current == 'soft',
                              onTap: () => _updateIntensity('soft'),
                            ),
                            Divider(color: colors.glassBorder, height: 1),
                            _IntensityTile(
                              title: 'Normal',
                              subtitle: '13:00 y 21:00',
                              sample: '¿Cómo va el día? Anotá lo que llevás gastado.',
                              isSelected: current == 'normal',
                              onTap: () => _updateIntensity('normal'),
                            ),
                            Divider(color: colors.glassBorder, height: 1),
                            _IntensityTile(
                              title: 'Insistente',
                              subtitle: 'Cada 3 h desde las 12:00 (máx 4)',
                              sample: 'ANOTÁ TUS GASTOS DE HOY.',
                              isSelected: current == 'insistent',
                              onTap: () => _updateIntensity('insistent'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Horas de silencio', colors),
                  const SizedBox(height: 4),
                  Text(
                    'No se enviarán recordatorios durante este período.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<String?>(
                    stream: quietStartStream,
                    builder: (context, startSnap) {
                      final startVal = startSnap.data ?? '23:00';
                      return StreamBuilder<String?>(
                        stream: quietEndStream,
                        builder: (context, endSnap) {
                          final endVal = endSnap.data ?? '09:00';

                          return GlassCard(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 16,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            child: Column(
                              children: [
                                _TimePickerRow(
                                  label: 'Desde',
                                  value: startVal,
                                  onTap: () => _pickTime(
                                    context,
                                    SettingsKeys.remindersQuietStart,
                                    startVal,
                                  ),
                                ),
                                Divider(color: colors.glassBorder, height: 1),
                                _TimePickerRow(
                                  label: 'Hasta',
                                  value: endVal,
                                  onTap: () => _pickTime(
                                    context,
                                    SettingsKeys.remindersQuietEnd,
                                    endVal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Los recordatorios solo se envían si en el día no registraste ningún gasto y no marcaste "Hoy no gasté nada".',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colors.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Pressable(
                    onTap: _sendTestReminder,
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      child: Row(
                        children: [
                          Icon(
                            uiIcon('bell'),
                            size: 20,
                            color: colors.textPrimary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Probar recordatorio',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            'llega en 5 s',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, PocktColors colors) {
    return Padding(
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
                  'Recordatorios',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  'Alertas diarias de registro',
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
    );
  }

  Widget _buildSectionTitle(String title, PocktColors colors) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
    );
  }

  Widget _buildPermissionAlert(PocktColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(uiIcon('bell'), size: 18, color: colors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Las notificaciones están desactivadas',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Para que Pockt pueda avisarte en los horarios configurados, necesitás otorgar el permiso de notificaciones.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Pressable(
            onTap: _requestPermission,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.warning,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Activar notificaciones',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Programa un recordatorio real dentro de 5 segundos, con el texto de la
  /// intensidad elegida y sus botones, para ver cómo queda la notificación.
  Future<void> _sendTestReminder() async {
    Haptics.tick();
    final notifier = ref.read(notifierProvider);
    if (!await notifier.ensurePermission()) return;
    final intensity = await ref
        .read(settingsRepositoryProvider)
        .get(SettingsKeys.remindersIntensity);
    final body = intensity == 'insistent'
        ? 'ANOTÁ TUS GASTOS DE HOY.'
        : '¿Gastaste algo hoy? Anotalo en 10 segundos.';
    await notifier.schedule(
      PlannedReminder(
        atLocal: DateTime.now().add(const Duration(seconds: 5)),
        notificationId: kTestReminderId,
        title: 'Pockt',
        body: body,
      ),
    );
  }

  Future<void> _updateIntensity(String value) async {
    Haptics.tick();
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsKeys.remindersIntensity, value);
    await ref
        .read(reminderSchedulerProvider)
        .reschedule(nowLocal: DateTime.now());
  }

  Future<void> _pickTime(
    BuildContext context,
    String key,
    String currentVal,
  ) async {
    Haptics.tick();
    final parts = currentVal.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );

    final picked = await showTimePicker(context: context, initialTime: initial);

    if (picked != null) {
      final timeStr =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await ref.read(settingsRepositoryProvider).set(key, timeStr);
      await ref
          .read(reminderSchedulerProvider)
          .reschedule(nowLocal: DateTime.now());
    }
  }
}

class _IntensityTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String sample;
  final bool isSelected;
  final VoidCallback onTap;

  const _IntensityTile({
    required this.title,
    required this.subtitle,
    required this.sample,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                      const SizedBox(width: 8),
                      Text(
                        '· $subtitle',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sample,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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

class _TimePickerRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimePickerRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.brandStart,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  uiIcon('caret-right'),
                  size: 14,
                  color: colors.textTertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
