#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <mutant_tanks>
#include <l4d2_pve_mutant_tanks>

#define PLUGIN_VERSION "1.1.0"
#define EXPECTED_MT_TYPES 146
#define MAX_LIST_PARTS 192
#define MAX_CONFIG_LINE 256
#define CONFIG_REFRESH_MAX_ATTEMPTS 8
#define CONFIG_REFRESH_INITIAL_DELAY 0.1
#define CONFIG_REFRESH_RETRY_DELAY 1.0

public Plugin myinfo =
{
    name = "L4D2 PvE Mutant Tank Pool",
    author = "Codex",
    description = "Validated 146-type Mutant Tanks pool with weighted sources and chapter counters.",
    version = PLUGIN_VERSION,
    url = ""
};

ConVar g_cvEnabled;
ConVar g_cvWhitelist;
ConVar g_cvBlacklist;
ConVar g_cvWeights;
ConVar g_cvNormalPerChapter;

bool g_bAllowed[EXPECTED_MT_TYPES + 1];
int g_iWeight[EXPECTED_MT_TYPES + 1];
char g_sTypeNames[EXPECTED_MT_TYPES + 1][64];
bool g_bSeenType[EXPECTED_MT_TYPES + 1];
int g_iConfiguredTypeCount;
int g_iInvalidTypeHeaders;

PveMutantTankSource g_iPendingSource = PveMutantTankSource_Normal;
int g_iPendingType;
int g_iPendingGeneration;
int g_iNormalCount;
int g_iPurchasedCount;
int g_iAdminCount;

Handle g_hConfigRefreshTimer;
int g_iConfigRefreshAttempt;
int g_iConfigRefreshGeneration;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
    RegPluginLibrary("l4d2_pve_mutant_tanks");
    CreateNative("L4D2PveMutantTanks_MarkNextSpawn", Native_MarkNextSpawn);
    CreateNative("L4D2PveMutantTanks_GetCounts", Native_GetCounts);
    CreateNative("L4D2PveMutantTanks_IsRandomTypeAllowed", Native_IsRandomTypeAllowed);
    CreateNative("L4D2PveMutantTanks_GetTypeName", Native_GetTypeName);
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar("l4d2_pve_mt_pool_enable", "1", "Enable the PvPvE Mutant Tank type pool.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvWhitelist = CreateConVar("l4d2_pve_mt_whitelist", "1-146", "Random-pool type IDs and ranges. Admin-forced types bypass this list.", FCVAR_NOTIFY);
    g_cvBlacklist = CreateConVar("l4d2_pve_mt_blacklist", "41,61,97,122,123,128,145,146", "Random-pool type IDs excluded by default. Admin-forced types bypass this list.", FCVAR_NOTIFY);
    g_cvWeights = CreateConVar("l4d2_pve_mt_weights", "1-88:4,89-121:2,124-144:1,126:2", "Random weights as range:weight entries.", FCVAR_NOTIFY);
    g_cvNormalPerChapter = CreateConVar("l4d2_pve_mt_normal_per_chapter", "2", "Maximum automatic random Mutant Tanks per chapter. 0 means unlimited.", FCVAR_NOTIFY, true, 0.0, true, 32.0);

    HookConVarChange(g_cvWhitelist, ConVarChanged_Pool);
    HookConVarChange(g_cvBlacklist, ConVarChanged_Pool);
    HookConVarChange(g_cvWeights, ConVarChanged_Pool);
    RegAdminCmd("sm_pvemtstats", Command_Stats, ADMFLAG_GENERIC, "Show Mutant Tank pool counts and bounds.");
    RegAdminCmd("sm_pvemtvalidate", Command_Validate, ADMFLAG_CONFIG, "Validate all 146 Mutant Tank names, bounds and pool entries.");
    AutoExecConfig(true, "l4d2_pve_mutant_tanks");
    RefreshPoolState();
}

public void OnAllPluginsLoaded()
{
    StartConfigRefreshCycle(CONFIG_REFRESH_INITIAL_DELAY);
}

public void OnConfigsExecuted()
{
    StartConfigRefreshCycle(CONFIG_REFRESH_INITIAL_DELAY);
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "mutant_tanks"))
    {
        StartConfigRefreshCycle(CONFIG_REFRESH_INITIAL_DELAY);
    }
}

public void OnPluginEnd()
{
    CancelConfigRefreshTimer();
}

public void MT_OnConfigsLoad(int mode)
{
    if (mode == 1 || mode == 2)
    {
        StartConfigRefreshCycle(CONFIG_REFRESH_INITIAL_DELAY);
    }
}

public void OnMapStart()
{
    g_iNormalCount = 0;
    g_iPurchasedCount = 0;
    g_iAdminCount = 0;
    ClearPendingSpawn();
    RefreshPoolState();
}

public void OnMapEnd()
{
    CancelConfigRefreshTimer();
}

public void ConVarChanged_Pool(ConVar convar, const char[] oldValue, const char[] newValue)
{
    RebuildPool();
}

public any Native_MarkNextSpawn(Handle plugin, int numParams)
{
    int source = GetNativeCell(1);
    if (source < 0 || source > 2)
    {
        source = 0;
    }

    g_iPendingSource = view_as<PveMutantTankSource>(source);
    g_iPendingType = GetNativeCell(2);
    g_iPendingGeneration++;
    CreateTimer(3.0, Timer_ClearPending, g_iPendingGeneration, TIMER_FLAG_NO_MAPCHANGE);
    return 0;
}

public any Native_GetCounts(Handle plugin, int numParams)
{
    SetNativeCellRef(1, g_iNormalCount);
    SetNativeCellRef(2, g_iPurchasedCount);
    SetNativeCellRef(3, g_iAdminCount);
    return 0;
}

public any Native_IsRandomTypeAllowed(Handle plugin, int numParams)
{
    return IsRandomPoolType(GetNativeCell(1));
}

public any Native_GetTypeName(Handle plugin, int numParams)
{
    int type = GetNativeCell(1);
    if (type < 1 || type > EXPECTED_MT_TYPES || g_sTypeNames[type][0] == '\0')
    {
        return false;
    }

    SetNativeString(2, g_sTypeNames[type], GetNativeCell(3));
    return true;
}

public Action Timer_ClearPending(Handle timer, int generation)
{
    if (generation == g_iPendingGeneration)
    {
        ClearPendingSpawn();
    }
    return Plugin_Stop;
}

public Action Timer_RefreshConfig(Handle timer, int generation)
{
    if (timer == g_hConfigRefreshTimer)
    {
        g_hConfigRefreshTimer = null;
    }
    if (generation != g_iConfigRefreshGeneration)
    {
        return Plugin_Stop;
    }

    g_iConfigRefreshAttempt++;
    RefreshPoolState();

    int minType, maxType, allowed;
    if (IsUpstreamConfigReady(minType, maxType, allowed))
    {
        ValidateTypes(false, 0);
        LogMessage("Mutant Tanks config ready after %d refresh attempt(s): bounds=%d-%d allowed=%d.",
            g_iConfigRefreshAttempt, minType, maxType, allowed);
        return Plugin_Stop;
    }

    if (g_iConfigRefreshAttempt < CONFIG_REFRESH_MAX_ATTEMPTS)
    {
        g_hConfigRefreshTimer = CreateTimer(CONFIG_REFRESH_RETRY_DELAY, Timer_RefreshConfig, generation, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    }

    LogError("Mutant Tanks config was not ready after %d refresh attempts: names=%d/%d bounds=%d-%d allowed=%d.",
        g_iConfigRefreshAttempt, g_iConfiguredTypeCount, EXPECTED_MT_TYPES, minType, maxType, allowed);
    return Plugin_Stop;
}

public Action MT_OnTypeChosen(int &type, int tank)
{
    if (!g_cvEnabled.BoolValue)
    {
        return Plugin_Continue;
    }

    PveMutantTankSource source = g_iPendingSource;
    if (source == PveMutantTankSource_Admin)
    {
        if (!IsConfiguredType(g_iPendingType))
        {
            LogError("Rejected invalid admin-forced Mutant Tank type %d.", g_iPendingType);
            ClearPendingSpawn();
            return Plugin_Stop;
        }

        type = g_iPendingType;
        if (tank > 0)
        {
            g_iAdminCount++;
            ClearPendingSpawn();
        }
        return Plugin_Changed;
    }

    if (source == PveMutantTankSource_Normal && g_cvNormalPerChapter.IntValue > 0 && g_iNormalCount >= g_cvNormalPerChapter.IntValue)
    {
        ClearPendingSpawn();
        return Plugin_Stop;
    }

    int selected = PickWeightedType();
    if (selected <= 0)
    {
        LogError("No valid Mutant Tank type remains after whitelist/blacklist/weight filtering.");
        ClearPendingSpawn();
        return Plugin_Stop;
    }

    type = selected;
    if (tank > 0)
    {
        if (source == PveMutantTankSource_Purchase)
        {
            g_iPurchasedCount++;
        }
        else
        {
            g_iNormalCount++;
        }
        ClearPendingSpawn();
    }
    return Plugin_Changed;
}

public Action Command_Stats(int client, int args)
{
    int minType, maxType;
    GetTypeBounds(minType, maxType);
    ReplyToCommand(client, "[PVE] MT pool: names=%d/%d bounds=%d-%d allowed=%d normal=%d purchased=%d admin=%d pending=%d:%d",
        g_iConfiguredTypeCount, EXPECTED_MT_TYPES, minType, maxType, CountAllowedTypes(), g_iNormalCount, g_iPurchasedCount, g_iAdminCount, g_iPendingSource, g_iPendingType);
    return Plugin_Handled;
}

public Action Command_Validate(int client, int args)
{
    RefreshPoolState();
    ValidateTypes(true, client);
    return Plugin_Handled;
}

void StartConfigRefreshCycle(float delay)
{
    CancelConfigRefreshTimer();
    g_iConfigRefreshAttempt = 0;
    g_iConfigRefreshGeneration++;
    g_hConfigRefreshTimer = CreateTimer(delay, Timer_RefreshConfig, g_iConfigRefreshGeneration, TIMER_FLAG_NO_MAPCHANGE);
}

void CancelConfigRefreshTimer()
{
    if (g_hConfigRefreshTimer != null)
    {
        delete g_hConfigRefreshTimer;
        g_hConfigRefreshTimer = null;
    }
}

void RefreshPoolState()
{
    RefreshTypeNames();
    RebuildPool();
}

bool IsUpstreamConfigReady(int &minType, int &maxType, int &allowed)
{
    minType = 0;
    maxType = 0;
    allowed = 0;
    if (!IsFeatureAvailable("MT_GetMinType") || !IsFeatureAvailable("MT_GetMaxType"))
    {
        return false;
    }

    minType = MT_GetMinType();
    maxType = MT_GetMaxType();
    if (minType < 1 || maxType < EXPECTED_MT_TYPES || maxType < minType)
    {
        return false;
    }

    allowed = CountAllowedTypes();
    return g_iConfiguredTypeCount == EXPECTED_MT_TYPES && g_iInvalidTypeHeaders == 0 && allowed > 0;
}

void ClearPendingSpawn()
{
    g_iPendingSource = PveMutantTankSource_Normal;
    g_iPendingType = 0;
    g_iPendingGeneration++;
}

void RebuildPool()
{
    for (int type = 1; type <= EXPECTED_MT_TYPES; type++)
    {
        g_bAllowed[type] = false;
        g_iWeight[type] = 1;
    }

    char value[1024];
    g_cvWhitelist.GetString(value, sizeof(value));
    ApplyTypeList(value, true);
    g_cvBlacklist.GetString(value, sizeof(value));
    ApplyTypeList(value, false);
    g_cvWeights.GetString(value, sizeof(value));
    ApplyWeights(value);
}

void ApplyTypeList(const char[] list, bool allowed)
{
    char parts[MAX_LIST_PARTS][24];
    int count = ExplodeString(list, ",", parts, sizeof(parts), sizeof(parts[]));
    for (int i = 0; i < count; i++)
    {
        TrimString(parts[i]);
        int first, last;
        if (!ParseRange(parts[i], first, last) || first < 1 || last > EXPECTED_MT_TYPES)
        {
            continue;
        }

        for (int type = first; type <= last; type++)
        {
            g_bAllowed[type] = allowed;
        }
    }
}

void ApplyWeights(const char[] list)
{
    char parts[MAX_LIST_PARTS][32];
    char pair[2][24];
    int count = ExplodeString(list, ",", parts, sizeof(parts), sizeof(parts[]));
    for (int i = 0; i < count; i++)
    {
        TrimString(parts[i]);
        if (ExplodeString(parts[i], ":", pair, sizeof(pair), sizeof(pair[])) != 2)
        {
            continue;
        }

        int first, last;
        if (!ParseRange(pair[0], first, last) || first < 1 || last > EXPECTED_MT_TYPES)
        {
            continue;
        }

        int weight = ClampInt(StringToInt(pair[1]), 0, 1000);
        for (int type = first; type <= last; type++)
        {
            g_iWeight[type] = weight;
        }
    }
}

bool ParseRange(const char[] token, int &first, int &last)
{
    char bounds[2][16];
    int count = ExplodeString(token, "-", bounds, sizeof(bounds), sizeof(bounds[]));
    if (count < 1 || bounds[0][0] == '\0')
    {
        return false;
    }

    first = StringToInt(bounds[0]);
    last = count == 2 ? StringToInt(bounds[1]) : first;
    return first > 0 && last >= first;
}

int PickWeightedType()
{
    int minType, maxType;
    GetTypeBounds(minType, maxType);

    int total = 0;
    for (int type = minType; type <= maxType; type++)
    {
        if (IsRandomPoolType(type))
        {
            total += g_iWeight[type];
        }
    }
    if (total <= 0)
    {
        return 0;
    }

    int roll = GetRandomInt(1, total);
    for (int type = minType; type <= maxType; type++)
    {
        if (!IsRandomPoolType(type))
        {
            continue;
        }

        roll -= g_iWeight[type];
        if (roll <= 0)
        {
            return type;
        }
    }
    return 0;
}

bool IsRandomPoolType(int type)
{
    return IsConfiguredType(type) && IsMtEnabledType(type) && g_bAllowed[type] && g_iWeight[type] > 0;
}

bool IsConfiguredType(int type)
{
    if (type < 1 || type > EXPECTED_MT_TYPES || g_sTypeNames[type][0] == '\0')
    {
        return false;
    }

    int minType, maxType;
    GetTypeBounds(minType, maxType);
    return type >= minType && type <= maxType;
}

bool IsMtEnabledType(int type)
{
    // The project pool owns normal random eligibility. Mutant Tanks validates
    // the selected type during the actual spawn; querying its cold-start cache
    // here would make a hibernating server report an empty pool.
    return type >= 1 && type <= EXPECTED_MT_TYPES;
}

int CountAllowedTypes()
{
    int count;
    for (int type = 1; type <= EXPECTED_MT_TYPES; type++)
    {
        if (IsRandomPoolType(type))
        {
            count++;
        }
    }
    return count;
}

void RefreshTypeNames()
{
    for (int type = 1; type <= EXPECTED_MT_TYPES; type++)
    {
        g_sTypeNames[type][0] = '\0';
        g_bSeenType[type] = false;
    }
    g_iConfiguredTypeCount = 0;
    g_iInvalidTypeHeaders = 0;

    char configName[PLATFORM_MAX_PATH] = "mutant_tanks.cfg";
    ConVar configCvar = FindConVar("mt_configfile");
    if (configCvar != null)
    {
        configCvar.GetString(configName, sizeof(configName));
    }

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "data/mutant_tanks/%s", configName);
    File file = OpenFile(path, "r");
    if (file == null)
    {
        LogError("Unable to read Mutant Tanks config: %s", path);
        return;
    }

    char line[MAX_CONFIG_LINE];
    char parts[6][64];
    int currentType = 0;
    while (file.ReadLine(line, sizeof(line)))
    {
        TrimString(line);
        if (StrContains(line, "\"Tank #", false) == 0)
        {
            currentType = ParseTankType(line);
            if (currentType < 1 || currentType > EXPECTED_MT_TYPES || g_bSeenType[currentType])
            {
                g_iInvalidTypeHeaders++;
            }
            else
            {
                g_bSeenType[currentType] = true;
                g_iConfiguredTypeCount++;
            }
            continue;
        }
        if (currentType < 1 || currentType > EXPECTED_MT_TYPES)
        {
            continue;
        }

        int count = ExplodeString(line, "\"", parts, sizeof(parts), sizeof(parts[]));
        if (count >= 4 && StrEqual(parts[1], "Tank Name", false))
        {
            strcopy(g_sTypeNames[currentType], sizeof(g_sTypeNames[]), parts[3]);
        }
    }
    delete file;
}

int ParseTankType(const char[] line)
{
    char token[MAX_CONFIG_LINE];
    strcopy(token, sizeof(token), line);
    ReplaceString(token, sizeof(token), "\"Tank #", "");
    return StringToInt(token);
}

void ValidateTypes(bool reply, int client)
{
    int missing;
    for (int type = 1; type <= EXPECTED_MT_TYPES; type++)
    {
        if (!g_bSeenType[type] || g_sTypeNames[type][0] == '\0')
        {
            missing++;
            if (reply)
            {
                ReplyToCommand(client, "[PVE] Missing or malformed Mutant Tank type %d.", type);
            }
        }
    }

    int minType, maxType;
    GetTypeBounds(minType, maxType);
    int allowed = CountAllowedTypes();
    bool valid = missing == 0 && g_iConfiguredTypeCount == EXPECTED_MT_TYPES && g_iInvalidTypeHeaders == 0 && minType == 1 && maxType >= EXPECTED_MT_TYPES && allowed > 0;
    if (reply)
    {
        ReplyToCommand(client, "[PVE] MT audit: names=%d/%d bounds=%d-%d random_allowed=%d invalid_headers=%d missing=%d result=%s",
            g_iConfiguredTypeCount, EXPECTED_MT_TYPES, minType, maxType, allowed, g_iInvalidTypeHeaders, missing, valid ? "PASS" : "FAIL");
    }
    if (!valid)
    {
        LogError("Mutant Tanks validation failed: names=%d/%d invalid_headers=%d missing=%d bounds=%d-%d allowed=%d.",
            g_iConfiguredTypeCount, EXPECTED_MT_TYPES, g_iInvalidTypeHeaders, missing, minType, maxType, allowed);
    }
}

void GetTypeBounds(int &minType, int &maxType)
{
    minType = 1;
    maxType = EXPECTED_MT_TYPES;
    if (IsFeatureAvailable("MT_GetMinType") && IsFeatureAvailable("MT_GetMaxType"))
    {
        int nativeMin = MT_GetMinType();
        int nativeMax = MT_GetMaxType();
        if (nativeMin >= 1 && nativeMax >= nativeMin && nativeMax >= EXPECTED_MT_TYPES)
        {
            minType = nativeMin;
            maxType = nativeMax;
        }
    }

    minType = ClampInt(minType, 1, EXPECTED_MT_TYPES);
    maxType = ClampInt(maxType, minType, EXPECTED_MT_TYPES);
}

bool IsFeatureAvailable(const char[] name)
{
    return GetFeatureStatus(FeatureType_Native, name) == FeatureStatus_Available;
}

int ClampInt(int value, int minimum, int maximum)
{
    if (value < minimum)
    {
        return minimum;
    }
    if (value > maximum)
    {
        return maximum;
    }
    return value;
}
