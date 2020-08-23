#if defined __vh_store_included
	#endinput
#endif
#define __vh_store_included

native int VH_GetCredits(int client);
native void VH_SetCredits(int client, int value);
native void VH_AddCredits(int client, int value);
native bool VH_RemoveCredits(int client, int value, bool safe = true);
native bool VH_PurchaseItem(int client, int item);
native void VH_GiveItem(int client, int item);
native void VH_OpenStoreMenu(int client);
native void VH_OpenShopMenu(int client);
native void VH_OpenInventoryMenu(int client);

native bool VH_GetEquipped(int client, const char[] category, int slot, char[] item, int size);
native bool VH_GetItemData(const char[] item, char[] data, int size);

forward Action VH_OnItemPurchase(int client, int categoryid, int itemid);
forward void VH_OnItemPurchased(int client, int categoryid, int itemid);
forward Action VH_OnItemGive(int client, int categoryid, int itemid, int giver);
forward void VH_OnItemGiven(int client, int categoryid, int itemid, int giver);
forward Action VH_OnItemEquip(int client, int categoryid, int itemid, bool safe);
forward void VH_OnItemEquipped(int client, int categoryid, int itemid, bool safe);

#if !defined REQUIRE_PLUGIN
public void __pl_vh_store_SetNTVOptional()
{
	MarkNativeAsOptional("VH_GetCredits");
	MarkNativeAsOptional("VH_SetCredits");
	MarkNativeAsOptional("VH_AddCredits");
	MarkNativeAsOptional("VH_RemoveCredits");
	MarkNativeAsOptional("VH_PurchaseItem");
	MarkNativeAsOptional("VH_GiveItem");
	MarkNativeAsOptional("VH_OpenStoreMenu");
	MarkNativeAsOptional("VH_OpenShopMenu");
	MarkNativeAsOptional("VH_OpenInventoryMenu");

	MarkNativeAsOptional("VH_GetEquipped");
	MarkNativeAsOptional("VH_GetItemData");
}
#endif

public SharedPlugin __pl_vh_store =
{
	name = "vh-store",
	file = "vh-store.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};