//Pragma
#pragma semicolon 1
//#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights][L4D2] :: Common Adjuster"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

//Sourcemod Includes
#include <sourcemod>

ConVar difficulty;
ConVar limit;

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
	difficulty = FindConVar("z_difficulty");
	difficulty.AddChangeHook(OnDifficultyChange);
	
	limit = FindConVar("z_common_limit");
}

public void OnMapStart()
{
	char difficultyname[32];
	difficulty.GetString(difficultyname, sizeof(difficultyname));
	
	if (StrEqual(difficultyname, "Easy", false))
		limit.IntValue = 25;
	else if (StrEqual(difficultyname, "Normal", false))
		limit.IntValue = 50;
	else if (StrEqual(difficultyname, "Hard", false))
		limit.IntValue = 75;
	else if (StrEqual(difficultyname, "Impossible", false))
		limit.IntValue = 100;
}

public void OnDifficultyChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StrEqual(oldValue, newValue, false))
		return;
	
	if (StrEqual(newValue, "Easy", false))
		limit.IntValue = 25;
	else if (StrEqual(newValue, "Normal", false))
		limit.IntValue = 50;
	else if (StrEqual(newValue, "Hard", false))
		limit.IntValue = 75;
	else if (StrEqual(newValue, "Impossible", false))
		limit.IntValue = 100;
}