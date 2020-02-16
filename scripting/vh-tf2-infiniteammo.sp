/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights][TF2] :: Infinite Ammo"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>
#include <dhooks>

#include <vertexheights>

/*****************************/
//Globals
Handle g_hRemoveAmmo;

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
	Handle hConf = LoadGameConfigFile("vh.gamedata");
	
	int iOffset = GameConfGetOffset(hConf, "CTFPlayer::RemoveAmmo");
	if ((g_hRemoveAmmo = DHookCreate(iOffset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, CTFPlayer_RemoveAmmo)) == INVALID_HANDLE)
		SetFailState("Failed to create DHook for CTFPlayer::RemoveAmmo offset!"); 
	DHookAddParam(g_hRemoveAmmo, HookParamType_Int);
	DHookAddParam(g_hRemoveAmmo, HookParamType_Int);
	
	delete hConf;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnClientPutInServer(int client)
{
	DHookEntity(g_hRemoveAmmo, false, client);
}

public MRESReturn CTFPlayer_RemoveAmmo(int pThis, Handle hReturn, Handle hParams)
{
	DHookSetParam(hParams, 1, 0);
	DHookSetReturn(hReturn, DHookGetReturn(hReturn));
	
	return MRES_Supercede;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_ammo_pack", false))
		AcceptEntityInput(entity, "Kill");
}