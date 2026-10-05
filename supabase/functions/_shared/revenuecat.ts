// Shared, dependency-free RevenueCat <-> personal_entitlements mapping.
//
// Both `revenuecat-webhook` and `revenuecat-sync-entitlement` write rows into
// `public.personal_entitlements`. The partial unique index
// `personal_entitlements_unique_active_store_purchase` (migration 009) can only
// recognise "the same store purchase" if both writers produce the same
// (store, product_id, purchase_token_hash) triple, so every part of that triple
// is derived here and nowhere else.
//
// Keep this module free of remote imports so it can be unit tested offline.

export type EntitlementStatus =
  | 'active'
  | 'grace'
  | 'account_hold'
  | 'paused'
  | 'cancelled_active'
  | 'expired';

export type EntitlementTier = 'personalPremium' | 'pebbleHousehold';
export type ProfileTier = 'personalFree' | EntitlementTier;

/** Statuses that unlock Premium while `period_ends_at` is in the future. */
export const ACTIVE_ENTITLEMENT_STATUSES: readonly EntitlementStatus[] = [
  'active',
  'grace',
  'cancelled_active',
];

export const DEFAULT_PERSONAL_PREMIUM_ENTITLEMENT_ID = 'personal_premium';

/**
 * Canonical store name stored in `personal_entitlements.store`.
 *
 * Accepts both the webhook spelling (`PLAY_STORE`) and the REST v1 subscriber
 * spelling (`play_store`).
 */
export function normalizeStore(value: string | null | undefined): string {
  const raw = value?.trim();
  if (!raw) return 'revenueCat';
  switch (raw.toUpperCase()) {
    case 'APP_STORE':
    case 'MAC_APP_STORE':
      return 'appStore';
    case 'PLAY_STORE':
      return 'googlePlay';
    case 'STRIPE':
      return 'stripe';
    case 'RC_BILLING':
      return 'revenueCat';
    case 'AMAZON':
      return 'amazon';
    case 'PROMOTIONAL':
      return 'promotional';
    default:
      return raw.toLowerCase();
  }
}

/**
 * Canonical product id: `<subscriptionId>:<basePlanId>` for Google Play base
 * plans (which is what RevenueCat webhooks already send), the plain product id
 * everywhere else.
 *
 * The REST v1 subscriber endpoint reports Google Play products as
 * `product_identifier: "personal_premium"` plus a separate
 * `product_plan_identifier: "yearly"`; joining them here makes the sync
 * function agree with the webhook (`personal_premium:yearly`).
 */
export function canonicalProductId(
  productId: string | null | undefined,
  basePlanId: string | null | undefined,
  fallback: string,
): string {
  const product = productId?.trim();
  if (!product) return fallback;
  if (product.includes(':')) return product;
  const plan = basePlanId?.trim();
  return plan ? `${product}:${plan}` : product;
}

/**
 * Store transaction id that identifies the whole subscription, not one
 * renewal. Google Play renewal order ids are `<original order id>..<n>`, so the
 * suffix is stripped to get back to the first order id, which is what
 * RevenueCat webhooks send as `original_transaction_id`.
 */
export function canonicalTransactionId(
  store: string,
  transactionId: string | null | undefined,
): string | null {
  const id = transactionId?.trim();
  if (!id) return null;
  if (store === 'googlePlay') {
    return id.replace(/\.\.\d+$/, '');
  }
  return id;
}

/**
 * Stable per-user key used when no store transaction id is available. It is
 * deliberately independent of RevenueCat event ids, so repeated events for the
 * same purchase update one row instead of inserting a new one each time.
 */
export function fallbackPurchaseKey(
  userId: string,
  store: string,
  productId: string,
): string {
  return `revenuecat:${userId.toLowerCase()}:${store}:${productId}`;
}

/** Plain-text source of `purchase_token_hash` (hash it with sha256Hex). */
export function purchaseKeySource(input: {
  userId: string;
  store: string;
  productId: string;
  originalTransactionId?: string | null;
  transactionId?: string | null;
}): { source: string; stable: boolean } {
  const original = canonicalTransactionId(
    input.store,
    input.originalTransactionId,
  );
  if (original) return { source: original, stable: true };
  const latest = canonicalTransactionId(input.store, input.transactionId);
  // A latest-transaction id only identifies the subscription on Google Play,
  // where the renewal suffix can be stripped. On the App Store it changes on
  // every renewal, so it is not used as a purchase key there.
  if (latest && input.store === 'googlePlay') {
    return { source: latest, stable: true };
  }
  return {
    source: fallbackPurchaseKey(input.userId, input.store, input.productId),
    stable: false,
  };
}

export async function purchaseTokenHash(
  input: Parameters<typeof purchaseKeySource>[0],
): Promise<{ hash: string; stable: boolean }> {
  const { source, stable } = purchaseKeySource(input);
  return { hash: await sha256Hex(source), stable };
}

export function isEntitlementCurrentlyActive(
  status: string | null | undefined,
  periodEndsAt: string | null | undefined,
  nowMs = Date.now(),
): boolean {
  if (!ACTIVE_ENTITLEMENT_STATUSES.includes(status as EntitlementStatus)) {
    return false;
  }
  if (periodEndsAt === null || periodEndsAt === undefined) return true;
  const ends = new Date(periodEndsAt).getTime();
  return Number.isFinite(ends) && ends > nowMs;
}

export type EntitlementRowForTier = {
  entitlement_tier?: string | null;
  status?: string | null;
  period_ends_at?: string | null;
};

/**
 * The tier `profiles.tier` must mirror, derived only from entitlement rows.
 * Mirrors `public.entitled_profile_tier(uuid)` in migration 017.
 */
export function profileTierForEntitlements(
  rows: EntitlementRowForTier[],
  nowMs = Date.now(),
): ProfileTier {
  let tier: ProfileTier = 'personalFree';
  for (const row of rows) {
    if (!isEntitlementCurrentlyActive(row.status, row.period_ends_at, nowMs)) {
      continue;
    }
    if (row.entitlement_tier === 'pebbleHousehold') return 'pebbleHousehold';
    if (row.entitlement_tier === 'personalPremium') tier = 'personalPremium';
  }
  return tier;
}

/**
 * Whether an event may take over (or expire) a claim row last written at
 * `claimUpdatedAt`. Rows are written at processing time, which is always after
 * the event that wrote them, so an event older than the row is a stale retry
 * and must not override it.
 */
export function eventSupersedesClaim(
  eventTimestampMs: number | null | undefined,
  claimUpdatedAt: string | null | undefined,
  nowMs = Date.now(),
): boolean {
  const eventMs = typeof eventTimestampMs === 'number' &&
      Number.isFinite(eventTimestampMs)
    ? eventTimestampMs
    : nowMs;
  if (!claimUpdatedAt) return true;
  const claimMs = new Date(claimUpdatedAt).getTime();
  if (!Number.isFinite(claimMs)) return true;
  return eventMs >= claimMs;
}

export function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

/** Lower-cased, de-duplicated UUID-shaped ids, in input order. */
export function uuidCandidates(
  values: ReadonlyArray<string | null | undefined>,
): string[] {
  const unique = new Set<string>();
  for (const value of values) {
    const trimmed = value?.trim();
    if (trimmed && isUuid(trimmed)) unique.add(trimmed.toLowerCase());
  }
  return [...unique];
}

export async function sha256Hex(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}
