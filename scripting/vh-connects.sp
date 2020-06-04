/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Connects"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.4"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>
#include <geoip>

#include <vertexheights>
#include <vh-logs>
//#include <vh-store>

/*****************************/
//Globals
int g_MessageDelay[MAXPLAYERS + 1];
StringMap g_ConnectionSpam;
char g_ConnectMethod[MAXPLAYERS + 1][64];
StringMap g_FavoriteConnects;

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
	HookEventEx("player_connect", Event_SupressBroadcast, EventHookMode_Pre);
	HookEventEx("player_connect_client", Event_SupressBroadcast, EventHookMode_Pre);
	HookEventEx("player_activate", Event_SupressBroadcast, EventHookMode_Pre);
	HookEventEx("player_team", Event_SupressBroadcast, EventHookMode_Pre);	
	HookEventEx("player_disconnect", Event_SupressBroadcast, EventHookMode_Pre);
	HookEventEx("server_cvar", Event_SupressBroadcast, EventHookMode_Pre);
	HookEventEx("player_spawn", Event_OnPlayerSpawn);

	HookUserMessage(GetUserMessageId("VoiceSubtitle"), UserMsg_VoiceSubtitle, true);
	HookUserMessage(GetUserMessageId("TextMsg"), UserMsg_TextMsg, true);

	AddCommandListener(onJoinTeam, "jointeam");

	g_ConnectionSpam = new StringMap();
	g_FavoriteConnects = new StringMap();

	CreateTimer(300.0, Timer_ResetConnects, _, TIMER_REPEAT);
}

public Action Event_SupressBroadcast(Event event, const char[] name, bool dontBroadcast)
{
	dontBroadcast = true;
	event.BroadcastDisabled = true;
	return Plugin_Continue;
}

public Action Timer_ResetConnects(Handle timer)
{
	g_ConnectionSpam.Clear();
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	if (IsFakeClient(client))
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));

		if (StrContains(sName, "TFBot", false) == -1)
			Vertex_SendPrintToAll("[H]%N [D]has been created.", client);
		
		return true;
	}
	
	char sIP[32];
	GetClientIP(client, sIP, sizeof(sIP));

	int count;
	g_ConnectionSpam.GetValue(sIP, count);

	count++;
	g_ConnectionSpam.SetValue(sIP, count);

	if (StrEqual(sIP, "162.199.228.82", false) || count <= 4)
	{
		Vertex_SendPrintToAll("[H]%N [D]is connecting to the server...", client);
		VH_SystemLog("%N has connected to the server.", client);
		return true;
	}
	
	strcopy(rejectmsg, maxlen, "Please wait a bit to connect again.");
	return false;
}

public void OnMapEnd()
{
	g_ConnectionSpam.Clear();
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;
	
	char sIP[64];
	GetClientIP(client, sIP, sizeof(sIP));

	char sCountry[64];
	GeoipCountry(sIP, sCountry, sizeof(sCountry));

	if(!GetClientInfo(client, "cl_connectmethod", g_ConnectMethod[client], sizeof(g_ConnectMethod[])))
		strcopy(g_ConnectMethod[client], sizeof(g_ConnectMethod[]), "Unknown");
	
	char sConnect[32] = "Normal";
	if (StrEqual(g_ConnectMethod[client], "serverbrowser_favorites"))
		strcopy(sConnect, sizeof(sConnect), "Favorites");
	
	Vertex_SendPrintToAll("[H]%N [D]has connected successfully from [H]%s[D] via: [H]%s.", client, sCountry, sConnect);
}

public void OnClientDisconnect(int client)
{
	Vertex_SendPrintToAll("[H]%N [D]has disconnected from the server.", client);
	VH_SystemLog("%N has disconnected from the server.", client);
}

public Action UserMsg_VoiceSubtitle(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	return Plugin_Handled;
}

public Action UserMsg_TextMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	char message[32];
	msg.ReadByte();
	msg.ReadString(message, sizeof(message));

	if (StrContains(message, "connected", false) != -1 || strcmp(message, "#game_respawn_as") == 0 || strcmp(message, "#game_spawn_as") == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action onJoinTeam(int client, const char[] command, int argc)
{
	int time = GetTime();

	if (g_MessageDelay[client] != -1 && g_MessageDelay[client] > time)
		return Plugin_Continue;
	
	g_MessageDelay[client] = time + 5;

	char sTeam[32];
	GetCmdArgString(sTeam, sizeof(sTeam));
	sTeam[0] = CharToUpper(sTeam[0]);

	char sColor[32];
	if (StrEqual(sTeam, "auto", false))
		strcopy(sColor, sizeof(sColor), "{darkorange}");
	else if (StrEqual(sTeam, "spectate", false))
		strcopy(sColor, sizeof(sColor), "{silver}");
	else if (StrEqual(sTeam, "red", false))
		strcopy(sColor, sizeof(sColor), "{red}");
	else if (StrEqual(sTeam, "blue", false))
		strcopy(sColor, sizeof(sColor), "{blue}");
	else
		return Plugin_Continue;

	if (strlen(sColor) > 0)
		Vertex_SendPrintToAll("[H]%N [D]has joined team: %s%s", client, sColor, sTeam);
	
	return Plugin_Continue;
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client == 0)
		return;
	
	if (StrEqual(g_ConnectMethod[client], "serverbrowser_favorites"))
	{
		char sIP[32];
		GetClientIP(client, sIP, sizeof(sIP));

		int status;
		g_FavoriteConnects.GetValue(sIP, status);

		if (status > 0)
			return;
		
		g_FavoriteConnects.SetValue(sIP, 1);

		//VH_AddCredits(client, 10);
		//Vertex_SendPrint(client, "You have gained [H]%i [D]credits for connecting via favorites!", 10);
	}
}