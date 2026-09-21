#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4dinfectedbots>
#include <l4d2_campaign_shop>
#include <l4d2_playable_witch>
#include <l4d2_pve_mutant_tanks>

#define PLUGIN_VERSION "0.1.1"

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

#define ZC_SMOKER 1
#define ZC_BOOMER 2
#define ZC_HUNTER 3
#define ZC_SPITTER 4
#define ZC_JOCKEY 5
#define ZC_CHARGER 6
#define ZC_WITCH 7
#define ZC_TANK 8

#define SI_FIRST ZC_SMOKER
#define SI_LAST ZC_CHARGER
#define SI_CLASS_COUNT 6

public Plugin myinfo =
{
    name = "L4D2 PvE Infected Core",
    author = "Codex",
    description = "Campaign PvPvE team switching, human SI classes, points, Tank lottery and HUD.",
    version = PLUGIN_VERSION,
    url = ""
};

ConVar g_cvEnabled;
ConVar g_cvGameMode;
ConVar g_cvHumanLimit;
ConVar g_cvSwitchCooldown;
ConVar g_cvRecentDamageLock;
ConVar g_cvSIHealthMultiplier;
ConVar g_cvSICooldownMultiplier;
ConVar g_cvSIRespawnSeconds;
ConVar g_cvTankHealthMultiplier;
ConVar g_cvTankLimit;
ConVar g_cvTankSpawnMinInterval;
ConVar g_cvTankHumanPerChapter;
ConVar g_cvTankPlayerPerChapter;
ConVar g_cvTankPlayerCooldown;
ConVar g_cvAdminSpawnBypass;
ConVar g_cvLifeHealthCost;
ConVar g_cvLifeCooldownCost;
ConVar g_cvGhostCost;
ConVar g_cvRefreshCost;
ConVar g_cvTankPriorityCost;
ConVar g_cvTankArrivalCost;
ConVar g_cvTankArrivalPerCampaign;
ConVar g_cvTankArrivalPerPlayer;
ConVar g_cvWitchCost;
ConVar g_cvWitchChance;
ConVar g_cvHUD;
ConVar g_cvHUDRate;
ConVar g_cvPointsDamageInterval;
ConVar g_cvPointsDamageCap;
ConVar g_cvRewardPin;
ConVar g_cvRewardIncap;
ConVar g_cvRewardKill;
ConVar g_cvRewardTankIncap;
ConVar g_cvRewardTankKill;
ConVar g_cvClassLimit[SI_CLASS_COUNT];

bool g_bTankQueue[MAXPLAYERS + 1];
bool g_bTankPriority[MAXPLAYERS + 1];
bool g_bTankControl[MAXPLAYERS + 1];
bool g_bLifeHealthBoost[MAXPLAYERS + 1];
bool g_bLifeCooldownBoost[MAXPLAYERS + 1];
bool g_bLifeGhostBoost[MAXPLAYERS + 1];
bool g_bBoughtWitch[MAXPLAYERS + 1];
bool g_bBoughtTankArrival[MAXPLAYERS + 1];
bool g_bTankRecent[MAXPLAYERS + 1];
bool g_bBalanceApplied[MAXPLAYERS + 1];

int g_iSurvivorBot[MAXPLAYERS + 1];
int g_iTankSurvivorBot[MAXPLAYERS + 1];
int g_iDamageProgress[MAXPLAYERS + 1];
int g_iDamageRewarded[MAXPLAYERS + 1];
int g_iTankArrivals;
int g_iPendingTankBuyer;
int g_iHumanTankControlsThisChapter;

float g_fLastDamage[MAXPLAYERS + 1];
float g_fLastTankSpawnTime;
float g_fLastSwitch[MAXPLAYERS + 1];
float g_fScaledAbilityEnd[MAXPLAYERS + 1];
float g_fNextHUD;

bool g_bLeftSafeArea;
bool g_bFinaleLocked;
char g_sCampaign[64];
StringMap g_hSwitchCooldown;
StringMap g_hTankChapterCount;
StringMap g_hTankControlLast;
Handle g_hHUDTimer;

static const char g_sClassNames[SI_CLASS_COUNT][] =
{
    "Smoker",
    "Boomer",
    "Hunter",
    "Spitter",
    "Jockey",
    "Charger"
};

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar("l4d2_pve_infected_enable", "1", "Enable the Campaign PvPvE infected core.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvGameMode = FindConVar("mp_gamemode");
    g_cvHumanLimit = CreateConVar("l4d2_pve_infected_human_limit", "4", "Maximum human infected players, also bounded by survivor count.", FCVAR_NOTIFY, true, 0.0, true, 8.0);
    g_cvSwitchCooldown = CreateConVar("l4d2_pve_infected_switch_cooldown", "90.0", "Seconds between voluntary team changes.", FCVAR_NOTIFY, true, 0.0);
    g_cvRecentDamageLock = CreateConVar("l4d2_pve_infected_recent_damage_lock", "5.0", "Seconds after taking or dealing damage during which team switching is blocked.", FCVAR_NOTIFY, true, 0.0);
    g_cvSIHealthMultiplier = CreateConVar("l4d2_pve_infected_si_health_multiplier", "1.30", "Health multiplier for human controlled ordinary SI.", FCVAR_NOTIFY, true, 1.0);
    g_cvSICooldownMultiplier = CreateConVar("l4d2_pve_infected_si_cooldown_multiplier", "0.85", "Ability cooldown multiplier for human controlled ordinary SI.", FCVAR_NOTIFY, true, 0.1, true, 2.0);
    g_cvSIRespawnSeconds = CreateConVar("l4d2_pve_infected_si_respawn_seconds", "22.0", "Target Ghost respawn wait for human SI.", FCVAR_NOTIFY, true, 0.0);
    g_cvTankHealthMultiplier = CreateConVar("l4d2_pve_infected_tank_health_multiplier", "1.15", "Optional health multiplier for a human controlled Tank.", FCVAR_NOTIFY, true, 1.0);
    g_cvTankLimit = CreateConVar("l4d2_pve_infected_tank_limit", "1", "Maximum simultaneous Tanks allowed by the custom core.", FCVAR_NOTIFY, true, 0.0, true, 8.0);
    g_cvTankSpawnMinInterval = CreateConVar("l4d2_pve_infected_tank_spawn_min_interval", "600.0", "Minimum seconds between non-finale Tank spawns, including purchased Tanks.", FCVAR_NOTIFY, true, 0.0);
    g_cvTankHumanPerChapter = CreateConVar("l4d2_pve_infected_tank_human_per_chapter", "1", "Maximum Tanks handed to human players per chapter. Zero disables human Tank control.", FCVAR_NOTIFY, true, 0.0, true, 8.0);
    g_cvTankPlayerPerChapter = CreateConVar("l4d2_pve_infected_tank_player_per_chapter", "1", "Maximum Tank controls per player per chapter. Zero disables human Tank control.", FCVAR_NOTIFY, true, 0.0, true, 8.0);
    g_cvTankPlayerCooldown = CreateConVar("l4d2_pve_infected_tank_player_cooldown", "1800.0", "Seconds before the same player may control another Tank across chapter transitions.", FCVAR_NOTIFY, true, 0.0);
    g_cvAdminSpawnBypass = CreateConVar("l4d2_pve_infected_admin_spawn_bypass", "0", "Internal one-shot bypass for administrator-forced Tank spawns.", FCVAR_DONTRECORD, true, 0.0, true, 1.0);
    HookConVarChange(g_cvTankSpawnMinInterval, ConVarChanged_TankSpawnMinInterval);
    g_cvLifeHealthCost = CreateConVar("l4d2_pve_infected_life_health_cost", "25", "Campaign points for current-life SI health boost.", FCVAR_NOTIFY, true, 0.0);
    g_cvLifeCooldownCost = CreateConVar("l4d2_pve_infected_life_cooldown_cost", "30", "Campaign points for current-life SI cooldown boost.", FCVAR_NOTIFY, true, 0.0);
    g_cvGhostCost = CreateConVar("l4d2_pve_infected_ghost_cost", "25", "Campaign points for the current-life Ghost wait reduction.", FCVAR_NOTIFY, true, 0.0);
    g_cvRefreshCost = CreateConVar("l4d2_pve_infected_refresh_cost", "35", "Campaign points for one immediate SI ability refresh.", FCVAR_NOTIFY, true, 0.0);
    g_cvTankPriorityCost = CreateConVar("l4d2_pve_infected_tank_priority_cost", "220", "Campaign points for Next Tank Priority.", FCVAR_NOTIFY, true, 0.0);
    g_cvTankArrivalCost = CreateConVar("l4d2_pve_infected_tank_arrival_cost", "320", "Campaign points for Tank Arrival.", FCVAR_NOTIFY, true, 0.0);
    g_cvTankArrivalPerCampaign = CreateConVar("l4d2_pve_infected_tank_arrival_per_campaign", "1", "Maximum purchased Tank Arrivals per campaign.", FCVAR_NOTIFY, true, 0.0, true, 4.0);
    g_cvTankArrivalPerPlayer = CreateConVar("l4d2_pve_infected_tank_arrival_per_player", "1", "Maximum purchased Tank Arrivals per player per campaign.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
    g_cvWitchCost = CreateConVar("l4d2_pve_infected_witch_cost", "150", "Campaign points for experimental Witch control.", FCVAR_NOTIFY, true, 0.0);
    g_cvWitchChance = CreateConVar("l4d2_pve_infected_witch_chance", "2.5", "Reserved chance for experimental Witch selection; requires a playable Witch module.", FCVAR_NOTIFY, true, 0.0, true, 100.0);
    HookConVarChange(g_cvWitchChance, ConVarChanged_WitchChance);
    g_cvHUD = CreateConVar("l4d2_pve_infected_hud", "1", "Show the infected PvPvE HUD.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvHUDRate = CreateConVar("l4d2_pve_infected_hud_rate", "0.50", "HUD refresh interval in seconds.", FCVAR_NOTIFY, true, 0.25, true, 4.0);
    g_cvPointsDamageInterval = CreateConVar("l4d2_pve_infected_damage_points_interval", "100", "Human survivor damage needed for one infected point.", FCVAR_NOTIFY, true, 1.0);
    g_cvPointsDamageCap = CreateConVar("l4d2_pve_infected_damage_points_cap", "10", "Maximum damage-only points per infected life.", FCVAR_NOTIFY, true, 0.0);
    g_cvRewardPin = CreateConVar("l4d2_pve_infected_reward_pin", "2", "Points for a successful human SI pin.", FCVAR_NOTIFY, true, 0.0);
    g_cvRewardIncap = CreateConVar("l4d2_pve_infected_reward_incap", "5", "Points for causing an incap.", FCVAR_NOTIFY, true, 0.0);
    g_cvRewardKill = CreateConVar("l4d2_pve_infected_reward_kill", "10", "Points for killing a human Survivor.", FCVAR_NOTIFY, true, 0.0);
    g_cvRewardTankIncap = CreateConVar("l4d2_pve_infected_reward_tank_incap", "8", "Points for a Tank causing an incap.", FCVAR_NOTIFY, true, 0.0);
    g_cvRewardTankKill = CreateConVar("l4d2_pve_infected_reward_tank_kill", "15", "Points for a Tank killing a human Survivor.", FCVAR_NOTIFY, true, 0.0);

    g_cvClassLimit[0] = CreateConVar("l4d2_pve_infected_smoker_limit", "2", "Human plus AI Smoker class limit.", FCVAR_NOTIFY, true, 0.0);
    g_cvClassLimit[1] = CreateConVar("l4d2_pve_infected_boomer_limit", "2", "Human plus AI Boomer class limit.", FCVAR_NOTIFY, true, 0.0);
    g_cvClassLimit[2] = CreateConVar("l4d2_pve_infected_hunter_limit", "3", "Human plus AI Hunter class limit.", FCVAR_NOTIFY, true, 0.0);
    g_cvClassLimit[3] = CreateConVar("l4d2_pve_infected_spitter_limit", "2", "Human plus AI Spitter class limit.", FCVAR_NOTIFY, true, 0.0);
    g_cvClassLimit[4] = CreateConVar("l4d2_pve_infected_jockey_limit", "2", "Human plus AI Jockey class limit.", FCVAR_NOTIFY, true, 0.0);
    g_cvClassLimit[5] = CreateConVar("l4d2_pve_infected_charger_limit", "2", "Human plus AI Charger class limit.", FCVAR_NOTIFY, true, 0.0);

    AddCommandListener(CommandListener_JoinInfected, "sm_infected");
    AddCommandListener(CommandListener_JoinInfected, "sm_inf");
    AddCommandListener(CommandListener_JoinInfected, "sm_特感");
    AddCommandListener(CommandListener_JoinSurvivor, "sm_survivor");
    AddCommandListener(CommandListener_JoinSurvivor, "sm_人类");
    RegConsoleCmd("sm_zclass", Command_ZClass, "Choose an ordinary Special Infected class.");
    RegConsoleCmd("sm_特感选择", Command_ZClass, "Choose an ordinary Special Infected class.");
    RegConsoleCmd("sm_tankqueue", Command_TankQueue, "Join the Tank lottery.");
    RegConsoleCmd("sm_notank", Command_NoTank, "Leave the Tank lottery.");

    AddCommandListener(CommandListener_Buy, "sm_buy");
    AddCommandListener(CommandListener_Buy, "sm_shop");

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
    HookEvent("finale_win", Event_FinaleWin, EventHookMode_PostNoCopy);
    HookEvent("finale_start", Event_FinaleStart, EventHookMode_PostNoCopy);
    HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving, EventHookMode_PostNoCopy);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
    HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_Post);
    HookEvent("ghost_spawn_time", Event_GhostSpawnTime, EventHookMode_Post);
    HookEvent("player_left_start_area", Event_LeftStartArea, EventHookMode_PostNoCopy);

    g_hSwitchCooldown = new StringMap();
    g_hTankChapterCount = new StringMap();
    g_hTankControlLast = new StringMap();
    g_hHUDTimer = CreateTimer(0.25, Timer_HUD, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    AutoExecConfig(true, "l4d2_pve_infected_core");
    ApplyTankDirectorInterval();
    ServerCommand("exec sourcemod/pve_infected_balance.cfg");
}

public void ConVarChanged_TankSpawnMinInterval(ConVar convar, const char[] oldValue, const char[] newValue)
{
    ApplyTankDirectorInterval();
}

public void OnAllPluginsLoaded()
{
    ApplyPlayableWitchChance();
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "l4d2_playable_witch"))
    {
        ApplyPlayableWitchChance();
    }
}

public void ConVarChanged_WitchChance(ConVar convar, const char[] oldValue, const char[] newValue)
{
    ApplyPlayableWitchChance();
}

void ApplyPlayableWitchChance()
{
    ConVar playableChance = FindConVar("pve_playable_witch_random_chance");
    if (playableChance != null)
    {
        playableChance.SetFloat(g_cvWitchChance.FloatValue);
    }
}

void ApplyTankDirectorInterval()
{
    float interval = g_cvTankSpawnMinInterval.FloatValue;
    ConVar directorMin = FindConVar("director_tank_min_interval");
    if (directorMin != null && interval > 0.0)
    {
        directorMin.SetFloat(interval);
    }

    ConVar directorMax = FindConVar("director_tank_max_interval");
    if (directorMax != null && interval > 0.0 && directorMax.FloatValue < interval)
    {
        directorMax.SetFloat(interval);
    }
}

public void OnPluginEnd()
{
    delete g_hSwitchCooldown;
    delete g_hTankChapterCount;
    delete g_hTankControlLast;
    delete g_hHUDTimer;
}

public void OnMapStart()
{
    char map[64], campaign[64];
    GetCurrentMap(map, sizeof(map));
    GetCampaignKey(map, campaign, sizeof(campaign));

    if (g_sCampaign[0] != '\0' && !StrEqual(g_sCampaign, campaign))
    {
        ResetCampaignState();
    }
    else
    {
        ResetChapterState();
    }
    strcopy(g_sCampaign, sizeof(g_sCampaign), campaign);
    g_bLeftSafeArea = false;
    g_bFinaleLocked = false;
    g_fLastTankSpawnTime = 0.0;
    g_iPendingTankBuyer = 0;
}

public void OnClientPutInServer(int client)
{
    g_bTankQueue[client] = true;
    g_bTankPriority[client] = false;
    g_bTankControl[client] = false;
    g_bLifeHealthBoost[client] = false;
    g_bLifeCooldownBoost[client] = false;
    g_bLifeGhostBoost[client] = false;
    g_bBoughtWitch[client] = false;
    g_bBoughtTankArrival[client] = false;
    g_bTankRecent[client] = false;
    g_bBalanceApplied[client] = false;
    g_iSurvivorBot[client] = 0;
    g_iTankSurvivorBot[client] = 0;
    g_iDamageProgress[client] = 0;
    g_iDamageRewarded[client] = 0;
    g_fLastDamage[client] = 0.0;
    g_fLastSwitch[client] = 0.0;
    g_fScaledAbilityEnd[client] = 0.0;
}

public void OnClientDisconnect(int client)
{
    g_iSurvivorBot[client] = 0;
    g_iTankSurvivorBot[client] = 0;
    g_bTankControl[client] = false;
    if (g_iPendingTankBuyer == client)
    {
        g_iPendingTankBuyer = 0;
    }
}

public Action Command_JoinInfected(int client, int args)
{
    if (!CanUseCore(client) || GetClientTeam(client) != TEAM_SURVIVOR)
    {
        return Plugin_Handled;
    }

    if (!CanSwitchTeam(client, true))
    {
        return Plugin_Handled;
    }

    int limit = GetDynamicHumanLimit();
    if (CountRealInfected() >= limit)
    {
        PrintToChat(client, "\x04[感染者]\x01 当前真人感染者上限为 %d。", limit);
        return Plugin_Handled;
    }

    int bot = FindSurvivorBotForClient(client);
    if (bot == 0)
    {
        L4D_ReplaceWithBot(client);
        bot = FindSurvivorBotForClient(client);
        if (bot == 0)
        {
            bot = FindFreeSurvivorBot();
        }
    }
    g_iSurvivorBot[client] = bot;
    g_fLastSwitch[client] = GetGameTime();
    RememberSwitchCooldown(client);

    FakeClientCommand(client, "sm_ji");
    CreateTimer(0.35, Timer_ConfirmInfected, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    PrintToChat(client, "\x04[感染者]\x01 已申请加入感染者阵营。Survivor Bot 将继续推进战役。\x03 !zclass\x01 选择职业。\x04 !buy\x01 打开感染者商城。");
    return Plugin_Handled;
}

public Action CommandListener_JoinInfected(int client, const char[] command, int argc)
{
    if (!IsEligibleRealPlayer(client) || GetClientTeam(client) != TEAM_SURVIVOR)
    {
        return Plugin_Continue;
    }
    if (!CanUseCore(client))
    {
        return Plugin_Continue;
    }
    return Command_JoinInfected(client, argc);
}

public Action Command_JoinSurvivor(int client, int args)
{
    if (!CanUseCore(client) || GetClientTeam(client) != TEAM_INFECTED)
    {
        return Plugin_Handled;
    }

    if (!CanSwitchTeam(client, false))
    {
        return Plugin_Handled;
    }

    int bot = g_iSurvivorBot[client];
    if (!IsFreeSurvivorBot(bot))
    {
        bot = FindFreeSurvivorBot();
    }
    if (bot == 0)
    {
        PrintToChat(client, "\x04[感染者]\x01 当前没有可接管的 Survivor Bot。");
        return Plugin_Handled;
    }

    ChangeClientTeam(client, TEAM_SPECTATOR);
    L4D_SetHumanSpec(bot, client);
    L4D_TakeOverBot(client);
    g_iSurvivorBot[client] = 0;
    g_fLastSwitch[client] = GetGameTime();
    RememberSwitchCooldown(client);
    PrintToChat(client, "\x04[人类]\x01 已接回 Survivor Bot。");
    return Plugin_Handled;
}

public Action CommandListener_JoinSurvivor(int client, const char[] command, int argc)
{
    if (!IsEligibleRealPlayer(client) || GetClientTeam(client) != TEAM_INFECTED)
    {
        return Plugin_Continue;
    }
    if (!CanUseCore(client))
    {
        return Plugin_Continue;
    }
    return Command_JoinSurvivor(client, argc);
}

public Action Command_ZClass(int client, int args)
{
    if (!CanUseCore(client) || GetClientTeam(client) != TEAM_INFECTED || IsPlayerTank(client) || !CanChooseClass(client))
    {
        if (IsValidClient(client))
        {
            PrintToChat(client, "\x04[感染者]\x01 只有普通感染者 Ghost 或复活阶段可以选择职业。");
        }
        return Plugin_Handled;
    }

    Menu menu = new Menu(MenuHandler_ZClass);
    menu.SetTitle("普通特感职业 | 免费选择");
    char info[8], display[64];
    for (int i = 0; i < SI_CLASS_COUNT; i++)
    {
        IntToString(i + SI_FIRST, info, sizeof(info));
        Format(display, sizeof(display), "%s | %d/%d", g_sClassNames[i], CountClass(i + SI_FIRST), g_cvClassLimit[i].IntValue);
        menu.AddItem(info, display, CountClass(i + SI_FIRST) >= g_cvClassLimit[i].IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    }
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public int MenuHandler_ZClass(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char info[8];
        menu.GetItem(item, info, sizeof(info));
        SelectClass(client, StringToInt(info));
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public Action Command_TankQueue(int client, int args)
{
    if (!IsEligibleRealPlayer(client))
    {
        return Plugin_Handled;
    }
    g_bTankQueue[client] = true;
    PrintToChat(client, "\x04[TANK]\x01 你已加入 Tank 抽签池。");
    return Plugin_Handled;
}

public Action Command_NoTank(int client, int args)
{
    if (!IsEligibleRealPlayer(client))
    {
        return Plugin_Handled;
    }
    g_bTankQueue[client] = false;
    PrintToChat(client, "\x04[TANK]\x01 你已退出 Tank 抽签池。");
    return Plugin_Handled;
}

public Action CommandListener_Buy(int client, const char[] command, int argc)
{
    if (!IsEligibleRealPlayer(client) || GetClientTeam(client) != TEAM_INFECTED)
    {
        return Plugin_Continue;
    }

    ShowInfectedShop(client);
    return Plugin_Handled;
}

void ShowInfectedShop(int client)
{
    Menu menu = new Menu(MenuHandler_InfectedShop);
    char title[128], display[128];
    Format(title, sizeof(title), "感染者商城 | 积分: %d", GetPoints(client));
    menu.SetTitle(title);

    Format(display, sizeof(display), "本次生命 HP +25%% | %d", g_cvLifeHealthCost.IntValue);
    menu.AddItem("hp", display);
    Format(display, sizeof(display), "本次生命技能 CD -15%% | %d", g_cvLifeCooldownCost.IntValue);
    menu.AddItem("cd", display);
    Format(display, sizeof(display), "缩短当前 Ghost 等待 | %d", g_cvGhostCost.IntValue);
    menu.AddItem("ghost", display);
    Format(display, sizeof(display), "当前技能立即恢复一次 | %d", g_cvRefreshCost.IntValue);
    menu.AddItem("refresh", display);
    Format(display, sizeof(display), "Witch 控制权 [实验模块] | %d", g_cvWitchCost.IntValue);
    menu.AddItem("witch", display, IsPlayableWitchAvailable() ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    Format(display, sizeof(display), "下一只 Tank 优先权 | %d", g_cvTankPriorityCost.IntValue);
    menu.AddItem("priority", display);
    Format(display, sizeof(display), "Tank 降临 | %d", g_cvTankArrivalCost.IntValue);
    menu.AddItem("arrival", display);
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_InfectedShop(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(item, info, sizeof(info));
        BuyInfectedItem(client, info);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void BuyInfectedItem(int client, const char[] item)
{
    if (!IsEligibleRealPlayer(client) || GetClientTeam(client) != TEAM_INFECTED)
    {
        return;
    }

    int price = 0;
    if (StrEqual(item, "hp"))
    {
        price = g_cvLifeHealthCost.IntValue;
        if (g_bLifeHealthBoost[client])
        {
            PrintToChat(client, "\x04[感染者]\x01 本次生命 HP 强化已经购买。");
            return;
        }
    }
    else if (StrEqual(item, "cd"))
    {
        price = g_cvLifeCooldownCost.IntValue;
        if (g_bLifeCooldownBoost[client])
        {
            PrintToChat(client, "\x04[感染者]\x01 本次生命技能强化已经购买。");
            return;
        }
    }
    else if (StrEqual(item, "ghost"))
    {
        price = g_cvGhostCost.IntValue;
        if (g_bLifeGhostBoost[client])
        {
            PrintToChat(client, "\x04[感染者]\x01 Ghost 强化已经购买。");
            return;
        }
    }
    else if (StrEqual(item, "refresh"))
    {
        price = g_cvRefreshCost.IntValue;
        if (!IsPlayerAlive(client) || IsPlayerGhost(client))
        {
            PrintToChat(client, "\x04[感染者]\x01 只有已进场的普通特感才能恢复技能。");
            return;
        }
    }
    else if (StrEqual(item, "witch"))
    {
        price = g_cvWitchCost.IntValue;
        if (!IsPlayableWitchAvailable())
        {
            PrintToChat(client, "\x04[感染者]\x01 Playable Witch 模块当前关闭，未扣分。");
            return;
        }
        if (g_bBoughtWitch[client])
        {
            PrintToChat(client, "\x04[感染者]\x01 本章节已经购买过 Witch。");
            return;
        }
    }
    else if (StrEqual(item, "priority"))
    {
        price = g_cvTankPriorityCost.IntValue;
        if (g_bTankPriority[client])
        {
            PrintToChat(client, "\x04[TANK]\x01 你已经拥有 Tank 优先权。");
            return;
        }
    }
    else if (StrEqual(item, "arrival"))
    {
        price = g_cvTankArrivalCost.IntValue;
        if (g_cvTankArrivalPerPlayer.IntValue <= 0 || g_bBoughtTankArrival[client] || g_iTankArrivals >= g_cvTankArrivalPerCampaign.IntValue)
        {
            PrintToChat(client, "\x04[TANK]\x01 本章节 Tank 降临次数已用完。");
            return;
        }
        if (!CanSpawnPurchasedTank(client))
        {
            PrintToChat(client, "\x04[TANK]\x01 当前阶段不允许额外生成 Tank，未扣分。");
            return;
        }
    }
    else
    {
        return;
    }

    if (GetPoints(client) < price)
    {
        PrintToChat(client, "\x04[感染者]\x01 积分不足，需要 %d，当前 %d。", price, GetPoints(client));
        return;
    }
    if (RemovePoints(client, price) < 0)
    {
        PrintToChat(client, "\x04[感染者]\x01 商城积分接口不可用，未完成购买。");
        return;
    }

    if (StrEqual(item, "hp"))
    {
        g_bLifeHealthBoost[client] = true;
        ApplyLifeHealthBoost(client);
    }
    else if (StrEqual(item, "cd"))
    {
        g_bLifeCooldownBoost[client] = true;
        ApplyCurrentCooldownReduction(client);
    }
    else if (StrEqual(item, "ghost"))
    {
        g_bLifeGhostBoost[client] = true;
    }
    else if (StrEqual(item, "refresh"))
    {
        if (!RefreshAbility(client))
        {
            AddPoints(client, price);
            g_fScaledAbilityEnd[client] = 0.0;
            PrintToChat(client, "\x04[感染者]\x01 当前职业没有可恢复的技能，积分已退回。");
            return;
        }
    }
    else if (StrEqual(item, "witch"))
    {
        if (!L4D2PlayableWitch_Request(client, PlayableWitchSource_Purchase))
        {
            AddPoints(client, price);
            PrintToChat(client, "\x04[感染者]\x01 Witch 实体控制启动失败，积分已退回。\x01");
            return;
        }
        g_bBoughtWitch[client] = true;
    }
    else if (StrEqual(item, "priority"))
    {
        g_bTankPriority[client] = true;
        g_bTankQueue[client] = true;
    }
    else if (StrEqual(item, "arrival"))
    {
        g_bBoughtTankArrival[client] = true;
        if (!SpawnPurchasedTank(client))
        {
            AddPoints(client, price);
            g_bBoughtTankArrival[client] = false;
            PrintToChat(client, "\x04[TANK]\x01 Tank 生成失败，积分已退回。");
            return;
        }
        g_iTankArrivals++;
    }
    PrintToChat(client, "\x04[感染者]\x01 购买成功：%s。余额 %d。", item, GetPoints(client));
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bFinaleLocked = false;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bFinaleLocked = true;
}

public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast)
{
    ResetCampaignState();
}

public void Event_FinaleWin(Event event, const char[] name, bool dontBroadcast)
{
    g_bFinaleLocked = true;
}

public void Event_FinaleStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bFinaleLocked = true;
}

public void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
    g_bFinaleLocked = true;
}

public void Event_LeftStartArea(Event event, const char[] name, bool dontBroadcast)
{
    g_bLeftSafeArea = true;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsEligibleRealPlayer(client))
    {
        return;
    }
    g_bBalanceApplied[client] = false;
    g_iDamageProgress[client] = 0;
    g_iDamageRewarded[client] = 0;
    g_fScaledAbilityEnd[client] = 0.0;
    if (GetClientTeam(client) == TEAM_INFECTED)
    {
        CreateTimer(0.5, Timer_ApplyBalance, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (IsEligibleRealPlayer(victim))
    {
        if (g_bTankControl[victim])
        {
            CreateTimer(0.25, Timer_ReturnFromTank, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);
        }
        g_bBalanceApplied[victim] = false;
        g_iDamageProgress[victim] = 0;
        g_iDamageRewarded[victim] = 0;
        g_fScaledAbilityEnd[victim] = 0.0;
        g_bLifeHealthBoost[victim] = false;
        g_bLifeCooldownBoost[victim] = false;
        g_bLifeGhostBoost[victim] = false;
    }

    if (IsHumanSurvivor(victim) && IsHumanInfected(attacker))
    {
        bool tank = IsPlayerTank(attacker);
        AddPoints(attacker, tank ? g_cvRewardTankKill.IntValue : g_cvRewardKill.IntValue);
    }
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int damage = event.GetInt("dmg_health");
    float now = GetGameTime();
    if (IsEligibleRealPlayer(victim))
    {
        g_fLastDamage[victim] = now;
    }
    if (IsEligibleRealPlayer(attacker))
    {
        g_fLastDamage[attacker] = now;
    }
    if (!IsHumanSurvivor(victim) || !IsHumanInfected(attacker) || damage <= 0)
    {
        return;
    }

    int interval = g_cvPointsDamageInterval.IntValue;
    g_iDamageProgress[attacker] += damage;
    while (g_iDamageProgress[attacker] >= interval && g_iDamageRewarded[attacker] < g_cvPointsDamageCap.IntValue)
    {
        g_iDamageProgress[attacker] -= interval;
        g_iDamageRewarded[attacker]++;
        AddPoints(attacker, 1);
    }
}

public Action L4D_OnSpawnTank(const float vecPos[3], const float vecAng[3])
{
    if (!CanUseCore() || g_bFinaleLocked || g_iPendingTankBuyer > 0 || g_cvAdminSpawnBypass.BoolValue)
    {
        return Plugin_Continue;
    }

    float elapsed = GetEngineTime() - g_fLastTankSpawnTime;
    if (g_fLastTankSpawnTime > 0.0 && elapsed < g_cvTankSpawnMinInterval.FloatValue)
    {
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (!CanUseCore() || CountAliveTanks() > g_cvTankLimit.IntValue)
    {
        return;
    }
    g_fLastTankSpawnTime = GetEngineTime();
    CreateTimer(0.2, Timer_TankLottery, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_GhostSpawnTime(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsHumanInfected(client))
    {
        return;
    }
    float delay = g_cvSIRespawnSeconds.FloatValue;
    if (g_bLifeGhostBoost[client])
    {
        delay -= 8.0;
    }
    if (delay < 0.0)
    {
        delay = 0.0;
    }
    SetEventInt(event, "spawntime", RoundToCeil(delay));
    if (GetFeatureStatus(FeatureType_Native, "L4D_SetPlayerSpawnTime") == FeatureStatus_Available)
    {
        L4D_SetPlayerSpawnTime(client, delay, true);
    }
}

public void L4D_OnIncapacitated_Post(int victim, int inflictor, int attacker, float damage, int damagetype, int weapon)
{
    if (IsEligibleRealPlayer(victim))
    {
        g_fLastDamage[victim] = GetGameTime();
    }
    if (IsHumanSurvivor(victim) && IsHumanInfected(attacker))
    {
        g_fLastDamage[attacker] = GetGameTime();
        AddPoints(attacker, IsPlayerTank(attacker) ? g_cvRewardTankIncap.IntValue : g_cvRewardIncap.IntValue);
    }
}

public void L4D_OnPouncedOnSurvivor_Post(int victim, int attacker)
{
    RewardPin(attacker, victim);
}

public void L4D_OnGrabWithTongue_Post(int victim, int attacker)
{
    RewardPin(attacker, victim);
}

public void L4D2_OnJockeyRide_Post(int victim, int attacker)
{
    RewardPin(attacker, victim);
}

public void L4D2_OnStartCarryingVictim_Post(int victim, int attacker)
{
    RewardPin(attacker, victim);
}

public void L4D2_OnSlammedSurvivor_Post(int victim, int attacker, bool wallSlam, bool deadlyCharge)
{
    RewardPin(attacker, victim);
}

public void L4D_OnVomitedUpon_Post(int victim, int attacker, bool boomerExplosion)
{
    if (boomerExplosion && IsHumanSurvivor(victim) && IsHumanInfected(attacker))
    {
        AddPoints(attacker, 1);
    }
}

void RewardPin(int attacker, int victim)
{
    if (IsHumanSurvivor(victim) && IsHumanInfected(attacker))
    {
        g_fLastDamage[victim] = GetGameTime();
        g_fLastDamage[attacker] = GetGameTime();
        AddPoints(attacker, IsPlayerTank(attacker) ? g_cvRewardTankIncap.IntValue : g_cvRewardPin.IntValue);
    }
}

public Action Timer_ConfirmInfected(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client))
    {
        return Plugin_Stop;
    }
    if (GetClientTeam(client) != TEAM_INFECTED)
    {
        PrintToChat(client, "\x04[感染者]\x01 InfectedBots 没有接受本次加入请求，请确认 coop_versus_enable 和 human_limit 配置。");
    }
    return Plugin_Stop;
}

public Action Timer_ApplyBalance(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (IsHumanInfected(client))
    {
        ApplyHumanBalance(client);
    }
    return Plugin_Stop;
}

public Action Timer_ReturnFromTank(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client) || !g_bTankControl[client])
    {
        return Plugin_Stop;
    }

    int bot = g_iTankSurvivorBot[client];
    g_bTankControl[client] = false;
    g_iTankSurvivorBot[client] = 0;
    if (IsFreeSurvivorBot(bot))
    {
        ChangeClientTeam(client, TEAM_SPECTATOR);
        L4D_SetHumanSpec(bot, client);
        L4D_TakeOverBot(client);
        PrintToChat(client, "\x04[TANK]\x01 Tank 已结束，你已接回原 Survivor Bot。");
    }
    return Plugin_Stop;
}

public Action Timer_TankLottery(Handle timer)
{
    int tank = FindLiveTank();
    if (tank == 0)
    {
        return Plugin_Stop;
    }

    int candidate = 0;
    if (g_iPendingTankBuyer > 0 && IsTankControlAllowed(g_iPendingTankBuyer))
    {
        candidate = g_iPendingTankBuyer;
    }
    g_iPendingTankBuyer = 0;
    if (candidate == 0)
    {
        candidate = PickTankCandidate();
    }
    if (candidate == 0)
    {
        return Plugin_Stop;
    }

    int survivorBot = 0;
    if (GetClientTeam(candidate) == TEAM_SURVIVOR)
    {
        L4D_ReplaceWithBot(candidate);
        survivorBot = FindSurvivorBotForClient(candidate);
        if (survivorBot == 0)
        {
            survivorBot = FindFreeSurvivorBot();
        }
    }
    else if (IsPlayerAlive(candidate) && !IsPlayerGhost(candidate))
    {
        L4D_ReplaceWithBot(candidate);
    }

    ChangeClientTeam(candidate, TEAM_SPECTATOR);
    ChangeClientTeam(candidate, TEAM_INFECTED);
    L4D_ReplaceTank(tank, candidate);
    g_bTankControl[candidate] = true;
    RecordTankControl(candidate);
    g_bTankRecent[candidate] = true;
    g_bTankPriority[candidate] = false;
    g_iTankSurvivorBot[candidate] = survivorBot;
    PrintToChatAll("\x04[TANK]\x01 %N 被抽中控制本次 Tank。", candidate);
    return Plugin_Stop;
}

public Action Timer_HUD(Handle timer)
{
    if (!g_cvHUD.BoolValue || GetGameTime() < g_fNextHUD)
    {
        return Plugin_Continue;
    }
    g_fNextHUD = GetGameTime() + g_cvHUDRate.FloatValue;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsHumanInfected(client))
        {
            continue;
        }
        if (IsPlayerAlive(client) && !IsPlayerGhost(client) && !IsPlayerTank(client))
        {
            ScaleAbilityCooldown(client);
        }
        ShowInfectedHUD(client);
    }
    return Plugin_Continue;
}

void ShowInfectedHUD(int client)
{
    int points = GetPoints(client);
    int class = GetZombieClass(client);
    char role[32];
    if (class == ZC_TANK)
    {
        strcopy(role, sizeof(role), "TANK");
    }
    else if (class >= SI_FIRST && class <= SI_LAST)
    {
        strcopy(role, sizeof(role), g_sClassNames[class - SI_FIRST]);
    }
    else
    {
        strcopy(role, sizeof(role), "Ghost");
    }

    char state[64];
    if (IsPlayerGhost(client))
    {
        Format(state, sizeof(state), "Ghost | 复活约 %.0fs", g_cvSIRespawnSeconds.FloatValue);
    }
    else if (class == ZC_TANK)
    {
        Format(state, sizeof(state), "Tank HP %d/%d", GetClientHealth(client), GetMaxHealth(client));
    }
    else
    {
        Format(state, sizeof(state), "HP %d/%d", GetClientHealth(client), GetMaxHealth(client));
    }
    SetHudTextParams(0.02, 0.72, g_cvHUDRate.FloatValue + 0.10, 255, 80, 80, 220, 0, 0.0, 0.0, 0.0);
    ShowHudText(client, -1, "[感染者] %s\n%s\n积分 %d | Survivor %d | SI %d/%d\nTank 抽签: %s", role, state, points, CountRealSurvivors(), CountSpecialInfected(), GetConfiguredSIMax(), g_bTankQueue[client] ? "ON" : "OFF");
}

void ApplyHumanBalance(int client)
{
    if (!IsHumanInfected(client) || !IsPlayerAlive(client) || IsPlayerGhost(client) || g_bBalanceApplied[client])
    {
        return;
    }

    int class = GetZombieClass(client);
    float multiplier = class == ZC_TANK ? g_cvTankHealthMultiplier.FloatValue : g_cvSIHealthMultiplier.FloatValue;
    if (g_bLifeHealthBoost[client] && class != ZC_TANK)
    {
        multiplier *= 1.25;
    }

    int health = GetClientHealth(client);
    int maxHealth = GetMaxHealth(client);
    if (health <= 0)
    {
        return;
    }
    int newHealth = RoundToCeil(float(health) * multiplier);
    int newMaxHealth = RoundToCeil(float(maxHealth > 0 ? maxHealth : health) * multiplier);
    SetEntProp(client, Prop_Data, "m_iHealth", newHealth);
    if (HasEntProp(client, Prop_Data, "m_iMaxHealth"))
    {
        SetEntProp(client, Prop_Data, "m_iMaxHealth", newMaxHealth);
    }
    ScaleAbilityCooldown(client);
    g_bBalanceApplied[client] = true;
}

void ApplyLifeHealthBoost(int client)
{
    if (!IsHumanInfected(client) || !IsPlayerAlive(client) || IsPlayerGhost(client) || IsPlayerTank(client))
    {
        return;
    }

    int health = GetClientHealth(client);
    int maxHealth = GetMaxHealth(client);
    if (health <= 0)
    {
        return;
    }

    SetEntProp(client, Prop_Data, "m_iHealth", RoundToCeil(float(health) * 1.25));
    if (HasEntProp(client, Prop_Data, "m_iMaxHealth"))
    {
        SetEntProp(client, Prop_Data, "m_iMaxHealth", RoundToCeil(float(maxHealth > 0 ? maxHealth : health) * 1.25));
    }
}

void ApplyCurrentCooldownReduction(int client)
{
    if (!HasEntProp(client, Prop_Send, "m_customAbility"))
    {
        return;
    }
    int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
    if (ability <= MaxClients || !IsValidEntity(ability) || !HasEntProp(ability, Prop_Send, "m_nextActivationTimer"))
    {
        return;
    }
    float next = GetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer");
    float now = GetGameTime();
    if (next > now)
    {
        float target = now + ((next - now) * 0.85);
        SetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", target);
        g_fScaledAbilityEnd[client] = target;
    }
}

void ScaleAbilityCooldown(int client)
{
    if (!HasEntProp(client, Prop_Send, "m_customAbility"))
    {
        return;
    }
    int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
    if (ability <= MaxClients || !IsValidEntity(ability) || !HasEntProp(ability, Prop_Send, "m_nextActivationTimer"))
    {
        return;
    }
    float next = GetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer");
    float now = GetGameTime();
    if (next <= now)
    {
        g_fScaledAbilityEnd[client] = 0.0;
        return;
    }
    if (g_fScaledAbilityEnd[client] > now && FloatAbs(next - g_fScaledAbilityEnd[client]) < 0.05)
    {
        return;
    }

    float multiplier = g_cvSICooldownMultiplier.FloatValue;
    if (g_bLifeCooldownBoost[client])
    {
        multiplier *= 0.85;
    }
    float target = now + ((next - now) * multiplier);
    if (target < next - 0.05)
    {
        SetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", target);
        g_fScaledAbilityEnd[client] = target;
    }
}

bool CanUseCore(int client = 0)
{
    if (!g_cvEnabled.BoolValue || L4D_HasPlayerControlledZombies() || L4DInfectedBots_GetConfigInt("coop_versus_enable") <= 0)
    {
        return false;
    }
    if (g_cvGameMode != null)
    {
        char mode[32];
        g_cvGameMode.GetString(mode, sizeof(mode));
        if (!StrEqual(mode, "coop") && !StrEqual(mode, "realism"))
        {
            return false;
        }
    }
    return client == 0 || IsEligibleRealPlayer(client);
}

bool CanSwitchTeam(int client, bool toInfected)
{
    if (!IsEligibleRealPlayer(client))
    {
        return false;
    }
    if (g_bFinaleLocked)
    {
        PrintToChat(client, "\x04[感染者]\x01 当前处于 Finale/救援结算阶段，不能换边。");
        return false;
    }
    float now = GetGameTime();
    float lockedUntil;
    if (g_hSwitchCooldown.GetValue(GetSteamId(client), lockedUntil) && lockedUntil > now)
    {
        PrintToChat(client, "\x04[感染者]\x01 换边冷却还剩 %.0f 秒。", lockedUntil - now);
        return false;
    }
    if (now - g_fLastDamage[client] < g_cvRecentDamageLock.FloatValue)
    {
        PrintToChat(client, "\x04[感染者]\x01 最近发生过战斗，请等待几秒后再换边。");
        return false;
    }
    if (toInfected)
    {
        if (!IsPlayerAlive(client) || IsIncapacitated(client) || IsPinned(client))
        {
            PrintToChat(client, "\x04[感染者]\x01 活着、未倒地且未被控制时才能加入感染者。");
            return false;
        }
    }
    else if (IsPlayerAlive(client) && !IsPlayerGhost(client))
    {
        PrintToChat(client, "\x04[人类]\x01 普通特感存活时不能直接逃离战斗，请等待死亡或进入 Ghost。");
        return false;
    }
    return true;
}

void RememberSwitchCooldown(int client)
{
    g_hSwitchCooldown.SetValue(GetSteamId(client), GetGameTime() + g_cvSwitchCooldown.FloatValue);
}

int GetDynamicHumanLimit()
{
    int survivors = CountRealSurvivors();
    int dynamicLimit = survivors <= 4 ? 1 : survivors <= 8 ? 2 : 4;
    int configured = g_cvHumanLimit.IntValue;
    if (dynamicLimit > configured)
    {
        dynamicLimit = configured;
    }
    int infectedBotsLimit = L4DInfectedBots_GetConfigInt("coop_versus_human_limit");
    if (infectedBotsLimit > 0 && dynamicLimit > infectedBotsLimit)
    {
        dynamicLimit = infectedBotsLimit;
    }
    return dynamicLimit;
}

bool IsTankControlAllowed(int client)
{
    if (!IsEligibleRealPlayer(client) || g_bTankControl[client])
    {
        return false;
    }
    if (g_iHumanTankControlsThisChapter >= g_cvTankHumanPerChapter.IntValue)
    {
        return false;
    }

    char steamId[64];
    if (!GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId), true))
    {
        return false;
    }

    int count = 0;
    if (g_hTankChapterCount.GetValue(steamId, count) && count >= g_cvTankPlayerPerChapter.IntValue)
    {
        return false;
    }

    float last = 0.0;
    if (g_cvTankPlayerCooldown.FloatValue > 0.0 && g_hTankControlLast.GetValue(steamId, last))
    {
        if (GetEngineTime() - last < g_cvTankPlayerCooldown.FloatValue)
        {
            return false;
        }
    }
    return true;
}

void RecordTankControl(int client)
{
    char steamId[64];
    if (!GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId), true))
    {
        return;
    }

    int count = 0;
    g_hTankChapterCount.GetValue(steamId, count);
    g_hTankChapterCount.SetValue(steamId, count + 1);
    g_hTankControlLast.SetValue(steamId, GetEngineTime());
    g_iHumanTankControlsThisChapter++;
}

int PickTankCandidate()
{
    int priority[MAXPLAYERS + 1];
    int regular[MAXPLAYERS + 1];
    int recent[MAXPLAYERS + 1];
    int priorityCount, regularCount, recentCount;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsTankControlAllowed(client) || !g_bTankQueue[client])
        {
            continue;
        }
        if (g_bTankPriority[client])
        {
            priority[priorityCount++] = client;
        }
        else if (g_bTankRecent[client])
        {
            recent[recentCount++] = client;
        }
        else
        {
            regular[regularCount++] = client;
        }
    }
    if (priorityCount > 0)
    {
        return priority[GetRandomInt(0, priorityCount - 1)];
    }
    if (regularCount > 0)
    {
        return regular[GetRandomInt(0, regularCount - 1)];
    }
    if (recentCount > 0)
    {
        return recent[GetRandomInt(0, recentCount - 1)];
    }
    return 0;
}

bool CanSpawnPurchasedTank(int buyer)
{
    if (!CanUseCore() || !g_bLeftSafeArea || g_bFinaleLocked || !IsTankControlAllowed(buyer))
    {
        return false;
    }
    if (CountAliveTanks() >= g_cvTankLimit.IntValue || FindLiveSurvivor() <= 0 || GetConfiguredTankLimit() <= 0)
    {
        return false;
    }
    if (g_fLastTankSpawnTime > 0.0 && GetEngineTime() - g_fLastTankSpawnTime < g_cvTankSpawnMinInterval.FloatValue)
    {
        return false;
    }
    return true;
}

bool SpawnPurchasedTank(int buyer)
{
    if (!CanSpawnPurchasedTank(buyer) || GetFeatureStatus(FeatureType_Native, "L4D2_SpawnTank") != FeatureStatus_Available)
    {
        return false;
    }

    int survivor = FindLiveSurvivor();
    float pos[3], ang[3];
    if (!L4D_GetRandomPZSpawnPosition(survivor, ZC_TANK, 10, pos))
    {
        GetClientAbsOrigin(survivor, pos);
    }
    ang[0] = 0.0;
    ang[1] = 0.0;
    ang[2] = 0.0;
    g_iPendingTankBuyer = buyer;
    if (GetFeatureStatus(FeatureType_Native, "L4D2PveMutantTanks_MarkNextSpawn") == FeatureStatus_Available)
    {
        L4D2PveMutantTanks_MarkNextSpawn(PveMutantTankSource_Purchase, 0);
    }
    int tank = L4D2_SpawnTank(pos, ang);
    if (tank <= 0)
    {
        g_iPendingTankBuyer = 0;
        return false;
    }
    PrintToChatAll("\x04[TANK]\x01 %N 购买了 Tank 降临。", buyer);
    return true;
}

bool IsPlayableWitchAvailable()
{
    if (GetFeatureStatus(FeatureType_Native, "L4D2PlayableWitch_IsAvailable") != FeatureStatus_Available
        || GetFeatureStatus(FeatureType_Native, "L4D2PlayableWitch_Request") != FeatureStatus_Available)
    {
        return false;
    }
    return L4D2PlayableWitch_IsAvailable();
}

bool RefreshAbility(int client)
{
    if (!HasEntProp(client, Prop_Send, "m_customAbility"))
    {
        return false;
    }
    int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
    if (ability <= MaxClients || !IsValidEntity(ability))
    {
        return false;
    }
    if (HasEntProp(ability, Prop_Send, "m_nextActivationTimer"))
    {
        SetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", 0.0);
        return true;
    }
    return false;
}

bool CanChooseClass(int client)
{
    return !IsPlayerAlive(client) || IsPlayerGhost(client);
}

void SelectClass(int client, int class)
{
    if (!IsHumanInfected(client) || class < SI_FIRST || class > SI_LAST || !CanChooseClass(client))
    {
        return;
    }
    int index = class - SI_FIRST;
    if (CountClass(class) >= g_cvClassLimit[index].IntValue)
    {
        PrintToChat(client, "\x04[感染者]\x01 %s 当前已达到职业上限。", g_sClassNames[index]);
        return;
    }
    SetEntProp(client, Prop_Send, "m_zombieClass", class);
    PrintToChat(client, "\x04[感染者]\x01 已选择 %s。", g_sClassNames[index]);
}

int CountClass(int class)
{
    int count;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED && GetZombieClass(client) == class)
        {
            count++;
        }
    }
    return count;
}

int CountSpecialInfected()
{
    int count;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED && GetZombieClass(client) >= SI_FIRST && GetZombieClass(client) <= ZC_TANK)
        {
            count++;
        }
    }
    return count;
}

int CountRealSurvivors()
{
    int count;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsHumanSurvivor(client))
        {
            count++;
        }
    }
    return count;
}

int CountRealInfected()
{
    int count;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsHumanInfected(client))
        {
            count++;
        }
    }
    return count;
}

int GetConfiguredSIMax()
{
    int maxSpecials = L4DInfectedBots_GetConfigInt("max_specials");
    return maxSpecials > 0 ? maxSpecials : 12;
}

int GetConfiguredTankLimit()
{
    int limit = L4DInfectedBots_GetConfigInt("tank_limit");
    return limit > 0 ? limit : g_cvTankLimit.IntValue;
}

int CountAliveTanks()
{
    int count;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED && IsPlayerAlive(client) && IsPlayerTank(client))
        {
            count++;
        }
    }
    return count;
}

int FindLiveTank()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED && IsPlayerAlive(client) && IsPlayerTank(client))
        {
            return client;
        }
    }
    return 0;
}

int FindLiveSurvivor()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client))
        {
            return client;
        }
    }
    return 0;
}

int FindFreeSurvivorBot()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsFreeSurvivorBot(client))
        {
            return client;
        }
    }
    return 0;
}

int FindSurvivorBotForClient(int owner)
{
    if (!IsValidClient(owner))
    {
        return 0;
    }
    int userid = GetClientUserId(owner);
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsFreeSurvivorBot(client))
        {
            continue;
        }
        if (HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
        {
            int linked = GetEntProp(client, Prop_Send, "m_humanSpectatorUserID");
            if (linked == owner || linked == userid)
            {
                return client;
            }
        }
    }
    return 0;
}

bool IsFreeSurvivorBot(int client)
{
    if (!IsValidClient(client) || !IsFakeClient(client) || GetClientTeam(client) != TEAM_SURVIVOR)
    {
        return false;
    }
    if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
    {
        return true;
    }
    return GetEntProp(client, Prop_Send, "m_humanSpectatorUserID") == 0;
}

bool IsEligibleRealPlayer(int client)
{
    return IsValidClient(client) && !IsFakeClient(client) && (GetClientTeam(client) == TEAM_SURVIVOR || GetClientTeam(client) == TEAM_INFECTED);
}

bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

bool IsHumanSurvivor(int client)
{
    return IsEligibleRealPlayer(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool IsHumanInfected(int client)
{
    return IsEligibleRealPlayer(client) && GetClientTeam(client) == TEAM_INFECTED;
}

bool IsPlayerTank(int client)
{
    return IsValidClient(client) && GetClientTeam(client) == TEAM_INFECTED && GetZombieClass(client) == ZC_TANK;
}

bool IsPlayerGhost(int client)
{
    return IsValidClient(client) && HasEntProp(client, Prop_Send, "m_isGhost") && GetEntProp(client, Prop_Send, "m_isGhost") != 0;
}

bool IsIncapacitated(int client)
{
    return IsValidClient(client) && HasEntProp(client, Prop_Send, "m_isIncapacitated") && GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0;
}

bool IsPinned(int client)
{
    static const char props[][] = {"m_tongueOwner", "m_pounceAttacker", "m_jockeyAttacker", "m_carryAttacker", "m_pummelAttacker"};
    for (int i = 0; i < sizeof(props); i++)
    {
        if (HasEntProp(client, Prop_Send, props[i]) && GetEntPropEnt(client, Prop_Send, props[i]) > 0)
        {
            return true;
        }
    }
    return false;
}

int GetZombieClass(int client)
{
    if (!IsValidClient(client) || !HasEntProp(client, Prop_Send, "m_zombieClass"))
    {
        return 0;
    }
    return GetEntProp(client, Prop_Send, "m_zombieClass");
}

int GetMaxHealth(int client)
{
    if (HasEntProp(client, Prop_Data, "m_iMaxHealth"))
    {
        return GetEntProp(client, Prop_Data, "m_iMaxHealth");
    }
    return GetClientHealth(client);
}

int GetPoints(int client)
{
    if (GetFeatureStatus(FeatureType_Native, "L4D2CampaignShop_GetPoints") != FeatureStatus_Available)
    {
        return -1;
    }
    return L4D2CampaignShop_GetPoints(client);
}

int AddPoints(int client, int amount)
{
    if (amount <= 0 || GetFeatureStatus(FeatureType_Native, "L4D2CampaignShop_AddPoints") != FeatureStatus_Available)
    {
        return -1;
    }
    return L4D2CampaignShop_AddPoints(client, amount);
}

int RemovePoints(int client, int amount)
{
    if (amount <= 0 || GetFeatureStatus(FeatureType_Native, "L4D2CampaignShop_RemovePoints") != FeatureStatus_Available)
    {
        return -1;
    }
    return L4D2CampaignShop_RemovePoints(client, amount);
}

char[] GetSteamId(int client)
{
    static char steamId[64];
    steamId[0] = '\0';
    GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId), true);
    return steamId;
}

void ResetCampaignState()
{
    g_iTankArrivals = 0;
    g_iPendingTankBuyer = 0;
    ResetChapterState();
    for (int client = 1; client <= MaxClients; client++)
    {
        g_bTankPriority[client] = false;
        g_bBoughtTankArrival[client] = false;
        g_bTankRecent[client] = false;
    }
}

void ResetChapterState()
{
    g_iHumanTankControlsThisChapter = 0;
    g_hTankChapterCount.Clear();
    for (int client = 1; client <= MaxClients; client++)
    {
        g_bBoughtWitch[client] = false;
        g_bTankControl[client] = false;
        g_iTankSurvivorBot[client] = 0;
        g_bTankRecent[client] = false;
    }
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
