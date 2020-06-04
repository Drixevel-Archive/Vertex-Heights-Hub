/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights][TF2] :: Bonk Machine"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.2"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>

#include <misc-sm>
#include <misc-tf>
#include <misc-colors>

#include <vertexheights>
#include <vh-store>

/*****************************/
//Globals
Database g_Database;
bool g_Late;
int g_VendingMachine;
Handle g_HumTimer;
Handle g_HudSync;

#define EFFECT_NONE 0
#define EFFECT_MINICRITS 1
#define EFFECT_UBER 2
#define EFFECT_SPEEDBOOST 3
#define EFFECT_CRITS 4
#define EFFECT_MEGAHEAL 5
#define EFFECT_BIGHEAD 6
#define EFFECT_MAX 7

int g_RandomEffect[MAX_ENTITY_LIMIT + 1];

enum struct Secondary
{
	char class[32];
	int index;
	int clip;
	int ammo;
}

Secondary g_Secondary[MAXPLAYERS + 1];

int g_BuyDelay[MAXPLAYERS + 1] = {-1, ...};

float g_Origin[3];
float g_Angles[3];

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
	g_Late = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	Database.Connect(OnSQLConnect, "default");
	g_HudSync = CreateHudSynchronizer();
	RegAdminCmd("sm_bonkmachine", Command_BonkMachine, ADMFLAG_ROOT, "Sets the coordinates to spawn a bonk machine on the current map.");
}

public void OnSQLConnect(Database db, const char[] error, any data)
{
	if (db == null)
		ThrowError("Error while connecting to database: %s", error);
	
	if (g_Database != null)
	{
		delete db;
		return;
	}

	g_Database = db;
	LogMessage("Connected to database successfully.");

	ParseSpawn();
}

void ParseSpawn()
{
	if (!IsValidEntity(0) || g_Database == null)
		return;
	
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	GetMapDisplayName(sMap, sMap, sizeof(sMap));

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT origin, angles FROM `bonkmachine_spawns` WHERE map = '%s';", sMap);
	g_Database.Query(OnParseSpawn, sQuery);
}

public void OnParseSpawn(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while parsing bonk machine spawnpoint: %s", error);
	
	if (results.FetchRow())
	{
		char sOrigin[64];
		results.FetchString(0, sOrigin, sizeof(sOrigin));

		char sPart[3][16];
		ExplodeString(sOrigin, " ", sPart, 3, 16);

		g_Origin[0] = StringToFloat(sPart[0]);
		g_Origin[1] = StringToFloat(sPart[1]);
		g_Origin[2] = StringToFloat(sPart[2]);

		char sAngles[64];
		results.FetchString(1, sAngles, sizeof(sAngles));

		char sPart2[3][16];
		ExplodeString(sAngles, " ", sPart2, 3, 16);

		g_Angles[0] = StringToFloat(sPart2[0]);
		g_Angles[1] = StringToFloat(sPart2[1]);
		g_Angles[2] = StringToFloat(sPart2[2]);

		if (g_Late)
		{
			g_Late = false;
			TF2_OnRoundStart(false);
		}
	}
}

public void OnPluginEnd()
{
	if (g_VendingMachine > MaxClients && IsValidEntity(g_VendingMachine))
		AcceptEntityInput(g_VendingMachine, "Kill");
}

public void OnMapStart()
{
	PrecacheModel("models/props/soda_machine.mdl");
	AddFileToDownloadsTable("models/props/soda_machine.dx80.vtx");
	AddFileToDownloadsTable("models/props/soda_machine.dx90.vtx");
	AddFileToDownloadsTable("models/props/soda_machine.mdl");
	AddFileToDownloadsTable("models/props/soda_machine.phy");
	AddFileToDownloadsTable("models/props/soda_machine.sw.vtx");
	AddFileToDownloadsTable("models/props/soda_machine.vvd");
	AddFileToDownloadsTable("materials/models/props/soda_machine.vmt");
	AddFileToDownloadsTable("materials/models/props/soda_machine.vtf");
	AddFileToDownloadsTable("materials/models/props/soda_machine_blue.vmt");
	AddFileToDownloadsTable("materials/models/props/soda_machine_blue.vtf");
	AddFileToDownloadsTable("materials/models/props/soda_machine_glass.vmt");
	AddFileToDownloadsTable("materials/models/props/soda_machine_glass.vtf");
	AddFileToDownloadsTable("materials/models/props/soda_machine_illum.vtf");

	PrecacheSound("ambient/machine_hum.wav");
	PrecacheSound("items/gift_pickup.wav");
	PrecacheSound("player/pl_scout_dodge_can_drink.wav");
	PrecacheSound("mvm/mvm_bought_upgrade.wav");
}

public void OnMapEnd()
{
	g_HumTimer = null;
}

public void TF2_OnRoundStart(bool full_reset)
{
	if (g_VendingMachine > 0 && IsValidEntity(g_VendingMachine))
		AcceptEntityInput(g_VendingMachine, "Kill");
	
	g_VendingMachine = CreateEntityByName("prop_dynamic");

	if (!IsValidEntity(g_VendingMachine))
		return;
	
	DispatchKeyValueVector(g_VendingMachine, "origin", g_Origin);
	DispatchKeyValueVector(g_VendingMachine, "angles", g_Angles);
	DispatchKeyValue(g_VendingMachine, "model", "models/props/soda_machine.mdl");
	DispatchKeyValue(g_VendingMachine, "solid", "6");
	DispatchKeyValue(g_VendingMachine, "modelscale", "1.3");

	DispatchSpawn(g_VendingMachine);
	TF2_CreateGlow("vending_machine_glow", g_VendingMachine, view_as<int>({255, 0, 255, 255}));

	EmitSoundToAllSafe("ambient/machine_hum.wav", g_VendingMachine, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEVOL, 0.5);
	StopTimer(g_HumTimer);
	g_HumTimer = CreateTimer(1.5, Timer_MachineHum, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_MachineHum(Handle timer)
{
	EmitSoundToAllSafe("ambient/machine_hum.wav", g_VendingMachine, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEVOL, 0.5);
}

public void OnGameFrame()
{
	if (!IsValidEntity(g_VendingMachine))
		return;
	
	SetHudTextParams(-1.0, 0.3, 0.5, 255, 255, 255, 255);
	
	int credits;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) < 2 || IsFakeClient(i))
			continue;
		
		if (GetEntitiesDistance(i, g_VendingMachine) < 100.0)
		{
			credits = VH_GetCredits(i);

			if (credits >= 25)
				ShowSyncHudText(i, g_HudSync, "Press 'MEDIC!' to purchase a Cola.");
			else
				ShowSyncHudText(i, g_HudSync, "Press 'MEDIC!' to purchase a Cola for 25 credits. (requires %i credits)", (25 - credits));
		}
		else
			ClearSyncHud(i, g_HudSync);
	}
}

public Action TF2_OnCallMedic(int client)
{
	if (!IsValidEntity(g_VendingMachine) || !IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) < 2 || IsFakeClient(client))
		return Plugin_Continue;
	
	if (GetEntitiesDistance(client, g_VendingMachine) < 100.0)
	{
		int time = GetTime();
		if (g_BuyDelay[client] != -1 && g_BuyDelay[client] > time)
			return Plugin_Handled;
		
		g_BuyDelay[client] = time + 8;
		int credits = VH_GetCredits(client);

		if (credits < 25)
		{
			Vertex_SendPrint(client, "You must gain %i more credits to purchase a Cola from this machine.", (25 - credits));
			EmitGameSoundToClient(client, "Player.UseDeny");
			SpeakResponseConcept(client, "TLK_PLAYER_NEGATIVE");
			return Plugin_Handled;
		}

		if (!VH_RemoveCredits(client, 25))
			return Plugin_Handled;
		
		Vertex_SendPrint(client, "You have purchased a Cola for 25 credits!");
		EmitGameSoundToClient(client, "Christmas.GiftPickup");
		EmitSoundToClientSafe(client, "mvm/mvm_bought_upgrade.wav");
		SpeakResponseConcept(client, "TLK_PLAYER_THANKS");

		TFClassType activeclass = TF2_GetPlayerClass(client);
		if (activeclass == TFClass_Pyro || activeclass == TFClass_Engineer || activeclass == TFClass_Medic || activeclass == TFClass_Sniper)
		{
			TF2_StunPlayer(client, 1.2, 0.0, TF_STUNFLAG_SLOWDOWN|TF_STUNFLAG_NOSOUNDOREFFECT|TF_STUNFLAG_THIRDPERSON, 0);
			EmitSoundToAll("player/pl_scout_dodge_can_drink.wav", client);
			CreateTimer(2.0, Timer_ApplyEffect, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			return Plugin_Handled;
		}

		int secondary = GetPlayerWeaponSlot(client, 1);

		if (IsValidEntity(secondary))
		{
			char class[32];
			GetEntityClassname(secondary, class, sizeof(class));
			strcopy(g_Secondary[client].class, 32, class);

			g_Secondary[client].index = GetWeaponIndex(secondary);
			g_Secondary[client].clip = GetClip(secondary);
			g_Secondary[client].ammo = GetAmmo(client, secondary);

			AcceptEntityInput(secondary, "Kill");
		}

		char class[32]; int index;
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Scout:
			{
				strcopy(class, sizeof(class), "tf_weapon_lunchbox_drink");
				index = 46;
			}
			case TFClass_Soldier: //Equips, can't left click.
			{
				strcopy(class, sizeof(class), "tf_weapon_lunchbox_drink");
				index = 46;
			}
			case TFClass_Pyro: //Doesn't equip, can't left click.
			{
				strcopy(class, sizeof(class), "tf_weapon_lunchbox_drink");
				index = 46;
			}
			case TFClass_DemoMan: //Equips, can't left click.
			{
				strcopy(class, sizeof(class), "tf_weapon_lunchbox_drink");
				index = 46;
			}
			case TFClass_Heavy: //Equips, can't left click.
			{
				strcopy(class, sizeof(class), "tf_weapon_lunchbox_drink");
				index = 46;
			}
			case TFClass_Engineer: //Doesn't equip, can't left click.
			{
				strcopy(class, sizeof(class), "tf_weapon_lunchbox_drink");
				index = 46;
			}
			case TFClass_Medic: //Doesn't equip, can't left click.
			{
				strcopy(class, sizeof(class), "tf_weapon_lunchbox_drink");
				index = 46;
			}
			case TFClass_Sniper: //Doesn't equip, can't left click.
			{
				strcopy(class, sizeof(class), "tf_weapon_lunchbox_drink");
				index = 46;
			}
			case TFClass_Spy: //Equips, can't left click.
			{
				strcopy(class, sizeof(class), "tf_weapon_lunchbox_drink");
				index = 46;
			}
		}
		
		int bonk = TF2_GiveItem(client, class, index);

		if (IsValidEntity(bonk))
		{
			g_RandomEffect[bonk] = GetRandomInt(1, EFFECT_MAX);
			EquipWeapon(client, bonk);
		}
		
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Timer_ApplyEffect(Handle timer, any data)
{
	int client;
	if ((client = GetClientOfUserId(data)) == 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Stop;
	
	switch (GetRandomInt(1, EFFECT_MAX))
	{
		case EFFECT_MINICRITS:
		{
			Vertex_SendPrint(client, "You have received: Mini Crits!");
			TF2_AddCondition(client, TFCond_CritCola, 20.0);
		}
		case EFFECT_UBER:
		{
			Vertex_SendPrint(client, "You have received: Uber!");
			CreateTimer(0.5, Frame_Uber, GetClientUserId(client));
		}
		case EFFECT_SPEEDBOOST:
		{
			Vertex_SendPrint(client, "You have received: Speed!");
			TF2_AddCondition(client, TFCond_SpeedBuffAlly, 20.0);
		}
		case EFFECT_CRITS:
		{
			Vertex_SendPrint(client, "You have received: Crits!");
			TF2_AddCondition(client, TFCond_Kritzkrieged, 20.0);
		}
		case EFFECT_MEGAHEAL:
		{
			Vertex_SendPrint(client, "You have received: Mega Heal!");
			TF2_AddCondition(client, TFCond_MegaHeal, 20.0);
		}
		case EFFECT_BIGHEAD:
		{
			Vertex_SendPrint(client, "You have received: Big Head!");
			TF2_AddCondition(client, TFCond_BalloonHead, 20.0);
		}
	}

	return Plugin_Stop;
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (TF2_GetPlayerClass(client) == TFClass_Scout && condition == TFCond_Bonked)
	{
		TF2_RemoveCondition(client, condition);

		int bonk = GetPlayerWeaponSlot(client, 1);

		if (IsValidEntity(bonk) && g_RandomEffect[bonk] != EFFECT_NONE)
		{
			switch (g_RandomEffect[bonk])
			{
				case EFFECT_MINICRITS:
				{
					Vertex_SendPrint(client, "You have received: Mini Crits!");
					TF2_AddCondition(client, TFCond_CritCola, 20.0);
				}
				case EFFECT_UBER:
				{
					Vertex_SendPrint(client, "You have received: Uber!");
					CreateTimer(0.5, Frame_Uber, GetClientUserId(client));
				}
				case EFFECT_SPEEDBOOST:
				{
					Vertex_SendPrint(client, "You have received: Speed!");
					TF2_AddCondition(client, TFCond_SpeedBuffAlly, 20.0);
				}
				case EFFECT_CRITS:
				{
					Vertex_SendPrint(client, "You have received: Crits!");
					TF2_AddCondition(client, TFCond_Kritzkrieged, 20.0);
				}
				case EFFECT_MEGAHEAL:
				{
					Vertex_SendPrint(client, "You have received: Mega Heal!");
					TF2_AddCondition(client, TFCond_MegaHeal, 20.0);
				}
				case EFFECT_BIGHEAD:
				{
					Vertex_SendPrint(client, "You have received: Big Head!");
					TF2_AddCondition(client, TFCond_BalloonHead, 20.0);
				}
			}

			g_RandomEffect[bonk] = EFFECT_NONE;

			CreateTimer(0.4, Timer_SetPrimary, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

			DataPack pack;
			CreateDataTimer(0.8, Timer_KillEntity, pack, TIMER_FLAG_NO_MAPCHANGE);
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(EntIndexToEntRef(bonk));
		}
	}
}

public Action Timer_SetPrimary(Handle timer, any data)
{
	int client;
	if ((client = GetClientOfUserId(data)) > 0 && IsClientInGame(client) && IsPlayerAlive(client))
		EquipWeaponSlot(client, 0);
}

public Action Timer_KillEntity(Handle timer, DataPack pack)
{
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	int bonk = EntRefToEntIndex(pack.ReadCell());

	delete pack;

	if (client == 0)
		return Plugin_Stop;

	if (IsValidEntity(bonk) && bonk > MaxClients)
		AcceptEntityInput(bonk, "Kill");
	
	int secondary = TF2_GiveItem(client, g_Secondary[client].class, g_Secondary[client].index);

	if (IsValidEntity(secondary))
		SetPlayerWeaponAmmo(client, secondary, g_Secondary[client].clip, g_Secondary[client].ammo);
	
	g_Secondary[client].class[0] = '\0';
	g_Secondary[client].index = 0;
	g_Secondary[client].clip = 0;
	g_Secondary[client].ammo = 0;

	return Plugin_Stop;
}

public Action Frame_Uber(Handle timer, any data)
{
	int client;
	if ((client = GetClientOfUserId(data)) > 0 && IsClientInGame(client) && IsPlayerAlive(client))
		TF2_AddCondition(client, TFCond_Ubercharged, 20.0);
}

public void OnClientDisconnect_Post(int client)
{
	g_BuyDelay[client] = -1;
}

public void TF2_OnButtonPressPost(int client, int button)
{
	TFClassType class = TF2_GetPlayerClass(client);

	if ((button & IN_ATTACK) == IN_ATTACK && (class == TFClass_Soldier || class == TFClass_DemoMan || class == TFClass_Heavy || class == TFClass_Spy))
	{
		int bonk = GetActiveWeapon(client);

		if (IsValidEntity(bonk) && g_RandomEffect[bonk] != EFFECT_NONE)
		{
			switch (g_RandomEffect[bonk])
			{
				case EFFECT_MINICRITS:
				{
					Vertex_SendPrint(client, "You have received: Mini Crits!");
					TF2_AddCondition(client, TFCond_CritCola, 20.0);
				}
				case EFFECT_UBER:
				{
					Vertex_SendPrint(client, "You have received: Uber!");
					CreateTimer(0.5, Frame_Uber, GetClientUserId(client));
				}
				case EFFECT_SPEEDBOOST:
				{
					Vertex_SendPrint(client, "You have received: Speed!");
					TF2_AddCondition(client, TFCond_SpeedBuffAlly, 20.0);
				}
				case EFFECT_CRITS:
				{
					Vertex_SendPrint(client, "You have received: Crits!");
					TF2_AddCondition(client, TFCond_Kritzkrieged, 20.0);
				}
				case EFFECT_MEGAHEAL:
				{
					Vertex_SendPrint(client, "You have received: Mega Heal!");
					TF2_AddCondition(client, TFCond_MegaHeal, 20.0);
				}
				case EFFECT_BIGHEAD:
				{
					Vertex_SendPrint(client, "You have received: Big Head!");
					TF2_AddCondition(client, TFCond_BalloonHead, 20.0);
				}
			}

			g_RandomEffect[bonk] = EFFECT_NONE;

			CreateTimer(0.4, Timer_SetPrimary, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

			DataPack pack;
			CreateDataTimer(0.8, Timer_KillEntity, pack, TIMER_FLAG_NO_MAPCHANGE);
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(EntIndexToEntRef(bonk));
		}
	}
}

public Action Command_BonkMachine(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	
	if (g_Database == null)
	{
		PrintToChat(client, "Database is not connect to set the bonk machine spawnpoint.");
		return Plugin_Handled;
	}

	GetClientAbsOrigin(client, g_Origin);
	GetClientAbsAngles(client, g_Angles);

	TF2_OnRoundStart(false);
	PrintToChat(client, "Bonk machine moved to your position.");

	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	GetMapDisplayName(sMap, sMap, sizeof(sMap));

	char sOrigin[64];
	FormatEx(sOrigin, sizeof(sOrigin), "%.2f %.2f %.2f", g_Origin[0], g_Origin[1], g_Origin[2]);
	
	char sAngles[64];
	FormatEx(sAngles, sizeof(sAngles), "%.2f %.2f %.2f", g_Angles[0], g_Angles[1], g_Angles[2]);

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `bonkmachine_spawns` (map, origin, angles) VALUES ('%s', '%s', '%s') ON DUPLICATE KEY UPDATE origin = '%s', angles = '%s';", sMap, sOrigin, sAngles, sOrigin, sAngles);
	g_Database.Query(OnSaveSpawn, sQuery);

	return Plugin_Handled;
}

public void OnSaveSpawn(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while saving bonk machine position: %s", error);
}