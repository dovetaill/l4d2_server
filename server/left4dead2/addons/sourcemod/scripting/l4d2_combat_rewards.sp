#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0.0"
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZOMBIE_TANK 8
#define MAX_LOOT_ENTITIES 2048

ConVar g_cvSIHeal;
ConVar g_cvSIHeadshotHeal;
ConVar g_cvWitchHeal;
ConVar g_cvWitchCrownHeal;
ConVar g_cvTankHeal;
ConVar g_cvSecondWindHealth;
ConVar g_cvSecondWindTankHealth;
ConVar g_cvSecondWindCooldown;
ConVar g_cvMaxHealth;
ConVar g_cvLootLifetime;
ConVar g_cvRareLootChance;
ConVar g_cvMinigunLifetime;

float g_fLastSecondWind[MAXPLAYERS + 1];
int g_iLastWitchAttacker;
int g_iMinigunTokens[MAXPLAYERS + 1];
int g_iActiveMinigun[MAXPLAYERS + 1];
int g_iActiveMiniguns;

public Plugin myinfo =
{
    name = "L4D2 Combat Rewards",
    author = "Codex",
    description = "Campaign-scoped combat healing, Second Wind, Tank loot, and deployable miniguns.",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    g_cvSIHeal = CreateConVar("l4d2_rewards_si_heal", "3", "Permanent HP for a Special Infected kill.", FCVAR_NOTIFY, true, 0.0);
    g_cvSIHeadshotHeal = CreateConVar("l4d2_rewards_si_headshot_heal", "5", "Permanent HP for a headshot Special Infected kill.", FCVAR_NOTIFY, true, 0.0);
    g_cvWitchHeal = CreateConVar("l4d2_rewards_witch_heal", "15", "Permanent HP for killing a Witch.", FCVAR_NOTIFY, true, 0.0);
    g_cvWitchCrownHeal = CreateConVar("l4d2_rewards_witch_crown_heal", "25", "Permanent HP for a one-shot Witch kill.", FCVAR_NOTIFY, true, 0.0);
    g_cvTankHeal = CreateConVar("l4d2_rewards_tank_heal", "35", "Permanent HP for the last hit on a Tank.", FCVAR_NOTIFY, true, 0.0);
    g_cvSecondWindHealth = CreateConVar("l4d2_rewards_second_wind_health", "35", "HP after Second Wind against a Special Infected.", FCVAR_NOTIFY, true, 1.0);
    g_cvSecondWindTankHealth = CreateConVar("l4d2_rewards_second_wind_tank_health", "60", "HP after Second Wind against a Tank.", FCVAR_NOTIFY, true, 1.0);
    g_cvSecondWindCooldown = CreateConVar("l4d2_rewards_second_wind_cooldown", "5.0", "Seconds between Second Wind activations per player.", FCVAR_NOTIFY, true, 0.0);
    g_cvMaxHealth = CreateConVar("l4d2_rewards_max_health", "100", "Maximum permanent HP granted by rewards.", FCVAR_NOTIFY, true, 1.0);
    g_cvLootLifetime = CreateConVar("l4d2_rewards_loot_lifetime", "75.0", "Seconds before Tank loot is removed.", FCVAR_NOTIFY, true, 1.0);
    g_cvRareLootChance = CreateConVar("l4d2_rewards_rare_loot_chance", "30", "Percent chance for a second rare Tank drop.", FCVAR_NOTIFY, true, 0.0, true, 100.0);
    g_cvMinigunLifetime = CreateConVar("l4d2_rewards_minigun_lifetime", "120.0", "Seconds before a deployed minigun is removed.", FCVAR_NOTIFY, true, 10.0);
    CreateConVar("l4d2_combat_rewards_version", PLUGIN_VERSION, "Combat Rewards version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("witch_harasser_set", Event_WitchHarasserSet, EventHookMode_Post);
    HookEvent("witch_killed", Event_WitchKilled, EventHookMode_Post);
    HookEvent("round_start", Event_ResetRound, EventHookMode_Post);
    HookEvent("map_transition", Event_ResetRound, EventHookMode_Post);
    HookEvent("finale_win", Event_ResetRound, EventHookMode_Post);
    HookEvent("mission_lost", Event_ResetRound, EventHookMode_Post);

    RegConsoleCmd("sm_minigun", Command_Minigun, "Deploy a Tank-loot minigun token.");
    RegConsoleCmd("sm_mg", Command_Minigun, "Deploy a Tank-loot minigun token.");

    AutoExecConfig(true, "l4d2_combat_rewards");
    ResetPlayerState();
}

public void OnMapEnd()
{
    RemoveAllDeployedMiniguns();
    ResetPlayerState();
}

public void Event_ResetRound(Event event, const char[] name, bool dontBroadcast)
{
    g_iLastWitchAttacker = 0;
    for (int client = 1; client <= MaxClients; client++)
    {
        g_fLastSecondWind[client] = 0.0;
    }
}

public void ResetPlayerState()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        g_fLastSecondWind[client] = 0.0;
        g_iMinigunTokens[client] = 0;
        g_iActiveMinigun[client] = -1;
    }
    g_iLastWitchAttacker = 0;
    g_iActiveMiniguns = 0;
}

public void Event_WitchHarasserSet(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    if (IsRealSurvivor(attacker))
    {
        g_iLastWitchAttacker = attacker;
    }
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (!IsRealSurvivor(attacker))
    {
        attacker = GetClientOfUserId(event.GetInt("userid"));
    }
    if (!IsRealSurvivor(attacker))
    {
        attacker = g_iLastWitchAttacker;
    }

    if (IsRealSurvivor(attacker))
    {
        bool crown = event.GetBool("one_shot") || event.GetBool("headshot");
        RewardOrSecondWind(attacker, crown ? g_cvWitchCrownHeal.IntValue : g_cvWitchHeal.IntValue, false);
    }
    g_iLastWitchAttacker = 0;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (!IsRealSurvivor(attacker) || !IsValidClient(victim) || GetClientTeam(victim) != TEAM_INFECTED)
    {
        return;
    }

    int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
    bool tank = zombieClass == ZOMBIE_TANK;
    bool headshot = event.GetBool("headshot");

    if (IsIncapacitated(attacker))
    {
        TrySecondWind(attacker, tank);
        return;
    }

    if (tank)
    {
        HealPlayer(attacker, g_cvTankHeal.IntValue);
        SpawnTankLoot(victim);
    }
    else if (zombieClass >= 1 && zombieClass <= 6)
    {
        HealPlayer(attacker, headshot ? g_cvSIHeadshotHeal.IntValue : g_cvSIHeal.IntValue);
    }
}

void RewardOrSecondWind(int attacker, int heal, bool tank)
{
    if (IsIncapacitated(attacker))
    {
        TrySecondWind(attacker, tank);
        return;
    }
    HealPlayer(attacker, heal);
}

void TrySecondWind(int client, bool tank)
{
    float now = GetGameTime();
    if (now - g_fLastSecondWind[client] < g_cvSecondWindCooldown.FloatValue)
    {
        return;
    }
    g_fLastSecondWind[client] = now;

    if (GetFeatureStatus(FeatureType_Native, "L4D_ReviveSurvivor") == FeatureStatus_Available)
    {
        L4D_ReviveSurvivor(client);
    }
    else
    {
        SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);
        SetEntProp(client, Prop_Send, "m_isHangingFromLedge", 0);
    }

    int health = tank ? g_cvSecondWindTankHealth.IntValue : g_cvSecondWindHealth.IntValue;
    SetEntityHealth(client, health);

    char targetName[MAX_NAME_LENGTH];
    GetClientName(client, targetName, sizeof(targetName));
    PrintToChatAll("\x04[SECOND WIND]\x01 %s 重新站起来了！", targetName);
}

void HealPlayer(int client, int amount)
{
    if (!IsRealSurvivor(client) || IsIncapacitated(client) || amount <= 0)
    {
        return;
    }
    int health = GetClientHealth(client);
    int maxHealth = g_cvMaxHealth.IntValue;
    SetEntityHealth(client, health > maxHealth - amount ? maxHealth : health + amount);
}

void SpawnTankLoot(int tank)
{
    float pos[3];
    if (!IsValidClient(tank) || !GetClientAbsOrigin(tank, pos))
    {
        return;
    }

    char guaranteed[64];
    int roll = GetRandomInt(1, 100);
    if (roll <= 30)
    {
        strcopy(guaranteed, sizeof(guaranteed), "weapon_first_aid_kit_spawn");
    }
    else if (roll <= 50)
    {
        strcopy(guaranteed, sizeof(guaranteed), "weapon_defibrillator_spawn");
    }
    else if (roll <= 70)
    {
        strcopy(guaranteed, sizeof(guaranteed), "weapon_upgradepack_explosive_spawn");
    }
    else if (roll <= 90)
    {
        strcopy(guaranteed, sizeof(guaranteed), "weapon_upgradepack_incendiary_spawn");
    }
    else
    {
        strcopy(guaranteed, sizeof(guaranteed), GetRandomInt(0, 1) == 0 ? "weapon_pain_pills_spawn" : "weapon_adrenaline_spawn");
    }
    SpawnLootEntity(guaranteed, pos, g_cvLootLifetime.FloatValue);

    if (GetRandomInt(1, 100) <= g_cvRareLootChance.IntValue)
    {
        int rareRoll = GetRandomInt(1, 100);
        if (rareRoll == 1)
        {
            SpawnMinigunToken(pos);
        }
        else
        {
            char rare[64];
            switch (GetRandomInt(1, 6))
            {
                case 1: strcopy(rare, sizeof(rare), "weapon_rifle_m60_spawn");
                case 2: strcopy(rare, sizeof(rare), "weapon_grenade_launcher_spawn");
                case 3: strcopy(rare, sizeof(rare), "weapon_rifle_sg552_spawn");
                case 4: strcopy(rare, sizeof(rare), "weapon_smg_mp5_spawn");
                case 5: strcopy(rare, sizeof(rare), "weapon_sniper_awp_spawn");
                default: strcopy(rare, sizeof(rare), "weapon_sniper_scout_spawn");
            }
            pos[2] += 8.0;
            SpawnLootEntity(rare, pos, g_cvLootLifetime.FloatValue);
        }
    }
}

int SpawnLootEntity(const char[] classname, const float pos[3], float lifetime)
{
    int entity = CreateEntityByName(classname);
    if (entity == -1)
    {
        LogError("Unable to create Tank loot entity: %s", classname);
        return -1;
    }
    DispatchSpawn(entity);
    TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
    CreateTimer(lifetime, Timer_RemoveEntity, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
    return entity;
}

void SpawnMinigunToken(const float origin[3])
{
    int entity = CreateEntityByName("prop_physics_override");
    if (entity == -1)
    {
        LogError("Unable to create deployable minigun token entity.");
        return;
    }
    DispatchKeyValue(entity, "model", "models/props_junk/garbage_metalcan001a.mdl");
    DispatchKeyValue(entity, "solid", "6");
    DispatchKeyValue(entity, "spawnflags", "256");
    DispatchSpawn(entity);
    float pos[3];
    pos = origin;
    pos[2] += 16.0;
    TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
    SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
    SetEntProp(entity, Prop_Send, "m_nGlowRange", 500);
    SetEntProp(entity, Prop_Send, "m_glowColorOverride", 65280);
    SDKHook(entity, SDKHook_StartTouch, OnTokenStartTouch);
    CreateTimer(g_cvLootLifetime.FloatValue, Timer_RemoveEntity, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

public Action OnTokenStartTouch(int entity, int other)
{
    if (!IsRealSurvivor(other))
    {
        return Plugin_Continue;
    }
    g_iMinigunTokens[other]++;
    PrintToChat(other, "\x04[LOOT]\x01 获得一个加特林部署装置。输入 !minigun 部署。");
    RemoveEntity(entity);
    return Plugin_Handled;
}

public Action Timer_RemoveEntity(Handle timer, any ref)
{
    int entity = EntRefToEntIndex(ref);
    if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
    {
        RemoveEntity(entity);
    }
    return Plugin_Stop;
}

public Action Command_Minigun(int client, int args)
{
    if (!IsRealSurvivor(client) || !IsPlayerAlive(client))
    {
        return Plugin_Handled;
    }
    if (g_iMinigunTokens[client] <= 0)
    {
        PrintToChat(client, "\x04[LOOT]\x01 你没有加特林部署装置。");
        return Plugin_Handled;
    }
    if (g_iActiveMiniguns >= 2 || (g_iActiveMinigun[client] != -1 && IsValidEntity(g_iActiveMinigun[client])))
    {
        PrintToChat(client, "\x04[LOOT]\x01 当前加特林数量已达上限，或你已有一台正在部署。");
        return Plugin_Handled;
    }

    float eye[3], angles[3], hit[3], downStart[3], downEnd[3];
    GetClientEyePosition(client, eye);
    GetClientEyeAngles(client, angles);
    Handle trace = TR_TraceRayFilterEx(eye, angles, MASK_SOLID, RayType_Infinite, TraceFilterIgnoreClients, client);
    if (!TR_DidHit(trace))
    {
        delete trace;
        PrintToChat(client, "\x04[LOOT]\x01 找不到可部署的地面。");
        return Plugin_Handled;
    }
    TR_GetEndPosition(hit, trace);
    delete trace;

    downStart = hit;
    downStart[2] += 32.0;
    downEnd = hit;
    downEnd[2] -= 96.0;
    trace = TR_TraceRayFilterEx(downStart, downEnd, MASK_SOLID, RayType_EndPoint, TraceFilterIgnoreClients, client);
    if (!TR_DidHit(trace))
    {
        delete trace;
        PrintToChat(client, "\x04[LOOT]\x01 地面不稳定，无法部署。");
        return Plugin_Handled;
    }
    TR_GetEndPosition(hit, trace);
    delete trace;

    int entity = CreateEntityByName("prop_minigun_l4d1");
    if (entity == -1)
    {
        PrintToChat(client, "\x04[LOOT]\x01 当前地图无法创建加特林。");
        return Plugin_Handled;
    }
    DispatchSpawn(entity);
    GetClientAbsAngles(client, angles);
    angles[0] = 0.0;
    angles[2] = 0.0;
    hit[2] += 2.0;
    TeleportEntity(entity, hit, angles, NULL_VECTOR);
    g_iMinigunTokens[client]--;
    g_iActiveMinigun[client] = entity;
    g_iActiveMiniguns++;
    CreateTimer(g_cvMinigunLifetime.FloatValue, Timer_RemoveMinigun, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
    PrintToChatAll("\x04[LOOT]\x01 %N 部署了加特林。", client);
    return Plugin_Handled;
}

public Action Timer_RemoveMinigun(Handle timer, any ref)
{
    int entity = EntRefToEntIndex(ref);
    if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
    {
        for (int client = 1; client <= MaxClients; client++)
        {
            if (g_iActiveMinigun[client] == entity)
            {
                g_iActiveMinigun[client] = -1;
                if (g_iActiveMiniguns > 0)
                {
                    g_iActiveMiniguns--;
                }
                break;
            }
        }
        RemoveEntity(entity);
    }
    return Plugin_Stop;
}

void RemoveAllDeployedMiniguns()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        int entity = g_iActiveMinigun[client];
        if (entity != -1 && IsValidEntity(entity))
        {
            RemoveEntity(entity);
        }
        g_iActiveMinigun[client] = -1;
    }
    g_iActiveMiniguns = 0;
}

public bool TraceFilterIgnoreClients(int entity, int contentsMask, any data)
{
    return entity > MaxClients;
}

bool IsValidClient(int client)
{
    return client >= 1 && client <= MaxClients && IsClientInGame(client);
}

bool IsRealSurvivor(int client)
{
    return IsValidClient(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool IsIncapacitated(int client)
{
    return IsValidClient(client) && GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0;
}
