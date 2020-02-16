#if defined __vh_bans_included
	#endinput
#endif
#define __vh_bans_included

native void VH_OpenBansMenu(int client);

#if !defined REQUIRE_PLUGIN
public void __pl_vh_bans_SetNTVOptional()
{
	MarkNativeAsOptional("VH_OpenBansMenu");
}
#endif

public SharedPlugin __pl_vh_bans =
{
	name = "vh-bans",
	file = "vh-bans.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};