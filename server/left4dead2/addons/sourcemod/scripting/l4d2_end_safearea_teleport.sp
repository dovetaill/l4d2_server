#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#define TEAM_SURVIVOR 2

public Plugin myinfo =
{
    name = "L4D2 PvE Safearea Owner",
    author = "Codex",
    description = "Owns the random start-door opener, final team gate, and grace teleport.",
    version = "1.1.0",
    url = ""
};

ConVar g_hEnable;
ConVar g_hDelay;
ConVar g_hFinale;
ConVar g_hOpenerEnable;
ConVar g_hOpenerTimeout;
ConVar g_hFinalGateEnable;
ConVar g_hFinalGateRatio;
ConVar g_hFinalGateNearDistance;
ConVar g_hOpenerName;
ConVar g_hGateStatus;
Handle g_hTimer = null;
Handle g_hDoorTimer = null;
bool g_bActive;
bool g_bStartDoorUnlocked;
int g_iRemaining;
int g_iOpener;
int g_iStartDoorRef = INVALID_ENT_REFERENCE;
int g_iEndDoorRef = INVALID_ENT_REFERENCE;
float g_fOpenerDeadline;
float g_fNextBlockedNotice[MAXPLAYERS + 1];
float g_fDestination[3];

public void OnPluginStart()
{
    g_hEnable = CreateConVar("l4d2_end_safearea_enable", "1", "Enable end safearea grace teleport.", _, true, 0.0, true, 1.0);
    g_hDelay = CreateConVar("l4d2_end_safearea_delay", "60", "Seconds before living lagging survivors are teleported.", _, true, 5.0, true, 300.0);
    g_hFinale = CreateConVar("l4d2_end_safearea_finale", "1", "Also apply the grace teleport to finale rescue areas.", _, true, 0.0, true, 1.0);
    g_hOpenerEnable = CreateConVar("l4d2_safearea_opener_enable", "1", "Require one random real Survivor for the first start-door opening.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hOpenerTimeout = CreateConVar("l4d2_safearea_opener_timeout", "120.0", "Seconds before the chapter start door automatically unlocks.", FCVAR_NOTIFY, true, 30.0, true, 300.0);
    g_hFinalGateEnable = CreateConVar("l4d2_safearea_final_gate_enable", "1", "Require the living Survivor team ratio near the final safe area.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hFinalGateRatio = CreateConVar("l4d2_safearea_final_gate_ratio", "0.70", "Living Survivor ratio required near or inside the final safe area.", FCVAR_NOTIFY, true, 0.50, true, 1.0);
    g_hFinalGateNearDistance = CreateConVar("l4d2_safearea_final_gate_near_distance", "600.0", "Distance from the final checkpoint door counted by the team gate.", FCVAR_NOTIFY, true, 200.0, true, 1500.0);
    g_hOpenerName = CreateConVar("l4d2_safearea_opener_name", "NONE", "Current chapter start-door opener.", FCVAR_NOTIFY);
    g_hGateStatus = CreateConVar("l4d2_safearea_gate_status", "IDLE", "Current safearea gate state.", FCVAR_NOTIFY);
    CreateConVar("l4d2_safearea_owner_version", "1.1.0", "Safearea Owner version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);

    RegAdminCmd("sm_pvedoor_reroll", Command_Reroll, ADMFLAG_GENERIC, "Reroll the current chapter start-door opener.");
    RegAdminCmd("sm_pvedoor_unlock", Command_Unlock, ADMFLAG_GENERIC, "Unlock the current chapter start door.");
    RegAdminCmd("sm_pvedoor_status", Command_Status, ADMFLAG_GENERIC, "Show safearea opener and final gate status.");
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_Reset, EventHookMode_PostNoCopy);
    HookEvent("map_transition", Event_Reset, EventHookMode_PostNoCopy);
    HookEvent("mission_lost", Event_Reset, EventHookMode_PostNoCopy);
    HookEvent("finale_win", Event_Reset, EventHookMode_PostNoCopy);
    HookEvent("player_death", Event_PlayerStateChanged, EventHookMode_Post);
    HookEvent("player_team", Event_PlayerStateChanged, EventHookMode_Post);
    HookEvent("player_entered_checkpoint", Event_EnteredCheckpoint, EventHookMode_Post);
    AutoExecConfig(true, "l4d2_end_safearea_teleport");
}

public void OnMapStart()
{
    StopGraceTimer();
    ResetDoorPolicy();
    CreateTimer(1.0, Timer_InitializeDoors, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
    StopGraceTimer();
    StopDoorTimer();
    ResetDoorPolicy();
}

public void OnClientPutInServer(int client)
{
    if (!IsFakeClient(client))
    {
        RefreshDoorTimer();
        RequestFrame(Frame_RefreshDoorPolicy);
    }
}

public void OnClientDisconnect(int client)
{
    if (!IsFakeClient(client))
    {
        if (client == g_iOpener)
        {
            g_iOpener = 0;
        }
        RequestFrame(Frame_RefreshDoorPolicy);
    }
}

public void Frame_RefreshDoorPolicy(any data)
{
    EnsureDoorPolicy();
    RefreshDoorTimer();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    StopGraceTimer();
    ResetDoorPolicy();
    CreateTimer(1.0, Timer_InitializeDoors, _, TIMER_FLAG_NO_MAPCHANGE);
    RefreshDoorTimer();
}

public void Event_PlayerStateChanged(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client == g_iOpener)
    {
        g_iOpener = 0;
        RequestFrame(Frame_RefreshDoorPolicy);
    }
}

public Action Timer_InitializeDoors(Handle timer)
{
    EnsureDoorPolicy();
    RefreshDoorTimer();
    return Plugin_Stop;
}

public Action Timer_DoorPolicy(Handle timer)
{
    if (CountHumans() == 0)
    {
        g_hDoorTimer = null;
        return Plugin_Stop;
    }

    EnsureDoorPolicy();
    if (g_hOpenerEnable.BoolValue && !g_bStartDoorUnlocked)
    {
        if (!IsEligibleOpener(g_iOpener))
        {
            SelectOpener();
        }
        else if (GetGameTime() >= g_fOpenerDeadline)
        {
            UnlockStartDoor("TIMEOUT");
            PrintToChatAll("\x04[PVE]\x01 开门员等待超时，起始安全门已自动解锁。");
        }
    }
    return Plugin_Continue;
}

public Action OnStartDoorUse(int entity, int activator, int caller, UseType type, float value)
{
    if (!g_hOpenerEnable.BoolValue || g_bStartDoorUnlocked)
    {
        return Plugin_Continue;
    }
    if (!IsEligibleOpener(g_iOpener))
    {
        SelectOpener();
    }
    if (g_iOpener == 0)
    {
        UnlockStartDoor("NO_CANDIDATE");
        return Plugin_Continue;
    }
    if (activator == g_iOpener)
    {
        UnlockStartDoor("OPENED");
        PrintToChatAll("\x04[PVE]\x01 本章开门员 %N 已开启起始安全门。", activator);
        return Plugin_Continue;
    }
    if (activator > 0 && activator <= MaxClients && IsClientInGame(activator)
        && GetGameTime() >= g_fNextBlockedNotice[activator])
    {
        PrintHintText(activator, "本章起始安全门由 %N 首次开启", g_iOpener);
        g_fNextBlockedNotice[activator] = GetGameTime() + 2.0;
    }
    return Plugin_Handled;
}

public Action OnEndDoorUse(int entity, int activator, int caller, UseType type, float value)
{
    if (!g_hFinalGateEnable.BoolValue || L4D_IsFinaleEscapeInProgress())
    {
        g_hGateStatus.SetString("BYPASS");
        return Plugin_Continue;
    }
    if (activator < 1 || activator > MaxClients || !IsClientInGame(activator)
        || GetClientTeam(activator) != TEAM_SURVIVOR)
    {
        return Plugin_Continue;
    }

    int total;
    int ready;
    CountFinalGateSurvivors(entity, total, ready);
    int required = RoundToCeil(float(total) * g_hFinalGateRatio.FloatValue);
    if (total <= 0 || ready >= required)
    {
        g_hGateStatus.SetString("PASS");
        return Plugin_Continue;
    }

    char status[32];
    Format(status, sizeof(status), "WAIT_%d_OF_%d", ready, required);
    g_hGateStatus.SetString(status);
    if (GetGameTime() >= g_fNextBlockedNotice[activator])
    {
        PrintHintText(activator, "最终安全区需要 %d/%d 名存活 Survivor 到位（当前 %d）", required, total, ready);
        g_fNextBlockedNotice[activator] = GetGameTime() + 2.0;
    }
    return Plugin_Handled;
}

public Action Command_Reroll(int client, int args)
{
    g_bStartDoorUnlocked = false;
    SelectOpener();
    ReplyToCommand(client, "[PVE] 已重新抽取本章开门员。");
    return Plugin_Handled;
}

public Action Command_Unlock(int client, int args)
{
    UnlockStartDoor("ADMIN_UNLOCK");
    ReplyToCommand(client, "[PVE] 本章起始安全门限制已解除。");
    return Plugin_Handled;
}

public Action Command_Status(int client, int args)
{
    char opener[MAX_NAME_LENGTH] = "NONE";
    char gate[32];
    if (IsEligibleOpener(g_iOpener))
    {
        GetClientName(g_iOpener, opener, sizeof(opener));
    }
    g_hGateStatus.GetString(gate, sizeof(gate));
    ReplyToCommand(client, "[PVE/Safearea] opener=%s unlocked=%d timeout=%.0fs gate=%s ratio=%.0f%% near=%.0f",
        opener, g_bStartDoorUnlocked, g_hOpenerTimeout.FloatValue, gate,
        g_hFinalGateRatio.FloatValue * 100.0, g_hFinalGateNearDistance.FloatValue);
    return Plugin_Handled;
}

void EnsureDoorPolicy()
{
    int startDoor = EntRefToEntIndex(g_iStartDoorRef);
    if (startDoor == INVALID_ENT_REFERENCE || !IsValidEntity(startDoor))
    {
        startDoor = L4D_GetCheckpointFirst();
        if (startDoor > MaxClients && IsValidEntity(startDoor))
        {
            g_iStartDoorRef = EntIndexToEntRef(startDoor);
            SDKHook(startDoor, SDKHook_Use, OnStartDoorUse);
        }
    }

    int endDoor = EntRefToEntIndex(g_iEndDoorRef);
    if (endDoor == INVALID_ENT_REFERENCE || !IsValidEntity(endDoor))
    {
        endDoor = L4D_GetCheckpointLast();
        if (endDoor > MaxClients && IsValidEntity(endDoor) && endDoor != startDoor)
        {
            g_iEndDoorRef = EntIndexToEntRef(endDoor);
            SDKHook(endDoor, SDKHook_Use, OnEndDoorUse);
        }
    }

    if (g_hOpenerEnable.BoolValue && !g_bStartDoorUnlocked && !IsEligibleOpener(g_iOpener))
    {
        SelectOpener();
    }
}

void SelectOpener()
{
    int candidates[MAXPLAYERS];
    int count;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsEligibleOpener(client))
        {
            candidates[count++] = client;
        }
    }
    if (count == 0)
    {
        g_iOpener = 0;
        g_hOpenerName.SetString("WAITING");
        g_hGateStatus.SetString("WAITING_FOR_OPENER");
        return;
    }
    g_iOpener = candidates[GetRandomInt(0, count - 1)];
    g_fOpenerDeadline = GetGameTime() + g_hOpenerTimeout.FloatValue;
    char name[MAX_NAME_LENGTH];
    GetClientName(g_iOpener, name, sizeof(name));
    g_hOpenerName.SetString(name);
    g_hGateStatus.SetString("START_LOCKED");
    PrintToChatAll("\x04[PVE]\x01 本章随机开门员：%N。", g_iOpener);
}

void UnlockStartDoor(const char[] reason)
{
    g_bStartDoorUnlocked = true;
    g_iOpener = 0;
    g_hOpenerName.SetString("UNLOCKED");
    g_hGateStatus.SetString(reason);
}

void CountFinalGateSurvivors(int door, int &total, int &ready)
{
    float doorOrigin[3];
    GetEntPropVector(door, Prop_Send, "m_vecOrigin", doorOrigin);
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
        {
            continue;
        }
        total++;
        float origin[3];
        GetClientAbsOrigin(client, origin);
        if (IsSurvivorInEndArea(client) || GetVectorDistance(origin, doorOrigin) <= g_hFinalGateNearDistance.FloatValue)
        {
            ready++;
        }
    }
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
    StopDoorTimer();
    ResetDoorPolicy();
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

bool IsEligibleOpener(int client)
{
    return IsValidSurvivor(client) && IsPlayerAlive(client);
}

int CountHumans()
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

void RefreshDoorTimer()
{
    if (CountHumans() == 0)
    {
        StopDoorTimer();
        return;
    }
    if (g_hDoorTimer == null)
    {
        g_hDoorTimer = CreateTimer(1.0, Timer_DoorPolicy, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
}

void StopDoorTimer()
{
    if (g_hDoorTimer != null)
    {
        delete g_hDoorTimer;
        g_hDoorTimer = null;
    }
}

void ResetDoorPolicy()
{
    int door = EntRefToEntIndex(g_iStartDoorRef);
    if (door != INVALID_ENT_REFERENCE && IsValidEntity(door))
    {
        SDKUnhook(door, SDKHook_Use, OnStartDoorUse);
    }
    door = EntRefToEntIndex(g_iEndDoorRef);
    if (door != INVALID_ENT_REFERENCE && IsValidEntity(door))
    {
        SDKUnhook(door, SDKHook_Use, OnEndDoorUse);
    }
    g_iStartDoorRef = INVALID_ENT_REFERENCE;
    g_iEndDoorRef = INVALID_ENT_REFERENCE;
    g_iOpener = 0;
    g_bStartDoorUnlocked = false;
    g_fOpenerDeadline = 0.0;
    g_hOpenerName.SetString("NONE");
    g_hGateStatus.SetString("IDLE");
    for (int client = 1; client <= MaxClients; client++)
    {
        g_fNextBlockedNotice[client] = 0.0;
    }
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
