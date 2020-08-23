/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Permissions"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.2"
#define PLUGIN_URL "https://vertexheights.com/"

#define FLAG_LETTERS_SIZE 26

#define MENU_GIVE 1
#define MENU_EDIT 2
#define MENU_REMOVE 3

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>

#include <vertexheights>
#include <vh-core>
#include <vh-permissions>
#include <vh-logs>

/*****************************/
//Globals
Database g_Database;
Handle g_Forward_OnPermissionsParsed;

int g_Group[MAXPLAYERS + 1] = {VH_NULLADMGRP, ...};
GroupId g_GroupID[MAXPLAYERS + 1] = {INVALID_GROUP_ID, ...};

ArrayList g_Groups;
StringMap g_GroupNames;
StringMap g_GroupFlags;
StringMap g_GroupImmunity;

AdminFlag g_FlagLetters[FLAG_LETTERS_SIZE];

#define INPUT_NONE 0
#define INPUT_VID 1
#define INPUT_STEAMID 2

enum struct Inputs
{
	int client;
	bool open;
	int type;
	int menu;

	void Init(int client)
	{
		this.client = client;
		this.open = false;
		this.type = INPUT_NONE;
	}

	void Reset()
	{
		this.client = -1;
		this.open = false;
		this.type = INPUT_NONE;
	}

	void RequestInput(int type, int menu)
	{
		this.open = true;
		this.type = type;
		this.menu = menu;

		switch (this.type)
		{
			case INPUT_VID:
				Vertex_SendPrint(this.client, "Please specify a Vertex ID:");
			case INPUT_STEAMID:
				Vertex_SendPrint(this.client, "Please specify a Steam ID (must have a Vertex ID available):");
		}
	}

	void CloseInput()
	{
		this.open = false;
		this.type = INPUT_NONE;
		Vertex_SendPrint(this.client, "Input request is now closed.");
	}
}

Inputs g_Inputs[MAXPLAYERS + 1];

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
	RegPluginLibrary("vh-permissions");

	CreateNative("VH_OpenPermissionsMenu", Native_OpenPermissionsMenu);
	CreateNative("VH_GetAdmGroup", Native_GetAdmGroup);

	g_Forward_OnPermissionsParsed = CreateGlobalForward("VH_OnPermissionsParsed", ET_Ignore, Param_Cell, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	Database.Connect(onSQLConnect, "default");

	RegAdminCmd("sm_permissions", Command_Permissions, ADMFLAG_GENERIC, "Manage Vertex permissions.");
	RegAdminCmd("sm_reloadperms", Command_ReloadPerms, ADMFLAG_ROOT, "Reload vertex permissions.");

	g_Groups = new ArrayList();
	g_GroupNames = new StringMap();
	g_GroupFlags = new StringMap();
	g_GroupImmunity = new StringMap();

	g_FlagLetters = CreateFlagLetters();

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i))
			OnClientConnected(i);
}

public void VH_OnHubOpen(int client, Menu menu)
{
	if (g_Group[client] == 2)
	{
		menu.AddItem("vip", "VIP Only Menu", ITEMDRAW_DISABLED);
		menu.AddItem("bans", "Manage Bans");
		menu.AddItem("permissions", "Manage Permissions");
	}
	
	if (g_Group[client] == 3)
	{
		menu.AddItem("vip", "VIP Only Menu", ITEMDRAW_DISABLED);
		menu.AddItem("bans", "Manage Bans");
	}

	if (g_Group[client] == 4 || g_Group[client] == 5)
		menu.AddItem("vip", "VIP Only Menu", ITEMDRAW_DISABLED);
}

public void OnMapStart()
{
	PrecacheSound("misc/achievement_earned.wav");
}

AdminFlag CreateFlagLetters()
{
	AdminFlag FlagLetters[FLAG_LETTERS_SIZE];

	FlagLetters['a'-'a'] = Admin_Reservation;
	FlagLetters['b'-'a'] = Admin_Generic;
	FlagLetters['c'-'a'] = Admin_Kick;
	FlagLetters['d'-'a'] = Admin_Ban;
	FlagLetters['e'-'a'] = Admin_Unban;
	FlagLetters['f'-'a'] = Admin_Slay;
	FlagLetters['g'-'a'] = Admin_Changemap;
	FlagLetters['h'-'a'] = Admin_Convars;
	FlagLetters['i'-'a'] = Admin_Config;
	FlagLetters['j'-'a'] = Admin_Chat;
	FlagLetters['k'-'a'] = Admin_Vote;
	FlagLetters['l'-'a'] = Admin_Password;
	FlagLetters['m'-'a'] = Admin_RCON;
	FlagLetters['n'-'a'] = Admin_Cheats;
	FlagLetters['o'-'a'] = Admin_Custom1;
	FlagLetters['p'-'a'] = Admin_Custom2;
	FlagLetters['q'-'a'] = Admin_Custom3;
	FlagLetters['r'-'a'] = Admin_Custom4;
	FlagLetters['s'-'a'] = Admin_Custom5;
	FlagLetters['t'-'a'] = Admin_Custom6;
	FlagLetters['z'-'a'] = Admin_Root;

	return FlagLetters;
}

public void onSQLConnect(Database db, const char[] error, any data)
{
	if (db == null)
		LogError("Error while connecting to database: %s", error);
	
	g_Database = db;
	g_Database.SetCharset("utf8");

	ParseGroups();

	int vid;
	for (int i = 1; i <= MaxClients; i++)
		if ((vid = VH_GetVertexID(i)) != VH_NULLID)
			VH_OnSynced(i, vid);
}

public Action Command_Permissions(int client, int args)
{
	if (args > 0)
	{
		int target = GetCmdArgTarget(client, 1, true, false);

		if (target == -1)
		{
			Vertex_SendPrint(client, "Target not found, please try again.");
			return Plugin_Handled;
		}

		char sID[16];
		IntToString(g_Group[target], sID, sizeof(sID));
							
		char sGroup[64];
		g_GroupNames.GetString(sID, sGroup, sizeof(sGroup));

		Vertex_SendPrint(client, "%N's current permissions group is: [H]%s", target, sGroup);

		return Plugin_Handled;
	}

	if (CheckCommandAccess(client, "", ADMFLAG_ROOT, true))	
		OpenPermissionsMenu(client, false);
	else
		Vertex_SendPrint(client, "You must have higher group privileges to access this menu.");
	
	return Plugin_Handled;
}

public int Native_OpenPermissionsMenu(Handle plugin, int numParams)
{
	OpenPermissionsMenu(GetNativeCell(1));
}

void OpenPermissionsMenu(int client, bool back = true)
{
	Menu menu = new Menu(MenuHandler_Permissions);
	menu.SetTitle("Vertex Permissions :: Main Menu\n \n");

	menu.AddItem("give", "Give Permissions");
	menu.AddItem("edit", "Edit Permissions");
	menu.AddItem("remove", "Remove Permissions");

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Permissions(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "give"))
				OpenGivePermissionsMenu(param1);
			else if (StrEqual(sInfo, "edit"))
				OpenEditPermissionsMenu(param1);
			else if (StrEqual(sInfo, "remove"))
				OpenRemovePermissionsMenu(param1);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				VH_OpenVertexHub(param1);
		case MenuAction_End:
			delete menu;
	}
}

void OpenGivePermissionsMenu(int client, bool back = true)
{
	Menu menu = new Menu(MenuHandler_Give);
	menu.SetTitle("Vertex Permissions :: Give\n \n");

	menu.AddItem("player", "Choose a Player");
	menu.AddItem("vid", "Input a Vertex ID");
	menu.AddItem("steamid", "Input a SteamID");

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Give(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "player"))
				OpenPlayersMenu(param1, MENU_GIVE);
			else if (StrEqual(sInfo, "vid"))
				g_Inputs[param1].RequestInput(INPUT_VID, MENU_GIVE);
			else if (StrEqual(sInfo, "steamid"))
				g_Inputs[param1].RequestInput(INPUT_VID, MENU_GIVE);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenPermissionsMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

void OpenEditPermissionsMenu(int client, bool back = true)
{
	Menu menu = new Menu(MenuHandler_Edit);
	menu.SetTitle("Vertex Permissions :: Edit\n \n");

	menu.AddItem("player", "Choose a Player");
	menu.AddItem("vid", "Input a Vertex ID");
	menu.AddItem("steamid", "Input a SteamID");

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Edit(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "player"))
				OpenPlayersMenu(param1, MENU_EDIT);
			else if (StrEqual(sInfo, "vid"))
				g_Inputs[param1].RequestInput(INPUT_VID, MENU_EDIT);
			else if (StrEqual(sInfo, "steamid"))
				g_Inputs[param1].RequestInput(INPUT_VID, MENU_EDIT);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenPermissionsMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

void OpenRemovePermissionsMenu(int client, bool back = true)
{
	Menu menu = new Menu(MenuHandler_Remove);
	menu.SetTitle("Vertex Permissions :: Remove\n \n");

	menu.AddItem("player", "Choose a Player");
	menu.AddItem("vid", "Input a Vertex ID");
	menu.AddItem("steamid", "Input a SteamID");

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Remove(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "player"))
				OpenPlayersMenu(param1, MENU_REMOVE);
			else if (StrEqual(sInfo, "vid"))
				g_Inputs[param1].RequestInput(INPUT_VID, MENU_REMOVE);
			else if (StrEqual(sInfo, "steamid"))
				g_Inputs[param1].RequestInput(INPUT_VID, MENU_REMOVE);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenPermissionsMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

void OpenPlayersMenu(int client, int type, bool back = true)
{
	Menu menu = new Menu(MenuHandler_Player);
	menu.SetTitle("Vertex Permissions :: Pick a player:\n \n");

	char sVID[16]; char sName[MAX_NAME_LENGTH];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !CanUserTarget(client, i))
			continue;
		
		switch (type)
		{
			case MENU_GIVE:
			{
				if (g_GroupID[i] != INVALID_GROUP_ID)
					continue;
			}
			case MENU_EDIT, MENU_REMOVE:
			{
				if (g_GroupID[i] == INVALID_GROUP_ID)
					continue;
			}
		}

		IntToString(VH_GetVertexID(i), sVID, sizeof(sVID));
		GetClientName(i, sName, sizeof(sName));

		menu.AddItem(sVID, sName);
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", "--Empty--", ITEMDRAW_DISABLED);

	PushMenuInt(menu, "type", type);

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Player(Menu menu, MenuAction action, int param1, int param2)
{
	int type = GetMenuInt(menu, "type");

	switch (action)
	{
		case MenuAction_Select:
		{
			char sUserID[16]; char sName[MAX_NAME_LENGTH];
			menu.GetItem(param2, sUserID, sizeof(sUserID), _, sName, sizeof(sName));
			int vid = StringToInt(sUserID);

			switch (type)
			{
				case MENU_GIVE:
					OpenGroupsMenu(param1, type, vid);
				case MENU_EDIT:
					OpenEditPlayerPermissionsMenu(param1, type, vid);
				case MENU_REMOVE:
				{
					Vertex_SendPrint(param1, "You have removed [H]%s[D]'s permissions group.", sName);

					int target = VH_GetClientByVID(vid);

					if (target > 0)
					{
						Vertex_SendPrint(target, "[H]%N [D]has removed your permissions group.", param1);
						
						char sID[16];
						IntToString(g_Group[target], sID, sizeof(sID));
						
						char sGroup[64];
						g_GroupNames.GetString(sID, sGroup, sizeof(sGroup));
						
						VH_SystemLog("%N has removed %N from the %s group.", param1, target, sGroup);
					}
					
					UpdatePlayerGroup(vid, 0);
					OpenRemovePermissionsMenu(param1);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				switch (type)
				{
					case MENU_GIVE:
						OpenGivePermissionsMenu(param1);
					case MENU_EDIT:
						OpenEditPermissionsMenu(param1);
					case MENU_REMOVE:
						OpenRemovePermissionsMenu(param1);
				}
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

void OpenEditPlayerPermissionsMenu(int client, int type, int vid, bool back = true)
{
	int target = VH_GetClientByVID(vid);

	Menu menu = new Menu(MenuHandler_PlayerPermissions);
	if (target > 0)
		menu.SetTitle("Vertex Permissions :: Edit Player:\nPlayer: %N\n \n", target);
	else
		menu.SetTitle("Vertex Permissions :: Edit Player:\nVID: %i\n \n", vid);

	menu.AddItem("group", "Edit Group");

	PushMenuInt(menu, "type", type);
	PushMenuInt(menu, "vid", vid);

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_PlayerPermissions(Menu menu, MenuAction action, int param1, int param2)
{
	int type = GetMenuInt(menu, "type");
	int vid = GetMenuInt(menu, "vid");

	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "group"))
				OpenGroupsMenu(param1, type, vid);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenPlayersMenu(param1, type);
		case MenuAction_End:
			delete menu;
	}
}

void OpenGroupsMenu(int client, int type, int vid, bool back = true)
{
	int target = VH_GetClientByVID(vid);
	
	Menu menu = new Menu(MenuHandler_Groups);
	if (target > 0)
		menu.SetTitle("Vertex Permissions :: Pick a group:\nPlayer: %N\n \n", target);
	else
		menu.SetTitle("Vertex Permissions :: Pick a group:\nVID: %i\n \n", vid);

	char sID[16]; char sName[64];
	for (int i = 0; i < g_Groups.Length; i++)
	{
		IntToString(g_Groups.Get(i), sID, sizeof(sID));
		g_GroupNames.GetString(sID, sName, sizeof(sName));
		menu.AddItem(sID, sName);
	}

	PushMenuInt(menu, "type", type);
	PushMenuInt(menu, "vid", vid);

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Groups(Menu menu, MenuAction action, int param1, int param2)
{
	int type = GetMenuInt(menu, "type");
	int vid = GetMenuInt(menu, "vid");

	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[16]; char sGroup[64];
			menu.GetItem(param2, sID, sizeof(sID), _, sGroup, sizeof(sGroup));

			int target = VH_GetClientByVID(vid);

			if (StrEqual(sGroup, "Supporter") && target > 0)
			{
				Vertex_SendPrintToAll("[H]%N [D]has granted [H]%N [D]VIP!", param1, target);
				EmitSoundToAll("misc/achievement_earned.wav");
			}
			
			int id = StringToInt(sID);

			if (target > 0)
				VH_SystemLog("%N has set Player %N's group to %s.", param1, target, sGroup);
			else
				VH_SystemLog("%N has set VID %i's group to %s.", param1, vid, sGroup);

			switch (type)
			{
				case MENU_GIVE:
				{
					InsertPlayerGroup(vid, id);

					if (target > 0)
					{
						Vertex_SendPrint(param1, "You have given Player [H]%N [D]the permissions group [H]%s[D].", target, sGroup);
						Vertex_SendPrint(target, "[H]%N [D]has given you permissions group [H]%s[D].", param1, sGroup);
					}
					else
						Vertex_SendPrint(param1, "You have given VID [H]%i [D]the permissions group [H]%s[D].", vid, sGroup);
					
					OpenPermissionsMenu(param1);
				}
				case MENU_EDIT:
				{
					UpdatePlayerGroup(vid, id);

					if (target > 0)
					{
						Vertex_SendPrint(param1, "You have set Player [H]%N[D]'s permissions group to [H]%s[D].", target, sGroup);
						Vertex_SendPrint(target, "[H]%N [D]has set your permissions group to [H]%s[D].", param1, sGroup);
					}
					else
						Vertex_SendPrint(param1, "You have set VID [H]%i[D]'s permissions group to [H]%s[D].", vid, sGroup);

					OpenEditPlayerPermissionsMenu(param1, type, vid);
				}
			}
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenPlayersMenu(param1, type);
		case MenuAction_End:
			delete menu;
	}
}

void ParseGroups()
{
	if (g_Database == null)
		return;
	
	g_Database.Query(OnParseGroups, "SELECT * FROM `admgroups`;");
}

public void OnParseGroups(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_ThrowSystemLog("Error while parsing admin groups: %s", error);
	
	g_Groups.Clear();
	g_GroupNames.Clear();
	g_GroupFlags.Clear();
	g_GroupImmunity.Clear();
	
	int id; char sID[16]; char sName[64]; char sFlags[64]; int immunity;
	GroupId curGrp = INVALID_GROUP_ID;

	while (results.FetchRow())
	{
		id = results.FetchInt(0);
		g_Groups.Push(id);
		IntToString(id, sID, sizeof(sID));

		results.FetchString(1, sName, sizeof(sName));
		g_GroupNames.SetString(sID, sName);

		results.FetchString(2, sFlags, sizeof(sFlags));
		g_GroupFlags.SetString(sID, sFlags);

		immunity = results.FetchInt(3);
		g_GroupImmunity.SetValue(sID, immunity);

		curGrp = CreateAdmGroup(sName);

		if (curGrp == INVALID_GROUP_ID)
			curGrp = FindAdmGroup(sName);
		
		for (int i = 0; i < strlen(sFlags); ++i)
		{
			if (sFlags[i] < 'a' || sFlags[i] > 'z')
				continue;

			if (g_FlagLetters[sFlags[i]-'a'] < Admin_Reservation)
				continue;

			curGrp.SetFlag(g_FlagLetters[sFlags[i] - 'a'], true);
		}

		if (immunity > 0)
			curGrp.ImmunityLevel = immunity;
	}

	CheckLoadAdmins();
}

void CheckLoadAdmins()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsClientAuthorized(i))
		{
			RunAdminCacheChecks(i);
			NotifyPostAdminCheck(i);
		}
	}
}

void InsertPlayerGroup(int vid, int groupid)
{
	DataPack pack = new DataPack();
	pack.WriteCell(vid);
	pack.WriteCell(groupid);

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `permissions` (v_id, admgroup) VALUES ('%i', '%i') ON DUPLICATE KEY UPDATE admgroup = '%i';", vid, groupid, groupid);
	g_Database.Query(OnInsertPlayerGroup, sQuery, pack, DBPrio_Low);
}

public void OnInsertPlayerGroup(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();

	int vid = pack.ReadCell();
	int groupid = pack.ReadCell();

	delete pack;

	if (results == null)
		VH_ThrowSystemLog("Error while inserting vertex id %i's permissions group: %s", vid, error);
	
	int client = VH_GetClientByVID(vid);

	if (client > 0)
	{
		char sID[16];
		IntToString(groupid, sID, sizeof(sID));
		
		char sGroup[64];
		g_GroupNames.GetString(sID, sGroup, sizeof(sGroup));

		g_Group[client] = groupid;
		g_GroupID[client] = FindAdmGroup(sGroup);

		Call_StartForward(g_Forward_OnPermissionsParsed);
		Call_PushCell(client);
		Call_PushCell(groupid);
		Call_Finish();
		
		char auth[64];
		if (GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth)))
			SetPlayerGroup(client, auth);
	}
}

void UpdatePlayerGroup(int vid, int groupid)
{
	DataPack pack = new DataPack();
	pack.WriteCell(vid);
	pack.WriteCell(groupid);

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `permission` SET admgroup = '%i' WHERE v_id = '%i';", groupid, vid);
	g_Database.Query(OnUpdatePlayerGroup, sQuery, pack, DBPrio_Low);
}

public void OnUpdatePlayerGroup(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();

	int vid = pack.ReadCell();
	int groupid = pack.ReadCell();

	delete pack;

	if (results == null)
		VH_ThrowSystemLog("Error while updating vertex id %i's permissions group: %s", vid, error);
	
	int client = VH_GetClientByVID(vid);

	if (client > 0)
	{
		char sID[16];
		IntToString(groupid, sID, sizeof(sID));
		
		char sGroup[64];
		g_GroupNames.GetString(sID, sGroup, sizeof(sGroup));

		g_Group[client] = groupid;
		g_GroupID[client] = FindAdmGroup(sGroup);

		Call_StartForward(g_Forward_OnPermissionsParsed);
		Call_PushCell(client);
		Call_PushCell(groupid);
		Call_Finish();
		
		char auth[64];
		if (GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth)))
			SetPlayerGroup(client, auth);
	}
}

public void VH_OnSynced(int client, int vid)
{
	g_Group[client] = VH_NULLADMGRP;
	g_GroupID[client] = INVALID_GROUP_ID;

	if (IsFakeClient(client) || g_Database == null)
		return;
	
	char auth[64];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(auth);
	
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT admgroup FROM `permissions` WHERe v_id = '%i';", vid);
	g_Database.Query(onParseGroup, sQuery, pack);
}

public void onParseGroup(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();

	int userid = pack.ReadCell();

	char auth[64];
	pack.ReadString(auth, sizeof(auth));

	delete pack;

	int client;
	if ((client = GetClientOfUserId(userid)) == 0)
		return;
	
	if (results == null)
		VH_ThrowSystemLog("Error while parsing permissions group: %s", error);
	
	if (results.FetchRow())
	{
		int groupid = results.FetchInt(0);

		char sID[16];
		IntToString(groupid, sID, sizeof(sID));
		
		char sGroup[64];
		g_GroupNames.GetString(sID, sGroup, sizeof(sGroup));
		
		g_Group[client] = groupid;
		g_GroupID[client] = FindAdmGroup(sGroup);

		Call_StartForward(g_Forward_OnPermissionsParsed);
		Call_PushCell(client);
		Call_PushCell(groupid);
		Call_Finish();

		SetPlayerGroup(client, auth);
	}
	else
	{
		Call_StartForward(g_Forward_OnPermissionsParsed);
		Call_PushCell(client);
		Call_PushCell(VH_NULLADMGRP);
		Call_Finish();
	}
}

void SetPlayerGroup(int client, const char[] auth)
{
	AdminId adm = INVALID_ADMIN_ID;
	if ((adm = FindAdminByIdentity(AUTHMETHOD_STEAM, auth)) != INVALID_ADMIN_ID)
		RemoveAdmin(adm);
	
	if (g_GroupID[client] == INVALID_GROUP_ID)
		return;

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));
	
	adm = CreateAdmin(sName);
	if (!adm.BindIdentity(AUTHMETHOD_STEAM, auth))
		return;
	
	adm.InheritGroup(g_GroupID[client]);

	if (IsClientInGame(client))
		RunAdminCacheChecks(client);
}

public void OnClientConnected(int client)
{
	g_Inputs[client].Init(client);
}

public void OnClientDisconnect_Post(int client)
{
	g_Group[client] = VH_NULLADMGRP;
	g_GroupID[client] = INVALID_GROUP_ID;
	g_Inputs[client].Reset();
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	switch (part)
	{
		case AdminCache_Groups:
			ParseGroups();
		case AdminCache_Admins:
		{
			int vid;
			for (int i = 1; i <= MaxClients; i++)
				if ((vid = VH_GetVertexID(i)) != VH_NULLID)
					VH_OnSynced(i, vid);
		}
	}
}

public Action Command_ReloadPerms(int client, int args)
{
	int vid;
	for (int i = 1; i <= MaxClients; i++)
		if ((vid = VH_GetVertexID(i)) != VH_NULLID)
			VH_OnSynced(i, vid);
	
	Vertex_SendPrint(client, "Permissions have been reloaded.");
	return Plugin_Handled;
}

public int Native_GetAdmGroup(Handle plugin, int numParams)
{
	return g_Group[GetNativeCell(1)];
}

public void VH_OnPermissionsParsed(int client, int admgroup)
{
	if (IsCurrentMap("itemtest") && admgroup == VH_NULLADMGRP)
		KickClient(client, "This server is currently locked.");
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (g_Inputs[client].open)
	{
		char sInput[32];
		strcopy(sInput, sizeof(sInput), sArgs);
		TrimString(sInput);
		
		int menu = g_Inputs[client].menu;

		switch (g_Inputs[client].type)
		{
			case INPUT_VID:
			{
				int vid = StringToInt(sInput);

				switch (menu)
				{
					case MENU_GIVE:
						OpenGroupsMenu(client, menu, vid);
					case MENU_EDIT:
						OpenEditPlayerPermissionsMenu(client, menu, vid);
					case MENU_REMOVE:
					{
						int target = VH_GetClientByVID(vid);

						if (target > 0)
						{
							Vertex_SendPrint(client, "You have removed Player [H]%N[D]'s permissions group.", target);
							Vertex_SendPrint(target, "[H]%N [D]has removed your permissions group.", client);
							
							char sID[16];
							IntToString(g_Group[target], sID, sizeof(sID));
							
							char sGroup[64];
							g_GroupNames.GetString(sID, sGroup, sizeof(sGroup));
							
							VH_SystemLog("%N has removed %N from the %s group.", client, target, sGroup);
							UpdatePlayerGroup(vid, 0);
						}
						else
							Vertex_SendPrint(client, "You have removed VID [H]%i[D]'s permissions group.", vid);
						
						OpenRemovePermissionsMenu(client);
					}
				}
			}

			case INPUT_STEAMID:
			{

			}
		}
		

		g_Inputs[client].CloseInput();
	}

	return Plugin_Continue;
}