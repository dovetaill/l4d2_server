#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

TARGET_ROOT="${L4D2_TARGET_ROOT:-/opt/l4d2}"
STEAMCMD="${L4D2_STEAMCMD:-${TARGET_ROOT}/steamcmd/steamcmd.sh}"
SERVER_DIR="${L4D2_SERVER_DIR:-${TARGET_ROOT}/server}"
SERVICE_USER="${L4D2_SERVICE_USER:-l4d2srv}"
LOCK_FILE="${L4D2_STEAM_UPDATE_LOCK:-/run/l4d2-steam-update.lock}"

log() { printf '[steam-update] %s\n' "$*"; }
die() { printf '[steam-update] ERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -eq 0 ]] || die '必须使用 root 运行。'
[[ -x "${STEAMCMD}" ]] || die "找不到 SteamCMD：${STEAMCMD}"
[[ -d "${SERVER_DIR}" ]] || die "找不到游戏目录：${SERVER_DIR}"
command -v flock >/dev/null 2>&1 || die '缺少 flock。'
command -v runuser >/dev/null 2>&1 || die '缺少 runuser。'

exec 9>"${LOCK_FILE}"
flock -n 9 || die '已有另一个 SteamCMD 更新任务在运行。'

was_active=0
web_was_active=0
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet l4d2-web-admin.service; then
    web_was_active=1
fi
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet l4d2.service; then
    was_active=1
    log '停止 L4D2 服务后更新游戏文件。'
    systemctl stop l4d2.service
fi

restart_server() {
    if (( was_active == 1 )); then
        log 'SteamCMD 更新结束，重新启动 L4D2 服务。'
        systemctl start l4d2.service || printf '[steam-update] WARNING: L4D2 服务重启失败。\n' >&2
        if (( web_was_active == 1 )); then
            systemctl start l4d2-web-admin.service || printf '[steam-update] WARNING: 网页运维服务重启失败。\n' >&2
        fi
    fi
}
trap restart_server EXIT

log '检查/更新 Dedicated Server AppID 222860。'
runuser -u "${SERVICE_USER}" -- \
    "${STEAMCMD}" \
    +force_install_dir "${SERVER_DIR}" \
    +login anonymous \
    +app_update 222860 \
    +quit
log 'SteamCMD 更新完成。'
