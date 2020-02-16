/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Levels"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.1"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>

#include <misc-sm>
#include <misc-tf>
#include <misc-colors>

#include <vertexheights>
#include <vh-core>
#include <vh-logs>

/*****************************/
//Globals
Database g_Database;

enum struct PlayerData
{
	int level;
	int experience;
	bool loaded;
	bool updated;

	void Init()
	{
		this.level = 1;
		this.experience = 0;
		this.loaded = false;
		this.updated = false;
	}

	bool GiveXP(int value)
	{
		if (!this.loaded)
			return false;
		
		this.updated = true;
		this.experience += value;

		if (this.experience >= (this.level * 100))
		{
			this.experience -= (this.level * 100);
			this.level++;
			return true;
		}

		return false;
	}
}

PlayerData g_PlayerData[MAXPLAYERS + 1];

Handle g_Forward_OnLevelUp;
Handle g_Forward_OnExperienceGain;

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
	RegPluginLibrary("vh-levels");

	CreateNative("VH_GetLevel", Native_GetLevel);
	CreateNative("VH_GetExperience", Native_GetExperience);

	g_Forward_OnLevelUp = CreateGlobalForward("VH_OnLevelUp", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_Forward_OnExperienceGain = CreateGlobalForward("VH_OnExperienceGain", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	Database.Connect(onSQLConnect, "default");

	RegConsoleCmd("sm_level", Command_Level);

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i))
			OnClientConnected(i);
}

public void onSQLConnect(Database db, const char[] error, any data)
{
	if (db == null)
		VH_ThrowSystemLog("Error while connecting to database: %s", error);
	
	g_Database = db;
	g_Database.SetCharset("utf8");

	int vid;
	for (int i = 1; i <= MaxClients; i++)
		if ((vid = VH_GetVertexID(i)) != VH_NULLID)
			VH_OnSynced(i, vid);
}

public void OnClientConnected(int client)
{
	g_PlayerData[client].Init();
}

public void VH_OnSynced(int client, int vid)
{
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT level, experience FROM `player_levels` WHERE vid = '%i';", vid);
	g_Database.Query(onParseLevel, sQuery, GetClientUserId(client), DBPrio_Low);
}

public void onParseLevel(Database db, DBResultSet results, const char[] error, any data)
{
	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return;
	
	if (results == null)
		VH_ThrowSystemLog("Error while parsing player levels data: %s", error);
	
	if (results.FetchRow())
	{
		g_PlayerData[client].level = results.FetchInt(0);
		g_PlayerData[client].experience = results.FetchInt(1);
		g_PlayerData[client].loaded = true;
		return;
	}

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `player_levels` (vid, level, experience) VALUES ('%i', '1', '0');", VH_GetVertexID(client));
	g_Database.Query(onSyncLevel, sQuery, data, DBPrio_Low);
}

public void onSyncLevel(Database db, DBResultSet results, const char[] error, any data)
{
	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return;
	
	if (results == null)
		VH_ThrowSystemLog("Error while syncing player levels data: %s", error);
	
	g_PlayerData[client].level = 1;
	g_PlayerData[client].experience = 0;
	g_PlayerData[client].loaded = true;
}

public void OnClientDisconnect(int client)
{
	if (!g_PlayerData[client].loaded)
		return;
	
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `player_levels` SET level = '%i', experience = '%i' WHERE vid = '%i';", g_PlayerData[client].level, g_PlayerData[client].experience, VH_GetVertexID(client));
	g_Database.Query(onSaveLevel, sQuery, _, DBPrio_Low);
}

public void onSaveLevel(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while saving player levels data: %s", error);
}

public void TF2_OnFlagCapture(int team, int score)
{
	int value;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != team || !g_PlayerData[i].loaded)
			continue;
		
		value = GetRandomInt(48, 52);
		ExperienceGainNotification(i, value, "capturing a flag");

		if (g_PlayerData[i].GiveXP(value))
			LevelUpNotification(i);
	}
}

public void TF2_OnControlPointCaptured(int index, char[] name, int cappingteam, char[] cappers)
{
	int value;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != cappingteam || !g_PlayerData[i].loaded)
			continue;
		
		value = GetRandomInt(48, 52);
		ExperienceGainNotification(i, value, "capturing a control point");

		if (g_PlayerData[i].GiveXP(value))
			LevelUpNotification(i);
	}
}

public void TF2_OnRoundEnd(int team, int winreason, int flagcaplimit, bool full_round, float round_time, int losing_team_num_caps, bool was_sudden_death)
{
	int value;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != team || !g_PlayerData[i].loaded)
			continue;
		
		value = GetRandomInt(73, 77);
		ExperienceGainNotification(i, value, "winning the round");

		if (g_PlayerData[i].GiveXP(value))
			LevelUpNotification(i);
	}
}

public void TF2_OnPlayerDeath(int client, int attacker, int assister, int inflictor, int damagebits, int stun_flags, int death_flags, int customkill)
{
	if (client < 1 || client > MaxClients || client == attacker || TF2_IsMvM())
		return;
	
	if (attacker > 0 && attacker <= MaxClients && !IsFakeClient(attacker))
	{
		int value = GetRandomInt(3, 7);
		
		char sReason[128];
		FormatEx(sReason, sizeof(sReason), "killing %N", client);
		ExperienceGainNotification(attacker, value, sReason);

		if (g_PlayerData[attacker].GiveXP(value))
			LevelUpNotification(attacker);
	}

	if (assister > 0 && assister <= MaxClients && !IsFakeClient(assister))
	{
		int value = GetRandomInt(1, 5);
		
		char sReason[128];
		
		if (attacker > 0)
			FormatEx(sReason, sizeof(sReason), "assisting %N in killing %N", attacker, client);
		else
			FormatEx(sReason, sizeof(sReason), "assisting in killing %N", client);
		
		ExperienceGainNotification(assister, value, sReason);

		if (g_PlayerData[assister].GiveXP(value))
			LevelUpNotification(assister);
	}
}

void LevelUpNotification(int client)
{
	EmitSoundToAll("misc/achievement_earned.wav", client);
	Vertex_SendPrintToAll("%N has leveled up to level %i!", client, g_PlayerData[client].level);

	Call_StartForward(g_Forward_OnLevelUp);
	Call_PushCell(client);
	Call_PushCell(g_PlayerData[client].level);
	Call_PushCell(g_PlayerData[client].experience);
	Call_Finish();
}

void ExperienceGainNotification(int client, int amount, const char[] reason)
{
	Vertex_SendPrint(client, "%i experience gained for %s. (%i/%i to level %i)", amount, reason, g_PlayerData[client].experience, (g_PlayerData[client].level * 100), (g_PlayerData[client].level + 1));

	Call_StartForward(g_Forward_OnExperienceGain);
	Call_PushCell(client);
	Call_PushCell(amount);
	Call_PushString(reason);
	Call_PushCell(g_PlayerData[client].level);
	Call_PushCell(g_PlayerData[client].experience);
	Call_Finish();
}

public int Native_GetLevel(Handle plugin, int numParams)
{
	return g_PlayerData[GetNativeCell(1)].level;
}

public int Native_GetExperience(Handle plugin, int numParams)
{
	return g_PlayerData[GetNativeCell(1)].experience;
}

public Action Command_Level(int client, int args)
{
	int target = client;

	if (args > 0)
	{
		target = GetCmdArgTarget(client, 1);

		if (target == -1)
		{
			Vertex_SendPrint(client, "Couldn't find target to display levels data.");
			return Plugin_Handled;
		}
	}

	if (client == target)
		Vertex_SendPrint(client, "Your level is %i. [%i/%i to level %i]", g_PlayerData[target].level, g_PlayerData[target].experience, (g_PlayerData[target].level * 100), (g_PlayerData[target].level + 1));
	else
		Vertex_SendPrint(client, "%N's level is %i. [%i/%i to level %i]", target, g_PlayerData[target].level, g_PlayerData[target].experience, (g_PlayerData[target].level * 100), (g_PlayerData[target].level + 1));

	return Plugin_Handled;
}