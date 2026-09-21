#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <keyvalues>
#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <l4d2_campaign_shop>
#include <mutant_tanks>

#define PLUGIN_VERSION "1.1.0"
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZOMBIE_WITCH 7
#define ZOMBIE_TANK 8
#define MAX_ADMIN_ITEMS 24

public Plugin myinfo =
{
    name = "L4D2 PvE Admin",
    author = "Codex",
    description = "Small SourceMod admin menu and commands for the L4D2 PvE profile.",
    version = PLUGIN_VERSION,
    url = ""
};

enum AdminMenuMode
{
    MenuMode_Player = 1,
    MenuMode_Equipment,
    MenuMode_Points
};

enum TankAdminAction
{
    TankAdminAction_Spawn = 1,
    TankAdminAction_SpawnAndTakeover,
    TankAdminAction_Takeover
};

TopMenu g_hTopMenu;
TopMenuObject g_iCategory = INVALID_TOPMENUOBJECT;
TopMenuObject g_iPlayers = INVALID_TOPMENUOBJECT;
TopMenuObject g_iEquipment = INVALID_TOPMENUOBJECT;
TopMenuObject g_iPoints = INVALID_TOPMENUOBJECT;
TopMenuObject g_iInfected = INVALID_TOPMENUOBJECT;
TopMenuObject g_iBossAdmin = INVALID_TOPMENUOBJECT;
TopMenuObject g_iMaintenance = INVALID_TOPMENUOBJECT;

int g_iMenuMode[MAXPLAYERS + 1];
int g_iMenuTarget[MAXPLAYERS + 1];
int g_iMenuTankType[MAXPLAYERS + 1];

ConVar g_cvAdminTankMenu;
ConVar g_cvAdminWitchMenu;
ConVar g_cvAdminWitchPlaceholder;
ConVar g_cvAdminTankSpawnDelay;

char g_sTankTypeNames[MT_MAXTYPES + 1][64];

char g_sItemNames[MAX_ADMIN_ITEMS][64] =
{
    "AK47",
    "M16",
    "SCAR",
    "SG552",
    "SMG",
    "MP5",
    "Auto Shotgun",
    "SPAS",
    "Hunting Rifle",
    "Military Sniper",
    "AWP",
    "Scout",
    "M60",
    "Grenade Launcher",
    "Pistol",
    "Magnum",
    "Fire Axe",
    "Katana",
    "First Aid Kit",
    "Defibrillator",
    "Pain Pills",
    "Adrenaline",
    "Molotov",
    "Pipe Bomb"
};

char g_sItemClasses[MAX_ADMIN_ITEMS][64] =
{
    "rifle_ak47",
    "rifle",
    "rifle_scar",
    "rifle_sg552",
    "smg",
    "smg_mp5",
    "autoshotgun",
    "shotgun_spas",
    "hunting_rifle",
    "sniper_military",
    "sniper_awp",
    "sniper_scout",
    "rifle_m60",
    "grenade_launcher",
    "pistol",
    "pistol_magnum",
    "fireaxe",
    "katana",
    "first_aid_kit",
    "defibrillator",
    "pain_pills",
    "adrenaline",
    "molotov",
    "pipe_bomb"
};

public void OnPluginStart()
{
    LoadTranslations("common.phrases");

    RegAdminCmd("sm_pveadmin", Command_PveAdmin, ADMFLAG_GENERIC, "Open the L4D2 PvE admin menu.");
    RegAdminCmd("sm_pvegive", Command_PveGive, ADMFLAG_SLAY, "sm_pvegive <target> <item>");
    RegAdminCmd("sm_pveheal", Command_PveHeal, ADMFLAG_SLAY, "sm_pveheal <target>");
    RegAdminCmd("sm_pverevive", Command_PveRevive, ADMFLAG_SLAY, "sm_pverevive <target>");
    RegAdminCmd("sm_pvepoints", Command_PvePoints, ADMFLAG_CUSTOM6, "sm_pvepoints [target]");
    RegAdminCmd("sm_pveaddpoints", Command_PveAddPoints, ADMFLAG_CUSTOM6, "sm_pveaddpoints <target> <amount>");
    RegAdminCmd("sm_pvesetpoints", Command_PveSetPoints, ADMFLAG_CUSTOM6, "sm_pvesetpoints <target> <amount>");
    RegAdminCmd("sm_pvespawn", Command_PveSpawn, ADMFLAG_SLAY, "sm_pvespawn <smoker|boomer|hunter|spitter|jockey|charger|tank|witch>");
    RegAdminCmd("sm_pvehorde", Command_PveHorde, ADMFLAG_SLAY, "Force a director panic event.");
    RegAdminCmd("sm_pveinfo", Command_PveInfo, ADMFLAG_GENERIC, "Show PvE server counters.");
    RegAdminCmd("sm_pvereloadshop", Command_PveReloadShop, ADMFLAG_CONFIG, "Reload the campaign shop plugin.");

    g_cvAdminTankMenu = CreateConVar("l4d2_pve_admin_tank_menu", "1", "Show the administrator Tank type menu.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvAdminWitchMenu = CreateConVar("l4d2_pve_admin_witch_menu", "1", "Show the administrator Witch management entry.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvAdminWitchPlaceholder = CreateConVar("l4d2_pve_admin_witch_placeholder", "1", "Show the Witch takeover compatibility placeholder when no playable Witch API is available.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvAdminTankSpawnDelay = CreateConVar("l4d2_pve_admin_tank_spawn_delay", "0.25", "Delay before applying the selected Mutant Tank type after an admin Tank spawn.", FCVAR_NOTIFY, true, 0.0, true, 2.0);

    AutoExecConfig(true, "l4d2_pve_admin");
    RefreshMutantTankTypeNames();

    TopMenu topmenu;
    if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
    {
        OnAdminMenuReady(topmenu);
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "adminmenu"))
    {
        TopMenu topmenu = GetAdminTopMenu();
        if (topmenu != null)
        {
            OnAdminMenuReady(topmenu);
        }
    }
    else if (StrEqual(name, "mutant_tanks"))
    {
        RefreshMutantTankTypeNames();
    }
}

public void OnAllPluginsLoaded()
{
    RefreshMutantTankTypeNames();
}

public void OnAdminMenuReady(Handle aTopMenu)
{
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
    if (topmenu == g_hTopMenu)
    {
        return;
    }

    g_hTopMenu = topmenu;
    g_iCategory = g_hTopMenu.AddCategory("L4D2PVEAdmin", TopMenuHandler, "", ADMFLAG_GENERIC);
    if (g_iCategory == INVALID_TOPMENUOBJECT)
    {
        return;
    }

    g_iPlayers = g_hTopMenu.AddItem("pve_players", TopMenuHandler, g_iCategory, "", ADMFLAG_SLAY);
    g_iEquipment = g_hTopMenu.AddItem("pve_equipment", TopMenuHandler, g_iCategory, "", ADMFLAG_SLAY);
    g_iPoints = g_hTopMenu.AddItem("pve_points", TopMenuHandler, g_iCategory, "", ADMFLAG_CUSTOM6);
    g_iInfected = g_hTopMenu.AddItem("pve_infected", TopMenuHandler, g_iCategory, "", ADMFLAG_SLAY);
    g_iBossAdmin = g_hTopMenu.AddItem("pve_boss_admin", TopMenuHandler, g_iCategory, "", ADMFLAG_SLAY);
    g_iMaintenance = g_hTopMenu.AddItem("pve_maintenance", TopMenuHandler, g_iCategory, "", ADMFLAG_CONFIG);
}

public void TopMenuHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayTitle)
    {
        if (object_id == INVALID_TOPMENUOBJECT || object_id == g_iCategory)
        {
            Format(buffer, maxlength, "L4D2 PvE 管理");
        }
        return;
    }

    if (action == TopMenuAction_DisplayOption)
    {
        if (object_id == g_iCategory)
        {
            Format(buffer, maxlength, "L4D2 PvE 管理");
        }
        else if (object_id == g_iPlayers)
        {
            Format(buffer, maxlength, "玩家管理");
        }
        else if (object_id == g_iEquipment)
        {
            Format(buffer, maxlength, "装备管理");
        }
        else if (object_id == g_iPoints)
        {
            Format(buffer, maxlength, "积分管理");
        }
        else if (object_id == g_iInfected)
        {
            Format(buffer, maxlength, "感染者 / Boss 测试");
        }
        else if (object_id == g_iBossAdmin)
        {
            Format(buffer, maxlength, "Tank / Witch 管理");
        }
        else if (object_id == g_iMaintenance)
        {
            Format(buffer, maxlength, "服务器维护 / 信息");
        }
        return;
    }

    if (action != TopMenuAction_SelectOption)
    {
        return;
    }

    if (object_id == g_iPlayers)
    {
        ShowTargetMenu(param, MenuMode_Player);
    }
    else if (object_id == g_iEquipment)
    {
        ShowTargetMenu(param, MenuMode_Equipment);
    }
    else if (object_id == g_iPoints)
    {
        if (IsPointsAdmin(param))
        {
            ShowTargetMenu(param, MenuMode_Points);
        }
        else
        {
            PrintToChat(param, "\x04[PVE]\x01 你的管理员权限不足以修改积分。");
        }
    }
    else if (object_id == g_iInfected)
    {
        ShowInfectedMenu(param);
    }
    else if (object_id == g_iBossAdmin)
    {
        ShowBossAdminMenu(param);
    }
    else if (object_id == g_iMaintenance)
    {
        ShowMaintenanceMenu(param);
    }
}

public Action Command_PveAdmin(int client, int args)
{
    if (!IsValidClient(client) || g_hTopMenu == null)
    {
        ReplyToCommand(client, "[PVE] This command must be used in-game after adminmenu.smx is loaded.");
        return Plugin_Handled;
    }

    g_hTopMenu.Display(client, TopMenuPosition_Start);
    return Plugin_Handled;
}

public Action Command_PveGive(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[PVE] Usage: sm_pvegive <target> <item>");
        return Plugin_Handled;
    }

    char targetArg[MAX_TARGET_LENGTH], itemArg[64];
    GetCmdArg(1, targetArg, sizeof(targetArg));
    GetCmdArg(2, itemArg, sizeof(itemArg));

    int targets[MAXPLAYERS], targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tnIsMl;
    targetCount = ProcessTargetString(targetArg, client, targets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tnIsMl);
    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    int item = FindItem(itemArg);
    if (item == -1)
    {
        ReplyToCommand(client, "[PVE] Unknown item. Use sm_pveadmin or sm_pvegive <target> ak47|m60|first_aid_kit...");
        return Plugin_Handled;
    }

    for (int i = 0; i < targetCount; i++)
    {
        GiveItemToTarget(client, targets[i], item);
    }
    return Plugin_Handled;
}

public Action Command_PveHeal(int client, int args)
{
    return Command_TargetAction(client, args, "sm_pveheal", TargetAction_Heal);
}

public Action Command_PveRevive(int client, int args)
{
    return Command_TargetAction(client, args, "sm_pverevive", TargetAction_Revive);
}

public Action Command_PvePoints(int client, int args)
{
    if (!IsPointsAdmin(client))
    {
        ReplyToCommand(client, "[PVE] You need root or custom6 access for point administration.");
        return Plugin_Handled;
    }
    if (!ShopApiAvailable())
    {
        ReplyToCommand(client, "[PVE] Campaign shop API is not available. Load l4d2_campaign_shop.smx first.");
        return Plugin_Handled;
    }

    int target = client;
    if (args >= 1)
    {
        target = FindSingleTarget(client, 1);
    }
    if (!IsValidTarget(client, target))
    {
        return Plugin_Handled;
    }

    ReplyToCommand(client, "[PVE] %N campaign points: %d", target, L4D2CampaignShop_GetPoints(target));
    Audit(client, target, "points", "show=%d", L4D2CampaignShop_GetPoints(target));
    return Plugin_Handled;
}

public Action Command_PveAddPoints(int client, int args)
{
    if (!IsPointsAdmin(client))
    {
        ReplyToCommand(client, "[PVE] You need root or custom6 access for point administration.");
        return Plugin_Handled;
    }
    if (args < 2)
    {
        ReplyToCommand(client, "[PVE] Usage: sm_pveaddpoints <target> <amount>");
        return Plugin_Handled;
    }
    if (!ShopApiAvailable())
    {
        ReplyToCommand(client, "[PVE] Campaign shop API is not available.");
        return Plugin_Handled;
    }

    int target = FindSingleTarget(client, 1);
    if (!IsValidTarget(client, target))
    {
        return Plugin_Handled;
    }

    char amountArg[16];
    GetCmdArg(2, amountArg, sizeof(amountArg));
    int amount = StringToInt(amountArg);
    if (amount <= 0)
    {
        ReplyToCommand(client, "[PVE] Amount must be greater than zero.");
        return Plugin_Handled;
    }

    int balance = L4D2CampaignShop_AddPoints(target, amount);
    ReplyToCommand(client, "[PVE] %N now has %d campaign points.", target, balance);
    Audit(client, target, "add_points", "amount=%d balance=%d", amount, balance);
    return Plugin_Handled;
}

public Action Command_PveSetPoints(int client, int args)
{
    if (!IsPointsAdmin(client))
    {
        ReplyToCommand(client, "[PVE] You need root or custom6 access for point administration.");
        return Plugin_Handled;
    }
    if (args < 2)
    {
        ReplyToCommand(client, "[PVE] Usage: sm_pvesetpoints <target> <amount>");
        return Plugin_Handled;
    }
    if (!ShopApiAvailable())
    {
        ReplyToCommand(client, "[PVE] Campaign shop API is not available.");
        return Plugin_Handled;
    }

    int target = FindSingleTarget(client, 1);
    if (!IsValidTarget(client, target))
    {
        return Plugin_Handled;
    }

    char amountArg[16];
    GetCmdArg(2, amountArg, sizeof(amountArg));
    int amount = StringToInt(amountArg);
    if (amount < 0)
    {
        ReplyToCommand(client, "[PVE] Amount cannot be negative.");
        return Plugin_Handled;
    }

    int balance = L4D2CampaignShop_SetPoints(target, amount);
    ReplyToCommand(client, "[PVE] %N now has %d campaign points.", target, balance);
    Audit(client, target, "set_points", "requested=%d balance=%d", amount, balance);
    return Plugin_Handled;
}

public Action Command_PveSpawn(int client, int args)
{
    if (!IsValidClient(client) || args < 1)
    {
        ReplyToCommand(client, "[PVE] Usage in-game: sm_pvespawn <smoker|boomer|hunter|spitter|jockey|charger|tank|witch>");
        return Plugin_Handled;
    }

    char token[32];
    GetCmdArg(1, token, sizeof(token));
    if (!SpawnByToken(client, token))
    {
        ReplyToCommand(client, "[PVE] Spawn failed or unknown class.");
    }
    return Plugin_Handled;
}

public Action Command_PveHorde(int client, int args)
{
    ServerCommand("director_force_panic");
    ServerExecute();
    ReplyToCommand(client, "[PVE] Director panic event requested.");
    Audit(client, 0, "horde", "director_force_panic");
    return Plugin_Handled;
}

public Action Command_PveInfo(int client, int args)
{
    PrintPveInfo(client);
    return Plugin_Handled;
}

public Action Command_PveReloadShop(int client, int args)
{
    ServerCommand("sm plugins reload l4d2_campaign_shop");
    ServerExecute();
    ReplyToCommand(client, "[PVE] Campaign shop reload requested.");
    Audit(client, 0, "reload_shop", "l4d2_campaign_shop");
    return Plugin_Handled;
}

void ShowTargetMenu(int client, AdminMenuMode mode)
{
    if (!IsValidClient(client))
    {
        return;
    }

    g_iMenuMode[client] = mode;
    Menu menu = new Menu(MenuHandler_Target);
    switch (mode)
    {
        case MenuMode_Player: menu.SetTitle("玩家管理");
        case MenuMode_Equipment: menu.SetTitle("装备管理 - 选择玩家");
        case MenuMode_Points: menu.SetTitle("积分管理 - 选择玩家");
    }
    menu.ExitBackButton = true;
    AddTargetsToMenu2(menu, client, COMMAND_FILTER_CONNECTED);
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Target(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (item == MenuCancel_ExitBack)
        {
            ReturnToAdminMenu(client);
        }
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(item, info, sizeof(info));
        int target = GetClientOfUserId(StringToInt(info));
        if (!IsValidTarget(client, target))
        {
            ShowTargetMenu(client, view_as<AdminMenuMode>(g_iMenuMode[client]));
            return 0;
        }

        g_iMenuTarget[client] = GetClientUserId(target);
        switch (g_iMenuMode[client])
        {
            case MenuMode_Player: ShowPlayerActionMenu(client);
            case MenuMode_Equipment: ShowEquipmentMenu(client);
            case MenuMode_Points: ShowPointsMenu(client);
        }
    }
    return 0;
}

void ShowPlayerActionMenu(int client)
{
    int target = GetClientOfUserId(g_iMenuTarget[client]);
    if (!IsValidTarget(client, target))
    {
        ShowTargetMenu(client, MenuMode_Player);
        return;
    }

    Menu menu = new Menu(MenuHandler_PlayerAction);
    menu.SetTitle("玩家管理: %N", target);
    menu.AddItem("heal", "治疗到 100 HP");
    menu.AddItem("revive", "复活 / Second Wind");
    menu.AddItem("slay", "处死");
    menu.AddItem("kick", "踢出");
    menu.AddItem("ban", "Ban 60 分钟");
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_PlayerAction(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (item == MenuCancel_ExitBack)
        {
            ShowTargetMenu(client, MenuMode_Player);
        }
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(item, info, sizeof(info));
        int target = GetClientOfUserId(g_iMenuTarget[client]);
        if (IsValidTarget(client, target))
        {
            if (StrEqual(info, "heal"))
            {
                HealTarget(client, target);
            }
            else if (StrEqual(info, "revive"))
            {
                ReviveTarget(client, target);
            }
            else if (StrEqual(info, "slay"))
            {
                SlayTarget(client, target);
            }
            else if (StrEqual(info, "kick"))
            {
                KickTarget(client, target);
            }
            else if (StrEqual(info, "ban"))
            {
                BanTarget(client, target);
            }
        }
        if (IsValidClient(client))
        {
            ShowPlayerActionMenu(client);
        }
    }
    return 0;
}

void ShowEquipmentMenu(int client)
{
    int target = GetClientOfUserId(g_iMenuTarget[client]);
    if (!IsValidTarget(client, target))
    {
        ShowTargetMenu(client, MenuMode_Equipment);
        return;
    }

    Menu menu = new Menu(MenuHandler_Equipment);
    menu.SetTitle("给 %N 装备", target);
    char info[16];
    for (int i = 0; i < MAX_ADMIN_ITEMS; i++)
    {
        IntToString(i, info, sizeof(info));
        menu.AddItem(info, g_sItemNames[i]);
    }
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Equipment(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (item == MenuCancel_ExitBack)
        {
            ShowTargetMenu(client, MenuMode_Equipment);
        }
    }
    else if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(item, info, sizeof(info));
        int target = GetClientOfUserId(g_iMenuTarget[client]);
        int itemIndex = StringToInt(info);
        if (IsValidTarget(client, target) && itemIndex >= 0 && itemIndex < MAX_ADMIN_ITEMS)
        {
            GiveItemToTarget(client, target, itemIndex);
        }
        if (IsValidClient(client))
        {
            ShowEquipmentMenu(client);
        }
    }
    return 0;
}

void ShowPointsMenu(int client)
{
    int target = GetClientOfUserId(g_iMenuTarget[client]);
    if (!IsValidTarget(client, target) || !ShopApiAvailable())
    {
        if (!ShopApiAvailable())
        {
            PrintToChat(client, "\x04[PVE]\x01 商城积分 API 不可用。");
        }
        ReturnToAdminMenu(client);
        return;
    }

    Menu menu = new Menu(MenuHandler_Points);
    menu.SetTitle("积分: %N = %d", target, L4D2CampaignShop_GetPoints(target));
    menu.AddItem("add10", "+10");
    menu.AddItem("add50", "+50");
    menu.AddItem("add100", "+100");
    menu.AddItem("set0", "清空积分");
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Points(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (item == MenuCancel_ExitBack)
        {
            ShowTargetMenu(client, MenuMode_Points);
        }
    }
    else if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(item, info, sizeof(info));
        int target = GetClientOfUserId(g_iMenuTarget[client]);
        if (IsValidTarget(client, target) && ShopApiAvailable())
        {
            if (StrEqual(info, "set0"))
            {
                int balance = L4D2CampaignShop_SetPoints(target, 0);
                PrintToChat(client, "\x04[PVE]\x01 %N 的积分已清空。", target);
                Audit(client, target, "set_points", "requested=0 balance=%d", balance);
            }
            else
            {
                int amount = 10;
                if (StrEqual(info, "add50")) amount = 50;
                else if (StrEqual(info, "add100")) amount = 100;
                int balance = L4D2CampaignShop_AddPoints(target, amount);
                PrintToChat(client, "\x04[PVE]\x01 已给 %N 增加 %d 积分，余额 %d。", target, amount, balance);
                Audit(client, target, "add_points", "amount=%d balance=%d", amount, balance);
            }
        }
        if (IsValidClient(client))
        {
            ShowPointsMenu(client);
        }
    }
    return 0;
}

void ShowBossAdminMenu(int client)
{
    if (!IsValidClient(client))
    {
        return;
    }

    Menu menu = new Menu(MenuHandler_BossAdmin);
    menu.SetTitle("Tank / Witch 管理");
    if (g_cvAdminTankMenu.BoolValue)
    {
        if (MutantTanksApiAvailable())
        {
            menu.AddItem("tank_types", "Mutant Tanks：选择 Tank 类型");
        }
        else
        {
            menu.AddItem("tank_types", "Tank 类型选择不可用（Mutant Tanks 未加载）", ITEMDRAW_DISABLED);
        }
    }
    menu.AddItem("tank_normal", "兼容：生成普通 Tank");
    if (g_cvAdminWitchMenu.BoolValue)
    {
        menu.AddItem("witch", "Witch 管理入口");
    }
    menu.AddItem("clear_tank", "清除全部 Tank");
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_BossAdmin(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (item == MenuCancel_ExitBack)
        {
            ReturnToAdminMenu(client);
        }
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(item, info, sizeof(info));
        if (StrEqual(info, "tank_types"))
        {
            if (MutantTanksApiAvailable())
            {
                ShowTankTypeMenu(client);
            }
            else
            {
                PrintToChat(client, "\x04[PVE]\x01 Mutant Tanks 未加载，类型菜单不可用；可使用兼容的普通 Tank 生成。\x01");
                ShowBossAdminMenu(client);
            }
        }
        else if (StrEqual(info, "tank_normal"))
        {
            SpawnByToken(client, "tank");
            ShowBossAdminMenu(client);
        }
        else if (StrEqual(info, "witch"))
        {
            ShowWitchAdminMenu(client);
        }
        else if (StrEqual(info, "clear_tank"))
        {
            int count = KillInfectedByClass(true);
            PrintToChat(client, "\x04[PVE]\x01 已清除 %d 个 Tank。", count);
            Audit(client, 0, "clear_tank", "count=%d", count);
            ShowBossAdminMenu(client);
        }
    }
    return 0;
}

void ShowTankTypeMenu(int client)
{
    if (!IsValidClient(client) || !MutantTanksApiAvailable())
    {
        return;
    }

    RefreshMutantTankTypeNames();
    int minType = MT_GetMinType();
    int maxType = MT_GetMaxType();
    if (minType < 1 || maxType < minType)
    {
        PrintToChat(client, "\x04[PVE]\x01 Mutant Tanks 没有可用的 Tank 类型范围。\x01");
        ShowBossAdminMenu(client);
        return;
    }

    Menu menu = new Menu(MenuHandler_TankType);
    menu.SetTitle("Tank 类型管理 | 选择变体");
    char info[16], display[128], tankName[64];
    for (int type = minType; type <= maxType && type <= MT_MAXTYPES; type++)
    {
        IntToString(type, info, sizeof(info));
        GetTankTypeName(type, tankName, sizeof(tankName));
        if (!MT_IsTypeEnabled(type, 0))
        {
            Format(display, sizeof(display), "%d. %s（当前配置禁用）", type, tankName);
            menu.AddItem(info, display, ITEMDRAW_DISABLED);
        }
        else
        {
            Format(display, sizeof(display), "%d. %s", type, tankName);
            menu.AddItem(info, display);
        }
    }
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TankType(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (item == MenuCancel_ExitBack)
        {
            ShowBossAdminMenu(client);
        }
    }
    else if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(item, info, sizeof(info));
        int type = StringToInt(info);
        if (type > 0)
        {
            g_iMenuTankType[client] = type;
            ShowTankActionMenu(client, type);
        }
    }
    return 0;
}

void ShowTankActionMenu(int client, int type)
{
    if (!IsValidClient(client) || !MutantTanksApiAvailable())
    {
        return;
    }

    char tankName[64], title[128];
    GetTankTypeName(type, tankName, sizeof(tankName));
    Format(title, sizeof(title), "Tank 类型 #%d：%s", type, tankName);

    Menu menu = new Menu(MenuHandler_TankAction);
    menu.SetTitle(title);
    menu.AddItem("spawn", "生成该类型 Tank（AI）");
    menu.AddItem("spawn_takeover", "生成并接管该类型 Tank");
    bool canTakeover = GetFeatureStatus(FeatureType_Native, "L4D_ReplaceTank") == FeatureStatus_Available;
    menu.AddItem("takeover", "接管现有 Tank，并应用该类型", canTakeover ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    menu.AddItem("back_types", "返回 Tank 类型列表");
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TankAction(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (item == MenuCancel_ExitBack)
        {
            ShowTankTypeMenu(client);
        }
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(item, info, sizeof(info));
        int type = g_iMenuTankType[client];
        if (StrEqual(info, "spawn"))
        {
            SpawnAdminTank(client, type, false);
        }
        else if (StrEqual(info, "spawn_takeover"))
        {
            SpawnAdminTank(client, type, true);
        }
        else if (StrEqual(info, "takeover"))
        {
            TakeOverAdminTank(client, type);
        }
        else if (StrEqual(info, "back_types"))
        {
            ShowTankTypeMenu(client);
            return 0;
        }
        if (IsValidClient(client))
        {
            ShowTankActionMenu(client, type);
        }
    }
    return 0;
}

void ShowWitchAdminMenu(int client)
{
    if (!IsValidClient(client))
    {
        return;
    }

    bool canSpawn = GetFeatureStatus(FeatureType_Native, "L4D2_SpawnWitch") == FeatureStatus_Available;
    bool canSpawnBride = GetFeatureStatus(FeatureType_Native, "L4D2_SpawnWitchBride") == FeatureStatus_Available;
    Menu menu = new Menu(MenuHandler_WitchAdmin);
    menu.SetTitle("Witch 管理（管理员专用）");
    menu.AddItem("spawn", "生成普通 Witch", canSpawn ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    menu.AddItem("spawn_bride", "生成 Bride Witch", canSpawnBride ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    if (g_cvAdminWitchPlaceholder.BoolValue)
    {
        menu.AddItem("takeover_unavailable", "接管 Witch（需要 Playable Witch 控制模块）", ITEMDRAW_DISABLED);
    }
    menu.AddItem("status", "查看 Witch 能力状态");
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_WitchAdmin(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (item == MenuCancel_ExitBack)
        {
            ShowBossAdminMenu(client);
        }
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(item, info, sizeof(info));
        if (StrEqual(info, "spawn"))
        {
            SpawnWitchForAdmin(client, false);
        }
        else if (StrEqual(info, "spawn_bride"))
        {
            SpawnWitchForAdmin(client, true);
        }
        else if (StrEqual(info, "status"))
        {
            bool canSpawn = GetFeatureStatus(FeatureType_Native, "L4D2_SpawnWitch") == FeatureStatus_Available;
            bool canSpawnBride = GetFeatureStatus(FeatureType_Native, "L4D2_SpawnWitchBride") == FeatureStatus_Available;
            PrintToChat(client, "\x04[PVE]\x01 Witch 生成：普通=%s，Bride=%s。当前依赖范围没有可调用的 Witch 接管 native；占位不会影响普通玩家。", canSpawn ? "可用" : "不可用", canSpawnBride ? "可用" : "不可用");
            Audit(client, 0, "witch_status", "spawn=%d bride=%d takeover=0", canSpawn, canSpawnBride);
        }
        if (IsValidClient(client))
        {
            ShowWitchAdminMenu(client);
        }
    }
    return 0;
}

void ShowInfectedMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Infected);
    menu.SetTitle("感染者 / Boss 测试");
    menu.AddItem("smoker", "Spawn Smoker");
    menu.AddItem("boomer", "Spawn Boomer");
    menu.AddItem("hunter", "Spawn Hunter");
    menu.AddItem("spitter", "Spawn Spitter");
    menu.AddItem("jockey", "Spawn Jockey");
    menu.AddItem("charger", "Spawn Charger");
    menu.AddItem("tank", "Spawn Tank");
    menu.AddItem("witch", "Spawn Witch");
    menu.AddItem("horde", "触发普通尸潮");
    menu.AddItem("clear_si", "清除全部普通特感");
    menu.AddItem("clear_tank", "清除全部 Tank");
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Infected(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (item == MenuCancel_ExitBack)
        {
            ReturnToAdminMenu(client);
        }
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(item, info, sizeof(info));
        if (StrEqual(info, "horde"))
        {
            ServerCommand("director_force_panic");
            ServerExecute();
            PrintToChat(client, "\x04[PVE]\x01 已请求普通尸潮。");
            Audit(client, 0, "horde", "director_force_panic");
        }
        else if (StrEqual(info, "clear_si"))
        {
            int count = KillInfectedByClass(false);
            PrintToChat(client, "\x04[PVE]\x01 已清除 %d 个普通特感。", count);
            Audit(client, 0, "clear_si", "count=%d", count);
        }
        else if (StrEqual(info, "clear_tank"))
        {
            int count = KillInfectedByClass(true);
            PrintToChat(client, "\x04[PVE]\x01 已清除 %d 个 Tank。", count);
            Audit(client, 0, "clear_tank", "count=%d", count);
        }
        else
        {
            SpawnByToken(client, info);
        }
        if (IsValidClient(client))
        {
            ShowInfectedMenu(client);
        }
    }
    return 0;
}

void ShowMaintenanceMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Maintenance);
    menu.SetTitle("服务器维护 / 信息");
    menu.AddItem("info", "查看服务器状态");
    menu.AddItem("reload_shop", "重载战役商城");
    menu.AddItem("reload_admins", "重载管理员缓存");
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Maintenance(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (item == MenuCancel_ExitBack)
        {
            ReturnToAdminMenu(client);
        }
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(item, info, sizeof(info));
        if (StrEqual(info, "info"))
        {
            PrintPveInfo(client);
        }
        else if (StrEqual(info, "reload_shop"))
        {
            ServerCommand("sm plugins reload l4d2_campaign_shop");
            ServerExecute();
            PrintToChat(client, "\x04[PVE]\x01 已请求重载战役商城。");
            Audit(client, 0, "reload_shop", "l4d2_campaign_shop");
        }
        else if (StrEqual(info, "reload_admins"))
        {
            ServerCommand("sm_reloadadmins");
            ServerExecute();
            PrintToChat(client, "\x04[PVE]\x01 已请求重载管理员缓存。");
            Audit(client, 0, "reload_admins", "sm_reloadadmins");
        }
        if (IsValidClient(client))
        {
            ShowMaintenanceMenu(client);
        }
    }
    return 0;
}

enum TargetAction
{
    TargetAction_Heal = 1,
    TargetAction_Revive
};

Action Command_TargetAction(int client, int args, const char[] command, TargetAction action)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[PVE] Usage: %s <target>", command);
        return Plugin_Handled;
    }

    int targets[MAXPLAYERS], targetCount;
    char targetArg[MAX_TARGET_LENGTH], targetName[MAX_TARGET_LENGTH];
    bool tnIsMl;
    GetCmdArg(1, targetArg, sizeof(targetArg));
    targetCount = ProcessTargetString(targetArg, client, targets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tnIsMl);
    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    for (int i = 0; i < targetCount; i++)
    {
        if (!IsValidTarget(client, targets[i]))
        {
            continue;
        }
        if (action == TargetAction_Heal)
        {
            HealTarget(client, targets[i]);
        }
        else
        {
            ReviveTarget(client, targets[i]);
        }
    }
    return Plugin_Handled;
}

void HealTarget(int admin, int target)
{
    if (!IsValidTarget(admin, target) || GetClientTeam(target) != TEAM_SURVIVOR || !IsPlayerAlive(target))
    {
        return;
    }
    SetEntityHealth(target, 100);
    PrintToChat(target, "\x04[PVE]\x01 管理员已将你的生命值恢复到 100。\x01");
    Audit(admin, target, "heal", "health=100");
}

void ReviveTarget(int admin, int target)
{
    if (!IsValidTarget(admin, target) || GetClientTeam(target) != TEAM_SURVIVOR)
    {
        return;
    }

    if (GetFeatureStatus(FeatureType_Native, "L4D_ReviveSurvivor") == FeatureStatus_Available)
    {
        L4D_ReviveSurvivor(target);
    }
    else
    {
        SetEntProp(target, Prop_Send, "m_isIncapacitated", 0);
        SetEntProp(target, Prop_Send, "m_isHangingFromLedge", 0);
        SetEntProp(target, Prop_Send, "m_reviveOwner", 0);
    }
    SetEntityHealth(target, 35);
    PrintToChat(target, "\x04[PVE]\x01 管理员已复活你，生命值 35。\x01");
    Audit(admin, target, "revive", "health=35");
}

void SlayTarget(int admin, int target)
{
    if (!IsValidTarget(admin, target) || !IsPlayerAlive(target))
    {
        return;
    }
    ForcePlayerSuicide(target);
    Audit(admin, target, "slay", "");
}

void KickTarget(int admin, int target)
{
    if (!IsValidTarget(admin, target))
    {
        return;
    }
    Audit(admin, target, "kick", "");
    KickClient(target, "Kicked by L4D2 PvE admin");
}

void BanTarget(int admin, int target)
{
    if (!IsValidTarget(admin, target))
    {
        return;
    }
    Audit(admin, target, "ban", "minutes=60");
    BanClient(target, 60, BANFLAG_AUTO, "L4D2 PvE admin ban", "Banned by L4D2 PvE admin", "l4d2_pve_admin", admin);
}

void GiveItemToTarget(int admin, int target, int item)
{
    if (!IsValidTarget(admin, target) || item < 0 || item >= MAX_ADMIN_ITEMS)
    {
        return;
    }
    if (GetClientTeam(target) != TEAM_SURVIVOR || !IsPlayerAlive(target))
    {
        PrintToChat(admin, "\x04[PVE]\x01 目标必须是存活的 Survivor。");
        return;
    }

    int entity = GivePlayerItem(target, g_sItemClasses[item]);
    if (entity == -1)
    {
        PrintToChat(admin, "\x04[PVE]\x01 无法给 %N 生成 %s，可能是背包已满。", target, g_sItemNames[item]);
        return;
    }

    PrintToChat(target, "\x04[PVE]\x01 管理员给了你: %s。", g_sItemNames[item]);
    PrintToChat(admin, "\x04[PVE]\x01 已给 %N: %s。", target, g_sItemNames[item]);
    Audit(admin, target, "give", "item=%s", g_sItemClasses[item]);
}

bool MutantTanksApiAvailable()
{
    if (!LibraryExists("mutant_tanks"))
    {
        return false;
    }
    return GetFeatureStatus(FeatureType_Native, "MT_GetMinType") == FeatureStatus_Available
        && GetFeatureStatus(FeatureType_Native, "MT_GetMaxType") == FeatureStatus_Available
        && GetFeatureStatus(FeatureType_Native, "MT_IsTypeEnabled") == FeatureStatus_Available
        && GetFeatureStatus(FeatureType_Native, "MT_SetTankType") == FeatureStatus_Available;
}

void RefreshMutantTankTypeNames()
{
    for (int i = 0; i <= MT_MAXTYPES; i++)
    {
        g_sTankTypeNames[i][0] = '\0';
    }

    if (!LibraryExists("mutant_tanks"))
    {
        return;
    }

    char configName[PLATFORM_MAX_PATH];
    strcopy(configName, sizeof(configName), "mutant_tanks.cfg");
    ConVar configCvar = FindConVar("mt_configfile");
    if (configCvar != null)
    {
        configCvar.GetString(configName, sizeof(configName));
    }
    if (configName[0] == '\0')
    {
        return;
    }

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "data/mutant_tanks/%s", configName);
    KeyValues kv = new KeyValues("Mutant Tanks");
    if (!kv.ImportFromFile(path))
    {
        delete kv;
        return;
    }

    int maxType = MT_MAXTYPES;
    if (MutantTanksApiAvailable())
    {
        maxType = MT_GetMaxType();
        if (maxType > MT_MAXTYPES)
        {
            maxType = MT_MAXTYPES;
        }
    }

    char section[32];
    for (int type = 1; type <= maxType; type++)
    {
        Format(section, sizeof(section), "Tank #%d", type);
        kv.Rewind();
        if (!kv.JumpToKey(section, false))
        {
            continue;
        }
        if (!kv.JumpToKey("General", false))
        {
            continue;
        }
        kv.GetString("Tank Name", g_sTankTypeNames[type], sizeof(g_sTankTypeNames[]), "");
    }
    delete kv;
}

void GetTankTypeName(int type, char[] buffer, int size)
{
    if (type > 0 && type <= MT_MAXTYPES && g_sTankTypeNames[type][0] != '\0')
    {
        strcopy(buffer, size, g_sTankTypeNames[type]);
        return;
    }
    Format(buffer, size, "Mutant Tank #%d", type);
}

bool SpawnAdminTank(int admin, int type, bool takeover)
{
    if (!IsValidClient(admin) || !MutantTanksApiAvailable())
    {
        return false;
    }

    int minType = MT_GetMinType();
    int maxType = MT_GetMaxType();
    if (type < minType || type > maxType || !MT_IsTypeEnabled(type, 0))
    {
        PrintToChat(admin, "\x04[PVE]\x01 该 Tank 类型当前未启用，未执行操作。\x01");
        return false;
    }
    if (GetFeatureStatus(FeatureType_Native, "L4D2_SpawnTank") != FeatureStatus_Available)
    {
        PrintToChat(admin, "\x04[PVE]\x01 Left4DHooks 的 Tank 生成 native 不可用。\x01");
        return false;
    }

    float pos[3], ang[3];
    GetSpawnTransform(admin, ZOMBIE_TANK, pos, ang);
    int tank = L4D2_SpawnTank(pos, ang);
    if (tank <= 0)
    {
        PrintToChat(admin, "\x04[PVE]\x01 Tank 生成失败，可能被当前战役阶段或核心限制拦截。\x01");
        Audit(admin, 0, "spawn_tank_failed", "type=%d takeover=%d", type, takeover);
        return false;
    }

    DataPack pack;
    CreateDataTimer(g_cvAdminTankSpawnDelay.FloatValue, Timer_ApplyAdminTankType, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(GetClientUserId(admin));
    pack.WriteCell(tank);
    pack.WriteCell(type);
    pack.WriteCell(takeover);

    char tankName[64];
    GetTankTypeName(type, tankName, sizeof(tankName));
    PrintToChat(admin, "\x04[PVE]\x01 已请求生成 %s（类型 #%d）。", tankName, type);
    Audit(admin, 0, "spawn_tank", "type=%d name=%s takeover=%d", type, tankName, takeover);
    return true;
}

public Action Timer_ApplyAdminTankType(Handle timer, DataPack pack)
{
    pack.Reset();
    int admin = GetClientOfUserId(pack.ReadCell());
    int tankHint = pack.ReadCell();
    int type = pack.ReadCell();
    bool takeover = pack.ReadCell() != 0;

    int tank = IsLiveTank(tankHint) ? tankHint : FindLiveTank();
    if (!IsLiveTank(tank) || !MutantTanksApiAvailable())
    {
        if (IsValidClient(admin))
        {
            PrintToChat(admin, "\x04[PVE]\x01 Tank 已生成但未能应用 Mutant Tank 类型。\x01");
        }
        return Plugin_Stop;
    }

    MT_SetTankType(tank, type, true);
    if (takeover)
    {
        DataPack takeoverPack;
        CreateDataTimer(0.15, Timer_TakeoverSpawnedTank, takeoverPack, TIMER_FLAG_NO_MAPCHANGE);
        takeoverPack.WriteCell(GetClientUserId(admin));
        takeoverPack.WriteCell(tank);
        takeoverPack.WriteCell(type);
    }
    else if (IsValidClient(admin))
    {
        PrintToChat(admin, "\x04[PVE]\x01 Tank 类型已应用：#%d。", type);
    }
    return Plugin_Stop;
}

public Action Timer_TakeoverSpawnedTank(Handle timer, DataPack pack)
{
    pack.Reset();
    int admin = GetClientOfUserId(pack.ReadCell());
    int tankHint = pack.ReadCell();
    int type = pack.ReadCell();
    int tank = IsLiveTank(tankHint) ? tankHint : FindLiveTank();
    if (!IsValidClient(admin) || !IsLiveTank(tank))
    {
        return Plugin_Stop;
    }

    if (!TransferTankToAdmin(admin, tank))
    {
        PrintToChat(admin, "\x04[PVE]\x01 Tank 已生成，但接管失败；它将继续由 AI 控制。\x01");
        return Plugin_Stop;
    }
    MT_SetTankType(admin, type, true);
    PrintToChat(admin, "\x04[PVE]\x01 你已接管类型 #%d 的 Tank。", type);
    Audit(admin, admin, "takeover_tank", "type=%d source=%d", type, tank);
    return Plugin_Stop;
}

void TakeOverAdminTank(int admin, int type)
{
    if (!IsValidClient(admin) || !MutantTanksApiAvailable())
    {
        return;
    }
    if (GetFeatureStatus(FeatureType_Native, "L4D_ReplaceTank") != FeatureStatus_Available)
    {
        PrintToChat(admin, "\x04[PVE]\x01 当前 Left4DHooks 不支持 Tank 接管。\x01");
        return;
    }

    int tank = IsLiveTank(admin) ? admin : FindLiveTank();
    if (!IsLiveTank(tank))
    {
        PrintToChat(admin, "\x04[PVE]\x01 当前没有可接管的存活 Tank。\x01");
        return;
    }
    if (tank == admin)
    {
        MT_SetTankType(admin, type, true);
        PrintToChat(admin, "\x04[PVE]\x01 已将你当前控制的 Tank 切换为类型 #%d。", type);
        Audit(admin, admin, "set_tank_type", "type=%d", type);
        return;
    }

    if (!TransferTankToAdmin(admin, tank))
    {
        PrintToChat(admin, "\x04[PVE]\x01 Tank 接管准备失败，未改变当前玩家状态。\x01");
        return;
    }

    DataPack pack;
    CreateDataTimer(0.15, Timer_FinishAdminTankTakeover, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(GetClientUserId(admin));
    pack.WriteCell(type);
    pack.WriteCell(tank);
    PrintToChat(admin, "\x04[PVE]\x01 已请求接管现有 Tank，并应用类型 #%d。", type);
}

public Action Timer_FinishAdminTankTakeover(Handle timer, DataPack pack)
{
    pack.Reset();
    int admin = GetClientOfUserId(pack.ReadCell());
    int type = pack.ReadCell();
    int oldTank = pack.ReadCell();
    if (!IsLiveTank(admin) || !MutantTanksApiAvailable())
    {
        if (IsValidClient(admin))
        {
            PrintToChat(admin, "\x04[PVE]\x01 Tank 接管未完成；请确认当前仍在感染者阵营。\x01");
        }
        return Plugin_Stop;
    }

    MT_SetTankType(admin, type, true);
    PrintToChat(admin, "\x04[PVE]\x01 你已接管 Tank，并切换为类型 #%d。", type);
    Audit(admin, admin, "takeover_tank", "type=%d source=%d", type, oldTank);
    return Plugin_Stop;
}

bool TransferTankToAdmin(int admin, int tank)
{
    if (!IsValidClient(admin) || !IsLiveTank(tank) || admin == tank)
    {
        return admin == tank && IsLiveTank(admin);
    }

    if (GetClientTeam(admin) == TEAM_SURVIVOR || (GetClientTeam(admin) == TEAM_INFECTED && IsPlayerAlive(admin) && !IsGhostClient(admin)))
    {
        L4D_ReplaceWithBot(admin);
    }
    ChangeClientTeam(admin, 1);
    ChangeClientTeam(admin, TEAM_INFECTED);
    L4D_ReplaceTank(tank, admin);
    return true;
}

void SpawnWitchForAdmin(int admin, bool bride)
{
    if (!IsValidClient(admin))
    {
        return;
    }

    char nativeName[64];
    strcopy(nativeName, sizeof(nativeName), bride ? "L4D2_SpawnWitchBride" : "L4D2_SpawnWitch");
    if (GetFeatureStatus(FeatureType_Native, nativeName) != FeatureStatus_Available)
    {
        PrintToChat(admin, "\x04[PVE]\x01 当前 Left4DHooks 不支持该 Witch 生成 API；接管入口仅保留兼容占位。\x01");
        return;
    }

    float pos[3], ang[3];
    GetSpawnTransform(admin, ZOMBIE_WITCH, pos, ang);
    int entity = bride ? L4D2_SpawnWitchBride(pos, ang) : L4D2_SpawnWitch(pos, ang);
    if (entity <= 0)
    {
        PrintToChat(admin, "\x04[PVE]\x01 Witch 生成失败。\x01");
        Audit(admin, 0, "spawn_witch_failed", "bride=%d", bride);
        return;
    }

    PrintToChat(admin, "\x04[PVE]\x01 已请求生成 %s Witch。", bride ? "Bride" : "普通");
    Audit(admin, 0, "spawn_witch", "bride=%d entity=%d", bride, entity);
}

bool IsLiveTank(int client)
{
    return IsValidClient(client)
        && GetClientTeam(client) == TEAM_INFECTED
        && IsPlayerAlive(client)
        && HasEntProp(client, Prop_Send, "m_zombieClass")
        && GetEntProp(client, Prop_Send, "m_zombieClass") == ZOMBIE_TANK;
}

bool IsGhostClient(int client)
{
    return IsValidClient(client)
        && HasEntProp(client, Prop_Send, "m_isGhost")
        && GetEntProp(client, Prop_Send, "m_isGhost") != 0;
}

int FindLiveTank()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsLiveTank(client))
        {
            return client;
        }
    }
    return 0;
}

bool SpawnByToken(int admin, const char[] token)
{
    if (!IsValidClient(admin))
    {
        return false;
    }

    int zombieClass = 0;
    if (StrEqual(token, "smoker", false)) zombieClass = 1;
    else if (StrEqual(token, "boomer", false)) zombieClass = 2;
    else if (StrEqual(token, "hunter", false)) zombieClass = 3;
    else if (StrEqual(token, "spitter", false)) zombieClass = 4;
    else if (StrEqual(token, "jockey", false)) zombieClass = 5;
    else if (StrEqual(token, "charger", false)) zombieClass = 6;

    float pos[3], ang[3];
    GetSpawnTransform(admin, zombieClass == 0 ? ZOMBIE_TANK : zombieClass, pos, ang);
    int entity = -1;
    if (StrEqual(token, "tank", false))
    {
        if (GetFeatureStatus(FeatureType_Native, "L4D2_SpawnTank") == FeatureStatus_Available)
        {
            entity = L4D2_SpawnTank(pos, ang);
        }
    }
    else if (StrEqual(token, "witch", false))
    {
        if (GetFeatureStatus(FeatureType_Native, "L4D2_SpawnWitch") == FeatureStatus_Available)
        {
            entity = L4D2_SpawnWitch(pos, ang);
        }
    }
    else if (zombieClass > 0)
    {
        if (GetFeatureStatus(FeatureType_Native, "L4D2_SpawnSpecial") == FeatureStatus_Available)
        {
            entity = L4D2_SpawnSpecial(zombieClass, pos, ang);
        }
    }

    if (entity == -1)
    {
        PrintToChat(admin, "\x04[PVE]\x01 当前 Left4DHooks 不支持该生成 API，或生成失败。");
        return false;
    }

    PrintToChat(admin, "\x04[PVE]\x01 已请求生成 %s。", token);
    Audit(admin, 0, "spawn", "class=%s entity=%d", token, entity);
    return true;
}

void GetSpawnTransform(int client, int zombieClass, float pos[3], float ang[3])
{
    GetClientEyeAngles(client, ang);
    if (GetFeatureStatus(FeatureType_Native, "L4D_GetRandomPZSpawnPosition") == FeatureStatus_Available && L4D_GetRandomPZSpawnPosition(client, zombieClass, 8, pos))
    {
        return;
    }

    float origin[3], direction[3], right[3], up[3];
    GetClientAbsOrigin(client, origin);
    GetAngleVectors(ang, direction, right, up);
    ScaleVector(direction, 120.0);
    AddVectors(origin, direction, pos);
    pos[2] += 8.0;
}

int KillInfectedByClass(bool tanksOnly)
{
    int count;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidClient(client) || GetClientTeam(client) != TEAM_INFECTED || !IsPlayerAlive(client))
        {
            continue;
        }
        int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
        if ((tanksOnly && zombieClass == ZOMBIE_TANK) || (!tanksOnly && zombieClass >= 1 && zombieClass <= 6))
        {
            ForcePlayerSuicide(client);
            count++;
        }
    }
    return count;
}

void PrintPveInfo(int client)
{
    char map[64];
    GetCurrentMap(map, sizeof(map));
    int survivors, special, tanks;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i)) continue;
        int team = GetClientTeam(i);
        if (team == TEAM_SURVIVOR) survivors++;
        else if (team == TEAM_INFECTED && IsPlayerAlive(i))
        {
            int zombieClass = GetEntProp(i, Prop_Send, "m_zombieClass");
            if (zombieClass == ZOMBIE_TANK) tanks++;
            else if (zombieClass >= 1 && zombieClass <= 6) special++;
        }
    }
    ReplyToCommand(client, "[PVE] map=%s survivors=%d SI=%d tanks=%d shop_api=%s", map, survivors, special, tanks, ShopApiAvailable() ? "yes" : "no");
}

int FindSingleTarget(int client, int argIndex)
{
    char targetArg[MAX_TARGET_LENGTH], targetName[MAX_TARGET_LENGTH];
    bool tnIsMl;
    GetCmdArg(argIndex, targetArg, sizeof(targetArg));
    int targets[MAXPLAYERS];
    int count = ProcessTargetString(targetArg, client, targets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tnIsMl);
    if (count <= 0)
    {
        ReplyToTargetError(client, count);
        return 0;
    }
    return targets[0];
}

int FindItem(const char[] token)
{
    for (int i = 0; i < MAX_ADMIN_ITEMS; i++)
    {
        if (StrEqual(token, g_sItemClasses[i], false) || StrEqual(token, g_sItemNames[i], false))
        {
            return i;
        }
    }
    return -1;
}

bool IsValidTarget(int admin, int target)
{
    if (!IsValidClient(target))
    {
        if (IsValidClient(admin)) PrintToChat(admin, "\x04[PVE]\x01 目标玩家已经离开。");
        else ReplyToCommand(admin, "[PVE] Target is no longer available.");
        return false;
    }
    if (admin > 0 && !CanUserTarget(admin, target))
    {
        PrintToChat(admin, "\x04[PVE]\x01 你不能操作这个目标。");
        return false;
    }
    return true;
}

bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

bool IsPointsAdmin(int client)
{
    if (client == 0)
    {
        return true;
    }
    if ((GetUserFlagBits(client) & ADMFLAG_ROOT) != 0)
    {
        return true;
    }
    return CheckCommandAccess(client, "sm_pvepoints", ADMFLAG_CUSTOM6, true);
}

bool ShopApiAvailable()
{
    return LibraryExists("l4d2_campaign_shop") && GetFeatureStatus(FeatureType_Native, "L4D2CampaignShop_GetPoints") == FeatureStatus_Available;
}

void ReturnToAdminMenu(int client)
{
    if (IsValidClient(client) && g_hTopMenu != null)
    {
        g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
    }
}

void Audit(int admin, int target, const char[] action, const char[] detail, any ...)
{
    char adminName[MAX_NAME_LENGTH], adminAuth[64], targetName[MAX_NAME_LENGTH], targetAuth[64], message[256];
    if (IsValidClient(admin))
    {
        GetClientName(admin, adminName, sizeof(adminName));
        GetClientAuthId(admin, AuthId_Steam2, adminAuth, sizeof(adminAuth), true);
    }
    else
    {
        strcopy(adminName, sizeof(adminName), "CONSOLE");
        strcopy(adminAuth, sizeof(adminAuth), "CONSOLE");
    }
    if (IsValidClient(target))
    {
        GetClientName(target, targetName, sizeof(targetName));
        GetClientAuthId(target, AuthId_Steam2, targetAuth, sizeof(targetAuth), true);
    }
    else
    {
        strcopy(targetName, sizeof(targetName), "-");
        strcopy(targetAuth, sizeof(targetAuth), "-");
    }
    VFormat(message, sizeof(message), detail, 5);
    LogToFileEx("logs/pve_admin.log", "admin=\"%s\" steam=\"%s\" target=\"%s\" target_steam=\"%s\" action=\"%s\" %s", adminName, adminAuth, targetName, targetAuth, action, message);
}
