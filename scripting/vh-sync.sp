/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Sync"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.4"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>
#include <system2>

#include <vertexheights>
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

	RegAdminCmd("sm_sync", Command_Sync, ADMFLAG_ROOT);
	RegAdminCmd("sm_forcesync", Command_ForceSync, ADMFLAG_ROOT);
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

public Action Command_Sync(int client, int args)
{
	SyncPlugins();
	Vertex_SendPrint(client, "Vertex Hub files have been synced.");
	return Plugin_Handled;
}

public Action Command_ForceSync(int client, int args)
{
	SyncPlugins(true);
	Vertex_SendPrint(client, "Vertex Hub files have been force synced.");
	return Plugin_Handled;
}

public void OnAllPluginsLoaded()
{
	SyncPlugins();
}

void SyncPlugins(bool forced = false)
{
	if (g_Database != null)
		g_Database.Query(onParsePlugins, "SELECT type, name, version FROM `sync_files` WHERE ignored = 0;", forced, DBPrio_Low);
}

public void onParsePlugins(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while syncing server files: %s", error);
	
	bool forced = data;
	
	char sType[32]; char sName[256]; char sCheck[256]; char sVersion[64]; Handle plugin; char sCurrent[64];
	while (results.FetchRow())
	{
		results.FetchString(0, sType, sizeof(sType));
		results.FetchString(1, sName, sizeof(sName));

		if (StrEqual(sType, "plugin", false))
		{
			results.FetchString(2, sVersion, sizeof(sVersion));

			FormatEx(sCheck, sizeof(sCheck), "%s.smx", sName);
			plugin = FindPluginByFile(sCheck);

			if (plugin == null || GetPluginStatus(plugin) != Plugin_Running)
				continue;
			
			if (!forced && GetPluginInfo(plugin, PlInfo_Version, sCurrent, sizeof(sCurrent)) && StrEqual(sVersion, sCurrent))
				continue;
		}
		else if (StrEqual(sType, "gamedata", false))
			FormatEx(sCheck, sizeof(sCheck), "%s.txt", sName);
		else if (StrEqual(sType, "translation", false))
			FormatEx(sCheck, sizeof(sCheck), "%s.txt", sName);

		RequestFile(sType, sCheck);
	}
}

void RequestFile(const char[] type, const char[] file)
{
	char sURL[256];

	if (StrEqual(type, "plugin", false))
		FormatEx(sURL, sizeof(sURL), "https://vertexheights.com/hub/sync/plugins/%s", file);
	else if (StrEqual(type, "gamedata", false))
		FormatEx(sURL, sizeof(sURL), "https://vertexheights.com/hub/sync/gamedata/%s", file);
	else if (StrEqual(type, "translation", false))
		FormatEx(sURL, sizeof(sURL), "https://vertexheights.com/hub/sync/translations/%s", file);

	System2HTTPRequest httpRequest = new System2HTTPRequest(HttpResponseCallback, sURL);
	httpRequest.SetProgressCallback(HttpProgressCallback);
	httpRequest.SetBasicAuthentication("sync", "XfuBq7I6fv");

	if (StrEqual(type, "plugin", false))
		httpRequest.SetOutputFile("addons/sourcemod/plugins/%s", file);
	else if (StrEqual(type, "gamedata", false))
		httpRequest.SetOutputFile("addons/sourcemod/gamedata/%s", file);
	else if (StrEqual(type, "translation", false))
		httpRequest.SetOutputFile("addons/sourcemod/translations/%s", file);

	httpRequest.GET();
}

public void HttpProgressCallback(System2HTTPRequest request, int dlTotal, int dlNow, int ulTotal, int ulNow)
{
	PrintToServer("Downloaded %d of %d bytes", dlNow, dlTotal);
}

public void HttpResponseCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
    if (success)
	{
        char sURL[128];
        response.GetLastURL(sURL, sizeof(sURL));
        PrintToServer("Request to %s finished with status code %d in %.2f seconds", sURL, response.StatusCode, response.TotalTime);
    }
	else
        PrintToServer("Error on request: %s", error);
}