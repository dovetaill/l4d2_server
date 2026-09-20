#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define MAX_SHOP_ITEMS 15

public Plugin myinfo =
{
    name = "L4D2 Campaign Shop",
    author = "Codex",
    description = "In-memory campaign-scoped PvE shop; no permanent progression",
    version = "1.0.0",
    url = ""
};

ConVar g_hEnabled;
ConVar g_hMaxPoints;
ConVar g_hNotify;
ConVar g_hCommonInterval;
ConVar g_hCommonReward;
ConVar g_hSpecialReward;
ConVar g_hWitchReward;
ConVar g_hTankReward;
ConVar g_hReviveReward;
ConVar g_hRescueReward;
ConVar g_hDefibReward;
ConVar g_hHealReward;

int g_iPoints[MAXPLAYERS + 1];
int g_iCommonKills[MAXPLAYERS + 1];
char g_sCampaign[64];

char g_sItemNames[MAX_SHOP_ITEMS][64] =
{
    "Pills",
    "Adrenaline",
    "Molotov",
    "Pipe Bomb",
    "Vomit Jar",
    "First Aid Kit",
    "Defibrillator",
    "AK47",
    "M16",
    "Auto Shotgun",
    "Military Sniper",
    "M60",
    "Grenade Launcher",
    "Incendiary Upgrade",
    "Explosive Upgrade"
};

char g_sItemClasses[MAX_SHOP_ITEMS][64] =
{
    "pain_pills",
    "adrenaline",
    "molotov",
    "pipe_bomb",
    "vomitjar",
    "first_aid_kit",
    "defibrillator",
    "rifle_ak47",
    "rifle",
    "autoshotgun",
    "sniper_military",
    "rifle_m60",
    "grenade_launcher",
    "weapon_upgradepack_incendiary",
    "weapon_upgradepack_explosive"
};

int g_iPrices[MAX_SHOP_ITEMS] =
{
    10,
    12,
    15,
    15,
    18,
    35,
    45,
    25,
    25,
    30,
    30,
    70,
    85,
    25,
    30
};

public void OnPluginStart()
{
    g_hEnabled = CreateConVar("l4d2_campaign_shop_enable", "1", "Enable the in-memory campaign shop.", _, true, 0.0, true, 1.0);
    g_hMaxPoints = CreateConVar("l4d2_campaign_shop_max_points", "250", "Maximum points held by one player during a campaign.", _, true, 0.0);
    g_hNotify = CreateConVar("l4d2_campaign_shop_notify", "1", "Show reward notices in chat.", _, true, 0.0, true, 1.0);
    g_hCommonInterval = CreateConVar("l4d2_campaign_shop_common_interval", "20", "Common infected kills needed for one reward.", _, true, 1.0);
    g_hCommonReward = CreateConVar("l4d2_campaign_shop_common_reward", "4", "Points for each common-infected reward interval.", _, true, 0.0);
    g_hSpecialReward = CreateConVar("l4d2_campaign_shop_special_reward", "3", "Points for a special infected kill.", _, true, 0.0);
    g_hWitchReward = CreateConVar("l4d2_campaign_shop_witch_reward", "8", "Points for killing a Witch.", _, true, 0.0);
    g_hTankReward = CreateConVar("l4d2_campaign_shop_tank_reward", "22", "Points for killing a Tank.", _, true, 0.0);
    g_hReviveReward = CreateConVar("l4d2_campaign_shop_revive_reward", "5", "Points for reviving an incapacitated teammate.", _, true, 0.0);
    g_hRescueReward = CreateConVar("l4d2_campaign_shop_rescue_reward", "3", "Points for rescuing a hanging teammate.", _, true, 0.0);
    g_hDefibReward = CreateConVar("l4d2_campaign_shop_defib_reward", "10", "Points for using a defibrillator.", _, true, 0.0);
    g_hHealReward = CreateConVar("l4d2_campaign_shop_heal_reward", "5", "Points for healing a teammate.", _, true, 0.0);

    RegPluginLibrary("l4d2_campaign_shop");
    CreateNative("L4D2CampaignShop_GetPoints", Native_GetPoints);
    CreateNative("L4D2CampaignShop_AddPoints", Native_AddPoints);
    CreateNative("L4D2CampaignShop_RemovePoints", Native_RemovePoints);
    CreateNative("L4D2CampaignShop_SetPoints", Native_SetPoints);

    RegConsoleCmd("sm_buy", Command_Buy, "Open the campaign shop.");
    RegConsoleCmd("sm_shop", Command_Buy, "Open the campaign shop.");
    RegConsoleCmd("sm_points", Command_Points, "Show current campaign points.");
    RegConsoleCmd("sm_money", Command_Points, "Show current campaign points.");

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("infected_death", Event_InfectedDeath, EventHookMode_Post);
    HookEvent("witch_killed", Event_WitchKilled, EventHookMode_Post);
    HookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Post);
    HookEvent("defibrillator_used", Event_DefibrillatorUsed, EventHookMode_Post);
    HookEvent("heal_success", Event_HealSuccess, EventHookMode_Post);
    HookEvent("player_ledge_grab", Event_LedgeGrab, EventHookMode_Post);
    HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);

    AutoExecConfig(true, "l4d2_campaign_shop");
}

public void OnMapStart()
{
    char map[64], campaign[64];
    GetCurrentMap(map, sizeof(map));
    GetCampaignKey(map, campaign, sizeof(campaign));

    if (g_sCampaign[0] != '\0' && !StrEqual(g_sCampaign, campaign))
    {
        ResetPoints();
    }
    strcopy(g_sCampaign, sizeof(g_sCampaign), campaign);
}

public void OnClientPutInServer(int client)
{
    g_iPoints[client] = 0;
    g_iCommonKills[client] = 0;
}

public void OnClientDisconnect(int client)
{
    g_iPoints[client] = 0;
    g_iCommonKills[client] = 0;
}

public Action Command_Buy(int client, int args)
{
    if (!g_hEnabled.BoolValue)
    {
        ReplyToCommand(client, "[BUY] Shop is disabled.");
        return Plugin_Handled;
    }
    if (!IsRealSurvivor(client))
    {
        ReplyToCommand(client, "[BUY] Join the Survivor team first.");
        return Plugin_Handled;
    }

    ShowShop(client);
    return Plugin_Handled;
}

public Action Command_Points(int client, int args)
{
    if (!IsValidClient(client))
    {
        return Plugin_Handled;
    }

    ReplyToCommand(client, "[BUY] Campaign points: %d", g_iPoints[client]);
    return Plugin_Handled;
}

void ShowShop(int client)
{
    Menu menu = new Menu(MenuHandler_Buy);
    char title[128];
    Format(title, sizeof(title), "Campaign Shop | Points: %d", g_iPoints[client]);
    menu.SetTitle(title);

    char info[16], display[128];
    for (int i = 0; i < MAX_SHOP_ITEMS; i++)
    {
        IntToString(i, info, sizeof(info));
        Format(display, sizeof(display), "%s - %d points", g_sItemNames[i], g_iPrices[i]);
        menu.AddItem(info, display);
    }

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Buy(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(item, info, sizeof(info));
        BuyItem(client, StringToInt(info));
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void BuyItem(int client, int item)
{
    if (!IsRealSurvivor(client) || item < 0 || item >= MAX_SHOP_ITEMS)
    {
        return;
    }

    int price = g_iPrices[item];
    if (g_iPoints[client] < price)
    {
        PrintToChat(client, "\x04[BUY]\x01 Not enough points. Need %d, have %d.", price, g_iPoints[client]);
        return;
    }

    char classname[64];
    strcopy(classname, sizeof(classname), g_sItemClasses[item]);
    TrimString(classname);
    int entity = GivePlayerItem(client, classname);
    if (entity == -1)
    {
        PrintToChat(client, "\x04[BUY]\x01 Could not give %s. Your inventory may be full.", g_sItemNames[item]);
        return;
    }

    g_iPoints[client] -= price;
    PrintToChat(client, "\x04[BUY]\x01 Purchased %s for %d points. Balance: %d.", g_sItemNames[item], price, g_iPoints[client]);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = ResolveEventClient(event, "attacker");
    if (!IsRealSurvivor(attacker) || victim <= 0 || !IsClientInGame(victim) || GetClientTeam(victim) != TEAM_INFECTED)
    {
        return;
    }

    int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
    if (zombieClass == 8)
    {
        AddPoints(attacker, g_hTankReward.IntValue, "Tank");
    }
    else if (zombieClass > 0)
    {
        AddPoints(attacker, g_hSpecialReward.IntValue, "Special Infected");
    }
}

public void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = ResolveEventClient(event, "attacker");
    if (!IsRealSurvivor(attacker))
    {
        return;
    }

    g_iCommonKills[attacker]++;
    int interval = g_hCommonInterval.IntValue;
    if (g_iCommonKills[attacker] >= interval)
    {
        g_iCommonKills[attacker] -= interval;
        AddPoints(attacker, g_hCommonReward.IntValue, "Common interval");
    }
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = ResolveEventClient(event, "userid");
    if (attacker <= 0)
    {
        attacker = ResolveEventClient(event, "attacker");
    }
    if (IsRealSurvivor(attacker))
    {
        AddPoints(attacker, g_hWitchReward.IntValue, "Witch");
    }
}

public void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
    int client = ResolveEventClient(event, "userid");
    if (IsRealSurvivor(client))
    {
        AddPoints(client, g_hReviveReward.IntValue, "Revive");
    }
}

public void Event_DefibrillatorUsed(Event event, const char[] name, bool dontBroadcast)
{
    int client = ResolveEventClient(event, "userid");
    if (IsRealSurvivor(client))
    {
        AddPoints(client, g_hDefibReward.IntValue, "Defib");
    }
}

public void Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
    int client = ResolveEventClient(event, "userid");
    if (IsRealSurvivor(client))
    {
        AddPoints(client, g_hHealReward.IntValue, "Heal");
    }
}

public void Event_LedgeGrab(Event event, const char[] name, bool dontBroadcast)
{
    int client = ResolveEventClient(event, "userid");
    if (IsRealSurvivor(client))
    {
        AddPoints(client, g_hRescueReward.IntValue, "Ledge rescue");
    }
}

public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast)
{
    ResetPoints();
}

void AddPoints(int client, int amount, const char[] reason)
{
    if (!IsRealPlayer(client) || amount <= 0)
    {
        return;
    }

    int oldPoints = g_iPoints[client];
    g_iPoints[client] = oldPoints + amount;
    if (g_iPoints[client] > g_hMaxPoints.IntValue)
    {
        g_iPoints[client] = g_hMaxPoints.IntValue;
    }

    int gained = g_iPoints[client] - oldPoints;
    if (g_hNotify.BoolValue && gained > 0)
    {
        PrintToChat(client, "\x04[BUY]\x01 +%d points (%s). Balance: %d.", gained, reason, g_iPoints[client]);
    }
}

void ResetPoints()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iPoints[i] = 0;
        g_iCommonKills[i] = 0;
    }
}

int ResolveEventClient(Event event, const char[] field)
{
    int raw = event.GetInt(field);
    if (raw > 0 && raw <= MaxClients && IsClientInGame(raw))
    {
        return raw;
    }

    int client = GetClientOfUserId(raw);
    if (client > 0 && client <= MaxClients && IsClientInGame(client))
    {
        return client;
    }
    return 0;
}

void GetCampaignKey(const char[] map, char[] key, int maxlen)
{
    strcopy(key, maxlen, map);
    int marker = FindCharInString(key, 'm');
    if (marker > 0)
    {
        key[marker] = '\0';
    }
}

bool IsRealSurvivor(int client)
{
    return IsValidClient(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool IsRealPlayer(int client)
{
    if (!IsValidClient(client) || IsFakeClient(client))
    {
        return false;
    }

    int team = GetClientTeam(client);
    return team == TEAM_SURVIVOR || team == TEAM_INFECTED;
}

bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

public any Native_GetPoints(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsRealPlayer(client))
    {
        return -1;
    }
    return g_iPoints[client];
}

public any Native_AddPoints(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int amount = GetNativeCell(2);
    if (!IsRealPlayer(client) || amount <= 0)
    {
        return -1;
    }

    AddPoints(client, amount, "Admin");
    return g_iPoints[client];
}

public any Native_RemovePoints(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int amount = GetNativeCell(2);
    if (!IsRealPlayer(client) || amount <= 0)
    {
        return -1;
    }

    g_iPoints[client] -= amount;
    if (g_iPoints[client] < 0)
    {
        g_iPoints[client] = 0;
    }
    return g_iPoints[client];
}

public any Native_SetPoints(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int points = GetNativeCell(2);
    if (!IsRealPlayer(client))
    {
        return -1;
    }

    if (points < 0)
    {
        points = 0;
    }
    if (points > g_hMaxPoints.IntValue)
    {
        points = g_hMaxPoints.IntValue;
    }
    g_iPoints[client] = points;
    return points;
}
