/*
 * Based on AtomicStryker/HarryPotter l4d_kickloadstuckers 1.3,
 * fbef0102 commit e0fd18072b82498ed98535329f8b581262a8ff19.
 * Administrators receive a longer timeout, never a permanent exemption.
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.3-pve.1"

ConVar g_cvDuration;
ConVar g_cvAdminDuration;
Handle g_hLoadingTimer[MAXPLAYERS + 1];
float g_fConnectedAt[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "L4D Kick Load Stuckers",
    author = "AtomicStryker, HarryPotter, Codex",
    description = "Kicks clients that remain in connecting/loading state beyond a conservative timeout.",
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
    g_cvDuration = CreateConVar("l4d_kickloadstuckers_duration", "120", "Seconds before a non-admin loading client is kicked.", FCVAR_NOTIFY, true, 90.0, true, 300.0);
    g_cvAdminDuration = CreateConVar("l4d_kickloadstuckers_admin_duration", "180", "Seconds before a reservation-flag loading client is kicked.", FCVAR_NOTIFY, true, 120.0, true, 600.0);
    CreateConVar("l4d_kickloadstuckers_version", PLUGIN_VERSION, "Load stuck cleanup version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);
    RegAdminCmd("sm_kickloading", Command_KickLoading, ADMFLAG_KICK, "Kick all clients still loading.");
    AutoExecConfig(true, "l4d_kickloadstuckers");
}

public void OnClientConnected(int client)
{
    if (IsFakeClient(client))
    {
        return;
    }
    delete g_hLoadingTimer[client];
    g_fConnectedAt[client] = GetEngineTime();
    g_hLoadingTimer[client] = CreateTimer(g_cvDuration.FloatValue, Timer_CheckLoading, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPutInServer(int client)
{
    delete g_hLoadingTimer[client];
}

public void OnClientDisconnect(int client)
{
    delete g_hLoadingTimer[client];
    g_fConnectedAt[client] = 0.0;
}

public Action Timer_CheckLoading(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client > 0 && g_hLoadingTimer[client] == timer)
    {
        g_hLoadingTimer[client] = null;
    }
    if (client <= 0 || !IsClientConnected(client) || IsFakeClient(client) || IsClientInGame(client))
    {
        return Plugin_Stop;
    }

    float elapsed = GetEngineTime() - g_fConnectedAt[client];
    bool admin = CheckCommandAccess(client, "pve_loading_timeout", ADMFLAG_RESERVATION, true);
    float limit = admin ? g_cvAdminDuration.FloatValue : g_cvDuration.FloatValue;
    if (elapsed + 0.1 < limit)
    {
        g_hLoadingTimer[client] = CreateTimer(limit - elapsed, Timer_CheckLoading, userid, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    }

    LogLoadingKick(client, elapsed, admin, "loading timeout");
    KickClient(client, "Loading timeout after %.0f seconds", elapsed);
    return Plugin_Stop;
}

public Action Command_KickLoading(int client, int args)
{
    int kicked;
    for (int target = 1; target <= MaxClients; target++)
    {
        if (!IsClientConnected(target) || IsClientInGame(target) || IsFakeClient(target))
        {
            continue;
        }
        float elapsed = GetEngineTime() - g_fConnectedAt[target];
        LogLoadingKick(target, elapsed, CheckCommandAccess(target, "pve_loading_timeout", ADMFLAG_RESERVATION, true), "manual admin cleanup");
        KickClient(target, "Loading connection removed by an administrator");
        kicked++;
    }
    ReplyToCommand(client, "[PVE] Removed %d loading client(s).", kicked);
    return Plugin_Handled;
}

void LogLoadingKick(int client, float elapsed, bool admin, const char[] reason)
{
    char steamId[32] = "UNKNOWN";
    char name[MAX_NAME_LENGTH] = "UNKNOWN";
    GetClientName(client, name, sizeof(name));
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId), false);

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "logs/kickloadstuckers.log");
    LogToFileEx(path, "name=\"%s\" steamid=%s duration=%.1f admin=%d reason=\"%s\"", name, steamId, elapsed, admin, reason);
}
