# Runtime Ownership Matrix

状态日期：2026-09-22（America/New_York）。

一个运行时系统只能有一个 Owner。读取者不得写控制 CVar；策略插件不得越权创建实体。bootstrap 和 `l4d2ctl health` 将已知重复 Owner 视为硬失败或迁入 `plugins/disabled/`。

| 功能 | Owner | 允许读取插件 | 允许写入插件 | 关键 CVar | 冲突插件 | 验证方式 |
|---|---|---|---|---|---|---|
| SI 实体生成 | InfectedBots `3.0.8-pve.1` | Director、HUD、Core、Perf | 仅 InfectedBots | `max_specials`、`spawn_time_min/max`、`spawn_same_frame` | NekoSpecials、`l4d2_boss_spawn`、第二套 SI spawner | allowlist；源码/native caller 审计；真人检查无 burst |
| SI 动态策略 | `l4d2_pve_director_controller` | HUD、Perf、Admin | 仅 Director 写 InfectedBots 策略；不得生成实体 | profile、target、class weight、interval、headroom | Dynamic Balancer SI 功能、自建 SI timer | 源码禁止 spawn API；5s evaluate；状态 CVar |
| SI AI | AI_HardSI | HUD、统计 | 仅 AI_HardSI | AI 行为 CVar | 第二套 SI AI | 插件唯一性、真人行为测试 |
| Common 数量 | Dynamic Infected Spawn Balancer | Director、HUD、Perf | 仅 commons 功率 | `commons_power=0.222` | SI/Dominator/interval/Tank/Tank HP/versus-like balancer | 六项非 Common 写权限的配置与在线值必须为 0 |
| 真人感染者/职业/感染者积分/Tank lottery | `l4d2_pve_infected_core` | Shop、HUD、Witch、Director | 仅 Core；只接管已生成 Tank | `l4d2_pve_infected_*` | 第二套 team switch/Tank buyer | 源码无 SI/Tank spawn；真人换队测试 |
| Tank 生成 | 官方 Director | Core、Mutant Tanks、HUD | 官方 Director；Core 只 Gate/Lottery | Director Tank CVar | Tank spawn controller、购买后直接 spawn | `tank_spawn` 日志；无重复实体 |
| Tank 类型/能力 | Mutant Tanks 9.3 + `l4d2_pve_mutant_tanks` | Core、HUD、Perf | MT 与类型池 | MT data、pool CVar | 第二套 Tank HP/type/ability | 146 类型校验；AI/Human A/B |
| Witch 实体/真人控制 | `l4d2_playable_witch` | Core、Shop、HUD、Admin | 仅 Playable Witch | `pve_playable_witch_*` | multi-witches、boss spawn、第二套 controller | request native；EntityRef；恢复 Survivor bot |
| Friendly Fire | No Friendly-Fire 10.0 | Health、日志 | 仅 NoFF | guns/melee/fires/explosions/survivors | `anti-friendly_fire*`、damage modifier、反伤 | 唯一性+CVar；真人全武器测试 |
| Survivor 战役货币/商城 | `l4d2_campaign_shop` | Core、Rewards、HUD、Admin | 仅 Shop | `l4d2_campaign_shop_*` | 第二套 shop/currency/VIP economy | 单一 points native；无永久存档 |
| Survivor 阵亡复活 | `l4d2_pve_respawn` | MultiSlots、Left4DHooks | 仅阵亡真人 10 秒计时与空闲 Bot 接管 | `l4d2_pve_respawn_*` | 第二套自动复活计时器 | 不抢闲置真人 Bot；无 Bot 时直接复活 |
| 战斗奖励 | `l4d2_combat_rewards` | HUD、Admin | 仅 Rewards | reward/loot/Second Wind | RPG、Gun XP、永久 HP | heal 默认 0；换图无成长 |
| AntiRush | `l4d2_pve_antirush` | HUD、Admin、Director | 仅 AntiRush | flow threshold、duration、penalty | `no-rushing`、第二套 rush control | Flow median/anchor；豁免真人测试 |
| Safearea/随机开门员/final gate | `l4d2_end_safearea_teleport` | HUD、Admin | 仅 Safearea Owner | opener 120s、ratio 0.70、near 600、grace 60s | 全门锁插件、第二套 safearea teleporter | 首门 SDKHook；Finale bypass；防卡关测试 |
| 全局 HUD/黑白提示 | `l4d2_pve_server_hud` | Core、Director、Rewards、Witch、Perf、Safearea | 仅 Server HUD | rate 1s | Core 高频 HUD、永久 HUD plugin | 1s；空服暂停；状态变化通知 |
| 临时 Overdrive | `l4d2_pve_overdrive` + WeaponHandling API | Shop、HUD、Admin | 仅 Overdrive/API | duration/cooldown/multipliers | weapon attributes、第二套 rate owner | 生命周期全恢复；倍率方向源码审计 |
| Common 尸体清理 | `l4d2_pve_corpse_cleaner` | HUD、Perf、Admin | 仅 Cleaner；只删验证后的 dead common | common delay 1.0s | `clear_dead_body`、未知 cleaner | event+EntityRef；Survivor/SI/Tank/Witch 不删 |
| Entity 诊断/Recovery 请求 | `l4d2_pve_perf_guard` | HUD、Admin | 只写日志/状态并请求 Director | 1600/1800/1850；sample 5s | 自动删未知实体的 logger/cleaner | `!pveperf`；阈值限频日志 |
| 掉落武器/无主物品 | 现有 `clear_weapon_drop` | HUD、Admin | 仅现有插件 | data whitelist/清理时间 | 第二套 weapon/item/drop cleaner | 手持和任务物品不删；真人地图测试 |
| Engine slot 准入 | `l4d_reservedslots 1.8-pve.1` | Director、Perf、HUD、Admin | Reserved Slot 只管理真人准入 | public 12、reserved 1、hidden 1 | stock `reservedslots.smx`、第二套 kick reserve | 满服普通/管理员测试；不得踢人 |
| Loading 幽灵槽 | `l4d_kickloadstuckers 1.3-pve.1` | Admin、日志 | 仅该插件 | 120s/180s | 第二套 loading kicker | SteamID/持续时间/原因日志 |
| 空服重启 | `l4d2_restart_empty` + systemd | Admin、HUD | 插件正常退出；systemd 拉起 | grace 90s、min 3600s、Restart always/5s | auto restart、第二套 Empty Restart | 必须发生 >0 到 0；重新加入取消 |
| 网络/Crash 基线 | SMAC + Command Buffer Fixer 2.11 | Admin、Perf | 各自只处理本 exploit | SMAC actions、Cbuf | 重复 packet/spray/inputkill patch、自动永久 ban | 最新启动日志；overflow=0；gamedata fail closed |
| Hitsound | 未部署 | HUD、Damage Display 可在未来读取 | 无 | 无 | 第二套声音/overlay HUD | 作者源码、资源、commit 固定后再评估 |

## Slot Budget

默认公共真人位 12、隐藏管理员预留位 1、`sv_maxplayers 31`，Director 固定保留至少 2 个 engine headroom，并根据当前已连接玩家/Bot/SI 计算可用 SI 容量。未来 16+1 只能通过配置调整。Reserved Slot 不得踢普通玩家来腾位。

## 已完成迁移

旧 `no-rushing`、Predicaments、Item Hint、kills、Tank/Witch notify、Gear Transfer、`clear_dead_body`、deadbot、stock reservedslots 和 nextmap 均由 bootstrap 迁入 `plugins/disabled/`。Core 自带高频 HUD 和购买 Tank 的直接 spawn 路径已移除。Dynamic Balancer 只保留 Common 功能。

## Fail-closed

下列任一情况使 `l4d2ctl health` 失败：NoFF 未加载或第二个 FF Owner；NekoSpecials；重复 SI/Tank/Witch/AntiRush/Empty Restart；Identity Fix 与 deadbot 同时加载；Dynamic Balancer 六项非 Common 写权限在配置或在线 Runtime 中非 0；缺 gamedata/native；Bad Load/Failed plugin；Cbuf overflow；KeyValues Error；关键安全门、预留位或 Slot CVar 与受控配置不一致。
