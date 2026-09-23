#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

TARGET_ROOT="${L4D2_TARGET_ROOT:-/opt/l4d2}"
SERVER_DIR="${TARGET_ROOT}/server"
GAME_DIR="${SERVER_DIR}/left4dead2"
STEAMCMD_DIR="${TARGET_ROOT}/steamcmd"
SERVICE_USER="${L4D2_SERVICE_USER:-l4d2srv}"
SERVICE_GROUP="${L4D2_SERVICE_GROUP:-l4d2srv}"
ETC_DIR="${L4D2_ETC_ROOT:-/etc/l4d2}"
GAME_ENV="${ETC_DIR}/l4d2.env"
WEB_ENV="${ETC_DIR}/l4d2-admin.env"
PRIVATE_CFG="${GAME_DIR}/cfg/server_private.cfg"
MM_VERSION="1.12.0-git1226"
SM_VERSION="1.12.0-git7253"
MM_URL="https://mms.alliedmods.net/mmsdrop/1.12/mmsource-${MM_VERSION}-linux.tar.gz"
SM_URL="https://www.sourcemod.net/smdrop/1.12/sourcemod-${SM_VERSION}-linux.tar.gz"
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"

UPDATE_ONLY=0
NO_START=0
SKIP_APT="${L4D2_SKIP_APT:-0}"
SKIP_STEAM="${L4D2_SKIP_STEAM:-0}"
SKIP_FRAMEWORKS="${L4D2_SKIP_FRAMEWORKS:-0}"
SKIP_PRIVATE_CONFIG="${L4D2_SKIP_PRIVATE_CONFIG:-0}"
SKIP_SERVICES="${L4D2_SKIP_SERVICES:-0}"
SOURCE_PUBLIC_ADDRESS_AUTHORITATIVE="${L4D2_SOURCE_PUBLIC_ADDRESS_AUTHORITATIVE:-0}"
DOWNLOAD_CACHE="${L4D2_DOWNLOAD_CACHE:-/var/cache/l4d2/artifacts}"
TEMP_DIR=""
PROJECT_ROOT="${L4D2_SOURCE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST_FILE="${PROJECT_ROOT}/scripts/l4d2_artifact_manifest.sh"
INSTANCE_IDENTITY_CAPTURED=0
INSTANCE_SERVER_HOSTNAME_FILE=""
INSTANCE_RUNTIME_HOSTNAME_FILE=""
INSTANCE_PUBLIC_ADDRESS_FILE=""
INSTANCE_DISPLAY_NAME_FILE=""

log() {
    printf '[bootstrap] %s\n' "$*"
}

warn() {
    printf '[bootstrap] WARNING: %s\n' "$*" >&2
}

die() {
    printf '[bootstrap] ERROR: %s\n' "$*" >&2
    exit 1
}

require_exec_mount() {
    local path="$1" mount_options
    mount_options="$(findmnt -no OPTIONS -T "$path" 2>/dev/null || true)"
    [[ ",${mount_options}," != *,noexec,* ]] || die "目标文件系统包含 noexec，无法执行 ${path}；请移除 /opt 对应挂载项的 noexec 后重试。挂载信息：${mount_options}"
}


load_manifest() {
    [[ -f "${MANIFEST_FILE}" ]] || die "Artifact manifest is missing: ${MANIFEST_FILE}"
    # shellcheck disable=SC1090
    source "${MANIFEST_FILE}"
    l4d2_manifest_validate || die "Artifact manifest validation failed."
}

download_artifact() {
    local key="$1" destination="$2" cache_file partial partial_sha actual expected
    [[ -n "${L4D2_ARTIFACT_URL[$key]:-}" ]] || die "Unknown artifact key: ${key}"
    cache_file="${DOWNLOAD_CACHE}/${L4D2_ARTIFACT_FILE[$key]}"
    partial="${cache_file}.part"
    partial_sha="${cache_file}.part.sha256"
    expected="${L4D2_ARTIFACT_SHA256[$key]}"
    install -d -m 0700 "${DOWNLOAD_CACHE}"
    if [[ -f "${cache_file}" ]]; then
        if printf '%s  %s\n' "${L4D2_ARTIFACT_SHA256[$key]}" "${cache_file}" | sha256sum -c - >/dev/null; then
            log "Using verified cache for ${key}."
            install -m 0644 "${cache_file}" "${destination}"
        else
            log "Cached ${key} failed verification; downloading a fresh copy."
            mv -f "${cache_file}" "${cache_file}.invalid.$(date +%s).$$"
        fi
    fi
    if [[ ! -f "${cache_file}" ]]; then
        log "Downloading ${L4D2_ARTIFACT_VERSION[$key]}."
        if [[ -s "${partial}" ]] && [[ ! -f "${partial_sha}" || "$(<"${partial_sha}")" != "${expected}" ]]; then
            log "Incomplete ${key} download belongs to another version; starting over."
            mv -f "${partial}" "${partial}.invalid.$(date +%s).$$"
        fi
        printf '%s\n' "${expected}" >"${partial_sha}"
        if [[ -s "${partial}" ]]; then
            log "Resuming incomplete ${key} download."
            curl -fL -C - --retry 5 --retry-delay 2 --connect-timeout 20 \
                "${L4D2_ARTIFACT_URL[$key]}" -o "${partial}"
        else
            curl -fL --retry 5 --retry-delay 2 --connect-timeout 20 \
                "${L4D2_ARTIFACT_URL[$key]}" -o "${partial}"
        fi
        actual="$(sha256sum "${partial}" | awk '{print tolower($1)}')"
        if [[ "${actual}" != "${expected}" ]]; then
            mv -f "${partial}" "${partial}.invalid.$(date +%s).$$"
            die "SHA-256 verification failed for ${key}; invalid file was quarantined."
        fi
        mv -f "${partial}" "${cache_file}"
        unlink "${partial_sha}" 2>/dev/null || true
        install -m 0644 "${cache_file}" "${destination}"
    elif [[ ! -f "${destination}" ]]; then
        install -m 0644 "${cache_file}" "${destination}"
    fi
    printf '%s  %s\n' "${L4D2_ARTIFACT_SHA256[$key]}" "${destination}" | sha256sum -c - >/dev/null \
        || die "SHA-256 verification failed for ${key}."
}

extract_tar_overlay() {
    local archive="$1" target="$2" key="$3" extract_root top
    extract_root="${TEMP_DIR}/extract-${key}"
    install -d "${extract_root}"
    tar -xzf "${archive}" -C "${extract_root}"
    top="$(find "${extract_root}" -mindepth 1 -maxdepth 1 -type d -print -quit)"
    [[ -n "${top}" ]] || die "Archive ${key} has no top-level directory."
    if [[ -d "${top}/addons" ]]; then
        rsync -a "${top}/addons/" "${GAME_DIR}/addons/"
    elif [[ -d "${top}/sourcemod" ]]; then
        rsync -a "${top}/sourcemod/" "${GAME_DIR}/addons/sourcemod/"
    else
        die "Archive ${key} has no supported SourceMod layout."
    fi
}

usage() {
    cat <<'EOF'
Usage: sudo ./scripts/bootstrap_l4d2.sh [--update] [--no-start]

  --update    Update an existing installation from this source tree or release
              archive. The installer never pulls or mutates a VCS checkout.
  --no-start  Install and compile without starting or restarting services.

Environment switches for isolated validation:
  L4D2_TARGET_ROOT, L4D2_ETC_ROOT, L4D2_SOURCE_ROOT
  L4D2_SKIP_APT=1, L4D2_SKIP_STEAM=1, L4D2_SKIP_FRAMEWORKS=1
  L4D2_SKIP_PRIVATE_CONFIG=1, L4D2_SKIP_SERVICES=1
  L4D2_DOWNLOAD_CACHE=/path/to/verified/artifacts

Optional first-install environment variables:
  RCON_PASSWORD  RCON password written only to private runtime files.
  WEB_USER       Web administrator name (default: qi).
  WEB_PASSWORD   Web administrator password.
  WEB_BIND       Web listen address (default: 127.0.0.1).
  WEB_PORT       Web listen port (default: 27815).
  BIND_IP        Game listen address (default: 0.0.0.0).
  PORT           Game port (default: 27015).
  MAP            Startup map (default: c1m1_hotel).
  TICKRATE       Server tickrate (default: 30).
  GSLT           Optional Steam game server login token.
EOF
}

cleanup() {
    if [[ -n "${TEMP_DIR}" && -d "${TEMP_DIR}" ]]; then
        find "${TEMP_DIR}" -depth -delete
    fi
}
trap cleanup EXIT

for argument in "$@"; do
    case "${argument}" in
        --update) UPDATE_ONLY=1 ;;
        --no-start) NO_START=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown argument: ${argument}" ;;
    esac
done

[[ "${EUID}" -eq 0 ]] || die "Run this installer as root."
[[ -f "${PROJECT_ROOT}/scripts/bootstrap_l4d2.sh" ]] || die "Cannot determine the project root."

validate_single_line() {
    local label="$1"
    local value="$2"
    [[ -n "${value}" ]] || die "${label} cannot be empty."
    [[ "${value}" != *$'\n'* && "${value}" != *$'\r'* ]] || die "${label} cannot contain newlines."
}

validate_port() {
    local label="$1"
    local value="$2"
    [[ "${value}" =~ ^[0-9]+$ ]] || die "${label} must be an integer."
    (( value >= 1 && value <= 65535 )) || die "${label} must be between 1 and 65535."
}

random_secret() {
    openssl rand -hex 24
}

read_env_value() {
    local file="$1"
    local key="$2"
    local value
    [[ -f "${file}" ]] || return 1
    value="$(sed -n -E "s/^${key}=(.*)$/\\1/p" "${file}" | tail -n 1)"
    [[ -n "${value}" ]] || return 1
    if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
        value="${value:1:${#value}-2}"
        value="${value//\\\"/\"}"
        value="${value//\\\\/\\}"
    elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
        value="${value:1:${#value}-2}"
    fi
    printf '%s' "${value}"
}

read_rcon_from_cfg() {
    local value
    [[ -f "${PRIVATE_CFG}" ]] || return 1
    value="$(sed -n -E 's/^[[:space:]]*rcon_password[[:space:]]+"([^"\\]*)".*/\1/p' "${PRIVATE_CFG}" | tail -n 1)"
    [[ -n "${value}" ]] || return 1
    printf '%s' "${value}"
}

choose_secret() {
    local destination="$1"
    local env_name="$2"
    local existing="$3"
    local prompt="$4"
    local value="${!env_name:-}"

    if [[ -z "${value}" && -n "${existing}" ]]; then
        value="${existing}"
    fi
    if [[ -z "${value}" && -t 0 ]]; then
        read -r -s -p "${prompt} (leave empty to generate): " value
        printf '\n' >&2
    fi
    if [[ -z "${value}" ]]; then
        value="$(random_secret)"
        warn "${env_name} was not supplied; generated a random value in the private runtime configuration."
    fi
    validate_single_line "${env_name}" "${value}"
    printf -v "${destination}" '%s' "${value}"
}

escape_double_quoted() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "${value}"
}

install_dependencies() {
    if [[ "${SKIP_APT}" == "1" ]]; then
        log "L4D2_SKIP_APT=1; dependency installation skipped."
        return
    fi
    log "Enabling i386 and installing Debian dependencies."
    if ! dpkg --print-foreign-architectures | grep -qx i386; then
        dpkg --add-architecture i386
    fi
    apt-get update

    local curl32="libcurl4:i386"
    if apt-cache show libcurl4t64:i386 >/dev/null 2>&1; then
        curl32="libcurl4t64:i386"
    fi

    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl wget ca-certificates file tar gzip xz-utils unzip bzip2 \
        tmux htop sysstat openssl rsync python3 util-linux \
        lib32gcc-s1 lib32stdc++6 libc6:i386 libstdc++6:i386 zlib1g:i386 \
        "${curl32}" libsdl2-2.0-0:i386
}


ensure_service_user() {
    if ! id "${SERVICE_USER}" >/dev/null 2>&1; then
        log "Creating service account ${SERVICE_USER}."
        adduser --disabled-password --gecos "" "${SERVICE_USER}"
    else
        log "Reusing existing service account ${SERVICE_USER}."
    fi
}

capture_config_directive() {
    local config="$1" key="$2" destination="$3"
    [[ -f "${config}" ]] || return 0
    awk -v key="${key}" '$1 == key { print; exit }' "${config}" >"${destination}"
    if [[ ! -s "${destination}" ]]; then
        unlink "${destination}" 2>/dev/null || true
    fi
}


capture_instance_identity() {
    local target_server_cfg target_runtime_cfg target_display_name display_name
    target_server_cfg="${GAME_DIR}/cfg/server.cfg"
    target_runtime_cfg="${GAME_DIR}/cfg/pve_runtime.cfg"
    target_display_name="${GAME_DIR}/addons/sourcemod/configs/pve_hostname.txt"

    INSTANCE_SERVER_HOSTNAME_FILE="${TEMP_DIR}/instance-server-hostname"
    INSTANCE_RUNTIME_HOSTNAME_FILE="${TEMP_DIR}/instance-runtime-hostname"
    INSTANCE_PUBLIC_ADDRESS_FILE="${TEMP_DIR}/instance-public-address"
    INSTANCE_DISPLAY_NAME_FILE="${TEMP_DIR}/instance-display-name"

    capture_config_directive "${target_server_cfg}" hostname "${INSTANCE_SERVER_HOSTNAME_FILE}"
    capture_config_directive "${target_runtime_cfg}" hostname "${INSTANCE_RUNTIME_HOSTNAME_FILE}"

    # Only the one-click installer may replace an existing public address after
    # it has detected the target machine public IP. Ordinary updates preserve it.
    if [[ "${SOURCE_PUBLIC_ADDRESS_AUTHORITATIVE}" != "1" ]]; then
        capture_config_directive "${target_server_cfg}" net_public_adr "${INSTANCE_PUBLIC_ADDRESS_FILE}"
    fi

    if [[ -f "${target_display_name}" ]]; then
        IFS= read -r display_name <"${target_display_name}" || true
        if [[ -n "${display_name}" && "${display_name}" != *$'\r'* ]]; then
            printf '%s\n' "${display_name}" >"${INSTANCE_DISPLAY_NAME_FILE}"
        fi
    fi

    if [[ -f "${INSTANCE_SERVER_HOSTNAME_FILE}" || \
          -f "${INSTANCE_RUNTIME_HOSTNAME_FILE}" || \
          -f "${INSTANCE_PUBLIC_ADDRESS_FILE}" || \
          -f "${INSTANCE_DISPLAY_NAME_FILE}" ]]; then
        INSTANCE_IDENTITY_CAPTURED=1
        log "Preserving instance-specific server identity."
    fi
}


restore_config_directive() {
    local config="$1" key="$2" saved="$3" tmp
    [[ -f "${saved}" ]] || return 0
    install -d "$(dirname "${config}")"
    tmp="$(mktemp "${TEMP_DIR}/restore-${key}.XXXXXX")"
    if [[ -f "${config}" ]]; then
        awk -v key="${key}" -v saved="${saved}" '
            BEGIN { getline replacement < saved; close(saved); restored = 0 }
            $1 == key { if (!restored) print replacement; restored = 1; next }
            { print }
            END { if (!restored) print replacement }
        ' "${config}" >"${tmp}"
    else
        awk 'NR == 1 { print; exit }' "${saved}" >"${tmp}"
    fi
    install -m 0644 "${tmp}" "${config}"
    unlink "${tmp}"
}


restore_instance_identity() {
    (( INSTANCE_IDENTITY_CAPTURED == 1 )) || return 0
    restore_config_directive "${GAME_DIR}/cfg/server.cfg" hostname "${INSTANCE_SERVER_HOSTNAME_FILE}"
    restore_config_directive "${GAME_DIR}/cfg/server.cfg" net_public_adr "${INSTANCE_PUBLIC_ADDRESS_FILE}"
    restore_config_directive "${GAME_DIR}/cfg/pve_runtime.cfg" hostname "${INSTANCE_RUNTIME_HOSTNAME_FILE}"
    if [[ -f "${INSTANCE_DISPLAY_NAME_FILE}" ]]; then
        install -D -m 0644 "${INSTANCE_DISPLAY_NAME_FILE}" \
            "${GAME_DIR}/addons/sourcemod/configs/pve_hostname.txt"
    fi
}


sync_project_tree() {
    install -d -m 0755 "${TARGET_ROOT}"

    if [[ "${PROJECT_ROOT}" == "${TARGET_ROOT}" ]]; then
        log "Source and target are the same tree; no VCS operation is performed."
        return
    fi

    log "Synchronizing project files into ${TARGET_ROOT} without deleting runtime files."
    if [[ -d "${PROJECT_ROOT}/.git" ]]; then
        git -C "${PROJECT_ROOT}" ls-files -z --cached --others --exclude-standard | \
            rsync -a --from0 --files-from=- "${PROJECT_ROOT}/" "${TARGET_ROOT}/"
    else
        rsync -a \
            --exclude '/.git/' \
            --exclude '/lost+found/' \
            --exclude '/steamcmd/' \
            --exclude '/server/left4dead2/cfg/server_private.cfg' \
            --exclude '/server/left4dead2/addons/sourcemod/logs/' \
            --exclude '/server/left4dead2/addons/sourcemod/data/sqlite/' \
            "${PROJECT_ROOT}/" "${TARGET_ROOT}/"
    fi
    restore_instance_identity
}


set_runtime_ownership() {
    # Keep deployment code and Git metadata root-owned. Only the game and
    # SteamCMD runtime trees need to be writable by the dedicated game user.
    chown root:root "${TARGET_ROOT}"
    chmod 0755 "${TARGET_ROOT}"
    [[ ! -d "${STEAMCMD_DIR}" ]] || chmod 0755 "${STEAMCMD_DIR}"
    [[ ! -d "${SERVER_DIR}" ]] || chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${SERVER_DIR}"
    [[ ! -d "${STEAMCMD_DIR}" ]] || chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${STEAMCMD_DIR}"
    [[ ! -d "${PROJECT_ROOT}/scripts" ]] || chown -R root:root "${PROJECT_ROOT}/scripts"
    [[ ! -d "${TARGET_ROOT}/scripts" ]] || chown -R root:root "${TARGET_ROOT}/scripts"
    [[ ! -d "${TARGET_ROOT}/scripts" ]] || chmod 0755 "${TARGET_ROOT}/scripts"
    [[ ! -d "${TARGET_ROOT}/docs" ]] || chown -R root:root "${TARGET_ROOT}/docs"
    [[ ! -d "${TARGET_ROOT}/.git" ]] || chown -R root:root "${TARGET_ROOT}/.git"
    [[ ! -f "${TARGET_ROOT}/scripts/l4d2ctl.sh" ]] || chmod 0755 "${TARGET_ROOT}/scripts/l4d2ctl.sh"
    [[ ! -f "${TARGET_ROOT}/scripts/l4d2_web_admin.py" ]] || chmod 0755 "${TARGET_ROOT}/scripts/l4d2_web_admin.py"
}


disable_incompatible_runtime_entries() {
    # L4D2 is a 32-bit server. A stale x64 VDF makes the engine attempt to load
    # an ELF64 module, and Nextmap is not compatible with this game.
    find "${GAME_DIR}/addons" -type f -name 'metamod_x64.vdf' -delete 2>/dev/null || true
    if [[ -f "${GAME_DIR}/addons/sourcemod/plugins/nextmap.smx" ]]; then
        install -d "${GAME_DIR}/addons/sourcemod/plugins/disabled"
        mv -f "${GAME_DIR}/addons/sourcemod/plugins/nextmap.smx" \
            "${GAME_DIR}/addons/sourcemod/plugins/disabled/nextmap.smx"
    fi
    # Stock reservedslots would create a second slot owner. The project uses
    # the public l4d_reservedslots source with separate human admission Cvars.
    if [[ -f "${GAME_DIR}/addons/sourcemod/plugins/reservedslots.smx" ]]; then
        install -d "${GAME_DIR}/addons/sourcemod/plugins/disabled"
        mv -f "${GAME_DIR}/addons/sourcemod/plugins/reservedslots.smx" \
            "${GAME_DIR}/addons/sourcemod/plugins/disabled/reservedslots.smx"
    fi
    # InfectedBots 3.0.8 requires spawn_infected_nolimit as a low-level native.
    # The project-owned build exposes no commands and only accepts calls from
    # l4dinfectedbots.smx, so it is part of the same spawn Owner.
    for base in no-rushing.smx l4d2_predicaments.smx clear_dead_body.smx l4dafkfix_deadbot.smx \
        l4d2_item_hint.smx kills.smx tank_witch_spawn_notify.smx l4d_gear_transfer.smx; do
        if [[ -f "${GAME_DIR}/addons/sourcemod/plugins/${base}" ]]; then
            install -d "${GAME_DIR}/addons/sourcemod/plugins/disabled"
            mv -f "${GAME_DIR}/addons/sourcemod/plugins/${base}" \
                "${GAME_DIR}/addons/sourcemod/plugins/disabled/${base}"
        fi
    done
}

validate_runtime_ownership() {
    local plugins="${GAME_DIR}/addons/sourcemod/plugins"
    local required path pattern conflict public_slots reserved_slots
    local -a required_plugins=(
        no_friendly-fire.smx
        l4d_reservedslots.smx
        l4d_kickloadstuckers.smx
        l4dinfectedbots.smx
        spawn_infected_nolimit.smx
        l4d2_pve_infected_core.smx
        l4d2_playable_witch.smx
        l4d2_pve_respawn.smx
        l4d2_pve_director_controller.smx
        l4d2_pve_antirush.smx
        l4d2_pve_server_hud.smx
        l4d2_pve_corpse_cleaner.smx
        WeaponHandling.smx
        l4d2_pve_overdrive.smx
        l4d2_restart_empty.smx
    )
    local -a conflict_patterns=(
        'anti-friendly_fire*.smx'
        'l4dffannounce*.smx'
        'NekoSpecials*.smx'
        'NekoVote*.smx'
        'NekoKillHud*.smx'
        'l4d2_boss_spawn*.smx'
        'l4d2_si_spawn_control*.smx'
        'l4d2_multi_witches*.smx'
        'l4d2_auto_restart*.smx'
        'restart_empty_server*.smx'
        'no-rushing.smx'
        'reservedslots.smx'
        'clear_dead_body.smx'
        'l4dafkfix_deadbot.smx'
    )

    for required in "${required_plugins[@]}"; do
        [[ -f "${plugins}/${required}" ]] || die "Runtime Owner validation failed; missing ${required}."
    done

    for pattern in "${conflict_patterns[@]}"; do
        conflict="$(find "${plugins}" -maxdepth 1 -type f -iname "${pattern}" -print -quit)"
        [[ -z "${conflict}" ]] || die "Runtime Owner conflict remains enabled: ${conflict}"
    done

    if find "${plugins}" -maxdepth 1 -type f -iname '*survivor*identity*.smx' -print -quit | grep -q . \
        && find "${plugins}" -maxdepth 1 -type f -iname '*deadbot*.smx' -print -quit | grep -q .; then
        die "Runtime Owner conflict: Survivor Identity Fix and deadbot are both enabled."
    fi

    for path in \
        "${GAME_DIR}/addons/sourcemod/gamedata/command_buffer.games.txt" \
        "${GAME_DIR}/addons/sourcemod/gamedata/WeaponHandling.txt" \
        "${GAME_DIR}/addons/sourcemod/gamedata/physics_object_pushfix.txt" \
        "${GAME_DIR}/addons/sourcemod/gamedata/l4dinfectedbots.txt" \
        "${GAME_DIR}/addons/sourcemod/gamedata/spawn_infected_nolimit.txt" \
        "${GAME_DIR}/addons/sourcemod/gamedata/left4dhooks.l4d2.txt" \
        "${GAME_DIR}/addons/sourcemod/scripting/include/left4dhooks.inc" \
        "${GAME_DIR}/addons/sourcemod/scripting/include/weaponhandling.inc"; do
        [[ -f "${path}" ]] || die "Required runtime dependency is missing: ${path}"
    done

    for pattern in \
        sm_infected_balancer_si_general_power \
        sm_infected_balancer_si_dominator_power \
        sm_infected_balancer_spawn_interval_power \
        sm_infected_balancer_tank_balance \
        sm_infected_balancer_tank_increase_hp_percent \
        sm_infected_balancer_versus_like; do
        grep -Eq "^${pattern}[[:space:]]+\"?0\"?([[:space:]]|$)" \
            "${GAME_DIR}/cfg/sourcemod/l4d2_balancer_spawn_dyn.cfg" \
            || die "Dynamic Balancer Owner conflict: ${pattern} must be 0."
    done

    for pattern in tank_limit tank_spawn_probability witch_max_limit; do
        grep -Eq "^[[:space:]]*\"${pattern}\"[[:space:]]+\"0\"" \
            "${GAME_DIR}/addons/sourcemod/data/l4dinfectedbots/pve_pvpve.cfg" \
            || die "InfectedBots Owner conflict: ${pattern} must be 0."
    done
    grep -Eq '^[[:space:]]*"spawn_same_frame"[[:space:]]+"0"' \
        "${GAME_DIR}/addons/sourcemod/data/l4dinfectedbots/pve_pvpve.cfg" \
        || die "InfectedBots spawn_same_frame must remain 0."

    public_slots="$(awk '$1=="pve_public_human_slots"{gsub(/"/,"",$2); print $2}' \
        "${GAME_DIR}/cfg/sourcemod/l4d_reservedslots.cfg")"
    reserved_slots="$(awk '$1=="pve_admin_reserved_slots"{gsub(/"/,"",$2); print $2}' \
        "${GAME_DIR}/cfg/sourcemod/l4d_reservedslots.cfg")"
    [[ "${public_slots}" =~ ^(12|13|14|15|16)$ ]] \
        || die "Invalid pve_public_human_slots: ${public_slots:-missing}"
    [[ "${reserved_slots}" =~ ^[1-4]$ ]] \
        || die "Invalid pve_admin_reserved_slots: ${reserved_slots:-missing}"

    log "Runtime Owner validation passed before service startup."
}

install_steamcmd() {
    if [[ "${SKIP_STEAM}" == "1" ]]; then
        log "L4D2_SKIP_STEAM=1; SteamCMD/AppID 222860 installation skipped."
        return
    fi
    install -d -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" "${STEAMCMD_DIR}"
    if [[ ! -x "${STEAMCMD_DIR}/steamcmd.sh" ]]; then
        log "Installing SteamCMD."
        download_artifact steamcmd "${TEMP_DIR}/steamcmd.tar.gz"
        tar -xzf "${TEMP_DIR}/steamcmd.tar.gz" -C "${STEAMCMD_DIR}"
        chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${STEAMCMD_DIR}"
    fi

    # Valve archive permissions are not reliable across extraction tools.
    # Repair the launcher and binaries before dropping privileges.
    [[ -f "${STEAMCMD_DIR}/steamcmd.sh" ]] || die "SteamCMD launcher is missing: ${STEAMCMD_DIR}/steamcmd.sh"
    chmod 0755 "${STEAMCMD_DIR}/steamcmd.sh"
    require_exec_mount "${STEAMCMD_DIR}/steamcmd.sh"
    [[ ! -e "${STEAMCMD_DIR}/linux32/steamcmd" ]] || chmod 0755 "${STEAMCMD_DIR}/linux32/steamcmd"
    [[ ! -e "${STEAMCMD_DIR}/linux64/steamcmd" ]] || chmod 0755 "${STEAMCMD_DIR}/linux64/steamcmd"
    chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${STEAMCMD_DIR}"

    install -d -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" "${SERVER_DIR}"
    log "Installing/updating L4D2 Dedicated Server AppID 222860 with anonymous SteamCMD."
    local app_command=(+app_update 222860 validate)
    if (( UPDATE_ONLY )); then
        app_command=(+app_update 222860)
    fi
    runuser -u "${SERVICE_USER}" -- \
        /bin/bash "${STEAMCMD_DIR}/steamcmd.sh" \
        +force_install_dir "${SERVER_DIR}" \
        +login anonymous \
        "${app_command[@]}" \
        +quit

    [[ -x "${SERVER_DIR}/srcds_run" ]] || die "SteamCMD completed but ${SERVER_DIR}/srcds_run is missing."
}


install_frameworks() {
    if [[ "${SKIP_FRAMEWORKS}" == "1" ]]; then
        log "L4D2_SKIP_FRAMEWORKS=1; framework installation skipped."
        return
    fi
    install -d "${GAME_DIR}/addons" "${GAME_DIR}/addons/sourcemod"

    log "Installing MetaMod:Source ${MM_VERSION}."
    download_artifact metamod "${TEMP_DIR}/metamod.tar.gz"
    tar -xzf "${TEMP_DIR}/metamod.tar.gz" -C "${GAME_DIR}"

    log "Installing SourceMod ${SM_VERSION}."
    download_artifact sourcemod "${TEMP_DIR}/sourcemod.tar.gz"
    tar -xzf "${TEMP_DIR}/sourcemod.tar.gz" -C "${GAME_DIR}"

    log "Installing L4DToolZ, Actions 3.9.2, Left4DHooks 1.168, Dynamic Balancer and Mutant Tanks 9.3."
    download_artifact l4dtoolz "${TEMP_DIR}/l4dtoolz.zip"
    unzip -oq "${TEMP_DIR}/l4dtoolz.zip" -d "${GAME_DIR}/addons"
    download_artifact actions "${TEMP_DIR}/actions.zip"
    install -d "${GAME_DIR}/addons/sourcemod/extensions" "${GAME_DIR}/addons/sourcemod/gamedata" "${GAME_DIR}/addons/sourcemod/scripting/include"
    unzip -oq "${TEMP_DIR}/actions.zip" -d "${TEMP_DIR}/actions"
    rsync -a "${TEMP_DIR}/actions/actions.ext/extensions/" "${GAME_DIR}/addons/sourcemod/extensions/"
    rsync -a "${TEMP_DIR}/actions/actions.ext/gamedata/" "${GAME_DIR}/addons/sourcemod/gamedata/"
    rsync -a "${TEMP_DIR}/actions/actions.ext/scripting/include/" "${GAME_DIR}/addons/sourcemod/scripting/include/"

    download_artifact left4dhooks "${TEMP_DIR}/left4dhooks.tar.gz"
    extract_tar_overlay "${TEMP_DIR}/left4dhooks.tar.gz" "${GAME_DIR}" left4dhooks
    download_artifact mutant_tanks "${TEMP_DIR}/mutant_tanks.tar.gz"
    extract_tar_overlay "${TEMP_DIR}/mutant_tanks.tar.gz" "${GAME_DIR}" mutant_tanks
    download_artifact dynamic_balancer "${TEMP_DIR}/dynamic_balancer.zip"
    unzip -oq "${TEMP_DIR}/dynamic_balancer.zip" -d "${TEMP_DIR}/dynamic_balancer"
    if [[ -f "${TEMP_DIR}/dynamic_balancer/plugins/l4d2_balancer_spawn_dyn.smx" ]]; then
        install -m 0644 "${TEMP_DIR}/dynamic_balancer/plugins/l4d2_balancer_spawn_dyn.smx" "${GAME_DIR}/addons/sourcemod/plugins/l4d2_balancer_spawn_dyn.smx"
    fi

    sync_project_tree
    disable_incompatible_runtime_entries
    set_runtime_ownership
}



find_vendor_package_root() {
    local key="$1" package_name="${2:-}" root
    if [[ -n "${package_name}" ]]; then
        root="$(find "${TEMP_DIR}/${key}" -type d -name "${package_name}" -print -quit)"
    else
        root="$(find "${TEMP_DIR}/${key}" -mindepth 1 -maxdepth 1 -type d -print -quit)"
    fi
    [[ -n "${root}" ]] || die "Required vendor package is missing: ${key}/${package_name:-archive-root}"
    printf "%s\n" "${root}"
}

stage_vendor_package_companions() {
    local key="$1" package_name="$2" root source_root directory overlay_sm
    root="$(find_vendor_package_root "${key}" "${package_name}")"
    overlay_sm="${TEMP_DIR}/vendor-overlay/addons/sourcemod"
    install -d "${overlay_sm}" "${TEMP_DIR}/vendor-overlay/cfg"
    for source_root in "${root}" "${root}/addons/sourcemod"; do
        [[ -d "${source_root}" ]] || continue
        for directory in gamedata data configs translations; do
            if [[ -d "${source_root}/${directory}" ]]; then
                install -d "${overlay_sm}/${directory}"
                rsync -a "${source_root}/${directory}/" "${overlay_sm}/${directory}/"
            fi
        done
        if [[ -d "${source_root}/scripting/include" ]]; then
            install -d "${overlay_sm}/scripting/include"
            rsync -a "${source_root}/scripting/include/" "${overlay_sm}/scripting/include/"
        fi
    done
    if [[ -d "${root}/cfg" ]]; then
        rsync -a "${root}/cfg/" "${TEMP_DIR}/vendor-overlay/cfg/"
    fi
}

stage_vendor_named_file() {
    local key="$1" package_name="$2" source_name="$3" destination="$4" root
    local -a matches=()
    root="$(find_vendor_package_root "${key}" "${package_name}")"
    mapfile -t matches < <(find "${root}" -type f -name "${source_name}" -print)
    (( ${#matches[@]} == 1 )) || die "Expected one vendor file ${key}/${package_name}/${source_name}; found ${#matches[@]}."
    install -D -m 0644 "${matches[0]}" "${TEMP_DIR}/vendor-overlay/${destination}"
}

compile_vendor_plugin() {
    local key="$1" source_name="$2" output_name="$3" package_name="${4:-}"
    local root source compiler temp_output compile_log overlay_include
    local -a matches=()
    compiler="${GAME_DIR}/addons/sourcemod/scripting/spcomp"
    root="$(find_vendor_package_root "${key}" "${package_name}")"
    mapfile -t matches < <(find "${root}" -type f -name "${source_name}" -print)
    (( ${#matches[@]} == 1 )) || die "Expected one vendor source ${key}/${package_name}/${source_name}; found ${#matches[@]}."
    source="${matches[0]}"
    [[ -x "${compiler}" ]] || die "SourcePawn compiler is missing: ${compiler}"

    install -d "${TEMP_DIR}/vendor-smx"
    temp_output="${TEMP_DIR}/vendor-smx/${output_name}"
    compile_log="${TEMP_DIR}/vendor-${output_name}.log"
    overlay_include="${TEMP_DIR}/vendor-overlay/addons/sourcemod/scripting/include"
    if (cd "$(dirname "${source}")" && "${compiler}" \
            -i"${overlay_include}" \
            -i"${GAME_DIR}/addons/sourcemod/scripting/include" \
            "${source_name}" -o"${temp_output}") >"${compile_log}" 2>&1; then
        if grep -Eiq '(^|[^a-z])warning([[:space:]]+[0-9]+|s?:)' "${compile_log}"; then
            sed -n '1,160p' "${compile_log}" >&2
            die "Vendor SourcePawn compilation emitted warnings: ${source_name}"
        fi
        log "Staged vendor ${source_name} -> ${output_name}"
    else
        sed -n "1,160p" "${compile_log}" >&2
        die "Vendor SourcePawn compilation failed: ${source_name}"
    fi
}

install_gameplay_packages() {
    local key archive extract_root package source_name output_name
    local -a bundle_keys=(fbef_phase1 wyxls_plugins weapon_handling dual_primary votekick no_friendly_fire smac multicolors)
    local -a fbef_packages=(
        AI_HardSI cge_l4d2_deathcheck clear_weapon_drop fix_botkick
        l4d2_assist l4d2_maptankfix l4d2_rescue_vehicle_multi
        l4d2_tank_props_glow l4d_CreateSurvivorBot l4d_afk_commands
        l4d_both_fixUpgradePack l4d_finale_stage_fix
        l4d_full_slot_bot_replace_fix l4dmultislots
    )
    local -a fbef_plugins=(
        "AI_HardSI|AI_HardSI.sp|AI_HardSI.smx"
        "cge_l4d2_deathcheck|cge_l4d2_deathcheck.sp|cge_l4d2_deathcheck.smx"
        "clear_weapon_drop|clear_weapon_drop.sp|clear_weapon_drop.smx"
        "fix_botkick|fix_botkick.sp|fix_botkick.smx"
        "l4d2_assist|l4d2_assist.sp|l4d2_assist.smx"
        "l4d2_maptankfix|l4d2_maptankfix.sp|l4d2_maptankfix.smx"
        "l4d2_rescue_vehicle_multi|l4d2_rescue_vehicle_multi.sp|l4d2_rescue_vehicle_multi.smx"
        "l4d2_tank_props_glow|l4d2_tank_props_glow.sp|l4d2_tank_props_glow.smx"
        "l4d_CreateSurvivorBot|l4d_CreateSurvivorBot.sp|l4d_CreateSurvivorBot.smx"
        "l4d_afk_commands|l4d_afk_commands.sp|l4d_afk_commands.smx"
        "l4d_both_fixUpgradePack|l4d_both_fixUpgradePack.sp|l4d_both_fixUpgradePack.smx"
        "l4d_finale_stage_fix|l4d_finale_stage_fix.sp|l4d_finale_stage_fix.smx"
        "l4d_full_slot_bot_replace_fix|l4d_full_slot_bot_replace_fix.sp|l4d_full_slot_bot_replace_fix.smx"
        "l4dmultislots|l4dmultislots.sp|l4dmultislots.smx"
    )
    local -a vendor_outputs=(
        AI_HardSI.smx cge_l4d2_deathcheck.smx clear_weapon_drop.smx fix_botkick.smx
        l4d2_assist.smx l4d2_maptankfix.smx l4d2_rescue_vehicle_multi.smx
        l4d2_tank_props_glow.smx l4d_CreateSurvivorBot.smx l4d_afk_commands.smx
        l4d_both_fixUpgradePack.smx l4d_finale_stage_fix.smx
        l4d_full_slot_bot_replace_fix.smx l4dmultislots.smx
        Defib_Fix.smx
        WeaponHandling.smx survivor_afk_fix.smx no_friendly-fire.smx
        dual_primaries.smx l4d_votekick.smx smac.smx smac_aimbot.smx
        smac_commands.smx smac_cvars.smx smac_l4d2_fixes.smx smac_speedhack.smx
    )

    for key in "${bundle_keys[@]}"; do
        archive="${TEMP_DIR}/${key}.tar.gz"
        download_artifact "${key}" "${archive}"
        extract_root="${TEMP_DIR}/${key}"
        install -d "${extract_root}"
        tar -xzf "${archive}" -C "${extract_root}"
    done

    install -d "${TEMP_DIR}/vendor-overlay/addons/sourcemod/scripting/include" \
        "${TEMP_DIR}/vendor-overlay/cfg/sourcemod" "${TEMP_DIR}/vendor-smx"

    for package in "${fbef_packages[@]}"; do
        stage_vendor_package_companions fbef_phase1 "${package}"
    done
    stage_vendor_package_companions wyxls_plugins l4d2_automatic_weapons
    stage_vendor_package_companions smac ""

    stage_vendor_named_file wyxls_plugins "(Must_Install) BasicEnvs" Defib_Fix.inc addons/sourcemod/scripting/include/Defib_Fix.inc
    stage_vendor_named_file weapon_handling "" weaponhandling.inc addons/sourcemod/scripting/include/weaponhandling.inc
    stage_vendor_named_file wyxls_plugins "(Must_Install) BasicEnvs" defib_fix.txt addons/sourcemod/gamedata/defib_fix.txt
    stage_vendor_named_file weapon_handling "" WeaponHandling.txt addons/sourcemod/gamedata/WeaponHandling.txt
    stage_vendor_named_file wyxls_plugins "(Must_Install) BasicEnvs" survivor_afk_fix.txt addons/sourcemod/gamedata/survivor_afk_fix.txt

    while IFS= read -r -d "" package; do
        rsync -a "${package}/" "${TEMP_DIR}/vendor-overlay/addons/sourcemod/scripting/include/"
    done < <(find "${TEMP_DIR}/multicolors" -type d -path "*/scripting/include" -print0)

    for package in "${fbef_plugins[@]}"; do
        IFS="|" read -r key source_name output_name <<<"${package}"
        compile_vendor_plugin fbef_phase1 "${source_name}" "${output_name}" "${key}"
    done

    grep -Eq '^#define[[:space:]]+PLUGIN_VERSION[[:space:]]+"1\.0\.7"' \
        "$(find "${TEMP_DIR}/weapon_handling" -type f -name WeaponHandling.sp -print -quit)" \
        || die "WeaponHandling source is not the required 1.0.7."
    compile_vendor_plugin wyxls_plugins Defib_Fix.sp Defib_Fix.smx "(Must_Install) BasicEnvs"
    compile_vendor_plugin weapon_handling WeaponHandling.sp WeaponHandling.smx
    compile_vendor_plugin wyxls_plugins survivor_afk_fix.sp survivor_afk_fix.smx "(Must_Install) BasicEnvs"
    compile_vendor_plugin no_friendly_fire no_friendly-fire.sp no_friendly-fire.smx
    compile_vendor_plugin dual_primary dual_primaries.sp dual_primaries.smx
    compile_vendor_plugin votekick l4d_votekick.sp l4d_votekick.smx
    compile_vendor_plugin smac smac.sp smac.smx
    compile_vendor_plugin smac smac_aimbot.sp smac_aimbot.smx
    compile_vendor_plugin smac smac_commands.sp smac_commands.smx
    compile_vendor_plugin smac smac_cvars.sp smac_cvars.smx
    compile_vendor_plugin smac smac_l4d2_fixes.sp smac_l4d2_fixes.smx
    compile_vendor_plugin smac smac_speedhack.sp smac_speedhack.smx

    for output_name in "${vendor_outputs[@]}"; do
        [[ -f "${TEMP_DIR}/vendor-smx/${output_name}" ]] || die "Staged vendor output is missing: ${output_name}"
    done
    rsync -a "${TEMP_DIR}/vendor-overlay/" "${GAME_DIR}/"
    install -d "${GAME_DIR}/addons/sourcemod/plugins"
    for output_name in "${vendor_outputs[@]}"; do
        install -m 0644 "${TEMP_DIR}/vendor-smx/${output_name}" "${GAME_DIR}/addons/sourcemod/plugins/${output_name}"
    done

    log "Installed the explicit vendor allowlist after all selected sources compiled."
}

compile_plugins() {
    local scripting="${GAME_DIR}/addons/sourcemod/scripting"
    local compiler="${scripting}/spcomp"
    local plugins="${GAME_DIR}/addons/sourcemod/plugins"
    local stage_dir="${TEMP_DIR}/project-smx"
    local failures=0
    local item source relative output temp_output compile_log
    local -a warning_flags=()
    local entries=(
        "l4d2_campaign_shop.sp:l4d2_campaign_shop.smx"
        "l4d2_automatic_weapons.sp:l4d2_automatic_weapons.smx"
        "l4d2_unicode_hostname.sp:l4d2_unicode_hostname.smx"
        "l4d2_clear_thirdstrike.sp:l4d2_clear_thirdstrike.smx"
        "l4d2_combat_rewards.sp:l4d2_combat_rewards.smx"
        "l4d2_incap_support.sp:l4d2_incap_support.smx"
        "l4d2_pve_respawn.sp:l4d2_pve_respawn.smx"
        "l4d2_end_safearea_teleport.sp:l4d2_end_safearea_teleport.smx"
        "l4d2_pve_admin.sp:l4d2_pve_admin.smx"
        "l4d2_pve_help_menu.sp:l4d2_pve_help_menu.smx"
        "l4d2_pve_infected_core.sp:l4d2_pve_infected_core.smx"
        "l4d2_switch_upgrade_ammo.sp:l4d2_switch_ammo.smx"
        "third_party/l4d2_double_jump.sp:l4d2_double_jump.smx"
        "third_party/miuwiki_autoscar.sp:miuwiki_autoscar.smx"
        "l4d2_pve_damage_display.sp:l4d2_pve_damage_display.smx"
        "l4d2_playable_witch.sp:l4d2_playable_witch.smx"
        "l4d2_pve_mutant_tanks.sp:l4d2_pve_mutant_tanks.smx"
        "third_party/command_buffer.sp:command_buffer.smx"
        "third_party/spawn_infected_nolimit.sp:spawn_infected_nolimit.smx"
        "third_party/l4dinfectedbots.sp:l4dinfectedbots.smx"
        "third_party/l4d_reservedslots.sp:l4d_reservedslots.smx"
        "third_party/l4d_kickloadstuckers.sp:l4d_kickloadstuckers.smx"
        "third_party/l4d_switch_team_survivor_dead_fix.sp:l4d_switch_team_survivor_dead_fix.smx"
        "third_party/jockey_ride_team_switch_teleport_fix.sp:jockey_ride_team_switch_teleport_fix.smx"
        "third_party/physics_object_pushfix.sp:physics_object_pushfix.smx"
        "l4d2_pve_server_hud.sp:l4d2_pve_server_hud.smx"
        "l4d2_pve_director_controller.sp:l4d2_pve_director_controller.smx"
        "l4d2_pve_antirush.sp:l4d2_pve_antirush.smx"
        "l4d2_pve_perf_guard.sp:l4d2_pve_perf_guard.smx"
        "l4d2_pve_corpse_cleaner.sp:l4d2_pve_corpse_cleaner.smx"
        "l4d2_pve_overdrive.sp:l4d2_pve_overdrive.smx"
        "l4d2_restart_empty.sp:l4d2_restart_empty.smx"
    )

    [[ -x "${compiler}" ]] || die "SourcePawn compiler is missing: ${compiler}"
    install -d -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" "${plugins}"
    install -d "${stage_dir}"
    log "Compiling all project SourcePawn plugins into an atomic staging directory."

    for item in "${entries[@]}"; do
        relative="${item%%:*}"
        output="${item##*:}"
        source="${scripting}/${relative}"
        temp_output="${stage_dir}/${output}"
        compile_log="${TEMP_DIR}/${output}.log"

        if [[ ! -f "${source}" ]]; then
            warn "Source is not present; retained any existing ${output}: ${relative}"
            failures=$((failures + 1))
            continue
        fi
        warning_flags=()
        if [[ "${relative}" == "l4d2_pve_mutant_tanks.sp" ]]; then
            # MT_CanTankSpawn is the compatibility stock for older 9.3 includes.
            warning_flags=(-w234)
        fi
        if (cd "${scripting}" && "${compiler}" \
                -i"${scripting}/include" "${warning_flags[@]}" \
                "${relative}" -o"${temp_output}") >"${compile_log}" 2>&1; then
            if grep -Eiq '(^|[^a-z])warning([[:space:]]+[0-9]+|s?:)' "${compile_log}"; then
                failures=$((failures + 1))
                warn "Compilation emitted warnings for ${relative}; no staged project plugin will be published."
                sed -n '1,160p' "${compile_log}" >&2
                continue
            fi
            log "Staged ${relative} -> ${output}"
        else
            failures=$((failures + 1))
            warn "Compilation failed for ${relative}; no staged project plugin will be published."
            sed -n '1,160p' "${compile_log}" >&2
        fi
    done

    if (( failures > 0 )); then
        die "${failures} 个必需 SourcePawn 插件缺失或编译失败；已保留旧 SMX，停止部署。"
    fi

    for item in "${entries[@]}"; do
        output="${item##*:}"
        [[ -f "${stage_dir}/${output}" ]] || die "Staged project output is missing: ${output}"
    done
    for item in "${entries[@]}"; do
        output="${item##*:}"
        install -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" -m 0644 \
            "${stage_dir}/${output}" "${plugins}/${output}"
    done
    log "Published the complete project plugin set after every compile succeeded."
}

write_private_configuration() {
    if [[ "${SKIP_PRIVATE_CONFIG}" == "1" ]]; then
        log "L4D2_SKIP_PRIVATE_CONFIG=1; private configuration generation skipped."
        return
    fi
    local existing_rcon=""
    local existing_web_password=""
    local rcon_password=""
    local web_password=""
    local web_user="${WEB_USER:-}"
    local web_bind="${WEB_BIND:-}"
    local web_port="${WEB_PORT:-}"
    local game_port="${PORT:-}"
    local rcon_host="${RCON_HOST:-}"
    local tmp escaped

    install -d -m 0755 "${ETC_DIR}"
    install -d -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" -m 0755 "${GAME_DIR}/cfg"

    existing_rcon="$(read_rcon_from_cfg || true)"
    if [[ -z "${existing_rcon}" ]]; then
        existing_rcon="$(read_env_value "${WEB_ENV}" RCON_PASSWORD || true)"
    fi
    choose_secret rcon_password RCON_PASSWORD "${existing_rcon}" "RCON password"

    tmp="$(mktemp "${ETC_DIR}/server-private.XXXXXX")"
    if [[ -f "${PRIVATE_CFG}" ]]; then
        grep -Ev '^[[:space:]]*rcon_password([[:space:]]|$)' "${PRIVATE_CFG}" >"${tmp}" || true
    fi
    escaped="$(escape_double_quoted "${rcon_password}")"
    printf 'rcon_password "%s"\n' "${escaped}" >>"${tmp}"
    chown "${SERVICE_USER}:${SERVICE_GROUP}" "${tmp}"
    chmod 0600 "${tmp}"
    mv -f "${tmp}" "${PRIVATE_CFG}"

    if [[ ! -f "${GAME_ENV}" ]]; then
        cat >"${GAME_ENV}" <<EOF
PORT=${PORT:-27015}
MAP=${MAP:-c1m1_hotel}
TICKRATE=${TICKRATE:-30}
BIND_IP=${BIND_IP:-0.0.0.0}
GSLT=${GSLT:-}
EOF
    fi
    chown root:root "${GAME_ENV}"
    chmod 0600 "${GAME_ENV}"

    [[ -n "${game_port}" ]] || game_port="$(read_env_value "${GAME_ENV}" PORT || true)"
    [[ -n "${game_port}" ]] || game_port="27015"
    validate_port PORT "${game_port}"
    [[ -n "${rcon_host}" ]] || rcon_host="$(read_env_value "${WEB_ENV}" RCON_HOST || true)"
    [[ -n "${rcon_host}" ]] || rcon_host="127.0.0.1"
    validate_single_line RCON_HOST "${rcon_host}"

    existing_web_password="$(read_env_value "${WEB_ENV}" WEB_PASSWORD || true)"
    choose_secret web_password WEB_PASSWORD "${existing_web_password}" "Web administrator password"
    [[ -n "${web_user}" ]] || web_user="$(read_env_value "${WEB_ENV}" WEB_USER || true)"
    [[ -n "${web_user}" ]] || web_user="qi"
    [[ -n "${web_bind}" ]] || web_bind="$(read_env_value "${WEB_ENV}" WEB_BIND || true)"
    [[ -n "${web_bind}" ]] || web_bind="127.0.0.1"
    [[ -n "${web_port}" ]] || web_port="$(read_env_value "${WEB_ENV}" WEB_PORT || true)"
    [[ -n "${web_port}" ]] || web_port="27815"

    validate_single_line WEB_USER "${web_user}"
    validate_single_line WEB_BIND "${web_bind}"
    validate_port WEB_PORT "${web_port}"

    tmp="$(mktemp "${ETC_DIR}/l4d2-admin.XXXXXX")"
    if [[ -f "${WEB_ENV}" ]]; then
        grep -Ev '^(WEB_USER|WEB_PASSWORD|WEB_BIND|WEB_PORT|RCON_PASSWORD|RCON_HOST|RCON_PORT|L4D2_SERVICE|L4D2CTL)=' \
            "${WEB_ENV}" >"${tmp}" || true
    fi
    printf 'WEB_USER="%s"\n' "$(escape_double_quoted "${web_user}")" >>"${tmp}"
    printf 'WEB_PASSWORD="%s"\n' "$(escape_double_quoted "${web_password}")" >>"${tmp}"
    printf 'WEB_BIND="%s"\n' "$(escape_double_quoted "${web_bind}")" >>"${tmp}"
    printf 'WEB_PORT="%s"\n' "${web_port}" >>"${tmp}"
    printf 'RCON_PASSWORD="%s"\n' "$(escape_double_quoted "${rcon_password}")" >>"${tmp}"
    printf 'RCON_HOST="%s"\nRCON_PORT="%s"\n' "$(escape_double_quoted "${rcon_host}")" "${game_port}" >>"${tmp}"
    printf 'L4D2_SERVICE="l4d2"\nL4D2CTL="/opt/l4d2/scripts/l4d2ctl.sh"\n' >>"${tmp}"
    chown root:root "${tmp}"
    chmod 0600 "${tmp}"
    mv -f "${tmp}" "${WEB_ENV}"
}

install_steamclient_link() {
    local home_dir
    local steamclient="${STEAMCMD_DIR}/linux32/steamclient.so"
    [[ -f "${steamclient}" ]] || return 0
    home_dir="$(getent passwd "${SERVICE_USER}" | cut -d: -f6)"
    [[ -n "${home_dir}" ]] || return 0
    install -d -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" "${home_dir}/.steam/sdk32"
    ln -sfn "${steamclient}" "${home_dir}/.steam/sdk32/steamclient.so"
    chown -h "${SERVICE_USER}:${SERVICE_GROUP}" "${home_dir}/.steam/sdk32/steamclient.so"
}

install_services() {
    if [[ "${SKIP_SERVICES}" == "1" ]]; then
        log "L4D2_SKIP_SERVICES=1; systemd unit changes skipped."
        return
    fi
    log "Creating systemd units."
    cat >/etc/systemd/system/l4d2.service <<'EOF'
[Unit]
Description=Left 4 Dead 2 Dedicated Server
Wants=network-online.target
After=network-online.target
RequiresMountsFor=/opt/l4d2

[Service]
Type=simple
User=l4d2srv
Group=l4d2srv
WorkingDirectory=/opt/l4d2/server
EnvironmentFile=/etc/l4d2/l4d2.env
ExecStart=/opt/l4d2/scripts/start_server.sh
Restart=always
RestartSec=5
LimitNOFILE=65536
KillSignal=SIGINT
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

    cat >/etc/systemd/system/l4d2-web-admin.service <<'EOF'
[Unit]
Description=L4D2 Local Web Administration Panel
After=network-online.target l4d2.service
Wants=network-online.target
Requires=l4d2.service
RequiresMountsFor=/opt/l4d2

[Service]
Type=simple
# The panel is localhost-only by default. It runs as root because its fixed,
# allowlisted operations include systemd service control and controlled updates.
User=root
Group=root
WorkingDirectory=/opt/l4d2
EnvironmentFile=/etc/l4d2/l4d2-admin.env
ExecStart=/usr/bin/python3 /opt/l4d2/scripts/l4d2_web_admin.py
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectControlGroups=true
ProtectKernelModules=true
ProtectKernelTunables=true
RestrictSUIDSGID=true

[Install]
WantedBy=multi-user.target
EOF

    chmod 0644 /etc/systemd/system/l4d2.service /etc/systemd/system/l4d2-web-admin.service
    chmod 0755 "${TARGET_ROOT}/scripts/start_server.sh"
    [[ -x "${TARGET_ROOT}/scripts/l4d2ctl.sh" ]] || die "缺少可执行的 ${TARGET_ROOT}/scripts/l4d2ctl.sh"
    [[ -f "${TARGET_ROOT}/scripts/l4d2_web_admin.py" ]] || die "缺少 ${TARGET_ROOT}/scripts/l4d2_web_admin.py"
    chmod 0755 "${TARGET_ROOT}/scripts/l4d2ctl.sh" "${TARGET_ROOT}/scripts/l4d2_web_admin.py"

    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        systemctl daemon-reload
        systemctl enable l4d2.service
        if [[ -f "${TARGET_ROOT}/scripts/l4d2_web_admin.py" ]]; then
            systemctl enable l4d2-web-admin.service
        else
            warn "Web panel script is absent; unit was created but not enabled."
        fi
    else
        warn "systemd is not active; unit files were created but not enabled or started."
    fi
}

start_services() {
    (( NO_START == 0 )) || { log "--no-start selected; services were not started."; return; }
    if ! command -v systemctl >/dev/null 2>&1 || [[ ! -d /run/systemd/system ]]; then
        warn "systemd is not active; cannot start services."
        return
    fi

    systemctl restart l4d2.service
    if [[ -f "${TARGET_ROOT}/scripts/l4d2_web_admin.py" ]]; then
        if python3 -c 'import pathlib,sys; compile(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"), sys.argv[1], "exec")' \
            "${TARGET_ROOT}/scripts/l4d2_web_admin.py"; then
            systemctl restart l4d2-web-admin.service
        else
            warn "Web panel has a Python syntax error; l4d2-web-admin was not started."
        fi
    fi
}

main() {
    TEMP_DIR="$(mktemp -d /tmp/l4d2-bootstrap.XXXXXX)"
    load_manifest
    install_dependencies
    ensure_service_user
    capture_instance_identity
    sync_project_tree
    set_runtime_ownership
    install_steamcmd
    install_frameworks
    disable_incompatible_runtime_entries
    if [[ "${SKIP_FRAMEWORKS}" != "1" ]]; then
        install_gameplay_packages
        # Vendor bundles may overwrite reviewed source/includes. Reassert the
        # project-owned policy patch before compilation.
        sync_project_tree
    fi
    disable_incompatible_runtime_entries
    write_private_configuration
    install_steamclient_link
    compile_plugins
    validate_runtime_ownership
    install_services
    start_services

    log "Installation/update completed."
    log "Game service: systemctl status l4d2 --no-pager -l"
    log "Web service:  systemctl status l4d2-web-admin --no-pager -l"
    log "Private credentials remain in ${PRIVATE_CFG} and ${WEB_ENV}."
}

main
