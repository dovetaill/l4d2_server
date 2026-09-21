#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT_DIR=/opt/l4d2
GAME_DIR="$ROOT_DIR/server/left4dead2"
WEB_ENV=/etc/l4d2/l4d2-admin.env
RUNTIME_CFG="$GAME_DIR/cfg/pve_runtime.cfg"
MOTD_FILE="$GAME_DIR/motd.txt"
HELP_TEXT_FILE="$GAME_DIR/cfg/sourcemod/l4d2_pve_help_menu_content.txt"
WELCOME_FILE="$GAME_DIR/cfg/sourcemod/l4d2_pve_welcome.txt"
HELP_KV_FILE="$GAME_DIR/addons/sourcemod/configs/pve_help_content.cfg"
ADMINS_FILE="$GAME_DIR/addons/sourcemod/configs/admins_simple.ini"
log(){ printf '[l4d2ctl] %s\n' "$*"; }
die(){ printf '[l4d2ctl] 错误：%s\n' "$*" >&2; exit 1; }
load_env(){ [[ -r "$WEB_ENV" ]] || die "缺少 $WEB_ENV"; set -a; source "$WEB_ENV"; set +a; RCON_HOST=${RCON_HOST:-127.0.0.1}; RCON_PORT=${RCON_PORT:-27015}; RCON_PASSWORD=${RCON_PASSWORD:-}; }
rcon(){ [[ -n "$RCON_PASSWORD" ]] || die '未配置 RCON_PASSWORD'; RCON_HOST="$RCON_HOST" RCON_PORT="$RCON_PORT" PYTHONPATH="$ROOT_DIR/scripts" RCON_PASSWORD="$RCON_PASSWORD" python3 -c 'import os,sys; from l4d2_web_admin import Rcon; r=Rcon(os.environ["RCON_HOST"],int(os.environ["RCON_PORT"]),os.environ["RCON_PASSWORD"]); r.__enter__();
try: print(r.command(sys.argv[1]),end="")
finally: r.__exit__()' "$*"; }
service(){ case "$1" in start) systemctl start l4d2.service;; stop) systemctl stop l4d2.service;; restart) systemctl restart l4d2.service;; update) [[ -d "$ROOT_DIR/.git" ]] || die '没有 Git 工作树'; git -C "$ROOT_DIR" diff --quiet --ignore-submodules -- || die '工作树有未提交改动'; git -C "$ROOT_DIR" diff --cached --quiet --ignore-submodules -- || die '暂存区有未提交改动'; git -C "$ROOT_DIR" pull --ff-only; systemctl restart l4d2.service;; *) die "未知服务命令 $1";; esac; }
write_cvar(){ local key=$1 val=$2 tmp; install -d "$(dirname "$RUNTIME_CFG")"; tmp=$(mktemp); [[ -f "$RUNTIME_CFG" ]] && awk -v k="$key" '$1!=k{print}' "$RUNTIME_CFG" >"$tmp"; printf '%s %s\n' "$key" "$val" >>"$tmp"; install -m0644 "$tmp" "$RUNTIME_CFG"; rm -f "$tmp"; }
q(){ local v=$1; v=${v//\\/\\\\}; v=${v//\"/\\\"}; printf '"%s"' "$v"; }
set_name(){ [[ -n "$1" && ${#1} -le 64 && "$1" != *$'\n'* ]] || die '大厅名称无效'; write_cvar hostname "$(q "$1")"; rcon "hostname $(q "$1")" || true; log "大厅名称：$1"; }
set_slots(){ [[ "$1" =~ ^[0-9]+$ && $1 -ge 1 && $1 -le 31 ]] || die '人数必须是1-31'; write_cvar sv_visiblemaxplayers "$1"; write_cvar sv_maxplayers "$1"; rcon "sv_visiblemaxplayers $1; sv_maxplayers $1" || true; }
set_difficulty(){ case "$1" in Easy|Normal|Hard|Impossible|Expert);;*) die '难度无效';;esac; write_cvar z_difficulty "$1"; rcon "z_difficulty $1" || true; }
set_si(){ [[ "$1" =~ ^[0-9]+$ && $1 -ge 1 && $1 -le 31 ]] || die 'SI数量必须是1-31'; write_cvar z_max_player_zombies "$1"; rcon "z_max_player_zombies $1" || true; }
set_interval(){ [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]] || die 'SI波次间隔无效'; write_cvar director_special_respawn_interval "$1"; write_cvar director_special_battlefield_respawn_interval "$1"; rcon "director_special_respawn_interval $1; director_special_battlefield_respawn_interval $1" || true; }
set_common(){ [[ "$1" =~ ^[0-9]+$ && $1 -le 300 ]] || die '普通感染者数量必须是0-300'; write_cvar z_common_limit "$1"; rcon "z_common_limit $1" || true; }
set_text(){ local file=$1 label=$2 tmp; tmp=$(mktemp); cat >"$tmp"; install -m0644 "$tmp" "$file"; rm -f "$tmp"; log "$label已保存"; }
regen_help(){ PYTHONPATH="$ROOT_DIR/scripts" HELP_TEXT_FILE="$HELP_TEXT_FILE" WELCOME_FILE="$WELCOME_FILE" HELP_KV_FILE="$HELP_KV_FILE" python3 -c 'import os; from pathlib import Path; h=Path(os.environ["HELP_TEXT_FILE"]); w=Path(os.environ["WELCOME_FILE"]); o=Path(os.environ["HELP_KV_FILE"]); hl=h.read_text(encoding="utf-8").splitlines() if h.exists() else []; wl=w.read_text(encoding="utf-8").splitlines() if w.exists() else []; ann=wl[0] if wl else "[开始菜单] 输入 !菜单 或 !pvehelp 打开中文帮助；按 H 可查看服务器帮助页。"; esc=lambda x:x.replace("\\","\\\\").replace(chr(34),"\\\"").replace("\\n"," "); lines=[chr(34)+"PvEHelp"+chr(34),"{", "    \"title\" \"无限火力 PvPvE 开始菜单\"", "    \"announcement\" \""+esc(ann)+"\"", "    \"details\"", "    {"]; lines += [f"        \"{i}\" \"{esc(x)}\"" for i,x in enumerate(hl[:12],1) if x.strip()]; lines += ["    }", "    \"commands\"", "    {"]; cmds=["!菜单 / !pvehelp：打开开始菜单","!buy / !shop：打开商城","!points / !money：查看积分","!infected / !特感：加入感染者","!survivor / !人类：返回幸存者","!zclass / !特感选择：选择普通特感","!tankqueue：加入 Tank 抽签","!notank：退出 Tank 抽签"]; lines += [f"        \"{i}\" \"{esc(x)}\"" for i,x in enumerate(cmds,1)]; lines += ["    }","}"]; o.parent.mkdir(parents=True,exist_ok=True); t=o.with_suffix(o.suffix+".tmp"); t.write_text("\\n".join(lines)+"\\n",encoding="utf-8"); t.replace(o)'; }
set_motd(){ set_text "$MOTD_FILE" MOTD; }
set_help(){ set_text "$HELP_TEXT_FILE" 'H菜单帮助'; regen_help; }
set_welcome(){ set_text "$WELCOME_FILE" '进房公告'; regen_help; }
set_admin(){ local id=$1 flags=${2:-z} tmp; [[ "$id" =~ ^(STEAM_[0-5]:[01]:[0-9]+|\[U:[0-9]+:[0-9]+\]|7656119[0-9]{10,})$ ]] || die 'SteamID无效'; [[ "$flags" =~ ^[a-z]+$ ]] || die 'flags无效'; install -d "$(dirname "$ADMINS_FILE")"; tmp=$(mktemp); [[ -f "$ADMINS_FILE" ]] && awk -v id="$id" '$0 !~ "^[[:space:]]*\\\"" id "\\\""{print}' "$ADMINS_FILE" >"$tmp"; printf '"%s" "99:%s"\n' "$id" "$flags" >>"$tmp"; install -m0644 "$tmp" "$ADMINS_FILE"; rm -f "$tmp"; rcon sm_reloadadmins || true; log "管理员：$id 99:$flags"; }
kick(){ [[ "$1" =~ ^[0-9]+$ ]] || die 'UserID无效'; rcon "kickid $1"; }
points(){ [[ "$1" =~ ^[0-9]+$ && "$2" =~ ^-?[0-9]+$ ]] || die 'UserID或积分无效'; rcon "sm_pveaddpoints #$1 $2"; }
set_web(){ local bind=$1 port=$2 user=$3 pass='' tmp; read -r pass || true; [[ "$bind" =~ ^([0-9]{1,3}[.]){3}[0-9]{1,3}$|^::1$|^0.0.0.0$ ]] || die '监听地址无效'; [[ "$port" =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]] || die '网页端口无效'; [[ "$user" =~ ^[A-Za-z0-9_.-]{1,32}$ ]] || die '网页账户无效'; [[ -z "$pass" || ${#pass} -ge 8 ]] || die '网页密码至少8位'; tmp=$(mktemp); awk '!/^(WEB_BIND|WEB_PORT|WEB_USER|WEB_PASSWORD)=/' "$WEB_ENV" >"$tmp" || true; printf 'WEB_BIND="%s"\nWEB_PORT="%s"\nWEB_USER="%s"\n' "$bind" "$port" "$user" >>"$tmp"; if [[ -n "$pass" ]]; then printf 'WEB_PASSWORD="%s"\n' "$pass" >>"$tmp"; else grep '^WEB_PASSWORD=' "$WEB_ENV" >>"$tmp" || die '缺少旧网页密码'; fi; install -o root -g root -m0600 "$tmp" "$WEB_ENV"; rm -f "$tmp"; systemctl restart l4d2-web-admin.service 2>/dev/null || true; }
health(){ local failed=0; [[ -x "$ROOT_DIR/server/srcds_run" ]] || { log '缺少srcds_run'; failed=1; }; [[ -x "$GAME_DIR/addons/sourcemod/scripting/spcomp" ]] || { log '缺少spcomp'; failed=1; }; [[ -f "$GAME_DIR/cfg/server_private.cfg" ]] || { log '缺少RCON私密配置'; failed=1; }; systemctl is-active --quiet l4d2.service || { log 'l4d2未运行'; failed=1; }; ss -lun 2>/dev/null | grep -q ':27015 ' || { log '27015未监听'; failed=1; }; return "$failed"; }
status(){ systemctl status l4d2.service --no-pager -l || true; printf '\n---在线玩家---\n'; rcon status || true; }
menu(){ while true; do printf '\nL4D2 PvPvE运维：1启动 2停止 3重启 4更新 5状态 6健康 7在线 8大厅名 9人数 10难度 11SI数量 12SI波次 13普通感染者 14踢人 15积分 16管理员 17MOTD 18H帮助 19进房公告 20网页配置 0退出\n'; read -r -p '请选择：' c; case "$c" in 1)service start;;2)service stop;;3)service restart;;4)service update;;5)status;;6)health||true;;7)rcon status;;8)read -r -p '大厅名：' v;set_name "$v";;9)read -r -p '人数：' v;set_slots "$v";;10)read -r -p '难度：' v;set_difficulty "$v";;11)read -r -p 'SI数量：' v;set_si "$v";;12)read -r -p 'SI波次：' v;set_interval "$v";;13)read -r -p '普通感染者：' v;set_common "$v";;14)read -r -p 'UserID：' v;kick "$v";;15)read -r -p 'UserID：' u;read -r -p '积分：' v;points "$u" "$v";;16)read -r -p 'SteamID：' v;set_admin "$v" z;;17)read -r -p 'MOTD：' v;printf '%s\n' "$v"|set_motd;;18)read -r -p 'H帮助：' v;printf '%s\n' "$v"|set_help;;19)read -r -p '公告：' v;printf '%s\n' "$v"|set_welcome;;20)read -r -p '监听地址：' b;read -r -p '端口：' p;read -r -p '账户：' u;read -r -s -p '新密码：' w;printf '\n';printf '%s\n' "$w"|set_web "$b" "$p" "$u";;0)return;;*)log '无效选择';;esac; done; }
load_env
[[ $# -eq 0 ]] && { menu; exit 0; }
cmd=$1; shift
case "$cmd" in start|stop|restart|update)service "$cmd";;status)status;;health)health;;set-name)set_name "$1";;set-slots)set_slots "$1";;set-difficulty)set_difficulty "$1";;set-si-count)set_si "$1";;set-si-interval)set_interval "$1";;set-common-limit)set_common "$1";;kick)kick "$1";;add-points)points "$1" "$2";;set-admin)set_admin "$1" "${2:-z}";;set-motd)set_motd;;set-help-text)set_help;;set-welcome-text)set_welcome;;set-web-config)set_web "$1" "$2" "$3";;*)die "未知命令：$cmd";;esac
