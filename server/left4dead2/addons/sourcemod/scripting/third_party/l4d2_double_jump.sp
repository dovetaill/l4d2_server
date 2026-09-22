#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name = "L4D2 Double Jump",
    author = "Codex, adapted from mature same-tick double-jump implementations",
    description = "Allows human survivors one controlled mid-air jump without a deferred frame correction.",
    version = "1.2.0",
    url = ""
};

ConVar gCvarEnabled;
ConVar gCvarCount;
ConVar gCvarBoost;
ConVar gCvarMaxVelocity;
int gJumps[MAXPLAYERS + 1];
int gLastButtons[MAXPLAYERS + 1];

public void OnPluginStart()
{
    gCvarEnabled = CreateConVar(
        "l4d2_doublejump_enabled",
        "1",
        "Enable one extra survivor jump.",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );
    gCvarCount = CreateConVar(
        "l4d2_doublejump_count",
        "1",
        "Extra mid-air jumps per takeoff.",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );
    gCvarBoost = CreateConVar(
        "l4d2_doublejump_boost",
        "300.0",
        "Upward velocity after the extra jump.",
        FCVAR_NOTIFY,
        true,
        1.0,
        true,
        500.0
    );
    gCvarMaxVelocity = CreateConVar(
        "l4d2_doublejump_max_velocity",
        "450.0",
        "Maximum upward velocity after the extra jump.",
        FCVAR_NOTIFY,
        true,
        1.0,
        true,
        800.0
    );
    AutoExecConfig(true, "double_jump");

    HookEvent("player_spawn", Event_ResetPlayer);
    HookEvent("player_death", Event_ResetPlayer);
    HookEvent("round_start", Event_ResetRound);
    HookEvent("round_end", Event_ResetRound);

    for (int client = 1; client <= MaxClients; client++)
    {
        ResetPlayer(client);
    }
}

public void OnClientDisconnect(int client)
{
    ResetPlayer(client);
}

public void Event_ResetPlayer(Event event, const char[] name, bool dontBroadcast)
{
    ResetPlayer(GetClientOfUserId(event.GetInt("userid")));
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
    gLastButtons[client] = 0;
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
    if (!gCvarEnabled.BoolValue || !IsValidSurvivor(client) || !IsPlayerAlive(client))
    {
        return Plugin_Continue;
    }

    if (GetEntityMoveType(client) == MOVETYPE_NOCLIP
        || GetEntityMoveType(client) == MOVETYPE_LADDER
        || GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2)
    {
        ResetPlayer(client);
        gLastButtons[client] = buttons;
        return Plugin_Continue;
    }

    bool onGround = (GetEntityFlags(client) & FL_ONGROUND) != 0;
    bool jumpPressed = (buttons & IN_JUMP) != 0 && (gLastButtons[client] & IN_JUMP) == 0;

    if (onGround)
    {
        gJumps[client] = 0;
    }
    else if (jumpPressed && gJumps[client] < gCvarCount.IntValue)
    {
        ApplyExtraJump(client);
    }

    gLastButtons[client] = buttons;
    return Plugin_Continue;
}

void ApplyExtraJump(int client)
{
    float velocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);

    if (velocity[2] < gCvarBoost.FloatValue)
    {
        velocity[2] = gCvarBoost.FloatValue;
    }
    if (velocity[2] > gCvarMaxVelocity.FloatValue)
    {
        velocity[2] = gCvarMaxVelocity.FloatValue;
    }

    // Mature L4D2 jump plugins apply this directly in the input tick. The old
    // implementation used RequestFrame + TeleportEntity, which was visible as
    // a one-frame hitch on this server.
    SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
    gJumps[client]++;
}

bool IsValidSurvivor(int client)
{
    return client >= 1 && client <= MaxClients && IsClientInGame(client)
        && GetClientTeam(client) == 2 && !IsFakeClient(client);
}
