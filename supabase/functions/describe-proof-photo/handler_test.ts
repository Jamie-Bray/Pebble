// Tests for describe-proof-photo against an in-memory store and a mocked
// fetch. No real provider call is ever made.

import { AI_PHOTO_CONSENT_VERSION } from '../_shared/ai_photo.ts';
import { type AiPhotoStore, createAiPhotoHandler, type Reservation } from './handler.ts';
import { AI_PHOTO_MODEL, anthropicDescriber } from './provider.ts';

function assert(condition: unknown, label: string): asserts condition {
  if (!condition) throw new Error(label);
}

function jpegBase64(bytes = 300): string {
  const data = new Uint8Array(bytes).fill(0x41);
  data.set([0xff, 0xd8, 0xff, 0xe0]);
  let binary = '';
  for (const b of data) binary += String.fromCharCode(b);
  return btoa(binary);
}

const USER = { id: 'user-a', email: 'jamie@example.com' };

/** Mirrors public.reserve_ai_photo_description. */
class FakeAiStore implements AiPhotoStore {
  paused = false;
  premium = new Set<string>([USER.id]);
  consents = new Map<string, { version: string; withdrawn: boolean; routineKey: string | null }>();
  keys = new Map<string, Set<string>>();
  monthCount = 0;
  failing = false;

  isPaused() {
    if (this.failing) return Promise.reject(new Error('database'));
    return Promise.resolve(this.paused);
  }
  hasActiveEntitlement(userId: string) {
    return Promise.resolve(this.premium.has(userId));
  }
  hasCurrentConsent(userId: string, version: string) {
    const c = this.consents.get(userId);
    return Promise.resolve(!!c && !c.withdrawn && c.version === version);
  }
  recordConsent(row: { userId: string; version: string; routineKey: string | null }) {
    this.consents.set(row.userId, { version: row.version, withdrawn: false, routineKey: row.routineKey });
    return Promise.resolve();
  }
  withdrawConsent(userId: string) {
    const c = this.consents.get(userId);
    if (c) c.withdrawn = true;
    return Promise.resolve();
  }
  reserve(input: { userId: string; idempotencyKey: string; dailyLimit: number; monthlyLimit: number }): Promise<Reservation> {
    const used = this.keys.get(input.userId) ?? new Set<string>();
    if (used.has(input.idempotencyKey)) return Promise.resolve('duplicate');
    if (used.size >= input.dailyLimit) return Promise.resolve('daily_limit');
    if (this.monthCount >= input.monthlyLimit) return Promise.resolve('budget_exhausted');
    this.monthCount += 1;
    used.add(input.idempotencyKey);
    this.keys.set(input.userId, used);
    return Promise.resolve('ok');
  }
}

type FetchStep = Response | Error | (() => Promise<Response>);

function anthropicReply(payload: unknown, stopReason = 'end_turn'): Response {
  return new Response(JSON.stringify({
    id: 'msg_test',
    type: 'message',
    role: 'assistant',
    model: AI_PHOTO_MODEL,
    stop_reason: stopReason,
    content: [{ type: 'text', text: typeof payload === 'string' ? payload : JSON.stringify(payload) }],
  }), { status: 200, headers: { 'content-type': 'application/json' } });
}

const GOOD = { clarity: 'clear', description: 'A white door with the handle pointing up.' };
const IMAGE = jpegBase64(600);

function setup(steps: FetchStep[] = [anthropicReply(GOOD)], options: { enabled?: boolean; apiKey?: string | null; daily?: number; monthly?: number } = {}) {
  const store = new FakeAiStore();
  store.consents.set(USER.id, { version: AI_PHOTO_CONSENT_VERSION, withdrawn: false, routineKey: 'local:1' });
  const calls: { url: string; headers: Headers; body: string }[] = [];
  const logs: string[] = [];
  const fakeFetch = ((url: string, init: RequestInit) => {
    calls.push({ url: String(url), headers: new Headers(init.headers), body: String(init.body) });
    const step = steps.shift() ?? anthropicReply(GOOD);
    if (step instanceof Error) return Promise.reject(step);
    return typeof step === 'function' ? step() : Promise.resolve(step);
  }) as typeof fetch;
  let enabled = options.enabled ?? true;
  const handler = createAiPhotoHandler({
    enabled: () => enabled,
    limits: { dailyPerUser: options.daily ?? 20, monthlyRequests: options.monthly ?? 5000 },
    store,
    authenticate: (req) => Promise.resolve(req.headers.get('x-test-user') === 'a' ? USER : null),
    describe: options.apiKey === null ? null : anthropicDescriber(options.apiKey ?? 'test-key', fakeFetch, { timeoutMs: 50, retryDelayMs: 1 }),
    log: (fields) => logs.push(JSON.stringify(fields)),
  });
  const call = async (method: string, body?: unknown, user = 'a') => {
    const res = await handler(new Request('https://f.example/describe-proof-photo', {
      method,
      headers: { 'x-test-user': user, 'content-type': 'application/json' },
      body: body === undefined ? undefined : typeof body === 'string' ? body : JSON.stringify(body),
    }));
    return { status: res.status, body: await res.json() };
  };
  const describe = (extra: Record<string, unknown> = {}, user = 'a') =>
    call('POST', { action: 'describe', idempotencyKey: 'photo-0001', imageBase64: IMAGE, ...extra }, user);
  return { store, calls, logs, call, describe, setEnabled: (value: boolean) => { enabled = value; } };
}

Deno.test('describes a photo: image, step title and fixed prompt go to the provider', async () => {
  const t = setup();
  const label = 'Check "front door" handle';
  const res = await t.describe({ stepLabel: label });
  assert(res.status === 200 && res.body.described === true, 'described');
  assert(res.body.description === GOOD.description, 'description returned');
  assert(t.calls.length === 1 && t.calls[0].url === 'https://api.anthropic.com/v1/messages', 'one provider call');
  assert(t.calls[0].headers.get('x-api-key') === 'test-key' && t.calls[0].headers.get('anthropic-version') === '2023-06-01', 'headers');
  const sent = JSON.parse(t.calls[0].body);
  assert(sent.model === 'claude-haiku-4-5' && sent.max_tokens === 200, 'model and small max_tokens');
  assert(sent.output_config.format.type === 'json_schema', 'constrained JSON requested');
  const schema = sent.output_config.format.schema;
  assert(schema.additionalProperties === false && schema.required.includes('clarity') && schema.required.includes('description'), 'both fields required');
  assert(JSON.stringify(schema.properties.clarity.enum) === JSON.stringify(['clear', 'partly_unclear', 'cannot_tell']), 'only supported clarity values');
  assert(sent.messages[0].content[0].source.media_type === 'image/jpeg' && sent.messages[0].content[0].source.data === IMAGE, 'image sent');
  assert(sent.messages[0].content[1].text.includes(JSON.stringify(label)), 'title quoted as untrusted context');
  assert(sent.system.includes('Never assume the expected object'), 'context must not override image');
  assert(!t.logs.join('').includes(label), 'title never logged');
  assert(!t.calls[0].body.includes(USER.id) && !t.calls[0].body.includes('jamie@') && !t.calls[0].body.includes('local:1'), 'no account or routine details');
  assert(t.store.monthCount === 1, 'counted once');
});

Deno.test('invalid step context is rejected without spending allowance or calling provider', async () => {
  for (const stepLabel of [42, {}, 'x'.repeat(1001)]) {
    const t = setup();
    const res = await t.describe({ stepLabel });
    assert(res.status === 400 && res.body.code === 'stepLabel', 'bad context rejected');
    assert(t.store.monthCount === 0 && t.calls.length === 0, 'no allowance or provider call');
  }
});

Deno.test('feature switch: off by secret, by missing key, by database pause, or when the pause cannot be read', async () => {
  for (const make of [
    () => setup([], { enabled: false }),
    () => setup([], { apiKey: null }),
    () => { const t = setup(); t.store.paused = true; return t; },
    () => { const t = setup(); t.store.failing = true; return t; },
  ]) {
    const t = make();
    assert((await t.call('GET')).body.enabled === false, 'status says off');
    const res = await t.describe();
    assert(res.body.described === false && res.body.reason === 'featureOff', 'describe refused');
    const consent = await t.call('POST', { action: 'consent', consentVersion: AI_PHOTO_CONSENT_VERSION });
    assert(consent.body.consented === false && consent.body.reason === 'featureOff', 'consent refused');
    assert(t.calls.length === 0 && t.store.monthCount === 0, 'no provider call, nothing counted');
  }
  const on = setup();
  assert((await on.call('GET')).body.enabled === true, 'status says on');
  on.setEnabled(false);
  assert((await on.describe()).body.reason === 'featureOff', 'switching off applies to the next request');
});

Deno.test('refuses without sign-in, Personal Premium or a current consent, before any provider call', async () => {
  const t = setup();
  assert((await t.describe({}, 'nobody')).status === 401, 'signed out');

  t.store.premium.delete(USER.id);
  assert((await t.describe()).body.reason === 'noActiveEntitlement', 'no premium');
  t.store.premium.add(USER.id);

  t.store.consents.delete(USER.id);
  assert((await t.describe()).body.reason === 'noConsent', 'never consented');
  t.store.consents.set(USER.id, { version: '2020-01-01', withdrawn: false, routineKey: null });
  assert((await t.describe()).body.reason === 'noConsent', 'consent to older wording');
  t.store.consents.set(USER.id, { version: AI_PHOTO_CONSENT_VERSION, withdrawn: true, routineKey: null });
  assert((await t.describe()).body.reason === 'noConsent', 'withdrawn consent');

  assert(t.calls.length === 0 && t.store.monthCount === 0, 'provider never called, nothing counted');
});

Deno.test('consent: recorded on the server, needs Premium and the current wording; withdrawal stops descriptions at once', async () => {
  const t = setup();
  t.store.consents.clear();
  const stale = await t.call('POST', { action: 'consent', consentVersion: '2020-01-01' });
  assert(stale.status === 409 && t.store.consents.size === 0, 'old wording refused');
  t.store.premium.delete(USER.id);
  assert((await t.call('POST', { action: 'consent', consentVersion: AI_PHOTO_CONSENT_VERSION })).body.reason === 'noActiveEntitlement', 'needs premium');
  t.store.premium.add(USER.id);
  assert((await t.call('POST', { action: 'consent', consentVersion: AI_PHOTO_CONSENT_VERSION }, 'nobody')).status === 401, 'needs sign-in');

  const ok = await t.call('POST', { action: 'consent', consentVersion: AI_PHOTO_CONSENT_VERSION, routineKey: 'local:7', appVersion: '1.0.0+35' });
  assert(ok.body.consented === true && t.store.consents.get(USER.id)?.routineKey === 'local:7', 'recorded');
  assert((await t.describe()).body.described === true, 'described after consent');

  // Withdrawal works even when the feature is off and Premium has ended.
  t.setEnabled(false);
  t.store.premium.delete(USER.id);
  assert((await t.call('POST', { action: 'withdraw' })).body.withdrawn === true, 'withdrawn');
  t.setEnabled(true);
  t.store.premium.add(USER.id);
  assert((await t.describe({ idempotencyKey: 'photo-0002' })).body.reason === 'noConsent', 'no description after withdrawal');
  assert(t.calls.length === 1, 'no second provider call');
});

Deno.test('request validation: bad input is refused before anything is counted', async () => {
  const t = setup();
  assert((await t.call('POST', 'not json')).status === 400, 'bad JSON');
  assert((await t.call('POST', { action: 'explode' })).status === 400, 'unknown action');
  assert((await t.call('PUT', {})).status === 405, 'method');
  assert((await t.describe({ idempotencyKey: 'x' })).status === 400, 'bad idempotency key');
  assert((await t.describe({ imageBase64: undefined })).body.code === 'imageMissing', 'no image');
  assert((await t.describe({ imageBase64: btoa('GIF89a' + 'A'.repeat(300)) })).body.code === 'imageNotJpeg', 'not a JPEG');
  const big = await t.describe({ imageBase64: jpegBase64(1_500_003) });
  assert(big.status === 413 && big.body.code === 'imageTooLarge', 'over 1.5 MB');
  assert(t.calls.length === 0 && t.store.monthCount === 0, 'nothing sent, nothing counted');
});

Deno.test('idempotency: the same photo key is sent to the provider and counted once', async () => {
  const t = setup();
  const [first, second] = await Promise.all([t.describe(), t.describe()]);
  const outcomes = [first.body, second.body];
  assert(outcomes.filter((b) => b.described === true).length === 1, 'one description');
  assert(outcomes.filter((b) => b.reason === 'duplicate').length === 1, 'one duplicate');
  assert((await t.describe()).body.reason === 'duplicate', 'later retry also refused');
  assert(t.calls.length === 1 && t.store.monthCount === 1, 'one provider call, counted once');
});

Deno.test('daily allowance and monthly budget stop provider calls when used up', async () => {
  const daily = setup([], { daily: 3 });
  for (let i = 0; i < 3; i++) assert((await daily.describe({ idempotencyKey: `photo-000${i}` })).body.described, `allowed ${i}`);
  assert((await daily.describe({ idempotencyKey: 'photo-0009' })).body.reason === 'dailyLimit', 'fourth refused');
  assert(daily.calls.length === 3, 'no call past the allowance');

  const monthly = setup([], { monthly: 2 });
  monthly.store.premium.add('user-b');
  for (let i = 0; i < 2; i++) assert((await monthly.describe({ idempotencyKey: `photo-000${i}` })).body.described, `allowed ${i}`);
  assert((await monthly.describe({ idempotencyKey: 'photo-0009' })).body.reason === 'budgetExhausted', 'budget refused');
  assert(monthly.calls.length === 2 && monthly.store.monthCount === 2, 'no call past the budget');
});

Deno.test('a failed or timed-out provider call is not refunded and returns a clean result', async () => {
  const timeout = setup([() => new Promise<Response>((_, reject) => setTimeout(() => reject(new DOMException('timed out', 'TimeoutError')), 5))]);
  const res = await timeout.describe();
  assert(res.status === 200 && res.body.described === false && res.body.reason === 'couldNotDescribe', 'clean failure');
  assert(timeout.calls.length === 1, 'a timeout is not retried');
  assert(timeout.store.monthCount === 1, 'reservation kept');
  assert((await timeout.describe()).body.reason === 'duplicate' && timeout.calls.length === 1, 'app retry is not billed again');

  const network = setup([new TypeError('connection reset')]);
  assert((await network.describe()).body.reason === 'couldNotDescribe' && network.calls.length === 1, 'network error, no retry');
});

Deno.test('provider errors: one retry for 429 and 5xx only', async () => {
  const error = (status: number) => new Response(JSON.stringify({ type: 'error', error: { type: 'x', message: 'secret detail' } }), { status });
  const overloaded = setup([error(529), anthropicReply(GOOD)]);
  assert((await overloaded.describe()).body.described === true && overloaded.calls.length === 2, 'retried once after 529');
  assert(overloaded.store.monthCount === 1, 'still one reservation');

  const stillDown = setup([error(500), error(500), anthropicReply(GOOD)]);
  const down = await stillDown.describe();
  assert(down.body.reason === 'couldNotDescribe' && stillDown.calls.length === 2, 'at most one retry');
  assert(!JSON.stringify(down.body).includes('secret detail'), 'provider text not passed on');

  for (const status of [400, 401, 403, 404, 413]) {
    const t = setup([error(status), anthropicReply(GOOD)]);
    assert((await t.describe()).body.reason === 'couldNotDescribe' && t.calls.length === 1, `${status} not retried`);
  }
  const limited = setup([error(429), anthropicReply(GOOD)]);
  assert((await limited.describe()).body.described === true && limited.calls.length === 2, '429 retried');
});

Deno.test('malformed, unsure, verdict or cut-short replies all become "could not describe"', async () => {
  const replies: Response[] = [
    anthropicReply('Sure! Here is a description: a white door.'),
    anthropicReply({ clarity: 'cannot_tell', description: 'The photo is too dark to make out the object.' }),
    anthropicReply({ clarity: 'clear', description: 'The front door is locked.' }),
    anthropicReply({ clarity: 'clear', description: 'The hob is switched off.' }),
    anthropicReply({ clarity: 'clear', description: 'word '.repeat(90) }),
    anthropicReply({ clarity: 'clear', description: 'a '.repeat(36).trim() }),
    anthropicReply({ clarity: 'clear' }),
    anthropicReply(GOOD, 'max_tokens'),
    anthropicReply(GOOD, 'refusal'),
    new Response('<html>bad gateway</html>', { status: 200 }),
    new Response(JSON.stringify({ content: [] , stop_reason: 'end_turn' }), { status: 200 }),
  ];
  for (let i = 0; i < replies.length; i++) {
    const t = setup([replies[i]]);
    const res = await t.describe();
    assert(res.status === 200 || res.status === 500, `status ${i}`);
    assert(res.body.described !== true && res.body.description === undefined, `reply ${i} must not produce a description`);
  }
});

Deno.test('logs carry outcome codes only: never image bytes, the description or the key', async () => {
  const runs = [
    setup(),
    setup([anthropicReply({ clarity: 'clear', description: 'The front door is locked.' })]),
    setup([new Response('nope', { status: 500 }), new Response('nope', { status: 500 })]),
    setup([new TypeError('failed: ' + IMAGE.slice(0, 40))]),
  ];
  const original = { log: console.log, error: console.error, warn: console.warn };
  const consoleLines: string[] = [];
  console.log = console.error = console.warn = (...args: unknown[]) => { consoleLines.push(args.map(String).join(' ')); };
  try {
    for (const t of runs) {
      await t.describe();
      await t.describe({ imageBase64: 'x'.repeat(200) });
      const all = t.logs.join('\n') + consoleLines.join('\n');
      assert(t.logs.length > 0, 'something was logged');
      assert(!all.includes(IMAGE.slice(0, 24)) && !all.includes(IMAGE.slice(-24)), 'no image bytes');
      assert(!all.includes('white door') && !all.includes('front door') && !all.includes('locked'), 'no description text');
      assert(!all.includes('test-key') && !all.includes(USER.email), 'no key or email');
    }
  } finally {
    Object.assign(console, original);
  }
});
