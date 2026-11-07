/**
 * category_arc_data.ts
 * Port of lib/features/home/domain/category_arc_data.dart
 */

export interface CategoryInput {
  id: string;
  name: string;
  amount: number;
  colorDark: number;
  colorLight: number;
}

export interface CategoryArcSegment {
  id: string;
  name: string;
  amount: number;
  percentage: number;
  colorDark: number;
  colorLight: number;
  isOther: boolean;
}

export function buildCategoryArcSegments(
  categoryTotals: CategoryInput[],
  options?: {
    otherColorDark?: number;
    otherColorLight?: number;
  },
): CategoryArcSegment[] {
  const otherColorDark = options?.otherColorDark ?? 0xff7c8796;
  const otherColorLight = options?.otherColorLight ?? 0xff606a74;

  const validTotals = categoryTotals.filter((c) => c.amount > 0);
  if (validTotals.length === 0) return [];

  // Sort descending by amount
  validTotals.sort((a, b) => b.amount - a.amount);

  const totalSum = validTotals.reduce((sum, c) => sum + c.amount, 0);
  if (totalSum <= 0) return [];

  const baseSegments: CategoryArcSegment[] = [];

  if (validTotals.length <= 5) {
    for (const ct of validTotals) {
      baseSegments.push({
        id: ct.id,
        name: ct.name,
        amount: ct.amount,
        percentage: 0,
        colorDark: ct.colorDark,
        colorLight: ct.colorLight,
        isOther: false,
      });
    }
  } else {
    for (let i = 0; i < 4; i++) {
      const ct = validTotals[i];
      baseSegments.push({
        id: ct.id,
        name: ct.name,
        amount: ct.amount,
        percentage: 0,
        colorDark: ct.colorDark,
        colorLight: ct.colorLight,
        isOther: false,
      });
    }

    let otherSum = 0;
    for (let i = 4; i < validTotals.length; i++) {
      otherSum += validTotals[i].amount;
    }

    if (otherSum > 0) {
      baseSegments.push({
        id: 'other',
        name: 'Otros',
        amount: otherSum,
        percentage: 0,
        colorDark: otherColorDark,
        colorLight: otherColorLight,
        isOther: true,
      });
    }
  }

  if (baseSegments.length === 0) return [];

  // Largest Remainder Method
  const floors: number[] = [];
  const remainders: number[] = [];
  let assignedSum = 0;

  for (const seg of baseSegments) {
    const exact = (seg.amount * 100.0) / totalSum;
    const f = Math.floor(exact);
    floors.push(f);
    remainders.push(exact - f);
    assignedSum += f;
  }

  const diff = 100 - assignedSum;
  const indices = Array.from({ length: baseSegments.length }, (_, i) => i);
  indices.sort((a, b) => {
    const cmp = remainders[b] - remainders[a];
    if (Math.abs(cmp) > 1e-9) return cmp;
    return baseSegments[b].amount - baseSegments[a].amount;
  });

  const finalPercentages = [...floors];
  for (let i = 0; i < diff && i < indices.length; i++) {
    finalPercentages[indices[i]] += 1;
  }

  return baseSegments.map((seg, i) => ({
    ...seg,
    percentage: finalPercentages[i],
  }));
}
