//Pragma
#pragma semicolon 1
//#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights][L4D2] :: Survivor Glows"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

//Sourcemod Includes
#include <sourcemod>
//#include <left4downtown>

enum L4D2GlowType
{
    L4D2Glow_None = 0,
    L4D2Glow_OnUse,
    L4D2Glow_OnLookAt,
    L4D2Glow_Constant
}

bool g_IsBoomed[MAXPLAYERS + 1];

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
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_first_spawn", Event_OnPlayerSpawn);
	HookEvent("player_hurt", Event_OnPlayerHurt);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("heal_success", Event_OnHealSuccess);
	
	HookEvent("tongue_grab", Event_OnTongueGrag);
	HookEvent("lunge_pounce", Event_OnTongueGrag);
	HookEvent("charger_carry_start", Event_OnTongueGrag);
	HookEvent("jockey_ride", Event_OnTongueGrag);
	HookEvent("player_now_it", Event_OnVomitStart);
	
	HookEvent("tongue_release", Event_OnTongueRelease);
	HookEvent("pounce_end", Event_OnTongueRelease);
	HookEvent("pounce_stopped", Event_OnTongueRelease);
	HookEvent("charger_pummel_end", Event_OnTongueRelease);
	HookEvent("jockey_ride_end", Event_OnTongueRelease);
	HookEvent("player_no_longer_it", Event_OnVomitEnd);
	
	for (int i = 1; i <= MaxClients; i++)
		SetGlowBasedOnHealth(i);
}

public void Event_OnTongueGrag(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	
	if (client > 0 && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		L4D2_SetEntGlow(client, L4D2Glow_Constant, 0, 0, {255, 0, 0}, true);
}

public void Event_OnVomitStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!event.GetBool("by_boomer"))
		return;
	
	if (client > 0 && IsPlayerAlive(client) && GetClientTeam(client) == 2)
	{
		g_IsBoomed[client] = true;
		L4D2_SetEntGlow(client, L4D2Glow_Constant, 0, 0, {110, 253, 37}, true);
	}
}

public void Event_OnTongueRelease(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	
	if (client > 0 && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		SetGlowBasedOnHealth(client);
}

public void Event_OnVomitEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (client > 0 && IsPlayerAlive(client) && GetClientTeam(client) == 2)
	{
		g_IsBoomed[client] = false;
		SetGlowBasedOnHealth(client);
	}
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (client > 0 && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		L4D2_SetEntGlow(client, L4D2Glow_Constant, 0, 0, {255, 72, 196}, false);
}

public void Event_OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	SetGlowBasedOnHealth(client);
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (client > 0 && !IsPlayerAlive(client) && GetClientTeam(client) == 2)
		L4D2_SetEntGlow(client, L4D2Glow_None, 0, 0, {255, 72, 196}, false);
}

public void Event_OnHealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	SetGlowBasedOnHealth(client);
}

void SetGlowBasedOnHealth(int client)
{
	if (!IsClientInGame(client) || g_IsBoomed[client])
		return;
	
	int color[3]; color = {255, 72, 196};
	int health = GetClientHealth(client);
	
	if (health <= 90)
	{
		color[1] -= 7;
		color[2] -= 17;
	}
	
	if (health <= 80)
	{
		color[1] -= 7;
		color[2] -= 17;
	}
	
	if (health <= 70)
	{
		color[1] -= 7;
		color[2] -= 17;
	}
	
	if (health <= 60)
	{
		color[1] -= 7;
		color[2] -= 17;
	}
	
	if (health <= 50)
	{
		color[1] -= 7;
		color[2] -= 15;
	}
	
	if (health <= 40)
	{
		color[1] -= 7;
		color[2] -= 17;
	}
	
	if (health <= 30)
	{
		color[1] -= 7;
		color[2] -= 17;
	}
	
	if (health <= 20)
	{
		color[1] -= 7;
		color[2] -= 17;
	}
	
	if (color[1] < 0)
		color[1] = 0;
	if (color[2] < 0)
		color[2] = 0;
	
	if (client > 0 && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		L4D2_SetEntGlow(client, L4D2Glow_Constant, 0, 0, color, false);
}

/**
 * Set entity glow. This is consider safer and more robust over setting each glow
 * property on their own because glow offset will be check first.
 *
 * @param entity        Entity index.
 * @parma type            Glow type.
 * @param range            Glow max range, 0 for unlimited.
 * @param minRange        Glow min range.
 * @param colorOverride Glow color, RGB.
 * @param flashing        Whether the glow will be flashing.
 * @return                True if glow was set, false if entity does not support
 *                        glow.
 */
stock bool:L4D2_SetEntGlow(entity, L4D2GlowType:type, range, minRange, colorOverride[3], bool:flashing)
{
    decl String:netclass[128];
    GetEntityNetClass(entity, netclass, 128);

    new offset = FindSendPropInfo(netclass, "m_iGlowType");
    if (offset < 1)
    {
        return false;    
    }

    L4D2_SetEntityGlow_Type(entity, type);
    L4D2_SetEntityGlow_Range(entity, range);
    L4D2_SetEntityGlow_MinRange(entity, minRange);
    L4D2_SetEntityGlow_ColorOverride(entity, colorOverride);
    L4D2_SetEntityGlow_Flashing(entity, flashing);
    return true;
}

/**
 * Set entity glow type.
 *
 * @param entity        Entity index.
 * @parma type            Glow type.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock L4D2_SetEntityGlow_Type(entity, L4D2GlowType:type)
{
    SetEntProp(entity, Prop_Send, "m_iGlowType", _:type);
}

/**
 * Set entity glow range.
 *
 * @param entity        Entity index.
 * @parma range            Glow range.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock L4D2_SetEntityGlow_Range(entity, range)
{
    SetEntProp(entity, Prop_Send, "m_nGlowRange", range);
}

/**
 * Set entity glow min range.
 *
 * @param entity        Entity index.
 * @parma minRange        Glow min range.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock L4D2_SetEntityGlow_MinRange(entity, minRange)
{
    SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", minRange);
}

/**
 * Set entity glow color.
 *
 * @param entity        Entity index.
 * @parma colorOverride    Glow color, RGB.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock L4D2_SetEntityGlow_ColorOverride(entity, colorOverride[3])
{
    SetEntProp(entity, Prop_Send, "m_glowColorOverride", colorOverride[0] + (colorOverride[1] * 256) + (colorOverride[2] * 65536));
}

/**
 * Set entity glow flashing state.
 *
 * @param entity        Entity index.
 * @parma flashing        Whether glow will be flashing.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock L4D2_SetEntityGlow_Flashing(entity, bool:flashing)
{
    SetEntProp(entity, Prop_Send, "m_bFlashing", _:flashing);
}  