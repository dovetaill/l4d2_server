#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

TARGET_ROOT="/opt/l4d2"
SERVER_DIR="${TARGET_ROOT}/server"
GAME_DIR="${SERVER_DIR}/left4dead2"
STEAMCMD_DIR="${TARGET_ROOT}/steamcmd"
SERVICE_USER="l4d2srv"
SERVICE_GROUP="l4d2srv"
ETC_DIR="/etc/l4d2"
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
TEMP_DIR=""
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

usage() {
    cat <<'EOF'
Usage: sudo ./scripts/bootstrap_l4d2.sh [--update] [--no-start]

  --update    Update an existing non-destructive installation. When this
              script runs inside /opt/l4d2, a clean Git checkout is updated
              with git pull --ff-only before the runtime update.
  --no-start  Install, compile, and create/enable services without starting or
              restarting them.

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
        rm -rf -- "${TEMP_DIR}"
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
        git curl wget ca-certificates file tar gzip xz-utils unzip bzip2 \
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
        if (( UPDATE_ONLY )) && [[ -d "${TARGET_ROOT}/.git" ]]; then
            if git -C "${TARGET_ROOT}" diff --quiet --ignore-submodules -- && \
               git -C "${TARGET_ROOT}" diff --cached --quiet --ignore-submodules --; then
                log "Updating clean /opt/l4d2 checkout with git pull --ff-only."
                git -C "${TARGET_ROOT}" pull --ff-only
            else
                warn "Tracked changes exist in /opt/l4d2; skipped git pull to preserve them."
            fi
        fi
        return
    fi

    log "Synchronizing tracked/non-ignored project files into ${TARGET_ROOT} without deleting runtime files."
    if [[ ! -d "${TARGET_ROOT}/.git" && -d "${PROJECT_ROOT}/.git" ]]; then
        cp -a "${PROJECT_ROOT}/.git" "${TARGET_ROOT}/.git"
    fi
    if [[ -d "${PROJECT_ROOT}/.git" ]]; then
        # Copy the current checkout, including non-ignored worktree additions,
        # without copying ignored Steam/runtime/private state from the source.
        git -C "${PROJECT_ROOT}" ls-files -z --cached --others --exclude-standard | \
            rsync -a --from0 --files-from=- "${PROJECT_ROOT}/" "${TARGET_ROOT}/"
    else
        # A source archive has no Git index. Keep the exclusions explicit and
        # still never use --delete against an existing production directory.
        rsync -a \
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
    [[ ! -d "${SERVER_DIR}" ]] || chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${SERVER_DIR}"
    [[ ! -d "${STEAMCMD_DIR}" ]] || chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${STEAMCMD_DIR}"
    [[ ! -d "${PROJECT_ROOT}/scripts" ]] || chown -R root:root "${PROJECT_ROOT}/scripts"
    [[ ! -d "${TARGET_ROOT}/scripts" ]] || chown -R root:root "${TARGET_ROOT}/scripts"
    [[ ! -d "${TARGET_ROOT}/docs" ]] || chown -R root:root "${TARGET_ROOT}/docs"
    [[ ! -d "${TARGET_ROOT}/.git" ]] || chown -R root:root "${TARGET_ROOT}/.git"
    [[ ! -f "${TARGET_ROOT}/scripts/l4d2ctl.sh" ]] || chmod 0755 "${TARGET_ROOT}/scripts/l4d2ctl.sh"
    [[ ! -f "${TARGET_ROOT}/scripts/l4d2_web_admin.py" ]] || chmod 0755 "${TARGET_ROOT}/scripts/l4d2_web_admin.py"
}

install_steamcmd() {
    install -d -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" "${STEAMCMD_DIR}"
    if [[ ! -x "${STEAMCMD_DIR}/steamcmd.sh" ]]; then
        log "Installing SteamCMD."
        curl -fL --retry 3 "${STEAMCMD_URL}" -o "${TEMP_DIR}/steamcmd.tar.gz"
        tar -xzf "${TEMP_DIR}/steamcmd.tar.gz" -C "${STEAMCMD_DIR}"
        chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${STEAMCMD_DIR}"
    fi

    install -d -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" "${SERVER_DIR}"
    log "Installing/updating L4D2 Dedicated Server AppID 222860 with anonymous SteamCMD."
    local app_command=(+app_update 222860 validate)
    if (( UPDATE_ONLY )); then
        app_command=(+app_update 222860)
    fi
    runuser -u "${SERVICE_USER}" -- \
        "${STEAMCMD_DIR}/steamcmd.sh" \
        +force_install_dir "${SERVER_DIR}" \
        +login anonymous \
        "${app_command[@]}" \
        +quit

    [[ -x "${SERVER_DIR}/srcds_run" ]] || die "SteamCMD completed but ${SERVER_DIR}/srcds_run is missing."
}

install_frameworks() {
    log "Installing MetaMod:Source ${MM_VERSION}."
    curl -fL --retry 3 "${MM_URL}" -o "${TEMP_DIR}/metamod.tar.gz"
    tar -xzf "${TEMP_DIR}/metamod.tar.gz" -C "${GAME_DIR}"

    log "Installing SourceMod ${SM_VERSION}."
    curl -fL --retry 3 "${SM_URL}" -o "${TEMP_DIR}/sourcemod.tar.gz"
    tar -xzf "${TEMP_DIR}/sourcemod.tar.gz" -C "${GAME_DIR}"

    # L4D2 does not support SourceMod's generic nextmap plugin. Keep the
    # framework copy disabled so every fresh bootstrap starts without Bad Load.
    if [[ -f "${GAME_DIR}/addons/sourcemod/plugins/nextmap.smx" ]]; then
        install -d "${GAME_DIR}/addons/sourcemod/plugins/disabled"
        mv -f "${GAME_DIR}/addons/sourcemod/plugins/nextmap.smx" \
            "${GAME_DIR}/addons/sourcemod/plugins/disabled/nextmap.smx"
    fi

    # Reapply project-owned configs and plugins after framework extraction.
    sync_project_tree
    set_runtime_ownership
}

compile_plugins() {
    local scripting="${GAME_DIR}/addons/sourcemod/scripting"
    local compiler="${scripting}/spcomp"
    local plugins="${GAME_DIR}/addons/sourcemod/plugins"
    local failures=0
    local item source relative output temp_output compile_log
    local entries=(
        "l4d2_campaign_shop.sp:l4d2_campaign_shop.smx"
        "l4d2_pve_admin.sp:l4d2_pve_admin.smx"
        "l4d2_pve_help_menu.sp:l4d2_pve_help_menu.smx"
        "l4d2_pve_infected_core.sp:l4d2_pve_infected_core.smx"
        "l4d2_switch_upgrade_ammo.sp:l4d2_switch_ammo.smx"
        "third_party/l4d2_double_jump.sp:l4d2_double_jump.smx"
        "l4d2_pve_damage_display.sp:l4d2_pve_damage_display.smx"
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
        if (cd "${scripting}" && "${compiler}" "${relative}" -o"${temp_output}") >"${compile_log}" 2>&1; then
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
    if [[ -z "${rcon_host}" ]]; then
        rcon_host="$(ip route get 1.1.1.1 2>/dev/null | sed -n -E 's/.* src ([0-9.]+).*/\1/p' | head -n 1)"
    fi
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
    [[ -f "${steamclient}" ]] || return
    home_dir="$(getent passwd "${SERVICE_USER}" | cut -d: -f6)"
    [[ -n "${home_dir}" ]] || return
    install -d -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" "${home_dir}/.steam/sdk32"
    ln -sfn "${steamclient}" "${home_dir}/.steam/sdk32/steamclient.so"
    chown -h "${SERVICE_USER}:${SERVICE_GROUP}" "${home_dir}/.steam/sdk32/steamclient.so"
}

install_services() {
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
    install_dependencies
    ensure_service_user
    sync_project_tree
    set_runtime_ownership
    install_steamcmd
    install_frameworks
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
