# 配置说明

状态日期：2026-09-22。

本文记录源码仓库中的公开默认值。源码工程位于 `/home/wwwroot/l4d2`，Runtime 位于 `/opt/l4d2`，实际游戏位于 `/opt/l4d2/server/left4dead2`；三者不得混用。密码、GSLT、RCON、网页认证和私密环境变量不进入 Git。

## Owner 与关键默认值

| 系统 | 唯一 Owner | 默认值 |
|---|---|---|
| SI Spawn | InfectedBots `3.0.8-pve.1` | `max_specials=12`、`spawn_same_frame=0`、`coordination=0`；Tank/Witch spawn off |
| SI Policy | `l4d2_pve_director_controller` | evaluate 5s；Normal target `5/8/10/12`；hard cap 12；headroom 2 |
| Common | Dynamic Infected Spawn Balancer | SI/Dominator/interval/Tank/Tank HP/versus-like `0/0/0/0/0/0`；Common `0.222` |
| AntiRush | `l4d2_pve_antirush` | 1s；warning max(1000,10%)/6s；severe max(1300,15%)/10s；扣 15/30 分 |
| Global HUD | `l4d2_pve_server_hud` | 1s；空服暂停；黑白只在状态变化时通知 |
| Friendly Fire | No Friendly-Fire 10.0 | guns/melee/fires/explosions=`1`；无反伤 |
| Reserved slots | `l4d_reservedslots 1.8-pve.1` | public 12；admin reserved 1；hidden 1；`ADMFLAG_RESERVATION` |
| Loading timeout | `l4d_kickloadstuckers 1.3-pve.1` | 普通 120s；reservation 管理员 180s |
| Corpse cleanup | `l4d2_pve_corpse_cleaner` | 只清 dead common，1.0s；Survivor/SI/Tank/Witch 不清 |
| Entity diagnostics | `l4d2_pve_perf_guard` | sample 5s；WARN 1600；CRITICAL 1800；Recovery request 1850；日志间隔 30s |
| Overdrive | `l4d2_pve_overdrive` + WeaponHandling | 15s；cooldown 75s；fire 1.12/reload 1.15/deploy 1.10/melee 1.08/item 1.05 |
| Witch lottery | `l4d2_playable_witch` | 35%；Flow 25%-80%；每章最多 1 次；同时最多 1 人 |
| Safearea | `l4d2_end_safearea_teleport` | opener timeout 120s；final gate 70%；near 600；grace teleport 60s |
| Empty restart | `l4d2_restart_empty` + systemd | 曾有真人后归零；grace 90s；最短间隔 3600s；`Restart=always`/5s |

`server.cfg` 在最终配置阶段显式执行 `sourcemod/l4d2_balancer_spawn_dyn.cfg`，避免 AutoExecConfig 时序恢复默认值；`l4d2ctl health` 同时核对文件和六个在线 CVar。

## Slot Budget

公开配置为：

```text
sv_visiblemaxplayers 12
sv_maxplayers 31
pve_public_human_slots 12
pve_admin_reserved_slots 1
pve_admin_reserved_slots_hide 1
l4d2_pve_director_engine_headroom 2
```

预留位属于 MaxClients 预算，Director 还会扣除已连接客户端和至少 2 个安全 headroom。未来 16+1 通过配置调整，不在源码写死。管理员位只 Reserve，不随机踢人、不踢高 Ping、最后加入者或 AFK 玩家。

## Friendly Fire

`cfg/sourcemod/no_friendly-fire.cfg`：

```text
nff_enable 1
nff_gamemodetypes 1
nff_survivors 1
nff_infected 1
nff_blockguns 1
nff_blockmelee 1
nff_blockfires 1
nff_blockexplosions 1
nff_saferoomonly 0
```

配置目标是只拦截 Survivor 对 Survivor 的枪、近战、火和爆炸伤害；不反伤攻击者。Tank/SI/Witch、环境 `trigger_hurt` 和必要 self damage 的最终行为仍需真人验证。

## Dynamic Director

RECOVERY 在倒地人数至少 2、倒地比例至少 35% 或有效战斗 Survivor 至多 2 时降低目标并延长间隔；NORMAL 使用人数区间目标；PRESSURE 只在平均健康至少 75、无大量倒地/挂边/被控且 Flow spread 不高于 12% 时增加 1。它只写 InfectedBots CVar，不创建 SI、不杀现有 SI、不踢真人感染者。

## AntiRush

使用 Left4DHooks Map Flow，中位数作为团队位置，35%-50% 分位的存活、未倒地、未挂边、未被控 Survivor 作为 teleport anchor。处罚为 warning、第二次 teleport+15 分、第三次及以后 teleport+30 分；不 Slay/Kick/Ban/Freeze，也不刷 SI 惩罚。Finale、救援、电梯、移动平台、单向跳、强制跑事件、Charger/Jockey 强制移动、仅 1-2 名有效 Survivor 和未知自定义图必须真人确认豁免/降级逻辑。

## Corpse 与 Entity

Cleaner 由 `infected_death` 驱动并在延迟后通过 EntityRef 复核，只删除死亡 common。它不遍历 2048 实体、不删除 Survivor death model、活体、武器、prop、任务实体、Tank 或 Witch。Perf Guard 只监测/告警并可请求 Director 临时 Recovery，不删除未知实体。已有 `clear_weapon_drop` 保持唯一掉落实体 Owner。

## 管理员与帮助菜单

`l4d2_pve_admin_gameplay_write_enable 0` 是生产默认值。管理员菜单提供 Director、AntiRush、HUD、Witch、Overdrive、Performance、Corpse、Slots、Restart 和 Safearea 状态，不提供强删所有实体或 Survivor corpse。帮助菜单只公开当前真实存在的 `!hud`、`!witchqueue`、`!nowitch`、`!overdrive`、`!pveperf` 等命令；`!snd`、`!pvevote`、`!nv` 未部署时不宣称可用。

## 验证边界

上述 Owner、slot、Witch 和 Dynamic Balancer 默认值已在 2026-09-22 08:40:57 EDT 的生产启动窗口通过在线检查；Friendly Fire、预留位准入、换队、AntiRush、安全门、Tank/Witch、12/16 真人和性能 A/B 仍未由真实 Steam 客户端验证。
