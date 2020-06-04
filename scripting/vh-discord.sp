/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 131072

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Discord"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.1"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>

#include <misc-sm>
#include <misc-colors>

#include <json>
#include <system2>
#include <discord>

#include <vertexheights>
#include <vh-core>
#include <vh-logs>

/*****************************/
//Globals
int g_Time[MAXPLAYERS + 1] = {-1, ...};

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
	RegConsoleCmd("sm_calladmin", Command_CallAdmin, "Request admin assistance on this server.");
	RegConsoleCmd("sm_requestadmin", Command_CallAdmin, "Request admin assistance on this server.");
}

public Action Command_CallAdmin(int client, int args)
{
	if (args == 0)
	{
		Vertex_SendPrint(client, "You must input a reason.");
		return Plugin_Handled;
	}

	int time = GetTime();
	if (g_Time[client] != -1 && g_Time[client] > time)
	{
		Vertex_SendPrint(client, "You must wait [H]%i [D]seconds to send another admin request.", (g_Time[client] - time));
		return Plugin_Handled;
	}

	g_Time[client] = time + 60;

	char sMessage[255];
	GetCmdArgString(sMessage, sizeof(sMessage));
	TrimString(sMessage);
	
	char sCommunityID[256];
	GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID));

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(sMessage);

	System2HTTPRequest httpRequest = new System2HTTPRequest(HttpResponseCallback, "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=1BCF6A240CE2853DA6C71A70810FA2B9&steamids=%s", sCommunityID);
	httpRequest.Any = pack;
	httpRequest.GET();

	return Plugin_Handled;
}

public void HttpResponseCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	DataPack pack = request.Any;

	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());

	char sMessage[255];
	pack.ReadString(sMessage, sizeof(sMessage));

	delete pack;

	char avatar[256];
	if (success)
	{
		char[] content = new char[response.ContentLength + 1];
		response.GetContent(content, response.ContentLength + 1);

		JSON_Object obj = json_decode(content);
		JSON_Object response2 = obj.GetObject("response");
		JSON_Object players = response2.GetObject("players");
		JSON_Object zero = players.GetObject("0");

		zero.GetString("avatarfull", avatar, sizeof(avatar));

		obj.Cleanup();
		delete obj;
    }

	Menu menu = new Menu(MenuHandler_Confirm);
	menu.SetTitle("Are you sure you want to call an admin?\n(Spam calls result in bans)\nMessage: %s", sMessage);
	menu.AddItem("yes", "Yes");
	menu.AddItem("no", "No");
	PushMenuString(menu, "message", sMessage);
	PushMenuString(menu, "avatar", avatar);
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Confirm(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (param2 != 0)
				return;
			
			char sMessage[255];
			GetMenuString(menu, "message", sMessage, sizeof(sMessage));

			char avatar[256];
			GetMenuString(menu, "avatar", avatar, sizeof(avatar));
			
			DiscordWebHook hook = new DiscordWebHook("https://discordapp.com/api/webhooks/629536920397021207/sRiKkw2wukt3N0xSMEl4f1nLr5w_mpfBjZ61JcJdgc7mOuC_gZOzcJUoCV9qYfJQmFei");
			hook.SlackMode = true;
			hook.SetUsername("Admin Requests");

			char sTitle[256];
			FormatEx(sTitle, sizeof(sTitle), "Admin Request From: %N (%i)", client, VH_GetVertexID(client));

			char sHostname[64];
			FindConVar("hostname").GetString(sHostname, sizeof(sHostname));

			char sServer[64];
			FormatEx(sServer, sizeof(sServer), "(%i) %s", VH_GetServerID(), sHostname);

			int ipaddr[4];
			SteamWorks_GetPublicIP(ipaddr);

			char sServerIP[64];
			FormatEx(sServerIP, sizeof(sServerIP), "%d.%d.%d.%d:%d", ipaddr[0], ipaddr[1], ipaddr[2], ipaddr[3], FindConVar("hostport").IntValue);

			char sPassword[64];
			FindConVar("sv_password").GetString(sPassword, sizeof(sPassword));

			if (strlen(sPassword) > 0)
				Format(sPassword, sizeof(sPassword), "/%s", sPassword);

			char sConnect[256];
			Format(sConnect, sizeof(sConnect), "steam://connect/%s%s", sServerIP, sPassword);

			MessageEmbed Embed = new MessageEmbed();
			Embed.SetColor("#FF69B4");
			Embed.SetTitle(sTitle);
			Embed.SetThumb(avatar);
			Embed.AddField("Message:", sMessage, true);
			Embed.AddField("Server:", sServer, false);
			Embed.AddField("Connect:", sConnect, false);
			
			hook.Embed(Embed);
			hook.Send();
			
			delete hook;

			Vertex_SendPrint(client, "Admin request has been sent.");
			VH_SystemLog("%N has requested admin assistance.", client);
		}
		case MenuAction_End:
			delete menu;
	}
}