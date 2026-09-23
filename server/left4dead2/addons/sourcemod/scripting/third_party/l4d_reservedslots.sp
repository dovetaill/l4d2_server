/*
 * Based on fbef0102/HarryPotter l4d_reservedslots 1.8 (2023-08-18),
 * commit e0fd18072b82498ed98535329f8b581262a8ff19.
 * Local policy changes keep engine MaxClients separate from human admission,
 * use ADMFLAG_RESERVATION, and never kick an already admitted player.
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.8-pve.1"

ConVar g_cvPublicSlots;
ConVar g_cvReservedSlots;
ConVar g_cvHideSlots;
ConVar g_cvVisibleMaxPlayers;
ConVar g_cvEngineMaxPlayers;

public Plugin myinfo =
{
    name = "[L4D2] Public/Admin Reserved Slots",
    author = "HarryPotter, Codex",
    description = "Reserves hidden human slots without evicting admitted public players.",
    version = PLUGIN_VERSION,
    url = "https://github.com/fbef0102/L4D1_2-Plugins"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, errMax, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("l4d_reservedslots.phrases");
    g_cvPublicSlots = CreateConVar("pve_public_human_slots", "12", "Public human slots.", FCVAR_NOTIFY, true, 1.0, true, 16.0);
    g_cvReservedSlots = CreateConVar("pve_admin_reserved_slots", "1", "Hidden reservation-flag human slots.", FCVAR_NOTIFY, true, 0.0, true, 4.0);
    g_cvHideSlots = CreateConVar("pve_admin_reserved_slots_hide", "1", "Report only public human slots to the browser.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    CreateConVar("l4d_reservedslots_version", PLUGIN_VERSION, "Reserved slot policy version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);

    g_cvPublicSlots.AddChangeHook(ConVarChanged_Slots);
    g_cvReservedSlots.AddChangeHook(ConVarChanged_Slots);
    g_cvHideSlots.AddChangeHook(ConVarChanged_Slots);
    HookEvent("player_connect", Event_PlayerConnect, EventHookMode_PostNoCopy);
    AutoExecConfig(true, "l4d_reservedslots");
}

public void OnAllPluginsLoaded()
{
    g_cvVisibleMaxPlayers = FindConVar("sv_visiblemaxplayers");
    g_cvEngineMaxPlayers = FindConVar("sv_maxplayers");
    if (g_cvVisibleMaxPlayers == null || g_cvEngineMaxPlayers == null)
    {
        SetFailState("L4DToolZ sv_visiblemaxplayers/sv_maxplayers are required.");
    }
    ApplySlotPolicy();
}

public void OnConfigsExecuted()
{
    ApplySlotPolicy();
}

public void OnMapStart()
{
    ApplySlotPolicy();
}

public void ConVarChanged_Slots(ConVar convar, const char[] oldValue, const char[] newValue)
{
    ApplySlotPolicy();
}

public void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    CreateTimer(GetRandomFloat(2.0, 3.0), Timer_CheckAdmission, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CheckAdmission(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client <= 0 || !IsClientConnected(client) || IsFakeClient(client))
    {
        return Plugin_Stop;
    }

    int publicSlots = g_cvPublicSlots.IntValue;
    int reservedSlots = g_cvReservedSlots.IntValue;
    bool hasReservation = CheckCommandAccess(client, "pve_reserved_slot", ADMFLAG_RESERVATION, true);
    int totalHumans;
    int ordinaryHumans;
    CountOtherConnectedHumans(client, totalHumans, ordinaryHumans);
    totalHumans++;
    if (!hasReservation)
    {
        ordinaryHumans++;
    }

    if (totalHumans > publicSlots + reservedSlots || ordinaryHumans > publicSlots)
    {
        LogMessage("Reserved slot rejected userid=%d total=%d ordinary=%d public=%d reserved=%d reservation=%d", userid, totalHumans, ordinaryHumans, publicSlots, reservedSlots, hasReservation);
        KickClient(client, "%t", "Message");
    }
    return Plugin_Stop;
}

void CountOtherConnectedHumans(int excludedClient, int &total, int &ordinary)
{
    total = 0;
    ordinary = 0;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (client == excludedClient || !IsClientConnected(client) || IsFakeClient(client))
        {
            continue;
        }
        total++;
        if (!CheckCommandAccess(client, "pve_reserved_slot", ADMFLAG_RESERVATION, true))
        {
            ordinary++;
        }
    }
}

void ApplySlotPolicy()
{
    if (g_cvVisibleMaxPlayers == null || g_cvEngineMaxPlayers == null)
    {
        return;
    }

    int publicSlots = g_cvPublicSlots.IntValue;
    int reservedSlots = g_cvReservedSlots.IntValue;
    int engineSlots = g_cvEngineMaxPlayers.IntValue;
    if (engineSlots > 0 && engineSlots < publicSlots + reservedSlots + 2)
    {
        LogError("Slot policy requires at least two engine headroom slots: engine=%d public=%d reserved=%d", engineSlots, publicSlots, reservedSlots);
    }
    g_cvVisibleMaxPlayers.SetInt(g_cvHideSlots.BoolValue ? publicSlots : publicSlots + reservedSlots);
}
