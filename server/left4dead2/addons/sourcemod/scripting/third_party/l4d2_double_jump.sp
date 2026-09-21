#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name = "L4D2 Double Jump",
    author = "Codex",
    description = "Allows human survivors one controlled mid-air jump.",
    version = "1.1.0",
    url = ""
};

ConVar gCvarEnabled;
ConVar gCvarCount;
ConVar gCvarBoost;
ConVar gCvarMaxVelocity;
int gJumps[MAXPLAYERS + 1];
bool gJumpHeld[MAXPLAYERS + 1];

public void OnPluginStart()
{
    gCvarEnabled = CreateConVar("l4d2_doublejump_enabled", "1", "Enable one extra survivor jump.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    gCvarCount = CreateConVar("l4d2_doublejump_count", "1", "Extra mid-air jumps per takeoff.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    gCvarBoost = CreateConVar("l4d2_doublejump_boost", "300.0", "Upward velocity added by the extra jump.", FCVAR_NOTIFY, true, 1.0, true, 500.0);
    gCvarMaxVelocity = CreateConVar("l4d2_doublejump_max_velocity", "450.0", "Maximum upward velocity after the extra jump.", FCVAR_NOTIFY, true, 1.0, true, 800.0);
    AutoExecConfig(true, "double_jump");

    HookEvent("player_spawn", Event_ResetPlayer);
    HookEvent("player_death", Event_ResetPlayer);
    HookEvent("round_start", Event_ResetRound);
    HookEvent("round_end", Event_ResetRound);

    for (int client = 1; client <= MaxClients; client++)
    {
        gJumpHeld[client] = false;
    }
}

public void OnClientDisconnect(int client)
{
    ResetPlayer(client);
}

public void Event_ResetPlayer(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    ResetPlayer(client);
}

public void Event_ResetRound(Event event, const char[] name, bool dontBroadcast)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        ResetPlayer(client);
    }
}

void ResetPlayer(int client)
{
    if (client < 1 || client > MaxClients)
    {
        return;
    }

    gJumps[client] = 0;
    gJumpHeld[client] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (!gCvarEnabled.BoolValue || !IsValidSurvivor(client) || !IsPlayerAlive(client))
    {
        return Plugin_Continue;
    }

    if (GetEntityMoveType(client) == MOVETYPE_NOCLIP || GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2)
    {
        ResetPlayer(client);
        return Plugin_Continue;
    }

    bool onGround = (GetEntityFlags(client) & FL_ONGROUND) != 0;
    bool pressingJump = (buttons & IN_JUMP) != 0;
    bool jumpPressed = pressingJump && !gJumpHeld[client];
    gJumpHeld[client] = pressingJump;

    if (onGround)
    {
        gJumps[client] = 0;
        return Plugin_Continue;
    }

    if (!jumpPressed || gJumps[client] >= gCvarCount.IntValue)
    {
        return Plugin_Continue;
    }

    float velocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
    if (velocity[2] < 0.0)
    {
        velocity[2] = 0.0;
    }
    velocity[2] += gCvarBoost.FloatValue;
    if (velocity[2] > gCvarMaxVelocity.FloatValue)
    {
        velocity[2] = gCvarMaxVelocity.FloatValue;
    }
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
    gJumps[client]++;

    return Plugin_Continue;
}

bool IsValidSurvivor(int client)
{
    return client >= 1 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && !IsFakeClient(client);
}
