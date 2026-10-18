import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/capture/data/counterparty_rules_repository.dart';
import 'package:pockt/features/capture/data/email_capture_service.dart';

class EmailCaptureSection extends ConsumerWidget {
  const EmailCaptureSection({super.key});

  Future<void> _toggleEmail(
    BuildContext context,
    WidgetRef ref,
    bool enable,
    DateTime sinceDate,
  ) async {
    Haptics.tick();
    if (!enable) {
      await ref.read(emailCaptureServiceProvider).disconnect();
      return;
    }

    await showEmailConnectSheet(context, ref, initialDate: sinceDate);
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
        .set(SettingsKeys.captureEmailSince, formatted);
  }

  String _formatAction(CounterpartyAction action) {
    switch (action) {
      case CounterpartyAction.income:
        return 'Ingreso';
      case CounterpartyAction.expense:
        return 'Gasto';
      case CounterpartyAction.loanRepayment:
        return 'Me pagaron un préstamo';
      case CounterpartyAction.loanLent:
        return 'Le presté a alguien';
      case CounterpartyAction.loanPayment:
        return 'Pagué una deuda';
      case CounterpartyAction.ignore:
        return 'No contar';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final enabled = ref.watch(captureEmailEnabledProvider).value ?? false;
    final sinceDate =
        ref.watch(captureEmailSinceProvider).value ?? DateTime(2026, 10, 15);
    final lastEmailAt = ref.watch(captureEmailLastAtProvider).value;
    final unrecognized =
        ref.watch(captureEmailUnrecognizedCountProvider).value ?? 0;
    final needsReconnect =
        ref.watch(captureEmailNeedsReconnectProvider).value ?? false;

    final rulesStream =
        ref.watch(counterpartyRulesRepositoryProvider).watchAll();

    final sinceFormatted = DateFormat('dd/MM/yyyy').format(sinceDate);
    final lastEmailFormatted = lastEmailAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(toLocal(lastEmailAt))
        : 'Ninguno todavía';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      color: colors.brandAt(1).withValues(alpha: 0.14),
                    ),
                    child: Center(
                      child: Icon(
                        uiIcon('envelope-simple'),
                        size: 18,
                        color: colors.brandAt(1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Leer correos de Itaú (Gmail)',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: PocktType.body,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    key: const ValueKey('capture-email-switch'),
                    value: enabled,
                    activeThumbColor: Colors.white,
                    activeTrackColor: colors.brandStart,
                    onChanged: (val) =>
                        _toggleEmail(context, ref, val, sinceDate),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Lee en tu teléfono los avisos de transferencias y pagos enviados por info@itau.com.py.',
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
        if (needsReconnect) ...[
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('email-reconnect-banner'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(PocktRadii.l),
              border: Border.all(
                color: colors.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      uiIcon('warning-circle'),
                      color: colors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Google requiere que vuelvas a conectar tu cuenta para seguir leyendo correos.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: PocktType.caption,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  key: const ValueKey('email-reconnect-button'),
                  onPressed: () async {
                    Haptics.tick();
                    await ref
                        .read(emailCaptureServiceProvider)
                        .connect(since: sinceDate);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.warning,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PocktRadii.m),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Volver a conectar',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (enabled) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'ESTADO CORREO',
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
                _EmailStatusRow(
                  label: 'Último correo leído',
                  value: lastEmailFormatted,
                ),
                Container(height: 1, color: colors.glassBorder),
                _EmailStatusRow(
                  label: 'No reconocidos',
                  value: '$unrecognized',
                ),
                Container(height: 1, color: colors.glassBorder),
                Pressable(
                  key: const ValueKey('capture-email-since-tile'),
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
        ],
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'PERSONAS RECORDADAS',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: colors.textTertiary,
            ),
          ),
        ),
        StreamBuilder<List<CounterpartyRule>>(
          stream: rulesStream,
          builder: (context, snapshot) {
            final rules = snapshot.data ?? const [];
            return GlassCard(
              padding: rules.isEmpty ? const EdgeInsets.all(16) : EdgeInsets.zero,
              child: rules.isEmpty
                  ? Text(
                      'Ninguna persona recordada. Al confirmar transferencias en la bandeja podés recordar cómo registrarlas.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: PocktType.caption,
                        color: colors.textSecondary,
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < rules.length; i++) ...[
                          if (i > 0)
                            Container(height: 1, color: colors.glassBorder),
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
                                    color: colors.brandStart
                                        .withValues(alpha: isDark ? 0.22 : 0.14),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      uiIcon('envelope-simple'),
                                      size: 16,
                                      color: colors.brandStart,
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
                                        rules[i].nameKey,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: PocktType.body,
                                          fontWeight: FontWeight.w500,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        _formatAction(rules[i].action),
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
                                  key: ValueKey('remove-rule-${rules[i].id}'),
                                  semanticLabel: 'Quitar ${rules[i].nameKey}',
                                  onTap: () async {
                                    Haptics.tick();
                                    await ref
                                        .read(counterpartyRulesRepositoryProvider)
                                        .delete(rules[i].id);
                                  },
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
            );
          },
        ),
        if (enabled) ...[
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              key: const ValueKey('disconnect-gmail-button'),
              onPressed: () async {
                Haptics.tick();
                await ref.read(emailCaptureServiceProvider).disconnect();
              },
              icon: Icon(uiIcon('trash'), color: colors.danger, size: 16),
              label: Text(
                'Desconectar Gmail',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.danger,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> showEmailConnectSheet(
  BuildContext context,
  WidgetRef ref, {
  required DateTime initialDate,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _EmailConnectSheet(initialDate: initialDate),
  );
}

class _EmailConnectSheet extends ConsumerStatefulWidget {
  final DateTime initialDate;

  const _EmailConnectSheet({required this.initialDate});

  @override
  ConsumerState<_EmailConnectSheet> createState() => _EmailConnectSheetState();
}

class _EmailConnectSheetState extends ConsumerState<_EmailConnectSheet> {
  late DateTime _selectedDate;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  Future<void> _pickDate() async {
    Haptics.tick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    final service = ref.read(emailCaptureServiceProvider);
    final ok = await service.connect(since: _selectedDate);
    if (ok) {
      unawaited(service.sync().catchError((_) => 0));
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat('dd/MM/yyyy').format(_selectedDate);

    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(colors.glassFill, colors.background),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(PocktRadii.xl),
        ),
        border: Border.all(color: colors.glassBorder),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.brandStart
                        .withValues(alpha: isDark ? 0.22 : 0.14),
                  ),
                  child: Center(
                    child: Icon(
                      uiIcon('envelope-simple'),
                      color: colors.brandStart,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Conectar Gmail',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Solo se leen los correos de info@itau.com.py, en modo lectura. Todo queda en tu teléfono.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Pressable(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colors.glassFill,
                  borderRadius: BorderRadius.circular(PocktRadii.m),
                  border: Border.all(color: colors.glassBorder),
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
                      formattedDate,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: PocktType.body,
                        fontWeight: FontWeight.w600,
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
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _connecting ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _connecting ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brandStart,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PocktRadii.l),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _connecting ? 'Conectando...' : 'Conectar',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
  }
}

class _EmailStatusRow extends StatelessWidget {
  const _EmailStatusRow({required this.label, required this.value});

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
