/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Chat"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>
#include <chat-processor>

#include <vertexheights>
#include <vh-core>
#include <vh-permissions>
#include <vh-logs>

/*****************************/
//Globals
Database g_Database;

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
	Database.Connect(onSQLConnect, "default");
}

public void onSQLConnect(Database db, const char[] error, any data)
{
	if (db == null)
		VH_ThrowSystemLog("Error while connecting to database: %s", error);
	
	if (g_Database != null)
	{
		delete db;
		return;
	}

	g_Database = db;
	LogMessage("Connected to database successfully.");
}

public void CP_OnReloadChatData()
{
	int vid; int admgroup;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		if ((vid = VH_GetVertexID(i)) != VH_NULLID)
			VH_OnSynced(i, vid);
		
		if ((admgroup = VH_GetAdmGroup(i)) != VH_NULLADMGRP)
			VH_OnPermissionsParsed(i, admgroup);
	}
}

public void VH_OnSynced(int client, int vid)
{
	ChatProcessor_StripClientTags(client);

	if (IsDrixevel(client))
	{
		ChatProcessor_AddClientTag(client, "[Developer] ");
		ChatProcessor_SetTagColor(client, "[Developer] ", "{fullred}");
		ChatProcessor_SetNameColor(client, "{ancient}");
		ChatProcessor_SetChatColor(client, "{honeydew}");
	}
}

public void VH_OnPermissionsParsed(int client, int admgroup)
{
	ChatProcessor_StripClientTags(client);

	if (g_Database == null)
		return;

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT tag, tag_color, name_color, chat_color FROM `chat` WHERE admgroup = '%i';", admgroup);
	g_Database.Query(onParseChat, sQuery, GetClientUserId(client), DBPrio_Low);
}

public void onParseChat(Database db, DBResultSet results, const char[] error, any data)
{
	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return;
	
	if (results == null)
		VH_ThrowSystemLog("Error while parsing chat data: %s", error);
	
	if (results.FetchRow())
	{
		char sTag[64];
		results.FetchString(0, sTag, sizeof(sTag));

		if (strlen(sTag) > 0)
		{
			ChatProcessor_AddClientTag(client, sTag);

			char sTagColor[64];
			results.FetchString(1, sTagColor, sizeof(sTagColor));

			if (strlen(sTagColor) > 0)
				ChatProcessor_SetTagColor(client, sTag, sTagColor);
		}

		char sNameColor[64];
		results.FetchString(2, sNameColor, sizeof(sNameColor));

		if (strlen(sNameColor) > 0)
			ChatProcessor_SetNameColor(client, sNameColor);
		
		char sChatColor[64];
		results.FetchString(3, sChatColor, sizeof(sChatColor));

		if (strlen(sChatColor) > 0)
			ChatProcessor_SetChatColor(client, sChatColor);
	}
}