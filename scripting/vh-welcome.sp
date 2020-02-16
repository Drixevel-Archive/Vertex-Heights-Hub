/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Welcome"
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

/*****************************/
//Globals
bool g_Connected[MAXPLAYERS + 1];

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

public void OnMapStart()
{
	PrecacheSound("ui/tv_tune.wav");
	PrecacheSound("ui/tv_tune2.wav");
	PrecacheSound("ui/tv_tune3.wav");
}

public void OnClientPutInServer(int client)
{
	char sSound[PLATFORM_MAX_PATH];
	switch (GetRandomInt(1, 3))
	{
		case 1:
			FormatEx(sSound, sizeof(sSound), "ui/tv_tune.wav");
		case 2:
			FormatEx(sSound, sizeof(sSound), "ui/tv_tune2.wav");
		case 3:
			FormatEx(sSound, sizeof(sSound), "ui/tv_tune3.wav");
	}

	EmitSoundToClient(client, sSound);
}

public void OnClientConnected(int client)
{
	if (!IsFakeClient(client))
		g_Connected[client] = true;
}

public void TF2_OnPlayerSpawn(int client, int team, int class)
{
	if (g_Connected[client] && IsPlayerAlive(client) && !IsFakeClient(client))
	{
		g_Connected[client] = false;
		CreateTimer(0.2, Timer_Welcome, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_Welcome(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (client > 0)
	{
		PrintHintText(client, "Welcome to Vertex Heights, type !vertex to see available commands.");
		SpeakResponseConcept(client, GetRandomInt(0, 1) == 0 ? "TLK_PLAYER_YES" : "TLK_PLAYER_CHEERS");
	}
}