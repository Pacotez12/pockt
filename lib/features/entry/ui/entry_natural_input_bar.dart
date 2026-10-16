import 'package:flutter/material.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/features/entry/domain/entry_form_logic.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';

class EntryNaturalInputSection extends StatelessWidget {
  final TextEditingController controller;
  final TxType currentType;
  final ParsedEntry? proposal;
  final Category? proposedCategory;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final void Function(ParsedEntry proposal, Category category) onProposalTapped;

  const EntryNaturalInputSection({
    super.key,
    required this.controller,
    required this.currentType,
    required this.proposal,
    required this.proposedCategory,
    required this.onChanged,
    required this.onClear,
    required this.onProposalTapped,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            borderRadius: BorderRadius.circular(PocktRadii.l),
            child: Row(
              children: [
                Icon(
                  uiIcon('sparkle'),
                  size: 18,
                  color: colors.textSecondary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: currentType == TxType.expense
                          ? 'Ej. bolt 28.500, super 230 mil ayer'
                          : 'Ej. sueldo 8.500.000, extra 300 mil',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: colors.textSecondary.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: onChanged,
                  ),
                ),
                if (controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: onClear,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        uiIcon('x'),
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: proposal != null && proposedCategory != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 8),
                  child: Pressable(
                    key: const ValueKey('natural-proposal-card'),
                    onTap: () => onProposalTapped(proposal!, proposedCategory!),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      borderRadius: BorderRadius.circular(PocktRadii.l),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(
                                isDark
                                    ? proposedCategory!.colorDark
                                    : proposedCategory!.colorLight,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: categoryIcon(
                              proposedCategory!.icon,
                              size: 22,
                              color: colors.keypadKey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  proposedCategory!.name,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                if (shouldShowProposalMerchant(
                                  proposal!,
                                  proposedCategory!,
                                ))
                                  Text(
                                    proposal!.merchant!,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            formatGs(proposal!.amount),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            uiIcon('caret-right'),
                            size: 16,
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
