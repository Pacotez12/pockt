import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import React from 'react';
import { SyncStatusView } from './SyncStatus';

describe('SyncStatusView', () => {
  it('renders "Sincronizado" when connected and not uploading', () => {
    render(
      <SyncStatusView
        status={{
          connected: true,
          dataFlowStatus: { uploading: false },
          hasSynced: true,
        }}
      />
    );

    expect(screen.getByText('Sincronizado')).toBeInTheDocument();
    const dot = screen.getByTestId('sync-dot');
    expect(dot).toHaveClass('bg-positive');
  });

  it('renders "Subiendo" when actively uploading changes', () => {
    render(
      <SyncStatusView
        status={{
          connected: true,
          dataFlowStatus: { uploading: true },
          hasSynced: true,
        }}
      />
    );

    expect(screen.getByText('Subiendo')).toBeInTheDocument();
    const dot = screen.getByTestId('sync-dot');
    expect(dot).toHaveClass('bg-warning');
  });

  it('renders "Sin conexión" with offline explanation tooltip when disconnected', () => {
    render(
      <SyncStatusView
        status={{
          connected: false,
          dataFlowStatus: { uploading: false },
          hasSynced: false,
        }}
      />
    );

    expect(screen.getByText('Sin conexión')).toBeInTheDocument();
    const container = screen.getByTitle('Sin conexión, los cambios se guardan y se suben al volver');
    expect(container).toBeInTheDocument();
  });
});
