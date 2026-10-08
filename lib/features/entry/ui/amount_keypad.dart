import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

class AmountKeypadScreen extends ConsumerStatefulWidget {
  final Category category;
  final TxType type;
  final TxView? editing;
  final int? initialAmount;
  final DateTime? initialDate;
  final String? initialMerchant;

  const AmountKeypadScreen({
    super.key,
    required this.category,
    required this.type,
    this.editing,
    this.initialAmount,
    this.initialDate,
    this.initialMerchant,
  });

  @override
  ConsumerState<AmountKeypadScreen> createState() => _AmountKeypadScreenState();
}

class _AmountKeypadScreenState extends ConsumerState<AmountKeypadScreen> {
  late Category _category;
  late String _digits;
  late DateTime _occurredAt;
  String? _merchant;
  String? _note;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    if (widget.editing != null) {
      _digits = widget.editing!.tx.amount.toString();
      _occurredAt = toLocal(widget.editing!.tx.occurredAt);
      _merchant = widget.editing!.tx.merchant;
      _note = widget.editing!.tx.note;
    } else {
      _digits = widget.initialAmount != null && widget.initialAmount! > 0
          ? widget.initialAmount.toString()
          : '';
      _occurredAt = widget.initialDate ?? DateTime.now();
      _merchant = widget.initialMerchant;
      _note = null;
    }
  }

  void _onKey(String key) {
    Haptics.key();
    setState(() {
      _digits = keypadAppend(_digits, key);
    });
  }

  Future<void> _onSave() async {
    final amount = keypadValue(_digits);
    if (amount <= 0 || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final txRepo = ref.read(transactionsRepositoryProvider);
      if (widget.editing != null) {
        await txRepo.update(
          widget.editing!.tx.id,
          amount: amount,
          categoryId: _category.id,
          occurredAt: _occurredAt.toUtc(),
          merchant: _merchant,
          note: _note,
        );
      } else {
        await txRepo.add(
          type: widget.type,
          amount: amount,
          categoryId: _category.id,
          occurredAt: _occurredAt.toUtc(),
          merchant: _merchant,
          note: _note,
        );
      }
      Haptics.save();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = Color(isDark ? _category.colorDark : _category.colorLight);
    final amount = keypadValue(_digits);
    final canSave = amount > 0 && !_isSaving;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient category glow behind top section
            Positioned(
              top: -60,
              left: -40,
              right: -40,
              height: 340,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        categoryColor.withValues(alpha: isDark ? 0.35 : 0.22),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                // Top bar: Close/back and Date Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(uiIcon('x'), size: 22),
                        color: colors.textSecondary,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      _DateSelector(
                        date: _occurredAt,
                        onDateSelected: (d) => setState(() => _occurredAt = d),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 1),
                // Category Pill with shared Hero
                Hero(
                  tag: 'cat-${_category.id}',
                  createRectTween: (begin, end) => SpringRectTween(begin: begin, end: end),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: isDark ? 0.22 : 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: categoryColor.withValues(alpha: isDark ? 0.6 : 0.4),
                          width: 1,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            categoryIcon(_category.icon, size: 20, color: colors.textPrimary),
                            const SizedBox(width: 8),
                            Text(
                              _category.name,
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
                  ),
                ),
                const SizedBox(height: 16),
                // Formatted Amount Display
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatGs(amount),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 48,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Optional chips: Merchant & Note
                _OptionalChips(
                  merchant: _merchant,
                  note: _note,
                  onMerchantChanged: (m) => setState(() => _merchant = m),
                  onNoteChanged: (n) => setState(() => _note = n),
                ),
                const Spacer(flex: 2),
                // 3x4 Keypad Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _AmountKeypadGrid(onKey: _onKey),
                ),
                const SizedBox(height: 16),
                // Save Button (FilledButton)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: FilledButton(
                    onPressed: canSave ? _onSave : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: categoryColor,
                      foregroundColor: categoryColor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      disabledBackgroundColor: colors.glassFill,
                      disabledForegroundColor: colors.textTertiary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text(
                      'Guardar',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountKeypadGrid extends StatelessWidget {
  final ValueChanged<String> onKey;

  const _AmountKeypadGrid({required this.onKey});

  static const List<String> _keys = [
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '000', '0', '⌫',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: _KeypadButton(
                    label: _keys[row * 3 + col],
                    onTap: () => onKey(_keys[row * 3 + col]),
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

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeypadButton({required this.label, required this.onTap});

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
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: label == '000' ? 18 : 22,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onDateSelected;

  const _DateSelector({
    required this.date,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1;

    final String label;
    if (isToday) {
      final hour = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');
      label = 'Hoy, $hour:$min';
    } else if (isYesterday) {
      label = 'Ayer';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Pressable(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onDateSelected(DateTime(
            picked.year,
            picked.month,
            picked.day,
            date.hour,
            date.minute,
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.glassFill,
          borderRadius: BorderRadius.circular(16),
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

class _OptionalChips extends StatelessWidget {
  final String? merchant;
  final String? note;
  final ValueChanged<String?> onMerchantChanged;
  final ValueChanged<String?> onNoteChanged;

  const _OptionalChips({
    required this.merchant,
    required this.note,
    required this.onMerchantChanged,
    required this.onNoteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ChipButton(
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
        _ChipButton(
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

class _ChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ChipButton({
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
          borderRadius: BorderRadius.circular(16),
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
