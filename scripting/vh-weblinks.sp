/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Weblinks"
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
#include <vh-logs>

/*****************************/
//Globals
Database g_Database;
ArrayList g_Commands;
StringMap g_CommandURLs;

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
	g_Commands = new ArrayList(ByteCountToCells(64));
	g_CommandURLs = new StringMap();

	Database.Connect(onSQLConnect, "default");

	RegConsoleCmd("sm_weblinks", Command_Weblinks, "Open the available list of weblinks.");
	RegAdminCmd("sm_reloadweblinks", Command_ReloadWebLinks, ADMFLAG_ROOT, "Reload available web link commands.");
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

	ParseWeblinks();
}

public Action Command_Weblinks(int client, int args)
{
	Panel panel = new Panel();
	panel.SetTitle("Available Weblinks:");

	char sCommand[64];
	for (int i = 0; i < g_Commands.Length; i++)
	{
		g_Commands.GetString(i, sCommand, sizeof(sCommand));
		panel.DrawText(sCommand);
	}

	panel.Send(client, MenuHandler_Void, MENU_TIME_FOREVER);
	delete panel;

	return Plugin_Handled;
}

public int MenuHandler_Void(Menu menu, MenuAction action, int param1, int param2)
{
	delete menu;
}

public Action Command_ReloadWebLinks(int client, int args)
{
	ParseWeblinks();
	Vertex_SendPrint(client, "Weblinks have been reloaded.");
	return Plugin_Handled;
}

void ParseWeblinks()
{
	if (g_Database == null)
		return;
	
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT command, url FROM `weblinks`;");
	g_Database.Query(onParseWebLinks, sQuery, _, DBPrio_Low);
}

public void onParseWebLinks(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while parsing weblinks: %s", error);
	
	g_Commands.Clear();
	g_CommandURLs.Clear();
	
	char sCommand[64]; char sURL[256]; char sVariant[64];
	while (results.FetchRow())
	{
		results.FetchString(0, sCommand, sizeof(sCommand));
		g_Commands.PushString(sCommand);

		results.FetchString(1, sURL, sizeof(sURL));
		g_CommandURLs.SetString(sCommand, sURL);

		Format(sVariant, sizeof(sVariant), "!%s", sCommand);
		g_CommandURLs.SetString(sVariant, sURL);

		Format(sVariant, sizeof(sVariant), "/%s", sCommand);
		g_CommandURLs.SetString(sVariant, sURL);
	}
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	char sCommand[64];
	strcopy(sCommand, sizeof(sCommand), sArgs);
	TrimString(sCommand);

	char sURL[256];
	if (g_CommandURLs.GetString(sCommand, sURL, sizeof(sURL)) && strlen(sURL) > 0)
		OpenWebsite(client, sURL);
}

void OpenWebsite(int client, const char[] url)
{
	KeyValues kv = new KeyValues("data");
	kv.SetString("title", "Vertex Heights");
	kv.SetNum("type", MOTDPANEL_TYPE_URL);
	kv.SetString("msg", url);
	kv.SetNum("customsvr", 1);
	ShowVGUIPanel(client, "info", kv, true);
	delete kv;
}