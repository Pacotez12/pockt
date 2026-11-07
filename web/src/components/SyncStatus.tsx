import React from 'react';
import { useStatus } from '@powersync/react';
import { cn } from '@/lib/utils';

export type SyncDisplayState = 'synced' | 'uploading' | 'offline';

export interface SyncStatusData {
  connected?: boolean;
  dataFlowStatus?: {
    uploading?: boolean;
    downloading?: boolean;
  };
  hasSynced?: boolean;
}

export function resolveSyncStatus(status?: SyncStatusData): {
  state: SyncDisplayState;
  label: string;
  tooltip: string;
} {
  if (!status || !status.connected) {
    return {
      state: 'offline',
      label: 'Sin conexión',
      tooltip: 'Sin conexión, los cambios se guardan y se suben al volver',
    };
  }

  if (status.dataFlowStatus?.uploading) {
    return {
      state: 'uploading',
      label: 'Subiendo',
      tooltip: 'Subiendo cambios al servidor…',
    };
  }

  return {
    state: 'synced',
    label: 'Sincronizado',
    tooltip: 'Tus datos están sincronizados con la nube',
  };
}

export function SyncStatusView({
  status,
  className,
}: {
  status?: SyncStatusData;
  className?: string;
}) {
  const { state, label, tooltip } = resolveSyncStatus(status);

  return (
    <div
      title={tooltip}
      aria-label={`${label}: ${tooltip}`}
      className={cn(
        'text-[12px] text-text-tertiary flex items-center gap-1.5 transition-all select-none cursor-default',
        className
      )}
    >
      <i
        data-testid="sync-dot"
        className={cn(
          'w-[7px] h-[7px] rounded-full shrink-0 transition-colors',
          state === 'synced' && 'bg-positive shadow-sm shadow-positive/30',
          state === 'uploading' && 'bg-warning animate-pulse shadow-sm shadow-warning/30',
          state === 'offline' && 'bg-text-tertiary/60'
        )}
      />
      <span className="truncate">{label}</span>
    </div>
  );
}

export function SyncStatus({ className }: { className?: string }) {
  let status: SyncStatusData | undefined;
  try {
    status = useStatus();
  } catch {
    // If used outside of PowerSyncContext (e.g. testing or disconnected), gracefully fallback
  }

  return <SyncStatusView status={status} className={className} />;
}
