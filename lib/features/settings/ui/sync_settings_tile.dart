import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/sync/auth_service.dart';
import 'package:pockt/core/sync/sync_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Formatea el tiempo relativo para el estado de sincronización.
/// Ejemplo: "hace 1 s", "hace 5 min", "hace 2 h".
String formatRelativeSyncTime(DateTime lastSyncedAt) {
  final diff = DateTime.now().toUtc().difference(lastSyncedAt.toUtc());
  final seconds = diff.inSeconds;
  if (seconds < 60) {
    return '${seconds <= 1 ? 1 : seconds} s';
  }
  final minutes = diff.inMinutes;
  if (minutes < 60) {
    return '$minutes min';
  }
  final hours = diff.inHours;
  if (hours < 24) {
    return '$hours h';
  }
  final days = diff.inDays;
  return '$days d';
}

/// Dibuja el logo 'G' de Google de 4 colores sin librerías externas.
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Blue (#4285F4)
    final bluePaint = Paint()
      ..color = PocktBrandLogos.googleBlue
      ..style = PaintingStyle.fill;
    final bluePath = Path()
      ..moveTo(22.0, 12.2)
      ..cubicTo(22.0, 11.5, 21.9, 10.8, 21.8, 10.2)
      ..lineTo(12.0, 10.2)
      ..lineTo(12.0, 14.0)
      ..lineTo(17.6, 14.0)
      ..arcToPoint(
        const Offset(15.5, 17.1),
        radius: const Radius.circular(4.8),
        clockwise: false,
      )
      ..lineTo(15.5, 19.7)
      ..lineTo(18.9, 19.7)
      ..cubicTo(20.9, 17.9, 22.0, 15.2, 22.0, 12.2)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green (#34A853)
    final greenPaint = Paint()
      ..color = PocktBrandLogos.googleGreen
      ..style = PaintingStyle.fill;
    final greenPath = Path()
      ..moveTo(12.0, 22.0)
      ..cubicTo(14.8, 22.0, 17.2, 21.1, 18.9, 19.5)
      ..lineTo(15.5, 16.9)
      ..cubicTo(14.6, 17.5, 13.4, 17.9, 12.0, 17.9)
      ..cubicTo(9.3, 17.9, 7.0, 16.1, 6.2, 13.6)
      ..lineTo(2.7, 13.6)
      ..lineTo(2.7, 16.3)
      ..arcToPoint(
        const Offset(12.0, 22.0),
        radius: const Radius.circular(10.0),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow (#FBBC05)
    final yellowPaint = Paint()
      ..color = PocktBrandLogos.googleYellow
      ..style = PaintingStyle.fill;
    final yellowPath = Path()
      ..moveTo(6.2, 13.6)
      ..arcToPoint(
        const Offset(6.2, 9.8),
        radius: const Radius.circular(6.0),
        clockwise: false,
      )
      ..lineTo(6.2, 7.1)
      ..lineTo(2.7, 7.1)
      ..arcToPoint(
        const Offset(2.7, 16.3),
        radius: const Radius.circular(10.0),
        clockwise: false,
      )
      ..lineTo(6.2, 13.6)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red (#EA4335)
    final redPaint = Paint()
      ..color = PocktBrandLogos.googleRed
      ..style = PaintingStyle.fill;
    final redPath = Path()
      ..moveTo(12.0, 5.9)
      ..cubicTo(13.5, 5.9, 14.9, 6.4, 16.0, 7.4)
      ..lineTo(19.0, 4.4)
      ..arcToPoint(
        const Offset(2.7, 7.1),
        radius: const Radius.circular(10.0),
        clockwise: false,
      )
      ..lineTo(6.2, 9.8)
      ..cubicTo(7.0, 7.7, 9.3, 5.9, 12.0, 5.9)
      ..close();
    canvas.drawPath(redPath, redPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Fila y tarjeta de configuración de "Sincronizar con la web".
class SyncSettingsTile extends ConsumerStatefulWidget {
  const SyncSettingsTile({super.key});

  @override
  ConsumerState<SyncSettingsTile> createState() => _SyncSettingsTileState();
}

class _SyncSettingsTileState extends ConsumerState<SyncSettingsTile> {
  int? _maxPending;

  @override
  Widget build(BuildContext context) {
    final syncController = ref.watch(syncControllerProvider);
    if (!syncController.isSyncAvailable) {
      return const SizedBox.shrink();
    }

    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final repo = ref.watch(settingsRepositoryProvider);
    final syncEnabledAsync = ref.watch(syncEnabledStreamProvider);
    final isEnabled = syncEnabledAsync.value ?? false;

    final authService = ref.watch(authServiceProvider);
    final hasSession = authService.isSignedIn;

    final syncStateAsync = ref.watch(syncStateProvider);
    final syncState = syncStateAsync.value ?? syncController.currentSyncState;

    if (syncState is SyncUploading) {
      final pending = syncState.pending;
      if (_maxPending == null || pending > _maxPending!) {
        _maxPending = pending;
      }
    } else {
      _maxPending = null;
    }

    final showActivePanel = isEnabled && hasSession;
    final email = authService.currentSession?.user.email;
    final subtitle = showActivePanel
        ? (email ?? 'Sincronización activa')
        : 'Ver y editar tus datos desde la compu';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(PocktRadii.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.brandStart.withValues(
                    alpha: isDark ? 0.16 : 0.12,
                  ),
                ),
                child: Center(
                  child: Icon(
                    uiIcon('cloud'),
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
                      'Sincronizar con la web',
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
                key: const ValueKey('settings-sync-switch'),
                value: isEnabled,
                onChanged: (val) => _handleToggle(val, hasSession, repo),
              ),
            ],
          ),
          if (showActivePanel) ...[
            const SizedBox(height: 12),
            _buildStatusContent(context, syncState, syncController),
            const SizedBox(height: 12),
            Pressable(
              onTap: () => _confirmSignOut(context, authService, repo),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.glassBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusContent(
    BuildContext context,
    SyncState state,
    SyncController controller,
  ) {
    final colors = context.pockt;

    switch (state) {
      case SyncConnecting():
        return Row(
          children: [
            _buildStatusDot(colors.brandStart),
            const SizedBox(width: 8),
            Text(
              'Conectando…',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: colors.textPrimary,
              ),
            ),
          ],
        );

      case SyncUploading(:final pending):
        final max = _maxPending ?? pending;
        final done = max - pending;
        final text = (max > 0 && done >= 0)
            ? 'Subiendo tus datos · $done de $max'
            : 'Subiendo tus datos';
        final progress = max > 0 ? (done / max).clamp(0.0, 1.0) : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusDot(colors.brandStart),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: colors.glassBorder,
                valueColor: AlwaysStoppedAnimation<Color>(colors.brandStart),
              ),
            ),
          ],
        );

      case SyncSynced(:final lastSyncedAt):
        final text = lastSyncedAt == null
            ? 'Sincronizado'
            : 'Sincronizado · hace ${formatRelativeSyncTime(lastSyncedAt)}';

        return Row(
          children: [
            _buildStatusDot(colors.positive),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: colors.textPrimary,
              ),
            ),
          ],
        );

      case SyncOffline(:final pending):
        final text = pending == 0
            ? 'Sin conexión'
            : (pending == 1
                ? 'Sin conexión · 1 cambio esperando'
                : 'Sin conexión · $pending cambios esperando');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusDot(colors.warning),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Se suben solos cuando vuelva la señal.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
          ],
        );

      case SyncError(:final message):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusDot(colors.danger),
                const SizedBox(width: 8),
                Text(
                  'No se pudo sincronizar',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Pressable(
                    onTap: () => showErrorDetailSheet(context, message: message),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.glassBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Ver detalle',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Pressable(
                    onTap: () {
                      Haptics.tick();
                      controller.retry();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.brandStart.withValues(alpha: 0.2),
                        border: Border.all(color: colors.brandStart),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Reintentar',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      case SyncOff():
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatusDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Future<void> _handleToggle(
    bool targetValue,
    bool hasSession,
    SettingsRepository repo,
  ) async {
    Haptics.tick();
    if (!targetValue) {
      await repo.set(SettingsKeys.syncEnabled, 'false');
      return;
    }

    if (hasSession) {
      await repo.set(SettingsKeys.syncEnabled, 'true');
      return;
    }

    // Sin sesión previa: abrir hoja informativa para entrar con Google
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SyncConnectSheet(
        onSuccess: () async {
          await repo.set(SettingsKeys.syncEnabled, 'true');
        },
      ),
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    AuthService authService,
    SettingsRepository repo,
  ) {
    Haptics.tick();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = ctx.pockt;
        return Container(
          decoration: BoxDecoration(
            color: Color.alphaBlend(colors.glassFill, colors.background),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(26),
            ),
            border: Border.all(color: colors.glassBorder),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  '¿Cerrar sesión?',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dejás de sincronizar con la web. Tus datos siguen en este teléfono.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.5,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Pressable(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.glassBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Pressable(
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await authService.signOut();
                          await repo.set(SettingsKeys.syncEnabled, 'false');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.glassBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Cerrar sesión',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              color: colors.danger,
                            ),
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
      },
    );
  }
}

/// Hoja explicativa "Tus datos en la web".
class _SyncConnectSheet extends ConsumerWidget {
  final Future<void> Function() onSuccess;

  const _SyncConnectSheet({required this.onSuccess});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;

    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(colors.glassFill, colors.background),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(26),
        ),
        border: Border.all(color: colors.glassBorder),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.brandStart.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(
                  uiIcon('cloud'),
                  size: 22,
                  color: colors.brandStart,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Tus datos en la web',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Entrá con Google para ver, cargar y editar movimientos desde la compu. Los cambios se ven al instante en los dos lados.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.5,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  uiIcon('lock'),
                  size: 16,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Solo vos ves tus datos. Se guardan en tu cuenta privada en la nube y también siguen en este teléfono.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.5,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Pressable(
              onTap: () async {
                final authService = ref.read(authServiceProvider);
                try {
                  await authService.signInWithGoogle();
                  await onSuccess();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    final isCancel = e is AuthException &&
                        e.message.toLowerCase().contains('cancelado');
                    final msg = isCancel
                        ? 'Inicio de sesión cancelado'
                        : 'No se pudo iniciar sesión con Google';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg)),
                    );
                  }
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(18, 18),
                      painter: const GoogleLogoPainter(),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Continuar con Google',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PocktBrandLogos.googleDarkText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Pressable(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                alignment: Alignment.center,
                child: Text(
                  'Ahora no',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Muestra la hoja modal con el mensaje detallado de error.
Future<void> showErrorDetailSheet(
  BuildContext context, {
  required String message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final colors = ctx.pockt;
      return Container(
        decoration: BoxDecoration(
          color: Color.alphaBlend(colors.glassFill, colors.background),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(26),
          ),
          border: Border.all(color: colors.glassBorder),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Detalle del error',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.glassBorder),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Pressable(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.glassBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Entendido',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Provider para observar reactivamente el valor de SettingsKeys.syncEnabled.
final syncEnabledStreamProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.syncEnabled).map((val) => val == 'true');
});
