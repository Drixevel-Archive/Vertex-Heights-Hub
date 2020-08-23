/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Chat"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.1"
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
#include <vh-store>

/*****************************/
//Globals
Database g_Database;

enum struct Chat
{
	char tag[64];
	char tagcolor[64];
	char namecolor[64];
	char chatcolor[64];

	void Clear()
	{
		this.tag[0] = '\0';
		this.tagcolor[0] = '\0';
		this.namecolor[0] = '\0';
		this.chatcolor[0] = '\0';
	}

	void AddTag(const char[] tag)
	{
		strcopy(this.tag, 64, tag);
	}

	void AddTagColor(const char[] tagcolor)
	{
		strcopy(this.tagcolor, 64, tagcolor);
	}

	void AddNameColor(const char[] namecolor)
	{
		strcopy(this.namecolor, 64, namecolor);
	}

	void AddChatColor(const char[] chatcolor)
	{
		strcopy(this.chatcolor, 64, chatcolor);
	}
}

Chat g_Chat[MAXPLAYERS + 1];

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
	int admgroup;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		g_Chat[i].Clear();
		
		if ((admgroup = VH_GetAdmGroup(i)) != VH_NULLADMGRP)
			VH_OnPermissionsParsed(i, admgroup);
	}
}

public void VH_OnPermissionsParsed(int client, int admgroup)
{
	if (g_Database == null)
		return;
	
	g_Chat[client].Clear();

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
		g_Chat[client].AddTag(sTag);

		char sTagColor[64];
		results.FetchString(1, sTagColor, sizeof(sTagColor));
		g_Chat[client].AddTagColor(sTagColor);

		char sNameColor[64];
		results.FetchString(2, sNameColor, sizeof(sNameColor));
		g_Chat[client].AddNameColor(sNameColor);
		
		char sChatColor[64];
		results.FetchString(3, sChatColor, sizeof(sChatColor));
		g_Chat[client].AddChatColor(sChatColor);
	}
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool & processcolors, bool & removecolors)
{
	bool changed;

	char sItem[64];

	char sTag[64];
	strcopy(sTag, sizeof(sTag), g_Chat[author].tag);

	char sTagColor[64];
	strcopy(sTagColor, sizeof(sTagColor), g_Chat[author].tagcolor);

	char sNameColor[64];
	strcopy(sNameColor, sizeof(sNameColor), g_Chat[author].namecolor);

	char sChatColor[64];
	strcopy(sChatColor, sizeof(sChatColor), g_Chat[author].chatcolor);

	if (VH_GetEquipped(author, "Chat Tags", 0, sItem, sizeof(sItem)))
		VH_GetItemData(sItem, sTag, sizeof(sTag));

	if (VH_GetEquipped(author, "Tag Colors", 0, sItem, sizeof(sItem)))
		VH_GetItemData(sItem, sTagColor, sizeof(sTagColor));

	if (VH_GetEquipped(author, "Name Colors", 0, sItem, sizeof(sItem)))
		VH_GetItemData(sItem, sNameColor, sizeof(sNameColor));

	if (VH_GetEquipped(author, "Chat Colors", 0, sItem, sizeof(sItem)))
		VH_GetItemData(sItem, sChatColor, sizeof(sChatColor));

	if (strlen(sTag) > 0)
	{
		Format(name, MAXLENGTH_NAME, "%s%s%s%s", sTagColor, sTag, sNameColor, name);
		changed = true;
	}
	else if (strlen(sNameColor) > 0)
	{
		Format(name, MAXLENGTH_NAME, "%s%s", sNameColor, name);
		changed = true;
	}

	if (strlen(sChatColor) > 0)
	{
		Format(message, MAXLENGTH_MESSAGE, "%s%s", sChatColor, message);
		changed = true;
	}

	return changed ? Plugin_Changed : Plugin_Continue;
}