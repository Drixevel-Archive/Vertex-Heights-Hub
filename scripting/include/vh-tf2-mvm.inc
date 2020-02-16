#if defined __vh_tf2_mvm_included
	#endinput
#endif
#define __vh_tf2_mvm_included

//native bool VH_IsMVM();

#if !defined REQUIRE_PLUGIN
public void __pl_vh_tf2_mvm_SetNTVOptional()
{
	//MarkNativeAsOptional("VH_IsMVM");
}
#endif

public SharedPlugin __pl_vh_tf2_mvm =
{
	name = "vh-tf2-mvm",
	file = "vh-tf2-mvm.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};