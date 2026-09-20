#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
    name = "L4D2 PvE Chinese Help Menu",
    author = "Codex",
    description = "Player-visible Chinese PvE/PvPvE start menu and command help.",
    version = "1.0.0",
    url = ""
};

ConVar g_cvEnabled;
ConVar g_cvWelcome;
ConVar g_cvWelcomeDelay;

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar("l4d2_pve_help_enable", "1", "Enable the player Chinese PvE help menu.", _, true, 0.0, true, 1.0);
    g_cvWelcome = CreateConVar("l4d2_pve_help_welcome", "1", "Show the help menu hint once when a player joins.", _, true, 0.0, true, 1.0);
    g_cvWelcomeDelay = CreateConVar("l4d2_pve_help_welcome_delay", "8.0", "Seconds after joining before the help hint is shown.", _, true, 0.0, true, 60.0);

    RegConsoleCmd("sm_pvehelp", Command_HelpMenu, "打开中文 PvE 开始菜单");
    RegConsoleCmd("sm_menu", Command_HelpMenu, "打开中文 PvE 开始菜单");
    RegConsoleCmd("sm_helpme", Command_HelpMenu, "打开中文 PvE 开始菜单");
    RegConsoleCmd("sm_帮助", Command_HelpMenu, "打开中文 PvE 开始菜单");
    RegConsoleCmd("sm_菜单", Command_HelpMenu, "打开中文 PvE 开始菜单");

    AutoExecConfig(true, "l4d2_pve_help_menu");
}

public void OnClientPutInServer(int client)
{
    if (g_cvWelcome.BoolValue && !IsFakeClient(client))
    {
        CreateTimer(g_cvWelcomeDelay.FloatValue, Timer_Welcome, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_Welcome(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client) || !g_cvEnabled.BoolValue)
    {
        return Plugin_Stop;
    }

    PrintToChat(client, "\x04[开始菜单]\x01 输入 \x03!菜单\x01 或 \x03!pvehelp\x01 打开中文帮助；按 H 可查看服务器帮助页。");
    return Plugin_Stop;
}

public Action Command_HelpMenu(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client) || !g_cvEnabled.BoolValue)
    {
        return Plugin_Handled;
    }

    ShowMainMenu(client);
    return Plugin_Handled;
}

void ShowMainMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Main);
    menu.SetTitle("无限火力 PvPvE 开始菜单");

    menu.AddItem("shop", "打开中文商城（!buy）");
    menu.AddItem("points", "查看战役积分（!points）");
    menu.AddItem("infected", "加入感染者阵营（!infected）");
    menu.AddItem("survivor", "返回幸存者阵营（!survivor）");
    menu.AddItem("zclass", "选择普通特感职业（!zclass）");
    menu.AddItem("tankqueue", "加入 Tank 抽签（!tankqueue）");
    menu.AddItem("notank", "退出 Tank 抽签（!notank）");
    menu.AddItem("details", "查看玩法与按键说明");
    menu.AddItem("commands", "查看全部中文指令");

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Main(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(item, info, sizeof(info));

        if (StrEqual(info, "shop"))
        {
            FakeClientCommand(client, "sm_buy");
        }
        else if (StrEqual(info, "points"))
        {
            FakeClientCommand(client, "sm_points");
        }
        else if (StrEqual(info, "infected"))
        {
            FakeClientCommand(client, "sm_infected");
        }
        else if (StrEqual(info, "survivor"))
        {
            FakeClientCommand(client, "sm_survivor");
        }
        else if (StrEqual(info, "zclass"))
        {
            FakeClientCommand(client, "sm_zclass");
        }
        else if (StrEqual(info, "tankqueue"))
        {
            FakeClientCommand(client, "sm_tankqueue");
        }
        else if (StrEqual(info, "notank"))
        {
            FakeClientCommand(client, "sm_notank");
        }
        else if (StrEqual(info, "details"))
        {
            ShowDetailsMenu(client);
        }
        else if (StrEqual(info, "commands"))
        {
            ShowCommandsMenu(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void ShowDetailsMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Info);
    menu.SetTitle("玩法与按键说明");
    menu.AddItem("info", "本服：无限火力战役 PvPvE", ITEMDRAW_DISABLED);
    menu.AddItem("info", "幸存者推进地图，感染者可由真人加入", ITEMDRAW_DISABLED);
    menu.AddItem("info", "H：默认打开服务器中文帮助页", ITEMDRAW_DISABLED);
    menu.AddItem("info", "Shift + Reload：切换普通/燃烧/爆炸升级弹", ITEMDRAW_DISABLED);
    menu.AddItem("info", "燃烧/爆炸升级弹：拾取后特殊弹药持续补充", ITEMDRAW_DISABLED);
    menu.AddItem("info", "积分只在当前战役有效，不是永久等级", ITEMDRAW_DISABLED);
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

void ShowCommandsMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Info);
    menu.SetTitle("全部中文指令");
    menu.AddItem("info", "!菜单 / !pvehelp：打开开始菜单", ITEMDRAW_DISABLED);
    menu.AddItem("info", "!buy / !shop：打开商城", ITEMDRAW_DISABLED);
    menu.AddItem("info", "!points / !money：查看积分", ITEMDRAW_DISABLED);
    menu.AddItem("info", "!infected / !特感：加入感染者", ITEMDRAW_DISABLED);
    menu.AddItem("info", "!survivor / !人类：返回幸存者", ITEMDRAW_DISABLED);
    menu.AddItem("info", "!zclass / !特感选择：选择普通特感", ITEMDRAW_DISABLED);
    menu.AddItem("info", "!tankqueue：加入 Tank 抽签", ITEMDRAW_DISABLED);
    menu.AddItem("info", "!notank：退出 Tank 抽签", ITEMDRAW_DISABLED);
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Info(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
    {
        ShowMainMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}
