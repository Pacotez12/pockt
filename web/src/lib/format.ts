/**
 * Formats an amount in Paraguayan Guaraníes (PYG).
 * Matches the mobile app behavior (`lib/core/format/money.dart`):
 * - No decimals
 * - Dots as thousands separator
 * - Currency prefix "Gs. " or "−Gs. " (using unicode minus U+2212)
 */

export interface FormatGsOptions {
  symbol?: boolean;
  explicitSign?: boolean;
}

export function formatThousands(value: number): string {
  const str = Math.abs(Math.trunc(value)).toString();
  const parts: string[] = [];
  const len = str.length;
  for (let i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 === 0) {
      parts.push('.');
    }
    parts.push(str[i]);
  }
  return parts.join('');
}

export function formatGs(amount: number, options: FormatGsOptions = {}): string {
  const { symbol = true, explicitSign = false } = options;
  const isNegative = amount < 0;
  const isPositive = amount > 0;

  let signPrefix = '';
  if (isNegative) {
    signPrefix = '−';
  } else if (explicitSign && isPositive) {
    signPrefix = '+';
  }

  const formatted = formatThousands(amount);
  if (symbol) {
    return `${signPrefix}Gs. ${formatted}`;
  }
  return `${signPrefix}${formatted}`;
}
