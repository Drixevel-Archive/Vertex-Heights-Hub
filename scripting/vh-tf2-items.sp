/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights][TF2] :: Items"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.1"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>

#include <misc-sm>
#include <misc-tf>
#include <misc-colors>

#include <vertexheights>
#include <tf2-items>

#include <tf2attributes>
#include <tf_econ_data>

/*****************************/
//Globals
int wearable[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

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
	RegConsoleCmd("sm_items", Command_Items);
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidEntity(wearable[i]))
			AcceptEntityInput(wearable[i], "Kill");
}

public void OnClientDisconnect_Post(int client)
{
	wearable[client] = INVALID_ENT_REFERENCE;
}

public Action Command_Items(int client, int args)
{
	OpenItemsMenu(client);
	return Plugin_Handled;
}

void OpenItemsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Items);
	menu.SetTitle("Pick a type:");

	menu.AddItem("weapons", "Weapons");
	menu.AddItem("wearables", "Wearables");
	menu.AddItem("effects", "Weapon Effects");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Items(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "weapons"))
				OpenSlotsMenu(param1);
			else if (StrEqual(sInfo, "wearables"))
				OpenWearablesMenu(param1);
			else if (StrEqual(sInfo, "effects"))
				OpenWeaponEffectsMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

void OpenSlotsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Slots);
	menu.SetTitle("Pick a slot:");

	menu.AddItem("0", "Primary");
	menu.AddItem("1", "Secondary");
	menu.AddItem("2", "Melee");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Slots(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			OpenWeaponsMenu(param1, StringToInt(sInfo));
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenItemsMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

void OpenWeaponsMenu(int client, int slot)
{
	Menu menu = new Menu(MenuHandler_Weapons);
	menu.SetTitle("Pick a weapon:");

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(slot);

	ArrayList weapons = TF2Econ_GetItemList(onParseWeapons, pack);

	int defindex; char sDefIndex[32];char sDisplay[64];
	for (int i = 0; i < weapons.Length; i++)
	{
		defindex = weapons.Get(i);
		IntToString(defindex, sDefIndex, sizeof(sDefIndex));
		TF2_GetWeaponNameFromIndex(defindex, sDisplay, sizeof(sDisplay));
		menu.AddItem(sDefIndex, sDisplay);
	}

	delete weapons;
	PushMenuInt(menu, "slot", slot);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Weapons(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			int defindex = StringToInt(sInfo);

			char sEntity[64];
			TF2Econ_GetItemClassName(defindex, sEntity, sizeof(sEntity));

			int slot = GetMenuInt(menu, "slot");
			TF2_RemoveWeaponSlot(param1, slot);

			TF2_GiveItem(param1, sEntity, defindex, TF2Quality_Normal, 0);
			OpenWeaponsMenu(param1, slot);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenSlotsMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

public bool onParseWeapons(int defindex, DataPack pack)
{
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	int slot = pack.ReadCell();

	if (!IsPlayerIndex(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
		return false;
	
	if (TF2Econ_GetItemSlot(defindex, TF2_GetPlayerClass(client)) != slot)
		return false;
	
	return true;
}

void OpenWearablesMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Wearables);
	menu.SetTitle("Pick a wearable:");

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));

	ArrayList wearables = TF2Econ_GetItemList(onParseWearables, pack);

	menu.AddItem("0", "None");

	int defindex; char sDefIndex[32];char sDisplay[64];
	for (int i = 0; i < wearables.Length; i++)
	{
		defindex = wearables.Get(i);
		IntToString(defindex, sDefIndex, sizeof(sDefIndex));
		TF2Econ_GetItemName(defindex, sDisplay, sizeof(sDisplay));
		menu.AddItem(sDefIndex, sDisplay);
	}

	delete wearables;

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Wearables(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			int defindex = StringToInt(sInfo);

			if (IsValidEntity(wearable[param1]))
				AcceptEntityInput(wearable[param1], "Kill");
			
			if (defindex == 0)
			{
				wearable[param1] = INVALID_ENT_REFERENCE;
				OpenWearablesMenu(param1);
				return;
			}
			
			wearable[param1] = EntIndexToEntRef(TF2Items_EquipWearable(param1, "tf_wearable", defindex, 0, 1));
			OpenWearablesMenu(param1);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenItemsMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

public bool onParseWearables(int defindex, DataPack pack)
{
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());

	if (!IsPlayerIndex(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
		return false;
	
	char sEntity[64];
	TF2Econ_GetItemClassName(defindex, sEntity, sizeof(sEntity));
	
	if (StrContains(sEntity, "tf_wearable", false) != 0)
		return false;
	
	if (TF2Econ_GetItemSlot(defindex, TF2_GetPlayerClass(client)) == -1)
		return false;
	
	return true;
}

void OpenWeaponEffectsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_WeaponEffects);
	menu.SetTitle("Pick a weapon effect:");

	menu.AddItem("0", "None");
	menu.AddItem("1", "Burning Red");
	menu.AddItem("2", "Flyingbits");
	menu.AddItem("3", "Nemesis Burst");
	menu.AddItem("4", "Community Sparkle");
	menu.AddItem("5", "Halopoint");
	menu.AddItem("6", "Green Confetti");
	menu.AddItem("7", "Purple Confetti");
	menu.AddItem("8", "Haunted Ghosts");
	menu.AddItem("9", "Green Energy");
	menu.AddItem("10", "Purple Energy");
	menu.AddItem("11", "Circling TF Logo");
	menu.AddItem("12", "Massed Flies");
	menu.AddItem("13", "Burning Flames");
	menu.AddItem("14", "Scorching Flames");
	menu.AddItem("15", "Searing Plasma");
	menu.AddItem("16", "Vivid Plasma");
	menu.AddItem("17", "Sunbeams");
	menu.AddItem("18", "Circling Peace Sign");
	menu.AddItem("19", "Circling Heart");
	menu.AddItem("20", "Stamps");
	menu.AddItem("28", "Pipe Smoke");
	menu.AddItem("29", "Stormy Storm");
	menu.AddItem("30", "Blizzardy Storm");
	menu.AddItem("31", "Nuts n' Bolts");
	menu.AddItem("32", "Orbiting Planets");
	menu.AddItem("33", "Orbiting Fire");
	menu.AddItem("34", "Bubbling");
	menu.AddItem("35", "Smoking");
	menu.AddItem("36", "Steaming");
	menu.AddItem("37", "Flaming Lantern");
	menu.AddItem("38", "Cloudy Moon");
	menu.AddItem("39", "Cauldron Bubbles");
	menu.AddItem("40", "Eerie Orbiting Fire");
	menu.AddItem("43", "Knifestorm");
	menu.AddItem("44", "Misty Skull");
	menu.AddItem("45", "Harvest Moon");
	menu.AddItem("46", "It's A Secret To Everybody");
	menu.AddItem("47", "Stormy 13th Hour");
	menu.AddItem("55", "Aces High Blue");
	menu.AddItem("56", "Kill-a-Watt");
	menu.AddItem("57", "Terror-Watt");
	menu.AddItem("58", "Cloud 9");
	menu.AddItem("59", "Aces High Red");
	menu.AddItem("60", "Dead Presidents");
	menu.AddItem("61", "Miami Nights");
	menu.AddItem("62", "Disco Beat Down");
	menu.AddItem("63", "Phosphorous");
	menu.AddItem("64", "Sulphurous");
	menu.AddItem("65", "Memory Leak");
	menu.AddItem("66", "Overclocked");
	menu.AddItem("67", "Electrostatic");
	menu.AddItem("68", "Power Surge");
	menu.AddItem("69", "Anti-Freeze");
	menu.AddItem("70", "Time Warp");
	menu.AddItem("71", "Green Black Hole");
	menu.AddItem("72", "Roboactive");
	menu.AddItem("73", "Arcana");
	menu.AddItem("74", "Spellbound");
	menu.AddItem("75", "Chiroptera Venenata");
	menu.AddItem("76", "Poisoned Shadows");
	menu.AddItem("77", "Something Burning This Way Comes");
	menu.AddItem("78", "Hellfire");
	menu.AddItem("79", "Darkblaze");
	menu.AddItem("80", "Demonflame");
	menu.AddItem("81", "Bonzo The All-Gnawing");
	menu.AddItem("82", "Amaranthine");
	menu.AddItem("83", "Stare From Beyond");
	menu.AddItem("84", "The Ooze");
	menu.AddItem("85", "Haunted Phantasm Jr");
	menu.AddItem("86", "El Amor Ardiente");
	menu.AddItem("87", "Frostbite");
	menu.AddItem("88", "Death at Dusk");
	menu.AddItem("89", "Morning Glory");
	menu.AddItem("90", "Molten Mallard");
	menu.AddItem("91", "Abduction");
	menu.AddItem("92", "Atomic");
	menu.AddItem("93", "Subatomic");
	menu.AddItem("94", "Electric Hat Protector");
	menu.AddItem("95", "Magnetic Hat Protector");
	menu.AddItem("96", "Voltaic Hat Protector");
	menu.AddItem("97", "Galactic Codex");
	menu.AddItem("98", "Ancient Codex");
	menu.AddItem("99", "Nebula");
	menu.AddItem("100", "Death by Disco");
	menu.AddItem("101", "It's a mystery to everyone");
	menu.AddItem("102", "It's a puzzle to me");
	menu.AddItem("103", "Ether Trail");
	menu.AddItem("104", "Nether Trail");
	menu.AddItem("105", "Ancient Eldritch");
	menu.AddItem("106", "Eldritch Flame");
	menu.AddItem("3001", "Taunt Show Stopper Red");
	menu.AddItem("3002", "Taunt Show Stopper Blue");
	menu.AddItem("3003", "Taunt Holy Grail");
	menu.AddItem("3004", "Taunt '72");
	menu.AddItem("3005", "Taunt Fountain Of Delight");
	menu.AddItem("3006", "Taunt Screaming Tiger");
	menu.AddItem("3007", "Taunt Skill Gotten Gains");
	menu.AddItem("3008", "Taunt Midnight Whirlwind");
	menu.AddItem("3009", "Taunt Silver Cyclone");
	menu.AddItem("3010", "Taunt Mega Strike");
	menu.AddItem("3011", "Taunt Haunted Phantasm");
	menu.AddItem("3012", "Taunt Ghastly Ghosts");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_WeaponEffects(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			int defindex = StringToInt(sInfo);

			int active = GetActiveWeapon(param1);
			
			if (IsValidEntity(active))
			{
				if (defindex == 0)
					TF2Attrib_RemoveByName(active, "attach particle effect");
				else
					TF2Attrib_SetByName(active, "attach particle effect", float(defindex));
			}
			
			OpenWeaponEffectsMenu(param1);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenItemsMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}