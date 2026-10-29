import { expect, test } from 'vitest';
import { formatGs } from './format';

test('formatea guaraníes enteros con puntos de miles', () => {
  expect(formatGs(184000)).toBe('Gs. 184.000');
});
