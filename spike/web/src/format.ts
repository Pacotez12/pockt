const guaranies = new Intl.NumberFormat('es-PY', { maximumFractionDigits: 0 });

export function formatGs(amount: number): string {
  return `Gs. ${guaranies.format(amount)}`;
}
