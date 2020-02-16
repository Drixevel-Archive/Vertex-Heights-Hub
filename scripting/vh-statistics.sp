/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Statistics"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-tf>
#include <misc-colors>

#include <vertexheights>
#include <vh-core>
#include <vh-permissions>
#include <vh-logs>

/*****************************/
//Globals
Database g_Database;

enum struct Statistics
{
	int Kills;
	int Deaths;
	int Assists;
	int Wins;
	int Losses;
	int Draws;
	float Damage;
	int Headshots;
	int Healing;
	int Backstabs;
	int Shots;
	int Hits;
	float Playtime;
	float Connecttime;
	int Taunts;
	
	void Reset()
	{
		this.Kills = 0;
		this.Deaths = 0;
		this.Assists = 0;
		this.Wins = 0;
		this.Losses = 0;
		this.Draws = 0;
		this.Damage = 0.0;
		this.Headshots = 0;
		this.Backstabs = 0;
		this.Healing = 0;
		this.Shots = 0;
		this.Hits = 0;
		this.Playtime = 0.0;
		this.Connecttime = 0.0;
		this.Taunts = 0;
	}
}

Statistics g_Statistics[MAXPLAYERS + 1];

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

	RegConsoleCmd("sm_stats", Command_Statistics);
	RegConsoleCmd("sm_statistics", Command_Statistics);

	CreateTimer(0.1, Timer_AddTime, _, TIMER_REPEAT);
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

public void VH_OnSynced(int client, int vid)
{
	g_Statistics[client].Reset();

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM `statistics` WHERE v_id = '%i' AND serverid = '%i';", vid, VH_GetServerID());
	g_Database.Query(onParseStatistics, sQuery, GetClientUserId(client), DBPrio_Low);
}

public void onParseStatistics(Database db, DBResultSet results, const char[] error, any data)
{
	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return;
	
	if (results == null)
		VH_ThrowSystemLog("Error while parsing statistics: %s", error);
	
	if (results.FetchRow())
	{
		g_Statistics[client].Kills = results.FetchInt(3);
		g_Statistics[client].Deaths = results.FetchInt(4);
		g_Statistics[client].Assists = results.FetchInt(5);
		g_Statistics[client].Wins = results.FetchInt(6);
		g_Statistics[client].Losses = results.FetchInt(7);
		g_Statistics[client].Draws = results.FetchInt(8);
		g_Statistics[client].Damage = results.FetchFloat(9);
		g_Statistics[client].Headshots = results.FetchInt(10);
		g_Statistics[client].Backstabs = results.FetchInt(11);
		g_Statistics[client].Healing = results.FetchInt(12);
		g_Statistics[client].Shots = results.FetchInt(13);
		g_Statistics[client].Hits = results.FetchInt(14);
		g_Statistics[client].Playtime = results.FetchFloat(15);
		g_Statistics[client].Connecttime = results.FetchFloat(16);
		g_Statistics[client].Taunts = results.FetchInt(17);
	}
}

public void OnClientDisconnect(int client)
{
	int vid = VH_GetVertexID(client);

	if (vid == VH_NULLID)
		return;
	
	int serverid = VH_GetServerID();

	int kills = g_Statistics[client].Kills;
	int deaths = g_Statistics[client].Deaths;
	int assists = g_Statistics[client].Assists;
	int wins = g_Statistics[client].Wins;
	int losses = g_Statistics[client].Losses;
	int draws = g_Statistics[client].Draws;
	float damage = g_Statistics[client].Damage;
	int headshots = g_Statistics[client].Headshots;
	int backstabs = g_Statistics[client].Backstabs;
	int healing = g_Statistics[client].Healing;
	int shots = g_Statistics[client].Shots;
	int hits = g_Statistics[client].Hits;
	float playtime = g_Statistics[client].Playtime;
	float connecttime = g_Statistics[client].Connecttime;
	int taunts = g_Statistics[client].Taunts;

	char sQuery[1024];
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `statistics` (v_id, serverid, kills, deaths, assists, wins, losses, draws, damage, headshots, backstabs, healing, shots, hits, playtime, connecttime, taunts) VALUES ('%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%.2f', '%i', '%i', '%i', '%i', '%i', '%.2f', '%.2f', '%i') ON DUPLICATE KEY UPDATE kills = '%i', deaths = '%i', assists = '%i', wins = '%i', losses = '%i', draws = '%i', damage = '%.2f', headshots = '%i', backstabs = '%i', healing = '%i', shots = '%i', hits = '%i', playtime = '%.2f', connecttime = '%.2f', taunts = '%i';", vid, serverid, kills, deaths, assists, wins, losses, draws, damage, headshots, backstabs, healing, shots, hits, playtime, connecttime, taunts, kills, deaths, assists, wins, losses, draws, damage, headshots, backstabs, healing, shots, hits, playtime, connecttime, taunts);
	g_Database.Query(onSaveStatistics, sQuery, _, DBPrio_Low);
}

public void onSaveStatistics(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while saving statistics: %s", error);
}

public void OnClientDisconnect_Post(int client)
{
	g_Statistics[client].Reset();
}

public Action Command_Statistics(int client, int args)
{
	OpenStatisticsMenu(client, client);
	return Plugin_Handled;
}

void OpenStatisticsMenu(int client, int target)
{
	Menu menu = new Menu(MenuHandler_Statistics);
	menu.SetTitle("Statistics for: %N", target);

	char sDisplay[64];
	
	FormatEx(sDisplay, sizeof(sDisplay), "Kill: %i", g_Statistics[target].Kills);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
	
	FormatEx(sDisplay, sizeof(sDisplay), "Deaths: %i", g_Statistics[target].Deaths);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
	
	FormatEx(sDisplay, sizeof(sDisplay), "Assists: %i", g_Statistics[target].Assists);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
	
	FormatEx(sDisplay, sizeof(sDisplay), "Wins: %i", g_Statistics[target].Wins);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
	
	FormatEx(sDisplay, sizeof(sDisplay), "Losses: %i", g_Statistics[target].Losses);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
	
	FormatEx(sDisplay, sizeof(sDisplay), "Draws: %i", g_Statistics[target].Draws);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
	
	FormatEx(sDisplay, sizeof(sDisplay), "Damage: %.2f", g_Statistics[target].Damage);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);

	FormatEx(sDisplay, sizeof(sDisplay), "Headshots: %i", g_Statistics[target].Headshots);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);

	FormatEx(sDisplay, sizeof(sDisplay), "Backstabs: %i", g_Statistics[target].Backstabs);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);

	FormatEx(sDisplay, sizeof(sDisplay), "Healing: %i", g_Statistics[target].Healing);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);

	FormatEx(sDisplay, sizeof(sDisplay), "Shots: %i", g_Statistics[target].Shots);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);

	FormatEx(sDisplay, sizeof(sDisplay), "Hits: %i", g_Statistics[target].Hits);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);

	FormatEx(sDisplay, sizeof(sDisplay), "Play time: %.2f", g_Statistics[target].Playtime);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);

	FormatEx(sDisplay, sizeof(sDisplay), "Connect time: %.2f", g_Statistics[target].Connecttime);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);

	FormatEx(sDisplay, sizeof(sDisplay), "Taunts: %i", g_Statistics[target].Taunts);
	menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Statistics(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
	}
}

//stats
public void TF2_OnPlayerDeath(int client, int attacker, int assister, int damagebits, int stun_flags, int death_flags, int customkill)
{
	g_Statistics[client].Deaths++;

	if (IsPlayerIndex(attacker))
	{
		g_Statistics[attacker].Kills++;
		
		switch (customkill)
		{
			case TF_CUSTOM_HEADSHOT:
				g_Statistics[attacker].Headshots++;
			case TF_CUSTOM_BACKSTAB:
				g_Statistics[attacker].Backstabs++;
		}
	}
	
	if (IsPlayerIndex(assister))
		g_Statistics[assister].Assists++;
}

public void TF2_OnRoundEnd(int team, int winreason, int flagcaplimit, bool full_round, float round_time, int losing_team_num_caps, bool was_sudden_death)
{
	int ourteam;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		ourteam = GetClientTeam(i);

		if (ourteam < 2)
			continue;
		
		if (team == 0)
			g_Statistics[i].Draws++;
		else if (ourteam == team)
			g_Statistics[i].Wins++;
		else
			g_Statistics[i].Losses++;
	}
}

public void TF2_OnPlayerDamagedPost(int victim, TFClassType victimclass, int attacker, TFClassType attackerclass, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if (IsPlayerIndex(attacker))
	{
		g_Statistics[attacker].Damage += damage;

		if (damagecustom != TF_CUSTOM_BURNING && damagecustom != TF_CUSTOM_BLEEDING)
			g_Statistics[attacker].Hits++;
	}
}

public void TF2_OnPlayerHealed(int patient, int healer, int amount)
{
	if (IsPlayerIndex(healer))
		g_Statistics[healer].Healing += amount;
}

public void TF2_OnWeaponFirePost(int client, int weapon)
{
	g_Statistics[client].Shots++;
}

public Action Timer_AddTime(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		if (GetClientTeam(i) > 1)
			g_Statistics[i].Playtime += 0.1;
		
		g_Statistics[i].Connecttime += 0.1;
	}
}

public void TF2_OnPlayerTaunting(int client, int index, int defindex)
{
	g_Statistics[client].Taunts++;
}