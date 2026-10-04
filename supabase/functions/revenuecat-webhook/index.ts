import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  canonicalProductId,
  DEFAULT_PERSONAL_PREMIUM_ENTITLEMENT_ID,
  type EntitlementStatus,
  eventSupersedesClaim,
  isEntitlementCurrentlyActive,
  normalizeStore,
  purchaseTokenHash,
  uuidCandidates,
} from '../_shared/revenuecat.ts';
import {
  type ClaimRow,
  expireClaim,
  findActiveClaims,
  findActiveClaimsForOwners,
  recomputeProfileTier,
  type ServiceClient,
} from '../_shared/entitlements_db.ts';
import { secretsMatch, stripBearer } from '../_shared/secrets.ts';

type RevenueCatWebhook = {
  api_version?: string;
  event?: RevenueCatEvent;
};

export type RevenueCatEvent = {
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
  purchaseKeyStable: boolean;
  tier: 'personalPremium';
  status: EntitlementStatus;
  periodStartedAt: string | null;
  periodEndsAt: string | null;
};

const personalPremiumEntitlementId =
  Deno.env.get('REVENUECAT_PERSONAL_PREMIUM_ENTITLEMENT_ID') ??
    DEFAULT_PERSONAL_PREMIUM_ENTITLEMENT_ID;

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

  const expectedAuthorization = stripBearer(
    Deno.env.get('REVENUECAT_WEBHOOK_SECRET') ??
      Deno.env.get('REVENUECAT_WEBHOOK_AUTH'),
  );
  if (!expectedAuthorization) {
    return json({ error: 'RevenueCat webhook authorization is not configured' }, 500);
  }
  const authHeader = stripBearer(req.headers.get('authorization'));
  if (!(await secretsMatch(authHeader, expectedAuthorization))) {
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
  logStructured({
    message: 'event_received',
    type: event.type,
    id: event.id,
    app_user_id: event.app_user_id,
    product_id: event.product_id,
    store: event.store,
    transferred_to: event.transferred_to,
    transferred_from: event.transferred_from,
  });

  const serviceClient = createClient(supabaseUrl, serviceRoleKey);

  // TRANSFER events carry no product, store or expiry, so they never go
  // through the generic mapping below (which would otherwise invent a
  // permanent, period-less row for the new owner).
  if (event.type === 'TRANSFER') {
    const result = await handleTransfer(serviceClient, event);
    if (result.error) return json({ error: result.error }, 500);
    return json({ ok: true, status: 'transfer_processed', ...result.summary });
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
    logStructured({
      message: 'event_ignored',
      type: event.type,
      id: event.id,
      reason:
        'no personal premium entitlement or no Supabase UUID app_user_id/transferred_to',
    });
    return json({ ok: true, ignored: true });
  }

  const now = new Date().toISOString();
  const affectedOwners = new Set<string>([mapped.userId]);

  // Other accounts still holding this purchase as active. RevenueCat is the
  // authority on who owns a purchase, so a newer event for this owner (or an
  // expiry of the purchase itself) releases those claims. A stale retry that
  // predates the other claim is acknowledged without writing anything.
  const claims = await findActiveClaims(
    serviceClient,
    mapped.store,
    mapped.productId,
    mapped.purchaseTokenHash,
  );
  if (claims.error) return json({ error: claims.error.message }, 500);
  const foreignClaims = claims.rows.filter((row) =>
    row.owner_user_id !== mapped.userId
  );
  const staleAgainst = foreignClaims.filter((row) =>
    !eventSupersedesClaim(event.event_timestamp_ms, row.updated_at)
  );
  if (staleAgainst.length > 0 && isActiveStatus(mapped.status)) {
    logStructured({
      message: 'purchase_claim_conflict',
      action_result: 'stale_event_acknowledged_no_write',
      revenuecat_event_id: event.id,
      event_type: event.type,
      mapped_user_id: mapped.userId,
      existing_owner_user_ids: staleAgainst.map((row) => row.owner_user_id),
      product_id: mapped.productId,
      store: mapped.store,
    });
    const recompute = await recomputeProfileTier(serviceClient, mapped.userId, now);
    if (recompute.error) return json({ error: recompute.error.message }, 500);
    return json({ ok: true, status: 'conflict_stale_event' });
  }
  for (const row of foreignClaims) {
    if (!eventSupersedesClaim(event.event_timestamp_ms, row.updated_at)) {
      continue;
    }
    const { error } = await expireClaim(serviceClient, row.id, now);
    if (error) return json({ error: error.message }, 500);
    affectedOwners.add(row.owner_user_id);
    logStructured({
      message: 'purchase_claim_released',
      revenuecat_event_id: event.id,
      event_type: event.type,
      released_owner_user_id: row.owner_user_id,
      new_owner_user_id: mapped.userId,
      product_id: mapped.productId,
      store: mapped.store,
    });
  }

  const upsert = await upsertClaim(serviceClient, mapped, now);
  if (upsert.error) {
    if (upsert.error.code === '23505') {
      // Lost a race with another writer for the same purchase. Acknowledge
      // so RevenueCat does not retry in a loop; the next event or sync wins.
      logStructured({
        message: 'purchase_claim_conflict',
        action_result: 'unique_violation_acknowledged',
        revenuecat_event_id: event.id,
        mapped_user_id: mapped.userId,
        product_id: mapped.productId,
        store: mapped.store,
      });
    } else {
      return json({ error: upsert.error.message }, 500);
    }
  }

  for (const userId of affectedOwners) {
    const recompute = await recomputeProfileTier(serviceClient, userId, now);
    if (recompute.error) return json({ error: recompute.error.message }, 500);
    logStructured({
      message: 'profile_tier_recomputed',
      owner_user_id: userId,
      tier: recompute.tier,
    });
  }

  logStructured({
    message: 'entitlement_mirror_updated',
    owner_user_id: mapped.userId,
    entitlement_tier: mapped.tier,
    status: mapped.status,
    product_id: mapped.productId,
    store: mapped.store,
    period_ends_at: mapped.periodEndsAt,
    purchase_key_stable: mapped.purchaseKeyStable,
  });

  return json({ ok: true });
}

async function upsertClaim(
  client: ServiceClient,
  mapped: MappedEntitlement,
  nowIso: string,
): Promise<{ error: { message: string; code?: string } | null }> {
  const { error } = await client
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
        last_verified_at: nowIso,
        updated_at: nowIso,
      },
      {
        onConflict: 'owner_user_id,store,product_id,purchase_token_hash',
      },
    );
  return { error: error ?? null };
}

export async function mapRevenueCatEvent(
  event: RevenueCatEvent,
  ownerUserId: string,
): Promise<MappedEntitlement | null> {
  if (!hasPebblePremiumEntitlement(event)) return null;

  const status = statusForRevenueCatEvent(event);
  const store = normalizeStore(event.store);
  const productId = canonicalProductId(
    event.product_id,
    null,
    personalPremiumEntitlementId,
  );
  const purchaseKey = await purchaseTokenHash({
    userId: ownerUserId,
    store,
    productId,
    originalTransactionId: event.original_transaction_id,
    transactionId: event.transaction_id,
  });

  return {
    userId: ownerUserId,
    productId,
    store,
    purchaseTokenHash: purchaseKey.hash,
    purchaseKeyStable: purchaseKey.stable,
    tier: 'personalPremium',
    status,
    periodStartedAt: isoFromMillis(event.purchased_at_ms),
    periodEndsAt: isoFromMillis(event.expiration_at_ms),
  };
}

export type TransferMove = {
  /** Row to expire on the source account. */
  expireRowId: string;
  /** Copy to create (or refresh) on the destination account, if any. */
  moveTo: Omit<ClaimRow, 'id' | 'updated_at'> | null;
};

/**
 * Pure planning step for a TRANSFER event: every active premium claim held by
 * the `transferred_from` accounts is expired, and the ones still inside their
 * paid period are re-created for the destination account. Claims written
 * after the event (a stale retry) are left alone, which together with the
 * status filter in `expireClaim` makes re-delivery a no-op.
 */
export function planTransfer(input: {
  sourceClaims: ClaimRow[];
  destinationUserId: string | null;
  eventTimestampMs: number | null | undefined;
  nowMs?: number;
}): TransferMove[] {
  const nowMs = input.nowMs ?? Date.now();
  const moves: TransferMove[] = [];
  for (const row of input.sourceClaims) {
    if (row.owner_user_id === input.destinationUserId) continue;
    if (!eventSupersedesClaim(input.eventTimestampMs, row.updated_at, nowMs)) {
      continue;
    }
    const stillPaid = isEntitlementCurrentlyActive(
      row.status,
      row.period_ends_at,
      nowMs,
    );
    moves.push({
      expireRowId: row.id,
      moveTo: input.destinationUserId && stillPaid
        ? {
          owner_user_id: input.destinationUserId,
          product_id: row.product_id,
          store: row.store,
          purchase_token_hash: row.purchase_token_hash,
          entitlement_tier: row.entitlement_tier,
          status: row.status,
          period_started_at: row.period_started_at,
          period_ends_at: row.period_ends_at,
        }
        : null,
    });
  }
  return moves;
}

async function handleTransfer(
  serviceClient: ServiceClient,
  event: RevenueCatEvent,
): Promise<{
  error: string | null;
  summary: { released: number; moved: number };
}> {
  const summary = { released: 0, moved: 0 };
  const destinationUserId = (await resolveExistingSupabaseUserIds(
    serviceClient,
    event.transferred_to ?? [],
  ))[0] ?? null;
  const from = (await resolveExistingSupabaseUserIds(
    serviceClient,
    event.transferred_from ?? [],
  )).filter((userId) => userId !== destinationUserId);

  if (from.length === 0) {
    logStructured({
      message: 'transfer_has_no_supabase_source_users',
      id: event.id,
      destination_user_id: destinationUserId,
    });
    if (destinationUserId) {
      const recompute = await recomputeProfileTier(serviceClient, destinationUserId);
      if (recompute.error) return { error: recompute.error.message, summary };
    }
    return { error: null, summary };
  }

  const sourceClaims = await findActiveClaimsForOwners(serviceClient, from);
  if (sourceClaims.error) return { error: sourceClaims.error.message, summary };

  const now = new Date().toISOString();
  const moves = planTransfer({
    sourceClaims: sourceClaims.rows,
    destinationUserId,
    eventTimestampMs: event.event_timestamp_ms,
  });

  for (const move of moves) {
    // Expire first: the partial unique index allows only one active claim per
    // purchase, so the source row must be released before the copy is made.
    const { error } = await expireClaim(serviceClient, move.expireRowId, now);
    if (error) return { error: error.message, summary };
    summary.released++;
    if (!move.moveTo) continue;
    const { error: moveError } = await serviceClient
      .from('personal_entitlements')
      .upsert(
        { ...move.moveTo, last_verified_at: now, updated_at: now },
        { onConflict: 'owner_user_id,store,product_id,purchase_token_hash' },
      );
    if (moveError) {
      if (moveError.code === '23505') {
        logStructured({
          message: 'transfer_move_conflict',
          id: event.id,
          destination_user_id: destinationUserId,
          product_id: move.moveTo.product_id,
          store: move.moveTo.store,
        });
        continue;
      }
      return { error: moveError.message, summary };
    }
    summary.moved++;
  }

  const touched = destinationUserId ? [...from, destinationUserId] : from;
  for (const userId of touched) {
    const recompute = await recomputeProfileTier(serviceClient, userId, now);
    if (recompute.error) return { error: recompute.error.message, summary };
  }

  logStructured({
    message: 'transfer_processed',
    id: event.id,
    source_user_ids: from,
    destination_user_id: destinationUserId,
    ...summary,
  });
  return { error: null, summary };
}

export function candidateUserIdsForRevenueCatEvent(
  event: RevenueCatEvent,
): string[] {
  return uuidCandidates([
    event.app_user_id,
    event.original_app_user_id,
    ...(event.aliases ?? []),
    ...(event.transferred_to ?? []),
  ]);
}

async function resolveSupabaseUserIdForRevenueCatEvent(
  serviceClient: ServiceClient,
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
  serviceClient: ServiceClient,
  values: string[],
): Promise<string[]> {
  const userIds: string[] = [];
  for (const candidate of uuidCandidates(values)) {
    if (await supabaseAuthUserExists(serviceClient, candidate)) {
      userIds.push(candidate);
    }
  }
  return userIds;
}

async function supabaseAuthUserExists(
  serviceClient: ServiceClient,
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
): EntitlementStatus {
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

function isActiveStatus(status: EntitlementStatus): boolean {
  return status === 'active' || status === 'grace' ||
    status === 'cancelled_active';
}

function isoFromMillis(value: number | null | undefined): string | null {
  return typeof value === 'number' ? new Date(value).toISOString() : null;
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
