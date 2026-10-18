import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';

void showAboutPocktDialog(BuildContext context) async {
  String version = '1.0.0';
  try {
    final info = await PackageInfo.fromPlatform();
    version = info.version;
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
          Icon(uiIcon('info'), color: colors.brandAt(0), size: 22),
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
            style: TextStyle(fontFamily: 'Inter', color: colors.textSecondary),
          ),
        ),
        Pressable(
          onTap: () => Navigator.of(ctx).pop(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.brandStart, colors.brandEnd],
              ),
              borderRadius: BorderRadius.circular(PocktRadii.m),
            ),
            child: const Text(
              'Cerrar',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
