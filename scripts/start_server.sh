#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_DIR="${ROOT_DIR}/server"

PORT="${PORT:-27015}"
MAP="${MAP:-c1m1_hotel}"
TICKRATE="${TICKRATE:-30}"

# This L4D2 dedicated-server build does not expose sv_setsteamaccount.
# Keep GSLT in /etc/l4d2/l4d2.env for reference, but do not pass the
# unsupported command because it only produces a misleading startup error.

cd "$SERVER_DIR"

exec ./srcds_run \
    -game left4dead2 \
    -console \
    -usercon \
    -port "$PORT" \
    -tickrate "$TICKRATE" \
    -maxplayers 31 \
    +sv_setmax 31 \
    +map "$MAP"
