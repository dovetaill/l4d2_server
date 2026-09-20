# L4D2 高难非 RPG 战役 PvE 服务器

这是一个面向中国玩家的 Left 4 Dead 2 Dedicated Server 部署目录。玩法目标是：无限火力、无限弹匣不换弹、多人 Survivor、多人特感、疯狂尸潮、技能 Tank、击杀回血、Second Wind、Tank 掉宝、战役内 `!buy` 商城和完全无友伤。

**明确不做：** RPG、等级、经验、永久属性、转生、职业、Gun XP、PerkMod、Melee Fatigue、反伤型反友伤系统。

文档状态：2026-09-20（America/New_York）

## 当前状态

- 系统：Debian GNU/Linux 13，x86_64 主机，32 位 L4D2 Server。
- 服务器目录：`/home/wwwroot/l4d2/server`。
- 游戏目录：`/home/wwwroot/l4d2/server/left4dead2`。
- 启动脚本：[`scripts/start_server.sh`](scripts/start_server.sh)。
- 当前公开目标：12 名真人 Survivor；引擎和 MultiSlots 配置保留到 31 槽，后续可扩展到 16 名 Survivor。
- 最新管理员插件启动探针：60 个 SourceMod 插件、12 个扩展加载成功，没有 `Failed` 或 `Bad Load`。
- 尚未完成真实 Steam 客户端的 1/4/8/12 人功能测试；`!admin` 菜单、SteamID 认证、战斗行为和 Tank 平衡仍需要实际进服验证。
- 已知启动噪声：部分地图会出现 `Cbuf_AddText: buffer overflow`，目前不等于插件加载失败，需在长期运行时继续观察。

详细部署清单、测试证据和回滚资料：

- [`docs/PLUGIN_MANIFEST.md`](docs/PLUGIN_MANIFEST.md)
- [`docs/TEST_REPORT.md`](docs/TEST_REPORT.md)
- [`docs/CONFIG_NOTES.md`](docs/CONFIG_NOTES.md)
- [`docs/ROLLBACK.md`](docs/ROLLBACK.md)
- [`docs/MANUAL_DOWNLOADS.md`](docs/MANUAL_DOWNLOADS.md)
- [`install_manifest.md`](install_manifest.md)

## 目录结构

```text
/home/wwwroot/l4d2/
├── README.md
├── docs/                         # 部署、配置、测试、回滚文档
├── scripts/start_server.sh       # 启动入口
├── server/                       # 实际 Dedicated Server
│   └── left4dead2/
│       ├── addons/metamod/
│       ├── addons/sourcemod/
│       │   ├── configs/
│       │   ├── plugins/
│       │   └── scripting/
│       └── cfg/
├── sources/                      # 第三方源码和解压源文件
├── incoming/                     # 手动下载文件暂存目录
├── backups/                      # 安装前和分阶段备份
├── archives/                     # 小型归档
└── logs/                         # 本地部署日志
```

Git 不提交完整游戏运行时、VPK、地图素材、Steam 缓存、日志、备份和归档；这些文件仍保留在服务器目录中。源码、SourceMod 配置、自制插件、文档和启动脚本会纳入版本控制。

## 快速启动

生产运行建议使用 `l4d2srv` 用户，不要用 root 启动：

```bash
cd /home/wwwroot/l4d2
runuser -u l4d2srv -- env \
  PORT=27015 \
  MAP=c1m1_hotel \
  TICKRATE=30 \
  /home/wwwroot/l4d2/scripts/start_server.sh
```

脚本会进入 `server/`，执行 `srcds_run`，并固定传入：

- `sv_setmax 31`
- `-maxplayers 31`
- 指定地图和 tickrate

公开人数仍由 [`server/left4dead2/cfg/server.cfg`](server/left4dead2/cfg/server.cfg) 和 MultiSlots 配置控制。启动前先把 `server.cfg` 中的：

```cfg
rcon_password "CHANGE_ME_BEFORE_PUBLIC_USE"
```

替换成真实的强密码。不要把真实 RCON 密码提交到 Git。

停止服务器时，在服务器控制台输入：

```text
quit
```

也可以使用现有 RCON 工具发送 `quit`。不要直接删除进程作为常规停止方式。

## 玩家常用功能

玩家进入 Survivor 队伍后可以使用：

| 操作 | 用法 |
|---|---|
| 战役商城 | `!buy` 或 `!shop` |
| 查看战役积分 | `!points` 或 `!money` |
| 部署 Tank 掉落的加特林 | `!minigun` |
| AFK / 回到 Survivor | `!away`、`!join`，具体别名以已安装 AFK 插件为准 |
| 投票踢人 | `!vk`，由 Votekick 插件提供 |
| 特殊弹切换 | `Shift + Reload` |

商城积分是**当前战役货币**：保存在内存中，跨章节保留；进入新 Campaign 或触发 `mission_lost` 时清零，不写永久成长数据库。

## SourceMod 管理员配置

管理员系统使用 SourceMod 原生 SteamID 认证，不使用昵称，也不需要额外管理员账号插件。

### 添加服主 Root

1. 进自己的 L4D2，在游戏控制台输入：

   ```text
   status
   ```

2. 找到自己的 Steam2 ID，例如：

   ```text
   STEAM_1:0:123456789
   ```

3. 编辑：

   ```text
   server/left4dead2/addons/sourcemod/configs/admins_simple.ini
   ```

4. 添加一行：

   ```text
   "STEAM_1:0:123456789"    "99:z"
   ```

   把示例 ID 换成 `status` 显示的真实 ID。`99` 是免疫等级，`z` 是 Root 全权限。

5. 在服务器控制台执行：

   ```text
   sm_reloadadmins
   ```

6. 重新进服后验证：

   ```text
   !admin
   sm_who
   ```

不要把真实 SteamID 当作密码，也不要把 RCON 密码写进 `admins_simple.ini`。本仓库不会替你猜 SteamID，也没有提交真实服主账号。

### 普通管理员

不要把所有协管员都授予 `z`。可以按 SourceMod flags 分配踢人、Ban、换图、语音等最小权限。积分修改命令要求 Root 或 `custom6` 权限；完整权限模型由 SourceMod 的 `admin_levels.cfg` 和 `admins_simple.ini` 控制。

## L4D2 PvE 管理插件

自制插件源码和编译结果：

- 源码：[`server/left4dead2/addons/sourcemod/scripting/l4d2_pve_admin.sp`](server/left4dead2/addons/sourcemod/scripting/l4d2_pve_admin.sp)
- 插件：`server/left4dead2/addons/sourcemod/plugins/l4d2_pve_admin.smx`
- 审计日志：`server/left4dead2/addons/sourcemod/logs/pve_admin.log`
- 版本：`1.0.0`

插件只使用 SourceMod 管理权限；不会创建第二套管理员数据库。它把功能加入原生 `!admin` 菜单，并提供命令行入口。

### 游戏内菜单

服主或有相应权限的管理员输入：

```text
!admin
```

在 `L4D2 PvE 管理` 下可以看到：

- **玩家管理**：治疗、复活、处死、踢出、Ban 60 分钟。
- **装备管理**：给 Survivor 武器、医疗、投掷物。
- **积分管理**：查看、增加 10/50/100、清空战役积分。需要 Root 或 `custom6`。
- **感染者 / Boss 测试**：生成 Smoker、Boomer、Hunter、Spitter、Jockey、Charger、Tank、Witch；触发尸潮；清除普通特感或 Tank。
- **服务器维护 / 信息**：查看地图和感染者计数、重载商城、重载管理员缓存。

生成特感、Tank 和 Witch 使用 Left4DHooks 的生成 API，不通过打开 `sv_cheats 1` 来实现。生成位置优先使用玩家附近的有效特感出生点，仅用于管理员测试。

### 命令行入口

```text
sm_pveadmin
sm_pvegive <target> <item>
sm_pveheal <target>
sm_pverevive <target>

sm_pvepoints [target]
sm_pveaddpoints <target> <amount>
sm_pvesetpoints <target> <amount>

sm_pvespawn <smoker|boomer|hunter|spitter|jockey|charger|tank|witch>
sm_pvehorde
sm_pveinfo
sm_pvereloadshop
```

`<target>` 支持 SourceMod 目标格式，例如 `@me`、`@all`、`#userid` 或玩家名。装备命令只接受白名单物品，常用别名包括：

```text
ak47, rifle, rifle_scar, rifle_sg552
smg, smg_mp5, autoshotgun, shotgun_spas
hunting_rifle, sniper_military, sniper_awp, sniper_scout
m60, grenade_launcher, pistol, pistol_magnum
fireaxe, katana, first_aid_kit, defibrillator
pain_pills, adrenaline, molotov, pipe_bomb
```

示例：

```text
sm_pvegive @me rifle_m60
sm_pvegive Sumo first_aid_kit
sm_pveaddpoints Sumo 50
sm_pvesetpoints Sumo 0
sm_pvespawn tank
```

每次给装备、修改积分、生成 Boss、清除感染者、踢人、Ban、重载配置都会写入 `pve_admin.log`，包含管理员和目标的 Steam2 ID、操作和参数。日志不会写 RCON 密码。

## 商城积分 API

原来的 `l4d2_campaign_shop.sp` 已补充三个 SourceMod native，管理员插件通过 API 调用，不直接访问商店内部数组：

```text
L4D2CampaignShop_GetPoints(client)
L4D2CampaignShop_AddPoints(client, amount)
L4D2CampaignShop_SetPoints(client, points)
```

声明文件：

```text
server/left4dead2/addons/sourcemod/scripting/include/l4d2_campaign_shop.inc
```

如果 `l4d2_campaign_shop.smx` 没有加载，管理员插件会显示 API 不可用，而不会自己创建 SQLite 或另一套积分数据。

## 重新编译自制插件

使用服务器自带 SourceMod 1.12 编译器：

```bash
cd /home/wwwroot/l4d2/server/left4dead2/addons/sourcemod/scripting

./spcomp l4d2_campaign_shop.sp \
  -iinclude \
  -o../plugins/l4d2_campaign_shop.smx

./spcomp l4d2_pve_admin.sp \
  -iinclude \
  -o../plugins/l4d2_pve_admin.smx
```

成功后可以在服务器控制台加载或重载：

```text
sm plugins reload l4d2_campaign_shop
sm plugins load l4d2_pve_admin
sm plugins list
```

如果修改了 `l4d2_campaign_shop.inc` 的 native 声明，必须重新编译商店和管理员插件。生产环境建议重启服务器，而不是在战役中重载会清空状态的插件。

## 关键配置

### 当前 12 人档

- `server/left4dead2/cfg/server.cfg`
  - `sv_visiblemaxplayers 12`
  - `sv_maxplayers 12`
  - `sv_setmax 31`
  - `sv_force_unreserved 1`
  - `z_difficulty Hard`
  - `sm_cvar sv_infinite_ammo 1`
- `server/left4dead2/cfg/sourcemod/l4dmultislots.cfg`
  - `l4d_multislots_max_survivors "12"`
- `server/left4dead2/cfg/pve_core.cfg`
- `server/left4dead2/cfg/pve_balance.cfg`
- `server/left4dead2/cfg/sourcemod/l4d2_campaign_shop.cfg`

### 改成 16 人

先停止服务器，再同时修改：

```cfg
// server/left4dead2/cfg/server.cfg
sv_visiblemaxplayers 16
sv_maxplayers 16
sv_setmax 31

// server/left4dead2/cfg/sourcemod/l4dmultislots.cfg
l4d_multislots_max_survivors "16"
```

启动脚本继续使用 `-maxplayers 31`。改成 16 人后必须重新测试实体数量、网络 choke、普通感染者上限、SI 数量、Tank HP、Finale 救援和换图流程，不建议只改一个数字就公开运行。

### 单一系统所有权

| 系统 | 唯一控制者 |
|---|---|
| SI 数量和刷新 | InfectedBots |
| SI AI | AI_HardSI |
| 普通感染者数量 | Dynamic Infected Balancer |
| Tank HP 和技能 | Mutant Tanks |
| 友伤 | No Friendly-Fire |
| 商城和战役积分 | L4D2 Campaign Shop |
| 击杀回血、Second Wind、Tank 掉宝 | L4D2 Combat Rewards |
| 管理权限和菜单 | SourceMod + L4D2 PvE Admin |

不要再安装第二个会修改同一批 Director ConVar、Tank HP、SI 数量或积分数据库的插件。

## 检查和故障排查

服务器控制台常用检查：

```text
meta version
meta list
sm version
sm exts list
sm plugins list
sm_who
```

重点检查：

- `sm plugins list` 中没有 `Failed` 或 `Bad Load`。
- `sm exts list` 中 Left4DHooks、DHooks、SDKHooks、TopMenus 正常加载。
- `server/left4dead2/addons/sourcemod/logs/errors_*.log` 没有新的加载错误。
- `server/left4dead2/addons/sourcemod/logs/pve_admin.log` 能记录管理员操作。
- `sm_reloadadmins` 后 `sm_who` 能看到自己的 Root 权限。
- `!admin` 能打开 SourceMod 原生菜单，且能看到 `L4D2 PvE 管理`。

如果插件加载失败，先确认：

1. `l4d2_campaign_shop.smx` 在 `plugins/` 根目录。
2. `l4d2_pve_admin.smx` 在 `plugins/` 根目录。
3. `left4dhooks.smx` 已加载。
4. 自制插件是用同一套 SourceMod 1.12 `spcomp` 编译。
5. `sm plugins list` 和错误日志的实际报错，而不是只看文件是否存在。

## 回滚

完整回滚步骤见 [`docs/ROLLBACK.md`](docs/ROLLBACK.md)。最小回滚方式：

```bash
mv server/left4dead2/addons/sourcemod/plugins/l4d2_pve_admin.smx \
   server/left4dead2/addons/sourcemod/plugins/disabled/
```

如果回滚积分 API 版本，同时恢复旧的 `l4d2_campaign_shop.smx`，管理员插件也应一并移到 `plugins/disabled/`，因为它依赖新增的 native。

安装阶段备份位于 `backups/`，例如：

- `backups/phase4_pre_20260920_014702.tar.gz`
- `backups/phase7a_pre_20260920_020638.tar.gz`
- `backups/compact_cfg_20260920_0300/`

## Git 用法

本目录是本地 Git 仓库，默认分支为 `main`。Git 主要管理源码、配置和文档，不替代服务器备份。

查看状态和变更：

```bash
cd /home/wwwroot/l4d2
git status
git diff
git log --oneline --decorate -10
```

提交自己的修改：

```bash
git add README.md docs/ server/left4dead2/addons/sourcemod/scripting \
  server/left4dead2/addons/sourcemod/configs \
  server/left4dead2/cfg scripts .gitignore

git commit -m "Update L4D2 PvE admin system"
```

查看某次提交：

```bash
git show --stat --oneline HEAD
git show HEAD -- README.md
```

添加远程仓库并推送。远程地址必须由你自己提供，当前仓库没有预设远程：

```bash
git remote add origin <你的 Git 远程地址>
git push -u origin main
```

建议发布一个部署基线标签：

```bash
git tag -a l4d2-pve-2026-09-20 -m "L4D2 PvE admin baseline"
git push origin l4d2-pve-2026-09-20
```

不要提交：真实 RCON 密码、Steam 凭据、运行日志、备份包、完整游戏 VPK 和 Steam 缓存。`.gitignore` 已经做了第一层过滤，但提交前仍要检查 `git status`。

## 下一步实测清单

用真实 Steam 客户端依次验证：

1. SteamID 管理员认证、`sm_who`、`!admin`。
2. `!admin` 中玩家管理、给枪、积分修改和审计日志。
3. `sm_pvespawn tank`、普通特感生成和尸潮。
4. 1/4/8/12 人加入、接管 Bot、换图和断线重连。
5. Dual Primaries、自动射击、二段跳、特殊弹切换。
6. 倒地自救、Second Wind、Tank 掉宝和 `!minigun`。
7. `c1m1_hotel`、`c1m4_atrium`、`c5m5_bridge`、`c8m5_rooftop`、`c12m5_cornfield`。
8. 监听 CPU、tick、entity count、网络 choke、错误日志和 SourceMod profiler。
