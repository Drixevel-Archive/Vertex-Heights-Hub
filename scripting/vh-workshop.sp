/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 131072

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Workshop"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.2"
#define PLUGIN_URL "https://vertexheights.com/"

#define NO_COLLECTION -1

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>
#include <system2>

#include <vertexheights>
#include <vh-core>
#include <vh-logs>

/*****************************/
//Globals
Database g_Database;
int g_Collection = NO_COLLECTION;

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

	ParseCollectionID(VH_GetServerID());
}

public void VH_OnParseServerData(int serverid, const char[] gamemode, const char[] region, const char[] hoster)
{
	ParseCollectionID(serverid);
}

void ParseCollectionID(int serverid)
{
	if (g_Database == null)
		return;
	
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT collection FROM `workshop` WHERE serverid = '%i';", serverid);
	g_Database.Query(onParseCollectionID, sQuery);
}

public void onParseCollectionID(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while parsing workshop collection ID: %s", error);
	
	if (results.FetchRow())
	{
		g_Collection = results.FetchInt(0);
		ParseMaps();
	}
}

public void OnMapStart()
{
	ParseMaps();
}

void ParseMaps()
{
	if (g_Collection == NO_COLLECTION)
	{
		FindConVar("mapcyclefile").SetString("mapcycle.txt");
		return;
	}

	System2HTTPRequest httpRequest = new System2HTTPRequest(HttpResponseCallback, "https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/?format=vdf");
	httpRequest.SetData("collectioncount=1&publishedfileids[0]=%i", g_Collection);
	httpRequest.POST();
}

public void HttpResponseCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if (!success)
		VH_ThrowSystemLog("Error on request: %s", error);

	char[] content = new char[response.ContentLength + 1];
	response.GetContent(content, response.ContentLength + 1);

	KeyValues vdf = new KeyValues("response");
	File mapcycle = OpenFile("cfg/mapcycle_workshop.txt", "w");
		
	if (vdf.ImportFromString(content, "response"))
	{
		vdf.JumpToKey("collectiondetails");
		vdf.JumpToKey("0");
		vdf.JumpToKey("children");

		if (vdf.GotoFirstSubKey())
		{
			char value[16];

			do
			{
				vdf.GetString("filetype", value, sizeof(value));
					
				if (StrEqual(value, "0"))
				{
					vdf.GetString("publishedfileid", value, sizeof(value));
					ServerCommand("tf_workshop_map_sync %s", value);
					mapcycle.WriteLine("workshop/%s", value);
				}
			}
			while(vdf.GotoNextKey());
		}
	}

	FindConVar("mapcyclefile").SetString("mapcycle_workshop.txt");

	mapcycle.Close();
	delete vdf;

	CreateTimer(2.0, Timer_ReloadMapPlugins);
}

public Action Timer_ReloadMapPlugins(Handle timer)
{
	ServerCommand("sm_rcon sm plugins reload basecommands");
	ServerCommand("sm_rcon sm plugins reload mapchooser");
	ServerCommand("sm_rcon sm plugins reload rockthevote");
	ServerCommand("sm_rcon sm plugins reload nominations");
}