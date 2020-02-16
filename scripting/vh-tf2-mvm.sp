/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights][TF2] :: MVM"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

#define CASH_SOUND "ui/credits_updated.wav"

#define CASH_SMALL "models/items/currencypack_small.mdl"
#define CASH_MEDIUM "models/items/currencypack_medium.mdl"
#define CASH_LARGE "models/items/currencypack_large.mdl"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-tf>
#include <misc-colors>

#include <vertexheights>

/*****************************/
//Globals

ConVar cvarCount;
ConVar sv_visiblemaxplayers;

int iCash[2048];
float g_Blocked[MAXPLAYERS + 1] = {-1.0, ...};
int g_StartingCash[MAXPLAYERS + 1];

ConVar g_hAdTimer;
ConVar g_hDropAmount;

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
	//RegPluginLibrary("vh-tf2-mvm");

	return APLRes_Success;
}

public void OnPluginStart()
{
	cvarCount = CreateConVar("mvm_visiblemaxplayers", "10", "Set above 0 to set sv_visiblemaxplayers for MvM", FCVAR_NOTIFY, true, -1.0, true, 10.0);	
	g_hAdTimer = CreateConVar("mvm_drop_money_info_timer", "90.0", "Info about drop timer", FCVAR_NOTIFY | FCVAR_REPLICATED, true, 1.0);
	g_hDropAmount = CreateConVar("mvm_drop_money_amount", "50", "<= 50.0 - cash small, <= 100 - cash medium, <= 200 cash large", FCVAR_NOTIFY | FCVAR_REPLICATED, true, 1.0);
	sv_visiblemaxplayers = FindConVar("sv_visiblemaxplayers");

	HookConVarChange(cvarCount, cvarChange_cvarCount);
	HookConVarChange(sv_visiblemaxplayers, cvarChange_sv_visiblemaxplayers);

	AddCommandListener(Cmd_JoinTeam, "jointeam");
	AddCommandListener(Cmd_JoinTeam, "autoteam");

	RegAdminCmd("sm_setcash", Command_SetCash, ADMFLAG_SLAY);
	RegAdminCmd("sm_addcash", Command_AddCash, ADMFLAG_SLAY);
	RegAdminCmd("sm_removecash", Command_RemoveCash, ADMFLAG_SLAY);

	RegAdminCmd("sm_mvmred", Command_JoinRed, ADMFLAG_RESERVATION, "Usage: sm_mvmred to join RED team if on the spectator team");
	
	CreateTimer(g_hAdTimer.FloatValue, Timer_ShowInfo, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public Action Command_SetCash(int client, int args)
{
	int target = GetCmdArgTarget(client, 1);

	if (target == -1)
	{
		Vertex_SendPrint(client, "Target not found, please try again.");
		return Plugin_Handled;
	}

	int value = GetCmdArgInt(2);
	TF2_SetCash(target, value);

	if (client == target)
		Vertex_SendPrint(client, "You have set your cash pool to [H]%i[D].", value);
	else
	{
		Vertex_SendPrint(client, "You have set [H]%N[D]'s cash pool to %i.", target, value);
		Vertex_SendPrint(target, "[H]%N [D]has set your cash pool to [H]%i[D].", client, value);
	}

	return Plugin_Handled;
}

public Action Command_AddCash(int client, int args)
{
	int target = GetCmdArgTarget(client, 1);

	if (target == -1)
	{
		Vertex_SendPrint(client, "Target not found, please try again.");
		return Plugin_Handled;
	}

	int value = GetCmdArgInt(2);
	TF2_AddCash(target, value);

	if (client == target)
		Vertex_SendPrint(client, "You have added [H]%i [D]cash to your own cash pool.", value);
	else
	{
		Vertex_SendPrint(client, "You have added [H]%i [%D]cash to [H]%N[D]'s cash pool.", value, target);
		Vertex_SendPrint(target, "[H]%N [D]has added [H]%i [D]to your cash pool.", client, value);
	}

	return Plugin_Handled;
}

public Action Command_RemoveCash(int client, int args)
{
	int target = GetCmdArgTarget(client, 1);

	if (target == -1)
	{
		Vertex_SendPrint(client, "Target not found, please try again.");
		return Plugin_Handled;
	}

	int value = GetCmdArgInt(2);
	TF2_RemoveCash(target, value);

	if (client == target)
		Vertex_SendPrint(client, "You have removed [H]%i [D]cash from your own cash pool.", value);
	else
	{
		Vertex_SendPrint(client, "You have removed [H]%i [%D]cash from [H]%N[D]'s cash pool.", value, target);
		Vertex_SendPrint(target, "[H]%N [D]has removed [H]%i [D]from your cash pool.", client, value);
	}

	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "item_currencypack_custom"))
		SDKHook(entity, SDKHook_SpawnPost, OnMoneySpawn);
}

public Action OnMoneySpawn(int entity)
{
	if (GetEntProp(entity, Prop_Send, "m_bDistributed") == 0)
	{
		char strModel[PLATFORM_MAX_PATH];
		GetEntPropString(entity, Prop_Data, "m_ModelName", strModel, PLATFORM_MAX_PATH);
		
		if (strlen(strModel) > 0)
		{
			int ent = CreateEntityByName("tf_taunt_prop");
			DispatchSpawn(ent);
			
			SetEntityModel(ent, strModel);
			
			SetEntPropEnt(ent, Prop_Data, "m_hEffectEntity", entity);
			SetEntProp(ent, Prop_Send, "m_bGlowEnabled", 1);
			
			int iFlags = GetEntityFlags(entity);
			int iEffects = GetEntProp(ent, Prop_Send, "m_fEffects");
			SetEntProp(ent, Prop_Send, "m_fEffects", iEffects|1|16|8);
			SetEntityFlags(entity, iFlags | FL_EDICT_ALWAYS);
			
			SetVariantString("!activator");
			AcceptEntityInput(ent, "SetParent", entity);
			
			SDKHook(ent, SDKHook_SetTransmit, Hook_MoneyTransmit);
		}
	}
}

public Action Hook_MoneyTransmit(int ent, int other)
{
	if (other > 0 && other <= MaxClients && IsClientInGame(other))
	{
		int money = GetEntPropEnt(ent, Prop_Data, "m_hEffectEntity");
		
		if (IsValidEntity(money))
		{
			int iclrRender = GetEntProp(money, Prop_Send, "m_clrRender");
			
			if (iclrRender == -1)
				return Plugin_Continue;
		}
	}

	return Plugin_Handled;
}

public void OnMapStart()
{
	TF2_IsMvM();

	PrecacheSound(CASH_SOUND);
	
	PrecacheModel(CASH_SMALL);
	PrecacheModel(CASH_MEDIUM);
	PrecacheModel(CASH_LARGE);
}

public Action Cmd_JoinTeam(int client, const char[] cmd, int args)
{
	if (!TF2_IsMvM())
		return Plugin_Continue;
	
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	if (IsFakeClient(client))
		return Plugin_Continue;
	
	if (!CheckCommandAccess(client, "sm_mvmred", 0))
		return Plugin_Continue;
	
	if (DetermineTooManyReds())
		return Plugin_Continue;
	
	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	if (StrEqual(cmd, "autoteam", false) || StrEqual(arg1, "auto", false) || StrEqual(arg1, "spectator", false) || StrEqual(arg1, "red", false))
	{
		if (!StrEqual(arg1, "spectator", false) || TF2_GetClientTeam(client) == TFTeam_Unassigned)
		{
			RequestFrame(Frame_TurnToRed, GetClientUserId(client));
			return Plugin_Continue;
		}
	}

	return Plugin_Continue;
}

public void Frame_TurnToRed(any data)
{
	int client = GetClientOfUserId(data);
	
	if (IsValidClient(client))
		TurnToRed(client);
}

void TurnToRed(int client)
{
	if (TF2_GetClientTeam(client) == TFTeam_Red)
		return;
	
	int target[MAXPLAYERS + 1] = { -1, ... };
	int amount;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		if (TF2_GetClientTeam(i) == TFTeam_Red)
		{
			target[amount] = i;
			amount++;
		}
	}
	
	for (int i = 0; i < (amount - 5); i++)
	{
		if (target[i] != -1)
			SetEntProp(target[i], Prop_Send, "m_iTeamNum", view_as<int>(TFTeam_Blue));
	}

	TF2_ChangeClientTeam(client, TFTeam_Red);
	
	for (int i = 0; i < (amount - 5); i++)
	{
		if (target[i] != -1)
		{
			SetEntProp(target[i], Prop_Send, "m_iTeamNum", view_as<int>(TFTeam_Red));
			int flag = GetEntPropEnt(target[i], Prop_Send, "m_hItem");
			
			if (flag > MaxClients && IsValidEntity(flag))
			{
				if (GetEntProp(flag, Prop_Send, "m_iTeamNum") != view_as<int>(TFTeam_Red))
					AcceptEntityInput(flag, "ForceDrop");
			}
		}
	}
	
	if (GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass") == view_as<int>(TFClass_Unknown))
		ShowVGUIPanel(client, TF2_GetClientTeam(client) == TFTeam_Blue ? "class_blue" : "class_red");
}

public Action Command_JoinRed(int client, int args)
{
	if (!TF2_IsMvM())
		return Plugin_Continue;
	
	if (!IsValidClient(client))
		return Plugin_Handled;
	
	if (IsFakeClient(client))
		return Plugin_Continue;
	
	if (TF2_GetClientTeam(client) != TFTeam_Spectator)
		return Plugin_Handled;
	
	if (DetermineTooManyReds())
	{
		Vertex_SendPrint(client, "Sorry, there's too many people already on RED for the robots to spawn properly if you join.");
		return Plugin_Handled;
	}

	TurnToRed(client);
	Vertex_SendPrint(client, "You're no longer spectating.");

	return Plugin_Handled;
}

bool DetermineTooManyReds()
{
	int max = 10;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		if (IsClientReplay(i) || IsClientSourceTV(i))
			max--;
		
		if (TF2_GetClientTeam(i) == TFTeam_Red)
			max--;
	}

	return (max <= 0);
}

public void cvarChange_cvarCount(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (TF2_IsMvM())
		sv_visiblemaxplayers.IntValue = (cvarCount.IntValue > 0 ? cvarCount.IntValue : -1);
}

public void cvarChange_sv_visiblemaxplayers(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (TF2_IsMvM() && cvarCount.IntValue > 0 && convar.IntValue != cvarCount.IntValue)
		convar.IntValue = (cvarCount.IntValue);
}

public void TF2_OnPlayerSpawn(int client, int team, int class)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return;
	
	g_StartingCash[client] = GetEntProp(client, Prop_Send, "m_nCurrency");
	//SetEntProp(client, Prop_Send, "m_nCurrency", g_StartingCash[client]);
	
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "tf_halloween_pickup")) != -1)
		if (GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") == client)
			AcceptEntityInput(entity, "Kill");
}

public void OnClientPutInServer(int client)
{
	g_Blocked[client] = -1.0;
}

public Action Timer_ShowInfo(Handle timer)
{
	PrintToChatAll("\x07%06X[MVM] \x07%06XClick mouse second button + reload to share your cash with someone!", 0xc14000, 0xFFD700);
}

public void OnGameFrame()
{
	float time = GetGameTime();

	for (int client = 1; client < MaxClients; client++)
	{
		if (IsValidClient(client) && GetClientTeam(client) > 1 && GetEntProp(client, Prop_Send, "m_nCurrency") > 0 && (GetClientButtons(client) & IN_RELOAD) && (GetClientButtons(client) & IN_ATTACK2) && (g_Blocked[client] == -1.0 || g_Blocked[client] <= time))
		{
			SpawnDosh(client, g_hDropAmount.IntValue >= 200 ? CASH_LARGE : g_hDropAmount.IntValue >= 100 ? CASH_MEDIUM : CASH_SMALL);
			g_Blocked[client] = time + 0.25;
		}
	}
}

int SpawnDosh(int client, const char[] strModel, const int iColor[3] = {255, ...})
{
	if (GetEntProp(client, Prop_Send, "m_nCurrency") <= g_StartingCash[client])
		return -1;
	
	int entity = CreateEntityByName("tf_halloween_pickup");

	if (!IsValidEntity(entity))
		return entity;
	
	float fPlayerAngle[3];
	GetClientEyeAngles(client, fPlayerAngle);
	
	float fPlayerPosEx[3];
	fPlayerPosEx[0] = Cosine((fPlayerAngle[1] / 180) * FLOAT_PI);
	fPlayerPosEx[1] = Sine((fPlayerAngle[1] / 180) * FLOAT_PI);
	fPlayerPosEx[2] = 0.0;
		
	ScaleVector(fPlayerPosEx, 75.0);
	
	float fPos[3];
	GetClientAbsOrigin(client, fPos);
	fPos[2] += 4;

	float fPlayerPosAway[3];
	AddVectors(fPos, fPlayerPosEx, fPlayerPosAway);
		
	Handle hTraceEx = TR_TraceRayFilterEx(fPos, fPlayerPosAway, MASK_SOLID, RayType_EndPoint, ExTraceFilter);
	TR_GetEndPosition(fPos, hTraceEx);
	delete hTraceEx;
	
	float fDirection[3];
	fDirection[0] = fPos[0];
	fDirection[1] = fPos[1];
	fDirection[2] = fPos[2] - 1024;
		
	Handle hTrace = TR_TraceRayFilterEx(fPos, fDirection, MASK_SOLID, RayType_EndPoint, ExTraceFilter);
	TR_GetEndPosition(fPos, hTrace);
	delete hTrace;
		
	fPos[2] += 4;

	DispatchKeyValueVector(entity, "origin", fPos);
	DispatchKeyValue(entity, "pickup_particle", "");
	DispatchKeyValue(entity, "pickup_sound", "");
	DispatchKeyValue(entity, "powerup_model", strModel);
	DispatchKeyValue(entity, "OnPlayerTouch", "!self,Kill,0,,-1");
	DispatchSpawn(entity);

	SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", client);
	
	int iAmount = GetEntProp(client, Prop_Send, "m_nCurrency") >= g_hDropAmount.IntValue ? g_hDropAmount.IntValue : GetEntProp(client, Prop_Send, "m_nCurrency");
	SetEntProp(client, Prop_Send, "m_nCurrency", GetEntProp(client, Prop_Send, "m_nCurrency") - iAmount);
	
	iCash[entity] = iAmount;
	SetEntityRenderColor(entity, iColor[0], iColor[1], iColor[2], 255);
	
	SDKHook(entity, SDKHook_Touch, OnDoshTouch);		
	
	return entity;
}

public void OnDoshTouch(int entity, int client)
{
	if (!IsValidClient(client))
		return;
	
	SetEntProp(client, Prop_Send, "m_nCurrency", GetEntProp(client, Prop_Send, "m_nCurrency") + iCash[entity]);	
	EmitSoundToClient(client, CASH_SOUND);
	AcceptEntityInput(entity, "Kill");
}

public bool ExTraceFilter(int entity, int contentmask)
{
	return entity > MaxClients || !entity;
}