/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 131072

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Proxycheck"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.1"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>

#include <system2>
#include <json>

#include <vertexheights>
#include <vh-logs>

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

public void OnClientConnected(int client)
{
	char sIP[32];
	GetClientIP(client, sIP, sizeof(sIP));

	System2HTTPRequest httpRequest = new System2HTTPRequest(HttpResponseCallback, "https://proxycheck.io/v2/%s?key=87zy59-g06060-wcl148-5t78t5", sIP);
	httpRequest.SetData("&vpn=1&risk=1");
	httpRequest.Timeout = 5;
	httpRequest.Any = GetClientUserId(client);
	httpRequest.GET();
}

public void HttpResponseCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if (success)
	{
		int client = GetClientOfUserId(request.Any);

		if (client == 0)
			return;
		
		char[] content = new char[response.ContentLength + 1];
		response.GetContent(content, response.ContentLength + 1);

		char sIP[32];
		GetClientIP(client, sIP, sizeof(sIP));

		JSON_Object obj = json_decode(content);
		
		if (obj == null)
			return;
		
		JSON_Object ip = obj.GetObject(sIP);
		
		if (ip != null)
		{
			char sProxy[16];
			ip.GetString("proxy", sProxy, sizeof(sProxy));
			
			if (StrEqual(sProxy, "yes", false))
				VH_SystemLog("Proxy Detected for %N.", client);
		}

		obj.Cleanup();
		delete obj;
    }
}