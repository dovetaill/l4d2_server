#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2

public Plugin myinfo =
{
    name = "L4D2 PvE Survivor Respawn",
    author = "Codex",
    description = "Revives a free bot and returns dead Survivor players after ten seconds.",
    version = "1.0.0",
    url = ""
};

ConVar g_cvEnabled;
ConVar g_cvDelay;
int g_iReservedBot[MAXPLAYERS + 1];

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar("l4d2_pve_respawn_enable", "1", "Enable ten-second Survivor respawn.", _, true, 0.0, true, 1.0);
    g_cvDelay = CreateConVar("l4d2_pve_respawn_delay", "10.0", "Seconds after death before returning to the Survivors.", _, true, 1.0, true, 60.0);
    HookEvent("player_death", Event_PlayerDeath);
    AutoExecConfig(true, "l4d2_pve_respawn");
}

public void OnClientDisconnect(int client)
{
    g_iReservedBot[client] = 0;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!g_cvEnabled.BoolValue || !IsValidHumanSurvivor(client))
    {
        return;
    }

    g_iReservedBot[client] = 0;
    PrintToChat(client, "\x04[复活]\x01 %d 秒后自动复活，期间会优先救起一名阵亡的队友 Bot。", RoundToNearest(g_cvDelay.FloatValue));
    CreateTimer(0.2, Timer_ReviveBot, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(g_cvDelay.FloatValue, Timer_ReturnPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ReviveBot(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!g_cvEnabled.BoolValue || !IsValidHumanSurvivor(client) || IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }

    int bot = FindFreeBot(false, client);
    if (bot > 0)
    {
        L4D_RespawnPlayer(bot);
        if (IsPlayerAlive(bot))
        {
            GiveOrdinaryWeapon(bot);
            g_iReservedBot[client] = GetClientUserId(bot);
        }
    }
    return Plugin_Stop;
}

public Action Timer_ReturnPlayer(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!g_cvEnabled.BoolValue || !IsValidHumanSurvivor(client) || IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }

    int bot = GetClientOfUserId(g_iReservedBot[client]);
    if (!IsFreeBot(bot, true) || IsReservedByAnotherPlayer(bot, client))
    {
        bot = FindFreeBot(true, client);
    }
    if (bot == 0)
    {
        bot = FindFreeBot(false, client);
        if (bot > 0)
        {
            L4D_RespawnPlayer(bot);
            if (IsPlayerAlive(bot))
            {
                GiveOrdinaryWeapon(bot);
            }
        }
    }

    g_iReservedBot[client] = 0;
    if (IsFreeBot(bot, true))
    {
        ChangeClientTeam(client, TEAM_SPECTATOR);
        if (L4D_SetHumanSpec(bot, client) && L4D_TakeOverBot(client))
        {
            PrintToChat(client, "\x04[复活]\x01 已接管幸存者 Bot，继续战斗！");
            return Plugin_Stop;
        }
        ChangeClientTeam(client, TEAM_SURVIVOR);
    }

    if (GetClientTeam(client) == TEAM_SURVIVOR)
    {
        L4D_RespawnPlayer(client);
        if (IsPlayerAlive(client))
        {
            GiveOrdinaryWeapon(client);
            PrintToChat(client, "\x04[复活]\x01 暂无可接管的 Bot，已直接复活。");
        }
    }
    return Plugin_Stop;
}

bool IsValidHumanSurvivor(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client)
        && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool IsFreeBot(int bot, bool alive)
{
    return bot > 0 && bot <= MaxClients && IsClientInGame(bot) && IsFakeClient(bot)
        && GetClientTeam(bot) == TEAM_SURVIVOR && IsPlayerAlive(bot) == alive
        && (!HasEntProp(bot, Prop_Send, "m_humanSpectatorUserID")
            || GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID")) == 0);
}

bool IsReservedByAnotherPlayer(int bot, int client)
{
    for (int player = 1; player <= MaxClients; player++)
    {
        if (player != client && g_iReservedBot[player] != 0 && GetClientOfUserId(g_iReservedBot[player]) == bot)
        {
            return true;
        }
    }
    return false;
}

int FindFreeBot(bool alive, int client)
{
    for (int bot = 1; bot <= MaxClients; bot++)
    {
        if (IsFreeBot(bot, alive) && !IsReservedByAnotherPlayer(bot, client))
        {
            return bot;
        }
    }
    return 0;
}

void GiveOrdinaryWeapon(int client)
{
    static const char weapons[][] = {
        "weapon_smg", "weapon_smg_silenced", "weapon_pumpshotgun", "weapon_shotgun_chrome",
        "weapon_autoshotgun", "weapon_rifle", "weapon_rifle_ak47", "weapon_sniper_military"
    };
    int primary = GetPlayerWeaponSlot(client, 0);
    if (primary > MaxClients && IsValidEntity(primary))
    {
        RemovePlayerItem(client, primary);
        AcceptEntityInput(primary, "Kill");
    }
    GivePlayerItem(client, weapons[GetRandomInt(0, sizeof(weapons) - 1)]);
}
