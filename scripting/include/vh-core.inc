#if defined __vh_core_included
	#endinput
#endif
#define __vh_core_included

#define VH_NULLID -1

native void VH_OpenVertexHub(int client);
native int VH_GetVertexID(int client);
native int VH_GetClientByVID(int vid);
native int VH_GetServerID();
native void VH_GetServerSecretKey(char[] buffer, int size);
native int VH_GetServerData(const char[] key, char[] buffer = "", int size = 0);
native bool VH_IsInSteamGroup(int client);

forward void VH_OnHubOpen(int client, Menu menu);
forward void VH_OnVIPFeatures(int client, Panel panel);
forward void VH_OnSynced(int client, int vid);
forward void VH_OnParseServerData(int serverid, const char[] gamemode, const char[] region, const char[] hoster);

#if !defined REQUIRE_PLUGIN
public void __pl_vh_core_SetNTVOptional()
{
	MarkNativeAsOptional("VH_OpenVertexHub");
	MarkNativeAsOptional("VH_GetVertexID");
	MarkNativeAsOptional("VH_GetClientByVID");
	MarkNativeAsOptional("VH_GetServerID");
	MarkNativeAsOptional("VH_GetServerSecretKey");
	MarkNativeAsOptional("VH_GetServerData");
	MarkNativeAsOptional("VH_IsInSteamGroup");
}
#endif

public SharedPlugin __pl_vh_core =
{
	name = "vh-core",
	file = "vh-core.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};