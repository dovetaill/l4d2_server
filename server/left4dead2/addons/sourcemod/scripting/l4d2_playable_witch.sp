#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2_playable_witch>

#define PLUGIN_VERSION "1.0.0"
#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_SMOKER 1

public Plugin myinfo =
{
    name = "L4D2 Playable Witch",
    author = "Codex",
    description = "Remote control for real Witch entities with camera, movement, attack, jump and rage.",
    version = PLUGIN_VERSION,
    url = ""
};

ConVar g_cvEnabled;
ConVar g_cvMaxPlayers;
ConVar g_cvHealth;
ConVar g_cvMoveSpeed;
ConVar g_cvJumpVelocity;
ConVar g_cvAttackDamage;
ConVar g_cvAttackRange;
ConVar g_cvAttackCooldown;
ConVar g_cvRageSpeed;
ConVar g_cvRageDuration;
ConVar g_cvRageCooldown;
ConVar g_cvRandomChance;

int g_iWitch[MAXPLAYERS + 1];
int g_iCamera[MAXPLAYERS + 1];
int g_iLastButtons[MAXPLAYERS + 1];
PlayableWitchSource g_iSource[MAXPLAYERS + 1];
float g_fNextAttack[MAXPLAYERS + 1];
float g_fNextRage[MAXPLAYERS + 1];
float g_fRageUntil[MAXPLAYERS + 1];
bool g_bRandomAttempted[MAXPLAYERS + 1];
bool g_bCleaning[MAXPLAYERS + 1];
StringMap g_hChapterPurchases;
Handle g_hHudTimer;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
    RegPluginLibrary("l4d2_playable_witch");
    CreateNative("L4D2PlayableWitch_IsAvailable", Native_IsAvailable);
    CreateNative("L4D2PlayableWitch_Request", Native_Request);
    CreateNative("L4D2PlayableWitch_IsControlling", Native_IsControlling);
    CreateNative("L4D2PlayableWitch_GetEntity", Native_GetEntity);
    MarkNativeAsOptional("L4D2_SpawnWitch");
    MarkNativeAsOptional("L4D_ReplaceWithBot");
    MarkNativeAsOptional("L4D_CullZombie");
    MarkNativeAsOptional("L4D_SetClass");
    MarkNativeAsOptional("L4D_BecomeGhost");
    MarkNativeAsOptional("L4D_State_Transition");
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar("pve_playable_witch_enable", "1", "Enable the independent playable Witch module.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvMaxPlayers = CreateConVar("pve_playable_witch_max", "1", "Maximum simultaneous human-controlled Witch entities.", FCVAR_NOTIFY, true, 1.0, true, 1.0);
    g_cvHealth = CreateConVar("pve_playable_witch_health", "1600", "Health for a human-controlled Witch.", FCVAR_NOTIFY, true, 1.0);
    g_cvMoveSpeed = CreateConVar("pve_playable_witch_speed", "235.0", "Playable Witch movement speed.", FCVAR_NOTIFY, true, 80.0, true, 400.0);
    g_cvJumpVelocity = CreateConVar("pve_playable_witch_jump", "285.0", "Playable Witch jump velocity.", FCVAR_NOTIFY, true, 0.0, true, 500.0);
    g_cvAttackDamage = CreateConVar("pve_playable_witch_attack_damage", "35.0", "Mouse1 slash damage.", FCVAR_NOTIFY, true, 1.0, true, 100.0);
    g_cvAttackRange = CreateConVar("pve_playable_witch_attack_range", "92.0", "Mouse1 slash range.", FCVAR_NOTIFY, true, 40.0, true, 180.0);
    g_cvAttackCooldown = CreateConVar("pve_playable_witch_attack_cooldown", "0.85", "Mouse1 slash cooldown.", FCVAR_NOTIFY, true, 0.2, true, 4.0);
    g_cvRageSpeed = CreateConVar("pve_playable_witch_rage_speed", "1.30", "Mild E rage movement multiplier.", FCVAR_NOTIFY, true, 1.0, true, 1.75);
    g_cvRageDuration = CreateConVar("pve_playable_witch_rage_duration", "4.0", "Mild E rage duration.", FCVAR_NOTIFY, true, 0.1, true, 10.0);
    g_cvRageCooldown = CreateConVar("pve_playable_witch_rage_cooldown", "24.0", "Mild E rage cooldown.", FCVAR_NOTIFY, true, 1.0, true, 120.0);
    g_cvRandomChance = CreateConVar("pve_playable_witch_random_chance", "2.5", "Per-chapter random Witch chance for an infected Ghost.", FCVAR_NOTIFY, true, 0.0, true, 100.0);

    HookConVarChange(g_cvEnabled, ConVarChanged_Enabled);
    HookEvent("round_end", Event_Cleanup, EventHookMode_PostNoCopy);
    HookEvent("mission_lost", Event_Cleanup, EventHookMode_PostNoCopy);
    HookEvent("finale_win", Event_Cleanup, EventHookMode_PostNoCopy);
    HookEvent("finale_vehicle_leaving", Event_Cleanup, EventHookMode_PostNoCopy);
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
    HookEvent("ghost_spawn_time", Event_GhostSpawnTime, EventHookMode_Post);

    RegAdminCmd("sm_playablewitch", Command_PlayableWitch, ADMFLAG_SLAY, "sm_playablewitch <target>");
    RegAdminCmd("sm_pvewitch_validate", Command_Validate, ADMFLAG_CONFIG, "Validate playable Witch dependencies and state.");
    RegAdminCmd("sm_pvewitch_selftest", Command_SelfTest, ADMFLAG_CONFIG, "Spawn and remove a real Witch entity to validate the module.");
    g_hChapterPurchases = new StringMap();
    g_hHudTimer = CreateTimer(0.25, Timer_Hud, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    AutoExecConfig(true, "l4d2_playable_witch");
}

public void OnPluginEnd()
{
    CleanupAll(true, false, "plugin unload");
    delete g_hChapterPurchases;
    delete g_hHudTimer;
}

public void OnMapStart()
{
    g_hChapterPurchases.Clear();
    for (int client = 1; client <= MaxClients; client++)
    {
        g_bRandomAttempted[client] = false;
    }
}

public void OnMapEnd()
{
    CleanupAll(true, false, "map end");
}

public void OnClientDisconnect(int client)
{
    EndControl(client, true, false, "disconnect");
    g_bRandomAttempted[client] = false;
}

public void ConVarChanged_Enabled(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!g_cvEnabled.BoolValue)
    {
        CleanupAll(true, true, "module disabled");
    }
}

public any Native_IsAvailable(Handle plugin, int numParams)
{
    return IsModuleAvailable();
}

public any Native_Request(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    PlayableWitchSource source = view_as<PlayableWitchSource>(GetNativeCell(2));
    return BeginControl(client, source);
}

public any Native_IsControlling(Handle plugin, int numParams)
{
    return IsControlling(GetNativeCell(1));
}

public any Native_GetEntity(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return IsControlling(client) ? g_iWitch[client] : -1;
}

public Action Command_PlayableWitch(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[PVE] Usage: sm_playablewitch <target>");
        return Plugin_Handled;
    }

    char targetArg[MAX_TARGET_LENGTH], targetName[MAX_TARGET_LENGTH];
    int targets[MAXPLAYERS], targetCount;
    bool tnIsMl;
    GetCmdArg(1, targetArg, sizeof(targetArg));
    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS,
        targetName, sizeof(targetName), tnIsMl);
    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    for (int i = 0; i < targetCount; i++)
    {
        if (!BeginControl(targets[i], PlayableWitchSource_Admin))
        {
            ReplyToCommand(client, "[PVE] Could not start playable Witch control for %N.", targets[i]);
        }
    }
    return Plugin_Handled;
}

public Action Command_Validate(int client, int args)
{
    int active;
    for (int target = 1; target <= MaxClients; target++)
    {
        if (IsControlling(target))
        {
            active++;
        }
    }
    ReplyToCommand(client, "[PVE] Playable Witch: enabled=%d spawn_native=%d active=%d/%d real_entity_control=1 class7_player=0.",
        g_cvEnabled.BoolValue,
        GetFeatureStatus(FeatureType_Native, "L4D2_SpawnWitch") == FeatureStatus_Available,
        active, g_cvMaxPlayers.IntValue);
    return Plugin_Handled;
}

public Action Command_SelfTest(int client, int args)
{
    if (!IsModuleAvailable())
    {
        ReplyToCommand(client, "[PVE] Playable Witch self-test unavailable: module disabled or L4D2_SpawnWitch is unavailable.");
        return Plugin_Handled;
    }

    float position[3] = {0.0, 0.0, 0.0};
    float angles[3] = {0.0, 0.0, 0.0};
    if (IsRealClient(client))
    {
        GetClientAbsOrigin(client, position);
        GetClientEyeAngles(client, angles);
    }
    else
    {
        for (int target = 1; target <= MaxClients; target++)
        {
            if (IsClientInGame(target) && GetClientTeam(target) == TEAM_SURVIVOR && IsPlayerAlive(target))
            {
                GetClientAbsOrigin(target, position);
                GetClientEyeAngles(target, angles);
                break;
            }
        }
    }

    int witch = L4D2_SpawnWitch(position, angles);
    if (witch <= MaxClients || !IsValidEntity(witch))
    {
        ReplyToCommand(client, "[PVE] Playable Witch self-test failed: L4D2_SpawnWitch returned an invalid entity.");
        return Plugin_Handled;
    }

    if (HasEntProp(witch, Prop_Data, "m_iHealth"))
    {
        SetEntProp(witch, Prop_Data, "m_iHealth", g_cvHealth.IntValue);
    }
    CreateTimer(1.0, Timer_SelfTestCleanup, EntIndexToEntRef(witch), TIMER_FLAG_NO_MAPCHANGE);
    ReplyToCommand(client, "[PVE] Playable Witch self-test passed: real entity %d spawned and scheduled for cleanup.", witch);
    return Plugin_Handled;
}

public Action Timer_SelfTestCleanup(Handle timer, int entityRef)
{
    int entity = EntRefToEntIndex(entityRef);
    if (entity > MaxClients && IsValidEntity(entity))
    {
        RemoveEntity(entity);
    }
    return Plugin_Stop;
}

public void Event_Cleanup(Event event, const char[] name, bool dontBroadcast)
{
    CleanupAll(true, true, name);
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int team = event.GetInt("team");
    if (IsControlling(client) && team != TEAM_SPECTATOR)
    {
        EndControl(client, true, team == TEAM_INFECTED, "team switch");
    }
}

public void Event_GhostSpawnTime(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsRealClient(client) || g_bRandomAttempted[client] || g_cvRandomChance.FloatValue <= 0.0)
    {
        return;
    }

    g_bRandomAttempted[client] = true;
    if (GetRandomFloat(0.0, 100.0) <= g_cvRandomChance.FloatValue)
    {
        CreateTimer(0.2, Timer_RandomWitch, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_RandomWitch(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (IsRealClient(client) && GetClientTeam(client) == TEAM_INFECTED && IsGhost(client))
    {
        BeginControl(client, PlayableWitchSource_Random);
    }
    return Plugin_Stop;
}

bool BeginControl(int client, PlayableWitchSource source)
{
    if (source < PlayableWitchSource_Purchase || source > PlayableWitchSource_Random
        || !IsModuleAvailable() || !IsRealClient(client) || IsControlling(client) || CountControllers() >= 1)
    {
        return false;
    }

    if (source == PlayableWitchSource_Purchase && HasPurchasedThisChapter(client))
    {
        return false;
    }

    int team = GetClientTeam(client);
    if (source == PlayableWitchSource_Purchase
        && (team != TEAM_INFECTED || (!IsGhost(client) && !IsPlayerAlive(client))))
    {
        return false;
    }
    if (source == PlayableWitchSource_Random
        && (team != TEAM_INFECTED || !IsGhost(client)))
    {
        return false;
    }

    if (team == TEAM_SURVIVOR && GetFeatureStatus(FeatureType_Native, "L4D_ReplaceWithBot") != FeatureStatus_Available)
    {
        return false;
    }
    if (team == TEAM_INFECTED && !IsGhost(client)
        && GetFeatureStatus(FeatureType_Native, "L4D_CullZombie") != FeatureStatus_Available)
    {
        return false;
    }

    float position[3], angles[3];
    GetControlSpawn(client, position, angles);
    int witch = L4D2_SpawnWitch(position, angles);
    if (witch <= MaxClients || !IsValidEntity(witch))
    {
        return false;
    }

    if (HasEntProp(witch, Prop_Data, "m_iHealth"))
    {
        SetEntProp(witch, Prop_Data, "m_iHealth", g_cvHealth.IntValue);
    }
    if (HasEntProp(witch, Prop_Data, "m_iMaxHealth"))
    {
        SetEntProp(witch, Prop_Data, "m_iMaxHealth", g_cvHealth.IntValue);
    }
    SDKHook(witch, SDKHook_OnTakeDamagePost, OnWitchDamagedPost);

    if (team == TEAM_SURVIVOR)
    {
        L4D_ReplaceWithBot(client);
    }
    else if (GetClientTeam(client) == TEAM_INFECTED && IsPlayerAlive(client) && !IsGhost(client))
    {
        L4D_CullZombie(client);
    }
    ChangeClientTeam(client, TEAM_SPECTATOR);

    int camera = CreateEntityByName("info_target");
    if (camera <= MaxClients || !DispatchSpawn(camera))
    {
        if (camera > MaxClients && IsValidEntity(camera))
        {
            RemoveEntity(camera);
        }
        RemoveEntity(witch);
        ReturnToGhost(client);
        return false;
    }

    g_iWitch[client] = witch;
    g_iCamera[client] = camera;
    g_iSource[client] = source;
    g_iLastButtons[client] = 0;
    g_fNextAttack[client] = 0.0;
    g_fNextRage[client] = 0.0;
    g_fRageUntil[client] = 0.0;
    SetClientViewEntity(client, camera);
    UpdateCamera(client);

    if (source == PlayableWitchSource_Purchase)
    {
        RecordChapterPurchase(client);
    }
    PrintToChat(client, "\x04[Witch]\x01 Mouse1 攻击，Space 跳跃，E 短时狂暴。死亡后返回普通感染者 Ghost。");
    LogMessage("Playable Witch started: client=%N source=%d entity=%d", client, source, witch);
    return true;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon,
    int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (!IsControlling(client))
    {
        return Plugin_Continue;
    }

    int witch = g_iWitch[client];
    float yaw[3] = {0.0, 0.0, 0.0};
    yaw[1] = angles[1];
    float direction[3], right[3], up[3], velocity[3];
    GetAngleVectors(yaw, direction, right, up);

    float side = 0.0;
    float front = 0.0;
    if (buttons & IN_FORWARD) front += 1.0;
    if (buttons & IN_BACK) front -= 1.0;
    if (buttons & IN_MOVERIGHT) side += 1.0;
    if (buttons & IN_MOVELEFT) side -= 1.0;

    velocity[0] = (direction[0] * front) + (right[0] * side);
    velocity[1] = (direction[1] * front) + (right[1] * side);
    float length = SquareRoot((velocity[0] * velocity[0]) + (velocity[1] * velocity[1]));
    if (length > 0.0)
    {
        float speed = g_cvMoveSpeed.FloatValue;
        if (GetGameTime() < g_fRageUntil[client])
        {
            speed *= g_cvRageSpeed.FloatValue;
        }
        velocity[0] = velocity[0] / length * speed;
        velocity[1] = velocity[1] / length * speed;
    }

    float currentVelocity[3];
    GetEntPropVector(witch, Prop_Data, "m_vecVelocity", currentVelocity);
    velocity[2] = currentVelocity[2];
    int pressed = buttons & ~g_iLastButtons[client];
    if ((pressed & IN_JUMP) && (GetEntityFlags(witch) & FL_ONGROUND))
    {
        velocity[2] = g_cvJumpVelocity.FloatValue;
    }
    if (pressed & IN_ATTACK)
    {
        WitchAttack(client);
    }
    if (pressed & IN_USE)
    {
        StartRage(client);
    }

    TeleportEntity(witch, NULL_VECTOR, yaw, velocity);
    g_iLastButtons[client] = buttons;
    buttons &= ~(IN_ATTACK | IN_ATTACK2 | IN_USE);
    return Plugin_Changed;
}

public void OnGameFrame()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsControlling(client))
        {
            UpdateCamera(client);
            if (g_fRageUntil[client] > 0.0 && GetGameTime() >= g_fRageUntil[client])
            {
                SetEntityRenderColor(g_iWitch[client], 255, 255, 255, 255);
                g_fRageUntil[client] = 0.0;
            }
        }
    }
}

public void OnWitchDamagedPost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
    if (IsValidEntity(victim) && GetEntProp(victim, Prop_Data, "m_iHealth") <= 0)
    {
        int client = FindController(victim);
        if (client > 0)
        {
            EndControl(client, false, true, "death");
        }
    }
}

public void OnEntityDestroyed(int entity)
{
    if (entity <= MaxClients)
    {
        return;
    }
    int client = FindController(entity);
    if (client > 0)
    {
        EndControl(client, false, true, "entity removed");
    }
}

public Action L4D2_OnEntityShoved(int client, int entity, int weapon, float vecDir[3], bool bIsHighPounce)
{
    int controller = FindController(entity);
    if (controller > 0 && GetGameTime() < g_fRageUntil[controller])
    {
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public Action Timer_Hud(Handle timer)
{
    float now = GetGameTime();
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsControlling(client))
        {
            continue;
        }
        int health = GetEntProp(g_iWitch[client], Prop_Data, "m_iHealth");
        float attack = g_fNextAttack[client] > now ? g_fNextAttack[client] - now : 0.0;
        float rage = g_fNextRage[client] > now ? g_fNextRage[client] - now : 0.0;
        PrintHintText(client, "WITCH HP %d | 攻击 %.1fs | 狂暴 %.1fs\nMouse1 攻击  Space 跳跃  E 狂暴", health, attack, rage);
    }
    return Plugin_Continue;
}

void WitchAttack(int client)
{
    float now = GetGameTime();
    if (now < g_fNextAttack[client])
    {
        return;
    }
    g_fNextAttack[client] = now + g_cvAttackCooldown.FloatValue;

    int witch = g_iWitch[client];
    float origin[3], angles[3], direction[3], right[3], up[3];
    GetEntPropVector(witch, Prop_Data, "m_vecAbsOrigin", origin);
    GetEntPropVector(witch, Prop_Data, "m_angAbsRotation", angles);
    GetAngleVectors(angles, direction, right, up);

    int target;
    float best = g_cvAttackRange.FloatValue;
    for (int survivor = 1; survivor <= MaxClients; survivor++)
    {
        if (!IsClientInGame(survivor) || GetClientTeam(survivor) != TEAM_SURVIVOR || !IsPlayerAlive(survivor))
        {
            continue;
        }
        float targetPos[3], delta[3];
        GetClientAbsOrigin(survivor, targetPos);
        MakeVectorFromPoints(origin, targetPos, delta);
        float distance = GetVectorLength(delta);
        if (distance > best || distance <= 0.0)
        {
            continue;
        }
        NormalizeVector(delta, delta);
        if (GetVectorDotProduct(direction, delta) < 0.20)
        {
            continue;
        }
        target = survivor;
        best = distance;
    }

    if (target > 0)
    {
        SDKHooks_TakeDamage(target, witch, witch, g_cvAttackDamage.FloatValue, DMG_SLASH);
    }
}

void StartRage(int client)
{
    float now = GetGameTime();
    if (now < g_fNextRage[client])
    {
        return;
    }
    g_fRageUntil[client] = now + g_cvRageDuration.FloatValue;
    g_fNextRage[client] = now + g_cvRageCooldown.FloatValue;
    SetEntityRenderColor(g_iWitch[client], 255, 90, 90, 255);
}

void UpdateCamera(int client)
{
    int witch = g_iWitch[client];
    int camera = g_iCamera[client];
    if (!IsValidEntity(witch) || !IsValidEntity(camera))
    {
        return;
    }

    float origin[3], angles[3], direction[3], right[3], up[3], cameraPos[3];
    GetEntPropVector(witch, Prop_Data, "m_vecAbsOrigin", origin);
    GetEntPropVector(witch, Prop_Data, "m_angAbsRotation", angles);
    GetAngleVectors(angles, direction, right, up);
    cameraPos[0] = origin[0] - (direction[0] * 105.0);
    cameraPos[1] = origin[1] - (direction[1] * 105.0);
    cameraPos[2] = origin[2] + 72.0;
    angles[0] = 12.0;
    TeleportEntity(camera, cameraPos, angles, NULL_VECTOR);
}

void GetControlSpawn(int client, float position[3], float angles[3])
{
    if (IsPlayerAlive(client))
    {
        GetClientAbsOrigin(client, position);
        GetClientEyeAngles(client, angles);
        position[2] += 8.0;
        return;
    }

    for (int survivor = 1; survivor <= MaxClients; survivor++)
    {
        if (IsClientInGame(survivor) && GetClientTeam(survivor) == TEAM_SURVIVOR && IsPlayerAlive(survivor))
        {
            GetClientAbsOrigin(survivor, position);
            GetClientEyeAngles(survivor, angles);
            float direction[3], right[3], up[3];
            GetAngleVectors(angles, direction, right, up);
            position[0] -= direction[0] * 180.0;
            position[1] -= direction[1] * 180.0;
            return;
        }
    }
    GetClientAbsOrigin(client, position);
    GetClientEyeAngles(client, angles);
}

void EndControl(int client, bool removeWitch, bool returnGhost, const char[] reason)
{
    if (client < 1 || client > MaxClients || g_bCleaning[client]
        || (g_iWitch[client] <= 0 && g_iCamera[client] <= 0))
    {
        return;
    }

    g_bCleaning[client] = true;

    int witch = g_iWitch[client];
    int camera = g_iCamera[client];
    g_iWitch[client] = 0;
    g_iCamera[client] = 0;
    g_iLastButtons[client] = 0;
    g_fRageUntil[client] = 0.0;

    if (IsClientInGame(client))
    {
        SetClientViewEntity(client, client);
    }
    if (camera > MaxClients && IsValidEntity(camera))
    {
        RemoveEntity(camera);
    }
    if (removeWitch && witch > MaxClients && IsValidEntity(witch))
    {
        SDKUnhook(witch, SDKHook_OnTakeDamagePost, OnWitchDamagedPost);
        RemoveEntity(witch);
    }
    if (returnGhost && IsRealClient(client))
    {
        ReturnToGhost(client);
    }
    LogMessage("Playable Witch ended: client=%d reason=%s", client, reason);
    g_bCleaning[client] = false;
}

void CleanupAll(bool removeWitch, bool returnGhost, const char[] reason)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        EndControl(client, removeWitch, returnGhost, reason);
    }
}

void ReturnToGhost(int client)
{
    ChangeClientTeam(client, TEAM_INFECTED);
    RequestFrame(Frame_ReturnToGhost, GetClientUserId(client));
}

public void Frame_ReturnToGhost(int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsRealClient(client) || GetClientTeam(client) != TEAM_INFECTED)
    {
        return;
    }
    if (GetFeatureStatus(FeatureType_Native, "L4D_SetClass") == FeatureStatus_Available)
    {
        L4D_SetClass(client, ZC_SMOKER);
    }
    if (GetFeatureStatus(FeatureType_Native, "L4D_State_Transition") == FeatureStatus_Available)
    {
        L4D_State_Transition(client, STATE_GHOST);
    }
    bool becameGhost;
    if (GetFeatureStatus(FeatureType_Native, "L4D_BecomeGhost") == FeatureStatus_Available)
    {
        becameGhost = L4D_BecomeGhost(client);
    }
    if (!becameGhost && HasEntProp(client, Prop_Send, "m_isGhost"))
    {
        SetEntProp(client, Prop_Send, "m_isGhost", 1);
    }
}

bool IsModuleAvailable()
{
    return g_cvEnabled.BoolValue
        && g_cvMaxPlayers.IntValue == 1
        && GetFeatureStatus(FeatureType_Native, "L4D2_SpawnWitch") == FeatureStatus_Available;
}

bool IsControlling(int client)
{
    return client > 0 && client <= MaxClients
        && g_iWitch[client] > MaxClients && IsValidEntity(g_iWitch[client])
        && g_iCamera[client] > MaxClients && IsValidEntity(g_iCamera[client]);
}

bool IsRealClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}

bool IsGhost(int client)
{
    return HasEntProp(client, Prop_Send, "m_isGhost") && GetEntProp(client, Prop_Send, "m_isGhost") != 0;
}

int CountControllers()
{
    int count;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsControlling(client))
        {
            count++;
        }
    }
    return count;
}

int FindController(int witch)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (g_iWitch[client] == witch)
        {
            return client;
        }
    }
    return 0;
}

bool HasPurchasedThisChapter(int client)
{
    char steamId[64];
    int count;
    return GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId), true)
        && g_hChapterPurchases.GetValue(steamId, count) && count >= 1;
}

void RecordChapterPurchase(int client)
{
    char steamId[64];
    if (GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId), true))
    {
        g_hChapterPurchases.SetValue(steamId, 1);
    }
}
