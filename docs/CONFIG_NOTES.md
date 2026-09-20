# Configuration Notes

## Server Profile

- `cfg/server.cfg`: public identity, 16 visible slots, `sv_setmax 31`, Hard difficulty, no lobby-only restriction and infinite magazine ammo.
- `cfg/pve_core.cfg`: conservative rate settings. Friendly fire is owned by `no_friendly-fire.smx`; cheat-protected native FF factors are intentionally absent.
- `cfg/pve_balance.cfg`: ownership boundary for SI, common infected and Tank balancing.

## Single Owner per System

| System | Owner |
|---|---|
| SI count and spawn interval | InfectedBots |
| SI behavior | AI_HardSI |
| Common infected scaling | Dynamic Infected Balancer |
| Tank HP and abilities | Mutant Tanks |
| Friendly fire | No Friendly-Fire |
| Economy | L4D2 Campaign Shop |
| Healing, Second Wind and Tank loot | L4D2 Combat Rewards |

## Key Values

- `l4d_multislots_max_survivors 12`
- `l4d_infectedbots_modes_off "versus,scavenge,survival"`
- Dynamic common power: `0.222`; SI/Tank scaling in that plugin is `0`.
- Mutant Tanks health formula: base 6000, extra 3500, multiplier 2, human scaling enabled through the configured type profile.
- The five PvPvE Tank profiles enable Mutant Tanks Human Support. Each profile exposes two or three manual abilities with two charges per ability and a 12-second human cooldown; ability ownership remains with Mutant Tanks.
- `l4d2_rewards_rare_loot_chance 30`; minigun lifetime 120 seconds; loot lifetime 75 seconds.
- `l4d2_end_safearea_delay 60`; lagging living survivors are teleported, never killed.
- `l4d2_campaign_shop_max_points 250`; points are memory-only and reset on a new campaign prefix or `mission_lost`.
- `l4d2_pve_admin.smx` uses SourceMod SteamID admins; Root is configured in `configs/admins_simple.ini`, and points require Root or `custom6`.
- `l4d2_pve_admin` calls the Campaign Shop natives instead of opening a second points database.
- `cfg/sourcemod/pve_infected_balance.cfg` holds the Campaign PvPvE tuning: 90-second team-switch cooldown, human SI health 1.30, human SI cooldown 0.85, 4-player human infected cap, life HP/CD/Ghost/refresh prices 25/30/25/35, Tank Priority 220 and Tank Arrival 320.
- `data/l4dinfectedbots/pve_pvpve.cfg` is selected by `l4d_infectedbots_read_data`; it keeps InfectedBots as the SI quota/spawn owner while allowing human infected in Coop. The core applies the 1/2/4 dynamic human-infected limit for 1-4, 5-8 and 9+ human Survivors.
- SMAC: `smac_aimbot_ban 0`, `smac_anticmdspam_kick 0`; movement/speed detection is log/admin-notice only.

## Startup Console Notes

The L4D2 engine still prints repeated `Cbuf_AddText: buffer overflow` messages during the map's config burst. Runtime plugin loading remains clean; the final PvPvE probe loaded 61 plugins, including the infected core, without new plugin errors. Generated configs were compacted and full versions are in `backups/compact_cfg_20260920_0300/`; this message should be monitored during a longer production start.

Normal engine noise also includes missing commentary point-template entities on `c1m1_hotel`, absent root Steam SDK lookup before the local Steam client is found, and VPK handles reported on clean quit.
