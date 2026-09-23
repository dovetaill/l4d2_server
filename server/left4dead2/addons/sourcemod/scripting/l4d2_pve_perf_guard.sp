#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <l4d2_pve_director_controller>

#define PLUGIN_VERSION "0.1.0"
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_TANK 8

ConVar g_cvEnabled;
ConVar g_cvSampleRate;
ConVar g_cvWarn;
ConVar g_cvCritical;
ConVar g_cvRecovery;
ConVar g_cvLogInterval;
ConVar g_cvRisk;
ConVar g_cvDirectorProfile;
Handle g_hTimer;
StringMap g_mPreviousCounts;
float g_fNextLog;
float g_fNextRecoveryRequest;

public Plugin myinfo =
{
    name = "L4D2 PvE Performance Guard",
    author = "Codex",
    description = "Read-only performance and entity pressure diagnostics.",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar("l4d2_pve_perf_guard_enable", "1", "Enable performance diagnostics.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvSampleRate = CreateConVar("l4d2_pve_perf_guard_sample_rate", "5.0", "Performance sample interval.", FCVAR_NOTIFY, true, 2.0, true, 5.0);
    g_cvWarn = CreateConVar("l4d2_pve_perf_guard_entity_warn", "1600", "Entity warning threshold.", FCVAR_NOTIFY, true, 1000.0, true, 2040.0);
    g_cvCritical = CreateConVar("l4d2_pve_perf_guard_entity_critical", "1800", "Entity critical threshold.", FCVAR_NOTIFY, true, 1000.0, true, 2040.0);
    g_cvRecovery = CreateConVar("l4d2_pve_perf_guard_entity_recovery", "1850", "Entity threshold requesting temporary Director RECOVERY.", FCVAR_NOTIFY, true, 1000.0, true, 2040.0);
    g_cvLogInterval = CreateConVar("l4d2_pve_perf_guard_log_interval", "30.0", "Minimum seconds between threshold logs.", FCVAR_NOTIFY, true, 10.0, true, 300.0);
    g_cvRisk = CreateConVar("l4d2_pve_perf_guard_risk", "NORMAL", "Current entity risk level.", FCVAR_NOTIFY);
    RegConsoleCmd("sm_pveperf", Command_Performance, "Show current server performance counters.");
    g_mPreviousCounts = new StringMap();
    AutoExecConfig(true, "l4d2_pve_perf_guard");
}

public void OnAllPluginsLoaded()
{
    g_cvDirectorProfile = FindConVar("l4d2_pve_director_profile");
    RefreshTimer();
}

public void OnMapStart()
{
    g_mPreviousCounts.Clear();
    g_fNextLog = 0.0;
    g_fNextRecoveryRequest = 0.0;
    RefreshTimer();
}

public void OnMapEnd()
{
    StopTimer();
}

public void OnClientPutInServer(int client)
{
    if (!IsFakeClient(client)) RefreshTimer();
}

public void OnClientDisconnect(int client)
{
    if (!IsFakeClient(client)) RequestFrame(Frame_RefreshTimer);
}

public void Frame_RefreshTimer(any data)
{
    RefreshTimer();
}

public Action Timer_Sample(Handle timer)
{
    if (CountHumans() == 0)
    {
        g_hTimer = null;
        return Plugin_Stop;
    }
    SampleEntityPressure();
    return Plugin_Continue;
}

public Action Command_Performance(int client, int args)
{
    int survivors;
    int aiSI;
    int humanSI;
    int common;
    int tank;
    int witch;
    CountRuntimeState(survivors, aiSI, humanSI, common, tank, witch);
    char profile[24] = "UNAVAILABLE";
    if (g_cvDirectorProfile != null) g_cvDirectorProfile.GetString(profile, sizeof(profile));
    char risk[16];
    g_cvRisk.GetString(risk, sizeof(risk));
    int tickrate = RoundToNearest(1.0 / GetTickInterval());
    ReplyToCommand(client, "[PVEPerf] CPU=N/A VAR=N/A timers=N/A tick=%d players=%d survivors=%d ai_si=%d human_si=%d common=%d entities=%d tank=%d witch=%d profile=%s risk=%s",
        tickrate, CountHumans(), survivors, aiSI, humanSI, common, GetEntityCount(), tank, witch, profile, risk);
    return Plugin_Handled;
}

void RefreshTimer()
{
    if (!g_cvEnabled.BoolValue || CountHumans() == 0)
    {
        StopTimer();
        return;
    }
    if (g_hTimer == null) g_hTimer = CreateTimer(g_cvSampleRate.FloatValue, Timer_Sample, _, TIMER_REPEAT);
}

void StopTimer()
{
    delete g_hTimer;
    g_hTimer = null;
}

void SampleEntityPressure()
{
    int entities = GetEntityCount();
    char risk[16] = "NORMAL";
    if (entities >= g_cvCritical.IntValue) strcopy(risk, sizeof(risk), "CRITICAL");
    else if (entities >= g_cvWarn.IntValue) strcopy(risk, sizeof(risk), "WARN");
    g_cvRisk.SetString(risk);
    if (entities < g_cvWarn.IntValue)
    {
        return;
    }

    char fastestClass[64] = "none";
    int fastestGrowth;
    BuildClassGrowth(fastestClass, sizeof(fastestClass), fastestGrowth);
    float now = GetGameTime();
    if (now >= g_fNextLog)
    {
        int survivors;
        int aiSI;
        int humanSI;
        int common;
        int tank;
        int witch;
        CountRuntimeState(survivors, aiSI, humanSI, common, tank, witch);
        char map[64];
        GetCurrentMap(map, sizeof(map));
        LogMessage("risk=%s entities=%d fastest_class=%s delta=%d map=%s humans=%d survivors=%d ai_si=%d human_si=%d common=%d tank=%d witch=%d",
            risk, entities, fastestClass, fastestGrowth, map, CountHumans(), survivors, aiSI, humanSI, common, tank, witch);
        g_fNextLog = now + g_cvLogInterval.FloatValue;
    }
    if (entities >= g_cvRecovery.IntValue && now >= g_fNextRecoveryRequest
        && GetFeatureStatus(FeatureType_Native, "L4D2PveDirector_RequestRecovery") == FeatureStatus_Available)
    {
        L4D2PveDirector_RequestRecovery(30.0, "entity pressure");
        g_fNextRecoveryRequest = now + 15.0;
    }
}

void BuildClassGrowth(char[] fastestClass, int maxLength, int &fastestGrowth)
{
    StringMap current = new StringMap();
    char classname[64];
    for (int entity = MaxClients + 1; entity < GetMaxEntities(); entity++)
    {
        if (!IsValidEntity(entity)) continue;
        GetEntityClassname(entity, classname, sizeof(classname));
        int count;
        current.GetValue(classname, count);
        current.SetValue(classname, count + 1);
    }

    StringMapSnapshot snapshot = current.Snapshot();
    for (int index = 0; index < snapshot.Length; index++)
    {
        snapshot.GetKey(index, classname, sizeof(classname));
        int count;
        int previous;
        current.GetValue(classname, count);
        g_mPreviousCounts.GetValue(classname, previous);
        int growth = count - previous;
        if (growth > fastestGrowth)
        {
            fastestGrowth = growth;
            strcopy(fastestClass, maxLength, classname);
        }
    }
    delete snapshot;
    delete g_mPreviousCounts;
    g_mPreviousCounts = current;
}

void CountRuntimeState(int &survivors, int &aiSI, int &humanSI, int &common, int &tank, int &witch)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client)) continue;
        if (GetClientTeam(client) == TEAM_SURVIVOR)
        {
            survivors++;
            continue;
        }
        if (GetClientTeam(client) != TEAM_INFECTED || !IsPlayerAlive(client)) continue;
        int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
        if (zombieClass == ZC_TANK) tank++;
        else if (zombieClass >= 1 && zombieClass <= 6)
        {
            if (IsFakeClient(client)) aiSI++;
            else humanSI++;
        }
    }
    char classname[32];
    for (int entity = MaxClients + 1; entity < GetMaxEntities(); entity++)
    {
        if (!IsValidEntity(entity)) continue;
        GetEntityClassname(entity, classname, sizeof(classname));
        if (StrEqual(classname, "infected")) common++;
        else if (StrEqual(classname, "witch")) witch++;
    }
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
