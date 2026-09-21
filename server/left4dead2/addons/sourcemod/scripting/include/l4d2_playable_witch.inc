#if defined _l4d2_playable_witch_included
    #endinput
#endif
#define _l4d2_playable_witch_included

enum PlayableWitchSource
{
    PlayableWitchSource_Purchase = 1,
    PlayableWitchSource_Admin,
    PlayableWitchSource_Random
};

native bool L4D2PlayableWitch_IsAvailable();
native bool L4D2PlayableWitch_Request(int client, PlayableWitchSource source);
native bool L4D2PlayableWitch_IsControlling(int client);
native int L4D2PlayableWitch_GetEntity(int client);

public SharedPlugin __pl_l4d2_playable_witch =
{
    name = "l4d2_playable_witch",
    file = "l4d2_playable_witch.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_playable_witch_SetNTVOptional()
{
    MarkNativeAsOptional("L4D2PlayableWitch_IsAvailable");
    MarkNativeAsOptional("L4D2PlayableWitch_Request");
    MarkNativeAsOptional("L4D2PlayableWitch_IsControlling");
    MarkNativeAsOptional("L4D2PlayableWitch_GetEntity");
}
#endif
