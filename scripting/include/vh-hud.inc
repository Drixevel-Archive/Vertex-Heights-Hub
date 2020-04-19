#if defined __vh_hud_included
	#endinput
#endif
#define __vh_hud_included

native void VH_SyncHud(int client);

#if !defined REQUIRE_PLUGIN
public void __pl_vh_hud_SetNTVOptional()
{
	MarkNativeAsOptional("VH_SyncHud");
}
#endif

public SharedPlugin __pl_vh_hud =
{
	name = "vh-hud",
	file = "vh-hud.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};