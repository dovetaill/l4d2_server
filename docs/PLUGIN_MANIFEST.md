# L4D2 PvE Plugin Manifest

Generated: 2026-09-20 (America/New_York)

## Runtime

- OS: Debian GNU/Linux 13 (trixie), x86_64 host, 32-bit L4D2 server
- Source repository: `/home/wwwroot/l4d2`
- Server root: `/opt/l4d2/server`
- Game root: `/opt/l4d2/server/left4dead2`
- Launcher: `/opt/l4d2/scripts/start_server.sh`
- Target public capacity: 16 mixed players; typical profile is 12 Survivor + up to 4 human Infected
- L4DToolZ engine capacity: 31 slots; architecture is ready for a future 16-survivor profile
- Current launch probe: port 27015, map `c1m1_hotel`

## Base Components

| Component | Version | Source | Status |
|---|---|---|---|
| MetaMod:Source | 1.12.0-git1226, build 9fd977d | official release archive | loaded |
| SourceMod | 1.12.0-git7253, build 2e229b111 | official release archive | loaded |
| L4DToolZ | 2.5.1 build 2155 | `lakwsh/l4dtoolz` | loaded |
| Left4DHooks | 1.168 | `SilvDev/Left4DHooks` | loaded |
| Actions | 3.9.2 | author release archive | loaded |

Actions 4.0.1 was kept in `sources/third_party/` but rejected by SourceMod 1.12 because its extension ABI was too new. The compatible 3.9.2 release is installed.

## Installed Gameplay Modules

- MultiSlots Improved 7.4; CreateSurvivorBot; rescue vehicle multi 1.2h; full-slot bot replacement fix; fix_botkick; deathcheck; upgrade-pack fix.
- No Friendly-Fire 10.0; Automatic Weapons 1.2; Dual Primaries 1.5.8; Codex Double Jump 1.0.0; Gear Transfer 2.29; Item Hint 4.9.
- InfectedBots 3.0.8; spawn_infected_nolimit 1.6h; AI_HardSI 2.6; Dynamic Infected Balancer 1.0.1.
- Mutant Tanks 9.3; map Tank fix 1.5; finale stage fix 1.4h; Tank Hittable Glow 2.9; Tank/Witch notify.
- Predicaments 0.4; Codex Clear Thirdstrike 1.0.0; Codex Switch Upgrade Ammo 1.0.0; Codex Combat Rewards 1.0.0.
- Codex Campaign Shop 1.0.0; Codex End Safearea Teleport 1.0.0; Votekick 5.3; AFK/Join commands 5.7; no-rushing 1.1h.
- l4d2_assist 2.7; kills 1.8; clear_weapon_drop 3.4; SMAC 0.8.8.0 core, Aimbot, Commands, ConVars, Speedhack and L4D2 Fixes.
- Command Buffer Fixer 2.11; reviewed upstream SourcePawn and gamedata are tracked with the project and loaded at startup.

## Source and Build Records

- `fbef0102/L4D1_2-Plugins`, repository HEAD `8e67e4f659023fccb2fa65fbb74ad38547463302`.
- `DrStr4Nge147/L4D2-DualPrimary-Plugin`, HEAD `83e2b71c0b21e2a6291b066f903c6af18254a90c`.
- `janiluuk/L4D2_Predicaments`, HEAD `5c148841817f305999dd3574645f45cc6a99bf7c`.
- `Hubfront/L4D1-L4D2-Votekick-Coop-Versus`, HEAD `8323e0aa01a8c72e52c4468b4a2bbb41976cab67`.
- `Rushaway/sm-plugin-SMAC`, HEAD `ea15f3ec0c8d9c499d0e42d7174675dd6d30780b`.
- Mutant Tanks 9.3 and official MetaMod/SourceMod/Left4DHooks archives are retained under `sources/`.
- All custom SourcePawn sources are retained in `server/left4dead2/addons/sourcemod/scripting/` and compiled with the server's SourceMod 1.12 `spcomp`.

## Custom Modules

| Source | Binary | Purpose |
|---|---|---|
| `l4d2_combat_rewards.sp` | `l4d2_combat_rewards.smx` | kill healing, Second Wind, Tank loot, deployable minigun |
| `l4d2_campaign_shop.sp` | `l4d2_campaign_shop.smx` | in-memory campaign currency and `!buy` |
| `l4d2_pve_admin.sp` | `l4d2_pve_admin.smx` | SourceMod `!admin` menu, PvE actions, points API, spawn tests and audit log |
| `l4d2_double_jump.sp` | `l4d2_double_jump.smx` | one extra air jump, boost 250 |
| `l4d2_end_safearea_teleport.sp` | `l4d2_end_safearea_teleport.smx` | 60-second final-area grace teleport |
| `l4d2_clear_thirdstrike.sp` | `l4d2_clear_thirdstrike.smx` | pills/adrenaline reduce revive count to minimum 1 |
| `l4d2_switch_upgrade_ammo.sp` | `l4d2_switch_ammo.smx` | Shift+Reload cycles regular/incendiary/explosive |
| `l4d2_pve_infected_core.sp` | `l4d2_pve_infected_core.smx` | Campaign PvPvE team switching, human SI classes, infected economy, Tank lottery and HUD |
| `l4d2_pve_damage_display.sp` | `l4d2_pve_damage_display.smx` | attacker-only damage hints and per-Tank top-five ranking |

## Deliberately Not Installed

RPGMaker, SkyRPG, PerkMod, Gun XP, ranks, levels, experience, prestige, attributes, classes, permanent skill trees, Melee Fatigue, anti-friendly-fire reflection, Simple Tank Health Regen, More Director Bosses, SuperVersus, Confogl, Zonemod, old Infinite Ammo Reserve, Multiple Equipments, Improved Multiple Equipment and automatic death-revive plugins.

## Operational Notes

- `rcon_password` is stored only in `/opt/l4d2/server/left4dead2/cfg/server_private.cfg` and `/etc/l4d2/l4d2-admin.env`; the actual secret is excluded from Git.
- The server was launched as root for probes only. Production should run as `l4d2srv`.
- The Item Hint plugin still reports that Use Priority Patch is recommended. It was not fetched from a random mirror.
- SourceMod's historical `errors_20260920.log` contains only pre-fix failures from `nextmap.smx`, missing Upgrade Pack gamedata, and Actions 4.0.1. The later successful probes added no new SourceMod error entries.
- `l4dinfectedbots` reads the local `data/l4dinfectedbots/pve_pvpve.cfg` profile. Its own `coop_versus_tank_playable` remains disabled because Tank ownership is deliberately handled by the custom lottery; Mutant Tanks remains the Tank ability owner.
- The five local Mutant Tanks profiles enable Human Support with bounded manual ability charges and cooldowns (two or three abilities per profile). This is configuration for the existing Mutant Tanks Human Support path, not a second Tank ability system.
- Playable Witch is intentionally not enabled. The infected core leaves the Witch purchase entry disabled until a separate current SourceMod/Left4DHooks module exposes a validated control native.
- The current restart loaded 64 plugins and 12 extensions with no `Failed` or `Bad Load` entries. Command Buffer Fixer 2.11 is active; no new `Cbuf_AddText: buffer overflow` was observed.
