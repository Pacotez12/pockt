#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ -f .env ]]; then source .env; fi
PS_HOST_PORT=${PS_HOST_PORT:-18080}
curl --fail --silent --show-error --max-time 5 "http://localhost:${PS_HOST_PORT}/probes/liveness" >/dev/null || { echo "FAIL: PowerSync no responde en localhost:${PS_HOST_PORT}"; exit 1; }
echo 'PASS: PowerSync liveness'
# psql del contenedor: no requiere instalar un cliente en el host.
result=$(docker exec supabase_db_pockt-spike psql -U postgres -d postgres -Atqc "SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.spike_tx')")
[[ "$result" == t ]] || { echo 'FAIL: spike_tx no existe o no tiene RLS'; exit 1; }
echo 'PASS: public.spike_tx existe con RLS activa'
