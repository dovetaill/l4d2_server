# 测试报告

测试日期：2026-09-22（America/New_York）。

## 自动验证

| 项目 | 结果 | 证据 |
|---|---|---|
| Bash 语法 | PASS | bootstrap、l4d2ctl、artifact manifest 通过 `bash -n` |
| SourcePawn full build | PASS | 31 个 project 插件使用 `spcomp 1.12.0.7253` 全量编译，零 warning/error |
| 隔离完整 bootstrap | PASS | 固定依赖 SHA 校验；27 个 vendor + 31 个 project 插件零 warning/error；Owner validation 通过 |
| 隔离 Runtime 插件布局 | PASS | active `.smx` 77，disabled `.smx` 9；必需 gamedata/translation/include 存在 |
| Dynamic Balancer ownership | PASS | 配置和生产在线值：SI general、Dominator、SI interval、Tank balance、Tank HP、versus-like 均为 0；Common 为 `0.222` |
| SI spawn ownership | PASS | InfectedBots 是 allowlist 中唯一 SI executor；Director 源码不包含 `CreateFakeClient`、`z_spawn`、`L4D2_SpawnSpecial` 或自建 spawn timer |
| Friendly Fire static | PASS | No Friendly-Fire 为唯一 allowlist FF Owner；枪、近战、火、爆炸 CVar 均为 1 |
| Safearea static | PASS | 单一 Owner；开门员 120 秒、final gate 70%、距离 600；编译零 warning |
| Fail-closed exercise | PASS | 第一次隔离构建因 Dynamic Balancer 配置未被 Git 跟踪而终止；修复 `.gitignore` 后重新完整通过，未生成半成品 Runtime |
| 工作树检查 | PASS | `git diff --check` 无空白错误 |

## 最终生产验证

最终生产启动窗口：2026-09-22 08:40:57 EDT，地图 `c1m1_hotel`，验证时 0 真人。

| 项目 | 结果 | 证据 |
|---|---|---|
| 生产部署 | PASS | `bootstrap --update --no-start` exit 0，零 warning/error；原子发布 31 个 project 插件 |
| SourceMod | PASS | `1.12.0.7253` / SourcePawn `1.12.0.7253` |
| MetaMod | PASS | 5 个：SourceMod、SDK Hooks、SDK Tools、DHooks、Actions 3.9.2 |
| SourceMod extensions | PASS | 12 个，未出现 `<FAILED>`/`<ERROR>` |
| SourceMod plugins | PASS | active 77；`health` 对每个 active `.smx` 执行 `sm plugins info` 并确认 `Status: running` |
| Production disabled | PASS | 15 个，完整清单见 `PLUGIN_MANIFEST.md` |
| Slot runtime | PASS | public 12、reserved 1、visible 12、`sv_maxplayers 31` |
| Dynamic Balancer runtime | PASS | 六个非 Common 写权限为 0；Common power `0.222` |
| Witch owner runtime | PASS | lottery `35.0`；旧 infected-core HUD 为 0 |
| `l4d2ctl health` | PASS | `static/runtime owner checks passed; human gameplay checks remain NOT HUMAN VERIFIED` |
| 当前启动日志 | PASS | 08:40:57 之后无 Cbuf overflow、KeyValues、Bad Load、Missing Native、signature、gamedata 或 failed plugin 错误 |

`errors_20260922.log` 保留 08:25:24 首次部署发现的 dual-primary 依赖、physics gamedata 解析和早期 slot 初始化错误，作为 fail-closed 审计证据；这些错误不在最终启动窗口内，且对应插件现已逐个确认为 `running`。

生产加载和静态 Owner 边界通过，不等同于真人玩法通过。

## Friendly Fire

| 场景 | 当前状态 |
|---|---|
| Rifle / Shotgun / Melee 对队友 | NOT HUMAN VERIFIED |
| Grenade Launcher / Pipe Bomb / Propane | NOT HUMAN VERIFIED |
| Molotov / Gascan / Fireworks indirect fire | NOT HUMAN VERIFIED |
| 攻击者不反伤 | NOT HUMAN VERIFIED |
| Tank / SI / Witch 对 Survivor 正常伤害 | NOT HUMAN VERIFIED |
| trigger_hurt / 环境伤害不被全面屏蔽 | NOT HUMAN VERIFIED |

插件 `Loaded` 和 CVar 正确只能证明静态配置，不能把以上项目写为 PASS。

## 真人与流程矩阵

| 流程 | 状态 |
|---|---|
| 公开位满后普通玩家被拒绝、reservation 管理员进入且不踢人 | NOT HUMAN VERIFIED |
| Survivor/Infected/Spectator 四向切换 | NOT HUMAN VERIFIED |
| Jockey 骑乘时换队，无 teleport/slot leak/duplicated bot | NOT HUMAN VERIFIED |
| 1 / 4 / 8 / 12 真人 | NOT HUMAN VERIFIED |
| 16 真人 | NOT VERIFIED WITH 16 HUMAN CLIENTS |
| Dynamic Director Recovery/Normal/Pressure 与无 spawn burst | NOT HUMAN VERIFIED |
| AntiRush、电梯、单向跳、Finale、自定义地图豁免 | NOT HUMAN VERIFIED |
| 随机开门员、120 秒自动解锁、final gate 防卡关 | NOT HUMAN VERIFIED |
| AI/Human Tank、Tank Rock、高 Ping、Mutant Tank | NOT HUMAN VERIFIED |
| Witch queue、Playable Witch、恢复 Survivor bot | NOT HUMAN VERIFIED |
| Defib、重复 Survivor model、AFK/返回/重连 | NOT HUMAN VERIFIED |
| 商城、Overdrive 恢复、HUD、章节换图、管理员 ChangeLevel | NOT HUMAN VERIFIED |
| 空服从 >0 降到 0 后 90 秒重启 | NOT HUMAN VERIFIED |
| Custom Map / Finale / 救援载具 | NOT HUMAN VERIFIED |

## 玩家反馈修复回归（2026-09-23）

本轮更改已在无真人在线时安装到 `/opt/l4d2`，旧游戏进程经两次受控重启退出，新的 `l4d2.service` 保持运行。新增和修改的 10 个 SourcePawn 插件均使用项目 `spcomp` 编译成功；`git diff --check`、相关 Shell 脚本 `bash -n`、`l4d2ctl health` 均通过。RCON 校验确认 AWP 价格 9999、Bot 难度权重 0.5、最少幸存者 12、自救弹药计数 64、阵亡复活间隔 10 秒；`sm_pvemtvalidate` 报告 146/146 类型配置、138 个随机池类型且边界 1-146。

仍须真人在客户端逐项验证 H 键显示、倒地长按 E 进度条、自救和缓慢移动、特殊弹药长时间运行、Bot 接管与 10 秒重复复活、Tank 变身后能力是否正确生效。当前 31 个 MaxClients 无法同时容纳 30 名幸存者、特感和预留槽位；简体中文菜单和常见提示已修正，但第三方 Mutant Tanks 仍有大量未翻译的技能文字，不能报告为全面汉化完成。

## 性能矩阵

12 Survivor + 10-12 SI + 大尸潮 + Tank 的 10 分钟固定场景尚未由真人执行。CPU、VAR、Choke、客户端 FPS、尸体清理前后平均/峰值 Entity Count 均为 `NOT HUMAN VERIFIED`。尸体清理是否长期保留必须以相同地图、相同人数、相同 SI/Common 配置的 A/B 数据为准。

## 推荐真人地图

`c1m1_hotel`、`c1m4_atrium`、`c5m5_bridge`、`c8m5_rooftop`、`c12m5_cornfield`，另需至少一张已知使用混合 Survivor model 和异常 Flow 的第三方地图。
