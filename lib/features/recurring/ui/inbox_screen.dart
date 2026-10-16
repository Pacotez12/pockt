import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/recurring/ui/suggestion_card.dart';

export 'package:pockt/features/recurring/ui/consecutive_confirmations.dart';
export 'package:pockt/features/recurring/ui/duplicate_warning_box.dart';
export 'package:pockt/features/recurring/ui/suggestion_card.dart';
export 'package:pockt/features/recurring/ui/suggestion_card_parts.dart';
export 'package:pockt/features/recurring/ui/suggestion_category_picker.dart';

/// Pantalla de Bandeja de sugerencias pendientes ("Por confirmar").
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTopBar(context),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<SuggestionView>>(
                stream: ref.watch(suggestionsRepositoryProvider).watchPending(),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return _buildEmptyState(context);
                  }
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return const SizedBox(height: 100);
                      }
                      final item = items[index];
                      return SuggestionCard(
                        key: ValueKey('suggestion-${item.suggestion.id}'),
                        item: item,
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

  Widget _buildTopBar(BuildContext context) {
    final colors = context.pockt;

    return Row(
      children: [
        Pressable(
          semanticLabel: 'Volver',
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.glassFill,
              shape: BoxShape.circle,
              border: Border.all(color: colors.glassBorder, width: 1),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Por confirmar',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: PocktType.title,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Movimientos sugeridos',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.pockt;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.glassFill,
                shape: BoxShape.circle,
                border: Border.all(color: colors.glassBorder, width: 1),
              ),
              child: Center(
                child: Icon(uiIcon('check'), size: 32, color: colors.positive),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Todo al día',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No tenés movimientos pendientes por confirmar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
