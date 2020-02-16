#if defined __vh_filters_included
	#endinput
#endif
#define __vh_filters_included

#define VH_NULLID -1

native Action VH_FilterMessage(int client, const char[] command, const char[] message);

#if !defined REQUIRE_PLUGIN
public void __pl_vh_filters_SetNTVOptional()
{
	MarkNativeAsOptional("VH_FilterMessage");
}
#endif

public SharedPlugin __pl_vh_filters =
{
	name = "vh-filters",
	file = "vh-filters.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};