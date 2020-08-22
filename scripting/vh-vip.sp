/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: VIP"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.2"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>

#include <vertexheights>
#include <vh-permissions>

/*****************************/
//Globals

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

bool IsVIP(int client)
{
	return VH_GetAdmGroup(client) != VH_NULLADMGRP;
}

public void VH_OnVIPFeatures(int client, Panel panel)
{
	panel.DrawText(" * Reserved Slot");
}

public void VH_OnPermissionsParsed(int client, int admgroup)
{
	if (GetRealPlayerCount() >= (MaxClients - 3) && !IsVIP(client))
		KickClient(client, "You cannot take up an admin slot.");
}

int GetRealPlayerCount()
{
	int count;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsClientSourceTV(i) || IsFakeClient(i))
			continue;

		count++;
	}

	return count;
}