/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Events"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.2"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>

#include <misc-sm>
#include <misc-colors>
#include <misc-tf>

#include <vertexheights>
#include <tf2-items>

#include <tf2_stocks>
#include <tf2items>

/*****************************/
//Globals

#define EVENT_NONE 0
#define EVENT_HALLOWEEN 1
#define EVENT_THANKSGIVING 2
#define EVENT_CHRISTMAS 3
#define EVENT_HAPPYNEWYEAR 4
#define EVENT_JULYFOURTH 5

int g_Event = EVENT_NONE;

#define SEASON_NONE 0
#define SEASON_SUMMER 1
#define SEASON_FALL 2
#define SEASON_WINTER 3
#define SEASON_SPRING 4

int g_Season = SEASON_NONE;

//Halloween
int g_iFog;
Handle g_WolfTimer;

//Pumpkins
#define SOUND_PUMPKIN_BOMB_FMT "vo/halloween_merasmus/hall2015_pumpbomb_%02d.mp3"
int g_pumpkinBombSounds[] = { 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 14, 15 };

#define SOUND_PUMPKIN_BOMB_EXPLODE_FMT "vo/halloween_merasmus/hall2015_pumpbombboom_%02d.mp3"
int g_pumpkinBombExplodeSounds[] = { 1, 2, 3, 4, 5, 6, 7 };

char g_HauntedPumpkinParticleNames[][] =
{
	"unusual_mystery_parent_green",
	"player_recent_teleport_red",
	"player_recent_teleport_blue"
};

//Christmas
ArrayList g_SnowParticles;

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
	RegAdminCmd("sm_setevent", Command_SetEvent, ADMFLAG_ROOT, "Sets the current event on the server until mapchange.");
	RegAdminCmd("sm_setseason", Command_SetSeason, ADMFLAG_ROOT, "Sets the current season on the server until mapchange.");
}

public void OnPluginEnd()
{
	if (g_SnowParticles != null && g_SnowParticles.Length > 0)
	{
		int entity;
		for (int i = 0; i < g_SnowParticles.Length; i++)
			if ((entity = EntRefToEntIndex(g_SnowParticles.Get(i))) > MaxClients)
				AcceptEntityInput(entity, "Kill");
	}
}

public Action Command_SetEvent(int client, int args)
{
	char sEvent[64];
	GetCmdArgString(sEvent, sizeof(sEvent));

	if (strlen(sEvent) == 0)
	{
		Vertex_SendPrint(client, "You must specify an event value.");
		return Plugin_Handled;
	}

	if (StrEqual(sEvent, "0") || StrEqual(sEvent, "None", false))
	{
		g_Event = EVENT_NONE;
		Vertex_SendPrintToAll("%N has disabled the current server event.", client);
		CacheFiles();
	}
	else if (StrEqual(sEvent, "1") || StrEqual(sEvent, "Halloween", false))
	{
		g_Event = EVENT_HALLOWEEN;
		Vertex_SendPrintToAll("%N has set the current server event to Halloween.", client);
		CacheFiles();
	}
	else if (StrEqual(sEvent, "2") || StrEqual(sEvent, "Thanksgiving", false))
	{
		g_Event = EVENT_THANKSGIVING;
		Vertex_SendPrintToAll("%N has set the current server event to Thanksgiving.", client);
		CacheFiles();
	}
	else if (StrEqual(sEvent, "3") || StrEqual(sEvent, "Christmas", false))
	{
		g_Event = EVENT_CHRISTMAS;
		Vertex_SendPrintToAll("%N has set the current server event to Christmas.", client);
		CacheFiles();
	}
	else if (StrEqual(sEvent, "4") || StrEqual(sEvent, "HappyNewYear", false))
	{
		g_Event = EVENT_HAPPYNEWYEAR;
		Vertex_SendPrintToAll("%N has set the current server event to Happy New Year.", client);
		CacheFiles();
	}
	else if (StrEqual(sEvent, "5") || StrEqual(sEvent, "JulyFourth", false))
	{
		g_Event = EVENT_JULYFOURTH;
		Vertex_SendPrintToAll("%N has set the current server event to Independence Day.", client);
		CacheFiles();
	}
	else
		Vertex_SendPrint(client, "The event you specified was not found.");

	return Plugin_Handled;
}

public Action Command_SetSeason(int client, int args)
{
	char sSeason[64];
	GetCmdArgString(sSeason, sizeof(sSeason));

	if (strlen(sSeason) == 0)
	{
		Vertex_SendPrint(client, "You must specify a seasonal value.");
		return Plugin_Handled;
	}

	if (StrEqual(sSeason, "0") || StrEqual(sSeason, "None", false))
	{
		g_Season = SEASON_NONE;
		Vertex_SendPrintToAll("%N has disabled the current server season.", client);
		CacheFiles();
	}
	else if (StrEqual(sSeason, "1") || StrEqual(sSeason, "Summer", false))
	{
		g_Season = SEASON_SUMMER;
		Vertex_SendPrintToAll("%N has set the current server season to Summer.", client);
		CacheFiles();
	}
	else if (StrEqual(sSeason, "2") || StrEqual(sSeason, "Fall", false))
	{
		g_Season = SEASON_FALL;
		Vertex_SendPrintToAll("%N has set the current server season to Fall.", client);
		CacheFiles();
	}
	else if (StrEqual(sSeason, "3") || StrEqual(sSeason, "Winter", false))
	{
		g_Season = SEASON_WINTER;
		Vertex_SendPrintToAll("%N has set the current server season to Winter.", client);
		CacheFiles();
	}
	else if (StrEqual(sSeason, "4") || StrEqual(sSeason, "Spring", false))
	{
		g_Season = SEASON_SPRING;
		Vertex_SendPrintToAll("%N has set the current server season to Spring.", client);
		CacheFiles();
	}
	else
		Vertex_SendPrint(client, "The season you specified was not found.");

	return Plugin_Handled;
}

public void OnMapStart()
{
	char sMonth[64];
	FormatTime(sMonth, sizeof(sMonth), "%B");

	char sDay[64];
	FormatTime(sDay, sizeof(sDay), "%d");
	int day = StringToInt(sDay);

	if (StrEqual(sMonth, "October", false) && day >= 24 && day <= 31)
		g_Event = EVENT_HALLOWEEN;
	else if (StrEqual(sMonth, "November", false) && day >= 21 && day <= 28)
		g_Event = EVENT_THANKSGIVING;
	else if (StrEqual(sMonth, "December", false) && day >= 18 && day <= 25)
		g_Event = EVENT_CHRISTMAS;
	else if (StrEqual(sMonth, "December", false) && day >= 28 && day <= 31)
		g_Event = EVENT_HAPPYNEWYEAR;
	else if (StrEqual(sMonth, "July", false) && day >= 2 && day <= 4)
		g_Event = EVENT_JULYFOURTH;
	
	if (StrEqual(sMonth, "June", false))
		g_Season = SEASON_SUMMER;
	else if (StrEqual(sMonth, "October", false))
		g_Season = SEASON_FALL;
	else if (StrEqual(sMonth, "December", false))
		g_Season = SEASON_WINTER;
	else if (StrEqual(sMonth, "March", false))
		g_Season = SEASON_SPRING;
	
	CacheFiles();
}

void CacheFiles()
{
	switch (g_Event)
	{
		case EVENT_HALLOWEEN:
		{
			PrecacheSound("misc/wolf_howl_01.wav");
			PrecacheSound("misc/wolf_howl_02.wav");
			PrecacheSound("misc/wolf_howl_03.wav");

			PrecacheModel("models/props_halloween/jackolantern_01.mdl");

			char gameSounds[PLATFORM_MAX_PATH];
			for (int i = 0; i < sizeof(g_pumpkinBombSounds); i++) {
				Format(gameSounds, sizeof(gameSounds), SOUND_PUMPKIN_BOMB_FMT, g_pumpkinBombSounds[i]);
				PrecacheSound(gameSounds);
			}
			for (int i = 0; i < sizeof(g_pumpkinBombExplodeSounds); i++) {
				Format(gameSounds, sizeof(gameSounds), SOUND_PUMPKIN_BOMB_EXPLODE_FMT, g_pumpkinBombExplodeSounds[i]);
				PrecacheSound(gameSounds);
			}
		}

		case EVENT_CHRISTMAS:
		{
			char gameSounds[PLATFORM_MAX_PATH];
			for (int i = 1; i <= 12; i++)
			{
				Format(gameSounds, sizeof(gameSounds), "ambient/halloween/windgust_%02d.wav", i);				
				PrecacheSound(gameSounds, true);
			}

			PrecacheSound("vertexheights/xmas.wav");
			AddFileToDownloadsTable("sound/vertexheights/xmas.wav");

			ApplySoundscape("stormfront.Underground", "stormfront.Outside");

			g_SnowParticles = new ArrayList();
			GenerateSnow();
		}
	}

	switch (g_Season)
	{
		case SEASON_SUMMER:
			AddFileToDownloadsTable("materials/correction/summer.raw");
		case SEASON_FALL:
			AddFileToDownloadsTable("materials/correction/autumn.raw");
		case SEASON_WINTER:
			AddFileToDownloadsTable("materials/correction/winter.raw");
	}
}

public void OnMapEnd()
{
	g_WolfTimer = null;
}

public void TF2_OnRoundStart(bool full_reset)
{
	switch (g_Event)
	{
		case EVENT_HALLOWEEN:
		{
			int fog_controller = FindEntityByClassname(-1, "env_fog_controller");
			
			if (fog_controller != -1)
				g_iFog = fog_controller;
			else
			{
				g_iFog = CreateEntityByName("env_fog_controller");
				DispatchSpawn(g_iFog);
			}
			
			DispatchKeyValue(g_iFog, "fogblend", "0");
			DispatchKeyValue(g_iFog, "fogcolor", "255 255 255");
			DispatchKeyValue(g_iFog, "fogcolor2", "255 255 255");
			DispatchKeyValueFloat(g_iFog, "fogstart", 250.0);
			DispatchKeyValueFloat(g_iFog, "fogend", 350.0);
			DispatchKeyValueFloat(g_iFog, "fogmaxdensity", 0.35);
			AcceptEntityInput(g_iFog, "TurnOn");

			StopTimer(g_WolfTimer);
			g_WolfTimer = CreateTimer(GetRandomFloat(120.0, 300.0), Timer_Wolf, _, TIMER_FLAG_NO_MAPCHANGE);

			//Spawn Pumpkins

			int pumpkin; float origin[3];
			for (int i = 0; i < 15; i++)
			{
				pumpkin = CreateEntityByName("tf_pumpkin_bomb");

				if (!IsValidEntity(pumpkin))
					continue;
				
				DispatchSpawn(pumpkin);

				GetRandomPostion(origin, 100.0, 500.0);
				GetGroundCoordinates(origin, origin);
				TeleportEntity(pumpkin, origin, NULL_VECTOR, NULL_VECTOR);
				SetEntProp(pumpkin, Prop_Data, "m_CollisionGroup", 17);

				if (GetRandomFloat(0.0, 100.0) <= 25.0)
					HauntPumpkin(pumpkin);
			}
		}

		case EVENT_CHRISTMAS:
		{
			EmitSoundToAll("vertexheights/xmas.wav");
			ApplySoundscape("stormfront.Underground", "stormfront.Outside");
			GenerateSnow();
		}
	}
	
	DataPack pack;
	switch (g_Season)
	{
		case SEASON_SUMMER:
		{
			CreateDataTimer(2.0, Timer_SetCorrection, pack, TIMER_FLAG_NO_MAPCHANGE);
			pack.WriteString("materials/correction/summer.raw");
		}
		case SEASON_FALL:
		{
			CreateDataTimer(2.0, Timer_SetCorrection, pack, TIMER_FLAG_NO_MAPCHANGE);
			pack.WriteString("materials/correction/autumn.raw");
		}
		case SEASON_WINTER:
		{
			CreateDataTimer(2.0, Timer_SetCorrection, pack, TIMER_FLAG_NO_MAPCHANGE);
			pack.WriteString("materials/correction/winter.raw");
		}
	}
}

public Action Timer_SetCorrection(Handle timer, DataPack pack)
{
	pack.Reset();

	char correction[128];
	pack.ReadString(correction, sizeof(correction));

	if (strlen(correction) > 0)
		SetCorrection(correction);
}

public Action Timer_Wolf(Handle timer, any data)
{
	char sSound[PLATFORM_MAX_PATH];
	FormatEx(sSound, sizeof(sSound), "misc/wolf_howl_0%i.wav", GetRandomInt(1, 3));
	EmitSoundToAll(sSound);
}

void GenerateSnow()
{
	if (g_SnowParticles == null)
		g_SnowParticles = new ArrayList();
	
	float origin[3];
	for (int i = 0; i < 100; i++)
	{
		GetRandomPostion(origin, 0.0, 1000.0);

		int entity = CreateEntityByName("info_particle_system");

		if (IsValidEntity(entity))
		{
			DispatchKeyValueVector(entity, "origin", origin);
			DispatchKeyValue(entity, "effect_name", "env_snow_stormfront_001");

			DispatchSpawn(entity);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "Start");

			g_SnowParticles.Push(EntIndexToEntRef(entity));
		}
	}
}

void SetCorrection(const char[] file)
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "color_correction")) != -1)
		AcceptEntityInput(entity, "Kill");
	
	int correction = CreateEntityByName("color_correction");
		
	if (IsValidEntity(correction))
	{
		DispatchKeyValue(correction, "maxweight", "1.0");
		DispatchKeyValue(correction, "maxfalloff", "-1");
		DispatchKeyValue(correction, "minfalloff", "0.0");
		DispatchKeyValue(correction, "filename", file);
		
		DispatchSpawn(correction);
		ActivateEntity(correction);
		AcceptEntityInput(correction, "Enable");
	}
}

TFTeam GetPumpkinTeam(int pumpkin)
{
	switch (GetEntProp(pumpkin, Prop_Data, "m_nSkin"))
	{
		case 1:
			return TFTeam_Red;
		case 2:
			return TFTeam_Blue;
	}

	return TFTeam_Unassigned;
}

void HauntPumpkin(int pumpkin)
{
	TFTeam pumpkinTeam = GetPumpkinTeam(pumpkin);
	
	int iParticleEffect = 0;
	switch (pumpkinTeam)
	{
		case TFTeam_Red:
			iParticleEffect = 1;
		case TFTeam_Blue:
			iParticleEffect = 2;
	}

	float particleOrigin[3];
	GetEntPropVector(pumpkin, Prop_Send, "m_vecOrigin", particleOrigin);

	if (pumpkinTeam == TFTeam_Unassigned)
		particleOrigin[2] += 12.0;
	
	int particle = CreateParticle(g_HauntedPumpkinParticleNames[iParticleEffect], particleOrigin);
	
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(pumpkin, "targetname", "haunted_pumpkin");
		DispatchKeyValue(particle, "targetname", "haunted_pumpkin_fx");
		
		SetVariantString("!activator");
		AcceptEntityInput(particle, "SetParent", pumpkin, particle, 0);
		
		SDKHook(pumpkin, SDKHook_OnTakeDamagePost, SDKHook_OnHauntedPumpkinDestroyed);
		PreparePumpkinTalkTimer(pumpkin);
		
		SetEntityModel(pumpkin, "models/props_halloween/jackolantern_01.mdl");
		
		float flModelScale = pumpkinTeam == TFTeam_Unassigned ? 0.55 : (0.9 * 0.55);
		SetEntPropFloat(pumpkin, Prop_Data, "m_flModelScale", flModelScale);
		
		AcceptEntityInput(pumpkin, "DisableShadow");
	}
}

public void SDKHook_OnHauntedPumpkinDestroyed(int pumpkin, int attacker, int inflictor, float damage, int damagetype)
{
	char sample[PLATFORM_MAX_PATH];
	GetGameSoundSample("sf15.Pumpkin.Bomb.Explode", sample, sizeof(sample));
	EmitSoundToAll(sample, pumpkin, _, SNDLEVEL_GUNFIRE);
	
	if (attacker && attacker <= MaxClients && IsClientInGame(attacker))
		EmitSoundToClient(attacker, sample);
}

void PreparePumpkinTalkTimer(int pumpkin)
{
	float delay = GetRandomFloat(3.0, 15.0);
	CreateTimer(delay, Timer_PumpkinTalk, EntIndexToEntRef(pumpkin), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_PumpkinTalk(Handle timer, int pumpkinref)
{
	int pumpkin = EntRefToEntIndex(pumpkinref);
	
	if (IsValidEntity(pumpkin))
	{
		char sample[PLATFORM_MAX_PATH];
		
		GetGameSoundSample("sf15.Pumpkin.Bomb", sample, sizeof(sample));
		EmitSoundToAll(sample, pumpkin, _, SNDLEVEL_GUNFIRE);
		
		PreparePumpkinTalkTimer(pumpkin);
	}

	return Plugin_Handled;
}

bool GetGameSoundSample(const char[] gameSound, char[] sample, int maxlength)
{
	int channel, soundLevel, pitch;
	float volume;
	return GetGameSoundParams(gameSound, channel, soundLevel, volume, pitch, sample, maxlength);
}


void ApplySoundscape(const char[] mapSoundscapeInside, const char[] mapSoundscapeOutside)
{
	int entity = -1;
	int proxy = -1;
	int scape = -1;

	float org[3];
	char target[32];
	
	while ((entity = FindEntityByClassname(entity, "env_soundscape_proxy")) != -1)
	{
        proxy = GetEntDataEnt2(entity, FindDataMapInfo(entity, "m_hProxySoundscape"));
        
        if (proxy != -1)
		{
            GetEntPropString(proxy, Prop_Data, "m_iName", target, sizeof(target));
            
            if ((StrContains(target, "inside", false) != -1) || (StrContains(target, "indoor", false) != -1) || (StrContains(target, "outside", false) != -1) || (StrContains(target, "outdoor", false) != -1))
			{
                scape = CreateEntityByName("env_soundscape");

                if (IsValidEntity(scape))
				{
                    GetEntPropVector(entity, Prop_Data, "m_vecOrigin", org);
                    TeleportEntity(scape, org, NULL_VECTOR, NULL_VECTOR);
                    
                    DispatchKeyValueFloat(scape, "radius", GetEntDataFloat(entity, FindDataMapInfo(entity, "m_flRadius")));
                    
                    if ((StrContains(target, "inside", false) != -1) || (StrContains(target, "indoor", false) != -1))
					{
                        DispatchKeyValue(scape, "soundscape", mapSoundscapeInside);
                        DispatchKeyValue(scape, "targetname", mapSoundscapeInside);
                    }
					else if ((StrContains(target, "outside", false) != -1) || (StrContains(target, "outdoor", false) != -1))
					{
                        DispatchKeyValue(scape, "soundscape", mapSoundscapeOutside);
                        DispatchKeyValue(scape, "targetname", mapSoundscapeOutside);
                    }
                    
                    DispatchSpawn(scape);
                }
            }
        }
        
        AcceptEntityInput(entity, "Kill");
    }
    
	while ((entity = FindEntityByClassname(entity, "env_soundscape")) != -1)
	{
        GetEntPropString(entity, Prop_Data, "m_iName", target, sizeof(target));
        
        if (!StrEqual(target, mapSoundscapeInside) && !StrEqual(target, mapSoundscapeOutside))
		{
            scape = CreateEntityByName("env_soundscape");
        
            if (IsValidEntity(scape))
			{
                GetEntPropVector(entity, Prop_Data, "m_vecOrigin", org);
                TeleportEntity(scape, org, NULL_VECTOR, NULL_VECTOR);
                
                DispatchKeyValueFloat(scape, "radius", GetEntDataFloat(entity, FindDataMapInfo(entity, "m_flRadius")));
                
                if ((StrContains(target, "inside", false) != -1) || (StrContains(target, "indoor", false) != -1))
				{
                    DispatchKeyValue(scape, "soundscape", mapSoundscapeInside);
                    DispatchKeyValue(scape, "targetname", mapSoundscapeInside);
                }
				else
				{
                    DispatchKeyValue(scape, "soundscape", mapSoundscapeOutside);
                    DispatchKeyValue(scape, "targetname", mapSoundscapeOutside);
                }
                
                DispatchSpawn(scape);
            }
        
            AcceptEntityInput(entity, "Kill");
        }
    }
}

public void TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int itemDefinitionIndex, int itemLevel, int itemQuality, int entityIndex)
{
	if (g_Event == EVENT_CHRISTMAS)
	{
		int festive = TF2_GetFestiveEquivalent(itemDefinitionIndex);

		if (festive != -1)
		{
			DataPack pack;
			CreateDataTimer(0.5, Timer_EquipWeapon, pack, TIMER_FLAG_NO_MAPCHANGE);
			pack.WriteCell(EntIndexToEntRef(entityIndex));
			pack.WriteCell(GetClientUserId(client));
			pack.WriteString(classname);
			pack.WriteCell(festive);
			pack.WriteCell(itemLevel);
			pack.WriteCell(itemQuality);
		}
	}
}

public Action Timer_EquipWeapon(Handle timer, DataPack pack)
{
	pack.Reset();

	int entityIndex = EntRefToEntIndex(pack.ReadCell());
	int client = GetClientOfUserId(pack.ReadCell());

	char classname[64];
	pack.ReadString(classname, sizeof(classname));

	int festive = pack.ReadCell();
	int itemLevel = pack.ReadCell();
	int itemQuality = pack.ReadCell();

	if (client ==  0 || !IsValidEntity(entityIndex) || TF2Items_IsCustom(entityIndex))
		return Plugin_Stop;
	
	if (StrContains(classname, "shotgun", false) != -1)
	{
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Soldier: strcopy(classname, sizeof(classname), "tf_weapon_shotgun_soldier");
			case TFClass_Pyro: strcopy(classname, sizeof(classname), "tf_weapon_shotgun_pyro");
			case TFClass_Heavy: strcopy(classname, sizeof(classname), "tf_weapon_shotgun_hwg");
			case TFClass_Engineer: strcopy(classname, sizeof(classname), "tf_weapon_shotgun_primary");
		}
	}

	int slot = GetWeaponSlot(client, entityIndex);
	
	if (StrEqual(classname, "tf_weapon_builder", false) && TF2_GetPlayerClass(client) == TFClass_Spy && slot == 1)
		return Plugin_Stop;

	TF2_RemoveWeaponSlot(client, GetWeaponSlot(client, entityIndex));

	Handle hWeapon = TF2Items_CreateItem(PRESERVE_ATTRIBUTES | FORCE_GENERATION);

	TF2Items_SetClassname(hWeapon, classname);
	TF2Items_SetItemIndex(hWeapon, festive);
	TF2Items_SetLevel(hWeapon, itemLevel);
	TF2Items_SetQuality(hWeapon, itemQuality);

	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	delete hWeapon;
    
	EquipPlayerWeapon(client, entity);

	return Plugin_Stop;
}