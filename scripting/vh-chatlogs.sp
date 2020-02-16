/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Chatlogs"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <tf2_stocks>

#include <misc-sm>

#include <vertexheights>
#include <vh-core>
#include <vh-logs>

/*****************************/
//Globals
Database g_Database;

enum struct Messages
{
	int vid;
	int timestamp;
	char command[64];
	char message[255];
	int serverid;
	int team;
	int class;
	float playtime;
}

Messages g_Messages[2048];
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

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (g_Database == null)
		return;
	
	char sMessage[255];
	strcopy(sMessage, sizeof(sMessage), sArgs);
	TrimString(sMessage);

	int size = 2 * strlen(sMessage) + 1;
	char[] sMessage2 = new char[size];
	g_Database.Escape(sMessage, sMessage2, size);

	g_Messages[g_Total].vid = VH_GetVertexID(client);
	g_Messages[g_Total].timestamp = GetTime();
	strcopy(g_Messages[g_Total].command, 64, command);
	strcopy(g_Messages[g_Total].message, 255, sMessage2);
	g_Messages[g_Total].serverid = VH_GetServerID();
	g_Messages[g_Total].team = GetClientTeam(client);
	g_Messages[g_Total].class = view_as<int>(TF2_GetPlayerClass(client));
	g_Messages[g_Total].playtime = GetClientTime(client);

	g_Total++;
}

public Action Timer_Logs(Handle timer)
{
	if (g_Total < 1 || g_Database == null)
		return Plugin_Continue;
	
	Transaction trans = new Transaction();

	char sQuery[512];
	for (int i = 0; i < g_Total; i++)
	{
		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `chatlogs` (vid, timestamp, command, message, serverid, team, class, playtime) VALUES ('%i', '%i', '%s', '%s', '%i', '%i', '%i', '%.2f');", 
		g_Messages[i].vid,
		g_Messages[i].timestamp,
		g_Messages[i].command,
		g_Messages[i].message,
		g_Messages[i].serverid,
		g_Messages[i].team,
		g_Messages[i].class,
		g_Messages[i].playtime);
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
	LogError("Error while pushing chat logs at query %i: %s", failIndex, error);
}