#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

RELEASE_BASE_URL="${L4D2_RELEASE_BASE_URL:-http://66.45.226.118:27816}"
RELEASE_NAME="${L4D2_RELEASE_NAME:-l4d2-cn77-release.zip}"
TARGET_ROOT="${L4D2_TARGET_ROOT:-/opt/l4d2}"
ETC_ROOT="${L4D2_ETC_ROOT:-/etc/l4d2}"
PUBLIC_IP="${L4D2_PUBLIC_IP:-}"
NO_START="${L4D2_NO_START:-0}"
TEMP_DIR=""

log() { printf '[cn77-install] %s\n' "$*"; }
warn() { printf '[cn77-install] WARNING: %s\n' "$*" >&2; }
die() { printf '[cn77-install] ERROR: %s\n' "$*" >&2; exit 1; }

cleanup() {
    local status=$?
    if [[ -n "${TEMP_DIR}" && -d "${TEMP_DIR}" ]]; then
        find "${TEMP_DIR}" -depth -delete || warn "临时目录未能完全清理：${TEMP_DIR}"
    fi
    return "${status}"
}
trap cleanup EXIT

[[ "${EUID}" -eq 0 ]] || die '请使用 root 运行：sudo bash install-cn77.sh'
[[ "${RELEASE_BASE_URL}" != */ ]] || RELEASE_BASE_URL="${RELEASE_BASE_URL%/}"

ensure_download_tools() {
    local missing=()
    command -v curl >/dev/null 2>&1 || missing+=(curl)
    command -v unzip >/dev/null 2>&1 || missing+=(unzip)
    command -v sha256sum >/dev/null 2>&1 || missing+=(coreutils)
    if (( ${#missing[@]} == 0 )); then
        return
    fi
    command -v apt-get >/dev/null 2>&1 || die "缺少下载工具：${missing[*]}，且系统没有 apt-get"
    log "安装发布包下载依赖：${missing[*]}"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates unzip coreutils
}

detect_public_ip() {
    [[ -n "${PUBLIC_IP}" ]] && return
    if command -v ip >/dev/null 2>&1; then
        PUBLIC_IP="$(ip route get 1.1.1.1 2>/dev/null | sed -n -E 's/.* src ([0-9.]+).*/\1/p' | head -n 1 || true)"
    fi
    if [[ -n "${PUBLIC_IP}" && ! "${PUBLIC_IP}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        PUBLIC_IP=""
    fi
}

rewrite_public_address() {
    local config="$1"
    [[ -f "${config}" ]] || return
    if [[ -n "${PUBLIC_IP}" ]]; then
        if grep -Eq '^[[:space:]]*net_public_adr[[:space:]]' "${config}"; then
            sed -i -E "s#^[[:space:]]*net_public_adr[[:space:]].*$#net_public_adr \"${PUBLIC_IP}\"#" "${config}"
        else
            printf '\nnet_public_adr "%s"\n' "${PUBLIC_IP}" >>"${config}"
        fi
        log "已将服务器公开地址设置为 ${PUBLIC_IP}"
    else
        sed -i -E '/^[[:space:]]*net_public_adr[[:space:]]/d' "${config}"
        warn '无法自动检测公网 IPv4；已删除 net_public_adr，请在 server.cfg 中按需填写。'
    fi
}

read_release_password() {
    local password="${L4D2_RELEASE_ZIP_PASSWORD:-}"
    if [[ -n "${password}" ]]; then
        printf '%s' "${password}"
        return
    fi
    if [[ -r /dev/tty ]]; then
        printf '请输入发布包 ZIP 解压密码： ' >/dev/tty
        IFS= read -r -s password </dev/tty || die '无法读取 ZIP 解压密码'
        printf '\n' >/dev/tty
    else
        die '当前不是交互终端；请设置 L4D2_RELEASE_ZIP_PASSWORD 后重试。'
    fi
    [[ "${password}" =~ ^[A-Za-z0-9]{8,128}$ ]] || die 'ZIP 解压密码必须为8-128位字母或数字'
    printf '%s' "${password}"
}

save_release_password() {
    local password="$1"
    install -d -m 0700 "${ETC_ROOT}"
    printf '%s\n' "${password}" | install -m 0600 /dev/stdin "${ETC_ROOT}/release_password"
}

download_release() {
    local archive="$1" sha_file="$2" url="${RELEASE_BASE_URL}/${RELEASE_NAME}" expected actual
    log "从 ${url} 下载已配置的插件与服务器配置。"
    curl -fL --retry 3 --retry-delay 1 --connect-timeout 20 "${url}" -o "${archive}"
    curl -fL --retry 3 --retry-delay 1 --connect-timeout 20 "${url}.sha256" -o "${sha_file}"
    expected="$(awk 'NF && $1 !~ /^#/ {print tolower($1); exit}' "${sha_file}")"
    [[ "${expected}" =~ ^[0-9a-f]{64}$ ]] || die '发布端 .sha256 文件格式错误'
    actual="$(sha256sum "${archive}" | awk '{print tolower($1)}')"
    [[ "${actual}" == "${expected}" ]] || die "发布包 SHA-256 校验失败：${actual} != ${expected}"
    log "发布包校验通过：${actual}"
}

install_update_units() {
    local source="$1"
    [[ "${L4D2_SKIP_UPDATE_TIMER:-0}" != "1" ]] || { log 'L4D2_SKIP_UPDATE_TIMER=1；跳过 SteamCMD 定时器安装。'; return; }
    [[ -f "${source}/systemd/l4d2-steam-update.service" ]] || return
    [[ -f "${source}/systemd/l4d2-steam-update.timer" ]] || return
    install -m 0644 "${source}/systemd/l4d2-steam-update.service" /etc/systemd/system/l4d2-steam-update.service
    install -m 0644 "${source}/systemd/l4d2-steam-update.timer" /etc/systemd/system/l4d2-steam-update.timer
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        systemctl daemon-reload
        systemctl enable --now l4d2-steam-update.timer
    fi
}

main() {
    local archive extracted source zip_password
    ensure_download_tools
    detect_public_ip
    TEMP_DIR="$(mktemp -d /tmp/l4d2-cn77-install.XXXXXX)"
    archive="${TEMP_DIR}/${RELEASE_NAME}"
    download_release "${archive}" "${archive}.sha256"
    extracted="${TEMP_DIR}/extracted"
    mkdir -p "${extracted}"
    zip_password="$(read_release_password)"
    unzip -q -P "${zip_password}" "${archive}" -d "${extracted}" || die 'ZIP 解压失败，请确认密码正确且发布包完整。'
    save_release_password "${zip_password}"
    source="$(find "${extracted}" -type f -path '*/scripts/bootstrap_l4d2.sh' -printf '%h/..\n' -quit)"
    [[ -n "${source}" ]] || die '发布包中缺少 scripts/bootstrap_l4d2.sh'
    source="$(cd "${source}" && pwd)"
    rewrite_public_address "${source}/server/left4dead2/cfg/server.cfg"

    log '开始处理依赖、SteamCMD、游戏文件、插件和配置。'
    L4D2_TARGET_ROOT="${TARGET_ROOT}" \
    L4D2_SOURCE_ROOT="${source}" \
    L4D2_SKIP_FRAMEWORKS=1 \
    "${source}/scripts/bootstrap_l4d2.sh" --update --no-start
    install_update_units "${source}"

    if [[ "${NO_START}" != "1" ]] && command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        systemctl restart l4d2.service
        systemctl restart l4d2-web-admin.service || warn '网页运维服务未能启动，请检查 systemctl status l4d2-web-admin。'
    else
        log 'L4D2_NO_START=1 或 systemd 不可用；未自动重启服务。'
    fi

    log '安装/更新完成。'
    log "游戏服务：systemctl status l4d2 --no-pager -l"
    log "运维脚本：${TARGET_ROOT}/scripts/l4d2ctl.sh status|health|restart|update|game-update"
    log "私密配置未打包，RCON/GSLT/网页密码保存在 ${ETC_ROOT}/。"
}

main "$@"
