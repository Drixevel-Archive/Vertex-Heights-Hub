/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Me"
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
#include <vh-filters>

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

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	char sMessage[255];
	strcopy(sMessage, sizeof(sMessage), sArgs);
	TrimString(sMessage);

	if (StrContains(sMessage, "/me ", false) == 0)
	{
		if (VH_FilterMessage(client, command, sMessage) != Plugin_Continue)
			return Plugin_Stop;
		
		ReplaceString(sMessage, sizeof(sMessage), "/me ", "");
		
		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(GetClientTeam(client) == 2 ? "{red}" : "{blue}");
		pack.WriteString(sMessage);

		RequestFrame(Frame_Me, pack);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void Frame_Me(DataPack pack)
{
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());

	char sColor[8];
	pack.ReadString(sColor, sizeof(sColor));

	char sMessage[255];
	pack.ReadString(sMessage, sizeof(sMessage));

	delete pack;

	if (client > 0)
		CPrintToChatAll("%s%N %s", sColor, client, sMessage);
}