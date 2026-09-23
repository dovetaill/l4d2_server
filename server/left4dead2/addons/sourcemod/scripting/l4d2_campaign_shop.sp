#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <l4d2_pve_overdrive>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define MAX_SHOP_ITEMS 49
#define SHOP_ITEM_LASER_SIGHT 9
#define SHOP_ITEM_DIRECT_INCENDIARY 10
#define SHOP_ITEM_DIRECT_EXPLOSIVE 11
#define SHOP_ITEM_FIRST_MELEE 31
#define SHOP_ITEM_CHAINSAW 37
#define SHOP_ITEM_LASER_PACK 45
#define SHOP_ITEM_SPECIAL_FIRST 46
#define SHOP_ITEM_SPECIAL_LAST 48
#define SHOP_CATEGORY_COUNT 11
#define SHOP_CATEGORY_MAX_ITEMS 20
#define UPGRADE_INCENDIARY (1 << 0)
#define UPGRADE_EXPLOSIVE (1 << 1)
#define UPGRADE_LASER_SIGHT (1 << 2)

native void L4D2SwitchAmmo_MarkLimited(int weapon);

public Plugin myinfo =
{
    name = "L4D2 战役商城",
    author = "Codex",
    description = "战役内存积分商城，不提供永久成长",
    version = "1.4.0",
    url = ""
};

ConVar g_hEnabled;
ConVar g_hMaxPoints;
ConVar g_hNotify;
ConVar g_hSpecialReward;
ConVar g_hWitchReward;
ConVar g_hTankReward;
ConVar g_hReviveReward;
ConVar g_hRescueReward;
ConVar g_hDefibReward;
ConVar g_hHealReward;
ConVar g_hAdminSteamId;
ConVar g_hAdminPoints;
ConVar g_hDirectAmmoMultiplier;
ConVar g_hDirectAmmoMax;
ConVar g_hDirectAmmoKillReward;
ConVar g_hDirectAmmoKillMax;
ConVar g_hOverdrivePrice;
ConVar g_hItemPrices[MAX_SHOP_ITEMS];

int g_iPoints[MAXPLAYERS + 1];
int g_iLimitedAmmoWeapon[MAXPLAYERS + 1];
int g_iLimitedAmmoRemaining[MAXPLAYERS + 1];
bool g_bLimitedAmmoShot[MAXPLAYERS + 1];
char g_sCampaign[64];

char g_sItemKeys[MAX_SHOP_ITEMS][32] =
{
    "pills",
    "adrenaline",
    "molotov",
    "pipe_bomb",
    "vomitjar",
    "first_aid_kit",
    "defibrillator",
    "upgrade_incendiary",
    "upgrade_explosive",
    "laser_sight",
    "ammo_incendiary",
    "ammo_explosive",
    "pistol",
    "pistol_magnum",
    "smg",
    "smg_silenced",
    "smg_mp5",
    "pumpshotgun",
    "shotgun_chrome",
    "autoshotgun",
    "shotgun_spas",
    "rifle",
    "rifle_ak47",
    "rifle_desert",
    "rifle_sg552",
    "hunting_rifle",
    "sniper_military",
    "sniper_scout",
    "sniper_awp",
    "rifle_m60",
    "grenade_launcher",
    "machete",
    "katana",
    "fireaxe",
    "crowbar",
    "baseball_bat",
    "frying_pan",
    "chainsaw",
    "cricket_bat",
    "electric_guitar",
    "tonfa",
    "knife",
    "shovel",
    "pitchfork",
    "golfclub",
    "laser_pack",
    "firework_crate",
    "gnome",
    "cola_bottles"
};

char g_sItemNames[MAX_SHOP_ITEMS][64] =
{
    "止痛药",
    "肾上腺素",
    "燃烧瓶",
    "土制炸弹",
    "胆汁罐",
    "医疗包",
    "电击器",
    "燃烧弹药包",
    "爆炸弹药包",
    "激光瞄准器",
    "燃烧弹弹药",
    "高爆弹药",
    "手枪",
    "马格南手枪",
    "冲锋枪",
    "消音冲锋枪",
    "MP5冲锋枪",
    "泵动式霰弹枪",
    "铬合金霰弹枪",
    "自动霰弹枪",
    "SPAS霰弹枪",
    "M16步枪",
    "AK-47步枪",
    "沙漠突击步枪",
    "SG552步枪",
    "猎枪",
    "军用狙击枪",
    "Scout狙击枪",
    "AWP狙击枪",
    "M60机枪",
    "榴弹发射器",
    "砍刀",
    "武士刀",
    "消防斧",
    "撬棍",
    "棒球棍",
    "平底锅",
    "电锯",
    "板球棒",
    "电吉他",
    "警棍",
    "战术小刀",
    "铁铲",
    "干草叉",
    "高尔夫球杆",
    "激光瞄准器包",
    "烟花箱",
    "小矮人",
    "可乐瓶"
};

char g_sItemClasses[MAX_SHOP_ITEMS][64] =
{
    "weapon_pain_pills",
    "weapon_adrenaline",
    "weapon_molotov",
    "weapon_pipe_bomb",
    "weapon_vomitjar",
    "weapon_first_aid_kit",
    "weapon_defibrillator",
    "weapon_upgradepack_incendiary",
    "weapon_upgradepack_explosive",
    "laser_sight",
    "weapon_upgradepack_incendiary",
    "weapon_upgradepack_explosive",
    "weapon_pistol",
    "weapon_pistol_magnum",
    "weapon_smg",
    "weapon_smg_silenced",
    "weapon_smg_mp5",
    "weapon_pumpshotgun",
    "weapon_shotgun_chrome",
    "weapon_autoshotgun",
    "weapon_shotgun_spas",
    "weapon_rifle",
    "weapon_rifle_ak47",
    "weapon_rifle_desert",
    "weapon_rifle_sg552",
    "weapon_hunting_rifle",
    "weapon_sniper_military",
    "weapon_sniper_scout",
    "weapon_sniper_awp",
    "weapon_rifle_m60",
    "weapon_grenade_launcher",
    "machete",
    "katana",
    "fireaxe",
    "crowbar",
    "baseball_bat",
    "frying_pan",
    "weapon_chainsaw",
    "cricket_bat",
    "electric_guitar",
    "tonfa",
    "knife",
    "shovel",
    "pitchfork",
    "golfclub",
    "weapon_upgradepack_laser",
    "weapon_fireworkcrate",
    "weapon_gnome",
    "weapon_cola_bottles"
};



int g_iDefaultPrices[MAX_SHOP_ITEMS] =
{
    15, 18, 25, 25, 30, 50, 70, 350, 450, 50, 45, 60,
    18, 28, 30, 35, 38, 35, 38, 45, 50, 40, 45, 350,
    260, 38, 48, 45, 9999, 550, 675, 32, 38, 35, 30, 30,
    30, 90, 30, 36, 30, 38, 32, 35, 35, 90, 40, 25, 35
};

char g_sCategoryNames[SHOP_CATEGORY_COUNT][64] =
{
    "医疗用品",
    "投掷物",
    "升级弹药与瞄具",
    "手枪",
    "冲锋枪",
    "霰弹枪",
    "步枪",
    "狙击枪",
    "重型武器",
    "近战武器",
    "特殊物品"
};

int g_iCategoryItems[SHOP_CATEGORY_COUNT][SHOP_CATEGORY_MAX_ITEMS] =
{
    {0, 1, 5, 6},
    {2, 3, 4},
    {7, 8, 9, 10, 11, 45},
    {12, 13},
    {14, 15, 16},
    {17, 18, 19, 20},
    {21, 22, 23, 24},
    {25, 26, 27, 28},
    {29, 30},
    {31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44},
    {46, 47, 48}
};

int g_iCategoryCounts[SHOP_CATEGORY_COUNT] =
{
    4, 3, 6, 2, 3, 4, 4, 4, 2, 14, 3
};


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
    MarkNativeAsOptional("L4D2SwitchAmmo_MarkLimited");
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_hEnabled = CreateConVar("l4d2_campaign_shop_enable", "1", "启用战役内存积分商城。", _, true, 0.0, true, 1.0);
    g_hMaxPoints = CreateConVar("l4d2_campaign_shop_max_points", "250", "单名玩家在一场战役中可持有的最大积分。", _, true, 0.0);
    g_hNotify = CreateConVar("l4d2_campaign_shop_notify", "1", "在聊天中显示积分奖励提示。", _, true, 0.0, true, 1.0);
    g_hSpecialReward = CreateConVar("l4d2_campaign_shop_special_reward", "1", "击杀特殊感染者给予的积分。", _, true, 0.0);
    g_hWitchReward = CreateConVar("l4d2_campaign_shop_witch_reward", "2", "击杀女巫给予的积分。", _, true, 0.0);
    g_hTankReward = CreateConVar("l4d2_campaign_shop_tank_reward", "3", "击杀坦克给予的积分。", _, true, 0.0);
    g_hReviveReward = CreateConVar("l4d2_campaign_shop_revive_reward", "5", "救起倒地队友给予的积分。", _, true, 0.0);
    g_hRescueReward = CreateConVar("l4d2_campaign_shop_rescue_reward", "3", "救援挂边队友给予的积分。", _, true, 0.0);
    g_hDefibReward = CreateConVar("l4d2_campaign_shop_defib_reward", "10", "使用电击器给予的积分。", _, true, 0.0);
    g_hHealReward = CreateConVar("l4d2_campaign_shop_heal_reward", "5", "治疗队友给予的积分。", _, true, 0.0);
    g_hAdminSteamId = CreateConVar("l4d2_campaign_shop_admin_steamid", "", "获得管理员战役积分的 Steam2 或 SteamID64。");
    g_hAdminPoints = CreateConVar("l4d2_campaign_shop_admin_points", "9999999", "为指定管理员自动发放的战役积分。", _, true, 0.0);
    g_hDirectAmmoMultiplier = CreateConVar("l4d2_campaign_shop_direct_ammo_multiplier", "5.0", "直接购买燃烧弹或高爆弹时，特殊弹药为弹匣容量的倍数。", _, true, 1.0, true, 20.0);
    g_hDirectAmmoMax = CreateConVar("l4d2_campaign_shop_direct_ammo_max", "250", "直接购买燃烧弹或高爆弹时的最大特殊弹药数。", _, true, 1.0, true, 999.0);
    g_hDirectAmmoKillReward = CreateConVar("l4d2_campaign_shop_direct_ammo_kill_reward", "1", "每次特感击杀返还的最少有限升级弹数量。", _, true, 0.0);
    g_hDirectAmmoKillMax = CreateConVar("l4d2_campaign_shop_direct_ammo_kill_max", "20", "每次特感击杀返还的最多有限升级弹数量。", _, true, 1.0, true, 20.0);
    g_hOverdrivePrice = CreateConVar("l4d2_campaign_shop_price_overdrive", "80", "15 秒临时 Overdrive 的战役积分价格。", _, true, 0.0);

    char priceCvar[64], priceDefault[16], priceDescription[128];
    for (int i = 0; i < MAX_SHOP_ITEMS; i++)
    {
        Format(priceCvar, sizeof(priceCvar), "l4d2_campaign_shop_price_%s", g_sItemKeys[i]);
        IntToString(g_iDefaultPrices[i], priceDefault, sizeof(priceDefault));
        Format(priceDescription, sizeof(priceDescription), "商城商品价格：%s。", g_sItemNames[i]);
        g_hItemPrices[i] = CreateConVar(priceCvar, priceDefault, priceDescription, _, true, 0.0);
    }

    RegPluginLibrary("l4d2_campaign_shop");
    CreateNative("L4D2CampaignShop_GetPoints", Native_GetPoints);
    CreateNative("L4D2CampaignShop_AddPoints", Native_AddPoints);
    CreateNative("L4D2CampaignShop_RemovePoints", Native_RemovePoints);
    CreateNative("L4D2CampaignShop_SetPoints", Native_SetPoints);

    RegConsoleCmd("sm_buy", Command_Buy, "打开战役商城。");
    RegConsoleCmd("sm_shop", Command_Buy, "打开战役商城。");
    RegConsoleCmd("sm_商城", Command_Buy, "打开战役商城。");
    RegConsoleCmd("sm_购买", Command_Buy, "打开战役商城。");
    RegConsoleCmd("sm_points", Command_Points, "显示当前战役积分。");
    RegConsoleCmd("sm_money", Command_Points, "显示当前战役积分。");
    RegConsoleCmd("sm_积分", Command_Points, "显示当前战役积分。");

    HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("witch_killed", Event_WitchKilled, EventHookMode_Post);
    HookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Post);
    HookEvent("defibrillator_used", Event_DefibrillatorUsed, EventHookMode_Post);
    HookEvent("heal_success", Event_HealSuccess, EventHookMode_Post);
    HookEvent("player_ledge_grab", Event_LedgeGrab, EventHookMode_Post);
    HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);

    AutoExecConfig(true, "l4d2_campaign_shop");
}

public void OnConfigsExecuted()
{
    ApplyAdminPointsToConnected();
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
    ResetLimitedAmmoState(client);
}

public void OnClientPostAdminCheck(int client)
{
    ApplyAdminPoints(client);
}

public void OnClientDisconnect(int client)
{
    g_iPoints[client] = 0;
    ResetLimitedAmmoState(client);
}

public Action Command_Buy(int client, int args)
{
    if (!g_hEnabled.BoolValue)
    {
        ReplyToCommand(client, "[商城] 商城当前已关闭。");
        return Plugin_Handled;
    }
    if (!IsRealSurvivor(client))
    {
        ReplyToCommand(client, "[商城] 请先加入幸存者队伍。");
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

    ReplyToCommand(client, "[商城] 当前战役积分：%d", g_iPoints[client]);
    return Plugin_Handled;
}

void ShowShop(int client)
{
    Menu menu = new Menu(MenuHandler_Category);
    char title[128];
    Format(title, sizeof(title), "战役商城｜积分：%d", g_iPoints[client]);
    menu.SetTitle(title);

    char overdrive[96];
    Format(overdrive, sizeof(overdrive), "Overdrive（15 秒）- %d 积分", g_hOverdrivePrice.IntValue);
    menu.AddItem("overdrive", overdrive);

    char info[16];
    for (int category = 0; category < SHOP_CATEGORY_COUNT; category++)
    {
        IntToString(category, info, sizeof(info));
        menu.AddItem(info, g_sCategoryNames[category]);
    }

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Category(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(item, info, sizeof(info));
        if (StrEqual(info, "overdrive"))
        {
            BuyOverdrive(client);
            if (IsRealSurvivor(client))
            {
                ShowShop(client);
            }
        }
        else
        {
            ShowShopCategory(client, StringToInt(info));
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowShopCategory(int client, int category)
{
    if (category < 0 || category >= SHOP_CATEGORY_COUNT)
    {
        ShowShop(client);
        return;
    }

    Menu menu = new Menu(MenuHandler_BuyCategory);
    char title[128];
    Format(title, sizeof(title), "%s｜积分：%d", g_sCategoryNames[category], g_iPoints[client]);
    menu.SetTitle(title);

    char info[32], display[128];
    for (int index = 0; index < g_iCategoryCounts[category]; index++)
    {
        int shopItem = g_iCategoryItems[category][index];
        Format(info, sizeof(info), "%d:%d", category, shopItem);
        Format(display, sizeof(display), "%s - %d 积分", g_sItemNames[shopItem], g_hItemPrices[shopItem].IntValue);
        menu.AddItem(info, display);
    }

    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_BuyCategory(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char info[32], pieces[2][16];
        menu.GetItem(item, info, sizeof(info));
        ExplodeString(info, ":", pieces, sizeof(pieces), sizeof(pieces[]));
        int category = StringToInt(pieces[0]);
        BuyItem(client, StringToInt(pieces[1]));
        if (IsRealSurvivor(client))
        {
            ShowShopCategory(client, category);
        }
    }
    else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
    {
        ShowShop(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void BuyOverdrive(int client)
{
    if (!IsRealSurvivor(client) || !IsPlayerAlive(client))
    {
        PrintToChat(client, "\x04[商城]\x01 只有存活的真人 Survivor 可以购买 Overdrive。");
        return;
    }
    if (GetFeatureStatus(FeatureType_Native, "L4D2PveOverdrive_IsAvailable") != FeatureStatus_Available
        || !L4D2PveOverdrive_IsAvailable())
    {
        PrintToChat(client, "\x04[商城]\x01 Overdrive 当前不可用，本次不扣除积分。");
        return;
    }
    int price = g_hOverdrivePrice.IntValue;
    if (g_iPoints[client] < price)
    {
        PrintToChat(client, "\x04[商城]\x01 积分不足，需要 %d，当前 %d。", price, g_iPoints[client]);
        return;
    }
    if (!L4D2PveOverdrive_Activate(client))
    {
        float cooldown = L4D2PveOverdrive_GetCooldownRemaining(client);
        PrintToChat(client, "\x04[商城]\x01 Overdrive 已生效或仍在冷却（%.1f 秒），本次不扣除积分。", cooldown);
        return;
    }
    g_iPoints[client] -= price;
    PrintToChat(client, "\x04[商城]\x01 已购买 Overdrive，花费 %d 积分。剩余积分：%d。", price, g_iPoints[client]);
}

void BuyItem(int client, int item)
{
    if (!IsRealSurvivor(client) || item < 0 || item >= MAX_SHOP_ITEMS)
    {
        return;
    }

    int price = g_hItemPrices[item].IntValue;
    if (g_iPoints[client] < price)
    {
        PrintToChat(client, "\x04[商城]\x01 积分不足，需要 %d，当前 %d。", price, g_iPoints[client]);
        return;
    }

    int entity = GiveShopItem(client, item);
    if (entity == -2)
    {
        PrintToChat(client, "\x04[商城]\x01 当前主武器已经装有激光瞄准器，本次不扣除积分。");
        return;
    }
    if (entity == -1)
    {
        if (item == SHOP_ITEM_LASER_SIGHT)
        {
            PrintToChat(client, "\x04[商城]\x01 请先装备一把可安装激光瞄具的主武器。");
        }
        else
        {
            PrintToChat(client, "\x04[商城]\x01 无法发放%s，可能是背包已满或地图不支持该物品。", g_sItemNames[item]);
        }
        return;
    }

    g_iPoints[client] -= price;
    PrintToChat(client, "\x04[商城]\x01 已购买%s，花费%d积分。剩余积分：%d。", g_sItemNames[item], price, g_iPoints[client]);
}

int GiveDirectUpgradeAmmo(int client, int upgradeBit)
{
    int weapon = GetPlayerWeaponSlot(client, 0);
    if (weapon <= MaxClients || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_upgradeBitVec") || !HasEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded") || !HasEntProp(weapon, Prop_Send, "m_iClip1"))
    {
        return -1;
    }

    int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
    if (clip <= 0)
    {
        return -1;
    }

    int amount = RoundToFloor(float(clip) * g_hDirectAmmoMultiplier.FloatValue);
    if (amount < clip)
    {
        amount = clip;
    }
    if (amount > g_hDirectAmmoMax.IntValue)
    {
        amount = g_hDirectAmmoMax.IntValue;
    }

    int upgrades = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
    upgrades &= ~(UPGRADE_INCENDIARY | UPGRADE_EXPLOSIVE);
    upgrades |= upgradeBit;
    SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", upgrades);
    SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", amount);

    g_iLimitedAmmoWeapon[client] = weapon;
    g_iLimitedAmmoRemaining[client] = amount;
    g_bLimitedAmmoShot[client] = false;

    if (GetFeatureStatus(FeatureType_Native, "L4D2SwitchAmmo_MarkLimited") == FeatureStatus_Available)
    {
        L4D2SwitchAmmo_MarkLimited(weapon);
    }

    return weapon;
}

int GiveShopItem(int client, int item)
{
    if (item == SHOP_ITEM_LASER_SIGHT)
    {
        int weapon = GetPlayerWeaponSlot(client, 0);
        if (weapon <= MaxClients || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_upgradeBitVec"))
        {
            return -1;
        }

        int upgrades = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
        if ((upgrades & UPGRADE_LASER_SIGHT) != 0)
        {
            return -2;
        }

        SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", upgrades | UPGRADE_LASER_SIGHT);
        return weapon;
    }

    if (item == SHOP_ITEM_DIRECT_INCENDIARY)
    {
        return GiveDirectUpgradeAmmo(client, UPGRADE_INCENDIARY);
    }
    if (item == SHOP_ITEM_DIRECT_EXPLOSIVE)
    {
        return GiveDirectUpgradeAmmo(client, UPGRADE_EXPLOSIVE);
    }

    if (item == SHOP_ITEM_LASER_PACK || (item >= SHOP_ITEM_SPECIAL_FIRST && item <= SHOP_ITEM_SPECIAL_LAST))
    {
        return GivePlayerItem(client, g_sItemClasses[item]);
    }

    if (item >= SHOP_ITEM_FIRST_MELEE && item < SHOP_ITEM_LASER_PACK)
    {
        if (item == SHOP_ITEM_CHAINSAW)
        {
            return GivePlayerItem(client, g_sItemClasses[item]);
        }

        int entity = CreateEntityByName("weapon_melee");
        if (entity == -1 || !IsValidEntity(entity))
        {
            return -1;
        }

        DispatchKeyValue(entity, "solid", "6");
        DispatchKeyValue(entity, "melee_script_name", g_sItemClasses[item]);
        DispatchSpawn(entity);
        EquipPlayerWeapon(client, entity);
        return entity;
    }

    return GivePlayerItem(client, g_sItemClasses[item]);
}


void ResetLimitedAmmoState(int client)
{
    g_iLimitedAmmoWeapon[client] = -1;
    g_iLimitedAmmoRemaining[client] = 0;
    g_bLimitedAmmoShot[client] = false;
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsRealSurvivor(client))
    {
        return;
    }

    g_bLimitedAmmoShot[client] = false;
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (weapon != g_iLimitedAmmoWeapon[client] || g_iLimitedAmmoRemaining[client] <= 0)
    {
        return;
    }

    g_iLimitedAmmoRemaining[client]--;
    g_bLimitedAmmoShot[client] = true;
}

bool IsLimitedAmmoKill(int client)
{
    if (!IsRealSurvivor(client) || !g_bLimitedAmmoShot[client])
    {
        return false;
    }

    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (weapon != g_iLimitedAmmoWeapon[client] || weapon <= MaxClients || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_upgradeBitVec"))
    {
        return false;
    }

    int upgrades = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
    return (upgrades & (UPGRADE_INCENDIARY | UPGRADE_EXPLOSIVE)) != 0;
}

void AwardLimitedAmmoKill(int client)
{
    if (!IsLimitedAmmoKill(client))
    {
        return;
    }

    g_bLimitedAmmoShot[client] = false;
    int minimum = g_hDirectAmmoKillReward.IntValue;
    int maximum = g_hDirectAmmoKillMax.IntValue;
    if (minimum <= 0 || maximum < minimum)
    {
        return;
    }

    int weapon = g_iLimitedAmmoWeapon[client];
    if (weapon <= MaxClients || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded"))
    {
        return;
    }

    int reward = GetRandomInt(minimum, maximum);
    int current = GetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
    int upgraded = current + reward;
    if (upgraded > g_hDirectAmmoMax.IntValue)
    {
        upgraded = g_hDirectAmmoMax.IntValue;
    }
    SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", upgraded);
    g_iLimitedAmmoRemaining[client] += reward;
    if (g_iLimitedAmmoRemaining[client] > g_hDirectAmmoMax.IntValue)
    {
        g_iLimitedAmmoRemaining[client] = g_hDirectAmmoMax.IntValue;
    }
    PrintToChat(client, "\x04[弹药]\x01 特感击杀返还 %d 发有限升级弹。", reward);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = ResolveEventClient(event, "attacker");
    if (!IsRealSurvivor(attacker) || victim <= 0 || !IsClientInGame(victim) || GetClientTeam(victim) != TEAM_INFECTED)
    {
        return;
    }

    AwardLimitedAmmoKill(attacker);

    int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
    if (zombieClass == 8)
    {
        AddPoints(attacker, g_hTankReward.IntValue, "坦克击杀");
    }
    else if (zombieClass > 0)
    {
        AddPoints(attacker, g_hSpecialReward.IntValue, "特感击杀");
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
        AddPoints(attacker, g_hWitchReward.IntValue, "女巫击杀");
    }
}

public void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
    int client = ResolveEventClient(event, "userid");
    if (IsRealSurvivor(client))
    {
        AddPoints(client, g_hReviveReward.IntValue, "救起队友");
    }
}

public void Event_DefibrillatorUsed(Event event, const char[] name, bool dontBroadcast)
{
    int client = ResolveEventClient(event, "userid");
    if (IsRealSurvivor(client))
    {
        AddPoints(client, g_hDefibReward.IntValue, "电击器救活");
    }
}

public void Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
    int client = ResolveEventClient(event, "userid");
    if (IsRealSurvivor(client))
    {
        AddPoints(client, g_hHealReward.IntValue, "治疗队友");
    }
}

public void Event_LedgeGrab(Event event, const char[] name, bool dontBroadcast)
{
    int client = ResolveEventClient(event, "userid");
    if (IsRealSurvivor(client))
    {
        AddPoints(client, g_hRescueReward.IntValue, "救援挂边队友");
    }
}

public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast)
{
    ResetPoints();
}

void ApplyAdminPointsToConnected()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsValidClient(client))
        {
            ApplyAdminPoints(client);
        }
    }
}

void ApplyAdminPoints(int client)
{
    if (!IsConfiguredAdmin(client))
    {
        return;
    }

    g_iPoints[client] = g_hAdminPoints.IntValue;
    if (g_hNotify.BoolValue)
    {
        PrintToChat(client, "\x04[商城]\x01 管理员战役积分：%d。", g_iPoints[client]);
    }
}

bool IsConfiguredAdmin(int client)
{
    if (!IsValidClient(client) || IsFakeClient(client))
    {
        return false;
    }

    char wanted[64], auth2[64], auth64[64];
    g_hAdminSteamId.GetString(wanted, sizeof(wanted));
    TrimString(wanted);
    if (wanted[0] == '\0')
    {
        return false;
    }

    if (GetClientAuthId(client, AuthId_Steam2, auth2, sizeof(auth2), true) && StrEqual(auth2, wanted, false))
    {
        return true;
    }
    return GetClientAuthId(client, AuthId_SteamID64, auth64, sizeof(auth64), true) && StrEqual(auth64, wanted, false);
}

int GetPointCap(int client)
{
    return IsConfiguredAdmin(client) ? g_hAdminPoints.IntValue : g_hMaxPoints.IntValue;
}

void AddPoints(int client, int amount, const char[] reason)
{
    if (!IsRealPlayer(client) || amount <= 0)
    {
        return;
    }

    int oldPoints = g_iPoints[client];
    g_iPoints[client] = oldPoints + amount;

    int cap = GetPointCap(client);
    if (g_iPoints[client] > cap)
    {
        g_iPoints[client] = cap;
    }

    int gained = g_iPoints[client] - oldPoints;
    if (g_hNotify.BoolValue && gained > 0)
    {
        PrintToChat(client, "\x04[商城]\x01 +%d积分（%s）。当前积分：%d。", gained, reason, g_iPoints[client]);
    }
}

void ResetPoints()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iPoints[i] = 0;
        g_bLimitedAmmoShot[i] = false;
    }
    ApplyAdminPointsToConnected();
}

int ResolveEventClient(Event event, const char[] field)
{
    int raw = event.GetInt(field);
    int client = GetClientOfUserId(raw);
    if (client > 0 && client <= MaxClients && IsClientInGame(client))
    {
        return client;
    }

    if (raw > 0 && raw <= MaxClients && IsClientInGame(raw))
    {
        return raw;
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

    AddPoints(client, amount, "管理员调整");
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
    int cap = GetPointCap(client);
    if (points > cap)
    {
        points = cap;
    }
    g_iPoints[client] = points;
    return points;
}
