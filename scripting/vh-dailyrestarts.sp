/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Daily Restarts"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>

#include <vertexheights>
#include <vh-logs>

/*****************************/
//Globals

#define PHASE_30 0
#define PHASE_15 1
#define PHASE_5 2
#define PHASE_2 3
#define PHASE_0 4

int g_RestartPhase;

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
	CreateTimer(1.0, Timer_CheckTime, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	PrecacheSound("ui/system_message_alert.wav");
}

public Action Timer_CheckTime(Handle timer)
{
	char sTime[32];
	FormatTime(sTime, sizeof(sTime), "%H%M");
	int time = StringToInt(sTime);

	if (time > 0430 && time <= 0430 + 1 && g_RestartPhase < PHASE_30)
	{
		g_RestartPhase = PHASE_30;
		
		PrintHintTextToAll("Restarting in 30 minutes...");
		PrintCenterTextAll("Restarting in 30 minutes...");
		PrintToChatAll("Restarting in 30 minutes...");

		EmitSoundToAll("ui/system_message_alert.wav");
	}
	else if (time > 0445 && time <= 0445 + 1 && g_RestartPhase < PHASE_15)
	{
		g_RestartPhase = PHASE_15;
		
		PrintHintTextToAll("Restarting in 15 minutes...");
		PrintCenterTextAll("Restarting in 15 minutes...");
		PrintToChatAll("Restarting in 15 minutes...");

		EmitSoundToAll("ui/system_message_alert.wav");
	}
	else if (time > 0455 && time <= 0455 + 1 && g_RestartPhase < PHASE_5)
	{
		g_RestartPhase = PHASE_5;
		
		PrintHintTextToAll("Restarting in 5 minutes...");
		PrintCenterTextAll("Restarting in 5 minutes...");
		PrintToChatAll("Restarting in 5 minutes...");

		EmitSoundToAll("ui/system_message_alert.wav");
	}
	else if (time > 0458 && time <= 0458 + 1 && g_RestartPhase < PHASE_2)
	{
		g_RestartPhase = PHASE_2;
		
		PrintHintTextToAll("Restarting in 2 minutes...");
		PrintCenterTextAll("Restarting in 2 minutes...");
		PrintToChatAll("Restarting in 2 minutes...");

		EmitSoundToAll("ui/system_message_alert.wav");
	}
	else if (time > 0500 && time <= 0500 + 1 && g_RestartPhase < PHASE_0)
	{
		g_RestartPhase = PHASE_0;
		PrintHintTextToAll("Restarting Server...");
		PrintCenterTextAll("Restarting Server...");
		PrintToChatAll("Restarting Server...");

		EmitSoundToAll("ui/system_message_alert.wav");
		VH_SystemLog("Server has been automatically restarted.");
		CreateTimer(5.0, Timer_Restart);
	}
}

public Action Timer_Restart(Handle timer)
{
	ServerCommand("quit");
}