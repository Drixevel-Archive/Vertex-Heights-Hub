/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights][TF2] :: Wheatley"
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
#include <tf2-items>

/*****************************/
//Globals
int wearable;
Handle g_hSDKPickup;

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
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(262);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hSDKPickup = EndPrepSDKCall();

	int drix = GetDrixevel();
	TF2_RemoveAllWearables(drix);
	int entity = CreateEntityByName("item_teamflag");

	if (IsValidEntity(entity))
	{
		//SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", true);

		float vecOrigin[3];
		GetClientAbsOrigin(drix, vecOrigin);

		float vecAngles[3];
		GetClientAbsAngles(drix, vecAngles);

		DispatchKeyValueVector(entity, "origin", vecOrigin);
		DispatchKeyValue(entity, "flag_model", "models/weapons/c_models/c_p2rec/c_p2rec.mdl");
		DispatchSpawn(entity);

		if (g_hSDKPickup != null)
		{
			SDKCall(g_hSDKPickup, entity, drix, true);
			TeleportEntity(entity, NULL_VECTOR, view_as<float>({270.0, 90.0, 0.0}), NULL_VECTOR);
		}
		
		wearable = entity;
	}
}

public void OnMapStart()
{
	PrecacheModel("models/weapons/c_models/c_p2rec/c_p2rec.mdl");
}

public void OnPluginEnd()
{
	if (IsValidEntity(wearable))
		AcceptEntityInput(wearable, "Kill");
}