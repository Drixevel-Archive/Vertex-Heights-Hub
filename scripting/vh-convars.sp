/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: ConVars"
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

	LoadConVars();
}

public void OnConfigsExecuted()
{
	LoadConVars();
}

public void VH_OnParseServerData(int serverid, const char[] gamemode, const char[] region, const char[] hoster)
{
	if (g_Database == null)
		return;
	
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT type, convar, value FROM `convars` WHERE serverid = '%i' OR serverid = '-1';", serverid);
	g_Database.Query(onParseConVars, sQuery);
}

void LoadConVars()
{
	if (g_Database == null)
		return;
	
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT type, convar, value FROM `convars` WHERE serverid = '%i' OR serverid = '-1';", VH_GetServerID());
	g_Database.Query(onParseConVars, sQuery);
}

public void onParseConVars(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while parsing ConVars: %s", error);
	
	char sType[64]; char sConVar[256]; char sValue[256];
	while (results.FetchRow())
	{
		results.FetchString(0, sType, sizeof(sType));
		results.FetchString(1, sConVar, sizeof(sConVar));
		results.FetchString(2, sValue, sizeof(sValue));

		if (StrEqual(sType, "string", false))
			FindConVar(sConVar).SetString(sValue, true, false);
		else if (StrEqual(sType, "int", false))
			FindConVar(sConVar).IntValue = StringToInt(sValue);
		else if (StrEqual(sType, "bool", false))
			FindConVar(sConVar).BoolValue = StringToBool(sValue);
		else if (StrEqual(sType, "float", false))
			FindConVar(sConVar).FloatValue = StringToFloat(sValue);
	}
}