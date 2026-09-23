# L4D2 无限火力战役 PvPvE 服务器

这是一个以官方 Campaign 流程为基础的 Left 4 Dead 2 PvPvE 服务器。它提供无限火力、双主武器、真人普通特感、Tank 抽签、完整 Mutant Tanks 类型池和可配置的真人 Witch 实体控制，不引入 RPG 等级、经验、转生或永久属性。

## 自研插件

当前项目维护并编译 21 个自研 SourceMod 插件。第三方插件、SourceMod 基础插件和运行依赖不在下表中，详见 [`docs/PLUGIN_MANIFEST.md`](docs/PLUGIN_MANIFEST.md)。运行时唯一所有者矩阵见 [`docs/RUNTIME_OWNERSHIP.md`](docs/RUNTIME_OWNERSHIP.md)，性能基线见 [`docs/PERFORMANCE_BASELINE.md`](docs/PERFORMANCE_BASELINE.md)。

| 标题 | 功能 | 链接（自研） |
|---|---|---|
| L4D2 战役商城 | 提供战役内存积分商城，可购买武器、道具和特殊能力；积分不跨战役永久保留。 | [`l4d2_campaign_shop.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_campaign_shop.sp) |
| L4D2 Unicode Hostname | 在引擎配置解析完成后加载并应用 UTF-8 服务器名称。 | [`l4d2_unicode_hostname.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_unicode_hostname.sp) |
| L4D2 Clear Thirdstrike | 使用药丸或肾上腺素时减少一次倒地次数，最低保持为配置的下限。 | [`l4d2_clear_thirdstrike.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_clear_thirdstrike.sp) |
| L4D2 Combat Rewards | 提供战役内战斗回血、Second Wind、Tank 战利品和可部署机枪奖励。 | [`l4d2_combat_rewards.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_combat_rewards.sp) |
| L4D2 Incap Support | 玩家倒地后允许受控移动，并可使用药丸或肾上腺素进行自救。 | [`l4d2_incap_support.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_incap_support.sp) |
| L4D2 PvE Survivor Respawn | 玩家死亡 10 秒后接管复活的 Bot，无 Bot 时直接复活；复活者获得随机普通枪械。 | [`l4d2_pve_respawn.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_pve_respawn.sp) |
| L4D2 Safearea Owner | 负责每章随机开门员、最终安全区 70% 团队 Gate 和 60 秒防卡关传送。 | [`l4d2_end_safearea_teleport.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_end_safearea_teleport.sp) |
| L4D2 PvE Admin | 提供只读状态页和受控管理入口；生产默认禁止直接刷 SI、Tank、Witch 或清实体。 | [`l4d2_pve_admin.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_pve_admin.sp) |
| L4D2 PvE Chinese Help Menu | 提供面向玩家的中文 PvE/PvPvE 开始菜单、指令帮助和欢迎提示。 | [`l4d2_pve_help_menu.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_pve_help_menu.sp) |
| L4D2 PvE Infected Core | 实现战役 PvPvE 队伍切换、真人普通特感、感染者积分和自然 Tank 抽签；不再生成 Tank 或刷新全局 HUD。 | [`l4d2_pve_infected_core.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_pve_infected_core.sp) |
| L4D2 Switch Upgrade Ammo | 支持 Shift+Reload 切换升级弹药，使用事件驱动补给而非永久高频 Timer。 | [`l4d2_switch_upgrade_ammo.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_switch_upgrade_ammo.sp) |
| L4D2 PvE Damage Display | 向攻击者显示 PvE 伤害提示，并提供 Tank 伤害排行。 | [`l4d2_pve_damage_display.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_pve_damage_display.sp) |
| L4D2 Playable Witch | 基于真实 Witch 实体提供玩家控制、镜头、移动、攻击、跳跃和短时狂暴。 | [`l4d2_playable_witch.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_playable_witch.sp) |
| L4D2 PvE Mutant Tank Pool | 校验 Mutant Tanks 的 146 个类型，提供加权随机池、黑白名单和章节计数。 | [`l4d2_pve_mutant_tanks.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_pve_mutant_tanks.sp) |
| L4D2 PvE Director Controller | 按 Recovery/Normal/Pressure 计算 SI 目标、间隔和职业权重，只写 InfectedBots 策略，不生成实体。 | [`l4d2_pve_director_controller.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_pve_director_controller.sp) |
| L4D2 PvE AntiRush | 使用 Left4DHooks 地图 Flow、中位数和安全锚点执行警告、传送及战役积分扣除。 | [`l4d2_pve_antirush.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_pve_antirush.sp) |
| L4D2 PvE Server HUD | 以 1 秒周期显示人数、SI、Flow、Tank/Witch、Profile、击杀、开门员与 AntiRush 状态。 | [`l4d2_pve_server_hud.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_pve_server_hud.sp) |
| L4D2 PvE Performance Guard | 低频监测实体风险并提供 `!pveperf`；只告警或请求 Director 临时 Recovery，不删除未知实体。 | [`l4d2_pve_perf_guard.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_pve_perf_guard.sp) |
| L4D2 PvE Corpse Cleaner | 事件驱动清理死亡 Common Infected；默认不清 Survivor、SI、Tank 或 Witch 尸体。 | [`l4d2_pve_corpse_cleaner.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_pve_corpse_cleaner.sp) |
| L4D2 PvE Overdrive | 通过 WeaponHandling API 提供单局 15 秒临时强化，并在死亡、切队、断线、换图和卸载时恢复倍率。 | [`l4d2_pve_overdrive.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_pve_overdrive.sp) |
| L4D2 Restart Empty | 服务器曾有真人且最后一名真人离开 90 秒后正常退出，由 systemd 拉起；最短间隔 1 小时。 | [`l4d2_restart_empty.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_restart_empty.sp) |

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
| Witch 抽签 | `!witchqueue`、`!nowitch` |
| HUD 开关 | `!hud` |
| 临时 Overdrive | `!overdrive`，或从商城购买 |
| 性能状态 | `!pveperf` |
| 管理员菜单 | `!admin` |

普通特感选择只包含 Smoker、Boomer、Hunter、Spitter、Jockey 和 Charger。Witch 不属于普通 `!zclass` 菜单，只能通过商城、管理员流程或每章一次的可选抽签获得。Hitsound 的 `!snd` 仍是延后候选，在作者源码、声音资源和职责冲突完成固定前不对外宣称可用。

## Playable Witch

Playable Witch 控制的是由 `L4D2_SpawnWitch` 创建的真实 Witch 实体，不把玩家伪装成 `m_zombieClass = 7`。默认同时最多 1 名真人 Witch；章节免费抽签默认概率 35%，只在地图 Flow 25% 至 80% 之间触发，每章最多一次。

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

生产配置 `l4d2_pve_admin_gameplay_write_enable 0`，因此管理员菜单默认只查看 Director、AntiRush、HUD、Witch Lottery、Overdrive、Performance、Corpse Cleaner、Reserved Slots、RestartEmpty 和 Safearea 状态。直接刷 SI/Tank/Witch、清实体、强制尸潮和接管 Tank 的维护入口默认关闭，避免形成第二个 Gameplay Owner。

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

CN77 发布 ZIP 使用字母数字密码加密。首次安装时会在终端交互输入解压密码，并将 `600` 权限的副本保存到目标机 `/etc/l4d2/release_password`，供后续命令行或网页更新使用。密码不写入 Git，也不进入发布 ZIP 的明文文件。

发布 ZIP 和固定依赖默认下载到 `/var/cache/l4d2/`。下载中断时 `.part` 文件会保留，重新运行安装或更新命令会通过 HTTP Range 续传；完成后仍必须通过 SHA-256 校验。发布端 `l4d2-cn77-release.service` 也必须使用项目内的 Range 服务，不得退回不支持续传的 `python3 -m http.server`。

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

最终生产快照（2026-09-22 08:40:57 EDT）：SourceMod `1.12.0.7253`，MetaMod plugins 5，SourceMod extensions 12，active/disabled `.smx` 为 77/15；`l4d2ctl health` PASS。该结论只覆盖启动、加载、配置和 Owner 边界，真人玩法与性能状态见测试报告。

## 测试边界

服务器控制台、RCON、Bot 和隔离启动只能证明加载、配置解析、实体生命周期、计数器、命令和错误日志，不能证明真人输入、镜头、队伍接管、延迟下的移动或 16 名真人并发。

- 自动测试：编译、脚本语法、隔离启动、`meta list`、扩展/插件加载、146 类型名称和边界、Witch 真实实体自测、Tank 池权重/黑白名单/计数、端口和网页健康。
- 真人客户端测试：1、4、8、12、16 人的队伍切换、装备唯一性、Tank/Witch 控制、Mouse1/Space/E/R/Mouse3、镜头、断线、Finale、救援载具、换图和章节结算。

没有真实 Steam 客户端证据时，不得写“16 真人通过”。详细矩阵和未决项见 `docs/TEST_REPORT.md`。
