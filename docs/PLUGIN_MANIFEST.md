# L4D2 PvPvE 插件清单

状态日期：2026-09-21（America/New_York）。

本文只描述源码仓库中的公开版本、作者来源、运行时职责和验证边界。完整下载 URL、归档文件名和 SHA-256 以 `scripts/l4d2_artifact_manifest.sh` 为准；手工核对表见 `docs/MANUAL_DOWNLOADS.md`。密码、GSLT、RCON、网页认证和 `/etc/l4d2` 私密配置不属于本清单。

## 固定基础组件

| 组件 | 固定版本/提交 | 官方或作者来源 | 部署约束 |
|---|---|---|---|
| SteamCMD | Valve Linux installer snapshot；AppID `222860` | Valve 官方 CDN | 只用于安装/更新 L4D2，不把登录凭据写入仓库 |
| MetaMod:Source | `1.12.0-git1226` | AlliedModders 官方归档 | L4D2 保留正常 32 位 VDF；只禁用 `addons/metamod_x64.vdf` |
| SourceMod | `1.12.0-git7253` | SourceMod 官方归档 | 使用同一归档内的 `spcomp` 编译插件 |
| L4DToolZ | `2.5.1` build `2155` | lakwsh 官方 release | 固定归档和 SHA-256 |
| Actions | `3.9.2` | Vinillia 官方 release | 只安装 3.9.2；明确不安装 4.0.1 |
| Left4DHooks | `1.168`，commit `f90ae5e62228e0b7baf12cda922e3fd40db844f4` | SilvDev 作者仓库固定提交 | 保留 plugin、gamedata、include、data 等伴随文件 |
| Mutant Tanks | `9.3`，commit `c7ef30eea49abce235ef9ff50587aed7cd3c4d5a` | Psykotikism 作者仓库固定提交 | 使用当前本地 146 类型配置，不引入第二套类型表 |
| InfectedBots | `3.0.8`，commit `8e67e4f659023fccb2fa65fbb74ad38547463302` | fbef0102 作者仓库固定提交 | 按选定模块安装 gamedata、translations、data、include |

## 固定源码快照

以下快照来自作者仓库的不可变 commit URL，并由清单脚本校验 SHA-256：

- `wyxls_plugins`：Automatic Weapons、Gear Transfer 及相关 L4D2 插件。
- `dual_primary`：Dual Primaries `1.5.8` 源码，安装器编译为 `dual_primaries.smx`。
- `predicaments`：Predicaments `0.4` 源码/伴随文件。
- `votekick`：Votekick `5.3` 源码，安装器编译为 `l4d_votekick.smx`。
- `no_friendly_fire`：No Friendly-Fire `10.0` 源码/伴随文件。
- `smac`：SMAC `0.8.8.0` 源码快照。
- `multicolors`：SMAC 编译所需的 MultiColors include 快照，保留 `multicolors/` include 层级。

## 运行模块与唯一所有者

- SI 数量/波次：InfectedBots；SI AI：AI_HardSI；普通感染者缩放：Dynamic Infected Spawn Balancer。
- Tank HP、能力和 Human Support：Mutant Tanks 9.3。
- PvPvE Tank 随机池、白名单/黑名单/权重和 normal/purchased/admin 计数：`l4d2_pve_mutant_tanks.smx`。
- Friendly Fire：No Friendly-Fire。
- 积分/商城：`l4d2_campaign_shop.smx`；不使用第二套永久积分数据库。
- Witch 实体和玩家控制：`l4d2_playable_witch.smx`。
- 奖励、Second Wind 和 loot：`l4d2_combat_rewards.smx`。
- 其他固定伴随模块包括 MultiSlots、满槽 bot/死亡检测/升级包修复、Automatic Weapons、Dual Primaries、Gear Transfer、Item Hint、map Tank fix、finale stage fix、Tank glow、Tank/Witch notify、Predicaments、AFK、no-rushing、assist、kills、clear weapon drop 和 Command Buffer Fixer。

## SMAC 选定模块

只纳入以下六个 SMAC 模块：

- Core：`smac.smx`
- Aimbot：`smac_aimbot.smx`
- Commands：`smac_commands.smx`
- ConVars：`smac_cvars.smx`
- L4D2 Fixes：`smac_l4d2_fixes.smx`
- Speedhack：`smac_speedhack.smx`

不纳入未选定的 wallhack、autotrigger、CSS/HL2DM 专用模块等。当前受版本控制的 `cfg/sourcemod/smac.cfg` 明确设置：`smac_aimbot_ban 0`、`smac_anticmdspam_kick 0`。Speedhack 的项目验收目标是只记录/告警、不自动封禁；当前公开配置没有单独的 Speedhack action cvar，因此该行为必须通过实际运行日志和真人客户端测试确认，本文不把“warn-only”文字视为已通过证明。

## Mutant Tanks：146 类型

`data/mutant_tanks/mutant_tanks.cfg` 当前包含连续的 `Tank #1` 至 `Tank #146`，并有 146 个 `Tank Name`。顶层 `Type Range` 为 `1-146`。PvPvE 池配置为：

- whitelist：`1-146`
- 默认 blacklist：`41,61,97,122,123,128,145,146`
- weights：`1-88:4,89-121:2,124-144:1,126:2`
- normal 每章上限：`2`

黑名单和权重只影响 normal 随机池；管理员强制类型可绕过该随机黑名单。管理员菜单展示已配置的 1-146 类型并分页。Human Support 保留为 Mutant Tanks 原生路径，当前配置使用有限 `Human Ammo` 和 `Human Cooldown`，不使用无限弹药值或零冷却。

## Playable Witch

Playable Witch 使用 Left4DHooks 的 `L4D2_SpawnWitch` 创建真实 `witch` 实体，不把玩家伪装成 `m_zombieClass = 7`。当前公开配置为：

- `pve_playable_witch_enable 1`
- `pve_playable_witch_max 1`
- `pve_playable_witch_random_chance 2.5`
- Mouse1 攻击、Space 跳跃、E 短时狂暴；断线、死亡、换图、终局和切队路径负责清理实体与控制状态。

商城购买、管理员入口和低概率随机入口彼此分开；普通 `!zclass` 只允许 Smoker、Boomer、Hunter、Spitter、Jockey、Charger，不提供 Witch 类别。

## 验证边界

静态检查、SourcePawn 编译、隔离安装、服务端 RCON、Bot 和实体/native 自检不能替代真实 Steam 客户端。当前文档不声称 1/4/8/12/16 名真人并发、真人 Tank/Witch 控制、Human Support、镜头/输入、断线回退、最终章或换图流程已经通过；这些仍需真人联机验收。

## 明确不安装

不安装 RPG、等级/经验/转生、永久属性、Gun XP、重复积分数据库、强制反伤、自动复活和未经作者确认的随机二进制。
