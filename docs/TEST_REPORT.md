# Test Report

Test date: 2026-09-20 (America/New_York)

## Phase Results

| Phase | Result | Evidence |
|---|---|---|
| 1. MetaMod, SourceMod, L4DToolZ, Left4DHooks | PASS | Meta list, extension list and map initialization |
| 2. MultiSlots and 5+ survivor fixes | PASS | all phase-2 plugins loaded |
| 3. no friendly fire, infinite ammo, auto weapons, dual primaries, double jump, gear transfer | PASS: load | cvars verified; no connected-player combat test available |
| 4. InfectedBots, no-limit spawn, AI_HardSI, common balancer | PASS: load | Actions 3.9.2 loaded; all plugins active |
| 5. Mutant Tanks and map/finale fixes | PASS: load/config | 67 detours and 36 patches registered; five local Tank profiles expose bounded Human Support |
| 6. shop, self-help, rewards | PASS: load | campaign shop cvars and reward plugin loaded |
| 7. safearea, vote kick, SMAC, Item Hint and QoL | PASS: load | final probe shows 61 plugins and 12 extensions |
| 8. Campaign PvPvE core build/config | PASS: build/load | core, Shop and Mutant Tanks config validated with SourceMod 1.12 and a 61-plugin launch; runtime client behavior still needs a live-player pass |

## Final Probe

- Baseline launch: `PORT=27022 MAP=c1m1_hotel TICKRATE=30 scripts/start_server.sh`
- Admin follow-up launch: `PORT=27024 MAP=c1m1_hotel TICKRATE=30 scripts/start_server.sh`
- Final PvPvE launch: `PORT=27031 MAP=c1m1_hotel TICKRATE=30 scripts/start_server.sh`
- Baseline `sm plugins list`: 59 plugins, no `Failed` or `Bad Load` entries.
- Final PvPvE `sm plugins list`: 61 plugins; `L4D2 PvE Infected Core (0.1.0)` and Mutant Tanks 9.3 were running.
- Admin follow-up `sm plugins list`: 60 plugins; `L4D2 PvE Admin (1.0.0)` loaded successfully and `sm_pveinfo` reported `shop_api=yes`.
- Admin follow-up `sm exts list`: 12 extensions, all loaded.
- Verified cvars: safearea enabled, Thirdstrike enabled, Switch Ammo enabled, Campaign Shop enabled, PvPvE costs 25/30/25/35, Tank Arrival 320, SMAC Aimbot ban 0, command-spam kick 0.
- SourceMod error log: no new errors after the compatible Actions extension and missing gamedata were corrected. Historical entries remain for audit.

## Admin Plugin Build Check

- `l4d2_campaign_shop.sp`: compiled successfully with the bundled SourceMod 1.12 `spcomp`.
- `l4d2_pve_admin.sp`: compiled successfully with the bundled SourceMod 1.12 `spcomp`; no compiler warnings remain.
- `l4d2_pve_infected_core.sp`: compiled successfully with the bundled SourceMod 1.12 `spcomp`; no compiler warnings remain after wiring reward forwards, balance controls, bounded cooldown scaling and configured shop costs.
- `l4d2_campaign_shop.sp`: recompiled after adding infected-compatible `Get/Add/Remove/SetPoints` natives.
- The plugin is installed as `l4d2_pve_admin.smx`; real SteamID authentication and in-game menu behavior still require a connected client test.

## Not Yet Functionally Verified

A server console probe cannot simulate a real Steam client. The following still need a real 1/4/8/12/16-player test: Survivor -> Infected bot replacement, Infected -> Survivor takeover, all six `!zclass` choices, class limits, team-switch cooldown, infected point rewards, infected `!buy`, Tank lottery, Survivor-selected Tank return, Tank Priority, Tank Arrival, Mutant Tank human abilities, finale rescue behavior and disconnect recovery.

Playable Witch is not marked as passed: the core intentionally leaves it disabled until a separate current implementation is available and validated in-game.

Test maps requested for the next live pass: `c1m1_hotel`, `c1m4_atrium`, `c5m5_bridge`, `c8m5_rooftop`, `c12m5_cornfield`.
