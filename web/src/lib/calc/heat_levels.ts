/**
 * heat_levels.ts
 * Port of lib/features/home/domain/heat_levels.dart
 */

export function heatLevels(dailyTotals: Map<number, number> | Record<number, number>): Map<number, number> {
  const entries: [number, number][] =
    dailyTotals instanceof Map
      ? Array.from(dailyTotals.entries())
      : Object.entries(dailyTotals).map(([k, v]) => [Number(k), v as number]);

  if (entries.length === 0) {
    return new Map();
  }

  const result = new Map<number, number>();
  const positiveDays = new Map<number, number>();

  for (const [day, val] of entries) {
    if (val <= 0) {
      result.set(day, 0);
    } else {
      positiveDays.set(day, val);
    }
  }

  if (positiveDays.size === 0) {
    return result;
  }

  const sortedAmounts = Array.from(positiveDays.values()).sort((a, b) => a - b);
  const n = sortedAmounts.length;
  const allEqual = sortedAmounts[0] === sortedAmounts[n - 1];

  if (allEqual) {
    for (const day of positiveDays.keys()) {
      result.set(day, 4);
    }
    return result;
  }

  for (const [day, amount] of positiveDays.entries()) {
    const rank = sortedAmounts.indexOf(amount);
    const calculated = 1 + Math.floor((4 * rank) / n);
    const level = Math.max(1, Math.min(4, calculated));
    result.set(day, level);
  }

  return result;
}
