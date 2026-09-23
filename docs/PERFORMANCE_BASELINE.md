# Performance Baseline

状态日期：2026-09-22（America/New_York）。

当前有部署前静态快照、隔离构建和最终生产空服快照。没有固定 12/16 真人战斗脚本，因此 CPU、VAR、Choke、客户端 FPS 和尸体清理效果不能标记为通过。

## 部署前生产快照

| 指标 | 值 | 状态 |
|---|---:|---|
| SourceMod | `1.12.0-git7253` | VERIFIED |
| MetaMod plugins | 5 | STATIC ONLY |
| SourceMod plugins | 69 | PRE-DEPLOY BASELINE |
| SourceMod extensions | 12 | PRE-DEPLOY BASELINE |
| Engine tickrate | 30 | VERIFIED FROM START COMMAND |
| `sv_maxplayers` / visible | 30 / 30 | FAILS NEW SLOT POLICY |
| InfectedBots max / same-frame / coordination | 12 / 0 / 0 | STATIC ONLY |
| Balancer SI/Dominator/Interval/Tank | 0/0/0/0 | STATIC ONLY |
| NoFF guns/melee/fire/explosion | 1/1/1/1 | STATIC ONLY |
| CPU/VAR/Choke/FPS | unavailable | NOT HUMAN VERIFIED |

## 隔离目标快照

| 指标 | 值 | 状态 |
|---|---:|---|
| vendor/project compile | 27 / 31 | PASS, ZERO WARNINGS |
| active/disabled `.smx` | 77 / 9 | ISOLATED BUILD ONLY |
| Owner validation | pass | STATIC ONLY |
| `sv_maxplayers` / visible | 31 / 12 | CONFIG VERIFIED |
| Director full evaluate | 5s | STATIC ONLY |
| HUD / AntiRush | 1s / 1s | STATIC ONLY |
| Perf sample | 5s | STATIC ONLY |
| Corpse cleanup | dead common only, 1s | STATIC ONLY |
| Empty-server timer release | implemented | NOT HUMAN VERIFIED |

## 最终生产空服快照

采样窗口从 2026-09-22 08:40:57 EDT 开始；服务器处于 hibernating，0 真人、0 Bot，因此此表只能证明 Runtime 状态，不能替代战斗性能数据。

| 指标 | 值 | 状态 |
|---|---:|---|
| SourceMod / SourcePawn | `1.12.0.7253` / `1.12.0.7253` | VERIFIED |
| MetaMod plugins | 5 | VERIFIED |
| SourceMod extensions | 12 | VERIFIED |
| active/disabled `.smx` | 77 / 15 | VERIFIED |
| Engine tickrate | 30 | VERIFIED FROM PROCESS COMMAND |
| `sv_maxplayers` / visible | 31 / 12 | VERIFIED RUNTIME |
| public/reserved human slots | 12 / 1 | VERIFIED RUNTIME |
| Balancer SI/Dominator/Interval/Tank | 0/0/0/0 | VERIFIED RUNTIME |
| Balancer Tank HP / versus-like / Common | 0 / 0 / 0.222 | VERIFIED RUNTIME |
| Current-start error signature count | 0 | VERIFIED FOR START WINDOW |
| CPU/VAR/Choke/FPS | unavailable | NOT HUMAN VERIFIED |

## Required A/B Runs

| 场景 | Before | After | 必需证据 |
|---|---|---|---|
| 12 Survivor + 10-12 SI + horde，10 分钟 | NOT RUN | NOT RUN | CPU、VAR、Entity avg/peak、Choke、client FPS |
| Tank + 12 SI + heavy gunfire | NOT RUN | NOT RUN | AI/Human Tank、VAR、Entity peak、damage duplication |
| Playable Witch | NOT RUN | NOT RUN | control latency、Entity Count、HUD cost |
| Corpse cleaner off/on | NOT RUN | NOT RUN | 同图同人数的 Entity avg/peak 与 client FPS |
| Hitsound/HUD/Overdrive | NOT RUN | NOT RUN | timer、network、VAR 与视觉拥挤 |
| Empty server >0 -> 0 | NOT RUN | NOT RUN | 90s grace、取消、进程树和端口恢复 |

## Acceptance Rules

- 不接受持续 VAR/Choke 上升、timer/entity 泄漏、重复 SI 补怪、同帧 spawn burst、Tank/Witch 重复实体。
- Cleaner 只有在受控 A/B 证明 Entity 峰值或客户端压力改善后才可写为性能成功。
- 首次真人性能报告必须记录地图、人数、SI/Common、插件/扩展列表、CVar、时间窗口及清理状态。
- 目前结论：`NOT HUMAN VERIFIED`；`NOT VERIFIED WITH 16 HUMAN CLIENTS`。
