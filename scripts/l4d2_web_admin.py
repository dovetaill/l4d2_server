#!/usr/bin/env python3
"""Dependency-free L4D2 web administration panel.

The panel intentionally exposes only fixed actions and fixed RCON command
formats. Keep it bound to localhost unless it is placed behind HTTPS and a
firewall.
"""
from __future__ import annotations

import base64
import html
import ipaddress
import os
import re
import secrets
import shlex
import socket
import subprocess
import sys
import time
from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Dict, List, Optional, Sequence, Tuple
from urllib.parse import parse_qs, quote, urlparse

ENV_FILE = "/etc/l4d2/l4d2-admin.env"
DEFAULT_BIND = "127.0.0.1"
DEFAULT_PORT = 27815
DEFAULT_SERVICE = "l4d2"
DEFAULT_CONTROL = "/opt/l4d2/scripts/l4d2ctl.sh"
DEFAULT_RCON_HOST = "127.0.0.1"
DEFAULT_RCON_PORT = 27015
DEFAULT_USER = "qi"
DIFFICULTIES = ("Easy", "Normal", "Hard", "Impossible", "Expert")
STEAM_ID_RE = re.compile(r"^(?:STEAM_[0-5]:[01]:\d+|\[U:\d+:\d+\]|7656119\d{10,})$")
USERID_RE = re.compile(r"^\d{1,5}$")
MOTD_FILE = "/opt/l4d2/server/left4dead2/motd.txt"
HELP_FILE = "/opt/l4d2/server/left4dead2/cfg/sourcemod/l4d2_pve_help_menu_content.txt"
WELCOME_FILE = "/opt/l4d2/server/left4dead2/cfg/sourcemod/l4d2_pve_welcome.txt"
HELP_KV_FILE = "/opt/l4d2/server/left4dead2/addons/sourcemod/configs/pve_help_content.cfg"
INFECTED_BOTS_FILE = "/opt/l4d2/server/left4dead2/addons/sourcemod/data/l4dinfectedbots/pve_pvpve.cfg"

CONTROL_SPECS = {
    "start": 0,
    "stop": 0,
    "restart": 0,
    "update": 0,
    "set-name": 1,
    "set-slots": 1,
    "set-difficulty": 1,
    "set-si-count": 1,
    "set-si-interval": 1,
    "set-common-limit": 1,
    "kick": 1,
    "add-points": 2,
    "set-admin": 2,
    "set-motd": 0,
    "set-help-text": 0,
    "set-welcome-text": 0,
    "set-web-config": 3,
}
STDIN_COMMANDS = {"set-motd", "set-help-text", "set-welcome-text", "set-web-config"}


def load_env(path: str) -> Dict[str, str]:
    """Read KEY=value lines without executing the environment file."""
    values: Dict[str, str] = {}
    try:
        with open(path, "r", encoding="utf-8") as handle:
            lines = handle.readlines()
    except FileNotFoundError as exc:
        raise ValueError(f"缺少私密配置文件：{path}") from exc
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        values[key] = value
    return values


def bounded_int(values: Dict[str, str], name: str, default: int, minimum: int, maximum: int) -> int:
    raw = values.get(name, str(default))
    try:
        value = int(raw)
    except ValueError as exc:
        raise ValueError(f"{name} 必须是整数") from exc
    if not minimum <= value <= maximum:
        raise ValueError(f"{name} 必须在 {minimum}-{maximum} 之间")
    return value


@dataclass(frozen=True)
class Settings:
    bind: str
    port: int
    user: str
    password: str
    service: str
    control: str
    rcon_host: str
    rcon_port: int
    rcon_password: str


def settings() -> Settings:
    values = load_env(ENV_FILE)
    password = values.get("WEB_PASSWORD", "")
    if not password:
        raise ValueError("缺少 WEB_PASSWORD，请创建 /etc/l4d2/l4d2-admin.env")
    rcon_port = bounded_int(values, "RCON_PORT", DEFAULT_RCON_PORT, 1, 65535)
    return Settings(
        bind=values.get("WEB_BIND", DEFAULT_BIND),
        port=bounded_int(values, "WEB_PORT", DEFAULT_PORT, 1, 65535),
        user=values.get("WEB_USER", DEFAULT_USER),
        password=password,
        service=values.get("L4D2_SERVICE", DEFAULT_SERVICE),
        control=values.get("L4D2CTL", DEFAULT_CONTROL),
        rcon_host=values.get("RCON_HOST", DEFAULT_RCON_HOST),
        rcon_port=rcon_port,
        rcon_password=values.get("RCON_PASSWORD", ""),
    )


class RconError(RuntimeError):
    pass


class Rcon:
    AUTH = 3
    EXEC = 2
    RESPONSE = 0
    AUTH_RESPONSE = 2

    def __init__(self, host: str, port: int, password: str, timeout: float = 2.5) -> None:
        if not password:
            raise RconError("未配置 RCON_PASSWORD")
        self.host = host
        self.port = port
        self.password = password
        self.timeout = timeout
        self.sock: Optional[socket.socket] = None
        self.next_id = 1

    @staticmethod
    def packet(request_id: int, packet_type: int, body: str) -> bytes:
        payload = body.encode("utf-8", errors="replace") + b"\x00\x00"
        size = 8 + len(payload)
        return size.to_bytes(4, "little", signed=True) + request_id.to_bytes(4, "little", signed=True) + packet_type.to_bytes(4, "little", signed=True) + payload

    def read_exact(self, size: int) -> bytes:
        if self.sock is None:
            raise RconError("RCON 未连接")
        result = bytearray()
        while len(result) < size:
            chunk = self.sock.recv(size - len(result))
            if not chunk:
                raise RconError("RCON 连接已关闭")
            result.extend(chunk)
        return bytes(result)

    def read_packet(self) -> Tuple[int, int, str]:
        size = int.from_bytes(self.read_exact(4), "little", signed=True)
        if size < 10 or size > 1024 * 1024:
            raise RconError("RCON 返回包大小无效")
        payload = self.read_exact(size)
        request_id = int.from_bytes(payload[0:4], "little", signed=True)
        packet_type = int.from_bytes(payload[4:8], "little", signed=True)
        return request_id, packet_type, payload[8:-2].decode("utf-8", errors="replace")

    def __enter__(self) -> "Rcon":
        self.sock = socket.create_connection((self.host, self.port), self.timeout)
        self.sock.settimeout(self.timeout)
        auth_id = self.next_id
        self.next_id += 1
        self.sock.sendall(self.packet(auth_id, self.AUTH, self.password))
        first = self.read_packet()
        second = self.read_packet()
        responses = (first, second)
        if any(packet_id == -1 for packet_id, _, _ in responses):
            raise RconError("RCON 认证失败")
        if not any(packet_id == auth_id and packet_type == self.AUTH_RESPONSE for packet_id, packet_type, _ in responses):
            raise RconError("RCON 认证响应无效")
        return self

    def __exit__(self, *_: object) -> None:
        if self.sock is not None:
            self.sock.close()
            self.sock = None

    def command(self, command: str) -> str:
        if self.sock is None:
            raise RconError("RCON 未连接")
        request_id = self.next_id
        self.next_id += 1
        self.sock.sendall(self.packet(request_id, self.EXEC, command))
        parts: List[str] = []
        deadline = time.monotonic() + self.timeout
        while time.monotonic() < deadline:
            try:
                response_id, packet_type, body = self.read_packet()
            except socket.timeout:
                break
            if response_id == request_id and packet_type == self.RESPONSE:
                parts.append(body)
                if len(body) < 4096:
                    break
        return "".join(parts).strip()


def run(argv: Sequence[str], timeout: float = 30.0) -> Tuple[bool, str]:
    try:
        result = subprocess.run(
            list(argv), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, timeout=timeout, check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, str(exc)
    output = (result.stdout or "").strip()
    if len(output) > 3000:
        output = output[-3000:]
    return result.returncode == 0, output or f"exit code {result.returncode}"


def control_run(
    config: Settings,
    command: str,
    args: Sequence[str] = (),
    input_text: Optional[str] = None,
    timeout: float = 45.0,
) -> Tuple[bool, str]:
    """Run only a fixed l4d2ctl.sh subcommand with validated argv."""
    expected = CONTROL_SPECS.get(command)
    if expected is None or len(args) != expected:
        return False, "控制命令不在允许列表或参数数量错误"
    if input_text is not None and command not in STDIN_COMMANDS:
        return False, "该控制命令不接受标准输入"
    if input_text is None and command in STDIN_COMMANDS:
        return False, "该控制命令需要标准输入"
    if not os.path.isfile(config.control) or not os.access(config.control, os.X_OK):
        return False, f"未找到受控更新脚本：{config.control}"
    if any("\x00" in value for value in args):
        return False, "控制参数包含无效字符"
    try:
        result = subprocess.run(
            [config.control, command, *args],
            input=input_text,
            stdin=subprocess.PIPE if input_text is not None else subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, str(exc)
    output = (result.stdout or "").strip()
    if len(output) > 3000:
        output = output[-3000:]
    return result.returncode == 0, output or f"exit code {result.returncode}"


def service_action(config: Settings, action: str) -> Tuple[bool, str]:
    if action not in {"start", "stop", "restart", "update"}:
        return False, "服务操作不在允许列表"
    return control_run(config, action, timeout=120.0 if action == "update" else 45.0)


def cvar_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def parse_cvar(value: str) -> str:
    for raw_line in value.splitlines():
        line = raw_line.strip()
        if not line or line.lower().startswith("unknown command"):
            continue
        if "=" in line:
            line = line.split("=", 1)[1].strip()
            quoted = re.match(r'^"((?:\\.|[^"\\])*)"', line)
            if quoted:
                return re.sub(r'\\(["\\])', r'\1', quoted.group(1)).strip()
        elif line.lower().startswith(("game ", "flags ", "default ", "description ", "min ", "max ")):
            continue
        if len(line) >= 2 and line[0] == line[-1] == '"':
            line = line[1:-1]
        return line.strip()
    return ""


def strip_chat_color_escapes(value: str) -> str:
    value = re.sub(r"\\x[0-9a-fA-F]{2}", "", value)
    return re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", value)


def read_help_kv_fallback() -> Tuple[str, str]:
    raw = read_text_file(HELP_KV_FILE, 32768)
    if not raw:
        return "", ""

    announcement_match = re.search(r'^\s*"announcement"\s+"((?:\\.|[^"])*)"', raw, re.MULTILINE)
    announcement = strip_chat_color_escapes(announcement_match.group(1)) if announcement_match else ""
    details_match = re.search(r'"details"\s*\{(?P<body>.*?)^\s*\}', raw, re.MULTILINE | re.DOTALL)
    details: List[str] = []
    if details_match:
        details = [
            strip_chat_color_escapes(match.group(1))
            for match in re.finditer(r'^\s*"\d+"\s+"((?:\\.|[^"])*)"', details_match.group("body"), re.MULTILINE)
        ]
    return "\n".join(line for line in details if line), announcement


def read_player_content() -> Dict[str, str]:
    help_text = strip_chat_color_escapes(read_text_file(HELP_FILE, 16384))
    welcome = strip_chat_color_escapes(read_text_file(WELCOME_FILE, 4096))
    fallback_help, fallback_welcome = read_help_kv_fallback()
    if not help_text:
        help_text = fallback_help
    if not welcome:
        welcome = fallback_welcome
    return {
        "motd": read_text_file(MOTD_FILE, 32768),
        "help": help_text,
        "welcome": welcome,
    }


def read_infected_bots_max_specials(default: int = 12) -> str:
    raw = read_text_file(INFECTED_BOTS_FILE, 32768)
    match = re.search(r'^\s*"max_specials"\s+"(\d+)"', raw, re.MULTILINE)
    return match.group(1) if match else str(default)


def parse_status(output: str) -> List[Dict[str, str]]:
    players: List[Dict[str, str]] = []
    for line in output.splitlines():
        text = line.strip()
        if not text.startswith("#"):
            continue
        try:
            tokens = shlex.split(text[1:].strip())
        except ValueError:
            continue
        if len(tokens) < 3 or not USERID_RE.fullmatch(tokens[0]):
            continue
        players.append({
            "userid": tokens[0], "name": tokens[1], "steamid": tokens[2],
            "ping": tokens[4] if len(tokens) > 4 else "",
            "state": tokens[6] if len(tokens) > 6 else "",
        })
    return players


def valid_userid(value: str) -> bool:
    return bool(USERID_RE.fullmatch(value)) and 1 <= int(value) <= 65535


def valid_hostname(value: str) -> bool:
    return 1 <= len(value) <= 64 and all(ord(char) >= 32 and char not in "\r\n\x00" for char in value)


def fixed_cvars(config: Settings) -> Dict[str, str]:
    names = (
        "hostname", "sv_visiblemaxplayers", "sv_maxplayers", "z_difficulty",
        "director_special_respawn_interval", "z_common_limit",
    )
    result: Dict[str, str] = {}
    with Rcon(config.rcon_host, config.rcon_port, config.rcon_password) as rcon:
        for name in names:
            result[name] = parse_cvar(rcon.command(name))
    return result


class Panel:
    def __init__(self, config: Settings) -> None:
        self.config = config
        self.csrf = secrets.token_urlsafe(32)

    def status(self) -> Dict[str, object]:
        active, service = run(("systemctl", "is-active", self.config.service), 5.0)
        data: Dict[str, object] = {
            "service": service if active else f"inactive ({service})",
            "players": [], "cvars": {}, "errors": [],
            "content": read_player_content(),
        }
        try:
            with Rcon(self.config.rcon_host, self.config.rcon_port, self.config.rcon_password) as rcon:
                data["players"] = parse_status(rcon.command("status"))
                cvars: Dict[str, str] = {}
                for name in (
                    "hostname", "sv_visiblemaxplayers", "sv_maxplayers", "z_difficulty",
                    "director_special_respawn_interval", "z_common_limit",
                ):
                    cvars[name] = parse_cvar(rcon.command(name))
                cvars["max_specials"] = read_infected_bots_max_specials()
                data["cvars"] = cvars
        except (OSError, RconError, socket.timeout) as exc:
            data["errors"] = [str(exc)]
        return data

    def command(self, text: str) -> str:
        with Rcon(self.config.rcon_host, self.config.rcon_port, self.config.rcon_password) as rcon:
            return rcon.command(text)


class Handler(BaseHTTPRequestHandler):
    server_version = "L4D2WebAdmin/1.0"

    @property
    def panel(self) -> Panel:
        return self.server.panel  # type: ignore[attr-defined]

    def log_message(self, fmt: str, *args: object) -> None:
        sys.stderr.write("[l4d2-web-admin] " + (fmt % args) + "\n")

    def auth(self) -> bool:
        header = self.headers.get("Authorization", "")
        if not header.startswith("Basic "):
            self.send_response(HTTPStatus.UNAUTHORIZED)
            self.send_header("WWW-Authenticate", 'Basic realm="L4D2 Web Admin"')
            self.end_headers()
            return False
        try:
            decoded = base64.b64decode(header[6:], validate=True).decode("utf-8")
            user, password = decoded.split(":", 1)
        except (ValueError, UnicodeError):
            user, password = "", ""
        ok = secrets.compare_digest(user, self.panel.config.user) and secrets.compare_digest(password, self.panel.config.password)
        if not ok:
            self.send_response(HTTPStatus.UNAUTHORIZED)
            self.send_header("WWW-Authenticate", 'Basic realm="L4D2 Web Admin"')
            self.end_headers()
        return ok

    def send_body(self, status: int, body: str, content_type: str = "text/html; charset=utf-8") -> None:
        payload = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.end_headers()
        self.wfile.write(payload)

    def redirect(self, key: str, message: str) -> None:
        self.send_response(HTTPStatus.SEE_OTHER)
        self.send_header("Location", "/?" + key + "=" + quote(message, safe=""))
        self.end_headers()

    def form(self) -> Dict[str, str]:
        if not self.headers.get("Content-Type", "").startswith("application/x-www-form-urlencoded"):
            raise ValueError("只接受表单请求")
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as exc:
            raise ValueError("Content-Length 无效") from exc
        if length < 0 or length > 131072:
            raise ValueError("请求体过大")
        raw = self.rfile.read(length).decode("utf-8")
        values = parse_qs(raw, keep_blank_values=True, max_num_fields=32)
        return {key: items[-1] for key, items in values.items()}

    def csrf(self, form: Dict[str, str]) -> None:
        if not secrets.compare_digest(form.get("csrf", ""), self.panel.csrf):
            raise ValueError("CSRF token 无效，请刷新页面")

    def do_GET(self) -> None:
        if not self.auth():
            return
        parsed = urlparse(self.path)
        if parsed.path == "/healthz":
            self.send_body(HTTPStatus.OK, "ok\n", "text/plain; charset=utf-8")
            return
        if parsed.path != "/":
            self.send_body(HTTPStatus.NOT_FOUND, "Not found\n", "text/plain; charset=utf-8")
            return
        query = parse_qs(parsed.query)
        try:
            body = page(self.panel, self.panel.status(), query.get("ok", [""])[-1], query.get("error", [""])[-1])
            self.send_body(HTTPStatus.OK, body)
        except Exception as exc:
            self.send_body(HTTPStatus.INTERNAL_SERVER_ERROR, "<h1>面板错误</h1><p>" + html.escape(str(exc)) + "</p>")

    def do_POST(self) -> None:
        if not self.auth():
            return
        path = urlparse(self.path).path
        if path not in {"/action", "/config", "/kick", "/points", "/admin", "/content", "/web-config"}:
            self.send_body(HTTPStatus.NOT_FOUND, "Not found\n", "text/plain; charset=utf-8")
            return
        try:
            values = self.form()
            self.csrf(values)
            self.redirect("ok", handle_post(self.panel, path, values))
        except (ValueError, OSError, RconError, socket.timeout) as exc:
            self.redirect("error", str(exc))


class WebServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address: Tuple[str, int], panel: Panel) -> None:
        super().__init__(address, Handler)
        self.panel = panel


def read_text_file(path: str, limit: int) -> str:
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read(limit)
    except (FileNotFoundError, PermissionError, OSError):
        return ""


def require_int(value: str, label: str, minimum: int, maximum: int) -> int:
    try:
        number = int(value)
    except ValueError as exc:
        raise ValueError(f"{label}必须是整数") from exc
    if not minimum <= number <= maximum:
        raise ValueError(f"{label}必须在 {minimum}-{maximum} 之间")
    return number


def require_float(value: str, label: str, minimum: float, maximum: float) -> float:
    try:
        number = float(value)
    except ValueError as exc:
        raise ValueError(f"{label}必须是数字") from exc
    if not minimum <= number <= maximum:
        raise ValueError(f"{label}必须在 {minimum:g}-{maximum:g} 之间")
    return number


def require_text(value: str, label: str, maximum: int) -> str:
    if "\x00" in value:
        raise ValueError(f"{label}包含无效字符")
    if len(value.encode("utf-8")) > maximum:
        raise ValueError(f"{label}不能超过 {maximum} 字节")
    return value


def handle_post(panel: Panel, path: str, values: Dict[str, str]) -> str:
    if path == "/action":
        action = values.get("action", "")
        ok, output = service_action(panel.config, action)
        if not ok:
            raise ValueError(f"{action} 失败：{output}")
        return f"{action} 已执行：{output}"

    if path == "/config":
        hostname = values.get("hostname", "").strip()
        difficulty = values.get("difficulty", "")
        slots = values.get("slots", "")
        si_limit = values.get("si_limit", "")
        si_interval = values.get("si_interval", "")
        common_limit = values.get("common_limit", "")
        if not valid_hostname(hostname):
            raise ValueError("大厅名必须为 1-64 个字符且不能换行")
        if difficulty not in DIFFICULTIES:
            raise ValueError("难度不在允许列表")
        slots_value = require_int(slots, "人数上限", 1, 31)
        si_value = require_int(si_limit, "SI 数量", 1, 31)
        common_value = require_int(common_limit, "普通感染者数量", 0, 300)
        interval_value = require_float(si_interval, "SI 波次间隔", 1.0, 180.0)
        operations = (
            ("set-name", (hostname,)),
            ("set-slots", (str(slots_value),)),
            ("set-difficulty", (difficulty,)),
            ("set-si-count", (str(si_value),)),
            ("set-si-interval", (f"{interval_value:g}",)),
            ("set-common-limit", (str(common_value),)),
        )
        for command, args in operations:
            ok, output = control_run(panel.config, command, args)
            if not ok:
                raise ValueError(f"{command} 失败：{output}")
        current = fixed_cvars(panel.config)
        if current.get("director_special_respawn_interval") != f"{interval_value:g}":
            raise ValueError("SI 波次间隔写入后回读不一致")
        if current.get("z_common_limit") != str(common_value):
            raise ValueError("普通感染者数量写入后回读不一致")
        return "大厅名、人数、难度、SI 数量、SI 波次间隔和普通感染者数量已更新"

    if path == "/kick":
        userid = values.get("userid", "")
        if not valid_userid(userid):
            raise ValueError("玩家编号无效，请从在线列表选择")
        ok, output = control_run(panel.config, "kick", (str(int(userid)),))
        if not ok:
            raise ValueError(f"踢出失败：{output}")
        return f"已请求踢出玩家 #{userid}：{output}"

    if path == "/points":
        userid = values.get("userid", "")
        if not valid_userid(userid):
            raise ValueError("玩家编号无效，请从在线列表选择")
        amount = require_int(values.get("amount", ""), "积分", -9999999, 9999999)
        ok, output = control_run(panel.config, "add-points", (str(int(userid)), str(amount)))
        if not ok:
            raise ValueError(f"积分操作失败：{output}")
        return f"已向玩家 #{userid} 修改积分 {amount}：{output}"

    if path == "/admin":
        identity = values.get("identity", "").strip()
        flags = values.get("flags", "z").strip().lower()
        if not STEAM_ID_RE.fullmatch(identity):
            raise ValueError("SteamID 格式无效")
        if not flags or len(flags) > 26 or any(char not in "zabcdefghijkmnopqrstuvw" for char in flags):
            raise ValueError("管理员 flags 无效")
        ok, output = control_run(panel.config, "set-admin", (identity, flags))
        if not ok:
            raise ValueError(f"设置管理员失败：{output}")
        return f"已添加管理员 {identity}（{flags}）：{output}"

    if path == "/content":
        motd = require_text(values.get("motd", ""), "MOTD", 32768)
        help_text = require_text(values.get("help_text", ""), "H 菜单帮助", 16384)
        welcome = require_text(values.get("welcome", ""), "进房公告", 4096)
        for command, text in (
            ("set-motd", motd),
            ("set-help-text", help_text),
            ("set-welcome-text", welcome),
        ):
            ok, output = control_run(panel.config, command, input_text=text)
            if not ok:
                raise ValueError(f"{command} 失败：{output}")
        return "MOTD、H 菜单帮助和进房公告已保存"

    if path == "/web-config":
        bind = values.get("bind", "").strip()
        port = require_int(values.get("port", ""), "网页端口", 1, 65535)
        user = values.get("user", "").strip()
        password = values.get("password", "")
        try:
            address = ipaddress.ip_address(bind)
        except ValueError as exc:
            raise ValueError("监听地址必须是有效的 IPv4 地址或 ::1") from exc
        if address.version == 6 and bind != "::1":
            raise ValueError("网页面板只允许 IPv4 或 ::1")
        if not re.fullmatch(r"[A-Za-z0-9_.-]{1,32}", user):
            raise ValueError("网页账户格式无效")
        if password and not 8 <= len(password) <= 128:
            raise ValueError("新密码必须为 8-128 个字符；留空表示保留当前密码")
        if any(char in password for char in "\r\n\x00"):
            raise ValueError("网页密码不能包含换行或控制字符")
        password = require_text(password, "网页密码", 512)
        ok, output = control_run(
            panel.config,
            "set-web-config",
            (bind, str(port), user),
            input_text=password + "\n",
        )
        if not ok:
            raise ValueError(f"网页配置失败：{output}")
        return f"网页配置已保存：{output}"

    raise ValueError("不允许的操作")

def page(panel: Panel, data: Dict[str, object], ok: str, error: str) -> str:
    cvars = data.get("cvars", {})
    if not isinstance(cvars, dict):
        cvars = {}
    players = data.get("players", [])
    if not isinstance(players, list):
        players = []
    errors = data.get("errors", [])
    if not isinstance(errors, list):
        errors = []
    notice = ""
    if ok:
        notice += "<div class='ok'>" + html.escape(ok) + "</div>"
    if error:
        notice += "<div class='bad'>" + html.escape(error) + "</div>"
    if errors:
        notice += "<div class='bad'>读取状态失败：" + html.escape("; ".join(str(item) for item in errors)) + "</div>"
    if not os.path.isfile(DEFAULT_CONTROL) or not os.access(DEFAULT_CONTROL, os.X_OK):
        notice += "<div class='warn'>写操作暂不可用：缺少 " + html.escape(DEFAULT_CONTROL) + "</div>"
    difficulty = str(cvars.get("z_difficulty", "Hard"))
    difficulty_options = "".join(
        f"<option value='{html.escape(item)}' {'selected' if item == difficulty else ''}>{html.escape(item)}</option>"
        for item in DIFFICULTIES
    )
    rows: List[str] = []
    player_options: List[str] = []
    for item in players:
        if not isinstance(item, dict):
            continue
        userid = html.escape(str(item.get("userid", "")))
        player_options.append("<option value='" + userid + "'>#" + userid + " " + html.escape(str(item.get("name", ""))) + "</option>")
        rows.append(
            "<tr><td>#" + userid + "</td><td>" + html.escape(str(item.get("name", ""))) + "</td>"
            "<td><code>" + html.escape(str(item.get("steamid", ""))) + "</code></td>"
            "<td>" + html.escape(str(item.get("ping", ""))) + "</td><td>"
            + html.escape(str(item.get("state", ""))) + "</td><td>"
            "<form method='post' action='/kick' onsubmit=\"return confirm('确认踢出？');\">"
            "<input type='hidden' name='csrf' value='" + html.escape(panel.csrf) + "'>"
            "<input type='hidden' name='userid' value='" + userid + "'>"
            "<button class='danger'>踢出</button></form></td></tr>"
        )
    if not rows:
        rows.append("<tr><td colspan='6'>暂无在线玩家，或 RCON 尚未连接。</td></tr>")
    content = data.get("content", {})
    if not isinstance(content, dict):
        content = {}
    csrf = html.escape(panel.csrf, quote=True)
    slots = html.escape(str(cvars.get("sv_visiblemaxplayers", cvars.get("sv_maxplayers", "16"))), quote=True)
    options = "".join(player_options) or "<option value=''>暂无在线玩家</option>"
    return f"""<!doctype html>
<html lang='zh-CN'><head><meta charset='utf-8'>
<meta name='viewport' content='width=device-width,initial-scale=1'>
<title>L4D2 中文运维面板</title>
<style>
body{{font-family:system-ui,sans-serif;max-width:1200px;margin:auto;padding:18px;background:#10151b;color:#e8eef2}}
section{{background:#19232d;border:1px solid #334352;border-radius:8px;padding:15px;margin:14px 0}}
h1{{margin-top:0}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:12px}}
label{{display:block;color:#b8c4cc;font-size:13px}}input,select,textarea{{display:block;width:100%;box-sizing:border-box;margin-top:5px;padding:8px;background:#0c1116;color:#fff;border:1px solid #465766;border-radius:4px;font:inherit}}
textarea{{min-height:120px;resize:vertical}}button{{padding:8px 12px;border:0;border-radius:4px;background:#2d8ccc;color:#fff;cursor:pointer}}.danger{{background:#b64242}}.warn{{background:#a97622}}
.ok,.bad,.warnbox{{padding:10px;border-radius:4px;margin:10px 0}}.ok{{background:#1d4934}}.bad{{background:#4b2227}}.warnbox{{background:#4b3a1e}}
table{{width:100%;border-collapse:collapse}}th,td{{padding:8px;border-bottom:1px solid #334352;text-align:left}}.muted{{color:#9eabb6;font-size:13px}}code{{color:#c8e8ff}}
</style></head><body>
<h1>L4D2 中文运维面板</h1>{notice}
<section><h2>运行状态</h2><div class='grid'>
<div>服务：<strong>{html.escape(str(data.get('service', 'unknown')))}</strong></div>
<div>大厅名：<strong>{html.escape(str(cvars.get('hostname', '未知')))}</strong></div>
<div>难度：<strong>{html.escape(difficulty)}</strong></div>
<div>在线人数：<strong>{len(players)}</strong></div>
<div>人数上限：<strong>{slots}</strong></div>
<div>SI 数量：<strong>{html.escape(str(cvars.get('max_specials', '未知')))}</strong></div>
<div>SI 波次间隔：<strong>{html.escape(str(cvars.get('director_special_respawn_interval', '未知')))} 秒</strong></div>
<div>普通感染者数量：<strong>{html.escape(str(cvars.get('z_common_limit', '未知')))}</strong></div></div></section>
<section><h2>服务控制</h2><div class='grid'>
<form method='post' action='/action'><input type='hidden' name='csrf' value='{csrf}'><button name='action' value='start'>启动</button></form>
<form method='post' action='/action'><input type='hidden' name='csrf' value='{csrf}'><button class='warn' name='action' value='restart'>重启</button></form>
<form method='post' action='/action'><input type='hidden' name='csrf' value='{csrf}'><button class='danger' name='action' value='stop'>停止</button></form>
<form method='post' action='/action'><input type='hidden' name='csrf' value='{csrf}'><button name='action' value='update'>更新</button></form></div>
<p class='muted'>服务写操作只调用固定路径 <code>{html.escape(DEFAULT_CONTROL)}</code> 的白名单子命令。</p></section>
<section><h2>大厅与战斗设置</h2><form method='post' action='/config'><input type='hidden' name='csrf' value='{csrf}'><div class='grid'>
<label>大厅名<input name='hostname' maxlength='64' required value='{html.escape(str(cvars.get('hostname', '')), quote=True)}'></label>
<label>难度<select name='difficulty'>{difficulty_options}</select></label>
<label>人数上限<input name='slots' type='number' min='1' max='31' required value='{slots}'></label>
<label>SI 数量<input name='si_limit' type='number' min='1' max='31' required value='{html.escape(str(cvars.get('max_specials', '12')), quote=True)}'></label>
<label>SI 波次间隔（秒）<input name='si_interval' type='number' min='1' max='180' step='0.1' required value='{html.escape(str(cvars.get('director_special_respawn_interval', '30')), quote=True)}'></label>
<label>普通感染者数量<input name='common_limit' type='number' min='0' max='300' required value='{html.escape(str(cvars.get('z_common_limit', '30')), quote=True)}'></label></div><p><button>保存战斗设置</button></p></form></section>
<section><h2>在线玩家（{len(players)}）</h2><div style='overflow-x:auto'><table><tr><th>编号</th><th>名称</th><th>SteamID</th><th>Ping</th><th>状态</th><th>操作</th></tr>{''.join(rows)}</table></div>
<div class='grid'><form method='post' action='/points'><input type='hidden' name='csrf' value='{csrf}'><label>玩家编号<select name='userid' required>{options}</select></label><label>积分增减<input name='amount' type='number' min='-9999999' max='9999999' value='100' required></label><p><button>修改积分</button></p></form>
<form method='post' action='/admin'><input type='hidden' name='csrf' value='{csrf}'><label>SteamID<input name='identity' placeholder='STEAM_0:1:126011599' required></label><label>权限 flags<input name='flags' value='z' maxlength='26' required></label><p><button>设置管理员</button></p></form></div></section>
<section><h2>玩家可见内容</h2><form method='post' action='/content'><input type='hidden' name='csrf' value='{csrf}'><label>MOTD / H 键帮助页<textarea name='motd' maxlength='32768'>{html.escape(str(content.get('motd', '')))}</textarea></label><div class='grid'><label>H 菜单帮助<textarea name='help_text' maxlength='16384'>{html.escape(str(content.get('help', '')))}</textarea></label><label>进房公告<textarea name='welcome' maxlength='4096'>{html.escape(str(content.get('welcome', '')))}</textarea></label></div><p><button>保存公告内容</button></p></form></section>
<section><h2>网页面板配置</h2><form method='post' action='/web-config'><input type='hidden' name='csrf' value='{csrf}'><div class='grid'><label>监听地址<input name='bind' value='{html.escape(panel.config.bind, quote=True)}' required></label><label>监听端口<input name='port' type='number' min='1' max='65535' value='{panel.config.port}' required></label><label>账户<input name='user' value='{html.escape(panel.config.user, quote=True)}' required></label><label>新密码<input name='password' type='password' minlength='8' maxlength='128' placeholder='留空保留当前密码'></label></div><p><button>保存网页配置</button></p><p class='muted'>默认监听 127.0.0.1:27815。修改监听地址、端口或账户后需要重新登录。</p></form></section>
<p class='muted'>建议使用 SSH 隧道访问，不要直接把内置 HTTP 服务暴露到公网。</p></body></html>"""


def main() -> int:
    try:
        config = settings()
    except ValueError as exc:
        print(f"l4d2_web_admin: {exc}", file=sys.stderr)
        return 2
    server = WebServer((config.bind, config.port), Panel(config))
    print(f"L4D2 web admin listening on http://{config.bind}:{config.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
