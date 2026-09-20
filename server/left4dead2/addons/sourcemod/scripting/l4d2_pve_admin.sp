#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <l4d2_campaign_shop>

#define PLUGIN_VERSION "1.0.0"
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
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

TopMenu g_hTopMenu;
TopMenuObject g_iCategory = INVALID_TOPMENUOBJECT;
TopMenuObject g_iPlayers = INVALID_TOPMENUOBJECT;
TopMenuObject g_iEquipment = INVALID_TOPMENUOBJECT;
TopMenuObject g_iPoints = INVALID_TOPMENUOBJECT;
TopMenuObject g_iInfected = INVALID_TOPMENUOBJECT;
TopMenuObject g_iMaintenance = INVALID_TOPMENUOBJECT;

int g_iMenuMode[MAXPLAYERS + 1];
int g_iMenuTarget[MAXPLAYERS + 1];

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

    AutoExecConfig(true, "l4d2_pve_admin");

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
