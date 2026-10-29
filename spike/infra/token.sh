#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[[ $# == 1 && ( "$1" == a@test.local || "$1" == b@test.local ) ]] || { echo 'Uso: token.sh <a@test.local|b@test.local>' >&2; exit 2; }
# .env es configuración local de confianza; nunca se versiona.
source .env
: "${SUPABASE_ANON_KEY:?}" "${SUPABASE_SERVICE_ROLE_KEY:?}" "${SPIKE_TEST_PASSWORD:?}"
payload=$(jq -nc --arg email "$1" --arg password "$SPIKE_TEST_PASSWORD" '{email:$email,password:$password}')
login() {
  curl -fsS --max-time 10 http://localhost:54321/auth/v1/token?grant_type=password \
    -H "apikey: $SUPABASE_ANON_KEY" -H 'Content-Type: application/json' -d "$payload"
}
if ! session=$(login 2>/dev/null); then
  curl -fsS --max-time 10 http://localhost:54321/auth/v1/admin/users \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H 'Content-Type: application/json' \
    -d "$(jq -c '. + {email_confirm:true}' <<< "$payload")" >/dev/null
  session=$(login)
fi
jwt=$(jq -er '.access_token | select(type == "string" and length > 0)' <<< "$session")
# Auth verifica firma y vigencia; stdout contiene exclusivamente el JWT.
curl -fsS --max-time 10 http://localhost:54321/auth/v1/user \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $jwt" \
  | jq -e --arg email "$1" '.email == $email' >/dev/null
printf '%s\n' "$jwt"
