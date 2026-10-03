import {
  canonicalProductId,
  canonicalTransactionId,
  eventSupersedesClaim,
  isEntitlementCurrentlyActive,
  normalizeStore,
  profileTierForEntitlements,
  purchaseKeySource,
  uuidCandidates,
} from './revenuecat.ts';
import { secretsMatch, stripBearer } from './secrets.ts';

function assertEquals(actual: unknown, expected: unknown, label = '') {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${label} expected ${e}, got ${a}`);
}

const USER = '6bf74839-d74d-4e9d-bf72-6a1d25b39099';
const NOW = Date.UTC(2026, 9, 3);

Deno.test('normalizeStore agrees for webhook and REST spellings', () => {
  for (const [a, b] of [
    ['PLAY_STORE', 'play_store'],
    ['APP_STORE', 'app_store'],
    ['MAC_APP_STORE', 'mac_app_store'],
    ['STRIPE', 'stripe'],
    ['RC_BILLING', 'rc_billing'],
    ['PROMOTIONAL', 'promotional'],
  ]) {
    assertEquals(normalizeStore(a), normalizeStore(b), `${a}/${b}`);
  }
  assertEquals(normalizeStore('PLAY_STORE'), 'googlePlay');
  assertEquals(normalizeStore('app_store'), 'appStore');
  assertEquals(normalizeStore(undefined), 'revenueCat');
  assertEquals(normalizeStore('  '), 'revenueCat');
});

Deno.test('canonicalProductId joins Google base plans and keeps webhook ids', () => {
  assertEquals(
    canonicalProductId('personal_premium', 'yearly', 'x'),
    'personal_premium:yearly',
  );
  assertEquals(
    canonicalProductId('personal_premium:yearly', 'yearly', 'x'),
    'personal_premium:yearly',
  );
  assertEquals(
    canonicalProductId('pebble_premium_yearly', null, 'x'),
    'pebble_premium_yearly',
  );
  assertEquals(canonicalProductId(undefined, 'yearly', 'fallback'), 'fallback');
});

Deno.test('canonicalTransactionId strips Google renewal suffix only', () => {
  assertEquals(
    canonicalTransactionId('googlePlay', 'GPA.1234-5678-9012-34567..3'),
    'GPA.1234-5678-9012-34567',
  );
  assertEquals(
    canonicalTransactionId('googlePlay', 'GPA.1234-5678-9012-34567'),
    'GPA.1234-5678-9012-34567',
  );
  assertEquals(canonicalTransactionId('appStore', '2000000..1'), '2000000..1');
  assertEquals(canonicalTransactionId('googlePlay', ''), null);
});

Deno.test('purchaseKeySource: webhook original id and REST latest id agree on Google Play', () => {
  const fromWebhook = purchaseKeySource({
    userId: USER,
    store: 'googlePlay',
    productId: 'personal_premium:yearly',
    originalTransactionId: 'GPA.1111-2222-3333-44444',
    transactionId: 'GPA.1111-2222-3333-44444..2',
  });
  const fromRest = purchaseKeySource({
    userId: USER,
    store: 'googlePlay',
    productId: 'personal_premium:yearly',
    originalTransactionId: null,
    transactionId: 'GPA.1111-2222-3333-44444..2',
  });
  assertEquals(fromWebhook, fromRest);
  assertEquals(fromWebhook.stable, true);
});

Deno.test('purchaseKeySource falls back to a stable per-user key, never an event id', () => {
  const a = purchaseKeySource({
    userId: USER.toUpperCase(),
    store: 'appStore',
    productId: 'p',
    transactionId: 'latest-renewal-id',
  });
  assertEquals(a, {
    source: `revenuecat:${USER}:appStore:p`,
    stable: false,
  });
});

Deno.test('isEntitlementCurrentlyActive honours status and period end', () => {
  const future = new Date(NOW + 1000).toISOString();
  const past = new Date(NOW - 1000).toISOString();
  assertEquals(isEntitlementCurrentlyActive('active', future, NOW), true);
  assertEquals(isEntitlementCurrentlyActive('cancelled_active', future, NOW), true);
  assertEquals(isEntitlementCurrentlyActive('grace', null, NOW), true);
  assertEquals(isEntitlementCurrentlyActive('active', past, NOW), false);
  assertEquals(isEntitlementCurrentlyActive('expired', future, NOW), false);
  assertEquals(isEntitlementCurrentlyActive('account_hold', future, NOW), false);
  assertEquals(isEntitlementCurrentlyActive('active', 'not-a-date', NOW), false);
});

Deno.test('profileTierForEntitlements downgrades lapsed "active" rows to free', () => {
  // The production state from the audit: rows still say active, but every
  // period ended on 12 Aug.
  const lapsed = new Date(Date.UTC(2026, 7, 12)).toISOString();
  assertEquals(
    profileTierForEntitlements([
      { entitlement_tier: 'personalPremium', status: 'active', period_ends_at: lapsed },
      { entitlement_tier: 'personalPremium', status: 'expired', period_ends_at: lapsed },
    ], NOW),
    'personalFree',
  );
  const future = new Date(NOW + 86_400_000).toISOString();
  assertEquals(
    profileTierForEntitlements([
      { entitlement_tier: 'personalPremium', status: 'cancelled_active', period_ends_at: future },
    ], NOW),
    'personalPremium',
  );
  assertEquals(
    profileTierForEntitlements([
      { entitlement_tier: 'personalPremium', status: 'active', period_ends_at: future },
      { entitlement_tier: 'pebbleHousehold', status: 'active', period_ends_at: future },
    ], NOW),
    'pebbleHousehold',
  );
  assertEquals(profileTierForEntitlements([], NOW), 'personalFree');
});

Deno.test('eventSupersedesClaim rejects stale retries', () => {
  const rowWritten = new Date(NOW).toISOString();
  assertEquals(eventSupersedesClaim(NOW + 1, rowWritten, NOW), true);
  assertEquals(eventSupersedesClaim(NOW, rowWritten, NOW), true);
  assertEquals(eventSupersedesClaim(NOW - 60_000, rowWritten, NOW), false);
  assertEquals(eventSupersedesClaim(null, rowWritten, NOW), true);
  assertEquals(eventSupersedesClaim(NOW - 60_000, null, NOW), true);
});

Deno.test('uuidCandidates keeps UUIDs only, lower-cased and de-duplicated', () => {
  assertEquals(
    uuidCandidates([
      USER,
      '$RCAnonymousID:abc',
      USER.toUpperCase(),
      null,
      ' a413cdbe-3dee-4eb5-8b59-b31dd23f4bed ',
    ]),
    [USER, 'a413cdbe-3dee-4eb5-8b59-b31dd23f4bed'],
  );
});

Deno.test('secretsMatch fails closed and compares exactly', async () => {
  assertEquals(await secretsMatch('abc', 'abc'), true);
  assertEquals(await secretsMatch('abc', 'abd'), false);
  assertEquals(await secretsMatch('abc', 'abcd'), false);
  assertEquals(await secretsMatch('', ''), false);
  assertEquals(await secretsMatch('anything', undefined), false);
  assertEquals(await secretsMatch('anything', '   '), false);
  assertEquals(await secretsMatch(undefined, 'abc'), false);
  assertEquals(stripBearer('Bearer  token '), 'token');
  assertEquals(stripBearer(null), '');
});
