#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define TEAM_SURVIVOR 2

public Plugin myinfo =
{
    name = "L4D2 Clear Thirdstrike",
    author = "Codex",
    description = "Pills/adrenaline reduce revive count by one, never below one",
    version = "1.0.0",
    url = ""
};

ConVar g_hEnable;
ConVar g_hMinimum;

public void OnPluginStart()
{
    g_hEnable = CreateConVar("l4d2_clear_thirdstrike_enable", "1", "Enable thirdstrike reduction from pills and adrenaline.", _, true, 0.0, true, 1.0);
    g_hMinimum = CreateConVar("l4d2_clear_thirdstrike_minimum", "1", "Minimum revive count after a reduction.", _, true, 1.0, true, 99.0);

    HookEvent("pills_used", Event_MedicineUsed, EventHookMode_Post);
    HookEvent("adrenaline_used", Event_MedicineUsed, EventHookMode_Post);
    AutoExecConfig(true, "l4d2_clear_thirdstrike");
}

public void Event_MedicineUsed(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hEnable.BoolValue)
    {
        return;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR)
    {
        return;
    }

    if (!HasEntProp(client, Prop_Send, "m_currentReviveCount"))
    {
        return;
    }

    int current = GetEntProp(client, Prop_Send, "m_currentReviveCount");
    int minimum = g_hMinimum.IntValue;
    if (current > minimum)
    {
        SetEntProp(client, Prop_Send, "m_currentReviveCount", current - 1);
        PrintToChat(client, "\x04[MED]\x01 Revive count reduced: %d -> %d.", current, current - 1);
    }
}
