#if defined __vh_logs_included
	#endinput
#endif
#define __vh_logs_included

native void VH_SystemLog(const char[] buffer, any ...);
native void VH_ThrowSystemLog(const char[] buffer, any ...);

#if !defined REQUIRE_PLUGIN
public void __pl_vh_logs_SetNTVOptional()
{
	MarkNativeAsOptional("VH_SystemLog");
	MarkNativeAsOptional("VH_ThrowSystemLog");
}
#endif

public SharedPlugin __pl_vh_logs =
{
	name = "vh-logs",
	file = "vh-logs.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};