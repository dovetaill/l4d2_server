#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <dual_primaries>

#define TEAM_SURVIVOR 2
#define UPGRADE_INCENDIARY (1 << 0)
#define UPGRADE_EXPLOSIVE (1 << 1)

public Plugin myinfo =
{
    name = "L4D2 Switch Upgrade Ammo",
    author = "Codex",
    description = "Shift+Reload switching with event-driven incendiary and explosive ammo refill",
    version = "1.3.0",
    url = ""
};

ConVar g_hEnable;
ConVar g_hInfinite;
ConVar g_hInfiniteUpgradeEnable;
ConVar g_hInfiniteUpgradeCount;

bool g_bCooldown[MAXPLAYERS + 1];
ArrayList g_hLimitedWeapons;
ArrayList g_hInfiniteWeapons;
ArrayList g_hInfiniteClipSizes;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
    RegPluginLibrary("l4d2_switch_upgrade_ammo");
    MarkNativeAsOptional("L4D2DualPrimaries_HasAlternate");
    MarkNativeAsOptional("L4D2DualPrimaries_Switch");
    CreateNative("L4D2SwitchAmmo_MarkLimited", Native_MarkLimited);
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_hLimitedWeapons = new ArrayList();
    g_hInfiniteWeapons = new ArrayList();
    g_hInfiniteClipSizes = new ArrayList(2);
    g_hEnable = CreateConVar("l4d2_switch_ammo_enable", "1", "Enable Shift+Reload upgrade ammo switching.", _, true, 0.0, true, 1.0);
    g_hInfinite = CreateConVar("l4d2_switch_ammo_infinite_load", "1", "Keep a large upgraded-ammo counter when switching.", _, true, 0.0, true, 1.0);
    g_hInfiniteUpgradeEnable = CreateConVar("l4d2_switch_ammo_infinite_upgrade_enable", "1", "Keep picked-up incendiary and explosive ammo replenished.", _, true, 0.0, true, 1.0);
    g_hInfiniteUpgradeCount = CreateConVar("l4d2_switch_ammo_infinite_upgrade_count", "999", "Special ammo count to restore for incendiary and explosive weapons.", _, true, 1.0, true, 9999.0);
    HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
    AutoExecConfig(true, "l4d2_switch_ammo");
}

public void OnMapStart()
{
    g_hLimitedWeapons.Clear();
    g_hInfiniteWeapons.Clear();
    g_hInfiniteClipSizes.Clear();
}

public void OnPluginEnd()
{
    delete g_hLimitedWeapons;
    delete g_hInfiniteWeapons;
    delete g_hInfiniteClipSizes;
}

public void OnClientDisconnect(int client)
{
    g_bCooldown[client] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (!g_hEnable.BoolValue || g_bCooldown[client] || !IsValidSurvivor(client) || !IsPlayerAlive(client))
    {
        return Plugin_Continue;
    }
    if (!(buttons & IN_RELOAD) || !(buttons & IN_SPEED))
    {
        return Plugin_Continue;
    }

    if (GetFeatureStatus(FeatureType_Native, "L4D2DualPrimaries_HasAlternate") == FeatureStatus_Available
        && L4D2DualPrimaries_HasAlternate(client))
    {
        L4D2DualPrimaries_Switch(client);
        buttons &= ~(IN_RELOAD | IN_SPEED);
        StartClientCooldown(client);
        return Plugin_Changed;
    }

    int active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (active <= MaxClients || !IsValidEntity(active) || !HasEntProp(active, Prop_Send, "m_upgradeBitVec"))
    {
        return Plugin_Continue;
    }

    if (IsTrackedWeapon(g_hLimitedWeapons, active))
    {
        int limitedBits = GetEntProp(active, Prop_Send, "m_upgradeBitVec");
        int limitedAmmo = HasEntProp(active, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded")
            ? GetEntProp(active, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded")
            : 0;
        if (limitedAmmo <= 0)
        {
            PrintToChat(client, "\x04[弹药]\x01 当前有限升级弹已经用完，请重新购买。");
        }
        else if (!(limitedBits & (UPGRADE_INCENDIARY | UPGRADE_EXPLOSIVE)))
        {
            PrintToChat(client, "\x04[弹药]\x01 当前有限升级弹状态无效，请重新购买。");
        }
        else
        {
            PrintToChat(client, "\x04[弹药]\x01 当前是商城购买的有限升级弹，打完后才能切换。");
        }
        StartClientCooldown(client);
        return Plugin_Continue;
    }

    if (!IsTrackedWeapon(g_hInfiniteWeapons, active))
    {
        PrintToChat(client, "\x04[弹药]\x01 请先使用燃烧或高爆升级包解锁无限升级弹。 ");
        StartClientCooldown(client);
        return Plugin_Continue;
    }

    int upgrades = GetEntProp(active, Prop_Send, "m_upgradeBitVec");
    int current = 0;
    if (upgrades & UPGRADE_INCENDIARY)
    {
        current = 1;
    }
    else if (upgrades & UPGRADE_EXPLOSIVE)
    {
        current = 2;
    }

    int next = (current + 1) % 3;
    upgrades &= ~(UPGRADE_INCENDIARY | UPGRADE_EXPLOSIVE);
    char label[32];
    if (next == 1)
    {
        upgrades |= UPGRADE_INCENDIARY;
        strcopy(label, sizeof(label), "燃烧弹");
    }
    else if (next == 2)
    {
        upgrades |= UPGRADE_EXPLOSIVE;
        strcopy(label, sizeof(label), "高爆弹");
    }
    else
    {
        strcopy(label, sizeof(label), "普通弹药");
    }

    SetEntProp(active, Prop_Send, "m_upgradeBitVec", upgrades);
    if (g_hInfinite.BoolValue && next != 0 && HasEntProp(active, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded"))
    {
        SetEntProp(active, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", g_hInfiniteUpgradeCount.IntValue);
    }
    PrintToChat(client, "\x04[弹药]\x01 已切换为 %s。", label);
    StartClientCooldown(client);
    return Plugin_Continue;
}

public void StartClientCooldown(int client)
{
    g_bCooldown[client] = true;
    CreateTimer(0.35, Timer_ClearCooldown, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ClearCooldown(Handle timer, int serial)
{
    int client = GetClientFromSerial(serial);
    if (client > 0)
    {
        g_bCooldown[client] = false;
    }
    return Plugin_Stop;
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hEnable.BoolValue || !g_hInfiniteUpgradeEnable.BoolValue)
    {
        return;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidSurvivor(client) && IsPlayerAlive(client))
    {
        RequestFrame(Frame_RefillUpgradeAmmo, GetClientSerial(client));
    }
}

public void Frame_RefillUpgradeAmmo(any serial)
{
    if (!g_hEnable.BoolValue || !g_hInfiniteUpgradeEnable.BoolValue)
    {
        return;
    }

    int client = GetClientFromSerial(serial);
    if (!IsValidSurvivor(client) || !IsPlayerAlive(client))
    {
        return;
    }

    RefillUpgradeAmmoWeapon(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"), g_hInfiniteUpgradeCount.IntValue);
}

void RefillUpgradeAmmoWeapon(int weapon, int amount)
{
    if (weapon <= MaxClients || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_upgradeBitVec") || !HasEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded"))
    {
        return;
    }

    int upgrades = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
    if (IsTrackedWeapon(g_hLimitedWeapons, weapon))
    {
        return;
    }

    if (!(upgrades & (UPGRADE_INCENDIARY | UPGRADE_EXPLOSIVE)))
    {
        return;
    }

    TrackWeapon(g_hInfiniteWeapons, weapon);
    if (HasEntProp(weapon, Prop_Send, "m_iClip1"))
    {
        int rememberedClip = GetRememberedInfiniteClip(weapon);
        if (rememberedClip < 0)
        {
            RememberInfiniteClip(weapon);
        }
        else if (GetEntProp(weapon, Prop_Send, "m_iClip1") != rememberedClip)
        {
            SetEntProp(weapon, Prop_Send, "m_iClip1", rememberedClip);
        }
    }
    if (GetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded") != amount)
    {
        SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", amount);
    }
}

public any Native_MarkLimited(Handle plugin, int numParams)
{
    int weapon = GetNativeCell(1);
    if (weapon <= MaxClients || !IsValidEntity(weapon))
    {
        return false;
    }

    RemoveTrackedWeapon(g_hInfiniteWeapons, weapon);
    RemoveInfiniteClip(weapon);
    TrackWeapon(g_hLimitedWeapons, weapon);
    return true;
}

void RememberInfiniteClip(int weapon)
{
    if (weapon <= MaxClients || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_iClip1"))
    {
        return;
    }
    PruneInfiniteClipSizes();
    int ref = EntIndexToEntRef(weapon);
    int index = g_hInfiniteClipSizes.FindValue(ref);
    int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
    if (index == -1)
    {
        int values[2];
        values[0] = ref;
        values[1] = clip;
        g_hInfiniteClipSizes.PushArray(values);
    }
    else
    {
        g_hInfiniteClipSizes.Set(index, clip, 1);
    }
}

int GetRememberedInfiniteClip(int weapon)
{
    PruneInfiniteClipSizes();
    int index = g_hInfiniteClipSizes.FindValue(EntIndexToEntRef(weapon));
    return index == -1 ? -1 : g_hInfiniteClipSizes.Get(index, 1);
}

void RemoveInfiniteClip(int weapon)
{
    int index = g_hInfiniteClipSizes.FindValue(EntIndexToEntRef(weapon));
    if (index != -1)
    {
        g_hInfiniteClipSizes.Erase(index);
    }
}

void PruneInfiniteClipSizes()
{
    for (int i = g_hInfiniteClipSizes.Length - 1; i >= 0; i--)
    {
        if (EntRefToEntIndex(g_hInfiniteClipSizes.Get(i, 0)) == INVALID_ENT_REFERENCE)
        {
            g_hInfiniteClipSizes.Erase(i);
        }
    }
}

void TrackWeapon(ArrayList list, int weapon)
{
    PruneWeaponList(list);
    int ref = EntIndexToEntRef(weapon);
    if (list.FindValue(ref) == -1)
    {
        list.Push(ref);
    }
}

bool IsTrackedWeapon(ArrayList list, int weapon)
{
    PruneWeaponList(list);
    return list.FindValue(EntIndexToEntRef(weapon)) != -1;
}

void RemoveTrackedWeapon(ArrayList list, int weapon)
{
    int ref = EntIndexToEntRef(weapon);
    int index = list.FindValue(ref);
    if (index != -1)
    {
        list.Erase(index);
    }
}

void PruneWeaponList(ArrayList list)
{
    for (int i = list.Length - 1; i >= 0; i--)
    {
        if (EntRefToEntIndex(list.Get(i)) == INVALID_ENT_REFERENCE)
        {
            list.Erase(i);
        }
    }
}

bool IsValidSurvivor(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}
