import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:flutter/foundation.dart';
import 'package:pockt/features/capture/data/capture_service.dart';
import 'package:pockt/features/capture/data/email_source.dart';
import 'package:workmanager/workmanager.dart';

/// Pantalla de configuración de Captura automática de SMS de Itaú (spec §4.6).
class CaptureSettingsScreen extends ConsumerWidget {
  const CaptureSettingsScreen({super.key});

  Future<void> _toggleEnabled(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    Haptics.tick();
    final repo = ref.read(settingsRepositoryProvider);
    if (!enable) {
      await repo.set(SettingsKeys.captureSmsEnabled, 'false');
      return;
    }

    final smsSource = ref.read(smsSourceProvider);
    final granted = await smsSource.requestPermissions();
    if (!granted) {
      await repo.set(SettingsKeys.captureSmsEnabled, 'false');
      return;
    }

    await repo.set(SettingsKeys.captureSmsEnabled, 'true');
    unawaited(ref.read(captureServiceProvider).syncInbox());
  }

  Future<void> _pickSinceDate(
    BuildContext context,
    WidgetRef ref,
    DateTime current,
  ) async {
    Haptics.tick();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );
    if (picked == null) return;
    final formatted = DateFormat('yyyy-MM-dd').format(picked);
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsKeys.captureSince, formatted);
  }

  Future<void> _removeAutoConfirm(WidgetRef ref, String merchantKey) async {
    Haptics.tick();
    final db = ref.read(databaseProvider);
    await (db.update(db.merchantMemory)
          ..where((m) => m.merchantKey.equals(merchantKey)))
        .write(const MerchantMemoryCompanion(autoConfirm: Value(false)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = ref.watch(captureSmsEnabledProvider).value ?? false;
    final sinceDate =
        ref.watch(captureSinceProvider).value ?? DateTime(2026, 10, 15);
    final lastSmsAt = ref.watch(captureLastSmsAtProvider).value;
    final capturedMonth = ref.watch(capturedThisMonthCountProvider).value ?? 0;
    final unrecognized = ref.watch(captureUnrecognizedCountProvider).value ?? 0;
    final autoMerchants =
        ref.watch(autoConfirmMerchantsProvider).value ?? const [];

    final sinceFormatted = DateFormat('dd/MM/yyyy').format(sinceDate);
    final lastSmsFormatted = lastSmsAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(toLocal(lastSmsAt))
        : 'Ninguno todavía';

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
                          'Captura automática',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: PocktType.title,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Avisos por SMS de Itaú (4828)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: PocktType.caption,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors
                                    .brandAt(0)
                                    .withValues(alpha: 0.14),
                              ),
                              child: Center(
                                child: Icon(
                                  uiIcon('chat-text'),
                                  size: 18,
                                  color: colors.brandAt(0),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Leer SMS de Itaú',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: PocktType.body,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            Switch(
                              key: const ValueKey('capture-sms-switch'),
                              value: enabled,
                              activeThumbColor: Colors.white,
                              activeTrackColor: colors.brandStart,
                              onChanged: (val) =>
                                  _toggleEnabled(context, ref, val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Lee en tu teléfono los avisos del remitente 4828 y los suma a la bandeja Por confirmar, sin compartir claves ni usar internet. Solo pide permiso de lectura de SMS al activarlo.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: PocktType.caption,
                            color: colors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'ESTADO',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _StatusRow(
                          label: 'Último SMS leído',
                          value: lastSmsFormatted,
                        ),
                        Container(height: 1, color: colors.glassBorder),
                        _StatusRow(
                          label: 'Capturados este mes',
                          value: '$capturedMonth',
                        ),
                        Container(height: 1, color: colors.glassBorder),
                        _StatusRow(
                          label: 'No reconocidos',
                          value: '$unrecognized',
                        ),
                        Container(height: 1, color: colors.glassBorder),
                        Pressable(
                          key: const ValueKey('capture-since-tile'),
                          semanticLabel: 'Leer desde $sinceFormatted',
                          onTap: () => _pickSinceDate(context, ref, sinceDate),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Leer desde',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: PocktType.body,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  sinceFormatted,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: PocktType.body,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  uiIcon('caret-right'),
                                  size: 16,
                                  color: colors.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'COMERCIOS CON CONFIRMACIÓN AUTOMÁTICA',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                  GlassCard(
                    padding: autoMerchants.isEmpty
                        ? const EdgeInsets.all(16)
                        : EdgeInsets.zero,
                    child: autoMerchants.isEmpty
                        ? Text(
                            'Ningún comercio configurado. Podés activarlo desde la bandeja Por confirmar.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: PocktType.caption,
                              color: colors.textSecondary,
                            ),
                          )
                        : Column(
                            children: [
                              for (
                                var i = 0;
                                i < autoMerchants.length;
                                i++
                              ) ...[
                                if (i > 0)
                                  Container(
                                    height: 1,
                                    color: colors.glassBorder,
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(
                                            isDark
                                                ? autoMerchants[i]
                                                      .category
                                                      .colorDark
                                                : autoMerchants[i]
                                                      .category
                                                      .colorLight,
                                          ).withValues(alpha: 0.16),
                                        ),
                                        child: Center(
                                          child: categoryIcon(
                                            autoMerchants[i].category.icon,
                                            size: 16,
                                            color: Color(
                                              isDark
                                                  ? autoMerchants[i]
                                                        .category
                                                        .colorDark
                                                  : autoMerchants[i]
                                                        .category
                                                        .colorLight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              autoMerchants[i].merchantKey,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: PocktType.body,
                                                fontWeight: FontWeight.w500,
                                                color: colors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              autoMerchants[i].category.name,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: PocktType.caption,
                                                color: colors.textTertiary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Pressable(
                                        key: ValueKey(
                                          'remove-autoconfirm-${autoMerchants[i].merchantKey}',
                                        ),
                                        semanticLabel:
                                            'Quitar ${autoMerchants[i].merchantKey}',
                                        onTap: () => _removeAutoConfirm(
                                          ref,
                                          autoMerchants[i].merchantKey,
                                        ),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: colors.glassFill,
                                            border: Border.all(
                                              color: colors.glassBorder,
                                            ),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              uiIcon('trash'),
                                              size: 16,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'DEBUG',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Pressable(
                        key: const ValueKey('gmail-probe-tile'),
                        semanticLabel: 'Gmail: probar',
                        onTap: () async {
                          final scaffold = ScaffoldMessenger.of(context);
                          final source = const AndroidEmailSource();
                          try {
                            final connected = await source.authorize();
                            if (!connected) {
                              scaffold.showSnackBar(
                                const SnackBar(
                                  content: Text('Gmail: cancelado'),
                                ),
                              );
                              return;
                            }
                            final now = DateTime.now();
                            final emails = await source.fetchSince(
                              now.subtract(const Duration(days: 7)),
                            );
                            scaffold.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Gmail probe: ${emails.length} correos',
                                ),
                              ),
                            );
                            await Workmanager().registerOneOffTask(
                              'pockt-email-probe',
                              'pockt-email-probe',
                              initialDelay: const Duration(minutes: 1),
                            );
                          } on GmailReconnectRequired {
                            scaffold.showSnackBar(
                              const SnackBar(
                                content: Text('Gmail: necesita reconectar'),
                              ),
                            );
                          } catch (e) {
                            scaffold.showSnackBar(
                              SnackBar(content: Text('Gmail probe error: $e')),
                            );
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Gmail: probar',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: PocktType.body,
                color: colors.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: PocktType.body,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
