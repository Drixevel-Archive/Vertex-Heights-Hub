/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Logs"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>
#include <system2>

#include <vertexheights>
#include <vh-core>

/*****************************/
//Globals

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
	RegPluginLibrary("vh-logs");

	CreateNative("VH_SystemLog", Native_SystemLog);
	CreateNative("VH_ThrowSystemLog", Native_ThrowSystemLog);

	return APLRes_Success;
}

public void OnPluginStart()
{
	RegAdminCmd("sm_log", Command_Log, ADMFLAG_ROOT, "Send a log to the Vertex systems.");
}

public Action Command_Log(int client, int args)
{
	char sLog[255];
	GetCmdArgString(sLog, sizeof(sLog));

	SystemLog(sLog);
	Vertex_SendPrint(client, "The following line has been logged:");
	Vertex_SendPrint(client, "[H]%s", sLog);

	return Plugin_Handled;
}

public int Native_SystemLog(Handle plugin, int numParams)
{
	char sLog[1024];
	FormatNativeString(0, 1, 2, sizeof(sLog), _, sLog);

	if (strlen(sLog) > 0)
		SystemLog(sLog);
}

public int Native_ThrowSystemLog(Handle plugin, int numParams)
{
	char sLog[1024];
	FormatNativeString(0, 1, 2, sizeof(sLog), _, sLog);

	if (strlen(sLog) > 0)
		SystemLog(sLog);
	
	return ThrowNativeError(SP_ERROR_NATIVE, sLog);
}

void SystemLog(char[] log)
{
	ParseLogForClients(log);

	char sSecretKey[32];
	VH_GetServerSecretKey(sSecretKey, sizeof(sSecretKey));

	System2HTTPRequest httpRequest = new System2HTTPRequest(HttpResponseCallback, "https://vertexheights.com/hub/api/logs.php?secret_key=%s&serverid=%i&log=%s", sSecretKey, VH_GetServerID(), log);
	httpRequest.POST();

	delete httpRequest;
}

public void HttpResponseCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
    if (!success)
		PrintToServer("Error on request with status code %i: %s", response.StatusCode, error);
}

void ParseLogForClients(char[] log)
{
	char sName[MAX_NAME_LENGTH]; char sName2[MAX_NAME_LENGTH + 18];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		GetClientName(i, sName, sizeof(sName));

		if (StrContains(log, sName, false) != -1)
		{
			FormatEx(sName2, sizeof(sName2), "%s(vid: %i)", sName, VH_GetVertexID(i));
			ReplaceString(log, 1024, sName, sName2, false);
		}
	}
}