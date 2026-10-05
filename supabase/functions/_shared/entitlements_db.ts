// Database helpers shared by the RevenueCat functions. The client is injected
// so these stay free of remote imports and can be exercised with a fake.

import {
  ACTIVE_ENTITLEMENT_STATUSES,
  type ProfileTier,
  profileTierForEntitlements,
} from './revenuecat.ts';

// deno-lint-ignore no-explicit-any
export type ServiceClient = any;

export type ClaimRow = {
  id: string;
  owner_user_id: string;
  product_id: string;
  store: string;
  purchase_token_hash: string;
  entitlement_tier: string;
  status: string;
  period_started_at: string | null;
  period_ends_at: string | null;
  updated_at: string | null;
};

const claimColumns =
  'id,owner_user_id,product_id,store,purchase_token_hash,entitlement_tier,status,period_started_at,period_ends_at,updated_at';

/**
 * Re-derives `profiles.tier` for one user from their entitlement rows and
 * writes it. `profiles.tier` is only a mirror: RLS and the app read
 * `personal_entitlements` directly. Migration 017 adds a trigger that keeps
 * the mirror in sync inside the database as well.
 */
export async function recomputeProfileTier(
  client: ServiceClient,
  userId: string,
  nowIso = new Date().toISOString(),
): Promise<{ tier: ProfileTier | null; error: { message: string } | null }> {
  const { data, error } = await client
    .from('personal_entitlements')
    .select('entitlement_tier,status,period_ends_at')
    .eq('owner_user_id', userId)
    .in('status', ACTIVE_ENTITLEMENT_STATUSES as string[]);
  if (error) return { tier: null, error };

  const tier = profileTierForEntitlements(
    data ?? [],
    new Date(nowIso).getTime(),
  );
  const { error: profileError } = await client.from('profiles').upsert({
    id: userId,
    tier,
    updated_at: nowIso,
  });
  if (profileError) return { tier: null, error: profileError };
  return { tier, error: null };
}

/** Active claim rows for one store purchase, across all owners. */
export async function findActiveClaims(
  client: ServiceClient,
  store: string,
  productId: string,
  purchaseTokenHash: string,
): Promise<{ rows: ClaimRow[]; error: { message: string } | null }> {
  const { data, error } = await client
    .from('personal_entitlements')
    .select(claimColumns)
    .eq('store', store)
    .eq('product_id', productId)
    .eq('purchase_token_hash', purchaseTokenHash)
    .in('status', ACTIVE_ENTITLEMENT_STATUSES as string[]);
  if (error) return { rows: [], error };
  return { rows: (data ?? []) as ClaimRow[], error: null };
}

/** Active premium-tier claim rows owned by any of `ownerUserIds`. */
export async function findActiveClaimsForOwners(
  client: ServiceClient,
  ownerUserIds: string[],
): Promise<{ rows: ClaimRow[]; error: { message: string } | null }> {
  if (ownerUserIds.length === 0) return { rows: [], error: null };
  const { data, error } = await client
    .from('personal_entitlements')
    .select(claimColumns)
    .in('owner_user_id', ownerUserIds)
    .in('status', ACTIVE_ENTITLEMENT_STATUSES as string[])
    .in('entitlement_tier', ['personalPremium', 'pebbleHousehold']);
  if (error) return { rows: [], error };
  return { rows: (data ?? []) as ClaimRow[], error: null };
}

/**
 * Marks one claim row expired. The status filter makes it a no-op when the row
 * was already released, so retries are idempotent.
 */
export async function expireClaim(
  client: ServiceClient,
  rowId: string,
  nowIso = new Date().toISOString(),
): Promise<{ error: { message: string } | null }> {
  const { error } = await client
    .from('personal_entitlements')
    .update({ status: 'expired', last_verified_at: nowIso, updated_at: nowIso })
    .eq('id', rowId)
    .in('status', ACTIVE_ENTITLEMENT_STATUSES as string[]);
  return { error: error ?? null };
}
