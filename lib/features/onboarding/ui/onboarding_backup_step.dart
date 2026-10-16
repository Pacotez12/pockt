import 'package:flutter/material.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';

class OnboardingBackupStep extends StatelessWidget {
  final TextEditingController passwordCtrl;
  final TextEditingController confirmPasswordCtrl;
  final String? backupError;
  final bool isSaving;
  final VoidCallback onFinish;

  const OnboardingBackupStep({
    super.key,
    required this.passwordCtrl,
    required this.confirmPasswordCtrl,
    required this.backupError,
    required this.isSaving,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return SingleChildScrollView(
      key: const ValueKey('step-3-backup'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.brandAt(0).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              uiIcon('shield-check'),
              color: colors.brandAt(0),
              size: 26,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Copia de seguridad local',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tus datos viven únicamente en tu teléfono. Las copias se guardan en Documentos/Pockt y se cifran con AES-256-GCM.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Advertencia de seguridad
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(PocktRadii.m),
              border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(uiIcon('warning'), color: colors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pockt nunca guarda tu contraseña: sin ella no podrás restaurar tus respaldos.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.warning,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Campos de contraseña
          TextField(
            controller: passwordCtrl,
            obscureText: true,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Contraseña de respaldo',
              labelStyle: TextStyle(color: colors.textSecondary),
              filled: true,
              fillColor: colors.glassFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PocktRadii.l),
                borderSide: BorderSide(color: colors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PocktRadii.l),
                borderSide: BorderSide(color: colors.glassBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmPasswordCtrl,
            obscureText: true,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              labelStyle: TextStyle(color: colors.textSecondary),
              filled: true,
              fillColor: colors.glassFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PocktRadii.l),
                borderSide: BorderSide(color: colors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PocktRadii.l),
                borderSide: BorderSide(color: colors.glassBorder),
              ),
            ),
          ),

          if (backupError != null) ...[
            const SizedBox(height: 10),
            Text(
              backupError!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: colors.danger,
              ),
            ),
          ],
          const SizedBox(height: 36),

          ElevatedButton(
            onPressed: isSaving ? null : onFinish,
            style: ElevatedButton.styleFrom(
              // Botón primario con el degradé de marca, como en el resto.
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              backgroundBuilder: (context, states, child) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.brandStart, colors.brandEnd],
                  ),
                  borderRadius: BorderRadius.circular(PocktRadii.xl),
                ),
                child: child,
              ),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PocktRadii.xl),
              ),
              elevation: 0,
            ),
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Empezar a usar Pockt',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
