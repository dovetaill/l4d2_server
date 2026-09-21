# Debian 一键安装与更新

本文档适用于 Debian amd64，将项目和 L4D2 Dedicated Server 统一部署到：

```text
/opt/l4d2
```

脚本日期：2026-09-21。安装脚本不会执行 `git reset --hard`，不会删除已有游戏运行时，也不会覆盖未显式提供的新密码。

## 脚本负责的内容

[`scripts/bootstrap_l4d2.sh`](../scripts/bootstrap_l4d2.sh) 会依次处理：

- 检查必须由 `root` 运行。
- 启用 Debian `i386` 多架构并安装 L4D2 所需的 32 位依赖。
- 创建或复用系统用户 `l4d2srv`。
- 将当前项目非破坏性同步到 `/opt/l4d2`。
- 安装 SteamCMD，并使用匿名登录安装或更新 AppID `222860`。
- 安装固定版本 MetaMod:Source `1.12.0-git1226`。
- 安装固定版本 SourceMod `1.12.0-git7253`。
- 编译项目的自制 SourcePawn 插件；只有编译成功才替换现有 `.smx`。
- 创建 `/etc/l4d2/l4d2.env` 和 `/etc/l4d2/l4d2-admin.env`。
- 创建私密的 `server_private.cfg`。
- 创建并启用 `l4d2.service` 与 `l4d2-web-admin.service`。
- 默认将网页运维面板绑定到 `127.0.0.1:27815`，默认用户名为 `qi`。

## 保留策略

脚本不会删除 `/opt/l4d2` 中的文件。同步项目时明确保留：

- `/opt/l4d2/.git`
- `/opt/l4d2/steamcmd`
- SteamCMD 安装的完整 `server` 运行时
- `server/left4dead2/cfg/server_private.cfg`
- SourceMod 日志和 SQLite 运行数据
- ext4 文件系统的 `lost+found`

如果 `/opt/l4d2` 已存在 Git tracked 修改，`--update` 不会强制重置或覆盖历史。脚本只在自身就在 `/opt/l4d2` 内运行且 tracked 工作区干净时执行：

```bash
git pull --ff-only
```

从其他检出的仓库运行时，当前检出的文件会使用 `rsync` 复制到 `/opt/l4d2`，不使用 `--delete`。

## 首次安装

先取得仓库，然后运行：

```bash
cd /path/to/l4d2_server
sudo ./scripts/bootstrap_l4d2.sh
```

在交互式终端中，首次安装会询问 RCON 和网页管理密码。直接回车会生成随机密码。密码只写入服务器本机的私密文件，不会写入 Git。

无人值守安装应通过进程环境传入密码。不要把真实密码写入仓库脚本、README、Shell history 或 systemd unit：

```bash
sudo env \
  RCON_PASSWORD='replace-at-runtime' \
  WEB_PASSWORD='replace-at-runtime' \
  ./scripts/bootstrap_l4d2.sh
```

还可以同时设置：

```text
WEB_USER     默认 qi
WEB_BIND     默认 127.0.0.1
WEB_PORT     默认 27815
PORT         默认 27015
MAP          默认 c1m1_hotel
TICKRATE     默认 30
GSLT         默认留空
```

脚本不会在版本库中硬编码任何实际 RCON 或网页密码。要使用指定密码，必须在执行时通过环境变量或交互输入提供。

## 仅安装，不启动

```bash
sudo ./scripts/bootstrap_l4d2.sh --no-start
```

此模式仍会创建并启用 systemd unit，但不会启动或重启服务。

## 更新现有服务器

```bash
cd /opt/l4d2
sudo ./scripts/bootstrap_l4d2.sh --update
```

更新模式执行匿名 SteamCMD `app_update 222860`，重新安装固定的 MetaMod/SourceMod 版本，重新应用项目配置，并重新编译自制插件。它不会执行 SteamCMD `validate`，以减少普通更新耗时；首次安装会执行 `validate`。

需要更新但暂不重启：

```bash
sudo ./scripts/bootstrap_l4d2.sh --update --no-start
```

## SourcePawn 编译安全策略

脚本尝试编译：

```text
l4d2_campaign_shop.sp
l4d2_pve_admin.sp
l4d2_pve_help_menu.sp
l4d2_pve_infected_core.sp
l4d2_switch_upgrade_ammo.sp
third_party/l4d2_double_jump.sp
l4d2_pve_damage_display.sp
```

每个插件先输出到临时目录。只有 `spcomp` 返回成功，脚本才将结果原子式安装到 `addons/sourcemod/plugins`。源码缺失或编译失败时会显示警告，并保留服务器上已有的可用 `.smx`。

`l4d2_switch_upgrade_ammo.sp` 的运行时文件名保持为现有部署使用的：

```text
l4d2_switch_ammo.smx
```

## 私密配置

游戏 RCON 文件：

```text
/opt/l4d2/server/left4dead2/cfg/server_private.cfg
```

游戏服务环境：

```text
/etc/l4d2/l4d2.env
```

网页运维环境：

```text
/etc/l4d2/l4d2-admin.env
```

两个 `/etc/l4d2` 环境文件均为 `root:root`、权限 `0600`。网页环境同时保存网页认证信息和本机 RCON 凭据。已有值会被复用；显式传入对应环境变量时才会更新。

`server_private.cfg` 保留已有的其他私密 cvar，只更新其中的 `rcon_password` 行，文件权限为 `0600`。

## systemd 服务

游戏服务：

```bash
systemctl status l4d2 --no-pager -l
journalctl -u l4d2 -n 200 --no-pager
```

网页服务：

```bash
systemctl status l4d2-web-admin --no-pager -l
journalctl -u l4d2-web-admin -n 200 --no-pager
```

网页面板默认只监听本机。推荐通过 SSH 隧道访问：

```bash
ssh -L 27815:127.0.0.1:27815 root@server-address
```

然后在本地浏览器打开：

```text
http://127.0.0.1:27815/
```

不要在没有 HTTPS、反向代理访问控制和防火墙限制的情况下把该面板绑定到公网地址。面板服务为了执行严格白名单内的 systemd 运维操作而以 root 启动，因此本机绑定和强密码是必要条件。

## 安装后检查

```bash
findmnt /opt/l4d2
df -h /opt/l4d2
ls -l /opt/l4d2/server/srcds_run
systemctl is-active l4d2
systemctl is-active l4d2-web-admin
ss -lunp | grep 27015
ss -lntp | grep 27815
```

游戏控制台或 RCON 中继续检查：

```text
meta version
meta list
sm version
sm exts list
sm plugins list
```

SourceMod 错误日志：

```bash
tail -n 200 /opt/l4d2/server/left4dead2/addons/sourcemod/logs/errors_*.log
```

目标状态是没有 `Failed`、`Bad Load`、未解析 native 或缺失 gamedata。
