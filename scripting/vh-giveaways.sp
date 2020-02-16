/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Giveaways"
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

/*****************************/
//Globals

enum struct Giveaways
{
	int index;
	bool running;
	int owner;
	int clients[MAXPLAYERS + 1];
	int count;
	int max;
	char prize[32];

	float endtime;
	Handle endtimer;
	bool forceend;

	void Initialize(int index, int client, char[] prize, int max, float timer)
	{
		this.index = index;
		this.running = true;
		this.owner = client;
		this.forceend = false;
		
		strcopy(this.prize, 32, prize);
		this.max = max;

		for (int i = 0; i < MAXPLAYERS + 1; i++)
			this.clients[i] = -1;
		
		this.count = 0;

		this.endtime = timer;
		this.endtimer = CreateTimer(1.0, Timer_Giveaway, this.index, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}

	void Join(int client)
	{
		this.clients[this.count++] = client;
	}

	bool IsEntered(int client)
	{
		for (int i = 0; i < this.count; i++)
		{
			if (this.clients[i] == client)
				return true;
		}

		return false;
	}

	bool IsFull()
	{
		if (this.max > 0 && this.count >= this.max)
			return true;
		
		return false;
	}

	int GetRandomWinner()
	{
		return (this.count == 0) ? -1 : this.clients[GetRandomInt(0, this.count - 1)];
	}

	void Destroy()
	{
		this.index = -1;
		this.running = false;
		this.owner = -1;
		this.forceend = false;

		for (int i = 0; i < MAXPLAYERS + 1; i++)
			this.clients[i] = -1;
		
		this.count = 0;
		this.endtime = 0.0;
		StopTimer(this.endtimer);
	}
}

Giveaways g_Giveaways[1024];
int g_Total;

bool g_IsHosting[MAXPLAYERS + 1];

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
	RegConsoleCmd("sm_giveaway", Command_Giveaway);
	RegConsoleCmd("sm_join", Command_Join);
	RegConsoleCmd("sm_end", Command_End);
}

public Action Command_Giveaway(int client, int args)
{
	if (args == 0)
	{
		Vertex_SendPrint(client, "Usage: sm_giveaway <prize> <max> <time>");
		return Plugin_Handled;
	}
	
	if (g_IsHosting[client])
	{
		Vertex_SendPrint(client, "You are already hosting a giveaway, please end your current giveaway.");
		return Plugin_Handled;
	}
	
	char prize[32];
	GetCmdArg(1, prize, sizeof(prize));
	
	int max = GetCmdArgInt(2);
	
	if (max < 1)
		max = 99999;
	
	float timer = GetCmdArgFloat(3);
	
	if (timer < 1.0)
		timer = 60.0;

	g_Giveaways[g_Total].Initialize(g_Total, client, prize, max, timer);
	
	if (strlen(prize) > 0)
		Vertex_SendPrintToAll("[H]%N [D]has started a giveaway for [H]%s[D]! Type [H]!join %i[D] in chat to enter this giveaway.", client, prize, g_Total);
	else
		Vertex_SendPrintToAll("[H]%N [D]has started a giveaway! Type [H]!join %i[D] in chat to enter this giveaway.", client, g_Total);
	
	g_Total++;
	g_IsHosting[client] = true;

	return Plugin_Handled;
}

public Action Command_Join(int client, int args)
{
	int id = GetCmdArgInt(1);

	if (!g_Giveaways[id].running)
	{
		Vertex_SendPrint(client, "This giveaway is not currently active.");
		return Plugin_Handled;
	}

	if (g_Giveaways[id].IsEntered(client))
	{
		Vertex_SendPrint(client, "You have already entered this giveaway.");
		return Plugin_Handled;
	}

	if (g_Giveaways[id].IsFull())
	{
		Vertex_SendPrint(client, "This giveaway is now full, you cannot enter.");
		return Plugin_Handled;
	}

	g_Giveaways[id].Join(client);
	if (strlen(g_Giveaways[id].prize) > 0)
		Vertex_SendPrintToAll("[H]%N [D]has joined [H]%N[D]'s giveaway for [H]%s[D]!", client, g_Giveaways[id].owner, g_Giveaways[id].prize);
	else
		Vertex_SendPrintToAll("[H]%N [D]has joined [H]%N[D]'s giveaway!", client, g_Giveaways[id].owner);

	return Plugin_Handled;
}

public Action Timer_Giveaway(Handle timer, any data)
{
	int index = data;

	if (g_Giveaways[index].endtime > 0.0 && !g_Giveaways[index].forceend)
	{
		g_Giveaways[index].endtime--;
		return Plugin_Continue;
	}

	int winner = g_Giveaways[index].GetRandomWinner();

	if (winner == -1)
	{
		Vertex_SendPrint(g_Giveaways[index].owner, "No players entered this giveaway, it's now closed.");
	}
	else
	{
		if (strlen(g_Giveaways[index].prize) > 0)
			Vertex_SendPrintToAll("[H]%N [D]has won the giveaway hosted by [H]%N[D] for [H]%s[D].", winner, g_Giveaways[index].owner, g_Giveaways[index].prize);
		else
			Vertex_SendPrintToAll("[H]%N [D]has won the giveaway hosted by [H]%N[D].", winner, g_Giveaways[index].owner);
	}
	
	g_IsHosting[g_Giveaways[index].owner] = false;

	g_Giveaways[index].Destroy();
	return Plugin_Stop;
}

public Action Command_End(int client, int args)
{
	if (!g_IsHosting[client])
	{
		Vertex_SendPrint(client, "You are currently not hosting a giveaway, start one to end one.");
		return Plugin_Handled;
	}
	
	int index = GetGiveaway(client);
	
	if (index == -1)
	{
		Vertex_SendPrint(client, "You are currently not hosting a giveaway, start one to end one.");
		return Plugin_Handled;
	}
	
	Vertex_SendPrintToAll("[H]%N [D]has manually ended the giveaway.", g_Giveaways[index].owner);
	
	g_Giveaways[index].forceend = true;
	TriggerTimer(g_Giveaways[index].endtimer);
	
	return Plugin_Handled;
}

int GetGiveaway(int client)
{
	for (int i = 0; i <= g_Total; i++)
		if (g_Giveaways[i].owner == client)
			return i;
	
	return -1;
}

public void OnClientDisconnect(int client)
{
	if (g_IsHosting[client])
	{
		int index = GetGiveaway(client);
		
		if (index == -1)
			return;
		
		Vertex_SendPrintToAll("[H]%N [D]has disconnected during the giveaway.", g_Giveaways[index].owner);
		g_Giveaways[index].Destroy();
	}
	
	for (int i = 0; i <= g_Total; i++)
		for (int x = 0; x < g_Giveaways[i].count; x++)
			if (g_Giveaways[i].clients[x] == client)
			{
				g_Giveaways[i].clients[x] = -1;
				g_Giveaways[i].count--;
			}
}

public void OnClientDisconnect_Post(int client)
{
	g_IsHosting[client] = false;
}