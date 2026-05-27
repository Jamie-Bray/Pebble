import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type RevenueCatWebhook = {
  api_version?: string;
  event?: RevenueCatEvent;
};

type RevenueCatEvent = {
  id?: string;
  type?: string;
  app_user_id?: string;
  product_id?: string;
  entitlement_id?: string | null;
  entitlement_ids?: string[] | null;
  store?: string;
  transaction_id?: string | null;
  original_transaction_id?: string | null;
  purchased_at_ms?: number | null;
  expiration_at_ms?: number | null;
  event_timestamp_ms?: number | null;
  transferred_from?: string[] | null;
  transferred_to?: string[] | null;
};

type MappedEntitlement = {
  userId: string;
  productId: string;
  store: string;
  purchaseTokenHash: string;
  tier: 'personalPremium';
  status:
    | 'active'
    | 'grace'
    | 'account_hold'
    | 'paused'
    | 'cancelled_active'
    | 'expired';
  periodStartedAt: string | null;
  periodEndsAt: string | null;
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

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  let rawBody: string;
  try {
    rawBody = await req.text();
  } catch (_) {
    return json({ error: 'Invalid body' }, 400);
  }

  const expectedAuthorization =
    Deno.env.get('REVENUECAT_WEBHOOK_SECRET') ??
      Deno.env.get('REVENUECAT_WEBHOOK_AUTH');
  if (!expectedAuthorization) {
    return json({ error: 'RevenueCat webhook authorization is not configured' }, 500);
  }
  const authHeader = req.headers.get('authorization') ?? '';
  if (!(await authorizationMatches(authHeader, expectedAuthorization))) {
    return json({ error: 'Unauthorized' }, 401);
  }

  let payload: RevenueCatWebhook;
  try {
    payload = JSON.parse(rawBody);
  } catch (_) {
    return json({ error: 'Invalid JSON body' }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: 'Supabase environment is not configured' }, 500);
  }

  const event = payload.event;
  if (!event?.type) {
    return json({ error: 'RevenueCat event is required' }, 400);
  }

  const serviceClient = createClient(supabaseUrl, serviceRoleKey);
  if (event.type === 'TRANSFER') {
    await handleTransfer(serviceClient, event);
  }

  const mapped = await mapRevenueCatEvent(event);
  if (!mapped) {
    return json({ ok: true, ignored: true });
  }

  const now = new Date().toISOString();
  const existingClaim = await findExistingPurchaseClaim(
    serviceClient,
    mapped.store,
    mapped.productId,
    mapped.purchaseTokenHash,
  );
  if (existingClaim.error) {
    return json({ error: existingClaim.error.message }, 500);
  }
  if (existingClaim.ownerUserId && existingClaim.ownerUserId !== mapped.userId) {
    return json({ error: 'This store purchase is already linked to another Pebble account' }, 409);
  }

  const { error: entitlementError } = await serviceClient
    .from('personal_entitlements')
    .upsert(
      {
        owner_user_id: mapped.userId,
        product_id: mapped.productId,
        store: mapped.store,
        purchase_token_hash: mapped.purchaseTokenHash,
        entitlement_tier: mapped.tier,
        status: mapped.status,
        period_started_at: mapped.periodStartedAt,
        period_ends_at: mapped.periodEndsAt,
        last_verified_at: now,
        updated_at: now,
      },
      {
        onConflict: 'owner_user_id,store,product_id,purchase_token_hash',
      },
    );

  if (entitlementError) {
    return json({ error: entitlementError.message }, 500);
  }

  const active = isEntitlementCurrentlyActive(
    mapped.status,
    mapped.periodEndsAt,
  );
  
  let targetTier = active ? mapped.tier : 'personalFree';
  if (!active) {
    const { data: activeEntitlements, error: countError } = await serviceClient
      .from('personal_entitlements')
      .select('id')
      .eq('owner_user_id', mapped.userId)
      .in('status', ['active', 'grace', 'cancelled_active'])
      .or(`period_ends_at.is.null,period_ends_at.gt.${now}`)
      .limit(1);

    if (countError) {
      return json({ error: countError.message }, 500);
    }

    if (activeEntitlements && activeEntitlements.length > 0) {
      targetTier = mapped.tier;
    }
  }

  const { error: profileError } = await serviceClient.from('profiles').upsert({
    id: mapped.userId,
    tier: targetTier,
    updated_at: now,
  });
  if (profileError) {
    return json({ error: profileError.message }, 500);
  }

  return json({ ok: true });
});

async function findExistingPurchaseClaim(
  client: ReturnType<typeof createClient>,
  store: string,
  productId: string,
  tokenHash: string,
): Promise<
  | { ownerUserId: string | null; error: null }
  | { ownerUserId: null; error: { message: string } }
> {
  const { data, error } = await client
    .from('personal_entitlements')
    .select('owner_user_id')
    .eq('store', store)
    .eq('product_id', productId)
    .eq('purchase_token_hash', tokenHash)
    .in('status', ['active', 'grace', 'cancelled_active'])
    .maybeSingle();
  if (error) {
    return { ownerUserId: null, error };
  }
  return { ownerUserId: data?.owner_user_id ?? null, error: null };
}

export async function mapRevenueCatEvent(
  event: RevenueCatEvent,
): Promise<MappedEntitlement | null> {
  if (!hasPebblePremiumEntitlement(event)) return null;
  if (!event.app_user_id || !isUuid(event.app_user_id)) return null;

  const status = statusForRevenueCatEvent(event);
  const productId = event.product_id ?? personalPremiumEntitlementId;
  const store = normalizeStore(event.store);
  const tokenSource =
    event.original_transaction_id ??
      event.transaction_id ??
      event.id ??
      `${event.app_user_id}:${productId}:${event.event_timestamp_ms ?? ''}`;

  return {
    userId: event.app_user_id,
    productId,
    store,
    purchaseTokenHash: await sha256Hex(tokenSource),
    tier: 'personalPremium',
    status,
    periodStartedAt: isoFromMillis(event.purchased_at_ms),
    periodEndsAt: isoFromMillis(event.expiration_at_ms),
  };
}

async function handleTransfer(
  serviceClient: ReturnType<typeof createClient>,
  event: RevenueCatEvent,
) {
  const from = event.transferred_from?.filter(isUuid) ?? [];
  if (from.length === 0) return;

  const productId = event.product_id ?? personalPremiumEntitlementId;
  const store = normalizeStore(event.store);
  const now = new Date().toISOString();
  await serviceClient
    .from('personal_entitlements')
    .update({
      status: 'expired',
      last_verified_at: now,
      updated_at: now,
    })
    .eq('product_id', productId)
    .eq('store', store)
    .in('owner_user_id', from);

  for (const userId of from) {
    const { data: activeEntitlements } = await serviceClient
      .from('personal_entitlements')
      .select('id')
      .eq('owner_user_id', userId)
      .in('status', ['active', 'grace', 'cancelled_active'])
      .or(`period_ends_at.is.null,period_ends_at.gt.${now}`)
      .limit(1);

    const hasActive = activeEntitlements && activeEntitlements.length > 0;

    await serviceClient.from('profiles').upsert({
      id: userId,
      tier: hasActive ? 'personalPremium' : 'personalFree',
      updated_at: now,
    });
  }
}

function hasPebblePremiumEntitlement(event: RevenueCatEvent): boolean {
  const ids = event.entitlement_ids ?? [];
  return ids.includes(personalPremiumEntitlementId) ||
    event.entitlement_id === personalPremiumEntitlementId;
}

export function statusForRevenueCatEvent(
  event: RevenueCatEvent,
): MappedEntitlement['status'] {
  const expiresInFuture =
    event.expiration_at_ms == null || event.expiration_at_ms > Date.now();

  switch (event.type) {
    case 'INITIAL_PURCHASE':
    case 'RENEWAL':
    case 'UNCANCELLATION':
    case 'PRODUCT_CHANGE':
    case 'SUBSCRIPTION_EXTENDED':
    case 'TEMPORARY_ENTITLEMENT_GRANT':
    case 'REFUND_REVERSED':
      return expiresInFuture ? 'active' : 'expired';
    case 'CANCELLATION':
      return expiresInFuture ? 'cancelled_active' : 'expired';
    case 'BILLING_ISSUE':
      return expiresInFuture ? 'grace' : 'account_hold';
    case 'SUBSCRIPTION_PAUSED':
      return 'paused';
    case 'EXPIRATION':
    case 'REFUND':
      return 'expired';
    default:
      return expiresInFuture ? 'active' : 'expired';
  }
}

function normalizeStore(value: string | undefined): string {
  switch (value) {
    case 'APP_STORE':
      return 'appStore';
    case 'PLAY_STORE':
      return 'googlePlay';
    case 'STRIPE':
      return 'stripe';
    case 'RC_BILLING':
      return 'revenueCat';
    default:
      return value?.toLowerCase() ?? 'revenueCat';
  }
}

function isEntitlementCurrentlyActive(
  status: MappedEntitlement['status'],
  periodEndsAt: string | null,
): boolean {
  if (!['active', 'grace', 'cancelled_active'].includes(status)) {
    return false;
  }
  return periodEndsAt === null || new Date(periodEndsAt).getTime() > Date.now();
}

function isoFromMillis(value: number | null | undefined): string | null {
  return typeof value === 'number' ? new Date(value).toISOString() : null;
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

async function sha256Hex(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

async function authorizationMatches(
  actualHeader: string,
  expectedValue: string,
): Promise<boolean> {
  const actual = normalizeAuthorizationValue(actualHeader);
  const expected = normalizeAuthorizationValue(expectedValue);
  if (!actual || !expected) return false;
  return await sha256Hex(actual) === await sha256Hex(expected);
}

function normalizeAuthorizationValue(value: string): string {
  return value.replace(/^Bearer\s+/i, '').trim();
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
