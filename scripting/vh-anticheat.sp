/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Anticheat"
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
int g_InterpCheck[MAXPLAYERS + 1] = {-1, ...};

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
	CreateTimer(1.0, Timer_Seconds, _, TIMER_REPEAT);
}

public Action Timer_Seconds(Handle timer)
{
	int time = GetTime();

	float lerp;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i) || g_InterpCheck[i] != -1 && g_InterpCheck[i] > time)
			continue;
		
		lerp = GetEntPropFloat(i, Prop_Data, "m_fLerpTime");
		
		if (lerp > 0.110)
			KickClient(i, "Your interp is too high (%.3f / 0.100 Max)", lerp);
		else
			g_InterpCheck[i] = time + 10;
	}
}

public void OnClientDisconnect_Post(int client)
{
	g_InterpCheck[client] = -1;
}