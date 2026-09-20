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
    description = "Shift+Reload cycles regular, incendiary and explosive ammo",
    version = "1.0.0",
    url = ""
};

ConVar g_hEnable;
ConVar g_hInfinite;
bool g_bCooldown[MAXPLAYERS + 1];

public void OnPluginStart()
{
    g_hEnable = CreateConVar("l4d2_switch_ammo_enable", "1", "Enable Shift+Reload upgrade ammo switching.", _, true, 0.0, true, 1.0);
    g_hInfinite = CreateConVar("l4d2_switch_ammo_infinite_load", "1", "Keep a large upgraded-ammo counter when switching.", _, true, 0.0, true, 1.0);
    AutoExecConfig(true, "l4d2_switch_ammo");
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
        SetEntProp(active, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", 999);
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

bool IsValidSurvivor(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}
