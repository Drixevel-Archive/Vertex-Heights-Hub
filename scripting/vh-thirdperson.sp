/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Thirdperson"
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
//#include <vh-settings>

/*****************************/
//Globals
bool g_Thirdperson[MAXPLAYERS + 1];

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
	RegConsoleCmd("sm_tp", Command_Thirdperson, "Set thirdperson view.");
	RegConsoleCmd("sm_thirdperson", Command_Thirdperson, "Set thirdperson view.");
	RegConsoleCmd("sm_fp", Command_Firstperson, "Set firstperson view.");
	RegConsoleCmd("sm_firstperosn", Command_Firstperson, "Set firstperson view.");
}

public void TF2_OnPlayerSpawn(int client, int team, int class)
{
	if (g_Thirdperson[client])
		CreateTimer(0.1, Timer_Thirdperson, GetClientUserId(client));
}

public Action Timer_Thirdperson(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (!IsPlayerIndex(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Stop;
	
	SetVariantInt(1);
	AcceptEntityInput(client, "SetForcedTauntCam");

	return Plugin_Stop;
}

public Action Command_Thirdperson(int client, int args)
{
	if (!IsPlayerAlive(client))
	{
		Vertex_SendPrint(client, "You must be alive to use this command.");
		return Plugin_Handled;
	}

	if (!GetEntProp(client, Prop_Send, "m_nForceTauntCam"))
	{
		SetVariantInt(1);
		AcceptEntityInput(client, "SetForcedTauntCam");
	}

	Vertex_SendPrint(client, "Thirdperson: [D]ON");
	g_Thirdperson[client] = true;

	return Plugin_Handled;
}

public Action Command_Firstperson(int client, int args)
{
	if (!IsPlayerAlive(client))
	{
		Vertex_SendPrint(client, "You must be alive to use this command.");
		return Plugin_Handled;
	}

	if (GetEntProp(client, Prop_Send, "m_nForceTauntCam"))
	{
		SetVariantInt(0);
		AcceptEntityInput(client, "SetForcedTauntCam");
	}

	Vertex_SendPrint(client, "Thirdperson: [D]OFF");
	g_Thirdperson[client] = false;

	return Plugin_Handled;
}

public void OnClientDisconnect_Post(int client)
{
	g_Thirdperson[client] = false;
}