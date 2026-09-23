#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "0.1.0"

ConVar g_cvEnabled;
ConVar g_cvGrace;
ConVar g_cvMinimumInterval;
ConVar g_cvState;
Handle g_hGraceTimer;
bool g_bHadHuman;
int g_iLastTrigger;
char g_sStateFile[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
    name = "L4D2 Restart Empty",
    author = "Codex",
    description = "Graceful empty-server quit coordinated with systemd.",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar("l4d2_restart_empty_enable", "1", "Enable restart after the last human leaves.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvGrace = CreateConVar("l4d2_restart_empty_grace", "90.0", "Seconds to wait before quitting an empty server.", FCVAR_NOTIFY, true, 30.0, true, 600.0);
    g_cvMinimumInterval = CreateConVar("l4d2_restart_empty_min_interval", "3600", "Minimum seconds between plugin-triggered restarts.", FCVAR_NOTIFY, true, 300.0, true, 86400.0);
    g_cvState = CreateConVar("l4d2_restart_empty_state", "IDLE", "Current restart-empty state.", FCVAR_NOTIFY);
    RegAdminCmd("sm_restartempty_status", Command_Status, ADMFLAG_GENERIC, "Show restart-empty state.");
    BuildPath(Path_SM, g_sStateFile, sizeof(g_sStateFile), "data/pve_restart_empty_last.txt");
    LoadLastTrigger();
    g_bHadHuman = CountHumans() > 0;
    AutoExecConfig(true, "l4d2_restart_empty");
}

public void OnConfigsExecuted()
{
    g_bHadHuman = g_bHadHuman || CountHumans() > 0;
}

public void OnClientPutInServer(int client)
{
    if (IsFakeClient(client)) return;
    g_bHadHuman = true;
    CancelGrace("human joined");
}

public void OnClientDisconnect(int client)
{
    if (!IsFakeClient(client)) RequestFrame(Frame_CheckEmpty);
}

public void Frame_CheckEmpty(any data)
{
    CheckEmptyTransition();
}

public Action Timer_GraceExpired(Handle timer)
{
    g_hGraceTimer = null;
    if (!g_cvEnabled.BoolValue || CountHumans() > 0)
    {
        g_cvState.SetString("IDLE");
        return Plugin_Stop;
    }
    g_iLastTrigger = GetTime();
    SaveLastTrigger();
    g_cvState.SetString("QUITTING");
    LogMessage("Empty grace elapsed; issuing normal server quit for systemd restart.");
    ServerCommand("quit");
    ServerExecute();
    return Plugin_Stop;
}

public Action Command_Status(int client, int args)
{
    char state[24];
    g_cvState.GetString(state, sizeof(state));
    ReplyToCommand(client, "[RestartEmpty] state=%s had_human=%d humans=%d last_trigger=%d grace=%.0f min_interval=%d",
        state, g_bHadHuman, CountHumans(), g_iLastTrigger, g_cvGrace.FloatValue, g_cvMinimumInterval.IntValue);
    return Plugin_Handled;
}

void CheckEmptyTransition()
{
    if (!g_cvEnabled.BoolValue || !g_bHadHuman || CountHumans() > 0 || g_hGraceTimer != null)
    {
        return;
    }
    int elapsed = GetTime() - g_iLastTrigger;
    if (g_iLastTrigger > 0 && elapsed < g_cvMinimumInterval.IntValue)
    {
        g_cvState.SetString("RATE_LIMITED");
        LogMessage("Empty restart suppressed by minimum interval: elapsed=%d required=%d", elapsed, g_cvMinimumInterval.IntValue);
        return;
    }
    g_cvState.SetString("GRACE");
    g_hGraceTimer = CreateTimer(g_cvGrace.FloatValue, Timer_GraceExpired);
    LogMessage("Last human left; empty restart grace started for %.0f seconds.", g_cvGrace.FloatValue);
}

void CancelGrace(const char[] reason)
{
    if (g_hGraceTimer != null)
    {
        delete g_hGraceTimer;
        g_hGraceTimer = null;
        LogMessage("Empty restart grace canceled: %s.", reason);
    }
    g_cvState.SetString("IDLE");
}

void LoadLastTrigger()
{
    File file = OpenFile(g_sStateFile, "r");
    if (file == null) return;
    char line[32];
    if (file.ReadLine(line, sizeof(line))) g_iLastTrigger = StringToInt(line);
    delete file;
}

void SaveLastTrigger()
{
    File file = OpenFile(g_sStateFile, "w");
    if (file == null)
    {
        LogError("Unable to write restart state: %s", g_sStateFile);
        return;
    }
    file.WriteLine("%d", g_iLastTrigger);
    delete file;
}

int CountHumans()
{
    int count;
    for (int client = 1; client <= MaxClients; client++)
    {
        count += IsClientInGame(client) && !IsFakeClient(client) ? 1 : 0;
    }
    return count;
}
