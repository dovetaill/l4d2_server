/* Public source: fbef0102 commit e0fd18072b82498ed98535329f8b581262a8ff19. */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define TEAM_INFECTED 3
#define ZC_JOCKEY 5

public Plugin myinfo =
{
    name = "Jockey Ride Team Switch Teleport Fix",
    author = "HarryPotter",
    description = "Stops a ridden Survivor from being teleported when the human Jockey changes team.",
    version = "1.0",
    url = "https://github.com/fbef0102/L4D1_2-Plugins"
};

public void OnPluginStart()
{
    HookEvent("player_bot_replace", Event_BotReplacePlayer);
}

public void Event_BotReplacePlayer(Event event, const char[] name, bool dontBroadcast)
{
    int player = GetClientOfUserId(event.GetInt("player"));
    if (player > 0 && IsClientInGame(player) && !IsFakeClient(player)
        && GetClientTeam(player) == TEAM_INFECTED && IsPlayerAlive(player)
        && GetEntProp(player, Prop_Send, "m_zombieClass") == ZC_JOCKEY)
    {
        ForcePlayerSuicide(player);
    }
}
