import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

/// Un grupo de gastos hormiga (por comercio o por categoría).
class AntExpenseGroup {
  final String name;
  final String? merchant;
  final String categoryName;
  final String categoryIcon;
  final int? colorDark;
  final int? colorLight;
  final int total;
  final int count;
  int get average => count > 0 ? total ~/ count : 0;

  const AntExpenseGroup({
    required this.name,
    this.merchant,
    required this.categoryName,
    required this.categoryIcon,
    this.colorDark,
    this.colorLight,
    required this.total,
    required this.count,
  });
}

/// Resumen consolidado de gastos hormiga del período.
class AntExpensesSummary {
  final int total;
  final int count;
  final int annualProjection;
  final int threshold;
  final List<AntExpenseGroup> groups;

  const AntExpensesSummary({
    required this.total,
    required this.count,
    required this.annualProjection,
    required this.threshold,
    required this.groups,
  });

  static const empty = AntExpensesSummary(
    total: 0,
    count: 0,
    annualProjection: 0,
    threshold: 30000,
    groups: [],
  );
}

/// Helper para agrupar información mientras se procesan los movimientos.
class _GroupAccumulator {
  int total = 0;
  int count = 0;
  final Map<String, int> merchantSpellings = {};
  final Map<String, int> categoryCounts = {};
  String fallbackCategoryName = '';
  String fallbackCategoryIcon = 'dots-three';
  int? colorDark;
  int? colorLight;
}

/// Calcula el resumen de gastos hormiga para una lista de movimientos.
/// Filtra gastos cuyo monto sea menor o igual a [threshold].
/// Proyección anual: total del mes * 12.
/// Agrupación: por comercio normalizado si existe, o por categoría si no.
AntExpensesSummary calculateAntExpenses({
  required List<TxView> transactions,
  int threshold = 30000,
}) {
  var grandTotal = 0;
  var grandCount = 0;

  final Map<String, _GroupAccumulator> map = {};

  for (final item in transactions) {
    final tx = item.tx;
    if (tx.type != TxType.expense || tx.amount > threshold) {
      continue;
    }

    grandTotal += tx.amount;
    grandCount += 1;

    final rawMerchant = tx.merchant?.trim();
    final hasMerchant = rawMerchant != null && rawMerchant.isNotEmpty;

    final String groupKey;
    if (hasMerchant) {
      groupKey = 'm_${normalizeKeyword(rawMerchant)}';
    } else {
      groupKey = 'c_${item.category.id}';
    }

    final acc = map.putIfAbsent(groupKey, () => _GroupAccumulator());
    acc.total += tx.amount;
    acc.count += 1;
    acc.fallbackCategoryName = item.category.name;
    acc.fallbackCategoryIcon = item.category.icon;
    acc.colorDark = item.category.colorDark;
    acc.colorLight = item.category.colorLight;

    if (hasMerchant) {
      acc.merchantSpellings[rawMerchant] =
          (acc.merchantSpellings[rawMerchant] ?? 0) + 1;
    }
  }

  final groups = map.entries.map((entry) {
    final acc = entry.value;
    final isMerchant = entry.key.startsWith('m_');

    String displayName;
    String? merchant;

    if (isMerchant && acc.merchantSpellings.isNotEmpty) {
      // Elegir el spelling más frecuente
      var bestSpelling = acc.merchantSpellings.keys.first;
      var bestCount = acc.merchantSpellings.values.first;
      for (final sEntry in acc.merchantSpellings.entries) {
        if (sEntry.value > bestCount) {
          bestCount = sEntry.value;
          bestSpelling = sEntry.key;
        }
      }
      displayName = bestSpelling;
      merchant = bestSpelling;
    } else {
      displayName = acc.fallbackCategoryName;
    }

    return AntExpenseGroup(
      name: displayName,
      merchant: merchant,
      categoryName: acc.fallbackCategoryName,
      categoryIcon: acc.fallbackCategoryIcon,
      colorDark: acc.colorDark,
      colorLight: acc.colorLight,
      total: acc.total,
      count: acc.count,
    );
  }).toList();

  groups.sort((a, b) {
    final cmp = b.total.compareTo(a.total);
    if (cmp != 0) return cmp;
    return b.count.compareTo(a.count);
  });

  return AntExpensesSummary(
    total: grandTotal,
    count: grandCount,
    annualProjection: grandTotal * 12,
    threshold: threshold,
    groups: groups,
  );
}
