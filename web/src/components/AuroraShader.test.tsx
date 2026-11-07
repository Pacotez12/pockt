import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import React from 'react';
import { AuroraShader } from './AuroraShader';
import { ThemeContext } from '@/lib/theme';

describe('AuroraShader', () => {
  it('renders canvas element without throwing even if WebGL is unavailable in test environment', () => {
    const { container } = render(<AuroraShader opacity={0.5} />);
    const canvas = container.querySelector('canvas');
    expect(canvas).not.toBeNull();
  });

  it('adapts to light mode by using light background and removing dark vignette', () => {
    const { container } = render(
      <ThemeContext.Provider
        value={{
          theme: 'light',
          resolvedTheme: 'light',
          setTheme: () => {},
        }}
      >
        <AuroraShader opacity={0.5} />
      </ThemeContext.Provider>
    );

    const canvas = container.querySelector('canvas');
    expect(canvas?.style.background).toBe('rgb(247, 247, 248)');

    const vignette = screen.getByTestId('aurora-vignette');
    expect(vignette.getAttribute('style')).toContain('background: none');
  });
});
