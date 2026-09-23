#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <weaponhandling>

#define PLUGIN_VERSION "1.0.0"
#define TEAM_SURVIVOR 2

ConVar g_cvEnabled;
ConVar g_cvDuration;
ConVar g_cvCooldown;
ConVar g_cvFire;
ConVar g_cvReload;
ConVar g_cvDeploy;
ConVar g_cvMelee;
ConVar g_cvItem;

bool g_bActive[MAXPLAYERS + 1];
float g_fCooldownUntil[MAXPLAYERS + 1];
Handle g_hEndTimer[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "L4D2 PvE Overdrive",
    author = "Codex",
    description = "Campaign-scoped temporary WeaponHandling multipliers.",
    version = PLUGIN_VERSION,
    url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
    RegPluginLibrary("l4d2_pve_overdrive");
    CreateNative("L4D2PveOverdrive_IsAvailable", Native_IsAvailable);
    CreateNative("L4D2PveOverdrive_Activate", Native_Activate);
    CreateNative("L4D2PveOverdrive_IsActive", Native_IsActive);
    CreateNative("L4D2PveOverdrive_GetCooldownRemaining", Native_GetCooldownRemaining);
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar("l4d2_pve_overdrive_enable", "1", "Enable temporary Overdrive purchases.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvDuration = CreateConVar("l4d2_pve_overdrive_duration", "15.0", "Overdrive duration in seconds.", FCVAR_NOTIFY, true, 1.0, true, 60.0);
    g_cvCooldown = CreateConVar("l4d2_pve_overdrive_cooldown", "75.0", "Overdrive cooldown in seconds from activation.", FCVAR_NOTIFY, true, 1.0, true, 600.0);
    g_cvFire = CreateConVar("l4d2_pve_overdrive_fire", "1.12", "WeaponHandling fire-rate multiplier while active.", FCVAR_NOTIFY, true, 1.0, true, 2.0);
    g_cvReload = CreateConVar("l4d2_pve_overdrive_reload", "1.15", "WeaponHandling reload multiplier while active.", FCVAR_NOTIFY, true, 1.0, true, 2.0);
    g_cvDeploy = CreateConVar("l4d2_pve_overdrive_deploy", "1.10", "WeaponHandling deploy multiplier while active.", FCVAR_NOTIFY, true, 1.0, true, 2.0);
    g_cvMelee = CreateConVar("l4d2_pve_overdrive_melee", "1.08", "WeaponHandling melee multiplier while active.", FCVAR_NOTIFY, true, 1.0, true, 2.0);
    g_cvItem = CreateConVar("l4d2_pve_overdrive_item", "1.05", "WeaponHandling item and throwable multiplier while active.", FCVAR_NOTIFY, true, 1.0, true, 2.0);

    RegConsoleCmd("sm_overdrive", Command_Status, "Show Overdrive state and cooldown.");
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("finale_win", Event_RoundEnd, EventHookMode_PostNoCopy);
    AutoExecConfig(true, "l4d2_pve_overdrive");
}

public void OnPluginEnd()
{
    ResetAll();
}

public void OnMapStart()
{
    ResetAll();
}

public void OnMapEnd()
{
    ResetAll();
}

public void OnClientDisconnect(int client)
{
    ResetClient(client, true);
}

public any Native_IsAvailable(Handle plugin, int numParams)
{
    return g_cvEnabled.BoolValue && LibraryExists("WeaponHandling");
}

public any Native_Activate(Handle plugin, int numParams)
{
    return ActivateOverdrive(GetNativeCell(1));
}

public any Native_IsActive(Handle plugin, int numParams)
{
    return IsOverdriveActive(GetNativeCell(1));
}

public any Native_GetCooldownRemaining(Handle plugin, int numParams)
{
    return view_as<int>(GetCooldownRemaining(GetNativeCell(1)));
}

public Action Command_Status(int client, int args)
{
    if (!IsRealSurvivor(client))
    {
        ReplyToCommand(client, "[火力强化] 仅真人幸存者可以使用。");
        return Plugin_Handled;
    }

    float cooldown = GetCooldownRemaining(client);
    ReplyToCommand(client, "[火力强化] %s，剩余冷却 %.1f 秒。", IsOverdriveActive(client) ? "正在生效" : "可使用", cooldown);
    return Plugin_Handled;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0)
    {
        ResetClient(client, false);
    }
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && event.GetInt("team") != TEAM_SURVIVOR)
    {
        ResetClient(client, false);
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    ResetAll();
}

public Action Timer_EndOverdrive(Handle timer, int serial)
{
    int client = GetClientFromSerial(serial);
    if (client > 0 && g_hEndTimer[client] == timer)
    {
        g_hEndTimer[client] = null;
        g_bActive[client] = false;
        PrintToChat(client, "\x04[Overdrive]\x01 强化已结束。");
    }
    return Plugin_Stop;
}

public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier)
{
    if (IsOverdriveActive(client))
    {
        speedmodifier *= g_cvMelee.FloatValue;
    }
}

public void WH_OnStartThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
    if (IsOverdriveActive(client))
    {
        speedmodifier *= g_cvItem.FloatValue;
    }
}

public void WH_OnReadyingThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
    if (IsOverdriveActive(client))
    {
        speedmodifier *= g_cvItem.FloatValue;
    }
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
    if (IsOverdriveActive(client))
    {
        speedmodifier *= g_cvReload.FloatValue;
    }
}

public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
    if (!IsOverdriveActive(client))
    {
        return;
    }
    speedmodifier *= IsItemType(weapontype) ? g_cvItem.FloatValue : g_cvFire.FloatValue;
}

public void WH_OnDeployModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
    if (IsOverdriveActive(client))
    {
        speedmodifier *= g_cvDeploy.FloatValue;
    }
}

bool ActivateOverdrive(int client)
{
    if (!g_cvEnabled.BoolValue || !LibraryExists("WeaponHandling") || !IsRealSurvivor(client)
        || !IsPlayerAlive(client) || g_bActive[client] || GetCooldownRemaining(client) > 0.0)
    {
        return false;
    }

    g_bActive[client] = true;
    g_fCooldownUntil[client] = GetGameTime() + g_cvCooldown.FloatValue;
    delete g_hEndTimer[client];
    g_hEndTimer[client] = CreateTimer(g_cvDuration.FloatValue, Timer_EndOverdrive, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
    PrintToChat(client, "\x04[Overdrive]\x01 已启动 %.0f 秒临时强化。", g_cvDuration.FloatValue);
    return true;
}

bool IsOverdriveActive(int client)
{
    return client > 0 && client <= MaxClients && g_bActive[client]
        && IsRealSurvivor(client) && IsPlayerAlive(client);
}

float GetCooldownRemaining(int client)
{
    if (client < 1 || client > MaxClients)
    {
        return 0.0;
    }
    float remaining = g_fCooldownUntil[client] - GetGameTime();
    return remaining > 0.0 ? remaining : 0.0;
}

void ResetClient(int client, bool resetCooldown)
{
    if (client < 1 || client > MaxClients)
    {
        return;
    }
    delete g_hEndTimer[client];
    g_hEndTimer[client] = null;
    g_bActive[client] = false;
    if (resetCooldown)
    {
        g_fCooldownUntil[client] = 0.0;
    }
}

void ResetAll()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        ResetClient(client, true);
    }
}

bool IsItemType(L4D2WeaponType weaponType)
{
    return weaponType == L4D2WeaponType_Molotov
        || weaponType == L4D2WeaponType_Pipebomb
        || weaponType == L4D2WeaponType_FirstAid
        || weaponType == L4D2WeaponType_Pills
        || weaponType == L4D2WeaponType_Vomitjar
        || weaponType == L4D2WeaponType_Adrenaline
        || weaponType == L4D2WeaponType_Defibrilator
        || weaponType == L4D2WeaponType_UpgradeFire
        || weaponType == L4D2WeaponType_UpgradeExplosive;
}

bool IsRealSurvivor(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client)
        && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}
