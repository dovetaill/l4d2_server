# L4D2 中文网页运维面板

`scripts/l4d2_web_admin.py` 使用 Python 3 标准库实现，不依赖 Flask、npm 或数据库。

## 安全边界

- 默认监听 `127.0.0.1:27815`。
- Basic Auth 默认用户名是 `qi`。
- 网页密码只从 `/etc/l4d2/l4d2-admin.env` 的 `WEB_PASSWORD` 读取，源码不包含默认密码。部署时在该私密文件中设置实际密码，但不得提交 Git。
- 所有写请求都使用 POST，并校验进程启动时随机生成的 CSRF token。
- 所有写操作只调用固定路径 `/opt/l4d2/scripts/l4d2ctl.sh` 的严格白名单子命令。
- Python 使用参数数组调用子进程，不使用 `shell=True`、`eval`、`sh -c` 或任意 shell 字符串拼接。
- RCON 只用于读取服务状态、CVar 和在线玩家列表。

如果固定控制脚本不存在，页面仍可读取状态，但会明确提示写操作不可用，不会退化为直接执行任意命令。

## 私密配置

```bash
install -d -m 750 /etc/l4d2
cat > /etc/l4d2/l4d2-admin.env <<'EOF'
WEB_BIND=127.0.0.1
WEB_PORT=27815
WEB_USER=qi
WEB_PASSWORD=请填写实际网页密码
L4D2_SERVICE=l4d2
RCON_HOST=127.0.0.1
RCON_PORT=27015
RCON_PASSWORD=这里填写实际RCON密码
EOF
chmod 600 /etc/l4d2/l4d2-admin.env
chown root:root /etc/l4d2/l4d2-admin.env
```

密码只放在这个文件或其他未纳入 Git 的私密存储中。缺少 `WEB_PASSWORD` 时程序退出，不启用空密码或内置密码。

## 启动和验证

```bash
cd /opt/l4d2
python3 scripts/l4d2_web_admin.py
python3 -m py_compile scripts/l4d2_web_admin.py
```

默认地址：

```text
http://127.0.0.1:27815/
```

健康检查：

```bash
curl -u qi:'网页密码' http://127.0.0.1:27815/healthz
```

预期返回 `ok`。

推荐使用 SSH 隧道：

```bash
ssh -N -L 27815:127.0.0.1:27815 root@服务器公网IP
```

然后访问本地 `http://127.0.0.1:27815/`。如果必须公网监听，应使用防火墙限制来源，并放到 TLS 反向代理后面；内置服务本身是 HTTP。

## 面板功能

- 启动、停止、重启、更新 L4D2 服务。
- 查看服务状态、在线玩家、UserID、名称、SteamID、Ping 和连接状态。
- 设置大厅名称、人数上限、难度、SI 数量、SI 波次间隔和普通感染者数量。
- 踢出在线玩家。
- 给在线玩家增加或扣除战役积分。
- 设置 SourceMod 管理员 SteamID 和权限 flags。
- 编辑 MOTD/H 键帮助页、H 菜单帮助文本和玩家进房公告。
- 设置网页监听地址、端口、账户和密码。

修改网页监听地址、端口或账户后当前连接可能中断，需要使用新地址重新登录。新密码留空表示保留当前密码。

## 固定控制脚本接口

网页只执行：

```text
/opt/l4d2/scripts/l4d2ctl.sh
```

该文件必须可执行，并且脚本自身也必须校验参数。网页允许的子命令如下：

无参数：

```text
start
stop
restart
update
```

单参数：

```text
set-name <大厅名称>
set-slots <1-31>
set-difficulty <Easy|Normal|Hard|Impossible|Expert>
set-si-count <1-31>
set-si-interval <1-180>
set-common-limit <0-300>
kick <UserID>
```

双参数：

```text
add-points <UserID> <-9999999..9999999>
set-admin <SteamID> <flags>
```

正文通过标准输入传入，不放进命令行：

```text
set-motd
set-help-text
set-welcome-text
```

网页配置命令：

```text
set-web-config <监听IP> <端口> <账户名>
```

该命令从标准输入读取一行新密码，空行表示保留现有密码。控制脚本应原子更新 `/etc/l4d2/l4d2-admin.env`，权限设置为 `600`，然后重启 `l4d2-web-admin.service`。

建议内容文件：

```text
/opt/l4d2/server/left4dead2/motd.txt
/opt/l4d2/server/left4dead2/cfg/sourcemod/l4d2_pve_help_menu_content.txt
/opt/l4d2/server/left4dead2/cfg/sourcemod/l4d2_pve_welcome.txt
```

## 输入限制

- 大厅名：1-64 个字符，禁止换行和 NUL。
- 人数：1-31。
- SI 数量：1-31。
- SI 波次间隔：1-180 秒。
- 普通感染者数量：0-300。
- 玩家操作只接受数字 UserID。
- 管理员身份只接受 Steam2、Steam3 或 SteamID64。
- 积分范围：`-9999999` 到 `9999999`。
- 网页新密码：8-128 个字符；留空保留当前密码。
- MOTD 最大 32768 字节，H 菜单帮助最大 16384 字节，进房公告最大 4096 字节。
