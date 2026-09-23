#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define TEAM_SURVIVOR 2

public Plugin myinfo =
{
    name = "L4D2 Incap Support",
    author = "Codex",
    description = "Allows controlled movement and item self-revive while incapacitated.",
    version = "1.1.0",
    url = ""
};

ConVar g_cvEnabled;
ConVar g_cvCrawlSpeed;
ConVar g_cvSelfReviveTime;
ConVar g_cvSelfReviveHealth;
float g_fUseStarted[MAXPLAYERS + 1];
bool g_bReviving[MAXPLAYERS + 1];
bool g_bProgress[MAXPLAYERS + 1];

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar("l4d2_incap_support_enable", "1", "Enable incapacitated movement and item self-revive.", _, true, 0.0, true, 1.0);
    g_cvCrawlSpeed = CreateConVar("l4d2_incap_crawl_speed", "55.0", "Horizontal movement speed while incapacitated.", _, true, 10.0, true, 150.0);
    g_cvSelfReviveTime = CreateConVar("l4d2_incap_self_revive_time", "4.0", "Seconds to hold Use with pills or adrenaline to self-revive.", _, true, 0.5, true, 10.0);
    g_cvSelfReviveHealth = CreateConVar("l4d2_incap_self_revive_health", "30", "Health after a pills/adrenaline self-revive.", _, true, 1.0, true, 100.0);
    HookEvent("player_spawn", Event_ResetClient);
    HookEvent("player_death", Event_ResetClient);
    HookEvent("round_start", Event_ResetRound);
    HookEvent("round_end", Event_ResetRound);
    HookEvent("mission_lost", Event_ResetRound);
    AutoExecConfig(true, "l4d2_incap_support");
}

public void OnClientDisconnect(int client)
{
    ResetClient(client);
}

public void Event_ResetClient(Event event, const char[] name, bool dontBroadcast)
{
    ResetClient(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_ResetRound(Event event, const char[] name, bool dontBroadcast)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        ResetClient(client);
    }
}

void ResetClient(int client)
{
    if (client < 1 || client > MaxClients)
    {
        return;
    }
    ClearProgress(client);
    g_fUseStarted[client] = 0.0;
    g_bReviving[client] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon,
    int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (!g_cvEnabled.BoolValue || client < 1 || client > MaxClients || !IsClientInGame(client)
        || IsFakeClient(client) || !IsPlayerAlive(client) || GetClientTeam(client) != TEAM_SURVIVOR
        || !HasEntProp(client, Prop_Send, "m_isIncapacitated")
        || GetEntProp(client, Prop_Send, "m_isIncapacitated") == 0)
    {
        if (client > 0 && client <= MaxClients)
        {
            ResetClient(client);
        }
        return Plugin_Continue;
    }

    bool changed = false;
    if (HasEntProp(client, Prop_Send, "m_isHangingFromLedge")
        && GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0)
    {
        ResetClient(client);
        return Plugin_Continue;
    }

    if (IsControlled(client))
    {
        ResetClient(client);
        return Plugin_Continue;
    }

    float forwardVec[3], rightVec[3], wish[3];
    GetAngleVectors(angles, forwardVec, rightVec, NULL_VECTOR);
    forwardVec[2] = 0.0;
    rightVec[2] = 0.0;
    NormalizeVector(forwardVec, forwardVec);
    NormalizeVector(rightVec, rightVec);
    wish[0] = 0.0;
    wish[1] = 0.0;
    if (buttons & IN_FORWARD)
    {
        wish[0] += forwardVec[0];
        wish[1] += forwardVec[1];
    }
    if (buttons & IN_BACK)
    {
        wish[0] -= forwardVec[0];
        wish[1] -= forwardVec[1];
    }
    if (buttons & IN_MOVERIGHT)
    {
        wish[0] += rightVec[0];
        wish[1] += rightVec[1];
    }
    if (buttons & IN_MOVELEFT)
    {
        wish[0] -= rightVec[0];
        wish[1] -= rightVec[1];
    }
    if (wish[0] != 0.0 || wish[1] != 0.0)
    {
        NormalizeVector(wish, wish);
        float velocity[3];
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
        velocity[0] = wish[0] * g_cvCrawlSpeed.FloatValue;
        velocity[1] = wish[1] * g_cvCrawlSpeed.FloatValue;
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
    }
    buttons &= ~IN_JUMP;
    int item = GetPlayerWeaponSlot(client, 4);
    bool hasItem = item > MaxClients && IsValidEntity(item) && IsSelfReviveItem(item);
    if (!(buttons & IN_USE) || !hasItem)
    {
        ResetClient(client);
    }
    else if (!g_bReviving[client])
    {
        if (g_fUseStarted[client] <= 0.0)
        {
            g_fUseStarted[client] = GetGameTime();
            StartProgress(client);
        }
        else if (GetGameTime() - g_fUseStarted[client] >= g_cvSelfReviveTime.FloatValue)
        {
            g_bReviving[client] = true;
            ClearProgress(client);
            SelfRevive(client, item);
            buttons &= ~IN_USE;
            changed = true;
        }
    }

    return changed ? Plugin_Changed : Plugin_Continue;
}

bool IsControlled(int client)
{
    static const char properties[][] = {"m_tongueOwner", "m_pounceAttacker", "m_jockeyAttacker", "m_carryAttacker", "m_pummelAttacker", "m_reviveOwner"};
    for (int index = 0; index < sizeof(properties); index++)
    {
        if (HasEntProp(client, Prop_Send, properties[index]) && GetEntPropEnt(client, Prop_Send, properties[index]) > 0)
        {
            return true;
        }
    }
    return false;
}

void StartProgress(int client)
{
    if (!HasEntProp(client, Prop_Send, "m_flProgressBarDuration") || !HasEntProp(client, Prop_Send, "m_reviveTarget"))
    {
        return;
    }
    SetEntPropEnt(client, Prop_Send, "m_reviveTarget", client);
    SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
    SetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", g_cvSelfReviveTime.FloatValue);
    g_bProgress[client] = true;
}

void ClearProgress(int client)
{
    if (!g_bProgress[client])
    {
        return;
    }
    if (IsClientInGame(client))
    {
        SetEntPropEnt(client, Prop_Send, "m_reviveTarget", -1);
        SetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", 0.0);
    }
    g_bProgress[client] = false;
}

bool IsSelfReviveItem(int entity)
{
    char classname[64];
    GetEntityClassname(entity, classname, sizeof(classname));
    return StrEqual(classname, "weapon_pain_pills") || StrEqual(classname, "weapon_adrenaline");
}

void SelfRevive(int client, int item)
{
    if (GetFeatureStatus(FeatureType_Native, "L4D_ReviveSurvivor") != FeatureStatus_Available)
    {
        PrintToChat(client, "[自救] 自救功能暂不可用，道具未消耗。");
        return;
    }
    char classname[64];
    GetEntityClassname(item, classname, sizeof(classname));
    L4D_ReviveSurvivor(client);
    RemovePlayerItem(client, item);
    AcceptEntityInput(item, "Kill");

    SetEntityHealth(client, g_cvSelfReviveHealth.IntValue);
    if (StrEqual(classname, "weapon_adrenaline")
        && GetFeatureStatus(FeatureType_Native, "L4D2_UseAdrenaline") == FeatureStatus_Available)
    {
        L4D2_UseAdrenaline(client, 15.0, true, true);
    }
    PrintToChat(client, "[自救] 已使用%s自救。", StrEqual(classname, "weapon_pain_pills") ? "止痛药" : "肾上腺素");
}
