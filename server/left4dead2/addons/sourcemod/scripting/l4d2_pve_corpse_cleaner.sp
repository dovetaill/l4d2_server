#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "0.1.0"

ConVar g_cvEnabled;
ConVar g_cvCommonDelay;
ConVar g_cvRemoved;
int g_iRemoved;

public Plugin myinfo =
{
    name = "L4D2 PvE Selective Corpse Cleaner",
    author = "Codex",
    description = "Event-driven cleanup for dead common infected only.",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar("l4d2_pve_corpse_cleaner_enable", "1", "Clean dead common infected entities.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvCommonDelay = CreateConVar("l4d2_pve_corpse_cleaner_common_delay", "1.0", "Delay before validating and removing a dead common infected.", FCVAR_NOTIFY, true, 0.5, true, 1.5);
    g_cvRemoved = CreateConVar("l4d2_pve_corpse_cleaner_removed", "0", "Common infected removed this map.", FCVAR_NOTIFY);
    RegAdminCmd("sm_pvecorpse_status", Command_Status, ADMFLAG_GENERIC, "Show selective corpse cleaner status.");
    HookEvent("infected_death", Event_InfectedDeath, EventHookMode_Post);
    AutoExecConfig(true, "l4d2_pve_corpse_cleaner");
}

public void OnMapStart()
{
    g_iRemoved = 0;
    g_cvRemoved.SetInt(0);
}

public void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue)
    {
        return;
    }
    int entity = event.GetInt("entityid");
    if (entity <= MaxClients || !IsValidEntity(entity))
    {
        return;
    }
    char classname[32];
    GetEntityClassname(entity, classname, sizeof(classname));
    if (!StrEqual(classname, "infected"))
    {
        return;
    }
    CreateTimer(g_cvCommonDelay.FloatValue, Timer_RemoveCommon, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_RemoveCommon(Handle timer, int reference)
{
    int entity = EntRefToEntIndex(reference);
    if (entity == INVALID_ENT_REFERENCE || entity <= MaxClients || !IsValidEntity(entity))
    {
        return Plugin_Stop;
    }
    char classname[32];
    GetEntityClassname(entity, classname, sizeof(classname));
    if (!StrEqual(classname, "infected") || !HasEntProp(entity, Prop_Data, "m_lifeState")
        || GetEntProp(entity, Prop_Data, "m_lifeState") == 0)
    {
        return Plugin_Stop;
    }
    RemoveEntity(entity);
    g_iRemoved++;
    g_cvRemoved.SetInt(g_iRemoved);
    return Plugin_Stop;
}

public Action Command_Status(int client, int args)
{
    ReplyToCommand(client, "[Corpse] enabled=%d common_delay=%.1f removed=%d survivor_cleanup=0 si_cleanup=0 tank_cleanup=0 witch_cleanup=0",
        g_cvEnabled.BoolValue, g_cvCommonDelay.FloatValue, g_iRemoved);
    return Plugin_Handled;
}
