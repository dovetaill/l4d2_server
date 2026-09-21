# Debian 13 一键安装与归档更新

适用平台：Debian 13 amd64，L4D2 服务端使用 32 位运行时。默认运行目录为 `/opt/l4d2`，服务用户为 `l4d2srv`。本文档对应 2026-09-21 的脚本实现。

## 安装器职责

`scripts/bootstrap_l4d2.sh` 会：

- 安装 i386 运行依赖并创建或复用 `l4d2srv`。
- 使用 SteamCMD 匿名安装或更新 AppID `222860`。
- 从 `scripts/l4d2_artifact_manifest.sh` 下载并校验固定 SHA-256 的 MetaMod:Source、SourceMod、L4DToolZ、Actions 3.9.2、Left4DHooks 1.168、Mutant Tanks 9.3、Dynamic Balancer 以及固定作者源码快照。
- 安装 InfectedBots 3.0.8、spawn nolimit、AI_HardSI、MultiSlots、CreateSurvivorBot、bot/deathcheck/upgrade-pack 修复、自动武器/双主武器/Gear Transfer/Item Hint、SMAC 选定模块及其他清单内伴随文件。
- 复制完整的插件、gamedata、translations、data、cfg、configs 和 include；下载或解压失败、哈希不匹配会立即终止。
- 使用生产 SourceMod 1.12.0.7253 编译全部项目插件，成功后才替换 `.smx`。编译包含 `-iinclude`，不会因本地 include 搜索路径缺失而误报。
- 禁用 `addons/metamod_x64.vdf`，保留正常的 `addons/metamod.vdf`、32 位 `bin/server.so` 和其他非 L4D2 二进制。
- 非破坏性同步项目文件，保留 SteamCMD、游戏数据、第三方 Runtime、日志、SQLite、`server_private.cfg` 和 `/etc/l4d2/*.env`。

更新过程不在运行目录执行版本控制命令，也不会自动删除未跟踪 Runtime。正式更新应使用经过 SHA-256 校验的发布归档。

## 首次安装

```bash
sudo env RCON_PASSWORD='只在进程环境提供' WEB_PASSWORD='只在进程环境提供' \
  ./scripts/bootstrap_l4d2.sh
```

未提供密码时，交互终端会询问；直接回车生成随机值。密码、GSLT 和私密配置只写入服务器本机，不进入源码。无人值守场景不要把真实值写入脚本、README、shell history 或提交内容。

可选环境变量：`WEB_USER`、`WEB_BIND`、`WEB_PORT`、`PORT`、`MAP`、`TICKRATE`、`GSLT`。

只安装不启动：

```bash
sudo ./scripts/bootstrap_l4d2.sh --no-start
```

## 归档更新

控制脚本通过发布归档更新，不从 `/opt/l4d2` 的 VCS 元数据取版本：

```bash
sudo env \
  L4D2_RELEASE_ARCHIVE_URL='https://发布系统.example/l4d2.tar.gz' \
  L4D2_RELEASE_ARCHIVE_SHA256='发布归档的完整64位SHA256' \
  /opt/l4d2/scripts/l4d2ctl.sh update
```

归档必须包含 `scripts/bootstrap_l4d2.sh` 和清单文件。控制脚本会为每次更新创建独立临时目录，并在下载、SHA-256 校验、解压、bootstrap 或重启成功和失败的所有退出路径执行清理。更新会保留 `/etc/l4d2/l4d2.env`、`/etc/l4d2/l4d2-admin.env`、`cfg/server_private.cfg`、日志、SQLite、SteamCMD 和第三方 Runtime；全部插件编译成功后才重启服务。

## 隔离验证

测试时可把目标和配置目录改到临时目录，并跳过系统写入：

```bash
L4D2_TARGET_ROOT=/tmp/l4d2-test \
L4D2_ETC_ROOT=/tmp/l4d2-test-etc \
L4D2_SKIP_APT=1 L4D2_SKIP_STEAM=1 L4D2_SKIP_FRAMEWORKS=1 \
L4D2_SKIP_PRIVATE_CONFIG=1 L4D2_SKIP_SERVICES=1 \
./scripts/bootstrap_l4d2.sh --update --no-start
```

隔离测试结束必须停止所有临时进程并删除本次创建的临时目录；不得对 `/opt/l4d2` 使用删除式清理。

## 安装后检查

```bash
systemctl is-active l4d2 l4d2-web-admin
ss -lunp | grep 27015
ss -lntp | grep 27815
```

RCON 中检查：`meta list`、`sm version`、`sm exts list`、`sm plugins list`、`sm_pvemtvalidate`、`sm_pvewitch_validate`。目标状态是 MetaMod/SourceMod、扩展和插件全部加载，没有 `Failed`、`Bad Load`、缺失 gamedata 或未解析 native。
