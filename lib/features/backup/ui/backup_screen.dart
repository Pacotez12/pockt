import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';
import 'package:pockt/features/backup/ui/restore_flow.dart';

/// Pantalla de configuración y gestión de copias de seguridad (Ajustes -> Backup).
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isBackingUp = false;
  bool _isExporting = false;

  Future<void> _handleBackupNow() async {
    if (_isBackingUp) return;

    setState(() {
      _isBackingUp = true;
    });
    Haptics.tick();

    try {
      final service = ref.read(backupServiceProvider);
      final result = await service.backupNow();

      if (!mounted) return;

      switch (result) {
        case BackupResult.success:
          Haptics.save();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copia de seguridad realizada correctamente'),
            ),
          );
        case BackupResult.noPassword:
          Haptics.warning();
          _showSetPasswordDialog(isInitial: true);
        case BackupResult.storage:
          Haptics.warning();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo guardar la copia en Documentos/Pockt'),
            ),
          );
        case BackupResult.unknown:
          Haptics.warning();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ocurrió un error inesperado al realizar la copia'),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  void _showSetPasswordDialog({bool isInitial = false}) {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final colors = dialogCtx.pockt;

          return AlertDialog(
            backgroundColor: colors.sheetSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PocktRadii.xl),
            ),
            title: Text(
              isInitial
                  ? 'Configurar contraseña de la copia'
                  : 'Cambiar contraseña de la copia',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Esta contraseña cifra tus copias con AES-256-GCM. '
                    'Pockt nunca guarda tu contraseña: sin ella no podrás restaurar tus copias.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (!isInitial) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(PocktRadii.m),
                      ),
                      child: Text(
                        'Advertencia: Las copias creadas anteriormente requerirán la contraseña que tenían al momento de su creación.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.warning,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Contraseña de la copia',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PocktRadii.m),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      errorText: errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PocktRadii.m),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              FilledButton(
                onPressed: () async {
                  if (passwordCtrl.text.isEmpty) {
                    setDialogState(() {
                      errorText = 'Ingresá una contraseña';
                    });
                    return;
                  }
                  if (passwordCtrl.text != confirmCtrl.text) {
                    setDialogState(() {
                      errorText = 'Las contraseñas no coinciden';
                    });
                    return;
                  }

                  Navigator.of(dialogCtx).pop();
                  final service = ref.read(backupServiceProvider);
                  await service.setPassword(passwordCtrl.text);
                  Haptics.save();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Contraseña de la copia guardada'),
                      ),
                    );
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final service = ref.watch(backupServiceProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _buildTopBar(context),
            ),
            Expanded(
              child: StreamBuilder<BackupStatus>(
                stream: service.watchStatus(),
                builder: (context, snapshot) {
                  final status =
                      snapshot.data ?? const BackupStatus(isOverdue: false);

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildStatusCard(context, status),
                      const SizedBox(height: 14),
                      _buildActionButtons(context, status),
                      const SizedBox(height: 14),
                      _buildFolderCard(context),
                      const SizedBox(height: 14),
                      _buildSecurityCard(context),
                      const SizedBox(height: 14),
                      _buildRestoreCard(context),
                      const SizedBox(height: 40),
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

  Widget _buildTopBar(BuildContext context) {
    final colors = context.pockt;

    return Row(
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
                'Copia de seguridad',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                'Copia automática y cifrada',
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
    );
  }

  Widget _buildStatusCard(BuildContext context, BackupStatus status) {
    final colors = context.pockt;
    final lastSuccess = status.lastSuccessAt;

    String formattedDate;
    if (lastSuccess == null) {
      formattedDate = 'Sin copias aún';
    } else {
      final now = DateTime.now();
      final isToday =
          lastSuccess.year == now.year &&
          lastSuccess.month == now.month &&
          lastSuccess.day == now.day;
      final timeStr = DateFormat('HH:mm').format(lastSuccess);
      if (isToday) {
        formattedDate = 'hoy $timeStr';
      } else {
        final dateStr = DateFormat('dd/MM/yyyy').format(lastSuccess);
        formattedDate = '$dateStr $timeStr';
      }
    }

    final hasError = status.lastError != null;
    final isOverdue = status.isOverdue;

    Color stateColor = colors.positive;
    if (hasError) {
      stateColor = colors.danger;
    } else if (isOverdue) {
      stateColor = colors.warning;
    } else if (lastSuccess == null) {
      stateColor = colors.textTertiary;
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: stateColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: stateColor.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Última copia: $formattedDate',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          if (isOverdue) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(PocktRadii.m),
                border: Border.all(
                  color: colors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(uiIcon('warning'), size: 16, color: colors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Copia vencida: pasaron más de 5 días sin una copia exitosa.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasError) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(PocktRadii.m),
                border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(uiIcon('x'), size: 16, color: colors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage(status.lastError!),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.danger,
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
  }

  Widget _buildActionButtons(BuildContext context, BackupStatus status) {
    final colors = context.pockt;

    return Pressable(
      onTap: _isBackingUp ? null : _handleBackupNow,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.brandStart, colors.brandEnd],
          ),
          borderRadius: BorderRadius.circular(PocktRadii.l),
          boxShadow: [
            BoxShadow(
              color: colors.brandStart.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isBackingUp
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      uiIcon('cloud-arrow-up'),
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Hacer copia ahora',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFolderCard(BuildContext context) {
    final colors = context.pockt;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dónde se guarda',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                uiIcon('device-mobile'),
                size: 18,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Documentos/Pockt',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Automático cada 2 días al abrir la app · se conservan las últimas 7',
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
          const SizedBox(height: 12),
          Text(
            'Para no perderla si perdés el teléfono, exportá una copia a Drive, '
            'WhatsApp o tu correo de vez en cuando.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          Pressable(
            key: const ValueKey('backup-export-button'),
            onTap: _isExporting ? null : _handleExport,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colors.glassFill,
                borderRadius: BorderRadius.circular(PocktRadii.m),
                border: Border.all(color: colors.glassBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(uiIcon('share'), size: 18, color: colors.brandStart),
                  const SizedBox(width: 8),
                  Text(
                    _isExporting ? 'Preparando…' : 'Exportar copia',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      final export = await ref.read(backupServiceProvider).buildExport();
      if (!mounted) return;
      if (export == null) {
        _showSetPasswordDialog(isInitial: true);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${export.name}');
      await file.writeAsBytes(export.bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Copia cifrada de Pockt'),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo exportar la copia')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _buildSecurityCard(BuildContext context) {
    final colors = context.pockt;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seguridad y cifrado',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tus copias de seguridad están cifradas de extremo a extremo con AES-256-GCM y clave derivada con Argon2id.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: colors.textTertiary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Pressable(
            onTap: () => _showSetPasswordDialog(isInitial: false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.glassFill,
                borderRadius: BorderRadius.circular(PocktRadii.m),
                border: Border.all(color: colors.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(uiIcon('key'), size: 16, color: colors.textPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'Cambiar contraseña de la copia',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreCard(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      onTap: () {
        Haptics.tick();
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const RestoreFlowScreen()));
      },
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(PocktRadii.xl),
        child: Row(
          children: [
            Icon(
              uiIcon('clock-counter-clockwise'),
              size: 20,
              color: colors.textPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restaurar copia',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Desde Documentos/Pockt o desde un archivo',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(uiIcon('caret-right'), size: 18, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }

  String _errorMessage(BackupResult error) {
    switch (error) {
      case BackupResult.noPassword:
        return 'No se configuró una contraseña para la copia.';
      case BackupResult.storage:
        return 'No se pudo guardar la copia en Documentos/Pockt.';
      case BackupResult.unknown:
        return 'Ocurrió un error inesperado al realizar la copia.';
      case BackupResult.success:
        return '';
    }
  }
}
