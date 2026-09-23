/*
 * Copyright (C) 2019 LuxLuma. GPL-3.0-or-later.
 * Public source updated by HarryPotter at fbef0102 commit
 * e0fd18072b82498ed98535329f8b581262a8ff19.
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define PLUGIN_VERSION "1.1h-2026/2/11"
#define GAMEDATA "physics_object_pushfix"
#define MAX_EDICTS 2048

int g_iPropModelIndex[4];
char g_sPropModels[4][] =
{
    "models/props_equipment/oxygentank01.mdl",
    "models/props_junk/explosive_box001.mdl",
    "models/props_junk/gascan001a.mdl",
    "models/props_junk/propanecanister001a.mdl"
};
bool g_bIsPhysics[MAX_EDICTS + 1];

public Plugin myinfo =
{
    name = "[L4D2] physics_object_pushfix",
    author = "Lux, Harry",
    description = "Prevents players from accidentally body-pushing critical carryable physics props.",
    version = PLUGIN_VERSION,
    url = "https://github.com/LuxLuma/Left-4-fix"
};

public void OnPluginStart()
{
    GameData gameData = new GameData(GAMEDATA);
    if (gameData == null)
    {
        SetFailState("Failed to load %s.txt gamedata.", GAMEDATA);
    }
    DynamicDetour detour = DynamicDetour.FromConf(gameData, "MovePropAway");
    if (detour == null || !detour.Enable(Hook_Pre, MovePropAwayPre))
    {
        SetFailState("Failed to enable MovePropAway detour.");
    }
    delete detour;
    delete gameData;
    CreateConVar("physics_object_pushfix_version", PLUGIN_VERSION, "", FCVAR_NOTIFY | FCVAR_DONTRECORD);
}

public void OnMapStart()
{
    for (int i = 0; i < sizeof(g_sPropModels); i++)
    {
        int model = PrecacheModel(g_sPropModels[i], true);
        g_iPropModelIndex[i] = model > 0 ? model : -1;
    }
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity <= MaxClients || entity > MAX_EDICTS)
    {
        return;
    }
    g_bIsPhysics[entity] = false;
    if (strncmp(classname, "prop_physics", 12, false) == 0 || strncmp(classname, "physics_prop", 12, false) == 0)
    {
        RequestFrame(Frame_InspectProp, EntIndexToEntRef(entity));
    }
}

public void OnEntityDestroyed(int entity)
{
    if (entity > MaxClients && entity <= MAX_EDICTS)
    {
        g_bIsPhysics[entity] = false;
    }
}

void Frame_InspectProp(int entityRef)
{
    int entity = EntRefToEntIndex(entityRef);
    if (entity == INVALID_ENT_REFERENCE)
    {
        return;
    }
    int model = GetEntProp(entity, Prop_Data, "m_nModelIndex", 2);
    for (int i = 0; i < sizeof(g_iPropModelIndex); i++)
    {
        if (model == g_iPropModelIndex[i])
        {
            g_bIsPhysics[entity] = true;
            return;
        }
    }
}

public MRESReturn MovePropAwayPre(DHookReturn returnValue, DHookParam params)
{
    int entity = params.Get(1);
    if (entity > MaxClients && entity <= MAX_EDICTS && g_bIsPhysics[entity])
    {
        returnValue.Value = false;
        return MRES_Supercede;
    }
    return MRES_Ignored;
}
