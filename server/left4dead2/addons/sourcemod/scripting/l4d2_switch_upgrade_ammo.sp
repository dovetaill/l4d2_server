#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define TEAM_SURVIVOR 2
#define UPGRADE_INCENDIARY (1 << 0)
#define UPGRADE_EXPLOSIVE (1 << 1)

public Plugin myinfo =
{
    name = "L4D2 Switch Upgrade Ammo",
    author = "Codex",
    description = "Shift+Reload switching with continuous incendiary and explosive ammo",
    version = "1.1.0",
    url = ""
};

ConVar g_hEnable;
ConVar g_hInfinite;
ConVar g_hInfiniteUpgradeEnable;
ConVar g_hInfiniteUpgradeCount;
ConVar g_hInfiniteUpgradeInterval;

Handle g_hUpgradeAmmoTimer;
bool g_bCooldown[MAXPLAYERS + 1];

public void OnPluginStart()
{
    g_hEnable = CreateConVar("l4d2_switch_ammo_enable", "1", "Enable Shift+Reload upgrade ammo switching.", _, true, 0.0, true, 1.0);
    g_hInfinite = CreateConVar("l4d2_switch_ammo_infinite_load", "1", "Keep a large upgraded-ammo counter when switching.", _, true, 0.0, true, 1.0);
    g_hInfiniteUpgradeEnable = CreateConVar("l4d2_switch_ammo_infinite_upgrade_enable", "1", "Keep picked-up incendiary and explosive ammo replenished.", _, true, 0.0, true, 1.0);
    g_hInfiniteUpgradeCount = CreateConVar("l4d2_switch_ammo_infinite_upgrade_count", "999", "Special ammo count to restore for incendiary and explosive weapons.", _, true, 1.0, true, 9999.0);
    g_hInfiniteUpgradeInterval = CreateConVar("l4d2_switch_ammo_infinite_upgrade_interval", "0.10", "Seconds between special ammo replenishment checks.", _, true, 0.05, true, 1.0);
    HookConVarChange(g_hEnable, ConVarChanged_AmmoFeature);
    HookConVarChange(g_hInfiniteUpgradeEnable, ConVarChanged_AmmoFeature);
    HookConVarChange(g_hInfiniteUpgradeInterval, ConVarChanged_AmmoInterval);
    AutoExecConfig(true, "l4d2_switch_ammo");
}

public void OnConfigsExecuted()
{
    RestartUpgradeAmmoTimer();
}

public void OnPluginEnd()
{
    StopUpgradeAmmoTimer();
}

public void OnClientDisconnect(int client)
{
    g_bCooldown[client] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (!g_hEnable.BoolValue || g_bCooldown[client] || !IsValidSurvivor(client) || !IsPlayerAlive(client))
    {
        return Plugin_Continue;
    }
    if (!(buttons & IN_RELOAD) || !(buttons & IN_SPEED))
    {
        return Plugin_Continue;
    }

    int active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (active <= MaxClients || !IsValidEntity(active) || !HasEntProp(active, Prop_Send, "m_upgradeBitVec"))
    {
        return Plugin_Continue;
    }

    int upgrades = GetEntProp(active, Prop_Send, "m_upgradeBitVec");
    int current = 0;
    if (upgrades & UPGRADE_INCENDIARY)
    {
        current = 1;
    }
    else if (upgrades & UPGRADE_EXPLOSIVE)
    {
        current = 2;
    }

    int next = (current + 1) % 3;
    upgrades &= ~(UPGRADE_INCENDIARY | UPGRADE_EXPLOSIVE);
    char label[32];
    if (next == 1)
    {
        upgrades |= UPGRADE_INCENDIARY;
        strcopy(label, sizeof(label), "Incendiary");
    }
    else if (next == 2)
    {
        upgrades |= UPGRADE_EXPLOSIVE;
        strcopy(label, sizeof(label), "Explosive");
    }
    else
    {
        strcopy(label, sizeof(label), "Regular");
    }

    SetEntProp(active, Prop_Send, "m_upgradeBitVec", upgrades);
    if (g_hInfinite.BoolValue && next != 0 && HasEntProp(active, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded"))
    {
        SetEntProp(active, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", g_hInfiniteUpgradeCount.IntValue);
    }
    PrintToChat(client, "\x04[AMMO]\x01 %s upgrade ammo selected.", label);
    g_bCooldown[client] = true;
    CreateTimer(0.35, Timer_ClearCooldown, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public Action Timer_ClearCooldown(Handle timer, int serial)
{
    int client = GetClientFromSerial(serial);
    if (client > 0)
    {
        g_bCooldown[client] = false;
    }
    return Plugin_Stop;
}

public void ConVarChanged_AmmoFeature(ConVar convar, const char[] oldValue, const char[] newValue)
{
    RestartUpgradeAmmoTimer();
}

public void ConVarChanged_AmmoInterval(ConVar convar, const char[] oldValue, const char[] newValue)
{
    RestartUpgradeAmmoTimer();
}

void RestartUpgradeAmmoTimer()
{
    StopUpgradeAmmoTimer();

    if (!g_hEnable.BoolValue || !g_hInfiniteUpgradeEnable.BoolValue)
    {
        return;
    }

    g_hUpgradeAmmoTimer = CreateTimer(g_hInfiniteUpgradeInterval.FloatValue, Timer_RefillUpgradeAmmo, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void StopUpgradeAmmoTimer()
{
    if (g_hUpgradeAmmoTimer != null)
    {
        delete g_hUpgradeAmmoTimer;
        g_hUpgradeAmmoTimer = null;
    }
}

public Action Timer_RefillUpgradeAmmo(Handle timer)
{
    if (!g_hEnable.BoolValue || !g_hInfiniteUpgradeEnable.BoolValue)
    {
        g_hUpgradeAmmoTimer = null;
        return Plugin_Stop;
    }

    int amount = g_hInfiniteUpgradeCount.IntValue;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidSurvivor(client) || !IsPlayerAlive(client))
        {
            continue;
        }

        RefillUpgradeAmmoInSlot(client, 0, amount);
        RefillUpgradeAmmoInSlot(client, 1, amount);
    }

    return Plugin_Continue;
}

void RefillUpgradeAmmoInSlot(int client, int slot, int amount)
{
    int weapon = GetPlayerWeaponSlot(client, slot);
    if (weapon <= MaxClients || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_upgradeBitVec") || !HasEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded"))
    {
        return;
    }

    int upgrades = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
    if (!(upgrades & (UPGRADE_INCENDIARY | UPGRADE_EXPLOSIVE)))
    {
        return;
    }

    if (GetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded") != amount)
    {
        SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", amount);
    }
}

bool IsValidSurvivor(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}
