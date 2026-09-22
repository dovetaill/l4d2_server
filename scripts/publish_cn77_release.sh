#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="${L4D2_RELEASE_DIR:-/var/lib/l4d2-release}"

"${ROOT_DIR}/scripts/build_cn77_release.sh" "$@"

if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    install -d -m 0755 "${RELEASE_DIR}" /opt/l4d2/scripts
    install -m 0755 "${ROOT_DIR}/scripts/serve_cn77_release.sh" /opt/l4d2/scripts/serve_cn77_release.sh
    install -m 0755 "${ROOT_DIR}/scripts/l4d2ctl.sh" /opt/l4d2/scripts/l4d2ctl.sh
    install -m 0755 "${ROOT_DIR}/scripts/update_steamcmd.sh" /opt/l4d2/scripts/update_steamcmd.sh
    install -m 0755 "${ROOT_DIR}/scripts/release_http_server.py" /opt/l4d2/scripts/release_http_server.py
    install -m 0644 "${ROOT_DIR}/systemd/l4d2-cn77-release.service" /etc/systemd/system/l4d2-cn77-release.service
    install -m 0644 "${ROOT_DIR}/systemd/l4d2-steam-update.service" /etc/systemd/system/l4d2-steam-update.service
    install -m 0644 "${ROOT_DIR}/systemd/l4d2-steam-update.timer" /etc/systemd/system/l4d2-steam-update.timer
    systemctl daemon-reload
    systemctl enable l4d2.service
    systemctl enable --now l4d2-cn77-release.service
    systemctl enable --now l4d2-steam-update.timer
    systemctl enable --now l4d2-web-admin.service || printf '[cn77-publish] WARNING: 网页运维服务未能启动。\n' >&2
    systemctl restart l4d2-cn77-release.service
    printf '[cn77-publish] 发布服务已启动：http://66.45.226.118:27816/\n'
else
    printf '[cn77-publish] systemd 不可用；可手动运行 scripts/serve_cn77_release.sh\n' >&2
fi
