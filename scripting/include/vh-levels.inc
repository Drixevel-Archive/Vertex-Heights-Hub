#if defined __vh_levels_included
	#endinput
#endif
#define __vh_levels_included

native int VH_GetLevel(int client);
native int VH_GetExperience(int client);

forward void VH_OnLevelUp(int client, int level, int experience);
forward void VH_OnExperienceGain(int client, int amount, const char[] reason, int level, int experience);

#if !defined REQUIRE_PLUGIN
public void __pl_vh_levels_SetNTVOptional()
{
	MarkNativeAsOptional("VH_GetLevel");
	MarkNativeAsOptional("VH_GetExperience");
}
#endif

public SharedPlugin __pl_vh_levels =
{
	name = "vh-levels",
	file = "vh-levels.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};