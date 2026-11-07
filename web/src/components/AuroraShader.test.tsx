import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import React from 'react';
import { AuroraShader } from './AuroraShader';

describe('AuroraShader', () => {
  it('renders canvas element without throwing even if WebGL is unavailable in test environment', () => {
    const { container } = render(<AuroraShader opacity={0.5} />);
    const canvas = container.querySelector('canvas');
    expect(canvas).not.toBeNull();
  });
});
