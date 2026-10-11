import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/backup/data/backup_store.dart';
import 'package:pockt/features/backup/domain/backup_format.dart';
import 'package:pockt/features/backup/domain/restore_service.dart';

const _kMonths = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

String _formatBackupDate(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} de ${_kMonths[dt.month - 1]}, $hh:$mm';
}

String _formatPreviewDate(DateTime dt) {
  return '${dt.day} de ${_kMonths[dt.month - 1]} de ${dt.year}';
}

/// Pantalla y flujo guiado de restauración de copias de seguridad (Plan 4, Task 5).
class RestoreFlowScreen extends ConsumerStatefulWidget {
  const RestoreFlowScreen({super.key});

  @override
  ConsumerState<RestoreFlowScreen> createState() => _RestoreFlowScreenState();
}

class _RestoreFlowScreenState extends ConsumerState<RestoreFlowScreen> {
  late Future<List<RemoteBackup>> _backupsFuture;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  void _loadBackups() {
    _backupsFuture = ref.read(backupStoreProvider).list();
  }

  Future<void> _onSelectBackup(RemoteBackup backup) async {
    Haptics.tick();
    await _showPasswordModal(backup);
  }

  Future<void> _showPasswordModal(RemoteBackup backup) async {
    final passwordCtrl = TextEditingController();
    bool isObscured = true;
    bool isVerifying = false;
    String? errorMessage;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final colors = context.pockt;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: colors.sheetSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 18),
                Text(
                  'Contraseña de la copia',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ingresá la contraseña que definiste al respaldar.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: passwordCtrl,
                  obscureText: isObscured,
                  autofocus: true,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    errorText: errorMessage,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: colors.textSecondary,
                      ),
                      onPressed: () {
                        setSheetState(() {
                          isObscured = !isObscured;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Pressable(
                  onTap: isVerifying
                      ? null
                      : () async {
                          final password = passwordCtrl.text;
                          if (password.isEmpty) {
                            setSheetState(() {
                              errorMessage = 'Ingresá la contraseña';
                            });
                            return;
                          }

                          setSheetState(() {
                            isVerifying = true;
                            errorMessage = null;
                          });

                          try {
                            final restoreService = ref.read(restoreServiceProvider);
                            final preview = await restoreService.preview(backup.id, password);

                            if (!context.mounted) return;
                            Navigator.of(sheetContext).pop();
                            await _showPreviewModal(backup, password, preview);
                          } catch (e) {
                            Haptics.danger();
                            setSheetState(() {
                              isVerifying = false;
                              if (e is WrongPasswordException) {
                                errorMessage = 'Contraseña incorrecta o copia alterada';
                              } else if (e is BadBackupFormatException) {
                                errorMessage = 'Formato de archivo inválido';
                              } else {
                                errorMessage = 'Error al verificar la copia: $e';
                              }
                            });
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.brandStart, colors.brandEnd],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: isVerifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Continuar',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showPreviewModal(
    RemoteBackup backup,
    String password,
    RestorePreview preview,
  ) async {
    bool isRestoring = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetInnerContext, setSheetState) {
          final colors = sheetInnerContext.pockt;
          final dateStr = _formatPreviewDate(preview.createdAt);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: colors.sheetSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 18),
                Text(
                  'Vista previa de la copia',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history, color: colors.brandStart, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Fecha: $dateStr',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.receipt_long_outlined, color: colors.positive, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            '${formatGs(preview.transactionCount, symbol: false)} movimientos',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.layers_outlined, color: colors.textSecondary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Esquema: v${preview.schemaVersion}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 20, color: colors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Al confirmar, los datos actuales de la app se reemplazarán por los de esta copia. '
                          'Se conservará un respaldo previo de seguridad por si algo falla.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: colors.warning,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Pressable(
                  onTap: isRestoring
                      ? null
                      : () async {
                          setSheetState(() {
                            isRestoring = true;
                          });
                          try {
                            final service = ref.read(restoreServiceProvider);
                            await service.restore(backup.id, password);
                            Haptics.save();
                            if (!mounted || !sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copia de seguridad restaurada con éxito'),
                              ),
                            );
                          } catch (e) {
                            Haptics.danger();
                            setSheetState(() {
                              isRestoring = false;
                            });
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('No se pudo restaurar la copia: $e'),
                              ),
                            );
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.brandStart, colors.brandEnd],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: isRestoring
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Confirmar y restaurar',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.glassFill,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: Center(
                        child: Icon(
                          uiIcon('arrow-left'),
                          size: 20,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Restaurar copia',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<RemoteBackup>>(
                future: _backupsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: colors.danger),
                            const SizedBox(height: 12),
                            Text(
                              'No se pudieron cargar las copias',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () {
                                setState(() {
                                  _loadBackups();
                                });
                              },
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final backups = snapshot.data ?? [];
                  if (backups.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_outlined, size: 56, color: colors.textTertiary),
                            const SizedBox(height: 16),
                            Text(
                              'No encontramos copias en tu Google Drive.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Asegurate de haber configurado los respaldos en Ajustes y de tener conexión a Internet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: colors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: backups.length,
                    itemBuilder: (context, index) {
                      final backup = backups[index];
                      final dateStr = _formatBackupDate(backup.createdAt);
                      final sizeKb = (backup.sizeBytes / 1024).toStringAsFixed(1);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Pressable(
                          onTap: () => _onSelectBackup(backup),
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            borderRadius: BorderRadius.circular(18),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: colors.brandStart.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(Icons.history, color: colors.brandStart, size: 22),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        backup.name,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$dateStr · $sizeKb KB',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  uiIcon('caret-right'),
                                  size: 18,
                                  color: colors.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
