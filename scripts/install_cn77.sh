#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

RELEASE_BASE_URL="${L4D2_RELEASE_BASE_URL:-http://38.147.191.100}"
RELEASE_NAME="${L4D2_RELEASE_NAME:-l4d2-cn77-release.zip}"
TARGET_ROOT="${L4D2_TARGET_ROOT:-/opt/l4d2}"
ETC_ROOT="${L4D2_ETC_ROOT:-/etc/l4d2}"
DOWNLOAD_CACHE_DIR="${L4D2_DOWNLOAD_CACHE_DIR:-/var/cache/l4d2}"
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
    local candidate endpoint

    is_ipv4() {
        local value="$1" octet
        local -a octets
        [[ "${value}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
        IFS=. read -r -a octets <<<"${value}"
        for octet in "${octets[@]}"; do
            (( 10#${octet} <= 255 )) || return 1
        done
    }

    is_public_ipv4() {
        local value="$1" a b c d
        is_ipv4 "${value}" || return 1
        IFS=. read -r a b c d <<<"${value}"
        (( a != 0 && a != 10 && a != 127 )) || return 1
        (( !(a == 100 && b >= 64 && b <= 127) )) || return 1
        (( !(a == 169 && b == 254) )) || return 1
        (( !(a == 172 && b >= 16 && b <= 31) )) || return 1
        (( !(a == 192 && b == 168) )) || return 1
        (( a < 224 )) || return 1
    }

    if [[ -n "${PUBLIC_IP}" ]]; then
        is_ipv4 "${PUBLIC_IP}" || die "L4D2_PUBLIC_IP 不是有效的 IPv4 地址：${PUBLIC_IP}"
        return
    fi

    for endpoint in http://ipv4.icanhazip.com http://ifconfig.me/ip; do
        candidate="$(curl -4 -fsS --connect-timeout 3 --max-time 5 "${endpoint}" 2>/dev/null | tr -d '[:space:]' || true)"
        if is_public_ipv4 "${candidate}"; then
            PUBLIC_IP="${candidate}"
            return
        fi
    done

    if command -v ip >/dev/null 2>&1; then
        candidate="$(ip route get 1.1.1.1 2>/dev/null | sed -n -E 's/.* src ([0-9.]+).*/\1/p' | head -n 1 || true)"
        if is_public_ipv4 "${candidate}"; then
            PUBLIC_IP="${candidate}"
        fi
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
    local partial="${archive}.part" partial_sha="${archive}.part.sha256" sha_tmp="${sha_file}.part"
    install -d -m 0700 "${DOWNLOAD_CACHE_DIR}"
    log "从 ${url} 下载已配置的插件与服务器配置。"

    # The checksum is tiny, but write it atomically so an interrupted update
    # never replaces a previously usable checksum with a truncated file.
    curl -fL --retry 5 --retry-delay 2 --connect-timeout 20 \
        "${url}.sha256" -o "${sha_tmp}"
    mv -f "${sha_tmp}" "${sha_file}"
    expected="$(awk 'NF && $1 !~ /^#/ {print tolower($1); exit}' "${sha_file}")"
    [[ "${expected}" =~ ^[0-9a-f]{64}$ ]] || die '发布端 .sha256 文件格式错误'

    if [[ -f "${archive}" ]]; then
        actual="$(sha256sum "${archive}" | awk '{print tolower($1)}')"
        if [[ "${actual}" == "${expected}" ]]; then
            log "发现已校验的本地发布包，跳过重复下载：${archive}"
            log "发布包校验通过：${actual}"
            return
        fi
        warn "本地发布包校验不匹配，保留旧文件并重新下载。"
        mv -f "${archive}" "${archive}.invalid.$(date +%s).$$"
    fi

    if [[ -s "${partial}" ]] && [[ ! -f "${partial_sha}" || "$(<"${partial_sha}")" != "${expected}" ]]; then
        warn "未完成下载属于旧版本或缺少版本标记，已隔离后重新下载。"
        mv -f "${partial}" "${partial}.invalid.$(date +%s).$$"
    fi
    printf '%s\n' "${expected}" >"${partial_sha}"
    if [[ -s "${partial}" ]]; then
        log "发现未完成的下载，继续传输：$(du -h "${partial}" | awk '{print $1}')"
        curl -fL -C - --retry 5 --retry-delay 2 --connect-timeout 20 \
            "${url}" -o "${partial}"
    else
        curl -fL --retry 5 --retry-delay 2 --connect-timeout 20 \
            "${url}" -o "${partial}"
    fi
    actual="$(sha256sum "${partial}" | awk '{print tolower($1)}')"
    if [[ "${actual}" != "${expected}" ]]; then
        mv -f "${partial}" "${partial}.invalid.$(date +%s).$$"
        die "发布包 SHA-256 校验失败，错误文件已隔离：${actual} != ${expected}"
    fi
    mv -f "${partial}" "${archive}"
    unlink "${partial_sha}" 2>/dev/null || true
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
    install -d -m 0700 "${DOWNLOAD_CACHE_DIR}"
    TEMP_DIR="$(mktemp -d /tmp/l4d2-cn77-install.XXXXXX)"
    archive="${DOWNLOAD_CACHE_DIR}/${RELEASE_NAME}"
    download_release "${archive}" "${DOWNLOAD_CACHE_DIR}/${RELEASE_NAME}.sha256"
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
    WEB_BIND="${WEB_BIND:-0.0.0.0}" \
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
