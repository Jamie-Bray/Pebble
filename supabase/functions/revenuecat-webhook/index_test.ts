import {
  candidateUserIdsForRevenueCatEvent,
  handler,
  mapRevenueCatEvent,
  planTransfer,
  statusForRevenueCatEvent,
} from './index.ts';
import type { ClaimRow } from '../_shared/entitlements_db.ts';
import { sha256Hex } from '../_shared/revenuecat.ts';

Deno.test('handler rejects invalid webhook secrets before any entitlement work', async () => {
  Deno.env.set('REVENUECAT_WEBHOOK_SECRET', 'expected-secret');
  const response = await handler(
    new Request('https://example.test/revenuecat-webhook', {
      method: 'POST',
      headers: { authorization: 'Bearer wrong-secret' },
      body: JSON.stringify({ event: { type: 'INITIAL_PURCHASE' } }),
    }),
  );

  if (response.status !== 401) {
    throw new Error(`Expected 401, got ${response.status}`);
  }
});

Deno.test('handler rejects malformed JSON with a verified secret', async () => {
  Deno.env.set('REVENUECAT_WEBHOOK_SECRET', 'expected-secret');
  const response = await handler(
    new Request('https://example.test/revenuecat-webhook', {
      method: 'POST',
      headers: { authorization: 'Bearer expected-secret' },
      body: '{not-json',
    }),
  );

  if (response.status !== 400) {
    throw new Error(`Expected 400, got ${response.status}`);
  }
});

Deno.test('handler refuses to run when the webhook secret is blank', async () => {
  Deno.env.set('REVENUECAT_WEBHOOK_SECRET', '   ');
  const response = await handler(
    new Request('https://example.test/revenuecat-webhook', {
      method: 'POST',
      headers: { authorization: 'Bearer ' },
      body: JSON.stringify({ event: { type: 'INITIAL_PURCHASE' } }),
    }),
  );
  Deno.env.set('REVENUECAT_WEBHOOK_SECRET', 'expected-secret');
  if (response.status !== 500) {
    throw new Error(`Expected 500, got ${response.status}`);
  }
});

Deno.test('candidateUserIdsForRevenueCatEvent keeps UUID-shaped candidates only', () => {
  const candidates = candidateUserIdsForRevenueCatEvent({
    type: 'INITIAL_PURCHASE',
    app_user_id: '6bf74839-d74d-4e9d-bf72-6a1d25b39099',
    original_app_user_id: '$RCAnonymousID:not-a-uuid',
    aliases: [
      'not-a-user',
      'A413CDBE-3DEE-4EB5-8B59-B31DD23F4BED',
      '6bf74839-d74d-4e9d-bf72-6a1d25b39099',
    ],
    transferred_to: ['bad', '8cfae236-9a16-4805-a65e-777f6517fcb0'],
  });

  if (JSON.stringify(candidates) !== JSON.stringify([
    '6bf74839-d74d-4e9d-bf72-6a1d25b39099',
    'a413cdbe-3dee-4eb5-8b59-b31dd23f4bed',
    '8cfae236-9a16-4805-a65e-777f6517fcb0',
  ])) {
    throw new Error(`Unexpected candidates: ${JSON.stringify(candidates)}`);
  }
});

Deno.test('mapRevenueCatEvent uses the verified Supabase owner, not app_user_id', async () => {
  const mapped = await mapRevenueCatEvent(
    {
      type: 'INITIAL_PURCHASE',
      app_user_id: '6bf74839-d74d-4e9d-bf72-6a1d25b39099',
      entitlement_ids: ['personal_premium'],
      product_id: 'personal_premium:yearly',
      store: 'PLAY_STORE',
      transaction_id: 'GPA.123',
      original_transaction_id: 'GPA.123',
      purchased_at_ms: Date.UTC(2026, 5, 1),
      expiration_at_ms: Date.now() + 86_400_000,
    },
    'a413cdbe-3dee-4eb5-8b59-b31dd23f4bed',
  );

  if (!mapped) {
    throw new Error('Expected mapped entitlement');
  }
  if (mapped.userId !== 'a413cdbe-3dee-4eb5-8b59-b31dd23f4bed') {
    throw new Error(`Unexpected mapped owner: ${mapped.userId}`);
  }
  if (mapped.store !== 'googlePlay') {
    throw new Error(`Unexpected store: ${mapped.store}`);
  }
  if (mapped.status !== 'active') {
    throw new Error(`Unexpected status: ${mapped.status}`);
  }
});

Deno.test('mapRevenueCatEvent keeps the existing webhook row key (product:baseplan + original order id)', async () => {
  const mapped = await mapRevenueCatEvent(
    {
      type: 'RENEWAL',
      entitlement_ids: ['personal_premium'],
      product_id: 'personal_premium:yearly',
      store: 'PLAY_STORE',
      transaction_id: 'GPA.1111-2222-3333-44444..1',
      original_transaction_id: 'GPA.1111-2222-3333-44444',
      expiration_at_ms: Date.now() + 86_400_000,
    },
    'a413cdbe-3dee-4eb5-8b59-b31dd23f4bed',
  );
  if (!mapped) throw new Error('Expected mapped entitlement');
  if (mapped.productId !== 'personal_premium:yearly') {
    throw new Error(`Unexpected product: ${mapped.productId}`);
  }
  if (mapped.purchaseTokenHash !== await sha256Hex('GPA.1111-2222-3333-44444')) {
    throw new Error('Purchase key changed for existing webhook rows');
  }
});

Deno.test('mapRevenueCatEvent without transaction ids is stable across events', async () => {
  const base = {
    entitlement_ids: ['personal_premium'],
    product_id: 'personal_premium:yearly',
    store: 'PLAY_STORE',
    expiration_at_ms: Date.now() + 86_400_000,
  };
  const a = await mapRevenueCatEvent(
    { ...base, type: 'RENEWAL', id: 'evt-1' },
    'a413cdbe-3dee-4eb5-8b59-b31dd23f4bed',
  );
  const b = await mapRevenueCatEvent(
    { ...base, type: 'CANCELLATION', id: 'evt-2' },
    'a413cdbe-3dee-4eb5-8b59-b31dd23f4bed',
  );
  if (!a || !b || a.purchaseTokenHash !== b.purchaseTokenHash) {
    throw new Error('Expected one purchase key for both events');
  }
});

Deno.test('statusForRevenueCatEvent maps cancellation with future expiry as active cancellation', () => {
  const status = statusForRevenueCatEvent({
    type: 'CANCELLATION',
    expiration_at_ms: Date.now() + 60_000,
  });

  if (status !== 'cancelled_active') {
    throw new Error(`Unexpected status: ${status}`);
  }
});

Deno.test('statusForRevenueCatEvent maps EXPIRATION to expired regardless of expiry', () => {
  const status = statusForRevenueCatEvent({
    type: 'EXPIRATION',
    expiration_at_ms: Date.now() + 60_000,
  });
  if (status !== 'expired') throw new Error(`Unexpected status: ${status}`);
});

const A = '6bf74839-d74d-4e9d-bf72-6a1d25b39099';
const B = 'a413cdbe-3dee-4eb5-8b59-b31dd23f4bed';
const T0 = Date.UTC(2026, 7, 12, 10);

function claim(overrides: Partial<ClaimRow>): ClaimRow {
  return {
    id: 'row-1',
    owner_user_id: A,
    product_id: 'personal_premium:yearly',
    store: 'googlePlay',
    purchase_token_hash: 'h1',
    entitlement_tier: 'personalPremium',
    status: 'active',
    period_started_at: new Date(T0 - 86_400_000).toISOString(),
    period_ends_at: new Date(T0 + 86_400_000).toISOString(),
    updated_at: new Date(T0 - 60_000).toISOString(),
    ...overrides,
  };
}

Deno.test('planTransfer moves every active claim regardless of product id', () => {
  const moves = planTransfer({
    sourceClaims: [
      claim({ id: 'webhook-row', product_id: 'personal_premium:yearly' }),
      claim({ id: 'sync-row', product_id: 'personal_premium', purchase_token_hash: 'h2' }),
    ],
    destinationUserId: B,
    eventTimestampMs: T0,
    nowMs: T0,
  });
  if (moves.length !== 2) throw new Error(`Expected 2 moves, got ${moves.length}`);
  for (const move of moves) {
    if (move.moveTo?.owner_user_id !== B) throw new Error('Expected move to B');
  }
  if (moves[0].moveTo?.period_ends_at !== claim({}).period_ends_at) {
    throw new Error('Period end must be preserved');
  }
});

Deno.test('planTransfer expires lapsed claims without recreating them', () => {
  const moves = planTransfer({
    sourceClaims: [claim({ period_ends_at: new Date(T0 - 1).toISOString() })],
    destinationUserId: B,
    eventTimestampMs: T0,
    nowMs: T0,
  });
  if (moves.length !== 1 || moves[0].moveTo !== null) {
    throw new Error(`Unexpected plan: ${JSON.stringify(moves)}`);
  }
});

Deno.test('planTransfer is a no-op for stale retries and already-moved claims', () => {
  const stale = planTransfer({
    // Claim was rewritten after the transfer event happened.
    sourceClaims: [claim({ updated_at: new Date(T0 + 60_000).toISOString() })],
    destinationUserId: B,
    eventTimestampMs: T0,
    nowMs: T0 + 120_000,
  });
  const alreadyMoved = planTransfer({
    sourceClaims: [claim({ owner_user_id: B })],
    destinationUserId: B,
    eventTimestampMs: T0,
    nowMs: T0,
  });
  if (stale.length !== 0 || alreadyMoved.length !== 0) {
    throw new Error('Expected no moves');
  }
});

Deno.test('planTransfer with no destination only expires source claims', () => {
  const moves = planTransfer({
    sourceClaims: [claim({})],
    destinationUserId: null,
    eventTimestampMs: T0,
    nowMs: T0,
  });
  if (moves.length !== 1 || moves[0].moveTo !== null) {
    throw new Error(`Unexpected plan: ${JSON.stringify(moves)}`);
  }
});
