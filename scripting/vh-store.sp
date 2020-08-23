/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Store"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.8"
#define PLUGIN_URL "https://vertexheights.com/"

#define TYPE_SHOP 1
#define TYPE_INV 2
#define TYPE_GIVE 3

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>

#include <vertexheights>
#include <vh-core>
#include <vh-logs>
#include <vh-permissions>

#include <chat-processor>

/*****************************/
//ConVars
ConVar convar_Shop;
ConVar convar_Inventory;
ConVar convar_StartingCredits;

/*****************************/
//Forwards
Handle g_Forward_OnItemPurchase;
Handle g_Forward_OnItemPurchased;
Handle g_Forward_OnItemGive;
Handle g_Forward_OnItemGiven;
Handle g_Forward_OnItemEquip;
Handle g_Forward_OnItemEquipped;

/*****************************/
//Globals
Database g_Database;

enum struct Categories
{
	int id;
	char name[MAX_NAME_LENGTH];
	int admgroup;
	int max_equipped;
	bool hidden;

	void Reset()
	{
		this.id = -1;
		this.name[0] = '\0';
		this.admgroup = VH_NULLADMGRP;
		this.max_equipped = -1;
		this.hidden = false;
	}
}

Categories g_Categories[256];
int g_TotalCategories;

enum struct Items
{
	int id;
	int category;
	char name[MAX_NAME_LENGTH];
	int price;
	char data[2048];
	int maximum;
	int admgroup;
	bool hidden;

	void Reset()
	{
		this.id = -1;
		this.category = -1;
		this.name[0] = '\0';
		this.price = -1;
		this.data[0] = '\0';
		this.maximum = -1;
		this.admgroup = -1;
		this.hidden = false;
	}
}

Items g_Items[2048];
int g_TotalItems;

enum struct Player
{
	int client;
	int credits;
	ArrayList items;

	StringMap equips;
	StringMap equiptotals;

	void Init(int client)
	{
		this.client = client;
		this.credits = convar_StartingCredits.IntValue;
		this.items = new ArrayList();

		this.equips = new StringMap();
		this.equiptotals = new StringMap();
	}

	void Clear()
	{
		this.client = -1;
		this.credits = convar_StartingCredits.IntValue;
		delete this.items;

		delete this.equips;
		delete this.equiptotals;
	}

	int GetItemCount(int itemid)
	{
		int count;

		for (int i = 0; i < this.items.Length; i++)
			if (this.items.Get(i) == itemid)
				count++;

		return count;
	}

	void SetCredits(int value)
	{
		this.credits = value;
		
		if (this.credits < 0)
			this.credits = 0;

		this.SaveCredits();
	}

	void AddCredits(int value)
	{
		this.credits += value;
		this.SaveCredits();
	}

	bool RemoveCredits(int value, bool safe = true)
	{
		if (safe && this.credits < value)
			return false;
		
		this.credits -= value;

		if (this.credits < 0)
			this.credits = 0;
		
		this.SaveCredits();

		return true;
	}

	void SaveCredits()
	{
		char sQuery[256];
		g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `store_credits` SET credits = '%i' WHERE vid = '%i';", this.credits, VH_GetVertexID(this.client));
		g_Database.Query(onSaveCredits, sQuery);
	}

	bool PurchaseItem(int categoryid, int itemid)
	{
		int index = GetItemIndexById(itemid);

		if (this.credits < g_Items[index].price)
		{
			Vertex_SendPrint(this.client, "You don't have enough credits for this item.");
			return false;
		}

		if (g_Items[index].maximum != -1 && this.GetItemCount(g_Items[index].id) >= g_Items[index].maximum)
		{
			Vertex_SendPrint(this.client, "You already own the maximum amount of this item. (%i)", g_Items[index].maximum);
			return false;
		}

		Call_StartForward(g_Forward_OnItemPurchase);
		Call_PushCell(this.client);
		Call_PushCell(g_Items[index].category);
		Call_PushCell(g_Items[index].id);

		Action results = Plugin_Continue;
		Call_Finish(results);

		if (results != Plugin_Continue)
			return false;

		this.credits -= g_Items[index].price;
		this.SaveCredits();

		Vertex_SendPrint(this.client, "You have purchased the item [H]%s [D]for [H]%i [D]credits.", g_Items[index].name, g_Items[index].price);

		this.GiveItem(categoryid, itemid);

		Call_StartForward(g_Forward_OnItemPurchased);
		Call_PushCell(this.client);
		Call_PushCell(g_Items[index].category);
		Call_PushCell(g_Items[index].id);
		Call_Finish();

		return true;
	}

	bool GiveItem(int categoryid, int itemid, int giver = -1)
	{
		int index = GetItemIndexById(itemid);

		if (g_Items[index].maximum != -1 && this.GetItemCount(g_Items[index].id) >= g_Items[index].maximum)
		{
			Vertex_SendPrint(this.client, "You already own the maximum amount of this item. (%i)", g_Items[index].maximum);
			return;
		}

		Call_StartForward(g_Forward_OnItemGive);
		Call_PushCell(this.client);
		Call_PushCell(g_Items[index].category);
		Call_PushCell(g_Items[index].id);
		Call_PushCell(giver);
		
		Action results = Plugin_Continue;
		Call_Finish(results);

		if (results != Plugin_Continue)
			return;

		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(this.client));
		pack.WriteCell(itemid);
		pack.WriteCell(giver);

		char sQuery[256];
		g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `store_user_items` (vid, itemid) VALUES ('%i', '%i');", VH_GetVertexID(this.client), g_Items[index].id);
		g_Database.Query(onGiveItem, sQuery, pack);
	}

	bool IsEquipped(int categoryid, int itemid, int class = -1, int tf2item = -1)
	{
		char sIndex[16];
		IntToString(categoryid, sIndex, sizeof(sIndex));

		if (class != -1)
			Format(sIndex, sizeof(sIndex), "%s-%i", sIndex, class);

		if (tf2item != -1)
			Format(sIndex, sizeof(sIndex), "%s-%i", sIndex, tf2item);

		int total;
		this.equiptotals.GetValue(sIndex, total);

		int[] equipped = new int[total];
		this.equips.GetArray(sIndex, equipped, total);

		for (int i = 0; i < total; i++)
			if (equipped[i] == itemid)
				return true;
		
		return false;
	}

	bool GetEquippedByCategoryId(int categoryid, int[] itemids, int size, int class = -1, int tf2item = -1)
	{
		char sIndex[16];
		IntToString(categoryid, sIndex, sizeof(sIndex));

		int total;
		int count;

		if (this.equiptotals.GetValue(sIndex, total) && total > 0)
		{
			int[] equipped = new int[total];
			this.equips.GetArray(sIndex, equipped, total);

			for (int i = count; i < size; i++)
			{
				if (this.items.FindValue(equipped[i]) == -1)
				{
					this.UnequipItem(categoryid, equipped[i]);
					continue;
				}

				itemids[i] = equipped[i];
				count++;
			}
		}

		if (class != -1)
			Format(sIndex, sizeof(sIndex), "%s-%i", sIndex, class);
		
		if (this.equiptotals.GetValue(sIndex, total) && total > 0)
		{
			int[] equipped = new int[total];
			this.equips.GetArray(sIndex, equipped, total);

			for (int i = count; i < size; i++)
			{
				if (this.items.FindValue(equipped[i]) == -1)
				{
					this.UnequipItem(categoryid, equipped[i]);
					continue;
				}

				itemids[i] = equipped[i];
				count++;
			}
		}

		if (tf2item != -1)
			Format(sIndex, sizeof(sIndex), "%s-%i", sIndex, tf2item);
		
		if (this.equiptotals.GetValue(sIndex, total) && total > 0)
		{
			int[] equipped = new int[total];
			this.equips.GetArray(sIndex, equipped, total);

			for (int i = count; i < size; i++)
			{
				if (this.items.FindValue(equipped[i]) == -1)
				{
					this.UnequipItem(categoryid, equipped[i]);
					continue;
				}

				itemids[i] = equipped[i];
				count++;
			}
		}

		return true;
	}

	int GetEquippedTotal(int categoryid, int class = -1, int tf2item = -1)
	{
		char sIndex[16];
		IntToString(categoryid, sIndex, sizeof(sIndex));

		if (class != -1)
			Format(sIndex, sizeof(sIndex), "%s-%i", sIndex, class);

		if (tf2item != -1)
			Format(sIndex, sizeof(sIndex), "%s-%i", sIndex, tf2item);

		int total;
		this.equiptotals.GetValue(sIndex, total);

		return total;
	}

	bool EquipItem(int categoryid, int itemid, int class = -1, int tf2item = -1, bool save = true, bool verbose = true)
	{
		if (this.items.FindValue(itemid) == -1)
		{
			Vertex_SendPrint(this.client, "You cannot equip this item, you don't own it.");
			return false;
		}
		
		int current = this.GetEquippedTotal(categoryid, class, tf2item);
		int index = GetCategoryIndexById(categoryid);
		int max = g_Categories[index].max_equipped;

		if (max != -1 && current >= max)
		{
			Vertex_SendPrint(this.client, "You cannot equip more than [H]%i [D]of the category: [H]%s", max, g_Categories[index].name);
			return false;
		}
		
		Call_StartForward(g_Forward_OnItemEquip);
		Call_PushCell(this.client);
		Call_PushCell(categoryid);
		Call_PushCell(itemid);
		Call_PushCell(save);

		Action result = Plugin_Continue;
		Call_Finish(result);

		if (result != Plugin_Continue)
			return false;

		char sIndex[16];
		IntToString(categoryid, sIndex, sizeof(sIndex));

		if (class != -1)
			Format(sIndex, sizeof(sIndex), "%s-%i", sIndex, class);

		if (tf2item != -1)
			Format(sIndex, sizeof(sIndex), "%s-%i", sIndex, tf2item);

		int total;
		this.equiptotals.GetValue(sIndex, total);

		int[] equipped = new int[total + 1];
		this.equips.GetArray(sIndex, equipped, total);

		equipped[total++] = itemid;

		this.equiptotals.SetValue(sIndex, total);
		this.equips.SetArray(sIndex, equipped, total);

		if (verbose)
		{
			int index2 = GetItemIndexById(itemid);
			Vertex_SendPrint(this.client, "You have equipped the item [H]%s [D]in the category [H]%s[D].", g_Items[index2].name, g_Categories[index].name);
		}

		if (save)
			this.SaveEquippedState(categoryid, class, tf2item);
		
		Call_StartForward(g_Forward_OnItemEquipped);
		Call_PushCell(this.client);
		Call_PushCell(categoryid);
		Call_PushCell(itemid);
		Call_PushCell(save);
		Call_Finish();

		return true;
	}

	bool UnequipItem(int categoryid, int itemid, int class = -1, int tf2item = -1, bool save = true, bool verbose = true)
	{
		char sIndex[16];
		IntToString(categoryid, sIndex, sizeof(sIndex));

		if (class != -1)
			Format(sIndex, sizeof(sIndex), "%s-%i", sIndex, class);

		if (tf2item != -1)
			Format(sIndex, sizeof(sIndex), "%s-%i", sIndex, tf2item);

		int total;
		this.equiptotals.GetValue(sIndex, total);

		int[] equipped = new int[total + 1];
		this.equips.GetArray(sIndex, equipped, total);

		int[] equipped2 = new int[total + 1];
		int total2;

		for (int i = 0; i < total; i++)
			if (equipped[i] != itemid)
				equipped2[total2++] = equipped[i];

		this.equiptotals.SetValue(sIndex, total2);
		this.equips.SetArray(sIndex, equipped2, total2);

		if (verbose)
		{
			int index = GetCategoryIndexById(categoryid);
			int index2 = GetItemIndexById(itemid);
			Vertex_SendPrint(this.client, "You have unequipped the item [H]%s [D]in the category [H]%s[D].", g_Items[index2].name, g_Categories[index].name);
		}

		if (save)
			this.SaveEquippedState(categoryid, class, tf2item);
		
		return true;
	}

	bool SaveEquippedState(int categoryid, int class = -1, int tf2item = -1)
	{
		char sIndex[16];
		IntToString(categoryid, sIndex, sizeof(sIndex));

		if (class != -1)
			Format(sIndex, sizeof(sIndex), "%s-%i", sIndex, class);

		if (tf2item != -1)
			Format(sIndex, sizeof(sIndex), "%s-%i", sIndex, tf2item);

		int total;
		this.equiptotals.GetValue(sIndex, total);

		int[] equipped = new int[total + 1];
		this.equips.GetArray(sIndex, equipped, total);

		char sItems[512];
		for (int item = 0; item < total; item++)
		{
			if (item == 0)
				FormatEx(sItems, sizeof(sItems), "%i", equipped[item]);
			else
				Format(sItems, sizeof(sItems), "%s;%i", sItems, equipped[item]);
		}

		char sQuery[256];
		g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `store_equipped` (vid, category, class, item, items) VALUES ('%i', '%i', '%i', '%i', '%s') ON DUPLICATE KEY UPDATE items = '%s';", VH_GetVertexID(this.client), categoryid, class, tf2item, sItems, sItems);
		g_Database.Query(onSaveEquipped, sQuery);

		return true;
	}
}

Player g_Player[MAXPLAYERS + 1];

public void onSaveCredits(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while saving credits: %s", error);
}

public void onGiveItem(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();

	int userid = pack.ReadCell();
	int itemid = pack.ReadCell();
	int giver = pack.ReadCell();

	delete pack;

	if (results == null)
		ThrowError("Error while giving item: %s", error);
	
	int client;
	if ((client = GetClientOfUserId(userid)) == 0)
		return;
	
	int index = GetItemIndexById(itemid);
	
	if (giver != -1)
	{
		Vertex_SendPrint(client, "You were given the item [H]%s [D]from [H]%N[D].", g_Items[index].name, giver);
		Vertex_SendPrint(giver, "You have given the item [H]%s [D]to [H]%N[D].", g_Items[index].name, client);
	}

	g_Player[client].items.Push(g_Items[index].id);
	Vertex_SendPrint(client, "You have gained the item: [H]%s", g_Items[index].name);

	Call_StartForward(g_Forward_OnItemGiven);
	Call_PushCell(client);
	Call_PushCell(g_Items[index].category);
	Call_PushCell(g_Items[index].id);
	Call_PushCell(giver);
	Call_Finish();
}

public void onSaveEquipped(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while saving equipped: %s", error);
}

int g_TotalMarketItems;
enum struct Marketplace
{
	char name[64];
	int credits;
	int available;

	void Init()
	{
		this.name[0] = '\0';
		this.credits = 0;
		this.available = 0;
	}

	void AddMarketplaceItem(const char[] name, int credits, int available)
	{
		strcopy(this.name, 64, name);
		this.credits = credits;
		this.available = available;
		g_TotalMarketItems++;
	}
}

Marketplace g_Marketplace[256];

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
	RegPluginLibrary("vh-store");

	CreateNative("VH_GetCredits", Native_GetCredits);
	CreateNative("VH_SetCredits", Native_SetCredits);
	CreateNative("VH_AddCredits", Native_AddCredits);
	CreateNative("VH_RemoveCredits", Native_RemoveCredits);
	CreateNative("VH_PurchaseItem", Native_PurchaseItem);
	CreateNative("VH_GiveItem", Native_GiveItem);
	CreateNative("VH_OpenStoreMenu", Native_OpenStoreMenu);
	CreateNative("VH_OpenShopMenu", Native_OpenShopMenu);
	CreateNative("VH_OpenInventoryMenu", Native_OpenInventoryMenu);

	CreateNative("VH_GetEquipped", Native_GetEquipped);
	CreateNative("VH_GetItemData", Native_GetItemData);

	g_Forward_OnItemPurchase = CreateGlobalForward("VH_OnItemPurchase", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	g_Forward_OnItemPurchased = CreateGlobalForward("VH_OnItemPurchased", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_Forward_OnItemGive = CreateGlobalForward("VH_OnItemGive", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_Forward_OnItemGiven = CreateGlobalForward("VH_OnItemGiven", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_Forward_OnItemEquip = CreateGlobalForward("VH_OnItemEquip", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_Forward_OnItemEquipped = CreateGlobalForward("VH_OnItemEquipped", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

	return APLRes_Success;
}

public int Native_GetEquipped(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	int size;
	GetNativeStringLength(2, size); size++;

	char[] sCategory = new char[size];
	GetNativeString(2, sCategory, size);

	int index = GetNativeCell(3);

	int class = GetEntProp(client, Prop_Send, "m_iClass");

	int wepindex = -1; int weapon = -1;
	if ((weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")) != -1)
		wepindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

	int id = GetCategoryByName(sCategory);
	int category = GetCategoryIndexById(id);
	int max = g_Categories[category].max_equipped;

	int[] equipped = new int[max];
	g_Player[client].GetEquippedByCategoryId(id, equipped, max, class, wepindex);
	
	if (equipped[index] == -1)
		return false;
	
	int item = -1;
	if ((item = GetItemIndexById(equipped[index])) == -1)
		return false;
	
	SetNativeString(4, g_Items[item].name, GetNativeCell(5));
	return true;
}

public int Native_GetItemData(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size); size++;

	char[] sItem = new char[size];
	GetNativeString(1, sItem, size);

	for (int i = 0; i < g_TotalItems; i++)
	{
		if (!StrEqual(sItem, g_Items[i].name, false))
			continue;
		
		SetNativeString(2, g_Items[i].data, GetNativeCell(3));
		return true;
	}

	return false;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	Database.Connect(onSQLConnect, "default");

	convar_Shop = CreateConVar("sm_vertexheights_store_shop", "1");
	convar_Inventory = CreateConVar("sm_vertexheights_store_inventory", "1");
	convar_StartingCredits = CreateConVar("sm_vertexheights_store_starting_credits", "200");

	RegConsoleCmd("sm_store", Command_Store, "Open the store menu to access store features.");
	RegConsoleCmd("sm_shop", Command_Shop, "Access the items shop to purchase new items.");
	RegConsoleCmd("sm_inventory", Command_Inventory, "Access your inventory to equip, refund, sell, gift and auction items.");
	RegConsoleCmd("sm_loadouts", Command_Loadouts, "Create loadouts for items to equip and unequip multiple items at once.");
	RegConsoleCmd("sm_marketplace", Command_Marketplace, "Access and purchase available TF2 marketplace items.");
	RegConsoleCmd("sm_credits", Command_Credits, "Displays your credits or a targets credits in chat.");

	RegAdminCmd("sm_setcredits", Command_SetCredits, ADMFLAG_ROOT);
	RegAdminCmd("sm_addcredits", Command_AddCredits, ADMFLAG_ROOT);
	RegAdminCmd("sm_removecredits", Command_RemoveCredits, ADMFLAG_ROOT);

	RegAdminCmd("sm_giveitem", Command_GiveItem, ADMFLAG_ROOT);

	RegAdminCmd("sm_reloadcategories", Command_ReloadCategories, ADMFLAG_ROOT);
	RegAdminCmd("sm_reloaditems", Command_ReloadItems, ADMFLAG_ROOT);
	RegAdminCmd("sm_reloadmarketplace", Command_ReloadMarketplace, ADMFLAG_ROOT);

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i))
			OnClientConnected(i);
	
	CreateTimer(300.0, Timer_GiveCredits, _, TIMER_REPEAT);
	CreateTimer(3600.0, Timer_ParseMarketplace, _, TIMER_REPEAT);
}

public Action Timer_GiveCredits(Handle timer)
{
	int credits; bool ingroup;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) < 2)
			continue;
		
		credits = GetRandomInt(4, 6) + ((VH_GetAdmGroup(i) != VH_NULLADMGRP) ? 2 : 0);

		if (VH_IsInSteamGroup(i))
		{
			credits += 2;
			ingroup = true;
		}
		
		g_Player[i].AddCredits(credits);
		Vertex_SendPrint(i, "You have gained [H]%i [D]credits for playing on the server.%s", credits, ingroup ? " (+2 for being in Steamgroup)" : "");
	}
}

public void VH_OnVIPFeatures(int client, Panel panel)
{
	panel.DrawText(" * Extra Credits Gained");
}

public void onSQLConnect(Database db, const char[] error, any data)
{
	if (db == null)
		ThrowError("Error while connecting to database: %s", error);
	
	if (g_Database != null)
	{
		delete db;
		return;
	}

	g_Database = db;

	ParseCategories();
	ParseItems();
	ParseMarketplaceItems();

	for (int i = 1; i <= MaxClients; i++)
		if (VH_GetVertexID(i) != VH_NULLID)
			VH_OnSynced(i, VH_GetVertexID(i));
}

void ParseCategories()
{
	g_Database.Query(onParseCategories, "SELECT * FROM `store_categories` WHERE hidden = 0;");
}

public void onParseCategories(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while parsing shop categories: %s", error);
	
	for (int i = 0; i < g_TotalCategories; i++)
		g_Categories[i].Reset();
	g_TotalCategories = 0;
	
	while (results.FetchRow())
	{
		g_Categories[g_TotalCategories].id = results.FetchInt(0);
		results.FetchString(1, g_Categories[g_TotalCategories].name, sizeof(g_Categories[].name));
		g_Categories[g_TotalCategories].admgroup = results.FetchInt(2);
		g_Categories[g_TotalCategories].max_equipped = results.FetchInt(3);
		g_Categories[g_TotalCategories].hidden = view_as<bool>(results.FetchInt(4));

		g_TotalCategories++;
	}

	Vertex_SendPrintToAll("%i categories are now available.", g_TotalCategories);
}

void ParseItems()
{
	g_Database.Query(onParseItems, "SELECT * FROM `store_items` WHERE hidden = 0;");
}

public void onParseItems(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while parsing shop items: %s", error);
	
	for (int i = 0; i < g_TotalItems; i++)
		g_Items[i].Reset();
	g_TotalItems = 0;
	
	while (results.FetchRow())
	{
		g_Items[g_TotalItems].id = results.FetchInt(0);
		g_Items[g_TotalItems].category = results.FetchInt(1);
		results.FetchString(2, g_Items[g_TotalItems].name, sizeof(g_Items[].name));
		g_Items[g_TotalItems].price = results.FetchInt(3);
		results.FetchString(4, g_Items[g_TotalItems].data, sizeof(g_Items[].data));
		g_Items[g_TotalItems].maximum = results.FetchInt(5);
		g_Items[g_TotalItems].admgroup = results.FetchInt(6);
		g_Items[g_TotalItems].hidden = view_as<bool>(results.FetchInt(7));

		g_TotalItems++;
	}

	Vertex_SendPrintToAll("%i items are now available.", g_TotalItems);
}

public void OnClientConnected(int client)
{
	g_Player[client].Init(client);
}

public void VH_OnSynced(int client, int vid)
{
	char sQuery[256];

	g_Database.Format(sQuery, sizeof(sQuery), "SELECT credits FROM `store_credits` WHERE vid = '%i';", vid);
	g_Database.Query(onParseCredits, sQuery, GetClientUserId(client));

	g_Database.Format(sQuery, sizeof(sQuery), "SELECT itemid FROM `store_user_items` WHERE vid = '%i';", vid);
	g_Database.Query(onParseUserItems, sQuery, GetClientUserId(client));

	g_Database.Format(sQuery, sizeof(sQuery), "SELECT category, class, item, items FROM `store_equipped` WHERE vid = '%i';", vid);
	g_Database.Query(onParseEquipped, sQuery, GetClientUserId(client));
}

public void onParseCredits(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while parsing credits: %s", error);
	
	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return;
	
	if (results.FetchRow())
	{
		g_Player[client].credits = results.FetchInt(0);
		return;
	}

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `store_credits` (vid, credits) VALUES ('%i', '%i');", VH_GetVertexID(client), convar_StartingCredits.IntValue);
	g_Database.Query(onSetupCredits, sQuery, GetClientUserId(client));
}

public void onSetupCredits(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while setting up credits: %s", error);
}

public void onParseUserItems(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while parsing user items: %s", error);
	
	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return;
	
	while (results.FetchRow())
		g_Player[client].items.Push(results.FetchInt(0));
}

public void onParseEquipped(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while parsing user equipped data: %s", error);
	
	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return;
	
	int category; int class; int item; char sItems[512]; char sPart[2048][16]; int found;
	while (results.FetchRow())
	{
		category = results.FetchInt(0);
		class = results.FetchInt(1);
		item = results.FetchInt(2);
		results.FetchString(3, sItems, sizeof(sItems));

		found = ExplodeString(sItems, ";", sPart, 2048, 16);

		for (int i = 0; i < found; i++)
			g_Player[client].EquipItem(category, StringToInt(sPart[i]), class, item, false, false);
	}
}

public void OnClientDisconnect(int client)
{
	g_Player[client].SaveCredits();
}

public void OnClientDisconnect_Post(int client)
{
	g_Player[client].Clear();
}

public Action Command_Store(int client, int args)
{
	OpenStoreMenu(client);
	return Plugin_Handled;
}

void OpenStoreMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Store);
	menu.SetTitle("::Vertex Heights :: Store Menu\n::Credits: %i", g_Player[client].credits);

	menu.AddItem("shop", "Purchase Items");
	menu.AddItem("inv", "Access your Inventory");
	menu.AddItem("load", "Manage your Loadouts");
	menu.AddItem("market", "Access Available Marketplace Items");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Store(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "shop"))
			{
				if (!OpenShopMenu(param1))
					OpenStoreMenu(param1);
			}
			else if (StrEqual(sInfo, "inv"))
			{
				if (!OpenInventoryMenu(param1))
					OpenStoreMenu(param1);
			}
			else if (StrEqual(sInfo, "load"))
			{
				if (!OpenLoadoutsMenu(param1))
					OpenStoreMenu(param1);
			}
			else if (StrEqual(sInfo, "market"))
			{
				if (!OpenMarketplaceMenu(param1))
					OpenStoreMenu(param1);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public Action Command_Shop(int client, int args)
{
	OpenShopMenu(client);
	return Plugin_Handled;
}

bool OpenShopMenu(int client)
{
	if (!convar_Shop.BoolValue)
	{
		Vertex_SendPrint(client, "[H]Shop [D]is currently {red}CLOSED[D], please come back later.");
		return false;
	}

	Menu menu = new Menu(MenuHandler_Shop);
	menu.SetTitle("::Vertex Heights :: Shop for Items\n::Credits: %i", g_Player[client].credits);

	menu.AddItem("category", "Pick a Category");
	menu.AddItem("items", "View all Items");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	Vertex_SendPrint(client, "[H]Shop [D]is currently {green}OPEN[D], enjoy your browsing.");
	return true;
}

public int MenuHandler_Shop(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "category"))
				OpenCategoriesMenu(param1, TYPE_SHOP);
			else if (StrEqual(sInfo, "items"))
				OpenItemsMenu(param1, TYPE_SHOP, -1, false);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenStoreMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

public Action Command_Inventory(int client, int args)
{
	OpenInventoryMenu(client);
	return Plugin_Handled;
}

bool OpenInventoryMenu(int client)
{
	if (!convar_Inventory.BoolValue)
	{
		Vertex_SendPrint(client, "[H]Inventory [D]is currently {red}LOCKED[D].");
		return false;
	}

	Menu menu = new Menu(MenuHandler_Inventory);
	menu.SetTitle("::Vertex Heights :: Your Inventory\n::Credits: %i", g_Player[client].credits);

	menu.AddItem("category", "Pick a Category");
	menu.AddItem("all", "Access all Items");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return true;
}

public int MenuHandler_Inventory(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "category"))
				OpenCategoriesMenu(param1, TYPE_INV);
			else if (StrEqual(sInfo, "all"))
				OpenItemsMenu(param1, TYPE_INV, -1, true);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenStoreMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

void OpenCategoriesMenu(int client, int type)
{
	Menu menu = new Menu(MenuHandler_Categories);
	menu.SetTitle("::Vertex Heights :: Pick a category:\n::Credits: %i", g_Player[client].credits);

	char sID[16];
	for (int i = 0; i < g_TotalCategories; i++)
	{
		IntToString(i, sID, sizeof(sID));
		menu.AddItem(sID, g_Categories[i].name);
	}

	PushMenuInt(menu, "type", type);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Categories(Menu menu, MenuAction action, int param1, int param2)
{
	int type = GetMenuInt(menu, "type");

	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[16];
			menu.GetItem(param2, sID, sizeof(sID));
			
			int index = StringToInt(sID);

			switch (type)
			{
				case TYPE_SHOP:
					OpenItemsMenu(param1, type, index, (type == TYPE_INV));
				case TYPE_INV:
					OpenItemsMenu(param1, type, index, (type == TYPE_INV));
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				switch (type)
				{
					case TYPE_SHOP:
						OpenShopMenu(param1);
					case TYPE_INV:
						OpenInventoryMenu(param1);
				}
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

void OpenItemsMenu(int client, int type, int category = -1, bool show_owned = false, int give_target = -1)
{
	Menu menu = new Menu(MenuHandler_Items);

	if (give_target != -1)
		menu.SetTitle("::Vertex Heights :: Pick an item:\n::Credits: %i", g_Player[client].credits);
	else
		menu.SetTitle("::Vertex Heights :: Pick an item:");

	char sID[16]; char sDisplay[128]; char sEquipped[12];
	for (int i = 0; i < g_TotalItems; i++)
	{
		if (category != -1 && g_Items[i].category != g_Categories[category].id)
			continue;
		
		if (show_owned && g_Player[client].items.FindValue(g_Items[i].id) == -1)
			continue;
		
		if (show_owned && g_Player[client].IsEquipped(g_Items[i].category, g_Items[i].id))
			strcopy(sEquipped, sizeof(sEquipped), " (E)");
		else
			sEquipped[0] = '\0';
		
		IntToString(i, sID, sizeof(sID));
		FormatEx(sDisplay, sizeof(sDisplay), "%s (%s)%s", g_Items[i].name, g_Categories[GetCategoryIndexById(g_Items[i].category)].name, sEquipped);
		menu.AddItem(sID, sDisplay);
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", " :: No Items Found", ITEMDRAW_DISABLED);

	PushMenuInt(menu, "type", type);
	PushMenuInt(menu, "category", category);
	PushMenuBool(menu, "show_owned", show_owned);
	PushMenuInt(menu, "give_target", give_target);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Items(Menu menu, MenuAction action, int param1, int param2)
{
	int type = GetMenuInt(menu, "type");
	int category = GetMenuInt(menu, "category");
	bool show_owned = GetMenuBool(menu, "show_owned");
	int give_target = GetMenuInt(menu, "give_target");

	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[16];
			menu.GetItem(param2, sID, sizeof(sID));

			int index = StringToInt(sID);

			if (give_target != -1)
				g_Player[give_target].GiveItem(g_Items[index].category, g_Items[index].id, param1);
			else
				OpenItemMenu(param1, type, category, index, show_owned);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenCategoriesMenu(param1, type);
		case MenuAction_End:
			delete menu;
	}
}

void OpenItemMenu(int client, int type, int category, int item, bool show_owned)
{
	if (category == -1)
		category = GetCategoryIndexById(g_Items[item].category);
	
	char sAppend[256]; bool equipped;
	Format(sAppend, sizeof(sAppend), "%s\nCategory: %s", sAppend, g_Categories[category].name);
	
	switch (type)
	{
		case TYPE_SHOP:
		{
			Format(sAppend, sizeof(sAppend), "%s\nPrice: %i", sAppend, g_Items[item].price);
		}
		case TYPE_INV:
		{
			equipped = g_Player[client].IsEquipped(g_Items[item].category, g_Items[item].id);
			Format(sAppend, sizeof(sAppend), "%s\nEquipped: %s", sAppend, equipped ? "Yes" : "No");
		}
	}

	char sMaximum[32];
	if (g_Items[item].maximum != -1)
		FormatEx(sMaximum, sizeof(sMaximum), " / %i", g_Items[item].maximum);
	
	Format(sAppend, sizeof(sAppend), "%s\nAmount: %i%s", sAppend, g_Player[client].GetItemCount(g_Items[item].id), sMaximum);
	Format(sAppend, sizeof(sAppend), "%s\n ", sAppend);

	Menu menu = new Menu(MenuHandler_Item);
	menu.SetTitle("::Vertex Heights :: Item: %s:\n::Credits: %i\n \n%s", g_Items[item].name, g_Player[client].credits, sAppend);

	switch (type)
	{
		case TYPE_SHOP:
		{
			int draw = ITEMDRAW_DEFAULT;

			if (g_Player[client].credits < g_Items[item].price)
				draw = ITEMDRAW_DISABLED;

			if (g_Items[item].maximum != -1 && g_Player[client].GetItemCount(g_Items[item].id) >= g_Items[item].maximum)
				draw = ITEMDRAW_DISABLED;
			
			menu.AddItem("purchase", "Purchase Item", draw);

			if (g_Player[client].GetItemCount(g_Items[item].id) > 0)
				menu.AddItem("inventory", "Access in your Inventory");
		}
		case TYPE_INV:
		{
			if (equipped)
				menu.AddItem("unequip", "Unequip Item");
			else
				menu.AddItem("equip", "Equip Item");
			
			menu.AddItem("equipclass", "Equip to a Class");
			menu.AddItem("equipweapon", "Equip to a Weapon");
		}
	}

	PushMenuInt(menu, "type", type);
	PushMenuInt(menu, "category", category);
	PushMenuInt(menu, "item", item);
	PushMenuBool(menu, "show_owned", show_owned);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Item(Menu menu, MenuAction action, int param1, int param2)
{
	int type = GetMenuInt(menu, "type");
	int category = GetMenuInt(menu, "category");
	int item = GetMenuInt(menu, "item");
	bool show_owned = GetMenuBool(menu, "show_owned");

	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "purchase"))
			{
				g_Player[param1].PurchaseItem(g_Items[item].category, g_Items[item].id);
				OpenItemsMenu(param1, type, category = -1, show_owned);
			}
			else if (StrEqual(sInfo, "inventory"))
			{
				OpenItemMenu(param1, TYPE_INV, category, item, show_owned);
			}
			else if (StrEqual(sInfo, "equip"))
			{
				g_Player[param1].EquipItem(g_Items[item].category, g_Items[item].id);
				OpenItemMenu(param1, type, category, item, show_owned);
			}
			else if (StrEqual(sInfo, "unequip"))
			{
				g_Player[param1].UnequipItem(g_Items[item].category, g_Items[item].id);
				OpenItemMenu(param1, type, category, item, show_owned);
			}
			else if (StrEqual(sInfo, "equipclass"))
			{
				OpenClassesMenu(param1, category, item);
			}
			else if (StrEqual(sInfo, "equipweapon"))
			{
				OpenWeaponMenu(param1, category, item);
			}
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenItemsMenu(param1, type, category, show_owned);
		case MenuAction_End:
			delete menu;
	}
}

void OpenClassesMenu(int client, int category, int item)
{
	Menu menu = new Menu(MenuHandler_Classes);
	menu.SetTitle("::Vertex Heights :: Item: %s\nPick a Class:\n \n", g_Items[item].name);
	
	menu.AddItem("1", "Scout");
	menu.AddItem("3", "Soldier");
	menu.AddItem("7", "Pyro");
	menu.AddItem("4", "DemoMan");
	menu.AddItem("6", "Heavy");
	menu.AddItem("9", "Engineer");
	menu.AddItem("5", "Medic");
	menu.AddItem("2", "Sniper");
	menu.AddItem("8", "Spy");

	PushMenuInt(menu, "category", category);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Classes(Menu menu, MenuAction action, int param1, int param2)
{
	int type = GetMenuInt(menu, "type");
	int category = GetMenuInt(menu, "category");
	int item = GetMenuInt(menu, "item");
	bool show_owned = GetMenuBool(menu, "show_owned");

	switch (action)
	{
		case MenuAction_Select:
		{
			char sClass[16];
			menu.GetItem(param2, sClass, sizeof(sClass));
			int class = StringToInt(sClass);

			g_Player[param1].EquipItem(g_Items[item].category, g_Items[item].id, class);
			OpenItemMenu(param1, type, category, item, show_owned);
		}
		case MenuAction_End:
			delete menu;
	}
}

void OpenWeaponMenu(int client, int category, int item)
{
	Menu menu = new Menu(MenuHandler_Weapons);
	menu.SetTitle("::Vertex Heights :: Item: %s\nPick a Weapon:\n \n", g_Items[item].name);

	int weapon; int wepindex; char sWepIndex[16]; char sName[64];
	for (int i = 0; i < 8; i++)
	{
		if ((weapon = GetPlayerWeaponSlot(client, i)) == -1)
			continue;
		
		wepindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		
		IntToString(wepindex, sWepIndex, sizeof(sWepIndex));
		TF2_GetWeaponNameFromIndex(wepindex, sName, sizeof(sName));

		menu.AddItem(sWepIndex, sName);
	}

	PushMenuInt(menu, "category", category);

	PushMenuInt(menu, "class", GetEntProp(client, Prop_Send, "m_iClass"));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Weapons(Menu menu, MenuAction action, int param1, int param2)
{
	int type = GetMenuInt(menu, "type");
	int category = GetMenuInt(menu, "category");
	int item = GetMenuInt(menu, "item");
	bool show_owned = GetMenuBool(menu, "show_owned");

	switch (action)
	{
		case MenuAction_Select:
		{
			char sWepIndex[16];
			menu.GetItem(param2, sWepIndex, sizeof(sWepIndex));
			
			int wepindex = StringToInt(sWepIndex);
			int class = GetMenuInt(menu, "class");
			
			g_Player[param1].EquipItem(g_Items[item].category, g_Items[item].id, class, wepindex);
			OpenItemMenu(param1, type, category, item, show_owned);
		}
		case MenuAction_End:
			delete menu;
	}
}

public Action Command_ReloadCategories(int client, int args)
{
	ParseCategories();
	Vertex_SendPrint(client, "Store categories have been synced.");
	return Plugin_Handled;
}

public Action Command_ReloadItems(int client, int args)
{
	ParseItems();
	Vertex_SendPrint(client, "Store items have been synced.");
	return Plugin_Handled;
}

public int Native_PurchaseItem(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int item = GetNativeCell(2);

	int index = GetItemIndexById(item);

	return g_Player[client].PurchaseItem(g_Items[index].category, g_Items[index].id);
}

public int Native_GiveItem(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int item = GetNativeCell(2);
	int giver = GetNativeCell(3);

	int index = GetItemIndexById(item);

	g_Player[client].GiveItem(g_Items[index].category, g_Items[index].id, giver);
}

public Action Command_GiveItem(int client, int args)
{
	OpenPlayersMenu(client, TYPE_GIVE);
	return Plugin_Handled;
}

void OpenPlayersMenu(int client, int type)
{
	Menu menu = new Menu(MenuHandler_Players);
	menu.SetTitle("::Vertex Heights :: Pick a player:");

	char sID[32]; char sName[MAX_NAME_LENGTH];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		IntToString(GetClientUserId(i), sID, sizeof(sID));
		GetClientName(i, sName, sizeof(sName));
		menu.AddItem(sID, sName);
	}

	PushMenuInt(menu, "type", type);

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Players(Menu menu, MenuAction action, int param1, int param2)
{
	int type = GetMenuInt(menu, "type");

	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[32];
			menu.GetItem(param2, sID, sizeof(sID));
			int target = GetClientOfUserId(StringToInt(sID));

			if (target == -1)
			{
				Vertex_SendPrint(param1, "Target is no longer available.");
				OpenPlayersMenu(param1, type);
				return;
			}

			OpenItemsMenu(param1, type, -1, false, target);
		}
		case MenuAction_End:
			delete menu;
	}
}

int GetCategoryByName(const char[] name)
{
	for (int i = 0; i < g_TotalCategories; i++)
		if (StrEqual(g_Categories[i].name, name, false))
			return g_Categories[i].id;
	
	return -1;
}

int GetCategoryIndexById(int id)
{
	for (int i = 0; i < g_TotalCategories; i++)
		if (g_Categories[i].id == id)
			return i;
	
	return -1;
}

stock int GetItemByName(const char[] name)
{
	for (int i = 0; i < g_TotalItems; i++)
		if (StrEqual(g_Items[i].name, name, false))
			return g_Items[i].id;
	
	return -1;
}

int GetItemIndexById(int id)
{
	for (int i = 0; i < g_TotalItems; i++)
		if (g_Items[i].id == id)
			return i;
	
	return -1;
}

public int Native_GetCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_Player[client].credits;
}

public int Native_SetCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int value = GetNativeCell(2);

	g_Player[client].SetCredits(value);
}

public Action Command_SetCredits(int client, int args)
{
	if (args != 2)
	{
		char sCommand[32];
		GetCommandName(sCommand, sizeof(sCommand));
		Vertex_SendPrint(client, "Usage: %s <target> <value>", sCommand);
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0)
	{
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	int value = GetCmdArgInt(2);

	if (value < 0)
	{
		Vertex_SendPrint(client, "Value must be more than -1.");
		return Plugin_Handled;
	}

	for (int i = 0; i < targets; i++)
	{
		g_Player[targets_list[i]].SetCredits(value);
		Vertex_SendPrint(targets_list[i], "Your credits have been set to [H]%i [D]by [H]%N[D].", value, client);
	}
	
	if (tn_is_ml)
		Vertex_SendPrint(client, "You have set [H]%t[D]'s credits to [H]%i[D].", sTargetName, value);
	else
		Vertex_SendPrint(client, "You have set [H]%s[D]'s credits to [H]%i[D].", sTargetName, value);

	return Plugin_Handled;
}

public int Native_AddCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int value = GetNativeCell(2);

	g_Player[client].AddCredits(value);
}

public Action Command_AddCredits(int client, int args)
{
	if (args != 2)
	{
		char sCommand[32];
		GetCommandName(sCommand, sizeof(sCommand));
		Vertex_SendPrint(client, "Usage: %s <target> <value>", sCommand);
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0)
	{
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	int value = GetCmdArgInt(2);

	if (value < 0)
	{
		Vertex_SendPrint(client, "Value must be more than -1.");
		return Plugin_Handled;
	}

	for (int i = 0; i < targets; i++)
	{
		g_Player[targets_list[i]].AddCredits(value);
		Vertex_SendPrint(targets_list[i], "You have gained [H]%i [D]credits from [H]%N[D].", value, client);
	}
	
	if (tn_is_ml)
		Vertex_SendPrint(client, "You have given [H]%i[D] credits to [H]%t[D].", value, sTargetName);
	else
		Vertex_SendPrint(client, "You have given [H]%i[D] credits to [H]%s[D].", value, sTargetName);

	return Plugin_Handled;
}

public int Native_RemoveCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int value = GetNativeCell(2);
	bool safe = GetNativeCell(3);

	return g_Player[client].RemoveCredits(value, safe);
}

public Action Command_RemoveCredits(int client, int args)
{
	if (args != 2)
	{
		char sCommand[32];
		GetCommandName(sCommand, sizeof(sCommand));
		Vertex_SendPrint(client, "Usage: %s <target> <value>", sCommand);
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int targets_list[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int targets = ProcessTargetString(sTarget, client, targets_list, sizeof(targets_list), COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (targets <= 0)
	{
		ReplyToTargetError(client, COMMAND_TARGET_NONE);
		return Plugin_Handled;
	}

	int value = GetCmdArgInt(2);

	if (value < 0)
	{
		Vertex_SendPrint(client, "Value must be more than -1.");
		return Plugin_Handled;
	}

	for (int i = 0; i < targets; i++)
	{
		g_Player[targets_list[i]].RemoveCredits(value, false);
		Vertex_SendPrint(targets_list[i], "[H]%N [D]has removed [H]%i [D]credits from you.", client, value);
	}
	
	if (tn_is_ml)
		Vertex_SendPrint(client, "You have removed [H]%i[D] credits from [H]%t[D].", value, sTargetName);
	else
		Vertex_SendPrint(client, "You have removed [H]%i[D] credits from [H]%s[D].", value, sTargetName);

	return Plugin_Handled;
}

public Action Command_Credits(int client, int args)
{
	int target = client;

	if (args > 0)
		target = GetCmdArgTarget(client, 1, true, false);
	
	if (target == -1)
	{
		Vertex_SendPrint(client, "Target not found, please try again.");
		return Plugin_Handled;
	}

	if (client == target)
		Vertex_SendPrint(client, "You have [H]%i [D]credits available in the store.", g_Player[target].credits);
	else
		Vertex_SendPrint(client, "[H]%N [D]has [H]%i [D]credits available in the store.", target, g_Player[target].credits);
	
	return Plugin_Handled;
}

public int Native_OpenStoreMenu(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	OpenStoreMenu(client);
}

public int Native_OpenShopMenu(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	OpenShopMenu(client);
}

public int Native_OpenInventoryMenu(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	OpenInventoryMenu(client);
}

public void TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int itemDefinitionIndex, int itemLevel, int itemQuality, int entityIndex)
{

}

void TF2_GetWeaponNameFromIndex(int index, char[] buffer, int size)
{
	switch (index)
	{
		//Misc
		case 154: strcopy(buffer, size, "The Pain Train");
		case 160: strcopy(buffer, size, "Vintage Lugermorph");
		case 199: strcopy(buffer, size, "Shotgun (Renamed/Strange)");
		case 209: strcopy(buffer, size, "Pistol (Renamed/Strange)");
		case 264: strcopy(buffer, size, "Frying Pan");
		case 294: strcopy(buffer, size, "Lugermorph");
		case 357: strcopy(buffer, size, "The Half-Zatoichi");
		case 415: strcopy(buffer, size, "The Reserve Shooter");
		case 423: strcopy(buffer, size, "Saxxy");
		case 474: strcopy(buffer, size, "The Conscientious Objector");
		case 880: strcopy(buffer, size, "The Freedom Staff");
		case 939: strcopy(buffer, size, "The Bat Outta Hell");
		case 954: strcopy(buffer, size, "The Memory Maker");
		case 1013: strcopy(buffer, size, "The Ham Shank");
		case 1071: strcopy(buffer, size, "Gold Frying Pan");
		case 1101: strcopy(buffer, size, "The B.A.S.E. Jumper");
		case 1123: strcopy(buffer, size, "The Necro Smasher");
		case 1127: strcopy(buffer, size, "The Crossing Guard");
		case 1141: strcopy(buffer, size, "Festive Shotgun");
		case 1153: strcopy(buffer, size, "Panic Attack");
		case 15003: strcopy(buffer, size, "Backwoods Boomstick");
		case 15013: strcopy(buffer, size, "Red Rock Roscoe");
		case 15016: strcopy(buffer, size, "Rustic Ruiner");
		case 15018: strcopy(buffer, size, "Homemade Heater");
		case 15035: strcopy(buffer, size, "Hickory Holepuncher");
		case 15041: strcopy(buffer, size, "Local Hero");
		case 15044: strcopy(buffer, size, "Civic Duty");
		case 15046: strcopy(buffer, size, "Black Dahlia");
		case 15047: strcopy(buffer, size, "Lightning Rod");
		case 15056: strcopy(buffer, size, "Sandstone Special");
		case 15060: strcopy(buffer, size, "Macabre Web");
		case 15061: strcopy(buffer, size, "Nutcracker");
		case 15085: strcopy(buffer, size, "Autumn");
		case 15100: strcopy(buffer, size, "Blue Mew");
		case 15101: strcopy(buffer, size, "Brain Candy");
		case 15102: strcopy(buffer, size, "Shot to Hell");
		case 15109: strcopy(buffer, size, "Flower Power");
		case 15123: strcopy(buffer, size, "Coffin Nail");
		case 15126: strcopy(buffer, size, "Dressed To Kill");
		case 15132: strcopy(buffer, size, "Coffin Nail");
		case 15133: strcopy(buffer, size, "Dressed to Kill");
		case 15148: strcopy(buffer, size, "Blitzkrieg");
		case 15152: strcopy(buffer, size, "Red Bear");
		case 30666: strcopy(buffer, size, "The C.A.P.P.E.R.");
		case 30758: strcopy(buffer, size, "Prinny Machete");
		
		//Scout Primary
		case 13: strcopy(buffer, size, "Scattergun");
		case 200: strcopy(buffer, size, "Scattergun (Renamed/Strange)");
		case 45: strcopy(buffer, size, "Force-A-Nature");
		case 220: strcopy(buffer, size, "The Shortstop");
		case 448: strcopy(buffer, size, "The Soda Popper");
		case 669: strcopy(buffer, size, "Festive Scattergun");
		case 772: strcopy(buffer, size, "Baby Face's Blaster");
		case 799: strcopy(buffer, size, "Silver Botkiller Scattergun Mk.I");
		case 808: strcopy(buffer, size, "Gold Botkiller Scattergun Mk.I");
		case 888: strcopy(buffer, size, "Rust Botkiller Scattergun Mk.I");
		case 897: strcopy(buffer, size, "Blood Botkiller Scattergun Mk.I");
		case 906: strcopy(buffer, size, "Carbonado Botkiller Scattergun Mk.I");
		case 915: strcopy(buffer, size, "Diamond Botkiller Scattergun Mk.I");
		case 964: strcopy(buffer, size, "Silver Botkiller Scattergun Mk.II");
		case 973: strcopy(buffer, size, "Gold Botkiller Scattergun Mk.II");
		case 1078: strcopy(buffer, size, "Festive Force-A-Nature");
		case 1103: strcopy(buffer, size, "The Back Scatter");
		case 15002: strcopy(buffer, size, "Night Terror");
		case 15015: strcopy(buffer, size, "Tartan Torpedo");
		case 15021: strcopy(buffer, size, "Country Crusher");
		case 15029: strcopy(buffer, size, "Backcountry Blaster");
		case 15036: strcopy(buffer, size, "Spruce Deuce");
		case 15053: strcopy(buffer, size, "Current Event");
		case 15065: strcopy(buffer, size, "Macabre Web");
		case 15069: strcopy(buffer, size, "Nutcracker");
		case 15106: strcopy(buffer, size, "Blue Mew");
		case 15107: strcopy(buffer, size, "Flower Power");
		case 15108: strcopy(buffer, size, "Shot to Hell");
		case 15131: strcopy(buffer, size, "Coffin Nail");
		case 15151: strcopy(buffer, size, "Killer Bee");
		case 15157: strcopy(buffer, size, "Corsair");
		
		//Scout Secondary
		case 23: strcopy(buffer, size, "Scout's Pistol");
		case 46: strcopy(buffer, size, "Bonk! Atomic Punch");
		case 163: strcopy(buffer, size, "Crit-a-Cola");
		case 222: strcopy(buffer, size, "Mad Milk");
		case 449: strcopy(buffer, size, "The Winger");
		case 773: strcopy(buffer, size, "Pretty Boy's Pocket Pistol");
		case 812: strcopy(buffer, size, "The Flying Guillotine");
		case 833: strcopy(buffer, size, "The Flying Guillotine (Genuine)");
		case 1121: strcopy(buffer, size, "Mutated Milk");
		case 1145: strcopy(buffer, size, "Festive Bonk!");
		
		//Scout Melee
		case 0: strcopy(buffer, size, "Bat");
		case 190: strcopy(buffer, size, "Bat (Renamed/Strange)");
		case 44: strcopy(buffer, size, "The Sandman");
		case 221: strcopy(buffer, size, "The Holy Mackerel");
		case 317: strcopy(buffer, size, "The Candy Cane");
		case 325: strcopy(buffer, size, "The Boston Basher");
		case 349: strcopy(buffer, size, "Sun-on-a-Stick");
		case 355: strcopy(buffer, size, "The Fan O'War");
		case 450: strcopy(buffer, size, "The Atomizer");
		case 452: strcopy(buffer, size, "Three-Rune Blade");
		case 572: strcopy(buffer, size, "Unarmed Combat");
		case 648: strcopy(buffer, size, "The Wrap Assassin");
		case 660: strcopy(buffer, size, "Festive Bat");
		case 999: strcopy(buffer, size, "Festive Holy Mackerel");
		case 30667: strcopy(buffer, size, "Batsaber");
		
		//Soldier Primary
		case 18: strcopy(buffer, size, "Rocket Launcher");
		case 205: strcopy(buffer, size, "Rocket Launcher (Renamed/Strange)");
		case 127: strcopy(buffer, size, "The Direct Hit");
		case 228: strcopy(buffer, size, "The Black Box");
		case 237: strcopy(buffer, size, "Rocket Jumper");
		case 414: strcopy(buffer, size, "The Liberty Launcher");
		case 441: strcopy(buffer, size, "The Cow Mangler 5000");
		case 513: strcopy(buffer, size, "The Original");
		case 658: strcopy(buffer, size, "Festive Rocket Launcher");
		case 730: strcopy(buffer, size, "The Beggar's Bazooka");
		case 800: strcopy(buffer, size, "Silver Botkiller Rocket Launcher Mk.I");
		case 809: strcopy(buffer, size, "Gold Botkiller Rocket Launcher Mk.I");
		case 889: strcopy(buffer, size, "Rust Botkiller Rocket Launcher Mk.I");
		case 898: strcopy(buffer, size, "Blood Botkiller Rocket Launcher Mk.I");
		case 907: strcopy(buffer, size, "Carbonado Botkiller Rocket Launcher Mk.I");
		case 916: strcopy(buffer, size, "Diamond Botkiller Rocket Launcher Mk.I");
		case 965: strcopy(buffer, size, "Silver Botkiller Rocket Launcher Mk.II");
		case 974: strcopy(buffer, size, "Gold Botkiller Rocket Launcher Mk.II");
		case 1085: strcopy(buffer, size, "Festive Black Box");
		case 1104: strcopy(buffer, size, "The Air Strike");
		case 15006: strcopy(buffer, size, "Woodland Warrior");
		case 15014: strcopy(buffer, size, "Sand Cannon");
		case 15028: strcopy(buffer, size, "American Pastoral");
		case 15043: strcopy(buffer, size, "Smalltown Bringdown");
		case 15052: strcopy(buffer, size, "Shell Shocker");
		case 15057: strcopy(buffer, size, "Aqua Marine");
		case 15081: strcopy(buffer, size, "Autumn");
		case 15104: strcopy(buffer, size, "Blue Mew");
		case 15105: strcopy(buffer, size, "Brain Candy");
		case 15129: strcopy(buffer, size, "Coffin Nail");
		case 15130: strcopy(buffer, size, "High Roller's");
		case 15150: strcopy(buffer, size, "Warhawk");
		
		//Soldier Secondary
		case 10: strcopy(buffer, size, "Soldier's Shotgun");
		case 129: strcopy(buffer, size, "The Buff Banner");
		case 133: strcopy(buffer, size, "Gunboats");
		case 226: strcopy(buffer, size, "The Battalion's Backup");
		case 354: strcopy(buffer, size, "The Concheror");
		case 442: strcopy(buffer, size, "The Righteous Bison");
		case 444: strcopy(buffer, size, "The Mantreads");
		case 1001: strcopy(buffer, size, "Festive Buff Banner");
		
		//Soldier Melee
		case 6: strcopy(buffer, size, "Shovel");
		case 196: strcopy(buffer, size, "Shovel (Renamed/Strange)");
		case 128: strcopy(buffer, size, "The Equalizer");
		case 416: strcopy(buffer, size, "The Market Gardener");
		case 447: strcopy(buffer, size, "The Disciplinary Action");
		case 775: strcopy(buffer, size, "The Escape Plan");

		//Pyro Primary
		case 21: strcopy(buffer, size, "Flame Thrower");
		case 208: strcopy(buffer, size, "Flame Thrower (Renamed/Strange)");
		case 40: strcopy(buffer, size, "The Backburner");
		case 215: strcopy(buffer, size, "The Degreaser");
		case 594: strcopy(buffer, size, "The Phlogistinator");
		case 659: strcopy(buffer, size, "Festive Flame Thrower");
		case 741: strcopy(buffer, size, "The Rainblower");
		case 798: strcopy(buffer, size, "Silver Botkiller Flame Thrower Mk.I");
		case 807: strcopy(buffer, size, "Gold Botkiller Flame Thrower Mk.I");
		case 887: strcopy(buffer, size, "Rust Botkiller Flame Thrower Mk.I");
		case 896: strcopy(buffer, size, "Blood Botkiller Flame Thrower Mk.I");
		case 905: strcopy(buffer, size, "Carbonado Botkiller Flame Thrower Mk.I");
		case 914: strcopy(buffer, size, "Diamond Botkiller Flame Thrower Mk.I");
		case 963: strcopy(buffer, size, "Silver Botkiller Flame Thrower Mk.II");
		case 972: strcopy(buffer, size, "Gold Botkiller Flame Thrower Mk.II");
		case 1146: strcopy(buffer, size, "Festive Backburner");
		case 1178: strcopy(buffer, size, "Dragon's Fury");
		case 15005: strcopy(buffer, size, "Forest Fire");
		case 15017: strcopy(buffer, size, "Barn Burner");
		case 15030: strcopy(buffer, size, "Bovine Blazemaker");
		case 15034: strcopy(buffer, size, "Earth, Sky and Fire");
		case 15049: strcopy(buffer, size, "Flash Fryer");
		case 15054: strcopy(buffer, size, "Turbine Torcher");
		case 15066: strcopy(buffer, size, "Autumn");
		case 15067: strcopy(buffer, size, "Pumpkin Patch");
		case 15068: strcopy(buffer, size, "Nutcracker");
		case 15089: strcopy(buffer, size, "Balloonicorn");
		case 15090: strcopy(buffer, size, "Rainbow");
		case 15115: strcopy(buffer, size, "Coffin Nail");
		case 15141: strcopy(buffer, size, "Warhawk");
		case 30474: strcopy(buffer, size, "Nostromo Napalmer");
		
		//Pyro Secondary
		case 12: strcopy(buffer, size, "Pyro's Shotgun");
		case 39: strcopy(buffer, size, "The Flare Gun");
		case 351: strcopy(buffer, size, "The Detonator");
		case 595: strcopy(buffer, size, "The Manmelter");
		case 740: strcopy(buffer, size, "The Scorch Shot");
		case 1081: strcopy(buffer, size, "Festive Flare Gun");
		case 1179: strcopy(buffer, size, "Thermal Thruster");
		case 1180: strcopy(buffer, size, "Gas Passer");
		
		//Pyro Melee
		case 2: strcopy(buffer, size, "Fire Axe");
		case 192: strcopy(buffer, size, "Fire Axe (Renamed/Strange)");
		case 38: strcopy(buffer, size, "The Axtinguisher");
		case 153: strcopy(buffer, size, "Homewrecker");
		case 214: strcopy(buffer, size, "The Powerjack");
		case 326: strcopy(buffer, size, "The Back Scratcher");
		case 348: strcopy(buffer, size, "Sharpened Volcano Fragment");
		case 457: strcopy(buffer, size, "The Postal Pummeler");
		case 466: strcopy(buffer, size, "The Maul");
		case 593: strcopy(buffer, size, "The Third Degree");
		case 739: strcopy(buffer, size, "The Lollichop");
		case 813: strcopy(buffer, size, "Neon Annihilator");
		case 834: strcopy(buffer, size, "Neon Annihilator (Genuine)");
		case 1000: strcopy(buffer, size, "The Festive Axtinguisher");
		case 1181: strcopy(buffer, size, "Hot Hand");
		
		//Demoman Primary
		case 19: strcopy(buffer, size, "Grenade Launcher");
		case 206: strcopy(buffer, size, "Grenade Launcher (Renamed/Strange)");
		case 308: strcopy(buffer, size, "The Loch-n-Load");
		case 405: strcopy(buffer, size, "Ali Baba's Wee Booties");
		case 608: strcopy(buffer, size, "The Bootlegger");
		case 996: strcopy(buffer, size, "The Loose Cannon");
		case 1007: strcopy(buffer, size, "Festive Grenade Launcher");
		case 1151: strcopy(buffer, size, "The Iron Bomber");
		case 15077: strcopy(buffer, size, "Autumn");
		case 15079: strcopy(buffer, size, "Macabre Web");
		case 15091: strcopy(buffer, size, "Rainbow");
		case 15092: strcopy(buffer, size, "Sweet Dreams");
		case 15116: strcopy(buffer, size, "Coffin Nail");
		case 15117: strcopy(buffer, size, "Top Shelf");
		case 15142: strcopy(buffer, size, "Warhawk");
		case 15158: strcopy(buffer, size, "Butcher Bird");
		
		//Demoman Secondary
		case 20: strcopy(buffer, size, "Stickybomb Launcher");
		case 207: strcopy(buffer, size, "Stickybomb Launcher (Renamed/Strange)");
		case 130: strcopy(buffer, size, "The Scottish Resistance");
		case 131: strcopy(buffer, size, "The Chargin' Targe");
		case 265: strcopy(buffer, size, "Sticky Jumper");
		case 406: strcopy(buffer, size, "The Splendid Screen");
		case 661: strcopy(buffer, size, "Festive Stickybomb Launcher");
		case 797: strcopy(buffer, size, "Silver Botkiller Stickybomb Launcher Mk.I");
		case 806: strcopy(buffer, size, "Gold Botkiller Stickybomb Launcher Mk.I");
		case 886: strcopy(buffer, size, "Rust Botkiller Stickybomb Launcher Mk.I");
		case 895: strcopy(buffer, size, "Blood Botkiller Stickybomb Launcher Mk.I");
		case 904: strcopy(buffer, size, "Carbonado Botkiller Stickybomb Launcher Mk.I");
		case 913: strcopy(buffer, size, "Diamond Botkiller Stickybomb Launcher Mk.I");
		case 962: strcopy(buffer, size, "Silver Botkiller Stickybomb Launcher Mk.II");
		case 971: strcopy(buffer, size, "Gold Botkiller Stickybomb Launcher Mk.II");
		case 1099: strcopy(buffer, size, "The Tide Turner");
		case 1144: strcopy(buffer, size, "Festive Targe");
		case 1150: strcopy(buffer, size, "The Quickiebomb Launcher");
		case 15009: strcopy(buffer, size, "Sudden Flurry");
		case 15012: strcopy(buffer, size, "Carpet Bomber");
		case 15024: strcopy(buffer, size, "Blasted Bombardier");
		case 15038: strcopy(buffer, size, "Rooftop Wrangler");
		case 15045: strcopy(buffer, size, "Liquid Asset");
		case 15048: strcopy(buffer, size, "Pink Elephant");
		case 15082: strcopy(buffer, size, "Autumn");
		case 15083: strcopy(buffer, size, "Pumpkin Patch");
		case 15084: strcopy(buffer, size, "Macabre Web");
		case 15113: strcopy(buffer, size, "Sweet Dreams");
		case 15137: strcopy(buffer, size, "Coffin Nail");
		case 15138: strcopy(buffer, size, "Dressed to Kill");
		case 15155: strcopy(buffer, size, "Blitzkrieg");
		
		//Demoman Melee
		case 1: strcopy(buffer, size, "Bottle");
		case 191: strcopy(buffer, size, "Bottle (Renamed/Strange)");
		case 132: strcopy(buffer, size, "The Eyelander");
		case 172: strcopy(buffer, size, "The Scotsman's Skullcutter");
		case 266: strcopy(buffer, size, "Horseless Headless Horsemann's Headtaker");
		case 307: strcopy(buffer, size, "Ullapool Caber");
		case 327: strcopy(buffer, size, "The Claidheamh Mòr");
		case 404: strcopy(buffer, size, "The Persian Persuader");
		case 482: strcopy(buffer, size, "Nessie's Nine Iron");
		case 609: strcopy(buffer, size, "The Scottish Handshake");
		case 1082: strcopy(buffer, size, "Festive Eyelander");
		
		//Heavy Primary
		case 15: strcopy(buffer, size, "Minigun");
		case 202: strcopy(buffer, size, "Minigun (Renamed/Strange)");
		case 41: strcopy(buffer, size, "Natascha");
		case 298: strcopy(buffer, size, "Iron Curtain");
		case 312: strcopy(buffer, size, "The Brass Beast");
		case 424: strcopy(buffer, size, "Tomislav");
		case 654: strcopy(buffer, size, "Festive Minigun");
		case 793: strcopy(buffer, size, "Silver Botkiller Minigun Mk.I");
		case 802: strcopy(buffer, size, "Gold Botkiller Minigun Mk.I");
		case 811: strcopy(buffer, size, "The Huo-Long Heater");
		case 832: strcopy(buffer, size, "The Huo-Long Heater (Genuine)");
		case 850: strcopy(buffer, size, "Deflector (MvM only?)");
		case 882: strcopy(buffer, size, "Rust Botkiller Minigun Mk.I");
		case 891: strcopy(buffer, size, "Blood Botkiller Minigun Mk.I");
		case 900: strcopy(buffer, size, "Carbonado Botkiller Minigun Mk.I");
		case 909: strcopy(buffer, size, "Diamond Botkiller Minigun Mk.I");
		case 958: strcopy(buffer, size, "Silver Botkiller Minigun Mk.II");
		case 967: strcopy(buffer, size, "Gold Botkiller Minigun Mk.II");
		case 15004: strcopy(buffer, size, "King of the Jungle");
		case 15020: strcopy(buffer, size, "Iron Wood");
		case 15026: strcopy(buffer, size, "Antique Annihilator");
		case 15031: strcopy(buffer, size, "War Room");
		case 15040: strcopy(buffer, size, "Citizen Pain");
		case 15055: strcopy(buffer, size, "Brick House");
		case 15086: strcopy(buffer, size, "Macabre Web");
		case 15087: strcopy(buffer, size, "Pumpkin Patch");
		case 15088: strcopy(buffer, size, "Nutcracker");
		case 15098: strcopy(buffer, size, "Brain Candy");
		case 15099: strcopy(buffer, size, "Mister Cuddles");
		case 15124: strcopy(buffer, size, "Dressed to Kill");
		case 15125: strcopy(buffer, size, "Top Shelf");
		case 15147: strcopy(buffer, size, "Butcher Bird");

		//Heavy Secondary
		case 11: strcopy(buffer, size, "Heavy's Shotgun");
		case 42: strcopy(buffer, size, "Sandvich");
		case 159: strcopy(buffer, size, "The Dalokohs Bar");
		case 311: strcopy(buffer, size, "The Buffalo Steak Sandvich");
		case 425: strcopy(buffer, size, "The Family Business");
		case 433: strcopy(buffer, size, "Fishcake");
		case 863: strcopy(buffer, size, "Robo-Sandvich");
		case 1002: strcopy(buffer, size, "Festive Sandvich");
		
		//Heavy Melee
		case 5: strcopy(buffer, size, "Fists");
		case 195: strcopy(buffer, size, "Fists (Renamed/Strange)");
		case 43: strcopy(buffer, size, "The Killing Gloves of Boxing");
		case 239: strcopy(buffer, size, "Gloves of Running Urgently");
		case 310: strcopy(buffer, size, "Warrior's Spirit");
		case 331: strcopy(buffer, size, "Fists of Steel");
		case 426: strcopy(buffer, size, "The Eviction Notice");
		case 587: strcopy(buffer, size, "Apoco-Fists");
		case 656: strcopy(buffer, size, "The Holiday Punch");
		case 1084: strcopy(buffer, size, "Festive Gloves of Running Urgently (G.R.U.)");
		case 1100: strcopy(buffer, size, "The Bread Bite");
		case 1184: strcopy(buffer, size, "Gloves of Running Urgently MvM");
		
		//Engineer Primary
		case 9: strcopy(buffer, size, "Engineer's Shotgun");
		case 141: strcopy(buffer, size, "The Frontier Justice");
		case 527: strcopy(buffer, size, "The Widowmaker");
		case 588: strcopy(buffer, size, "The Pomson 6000");
		case 997: strcopy(buffer, size, "The Rescue Ranger");
		case 1004: strcopy(buffer, size, "Festive Frontier Justice");
		
		//Engineer Secondary
		case 22: strcopy(buffer, size, "Engineer's Pistol");
		case 140: strcopy(buffer, size, "The Wrangler");
		case 528: strcopy(buffer, size, "The Short Circuit");
		case 1086: strcopy(buffer, size, "Festive Wrangler");
		case 30668: strcopy(buffer, size, "The Gigar Counter");
		
		//Engineer Melee
		case 7: strcopy(buffer, size, "Wrench");
		case 197: strcopy(buffer, size, "Wrench (Renamed/Strange)");
		case 142: strcopy(buffer, size, "The Gunslinger");
		case 155: strcopy(buffer, size, "The Southern Hospitality");
		case 169: strcopy(buffer, size, "Golden Wrench");
		case 329: strcopy(buffer, size, "The Jag");
		case 589: strcopy(buffer, size, "The Eureka Effect");
		case 662: strcopy(buffer, size, "Festive Wrench");
		case 795: strcopy(buffer, size, "Silver Botkiller Wrench Mk.I");
		case 804: strcopy(buffer, size, "Gold Botkiller Wrench Mk.I");
		case 884: strcopy(buffer, size, "Rust Botkiller Wrench Mk.I");
		case 893: strcopy(buffer, size, "Blood Botkiller Wrench Mk.I");
		case 902: strcopy(buffer, size, "Carbonado Botkiller Wrench Mk.I");
		case 911: strcopy(buffer, size, "Diamond Botkiller Wrench Mk.I");
		case 960: strcopy(buffer, size, "Silver Botkiller Wrench Mk.II");
		case 969: strcopy(buffer, size, "Gold Botkiller Wrench Mk.II");
		case 15073: strcopy(buffer, size, "Nutcracker");
		case 15074: strcopy(buffer, size, "Autumn");
		case 15075: strcopy(buffer, size, "Boneyard");
		case 15139: strcopy(buffer, size, "Dressed to Kill");
		case 15140: strcopy(buffer, size, "Top Shelf");
		case 15114: strcopy(buffer, size, "Torqued to Hell");
		case 15156: strcopy(buffer, size, "Airwolf");
		
		//Medic Primary
		case 17: strcopy(buffer, size, "Syringe Gun");
		case 204: strcopy(buffer, size, "Syringe Gun (Renamed/Strange)");
		case 36: strcopy(buffer, size, "The Blutsauger");
		case 305: strcopy(buffer, size, "Crusader's Crossbow");
		case 412: strcopy(buffer, size, "The Overdose");
		case 1079: strcopy(buffer, size, "Festive Crusader's Crossbow");
		
		//Medic Secondary
		case 29: strcopy(buffer, size, "Medi Gun");
		case 211: strcopy(buffer, size, "Medi Gun(Renamed/Strange)");
		case 35: strcopy(buffer, size, "The Kritzkrieg");
		case 411: strcopy(buffer, size, "The Quick-Fix");
		case 663: strcopy(buffer, size, "Festive Medi Gun");
		case 796: strcopy(buffer, size, "Silver Botkiller Medi Gun Mk.I");
		case 805: strcopy(buffer, size, "Gold Botkiller Medi Gun Mk.I");
		case 885: strcopy(buffer, size, "Rust Botkiller Medi Gun Mk.I");
		case 894: strcopy(buffer, size, "Blood Botkiller Medi Gun Mk.I");
		case 903: strcopy(buffer, size, "Carbonado Botkiller Medi Gun Mk.I");
		case 912: strcopy(buffer, size, "Diamond Botkiller Medi Gun Mk.I");
		case 961: strcopy(buffer, size, "Silver Botkiller Medi Gun Mk.II");
		case 970: strcopy(buffer, size, "Gold Botkiller Medi Gun Mk.II");
		case 998: strcopy(buffer, size, "The Vaccinator");
		case 15008: strcopy(buffer, size, "Masked Mender");
		case 15010: strcopy(buffer, size, "Wrapped Reviver");
		case 15025: strcopy(buffer, size, "Reclaimed Reanimator");
		case 15039: strcopy(buffer, size, "Civil Servant");
		case 15050: strcopy(buffer, size, "Spark of Life");
		case 15078: strcopy(buffer, size, "Wildwood");
		case 15097: strcopy(buffer, size, "Flower Power");
		case 15121: strcopy(buffer, size, "Dressed To Kill");
		case 15122: strcopy(buffer, size, "High Roller's");
		case 15145: strcopy(buffer, size, "Blitzkrieg");
		case 15146: strcopy(buffer, size, "Corsair");
		
		//Medic Melee
		case 8: strcopy(buffer, size, "Bonesaw");
		case 198: strcopy(buffer, size, "Bonesaw (Renamed/Strange)");
		case 37: strcopy(buffer, size, "The Ubersaw");
		case 173: strcopy(buffer, size, "The Vita-Saw");
		case 304: strcopy(buffer, size, "Amputator");
		case 413: strcopy(buffer, size, "The Solemn Vow");
		case 1003: strcopy(buffer, size, "Festive Ubersaw");
		case 1143: strcopy(buffer, size, "Festive Bonesaw");
		
		//Sniper Primary
		case 14: strcopy(buffer, size, "Sniper Rifle");
		case 201: strcopy(buffer, size, "Sniper Rifle (Renamed/Strange)");
		case 56: strcopy(buffer, size, "The Huntsman");
		case 230: strcopy(buffer, size, "The Sydney Sleeper");
		case 402: strcopy(buffer, size, "The Bazaar Bargain");
		case 526: strcopy(buffer, size, "The Machina");
		case 664: strcopy(buffer, size, "Festive Sniper Rifle");
		case 752: strcopy(buffer, size, "The Hitman's Heatmaker");
		case 792: strcopy(buffer, size, "Silver Botkiller Sniper Rifle Mk.I");
		case 801: strcopy(buffer, size, "Gold Botkiller Sniper Rifle Mk.I");
		case 851: strcopy(buffer, size, "The AWPer Hand");
		case 881: strcopy(buffer, size, "Rust Botkiller Sniper Rifle Mk.I");
		case 890: strcopy(buffer, size, "Blood Botkiller Sniper Rifle Mk.I");
		case 899: strcopy(buffer, size, "Carbonado Botkiller Sniper Rifle Mk.I");
		case 908: strcopy(buffer, size, "Diamond Botkiller Sniper Rifle Mk.I");
		case 957: strcopy(buffer, size, "Silver Botkiller Sniper Rifle Mk.II");
		case 966: strcopy(buffer, size, "Gold Botkiller Sniper Rifle Mk.II");
		case 1005: strcopy(buffer, size, "Festive Huntsman");
		case 1092: strcopy(buffer, size, "The Fortified Compound");
		case 1098: strcopy(buffer, size, "The Classic");
		case 15000: strcopy(buffer, size, "Night Owl");
		case 15007: strcopy(buffer, size, "Purple Range");
		case 15019: strcopy(buffer, size, "Lumber From Down Under");
		case 15023: strcopy(buffer, size, "Shot in the Dark");
		case 15033: strcopy(buffer, size, "Bogtrotter");
		case 15059: strcopy(buffer, size, "Thunderbolt");
		case 15070: strcopy(buffer, size, "Pumpkin Patch");
		case 15071: strcopy(buffer, size, "Boneyard");
		case 15072: strcopy(buffer, size, "Wildwood");
		case 15111: strcopy(buffer, size, "Balloonicorn");
		case 15112: strcopy(buffer, size, "Rainbow");
		case 15135: strcopy(buffer, size, "Coffin Nail");
		case 15136: strcopy(buffer, size, "Dressed to Kill");
		case 15154: strcopy(buffer, size, "Airwolf");
		case 30665: strcopy(buffer, size, "Shooting Star");
		
		//Sniper Secondary
		case 16: strcopy(buffer, size, "SMG");
		case 203: strcopy(buffer, size, "SMG (Renamed/Strange)");
		case 57: strcopy(buffer, size, "The Razorback");
		case 58: strcopy(buffer, size, "Jarate");
		case 231: strcopy(buffer, size, "Darwin's Danger Shield");
		case 642: strcopy(buffer, size, "Cozy Camper");
		case 751: strcopy(buffer, size, "The Cleaner's Carbine");
		case 1083: strcopy(buffer, size, "Festive Jarate");
		case 1105: strcopy(buffer, size, "The Self-Aware Beauty Mark");
		case 1149: strcopy(buffer, size, "Festive SMG");
		case 15001: strcopy(buffer, size, "Woodsy Widowmaker");
		case 15022: strcopy(buffer, size, "Plaid Potshotter");
		case 15032: strcopy(buffer, size, "Treadplate Tormenter");
		case 15037: strcopy(buffer, size, "Team Sprayer");
		case 15058: strcopy(buffer, size, "Low Profile");
		case 15076: strcopy(buffer, size, "Wildwood");
		case 15110: strcopy(buffer, size, "Blue Mew");
		case 15134: strcopy(buffer, size, "High Roller's");
		case 15153: strcopy(buffer, size, "Blitzkrieg");
		
		//Sniper Melee
		case 3: strcopy(buffer, size, "Kukri");
		case 193: strcopy(buffer, size, "Kukri (Renamed/Strange)");
		case 171: strcopy(buffer, size, "The Tribalman's Shiv");
		case 232: strcopy(buffer, size, "The Bushwacka");
		case 401: strcopy(buffer, size, "The Shahanshah");
		
		//Spy Primary
		case 24: strcopy(buffer, size, "Revolver");
		case 210: strcopy(buffer, size, "Revolver (Renamed/Strange)");
		case 61: strcopy(buffer, size, "The Ambassador");
		case 161: strcopy(buffer, size, "Big Kill");
		case 224: strcopy(buffer, size, "L'Etranger");
		case 460: strcopy(buffer, size, "The Enforcer");
		case 525: strcopy(buffer, size, "The Diamondback");
		case 1006: strcopy(buffer, size, "Festive Ambassador");
		case 1142: strcopy(buffer, size, "Festive Revolver");
		case 15011: strcopy(buffer, size, "Psychedelic Slugger");
		case 15027: strcopy(buffer, size, "Old Country");
		case 15042: strcopy(buffer, size, "Mayor");
		case 15051: strcopy(buffer, size, "Dead Reckoner");
		case 15063: strcopy(buffer, size, "Wildwood");
		case 15064: strcopy(buffer, size, "Macabre Web");
		case 15103: strcopy(buffer, size, "Flower Power");
		case 15128: strcopy(buffer, size, "Top Shelf");
		case 15149: strcopy(buffer, size, "Blitzkrieg");
		
		//Spy Secondary
		case 735: strcopy(buffer, size, "Sapper");
		case 736: strcopy(buffer, size, "Sapper (Renamed/Strange)");
		case 810: strcopy(buffer, size, "The Red-Tape Recorder");
		case 831: strcopy(buffer, size, "The Red-Tape Recorder (Genuine)");
		case 933: strcopy(buffer, size, "The Ap-Sap (Genuine)");
		case 1080: strcopy(buffer, size, "Festive Sapper");
		case 1102: strcopy(buffer, size, "The Snack Attack");
		
		//Spy Melee
		case 4: strcopy(buffer, size, "Knife");
		case 194: strcopy(buffer, size, "Knife (Renamed/Strange)");
		case 225: strcopy(buffer, size, "Your Eternal Reward");
		case 356: strcopy(buffer, size, "Conniver's Kunai");
		case 461: strcopy(buffer, size, "The Big Earner");
		case 574: strcopy(buffer, size, "The Wanga Prick");
		case 638: strcopy(buffer, size, "The Sharp Dresser");
		case 649: strcopy(buffer, size, "The Spy-cicle");
		case 665: strcopy(buffer, size, "Festive Knife");
		case 727: strcopy(buffer, size, "The Black Rose");
		case 794: strcopy(buffer, size, "Silver Botkiller Knife Mk.I");
		case 803: strcopy(buffer, size, "Gold Botkiller Knife Mk.I");
		case 883: strcopy(buffer, size, "Rust Botkiller Knife Mk.I");
		case 892: strcopy(buffer, size, "Blood Botkiller Knife Mk.I");
		case 901: strcopy(buffer, size, "Carbonado Botkiller Knife Mk.I");
		case 910: strcopy(buffer, size, "Diamond Botkiller Knife Mk.I");
		case 959: strcopy(buffer, size, "Silver Botkiller Knife Mk.II");
		case 968: strcopy(buffer, size, "Gold Botkiller Knife Mk.II");
		case 15062: strcopy(buffer, size, "Boneyard");
		case 15094: strcopy(buffer, size, "Blue Mew");
		case 15095: strcopy(buffer, size, "Brain Candy");
		case 15096: strcopy(buffer, size, "Stabbed to Hell");
		case 15118: strcopy(buffer, size, "Dressed to Kill");
		case 15119: strcopy(buffer, size, "Top Shelf");
		case 15143: strcopy(buffer, size, "Blitzkrieg");
		case 15144: strcopy(buffer, size, "Airwolf");
	}
}

public Action Command_Loadouts(int client, int args)
{
	OpenLoadoutsMenu(client);
	return Plugin_Handled;
}

bool OpenLoadoutsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Loadouts);
	menu.SetTitle("::Vertex Heights :: Your Loadouts\n::Credits: %i", g_Player[client].credits);

	menu.AddItem("manage", "Manage your Loadouts");
	menu.AddItem("create", "Create a Loadout");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return true;
}

public int MenuHandler_Loadouts(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenStoreMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

public Action Command_Marketplace(int client, int args)
{
	OpenMarketplaceMenu(client);
	return Plugin_Handled;
}

bool OpenMarketplaceMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Marketplace);
	menu.SetTitle("::Vertex Heights :: Marketplace Items\n::Credits: %i", g_Player[client].credits);

	char sDisplay[256];
	for (int i = 0; i < g_TotalMarketItems; i++)
	{
		FormatEx(sDisplay, sizeof(sDisplay), "(%s) %s(%i)", g_Marketplace[i].available != 0 ? "Unlocked" : "Locked", g_Marketplace[i].name, g_Marketplace[i].credits);
		menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", " :: No Marketplace Items Found", ITEMDRAW_DISABLED);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return true;
}

public int MenuHandler_Marketplace(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			OpenMarketplaceMenu(param1);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenStoreMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

public Action Timer_ParseMarketplace(Handle timer)
{
	ParseMarketplaceItems();
}

public Action Command_ReloadMarketplace(int client, int args)
{
	ParseMarketplaceItems();
	Vertex_SendPrint(client, "Marketplace items have been synced.");
	return Plugin_Handled;
}

void ParseMarketplaceItems()
{
	for (int i = 0; i < g_TotalMarketItems; i++)
		g_Marketplace[i].Init();
	g_TotalMarketItems = 0;

	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT name, credits, available FROM `store_marketplace`;");
	g_Database.Query(OnParseMarketplaceItems, sQuery);
}

public void OnParseMarketplaceItems(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while parsing marketplace items: %s", error);
	
	char name[64]; int credits; int available;

	while (results.FetchRow())
	{
		results.FetchString(0, name, sizeof(name));
		TrimString(name);
		credits = results.FetchInt(1);
		available = results.FetchInt(2);
		g_Marketplace[g_TotalMarketItems].AddMarketplaceItem(name, credits, available);
	}

	Vertex_SendPrintToAll("Available marketplace items have been updated.");
}