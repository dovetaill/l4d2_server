#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <sdktools>
#include <left4dhooks>

ConVar gCvarEnabled;
ConVar gCvarWeapons;
ConVar gCvarScarCycleTime;
ConVar gCvarScarBullets;
ConVar gCvarAwpCycleTime;

bool gEnabled = true;
char gAllowedWeapons[64][32];
int gAllowedWeaponsCount;
int gAllowedCache[MAXPLAYERS + 1];
int gActiveWeaponCache[MAXPLAYERS + 1];
float gScarCycleTime = 0.09;
float gAwpCycleTime = 0.09;
Handle gHGetRateOfFire;

public Plugin myinfo =
{
    name = "Automatic Weapons",
    author = "Timocop, Zakikun, Codex",
    description = "Allows configured weapons to fire while holding the attack button.",
    version = "1.4.0",
    url = ""
};

public void OnPluginStart()
{
    gCvarEnabled = CreateConVar(
        "l4d_autopistols_enabled",
        "1",
        "Enable automatic fire for configured weapons.",
        FCVAR_REPLICATED | FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );
    gCvarWeapons = CreateConVar(
        "l4d_autopistols_weapons",
        "weapon_pistol",
        "Configured weapon classnames separated by ';'.",
        FCVAR_REPLICATED | FCVAR_NOTIFY
    );
    gCvarScarCycleTime = CreateConVar(
        "l4d_autopistols_scar_cycle_time",
        "0.0",
        "SCAR automatic cycle time in seconds. 0 = match the server's SG552 CycleTime.",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );
    gCvarScarBullets = CreateConVar(
        "l4d_autopistols_scar_bullets",
        "3",
        "Number of simultaneous bullets fired by each SCAR full-auto shot.",
        FCVAR_NOTIFY,
        true,
        1.0,
        true,
        8.0
    );
    gCvarAwpCycleTime = CreateConVar(
        "l4d_autopistols_awp_cycle_time",
        "0.0",
        "AWP automatic cycle time in seconds. 0 = match the server's SG552 CycleTime.",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );

    gCvarEnabled.AddChangeHook(OnCvarChanged);
    gCvarWeapons.AddChangeHook(OnCvarChanged);
    gCvarScarCycleTime.AddChangeHook(OnCvarChanged);
    gCvarScarBullets.AddChangeHook(OnCvarChanged);
    gCvarAwpCycleTime.AddChangeHook(OnCvarChanged);

    AutoExecConfig(true, "l4d2_automatic_weapons");
    gEnabled = gCvarEnabled.BoolValue;
    RebuildWeaponList();
    RefreshWeaponTuning();

    GameData gameData = new GameData("l4d2_automatic_weapons");
    if (gameData == null)
    {
        SetFailState("Missing gamedata: l4d2_automatic_weapons.txt");
    }
    gHGetRateOfFire = DHookCreateFromConf(gameData, "CTerrorGun::GetRateOfFire");
    delete gameData;
    if (gHGetRateOfFire == null || !DHookEnableDetour(gHGetRateOfFire, false, DetourGetRateOfFire))
    {
        SetFailState("Failed to hook CTerrorGun::GetRateOfFire");
    }
}

public void OnConfigsExecuted()
{
    RefreshWeaponTuning();
}

public void OnPluginEnd()
{
    if (gHGetRateOfFire != null)
    {
        DHookDisableDetour(gHGetRateOfFire, false, DetourGetRateOfFire);
        delete gHGetRateOfFire;
    }
}

public void OnClientDisconnect(int client)
{
    gAllowedCache[client] = 0;
    gActiveWeaponCache[client] = -1;
}

public void OnCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == gCvarEnabled)
    {
        gEnabled = gCvarEnabled.BoolValue;
    }
    else if (convar == gCvarWeapons)
    {
        RebuildWeaponList();
    }
    else if (convar == gCvarScarCycleTime || convar == gCvarScarBullets || convar == gCvarAwpCycleTime)
    {
        RefreshWeaponTuning();
    }
}

void RebuildWeaponList()
{
    char value[256];
    gCvarWeapons.GetString(value, sizeof(value));
    gAllowedWeaponsCount = ExplodeString(value, ";", gAllowedWeapons, sizeof(gAllowedWeapons), sizeof(gAllowedWeapons[]));

    for (int i = 0; i < gAllowedWeaponsCount; i++)
    {
        TrimString(gAllowedWeapons[i]);
    }

    for (int client = 1; client <= MaxClients; client++)
    {
        gAllowedCache[client] = 0;
        gActiveWeaponCache[client] = -1;
    }
}

void RefreshWeaponTuning()
{
    float sg552Cycle = 0.09;
    if (GetFeatureStatus(FeatureType_Native, "L4D2_GetFloatWeaponAttribute") == FeatureStatus_Available)
    {
        float detectedCycle = L4D2_GetFloatWeaponAttribute("weapon_rifle_sg552", L4D2FWA_CycleTime);
        if (detectedCycle > 0.0)
        {
            sg552Cycle = detectedCycle;
        }
    }

    gScarCycleTime = gCvarScarCycleTime.FloatValue > 0.0 ? gCvarScarCycleTime.FloatValue : sg552Cycle;
    gAwpCycleTime = gCvarAwpCycleTime.FloatValue > 0.0 ? gCvarAwpCycleTime.FloatValue : sg552Cycle;

    if (GetFeatureStatus(FeatureType_Native, "L4D2_SetIntWeaponAttribute") == FeatureStatus_Available)
    {
        L4D2_SetIntWeaponAttribute("weapon_rifle_desert", L4D2IWA_Bullets, gCvarScarBullets.IntValue);
    }
    if (GetFeatureStatus(FeatureType_Native, "L4D2_SetFloatWeaponAttribute") == FeatureStatus_Available)
    {
        L4D2_SetFloatWeaponAttribute("weapon_sniper_awp", L4D2FWA_CycleTime, gAwpCycleTime);
    }
}

MRESReturn DetourGetRateOfFire(int weapon, DHookReturn hReturn)
{
    if (weapon <= MaxClients || !IsValidEntity(weapon))
    {
        return MRES_Ignored;
    }

    char classname[32];
    GetEntityClassname(weapon, classname, sizeof(classname));
    if (!StrEqual(classname, "weapon_sniper_awp", false))
    {
        return MRES_Ignored;
    }

    DHookSetReturn(hReturn, gAwpCycleTime);
    return MRES_Supercede;
}

public Action OnPlayerRunCmd(
    int client,
    int &buttons,
    int &impulse,
    float vel[3],
    float angles[3],
    int &weapon
)
{
    if (!gEnabled || !(buttons & IN_ATTACK))
    {
        return Plugin_Continue;
    }

    if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client)
        || GetClientTeam(client) != 2 || IsMountedWeapon(client))
    {
        return Plugin_Continue;
    }

    int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (activeWeapon <= MaxClients || !IsValidEntity(activeWeapon))
    {
        return Plugin_Continue;
    }

    if (activeWeapon != gActiveWeaponCache[client])
    {
        gActiveWeaponCache[client] = activeWeapon;
        gAllowedCache[client] = 0;
    }

    if (!IsAllowedWeapon(client))
    {
        return Plugin_Continue;
    }

    if (GetEntProp(activeWeapon, Prop_Send, "m_bInReload") > 0)
    {
        return Plugin_Continue;
    }

    char classname[32];
    GetEntityClassname(activeWeapon, classname, sizeof(classname));
    bool isScar = StrEqual(classname, "weapon_rifle_desert", false);
    bool isAwp = StrEqual(classname, "weapon_sniper_awp", false);

    // The original automatic-weapons plugin only clears the holding-fire flag.
    // SCAR still waits for its burst cooldown, so match the real SG552 cycle on
    // the same input frame instead of scheduling a correction for a later frame.
    if (isScar)
    {
        ApplyScarCycle(client, activeWeapon);
        SetEntProp(activeWeapon, Prop_Send, "m_isHoldingFireButton", 0);
        ChangeEdictState(activeWeapon, FindDataMapInfo(activeWeapon, "m_isHoldingFireButton"));
    }
    else if (isAwp)
    {
        ApplyAutomaticCycle(client, activeWeapon, gAwpCycleTime, true);
        SetEntProp(activeWeapon, Prop_Send, "m_isHoldingFireButton", 0);
        int offset = FindDataMapInfo(activeWeapon, "m_isHoldingFireButton");
        if (offset >= 0)
        {
            ChangeEdictState(activeWeapon, offset);
        }
    }

    if (!isAwp && GetEntPropFloat(activeWeapon, Prop_Send, "m_flCycle") > 0.0)
    {
        return Plugin_Continue;
    }

    if (!HasEntProp(activeWeapon, Prop_Send, "m_isHoldingFireButton"))
    {
        return Plugin_Continue;
    }

    SetEntProp(activeWeapon, Prop_Send, "m_isHoldingFireButton", 0);
    int offset = FindDataMapInfo(activeWeapon, "m_isHoldingFireButton");
    if (offset >= 0)
    {
        ChangeEdictState(activeWeapon, offset);
    }

    return Plugin_Continue;
}

void ApplyScarCycle(int client, int activeWeapon)
{
    ApplyAutomaticCycle(client, activeWeapon, gScarCycleTime, false);
}

void ApplyAutomaticCycle(int client, int activeWeapon, float cycleTime, bool clearWeaponCycle)
{
    if (clearWeaponCycle && HasEntProp(activeWeapon, Prop_Send, "m_flCycle"))
    {
        SetEntPropFloat(activeWeapon, Prop_Send, "m_flCycle", 0.0);
    }

    float desired = GetGameTime() + cycleTime;
    float nextPrimary = GetEntPropFloat(activeWeapon, Prop_Send, "m_flNextPrimaryAttack");
    if (nextPrimary > desired)
    {
        SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextPrimaryAttack", desired);
    }

    if (HasEntProp(activeWeapon, Prop_Send, "m_flNextSecondaryAttack"))
    {
        float nextSecondary = GetEntPropFloat(activeWeapon, Prop_Send, "m_flNextSecondaryAttack");
        if (nextSecondary > desired)
        {
            SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextSecondaryAttack", desired);
        }
    }

    if (HasEntProp(client, Prop_Send, "m_flNextAttack"))
    {
        float nextAttack = GetEntPropFloat(client, Prop_Send, "m_flNextAttack");
        if (nextAttack > desired)
        {
            SetEntPropFloat(client, Prop_Send, "m_flNextAttack", desired);
        }
    }
}

bool IsMountedWeapon(int client)
{
    return GetEntProp(client, Prop_Send, "m_usingMountedGun") > 0
        || GetEntProp(client, Prop_Send, "m_usingMountedWeapon") > 0;
}

bool IsAllowedWeapon(int client)
{
    if (gAllowedCache[client] == 1)
    {
        return true;
    }
    if (gAllowedCache[client] == 2)
    {
        return false;
    }

    char currentWeapon[32];
    GetClientWeapon(client, currentWeapon, sizeof(currentWeapon));
    for (int i = 0; i < gAllowedWeaponsCount; i++)
    {
        if (StrEqual(gAllowedWeapons[i], currentWeapon, false))
        {
            gAllowedCache[client] = 1;
            return true;
        }
    }

    gAllowedCache[client] = 2;
    return false;
}
