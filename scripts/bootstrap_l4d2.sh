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
DOWNLOAD_CACHE="${L4D2_DOWNLOAD_CACHE:-/var/cache/l4d2/artifacts}"
TEMP_DIR=""
PROJECT_ROOT="${L4D2_SOURCE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST_FILE="${PROJECT_ROOT}/scripts/l4d2_artifact_manifest.sh"

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

    # L4D2 is a 32-bit server. Disable only the x64 MetaMod VDF probe; keep
    # the normal VDF, 32-bit module and the linux64 binary for other games.
    find "${GAME_DIR}/addons" -type f -name 'metamod_x64.vdf' -delete

    if [[ -f "${GAME_DIR}/addons/sourcemod/plugins/nextmap.smx" ]]; then
        install -d "${GAME_DIR}/addons/sourcemod/plugins/disabled"
        mv -f "${GAME_DIR}/addons/sourcemod/plugins/nextmap.smx" \
            "${GAME_DIR}/addons/sourcemod/plugins/disabled/nextmap.smx"
    fi

    sync_project_tree
    set_runtime_ownership
}



compile_vendor_plugin() {
    local key="$1" source_name="$2" output_name="$3"
    local source compiler temp_output compile_log
    compiler="${GAME_DIR}/addons/sourcemod/scripting/spcomp"
    source="$(find "${TEMP_DIR}/${key}" -type f -name "${source_name}" -print -quit)"
    [[ -n "${source}" ]] || die "Required vendor source is missing: ${key}/${source_name}"
    [[ -x "${compiler}" ]] || die "SourcePawn compiler is missing: ${compiler}"

    install -d "${TEMP_DIR}/vendor-smx"
    temp_output="${TEMP_DIR}/vendor-smx/${output_name}"
    compile_log="${TEMP_DIR}/vendor-${output_name}.log"
    if (cd "$(dirname "${source}")" && "${compiler}" \
            -iinclude \
            -i"${GAME_DIR}/addons/sourcemod/scripting/include" \
            "${source_name}" -o"${temp_output}") >"${compile_log}" 2>&1; then
        log "Staged vendor ${source_name} -> ${output_name}"
    else
        sed -n '1,160p' "${compile_log}" >&2
        die "Vendor SourcePawn compilation failed: ${source_name}"
    fi
}

install_gameplay_packages() {
    local key archive extract_root root package_dir plugin_dir base
    local -a bundle_keys=(fbef_plugins wyxls_plugins dual_primary predicaments votekick no_friendly_fire smac multicolors)
    for key in "${bundle_keys[@]}"; do
        archive="${TEMP_DIR}/${key}.tar.gz"
        download_artifact "${key}" "${archive}"
        extract_root="${TEMP_DIR}/${key}"
        install -d "${extract_root}"
        tar -xzf "${archive}" -C "${extract_root}"
    done

    install -d "${GAME_DIR}/addons/sourcemod/plugins" \
        "${GAME_DIR}/addons/sourcemod/gamedata" \
        "${GAME_DIR}/addons/sourcemod/data" \
        "${GAME_DIR}/addons/sourcemod/configs" \
        "${GAME_DIR}/addons/sourcemod/translations" \
        "${GAME_DIR}/addons/sourcemod/scripting/include" \
        "${GAME_DIR}/cfg/sourcemod"

    # These repositories publish each plugin as a complete package directory.
    # Copy only runtime companions; README/images/source are not runtime input.
    for key in fbef_plugins wyxls_plugins; do
        while IFS= read -r -d '' plugin_dir; do
            base="${plugin_dir%/plugins}"
            case "${base}" in *BasicEnvs*) continue ;; esac
            find "${plugin_dir}" -maxdepth 1 -type f -name '*.smx' -exec install -m 0644 {} "${GAME_DIR}/addons/sourcemod/plugins/" \;
            for package_dir in gamedata data translations; do
                [[ -d "${base}/${package_dir}" ]] && rsync -a "${base}/${package_dir}/" "${GAME_DIR}/addons/sourcemod/${package_dir}/"
            done
            [[ -d "${base}/scripting/include" ]] && rsync -a "${base}/scripting/include/" "${GAME_DIR}/addons/sourcemod/scripting/include/"
            [[ -d "${base}/cfg" ]] && rsync -a "${base}/cfg/" "${GAME_DIR}/cfg/"
            [[ -d "${base}/configs" ]] && rsync -a "${base}/configs/" "${GAME_DIR}/cfg/sourcemod/"
        done < <(find "${TEMP_DIR}/${key}" -type d -name plugins -print0)
    done

    # The remaining fixed sources may publish either a runtime plugin or a
    # source/include pair. Install every runtime companion when present.
    for key in dual_primary predicaments votekick no_friendly_fire smac; do
        find "${TEMP_DIR}/${key}" -type f -name '*.smx' -exec install -m 0644 {} "${GAME_DIR}/addons/sourcemod/plugins/" \;
        find "${TEMP_DIR}/${key}" -type d -name gamedata -exec rsync -a {}/ "${GAME_DIR}/addons/sourcemod/gamedata/" \;
        find "${TEMP_DIR}/${key}" -type d -name data -exec rsync -a {}/ "${GAME_DIR}/addons/sourcemod/data/" \;
        find "${TEMP_DIR}/${key}" -type d -name translations -exec rsync -a {}/ "${GAME_DIR}/addons/sourcemod/translations/" \;
        find "${TEMP_DIR}/${key}" -type d -name configs -exec rsync -a {}/ "${GAME_DIR}/addons/sourcemod/configs/" \;
        find "${TEMP_DIR}/${key}" -type d -name cfg -exec rsync -a {}/ "${GAME_DIR}/cfg/" \;
        find "${TEMP_DIR}/${key}" -type d -path '*/scripting/include' -exec rsync -a {}/ "${GAME_DIR}/addons/sourcemod/scripting/include/" \;
    done

    # MultiColors is an include-only dependency required while compiling SMAC.
    # Preserve its nested multicolors/ directory because multicolors.inc imports it.
    while IFS= read -r -d '' package_dir; do
        rsync -a "${package_dir}/" "${GAME_DIR}/addons/sourcemod/scripting/include/"
    done < <(find "${TEMP_DIR}/multicolors" -type d -path '*/scripting/include' -print0)

    # These pinned repositories publish source only. Compile the exact runtime
    # profile after all includes are installed and replace plugins atomically.
    compile_vendor_plugin dual_primary dual_primaries.sp dual_primaries.smx
    compile_vendor_plugin votekick l4d_votekick.sp l4d_votekick.smx
    compile_vendor_plugin smac smac.sp smac.smx
    compile_vendor_plugin smac smac_aimbot.sp smac_aimbot.smx
    compile_vendor_plugin smac smac_commands.sp smac_commands.smx
    compile_vendor_plugin smac smac_cvars.sp smac_cvars.smx
    compile_vendor_plugin smac smac_l4d2_fixes.sp smac_l4d2_fixes.smx
    compile_vendor_plugin smac smac_speedhack.sp smac_speedhack.smx

    # Publish the selected vendor profile only after every source compiled.
    for base in dual_primaries.smx l4d_votekick.smx smac.smx smac_aimbot.smx \
        smac_commands.smx smac_cvars.smx smac_l4d2_fixes.smx smac_speedhack.smx; do
        install -m 0644 "${TEMP_DIR}/vendor-smx/${base}" "${GAME_DIR}/addons/sourcemod/plugins/${base}"
    done

    # Keep the project-owned pve_pvpve profile and all private/runtime data.
    log "Installed fixed-source gameplay packages and companion files."
}

compile_plugins() {
    local scripting="${GAME_DIR}/addons/sourcemod/scripting"
    local compiler="${scripting}/spcomp"
    local plugins="${GAME_DIR}/addons/sourcemod/plugins"
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
        "l4d2_end_safearea_teleport.sp:l4d2_end_safearea_teleport.smx"
        "l4d2_pve_admin.sp:l4d2_pve_admin.smx"
        "l4d2_pve_help_menu.sp:l4d2_pve_help_menu.smx"
        "l4d2_pve_infected_core.sp:l4d2_pve_infected_core.smx"
        "l4d2_switch_upgrade_ammo.sp:l4d2_switch_ammo.smx"
        "third_party/dual_primaries.sp:dual_primaries.smx"
        "third_party/l4d2_double_jump.sp:l4d2_double_jump.smx"
        "third_party/miuwiki_autoscar.sp:miuwiki_autoscar.smx"
        "l4d2_pve_damage_display.sp:l4d2_pve_damage_display.smx"
        "l4d2_playable_witch.sp:l4d2_playable_witch.smx"
        "l4d2_pve_mutant_tanks.sp:l4d2_pve_mutant_tanks.smx"
        "third_party/command_buffer.sp:command_buffer.smx"
    )

    [[ -x "${compiler}" ]] || die "SourcePawn compiler is missing: ${compiler}"
    install -d -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" "${plugins}"
    log "Compiling project SourcePawn plugins. Existing SMX files are replaced only after success."

    for item in "${entries[@]}"; do
        relative="${item%%:*}"
        output="${item##*:}"
        source="${scripting}/${relative}"
        temp_output="${TEMP_DIR}/${output}"
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
            install -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" -m 0644 \
                "${temp_output}" "${plugins}/${output}"
            log "Compiled ${relative} -> ${output}"
        else
            failures=$((failures + 1))
            warn "Compilation failed for ${relative}; retained the existing ${output}."
            sed -n '1,160p' "${compile_log}" >&2
        fi
    done

    if (( failures > 0 )); then
        die "${failures} 个必需 SourcePawn 插件缺失或编译失败；已保留旧 SMX，停止部署。"
    fi
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
Restart=on-failure
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
    sync_project_tree
    set_runtime_ownership
    install_steamcmd
    install_frameworks
    if [[ "${SKIP_FRAMEWORKS}" != "1" ]]; then
        install_gameplay_packages
    fi
    write_private_configuration
    install_steamclient_link
    compile_plugins
    install_services
    start_services

    log "Installation/update completed."
    log "Game service: systemctl status l4d2 --no-pager -l"
    log "Web service:  systemctl status l4d2-web-admin --no-pager -l"
    log "Private credentials remain in ${PRIVATE_CFG} and ${WEB_ENV}."
}

main
