#if defined __vh_settings_included
	#endinput
#endif
#define __vh_settings_included

#define TYPE_INT 0
#define TYPE_FLOAT 1
#define TYPE_STRING 2
#define TYPE_COLOR 3
#define TYPE_VECTOR2D 4
#define TYPE_VECTOR3D 5

native int VH_RegisterSetting(const char[] name, const char[] unique, int type);

#if !defined REQUIRE_PLUGIN
public void __pl_vh_settings_SetNTVOptional()
{
	MarkNativeAsOptional("VH_RegisterSetting");
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