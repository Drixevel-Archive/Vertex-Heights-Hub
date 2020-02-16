/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Concepts"
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
bool g_HasDied[MAXPLAYERS + 1];
int g_GotAKill[MAXPLAYERS + 1] = {-1, ...};

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
	RegAdminCmd("sm_concept", Command_Concept, ADMFLAG_RESERVATION);
}

public Action Command_Concept(int client, int args)
{
	char sConcept[64];
	GetCmdArgString(sConcept, sizeof(sConcept));
	SpeakResponseConcept(client, sConcept);
	return Plugin_Handled;
}

public void TF2_OnPlayerSpawn(int client, int team, int class)
{
	if (g_HasDied[client])
	{
		g_HasDied[client] = false;

		if (GetRandomFloat(0.0, 100.0) <= 25.0)
			SpeakResponseConcept(client, GetRandomInt(0, 1) == 0 ? "TLK_PLAYER_JEERS" : "TLK_PLAYER_NEGATIVE");
	}
}

public void TF2_OnPlayerDeath(int client, int attacker, int assister, int inflictor, int damagebits, int stun_flags, int death_flags, int customkill)
{
	g_HasDied[client] = true;
	g_GotAKill[client] = -1;

	g_GotAKill[attacker] = GetTime() + 1;

	if (GetRandomFloat(0.0, 100.0) <= 25.0)
		SpeakResponseConcept(attacker, GetRandomInt(0, 1) == 0 ? "TLK_PLAYER_CHEERS" : "TLK_PLAYER_YES");
}

public void OnClientDisconnect_Post(int client)
{
	g_HasDied[client] = false;
	g_GotAKill[client] = -1;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(client) != GetClientTeam(i) || i == client)
			continue;
		
		if (GetEntitiesDistance(client, i) > 1000.0)
			continue;
		
		if (g_GotAKill[i] != -1 && g_GotAKill[i] > GetTime() && GetRandomFloat(0.0, 100.0) <= 5.0)
			SpeakResponseConcept(client, GetRandomInt(0, 1) == 0 ? "TLK_PLAYER_NICESHOT" : "TLK_PLAYER_GOODJOB");
	}
}