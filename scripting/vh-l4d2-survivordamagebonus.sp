//Pragma
#pragma semicolon 1
//#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights][L4D2] :: Survivor Damage Bonus"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

//Sourcemod Includes
#include <sourcemod>
#include <sdkhooks>

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
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if (attacker > 0 && attacker <= MaxClients)
	{
		damage = damage *= 1.0 + 0.50;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "infected", false))
		CreateTimer(0.2, Timer_SetHealth, EntIndexToEntRef(entity));
}

public Action Timer_SetHealth(Handle timer, any data)
{
	int entity = EntRefToEntIndex(data);
	
	if (IsValidEntity(entity))
		SetEntProp(entity, Prop_Data, "m_iHealth", 25);
}