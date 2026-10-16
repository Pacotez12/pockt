import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/entry/domain/entry_form_logic.dart';
import 'package:pockt/features/entry/ui/category_hero_pill.dart';
import 'package:pockt/features/entry/ui/keypad_widgets.dart';
import 'package:pockt/features/home/ui/month_glow.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

export 'package:pockt/features/entry/ui/category_hero_pill.dart';
export 'package:pockt/features/entry/ui/keypad_widgets.dart';

class AmountKeypadScreen extends ConsumerStatefulWidget {
  final Category category;
  final TxType type;
  final TxView? editing;
  final int? initialAmount;
  final DateTime? initialDate;
  final String? initialMerchant;
  final String? initialLoanId;
  final Future<void> Function({
    required int amount,
    required Category category,
    required DateTime occurredAt,
    String? merchant,
    String? note,
  })?
  onSaveOverride;

  final bool showMerchant;

  const AmountKeypadScreen({
    super.key,
    required this.category,
    required this.type,
    this.editing,
    this.initialAmount,
    this.initialDate,
    this.initialMerchant,
    this.initialLoanId,
    this.onSaveOverride,
    this.showMerchant = true,
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
  String? _loanId;
  bool _isSaving = false;
  bool _notePrompted = false;

  @override
  void initState() {
    super.initState();
    final seed = EntryKeypadSeed.fromArgs(
      category: widget.category,
      editing: widget.editing,
      initialAmount: widget.initialAmount,
      initialDate: widget.initialDate,
      initialMerchant: widget.initialMerchant,
      initialLoanId: widget.initialLoanId,
    );
    _category = seed.category;
    _loanId = seed.loanId;
    _digits = seed.digits;
    _occurredAt = seed.occurredAt;
    _merchant = seed.merchant;
    _note = seed.note;
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

    final askNote = ref.read(askNoteProvider).value ?? false;
    if (shouldPromptForNote(
      askNoteEnabled: askNote,
      alreadyPrompted: _notePrompted,
      currentNote: _note,
    )) {
      _notePrompted = true;
      final noteController = TextEditingController(text: _note ?? '');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nota o comercio'),
          content: TextField(
            key: const ValueKey('ask-note-field'),
            controller: noteController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ej. Almuerzo, Superseis',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Omitir'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Listo'),
            ),
          ],
        ),
      );
      if (confirmed == null) {
        _notePrompted = false;
        return;
      }
      if (noteController.text.trim().isNotEmpty) {
        _note = noteController.text.trim();
      }
    }

    setState(() => _isSaving = true);
    try {
      if (widget.onSaveOverride != null) {
        await widget.onSaveOverride!(
          amount: amount,
          category: _category,
          occurredAt: _occurredAt.toUtc(),
          merchant: _merchant,
          note: _note,
        );
      } else {
        final txRepo = ref.read(transactionsRepositoryProvider);
        if (widget.editing != null) {
          await txRepo.update(
            widget.editing!.tx.id,
            amount: amount,
            categoryId: _category.id,
            occurredAt: _occurredAt.toUtc(),
            merchant: _merchant,
            note: _note,
            loanId: _loanId,
          );
        } else {
          await txRepo.add(
            type: widget.type,
            amount: amount,
            categoryId: _category.id,
            occurredAt: _occurredAt.toUtc(),
            merchant: _merchant,
            note: _note,
            loanId: _loanId,
          );
        }
      }
      Haptics.save();
      ref.read(monthGlowPulseProvider.notifier).pulse();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: context.pockt.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = Color(
      isDark ? _category.colorDark : _category.colorLight,
    );
    final amount = keypadValue(_digits);
    final canSave = amount > 0 && !_isSaving;
    ref.watch(askNoteProvider);

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
                child: RepaintBoundary(
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
            ),
            Column(
              children: [
                // Top bar: Close/back and Date Selector
                RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(uiIcon('x'), size: 22),
                          color: colors.textSecondary,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        EntryDateSelector(
                          date: _occurredAt,
                          onDateSelected: (d) => setState(
                            () => _occurredAt = combineDayWithNow(
                              d,
                              DateTime.now(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                // Category Pill with shared Hero                // Category Pill with shared Hero
                CategoryHeroPill(category: _category),
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
                EntryOptionalChips(
                  merchant: _merchant,
                  note: _note,
                  showMerchant: widget.showMerchant,
                  onMerchantChanged: (m) => setState(() => _merchant = m),
                  onNoteChanged: (n) => setState(() => _note = n),
                ),
                const Spacer(flex: 2),
                // 3x4 Keypad Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: RepaintBoundary(
                    child: AmountKeypadGrid(
                      onKey: _onKey,
                      quickKey: ref.watch(quickKeyProvider).value ?? '000',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Save Button (FilledButton)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: FilledButton(
                    key: const ValueKey('keypad-btn-action'),
                    onPressed: canSave ? _onSave : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: categoryColor,
                      foregroundColor: categoryColor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      disabledBackgroundColor: colors.glassFill,
                      disabledForegroundColor: colors.textTertiary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PocktRadii.xl),
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
