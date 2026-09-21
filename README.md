# L4D2 无限火力战役 PvPvE 服务器

这是一个非 RPG 的 Left 4 Dead 2 Campaign PvPvE 服务器方案。

- 幸存者阵营：无限火力、双主武器、二段跳、战役商城、回血、Second Wind、Boss 掉落。
- 感染者阵营：真人特感、自由选择普通 SI、感染者商城、Tank 抽签、Mutant Tank 技能。
- AI 系统：尸潮、AI 特感、动态数量、地图 Tank、Finale 修复。
- 不包含：等级、经验、永久属性、转生、职业成长和永久 RPG 数据。

## 固定目录

| 用途 | 路径 |
|---|---|
| 项目源码 | `/home/wwwroot/l4d2` |
| 实际服务器 | `/opt/l4d2` |
| 游戏目录 | `/opt/l4d2/server/left4dead2` |
| SteamCMD | `/opt/l4d2/steamcmd` |
| 启动脚本 | `/opt/l4d2/scripts/start_server.sh` |
| 中文运维脚本 | `/opt/l4d2/scripts/l4d2ctl.sh` |
| 网页运维程序 | `/opt/l4d2/scripts/l4d2_web_admin.py` |
| 游戏服务 | `l4d2.service` |
| 网页服务 | `l4d2-web-admin.service` |

不要把实际密码、GSLT 或其他私密凭据写入本文件。

## 玩家连接

在 L4D2 客户端启用开发者控制台，然后输入：

```text
connect <服务器公网IP>:27015
```

默认游戏端口是 UDP `27015`。

## 玩家常用指令

| 功能 | 指令 |
|---|---|
| 打开中文开始菜单 | `!菜单`、`!pvehelp` |
| 打开战役商城 | `!buy`、`!shop` |
| 查看当前战役积分 | `!points`、`!money` |
| 加入真人感染者 | `!infected`、`!特感` |
| 返回幸存者阵营 | `!survivor`、`!人类` |
| 选择普通特感 | `!zclass`、`!特感选择` |
| 加入 Tank 抽签 | `!tankqueue` |
| 退出 Tank 抽签 | `!notank` |
| 打开管理员菜单 | `!admin` |
| 查看帮助页 | 按 `H` |

普通特感菜单包含 Smoker、Boomer、Hunter、Spitter、Jockey 和 Charger。Tank 与 Witch 不在普通职业菜单中。

## 管理员使用

当前管理员身份应保存在：

```text
/opt/l4d2/server/left4dead2/addons/sourcemod/configs/admins_simple.ini
```

添加管理员：

```bash
sudo /opt/l4d2/scripts/l4d2ctl.sh set-admin 'STEAM_0:1:126011599' z
```

游戏中验证：

```text
!admin
sm_who
```

查看服务器状态和在线玩家：

```bash
sudo /opt/l4d2/scripts/l4d2ctl.sh status
```

踢出指定 UserID：

```bash
sudo /opt/l4d2/scripts/l4d2ctl.sh kick 12
```

增加战役积分：

```bash
sudo /opt/l4d2/scripts/l4d2ctl.sh add-points 12 1000
```

积分是当前 Campaign 范围的数据，不是永久 RPG 数据。

## 中文运维脚本

直接打开交互菜单：

```bash
sudo /opt/l4d2/scripts/l4d2ctl.sh
```

菜单支持：

- 启动、停止、重启和更新服务。
- 查看服务状态、健康状态和在线玩家。
- 设置大厅名称、人数、难度、SI 数量、SI 波次间隔和普通感染者数量。
- 踢出玩家、增加积分和添加管理员。
- 修改 MOTD、H 菜单帮助、进房公告。
- 修改网页面板账户、密码、监听地址和端口。

常用非交互命令：

```bash
sudo /opt/l4d2/scripts/l4d2ctl.sh start
sudo /opt/l4d2/scripts/l4d2ctl.sh stop
sudo /opt/l4d2/scripts/l4d2ctl.sh restart
sudo /opt/l4d2/scripts/l4d2ctl.sh status
sudo /opt/l4d2/scripts/l4d2ctl.sh health
sudo /opt/l4d2/scripts/l4d2ctl.sh update
```

设置大厅和战斗参数：

```bash
sudo /opt/l4d2/scripts/l4d2ctl.sh set-name '无限火力战役 PvPvE'
sudo /opt/l4d2/scripts/l4d2ctl.sh set-slots 16
sudo /opt/l4d2/scripts/l4d2ctl.sh set-difficulty Hard
sudo /opt/l4d2/scripts/l4d2ctl.sh set-si-count 12
sudo /opt/l4d2/scripts/l4d2ctl.sh set-si-interval 25
sudo /opt/l4d2/scripts/l4d2ctl.sh set-common-limit 60
```

## systemd 运维

```bash
sudo systemctl start l4d2
sudo systemctl stop l4d2
sudo systemctl restart l4d2
sudo systemctl status l4d2 --no-pager -l
sudo journalctl -u l4d2 -n 200 --no-pager
```

网页面板：

```bash
sudo systemctl restart l4d2-web-admin
sudo systemctl status l4d2-web-admin --no-pager -l
```

## 网页运维面板

网页面板默认只监听：

```text
127.0.0.1:27815
```

从管理电脑建立 SSH 隧道：

```bash
ssh -N -L 27815:127.0.0.1:27815 root@<服务器公网IP>
```

然后浏览器访问：

```text
http://127.0.0.1:27815/
```

网页账户、密码和端口保存在：

```text
/etc/l4d2/l4d2-admin.env
```

文件权限应为 `0600`。不要直接把内置 HTTP 面板暴露到公网；如确需公网访问，应使用防火墙白名单和 HTTPS 反向代理。

网页支持：

- 启动、停止、重启和更新。
- 设置大厅名称、人数、难度、SI 数量、波次间隔和普通感染者数量。
- 查看在线玩家、踢人、增加积分、添加管理员。
- 修改 MOTD、H 菜单内容和进房公告。
- 修改网页账户、密码、监听地址和端口。

## 私密配置

RCON 配置：

```text
/opt/l4d2/server/left4dead2/cfg/server_private.cfg
```

网页和 RCON 环境配置：

```text
/etc/l4d2/l4d2-admin.env
```

游戏启动环境：

```text
/etc/l4d2/l4d2.env
```

建议权限：

```bash
sudo chmod 600 /etc/l4d2/l4d2.env
sudo chmod 600 /etc/l4d2/l4d2-admin.env
sudo chmod 600 /opt/l4d2/server/left4dead2/cfg/server_private.cfg
```

## 当前插件健康状态

当前生产检查结果：

- MetaMod:Source `1.12.0-git1226`。
- SourceMod `1.12.0-git7253`。
- Left4DHooks `1.168`。
- Actions `3.9.2`。
- SourceMod 插件 64 个。
- SourceMod 扩展 12 个。
- Command Buffer Fixer `2.11` 已加载。
- 当前没有 `Failed`、`Bad Load`、missing native 或 missing gamedata。

MetaMod 在 32 位 L4D2 启动时可能先尝试 `linux64/server.so` 并打印架构提示，随后会加载正确的 32 位模块。只要 `meta list`、`sm plugins list` 和 `sm exts list` 正常，这条提示本身不代表服务器启动失败。

## 日常健康检查

```bash
sudo /opt/l4d2/scripts/l4d2ctl.sh health
sudo systemctl status l4d2 --no-pager -l
sudo systemctl status l4d2-web-admin --no-pager -l
sudo ss -lunp | grep 27015
sudo journalctl -u l4d2 -n 200 --no-pager
```

SourceMod 错误日志：

```bash
sudo find /opt/l4d2/server/left4dead2/addons/sourcemod/logs \
  -type f -name 'errors_*.log' -printf '%T@ %p\n' \
  | sort -nr | head
```

游戏控制台检查：

```text
meta list
sm version
sm exts list
sm plugins list
```

目标：

```text
Failed = 0
Bad Load = 0
missing native = 0
missing gamedata = 0
```

# 全新 Debian 服务器从零部署

## 前置条件

- Debian 13 amd64。
- `/opt/l4d2` 已挂载到准备存放游戏数据的磁盘。
- root 权限。
- 至少放行 UDP `27015`。
- 能访问 SteamCMD、AlliedModders 和项目发布地址。

确认磁盘：

```bash
findmnt /opt/l4d2
df -h /opt/l4d2
```

## 下载部署包

以下方式不要求管理员手工管理项目版本历史，只下载当前主分支归档：

```bash
sudo apt update
sudo apt install -y curl ca-certificates tar gzip
sudo install -d -m 0755 /opt/l4d2
sudo curl -fL \
  https://github.com/dovetaill/l4d2_server/archive/refs/heads/main.tar.gz \
  -o /tmp/l4d2-server.tar.gz
sudo tar -xzf /tmp/l4d2-server.tar.gz \
  --strip-components=1 \
  -C /opt/l4d2
sudo chmod +x /opt/l4d2/scripts/*.sh
```

## 创建部署私密参数

每台服务器建议使用不同的 RCON 和网页密码：

```bash
sudo install -d -m 0700 /root/l4d2-bootstrap
sudo nano /root/l4d2-bootstrap/deploy.env
```

内容示例：

```bash
RCON_PASSWORD='为本机设置强密码'
WEB_USER='qi'
WEB_PASSWORD='为本机设置网页强密码'
WEB_BIND='127.0.0.1'
WEB_PORT='27815'
PORT='27015'
MAP='c1m1_hotel'
TICKRATE='30'
GSLT=''
```

保护文件：

```bash
sudo chmod 600 /root/l4d2-bootstrap/deploy.env
```

## 一键安装

```bash
sudo bash -c '
  set -a
  source /root/l4d2-bootstrap/deploy.env
  set +a
  exec /opt/l4d2/scripts/bootstrap_l4d2.sh
'
```

脚本设计为重复执行时保留已有游戏目录和私密配置，不删除 SteamCMD、游戏本体、日志或数据库。

当前版本能够自动完成：

- Debian i386 依赖。
- `l4d2srv` 服务账户。
- SteamCMD 与 AppID `222860`。
- MetaMod 和 SourceMod。
- 自制 SourcePawn 插件编译。
- RCON 私密配置。
- systemd 游戏服务和网页服务。

> 重要：完整第三方 Runtime 的全新服务器自动恢复仍列在 `docs/NEXT_WINDOW_REMAINING_TASKS_PROMPT.md` 中。完成该任务前，新机器的一键安装只能视为基础安装，不能视为与当前生产服务器完全一致。

## 首次部署后检查

```bash
sudo systemctl status l4d2 --no-pager -l
sudo systemctl status l4d2-web-admin --no-pager -l
sudo /opt/l4d2/scripts/l4d2ctl.sh health
sudo ss -lunp | grep 27015
```

添加管理员：

```bash
sudo /opt/l4d2/scripts/l4d2ctl.sh set-admin 'STEAM_0:1:126011599' z
```

客户端连接：

```text
connect <服务器公网IP>:27015
```

## 多台服务器批量部署原则

- 所有机器统一使用 `/opt/l4d2`。
- 所有机器使用同一个安装入口：`scripts/bootstrap_l4d2.sh`。
- 每台机器使用独立的 `/root/l4d2-bootstrap/deploy.env`。
- 每台机器使用独立的 RCON 密码；网页账户可以统一，但密码仍建议分开。
- 不要把 `/etc/l4d2` 或 `server_private.cfg` 放进公开部署包。
- 部署完成后必须检查插件列表和错误日志，不能只判断进程是否存在。

## 防火墙

使用 UFW 时：

```bash
sudo apt install -y ufw
sudo ufw allow 27015/udp
```

RCON 不建议直接对全网开放。网页面板默认只监听本机，不需要开放 `27815`。

## 剩余开发任务

剩余任务的完整新窗口执行说明保存在：

```text
/home/wwwroot/l4d2/docs/NEXT_WINDOW_REMAINING_TASKS_PROMPT.md
```

完成其中任务后，应再次更新本 README 的一键部署能力说明和最终验证结果。
