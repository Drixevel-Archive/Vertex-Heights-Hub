/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights][TF2] :: Movement Unlocker"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

#define MAX_SPEED 10000.0

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>
#include <dhooks>

#include <vertexheights>

/*****************************/
//Globals
Handle g_hProcessMovement;

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
	Handle hConfig = LoadGameConfigFile("vh.gamedata");
	
	g_hProcessMovement = DHookCreateFromConf(hConfig, "CTFGameMovement::ProcessMovement");
	
	if (!DHookEnableDetour(g_hProcessMovement, false, CTFGameMovement_ProcessMovement))
		SetFailState("Failed to create \"CTFGameMovement::ProcessMovement\" detour");
	
	MemoryPatch("ProcessMovement", hConfig, {0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90}, 7);
		
	delete hConfig;
}

public void OnPluginEnd()
{
	DHookDisableDetour(g_hProcessMovement, false, CTFGameMovement_ProcessMovement);
}

public MRESReturn CTFGameMovement_ProcessMovement(Handle hParams)
{
	DHookSetParamObjectPtrVar(hParams, 2, 60, ObjectValueType_Float, MAX_SPEED);
	return MRES_ChangedHandled;
}

void MemoryPatch(const char[] patch, Handle &hConf, int[] PatchBytes, int iCount)
{
	Address iAddr = GameConfGetAddress(hConf, patch);
	
	if (iAddr == Address_Null)
		return;
	
	for (int i = 0; i < iCount; i++)
		StoreToAddress(iAddr + view_as<Address>(i), PatchBytes[i], NumberType_Int8);
}