#if defined _l4d2_pve_mutant_tanks_included
    #endinput
#endif
#define _l4d2_pve_mutant_tanks_included

enum PveMutantTankSource
{
    PveMutantTankSource_Normal = 0,
    PveMutantTankSource_Purchase,
    PveMutantTankSource_Admin
};

native void L4D2PveMutantTanks_MarkNextSpawn(PveMutantTankSource source, int forcedType = 0);
native void L4D2PveMutantTanks_GetCounts(int &normal, int &purchased, int &admin);
native bool L4D2PveMutantTanks_IsRandomTypeAllowed(int type);
native bool L4D2PveMutantTanks_GetTypeName(int type, char[] name, int maxlen);

public SharedPlugin __pl_l4d2_pve_mutant_tanks =
{
    name = "l4d2_pve_mutant_tanks",
    file = "l4d2_pve_mutant_tanks.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_pve_mutant_tanks_SetNTVOptional()
{
    MarkNativeAsOptional("L4D2PveMutantTanks_MarkNextSpawn");
    MarkNativeAsOptional("L4D2PveMutantTanks_GetCounts");
    MarkNativeAsOptional("L4D2PveMutantTanks_IsRandomTypeAllowed");
    MarkNativeAsOptional("L4D2PveMutantTanks_GetTypeName");
}
#endif
