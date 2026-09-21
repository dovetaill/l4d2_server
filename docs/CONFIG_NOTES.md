# 配置说明

状态日期：2026-09-21。

本文记录当前源码仓库中公开配置的所有权、关键值和验证边界。生产密码、GSLT、RCON、网页认证、SQLite 和日志不在这些文件中。

## 系统所有权

| 系统 | 唯一所有者 | 公开配置/代码位置 |
|---|---|---|
| SI 数量/波次 | InfectedBots | `cfg/sourcemod/l4dinfectedbots.cfg` 与 `data/l4dinfectedbots/` |
| SI AI | AI_HardSI | `cfg/sourcemod/AI_HardSI.cfg` |
| 普通感染者缩放 | Dynamic Infected Spawn Balancer | `cfg/sourcemod/l4d2_balancer_spawn_dyn.cfg` |
| Tank HP/能力/Human Support | Mutant Tanks 9.3 | `data/mutant_tanks/mutant_tanks.cfg` |
| PvPvE Tank 池 | `l4d2_pve_mutant_tanks.smx` | `cfg/sourcemod/l4d2_pve_mutant_tanks.cfg` |
| Friendly Fire | No Friendly-Fire | `cfg/sourcemod/no_friendly-fire.cfg` |
| 积分/商城 | `l4d2_campaign_shop.smx` | `cfg/sourcemod/l4d2_campaign_shop.cfg` |
| Witch 实体控制 | `l4d2_playable_witch.smx` | `cfg/sourcemod/l4d2_playable_witch.cfg` |
| 奖励、Second Wind、loot | `l4d2_combat_rewards.smx` | `cfg/sourcemod/l4d2_combat_rewards.cfg` |

不要为同一系统再添加第二个所有者或第二套积分/MT 类型解析器。

## Mutant Tanks 146 池

真实类型配置是 `addons/sourcemod/data/mutant_tanks/mutant_tanks.cfg`，不是普通 SourceMod KeyValues 解析器生成的副本。静态检查结果如下：

- `Tank #1` 至 `Tank #146` 连续存在。
- `Tank Name` 共 146 个。
- 顶层 `Type Range` 为 `1-146`。
- 全局 Human Support 段的 `Human Cooldown` 为 `12`。
- 当前显式 `Human Support = 1` 的类型段为 139 个；这不等同于声称每个类型都具有相同的人类技能配置。
- `Human Ability` 取值为 `1` 或 `2`；`Human Ammo` 取值为 `1`、`2`、`3` 或 `5`；没有 `Human Ammo 99999`，也没有 `Human Cooldown 0`。

PvPvE 池 `cfg/sourcemod/l4d2_pve_mutant_tanks.cfg` 当前为：

```text
l4d2_pve_mt_pool_enable "1"
l4d2_pve_mt_whitelist "1-146"
l4d2_pve_mt_blacklist "41,61,97,122,123,128,145,146"
l4d2_pve_mt_weights "1-88:4,89-121:2,124-144:1,126:2"
l4d2_pve_mt_normal_per_chapter "2"
```

whitelist、blacklist、weights 和 normal 每章上限只约束 normal 随机池；商城购买和管理员生成分别计数，管理员强制类型默认绕过随机 blacklist。`sm_pvemtvalidate` 负责 146 名称、边界、header 和随机池审计；`sm_pvemtstats` 负责 normal、purchased、admin 三类计数。

## SMAC 安全边界

当前受版本控制的 `cfg/sourcemod/smac.cfg` 只启用以下选定模块的配置范围：Core、Aimbot、Commands、ConVars、L4D2 Fixes、Speedhack。未纳入 wallhack、autotrigger、CSS/HL2DM 等未选模块。

公开配置的关键值是：

```text
smac_ban_duration 0
smac_aimbot_ban 0
smac_anticmdspam_kick 0
```

其中 `smac_aimbot_ban 0` 和 `smac_anticmdspam_kick 0` 明确关闭对应自动动作。项目目标是 Speedhack 只记录/告警、不自动永久封禁；当前公开 `smac.cfg` 没有单独的 Speedhack action cvar，所以不能仅凭这几行配置声称该目标已经由真人测试确认。Speedhack 的最终行为必须以实际运行日志和真人客户端验收为准。

## Playable Witch

当前公开配置 `cfg/sourcemod/l4d2_playable_witch.cfg` 为：

```text
pve_playable_witch_enable "1"
pve_playable_witch_max "1"
pve_playable_witch_health "1600"
pve_playable_witch_speed "235.0"
pve_playable_witch_jump "285.0"
pve_playable_witch_attack_damage "35.0"
pve_playable_witch_attack_range "92.0"
pve_playable_witch_attack_cooldown "0.85"
pve_playable_witch_rage_speed "1.30"
pve_playable_witch_rage_duration "4.0"
pve_playable_witch_rage_cooldown "24.0"
pve_playable_witch_random_chance "2.5"
```

模块使用 `L4D2_SpawnWitch` 创建真实 Witch 实体，不通过把玩家设置为 `m_zombieClass = 7` 来伪装。商城购买、管理员入口和随机入口分开管理；普通 `!zclass` 仍只有 Smoker、Boomer、Hunter、Spitter、Jockey、Charger。实体死亡、断线、换图、终局和切队路径必须清理控制状态并让玩家回到普通感染者 Ghost。

## 其他公开 PvPvE 值

`cfg/sourcemod/pve_infected_balance.cfg` 当前的关键边界包括：真人感染者上限 `4`，换边冷却 `90` 秒，SI health multiplier `1.30`，SI cooldown multiplier `0.85`，Tank limit `1`，Witch purchase cost `150`，Witch random chance `2.5`。这些值是配置说明，不是多人验收结果。

## 验证边界

静态配置检查、编译、隔离安装、服务端 RCON、Bot 和 native/entity 自检不能替代真实 Steam 客户端。本文不声称 1/4/8/12/16 名真人并发、真人 SI 六类选择、Tank 抽签/接管/断线、Mutant Tanks Human Support、Playable Witch 的 Mouse1/Space/E/镜头/死亡回 Ghost、最终章救援、换图或章节结算已经通过。没有真人客户端证据，不标记“真实多人通过”。
