#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT_DIR="${L4D2_TARGET_ROOT:-/opt/l4d2}"
GAME_DIR="$ROOT_DIR/server/left4dead2"
WEB_ENV="${L4D2_WEB_ENV:-/etc/l4d2/l4d2-admin.env}"
RUNTIME_CFG="$GAME_DIR/cfg/pve_runtime.cfg"
MOTD_FILE="$GAME_DIR/motd.txt"
HELP_TEXT_FILE="$GAME_DIR/cfg/sourcemod/l4d2_pve_help_menu_content.txt"
WELCOME_FILE="$GAME_DIR/cfg/sourcemod/l4d2_pve_welcome.txt"
HELP_KV_FILE="$GAME_DIR/addons/sourcemod/configs/pve_help_content.cfg"
HOSTNAME_FILE="$GAME_DIR/addons/sourcemod/configs/pve_hostname.txt"
INFECTED_BOTS_CFG="$GAME_DIR/addons/sourcemod/data/l4dinfectedbots/pve_pvpve.cfg"
RESERVED_CFG="$GAME_DIR/cfg/sourcemod/l4d_reservedslots.cfg"
DIRECTOR_CFG="$GAME_DIR/cfg/sourcemod/l4d2_pve_director_controller.cfg"
ADMINS_FILE="$GAME_DIR/addons/sourcemod/configs/admins_simple.ini"
RELEASE_PASSWORD_FILE="${L4D2_RELEASE_PASSWORD_FILE:-${L4D2_ETC_ROOT:-/etc/l4d2}/release_password}"
DOWNLOAD_CACHE_DIR="${L4D2_DOWNLOAD_CACHE_DIR:-/var/cache/l4d2}"
log(){ printf '[l4d2ctl] %s\n' "$*"; }
die(){ printf '[l4d2ctl] 错误：%s\n' "$*" >&2; exit 1; }
load_env(){ [[ -r "$WEB_ENV" ]] || die "缺少 $WEB_ENV"; set -a; source "$WEB_ENV"; set +a; RCON_HOST=${RCON_HOST:-127.0.0.1}; RCON_PORT=${RCON_PORT:-27015}; RCON_PASSWORD=${RCON_PASSWORD:-}; }
rcon(){ [[ -n "$RCON_PASSWORD" ]] || die '未配置 RCON_PASSWORD'; RCON_HOST="$RCON_HOST" RCON_PORT="$RCON_PORT" PYTHONPATH="$ROOT_DIR/scripts" RCON_PASSWORD="$RCON_PASSWORD" python3 -c 'import os,sys; from l4d2_web_admin import Rcon; r=Rcon(os.environ["RCON_HOST"],int(os.environ["RCON_PORT"]),os.environ["RCON_PASSWORD"]); r.__enter__();
try: print(r.command(sys.argv[1]),end="")
finally: r.__exit__()' "$*"; }
read_release_password(){ local password="${L4D2_RELEASE_ZIP_PASSWORD:-}"; if [[ -z "$password" && -r "$RELEASE_PASSWORD_FILE" ]]; then password="$(<"$RELEASE_PASSWORD_FILE")"; fi; if [[ -z "$password" ]]; then [[ -r /dev/tty ]] || die '当前不是交互终端；请设置 L4D2_RELEASE_ZIP_PASSWORD 或创建 /etc/l4d2/release_password 后重试。'; printf '请输入发布包 ZIP 解压密码： ' >/dev/tty; IFS= read -r -s password </dev/tty || die '无法读取 ZIP 解压密码'; printf '\n' >/dev/tty; fi; [[ "$password" =~ ^[A-Za-z0-9]{8,128}$ ]] || die 'ZIP 解压密码必须为8-128位字母或数字'; printf '%s' "$password"; }
update_from_release() (
  local url="${L4D2_RELEASE_ARCHIVE_URL:-http://38.147.191.100/l4d2-cn77-release.zip}" sha="${L4D2_RELEASE_ARCHIVE_SHA256:-}" sha_url="${L4D2_RELEASE_ARCHIVE_SHA256_URL:-}" tmp='' archive source zip_password
  local archive_name partial partial_sha
  cleanup_release_tmp(){
    local status=$?
    if [[ -n "$tmp" && -d "$tmp" ]]; then
      find "$tmp" -depth -delete || printf '[l4d2ctl] 警告：无法完整清理发布临时目录：%s\n' "$tmp" >&2
    fi
    return "$status"
  }
  trap cleanup_release_tmp EXIT
  [[ -n "$url" ]] || die '更新需要 L4D2_RELEASE_ARCHIVE_URL；更新不从运行目录执行版本控制操作'
  [[ "$url" == https://* || "$url" == http://66.45.226.118:27816/* || "$url" == http://38.147.191.100/* ]] || die '发布归档 URL 必须使用 HTTPS，或使用受信任的 66 发布地址/38 中转地址'
  if [[ -z "$sha" ]]; then
    [[ -n "$sha_url" ]] || sha_url="${url}.sha256"
    sha="$(curl -fsL --retry 3 --retry-delay 1 --connect-timeout 20 "$sha_url" | awk 'NF && $1 !~ /^#/ {print $1; exit}')"
  fi
  [[ "$sha" =~ ^[0-9a-fA-F]{64}$ ]] || die '更新需要完整的 L4D2_RELEASE_ARCHIVE_SHA256，或可访问发布端的 .sha256 文件'
  archive_name="${url%%\?*}"
  archive_name="${archive_name##*/}"
  [[ "$archive_name" =~ ^[A-Za-z0-9._-]+$ ]] || die "无法从发布归档 URL 得到安全文件名：$archive_name"
  install -d -m 0700 "$DOWNLOAD_CACHE_DIR"
  tmp=$(mktemp -d /tmp/l4d2ctl-release.XXXXXX)
  archive="$DOWNLOAD_CACHE_DIR/$archive_name"
  partial="$archive.part"
  partial_sha="$archive.part.sha256"
  if [[ -f "$archive" ]]; then
    if ! printf '%s  %s\n' "$sha" "$archive" | sha256sum -c - >/dev/null; then
      log "本地发布归档校验不匹配，保留旧文件并重新下载。"
      mv -f "$archive" "$archive.invalid.$(date +%s).$$"
    fi
  fi
  if [[ ! -f "$archive" ]]; then
    if [[ -s "$partial" ]] && [[ ! -f "$partial_sha" || "$(<"$partial_sha")" != "${sha,,}" ]]; then
      log "未完成的发布归档属于旧版本或缺少版本标记，已隔离后重新下载。"
      mv -f "$partial" "$partial.invalid.$(date +%s).$$"
    fi
    printf '%s\n' "${sha,,}" >"$partial_sha"
    if [[ -s "$partial" ]]; then
      log "发现未完成的发布归档，继续传输：$(du -h "$partial" | awk '{print $1}')"
      curl -fL -C - --retry 5 --retry-delay 2 --connect-timeout 20 "$url" -o "$partial"
    else
      curl -fL --retry 5 --retry-delay 2 --connect-timeout 20 "$url" -o "$partial"
    fi
    if ! printf '%s  %s\n' "$sha" "$partial" | sha256sum -c - >/dev/null; then
      mv -f "$partial" "$partial.invalid.$(date +%s).$$"
      die '发布归档 SHA-256 校验失败，错误文件已隔离'
    fi
    mv -f "$partial" "$archive"
    unlink "$partial_sha" 2>/dev/null || true
  fi
  mkdir "$tmp/source"
  case "$url" in
    *.zip|*.zip\?*) zip_password="$(read_release_password)"; unzip -q -P "$zip_password" "$archive" -d "$tmp/source" || die 'ZIP 解压失败，请确认密码正确且发布包完整。';;
    *) tar -xzf "$archive" -C "$tmp/source";;
  esac
  source=$(find "$tmp/source" -type f -path '*/scripts/bootstrap_l4d2.sh' -printf '%h/..\n' -quit)
  [[ -n "$source" && -x "$source/scripts/bootstrap_l4d2.sh" ]] || die '归档中缺少 scripts/bootstrap_l4d2.sh'
  source=$(cd "$source" && pwd)
  log '使用已校验的发布归档执行非破坏性更新。'
  L4D2_TARGET_ROOT="$ROOT_DIR" L4D2_SOURCE_ROOT="$source" L4D2_SKIP_FRAMEWORKS=1 \
    "$source/scripts/bootstrap_l4d2.sh" --update --no-start
  if [[ -f "$source/systemd/l4d2-steam-update.service" && -f "$source/systemd/l4d2-steam-update.timer" ]]; then
    install -m 0644 "$source/systemd/l4d2-steam-update.service" /etc/systemd/system/l4d2-steam-update.service
    install -m 0644 "$source/systemd/l4d2-steam-update.timer" /etc/systemd/system/l4d2-steam-update.timer
    systemctl daemon-reload
    systemctl enable --now l4d2-steam-update.timer
  fi
  systemctl restart l4d2.service
  systemctl restart l4d2-web-admin.service 2>/dev/null || true
)
game_update(){ [[ -x "$ROOT_DIR/scripts/update_steamcmd.sh" ]] || die "缺少 $ROOT_DIR/scripts/update_steamcmd.sh"; "$ROOT_DIR/scripts/update_steamcmd.sh"; }
service(){ case "$1" in start) systemctl start l4d2.service;; stop) systemctl stop l4d2.service;; restart) systemctl restart l4d2.service;; update) update_from_release;; game-update) game_update;; *) die "未知服务命令 $1";; esac; }
write_cvar(){ local key=$1 val=$2 tmp; install -d "$(dirname "$RUNTIME_CFG")"; tmp=$(mktemp); [[ -f "$RUNTIME_CFG" ]] && awk -v k="$key" '$1!=k{print}' "$RUNTIME_CFG" >"$tmp"; printf '%s %s\n' "$key" "$val" >>"$tmp"; install -m0644 "$tmp" "$RUNTIME_CFG"; rm -f "$tmp"; }
write_sm_cvar(){ local key=$1 val=$2 tmp; install -d "$(dirname "$RUNTIME_CFG")"; tmp=$(mktemp); [[ -f "$RUNTIME_CFG" ]] && awk -v k="$key" '!($1==k || ($1=="sm_cvar" && $2==k)){print}' "$RUNTIME_CFG" >"$tmp"; printf 'sm_cvar %s %s\n' "$key" "$val" >>"$tmp"; install -m0644 "$tmp" "$RUNTIME_CFG"; rm -f "$tmp"; }
write_cfg_cvar(){ local file=$1 key=$2 val=$3 tmp; [[ -f "$file" ]] || die "缺少 $file"; tmp=$(mktemp); awk -v k="$key" -v v="$val" 'BEGIN{done=0} $1==k{print k " \"" v "\"";done=1;next} {print} END{if(!done) print k " \"" v "\""}' "$file" >"$tmp"; install -m0644 "$tmp" "$file"; rm -f "$tmp"; }
q(){ local v=$1; v=${v//\\/\\\\}; v=${v//\"/\\\"}; printf '"%s"' "$v"; }
set_name(){ local tmp; [[ -n "$1" && ${#1} -le 64 && "$1" != *$'\n'* ]] || die '大厅名称无效'; install -d "$(dirname "$HOSTNAME_FILE")"; tmp=$(mktemp); printf '%s\n' "$1" >"$tmp"; install -m0644 "$tmp" "$HOSTNAME_FILE"; rm -f "$tmp"; write_cvar hostname '"CN 77 Infinite Fire"'; rcon sm_pvehostname_reload >/dev/null || true; log "大厅名称：$1"; }
set_slots(){ [[ "$1" =~ ^[0-9]+$ && $1 -ge 1 && $1 -le 16 ]] || die '公开真人位必须是1-16'; write_cfg_cvar "$RESERVED_CFG" pve_public_human_slots "$1"; write_cvar sv_visiblemaxplayers "$1"; write_cvar sv_maxplayers 31; rcon "pve_public_human_slots $1; sv_visiblemaxplayers $1; sv_maxplayers 31" || true; log "公开真人位：$1；引擎 MaxClients：31"; }
set_difficulty(){ case "$1" in Easy|Normal|Hard|Impossible|Expert);;*) die '难度无效';;esac; write_cvar z_difficulty "$1"; rcon "z_difficulty $1" || true; }
set_si(){ [[ "$1" =~ ^[0-9]+$ && $1 -ge 1 && $1 -le 12 ]] || die 'SI硬上限必须是1-12'; write_cfg_cvar "$DIRECTOR_CFG" l4d2_pve_director_hard_cap "$1"; rcon "l4d2_pve_director_hard_cap $1" >/dev/null || true; log "SI硬上限：$1（Dynamic Director Owner）"; }
set_interval(){ local min=$1 max=${2:-$1}; [[ "$min" =~ ^[0-9]+([.][0-9]+)?$ && "$max" =~ ^[0-9]+([.][0-9]+)?$ ]] || die 'SI波次区间无效'; awk -v min="$min" -v max="$max" 'BEGIN{exit !(min>=3 && max>=min && max<=180)}' || die 'SI波次必须满足 3 <= min <= max <= 180'; write_cfg_cvar "$DIRECTOR_CFG" l4d2_pve_director_normal_spawn_min "$min"; write_cfg_cvar "$DIRECTOR_CFG" l4d2_pve_director_normal_spawn_max "$max"; rcon "l4d2_pve_director_normal_spawn_min $min; l4d2_pve_director_normal_spawn_max $max" >/dev/null || true; log "NORMAL SI波次区间：$min-$max 秒（Dynamic Director Owner）"; }
set_common(){ [[ "$1" =~ ^[0-9]+$ && $1 -le 300 ]] || die '普通感染者数量必须是0-300'; write_sm_cvar z_common_limit "$1"; rcon "sm_cvar z_common_limit $1" >/dev/null; log "普通感染者数量：$1"; }
set_text(){ local file=$1 label=$2 tmp; tmp=$(mktemp); cat >"$tmp"; install -m0644 "$tmp" "$file"; rm -f "$tmp"; log "$label已保存"; }
regen_help(){ PYTHONPATH="$ROOT_DIR/scripts" HELP_TEXT_FILE="$HELP_TEXT_FILE" WELCOME_FILE="$WELCOME_FILE" HELP_KV_FILE="$HELP_KV_FILE" python3 -c 'import os; from pathlib import Path; h=Path(os.environ["HELP_TEXT_FILE"]); w=Path(os.environ["WELCOME_FILE"]); o=Path(os.environ["HELP_KV_FILE"]); hl=h.read_text(encoding="utf-8").splitlines() if h.exists() else []; wl=w.read_text(encoding="utf-8").splitlines() if w.exists() else []; ann=wl[0] if wl else "[开始菜单] 输入 !菜单 或 !pvehelp 打开中文帮助；按 H 可查看服务器帮助页。"; esc=lambda x:x.replace("\\","\\\\").replace(chr(34),"\\\"").replace("\\n"," "); lines=[chr(34)+"PvEHelp"+chr(34),"{", "    \"title\" \"无限火力 PvPvE 开始菜单\"", "    \"announcement\" \""+esc(ann)+"\"", "    \"details\"", "    {"]; lines += [f"        \"{i}\" \"{esc(x)}\"" for i,x in enumerate(hl[:12],1) if x.strip()]; lines += ["    }", "    \"commands\"", "    {"]; cmds=["!菜单 / !pvehelp：打开开始菜单","!buy / !shop：打开商城","!points / !money：查看积分","!infected / !特感：加入感染者","!survivor / !人类：返回幸存者","!zclass / !特感选择：选择普通特感","!tankqueue：加入 Tank 抽签","!notank：退出 Tank 抽签","!witchqueue / !nowitch：加入 / 退出 Witch 抽签","!hud：切换个人全局 HUD 显示","!overdrive：查看临时强化与冷却状态","!pveperf：查看 Entity、SI、Common 与风险级别"]; lines += [f"        \"{i}\" \"{esc(x)}\"" for i,x in enumerate(cmds,1)]; lines += ["    }","}"]; o.parent.mkdir(parents=True,exist_ok=True); t=o.with_suffix(o.suffix+".tmp"); t.write_text("\\n".join(lines)+"\\n",encoding="utf-8"); t.replace(o)'; }
set_motd(){ set_text "$MOTD_FILE" MOTD; }
set_help(){ set_text "$HELP_TEXT_FILE" 'H菜单帮助'; regen_help; }
set_welcome(){ set_text "$WELCOME_FILE" '进房公告'; regen_help; }
set_admin(){ local id=$1 flags=${2:-z} tmp; [[ "$id" =~ ^(STEAM_[0-5]:[01]:[0-9]+|\[U:[0-9]+:[0-9]+\]|7656119[0-9]{10,})$ ]] || die 'SteamID无效'; [[ "$flags" =~ ^[a-z]+$ ]] || die 'flags无效'; install -d "$(dirname "$ADMINS_FILE")"; tmp=$(mktemp); [[ -f "$ADMINS_FILE" ]] && awk -v id="$id" '$0 !~ "^[[:space:]]*\\\"" id "\\\""{print}' "$ADMINS_FILE" >"$tmp"; printf '"%s" "99:%s"\n' "$id" "$flags" >>"$tmp"; install -m0644 "$tmp" "$ADMINS_FILE"; rm -f "$tmp"; rcon sm_reloadadmins || true; log "管理员：$id 99:$flags"; }
kick(){ [[ "$1" =~ ^[0-9]+$ ]] || die 'UserID无效'; rcon "kickid $1"; }
points(){ [[ "$1" =~ ^[0-9]+$ && "$2" =~ ^-?[0-9]+$ ]] || die 'UserID或积分无效'; rcon "sm_pveaddpoints #$1 $2"; }
set_web(){ local bind=$1 port=$2 user=$3 pass='' tmp; read -r pass || true; [[ "$bind" =~ ^([0-9]{1,3}[.]){3}[0-9]{1,3}$|^::1$|^0.0.0.0$ ]] || die '监听地址无效'; [[ "$port" =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]] || die '网页端口无效'; [[ "$user" =~ ^[A-Za-z0-9_.-]{1,32}$ ]] || die '网页账户无效'; [[ -z "$pass" || ${#pass} -ge 8 ]] || die '网页密码至少8位'; tmp=$(mktemp); awk '!/^(WEB_BIND|WEB_PORT|WEB_USER|WEB_PASSWORD)=/' "$WEB_ENV" >"$tmp" || true; printf 'WEB_BIND="%s"\nWEB_PORT="%s"\nWEB_USER="%s"\n' "$bind" "$port" "$user" >>"$tmp"; if [[ -n "$pass" ]]; then printf 'WEB_PASSWORD="%s"\n' "$pass" >>"$tmp"; else grep '^WEB_PASSWORD=' "$WEB_ENV" >>"$tmp" || die '缺少旧网页密码'; fi; install -o root -g root -m0600 "$tmp" "$WEB_ENV"; rm -f "$tmp"; systemctl restart l4d2-web-admin.service 2>/dev/null || true; }
health(){
  local failed=0 plugins='' active_plugins='' plugin_info='' plugin_rel='' extensions='' meta='' journal='' active_since='' value='' key='' count=0 public_slots='' reserved_slots=''
  health_fail(){ log "FAIL: $*"; failed=1; }

  [[ -x "$ROOT_DIR/server/srcds_run" ]] || health_fail "缺少 srcds_run"
  [[ -x "$GAME_DIR/addons/sourcemod/scripting/spcomp" ]] || health_fail "缺少 spcomp"
  [[ -f "$GAME_DIR/cfg/server_private.cfg" ]] || health_fail "缺少 RCON 私密配置"
  systemctl is-active --quiet l4d2.service || health_fail "l4d2 未运行"
  ss -lun 2>/dev/null | grep -q ':27015 ' || health_fail "27015/UDP 未监听"

  for key in \
    "$GAME_DIR/addons/sourcemod/gamedata/command_buffer.games.txt" \
    "$GAME_DIR/addons/sourcemod/gamedata/WeaponHandling.txt" \
    "$GAME_DIR/addons/sourcemod/gamedata/physics_object_pushfix.txt" \
    "$GAME_DIR/addons/sourcemod/gamedata/l4dinfectedbots.txt" \
    "$GAME_DIR/addons/sourcemod/gamedata/spawn_infected_nolimit.txt" \
    "$GAME_DIR/addons/sourcemod/gamedata/left4dhooks.l4d2.txt" \
    "$GAME_DIR/addons/sourcemod/scripting/include/left4dhooks.inc" \
    "$GAME_DIR/addons/sourcemod/scripting/include/weaponhandling.inc"; do
    [[ -f "$key" ]] || health_fail "缺少依赖文件：$key"
  done

  if ! plugins="$(rcon 'sm plugins list' 2>/dev/null)"; then
    health_fail "无法读取 sm plugins list"
  fi

  active_plugins="$(find "$GAME_DIR/addons/sourcemod/plugins" -type f -name '*.smx' ! -path '*/disabled/*' -printf '%P\n' | sort)"
  if [[ -z "$active_plugins" ]]; then
    health_fail "Runtime 没有 active SourceMod 插件"
  else
    while IFS= read -r plugin_rel; do
      [[ -n "$plugin_rel" ]] || continue
      plugin_info="$(rcon "sm plugins info $plugin_rel" 2>/dev/null || true)"
      if ! printf '%s\n' "$plugin_info" | grep -Eq 'Status:[[:space:]]+running'; then
        health_fail "插件未运行：$plugin_rel"
      fi
    done <<<"$active_plugins"

    for key in \
      no_friendly-fire.smx l4d_reservedslots.smx l4d_kickloadstuckers.smx \
      l4d2_pve_infected_core.smx l4d2_playable_witch.smx WeaponHandling.smx \
      l4d2_pve_overdrive.smx l4d2_pve_server_hud.smx spawn_infected_nolimit.smx \
      l4dinfectedbots.smx l4d2_pve_director_controller.smx l4d2_pve_antirush.smx \
      l4d2_pve_perf_guard.smx l4d2_pve_corpse_cleaner.smx l4d2_restart_empty.smx \
      l4d2_end_safearea_teleport.smx physics_object_pushfix.smx \
      dual_primaries.smx l4d2_switch_ammo.smx; do
      printf '%s\n' "$active_plugins" | grep -Fqx "$key" || health_fail "缺少必需 active 插件：$key"
    done

    count="$(printf '%s\n' "$active_plugins" | grep -Eic '(^|/)(no_friendly-fire|anti-friendly_fire[^/]*|l4dffannounce[^/]*|[^/]*friendly.?fire.?damage[^/]*)[.]smx$' || true)"
    [[ "$count" -eq 1 ]] || health_fail "Friendly Fire controller 数量异常：$count"
    count="$(printf '%s\n' "$active_plugins" | grep -Eic '(^|/)(l4dinfectedbots|NekoSpecials|l4d2_boss_spawn|l4d2_si_spawn_control|manual[-_].*spawn.*infected)[.]smx$' || true)"
    [[ "$count" -eq 1 ]] || health_fail "SI Spawn controller 数量异常：$count"
    count="$(printf '%s\n' "$active_plugins" | grep -Eic '(^|/)(l4d2_pve_infected_core|l4d2_boss_spawn|tank_spawn_controller|tank_spawner|l4d2_tank_limit)[.]smx$' || true)"
    [[ "$count" -eq 1 ]] || health_fail "Tank Gate/Spawn controller 数量异常：$count"
    count="$(printf '%s\n' "$active_plugins" | grep -Eic '(^|/)(l4d2_playable_witch|l4d2_multi_witches|l4d2_boss_spawn|witch_controller)[.]smx$' || true)"
    [[ "$count" -eq 1 ]] || health_fail "Witch controller 数量异常：$count"
    count="$(printf '%s\n' "$active_plugins" | grep -Eic '(^|/)(l4d2_pve_antirush|no-rushing|[^/]*antirush[^/]*)[.]smx$' || true)"
    [[ "$count" -eq 1 ]] || health_fail "AntiRush controller 数量异常：$count"
    count="$(printf '%s\n' "$active_plugins" | grep -Eic '(^|/)(l4d2_restart_empty|l4d2_auto_restart|[^/]*restart[^/]*empty[^/]*)[.]smx$' || true)"
    [[ "$count" -eq 1 ]] || health_fail "Empty Restart controller 数量异常：$count"
    count="$(printf '%s\n' "$active_plugins" | grep -Eic '(^|/)(l4d2_pve_server_hud|NekoKillHud|[^/]*server_hud[^/]*)[.]smx$' || true)"
    [[ "$count" -eq 1 ]] || health_fail "Global HUD controller 数量异常：$count"

    if printf '%s\n' "$active_plugins" | grep -Eiq '(^|/)survivor.?identity.?fix[^/]*[.]smx$' \
      && printf '%s\n' "$active_plugins" | grep -Eiq '(^|/)(deadbot|l4dafkfix_deadbot)[.]smx$'; then
      health_fail "Survivor Identity Fix 与 deadbot 同时加载"
    fi
    printf '%s\n' "$active_plugins" | grep -Eiq '(^|/)(NekoSpecials|NekoVote|NekoKillHud|l4d2_boss_spawn)[.]smx$' \
      && health_fail "禁止的 Neko/第二 Boss 组件已加载"
    printf '%s\n' "$active_plugins" | grep -Eiq '(^|/)(no-rushing|l4d2_predicaments|manual[-_].*spawn.*infected)[.]smx$' \
      && health_fail "旧 AntiRush/高频 Predicaments/未受限 Spawn 插件仍在加载"
  fi
  extensions="$(rcon 'sm exts list' 2>/dev/null || true)"
  meta="$(rcon 'meta list' 2>/dev/null || true)"
  [[ -n "$extensions" ]] || health_fail "无法读取 sm exts list"
  [[ -n "$meta" ]] || health_fail "无法读取 meta list"
  printf '%s\n%s\n' "$extensions" "$meta" | grep -Eiq '<FAILED>|<ERROR>|error loading|failed to load' && health_fail "MetaMod/SourceMod 扩展加载失败"

  for key in nff_blockguns nff_blockmelee nff_blockfires nff_blockexplosions nff_survivors nff_infected; do
    value="$(rcon "$key" 2>/dev/null || true)"
    printf '%s\n' "$value" | grep -Eq '"'"$key"'"[[:space:]]*=[[:space:]]*"1"' || health_fail "$key != 1"
  done
  log "Friendly Fire human verification: NOT HUMAN VERIFIED"

  value="$(rcon 'l4d_infectedbots_version' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '3\.0\.8-pve\.1' || health_fail "未加载项目审计版 InfectedBots"
  value="$(rcon 'sm_spawn_infected_nolimit_version' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '1\.6h-pve\.1' || health_fail "未加载受限 Spawn API"
  value="$(rcon 'weaponhandling_version' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"weaponhandling_version"[[:space:]]*=[[:space:]]*"1\.0\.7"' || health_fail "WeaponHandling != 1.0.7"
  value="$(rcon 'l4d2_pve_overdrive_enable' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"l4d2_pve_overdrive_enable"[[:space:]]*=[[:space:]]*"1"' || health_fail "Overdrive 未启用"
  value="$(rcon 'pve_playable_witch_random_chance' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"pve_playable_witch_random_chance"[[:space:]]*=[[:space:]]*"35\.0+"' || health_fail "Witch 章节抽奖概率 != 35%"
  value="$(rcon 'pve_playable_witch_lottery_flow_min' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"pve_playable_witch_lottery_flow_min"[[:space:]]*=[[:space:]]*"25\.0+"' || health_fail "Witch lottery flow min != 25%"
  value="$(rcon 'pve_playable_witch_lottery_flow_max' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"pve_playable_witch_lottery_flow_max"[[:space:]]*=[[:space:]]*"80\.0+"' || health_fail "Witch lottery flow max != 80%"
  value="$(rcon 'l4d2_pve_admin_gameplay_write_enable' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"l4d2_pve_admin_gameplay_write_enable"[[:space:]]*=[[:space:]]*"0"' || health_fail "管理员直接 Gameplay 写入未关闭"
  value="$(rcon 'l4d2_pve_infected_hud' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"l4d2_pve_infected_hud"[[:space:]]*=[[:space:]]*"0"' || health_fail "感染者 Core 旧 HUD 未关闭"
  value="$(rcon 'l4d2_safearea_owner_version' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"l4d2_safearea_owner_version"[[:space:]]*=[[:space:]]*"1\.1\.0"' || health_fail "安全门 Owner != 1.1.0"
  value="$(rcon 'l4d2_safearea_opener_timeout' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"l4d2_safearea_opener_timeout"[[:space:]]*=[[:space:]]*"120\.0+"' || health_fail "随机开门员超时 != 120 秒"
  value="$(rcon 'l4d2_safearea_final_gate_ratio' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"l4d2_safearea_final_gate_ratio"[[:space:]]*=[[:space:]]*"0\.70+"' || health_fail "最终安全区比例 != 70%"
  value="$(rcon 'l4d2_safearea_final_gate_near_distance' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"l4d2_safearea_final_gate_near_distance"[[:space:]]*=[[:space:]]*"600\.0+"' || health_fail "最终安全区接近距离 != 600"

  grep -Eq '^sm_infected_balancer_si_general_power[[:space:]]+"?0"?$' "$GAME_DIR/cfg/sourcemod/l4d2_balancer_spawn_dyn.cfg" || health_fail "Dynamic Balancer SI power != 0"
  grep -Eq '^sm_infected_balancer_si_dominator_power[[:space:]]+"?0"?$' "$GAME_DIR/cfg/sourcemod/l4d2_balancer_spawn_dyn.cfg" || health_fail "Dynamic Balancer dominator power != 0"
  grep -Eq '^sm_infected_balancer_spawn_interval_power[[:space:]]+"?0"?$' "$GAME_DIR/cfg/sourcemod/l4d2_balancer_spawn_dyn.cfg" || health_fail "Dynamic Balancer interval power != 0"
  grep -Eq '^sm_infected_balancer_tank_balance[[:space:]]+"?0"?$' "$GAME_DIR/cfg/sourcemod/l4d2_balancer_spawn_dyn.cfg" || health_fail "Dynamic Balancer Tank power != 0"
  grep -Eq '^sm_infected_balancer_tank_increase_hp_percent[[:space:]]+"?0"?$' "$GAME_DIR/cfg/sourcemod/l4d2_balancer_spawn_dyn.cfg" || health_fail "Dynamic Balancer Tank HP power != 0"
  grep -Eq '^sm_infected_balancer_versus_like[[:space:]]+"?0"?$' "$GAME_DIR/cfg/sourcemod/l4d2_balancer_spawn_dyn.cfg" || health_fail "Dynamic Balancer versus-like SI bonus != 0"
  for key in \
    sm_infected_balancer_si_general_power \
    sm_infected_balancer_si_dominator_power \
    sm_infected_balancer_spawn_interval_power \
    sm_infected_balancer_tank_balance \
    sm_infected_balancer_tank_increase_hp_percent \
    sm_infected_balancer_versus_like; do
    value="$(rcon "$key" 2>/dev/null || true)"
    printf '%s\n' "$value" | grep -Eq '"'"$key"'"[[:space:]]*=[[:space:]]*"0([.]0+)?"' \
      || health_fail "Runtime $key != 0"
  done
  grep -Eq '^[[:space:]]*"tank_limit"[[:space:]]+"0"' "$INFECTED_BOTS_CFG" || health_fail "InfectedBots Tank limit != 0"
  grep -Eq '^[[:space:]]*"tank_spawn_probability"[[:space:]]+"0"' "$INFECTED_BOTS_CFG" || health_fail "InfectedBots Tank spawn probability != 0"
  grep -Eq '^[[:space:]]*"witch_max_limit"[[:space:]]+"0"' "$INFECTED_BOTS_CFG" || health_fail "InfectedBots Witch limit != 0"
  grep -Eq '^[[:space:]]*"spawn_same_frame"[[:space:]]+"0"' "$INFECTED_BOTS_CFG" || health_fail "InfectedBots spawn_same_frame != 0"
  grep -Eq '^[[:space:]]*"max_specials"[[:space:]]+"12"' "$INFECTED_BOTS_CFG" || health_fail "InfectedBots base max_specials != 12"

  public_slots="$(awk '$1=="pve_public_human_slots"{gsub(/"/,"",$2);print $2}' "$RESERVED_CFG" 2>/dev/null || true)"
  reserved_slots="$(awk '$1=="pve_admin_reserved_slots"{gsub(/"/,"",$2);print $2}' "$RESERVED_CFG" 2>/dev/null || true)"
  [[ "$public_slots" =~ ^(12|13|14|15|16)$ ]] || health_fail "pve_public_human_slots 无效：${public_slots:-missing}"
  [[ "$reserved_slots" =~ ^[1-4]$ ]] || health_fail "pve_admin_reserved_slots 无效：${reserved_slots:-missing}"
  value="$(rcon 'pve_public_human_slots' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"pve_public_human_slots"[[:space:]]*=[[:space:]]*"'"$public_slots"'"' || health_fail "Runtime public slot policy 与配置不一致"
  value="$(rcon 'pve_admin_reserved_slots' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"pve_admin_reserved_slots"[[:space:]]*=[[:space:]]*"'"$reserved_slots"'"' || health_fail "Runtime reserved slot policy 与配置不一致"
  value="$(rcon 'sv_maxplayers' 2>/dev/null || true)"
  printf '%s\n' "$value" | grep -Eq '"sv_maxplayers"[[:space:]]*=[[:space:]]*"31"' || health_fail "sv_maxplayers != 31"

  if active_since="$(systemctl show -p ActiveEnterTimestamp --value l4d2.service 2>/dev/null)" && [[ -n "$active_since" ]]; then
    journal="$(journalctl -u l4d2.service --since "$active_since" --no-pager -o cat 2>/dev/null || true)"
    printf '%s\n' "$journal" | grep -Eiq 'Cbuf_AddText: buffer overflow|KeyValues.*(error|failed)|bad load|missing native|native .* was not found|signature.*not found|Invalid convar handle' && health_fail "当前启动窗口存在 SourceMod/KeyValues/Cbuf/签名错误"
  fi

  if [[ "$failed" -eq 0 ]]; then
    log "PASS: static/runtime owner checks passed; human gameplay checks remain NOT HUMAN VERIFIED"
  fi
  return "$failed"
}
status(){ systemctl status l4d2.service --no-pager -l || true; printf '\n---在线玩家---\n'; rcon status || true; }
menu(){ while true; do printf '\nL4D2 PvPvE运维：1启动 2停止 3重启 4同步发布 5状态 6健康 7在线 8大厅名 9人数 10难度 11SI数量 12SI波次 13普通感染者 14踢人 15积分 16管理员 17MOTD 18H帮助 19进房公告 20网页配置 21检查游戏更新 0退出\n'; read -r -p '请选择：' c; case "$c" in 1)service start;;2)service stop;;3)service restart;;4)service update;;5)status;;6)health||true;;7)rcon status;;8)read -r -p '大厅名：' v;set_name "$v";;9)read -r -p '人数：' v;set_slots "$v";;10)read -r -p '难度：' v;set_difficulty "$v";;11)read -r -p 'SI数量：' v;set_si "$v";;12)read -r -p 'SI波次：' v;set_interval "$v";;13)read -r -p '普通感染者：' v;set_common "$v";;14)read -r -p 'UserID：' v;kick "$v";;15)read -r -p 'UserID：' u;read -r -p '积分：' v;points "$u" "$v";;16)read -r -p 'SteamID：' v;set_admin "$v" z;;17)read -r -p 'MOTD：' v;printf '%s\n' "$v"|set_motd;;18)read -r -p 'H帮助：' v;printf '%s\n' "$v"|set_help;;19)read -r -p '公告：' v;printf '%s\n' "$v"|set_welcome;;20)read -r -p '监听地址：' b;read -r -p '端口：' p;read -r -p '账户：' u;read -r -s -p '新密码：' w;printf '\n';printf '%s\n' "$w"|set_web "$b" "$p" "$u";;21)game_update;;0)return;;*)log '无效选择';;esac; done; }
load_env
[[ $# -eq 0 ]] && { menu; exit 0; }
cmd=$1; shift
case "$cmd" in start|stop|restart|update|game-update)service "$cmd";;status)status;;health)health;;set-name)set_name "$1";;set-slots)set_slots "$1";;set-difficulty)set_difficulty "$1";;set-si-count)set_si "$1";;set-si-interval)set_interval "$1";;set-common-limit)set_common "$1";;kick)kick "$1";;add-points)points "$1" "$2";;set-admin)set_admin "$1" "${2:-z}";;set-motd)set_motd;;set-help-text)set_help;;set-welcome-text)set_welcome;;set-web-config)set_web "$1" "$2" "$3";;*)die "未知命令：$cmd";;esac
