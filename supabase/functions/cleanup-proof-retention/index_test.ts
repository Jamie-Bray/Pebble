import { handler } from './index.ts';
import { isGuidanceAudioKey, planCleanup, type UsageRow } from './plan.ts';

const NOW = Date.UTC(2026, 9, 3);
const DAY = 86_400_000;
const UID = '6bf74839-d74d-4e9d-bf72-6a1d25b39099';

function iso(ms: number) {
  return new Date(ms).toISOString();
}

function row(overrides: Partial<UsageRow>): UsageRow {
  return {
    id: 'r1',
    object_key: `users/${UID}/routine_session/s1/p1.webp`,
    entity_type: 'routine_session',
    created_at: iso(NOW - 30 * DAY),
    expires_at: iso(NOW - 9 * DAY),
    deleted_at: null,
    ...overrides,
  };
}

Deno.test('handler fails closed when the secret is unset or blank', async () => {
  for (const value of [undefined, '', '   ']) {
    if (value === undefined) Deno.env.delete('CLEANUP_PROOF_RETENTION_SECRET');
    else Deno.env.set('CLEANUP_PROOF_RETENTION_SECRET', value);
    const response = await handler(
      new Request('https://example.test/cleanup-proof-retention', {
        method: 'POST',
        headers: { 'x-cleanup-secret': '' },
      }),
    );
    if (response.status !== 503) {
      throw new Error(`Expected 503 for ${JSON.stringify(value)}, got ${response.status}`);
    }
  }
});

Deno.test('handler rejects a wrong or missing secret', async () => {
  Deno.env.set('CLEANUP_PROOF_RETENTION_SECRET', 'expected');
  const attempts: Record<string, string>[] = [
    {},
    { 'x-cleanup-secret': 'nope' },
    { 'x-cleanup-secret': 'expected2' },
  ];
  for (const headers of attempts) {
    const response = await handler(
      new Request('https://example.test/cleanup-proof-retention', {
        method: 'POST',
        headers,
      }),
    );
    if (response.status !== 401) {
      throw new Error(`Expected 401, got ${response.status}`);
    }
  }
});

Deno.test('isGuidanceAudioKey matches only users/<uid>/guidance_audio/...', () => {
  const cases: [string, boolean][] = [
    [`users/${UID}/guidance_audio/clip.wav`, true],
    [`users/${UID}/guidance_audio/nested/clip.wav`, true],
    [`users/${UID}/routine_session/s/guidance_audio.webp`, false],
    [`users/${UID}/guidance_audio`, false],
    [`guidance_audio/${UID}/clip.wav`, false],
  ];
  for (const [key, expected] of cases) {
    if (isGuidanceAudioKey(key) !== expected) throw new Error(`Wrong result for ${key}`);
  }
});

Deno.test('planCleanup removes expired proofs and old orphans', () => {
  const plan = planCleanup(
    [row({})],
    [
      { key: row({}).object_key, createdAt: iso(NOW - 30 * DAY), updatedAt: null },
      { key: `users/${UID}/x/y/orphan.webp`, createdAt: iso(NOW - 40 * DAY), updatedAt: null },
      { key: `users/${UID}/x/y/fresh-orphan.webp`, createdAt: iso(NOW - DAY), updatedAt: null },
    ],
    NOW,
  );
  if (JSON.stringify(plan.keysToRemove) !== JSON.stringify([
    row({}).object_key,
    `users/${UID}/x/y/orphan.webp`,
  ])) {
    throw new Error(`Unexpected keys: ${JSON.stringify(plan.keysToRemove)}`);
  }
  if (JSON.stringify(plan.metadataIdsToDelete) !== JSON.stringify(['r1'])) {
    throw new Error(`Unexpected ids: ${JSON.stringify(plan.metadataIdsToDelete)}`);
  }
});

Deno.test('planCleanup never touches guidance audio by key or by entity type', () => {
  const audioKey = `users/${UID}/guidance_audio/clip.wav`;
  const oddKey = `users/${UID}/legacy/clip.wav`;
  const plan = planCleanup(
    [
      row({ id: 'a1', object_key: audioKey, entity_type: 'guidance_audio', created_at: iso(NOW - 400 * DAY), expires_at: iso(NOW + 3000 * DAY) }),
      // Typed as guidance audio but stored outside the folder.
      row({ id: 'a2', object_key: oddKey, entity_type: 'guidance_audio' }),
      // Under the folder but with no metadata at all (orphan).
      row({ id: 'a3', object_key: `users/${UID}/guidance_audio/missing.wav`, entity_type: null }),
    ],
    [
      { key: audioKey, createdAt: iso(NOW - 400 * DAY), updatedAt: null },
      { key: oddKey, createdAt: iso(NOW - 400 * DAY), updatedAt: null },
      { key: `users/${UID}/guidance_audio/orphan.wav`, createdAt: iso(NOW - 400 * DAY), updatedAt: null },
    ],
    NOW,
  );
  if (plan.keysToRemove.length !== 0 || plan.metadataIdsToDelete.length !== 0) {
    throw new Error(`Guidance audio was scheduled for deletion: ${JSON.stringify(plan)}`);
  }
});
