#!/usr/bin/env bash
# Roda as migrations e os testes de banco num Postgres descartável.
#
#   tests/db/run.sh                 # sobe um Postgres temporário local (precisa de initdb/pg_ctl)
#   PGURL=postgres://... tests/db/run.sh   # usa um banco vazio já existente (o CI faz assim)
#
# Sai com código diferente de zero no primeiro teste que falhar.
set -euo pipefail

raiz="$(cd "$(dirname "$0")/../.." && pwd)"
dir_testes="$raiz/tests/db"

if [[ -z "${PGURL:-}" ]]; then
  bin="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)"
  [[ -x "$bin/initdb" ]] || { echo "initdb não encontrado; defina PGURL"; exit 2; }
  tmp="$(mktemp -d)"
  trap '"$bin/pg_ctl" -D "$tmp/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
  dono=postgres
  if [[ "$(id -u)" == 0 ]]; then
    chown -R nobody "$tmp" 2>/dev/null || true
    roda() { su -s /bin/bash nobody -c "$*"; }
  else
    roda() { bash -c "$*"; }
  fi
  roda "'$bin/initdb' -D '$tmp/data' -U $dono -A trust >/dev/null"
  roda "'$bin/pg_ctl' -D '$tmp/data' -o '-p 54329 -k $tmp -c listen_addresses=' -l '$tmp/log' -w start >/dev/null"
  PGURL="postgresql://$dono@/postgres?host=$tmp&port=54329"
fi

psql_() { psql "$PGURL" -X -q -v ON_ERROR_STOP=1 "$@"; }

psql_ -f "$dir_testes/supabase_stub.sql"
for m in "$raiz"/supabase/migrations/*.sql; do
  echo "migration: $(basename "$m")"
  psql_ -f "$m"
done
for t in "$dir_testes"/test_*.sql; do
  echo "teste: $(basename "$t")"
  psql_ -o /dev/null -f "$t"
done
echo "OK: todos os testes de banco passaram"
