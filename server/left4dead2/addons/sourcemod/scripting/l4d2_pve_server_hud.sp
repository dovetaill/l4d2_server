#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <l4d2_playable_witch>

#define PLUGIN_VERSION "0.2.0"
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_TANK 8
#define ENTITY_KIND_NONE 0
#define ENTITY_KIND_COMMON 1
#define ENTITY_KIND_WITCH 2
#define MAX_TRACKED_ENTITIES 2048

ConVar g_cvEnabled;
ConVar g_cvRate;
ConVar g_cvDirectorProfile;
ConVar g_cvAntiRushEnabled;
ConVar g_cvMaxIncaps;
ConVar g_cvDoorOpener;
Handle g_hHudTimer;

bool g_bHudEnabled[MAXPLAYERS + 1];
bool g_bBlackWhiteKnown[MAXPLAYERS + 1];
bool g_bBlackWhite[MAXPLAYERS + 1];
int g_iEntityKind[MAX_TRACKED_ENTITIES + 1];
int g_iCommonCount;
int g_iWitchCount;
int g_iChapterSIKills;
int g_iChapterCommonKills;
int g_iWipes;

public Plugin myinfo =
{
    name = "L4D2 PvE Server HUD",
    author = "Codex",
    description = "Single-owner, one-second PvPvE status HUD with cached entity counters.",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar("l4d2_pve_server_hud_enable", "1", "Enable the global server HUD.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvRate = CreateConVar("l4d2_pve_server_hud_rate", "1.0", "HUD refresh interval.", FCVAR_NOTIFY, true, 1.0, true, 5.0);
    g_cvRate.AddChangeHook(ConVarChanged_Rate);
    g_cvMaxIncaps = FindConVar("survivor_max_incapacitated_count");

    RegConsoleCmd("sm_hud", Command_Hud, "Toggle the global server HUD.");
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("infected_death", Event_InfectedDeath, EventHookMode_PostNoCopy);

    AutoExecConfig(true, "l4d2_pve_server_hud");
}

public void OnAllPluginsLoaded()
{
    g_cvDirectorProfile = FindConVar("l4d2_pve_director_profile");
    g_cvAntiRushEnabled = FindConVar("l4d2_pve_antirush_enable");
    g_cvDoorOpener = FindConVar("l4d2_safearea_opener_name");
}

public void OnConfigsExecuted()
{
    RebuildEntityCounters();
    RefreshHudTimer();
}

public void OnPluginEnd()
{
    StopHudTimer();
}

public void OnMapStart()
{
    ResetChapterCounters();
    ResetEntityCounters();
    RefreshHudTimer();
}

public void OnMapEnd()
{
    StopHudTimer();
}

public void OnClientPutInServer(int client)
{
    g_bHudEnabled[client] = true;
    g_bBlackWhiteKnown[client] = false;
    g_bBlackWhite[client] = false;
    if (!IsFakeClient(client))
    {
        RefreshHudTimer();
    }
}

public void OnClientDisconnect(int client)
{
    bool human = !IsFakeClient(client);
    g_bHudEnabled[client] = false;
    g_bBlackWhiteKnown[client] = false;
    g_bBlackWhite[client] = false;
    if (human)
    {
        RequestFrame(Frame_RefreshHudTimer);
    }
}

public void Frame_RefreshHudTimer(any data)
{
    RefreshHudTimer();
}

public void ConVarChanged_Rate(ConVar convar, const char[] oldValue, const char[] newValue)
{
    StopHudTimer();
    RefreshHudTimer();
}

public Action Command_Hud(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client))
    {
        return Plugin_Handled;
    }
    g_bHudEnabled[client] = !g_bHudEnabled[client];
    PrintToChat(client, "\x04[HUD]\x01 全局 HUD：%s", g_bHudEnabled[client] ? "开启" : "关闭");
    return Plugin_Handled;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ResetChapterCounters();
}

public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast)
{
    g_iWipes++;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (victim > 0 && IsClientInGame(victim) && GetClientTeam(victim) == TEAM_INFECTED)
    {
        int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        if (zombieClass >= 1 && zombieClass <= 6)
        {
            g_iChapterSIKills++;
        }
    }
}

public void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
    g_iChapterCommonKills++;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity <= MaxClients || entity > MAX_TRACKED_ENTITIES)
    {
        return;
    }
    UntrackEntity(entity);
    if (StrEqual(classname, "infected"))
    {
        g_iEntityKind[entity] = ENTITY_KIND_COMMON;
        g_iCommonCount++;
    }
    else if (StrEqual(classname, "witch"))
    {
        g_iEntityKind[entity] = ENTITY_KIND_WITCH;
        g_iWitchCount++;
    }
}

public void OnEntityDestroyed(int entity)
{
    if (entity > MaxClients && entity <= MAX_TRACKED_ENTITIES)
    {
        UntrackEntity(entity);
    }
}

public Action Timer_Hud(Handle timer)
{
    int humanPlayers = CountHumanPlayers();
    if (!g_cvEnabled.BoolValue || humanPlayers == 0)
    {
        g_hHudTimer = null;
        return Plugin_Stop;
    }

    int survivors;
    int humanInfected;
    int aiSI;
    int tank;
    int tankHealth;
    char tankPlayer[MAX_NAME_LENGTH] = "AI";
    CountPlayerState(survivors, humanInfected, aiSI, tank, tankHealth, tankPlayer, sizeof(tankPlayer));

    float flow = GetFlowPercent();
    char profile[24] = "NORMAL";
    if (g_cvDirectorProfile != null)
    {
        g_cvDirectorProfile.GetString(profile, sizeof(profile));
    }
    char antiRush[16] = "OFF";
    if (g_cvAntiRushEnabled != null && g_cvAntiRushEnabled.BoolValue)
    {
        strcopy(antiRush, sizeof(antiRush), "ON");
    }
    char opener[MAX_NAME_LENGTH] = "NONE";
    if (g_cvDoorOpener != null)
    {
        g_cvDoorOpener.GetString(opener, sizeof(opener));
    }
    char witchPlayer[MAX_NAME_LENGTH] = "AI";
    float witchFlow = GetPlayableWitchStatus(witchPlayer, sizeof(witchPlayer));

    char map[64];
    char serverTime[32];
    GetCurrentMap(map, sizeof(map));
    FormatTime(serverTime, sizeof(serverTime), "%H:%M:%S", GetTime());

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client))
        {
            continue;
        }
        NotifyBlackWhiteChange(client);
        if (!g_bHudEnabled[client])
        {
            continue;
        }
        SetHudTextParams(0.01, 0.02, g_cvRate.FloatValue + 0.2, 220, 235, 240, 210, 0, 0.0, 0.0, 0.0);
        ShowHudText(client, 4,
            "%s | %s\n玩家 %d | Survivor %d | 真人SI %d | AI SI %d\nProfile %s | Flow %.0f%% | AntiRush %s\nTank %d HP %d (%s) | Witch %d (%s %.0f%%)\n开门员 %s | 本章 SI %d | Common %d/%d | 团灭 %d | Entity %d",
            map, serverTime, humanPlayers, survivors, humanInfected, aiSI,
            profile, flow, antiRush, tank, tankHealth, tankPlayer, g_iWitchCount,
            witchPlayer, witchFlow, opener, g_iChapterSIKills, g_iCommonCount,
            g_iChapterCommonKills, g_iWipes, GetEntityCount());
    }
    return Plugin_Continue;
}

void RefreshHudTimer()
{
    if (!g_cvEnabled.BoolValue || CountHumanPlayers() == 0)
    {
        StopHudTimer();
        return;
    }
    if (g_hHudTimer == null)
    {
        g_hHudTimer = CreateTimer(g_cvRate.FloatValue, Timer_Hud, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
}

void StopHudTimer()
{
    if (g_hHudTimer != null)
    {
        delete g_hHudTimer;
        g_hHudTimer = null;
    }
}

void CountPlayerState(int &survivors, int &humanInfected, int &aiSI, int &tank, int &tankHealth, char[] tankPlayer, int tankPlayerLength)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
        {
            continue;
        }
        int team = GetClientTeam(client);
        if (team == TEAM_SURVIVOR && !IsFakeClient(client))
        {
            survivors++;
        }
        if (team != TEAM_INFECTED)
        {
            continue;
        }
        int zombieClass = IsPlayerAlive(client) ? GetEntProp(client, Prop_Send, "m_zombieClass") : 0;
        if (zombieClass == ZC_TANK && IsPlayerAlive(client))
        {
            tank++;
            tankHealth += GetClientHealth(client);
            if (!IsFakeClient(client))
            {
                GetClientName(client, tankPlayer, tankPlayerLength);
            }
        }
        else if (zombieClass >= 1 && zombieClass <= 6)
        {
            if (IsFakeClient(client))
            {
                aiSI++;
            }
            else
            {
                humanInfected++;
            }
        }
    }
}

int CountHumanPlayers()
{
    int count;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && !IsFakeClient(client))
        {
            count++;
        }
    }
    return count;
}

float GetFlowPercent()
{
    if (GetFeatureStatus(FeatureType_Native, "L4D2_GetFurthestSurvivorFlow") != FeatureStatus_Available
        || GetFeatureStatus(FeatureType_Native, "L4D2Direct_GetMapMaxFlowDistance") != FeatureStatus_Available)
    {
        return 0.0;
    }
    float maximum = L4D2Direct_GetMapMaxFlowDistance();
    if (maximum <= 0.0)
    {
        return 0.0;
    }
    float percent = L4D2_GetFurthestSurvivorFlow() / maximum * 100.0;
    if (percent < 0.0)
    {
        return 0.0;
    }
    return percent > 100.0 ? 100.0 : percent;
}

float GetPlayableWitchStatus(char[] playerName, int playerNameLength)
{
    if (GetFeatureStatus(FeatureType_Native, "L4D2PlayableWitch_IsControlling") != FeatureStatus_Available
        || GetFeatureStatus(FeatureType_Native, "L4D2PlayableWitch_GetEntity") != FeatureStatus_Available)
    {
        return 0.0;
    }
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || !L4D2PlayableWitch_IsControlling(client))
        {
            continue;
        }
        GetClientName(client, playerName, playerNameLength);
        int witch = L4D2PlayableWitch_GetEntity(client);
        if (witch <= MaxClients || !IsValidEntity(witch))
        {
            return 0.0;
        }
        float position[3];
        GetEntPropVector(witch, Prop_Send, "m_vecOrigin", position);
        Address area = L4D2Direct_GetTerrorNavArea(position);
        float maximum = L4D2Direct_GetMapMaxFlowDistance();
        if (area == Address_Null || maximum <= 0.0)
        {
            return 0.0;
        }
        float flow = L4D2Direct_GetTerrorNavAreaFlow(area) / maximum * 100.0;
        return flow < 0.0 ? 0.0 : (flow > 100.0 ? 100.0 : flow);
    }
    return 0.0;
}

void NotifyBlackWhiteChange(int client)
{
    if (GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client) || g_cvMaxIncaps == null)
    {
        g_bBlackWhiteKnown[client] = false;
        g_bBlackWhite[client] = false;
        return;
    }
    int revives = GetEntProp(client, Prop_Send, "m_currentReviveCount");
    bool blackWhite = revives >= g_cvMaxIncaps.IntValue;
    if (g_bBlackWhiteKnown[client] && blackWhite != g_bBlackWhite[client])
    {
        PrintToChatAll("\x04[状态]\x01 %N %s黑白状态。", client, blackWhite ? "进入" : "解除");
    }
    g_bBlackWhiteKnown[client] = true;
    g_bBlackWhite[client] = blackWhite;
}

void UntrackEntity(int entity)
{
    if (g_iEntityKind[entity] == ENTITY_KIND_COMMON && g_iCommonCount > 0)
    {
        g_iCommonCount--;
    }
    else if (g_iEntityKind[entity] == ENTITY_KIND_WITCH && g_iWitchCount > 0)
    {
        g_iWitchCount--;
    }
    g_iEntityKind[entity] = ENTITY_KIND_NONE;
}

void ResetChapterCounters()
{
    g_iChapterSIKills = 0;
    g_iChapterCommonKills = 0;
}

void ResetEntityCounters()
{
    g_iCommonCount = 0;
    g_iWitchCount = 0;
    for (int entity = MaxClients + 1; entity <= MAX_TRACKED_ENTITIES; entity++)
    {
        g_iEntityKind[entity] = ENTITY_KIND_NONE;
    }
}

void RebuildEntityCounters()
{
    ResetEntityCounters();
    int limit = GetMaxEntities();
    if (limit > MAX_TRACKED_ENTITIES + 1)
    {
        limit = MAX_TRACKED_ENTITIES + 1;
    }
    char classname[32];
    for (int entity = MaxClients + 1; entity < limit; entity++)
    {
        if (!IsValidEntity(entity) || !GetEntityClassname(entity, classname, sizeof(classname)))
        {
            continue;
        }
        if (StrEqual(classname, "infected"))
        {
            g_iEntityKind[entity] = ENTITY_KIND_COMMON;
            g_iCommonCount++;
        }
        else if (StrEqual(classname, "witch"))
        {
            g_iEntityKind[entity] = ENTITY_KIND_WITCH;
            g_iWitchCount++;
        }
    }
}
