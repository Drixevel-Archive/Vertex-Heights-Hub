//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights][TF2] :: Pickup Glows"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

//Sourcemod Includes
#include <sourcemod>
#include <misc-sm>

public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "item_") == 0)
		SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
}

public void OnSpawnPost(int entity)
{
	if (!HasEntProp(entity, Prop_Data, "m_ModelName"))
		return;
	
	char sModel[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	
	if (strlen(sModel) == 0)
		return;
	
	float vecPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vecPos);
	
	float vecAng[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vecAng);
	
	int glow = CreateEntityByName("tf_taunt_prop");
	
	if (IsValidEntity(glow))
	{
		DispatchKeyValueVector(glow, "origin", vecPos);
		DispatchKeyValueVector(glow, "angles", vecAng);
		
		DispatchSpawn(glow);
		ActivateEntity(glow);
		
		SetParent(entity, glow);
		
		SetEntityModel(glow, sModel);
		SetEntityRenderMode(glow, RENDER_TRANSCOLOR);
		SetEntityRenderColor(glow, 0, 0, 0, 0);
		
		SetEntProp(glow, Prop_Send, "m_fEffects", EF_PARENT_ANIMATES|EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
		SetEntProp(glow, Prop_Send, "m_bGlowEnabled", 1);
	}
}