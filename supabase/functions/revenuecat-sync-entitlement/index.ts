import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  canonicalProductId,
  DEFAULT_PERSONAL_PREMIUM_ENTITLEMENT_ID,
  normalizeStore,
  purchaseTokenHash,
} from "../_shared/revenuecat.ts";
import {
  expireClaim,
  findActiveClaims,
  recomputeProfileTier,
  type ServiceClient,
} from "../_shared/entitlements_db.ts";

export type RevenueCatSubscriberResponse = {
  subscriber?: {
    entitlements?: Record<string, RevenueCatSubscriberEntitlement>;
    subscriptions?: Record<string, RevenueCatSubscriberSubscription>;
  };
};

type RevenueCatSubscriberEntitlement = {
  product_identifier?: string;
  product_plan_identifier?: string | null;
  purchase_date?: string | null;
  expires_date?: string | null;
};

type RevenueCatSubscriberSubscription = {
  store?: string;
  purchase_date?: string | null;
  expires_date?: string | null;
  original_transaction_id?: string | null;
  store_transaction_id?: string | null;
  product_plan_identifier?: string | null;
};

const personalPremiumEntitlementId =
  Deno.env.get("REVENUECAT_PERSONAL_PREMIUM_ENTITLEMENT_ID") ??
    DEFAULT_PERSONAL_PREMIUM_ENTITLEMENT_ID;

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

export async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const revenueCatApiKey = Deno.env.get("REVENUECAT_REST_API_KEY") ??
    Deno.env.get("REVENUECAT_SECRET_API_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !revenueCatApiKey) {
    return json({
      error: "RevenueCat sync is not configured",
      status: "config_error",
    }, 500);
  }

  const authorization = req.headers.get("authorization") ?? "";
  const jwt = authorization.replace(/^Bearer\s+/i, "").trim();
  if (!jwt || jwt === anonKey) {
    return json({
      error: "Missing user authorization",
      status: "unauthenticated",
    }, 401);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(
    jwt,
  );
  if (userError || !userData.user) {
    return json({
      error: "Invalid user authorization",
      status: "unauthenticated",
    }, 401);
  }
  if (isAnonymousUser(userData.user)) {
    return json({
      error: "Create or sign in to an account before verifying purchases",
      status: "unauthenticated",
    }, 403);
  }

  const userId = userData.user.id;
  logStructured({
    message: "reconciliation_requested",
    owner_user_id: userId,
    entitlement_id: personalPremiumEntitlementId,
  });

  const subscriber = await fetchRevenueCatSubscriber(userId, revenueCatApiKey);
  if (!subscriber.ok) {
    logStructured({
      message: "reconciliation_revenuecat_unavailable",
      owner_user_id: userId,
      revenuecat_status: subscriber.status,
      error: subscriber.error,
    });
    return json({
      error: subscriber.error,
      status: "revenuecat_unavailable",
    }, subscriber.status);
  }

  const serviceClient = createClient(supabaseUrl, serviceRoleKey);
  const now = new Date().toISOString();

  const active = activePersonalEntitlement(
    subscriber.data,
    personalPremiumEntitlementId,
  );
  if (!active) {
    const debug = subscriberDebugSummary(
      subscriber.data,
      personalPremiumEntitlementId,
    );
    // Keep the profiles.tier mirror honest even when nothing is written: a
    // lapsed purchase whose EXPIRATION webhook never landed downgrades here.
    const recompute = await recomputeProfileTier(serviceClient, userId, now);
    logStructured({
      message: "reconciliation_no_active_entitlement",
      owner_user_id: userId,
      entitlement_id: personalPremiumEntitlementId,
      revenuecat_debug: debug,
      profile_tier: recompute.tier,
      profile_tier_error: recompute.error?.message,
    });
    return json({
      error:
        "RevenueCat does not show an active Personal Premium entitlement for this account",
      status: "no_active_revenuecat_entitlement",
      revenueCat: debug,
    }, 403);
  }

  const purchaseKey = await purchaseTokenHash({
    userId,
    store: active.store,
    productId: active.productId,
    originalTransactionId: active.originalTransactionId,
    transactionId: active.storeTransactionId,
  });
  let tokenHash = purchaseKey.hash;
  if (!purchaseKey.stable) {
    // No store transaction id in the REST response: reuse the row the webhook
    // already wrote for this user and product instead of adding a duplicate.
    const reused = await latestOwnClaimHash(
      serviceClient,
      userId,
      active.store,
      active.productId,
    );
    if (reused) tokenHash = reused;
  }

  // RevenueCat has just confirmed, server to server, that this user owns the
  // entitlement right now, so any other account still holding the same
  // purchase as active is stale (a transfer whose webhook never landed).
  const claims = await findActiveClaims(
    serviceClient,
    active.store,
    active.productId,
    tokenHash,
  );
  if (claims.error) {
    return json({
      error: claims.error.message,
      status: "supabase_write_failed",
    }, 500);
  }
  const releasedOwners: string[] = [];
  for (const row of claims.rows) {
    if (row.owner_user_id === userId) continue;
    const { error } = await expireClaim(serviceClient, row.id, now);
    if (error) {
      return json({ error: error.message, status: "supabase_write_failed" }, 500);
    }
    releasedOwners.push(row.owner_user_id);
    logStructured({
      message: "purchase_claim_released",
      released_owner_user_id: row.owner_user_id,
      new_owner_user_id: userId,
      product_id: active.productId,
      store: active.store,
    });
  }

  const { data: entitlement, error: entitlementError } = await serviceClient
    .from("personal_entitlements")
    .upsert(
      {
        owner_user_id: userId,
        product_id: active.productId,
        store: active.store,
        purchase_token_hash: tokenHash,
        entitlement_tier: "personalPremium",
        status: "active",
        period_started_at: active.purchaseDate,
        period_ends_at: active.expiresDate,
        last_verified_at: now,
        updated_at: now,
      },
      {
        onConflict: "owner_user_id,store,product_id,purchase_token_hash",
      },
    )
    .select(
      "entitlement_tier,status,product_id,period_ends_at,last_verified_at",
    )
    .single();

  if (entitlementError) {
    logStructured({
      message: "reconciliation_entitlement_write_failed",
      owner_user_id: userId,
      error: entitlementError.message,
      code: entitlementError.code,
    });
    return json({
      error: entitlementError.message,
      status: entitlementError.code === "23505"
        ? "purchase_claim_conflict"
        : "supabase_write_failed",
    }, entitlementError.code === "23505" ? 409 : 500);
  }

  for (const ownerId of [userId, ...releasedOwners]) {
    const recompute = await recomputeProfileTier(serviceClient, ownerId, now);
    if (recompute.error) {
      logStructured({
        message: "reconciliation_profile_write_failed",
        owner_user_id: ownerId,
        error: recompute.error.message,
      });
      return json({
        error: recompute.error.message,
        status: "supabase_write_failed",
      }, 500);
    }
  }

  logStructured({
    message: "reconciliation_mirrored_entitlement",
    owner_user_id: userId,
    product_id: active.productId,
    store: active.store,
    period_ends_at: active.expiresDate,
    purchase_key_stable: purchaseKey.stable,
  });

  return json({
    ok: true,
    mirrored: true,
    entitlement: {
      tier: entitlement.entitlement_tier,
      status: entitlement.status,
      productId: entitlement.product_id,
      periodEndsAt: entitlement.period_ends_at,
      lastVerifiedAt: entitlement.last_verified_at,
    },
  });
}

async function latestOwnClaimHash(
  client: ServiceClient,
  userId: string,
  store: string,
  productId: string,
): Promise<string | null> {
  const { data, error } = await client
    .from("personal_entitlements")
    .select("purchase_token_hash")
    .eq("owner_user_id", userId)
    .eq("store", store)
    .eq("product_id", productId)
    .order("updated_at", { ascending: false })
    .limit(1);
  if (error || !data || data.length === 0) return null;
  return data[0].purchase_token_hash ?? null;
}

async function fetchRevenueCatSubscriber(
  appUserId: string,
  apiKey: string,
): Promise<
  | { ok: true; data: RevenueCatSubscriberResponse }
  | { ok: false; status: number; error: string }
> {
  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${
      encodeURIComponent(appUserId)
    }`,
    {
      headers: {
        authorization: `Bearer ${apiKey}`,
        accept: "application/json",
      },
    },
  );
  const body = await response.json().catch(() => null);
  if (!response.ok) {
    return {
      ok: false,
      status: response.status >= 500 ? 502 : response.status,
      error: body?.message ??
        body?.error ??
        "RevenueCat subscriber lookup failed",
    };
  }
  return { ok: true, data: body as RevenueCatSubscriberResponse };
}

export type ActivePersonalEntitlement = {
  productId: string;
  store: string;
  purchaseDate: string | null;
  expiresDate: string | null;
  originalTransactionId: string | null;
  storeTransactionId: string | null;
};

/**
 * Pure mapping from a REST v1 subscriber response to the canonical
 * (store, product_id) used by the webhook as well.
 */
export function activePersonalEntitlement(
  response: RevenueCatSubscriberResponse,
  entitlementId: string,
  nowMs = Date.now(),
): ActivePersonalEntitlement | null {
  const entitlement = response.subscriber?.entitlements?.[entitlementId];
  if (!entitlement?.product_identifier) {
    return null;
  }
  if (
    entitlement.expires_date !== null &&
    entitlement.expires_date !== undefined &&
    new Date(entitlement.expires_date).getTime() <= nowMs
  ) {
    return null;
  }

  const subscriptions = response.subscriber?.subscriptions ?? {};
  const basePlan = entitlement.product_plan_identifier ?? null;
  const fullProductId = canonicalProductId(
    entitlement.product_identifier,
    basePlan,
    entitlement.product_identifier,
  );
  const subscription = subscriptions[fullProductId] ??
    subscriptions[entitlement.product_identifier];
  const productId = canonicalProductId(
    entitlement.product_identifier,
    basePlan ?? subscription?.product_plan_identifier ?? null,
    entitlement.product_identifier,
  );
  return {
    productId,
    store: normalizeStore(subscription?.store),
    purchaseDate: entitlement.purchase_date ?? subscription?.purchase_date ??
      null,
    expiresDate: entitlement.expires_date ?? subscription?.expires_date ?? null,
    originalTransactionId: subscription?.original_transaction_id ?? null,
    storeTransactionId: subscription?.store_transaction_id ?? null,
  };
}

function subscriberDebugSummary(
  response: RevenueCatSubscriberResponse,
  entitlementId: string,
): {
  queriedEntitlementId: string;
  entitlementIdsReturned: string[];
  activeSubscriptionProductIds: string[];
  personalPremiumExists: boolean;
  personalPremiumExpired: boolean | null;
  personalPremiumExpiresDate: string | null;
} {
  const entitlements = response.subscriber?.entitlements ?? {};
  const subscriptions = response.subscriber?.subscriptions ?? {};
  const personalPremium = entitlements[entitlementId];
  const now = Date.now();
  const expiresDate = personalPremium?.expires_date ?? null;
  const expired = personalPremium === undefined
    ? null
    : expiresDate === null
    ? false
    : new Date(expiresDate).getTime() <= now;
  const activeSubscriptionProductIds = Object.entries(subscriptions)
    .filter(([, subscription]) => {
      const expires = subscription.expires_date;
      return !expires || new Date(expires).getTime() > now;
    })
    .map(([productId]) => productId);

  return {
    queriedEntitlementId: entitlementId,
    entitlementIdsReturned: Object.keys(entitlements),
    activeSubscriptionProductIds,
    personalPremiumExists: personalPremium !== undefined,
    personalPremiumExpired: expired,
    personalPremiumExpiresDate: expiresDate,
  };
}

function isAnonymousUser(
  user: { is_anonymous?: boolean; app_metadata?: Record<string, unknown> },
): boolean {
  return user.is_anonymous === true ||
    user.app_metadata?.provider === "anonymous";
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
    },
  });
}

function logStructured(fields: Record<string, unknown>) {
  console.log(
    JSON.stringify({
      scope: "revenuecat-sync-entitlement",
      ...fields,
    }),
  );
}

if (import.meta.main) {
  serve(handler);
}
