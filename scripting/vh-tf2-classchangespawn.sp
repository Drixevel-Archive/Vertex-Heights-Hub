/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights][TF2] :: Class Change Spawn"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-tf>
#include <misc-colors>

#include <vertexheights>

/*****************************/
//Globals
int g_Delay[MAXPLAYERS + 1] = {-1, ...};

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

public Action OnClientCommand(int client, int args)
{
	char sCommand[32];
	GetCmdArg(0, sCommand, sizeof(sCommand));

	if (StrEqual(sCommand, "joinclass"))
	{
		int time = GetTime();
		if (g_Delay[client] != -1 && g_Delay[client] > time)
			return Plugin_Stop;
		
		g_Delay[client] = time + 2;

		char sClass[32];
		GetCmdArg(1, sClass, sizeof(sClass));

		int health = GetClientHealth(client);

		TFClassType class = TF2_GetClass(sClass);
		TF2_SetPlayerClass(client, class, false, true);
		TF2_RegeneratePlayer(client);
		SetEntityHealth(client, health);

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void OnClientDisconnect_Post(int client)
{
	g_Delay[client] = -1;
}