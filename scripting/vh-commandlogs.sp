/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Commandlogs"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <tf2_stocks>

#include <misc-sm>
#include <misc-colors>

#include <vertexheights>
#include <vh-core>
#include <vh-logs>

/*****************************/
//Globals
Database g_Database;

enum struct Commands
{
	int vid;
	int timestamp;
	char command[64];
	char arguments[255];
	int serverid;
	int team;
	int class;
	float playtime;
}

Commands g_Commands[2048];
int g_Total;

Handle g_LogsTimer;

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

	StopTimer(g_LogsTimer);
	g_LogsTimer = CreateTimer(120.0, Timer_Logs, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action OnClientCommand(int client, int args)
{
	char sCommand[64];
	GetCmdArg(0, sCommand, sizeof(sCommand));
	TrimString(sCommand);

	if (StrContains(sCommand, "sm_", false) != 0)
		return Plugin_Continue;
	
	int size = 2 * strlen(sCommand) + 1;
	char[] sCommand2 = new char[size];
	g_Database.Escape(sCommand, sCommand2, size);
		
	char sArguments[256];
	GetCmdArgString(sArguments, sizeof(sArguments));
	TrimString(sArguments);

	size = 2 * strlen(sArguments) + 1;
	char[] sArguments2 = new char[size];
	g_Database.Escape(sArguments, sArguments2, size);

	g_Commands[g_Total].vid = VH_GetVertexID(client);
	g_Commands[g_Total].timestamp = GetTime();
	strcopy(g_Commands[g_Total].command, 64, sCommand2);
	strcopy(g_Commands[g_Total].arguments, 255, sArguments2);
	g_Commands[g_Total].serverid = VH_GetServerID();
	g_Commands[g_Total].team = GetClientTeam(client);
	g_Commands[g_Total].class = view_as<int>(TF2_GetPlayerClass(client));
	g_Commands[g_Total].playtime = GetClientTime(client);

	g_Total++;

	return Plugin_Continue;
}

public Action Timer_Logs(Handle timer)
{
	if (g_Total < 1 || g_Database == null)
		return Plugin_Continue;
	
	Transaction trans = new Transaction();

	char sQuery[512];
	for (int i = 0; i < g_Total; i++)
	{
		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `commandlogs` (vid, timestamp, command, arguments, serverid, team, class, playtime) VALUES ('%i', '%i', '%s', '%s', '%i', '%i', '%i', '%.2f');", 
		g_Commands[i].vid,
		g_Commands[i].timestamp,
		g_Commands[i].command,
		g_Commands[i].arguments,
		g_Commands[i].serverid,
		g_Commands[i].team,
		g_Commands[i].class,
		g_Commands[i].playtime);
		trans.AddQuery(sQuery);
	}

	g_Total = 0;

	g_Database.Execute(trans, onSuccess, onFailure, _, DBPrio_Low);
	return Plugin_Continue;
}

public void onSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	
}

public void onFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Error while pushing command logs at query %i: %s", failIndex, error);
}