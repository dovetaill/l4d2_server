# L4D2 无限火力战役 PvPvE 服务器

这是一个以官方 Campaign 流程为基础的 Left 4 Dead 2 PvPvE 服务器。它提供无限火力、双主武器、真人普通特感、Tank 抽签、完整 Mutant Tanks 类型池和可配置的真人 Witch 实体控制，不引入 RPG 等级、经验、转生或永久属性。

## 目录与服务

| 用途 | 路径 |
|---|---|
| 源码与发布工程 | `/home/wwwroot/l4d2` |
| 实际运行目录 | `/opt/l4d2` |
| 游戏目录 | `/opt/l4d2/server/left4dead2` |
| SteamCMD | `/opt/l4d2/steamcmd` |
| 游戏启动脚本 | `/opt/l4d2/scripts/start_server.sh` |
| 运维脚本 | `/opt/l4d2/scripts/l4d2ctl.sh` |
| 网页面板 | `/opt/l4d2/scripts/l4d2_web_admin.py` |
| 游戏服务 | `l4d2.service` |
| 网页服务 | `l4d2-web-admin.service` |

密码、GSLT、RCON 和私密配置只存在服务器本机的受保护文件中，不写入本 README、发布归档或版本库。

## 玩家使用

```text
connect <服务器公网IP>:27015
```

| 功能 | 指令 |
|---|---|
| 中文开始菜单 | `!菜单`、`!pvehelp` |
| 战役商城 | `!buy`、`!shop` |
| 当前战役积分 | `!points`、`!money` |
| 加入感染者 | `!infected`、`!特感` |
| 返回幸存者 | `!survivor`、`!人类` |
| 普通特感选择 | `!zclass`、`!特感选择` |
| Tank 抽签 | `!tankqueue`、`!notank` |
| 管理员菜单 | `!admin` |

普通特感选择只包含 Smoker、Boomer、Hunter、Spitter、Jockey 和 Charger。Witch 不属于普通 `!zclass` 菜单，只能通过商城、管理员流程或低概率随机流程获得。

## Playable Witch

Playable Witch 控制的是由 `L4D2_SpawnWitch` 创建的真实 Witch 实体，不把玩家伪装成 `m_zombieClass = 7`。默认同时最多 1 名真人 Witch，每名玩家每章默认最多购买 1 次。

- Mouse1：近距离攻击。
- Space：跳跃。
- E：短时温和 Rage，只提供短时速度和抗硬直；不提供激光、火球、陨石或闪现。
- 死亡、断线、换队、过场、Finale 或换图时清理实体和镜头。
- 死亡后恢复为普通感染者 Ghost。
- 独立开关：`pve_playable_witch_enable 0/1`。

模块加载失败或关闭时，不应阻断普通 SI、商城、Tank 抽签和章节结束流程。

## 管理员操作

管理员文件：

```text
/opt/l4d2/server/left4dead2/addons/sourcemod/configs/admins_simple.ini
```

常用命令：

```text
sm_pvetank <target> <1-146>
sm_pvewitch <target>
sm_pvemtvalidate
sm_pvemtstats
sm_pvewitch_validate
sm_pvewitch_selftest
```

`sm_pvetank` 可让自己或目标玩家成为任意有效的 Mutant Tanks 类型。菜单必须分页显示全部 146 个有效类型；管理员强制类型可以选择默认随机池排除的惩罚、测试、Slacker、Rusher 等类型。管理员测试、商城购买和正常随机 Tank 使用独立计数。

## 网页面板

网页服务默认只监听 `127.0.0.1:27815`。推荐通过 SSH 隧道访问：

```bash
ssh -N -L 27815:127.0.0.1:27815 root@<服务器地址>
```

然后打开 `http://127.0.0.1:27815/`。网页认证、RCON、绑定地址和端口保存在 `/etc/l4d2/l4d2-admin.env`。不要在没有 HTTPS、访问控制和防火墙白名单的情况下把面板绑定到公网。

## 一键部署与发布归档更新

新服务器使用 Debian 13 amd64、root 权限、可用网络和可写 `/opt/l4d2`。部署入口是发布归档内的 `/opt/l4d2/scripts/bootstrap_l4d2.sh`。

安装器必须从固定发布清单下载并校验 SteamCMD、MetaMod:Source、SourceMod、L4DToolZ、Left4DHooks、Actions、InfectedBots、Mutant Tanks、SMAC 和所有第三方伴随文件。下载失败、版本不符、SHA-256 不符或伴随文件缺失时必须终止，不得生成半成品 Runtime。完整锁定表见 `docs/MANUAL_DOWNLOADS.md`。

发布更新通过版本归档和清单完成，不要求管理员手工执行版本控制命令：

```bash
sudo env \
  L4D2_RELEASE_ARCHIVE_URL='https://发布系统.example/l4d2-server-v<版本>.tar.gz' \
  L4D2_RELEASE_ARCHIVE_SHA256='<发布归档的完整64位SHA256>' \
  /opt/l4d2/scripts/l4d2ctl.sh update
```

更新必须保留 SteamCMD、游戏数据、日志、SQLite、第三方 Runtime、`/etc/l4d2/*.env` 和 `cfg/server_private.cfg`，并在成功编译全部自制插件后才替换 `.smx`。测试时可使用 `L4D2_TARGET_ROOT` 等环境变量把 Runtime 放入隔离临时目录；不得依赖源码目录中未纳入发布包的缓存。

## 健康检查与故障排查

```bash
sudo systemctl status l4d2 --no-pager -l
sudo systemctl status l4d2-web-admin --no-pager -l
sudo /opt/l4d2/scripts/l4d2ctl.sh health
sudo ss -lunp | grep 27015
sudo ss -lntp | grep 27815
```

在 RCON 或服务器控制台检查：

```text
meta list
sm version
sm exts list
sm plugins list
```

验收目标：`Failed = 0`、`Bad Load = 0`、`missing native = 0`、`missing gamedata = 0`、`Cbuf_AddText: buffer overflow = 0`、`KeyValues Error = 0`。

32 位 L4D2 使用 `addons/metamod/bin/server.so` 和 `addons/metamod.vdf`。发布安装时必须禁用会尝试加载 64 位模块的 `addons/metamod_x64.vdf`，但不得删除 `bin/linux64/server.so` 或正常工作的 32 位文件。修复后以 `meta list` 和新启动日志确认不再出现错误的 x64 VDF 探测。

## 测试边界

服务器控制台、RCON、Bot 和隔离启动只能证明加载、配置解析、实体生命周期、计数器、命令和错误日志，不能证明真人输入、镜头、队伍接管、延迟下的移动或 16 名真人并发。

- 自动测试：编译、脚本语法、隔离启动、`meta list`、扩展/插件加载、146 类型名称和边界、Witch 真实实体自测、Tank 池权重/黑白名单/计数、端口和网页健康。
- 真人客户端测试：1、4、8、12、16 人的队伍切换、装备唯一性、Tank/Witch 控制、Mouse1/Space/E/R/Mouse3、镜头、断线、Finale、救援载具、换图和章节结算。

没有真实 Steam 客户端证据时，不得写“16 真人通过”。详细矩阵和未决项见 `docs/TEST_REPORT.md`。
