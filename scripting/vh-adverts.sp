/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Adverts"
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
#include <vh-core>
#include <vh-logs>

/*****************************/
//Globals
Database g_Database;
ArrayList g_Adverts;
int g_LastAd;

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
	g_Adverts = new ArrayList(ByteCountToCells(255));

	RegAdminCmd("sm_reloadadverts", Command_ReloadAdverts, ADMFLAG_ROOT, "Reload advertisements.");
	RegAdminCmd("sm_printadverts", Command_PrintAdverts, ADMFLAG_ROOT, "Print advertisements.");

	Database.Connect(onSQLConnect, "default");
	CreateTimer(120.0, Timer_Advertisement, _, TIMER_REPEAT);
}

public void onSQLConnect(Database db, const char[] error, any data)
{
	if (db == null)
		VH_ThrowSystemLog("Error while connecting to database: test %s", error);
	
	if (g_Database != null)
	{
		delete db;
		return;
	}

	g_Database = db;
	LogMessage("Connected to database successfully.");

	ParseAds();
}

public Action Command_ReloadAdverts(int client, int args)
{
	ParseAds();
	Vertex_SendPrint(client, "Advertisements have been reloaded.");
	VH_SystemLog("%N has reloaded advertisements.", client);
	return Plugin_Handled;
}

void ParseAds()
{
	if (g_Database == null)
		return;
	
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT advert FROM `advertisements` WHERE serverid = '%i' OR serverid = '-1';", VH_GetServerID());
	g_Database.Query(onParseAds, sQuery, _, DBPrio_Low);
}

public void onParseAds(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while parsing advertisements: %s", error);
	
	g_Adverts.Clear();
	
	char sAdvertisement[255];
	while (results.FetchRow())
	{
		results.FetchString(0, sAdvertisement, sizeof(sAdvertisement));
		g_Adverts.PushString(sAdvertisement);
	}
}

public Action Timer_Advertisement(Handle timer)
{
	int size = g_Adverts.Length;

	if (size == 0)
		return Plugin_Continue;
	
	char sAdvertisement[255];
	g_Adverts.GetString(g_LastAd, sAdvertisement, sizeof(sAdvertisement));

	int id = VH_GetServerData("id"); char sID[16];
	IntToString(id, sID, sizeof(sID));
	ReplaceString(sAdvertisement, sizeof(sAdvertisement), "{SERVERID}", sID);

	char sGamemode[64];
	VH_GetServerData("gamemode", sGamemode, sizeof(sGamemode));
	ReplaceString(sAdvertisement, sizeof(sAdvertisement), "{GAMEMODE}", sGamemode);

	char sRegion[64];
	VH_GetServerData("region", sRegion, sizeof(sRegion));
	ReplaceString(sAdvertisement, sizeof(sAdvertisement), "{REGION}", sRegion);

	char sHoster[64];
	VH_GetServerData("hoster", sHoster, sizeof(sHoster));
	ReplaceString(sAdvertisement, sizeof(sAdvertisement), "{HOSTER}", sHoster);
	
	Vertex_SendPrintToAll(sAdvertisement);
	EmitSoundToAll(GetRandomFloat(0.00, 100.0) > 50.0 ? "ui/trade_up_envelope_slide_in.wav" : "ui/trade_up_envelope_slide_out.wav");
	g_LastAd++;

	if (g_LastAd > size - 1)
		g_LastAd = 0;
	
	return Plugin_Continue;
}

public void OnMapStart()
{
	PrecacheSound("ui/trade_up_envelope_slide_in.wav");
	PrecacheSound("ui/trade_up_envelope_slide_out.wav");
}

public Action Command_PrintAdverts(int client, int args)
{
	for (int i = 0; i < g_Adverts.Length; i++)
	{
		char sAdvertisement[255];
		g_Adverts.GetString(i, sAdvertisement, sizeof(sAdvertisement));

		int id = VH_GetServerData("id"); char sID[16];
		IntToString(id, sID, sizeof(sID));
		ReplaceString(sAdvertisement, sizeof(sAdvertisement), "{SERVERID}", sID);

		char sGamemode[64];
		VH_GetServerData("gamemode", sGamemode, sizeof(sGamemode));
		ReplaceString(sAdvertisement, sizeof(sAdvertisement), "{GAMEMODE}", sGamemode);

		char sRegion[64];
		VH_GetServerData("region", sRegion, sizeof(sRegion));
		ReplaceString(sAdvertisement, sizeof(sAdvertisement), "{REGION}", sRegion);

		char sHoster[64];
		VH_GetServerData("hoster", sHoster, sizeof(sHoster));
		ReplaceString(sAdvertisement, sizeof(sAdvertisement), "{HOSTER}", sHoster);

		Vertex_SendPrint(client, sAdvertisement);
	}

	return Plugin_Handled;
}