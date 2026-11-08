import React, { useState } from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { useFocusTrap } from './useFocusTrap';

function TestModal({ onClose }: { onClose: () => void }) {
  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useFocusTrap<HTMLDivElement>(isOpen, () => {
    setIsOpen(false);
    onClose();
  });

  return (
    <div>
      <button id="open-btn" onClick={() => setIsOpen(true)}>
        Open Modal
      </button>

      {isOpen && (
        <div ref={containerRef} role="dialog" data-testid="dialog">
          <input data-testid="input-1" placeholder="First" />
          <input data-testid="input-2" placeholder="Second" />
          <button data-testid="close-btn" onClick={() => { setIsOpen(false); onClose(); }}>
            Close
          </button>
        </div>
      )}
    </div>
  );
}

describe('useFocusTrap', () => {
  it('traps focus inside the dialog when pressing Tab and Shift+Tab', async () => {
    const handleClose = vi.fn();
    render(<TestModal onClose={handleClose} />);

    const openBtn = screen.getByRole('button', { name: 'Open Modal' });
    openBtn.focus();
    expect(document.activeElement).toBe(openBtn);

    fireEvent.click(openBtn);

    const input1 = await screen.findByTestId('input-1');
    const closeBtn = screen.getByTestId('close-btn');

    // Wait for initial focus
    await new Promise((r) => setTimeout(r, 60));
    expect(document.activeElement).toBe(input1);

    // Tab from last element wraps to first
    closeBtn.focus();
    expect(document.activeElement).toBe(closeBtn);

    fireEvent.keyDown(window, { key: 'Tab', shiftKey: false });
    expect(document.activeElement).toBe(input1);

    // Shift+Tab from first element wraps to last
    fireEvent.keyDown(window, { key: 'Tab', shiftKey: true });
    expect(document.activeElement).toBe(closeBtn);
  });

  it('restores focus to trigger button when closed and handles Escape', async () => {
    const handleClose = vi.fn();
    render(<TestModal onClose={handleClose} />);

    const openBtn = screen.getByRole('button', { name: 'Open Modal' });
    openBtn.focus();
    fireEvent.click(openBtn);

    await screen.findByTestId('dialog');

    // Press Escape
    fireEvent.keyDown(window, { key: 'Escape' });
    expect(handleClose).toHaveBeenCalledTimes(1);

    // Focus restored to open button
    expect(document.activeElement).toBe(openBtn);
  });
});
