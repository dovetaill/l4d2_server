# Manual Downloads and Deferred Items

Checked on 2026-09-20. AlliedModders pages were reachable only as protected forum pages from this host, and no trustworthy author GitHub source was found for the items below. No random mirrors or unknown precompiled binaries were used.

## Still Unavailable from an Author Source

| Item | Requested source | Action taken |
|---|---|---|
| High-Extensibility Shop System 1.3 | AlliedModders plugin 9016 | Replaced by `l4d2_campaign_shop.smx`; no SQLite and no permanent progression |
| Adrenaline Momentum | AlliedModders thread 352007 | Not installed; needs the original source or a confirmed current fork |
| Survivor Identity Fix 1.7b | AlliedModders post 2718792 / Shadowysn fork | Not installed; MultiSlots and bot replacement fixes are active |
| Defib Fix 2.0.1 | AlliedModders thread 315483 | Not installed; needs original source/gamedata |
| Stucked Tank Teleport | AlliedModders thread 349330 | Not installed; Mutant Tanks and map Tank fixes are active |
| Use Priority Patch | AlliedModders thread 327511 | Not installed; Item Hint logs a recommendation only |
| Witch Pipebomb Exploit Fix | AlliedModders post 2800439 | Not installed; needs original source/gamedata |
| l4d2_transition_info_fix | fbef0102 plugin source | Deferred because its documented dependency `l4d2_fix_changelevel` was not part of the stable profile |

## Replaced by Local Source

- Switch Upgrade Ammo Types 1.31, thread 325300: replaced by `l4d2_switch_ammo.smx` using `m_upgradeBitVec`; no Multiple Equipments dependency.
- Clear Thirdstrike 1.3, thread 349321: replaced by `l4d2_clear_thirdstrike.smx`.
- End Safearea Teleport 1.2, thread 335631: replaced by `l4d2_end_safearea_teleport.smx` using Left4DHooks final-checkpoint detection.

## Where to Put Manual Files

Use `/home/wwwroot/l4d2/incoming/` for files you download manually. Keep the original archive and source together. Do not overwrite the current plugin until the source, license, gamedata and SourceMod 1.12 compile have been checked.

Expected useful input formats:

- `.sp` plus all `.inc` files and gamedata
- official `.smx` only when no source exists and the author page identifies the exact game/SourceMod compatibility
- translation files and license text

After a manual drop, the next installation pass should compile and load it in isolation before replacing a local substitute.
