import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:pockt/features/transactions/ui/tx_row.dart';

/// Pestaña Movimientos (spec §5.4):
/// Lista de transacciones agrupadas por día local (encabezados "Hoy", "Ayer",
/// luego fecha), con buscador por texto (nota y comercio) y filtros.
class TransactionsScreen extends ConsumerStatefulWidget {
  final DateTime? nowLocal;

  const TransactionsScreen({super.key, this.nowLocal});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  TxType? _typeFilter;

  DateTime _getNow() => widget.nowLocal ?? toLocal(DateTime.now());

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final now = _getNow();
    final repo = ref.watch(transactionsRepositoryProvider);

    final txStream = repo.watchFiltered(
      query: _query.isEmpty ? null : _query,
      type: _typeFilter,
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            // Encabezado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Movimientos',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Buscador
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.glassFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.glassBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      uiIcon('magnifying-glass'),
                      size: 18,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('tx-search'),
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _query = val.trim();
                          });
                        },
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar por comercio o nota...',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: colors.textTertiary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                        child: Icon(
                          uiIcon('close'),
                          size: 16,
                          color: colors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Filtro por tipo (Todos / Gastos / Ingresos)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildTypeFilterChip(label: 'Todos', type: null),
                  const SizedBox(width: 8),
                  _buildTypeFilterChip(label: 'Gastos', type: TxType.expense),
                  const SizedBox(width: 8),
                  _buildTypeFilterChip(label: 'Ingresos', type: TxType.income),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Lista agrupada por día local
            Expanded(
              child: StreamBuilder<List<TxView>>(
                stream: txStream,
                builder: (context, snapshot) {
                  final list = snapshot.data ?? const [];

                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        _query.isNotEmpty
                            ? 'Sin resultados para "$_query"'
                            : 'Sin movimientos',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: colors.textTertiary,
                        ),
                      ),
                    );
                  }

                  // Agrupar por día local
                  final groups = <DateTime, List<TxView>>{};
                  for (final view in list) {
                    final local = toLocal(view.tx.occurredAt);
                    final dayKey = DateTime(local.year, local.month, local.day);
                    groups.putIfAbsent(dayKey, () => []).add(view);
                  }

                  final sortedDays = groups.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                    itemCount: sortedDays.length,
                    itemBuilder: (context, index) {
                      final day = sortedDays[index];
                      final items = groups[day]!;
                      final header = formatDayHeader(day, now);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 6),
                            child: Text(
                              header,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            borderRadius: BorderRadius.circular(20),
                            child: Column(
                              children: [
                                for (final item in items)
                                  SwipeableTxRow(
                                    view: item,
                                    subtitle: _rowSubtitle(item, now),
                                  ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildTypeFilterChip({required String label, required TxType? type}) {
    final colors = context.pockt;
    final isSelected = _typeFilter == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _typeFilter = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.glassBorder : colors.glassFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.textSecondary : colors.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? colors.textPrimary : colors.textTertiary,
          ),
        ),
      ),
    );
  }

  String _rowSubtitle(TxView view, DateTime now) {
    final localTime = toLocal(view.tx.occurredAt);
    final timeStr =
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    final merchant = view.tx.merchant?.trim();
    if (merchant != null && merchant.isNotEmpty) {
      return '${view.category.name} · $timeStr';
    }
    return timeStr;
  }
}
