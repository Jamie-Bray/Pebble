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
  original_app_user_id?: string;
  aliases?: string[] | null;
  product_id?: string;
  entitlement_id?: string | null;
  entitlement_ids?: string[] | null;
  environment?: string;
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

type SupabaseServiceClient = any;

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
  console.log(
    JSON.stringify({
      scope: 'revenuecat-webhook',
      message: 'event_received',
      type: event.type,
      id: event.id,
      app_user_id: event.app_user_id,
      product_id: event.product_id,
      store: event.store,
      transferred_to: event.transferred_to,
      transferred_from: event.transferred_from,
    }),
  );

  const serviceClient = createClient(supabaseUrl, serviceRoleKey);
  if (event.type === 'TRANSFER') {
    await handleTransfer(serviceClient, event);
  }

  const ownerUserId = await resolveSupabaseUserIdForRevenueCatEvent(
    serviceClient,
    event,
  );
  if (!ownerUserId && hasPebblePremiumEntitlement(event)) {
    logStructured({
      message: 'pending_unmatched_entitlement',
      reason: 'no_matching_supabase_auth_user',
      event_type: event.type,
      revenuecat_event_id: event.id,
      app_user_id: event.app_user_id,
      original_app_user_id: event.original_app_user_id,
      aliases: event.aliases,
      transferred_to: event.transferred_to,
      transaction_id: event.transaction_id,
      original_transaction_id: event.original_transaction_id,
      product_id: event.product_id,
      entitlement_ids: event.entitlement_ids,
      store: event.store,
      environment: event.environment,
      action_result: 'accepted_unmatched_no_entitlement_write',
    });
    return json({
      ok: true,
      status: 'unmatched_user',
      message:
        'RevenueCat event accepted but no matching Supabase auth user was found. No entitlement row written.',
    });
  }

  const mapped = ownerUserId === null
    ? null
    : await mapRevenueCatEvent(event, ownerUserId);
  if (!mapped) {
    console.log(
      JSON.stringify({
        scope: 'revenuecat-webhook',
        message: 'event_ignored',
        type: event.type,
        id: event.id,
        reason:
          'no personal premium entitlement or no Supabase UUID app_user_id/transferred_to',
      }),
    );
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
    console.log(
      JSON.stringify({
        scope: 'revenuecat-webhook',
        message: 'purchase_claim_conflict',
        mapped_user_id: mapped.userId,
        existing_owner_user_id: existingClaim.ownerUserId,
        product_id: mapped.productId,
        store: mapped.store,
      }),
    );
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
  console.log(
    JSON.stringify({
      scope: 'revenuecat-webhook',
      message: 'entitlement_mirror_updated',
      owner_user_id: mapped.userId,
      entitlement_tier: mapped.tier,
      status: mapped.status,
      product_id: mapped.productId,
      store: mapped.store,
      period_ends_at: mapped.periodEndsAt,
    }),
  );

  return json({ ok: true });
}

async function findExistingPurchaseClaim(
  client: SupabaseServiceClient,
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
  ownerUserId: string,
): Promise<MappedEntitlement | null> {
  if (!hasPebblePremiumEntitlement(event)) return null;

  const status = statusForRevenueCatEvent(event);
  const productId = event.product_id ?? personalPremiumEntitlementId;
  const store = normalizeStore(event.store);
  const tokenSource =
    event.original_transaction_id ??
      event.transaction_id ??
      event.id ??
      `${event.app_user_id}:${productId}:${event.event_timestamp_ms ?? ''}`;

  return {
    userId: ownerUserId,
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
  serviceClient: SupabaseServiceClient,
  event: RevenueCatEvent,
) {
  const from = await resolveExistingSupabaseUserIds(
    serviceClient,
    event.transferred_from ?? [],
  );
  if (from.length === 0) {
    console.log(
      JSON.stringify({
        scope: 'revenuecat-webhook',
        message: 'transfer_has_no_supabase_source_users',
        id: event.id,
      }),
    );
    return;
  }

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

export function candidateUserIdsForRevenueCatEvent(
  event: RevenueCatEvent,
): string[] {
  const candidates = [
    event.app_user_id,
    event.original_app_user_id,
    ...(event.aliases ?? []),
    ...(event.transferred_to ?? []),
  ];
  const unique = new Set<string>();
  for (const candidate of candidates) {
    const trimmed = candidate?.trim();
    if (trimmed && isUuid(trimmed)) {
      unique.add(trimmed.toLowerCase());
    }
  }
  return [...unique];
}

async function resolveSupabaseUserIdForRevenueCatEvent(
  serviceClient: SupabaseServiceClient,
  event: RevenueCatEvent,
): Promise<string | null> {
  const candidates = candidateUserIdsForRevenueCatEvent(event);
  logStructured({
    message: 'candidate_user_ids_extracted',
    event_type: event.type,
    revenuecat_event_id: event.id,
    candidate_user_ids: candidates,
  });
  for (const candidate of candidates) {
    if (await supabaseAuthUserExists(serviceClient, candidate)) {
      logStructured({
        message: 'candidate_user_exists',
        event_type: event.type,
        revenuecat_event_id: event.id,
        chosen_owner_user_id: candidate,
      });
      return candidate;
    }
    logStructured({
      message: 'candidate_user_missing',
      event_type: event.type,
      revenuecat_event_id: event.id,
      candidate_user_id: candidate,
    });
  }
  return null;
}

async function resolveExistingSupabaseUserIds(
  serviceClient: SupabaseServiceClient,
  values: string[],
): Promise<string[]> {
  const userIds: string[] = [];
  for (const candidate of values) {
    const trimmed = candidate.trim().toLowerCase();
    if (!isUuid(trimmed)) continue;
    if (await supabaseAuthUserExists(serviceClient, trimmed)) {
      userIds.push(trimmed);
    }
  }
  return userIds;
}

async function supabaseAuthUserExists(
  serviceClient: SupabaseServiceClient,
  userId: string,
): Promise<boolean> {
  const { data, error } = await serviceClient.auth.admin.getUserById(userId);
  return !error && data.user !== null;
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

function logStructured(fields: Record<string, unknown>) {
  console.log(
    JSON.stringify({
      scope: 'revenuecat-webhook',
      ...fields,
    }),
  );
}

if (import.meta.main) {
  serve(handler);
}
