#if defined _l4d2_campaign_shop_included
    #endinput
#endif
#define _l4d2_campaign_shop_included

/** Returns the current campaign points for a connected real player. */
native int L4D2CampaignShop_GetPoints(int client);

/** Adds campaign points, respecting the shop maximum. Returns the new balance. */
native int L4D2CampaignShop_AddPoints(int client, int amount);

/** Removes campaign points, clamped at zero. Returns the new balance. */
native int L4D2CampaignShop_RemovePoints(int client, int amount);

/** Sets campaign points, clamped to 0..l4d2_campaign_shop_max_points. Returns the new balance. */
native int L4D2CampaignShop_SetPoints(int client, int points);

public SharedPlugin __pl_l4d2_campaign_shop =
{
    name = "l4d2_campaign_shop",
    file = "l4d2_campaign_shop.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_campaign_shop_SetNTVOptional()
{
    MarkNativeAsOptional("L4D2CampaignShop_GetPoints");
    MarkNativeAsOptional("L4D2CampaignShop_AddPoints");
    MarkNativeAsOptional("L4D2CampaignShop_RemovePoints");
    MarkNativeAsOptional("L4D2CampaignShop_SetPoints");
}
#endif
