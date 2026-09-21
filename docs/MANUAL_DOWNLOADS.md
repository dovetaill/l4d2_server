# 手工下载与延后项目

状态日期：2026-09-21。

自动安装的唯一清单是 `scripts/l4d2_artifact_manifest.sh`。下表是该脚本当前内容的人工核对副本：URL 必须保持 HTTPS，SHA-256 必须完整匹配；不得替换为 `latest`、分支、未经确认的镜像或其他预编译二进制。

## 固定下载清单

| key | 版本/用途 | 官方或作者 URL | 文件名 | SHA-256 |
|---|---|---|---|---|
| `steamcmd` | Valve SteamCMD Linux installer；L4D2 AppID `222860` | `https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz` | `steamcmd_linux.tar.gz` | `cebf0046bfd08cf45da6bc094ae47aa39ebf4155e5ede41373b579b8f1071e7c` |
| `metamod` | MetaMod:Source `1.12.0-git1226` | `https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1226-linux.tar.gz` | `mmsource-1.12.0-git1226-linux.tar.gz` | `f3ab8688885c945516c2616c3e2792451615bd8ad752ed5e0b96334b49f49077` |
| `sourcemod` | SourceMod `1.12.0-git7253` | `https://www.sourcemod.net/smdrop/1.12/sourcemod-1.12.0-git7253-linux.tar.gz` | `sourcemod-1.12.0-git7253-linux.tar.gz` | `6bbcab989cda0ada83600d0dcb0f46affd16529b2b02ed2dba1b5baeaf02fdb4` |
| `l4dtoolz` | L4DToolZ `2.5.1` build `2155` | `https://github.com/lakwsh/l4dtoolz/releases/download/2.5.1/l4dtoolz-2.5.1-2155.zip` | `l4dtoolz-2.5.1-2155.zip` | `098ed0f0050fd770305ba697a924ccde1afd474f4776afc7a18e9c29c0180df6` |
| `actions` | Actions extension `3.9.2` | `https://github.com/Vinillia/actions.ext/releases/download/v3.9.2/actions.ext.zip` | `actions.ext-v3.9.2.zip` | `e093ca79bf977b48fdb318b4fa4bc3ab1ce01c7ad7cf0c871354a52e5f8fdd15` |
| `dynamic_balancer` | Dynamic Infected Spawn Balancer `1.0.1` | `https://github.com/szGabu/L4D2_DynamicInfectedSpawnBalancer/releases/download/1.0.1/L4D2_DynamicInfectedSpawnBalancer.zip` | `L4D2_DynamicInfectedSpawnBalancer-1.0.1.zip` | `af1ef8d95302c02d56f68854e83a9ca1dbbf19a0b360a26afbf59752245171f4` |
| `left4dhooks` | Left4DHooks `1.168`, commit `f90ae5e6` | `https://codeload.github.com/SilvDev/Left4DHooks/tar.gz/f90ae5e62228e0b7baf12cda922e3fd40db844f4` | `left4dhooks-1.168-f90ae5e6.tar.gz` | `dd5480e092f5f96c21fcf6bfe1dcea8fc31f89cde9fb164f9b826a6f699d07e3` |
| `mutant_tanks` | Mutant Tanks `9.3`, commit `c7ef30ee` | `https://codeload.github.com/Psykotikism/Mutant_Tanks/tar.gz/c7ef30eea49abce235ef9ff50587aed7cd3c4d5a` | `mutant-tanks-9.3-c7ef30ee.tar.gz` | `24845fd22619dcec5f0ca91952da64d6d6e56f185e45fe630aa41df2568db8ef` |
| `fbef_plugins` | fbef0102 selected L4D1/L4D2 plugins, commit `8e67e4f6` | `https://codeload.github.com/fbef0102/L4D1_2-Plugins/tar.gz/8e67e4f659023fccb2fa65fbb74ad38547463302` | `fbef0102-8e67e4f6.tar.gz` | `7f05e1f7d5495279591b75260dbf2d3ccd5804aa5f0cd353209029e882a8be89` |
| `wyxls_plugins` | wyxls Automatic Weapons/Gear Transfer, commit `c1d14e5f` | `https://codeload.github.com/wyxls/SourceModPlugins-L4D2/tar.gz/c1d14e5f06368363d6800311db752ef6e6b22eda` | `wyxls-SourceModPlugins-L4D2-c1d14e5f.tar.gz` | `68e941c69e352b79558407f35b24f679b2b0be615af0f3b8b0cadd2dc6b73004` |
| `dual_primary` | Dual Primaries `1.5.8` source, commit `83e2b71c` | `https://codeload.github.com/DrStr4Nge147/L4D2-DualPrimary-Plugin/tar.gz/83e2b71c0b21e2a6291b066f903c6af18254a90c` | `dual-primary-83e2b71c.tar.gz` | `8e36550486a9e03831849d034b7649a6f134183f6ed0511d2d97c8043f470d1d` |
| `predicaments` | Predicaments `0.4` source, commit `5c148841` | `https://codeload.github.com/janiluuk/L4D2_Predicaments/tar.gz/5c148841817f305999dd3574645f45cc6a99bf7c` | `predicaments-5c148841.tar.gz` | `603d1c77f9e9c26ff2b9e9a5ee69d9e75831147e7a6cf234a76a0518b068334d` |
| `votekick` | Votekick `5.3` source, commit `8323e0aa` | `https://codeload.github.com/Hubfront/L4D1-L4D2-Votekick-Coop-Versus/tar.gz/8323e0aa01a8c72e52c4468b4a2bbb41976cab67` | `votekick-v5.3-8323e0aa.tar.gz` | `4efde606b17963d94f995e131fb2a6718fc91d07ce11fea6da8302a4deed78b6` |
| `no_friendly_fire` | No Friendly-Fire `10.0` source, commit `c4985243` | `https://codeload.github.com/Psykotikism/No_Friendly-Fire/tar.gz/c4985243d77e4ba2ec58b586a45ba8f3a009821e` | `no-friendly-fire-c4985243.tar.gz` | `bc798412771a864be4a453a1a60ff0a57b43533de71576a01e6d93753943073a` |
| `smac` | SMAC `0.8.8.0` source, commit `ea15f3ec` | `https://codeload.github.com/Rushaway/sm-plugin-SMAC/tar.gz/ea15f3ec0c8d9c499d0e42d7174675dd6d30780b` | `smac-0.8.8.0-ea15f3ec.tar.gz` | `6410cec01a2e51981c80a183103c0375b877f23dc97079cdef15782c29b389c5` |
| `multicolors` | MultiColors include snapshot, commit `d2f2dc91` | `https://codeload.github.com/srcdslab/sm-plugin-MultiColors/tar.gz/d2f2dc9126255571c0fc4499d5729cacb57265ca` | `multicolors-d2f2dc91.tar.gz` | `e02900f8df929481ce968f9ac0b551be59526e7d43731215f7c513da51b8c8f6` |

### 手工校验

下载后在不包含私密配置的临时目录中运行：

```bash
sha256sum <downloaded-file>
```

输出必须与上表完全一致。Source snapshot 只能从对应 commit URL 下载；不要改用仓库默认分支。Actions 只接受 `3.9.2` 的 URL 和 SHA-256，Actions `4.0.1` 不属于本项目兼容矩阵。

正常安装仍应使用 `scripts/bootstrap_l4d2.sh`，因为它还负责 AppID `222860`、解压布局、依赖复制、SourceMod 1.12 编译和原子替换。手工下载仅用于离线缓存、审阅或复现，不会自动获得生产信任。

## 手工提交文件

人工收到完整文件时放入 `/home/wwwroot/l4d2/incoming/`，保留原始归档、源码、license、gamedata、translations、data 和 include。安装器不会自动信任 `incoming/`，也不会把其中的密码、GSLT、RCON 或网页私密配置复制到运行目录。

只有在确认作者来源、固定版本、许可证、SourceMod `1.12.0-git7253` 编译结果和 gamedata 兼容性后，才可以考虑替换当前实现。

## 延后项目

以下项目在缺少作者源代码、gamedata 和 SourceMod 1.12 编译证据前保持延后，不用随机二进制替换当前稳定实现：

- High-Extensibility Shop System `1.3`
- Adrenaline Momentum
- Survivor Identity Fix `1.7b`
- Defib Fix `2.0.1`
- Stucked Tank Teleport
- Use Priority Patch
- Witch Pipebomb Exploit Fix
- 依赖额外 changelevel 修复的 `l4d2_transition_info_fix`
