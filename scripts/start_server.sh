#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_DIR="${ROOT_DIR}/server"

PORT="${PORT:-27015}"
MAP="${MAP:-c1m1_hotel}"
TICKRATE="${TICKRATE:-30}"

EXTRA_ARGS=()

if [[ -n "${GSLT:-}" ]]; then
    EXTRA_ARGS+=(+sv_setsteamaccount "$GSLT")
fi

cd "$SERVER_DIR"

exec ./srcds_run \
    -game left4dead2 \
    -console \
    -usercon \
    -port "$PORT" \
    -tickrate "$TICKRATE" \
    -maxplayers 31 \
    +sv_setmax 31 \
    "${EXTRA_ARGS[@]}" \
    +map "$MAP"
