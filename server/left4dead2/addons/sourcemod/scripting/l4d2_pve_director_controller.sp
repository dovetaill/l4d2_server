#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4dinfectedbots>

#define PLUGIN_VERSION "0.1.0"
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_TANK 8
#define PROFILE_RECOVERY 0
#define PROFILE_NORMAL 1
#define PROFILE_PRESSURE 2
#define SI_KILL_HISTORY 64

ConVar g_cvEnabled;
ConVar g_cvEvaluateRate;
ConVar g_cvTargetSmall;
ConVar g_cvTargetMedium;
ConVar g_cvTargetLarge;
ConVar g_cvTargetFull;
ConVar g_cvRecoveryReduction;
ConVar g_cvPressureBonus;
ConVar g_cvHardCap;
ConVar g_cvHeadroom;
ConVar g_cvRecoveryMin;
ConVar g_cvRecoveryMax;
ConVar g_cvNormalMin;
ConVar g_cvNormalMax;
ConVar g_cvPressureMin;
ConVar g_cvPressureMax;
ConVar g_cvPressureHealth;
ConVar g_cvPressureSpread;
ConVar g_cvProfile;
ConVar g_cvTarget;
ConVar g_cvSlotCapacity;
ConVar g_cvReservedSlots;
ConVar g_cvWeights[3][6];

Handle g_hEvaluateTimer;
float g_fExternalRecoveryUntil;
char g_sExternalRecoveryReason[96];
float g_fLastSurvivorDamage;
float g_fSIKillTimes[SI_KILL_HISTORY];
int g_iSIKillCursor;
int g_iCurrentProfile = PROFILE_NORMAL;
int g_iLastTarget = -1;
float g_fLastMin = -1.0;
float g_fLastMax = -1.0;

public Plugin myinfo =
{
    name = "L4D2 PvE Director Controller",
    author = "Codex",
    description = "Policy controller; InfectedBots remains the sole SI spawn executor.",
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
    RegPluginLibrary("l4d2_pve_director_controller");
    CreateNative("L4D2PveDirector_RequestRecovery", Native_RequestRecovery);
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar("l4d2_pve_director_enable", "1", "Enable dynamic SI policy.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvEvaluateRate = CreateConVar("l4d2_pve_director_evaluate_rate", "5.0", "Full policy evaluation interval.", FCVAR_NOTIFY, true, 5.0, true, 15.0);
    g_cvTargetSmall = CreateConVar("l4d2_pve_director_target_1_4", "5", "NORMAL SI target for 1-4 active Survivors.", FCVAR_NOTIFY, true, 1.0, true, 12.0);
    g_cvTargetMedium = CreateConVar("l4d2_pve_director_target_5_8", "8", "NORMAL SI target for 5-8 active Survivors.", FCVAR_NOTIFY, true, 1.0, true, 12.0);
    g_cvTargetLarge = CreateConVar("l4d2_pve_director_target_9_12", "10", "NORMAL SI target for 9-12 active Survivors.", FCVAR_NOTIFY, true, 1.0, true, 12.0);
    g_cvTargetFull = CreateConVar("l4d2_pve_director_target_13_16", "12", "NORMAL SI target for 13-16 active Survivors.", FCVAR_NOTIFY, true, 1.0, true, 12.0);
    g_cvRecoveryReduction = CreateConVar("l4d2_pve_director_recovery_reduction", "2", "SI target reduction in RECOVERY.", FCVAR_NOTIFY, true, 0.0, true, 8.0);
    g_cvPressureBonus = CreateConVar("l4d2_pve_director_pressure_bonus", "1", "SI target bonus in PRESSURE.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
    g_cvHardCap = CreateConVar("l4d2_pve_director_hard_cap", "12", "Absolute SI policy cap.", FCVAR_NOTIFY, true, 1.0, true, 12.0);
    g_cvHeadroom = CreateConVar("l4d2_pve_director_engine_headroom", "2", "Engine slots never allocated to SI policy.", FCVAR_NOTIFY, true, 2.0, true, 8.0);
    g_cvRecoveryMin = CreateConVar("l4d2_pve_director_recovery_spawn_min", "32.0", "RECOVERY minimum SI respawn delay.", FCVAR_NOTIFY, true, 3.0, true, 180.0);
    g_cvRecoveryMax = CreateConVar("l4d2_pve_director_recovery_spawn_max", "42.0", "RECOVERY maximum SI respawn delay.", FCVAR_NOTIFY, true, 3.0, true, 180.0);
    g_cvNormalMin = CreateConVar("l4d2_pve_director_normal_spawn_min", "24.0", "NORMAL minimum SI respawn delay.", FCVAR_NOTIFY, true, 3.0, true, 180.0);
    g_cvNormalMax = CreateConVar("l4d2_pve_director_normal_spawn_max", "34.0", "NORMAL maximum SI respawn delay.", FCVAR_NOTIFY, true, 3.0, true, 180.0);
    g_cvPressureMin = CreateConVar("l4d2_pve_director_pressure_spawn_min", "20.0", "PRESSURE minimum SI respawn delay.", FCVAR_NOTIFY, true, 3.0, true, 180.0);
    g_cvPressureMax = CreateConVar("l4d2_pve_director_pressure_spawn_max", "28.0", "PRESSURE maximum SI respawn delay.", FCVAR_NOTIFY, true, 3.0, true, 180.0);
    g_cvPressureHealth = CreateConVar("l4d2_pve_director_pressure_health", "75", "Minimum average active Survivor health for PRESSURE.", FCVAR_NOTIFY, true, 1.0, true, 100.0);
    g_cvPressureSpread = CreateConVar("l4d2_pve_director_pressure_spread", "0.12", "Maximum team flow spread ratio for PRESSURE.", FCVAR_NOTIFY, true, 0.02, true, 0.50);
    g_cvProfile = CreateConVar("l4d2_pve_director_profile", "NORMAL", "Current dynamic profile status.", FCVAR_NOTIFY);
    g_cvTarget = CreateConVar("l4d2_pve_director_target", "0", "Current slot-safe SI target status.", FCVAR_NOTIFY);
    g_cvSlotCapacity = CreateConVar("l4d2_pve_director_slot_capacity", "0", "Current slot-safe SI capacity status.", FCVAR_NOTIFY);
    CreateWeightCvars();
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    AutoExecConfig(true, "l4d2_pve_director_controller");
}

public void OnAllPluginsLoaded()
{
    if (GetFeatureStatus(FeatureType_Native, "L4DInfectedBots_SetDynamicPolicy") != FeatureStatus_Available)
    {
        SetFailState("Patched InfectedBots dynamic policy native is required.");
    }
    g_cvReservedSlots = FindConVar("pve_admin_reserved_slots");
    RefreshEvaluationTimer();
}

public void OnConfigsExecuted()
{
    RefreshEvaluationTimer();
    EvaluatePolicy();
}

public void OnMapStart()
{
    ResetRoundState();
    RefreshEvaluationTimer();
}

public void OnMapEnd()
{
    StopEvaluationTimer();
}

public void OnClientPutInServer(int client)
{
    if (!IsFakeClient(client))
    {
        RefreshEvaluationTimer();
    }
}

public void OnClientDisconnect(int client)
{
    if (!IsFakeClient(client))
    {
        RequestFrame(Frame_RefreshTimer);
    }
}

public void Frame_RefreshTimer(any data)
{
    RefreshEvaluationTimer();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ResetRoundState();
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (victim > 0 && IsClientInGame(victim) && GetClientTeam(victim) == TEAM_SURVIVOR)
    {
        g_fLastSurvivorDamage = GetGameTime();
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (victim <= 0 || !IsClientInGame(victim) || GetClientTeam(victim) != TEAM_INFECTED)
    {
        return;
    }
    int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
    if (zombieClass >= 1 && zombieClass <= 6)
    {
        g_fSIKillTimes[g_iSIKillCursor] = GetGameTime();
        g_iSIKillCursor = (g_iSIKillCursor + 1) % SI_KILL_HISTORY;
    }
}

public Action Timer_Evaluate(Handle timer)
{
    if (CountHumans() == 0)
    {
        g_hEvaluateTimer = null;
        return Plugin_Stop;
    }
    EvaluatePolicy();
    return Plugin_Continue;
}

public int Native_RequestRecovery(Handle plugin, int numParams)
{
    float seconds = view_as<float>(GetNativeCell(1));
    seconds = seconds < 5.0 ? 5.0 : (seconds > 120.0 ? 120.0 : seconds);
    GetNativeString(2, g_sExternalRecoveryReason, sizeof(g_sExternalRecoveryReason));
    float until = GetGameTime() + seconds;
    if (until > g_fExternalRecoveryUntil)
    {
        g_fExternalRecoveryUntil = until;
    }
    EvaluatePolicy();
    return 1;
}

void CreateWeightCvars()
{
    static const char profileNames[][] = {"recovery", "normal", "pressure"};
    static const int defaults[3][6] =
    {
        {65, 100, 60, 100, 55, 55},
        {100, 80, 100, 80, 100, 100},
        {110, 85, 115, 85, 110, 110}
    };
    static const char classNames[][] = {"smoker", "boomer", "hunter", "spitter", "jockey", "charger"};
    char cvarName[96];
    char defaultValue[16];
    for (int profile = 0; profile < 3; profile++)
    {
        for (int zombieClass = 0; zombieClass < 6; zombieClass++)
        {
            Format(cvarName, sizeof(cvarName), "l4d2_pve_director_%s_%s_weight", profileNames[profile], classNames[zombieClass]);
            IntToString(defaults[profile][zombieClass], defaultValue, sizeof(defaultValue));
            g_cvWeights[profile][zombieClass] = CreateConVar(cvarName, defaultValue, "InfectedBots class weight for this profile.", FCVAR_NOTIFY, true, 0.0, true, 1000.0);
        }
    }
}

void RefreshEvaluationTimer()
{
    if (!g_cvEnabled.BoolValue || CountHumans() == 0)
    {
        StopEvaluationTimer();
        return;
    }
    if (g_hEvaluateTimer == null)
    {
        g_hEvaluateTimer = CreateTimer(g_cvEvaluateRate.FloatValue, Timer_Evaluate, _, TIMER_REPEAT);
    }
}

void StopEvaluationTimer()
{
    delete g_hEvaluateTimer;
    g_hEvaluateTimer = null;
}

void ResetRoundState()
{
    g_fLastSurvivorDamage = 0.0;
    g_fExternalRecoveryUntil = 0.0;
    g_sExternalRecoveryReason[0] = '\0';
    g_iSIKillCursor = 0;
    for (int index = 0; index < SI_KILL_HISTORY; index++)
    {
        g_fSIKillTimes[index] = 0.0;
    }
}

void EvaluatePolicy()
{
    if (!g_cvEnabled.BoolValue || CountHumans() == 0)
    {
        return;
    }
    int alive;
    int incapacitated;
    int hanging;
    int controlled;
    int healthTotal;
    bool tankAlive;
    float minimumFlow;
    float maximumFlow;
    CollectTeamState(alive, incapacitated, hanging, controlled, healthTotal, tankAlive, minimumFlow, maximumFlow);
    if (alive <= 0)
    {
        return;
    }
    int effective = alive - incapacitated - hanging - controlled;
    float badRatio = float(incapacitated + hanging) / float(alive);
    float averageHealth = effective > 0 ? float(healthTotal) / float(effective) : 0.0;
    float mapFlow = GetFeatureStatus(FeatureType_Native, "L4D2Direct_GetMapMaxFlowDistance") == FeatureStatus_Available ? L4D2Direct_GetMapMaxFlowDistance() : 0.0;
    float spreadRatio = mapFlow > 0.0 ? (maximumFlow - minimumFlow) / mapFlow : 1.0;
    float now = GetGameTime();
    int profile = PROFILE_NORMAL;
    if (now < g_fExternalRecoveryUntil || incapacitated >= 2 || badRatio >= 0.35 || effective <= 2)
    {
        profile = PROFILE_RECOVERY;
    }
    else if (!tankAlive && incapacitated == 0 && hanging == 0 && controlled == 0 && alive >= 4
        && averageHealth >= g_cvPressureHealth.FloatValue && spreadRatio <= g_cvPressureSpread.FloatValue
        && (g_fLastSurvivorDamage <= 0.0 || now - g_fLastSurvivorDamage >= 8.0) && CountRecentSIKills(30.0) >= 4)
    {
        profile = PROFILE_PRESSURE;
    }

    int target = GetBaseTarget(alive);
    target += profile == PROFILE_RECOVERY ? -g_cvRecoveryReduction.IntValue : (profile == PROFILE_PRESSURE ? g_cvPressureBonus.IntValue : 0);
    target = ClampInt(target, 1, g_cvHardCap.IntValue);
    int capacity = CalculateSICapacity();
    g_cvSlotCapacity.SetInt(capacity);
    target = target > capacity ? capacity : target;
    target = target < 0 ? 0 : target;

    float spawnMin = profile == PROFILE_RECOVERY ? g_cvRecoveryMin.FloatValue : (profile == PROFILE_PRESSURE ? g_cvPressureMin.FloatValue : g_cvNormalMin.FloatValue);
    float spawnMax = profile == PROFILE_RECOVERY ? g_cvRecoveryMax.FloatValue : (profile == PROFILE_PRESSURE ? g_cvPressureMax.FloatValue : g_cvNormalMax.FloatValue);
    int weights[6];
    for (int index = 0; index < 6; index++)
    {
        weights[index] = g_cvWeights[profile][index].IntValue;
    }
    L4DInfectedBots_SetDynamicPolicy(target, spawnMin, spawnMax, weights[0], weights[1], weights[2], weights[3], weights[4], weights[5]);
    UpdateStatus(profile, target, spawnMin, spawnMax, alive, effective, capacity);
}

void CollectTeamState(int &alive, int &incapacitated, int &hanging, int &controlled, int &healthTotal,
    bool &tankAlive, float &minimumFlow, float &maximumFlow)
{
    minimumFlow = 999999.0;
    maximumFlow = 0.0;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || !IsPlayerAlive(client))
        {
            continue;
        }
        int team = GetClientTeam(client);
        if (team == TEAM_INFECTED)
        {
            tankAlive = tankAlive || GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK;
            continue;
        }
        if (team != TEAM_SURVIVOR)
        {
            continue;
        }
        alive++;
        bool isIncapacitated = GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) != 0;
        bool isHanging = GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) != 0;
        bool isControlled = IsControlled(client);
        incapacitated += isIncapacitated ? 1 : 0;
        hanging += isHanging ? 1 : 0;
        controlled += isControlled ? 1 : 0;
        if (!isIncapacitated && !isHanging && !isControlled)
        {
            healthTotal += GetClientHealth(client);
        }
        if (GetFeatureStatus(FeatureType_Native, "L4D2Direct_GetFlowDistance") == FeatureStatus_Available)
        {
            float flow = L4D2Direct_GetFlowDistance(client);
            minimumFlow = flow < minimumFlow ? flow : minimumFlow;
            maximumFlow = flow > maximumFlow ? flow : maximumFlow;
        }
    }
    minimumFlow = minimumFlow == 999999.0 ? 0.0 : minimumFlow;
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

int GetBaseTarget(int survivors)
{
    if (survivors <= 4) return g_cvTargetSmall.IntValue;
    if (survivors <= 8) return g_cvTargetMedium.IntValue;
    if (survivors <= 12) return g_cvTargetLarge.IntValue;
    return g_cvTargetFull.IntValue;
}

int CalculateSICapacity()
{
    int nonSpecialClients;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientConnected(client))
        {
            continue;
        }
        bool countedBySITarget;
        if (IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED && HasEntProp(client, Prop_Send, "m_zombieClass"))
        {
            int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
            countedBySITarget = zombieClass >= 1 && zombieClass <= 6;
        }
        if (!countedBySITarget)
        {
            nonSpecialClients++;
        }
    }
    int reserved = g_cvReservedSlots == null ? 1 : g_cvReservedSlots.IntValue;
    int capacity = MaxClients - nonSpecialClients - reserved - g_cvHeadroom.IntValue;
    return capacity > 0 ? capacity : 0;
}

int CountRecentSIKills(float window)
{
    int count;
    float cutoff = GetGameTime() - window;
    for (int index = 0; index < SI_KILL_HISTORY; index++)
    {
        count += g_fSIKillTimes[index] >= cutoff ? 1 : 0;
    }
    return count;
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

void UpdateStatus(int profile, int target, float spawnMin, float spawnMax, int alive, int effective, int capacity)
{
    static const char names[][] = {"RECOVERY", "NORMAL", "PRESSURE"};
    g_cvProfile.SetString(names[profile]);
    g_cvTarget.SetInt(target);
    if (profile != g_iCurrentProfile || target != g_iLastTarget || spawnMin != g_fLastMin || spawnMax != g_fLastMax)
    {
        LogMessage("profile=%s target=%d interval=%.1f-%.1f survivors=%d effective=%d slot_capacity=%d external=%s",
            names[profile], target, spawnMin, spawnMax, alive, effective, capacity,
            g_sExternalRecoveryReason[0] == '\0' ? "none" : g_sExternalRecoveryReason);
    }
    g_iCurrentProfile = profile;
    g_iLastTarget = target;
    g_fLastMin = spawnMin;
    g_fLastMax = spawnMax;
    if (GetGameTime() >= g_fExternalRecoveryUntil)
    {
        g_sExternalRecoveryReason[0] = '\0';
    }
}

int ClampInt(int value, int minimum, int maximum)
{
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
}
