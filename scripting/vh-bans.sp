/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Bans"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.2"
#define PLUGIN_URL "https://vertexheights.com/"

#define MENU_ADD 1
#define MENU_EDIT 2
#define MENU_SERVE 3
#define MENU_DELETE 4

#define BAN_TYPE_CONNECT 0
#define BAN_TYPE_VOICECHAT 1
#define BAN_TYPE_TEXTCHAT 2
#define BAN_TYPE_SPRAYS 3

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>

#include <vertexheights>
#include <vh-core>
#include <vh-permissions>
#include <vh-bans>
#include <vh-logs>

/*****************************/
//Globals
Database g_Database;

enum struct Bans
{
	int voiceid;
	int voice;
	int voicelength;
	int chatid;
	int chat;
	int chatlength;
	int sprayid;
	int spray;
	int spraylength;

	void Reset()
	{
		this.voiceid = -1;
		this.voice = -1;
		this.voicelength = -1;
		this.chatid = -1;
		this.chat = -1;
		this.chatlength = -1;
		this.sprayid = -1;
		this.spray = -1;
		this.spraylength = -1;
	}

	void ResetVoice()
	{
		this.voice = -1;
		this.voiceid = -1;
		this.voicelength = -1;
	}

	void ResetChat()
	{
		this.chat = -1;
		this.chatid = -1;
		this.chatlength = -1;
	}

	void ResetSpray()
	{
		this.spray = -1;
		this.sprayid = -1;
		this.spraylength = -1;
	}
}

Bans g_Bans[MAXPLAYERS + 1];

float g_SprayLocation[MAXPLAYERS + 1][3];

enum struct Report
{
	int vid;
	int type;
	char reason[32];
	int length;
	char filter[32];
	char name[MAX_NAME_LENGTH];
	bool inputreason;

	void Reset()
	{
		this.vid = VH_NULLID;
		this.type = BAN_TYPE_CONNECT;
		this.reason[0] = '\0';
		this.length = 0;
		this.filter[0] = '\0';
		this.name[0] = '\0';
		this.inputreason = false;
	}
}

Report g_Report[MAXPLAYERS + 1];

enum struct Disconnects
{
	char name[64];
	int vid;
}

Disconnects g_Disconnects[50];
int g_NextSlot;

ArrayList g_Quickban;

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
	RegPluginLibrary("vh-bans");
	CreateNative("VH_OpenBansMenu", Native_OpenBansMenu);
	return APLRes_Success;
}

public void OnPluginStart()
{
	Database.Connect(onSQLConnect, "default");

	RegAdminCmd("sm_bans", Command_Banplayer, ADMFLAG_BAN, "Manage Vertex bans.");
	RegAdminCmd("sm_quickban", Command_Quickban, ADMFLAG_GENERIC, "Temporarily ban players on the server during a map session.");

	AddTempEntHook("Player Decal", TempEnt_PlayerDecal);

	g_Quickban = new ArrayList();

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i))
			OnClientConnected(i);
	
	CreateTimer(1.0, Timer_HandleBans, _, TIMER_REPEAT);
}

public void onSQLConnect(Database db, const char[] error, any data)
{
	if (db == null)
		LogError("Error while connecting to database: %s", error);
	
	g_Database = db;
	g_Database.SetCharset("utf8");
}

public Action Command_Banplayer(int client, int args)
{
	OpenBansMenu(client, false);
	return Plugin_Handled;
}

public int Native_OpenBansMenu(Handle plugin, int numParams)
{
	OpenBansMenu(GetNativeCell(1));
}

void OpenBansMenu(int client, bool back = true)
{
	Menu menu = new Menu(MenuHandler_Bans);
	menu.SetTitle("Vertex Bans :: Main Menu\n \n");

	menu.AddItem("add", "File a Ban Report");
	menu.AddItem("edit", "Edit a Ban Report");
	menu.AddItem("serve", "Serve a Ban Report");

	if (IsDrixevel(client) || VH_GetAdmGroup(client) == 1)
		menu.AddItem("delete", "Delete a Ban Report (root)");

	menu.AddItem("disconnects", "Show Recent Disconnects");

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Bans(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "add"))
				OpenAddBanMenu(param1);
			else if (StrEqual(sInfo, "edit"))
				OpenEditBanMenu(param1);
			else if (StrEqual(sInfo, "serve"))
				OpenServeBanMenu(param1);
			else if (StrEqual(sInfo, "delete"))
				OpenDeleteBanMenu(param1);
			else if (StrEqual(sInfo, "disconnects"))
				OpenDisconnectsMenu(param1);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				VH_OpenVertexHub(param1);
		case MenuAction_End:
			delete menu;
	}
}

void OpenAddBanMenu(int client)
{
	Menu menu = new Menu(MenuHandler_AddBans);
	menu.SetTitle("Vertex Bans :: Add:\n \n");

	menu.AddItem("player", "Choose a Player");
	menu.AddItem("vid", "Input a Vertex ID");
	menu.AddItem("steamid", "Input a Steam ID");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AddBans(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "player"))
				OpenPlayersMenu(param1, MENU_ADD);
			else if (StrEqual(sInfo, "vid"))
				g_Inputs[param1].RequestInput(INPUT_VID, MENU_ADD);
			else if (StrEqual(sInfo, "steamid"))
				g_Inputs[param1].RequestInput(INPUT_STEAMID, MENU_ADD);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenBansMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

void OpenEditBanMenu(int client)
{
	Menu menu = new Menu(MenuHandler_EditBans);
	menu.SetTitle("Vertex Bans :: Edit:\n \n");

	menu.AddItem("player", "Choose a Player");
	menu.AddItem("vid", "Input a Vertex ID");
	menu.AddItem("steamid", "Input a Steam ID");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_EditBans(Menu menu, MenuAction action, int param1, int param2)
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
				g_Inputs[param1].RequestInput(INPUT_STEAMID, MENU_EDIT);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenBansMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

void OpenServeBanMenu(int client)
{
	Menu menu = new Menu(MenuHandler_ServeBans);
	menu.SetTitle("Vertex Bans :: Serve:\n \n");

	menu.AddItem("player", "Choose a Player");
	menu.AddItem("vid", "Input a Vertex ID");
	menu.AddItem("steamid", "Input a Steam ID");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ServeBans(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "player"))
				OpenPlayersMenu(param1, MENU_SERVE);
			else if (StrEqual(sInfo, "vid"))
				g_Inputs[param1].RequestInput(INPUT_VID, MENU_SERVE);
			else if (StrEqual(sInfo, "steamid"))
				g_Inputs[param1].RequestInput(INPUT_STEAMID, MENU_SERVE);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenBansMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

void OpenDeleteBanMenu(int client)
{
	Menu menu = new Menu(MenuHandler_DeleteBans);
	menu.SetTitle("Vertex Bans :: Delete:\n \n");

	menu.AddItem("player", "Choose a Player");
	menu.AddItem("vid", "Input a Vertex ID");
	menu.AddItem("steamid", "Input a Steam ID");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_DeleteBans(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "player"))
				OpenPlayersMenu(param1, MENU_DELETE);
			else if (StrEqual(sInfo, "vid"))
				g_Inputs[param1].RequestInput(INPUT_VID, MENU_DELETE);
			else if (StrEqual(sInfo, "steamid"))
				g_Inputs[param1].RequestInput(INPUT_STEAMID, MENU_DELETE);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenBansMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

public void OnClientConnected(int client)
{
	g_Bans[client].Reset();
	g_Inputs[client].Init(client);
}

public void OnClientDisconnect(int client)
{
	if (g_NextSlot >= 50)
		g_NextSlot = 0;
	
	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	strcopy(g_Disconnects[g_NextSlot].name, MAX_NAME_LENGTH, sName);
	g_Disconnects[g_NextSlot].vid = VH_GetVertexID(client);
	g_NextSlot++;
}

public void OnClientDisconnect_Post(int client)
{
	g_Bans[client].Reset();
	g_Report[client].Reset();
	g_Inputs[client].Reset();
}

void OpenDisconnectsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Disconnects);
	menu.SetTitle("Recent Disconnects:");

	char display[128]; char sID[16];
	for (int i = g_NextSlot; i >= 0; --i)
	{
		if (g_Disconnects[i].vid < 1)
			continue;
		
		IntToString(i, sID, sizeof(sID));
		FormatEx(display, sizeof(display), "[%i] %s", g_Disconnects[i].vid, g_Disconnects[i].name);
		menu.AddItem(sID, display);
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", " :: No Recent Disconnects.", ITEMDRAW_DISABLED);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Disconnects(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[16];
			menu.GetItem(param2, sID, sizeof(sID));
			int id = StringToInt(sID);

			OpenReportMenu(param1, g_Disconnects[id].vid, g_Disconnects[id].name);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenBansMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

void OpenPlayersMenu(int client, int menutype)
{
	Menu menu = new Menu(MenuHandler_Player);
	menu.SetTitle("Vertex Bans :: Pick a player:\n \n");

	char sVID[16]; char sName[MAX_NAME_LENGTH];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) /*|| IsDrixevel(i)*/)
			continue;
		
		switch (menutype)
		{
			case MENU_ADD:
			{

			}
			case MENU_EDIT, MENU_DELETE:
			{

			}
		}

		IntToString(VH_GetVertexID(i), sVID, sizeof(sVID));
		GetClientName(i, sName, sizeof(sName));

		menu.AddItem(sVID, sName);
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", "--Empty--", ITEMDRAW_DISABLED);

	PushMenuInt(menu, "menutype", menutype);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Player(Menu menu, MenuAction action, int param1, int param2)
{
	int menutype = GetMenuInt(menu, "menutype");

	switch (action)
	{
		case MenuAction_Select:
		{
			char sUserID[16]; char sName[MAX_NAME_LENGTH];
			menu.GetItem(param2, sUserID, sizeof(sUserID), _, sName, sizeof(sName));
			
			int vid = StringToInt(sUserID);

			switch (menutype)
			{
				case MENU_ADD:
					OpenReportMenu(param1, vid, sName);
				case MENU_EDIT:
					OpenListReportsMenu(param1, vid, sName, menutype);
				case MENU_SERVE:
					OpenListReportsMenu(param1, vid, sName, menutype);
				case MENU_DELETE:
					OpenListReportsMenu(param1, vid, sName, menutype);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				switch (menutype)
				{
					case MENU_ADD:
						OpenAddBanMenu(param1);
					case MENU_EDIT:
						OpenEditBanMenu(param1);
					case MENU_SERVE:
						OpenServeBanMenu(param1);
					case MENU_DELETE:
						OpenDeleteBanMenu(param1);
				}
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

void OpenReportMenu(int client, int vid = VH_NULLID, const char[] name = "")
{
	if (vid != VH_NULLID)
		g_Report[client].vid = vid;
	
	if (strlen(name) > 0)
		strcopy(g_Report[client].name, MAX_NAME_LENGTH, name);

	Menu menu = new Menu(MenuHandler_File);
	menu.SetTitle("Vertex Bans :: File a ban report:\nPlayer: %s (%i)\n \n", g_Report[client].name, g_Report[client].vid);

	char buffer[255];

	char sType[64];
	GetReportTypeName(g_Report[client].type, sType, sizeof(sType));

	FormatEx(buffer, sizeof(buffer), "Type: %s", sType);
	menu.AddItem("type", buffer);

	//FormatEx(buffer, sizeof(buffer), "Reason: %s", strlen(g_Report[client].reason) > 0 ? g_Report[client].reason : "N/A");
	//menu.AddItem("reason", buffer);

	char sLength[32];
	switch (g_Report[client].length)
	{
		case 0:
			strcopy(sLength, sizeof(sLength), "Forever");
		case 600:
			strcopy(sLength, sizeof(sLength), "10 minutes");
		case 1800:
			strcopy(sLength, sizeof(sLength), "30 minutes");
		case 3600:
			strcopy(sLength, sizeof(sLength), "1 Hour");
		case 21600:
			strcopy(sLength, sizeof(sLength), "6 Hours");
		case 43200:
			strcopy(sLength, sizeof(sLength), "12 Hours");
		case 86400:
			strcopy(sLength, sizeof(sLength), "1 Day");
		case 604800:
			strcopy(sLength, sizeof(sLength), "1 Week");
		case 1209600:
			strcopy(sLength, sizeof(sLength), "2 Weeks");
		case 2419200:
			strcopy(sLength, sizeof(sLength), "1 Month");
		case 7257600:
			strcopy(sLength, sizeof(sLength), "3 Months");
		case 14515200:
			strcopy(sLength, sizeof(sLength), "6 Months");
		case 29030400:
			strcopy(sLength, sizeof(sLength), "1 Year");
	}

	FormatEx(buffer, sizeof(buffer), "Length: %s", sLength);
	menu.AddItem("length", buffer);

	FormatEx(buffer, sizeof(buffer), "Filter: %s", strlen(g_Report[client].filter) == 0 ? "Global" : "Server");
	menu.AddItem("filter", buffer);

	menu.AddItem("submit", "Submit Report");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_File(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "type"))
				OpenTypesMenu(param1);
			else if (StrEqual(sInfo, "reason"))
				OpenReasonsMenu(param1);
			else if (StrEqual(sInfo, "length"))
				OpenLengthMenu(param1);
			else if (StrEqual(sInfo, "filter"))
				OpenFiltersMenu(param1);
			else if (StrEqual(sInfo, "submit"))
				SubmitReport(param1);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
			{
				g_Report[param1].Reset();
				OpenPlayersMenu(param1, MENU_ADD);
			}
		case MenuAction_End:
			delete menu;
	}
}

void OpenTypesMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Types);
	menu.SetTitle("Pick a type:");

	menu.AddItem("0", "Connect");
	menu.AddItem("1", "Voice Chat");
	menu.AddItem("2", "Text Chat");
	menu.AddItem("3", "Sprays");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Types(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sType[32];
			menu.GetItem(param2, sType, sizeof(sType));

			g_Report[param1].type = StringToInt(sType);
			OpenReportMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

void OpenReasonsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Reasons);
	menu.SetTitle("Pick a reason:");

	menu.AddItem("input", "Input a Custom Reason");
	menu.AddItem("", "Hacking");
	menu.AddItem("", "Glitching");
	menu.AddItem("", "Spamming");
	menu.AddItem("", "Racism");
	menu.AddItem("", "Sexism");
	menu.AddItem("", "Homophobia");
	menu.AddItem("", "Rude");
	menu.AddItem("", "Anger");
	menu.AddItem("", "Drama");
	menu.AddItem("", "Pornographic Spray");
	menu.AddItem("", "Gore Spray");
	menu.AddItem("", "Repulsive Spray");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Reasons(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInput[32]; char sReason[32];
			menu.GetItem(param2, sInput, sizeof(sInput), _, sReason, sizeof(sReason));

			if (StrEqual(sInput, "input"))
			{
				g_Report[param1].inputreason = true;
				Vertex_SendPrint(param1, "Type the reason in chat (It will not show up to others):");
			}
			else
			{
				strcopy(g_Report[param1].reason, 32, sReason);
				OpenReportMenu(param1);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

void OpenLengthMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Length);
	menu.SetTitle("Pick a length:");

	menu.AddItem("0", "Forever");
	menu.AddItem("600", "10 minutes");
	menu.AddItem("1800", "30 minutes");
	menu.AddItem("3600", "1 Hour");
	menu.AddItem("21600", "6 Hour");
	menu.AddItem("43200", "12 Hour");
	menu.AddItem("86400", "1 Day");
	menu.AddItem("604800", "1 Week");
	menu.AddItem("1209600", "2 Weeks");
	menu.AddItem("2419200", "1 Month");
	menu.AddItem("7257600", "3 Month");
	menu.AddItem("14515200", "6 Month");
	menu.AddItem("29030400", "1 Year");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Length(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sLength[32];
			menu.GetItem(param2, sLength, sizeof(sLength));

			g_Report[param1].length = StringToInt(sLength);
			OpenReportMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

void OpenFiltersMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Filters);
	menu.SetTitle("Pick a filter:");

	char sServerID[16];
	IntToString(VH_GetServerID(), sServerID, sizeof(sServerID));

	menu.AddItem("", "Global");
	menu.AddItem(sServerID, "Server");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Filters(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sFilter[32];
			menu.GetItem(param2, sFilter, sizeof(sFilter));

			strcopy(g_Report[param1].filter, 32, sFilter);
			OpenReportMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

void SubmitReport(int client)
{
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(g_Report[client].vid);
	pack.WriteCell(g_Report[client].type);
	pack.WriteString(g_Report[client].reason);
	pack.WriteCell(g_Report[client].length);
	pack.WriteString(g_Report[client].filter);

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `bans` (v_id, type, reason, length, expires, filter, adminid) VALUES ('%i', '%i', '%s', '%i', '%i', '%s', '%i');", g_Report[client].vid, g_Report[client].type, g_Report[client].reason, g_Report[client].length, (GetTime() + g_Report[client].length), g_Report[client].filter, VH_GetVertexID(client));
	g_Database.Query(onSubmitReport, sQuery, pack);

	g_Report[client].Reset();
}

public void onSubmitReport(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	int vid = pack.ReadCell();
	int type = pack.ReadCell();

	char sReason[32];
	pack.ReadString(sReason, sizeof(sReason));

	int length = pack.ReadCell();

	char sFilter[32];
	pack.ReadString(sFilter, sizeof(sFilter));

	delete pack;

	if (results == null)
		VH_ThrowSystemLog("Error while sending ban report: %s", error);
	
	if (client > 0)
	{
		char sType[64];
		GetReportTypeName(type, sType, sizeof(sType));

		Vertex_SendPrint(client, "Vertex ID [H]%i [D]has been banned successfully from: %s", vid, sType);
	}
	
	int target = VH_GetClientByVID(vid);

	if (target == -1)
		return;
	
	switch (type)
	{
		case BAN_TYPE_CONNECT:
			KickClient(target, "Your Vertex ID has been banned. Reason: %s", sReason);
		case BAN_TYPE_VOICECHAT:
		{
			g_Bans[target].voice = GetTime() + length;
			g_Bans[target].voiceid = results.InsertId;
			g_Bans[target].voicelength = length;
			SetClientListeningFlags(target, VOICE_MUTED);
			Vertex_SendPrint(target, "You have been banned from voice chat.");
		}
		case BAN_TYPE_TEXTCHAT:
		{
			g_Bans[target].chat = GetTime() + length;
			g_Bans[target].chatid = results.InsertId;
			g_Bans[target].chatlength = length;
			Vertex_SendPrint(target, "You have been banned from text chat.");
		}
		case BAN_TYPE_SPRAYS:
		{
			g_Bans[target].spray = GetTime() + length;
			g_Bans[target].sprayid = results.InsertId;
			g_Bans[target].spraylength = length;
			RemoveAimSpray(target);
			Vertex_SendPrint(target, "You have been banned from spraying.");
		}
	}
}

void OpenListReportsMenu(int client, int vid, const char[] name, int menutype)
{
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(vid);
	pack.WriteString(name);
	pack.WriteCell(menutype);

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT id, type, served FROM `bans` WHERE v_id = '%i' AND hidden = '0';", vid);
	g_Database.Query(onParseReports, sQuery, pack, DBPrio_Low);
}

public void onParseReports(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	int vid = pack.ReadCell();

	char name[MAX_NAME_LENGTH];
	pack.ReadString(name, sizeof(name));

	int menutype = pack.ReadCell();

	delete pack;

	if (results == null)
	{
		if (client > 0)
			Vertex_SendPrint(client, "Unknown error while parsing ban reports.");
		
		VH_ThrowSystemLog("Error while parsing ban reports: %s", error);
	}

	Menu menu = new Menu(MenuHandler_ParseReports);
	menu.SetTitle("Reports available for Vertex ID %i:", vid);

	int id; char sID[16]; int type; char sType[32]; int served; char sDisplay[256];
	while (results.FetchRow())
	{
		id = results.FetchInt(0);
		IntToString(id, sID, sizeof(sID));

		type = results.FetchInt(1);
		GetReportTypeName(type, sType, sizeof(sType));

		served = results.FetchInt(2);

		if (type == MENU_SERVE && served == 1)
			continue;

		FormatEx(sDisplay, sizeof(sDisplay), "(%i) %s %s", id, sType, served == 1 ? "(Served)" : "(Active)");
		menu.AddItem(sID, sDisplay, (menutype == MENU_SERVE && served == 1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", ":: No Reports Found.", ITEMDRAW_DISABLED);

	PushMenuInt(menu, "vid", vid);
	PushMenuString(menu, "name", name);
	PushMenuInt(menu, "menutype", menutype);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ParseReports(Menu menu, MenuAction action, int param1, int param2)
{
	int vid = GetMenuInt(menu, "vid");
	int menutype = GetMenuInt(menu, "menutype");

	char name[MAX_NAME_LENGTH];
	GetMenuString(menu, "name", name, sizeof(name));

	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[16];
			menu.GetItem(param2, sID, sizeof(sID));

			int id = StringToInt(sID);

			switch (menutype)
			{
				case MENU_EDIT:
					OpenEditReportMenu(param1, id, vid, name, menutype);
				case MENU_SERVE:
				{
					MarkReportServed(id);
					OpenListReportsMenu(param1, vid, name, menutype);
				}
				case MENU_DELETE:
				{
					MarkReportHidden(id);
					OpenListReportsMenu(param1, vid, name, menutype);
				}
			}
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenPlayersMenu(param1, menutype);
		case MenuAction_End:
			delete menu;
	}
}

void OpenEditReportMenu(int client, int id, int vid, char[] name, int menutype)
{
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(vid);
	pack.WriteString(name);
	pack.WriteCell(menutype);
	
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM `bans` WHERE id = '%i' AND hidden = '0';", id);
	g_Database.Query(onParseReport, sQuery, pack, DBPrio_Low);
}

public void onParseReport(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	int vid = pack.ReadCell();

	char name[MAX_NAME_LENGTH];
	pack.ReadString(name, sizeof(name));

	int menutype = pack.ReadCell();

	if (results == null)
	{
		if (client > 0)
			Vertex_SendPrint(client, "Unknown error while opening up report.");
		
		VH_ThrowSystemLog("Error while parsing a report: %s", error);
	}

	Menu menu = new Menu(MenuHandler_Report);

	char sBuffer[256];
	if (results.FetchRow())
	{
		int id = results.FetchInt(0);
		int v_id = results.FetchInt(1);

		menu.SetTitle("Report %i Details:\nVertexID: %i\n \n", id, v_id);

		int type2 = results.FetchInt(2);
		char sType[64];
		GetReportTypeName(type2, sType, sizeof(sType));
		FormatEx(sBuffer, sizeof(sBuffer), "Type: %s", sType);
		menu.AddItem("", sBuffer);

		char sReason[256];
		results.FetchString(3, sReason, sizeof(sReason));
		FormatEx(sBuffer, sizeof(sBuffer), "Reason: %s", sReason);
		menu.AddItem("", sBuffer);

		int length = results.FetchInt(4);
		FormatEx(sBuffer, sizeof(sBuffer), "Length: %i", length);
		menu.AddItem("", sBuffer);

		int expires = results.FetchInt(4);
		char sExpires[64];
		FormatTime(sExpires, sizeof(sExpires), "%c", expires);
		FormatEx(sBuffer, sizeof(sBuffer), "Expires: %s", sExpires);
		menu.AddItem("", sBuffer);
		
		char sFilter[32];
		results.FetchString(6, sFilter, sizeof(sFilter));
		FormatEx(sBuffer, sizeof(sBuffer), "Filter: %s", strlen(sFilter) == 0 ? "Global" : "Server");
		menu.AddItem("", sBuffer);

		int served = results.FetchInt(6);
		FormatEx(sBuffer, sizeof(sBuffer), "Report Status: %s", served == 1 ? "Served" : "Active");
		menu.AddItem("", sBuffer);
	}

	PushMenuInt(menu, "vid", vid);
	PushMenuString(menu, "name", name);
	PushMenuInt(menu, "menutype", menutype);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Report(Menu menu, MenuAction action, int param1, int param2)
{
	int vid = GetMenuInt(menu, "vid");

	char name[MAX_NAME_LENGTH];
	GetMenuString(menu, "name", name, sizeof(name));

	int menutype = GetMenuInt(menu, "menutype");

	switch (action)
	{
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenListReportsMenu(param1, vid, name, menutype);
		case MenuAction_End:
			delete menu;
	}
}

void GetReportTypeName(int type, char[] buffer, int size)
{
	switch (type)
	{
		case BAN_TYPE_CONNECT:
			strcopy(buffer, size, "Connect");
		case BAN_TYPE_VOICECHAT:
			strcopy(buffer, size, "Voice Chat");
		case BAN_TYPE_TEXTCHAT:
			strcopy(buffer, size, "Text Chat");
		case BAN_TYPE_SPRAYS:
			strcopy(buffer, size, "Sprays");
	}
}

public Action TempEnt_PlayerDecal(const char[] te_name, const int[] Players, int numClients, float delay)
{
	int client = TE_ReadNum("m_nPlayer");

	if (client == 0)
		return Plugin_Continue;
	
	if (g_Bans[client].spray != -1 && (g_Bans[client].spraylength == 0 || g_Bans[client].spray > GetTime()))
	{
		Vertex_SendPrint(client, "You are currently banned from spraying.");
		return Plugin_Handled;
	}

	float vecOrigin[3];
	TE_ReadVector("m_vecOrigin", vecOrigin);
	g_SprayLocation[client] = vecOrigin;

	return Plugin_Continue;
}

void RemoveAimSpray(int client)
{
	int owner = GetSprayOwnerFromAim(client);

	if (owner == -1)
		return;

	RemovePlayerSpray(owner);
	g_SprayLocation[owner][0] = 0.0;
	g_SprayLocation[owner][1] = 0.0;
	g_SprayLocation[owner][2] = 0.0;
}

int GetSprayOwnerFromAim(int client)
{
	float vecOrigin[3];
	if (!GetClientSprayLocation(client, vecOrigin))
		return -1;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		if (GetVectorDistance(vecOrigin, g_SprayLocation[i]) < 75.0)
			return i;
	}

	return -1;
}

bool GetClientSprayLocation(int client, float vector[3])
{
	if (!IsValidClient(client))
		return false;
	
	float vOrigin[3];
	GetClientEyePosition(client, vOrigin);

	float vAngles[3];
	GetClientEyeAngles(client, vAngles);

	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, ValidSpray);
	bool found;
	
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(vector, trace);
		found = true;
	}

	delete trace;
	return found;
}

public bool ValidSpray(int entity, int contentsmask)
{
	return entity > MaxClients;
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (g_Quickban.FindValue(GetSteamAccountID(client)) != -1)
		KickClient(client, "You have been temporarily banned this map session.");
}

public void VH_OnSynced(int client, int vid)
{
	if (g_Quickban.FindValue(vid) != -1)
		KickClient(client, "You have been temporarily banned this map session.");
	
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT id, type, reason, length, expires, filter FROM `bans` WHERE v_id = '%i' AND served = '0' AND hidden = '0';", vid);
	g_Database.Query(onParseBans, sQuery, GetClientUserId(client));
}

public void onParseBans(Database db, DBResultSet results, const char[] error, any data)
{
	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return;
	
	if (results == null)
		VH_ThrowSystemLog("Error while parsing bans data for %N: %s", client, error);

	int time = GetTime();

	char sServerID[16];
	IntToString(VH_GetServerID(), sServerID, sizeof(sServerID));
	
	while (results.FetchRow())
	{
		int id = results.FetchInt(0);
		int type = results.FetchInt(1);

		char reason[64];
		results.FetchString(2, reason, sizeof(reason));
		
		int length = results.FetchInt(3);
		int expires = results.FetchInt(4);

		char sFilter[32];
		results.FetchString(5, sFilter, sizeof(sFilter));

		if (strlen(sFilter) > 0 && StrContains(sFilter, sServerID, false) == -1)
			continue;

		switch (type)
		{
			case BAN_TYPE_CONNECT:
			{
				if (length == 0 || expires > time)
					KickClient(client, "Your Vertex ID has been banned. Reason: %s", reason);
				else
					MarkReportServed(id);
			}
			case BAN_TYPE_VOICECHAT:
			{
				g_Bans[client].voice = expires;
				g_Bans[client].voiceid = id;
				g_Bans[client].voicelength = length;
				Vertex_SendPrint(client, "You have been banned from voice chat.");

				if (length == 0 || expires > time)
					SetClientListeningFlags(client, VOICE_MUTED);
				else
					MarkReportServed(id);
			}
			case BAN_TYPE_TEXTCHAT:
			{
				g_Bans[client].chat = expires;
				g_Bans[client].chatid = id;
				g_Bans[client].chatlength = length;
				Vertex_SendPrint(client, "You have been banned from text chat.");

				if (length != 0 || expires <= time)
					MarkReportServed(id);
			}
			case BAN_TYPE_SPRAYS:
			{
				g_Bans[client].spray = expires;
				g_Bans[client].sprayid = id;
				g_Bans[client].spraylength = length;
				Vertex_SendPrint(client, "You have been banned from spraying.");

				if (length == 0 || expires > time)
					RemoveAimSpray(client);
				else
					MarkReportServed(id);
			}
		}
	}
}

public void OnMapEnd()
{
	g_Quickban.Clear();
}

public Action Command_Quickban(int client, int args)
{
	int target = GetCmdArgTargetEx(client, 1, true, true);

	if (target == -1)
	{
		Vertex_SendPrint(client, "Target not found to quickban, please try again.");
		return Plugin_Handled;
	}

	int vid = VH_GetVertexID(target);

	if (vid != VH_NULLID)
		g_Quickban.Push(vid);
	else
		g_Quickban.Push(GetSteamAccountID(target));
	
	Vertex_SendPrintToAll("%N has kicked and temporarily banned %N for this map session.", client, target);
	KickClient(target, "You have been temporarily banned this map session.");
	VH_SystemLog("%N has been quickbanned by %N for the map session.", target, client);

	return Plugin_Handled;
}

public Action Timer_HandleBans(Handle timer)
{
	int time = GetTime();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		if (g_Bans[i].voicelength > 0 && g_Bans[i].voice <= time)
		{
			MarkReportServed(g_Bans[i].voiceid);
			Vertex_SendPrint(i, "You voice ban has expired, you may talk again.");
			SetClientListeningFlags(i, VOICE_NORMAL);
			g_Bans[i].ResetVoice();
		}

		if (g_Bans[i].chatlength > 0 && g_Bans[i].chat <= time)
		{
			MarkReportServed(g_Bans[i].chatid);
			Vertex_SendPrint(i, "You chat ban has expired, you may type again.");

			g_Bans[i].ResetChat();
		}

		if (g_Bans[i].spraylength > 0 && g_Bans[i].spray <= time)
		{
			MarkReportServed(g_Bans[i].sprayid);
			Vertex_SendPrint(i, "You spray ban has expired, you may spray again.");

			g_Bans[i].ResetSpray();
		}
	}
}

void MarkReportServed(int report, bool status = true)
{
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `bans` SET served = %i WHERE id = '%i' AND hidden = '0';", status, report);
	g_Database.Query(onServeReport, sQuery, _, DBPrio_Low);
}

public void onServeReport(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_SystemLog("Error while setting served status for a report: %s", error);
}

void MarkReportHidden(int report, bool status = true)
{
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `bans` SET hidden = %i WHERE id = '%i';", status, report);
	g_Database.Query(onHideReport, sQuery, _, DBPrio_Low);
}

public void onHideReport(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		VH_SystemLog("Error while setting hidden status for a report: %s", error);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (g_Report[client].inputreason)
	{
		if (strlen(sArgs) > 32)
		{
			Vertex_SendPrint(client, "Reason must be 32 characters or less.");
			return Plugin_Stop;
		}

		char sReason[32];
		strcopy(sReason, sizeof(sReason), sArgs);
		TrimString(sReason);

		sReason[0] = CharToUpper(sReason[0]);
		strcopy(g_Report[client].reason, 32, sReason);

		g_Report[client].inputreason = false;
		OpenReportMenu(client);

		return Plugin_Stop;
	}

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
					case MENU_ADD:
						OpenReportMenu(client, vid, "");
					case MENU_EDIT:
						OpenListReportsMenu(client, vid, "", menu);
					case MENU_SERVE:
						OpenListReportsMenu(client, vid, "", menu);
					case MENU_DELETE:
						OpenListReportsMenu(client, vid, "", menu);
				}
			}

			case INPUT_STEAMID:
			{

			}
		}
		

		g_Inputs[client].CloseInput();
	}
	
	if (g_Bans[client].chat != -1 && (g_Bans[client].chatlength == 0 || g_Bans[client].chat > GetTime()))
	{
		Vertex_SendPrint(client, "You are currently banned from typing.");
		return Plugin_Stop;
	}

	return Plugin_Continue;
}