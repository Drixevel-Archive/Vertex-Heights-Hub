#if defined __vh_permissions_included
	#endinput
#endif
#define __vh_permissions_included

#define VH_NULLADMGRP -1

native void VH_OpenPermissionsMenu(int client);
native int VH_GetAdmGroup(int client);

forward void VH_OnPermissionsParsed(int client, int admgroup);

#if !defined REQUIRE_PLUGIN
public void __pl_vh_permissions_SetNTVOptional()
{
	MarkNativeAsOptional("VH_OpenPermissionsMenu");
	MarkNativeAsOptional("VH_GetAdmGroup");
}
#endif

public SharedPlugin __pl_vh_permissions =
{
	name = "vh-permissions",
	file = "vh-permissions.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};