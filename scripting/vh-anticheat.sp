/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Anticheat"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.1"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <tf2_stocks>

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

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
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

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_SetTransmit, OnSetTransmit);
}

public void OnClientDisconnect_Post(int client)
{
	g_InterpCheck[client] = -1;
}

public Action OnSetTransmit(int client, int other)
{
	if (other < 1 || other > MaxClients || client == other)
		return Plugin_Continue;
	
	if (!IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	if (!IsClientConnected(other) || !IsClientInGame(other) || GetPlayerDistance(client, other) <= 60.0)
		return Plugin_Continue;
	
	int team = GetClientTeam(client);

	if (team < 2 || team == GetClientTeam(other))
		return Plugin_Continue;
	
	if (!IsInvisible(client) || GetEntPropFloat(client, Prop_Send, "m_flCloakMeter") <= 0.0)
		return Plugin_Continue;
	
	return Plugin_Handled;
}

float GetPlayerDistance(int client1 ,int client2)
{
	float vec1[3];
	float vec2[3];
	GetClientAbsOrigin(client1,vec1);
	GetClientAbsOrigin(client2,vec2);
	return GetVectorDistance(vec1,vec2);
}

bool IsInvisible(int client)
{
	return (TF2_IsPlayerInCondition(client, TFCond_Cloaked) &&
		!TF2_IsPlayerInCondition(client, TFCond_Jarated) &&
		!TF2_IsPlayerInCondition(client, TFCond_OnFire) &&
		!TF2_IsPlayerInCondition(client, TFCond_Milked));
}