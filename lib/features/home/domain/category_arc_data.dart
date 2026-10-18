import 'package:pockt/features/transactions/data/transactions_repository.dart';

/// Representa un tramo proporcional del CategoryArc.
class CategoryArcSegment {
  final String id;
  final String name;
  final int amount;
  final int percentage; // 0..100
  final int colorDark;
  final int colorLight;
  final bool isOther;

  const CategoryArcSegment({
    required this.id,
    required this.name,
    required this.amount,
    required this.percentage,
    required this.colorDark,
    required this.colorLight,
    this.isOther = false,
  });

  CategoryArcSegment copyWith({
    String? id,
    String? name,
    int? amount,
    int? percentage,
    int? colorDark,
    int? colorLight,
    bool? isOther,
  }) {
    return CategoryArcSegment(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
      colorDark: colorDark ?? this.colorDark,
      colorLight: colorLight ?? this.colorLight,
      isOther: isOther ?? this.isOther,
    );
  }
}

/// Construye los tramos para el arco de categorías:
/// - Máximo 5 tramos.
/// - Si hay <= 5 categorías con gasto, se conservan todas de mayor a menor sin "Otros".
/// - Si hay > 5 categorías, se toman las 4 de mayor gasto y el resto se agrupa en "Otros" al final.
/// - Los porcentajes enteros se calculan con el método de mayor resto (Largest Remainder Method)
///   garantizando que la suma sea exactamente 100%.
List<CategoryArcSegment> buildCategoryArcSegments({
  required List<CategoryTotal> categoryTotals,
  int otherColorDark = 0xFF7C8796,
  int otherColorLight = 0xFF606A74,
}) {
  final validTotals = categoryTotals.where((c) => c.total > 0).toList();
  if (validTotals.isEmpty) return const [];

  // Ordenar de mayor a menor
  validTotals.sort((a, b) => b.total.compareTo(a.total));

  final totalSum = validTotals.fold<int>(0, (sum, c) => sum + c.total);
  if (totalSum <= 0) return const [];

  final List<CategoryArcSegment> baseSegments = [];

  if (validTotals.length <= 5) {
    for (final ct in validTotals) {
      baseSegments.add(
        CategoryArcSegment(
          id: ct.category.id,
          name: ct.category.name,
          amount: ct.total,
          percentage: 0,
          colorDark: ct.category.colorDark,
          colorLight: ct.category.colorLight,
          isOther: false,
        ),
      );
    }
  } else {
    // Top 4
    for (int i = 0; i < 4; i++) {
      final ct = validTotals[i];
      baseSegments.add(
        CategoryArcSegment(
          id: ct.category.id,
          name: ct.category.name,
          amount: ct.total,
          percentage: 0,
          colorDark: ct.category.colorDark,
          colorLight: ct.category.colorLight,
          isOther: false,
        ),
      );
    }
    // Resto agrupado en "Otros"
    int otherSum = 0;
    for (int i = 4; i < validTotals.length; i++) {
      otherSum += validTotals[i].total;
    }
    if (otherSum > 0) {
      baseSegments.add(
        CategoryArcSegment(
          id: 'other',
          name: 'Otros',
          amount: otherSum,
          percentage: 0,
          colorDark: otherColorDark,
          colorLight: otherColorLight,
          isOther: true,
        ),
      );
    }
  }

  if (baseSegments.isEmpty) return const [];

  // Método de mayor resto para porcentajes enteros que suman 100%
  final List<int> floors = [];
  final List<double> remainders = [];
  int assignedSum = 0;

  for (final seg in baseSegments) {
    final exact = (seg.amount * 100.0) / totalSum;
    final f = exact.floor();
    floors.add(f);
    remainders.add(exact - f);
    assignedSum += f;
  }

  int diff = 100 - assignedSum;
  // Índices ordenados por resto descendente
  final indices = List.generate(baseSegments.length, (i) => i);
  indices.sort((a, b) {
    final cmp = remainders[b].compareTo(remainders[a]);
    if (cmp != 0) return cmp;
    return baseSegments[b].amount.compareTo(baseSegments[a].amount);
  });

  final List<int> finalPercentages = List<int>.from(floors);
  for (int i = 0; i < diff && i < indices.length; i++) {
    finalPercentages[indices[i]] += 1;
  }

  return List.generate(baseSegments.length, (i) {
    return baseSegments[i].copyWith(percentage: finalPercentages[i]);
  });
}
