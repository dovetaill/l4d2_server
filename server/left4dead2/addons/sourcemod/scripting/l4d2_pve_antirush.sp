#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <l4d2_campaign_shop>

#define PLUGIN_VERSION "0.1.0"
#define TEAM_SURVIVOR 2

ConVar g_cvEnabled;
ConVar g_cvWarningUnits;
ConVar g_cvWarningPercent;
ConVar g_cvWarningSeconds;
ConVar g_cvSevereUnits;
ConVar g_cvSeverePercent;
ConVar g_cvSevereSeconds;
ConVar g_cvSecondPenalty;
ConVar g_cvThirdPenalty;
ConVar g_cvCooldown;
ConVar g_cvStatus;

Handle g_hTimer;
float g_fLeadSince[MAXPLAYERS + 1];
float g_fLastAction[MAXPLAYERS + 1];
int g_iOffenses[MAXPLAYERS + 1];
bool g_bFinaleStarted;
bool g_bOfficialMap;

public Plugin myinfo =
{
    name = "L4D2 PvE AntiRush",
    author = "Codex",
    description = "Flow-median anti-rush with safe warning-first escalation.",
    version = PLUGIN_VERSION,
    url = ""
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
    g_cvEnabled = CreateConVar("l4d2_pve_antirush_enable", "1", "Enable flow-based anti-rush.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvWarningUnits = CreateConVar("l4d2_pve_antirush_warning_units", "1000", "Absolute warning lead distance.", FCVAR_NOTIFY, true, 100.0, true, 5000.0);
    g_cvWarningPercent = CreateConVar("l4d2_pve_antirush_warning_percent", "0.10", "Map flow warning lead ratio.", FCVAR_NOTIFY, true, 0.01, true, 0.50);
    g_cvWarningSeconds = CreateConVar("l4d2_pve_antirush_warning_seconds", "6.0", "Required warning lead duration.", FCVAR_NOTIFY, true, 2.0, true, 30.0);
    g_cvSevereUnits = CreateConVar("l4d2_pve_antirush_severe_units", "1300", "Absolute severe lead distance.", FCVAR_NOTIFY, true, 100.0, true, 5000.0);
    g_cvSeverePercent = CreateConVar("l4d2_pve_antirush_severe_percent", "0.15", "Map flow severe lead ratio.", FCVAR_NOTIFY, true, 0.01, true, 0.50);
    g_cvSevereSeconds = CreateConVar("l4d2_pve_antirush_severe_seconds", "10.0", "Required severe lead duration.", FCVAR_NOTIFY, true, 2.0, true, 30.0);
    g_cvSecondPenalty = CreateConVar("l4d2_pve_antirush_second_penalty", "15", "Campaign points removed on the second safe teleport.", FCVAR_NOTIFY, true, 0.0, true, 200.0);
    g_cvThirdPenalty = CreateConVar("l4d2_pve_antirush_third_penalty", "30", "Campaign points removed from the third safe teleport onward.", FCVAR_NOTIFY, true, 0.0, true, 200.0);
    g_cvCooldown = CreateConVar("l4d2_pve_antirush_action_cooldown", "15.0", "Minimum time between actions for one player.", FCVAR_NOTIFY, true, 5.0, true, 60.0);
    g_cvStatus = CreateConVar("l4d2_pve_antirush_status", "IDLE", "Current anti-rush status.", FCVAR_NOTIFY);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("finale_start", Event_FinaleStart, EventHookMode_PostNoCopy);
    HookEvent("finale_vehicle_leaving", Event_FinaleStart, EventHookMode_PostNoCopy);
    AutoExecConfig(true, "l4d2_pve_antirush");
}

public void OnAllPluginsLoaded()
{
    if (GetFeatureStatus(FeatureType_Native, "L4D2Direct_GetMapMaxFlowDistance") != FeatureStatus_Available
        || GetFeatureStatus(FeatureType_Native, "L4D2Direct_GetFlowDistance") != FeatureStatus_Available)
    {
        SetFailState("Left4DHooks flow natives are required.");
    }
}

public void OnMapStart()
{
    char map[64];
    GetCurrentMap(map, sizeof(map));
    g_bOfficialMap = IsOfficialCampaignMap(map);
    ResetChapterState();
    RefreshTimer();
}

public void OnMapEnd()
{
    StopTimer();
}

public void OnClientPutInServer(int client)
{
    ResetClient(client);
    if (!IsFakeClient(client))
    {
        RefreshTimer();
    }
}

public void OnClientDisconnect(int client)
{
    ResetClient(client);
    RequestFrame(Frame_RefreshTimer);
}

public void Frame_RefreshTimer(any data)
{
    RefreshTimer();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ResetChapterState();
}

public void Event_FinaleStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bFinaleStarted = true;
    g_cvStatus.SetString("FINALE_EXEMPT");
}

public Action Timer_CheckRush(Handle timer)
{
    if (CountHumans() == 0)
    {
        g_hTimer = null;
        return Plugin_Stop;
    }
    EvaluateRunners();
    return Plugin_Continue;
}

void RefreshTimer()
{
    if (!g_cvEnabled.BoolValue || CountHumans() == 0)
    {
        StopTimer();
        return;
    }
    if (g_hTimer == null)
    {
        g_hTimer = CreateTimer(1.0, Timer_CheckRush, _, TIMER_REPEAT);
    }
}

void StopTimer()
{
    delete g_hTimer;
    g_hTimer = null;
}

void EvaluateRunners()
{
    if (!g_cvEnabled.BoolValue || g_bFinaleStarted || L4D_IsFinaleEscapeInProgress())
    {
        ResetLeadTimers();
        return;
    }

    int clients[MAXPLAYERS + 1];
    float flows[MAXPLAYERS + 1];
    int count = CollectValidSurvivors(clients, flows);
    if (count <= 2)
    {
        g_cvStatus.SetString("LOW_TEAM_EXEMPT");
        ResetLeadTimers();
        return;
    }
    SortByFlow(clients, flows, count);
    float median = count % 2 == 0 ? (flows[count / 2 - 1] + flows[count / 2]) * 0.5 : flows[count / 2];
    float mapFlow = L4D2Direct_GetMapMaxFlowDistance();
    if (mapFlow <= 0.0)
    {
        g_cvStatus.SetString("FLOW_UNAVAILABLE");
        ResetLeadTimers();
        return;
    }

    float warning = g_cvWarningUnits.FloatValue;
    float relativeWarning = mapFlow * g_cvWarningPercent.FloatValue;
    if (relativeWarning > warning) warning = relativeWarning;
    float severe = g_cvSevereUnits.FloatValue;
    float relativeSevere = mapFlow * g_cvSeverePercent.FloatValue;
    if (relativeSevere > severe) severe = relativeSevere;
    float now = GetGameTime();
    bool monitoring;

    for (int index = 0; index < count; index++)
    {
        int client = clients[index];
        float lead = flows[index] - median;
        if (lead < warning)
        {
            g_fLeadSince[client] = 0.0;
            continue;
        }
        monitoring = true;
        if (g_fLeadSince[client] <= 0.0)
        {
            g_fLeadSince[client] = now;
            PrintToChat(client, "\x04[防跑图]\x01 你已明显领先队伍，请等待队友。");
            continue;
        }
        float required = lead >= severe ? g_cvSevereSeconds.FloatValue : g_cvWarningSeconds.FloatValue;
        if (now - g_fLeadSince[client] < required || now - g_fLastAction[client] < g_cvCooldown.FloatValue)
        {
            continue;
        }
        int anchor = FindAnchor(clients, count, client);
        HandleViolation(client, anchor, lead, mapFlow);
        g_fLeadSince[client] = 0.0;
        g_fLastAction[client] = now;
    }
    g_cvStatus.SetString(monitoring ? (g_bOfficialMap ? "ACTIVE" : "WARNING_ONLY") : "IDLE");
}

int CollectValidSurvivors(int clients[MAXPLAYERS + 1], float flows[MAXPLAYERS + 1])
{
    int count;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsSafeSurvivor(client))
        {
            continue;
        }
        clients[count] = client;
        flows[count] = L4D2Direct_GetFlowDistance(client);
        count++;
    }
    return count;
}

void SortByFlow(int clients[MAXPLAYERS + 1], float flows[MAXPLAYERS + 1], int count)
{
    for (int left = 0; left < count - 1; left++)
    {
        for (int right = left + 1; right < count; right++)
        {
            if (flows[right] < flows[left])
            {
                float flow = flows[left];
                flows[left] = flows[right];
                flows[right] = flow;
                int client = clients[left];
                clients[left] = clients[right];
                clients[right] = client;
            }
        }
    }
}

int FindAnchor(int clients[MAXPLAYERS + 1], int count, int runner)
{
    int index = RoundToFloor(float(count - 1) * 0.40);
    if (clients[index] == runner && index > 0)
    {
        index--;
    }
    return clients[index];
}

void HandleViolation(int client, int anchor, float lead, float mapFlow)
{
    if (!CanSafelyTeleport(client, anchor))
    {
        PrintToChatAll("\x04[防跑图]\x01 %N 领先队伍 %.0f（地图 %.0f），当前场景仅警告。", client, lead, mapFlow);
        return;
    }

    g_iOffenses[client]++;
    if (g_iOffenses[client] == 1)
    {
        PrintToChatAll("\x04[防跑图]\x01 %N 领先队伍 %.0f（地图 %.0f），已警告。", client, lead, mapFlow);
        return;
    }

    float origin[3];
    float angles[3];
    float velocity[3] = {0.0, 0.0, 0.0};
    GetClientAbsOrigin(anchor, origin);
    GetClientAbsAngles(anchor, angles);
    origin[2] += 8.0;
    TeleportEntity(client, origin, angles, velocity);

    int penalty = g_iOffenses[client] == 2 ? g_cvSecondPenalty.IntValue : g_cvThirdPenalty.IntValue;
    if (penalty > 0 && GetFeatureStatus(FeatureType_Native, "L4D2CampaignShop_RemovePoints") == FeatureStatus_Available)
    {
        L4D2CampaignShop_RemovePoints(client, penalty);
    }
    PrintToChatAll("\x04[防跑图]\x01 %N 已传送回队伍并扣除 %d 分。", client, penalty);
    LogMessage("runner=%L offense=%d lead=%.0f anchor=%L penalty=%d", client, g_iOffenses[client], lead, anchor, penalty);
}

bool CanSafelyTeleport(int client, int anchor)
{
    if (!g_bOfficialMap || !IsSafeSurvivor(client) || !IsSafeSurvivor(anchor))
    {
        return false;
    }
    if (!(GetEntityFlags(client) & FL_ONGROUND) || !(GetEntityFlags(anchor) & FL_ONGROUND))
    {
        return false;
    }
    if (IsOnMovingPlatform(client) || IsOnMovingPlatform(anchor))
    {
        return false;
    }
    float runnerOrigin[3];
    float anchorOrigin[3];
    GetClientAbsOrigin(client, runnerOrigin);
    GetClientAbsOrigin(anchor, anchorOrigin);
    return FloatAbs(runnerOrigin[2] - anchorOrigin[2]) <= 180.0;
}

bool IsOnMovingPlatform(int client)
{
    if (!HasEntProp(client, Prop_Send, "m_hGroundEntity"))
    {
        return false;
    }
    int ground = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
    if (ground <= MaxClients || !IsValidEntity(ground))
    {
        return false;
    }
    char classname[64];
    GetEntityClassname(ground, classname, sizeof(classname));
    return StrEqual(classname, "func_elevator") || StrEqual(classname, "func_movelinear")
        || StrEqual(classname, "func_tracktrain") || StrEqual(classname, "func_train");
}

bool IsSafeSurvivor(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client)
        && GetClientTeam(client) == TEAM_SURVIVOR
        && GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) == 0
        && GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) == 0
        && !IsControlled(client);
}

bool IsControlled(int client)
{
    static const char properties[][] = {"m_tongueOwner", "m_pounceAttacker", "m_jockeyAttacker", "m_carryAttacker", "m_pummelAttacker"};
    for (int index = 0; index < sizeof(properties); index++)
    {
        if (HasEntProp(client, Prop_Send, properties[index]) && GetEntPropEnt(client, Prop_Send, properties[index]) > 0)
        {
            return true;
        }
    }
    return false;
}

bool IsOfficialCampaignMap(const char[] map)
{
    if (map[0] != 'c')
    {
        return false;
    }
    int index = 1;
    bool hasDigit;
    while (map[index] != '\0' && IsCharNumeric(map[index]))
    {
        hasDigit = true;
        index++;
    }
    return hasDigit && map[index] == 'm' && IsCharNumeric(map[index + 1]);
}

void ResetChapterState()
{
    g_bFinaleStarted = false;
    for (int client = 1; client <= MaxClients; client++)
    {
        ResetClient(client);
    }
    g_cvStatus.SetString("IDLE");
}

void ResetLeadTimers()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        g_fLeadSince[client] = 0.0;
    }
}

void ResetClient(int client)
{
    g_fLeadSince[client] = 0.0;
    g_fLastAction[client] = 0.0;
    g_iOffenses[client] = 0;
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
