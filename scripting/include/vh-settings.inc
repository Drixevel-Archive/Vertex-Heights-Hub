#if defined __vh_settings_included
	#endinput
#endif
#define __vh_settings_included

#if !defined REQUIRE_PLUGIN
public void __pl_vh_settings_SetNTVOptional()
{
	//MarkNativeAsOptional("VH_RegisterSetting");
}
#endif

public SharedPlugin __pl_vh_settings =
{
	name = "vh-settings",
	file = "vh-settings.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};