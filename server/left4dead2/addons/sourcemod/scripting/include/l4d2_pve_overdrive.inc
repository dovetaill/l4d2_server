#if defined _l4d2_pve_overdrive_included
    #endinput
#endif
#define _l4d2_pve_overdrive_included

native bool L4D2PveOverdrive_IsAvailable();
native bool L4D2PveOverdrive_Activate(int client);
native bool L4D2PveOverdrive_IsActive(int client);
native float L4D2PveOverdrive_GetCooldownRemaining(int client);

public SharedPlugin __pl_l4d2_pve_overdrive =
{
    name = "l4d2_pve_overdrive",
    file = "l4d2_pve_overdrive.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_pve_overdrive_SetNTVOptional()
{
    MarkNativeAsOptional("L4D2PveOverdrive_IsAvailable");
    MarkNativeAsOptional("L4D2PveOverdrive_Activate");
    MarkNativeAsOptional("L4D2PveOverdrive_IsActive");
    MarkNativeAsOptional("L4D2PveOverdrive_GetCooldownRemaining");
}
#endif
