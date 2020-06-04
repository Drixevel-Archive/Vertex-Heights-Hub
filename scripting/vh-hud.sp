/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Hud"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>

#include <vertexheights>
#include <vh-levels>
#include <vh-store>
#include <vh-settings>

/*****************************/
//Globals

Handle g_Sync_Hud;

//int g_Setting_HudPosition;

/*****************************/
//Plugin Info
public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("vh-hud");

	CreateNative("VH_SyncHud", Native_SyncHud);

	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", Event_OnRoundStart);
	HookEvent("player_spawn", Event_OnPlayerSpawn);

	g_Sync_Hud = CreateHudSynchronizer();

	for (int i = 1; i <= MaxClients; i++)
		ShowLogo(i);
	
	//g_Setting_HudPosition = VH_RegisterSetting("Hud Position", "hud_position", TYPE_VECTOR2D);
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			ClearSyncHud(i, g_Sync_Hud);
}

public void OnClientPutInServer(int client)
{
	ShowLogo(client);
}

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
		ShowLogo(i);
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	ShowLogo(client);
}

public int Native_SyncHud(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	ShowLogo(client);
}

void ShowLogo(int client)
{
	if (!IsPlayerIndex(client) || !IsClientInGame(client) || IsFakeClient(client))
		return;
	
	SetHudTextParams(0.008, 0.030, 9999999.0, 255, 0, 255, 255);
	ShowSyncHudText(client, g_Sync_Hud, "Level: %i\nExperience: %i\nCredits: %i", VH_GetLevel(client), VH_GetExperience(client), VH_GetCredits(client));
}