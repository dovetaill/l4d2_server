#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define TEAM_SURVIVOR 2

public Plugin myinfo =
{
    name = "L4D2 End Safearea Teleport",
    author = "Codex",
    description = "Moves living survivors into the final safe area after a grace period",
    version = "1.0.0",
    url = ""
};

ConVar g_hEnable;
ConVar g_hDelay;
ConVar g_hFinale;
Handle g_hTimer = null;
bool g_bActive;
int g_iRemaining;
float g_fDestination[3];

public void OnPluginStart()
{
    g_hEnable = CreateConVar("l4d2_end_safearea_enable", "1", "Enable end safearea grace teleport.", _, true, 0.0, true, 1.0);
    g_hDelay = CreateConVar("l4d2_end_safearea_delay", "60", "Seconds before living lagging survivors are teleported.", _, true, 5.0, true, 300.0);
    g_hFinale = CreateConVar("l4d2_end_safearea_finale", "1", "Also apply the grace teleport to finale rescue areas.", _, true, 0.0, true, 1.0);

    HookEvent("round_start", Event_Reset, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_Reset, EventHookMode_PostNoCopy);
    HookEvent("map_transition", Event_Reset, EventHookMode_PostNoCopy);
    HookEvent("mission_lost", Event_Reset, EventHookMode_PostNoCopy);
    HookEvent("finale_win", Event_Reset, EventHookMode_PostNoCopy);
    HookEvent("player_entered_checkpoint", Event_EnteredCheckpoint, EventHookMode_Post);
    AutoExecConfig(true, "l4d2_end_safearea_teleport");
}

public void OnMapStart()
{
        StopGraceTimer();
}

public void OnMapEnd()
{
    StopGraceTimer();
}

public void Event_EnteredCheckpoint(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidSurvivor(client) && IsSurvivorInEndArea(client))
    {
        StartGraceTimer(client);
    }
}

public void Event_Reset(Event event, const char[] name, bool dontBroadcast)
{
    StopGraceTimer();
}

void StartGraceTimer(int client)
{
    if (g_bActive || !g_hEnable.BoolValue || !IsValidSurvivor(client))
    {
        return;
    }

    if (!IsCoopMode())
    {
        return;
    }

    GetClientAbsOrigin(client, g_fDestination);
    g_fDestination[2] += 12.0;
    g_iRemaining = g_hDelay.IntValue;
    g_bActive = true;
    PrintHintTextToAll("Final safe area reached. Remaining survivors will be moved in %d seconds.", g_iRemaining);
    g_hTimer = CreateTimer(1.0, Timer_Grace, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Grace(Handle timer)
{
    if (!g_bActive)
    {
        return Plugin_Stop;
    }

    if (!AnySurvivorInEndArea())
    {
        StopGraceTimer();
        return Plugin_Stop;
    }

    g_iRemaining--;
    if (g_iRemaining <= 0)
    {
        TeleportLaggingSurvivors();
        StopGraceTimer();
        return Plugin_Stop;
    }

    if (g_iRemaining == 30 || g_iRemaining == 15 || g_iRemaining <= 10)
    {
        PrintHintTextToAll("Final safe area: %d", g_iRemaining);
    }
    return Plugin_Continue;
}

void TeleportLaggingSurvivors()
{
    int moved;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidSurvivor(i) || !IsPlayerAlive(i))
        {
            continue;
        }
        if (IsSurvivorInEndArea(i))
        {
            continue;
        }

        float angles[3];
        GetClientEyeAngles(i, angles);
        TeleportEntity(i, g_fDestination, angles, NULL_VECTOR);
        moved++;
    }

    if (moved > 0)
    {
        PrintHintTextToAll("%d survivor(s) were moved into the final safe area.", moved);
    }
}

bool AnySurvivorInEndArea()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidSurvivor(i) && IsPlayerAlive(i) && IsSurvivorInEndArea(i))
        {
            return true;
        }
    }
    return false;
}

bool IsSurvivorInEndArea(int client)
{
    if (g_hFinale.BoolValue && L4D_IsFinaleEscapeInProgress())
    {
        if (L4D_IsInLastCheckpoint(client))
        {
            return true;
        }
    }
    return L4D_IsInLastCheckpoint(client);
}

bool IsCoopMode()
{
    ConVar mode = FindConVar("mp_gamemode");
    if (mode == null)
    {
        return true;
    }

    char value[32];
    mode.GetString(value, sizeof(value));
    return StrEqual(value, "coop", false) || StrEqual(value, "realism", false) || StrEqual(value, "mutation", false);
}

bool IsValidSurvivor(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && !IsFakeClient(client);
}

void StopGraceTimer()
{
    g_bActive = false;
    g_iRemaining = 0;
    if (g_hTimer != null)
    {
        delete g_hTimer;
        g_hTimer = null;
    }
}
