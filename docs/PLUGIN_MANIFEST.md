# L4D2 PvPvE 插件清单

状态日期：2026-09-22（America/New_York）。

本文记录已固定、已编译和明确延后的组件。下载 URL、版本、不可变 commit、归档名和 SHA-256 以 `scripts/l4d2_artifact_manifest.sh` 为唯一机器清单；人工核对表见 `docs/MANUAL_DOWNLOADS.md`。任何仅有未知二进制、私有源码或无法确认作者出处的候选均不得进入 Runtime。

## 固定基础组件

| 组件 | 固定版本/提交 | 作者来源 | 许可证/运行约束 |
|---|---|---|---|
| SteamCMD | Valve Linux snapshot；AppID `222860` | Valve 官方 CDN | 仅安装/更新游戏 |
| MetaMod:Source | `1.12.0-git1226` | AlliedModders | 保留 L4D2 32 位加载链 |
| SourceMod | `1.12.0-git7253` | SourceMod | 所有 SourcePawn 使用归档内同一 `spcomp` |
| L4DToolZ | `2.5.1` build `2155` | lakwsh | 提供 31 MaxClients；不启用 100 tick |
| Actions | `3.9.2` | Vinillia | `4.x` 不在当前兼容矩阵 |
| Left4DHooks | `1.168`，`f90ae5e62228e0b7baf12cda922e3fd40db844f4` | SilvDev | GPL-3.0；保留 gamedata/include/data |
| Mutant Tanks | `9.3`，`c7ef30eea49abce235ef9ff50587aed7cd3c4d5a` | Psykotikism | 保留 146 类型配置和 Human Support |
| InfectedBots | `3.0.8-pve.1`，上游 `8e67e4f659023fccb2fa65fbb74ad38547463302` | fbef0102 | 本地策略补丁受 Git 管理；唯一 SI Spawn Executor |
| Dynamic Infected Spawn Balancer | `1.0.1` | szGabu | AGPL-3.0；只允许管理 Common；六个 SI/Tank 相关写权限固定为 0 |
| WeaponHandling API | `1.0.7`，`90391e079d0dd3b0c1c98d786372f28e7d6536e8` | LuxLuma | GPL-3.0；仅由 Overdrive 写临时倍率 |
| No Friendly-Fire | `10.0`，`c4985243d77e4ba2ec58b586a45ba8f3a009821e` | Psykotikism | 唯一 Friendly Fire Owner |
| SMAC | `0.8.8.0`，`ea15f3ec0c8d9c499d0e42d7174675dd6d30780b` | Rushaway snapshot | 只编译选定的 6 个模块 |

## 固定源码快照

| 快照 | 选定内容 | Immutable commit | 说明 |
|---|---|---|---|
| `fbef_plugins` | InfectedBots、MultiSlots、Defib Fix、Survivor AFK Fix 等选定模块 | `8e67e4f659023fccb2fa65fbb74ad38547463302` | 不安装重复 SI/Tank/Witch/Restart Owner |
| `fbef_phase1` | `l4d_reservedslots`、`l4d_kickloadstuckers`、两项换队修复、`physics_object_pushfix` | `e0fd18072b82498ed98535329f8b581262a8ff19` | 本地策略补丁受 Git 管理；归档 SHA 见下载表 |
| `wyxls_plugins` | Automatic Weapons、Defib Fix、Survivor AFK Fix | `c1d14e5f06368363d6800311db752ef6e6b22eda` | Gear Transfer 编译不兼容并保持 disabled |
| `dual_primary` | Dual Primaries `1.5.8` | `83e2b71c0b21e2a6291b066f903c6af18254a90c` | 从源码编译 |
| `votekick` | Votekick `5.3` | `8323e0aa01a8c72e52c4468b4a2bbb41976cab67` | 从源码编译 |
| `multicolors` | SMAC 编译 include | `d2f2dc9126255571c0fc4499d5729cacb57265ca` | 保留 include 层级 |
| `predicaments` | Predicaments `0.4` | `5c148841817f305999dd3574645f45cc6a99bf7c` | 已固定但生产 disabled，避免重复救援/状态 Owner |

## Production Ownership

- SI 实体生成：InfectedBots；`spawn_same_frame=0`、`coordination=0`。`l4d2_pve_director_controller` 只决定目标、间隔、权重和 Recovery/Normal/Pressure，不创建实体。
- SI AI：AI_HardSI。Common 数量：Dynamic Infected Spawn Balancer；SI general、Dominator、SI interval、Tank balance、Tank HP 和 versus-like 六项必须为 0。`server.cfg` 最终阶段显式重载 Owner 配置，`health` 再查询在线 CVar。
- 真人感染者阵营、职业、感染者积分和自然 Tank lottery：`l4d2_pve_infected_core`。Tank 由官方 Director 生成，core 只 Gate/接管，Mutant Tanks 负责类型和能力。
- Witch：`l4d2_playable_witch` 是唯一真人 Witch 控制器。每章最多一次免费抽签，默认 35%，Flow 25%-80%。
- Friendly Fire：No Friendly-Fire 10.0；枪、近战、火、爆炸全部拦截 Survivor 对 Survivor 伤害，不反伤。
- Survivor 战役货币/商城：`l4d2_campaign_shop`。战斗奖励：`l4d2_combat_rewards`。无永久 RPG 属性。
- AntiRush、全局 HUD、Overdrive、尸体清理、性能监测、空服重启和 Safearea 分别由同名自研插件单独拥有，详见 `docs/RUNTIME_OWNERSHIP.md`。
- 管理员位：本地审阅版 `l4d_reservedslots 1.8-pve.1`，默认 12 公共位 + 1 隐藏 reservation 位，不踢已在线普通玩家。

## Production Disabled

最终 Runtime 的 `plugins/disabled/` 有 15 个插件：

- `admin-sql-prefetch.smx`、`admin-sql-threaded.smx`、`sql-admin-manager.smx`；
- `mapchooser.smx`、`nominations.smx`、`randomcycle.smx`、`rockthevote.smx`、`nextmap.smx`；
- `reservedslots.smx`、`no-rushing.smx`、`l4d2_predicaments.smx`；
- `l4d2_item_hint.smx`、`kills.smx`、`tank_witch_spawn_notify.smx`、`l4d_gear_transfer.smx`。

`clear_dead_body.smx` 和 `l4dafkfix_deadbot.smx` 未进入 active Runtime。`Survivor Identity Fix + deadbot`、第二套 FF、SI、Tank、Witch、AntiRush、HUD、商城、货币或 Empty Restart 同时加载属于健康检查硬失败。

## SMAC 与安全边界

只纳入 Core、Aimbot、Commands、ConVars、L4D2 Fixes、Speedhack 六个模块。公开配置关闭 Aimbot 自动封禁和命令垃圾自动踢；Speedhack 最终动作仍需以运行日志和真人测试确认。Command Buffer Fixer 固定 `2.11`。其他 packet、spray、InputKill、null CUserCmd、Ladder Crash 等修复在来源、许可证、gamedata 和当前游戏签名完整固定前保持延后，不以未知 `.smx` 或 `.so` 补齐。

## 明确延后

Hitsound、`firebulletsfix`、`l4d_rock_lagcomp`、`l4d2_null_cusercmd_fix`、changelevel/transition pair、Use Priority、Survivor Identity Fix、Tank Ceiling Fix、第三方地图修复、Accelerator 和其余 security patches 尚未同时满足作者来源、不可变 commit、许可证、SourceMod 1.12 编译或 gamedata 验证，因此不在当前生产清单中。

## 最终生产快照

2026-09-22 08:40:57 EDT 启动窗口：SourceMod `1.12.0.7253`，MetaMod plugins 5，SourceMod extensions 12，active/disabled `.smx` 为 77/15。`l4d2ctl health` PASS；当前窗口未发现 Cbuf、KeyValues、Bad Load、Missing Native、signature 或 gamedata 错误。

## 验证边界

隔离构建已证明固定依赖可下载、校验和编译，但插件加载不等于真人玩法或性能通过。Friendly Fire、预留位、换队、Tank Rock、Witch、Finale、第三方地图、12 人和 16 人仍需真实 Steam 客户端；当前状态为 `NOT HUMAN VERIFIED`，且 `NOT VERIFIED WITH 16 HUMAN CLIENTS`。
