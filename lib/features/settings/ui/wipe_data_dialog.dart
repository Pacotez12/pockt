import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/notifications/notifier.dart' show notifierProvider;
import 'package:pockt/features/settings/domain/wipe_data.dart';
import 'package:pockt/features/widget/home_widget_bridge.dart';

class WipeDataDialog extends StatefulWidget {
  final WidgetRef ref;
  const WipeDataDialog({super.key, required this.ref});

  @override
  State<WipeDataDialog> createState() => WipeDataDialogState();
}

class WipeDataDialogState extends State<WipeDataDialog> {
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

void showWipeDataDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => WipeDataDialog(ref: ref),
  );
}
