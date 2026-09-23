#if defined _dual_primaries_included
    #endinput
#endif
#define _dual_primaries_included

native bool L4D2DualPrimaries_HasAlternate(int client);
native bool L4D2DualPrimaries_Switch(int client);

public SharedPlugin __pl_dual_primaries =
{
    name = "dual_primaries",
    file = "dual_primaries.smx",
    #if defined REQUIRE_PLUGIN
        required = 1,
    #else
        required = 0,
    #endif
};
