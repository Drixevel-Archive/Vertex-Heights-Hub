/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Away from Keyboard"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.1"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>

#include <vertexheights>
#include <vh-permissions>
#include <vh-logs>

/*****************************/
//ConVars
ConVar convar_KickPlayer;

/*****************************/
//Globals

float g_LastOrigin[MAXPLAYERS + 1][3];
int g_OriginTicks[MAXPLAYERS + 1];
int g_AFKSteps[MAXPLAYERS + 1];

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

public void OnPluginStart()
{
	convar_KickPlayer = CreateConVar("sm_vertexheights_afk_kickplayer", "1");
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		if (g_AFKSteps[i] > 0)
		{
			SetEntityRenderMode(i, RENDER_NORMAL);
			SetEntityRenderColor(i, 255, 255, 255, 255);
		}
	}
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) < 2)
		return;
	
	float vecOrigin[3];
	GetClientAbsOrigin(client, vecOrigin);

	if (g_LastOrigin[client][0] == vecOrigin[0] && g_LastOrigin[client][1] == vecOrigin[1] && g_LastOrigin[client][2] == vecOrigin[2])
		g_OriginTicks[client]++;
	else
	{
		g_OriginTicks[client] = 0;

		if (g_AFKSteps[client] > 0)
		{
			Vertex_SendPrint(client, "You are no longer marked as inactive.");

			SetEntityRenderMode(client, RENDER_NORMAL);
			SetEntityRenderColor(client, 255, 255, 255, 255);
		}
		
		g_AFKSteps[client] = 0;
	}

	int admgroup = VH_GetAdmGroup(client);
	
	if (convar_KickPlayer.BoolValue && g_OriginTicks[client] > 9000 && g_AFKSteps[client] == 2 && !IsDrixevel(client) && admgroup == VH_NULLADMGRP)
	{
		VH_SystemLog("%N has been kicked for being inactive.", client);
		KickClient(client, "You were inactive, feel free to reconnect whenever.");
	}
	else if (g_OriginTicks[client] > 6500 && g_AFKSteps[client] == 1 && !IsDrixevel(client) && admgroup == VH_NULLADMGRP)
	{
		Vertex_SendPrint(client, "Please move soon otherwise you will be kicked for inactivity.");
		g_AFKSteps[client] = 2;
	}
	else if (g_OriginTicks[client] > 2500 && g_AFKSteps[client] == 0)
	{
		Vertex_SendPrint(client, "You have been marked as inactive.");
		g_AFKSteps[client] = 1;

		SetEntityRenderMode(client, RENDER_TRANSALPHA);
		SetEntityRenderColor(client, 255, 255, 255, 150);
	}

	g_LastOrigin[client][0] = vecOrigin[0];
	g_LastOrigin[client][1] = vecOrigin[1];
	g_LastOrigin[client][2] = vecOrigin[2];
}

public void OnClientDisconnect_Post(int client)
{
	g_LastOrigin[client][0] = 0.0;
	g_LastOrigin[client][1] = 0.0;
	g_LastOrigin[client][2] = 0.0;

	g_OriginTicks[client] = 0;
	g_AFKSteps[client] = 0;
}