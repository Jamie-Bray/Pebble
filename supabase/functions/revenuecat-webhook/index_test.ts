import {
  candidateUserIdsForRevenueCatEvent,
  handler,
  mapRevenueCatEvent,
  statusForRevenueCatEvent,
} from './index.ts';

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
      expiration_at_ms: Date.UTC(2026, 6, 1),
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

Deno.test('statusForRevenueCatEvent maps cancellation with future expiry as active cancellation', () => {
  const status = statusForRevenueCatEvent({
    type: 'CANCELLATION',
    expiration_at_ms: Date.now() + 60_000,
  });

  if (status !== 'cancelled_active') {
    throw new Error(`Unexpected status: ${status}`);
  }
});
