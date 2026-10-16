import 'package:flutter/material.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/entry/domain/entry_form_logic.dart';

class AmountKeypadGrid extends StatelessWidget {
  final ValueChanged<String> onKey;
  final String quickKey;

  const AmountKeypadGrid({
    super.key,
    required this.onKey,
    this.quickKey = '000',
  });

  @override
  Widget build(BuildContext context) {
    final keys = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      quickKey,
      '0',
      '⌫',
    ];

    return Column(
      children: [
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: AmountKeypadButton(
                    label: keys[row * 3 + col],
                    onTap: () => onKey(keys[row * 3 + col]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class AmountKeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const AmountKeypadButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Pressable(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(PocktRadii.l),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: (label == '000' || label == '00') ? 18 : 22,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class EntryDateSelector extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onDateSelected;

  const EntryDateSelector({
    super.key,
    required this.date,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final label = formatEntryDateLabel(date, DateTime.now());

    return Pressable(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onDateSelected(mergePickedDateWithTime(picked, date));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.glassFill,
          borderRadius: BorderRadius.circular(PocktRadii.l),
          border: Border.all(color: colors.glassBorder, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class EntryOptionalChips extends StatelessWidget {
  final String? merchant;
  final String? note;
  final ValueChanged<String?> onMerchantChanged;
  final ValueChanged<String?> onNoteChanged;
  final bool showMerchant;

  const EntryOptionalChips({
    super.key,
    required this.merchant,
    required this.note,
    required this.onMerchantChanged,
    required this.onNoteChanged,
    this.showMerchant = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showMerchant) ...[
          EntryChipButton(
            icon: uiIcon('storefront'),
            label: merchant?.isNotEmpty == true ? merchant! : 'Comercio',
            isActive: merchant?.isNotEmpty == true,
            onTap: () => _showEditDialog(
              context,
              title: 'Comercio',
              initialValue: merchant,
              hint: 'Ej. Superseis',
              onChanged: onMerchantChanged,
            ),
          ),
          const SizedBox(width: 8),
        ],
        EntryChipButton(
          icon: uiIcon('note'),
          label: note?.isNotEmpty == true ? note! : 'Nota',
          isActive: note?.isNotEmpty == true,
          onTap: () => _showEditDialog(
            context,
            title: 'Nota',
            initialValue: note,
            hint: 'Ej. Almuerzo con café',
            onChanged: onNoteChanged,
          ),
        ),
      ],
    );
  }

  Future<void> _showEditDialog(
    BuildContext context, {
    required String title,
    required String? initialValue,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
    if (res != null) {
      onChanged(res.isEmpty ? null : res);
    }
  }
}

class EntryChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const EntryChipButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? colors.textPrimary.withValues(alpha: 0.12)
              : colors.glassFill,
          borderRadius: BorderRadius.circular(PocktRadii.l),
          border: Border.all(
            color: isActive ? colors.textSecondary : colors.glassBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? colors.textPrimary : colors.textTertiary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? colors.textPrimary : colors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
