#!/usr/bin/env bash

set -Eeuo pipefail

RELEASE_DIR="${L4D2_RELEASE_DIR:-/var/lib/l4d2-release}"
BIND_ADDRESS="${L4D2_RELEASE_BIND:-66.45.226.118}"
PORT="${L4D2_RELEASE_PORT:-27816}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_SCRIPT="${SCRIPT_DIR}/release_http_server.py"

[[ -d "${RELEASE_DIR}" ]] || { printf 'release directory does not exist: %s\n' "${RELEASE_DIR}" >&2; exit 1; }
[[ "${PORT}" =~ ^[0-9]+$ && "${PORT}" -ge 1 && "${PORT}" -le 65535 ]] || { printf 'invalid release port: %s\n' "${PORT}" >&2; exit 1; }
[[ -f "${SERVER_SCRIPT}" ]] || { printf 'release HTTP server is missing: %s\n' "${SERVER_SCRIPT}" >&2; exit 1; }

exec /usr/bin/python3 "${SERVER_SCRIPT}" \
    --port "${PORT}" \
    --bind "${BIND_ADDRESS}" \
    --directory "${RELEASE_DIR}"
