#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_ROOT="${L4D2_RUNTIME_ROOT:-/opt/l4d2}"
RELEASE_DIR="${L4D2_RELEASE_DIR:-/var/lib/l4d2-release}"
RELEASE_NAME="${L4D2_RELEASE_NAME:-l4d2-cn77-release.zip}"
RELEASE_VERSION="${L4D2_RELEASE_VERSION:-$(date -u +%Y%m%d.%H%M)}"
RELEASE_PASSWORD_FILE="${L4D2_RELEASE_PASSWORD_FILE:-/etc/l4d2/release_password}"
RELEASE_PASSWORD="${L4D2_RELEASE_ZIP_PASSWORD:-}"
TEMP_DIR=""

log() { printf '[cn77-build] %s\n' "$*"; }
die() { printf '[cn77-build] ERROR: %s\n' "$*" >&2; exit 1; }

load_release_password() {
    if [[ -z "${RELEASE_PASSWORD}" && -r "${RELEASE_PASSWORD_FILE}" ]]; then
        RELEASE_PASSWORD="$(<"${RELEASE_PASSWORD_FILE}")"
    fi
    [[ "${RELEASE_PASSWORD}" =~ ^[A-Za-z0-9]{8,128}$ ]] || die \
        "缺少有效的 ZIP 密码；请将仅含字母数字的密码写入 ${RELEASE_PASSWORD_FILE}，或设置 L4D2_RELEASE_ZIP_PASSWORD。"
}

cleanup() {
    local status=$?
    if [[ -n "${TEMP_DIR}" && -d "${TEMP_DIR}" ]]; then
        find "${TEMP_DIR}" -depth -delete || printf '[cn77-build] WARNING: 临时目录未能完全清理：%s\n' "${TEMP_DIR}" >&2
    fi
    return "${status}"
}
trap cleanup EXIT

[[ "${EUID}" -eq 0 ]] || die '构建发布包需要 root，以便读取 /opt/l4d2 的已安装运行时。'
[[ -d "${RUNTIME_ROOT}/server/left4dead2" ]] || die "运行时不存在：${RUNTIME_ROOT}/server/left4dead2"
command -v rsync >/dev/null 2>&1 || die '缺少 rsync'
command -v zip >/dev/null 2>&1 || die '缺少 zip'
command -v sha256sum >/dev/null 2>&1 || die '缺少 sha256sum'
load_release_password

TEMP_DIR="$(mktemp -d /var/tmp/l4d2-cn77-release.XXXXXX)"
PACKAGE_DIR="${TEMP_DIR}/package"
ARCHIVE_PATH="${TEMP_DIR}/${RELEASE_NAME}"
mkdir -p "${PACKAGE_DIR}/server/left4dead2" "${PACKAGE_DIR}/scripts" "${PACKAGE_DIR}/systemd"

log '复制当前已运行的插件、SourceMod 运行时和公开配置。'
rsync -a \
    --exclude '/sourcemod/logs/' \
    --exclude '/sourcemod/data/sqlite/' \
    --exclude '/sourcemod/configs/admins_simple.ini' \
    --exclude '/sourcemod/configs/databases.cfg' \
    --exclude '*.log' \
    --exclude '*.sqlite' \
    --exclude '*.db' \
    "${RUNTIME_ROOT}/server/left4dead2/addons/" \
    "${PACKAGE_DIR}/server/left4dead2/addons/"
rsync -a \
    --exclude 'server_private.cfg' \
    --exclude '*.log' \
    "${RUNTIME_ROOT}/server/left4dead2/cfg/" \
    "${PACKAGE_DIR}/server/left4dead2/cfg/"
[[ ! -f "${RUNTIME_ROOT}/server/left4dead2/motd.txt" ]] || install -m 0644 "${RUNTIME_ROOT}/server/left4dead2/motd.txt" "${PACKAGE_DIR}/server/left4dead2/motd.txt"

# The live install contains compiled plugins, while the project tree owns the
# maintained SourcePawn sources. Overlay both so a target can compile safely.
if [[ -d "${ROOT_DIR}/server/left4dead2/cfg" ]]; then
    rsync -a --exclude 'server_private.cfg' \
        "${ROOT_DIR}/server/left4dead2/cfg/" \
        "${PACKAGE_DIR}/server/left4dead2/cfg/"
fi
if [[ -d "${ROOT_DIR}/server/left4dead2/cfg/sourcemod" ]]; then
    rsync -a "${ROOT_DIR}/server/left4dead2/cfg/sourcemod/" \
        "${PACKAGE_DIR}/server/left4dead2/cfg/sourcemod/"
fi
if [[ -d "${ROOT_DIR}/server/left4dead2/addons/sourcemod/configs" ]]; then
    rsync -a \
        --exclude 'admins_simple.ini' \
        --exclude 'databases.cfg' \
        "${ROOT_DIR}/server/left4dead2/addons/sourcemod/configs/" \
        "${PACKAGE_DIR}/server/left4dead2/addons/sourcemod/configs/"
fi
if [[ -d "${ROOT_DIR}/server/left4dead2/addons/sourcemod/data" ]]; then
    rsync -a --exclude '/sqlite/' \
        "${ROOT_DIR}/server/left4dead2/addons/sourcemod/data/" \
        "${PACKAGE_DIR}/server/left4dead2/addons/sourcemod/data/"
fi
if [[ -f "${ROOT_DIR}/server/left4dead2/motd.txt" ]]; then
    install -m 0644 "${ROOT_DIR}/server/left4dead2/motd.txt" "${PACKAGE_DIR}/server/left4dead2/motd.txt"
fi
if [[ -d "${ROOT_DIR}/server/left4dead2/addons/sourcemod/scripting" ]]; then
    rsync -a --exclude '/compiled/' \
        "${ROOT_DIR}/server/left4dead2/addons/sourcemod/scripting/" \
        "${PACKAGE_DIR}/server/left4dead2/addons/sourcemod/scripting/"
fi
if [[ -d "${ROOT_DIR}/server/left4dead2/addons/sourcemod/gamedata" ]]; then
    rsync -a "${ROOT_DIR}/server/left4dead2/addons/sourcemod/gamedata/" \
        "${PACKAGE_DIR}/server/left4dead2/addons/sourcemod/gamedata/"
fi
for source in \
    l4d2_campaign_shop.sp l4d2_automatic_weapons.sp l4d2_unicode_hostname.sp \
    l4d2_clear_thirdstrike.sp l4d2_combat_rewards.sp l4d2_incap_support.sp \
    l4d2_end_safearea_teleport.sp l4d2_pve_admin.sp l4d2_pve_help_menu.sp \
    l4d2_pve_infected_core.sp l4d2_pve_damage_display.sp l4d2_playable_witch.sp \
    l4d2_pve_mutant_tanks.sp l4d2_switch_upgrade_ammo.sp; do
    [[ -f "${PACKAGE_DIR}/server/left4dead2/addons/sourcemod/scripting/${source}" ]] || die "SourcePawn 源码缺失：${source}"
done
for source in third_party/dual_primaries.sp third_party/l4d2_double_jump.sp \
    third_party/miuwiki_autoscar.sp third_party/command_buffer.sp; do
    [[ -f "${PACKAGE_DIR}/server/left4dead2/addons/sourcemod/scripting/${source}" ]] || die "第三方 SourcePawn 源码缺失：${source}"
done

# The package is portable. The installer writes the target machine's public
# address so the 66 release host is never advertised by a mainland server.
if [[ -f "${PACKAGE_DIR}/server/left4dead2/cfg/server.cfg" ]]; then
    sed -i -E '/^[[:space:]]*net_public_adr[[:space:]]/d' "${PACKAGE_DIR}/server/left4dead2/cfg/server.cfg"
fi

for file in \
    scripts/bootstrap_l4d2.sh \
    scripts/l4d2_artifact_manifest.sh \
    scripts/start_server.sh \
    scripts/l4d2ctl.sh \
    scripts/l4d2_web_admin.py \
    scripts/install_cn77.sh \
    scripts/update_steamcmd.sh \
    scripts/serve_cn77_release.sh \
    scripts/release_http_server.py \
    scripts/build_cn77_release.sh \
    scripts/publish_cn77_release.sh; do
    [[ -f "${ROOT_DIR}/${file}" ]] || die "发布脚本缺失：${ROOT_DIR}/${file}"
    install -D -m 0755 "${ROOT_DIR}/${file}" "${PACKAGE_DIR}/${file}"
done
for file in \
    systemd/l4d2-steam-update.service \
    systemd/l4d2-steam-update.timer \
    systemd/l4d2-cn77-release.service; do
    [[ -f "${ROOT_DIR}/${file}" ]] || die "systemd 文件缺失：${ROOT_DIR}/${file}"
    install -D -m 0644 "${ROOT_DIR}/${file}" "${PACKAGE_DIR}/${file}"
done

cat >"${PACKAGE_DIR}/CN77-RELEASE.txt" <<EOF
CN77 L4D2 release
Version: ${RELEASE_VERSION}
Built-UTC: $(date -u '+%Y-%m-%dT%H:%M:%SZ')

This archive contains the current compiled SourceMod runtime, plugins, public
configuration, SourcePawn sources included in the runtime, and operations
scripts. It intentionally excludes the Steam game files, server_private.cfg,
RCON credentials, GSLT, web-admin credentials, database files, and logs.
The ZIP payload is password protected. The installer asks for the password
and stores a mode-600 copy at /etc/l4d2/release_password for later updates.

Install from the 66 release host:
  sudo bash install_cn77.sh

After installation:
  sudo /opt/l4d2/scripts/l4d2ctl.sh status
  sudo /opt/l4d2/scripts/l4d2ctl.sh health
  sudo /opt/l4d2/scripts/l4d2ctl.sh update
  sudo /opt/l4d2/scripts/l4d2ctl.sh game-update

The game update timer checks AppID 222860 every 6 hours. It stops the game
for the check and starts it again when the check completes.
EOF

if find "${PACKAGE_DIR}" \( -name server_private.cfg -o -name admins_simple.ini -o -name databases.cfg \) -print -quit | grep -q .; then
    die '检测到不应发布的私密/本机配置文件，停止打包。'
fi
if grep -R -n -E '^[[:space:]]*rcon_password[[:space:]]+"|^WEB_PASSWORD=' "${PACKAGE_DIR}" >/dev/null 2>&1; then
    die '检测到 RCON 或网页密码内容，停止打包。'
fi

log '压缩并使用 ZIP 密码保护发布包。'
(cd "${PACKAGE_DIR}" && zip -q -9 -r -P "${RELEASE_PASSWORD}" "${ARCHIVE_PATH}" .)
(cd "${TEMP_DIR}" && sha256sum "${RELEASE_NAME}") >"${ARCHIVE_PATH}.sha256"

install -d -m 0755 "${RELEASE_DIR}"
install -m 0644 "${ARCHIVE_PATH}" "${RELEASE_DIR}/${RELEASE_NAME}"
install -m 0644 "${ARCHIVE_PATH}.sha256" "${RELEASE_DIR}/${RELEASE_NAME}.sha256"
install -m 0755 "${ROOT_DIR}/scripts/install_cn77.sh" "${RELEASE_DIR}/install-cn77.sh"
install -m 0644 "${PACKAGE_DIR}/CN77-RELEASE.txt" "${RELEASE_DIR}/CN77-RELEASE.txt"
if id l4d2srv >/dev/null 2>&1; then
    chown -R l4d2srv:l4d2srv "${RELEASE_DIR}"
    chmod 0755 "${RELEASE_DIR}"
    chmod 0644 "${RELEASE_DIR}/${RELEASE_NAME}" "${RELEASE_DIR}/${RELEASE_NAME}.sha256" "${RELEASE_DIR}/CN77-RELEASE.txt"
    chmod 0755 "${RELEASE_DIR}/install-cn77.sh"
fi

log "发布包：${RELEASE_DIR}/${RELEASE_NAME}"
log "校验文件：${RELEASE_DIR}/${RELEASE_NAME}.sha256"
log "版本：${RELEASE_VERSION}"
du -h "${RELEASE_DIR}/${RELEASE_NAME}"
