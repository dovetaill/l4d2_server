#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0.0"
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_TANK 8
#define MAX_TRACKED_ENTITIES 4096

enum DamageTargetType
{
    DamageTarget_None = 0,
    DamageTarget_Common,
    DamageTarget_Special,
    DamageTarget_Tank,
    DamageTarget_Witch
};

ConVar g_cvEnable;
ConVar g_cvHintEnable;
ConVar g_cvHintInterval;
ConVar g_cvUseCenter;
ConVar g_cvCommonEnable;
ConVar g_cvSpecialEnable;
ConVar g_cvTankEnable;
ConVar g_cvWitchEnable;
ConVar g_cvRankingEnable;
ConVar g_cvRankingTop;

bool g_bClientHooked[MAXPLAYERS + 1];
bool g_bEntityHooked[MAX_TRACKED_ENTITIES];

float g_fPreHealth[MAX_TRACKED_ENTITIES];
bool g_bPendingDamage[MAX_TRACKED_ENTITIES];

float g_fQueuedDamage[MAXPLAYERS + 1];
int g_iQueuedHits[MAXPLAYERS + 1];
int g_iQueuedTargetType[MAXPLAYERS + 1];
Handle g_hHintTimer[MAXPLAYERS + 1];
float g_fNextHint[MAXPLAYERS + 1];

bool g_bTankActive[MAXPLAYERS + 1];
bool g_bTankRankPrinted[MAXPLAYERS + 1];
int g_iTankSerial[MAXPLAYERS + 1];
float g_fTankDamage[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_iTankDamageSerial[MAXPLAYERS + 1][MAXPLAYERS + 1];
char g_sTankDamageName[MAXPLAYERS + 1][MAXPLAYERS + 1][MAX_NAME_LENGTH];

public Plugin myinfo =
{
    name = "L4D2 PvE Damage Display",
    author = "OpenAI",
    description = "Attacker-only PvE damage hints and per-Tank damage rankings",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    g_cvEnable = CreateConVar("l4d2_pve_damage_display_enable", "1", "启用 PvE 伤害显示和 Tank 排名", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvHintEnable = CreateConVar("l4d2_pve_damage_display_hint_enable", "1", "启用攻击者自己的低频伤害提示", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvHintInterval = CreateConVar("l4d2_pve_damage_display_hint_interval", "0.35", "同一攻击者伤害提示的最小间隔（秒）", FCVAR_NOTIFY, true, 0.10, true, 5.0);
    g_cvUseCenter = CreateConVar("l4d2_pve_damage_display_use_center", "0", "伤害提示使用 CenterText；0 使用 HintText", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvCommonEnable = CreateConVar("l4d2_pve_damage_display_common", "1", "统计普通感染者伤害", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvSpecialEnable = CreateConVar("l4d2_pve_damage_display_special", "1", "统计普通特殊感染者伤害", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvTankEnable = CreateConVar("l4d2_pve_damage_display_tank", "1", "统计 Tank 伤害", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvWitchEnable = CreateConVar("l4d2_pve_damage_display_witch", "1", "统计 Witch 伤害", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvRankingEnable = CreateConVar("l4d2_pve_damage_display_tank_ranking", "1", "Tank 死亡后打印伤害排名", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvRankingTop = CreateConVar("l4d2_pve_damage_display_tank_ranking_top", "5", "Tank 死亡后显示的排名人数", FCVAR_NOTIFY, true, 1.0, true, 10.0);
    CreateConVar("l4d2_pve_damage_display_version", PLUGIN_VERSION, "插件版本", FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_DONTRECORD);

    AutoExecConfig(true, "l4d2_pve_damage_display");

    HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_Post);
    HookEvent("tank_frustrated", Event_TankFrustrated, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("player_bot_replace", Event_PlayerBotReplace, EventHookMode_Post);
    HookEvent("bot_player_replace", Event_BotPlayerReplace, EventHookMode_Post);
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client))
        {
            HookClient(client);
        }
    }

    for (int entity = MaxClients + 1; entity < GetMaxEntities(); entity++)
    {
        if (IsValidEntity(entity))
        {
            Frame_HookInfectedEntity(EntIndexToEntRef(entity));
        }
    }
}

public void OnMapStart()
{
    ResetAllState();
}

public void OnMapEnd()
{
    ResetAllState();
}

public void OnClientPutInServer(int client)
{
    HookClient(client);
    ResetClientDisplay(client);
}

public void OnClientDisconnect(int client)
{
    if (client < 1 || client > MaxClients)
    {
        return;
    }

    if (g_bClientHooked[client])
    {
        SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamagePre);
        SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
        g_bClientHooked[client] = false;
    }

    ResetClientDisplay(client);
    g_bPendingDamage[client] = false;
    g_fPreHealth[client] = 0.0;

    if (g_bTankActive[client] && !g_bTankRankPrinted[client] && g_cvRankingEnable.BoolValue)
    {
        g_bTankRankPrinted[client] = true;
        PrintTankRanking(client);
    }
    g_bTankActive[client] = false;
    g_bTankRankPrinted[client] = false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity <= MaxClients || entity >= MAX_TRACKED_ENTITIES)
    {
        return;
    }

    if (StrEqual(classname, "infected") || StrEqual(classname, "witch"))
    {
        RequestFrame(Frame_HookInfectedEntity, EntIndexToEntRef(entity));
    }
}

public void OnEntityDestroyed(int entity)
{
    if (entity <= MaxClients || entity >= MAX_TRACKED_ENTITIES)
    {
        return;
    }

    if (g_bEntityHooked[entity])
    {
        SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamagePre);
        SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
        g_bEntityHooked[entity] = false;
    }

    g_bPendingDamage[entity] = false;
    g_fPreHealth[entity] = 0.0;
}

void HookClient(int client)
{
    if (client < 1 || client > MaxClients || g_bClientHooked[client])
    {
        return;
    }

    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamagePre);
    SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
    g_bClientHooked[client] = true;
}

public void Frame_HookInfectedEntity(int entityRef)
{
    int entity = EntRefToEntIndex(entityRef);
    if (entity == INVALID_ENT_REFERENCE || entity <= MaxClients || entity >= MAX_TRACKED_ENTITIES || !IsValidEntity(entity))
    {
        return;
    }

    char classname[32];
    GetEntityClassname(entity, classname, sizeof(classname));
    if (!StrEqual(classname, "infected") && !StrEqual(classname, "witch"))
    {
        return;
    }

    if (!g_bEntityHooked[entity])
    {
        SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamagePre);
        SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
        g_bEntityHooked[entity] = true;
    }
}

public Action OnTakeDamagePre(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!g_cvEnable.BoolValue || !IsTrackedIndex(victim) || damage <= 0.0)
    {
        return Plugin_Continue;
    }

    DamageTargetType targetType = GetDamageTargetType(victim);
    if (!IsTargetTypeEnabled(targetType))
    {
        g_bPendingDamage[victim] = false;
        return Plugin_Continue;
    }

    g_fPreHealth[victim] = float(GetTargetHealth(victim));
    g_bPendingDamage[victim] = true;
    return Plugin_Continue;
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
    if (!g_cvEnable.BoolValue || !IsTrackedIndex(victim) || damage <= 0.0)
    {
        return;
    }

    DamageTargetType targetType = GetDamageTargetType(victim);
    if (!IsTargetTypeEnabled(targetType))
    {
        g_bPendingDamage[victim] = false;
        return;
    }

    float actualDamage = damage;
    if (g_bPendingDamage[victim] && g_fPreHealth[victim] > 0.0)
    {
        float currentHealth = float(GetTargetHealth(victim));
        float healthDelta = g_fPreHealth[victim] - currentHealth;
        if (healthDelta >= 0.0)
        {
            actualDamage = healthDelta;
        }
        if (actualDamage > g_fPreHealth[victim])
        {
            actualDamage = g_fPreHealth[victim];
        }
    }
    g_bPendingDamage[victim] = false;

    if (actualDamage <= 0.0)
    {
        return;
    }

    int survivor = ResolveSurvivorAttacker(attacker, inflictor);
    if (!IsRealSurvivor(survivor))
    {
        return;
    }

    if (targetType == DamageTarget_Tank)
    {
        EnsureTankState(victim);
        int survivorSerial = GetClientSerial(survivor);
        if (g_iTankDamageSerial[victim][survivor] != survivorSerial)
        {
            g_iTankDamageSerial[victim][survivor] = survivorSerial;
            g_fTankDamage[victim][survivor] = 0.0;
            GetClientName(survivor, g_sTankDamageName[victim][survivor], MAX_NAME_LENGTH);
        }
        g_fTankDamage[victim][survivor] += actualDamage;
    }

    QueueDamageHint(survivor, targetType, actualDamage);
}

void QueueDamageHint(int client, DamageTargetType targetType, float damage)
{
    if (!g_cvHintEnable.BoolValue || client < 1 || client > MaxClients)
    {
        return;
    }

    g_fQueuedDamage[client] += damage;
    g_iQueuedHits[client]++;
    g_iQueuedTargetType[client] = view_as<int>(targetType);

    if (g_hHintTimer[client] == null)
    {
        g_hHintTimer[client] = CreateTimer(g_cvHintInterval.FloatValue, Timer_SendDamageHint, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_SendDamageHint(Handle timer, any userId)
{
    int client = GetClientOfUserId(userId);
    if (client < 1 || client > MaxClients)
    {
        return Plugin_Stop;
    }

    g_hHintTimer[client] = null;
    if (!IsRealSurvivor(client) || g_fQueuedDamage[client] <= 0.0)
    {
        ResetClientDisplay(client);
        return Plugin_Stop;
    }

    char targetName[32];
    GetTargetTypeName(view_as<DamageTargetType>(g_iQueuedTargetType[client]), targetName, sizeof(targetName));

    if (g_iQueuedHits[client] == 1)
    {
        if (g_cvUseCenter.BoolValue)
        {
            PrintCenterText(client, "伤害 +%.0f\n%s", g_fQueuedDamage[client], targetName);
        }
        else
        {
            PrintHintText(client, "伤害 +%.0f\n%s", g_fQueuedDamage[client], targetName);
        }
    }
    else
    {
        if (g_cvUseCenter.BoolValue)
        {
            PrintCenterText(client, "伤害 +%.0f\n%d 次命中", g_fQueuedDamage[client], g_iQueuedHits[client]);
        }
        else
        {
            PrintHintText(client, "伤害 +%.0f\n%d 次命中", g_fQueuedDamage[client], g_iQueuedHits[client]);
        }
    }

    g_fQueuedDamage[client] = 0.0;
    g_iQueuedHits[client] = 0;
    g_iQueuedTargetType[client] = DamageTarget_None;
    return Plugin_Stop;
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int tank = GetClientOfUserId(event.GetInt("userid"));
    if (tank < 1 || tank > MaxClients || !IsClientInGame(tank))
    {
        return;
    }

    if (!g_bTankActive[tank])
    {
        ResetTankState(tank);
        g_iTankSerial[tank]++;
        g_bTankActive[tank] = true;
        g_bTankRankPrinted[tank] = false;
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (victim < 1 || victim > MaxClients || !g_bTankActive[victim] || !IsTankClient(victim))
    {
        return;
    }

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));
    int damageType = event.GetInt("type");

    bool transfer = attacker == victim && StrEqual(weapon, "world", false) && (damageType & DMG_NEVERGIB) != 0;
    g_bTankActive[victim] = false;

    if (transfer || g_bTankRankPrinted[victim] || !g_cvRankingEnable.BoolValue)
    {
        return;
    }

    g_bTankRankPrinted[victim] = true;
    PrintTankRanking(victim);
}

public void Event_TankFrustrated(Event event, const char[] name, bool dontBroadcast)
{
    int tank = GetClientOfUserId(event.GetInt("userid"));
    if (tank >= 1 && tank <= MaxClients)
    {
        g_bTankActive[tank] = false;
    }
}

void PrintTankRanking(int tank)
{
    float total = 0.0;
    for (int client = 1; client <= MaxClients; client++)
    {
        total += g_fTankDamage[tank][client];
    }

    PrintToChatAll("\x04[Tank伤害]\x01 本只 Tank 已死亡，伤害排名：");
    if (total <= 0.0)
    {
        PrintToChatAll("\x04[Tank伤害]\x01 没有记录到有效的真人幸存者伤害。");
        return;
    }

    int top = g_cvRankingTop.IntValue;
    if (top < 1) top = 1;
    if (top > 10) top = 10;

    bool used[MAXPLAYERS + 1];
    for (int rank = 1; rank <= top; rank++)
    {
        int best = 0;
        float bestDamage = 0.0;
        for (int client = 1; client <= MaxClients; client++)
        {
            if (used[client] || g_fTankDamage[tank][client] <= bestDamage)
            {
                continue;
            }
            best = client;
            bestDamage = g_fTankDamage[tank][client];
        }

        if (best == 0)
        {
            break;
        }

        used[best] = true;
        char playerName[MAX_NAME_LENGTH];
        if (g_sTankDamageName[tank][best][0] != '\0')
        {
            strcopy(playerName, sizeof(playerName), g_sTankDamageName[tank][best]);
        }
        else if (IsClientInGame(best))
        {
            GetClientName(best, playerName, sizeof(playerName));
        }
        else
        {
            strcopy(playerName, sizeof(playerName), "已离线玩家");
        }

        PrintToChatAll("\x04[Tank伤害]\x01 #%d %s：%.0f 伤害（%.1f%%）", rank, playerName, bestDamage, bestDamage * 100.0 / total);
    }
}

public void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
    int player = GetClientOfUserId(event.GetInt("player"));
    int bot = GetClientOfUserId(event.GetInt("bot"));
    if (IsTankClient(player) && bot >= 1 && bot <= MaxClients)
    {
        CopyTankState(player, bot);
    }
}

public void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
    int bot = GetClientOfUserId(event.GetInt("bot"));
    int player = GetClientOfUserId(event.GetInt("player"));
    if (IsTankClient(bot) && player >= 1 && player <= MaxClients)
    {
        CopyTankState(bot, player);
    }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ResetAllState();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    ResetAllState();
}

void CopyTankState(int from, int to)
{
    if (from < 1 || from > MaxClients || to < 1 || to > MaxClients || from == to || !g_bTankActive[from])
    {
        return;
    }

    g_bTankActive[to] = true;
    g_bTankRankPrinted[to] = g_bTankRankPrinted[from];
    g_iTankSerial[to] = g_iTankSerial[from];
    for (int client = 1; client <= MaxClients; client++)
    {
        g_fTankDamage[to][client] = g_fTankDamage[from][client];
        g_iTankDamageSerial[to][client] = g_iTankDamageSerial[from][client];
        strcopy(g_sTankDamageName[to][client], MAX_NAME_LENGTH, g_sTankDamageName[from][client]);
    }

    g_bTankActive[from] = false;
}

void EnsureTankState(int tank)
{
    if (tank < 1 || tank > MaxClients || g_bTankActive[tank])
    {
        return;
    }

    ResetTankState(tank);
    g_iTankSerial[tank]++;
    g_bTankActive[tank] = true;
    g_bTankRankPrinted[tank] = false;
}

void ResetTankState(int tank)
{
    if (tank < 1 || tank > MaxClients)
    {
        return;
    }

    for (int client = 1; client <= MaxClients; client++)
    {
        g_fTankDamage[tank][client] = 0.0;
        g_iTankDamageSerial[tank][client] = 0;
        g_sTankDamageName[tank][client][0] = '\0';
    }
}

void ResetAllState()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        ResetClientDisplay(client);
        g_bTankActive[client] = false;
        g_bTankRankPrinted[client] = false;
        ResetTankState(client);
    }

    for (int entity = 0; entity < MAX_TRACKED_ENTITIES; entity++)
    {
        g_bPendingDamage[entity] = false;
        g_fPreHealth[entity] = 0.0;
        g_bEntityHooked[entity] = false;
    }
}

void ResetClientDisplay(int client)
{
    if (client < 1 || client > MaxClients)
    {
        return;
    }

    if (g_hHintTimer[client] != null)
    {
        delete g_hHintTimer[client];
        g_hHintTimer[client] = null;
    }

    g_fQueuedDamage[client] = 0.0;
    g_iQueuedHits[client] = 0;
    g_iQueuedTargetType[client] = DamageTarget_None;
    g_fNextHint[client] = 0.0;
}

bool IsTrackedIndex(int entity)
{
    return entity > 0 && entity < MAX_TRACKED_ENTITIES;
}

int GetTargetHealth(int entity)
{
    if (entity >= 1 && entity <= MaxClients)
    {
        return GetClientHealth(entity);
    }

    if (IsValidEntity(entity) && HasEntProp(entity, Prop_Data, "m_iHealth"))
    {
        return GetEntProp(entity, Prop_Data, "m_iHealth");
    }

    return 0;
}

DamageTargetType GetDamageTargetType(int entity)
{
    if (entity >= 1 && entity <= MaxClients)
    {
        if (!IsClientInGame(entity) || GetClientTeam(entity) != TEAM_INFECTED || !HasEntProp(entity, Prop_Send, "m_zombieClass"))
        {
            return DamageTarget_None;
        }

        return GetEntProp(entity, Prop_Send, "m_zombieClass") == ZC_TANK ? DamageTarget_Tank : DamageTarget_Special;
    }

    if (!IsValidEntity(entity))
    {
        return DamageTarget_None;
    }

    char classname[32];
    GetEntityClassname(entity, classname, sizeof(classname));
    if (StrEqual(classname, "infected"))
    {
        return DamageTarget_Common;
    }
    if (StrEqual(classname, "witch"))
    {
        return DamageTarget_Witch;
    }

    return DamageTarget_None;
}

bool IsTargetTypeEnabled(DamageTargetType targetType)
{
    switch (targetType)
    {
        case DamageTarget_Common: return g_cvCommonEnable.BoolValue;
        case DamageTarget_Special: return g_cvSpecialEnable.BoolValue;
        case DamageTarget_Tank: return g_cvTankEnable.BoolValue;
        case DamageTarget_Witch: return g_cvWitchEnable.BoolValue;
    }
    return false;
}

void GetTargetTypeName(DamageTargetType targetType, char[] buffer, int maxlen)
{
    switch (targetType)
    {
        case DamageTarget_Common: strcopy(buffer, maxlen, "普通感染者");
        case DamageTarget_Special: strcopy(buffer, maxlen, "特殊感染者");
        case DamageTarget_Tank: strcopy(buffer, maxlen, "Tank");
        case DamageTarget_Witch: strcopy(buffer, maxlen, "女巫");
        default: strcopy(buffer, maxlen, "目标");
    }
}

bool IsRealSurvivor(int client)
{
    return client >= 1 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool IsTankClient(int client)
{
    return client >= 1 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED && HasEntProp(client, Prop_Send, "m_zombieClass") && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK;
}

int ResolveSurvivorAttacker(int attacker, int inflictor)
{
    if (IsRealSurvivor(attacker))
    {
        return attacker;
    }

    int owner = GetOwnerEntity(inflictor);
    if (IsRealSurvivor(owner))
    {
        return owner;
    }

    owner = GetOwnerEntity(attacker);
    if (IsRealSurvivor(owner))
    {
        return owner;
    }

    return 0;
}

int GetOwnerEntity(int entity)
{
    if (entity <= MaxClients || !IsValidEntity(entity))
    {
        return 0;
    }

    static const char properties[][] =
    {
        "m_hThrower",
        "m_hOwnerEntity",
        "m_hAttacker"
    };

    for (int i = 0; i < sizeof(properties); i++)
    {
        if (HasEntProp(entity, Prop_Data, properties[i]))
        {
            int owner = GetEntPropEnt(entity, Prop_Data, properties[i]);
            if (owner > 0)
            {
                return owner;
            }
        }
        if (HasEntProp(entity, Prop_Send, properties[i]))
        {
            int owner = GetEntPropEnt(entity, Prop_Send, properties[i]);
            if (owner > 0)
            {
                return owner;
            }
        }
    }

    return 0;
}
