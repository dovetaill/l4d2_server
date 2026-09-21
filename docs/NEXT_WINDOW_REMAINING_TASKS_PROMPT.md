# 新窗口剩余任务执行 Prompt

> 适用日期：2026-09-21
>
> 项目源码目录只能使用 `/home/wwwroot/l4d2`。
>
> 实际服务器目录只能使用 `/opt/l4d2`。
>
> 禁止访问或修改 `/home/wwwroot/new_k/sogdia`。

## 可直接复制的引言

```text
继续处理 /home/wwwroot/l4d2 的 L4D2 无限火力战役 PvPvE 服务器项目。

源码目录：/home/wwwroot/l4d2
实际运行目录：/opt/l4d2

请先完整读取：
/home/wwwroot/l4d2/docs/NEXT_WINDOW_REMAINING_TASKS_PROMPT.md

严格按照该文档完成全部剩余任务。不要访问或修改 /home/wwwroot/new_k/sogdia，不要回滚现有改动，不要把密码、GSLT 或私密配置提交到仓库。需要并行时使用与主模型一致的 subagent，不要使用 DeepSeek。
```

## 开始前检查

1. 执行并记录：

```bash
cd /home/wwwroot/l4d2
git status --short --branch
git log -1 --oneline --decorate
```

2. 检查运行目录：

```bash
cd /opt/l4d2
git status --short --branch
git log -1 --oneline --decorate
systemctl status l4d2 --no-pager -l
systemctl status l4d2-web-admin --no-pager -l
```

3. 当前已知基线提交：

```text
8d85205e7cdcf6302e5aa60c8f5321f3c8a0ac11
```

如果 HEAD 已更新，以实际最新提交为准。不要回滚用户已有改动。

# 任务一：完成真正的一键全新部署

完善：

```text
/home/wwwroot/l4d2/scripts/bootstrap_l4d2.sh
```

目标是在全新 Debian 13 amd64 服务器上，从 `/opt/l4d2` 的项目归档开始，只执行一次 bootstrap 就得到与当前生产服务器等效的 Runtime。

必须自动安装或恢复：

- Debian amd64/i386 基础依赖。
- `l4d2srv` 用户。
- SteamCMD，匿名安装 AppID `222860`。
- MetaMod:Source `1.12.0-git1226`。
- SourceMod `1.12.0-git7253`。
- L4DToolZ `2.5.1 build 2155`。
- Left4DHooks `1.168`，包含插件、gamedata、include 和其他配套文件。
- DHooks 运行依赖。
- Actions `3.9.2`，禁止安装 Actions `4.0.1`。
- InfectedBots `3.0.8` 及其 gamedata、translations、data、include。
- `spawn_infected_nolimit`、AI_HardSI、Dynamic Infected Balancer。
- MultiSlots、CreateSurvivorBot、rescue vehicle fix、bot replacement、deathcheck、upgrade-pack fix。
- No Friendly-Fire、Automatic Weapons、Dual Primaries、Gear Transfer、Item Hint。
- Mutant Tanks `9.3` 与所有必需 abilities、gamedata、translations、data、include。
- Map Tank Fix、Finale Stage Fix、Tank Hittable Glow、Tank/Witch Notify。
- Predicaments、Votekick、AFK commands、no-rushing、assist、kills、clear weapon drop。
- SMAC `0.8.8.0` Core、Aimbot、Commands、ConVars、L4D2 Fixes；Speedhack 只告警，不自动永久封禁。
- Command Buffer Fixer `2.11` 与 gamedata。
- 所有项目自制 SourcePawn 插件。

要求：

- 只使用原作者仓库、官方发布或 AlliedModders 官方附件。
- 所有下载固定版本、来源 URL 和校验值必须记录在文档中。
- 不能依赖 `/home/wwwroot/l4d2/sources/` 中未纳入发布包的本地缓存。
- 下载失败必须明确终止，不能生成半成品服务器。
- 必须同时安装 `.smx`、extensions、gamedata、translations、configs、data 和 include，不能只复制插件文件。
- 安装脚本必须幂等，重复运行不得删除游戏数据、日志、SQLite、SteamCMD 或私密配置。
- 支持现有服务器更新和全新服务器安装。
- 支持通过环境变量覆盖测试根目录，便于在临时目录验证，不要只能写死 `/opt/l4d2`。
- `scripts/l4d2ctl.sh update` 必须支持通过发布归档更新，不应要求管理员手工执行版本控制命令。
- README 中不得出现版本控制工具的使用教程或命令。
- 完成后在干净临时目录或隔离测试环境执行一次从零安装验证。

必须同步更新：

```text
README.md
docs/BOOTSTRAP.md
docs/PLUGIN_MANIFEST.md
docs/TEST_REPORT.md
```

README 最终只保留玩家使用、管理员运维、网页面板、故障排查和一键部署方法。

# 任务二：Playable Witch 独立模块

创建：

```text
server/left4dead2/addons/sourcemod/scripting/l4d2_playable_witch.sp
```

并编译为：

```text
server/left4dead2/addons/sourcemod/plugins/l4d2_playable_witch.smx
```

要求：

- SourceMod `1.12.0-git7253`。
- Left4DHooks `1.168+`。
- Witch 不是普通 zombie class，禁止简单设置 `m_zombieClass = 7`。
- 控制真实 Witch 实体，并提供正确移动、转向、镜头、攻击、跳跃、死亡和地图切换清理。
- Mouse1 攻击，Space 跳跃，E 触发温和 Rage。
- Rage 只能提供短时间速度或抗硬直，不加入激光、火球、陨石、闪现。
- 普通 `!zclass` 绝对不能选择 Witch。
- Witch 只能通过商城购买、管理员菜单或配置的低概率随机获得。
- 同时真人 Witch 默认最多 1 个。
- 每玩家每章节默认最多购买 1 次。
- Witch 死亡后恢复为普通感染者 Ghost。
- 玩家断线、换图、过场、Finale、队伍切换时必须正确清理。
- 提供独立开关：

```text
pve_playable_witch_enable 0/1
```

- 模块关闭或加载失败不得影响感染者核心、商城、Tank 抽签和地图流程。
- 集成 `l4d2_campaign_shop`、`l4d2_pve_infected_core`、`l4d2_pve_admin` 和 HUD。
- 管理员菜单可以选择把自己或目标玩家变成 Witch。
- 使用当前 gamedata/SDKHook/Left4DHooks 方法；旧 Witch Control 只可作为行为参考，不得直接部署古老二进制。

必须编译、加载并进行可执行的单人测试；无法自动验证的真人行为明确列入测试清单。

# 任务三：完整 Mutant Tanks 类型与管理员选择

当前项目配置只有 5 种受控 Tank。需要基于 Mutant Tanks `9.3` 完整配置处理全部可用类型。

要求：

- 管理员菜单必须分页显示所有有效 Tank 类型。
- 管理员能够选择自己或指定玩家成为任意有效 Tank 类型。
- 管理员能够生成 Witch 或进入 Playable Witch 流程。
- 正常随机 Tank 池和管理员强制选择分离。
- 正常随机池默认排除惩罚、测试、Slacker、Rusher 等可能破坏战役流程的类型，但管理员可以显式选择。
- 支持配置随机池白名单、黑名单、权重和每章节次数。
- 保留 Human Support，并对真人 Tank 限制 2-3 个技能、Human Ammo 和 Human Cooldown。
- 不允许恢复过快 Tank 频率；正常 Tank、购买 Tank 和管理员测试 Tank 分开计数。
- `l4d2_pve_admin.sp` 不能使用普通 KeyValues 解析 Mutant Tanks 的扩展配置格式，避免再次出现大量 `KeyValues Error`。
- 检查所有 146 类型的配置解析、菜单名称、边界和无效类型处理。

# 任务四：真人与高并发测试

对以下流程建立可重复测试步骤、管理命令和测试报告：

- Survivor -> Infected，Survivor Bot 正确接管。
- Infected -> Survivor，正确接回空闲 Bot。
- 不复制装备、HP 或积分状态。
- 六种普通 SI 和职业数量限制。
- 队伍切换冷却与战斗状态防滥用。
- Tank lottery 公平权重与连续控制限制。
- Survivor 被抽中 Tank 后的 Bot 接管和 Tank 死亡回归。
- Tank Priority 与 Tank Arrival。
- 真人 Mutant Tank 的 E、R、Mouse3 技能。
- Playable Witch 购买、随机、死亡、断线和换图。
- Damage Display 对枪械、近战、投掷物、火焰和爆炸的攻击者私有显示。
- Tank 死亡前五伤害排名、百分比和多 Tank 独立统计。
- 1、4、8、12、16 真人规模。
- Finale、救援载具、deathfall、地图切换和章节结算。
- Tank/Witch/切队过程断线。

不能伪造“16 真人通过”。服务器控制台和 Bot 只能用于自动检查；必须把真实多人测试与自动测试分开报告。

发现以下任一问题必须先修复：

```text
duplicate survivor
duplicate inventory
camera stuck
invisible player
ghost Tank
round unable to end
rescue vehicle early trigger
Failed
Bad Load
missing native
missing gamedata
```

# 任务五：MetaMod linux64 启动提示

当前 32 位 L4D2 启动时会先尝试：

```text
addons/metamod/bin/linux64/server.so
```

调查 VDF、路径和 MetaMod 官方打包行为：

- 如果可以通过正确 VDF 配置消除错误尝试，修复并验证。
- 如果是官方兼容探测且无法安全消除，保留功能正常状态，并在 README 中准确解释。
- 不要删除当前正常加载的 32 位 MetaMod 文件。
- 修复后必须重新检查 `meta list` 和服务器启动。

# 最终部署与验收

必须完成：

1. `python3 -m py_compile scripts/l4d2_web_admin.py`。
2. `bash -n scripts/l4d2ctl.sh scripts/bootstrap_l4d2.sh`。
3. 用 SourceMod `1.12.0.7253` 编译全部自制 `.sp`。
4. 编译成功后才覆盖 `.smx`。
5. 同步到 `/opt/l4d2`，保留：

```text
/etc/l4d2/l4d2.env
/etc/l4d2/l4d2-admin.env
/opt/l4d2/server/left4dead2/cfg/server_private.cfg
SteamCMD
日志
SQLite
第三方 Runtime
```

6. 启动并检查：

```text
meta list
sm version
sm exts list
sm plugins list
```

7. 当前目标：

```text
Failed = 0
Bad Load = 0
missing native = 0
missing gamedata = 0
Cbuf_AddText: buffer overflow = 0
KeyValues Error = 0
```

8. 检查 UDP `27015`、网页 `127.0.0.1:27815` 和网页 `/healthz`。
9. 私密密码不得出现在 README、文档、提交内容或命令输出中。
10. 提交并推送源码与配置，让 `/opt/l4d2` 对齐同一个 commit；不得执行会删除未跟踪 Runtime 的清理命令。
11. 最终报告：提交 hash、已安装版本、插件和扩展数量、错误日志、尚需真实玩家验证的项目。
