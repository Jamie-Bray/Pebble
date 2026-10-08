// Tests for build-routine against an in-memory store and a mocked fetch.
// No real provider call is ever made.

import { hasBlockedWording, parseDraftReply, parseQuestionsReply, ROUTINE_AI_LIMITS } from '../_shared/routine_ai.ts';
import { createRoutineAiHandler, type Reservation, type RoutineAiStore } from './handler.ts';
import { anthropicRoutineAi, ROUTINE_AI_MODEL } from './provider.ts';

function assert(condition: unknown, label: string): asserts condition {
  if (!condition) throw new Error(label);
}

const INSTALL = '6f1c2a4e-1b2c-4d5e-8f90-123456789abc';
const OTHER_INSTALL = '0a1b2c3d-1b2c-4d5e-8f90-123456789abc';
const USER = { id: 'user-a', email: 'jamie@example.com' };

/** Mirrors public.reserve_routine_ai_call. */
class FakeStore implements RoutineAiStore {
  paused = false;
  premium = new Set<string>();
  builds = new Map<string, { install: string; user: string | null; premium: boolean; calls: number; used: boolean }>();
  monthCalls = 0;

  isPaused() {
    return Promise.resolve(this.paused);
  }
  hasActiveEntitlement(userId: string) {
    return Promise.resolve(this.premium.has(userId));
  }
  freeBuildUsed(installId: string, userId: string | null) {
    return Promise.resolve([...this.builds.values()].some((b) => b.used && (b.install === installId || (userId !== null && b.user === userId))));
  }
  reserve(input: Parameters<RoutineAiStore['reserve']>[0]): Promise<Reservation> {
    const existing = this.builds.get(input.buildKey);
    if (existing) {
      if (existing.install !== input.installId || existing.calls >= input.callsPerBuild) return Promise.resolve('too_many_tries');
    } else if (!input.premium) {
      if ([...this.builds.values()].some((b) => b.used && (b.install === input.installId || (input.userId !== null && b.user === input.userId)))) {
        return Promise.resolve('free_used');
      }
      if ([...this.builds.values()].filter((b) => !b.premium && b.used).length >= input.freeDailyCap) return Promise.resolve('free_daily_cap');
    } else if ([...this.builds.values()].filter((b) => b.premium && b.user === input.userId).length >= input.premiumDailyLimit) {
      return Promise.resolve('daily_limit');
    }
    if (this.monthCalls >= input.monthlyLimit) return Promise.resolve('budget_exhausted');
    this.monthCalls++;
    if (existing) existing.calls++;
    else this.builds.set(input.buildKey, { install: input.installId, user: input.userId, premium: input.premium, calls: 1, used: false });
    return Promise.resolve('ok');
  }
  markUsed(buildKey: string) {
    const build = this.builds.get(buildKey);
    if (build) build.used = true;
    return Promise.resolve();
  }
}

const DRAFT = {
  name: 'Leaving the house',
  steps: [
    { label: 'Hob dials off', photo: true },
    { label: 'Straighteners unplugged', photo: true },
    { label: 'Back door locked', photo: false },
    { label: 'Front door locked', photo: true },
  ],
};

function anthropicReply(data: unknown, stopReason = 'end_turn') {
  return new Response(JSON.stringify({ stop_reason: stopReason, content: [{ type: 'text', text: JSON.stringify(data) }] }), { status: 200 });
}

function setup(replies: (Response | Error)[] = [anthropicReply(DRAFT)], options: { signedIn?: boolean; enabled?: boolean } = {}) {
  const store = new FakeStore();
  const calls: Record<string, unknown>[] = [];
  const logs: string[] = [];
  const fetchImpl = ((_url: string, init: RequestInit) => {
    calls.push(JSON.parse(String(init.body)));
    const next = replies.shift() ?? anthropicReply(DRAFT);
    return next instanceof Error ? Promise.reject(next) : Promise.resolve(next);
  }) as unknown as typeof fetch;
  const handler = createRoutineAiHandler({
    enabled: () => options.enabled ?? true,
    store,
    authenticate: () => Promise.resolve(options.signedIn ? USER : null),
    ask: anthropicRoutineAi('test-key', fetchImpl, { retryDelayMs: 0 }),
    log: (fields) => logs.push(JSON.stringify(fields)),
  });
  const post = async (body: Record<string, unknown>) => {
    const res = await handler(new Request('https://x/build-routine', { method: 'POST', body: JSON.stringify(body) }));
    return { status: res.status, body: await res.json() };
  };
  const draft = (extra: Record<string, unknown> = {}) =>
    post({ action: 'draft', installId: INSTALL, buildKey: 'build-0001', description: 'leaving the house, I always forget the hob', ...extra });
  return { store, calls, logs, post, draft, handler };
}

Deno.test('a free install gets one draft, with a name and steps', async () => {
  const t = setup();
  const res = await t.draft();
  assert(res.status === 200 && res.body.ok === true, `built: ${JSON.stringify(res.body)}`);
  assert(res.body.draft.name === 'Leaving the house', 'name');
  assert(res.body.draft.steps.length === 4 && res.body.draft.steps[0].photo === true, 'steps');
  assert(t.calls[0].model === ROUTINE_AI_MODEL, 'model');
  // A second build on the same install is refused before any provider call.
  const second = await t.draft({ buildKey: 'build-0002' });
  assert(second.body.ok === false && second.body.reason === 'freeUsed', 'second free build refused');
  assert(t.calls.length === 1, 'no provider call for the refusal');
});

Deno.test('try again on the same build is allowed, up to the calls per build', async () => {
  const t = setup([]);
  for (let i = 0; i < ROUTINE_AI_LIMITS.callsPerBuild; i++) {
    const res = await t.draft();
    assert(res.body.ok === true, `try ${i}`);
  }
  const extra = await t.draft();
  assert(extra.body.reason === 'tooManyTries', 'capped');
});

Deno.test('a build key from another install is refused', async () => {
  const t = setup([]);
  await t.draft();
  const res = await t.draft({ installId: OTHER_INSTALL });
  assert(res.body.reason === 'tooManyTries', 'other install cannot reuse the key');
});

Deno.test('the free build follows the account to a new install', async () => {
  const t = setup([], { signedIn: true });
  await t.draft();
  const res = await t.draft({ installId: OTHER_INSTALL, buildKey: 'build-0002' });
  assert(res.body.reason === 'freeUsed', 'account already used its free build');
});

Deno.test('a failed build does not use up the free build', async () => {
  const t = setup([new Response('nope', { status: 500 }), new Response('nope', { status: 500 })]);
  const failed = await t.draft();
  assert(failed.body.reason === 'couldNotBuild', 'failed');
  const status = await t.post({ action: 'status', installId: INSTALL });
  assert(status.body.freeBuildUsed === false, 'still free');
  const retry = await t.draft({ buildKey: 'build-0002' });
  assert(retry.body.ok === true, 'new build allowed');
});

Deno.test('Personal Premium builds more, up to the daily limit', async () => {
  const t = setup([], { signedIn: true });
  t.store.premium.add(USER.id);
  for (let i = 0; i < ROUTINE_AI_LIMITS.premiumDailyPerUser; i++) {
    const res = await t.draft({ buildKey: `premium-${i.toString().padStart(4, '0')}` });
    assert(res.body.ok === true, `premium build ${i}`);
  }
  const over = await t.draft({ buildKey: 'premium-9999' });
  assert(over.body.reason === 'dailyLimit', 'daily limit');
  const status = await t.post({ action: 'status', installId: INSTALL });
  assert(status.body.premium === true && status.body.freeBuildUsed === false, 'status for premium');
});

Deno.test('questions come back with tap options and count as the build', async () => {
  const t = setup([anthropicReply({ questions: [{ question: 'Do you have a car?', options: ['Yes', 'No'] }] }), anthropicReply(DRAFT)]);
  const asked = await t.post({ action: 'questions', installId: INSTALL, buildKey: 'build-0001', description: 'leaving for work' });
  assert(asked.body.ok === true && asked.body.questions[0].options.length === 2, 'questions');
  const built = await t.draft({ answers: [{ question: 'Do you have a car?', answer: 'Yes' }] });
  assert(built.body.ok === true, 'draft after questions');
  assert(String((t.calls[1].messages as { content: string }[])[0].content).includes('Do you have a car?'), 'answers sent');
  const another = await t.draft({ buildKey: 'build-0002' });
  assert(another.body.reason === 'freeUsed', 'one build in total');
});

Deno.test('switched off, unconfigured, paused or out of budget never calls the provider', async () => {
  const off = setup([], { enabled: false });
  assert((await off.draft()).body.reason === 'featureOff', 'secret off');
  assert((await off.handler(new Request('https://x', { method: 'GET' })).then((r) => r.json())).enabled === false, 'GET off');
  const paused = setup();
  paused.store.paused = true;
  assert((await paused.draft()).body.reason === 'featureOff', 'paused');
  const broke = createRoutineAiHandler({ enabled: () => true, store: new FakeStore(), authenticate: () => Promise.resolve(null), ask: null });
  const res = await broke(new Request('https://x', { method: 'GET' }));
  assert((await res.json()).enabled === false, 'no key means off');
  const budget = setup();
  budget.store.monthCalls = ROUTINE_AI_LIMITS.monthlyCalls;
  assert((await budget.draft()).body.reason === 'busy', 'budget');
  assert(off.calls.length + paused.calls.length + budget.calls.length === 0, 'no provider calls');
});

Deno.test('bad requests are refused before reserving', async () => {
  const t = setup();
  assert((await t.draft({ installId: 'nope' })).status === 400, 'install id');
  assert((await t.draft({ buildKey: 'x' })).status === 400, 'build key');
  assert((await t.draft({ description: '' })).status === 400, 'empty description');
  assert((await t.draft({ description: 'x'.repeat(500) })).status === 400, 'long description');
  assert((await t.draft({ answers: [{ question: 'a', answer: 'b' }, { question: 'a', answer: 'b' }, { question: 'a', answer: 'b' }] })).status === 400, 'answers');
  assert(t.store.builds.size === 0 && t.calls.length === 0, 'nothing reserved');
});

Deno.test('drafts are checked: blocked wording, duplicates and too few steps', () => {
  const bad = parseDraftReply(JSON.stringify({
    name: 'Leaving',
    steps: [
      { label: 'Hob off', photo: true },
      { label: 'Hob off', photo: true },
      { label: 'Breathe and ease your anxiety', photo: false },
      { label: "Door locked, it's safe now", photo: false },
    ],
  }));
  assert(!bad.ok && bad.code === 'tooFewSteps', 'filtered to one step');
  const long = parseDraftReply(JSON.stringify({ name: 'A', steps: Array.from({ length: 12 }, (_, i) => ({ label: `Step ${i}`, photo: false })) }));
  assert(long.ok && long.draft.steps.length === ROUTINE_AI_LIMITS.maxSteps, 'capped at max steps');
  assert(!parseDraftReply('not json').ok, 'not json');
  assert(hasBlockedWording('Check for OCD triggers') && !hasBlockedWording('Hob dials off'), 'word filter');
  assert(!hasBlockedWording('Shocked? Clocked in'), 'whole words only');
  const questions = parseQuestionsReply(JSON.stringify({ questions: [{ question: 'Do you worry a lot?', options: ['Yes', 'No'] }, { question: 'Pets?', options: ['Cat'] }] }));
  assert(!questions.ok, 'blocked question and too few options dropped');
});

Deno.test('a cut-short or refused reply is a failure', async () => {
  const t = setup([anthropicReply(DRAFT, 'max_tokens')]);
  assert((await t.draft()).body.reason === 'couldNotBuild', 'max_tokens');
  const r = setup([anthropicReply(DRAFT, 'refusal')]);
  assert((await r.draft()).body.reason === 'couldNotBuild', 'refusal');
});

Deno.test('logs carry outcome codes only: never what was typed or the draft', async () => {
  const t = setup();
  await t.draft({ description: 'my secret flat at 12 Acacia Avenue' });
  const all = t.logs.join('\n');
  assert(t.logs.length > 0, 'logged');
  assert(!all.includes('Acacia') && !all.includes('Hob dials') && !all.includes('test-key'), 'no content');
});
