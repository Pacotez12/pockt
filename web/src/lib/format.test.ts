import { describe, it, expect } from 'vitest';
import { formatGs } from './format';

describe('formatGs', () => {
  it('formats positive amounts without decimals and with dot thousands separator', () => {
    expect(formatGs(1234567)).toBe('Gs. 1.234.567');
    expect(formatGs(0)).toBe('Gs. 0');
    expect(formatGs(15000)).toBe('Gs. 15.000');
    expect(formatGs(500)).toBe('Gs. 500');
  });

  it('formats negative amounts with unicode minus', () => {
    expect(formatGs(-1234567)).toBe('−Gs. 1.234.567');
    expect(formatGs(-15000)).toBe('−Gs. 15.000');
  });

  it('supports omitting the currency symbol', () => {
    expect(formatGs(1234567, { symbol: false })).toBe('1.234.567');
    expect(formatGs(-1234567, { symbol: false })).toBe('−1.234.567');
  });

  it('supports explicit sign for transactions (+ / −)', () => {
    expect(formatGs(15000, { explicitSign: true })).toBe('+Gs. 15.000');
    expect(formatGs(-15000, { explicitSign: true })).toBe('−Gs. 15.000');
    expect(formatGs(0, { explicitSign: true })).toBe('Gs. 0');
  });
});
