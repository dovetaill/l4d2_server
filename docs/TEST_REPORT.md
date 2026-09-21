# 测试报告

测试日期：2026-09-21（America/New_York）。

## 自动验证

| 项目 | 结果 | 证据 |
|---|---|---|
| Bash 语法 | PASS | bootstrap、l4d2ctl、artifact manifest 均通过 `bash -n` |
| Web 管理脚本 | PASS | `python3 -m py_compile scripts/l4d2_web_admin.py` |
| SourcePawn | PASS | 13 个自制插件使用 `spcomp 1.12.0.7253` 全部编译成功、无 warning/error |
| 隔离安装 | PASS | 临时目标目录完成非破坏性同步、项目插件全量编译并生成 13 个 `.smx`；测试临时目录已清理 |
| 固定第三方源码编译 | PASS | 双主武器、Votekick 及选定的 6 个 SMAC 模块使用固定源码和依赖完成编译、无 warning/error |
| MT 配置与池验证 | PASS | `Tank #1` 至 `Tank #146` 连续；运行时审计 `names=146/146`、`bounds=1-146`、`random_allowed=138`、`result=PASS` |
| Playable Witch 验证 | PASS | `sm_pvewitch_selftest` 生成真实实体 45 并安排清理；运行时报告 `enabled=1`、`spawn_native=1`、`real_entity_control=1`、`class7_player=0` |
| MetaMod VDF | PASS | 安装逻辑只删除 `metamod_x64.vdf`，保留正常 VDF 和 32 位模块 |
| 本次文档与脚本机密核对 | PASS | 四个目标文件只包含变量名、占位符和公开路径，未写入密码、GSLT、RCON 或私密配置值 |

## 已完成的生产加载检查

通过服务器控制台/RCON 已确认：MetaMod 列出 SourceMod、SDK Hooks、SDK Tools、DHooks 和 Actions；12 个扩展加载；66 个插件加载。InfectedBots 版本为 3.0.8，Mutant Tanks 版本为 9.3；`sm_pvemtvalidate` 返回 146/146 名称和 138 个随机池类型，`sm_pvewitch_validate` 确认使用真实 Witch 实体且未使用玩家 class 7。

这些结果证明当前服务端加载、配置解析、native/gamedata 依赖和服务端实体路径可用，不等同于真人客户端操作验收。历史诊断错误必须按最终启动时间切分检查，不能仅因旧日志仍存在而视为当前启动失败，也不能在未检查新日志的情况下宣称没有新错误。

## 尚需真实 Steam 客户端验证

服务器控制台、RCON、Bot 和隔离安装不能替代真实 Steam 客户端。以下仍必须由真实客户端完成：1/4/8/12/16 人队伍切换、Survivor bot 替换和库存唯一性、普通 SI 六类选择与技能、Tank 抽签/接管/断线、Mutant Tanks Human Support、Playable Witch 的 Mouse1/Space/E/镜头/死亡回 Ghost、最终章救援、换图和章节结算。

没有真实 Steam 客户端证据，不标记“16 真人通过”，也不把 Bot、伪客户端或服务端命令结果计为真人并发证据。

建议地图：`c1m1_hotel`、`c1m4_atrium`、`c5m5_bridge`、`c8m5_rooftop`、`c12m5_cornfield`。
