import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type RevenueCatSubscriberResponse = {
  subscriber?: {
    entitlements?: Record<string, RevenueCatSubscriberEntitlement>;
    subscriptions?: Record<string, RevenueCatSubscriberSubscription>;
  };
};

type RevenueCatSubscriberEntitlement = {
  product_identifier?: string;
  purchase_date?: string | null;
  expires_date?: string | null;
};

type RevenueCatSubscriberSubscription = {
  store?: string;
  purchase_date?: string | null;
  expires_date?: string | null;
  original_transaction_id?: string | null;
};

const personalPremiumEntitlementId =
  Deno.env.get('REVENUECAT_PERSONAL_PREMIUM_ENTITLEMENT_ID') ??
    'personal_premium';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers':
    'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

export async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const revenueCatApiKey =
    Deno.env.get('REVENUECAT_REST_API_KEY') ??
      Deno.env.get('REVENUECAT_SECRET_API_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !revenueCatApiKey) {
    return json({ error: 'RevenueCat sync is not configured' }, 500);
  }

  const authorization = req.headers.get('authorization') ?? '';
  const jwt = authorization.replace(/^Bearer\s+/i, '').trim();
  if (!jwt || jwt === anonKey) {
    return json({ error: 'Missing user authorization' }, 401);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(jwt);
  if (userError || !userData.user) {
    return json({ error: 'Invalid user authorization' }, 401);
  }
  if (isAnonymousUser(userData.user)) {
    return json({ error: 'Create or sign in to an account before verifying purchases' }, 403);
  }

  const userId = userData.user.id;
  logStructured({
    message: 'reconciliation_requested',
    owner_user_id: userId,
    entitlement_id: personalPremiumEntitlementId,
  });

  const subscriber = await fetchRevenueCatSubscriber(userId, revenueCatApiKey);
  if (!subscriber.ok) {
    return json({ error: subscriber.error }, subscriber.status);
  }

  const active = activePersonalEntitlement(subscriber.data);
  if (!active) {
    logStructured({
      message: 'reconciliation_no_active_entitlement',
      owner_user_id: userId,
      entitlement_id: personalPremiumEntitlementId,
    });
    return json({
      error: 'RevenueCat does not show an active Personal Premium entitlement for this account',
      status: 'no_active_revenuecat_entitlement',
    }, 403);
  }

  const now = new Date().toISOString();
  const serviceClient = createClient(supabaseUrl, serviceRoleKey);
  const purchaseTokenHash = await sha256Hex(
    active.originalTransactionId ??
      `revenuecat:${userId}:${active.productId}:${personalPremiumEntitlementId}`,
  );
  const { data: entitlement, error: entitlementError } = await serviceClient
    .from('personal_entitlements')
    .upsert(
      {
        owner_user_id: userId,
        product_id: active.productId,
        store: active.store,
        purchase_token_hash: purchaseTokenHash,
        entitlement_tier: 'personalPremium',
        status: 'active',
        period_started_at: active.purchaseDate,
        period_ends_at: active.expiresDate,
        last_verified_at: now,
        updated_at: now,
      },
      {
        onConflict: 'owner_user_id,store,product_id,purchase_token_hash',
      },
    )
    .select('entitlement_tier,status,product_id,period_ends_at,last_verified_at')
    .single();

  if (entitlementError) {
    return json({ error: entitlementError.message }, 500);
  }

  const { error: profileError } = await serviceClient.from('profiles').upsert({
    id: userId,
    tier: 'personalPremium',
    updated_at: now,
  });
  if (profileError) {
    return json({ error: profileError.message }, 500);
  }

  logStructured({
    message: 'reconciliation_mirrored_entitlement',
    owner_user_id: userId,
    product_id: active.productId,
    store: active.store,
    period_ends_at: active.expiresDate,
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

async function fetchRevenueCatSubscriber(
  appUserId: string,
  apiKey: string,
): Promise<
  | { ok: true; data: RevenueCatSubscriberResponse }
  | { ok: false; status: number; error: string }
> {
  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
    {
      headers: {
        authorization: `Bearer ${apiKey}`,
        accept: 'application/json',
      },
    },
  );
  const body = await response.json().catch(() => null);
  if (!response.ok) {
    return {
      ok: false,
      status: response.status >= 500 ? 502 : response.status,
      error:
        body?.message ??
        body?.error ??
        'RevenueCat subscriber lookup failed',
    };
  }
  return { ok: true, data: body as RevenueCatSubscriberResponse };
}

function activePersonalEntitlement(
  response: RevenueCatSubscriberResponse,
): {
  productId: string;
  store: string;
  purchaseDate: string | null;
  expiresDate: string | null;
  originalTransactionId: string | null;
} | null {
  const entitlement =
    response.subscriber?.entitlements?.[personalPremiumEntitlementId];
  if (!entitlement?.product_identifier) {
    return null;
  }
  if (entitlement.expires_date !== null &&
      entitlement.expires_date !== undefined &&
      new Date(entitlement.expires_date).getTime() <= Date.now()) {
    return null;
  }

  const subscription =
    response.subscriber?.subscriptions?.[entitlement.product_identifier];
  return {
    productId: entitlement.product_identifier,
    store: normalizeStore(subscription?.store),
    purchaseDate: entitlement.purchase_date ?? subscription?.purchase_date ?? null,
    expiresDate: entitlement.expires_date ?? subscription?.expires_date ?? null,
    originalTransactionId: subscription?.original_transaction_id ?? null,
  };
}

function normalizeStore(value: string | undefined): string {
  switch (value) {
    case 'app_store':
    case 'APP_STORE':
      return 'appStore';
    case 'play_store':
    case 'PLAY_STORE':
      return 'googlePlay';
    case 'stripe':
    case 'STRIPE':
      return 'stripe';
    default:
      return value?.toLowerCase() ?? 'revenueCat';
  }
}

function isAnonymousUser(user: { is_anonymous?: boolean; app_metadata?: Record<string, unknown> }): boolean {
  return user.is_anonymous === true || user.app_metadata?.provider === 'anonymous';
}

async function sha256Hex(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'content-type': 'application/json',
    },
  });
}

function logStructured(fields: Record<string, unknown>) {
  console.log(
    JSON.stringify({
      scope: 'revenuecat-sync-entitlement',
      ...fields,
    }),
  );
}

if (import.meta.main) {
  serve(handler);
}
