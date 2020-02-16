//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights][TF2] :: Resupply Glows"
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
	if (StrContains(classname, "prop_dynamic") != -1)
		SDKHook(entity, SDKHook_SpawnPost, OnDynamicSpawnPost);
}

public void OnDynamicSpawnPost(int entity)
{
	char sModel[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	
	if (StrContains(sModel, "resupply", false) != -1)
	{
		float vecPos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vecPos);
		
		float vecAng[3];
		GetEntPropVector(entity, Prop_Data, "m_angRotation", vecAng);
		
		int glow = CreateEntityByName("tf_taunt_prop");

		if (IsValidEntity(glow))
		{
			//DispatchKeyValue(glow, "model", sModel);
			DispatchKeyValueVector(glow, "origin", vecPos);
			DispatchKeyValueVector(glow, "angles", vecAng);
			
			/*
			int regenerator = -1;
			if ((regenerator = FindRegenerator(entity)) != -1)
				SetEntProp(glow, Prop_Send, "m_iTeamNum", GetEntProp(regenerator, Prop_Send, "m_iTeamNum"));*/
			
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
}

/*int FindRegenerator(int cabinet)
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "func_regenerate")) != -1)
	{
		if (GetEntPropEnt(entity, Prop_Data, "m_hAssociatedModel") == cabinet)
			return entity;
	}
	
	return -1;
}*/