import React from 'react';

export function RouteSpinner() {
  return (
    <div
      data-testid="route-loading"
      className="min-h-[50vh] flex items-center justify-center p-6 text-text-tertiary"
    >
      <div className="w-8 h-8 rounded-full border-2 border-glass-border border-t-brand-start animate-spin" />
    </div>
  );
}
