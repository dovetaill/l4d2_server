# 手工下载与延后项目

状态日期：2026-09-22。

自动安装的唯一机器清单是 `scripts/l4d2_artifact_manifest.sh`。下表是人工核对副本：URL 必须保持 HTTPS，commit 和 SHA-256 必须完整匹配；不得替换为 `latest`、默认分支、未知镜像或不明预编译二进制。

## 固定下载清单

| key | 版本/用途 | 作者来源/不可变提交 | 文件名 | SHA-256 |
|---|---|---|---|---|
| `steamcmd` | Valve SteamCMD；AppID `222860` | Valve 官方 CDN | `steamcmd_linux.tar.gz` | `cebf0046bfd08cf45da6bc094ae47aa39ebf4155e5ede41373b579b8f1071e7c` |
| `metamod` | MetaMod:Source `1.12.0-git1226` | AlliedModders 官方归档 | `mmsource-1.12.0-git1226-linux.tar.gz` | `f3ab8688885c945516c2616c3e2792451615bd8ad752ed5e0b96334b49f49077` |
| `sourcemod` | SourceMod `1.12.0-git7253` | SourceMod 官方归档 | `sourcemod-1.12.0-git7253-linux.tar.gz` | `6bbcab989cda0ada83600d0dcb0f46affd16529b2b02ed2dba1b5baeaf02fdb4` |
| `l4dtoolz` | L4DToolZ `2.5.1` build `2155` | lakwsh official release | `l4dtoolz-2.5.1-2155.zip` | `098ed0f0050fd770305ba697a924ccde1afd474f4776afc7a18e9c29c0180df6` |
| `actions` | Actions `3.9.2` | Vinillia official release | `actions.ext-v3.9.2.zip` | `e093ca79bf977b48fdb318b4fa4bc3ab1ce01c7ad7cf0c871354a52e5f8fdd15` |
| `dynamic_balancer` | Dynamic Infected Spawn Balancer `1.0.1` | szGabu official release | `L4D2_DynamicInfectedSpawnBalancer-1.0.1.zip` | `af1ef8d95302c02d56f68854e83a9ca1dbbf19a0b360a26afbf59752245171f4` |
| `left4dhooks` | Left4DHooks `1.168` | SilvDev `f90ae5e62228e0b7baf12cda922e3fd40db844f4` | `left4dhooks-1.168-f90ae5e6.tar.gz` | `dd5480e092f5f96c21fcf6bfe1dcea8fc31f89cde9fb164f9b826a6f699d07e3` |
| `mutant_tanks` | Mutant Tanks `9.3` | Psykotikism `c7ef30eea49abce235ef9ff50587aed7cd3c4d5a` | `mutant-tanks-9.3-c7ef30ee.tar.gz` | `24845fd22619dcec5f0ca91952da64d6d6e56f185e45fe630aa41df2568db8ef` |
| `fbef_plugins` | fbef0102 selected modules | fbef0102 `8e67e4f659023fccb2fa65fbb74ad38547463302` | `fbef0102-8e67e4f6.tar.gz` | `7f05e1f7d5495279591b75260dbf2d3ccd5804aa5f0cd353209029e882a8be89` |
| `fbef_phase1` | Reserved/load/team-switch/physics fixes | fbef0102 `e0fd18072b82498ed98535329f8b581262a8ff19` | `fbef0102-e0fd1807.tar.gz` | `e01da86bd27378055010a6c2a3e83a128bdbdef9d8371c5140105847fef64ea3` |
| `wyxls_plugins` | Automatic Weapons、Defib Fix、Survivor AFK Fix | wyxls `c1d14e5f06368363d6800311db752ef6e6b22eda` | `wyxls-SourceModPlugins-L4D2-c1d14e5f.tar.gz` | `68e941c69e352b79558407f35b24f679b2b0be615af0f3b8b0cadd2dc6b73004` |
| `weapon_handling` | WeaponHandling API `1.0.7` | LuxLuma `90391e079d0dd3b0c1c98d786372f28e7d6536e8` | `weapon-handling-api-1.0.7-90391e07.tar.gz` | `41c378ee0ff5e87041c3febcf9a4866e7928d81c2ec8287765b7cd4c88d504d5` |
| `dual_primary` | Dual Primaries `1.5.8` | DrStr4Nge147 `83e2b71c0b21e2a6291b066f903c6af18254a90c` | `dual-primary-83e2b71c.tar.gz` | `8e36550486a9e03831849d034b7649a6f134183f6ed0511d2d97c8043f470d1d` |
| `predicaments` | Predicaments `0.4`，仅固定/disabled | janiluuk `5c148841817f305999dd3574645f45cc6a99bf7c` | `predicaments-5c148841.tar.gz` | `603d1c77f9e9c26ff2b9e9a5ee69d9e75831147e7a6cf234a76a0518b068334d` |
| `votekick` | Votekick `5.3` | Hubfront `8323e0aa01a8c72e52c4468b4a2bbb41976cab67` | `votekick-v5.3-8323e0aa.tar.gz` | `4efde606b17963d94f995e131fb2a6718fc91d07ce11fea6da8302a4deed78b6` |
| `no_friendly_fire` | No Friendly-Fire `10.0` | Psykotikism `c4985243d77e4ba2ec58b586a45ba8f3a009821e` | `no-friendly-fire-c4985243.tar.gz` | `bc798412771a864be4a453a1a60ff0a57b43533de71576a01e6d93753943073a` |
| `smac` | SMAC `0.8.8.0` | Rushaway `ea15f3ec0c8d9c499d0e42d7174675dd6d30780b` | `smac-0.8.8.0-ea15f3ec.tar.gz` | `6410cec01a2e51981c80a183103c0375b877f23dc97079cdef15782c29b389c5` |
| `multicolors` | MultiColors include | srcdslab `d2f2dc9126255571c0fc4499d5729cacb57265ca` | `multicolors-d2f2dc91.tar.gz` | `e02900f8df929481ce968f9ac0b551be59526e7d43731215f7c513da51b8c8f6` |

机器 URL 不在本文重复维护，运行 `bash scripts/l4d2_artifact_manifest.sh` 可输出 URL、版本、SHA 和来源。Actions `4.x`、分支归档和 `latest` URL 均不属于当前兼容矩阵。

## License Evidence

许可证列只记录固定归档或源码头中能够直接确认的证据；归档未附许可证时明确标为未确认，不从整合包名称推断。

| key | 许可证证据 |
|---|---|
| `steamcmd` | Valve 专有分发/Steam 条款；非开源插件许可证 |
| `metamod` | 当前二进制归档未附独立 LICENSE；需按 AlliedModders 上游条款使用 |
| `sourcemod` | 归档 `LICENSE.txt`：GPL-3.0，并含 SourceMod 例外说明 |
| `l4dtoolz` | release ZIP 未附独立 LICENSE；当前文档不擅自赋予 SPDX 标识 |
| `actions` | release ZIP 未附 LICENSE/NOTICE；当前文档不擅自赋予 SPDX 标识 |
| `dynamic_balancer` | 归档 `LICENSE`：AGPL-3.0 |
| `left4dhooks` | 固定源码 `LICENSE`：GPL-3.0 |
| `mutant_tanks` | 固定源码 `LICENSE`：GPL-3.0 |
| `fbef_plugins` / `fbef_phase1` | 固定仓库 `LICENSE`：GPL-3.0 |
| `wyxls_plugins` | 归档仅包含 bundled SourceMod license，未发现所选插件的独立许可证声明 |
| `weapon_handling` | 固定源码 `LICENSE`：GPL-3.0 |
| `dual_primary` | README 许可声明：按原样提供，允许修改和再分发；未提供标准 SPDX 文件 |
| `predicaments` | 固定 commit/归档 SHA 已记录；本轮缓存未保留许可证文件证据，生产仍 disabled |
| `votekick` | 固定源码 `LICENSE`：GPL-3.0 |
| `no_friendly_fire` | 固定源码 `LICENSE`：GPL-2.0 |
| `smac` | `LICENSE.txt`：GPL-3.0-or-later |
| `multicolors` | 固定源码 `LICENSE`：GPL-3.0 |

## 本地审阅补丁

`fbef_phase1` 的源码在固定 commit 上进行最小策略补丁并由同一 SourceMod `1.12.0-git7253` 编译：

- `l4d_reservedslots 1.8-pve.1`：读取 `ADMFLAG_RESERVATION`，默认 12+1，仅 Reserve、不 Kick。
- `l4d_kickloadstuckers 1.3-pve.1`：普通 120 秒、reservation 管理员 180 秒；记录 SteamID、持续时间和原因。
- `l4d_switch_team_survivor_dead_fix`：只修复回 Survivor 的死亡/倒地状态。
- `jockey_ride_team_switch_teleport_fix`：只处理骑乘期间换队，不生成 SI。
- `physics_object_pushfix`：需要 `physics_object_pushfix.txt`；gamedata/signature 缺失即 fail closed。

`weapon_handling` 保留 LuxLuma GPL-3.0 声明。`physics_object_pushfix` 保留上游 GPL-3.0-or-later 声明。其余组件的许可证必须以固定归档中的上游 LICENSE/源码头为准；未明确声明时文档不得擅自赋予许可证。

## 手工校验

```bash
sha256sum <downloaded-file>
```

输出必须与上表完全一致。正常安装仍使用 `scripts/bootstrap_l4d2.sh`，因为它还负责布局、依赖、gamedata、translations、SourceMod 编译、Owner 冲突检查和原子替换。人工收到的文件只能放入 `incoming/` 审阅，安装器不会自动信任它们。

## 延后项目

以下组件尚未同时满足作者公开来源、不可变 commit、许可证、SourceMod 1.12 编译、gamedata/signature 与 Owner 冲突审计，当前不部署：

- NanakaNeko Hitsound branches；
- `firebulletsfix`、`l4d_rock_lagcomp`、`l4d2_null_cusercmd_fix`；
- `l4d2_fix_changelevel` + `l4d2_transition_info_fix`；
- Use Priority Patch、Survivor Identity Fix、Better Charger Collision、Witch Target Patch、`l4d_fix_target_replace`；
- Ladder/InputKill/Spray/Packet/HLTV/Command security 候选中除现有 Command Buffer Fixer 2.11 外的项目；
- Tank Punch Ceiling Stuck Fix、第三方地图 Flow/Dialogue/Finale fix、Cutscene No Damage、Accelerator；
- Night Vision、Kill Feed、Screen Shake Reducer、Achievement Trophy、Tank fast climb、M60/GL patch 和 reload animation fix。

这些项目不得用整合包中的未知 `.smx`、未知 `.so`、收费/私有源码或逆向实现替代。Defib Fix、Survivor AFK Fix 和 Command Buffer Fixer 2.11 已在当前固定构建中，不属于延后项。
