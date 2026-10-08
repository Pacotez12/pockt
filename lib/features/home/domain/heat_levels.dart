Map<int, int> heatLevels(Map<int, int> dailyTotals) {
  if (dailyTotals.isEmpty) {
    return {};
  }

  final result = <int, int>{};
  final positiveDays = <int, int>{};

  for (final entry in dailyTotals.entries) {
    if (entry.value <= 0) {
      result[entry.key] = 0;
    } else {
      positiveDays[entry.key] = entry.value;
    }
  }

  if (positiveDays.isEmpty) {
    return result;
  }

  final sortedAmounts = positiveDays.values.toList()..sort();
  final n = sortedAmounts.length;
  final allEqual = sortedAmounts.first == sortedAmounts.last;

  if (allEqual) {
    for (final day in positiveDays.keys) {
      result[day] = 4;
    }
    return result;
  }

  for (final entry in positiveDays.entries) {
    final amount = entry.value;
    final rank = sortedAmounts.indexOf(amount);
    final calculated = 1 + (4 * rank ~/ n);
    final level = calculated.clamp(1, 4);
    result[entry.key] = level;
  }

  return result;
}
