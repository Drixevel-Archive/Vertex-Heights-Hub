/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Files"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

#define TYPE_PRECACHE 0
#define TYPE_DOWNLOAD 1

#define FILE_MATERIAL 0
#define FILE_MODEL 1
#define FILE_SOUND 2

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

	ParseFiles();
}

public void OnMapStart()
{
	ParseFiles();
}

void ParseFiles()
{
	if (g_Database == null)
		return;
	
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT type, file, path FROM `files` WHERE serverid = '%i' OR serverid = '-1';", VH_GetServerID());
	g_Database.Query(onParseFiles, sQuery);
}

public void onParseFiles(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while parsing files: %s", error);
	
	int type; int file; char sPath[PLATFORM_MAX_PATH];
	while (results.FetchRow())
	{
		type = results.FetchInt(0);
		file = results.FetchInt(1);
		results.FetchString(2, sPath, sizeof(sPath));

		if (strlen(sPath) == 0)
			continue;
		
		switch (type)
		{
			case TYPE_PRECACHE:
			{
				switch (file)
				{
					case FILE_MODEL:
						PrecacheModel(sPath);
					case FILE_SOUND:
					{
						if (StrContains(sPath, "sound/", false) == 0)
							ReplaceString(sPath, sizeof(sPath), "sound/", "");
						
						PrecacheSound(sPath);
					}
				}
			}
			case TYPE_DOWNLOAD:
				AddFileToDownloadsTable(sPath);
		}
	}
}