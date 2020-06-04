/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Settings"
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
#include <vh-core>
#include <vh-settings>
#include <vh-logs>

/*****************************/
//Globals

Database g_Database;

enum struct Settings
{
	char name[64];
	char unique[64];
	int type;

	void RegisterSetting(const char[] name, const char[] unique, int type)
	{
		strcopy(this.name, 64, name);
		strcopy(this.unique, 64, unique);
		this.type = type;
	}
}

Settings g_Settings[1024];
int g_TotalSettings;

StringMap g_PlayerSettings[MAXPLAYERS + 1];

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

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("vh-settings");

	CreateNative("VH_RegisterSetting", Native_RegisterSetting);
	//CreateNative("VH_GetSettingValue", Native_GetSettingValue);

	return APLRes_Success;
}

public void OnPluginStart()
{
	Database.Connect(onSQLConnect, "default");

	RegConsoleCmd("sm_settings", Command_Settings);

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i))
			OnClientConnected(i);
}

public void onSQLConnect(Database db, const char[] error, any data)
{
	if (db == null)
		VH_ThrowSystemLog("Error while connecting to database: %s", error);
	
	g_Database = db;
	g_Database.SetCharset("utf8");

	int vid;
	for (int i = 1; i <= MaxClients; i++)
		if ((vid = VH_GetVertexID(i)) != VH_NULLID)
			VH_OnSynced(i, vid);
}

public void OnClientConnected(int client)
{
	delete g_PlayerSettings[client];
	g_PlayerSettings[client] = new StringMap();
}

public void VH_OnSynced(int client, int vid)
{
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT setting, value FROM `settings` WHERE vid = '%i';", vid);
	g_Database.Query(onParseSettings, sQuery, GetClientUserId(client), DBPrio_Low);
}

public void onParseSettings(Database db, DBResultSet results, const char[] error, any data)
{
	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return;
	
	if (results == null)
		VH_ThrowSystemLog("Error while parsing player settings data: %s", error);
	
	char sSetting[64]; char sValue[512];
	while (results.FetchRow())
	{
		results.FetchString(0, sSetting, sizeof(sSetting));
		results.FetchString(1, sValue, sizeof(sValue));
		g_PlayerSettings[client].SetString(sSetting, sValue);
	}
}

public Action Command_Settings(int client, int args)
{
	OpenSettingsMenu(client);
	return Plugin_Handled;
}

void OpenSettingsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Settings);
	menu.SetTitle("Vertex Heights :: Settings");

	char sID[16]; char sName[64];
	for (int i = 0; i < g_TotalSettings; i++)
	{
		IntToString(i, sID, sizeof(sID));
		FormatEx(sName, sizeof(sName), "%s", g_Settings[i].name);
		menu.AddItem(sID, sName);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Settings(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{

		}
		case MenuAction_End:
			delete menu;
	}
}

public int Native_RegisterSetting(Handle plugin, int numParams)
{
	char name[64];
	GetNativeString(1, name, sizeof(name));

	char unique[64];
	GetNativeString(2, unique, sizeof(unique));

	int type = GetNativeCell(3);

	g_Settings[g_TotalSettings].RegisterSetting(name, unique, type);
	int value = g_TotalSettings;

	g_TotalSettings++;
	return value;
}