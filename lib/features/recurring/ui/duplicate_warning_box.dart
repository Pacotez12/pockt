import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';

class DuplicateWarningBox extends ConsumerWidget {
  const DuplicateWarningBox({super.key, required this.duplicateTxId});

  final String duplicateTxId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<Transaction?>(
      stream:
          (db.select(db.transactions)
                ..where((t) => t.id.equals(duplicateTxId))
                ..limit(1))
              .watchSingleOrNull(),
      builder: (context, snapshot) {
        final tx = snapshot.data;
        final manualLabel = tx != null
            ? '${tx.merchant?.trim().isNotEmpty == true ? tx.merchant! : (tx.note?.trim().isNotEmpty == true ? tx.note! : "Movimiento manual")} · ${formatGs(tx.amount)}'
            : 'Movimiento manual con el mismo monto';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(PocktRadii.m),
            border: Border.all(color: colors.warning.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(uiIcon('warning'), size: 16, color: colors.warning),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Posible duplicado',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: PocktType.caption,
                        fontWeight: FontWeight.w700,
                        color: colors.warning,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ya cargaste: $manualLabel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: PocktType.caption,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
