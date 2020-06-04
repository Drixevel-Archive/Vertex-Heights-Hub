/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Objectives"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.1"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>

#include <misc-sm>
#include <misc-colors>

#include <vertexheights>

/*****************************/
//Globals

enum struct Objectives
{
	int type;
	int goal;
	int credits;

	int target;
	char map[64];
}

//Objectives g_Objectives[MAXPLAYERS + 1][4];
int g_GenerateObjs[MAXPLAYERS + 1] = {-1, ...};

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
	RegConsoleCmd("sm_objectives", Command_Objectives);
}

public Action Command_Objectives(int client, int args)
{
	OpenObjectivesMenu(client);
	return Plugin_Handled;
}

void OpenObjectivesMenu(int client)
{
	int time = GetTime();

	if (g_GenerateObjs[client] == -1 || g_GenerateObjs[client] != -1 && g_GenerateObjs[client] < time)
		GenerateObjectives(client, time);

	Panel panel = new Panel();
	panel.SetTitle("Available Objectives:\n \n");
	
	panel.DrawText("[X] Get 5 Kills on Badlands [50 credits]");
	panel.DrawText("[X] Initiate 1 Server [100 credits]");
	panel.DrawText("[✓] Kill Drixevel [200 credits]");
	
	panel.DrawText("\n \n");
	panel.DrawItem("Objectives Completed");
	panel.DrawItem("Exit");

	panel.Send(client, MenuAction_Void, MENU_TIME_FOREVER);
}

public int MenuAction_Void(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
	}
}

void GenerateObjectives(int client, int time)
{
	if (client > 0 && time > 0)
	{

	}
}