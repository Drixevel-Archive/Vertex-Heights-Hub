/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Core"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.6"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>

#include <misc-sm>
#include <misc-colors>
#include <misc-tf>

#include <steamworks>

#include <vertexheights>
#include <vh-core>
#include <vh-bans>
#include <vh-permissions>
#include <vh-logs>
#include <vh-levels>
#include <vh-store>

/*****************************/
//ConVars

/*****************************/
//Globals
Database g_Database;

int g_VertexID[MAXPLAYERS + 1] = {VH_NULLID, ...};
bool g_IsInGroup[MAXPLAYERS + 1];

enum struct Server
{
	int id;
	char secret_key[32];
	char gamemode[64];
	char region[64];
	char hoster[64];
}

Server g_Server;

Handle g_Forward_Hub;
Handle g_Forward_VIPPanel;
Handle g_Forward_OnSynced;
Handle g_Forward_OnParseServerData;

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
	RegPluginLibrary("vh-core");

	CreateNative("VH_GetVertexID", Native_GetPlayerID);
	CreateNative("VH_OpenVertexHub", Native_OpenVertexHub);
	CreateNative("VH_GetClientByVID", Native_GetClientByVID);
	CreateNative("VH_GetServerID", Native_GetServerID);
	CreateNative("VH_GetServerSecretKey", Native_GetServerSecretKey);
	CreateNative("VH_Resync", Native_Resync);
	CreateNative("VH_GetServerData", Native_GetServerData);
	CreateNative("VH_IsInSteamGroup", Native_IsInSteamgroup);

	g_Forward_Hub = CreateGlobalForward("VH_OnHubOpen", ET_Ignore, Param_Cell, Param_Cell);
	g_Forward_VIPPanel = CreateGlobalForward("VH_OnVIPFeatures", ET_Ignore, Param_Cell, Param_Cell);
	g_Forward_OnSynced = CreateGlobalForward("VH_OnSynced", ET_Ignore, Param_Cell, Param_Cell);
	g_Forward_OnParseServerData = CreateGlobalForward("VH_OnParseServerData", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String);

	return APLRes_Success;
}

public void OnPluginStart()
{
	Database.Connect(onSQLConnect, "default");

	RegConsoleCmd("sm_vertex", Command_Vertex, "Open the Vertex hub menu.");
	RegConsoleCmd("sm_vid", Command_VID, "Prints out your Vertex ID or another players Vertex ID.");
	RegConsoleCmd("sm_whois", Command_Whois, "Shows details pertaining to a specific player.");
	RegConsoleCmd("sm_connect", Command_Connect);
	RegConsoleCmd("sm_resync", Command_Resync);
	
	RegAdminCmd("sm_resyncall", Command_ResyncAll, ADMFLAG_ROOT, "Resync all players and their data.");

	//SteamWorks_SetGameDescription("Vertex Heights");
}

public Action Command_Connect(int client, int args)
{
	int ipaddr[4];
	if (SteamWorks_GetPublicIP(ipaddr))
	{
		char sPassword[64];
		if (CheckCommandAccess(client, "", ADMFLAG_GENERIC, true))
		{
			FindConVar("sv_password").GetString(sPassword, sizeof(sPassword));

			if (strlen(sPassword) > 0)
				Format(sPassword, sizeof(sPassword), "; password %s", sPassword);
		}
		
		Vertex_SendPrint(client, "Copy the line below:\nconnect %d.%d.%d.%d:%d%s", ipaddr[0], ipaddr[1], ipaddr[2], ipaddr[3], FindConVar("hostport").IntValue, sPassword);
	}
	else
		Vertex_SendPrint(client, "Error while parsing connect string.");

	return Plugin_Handled;
}

public Action Command_Vertex(int client, int args)
{
	OpenHubMenu(client);
	return Plugin_Handled;
}

public int Native_OpenVertexHub(Handle plugin, int numParams)
{
	OpenHubMenu(GetNativeCell(1));
}

void OpenHubMenu(int client)
{
	char sID[12];
	FormatEx(sID, sizeof(sID), g_VertexID[client] != VH_NULLID ? "%i" : "N/A", g_VertexID[client]);

	Menu menu = new Menu(MenuHandler_Hub);
	menu.SetTitle("::Vertex Heights :: Main Menu\n::Vertex ID: %s (level %i)\n \n", sID, VH_GetLevel(client));

	menu.AddItem("purchase", "Purchase VIP");
	menu.AddItem("features", "VIP Features");
	menu.AddItem("guidelines", "Community Guidelines");
	menu.AddItem("store", "Access the Store");
	
	if (g_Forward_Hub != null)
	{
		Call_StartForward(g_Forward_Hub);
		Call_PushCell(client);
		Call_PushCell(menu);
		Call_Finish();
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", "--Empty--", ITEMDRAW_DISABLED);

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Hub(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "purchase"))
				OpenPurchaseVIPPage(param1);
			else if (StrEqual(sInfo, "features"))
				OpenVIPFeaturesMenu(param1);
			else if (StrEqual(sInfo, "guidelines"))
				OpenGuidelinesPage(param1);
			else if (StrEqual(sInfo, "store"))
				//VH_OpenStoreMenu(param1);
				ClientCommand(param1, "sm_store");
			else if (StrEqual(sInfo, "bans"))
				//VH_OpenBansMenu(param1);
				ClientCommand(param1, "sm_bans");
			else if (StrEqual(sInfo, "permissions"))
				//VH_OpenPermissionsMenu(param1);
				ClientCommand(param1, "sm_permissions");
		}
		case MenuAction_End:
			delete menu;
	}
}

void OpenPurchaseVIPPage(int client)
{
	KeyValues kv = new KeyValues("data");
	kv.SetString("title", "Vertex Heights");
	kv.SetNum("type", MOTDPANEL_TYPE_URL);
	kv.SetString("msg", "https://vertexheights.com/forum/index.php?account/upgrades");
	kv.SetNum("customsvr", 1);
	ShowVGUIPanel(client, "info", kv, true);
	delete kv;

	OpenHubMenu(client);
}

void OpenGuidelinesPage(int client)
{
	KeyValues kv = new KeyValues("data");
	kv.SetString("title", "Vertex Heights");
	kv.SetNum("type", MOTDPANEL_TYPE_URL);
	kv.SetString("msg", "https://vertexheights.com/forum/index.php?threads/community-guidelines.1/");
	kv.SetNum("customsvr", 1);
	ShowVGUIPanel(client, "info", kv, true);
	delete kv;

	OpenHubMenu(client);
}

void OpenVIPFeaturesMenu(int client)
{
	Panel panel = new Panel();
	panel.SetTitle("Vertex Hub :: VIP Features");

	Call_StartForward(g_Forward_VIPPanel);
	Call_PushCell(client);
	Call_PushCell(panel);
	Call_Finish();

	panel.DrawItem("Back");

	panel.Send(client, MenuHandler_Void, MENU_TIME_FOREVER);
	delete panel;
}

public int MenuHandler_Void(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
			OpenHubMenu(param1);
	}
}

public void onSQLConnect(Database db, const char[] error, any data)
{
	if (db == null)
		VH_ThrowSystemLog("Error while connecting to database: %s", error);
	
	g_Database = db;
	g_Database.SetCharset("utf8");

	ParseServerID();
	Resync();
}

public void OnConfigsExecuted()
{
	ParseServerID();
}

void ParseServerID()
{
	if (g_Database == null)
		return;
	
	int ipaddr[4];
	SteamWorks_GetPublicIP(ipaddr);

	char sServerIP[64];
	FormatEx(sServerIP, sizeof(sServerIP), "%d.%d.%d.%d:%d", ipaddr[0], ipaddr[1], ipaddr[2], ipaddr[3], FindConVar("hostport").IntValue);

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT a.id, b.name, c.name, d.name FROM servers a INNER JOIN gamemodes b ON a.g_id = b.id INNER JOIN regions c ON a.r_id = c.id INNER JOIN hosters d ON a.h_id = d.id WHERE a.ip = '%s';", sServerIP);
	g_Database.Query(onParseServerID, sQuery, _, DBPrio_High);
}

public void onParseServerID(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while parsing Server ID: %s", error);

	if (results.FetchRow())
	{
		g_Server.id = results.FetchInt(0);
		results.FetchString(1, g_Server.gamemode, sizeof(g_Server.gamemode));
		results.FetchString(2, g_Server.region, sizeof(g_Server.region));
		results.FetchString(3, g_Server.hoster, sizeof(g_Server.hoster));

		Call_StartForward(g_Forward_OnParseServerData);
		Call_PushCell(g_Server.id);
		Call_PushString(g_Server.gamemode);
		Call_PushString(g_Server.region);
		Call_PushString(g_Server.hoster);
		Call_Finish();

		g_Server.id = results.FetchInt(0);
		results.FetchString(1, g_Server.gamemode, sizeof(g_Server.gamemode));
		results.FetchString(2, g_Server.region, sizeof(g_Server.region));
		results.FetchString(3, g_Server.hoster, sizeof(g_Server.hoster));

		return;
	}
	
	int ipaddr[4];
	SteamWorks_GetPublicIP(ipaddr);

	char sServerIP[64];
	FormatEx(sServerIP, sizeof(sServerIP), "%d.%d.%d.%d:%d", ipaddr[0], ipaddr[1], ipaddr[2], ipaddr[3], FindConVar("hostport").IntValue);

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `servers` (ip) VALUES ('%s');", sServerIP);
	g_Database.Query(onSetupServerID, sQuery, _, DBPrio_High);
}

public void onSetupServerID(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while setting up a Server ID: %s", error);
	
	g_Server.id = results.InsertId;
	Call_StartForward(g_Forward_OnParseServerData);
	Call_PushCell(g_Server.id);
	Call_PushString(g_Server.gamemode);
	Call_PushString(g_Server.region);
	Call_PushString(g_Server.hoster);
	Call_Finish();
}

public void VH_OnParseServerData(int serverid, const char[] gamemode, const char[] region, const char[] hoster)
{
	char mode[64];
	strcopy(mode, sizeof(mode), gamemode);

	if (strlen(mode) == 0)
		strcopy(mode, sizeof(mode), "Team Fortress 2");

	GetRandomString(g_Server.secret_key, sizeof(g_Server.secret_key), sizeof(g_Server.secret_key));

	char sQuery[1024];
	g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `servers` SET secret_key = '%s' WHERE id = '%i';", g_Server.secret_key, serverid);
	g_Database.Query(onUpdateSecretKey, sQuery);
}

public void onUpdateSecretKey(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while updating server secret key: %s", error);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (IsFakeClient(client) || g_Database == null)
		return;
	
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT id FROM `players` WHERE accountid = '%i';", GetSteamAccountID(client));
	g_Database.Query(onParseID, sQuery, GetClientUserId(client));
}

public void onParseID(Database db, DBResultSet results, const char[] error, any data)
{
	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return;
	
	if (results == null)
		VH_ThrowSystemLog("Error while retrieving ID: %s", error);
	
	if (results.FetchRow())
	{
		SyncForward(client, results.FetchInt(0));
		return;
	}

	RegisterPlayer(client);
}

void RegisterPlayer(int client)
{
	char sSteamID2[32];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamID2, sizeof(sSteamID2)))
		return;

	char sSteamID3[32];
	GetClientAuthId(client, AuthId_Steam3, sSteamID3, sizeof(sSteamID3));

	char sSteamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID64, sizeof(sSteamID64));
	
	char sQuery[512];
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `players` (accountid, steamid2, steamid3, steamid64) VALUES ('%i', '%s', '%s', '%s');", GetSteamAccountID(client), sSteamID2, sSteamID3, sSteamID64);
	g_Database.Query(onSyncID, sQuery, GetClientUserId(client));
}

public void onSyncID(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while syncing Vertex ID: %s" , error);
	
	int client;
	if ((client = GetClientOfUserId(data)) > 0)
		SyncForward(client, results.InsertId);
}

public void OnClientPostAdminCheck(int client)
{
	g_IsInGroup[client] = false;

	if (!SteamWorks_GetUserGroupStatus(client, 34551207))
		LogError("Error while pulling group information for: %N", client);
}

public void SteamWorks_OnClientGroupStatus(int authid, int groupid, bool isMember, bool isOfficer)
{
	int client = UserAuthGrab(authid);

	if (client > 0 && isMember)
		g_IsInGroup[client] = true;
}

int UserAuthGrab(int authid)
{
	char authchar[64];
	IntToString(authid, authchar, sizeof(authchar));

	char charauth[64];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !GetClientAuthId(i, AuthId_Steam3, charauth, sizeof(charauth)) || StrContains(charauth, authchar) == -1)
			continue;
		
		return i;
	}
	
	return 0;
}

public int Native_IsInSteamgroup(Handle plugin, int numParams)
{
	return g_IsInGroup[GetNativeCell(1)];
}

public void OnClientDisconnect_Post(int client)
{
	g_VertexID[client] = VH_NULLID;
}

public int Native_GetPlayerID(Handle plugin, int numParams)
{
	return g_VertexID[GetNativeCell(1)];
}

public Action Command_VID(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	
	int target = client;

	if (args > 0)
		target = GetCmdArgTargetEx(client, 1, true, false);
	
	if (target == -1)
	{
		Vertex_SendPrint(client, "Target not found, please try again.");
		return Plugin_Handled;
	}
	
	if (client == target)
	{
		if (g_VertexID[client] != VH_NULLID)
			Vertex_SendPrint(client, "[H]%i [D]is your Vertex ID, give it to another player if they need it.", g_VertexID[client]);
		else
			Vertex_SendPrint(client, "You currently do {red}NOT [D]have a valid Vertex ID, please reconnect.");
	}
	else
	{
		if (g_VertexID[target] != VH_NULLID)
			Vertex_SendPrint(client, "[H]%i [D]is their Vertex ID.", g_VertexID[target]);
		else
			Vertex_SendPrint(client, "They currently do {red}NOT [D]have a valid Vertex ID.");
	}
	
	return Plugin_Handled;
}

public int Native_GetClientByVID(Handle plugin, int numParams)
{
	int vid = GetNativeCell(1);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_VertexID[i] == vid)
			return i;
	}

	return -1;
}

public Action Command_Resync(int client, int args)
{
	int target = client;

	if (args > 0)
	{
		target = GetCmdArgTargetEx(client, 1, true, true);

		if (target == -1)
		{
			Vertex_SendPrint(client, "Couldn't find player to resync with the Vertex hub.");
			return Plugin_Handled;
		}
	}
	
	Resync(target);

	if (client == target)
		Vertex_SendPrint(client, "You have resynced yourself.");
	else
	{
		Vertex_SendPrint(client, "You have resynced %N with the Vertex hub.", target);
		Vertex_SendPrint(target, "You have been resynced by %N with the Vertex hub.", client);
	}

	return Plugin_Handled;
}

public Action Command_ResyncAll(int client, int args)
{
	Resync();
	Vertex_SendPrint(client, "You have resynced all players with Vertex servers.");
	return Plugin_Handled;
}

public int Native_Resync(Handle plugin, int numParams)
{
	Resync();
}

void Resync(int client = -1)
{
	if (g_Database == null)
		return;

	if (client > -1)
	{
		char sQuery[256];
		g_Database.Format(sQuery, sizeof(sQuery), "SELECT id FROM `players` WHERE accountid = '%i';", GetSteamAccountID(client));
		g_Database.Query(onParseID, sQuery, GetClientUserId(client));

		return;
	}

	Transaction trans = new Transaction();

	char sQuery[256];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientAuthorized(i))
			continue;
		
		g_Database.Format(sQuery, sizeof(sQuery), "SELECT id FROM `players` WHERE accountid = '%i';", GetSteamAccountID(i));
		trans.AddQuery(sQuery, GetClientUserId(i));
	}

	g_Database.Execute(trans, onResyncSuccess, onResyncFailure);
}

public void onResyncSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	int client;
	for (int i = 0; i < numQueries; i++)
	{
		if (results[i] == null || (client = GetClientOfUserId(queryData[i])) < 1)
			continue;

		if (results[i].FetchRow())
			SyncForward(client, results[i].FetchInt(0));
		else
			RegisterPlayer(client);
	}
}

public void onResyncFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	VH_ThrowSystemLog("Error while resyncing players at index %i: %s", failIndex, error);
}

void SyncForward(int client, int vid)
{
	g_VertexID[client] = vid;

	Call_StartForward(g_Forward_OnSynced);
	Call_PushCell(client);
	Call_PushCell(vid);
	Call_Finish();
}

public int Native_GetServerID(Handle plugin, int numParams)
{
	return g_Server.id;
}

public int Native_GetServerSecretKey(Handle plugin, int numParams)
{
	SetNativeString(1, g_Server.secret_key, GetNativeCell(2));
}

public Action Command_Whois(int client, int args)
{
	int target = client;

	if (args > 0)
		target = GetCmdArgTargetEx(client, 1, true, false);

	if (target != -1)
		OpenWhoisMenu(client, g_VertexID[target]);
	else
		OpenWhoisMenu(client, GetCmdArgInt(1), true);

	return Plugin_Handled;
}

void OpenWhoisMenu(int client, int vid, bool offline = false)
{
	if (offline)
	{
		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(client));
		pack.WriteCell(vid);

		char sQuery[256];
		g_Database.Format(sQuery, sizeof(sQuery), "SELECT accountid, steamid2, steamid3, steamid64 FROM `players` WHERE id = '%i';", vid);
		g_Database.Query(onParseWhois, sQuery, pack, DBPrio_Low);
	}
	else
	{
		int target = VH_GetClientByVID(vid);
		
		if (target == -1)
		{
			Vertex_SendPrint(client, "Vertex ID '%i' not found, please try again.", vid);
			return;
		}
		
		int accountid = GetSteamAccountID(target);

		char steamid2[64];
		GetClientAuthId(target, AuthId_Steam2, steamid2, sizeof(steamid2));

		char steamid3[64];
		GetClientAuthId(target, AuthId_Steam3, steamid3, sizeof(steamid3));

		char steamid64[64];
		GetClientAuthId(target, AuthId_SteamID64, steamid64, sizeof(steamid64));

		GenerateWhoisMenu(client, vid, accountid, steamid2, steamid2, steamid64);
	}
}

public void onParseWhois(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	int vid = pack.ReadCell();

	delete pack;

	if (results == null)
	{
		if (client > 0)
			Vertex_SendPrint(client, "Unknown error while opening whois information.");
		
		VH_ThrowSystemLog("Error while parsing whois data: %s", error);
	}

	if (client == 0)
		return;
	
	if (results.RowCount < 1)
	{
		Vertex_SendPrint(client, "Vertex ID '%i' not found, please try again.", vid);
		return;
	}

	int accountid; char steamid2[64]; char steamid3[64]; char steamid64[64];
	while (results.FetchRow())
	{
		accountid = results.FetchInt(0);
		results.FetchString(1, steamid2, sizeof(steamid2));
		results.FetchString(1, steamid3, sizeof(steamid3));
		results.FetchString(1, steamid64, sizeof(steamid64));
	}
	
	GenerateWhoisMenu(client, vid, accountid, steamid2, steamid3, steamid64);
}

void GenerateWhoisMenu(int client, int vid, int accountid, const char[] steamid2, const char[] steamid3, const char[] steamid64)
{
	Menu menu = new Menu(MenuHandler_Whois);
	menu.SetTitle("::Vertex Heights :: Whois\n::accountid: %i\n::steamid: %s\n::steamid3: %s\n::communityid: %s", accountid, steamid2, steamid3, steamid64);

	menu.AddItem("stats", "Show Statistics");
	menu.AddItem("items", "Show Items");
	menu.AddItem("loadouts", "Show Loadouts");

	int admgroup = VH_GetAdmGroup(client);

	if (IsDrixevel(client) || admgroup != VH_NULLADMGRP && admgroup < 4)
	{
		menu.AddItem("bans", "List Bans");
		menu.AddItem("chatlogs", "Show Chatlogs");
	}
	
	if (IsDrixevel(client) || admgroup != VH_NULLADMGRP && admgroup < 3)
		menu.AddItem("permissions", "List Permissions");
	
	PushMenuInt(menu, "vid", vid);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Whois(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			int vid = GetMenuInt(menu, "vid");

			if (StrEqual(sInfo, "stats"))
				DisplayStatisticsPanel(param1, vid);
			else if (StrEqual(sInfo, "items"))
				DisplayItemsPanel(param1, vid);
			else if (StrEqual(sInfo, "loadouts"))
				DisplayLoadoutsPanel(param1, vid);
			else if (StrEqual(sInfo, "bans"))
				DisplayBansPanel(param1, vid);
			else if (StrEqual(sInfo, "chatlogs"))
				DisplayChatlogs(param1, vid);
			else if (StrEqual(sInfo, "permissions"))
				DisplayPermissionsPanel(param1, vid);
		}
		case MenuAction_End:
			delete menu;
	}
}

void DisplayStatisticsPanel(int client, int vid)
{
	PrintToChat(client, "%i", vid);
}

void DisplayItemsPanel(int client, int vid)
{
	PrintToChat(client, "%i", vid);
}

void DisplayLoadoutsPanel(int client, int vid)
{
	PrintToChat(client, "%i", vid);
}

void DisplayBansPanel(int client, int vid)
{
	PrintToChat(client, "%i", vid);
}

void DisplayChatlogs(int client, int vid)
{
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT id, timestamp, command, message, serverid, team, class, playtime FROM `chatlogs` WHERE vid = '%i' LIMIT 50;", vid);
	g_Database.Query(onShowChatLogs, sQuery, GetClientUserId(client), DBPrio_Low);
}

public void onShowChatLogs(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);

	if (results == null)
	{
		if (client > 0)
			Vertex_SendPrint(client, "Unknown error while attempting to show chat logs.");
		
		VH_ThrowSystemLog("Error while parsing chat logs to show: %s", error);
	}

	PrintToConsole(client, "------------");
	while (results.FetchRow())
	{
		int id = results.FetchInt(0);
		int timestamp = results.FetchInt(1);

		char command[32];
		results.FetchString(2, command, sizeof(command));

		char message[255];
		results.FetchString(3, message, sizeof(message));

		int serverid = results.FetchInt(4);
		int team = results.FetchInt(5);
		int class = results.FetchInt(6);
		float playtime = results.FetchFloat(7);

		char sTime[64];
		FormatTime(sTime, sizeof(sTime), "%c", timestamp);

		char sTeam[32];
		GetTeamName(team, sTeam, sizeof(sTeam));

		char sClass[32];
		TF2_GetClassName(view_as<TFClassType>(class), sClass, sizeof(sClass));

		char sPlaytime[32];
		FormatSeconds(playtime, sPlaytime, sizeof(sPlaytime), "%H:%M:%S");

		PrintToConsole(client, "[%i|%s]%s| %s |Server:%i|Team:%s|Class:%s|Played:%s", id, sTime, command, message, serverid, sTeam, sClass, sPlaytime);
	}

	RequestFrame(Frame_Line, client);
}

public void Frame_Line(any data)
{
	PrintToConsole(data, "------------");
}

void DisplayPermissionsPanel(int client, int vid)
{
	PrintToChat(client, "%i", vid);
}

public void VH_OnSynced(int client, int vid)
{
	char sIP[64];
	GetClientIP(client, sIP, sizeof(sIP));

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	char sQuery[256];
	
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `ip_addresses` (vid, ip_address, connections) VALUES ('%i', '%s', '0') ON DUPLICATE KEY UPDATE connections = connections + 1;", vid, sIP);
	g_Database.Query(onSaveIP, sQuery, _, DBPrio_Low);
	
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT IGNORE INTO `player_names` (vid, name) VALUES ('%i', '%s');", vid, sName);
	g_Database.Query(onSaveName, sQuery, _, DBPrio_Low);
}

public void onSaveIP(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while saving IP: %s", error);
}

public void onSaveName(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while saving name: %s", error);
}

public int Native_GetServerData(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size); size++;

	char[] sKey = new char[size];
	GetNativeString(1, sKey, size);

	int other = GetNativeCell(3);

	if (StrEqual(sKey, "id", false))
		return g_Server.id;
	else if (StrEqual(sKey, "secret_key", false))
		return SetNativeString(2, g_Server.secret_key, other);
	else if (StrEqual(sKey, "gamemode", false))
		return SetNativeString(2, g_Server.gamemode, other);
	else if (StrEqual(sKey, "region", false))
		return SetNativeString(2, g_Server.region, other);
	else if (StrEqual(sKey, "hoster", false))
		return SetNativeString(2, g_Server.hoster, other);

	return -1;
}