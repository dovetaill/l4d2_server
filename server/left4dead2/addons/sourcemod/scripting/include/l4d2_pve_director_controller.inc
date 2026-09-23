#if defined _l4d2_pve_director_controller_included
    #endinput
#endif
#define _l4d2_pve_director_controller_included

native int L4D2PveDirector_RequestRecovery(float seconds, const char[] reason);

public SharedPlugin __pl_l4d2_pve_director_controller =
{
    name = "l4d2_pve_director_controller",
    file = "l4d2_pve_director_controller.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_pve_director_controller_SetNTVOptional()
{
    MarkNativeAsOptional("L4D2PveDirector_RequestRecovery");
}
#endif
