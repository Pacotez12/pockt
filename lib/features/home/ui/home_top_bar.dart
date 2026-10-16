import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/settings/ui/settings_screen.dart';

const List<String> kMonthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Barra superior de Inicio: selector desplegable de mes y acceso a Ajustes.
class HomeTopBar extends ConsumerWidget {
  final int month;
  final ValueChanged<int> onMonthSelected;

  const HomeTopBar({
    super.key,
    required this.month,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PopupMenuButton<int>(
          initialValue: month,
          tooltip: 'Elegir mes',
          onSelected: (m) {
            if (m != month) {
              Haptics.tick();
              onMonthSelected(m);
            }
          },
          itemBuilder: (context) => [
            for (int m = 1; m <= 12; m++)
              PopupMenuItem(
                value: m,
                child: Text(
                  kMonthNames[m - 1],
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: m == month ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PocktRadii.l),
              color: colors.glassFill,
              border: Border.all(color: colors.glassBorder),
            ),
            child: Text(
              '${kMonthNames[month - 1]} ▾',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        Pressable(
          semanticLabel: 'Ajustes',
          key: const ValueKey('home-settings-button'),
          onTap: () {
            Haptics.tick();
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
          },
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.glassFill,
              border: Border.all(color: colors.glassBorder),
            ),
            child: Center(
              child: Icon(uiIcon('gear'), size: 16, color: colors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}
