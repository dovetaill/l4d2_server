#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/server"

PORT="${PORT:-27015}"
MAP="${MAP:-c1m1_hotel}"
TICKRATE="${TICKRATE:-30}"

exec ./srcds_run \
  -game left4dead2 \
  -console \
  -usercon \
  -port "$PORT" \
  -tickrate "$TICKRATE" \
  +sv_setmax 31 \
  -maxplayers 31 \
  +map "$MAP"
