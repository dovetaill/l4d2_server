#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define MAX_HELP_LINES 12
#define HELP_TEXT_LENGTH 256

public Plugin myinfo =
{
    name = "L4D2 PvE Chinese Help Menu",
    author = "Codex",
    description = "Player-visible Chinese PvE/PvPvE start menu and command help.",
    version = "1.1.0",
    url = ""
};

ConVar g_cvEnabled;
ConVar g_cvWelcome;
ConVar g_cvWelcomeDelay;
ConVar g_cvAnnounceInterval;
Handle g_hAnnouncementTimer;
int g_iAnnouncementIndex;

char g_sHelpTitle[HELP_TEXT_LENGTH];
char g_sAnnouncement[HELP_TEXT_LENGTH];
char g_sDetails[MAX_HELP_LINES][HELP_TEXT_LENGTH];
char g_sCommands[MAX_HELP_LINES][HELP_TEXT_LENGTH];

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar("l4d2_pve_help_enable", "1", "Enable the player Chinese PvE help menu.", _, true, 0.0, true, 1.0);
    g_cvWelcome = CreateConVar("l4d2_pve_help_welcome", "1", "Show the help menu hint once when a player joins.", _, true, 0.0, true, 1.0);
    g_cvWelcomeDelay = CreateConVar("l4d2_pve_help_welcome_delay", "8.0", "Seconds after joining before the help hint is shown.", _, true, 0.0, true, 60.0);
    g_cvAnnounceInterval = CreateConVar("l4d2_pve_help_announce_interval", "120.0", "Seconds between player-visible Chinese help announcements.", _, true, 30.0, true, 600.0);

    RegConsoleCmd("sm_pvehelp", Command_HelpMenu, "打开中文 PvE 开始菜单");
    RegConsoleCmd("sm_menu", Command_HelpMenu, "打开中文 PvE 开始菜单");
    RegConsoleCmd("sm_helpme", Command_HelpMenu, "打开中文 PvE 开始菜单");
    RegConsoleCmd("sm_帮助", Command_HelpMenu, "打开中文 PvE 开始菜单");
    RegConsoleCmd("sm_菜单", Command_HelpMenu, "打开中文 PvE 开始菜单");
    RegAdminCmd("sm_pvehelpreload", Command_ReloadHelp, ADMFLAG_CONFIG, "重新加载 PvE 帮助菜单 KeyValues 配置");

    AutoExecConfig(true, "l4d2_pve_help_menu");
}

public void OnConfigsExecuted()
{
    LoadHelpContent();
    RestartAnnouncementTimer();
}

public void OnPluginEnd()
{
    if (g_hAnnouncementTimer != null)
    {
        delete g_hAnnouncementTimer;
        g_hAnnouncementTimer = null;
    }
}

public void OnClientPutInServer(int client)
{
    if (g_cvWelcome.BoolValue && !IsFakeClient(client))
    {
        RestartAnnouncementTimer();
        CreateTimer(g_cvWelcomeDelay.FloatValue, Timer_Welcome, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void OnClientDisconnect(int client)
{
    if (!IsFakeClient(client))
    {
        RequestFrame(Frame_RefreshAnnouncementTimer);
    }
}

public void Frame_RefreshAnnouncementTimer(any data)
{
    RestartAnnouncementTimer();
}

public Action Timer_Welcome(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client) || !g_cvEnabled.BoolValue)
    {
        return Plugin_Stop;
    }

    PrintToChat(client, "%s", g_sAnnouncement);
    return Plugin_Stop;
}

void RestartAnnouncementTimer()
{
    if (g_hAnnouncementTimer != null)
    {
        delete g_hAnnouncementTimer;
        g_hAnnouncementTimer = null;
    }
    g_iAnnouncementIndex = 0;
    if (g_cvEnabled.BoolValue && g_cvAnnounceInterval.FloatValue > 0.0 && CountRealClients() > 0)
    {
        g_hAnnouncementTimer = CreateTimer(g_cvAnnounceInterval.FloatValue, Timer_AnnounceHelp, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_AnnounceHelp(Handle timer)
{
    if (CountRealClients() == 0)
    {
        g_hAnnouncementTimer = null;
        return Plugin_Stop;
    }
    if (!g_cvEnabled.BoolValue)
    {
        return Plugin_Continue;
    }
    PrintToChatAll("%s", g_sAnnouncement);
    for (int i = 0; i < MAX_HELP_LINES; i++)
    {
        int index = (g_iAnnouncementIndex + i) % MAX_HELP_LINES;
        if (g_sDetails[index][0] != '\0')
        {
            PrintToChatAll("[玩法提示] %s", g_sDetails[index]);
            g_iAnnouncementIndex = (index + 1) % MAX_HELP_LINES;
            break;
        }
    }
    return Plugin_Continue;
}

public Action Command_ReloadHelp(int client, int args)
{
    LoadHelpContent();
    ReplyToCommand(client, "[PvE帮助] 配置已重新加载。");
    return Plugin_Handled;
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
    menu.SetTitle("%s", g_sHelpTitle);

    menu.AddItem("shop", "打开中文商城（!buy）");
    menu.AddItem("points", "查看战役积分（!points）");
    menu.AddItem("infected", "加入感染者阵营（!infected）");
    menu.AddItem("survivor", "返回幸存者阵营（!survivor）");
    menu.AddItem("zclass", "选择普通特感职业（!zclass）");
    menu.AddItem("tankqueue", "加入 Tank 抽签（!tankqueue）");
    menu.AddItem("notank", "退出 Tank 抽签（!notank）");
    menu.AddItem("witchqueue", "加入 Witch 抽签（!witchqueue）");
    menu.AddItem("nowitch", "退出 Witch 抽签（!nowitch）");
    menu.AddItem("hud", "切换全局 HUD（!hud）");
    menu.AddItem("overdrive", "查看 Overdrive（!overdrive）");
    menu.AddItem("pveperf", "查看性能状态（!pveperf）");
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
        else if (StrEqual(info, "witchqueue"))
        {
            FakeClientCommand(client, "sm_witchqueue");
        }
        else if (StrEqual(info, "nowitch"))
        {
            FakeClientCommand(client, "sm_nowitch");
        }
        else if (StrEqual(info, "hud"))
        {
            FakeClientCommand(client, "sm_hud");
        }
        else if (StrEqual(info, "overdrive"))
        {
            FakeClientCommand(client, "sm_overdrive");
        }
        else if (StrEqual(info, "pveperf"))
        {
            FakeClientCommand(client, "sm_pveperf");
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
    for (int i = 0; i < MAX_HELP_LINES; i++)
    {
        if (g_sDetails[i][0] != '\0')
        {
            menu.AddItem("info", g_sDetails[i], ITEMDRAW_DISABLED);
        }
    }
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

void ShowCommandsMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Info);
    menu.SetTitle("全部中文指令");
    for (int i = 0; i < MAX_HELP_LINES; i++)
    {
        if (g_sCommands[i][0] != '\0')
        {
            menu.AddItem("info", g_sCommands[i], ITEMDRAW_DISABLED);
        }
    }
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

void LoadHelpContent()
{
    SetDefaultHelpContent();

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/pve_help_content.cfg");

    KeyValues kv = new KeyValues("PvEHelp");
    if (!kv.ImportFromFile(path))
    {
        LogMessage("[PvE帮助] 未找到或无法读取 %s，继续使用内置默认内容。", path);
        delete kv;
        return;
    }

    char value[HELP_TEXT_LENGTH];
    kv.GetString("title", value, sizeof(value), "");
    if (value[0] != '\0')
    {
        strcopy(g_sHelpTitle, sizeof(g_sHelpTitle), value);
    }

    kv.GetString("announcement", value, sizeof(value), "");
    if (value[0] != '\0')
    {
        NormalizeChatText(value, sizeof(value));
        strcopy(g_sAnnouncement, sizeof(g_sAnnouncement), value);
    }

    if (kv.JumpToKey("details"))
    {
        LoadLines(kv, g_sDetails);
        kv.Rewind();
    }

    if (kv.JumpToKey("commands"))
    {
        LoadLines(kv, g_sCommands);
        kv.Rewind();
    }

    delete kv;
    LogMessage("[PvE帮助] 已加载 KeyValues 配置：%s", path);
}

void LoadLines(KeyValues kv, char lines[MAX_HELP_LINES][HELP_TEXT_LENGTH])
{
    char key[8];
    char value[HELP_TEXT_LENGTH];

    for (int i = 0; i < MAX_HELP_LINES; i++)
    {
        Format(key, sizeof(key), "%d", i + 1);
        kv.GetString(key, value, sizeof(value), "");
        if (value[0] != '\0')
        {
            NormalizeChatText(value, sizeof(value));
            strcopy(lines[i], HELP_TEXT_LENGTH, value);
        }
    }
}

void NormalizeChatText(char[] value, int maxlen)
{
    ReplaceString(value, maxlen, "\\x01", "", false);
    ReplaceString(value, maxlen, "\\x02", "", false);
    ReplaceString(value, maxlen, "\\x03", "", false);
    ReplaceString(value, maxlen, "\\x04", "", false);
    ReplaceString(value, maxlen, "\\x05", "", false);
    ReplaceString(value, maxlen, "\\x06", "", false);
    ReplaceString(value, maxlen, "\\x07", "", false);
}

void SetDefaultHelpContent()
{
    strcopy(g_sHelpTitle, sizeof(g_sHelpTitle), "无限火力 PvPvE 开始菜单");
    strcopy(g_sAnnouncement, sizeof(g_sAnnouncement), "[开始菜单] 输入 !菜单 或 !pvehelp 打开中文帮助；按 H 可查看服务器帮助页。");

    for (int i = 0; i < MAX_HELP_LINES; i++)
    {
        g_sDetails[i][0] = '\0';
        g_sCommands[i][0] = '\0';
    }

    strcopy(g_sDetails[0], HELP_TEXT_LENGTH, "本服：无限火力战役 PvPvE");
    strcopy(g_sDetails[1], HELP_TEXT_LENGTH, "幸存者推进地图，感染者可由真人加入");
    strcopy(g_sDetails[2], HELP_TEXT_LENGTH, "H：默认打开服务器中文帮助页");
    strcopy(g_sDetails[3], HELP_TEXT_LENGTH, "Shift + Reload：有第二把主武器时切换武器，否则切换升级弹");
    strcopy(g_sDetails[4], HELP_TEXT_LENGTH, "幸存者之间无队友伤害，不使用反伤或扣除攻击者生命");
    strcopy(g_sDetails[5], HELP_TEXT_LENGTH, "积分只在当前战役有效，不保存永久等级或 RPG 属性");
    strcopy(g_sDetails[6], HELP_TEXT_LENGTH, "Tank 与 Witch 采用候选队列抽签；可随时退出抽签");
    strcopy(g_sDetails[7], HELP_TEXT_LENGTH, "AntiRush 先警告，再安全传送并扣除少量本局积分");
    strcopy(g_sDetails[8], HELP_TEXT_LENGTH, "Overdrive 是商城购买的 15 秒临时 WeaponHandling 强化");
    strcopy(g_sDetails[9], HELP_TEXT_LENGTH, "普通感染者尸体快速清理；幸存者尸体不会自动清理");

    strcopy(g_sCommands[0], HELP_TEXT_LENGTH, "!菜单 / !pvehelp：打开开始菜单");
    strcopy(g_sCommands[1], HELP_TEXT_LENGTH, "!buy / !shop：打开商城");
    strcopy(g_sCommands[2], HELP_TEXT_LENGTH, "!points / !money：查看积分");
    strcopy(g_sCommands[3], HELP_TEXT_LENGTH, "!infected / !特感：加入感染者");
    strcopy(g_sCommands[4], HELP_TEXT_LENGTH, "!survivor / !人类：返回幸存者");
    strcopy(g_sCommands[5], HELP_TEXT_LENGTH, "!zclass / !特感选择：选择普通特感");
    strcopy(g_sCommands[6], HELP_TEXT_LENGTH, "!tankqueue：加入 Tank 抽签");
    strcopy(g_sCommands[7], HELP_TEXT_LENGTH, "!notank：退出 Tank 抽签");
    strcopy(g_sCommands[8], HELP_TEXT_LENGTH, "!witchqueue / !nowitch：加入 / 退出 Witch 抽签");
    strcopy(g_sCommands[9], HELP_TEXT_LENGTH, "!hud：切换个人全局 HUD 显示");
    strcopy(g_sCommands[10], HELP_TEXT_LENGTH, "!overdrive：查看临时强化与冷却状态");
    strcopy(g_sCommands[11], HELP_TEXT_LENGTH, "!pveperf：查看 Entity、SI、Common 与风险级别");
}

int CountRealClients()
{
    int count;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && !IsFakeClient(client))
        {
            count++;
        }
    }
    return count;
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
