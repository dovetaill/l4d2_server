# Rollback

The server was backed up before installation phases. Important archives include:

- `backups/phase4_pre_20260920_014702.tar.gz`
- `backups/phase7a_pre_20260920_020638.tar.gz`
- `backups/mt_config_20260920_022021/`
- `backups/compact_cfg_20260920_0300/`
- `backups/item_hint_cfg_20260920_024121.cfg`

## Full Restore

1. Stop the server cleanly with `quit` from its console.
2. Preserve the current `server/` tree as a new dated archive.
3. Extract the selected pre-phase archive over `/home/wwwroot/l4d2/server`.
4. Restore the matching `server.cfg`, `cfg/` and `addons/` files.
5. Start with `scripts/start_server.sh` and check `meta list`, `sm exts list` and `sm plugins list`.

## Disable One Module

Move the specific `.smx` from `server/left4dead2/addons/sourcemod/plugins/` into `plugins/disabled/`, then restart. Keep its source, cfg, gamedata and manifest entry in place for audit.

## Capacity Change

The current profile is 12 survivors. Change `sv_visiblemaxplayers`, `sv_maxplayers` and the MultiSlots `l4d_multislots_max_survivors` value together. Keep `sv_setmax 31` and the launcher `-maxplayers 31`. Review SI/common/Tank scaling before switching to 16.
