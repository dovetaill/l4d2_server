#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.0.0"
#define HOSTNAME_MAX_LENGTH 256

public Plugin myinfo =
{
    name = "L4D2 Unicode Hostname",
    author = "Codex",
    description = "Loads a UTF-8 server hostname after the engine config parser has finished.",
    version = PLUGIN_VERSION,
    url = ""
};

ConVar g_cvEnabled;
ConVar g_cvHostname;
char g_sHostnameFile[PLATFORM_MAX_PATH];
Handle g_hApplyTimer;

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar(
        "l4d2_unicode_hostname_enabled",
        "1",
        "Apply the UTF-8 hostname from addons/sourcemod/configs/pve_hostname.txt.",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );
    g_cvHostname = FindConVar("hostname");
    if (g_cvHostname == null)
    {
        SetFailState("The hostname convar was not found.");
    }
    HookConVarChange(g_cvHostname, OnHostnameChanged);

    BuildPath(Path_SM, g_sHostnameFile, sizeof(g_sHostnameFile), "configs/pve_hostname.txt");
    RegServerCmd("sm_pvehostname_reload", Command_Reload, "Reload the UTF-8 server hostname.");
    AutoExecConfig(true, "l4d2_unicode_hostname");
    ApplyHostname();
    StartApplyTimer();
}

public void OnConfigsExecuted()
{
    ApplyHostname();
    StartApplyTimer();
}

public void OnMapStart()
{
    ApplyHostname();
    StartApplyTimer();
}

public void OnPluginEnd()
{
    if (g_hApplyTimer != null)
    {
        delete g_hApplyTimer;
        g_hApplyTimer = null;
    }
}

void StartApplyTimer()
{
    if (g_hApplyTimer != null)
    {
        delete g_hApplyTimer;
    }
    g_hApplyTimer = CreateTimer(2.0, Timer_Apply, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Command_Reload(int args)
{
    ApplyHostname();
    return Plugin_Handled;
}

public void OnHostnameChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (g_cvEnabled != null && g_cvEnabled.BoolValue)
    {
        ApplyHostname();
    }
}

public Action Timer_Apply(Handle timer)
{
    ApplyHostname();
    return Plugin_Continue;
}

void ApplyHostname()
{
    if (!g_cvEnabled.BoolValue)
    {
        return;
    }

    File file = OpenFile(g_sHostnameFile, "r");
    if (file == null)
    {
        LogError("Hostname file is missing: %s", g_sHostnameFile);
        return;
    }

    char hostname[HOSTNAME_MAX_LENGTH];
    bool read = file.ReadLine(hostname, sizeof(hostname));
    delete file;
    if (!read)
    {
        LogError("Hostname file is empty: %s", g_sHostnameFile);
        return;
    }

    TrimString(hostname);
    if (hostname[0] == '\0')
    {
        LogError("Hostname file contains an empty name: %s", g_sHostnameFile);
        return;
    }

    char current[HOSTNAME_MAX_LENGTH];
    g_cvHostname.GetString(current, sizeof(current));
    if (!StrEqual(current, hostname))
    {
        g_cvHostname.SetString(hostname, true, false);
        PrintToServer("[UnicodeHostname] Applied hostname: %s", hostname);
    }
}
