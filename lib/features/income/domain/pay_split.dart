import 'dart:convert';

/// Divide el [monthlyAmount] entre los porcentajes [percents].
/// Cada tramo se redondea a guaraníes enteros y el último tramo absorbe
/// la diferencia para garantizar que la suma dé exactamente [monthlyAmount].
List<int> splitAmounts(int monthlyAmount, List<int> percents) {
  if (percents.isEmpty) return const [];
  if (percents.length == 1) return [monthlyAmount];

  final result = <int>[];
  var accumulated = 0;

  for (var i = 0; i < percents.length - 1; i++) {
    final amount = (monthlyAmount * (percents[i] / 100.0)).round();
    result.add(amount);
    accumulated += amount;
  }

  // El último tramo absorbe el redondeo restante.
  result.add(monthlyAmount - accumulated);
  return result;
}

/// Parsea los porcentajes de reparto desde un string JSON o devuelve
/// partes iguales según la cantidad [count].
List<int> parsePaySplitPercents(String? rawJson, {int count = 2}) {
  if (rawJson != null && rawJson.trim().isNotEmpty) {
    try {
      final list = (jsonDecode(rawJson) as List)
          .map((e) => (e as num).toInt())
          .toList();
      if (list.length == count) {
        return list;
      }
    } catch (_) {}
  }

  return defaultPaySplitPercents(count);
}

/// Genera porcentajes por defecto en partes iguales sumando 100.
List<int> defaultPaySplitPercents(int count) {
  if (count <= 1) return const [100];
  if (count == 2) return const [50, 50];

  final each = 100 ~/ count;
  final result = List.filled(count, each);
  result[count - 1] = 100 - (each * (count - 1));
  return result;
}
