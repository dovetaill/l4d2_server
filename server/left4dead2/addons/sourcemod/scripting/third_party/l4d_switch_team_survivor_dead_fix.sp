/* Public source: fbef0102 commit e0fd18072b82498ed98535329f8b581262a8ff19. */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define TEAM_SURVIVOR 2
#define GOD_TIME 0.05

float g_fProtectDamageTime[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "[L4D2] Fix Team Switch Dead/Incap",
    author = "HarryPotter",
    description = "Prevents stale fall damage when an infected/spectator takes over a Survivor bot.",
    version = "1.0",
    url = "https://github.com/fbef0102/L4D1_2-Plugins"
};

public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("bot_player_replace", Event_BotPlayerReplace);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, SurvivorOnTakeDamage);
}

public Action SurvivorOnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType)
{
    if (g_fProtectDamageTime[victim] > GetEngineTime() && !IsFakeClient(victim)
        && GetClientTeam(victim) == TEAM_SURVIVOR && IsPlayerAlive(victim)
        && (damageType & DMG_FALL))
    {
        g_fProtectDamageTime[victim] = 0.0;
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
    int player = GetClientOfUserId(event.GetInt("player"));
    if (player > 0 && IsClientInGame(player) && !IsFakeClient(player)
        && GetClientTeam(player) == TEAM_SURVIVOR && IsPlayerAlive(player))
    {
        g_fProtectDamageTime[player] = GetEngineTime() + GOD_TIME;
    }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        g_fProtectDamageTime[client] = 0.0;
    }
}
