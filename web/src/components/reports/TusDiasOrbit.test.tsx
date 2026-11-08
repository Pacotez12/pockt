import React from 'react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';

vi.mock('three', async (importOriginal) => {
  const actual = await importOriginal<typeof import('three')>();
  class MockWebGLRenderer {
    domElement: HTMLCanvasElement;
    constructor({ canvas }: { canvas?: HTMLCanvasElement } = {}) {
      this.domElement = canvas || document.createElement('canvas');
    }
    setPixelRatio = vi.fn();
    setSize = vi.fn();
    render = vi.fn();
    dispose = vi.fn();
  }
  return {
    ...actual,
    WebGLRenderer: MockWebGLRenderer,
  };
});

import { TusDias } from './TusDias';

describe('TusDias 3D Orbit & Accessibility', () => {
  beforeEach(() => {
    (window as any).WebGLRenderingContext = vi.fn();
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue({} as any);
  });

  afterEach(() => {
    delete (window as any).WebGLRenderingContext;
    vi.restoreAllMocks();
  });

  it('renders 3D canvas with accessibility attributes and interactive keyboard controls', () => {
    const days = [
      { date: new Date(2026, 10, 10), amount: 50000, txCount: 1 },
    ];

    render(<TusDias days={days} initialMode="3d" />);

    const canvas = screen.getByTestId('tus-dias-3d-canvas');
    expect(canvas).toBeInTheDocument();
    expect(canvas).toHaveAttribute('tabIndex', '0');
    expect(canvas).toHaveAttribute('role', 'region');
    expect(canvas).toHaveAttribute('aria-label');
    expect(canvas.getAttribute('aria-label')).toContain('flechas para rotar');
    expect(canvas).toHaveClass('touch-pan-y');

    // Keyboard navigation controls
    fireEvent.keyDown(canvas, { key: 'ArrowLeft' });
    fireEvent.keyDown(canvas, { key: 'ArrowRight' });
    fireEvent.keyDown(canvas, { key: 'ArrowUp' });
    fireEvent.keyDown(canvas, { key: 'ArrowDown' });
    fireEvent.keyDown(canvas, { key: '+' });
    fireEvent.keyDown(canvas, { key: '-' });
    fireEvent.keyDown(canvas, { key: '0' });
  });

  it('shows hint when wheel is used without Ctrl and zooms with Ctrl', () => {
    const days = [
      { date: new Date(2026, 10, 10), amount: 50000, txCount: 1 },
    ];

    render(<TusDias days={days} initialMode="3d" />);

    const canvas = screen.getByTestId('tus-dias-3d-canvas');

    // Normal wheel scroll (no Ctrl) shows hint
    fireEvent.wheel(canvas, { deltaY: 100, ctrlKey: false, metaKey: false });
    expect(screen.getByTestId('tus-dias-wheel-hint')).toBeInTheDocument();
    expect(screen.getByText('Usá Ctrl + rueda para acercar')).toBeInTheDocument();

    // Wheel with Ctrl zooms and prevents default
    const wheelEvent = new WheelEvent('wheel', { deltaY: -100, ctrlKey: true, cancelable: true });
    const prevented = !canvas.dispatchEvent(wheelEvent);
    expect(prevented).toBe(true);
  });
});
