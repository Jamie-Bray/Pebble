// End-to-end tests of the completion-email flow against an in-memory store:
// sender invites -> recipient confirms -> completions are emailed -> stop/block.

import { createContactHandler } from '../request-shared-alert-contact/handler.ts';
import { createCompletionHandler } from '../send-routine-completion-alert/handler.ts';
import { fakeMailer, FakeStore, testLinks, tokenFrom } from './shared_alert_fake_store.ts';
import { createLinkHandler } from './shared_alert_links.ts';
import { DAY_MS, HOUR_MS, LIMITS, type LinkAction, sha256Hex } from './shared_alert_policy.ts';

function assert(condition: unknown, label: string): asserts condition {
  if (!condition) throw new Error(label);
}

const SENDER = { id: 'user-a', email: 'jamie@example.com' };
const OTHER = { id: 'user-b', email: 'sam@example.com' };
const RECIPIENT = 'Friend@Example.com';

function setup(mailOutcomes: ('ok' | 'fail')[] = []) {
  let clock = Date.parse('2026-10-03T21:00:00Z');
  const now = () => clock;
  const store = new FakeStore(now);
  store.premium.add(SENDER.id);
  store.premium.add(OTHER.id);
  const { mailer, sent } = fakeMailer(mailOutcomes);
  const users: Record<string, { id: string; email: string }> = { a: SENDER, b: OTHER };
  const authenticate = (req: Request) => Promise.resolve(users[req.headers.get('x-test-user') ?? ''] ?? null);
  const contact = createContactHandler({ store, authenticate, mailer, links: testLinks, now });
  const complete = createCompletionHandler({ store, authenticate, mailer, links: testLinks, now });
  const link = (action: LinkAction) => createLinkHandler(action, { store, pagesBase: testLinks.pagesBase, now });

  const call = async (handler: (r: Request) => Promise<Response>, method: string, body?: unknown, user = 'a', query = '') => {
    const res = await handler(new Request(`https://f.example/fn${query}`, {
      method,
      headers: { 'x-test-user': user, 'content-type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    }));
    return { status: res.status, body: await res.json() };
  };
  const invite = (body: Record<string, unknown> = {}, user = 'a') =>
    call(contact, 'POST', { routineKey: 'local:1', recipientEmail: RECIPIENT, ...body }, user);
  const finish = (runId: string, extra: Record<string, unknown> = {}, user = 'a') =>
    call(complete, 'POST', {
      routineKey: 'local:1', routineTitle: 'Lock up', runId,
      completedAt: new Date(clock).toISOString(), utcOffsetMinutes: 60, completedSteps: 4, totalSteps: 4, ...extra,
    }, user);
  const confirm = async (action: LinkAction, token: string, form: Record<string, string> = {}) => {
    const res = await link(action)(new Request(`https://f.example/shared-alert-${action}`, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ token, ...form }),
    }));
    return res.headers.get('location') ?? `status ${res.status}`;
  };
  return {
    store, sent, contact, link, call, invite, finish, confirm,
    advance: (ms: number) => { clock += ms; },
  };
}

Deno.test('happy path: invite names the sender, accept, completion email sent once per run', async () => {
  const t = setup();
  const res = await t.invite();
  assert(res.status === 200 && res.body.contact.status === 'pending', 'pending contact');
  assert(t.sent.length === 1 && t.sent[0].to === 'friend@example.com', 'invite sent to normalised address');
  assert(t.sent[0].text.includes('jamie@example.com would like'), 'sender named in invite');
  assert(t.sent[0].headers['List-Unsubscribe'].includes('/shared-alert-block?token='), 'invite one-click blocks');

  // Not accepted yet: nothing is emailed.
  assert((await t.finish('run-0')).body.reason === 'noAcceptedContact', 'pending sends nothing');

  const token = tokenFrom(t.sent[0].text, 'accept');
  assert(await t.confirm('accept', token) === `${testLinks.pagesBase}/accepted/`, 'accepted page');
  assert(t.store.contacts[0].status === 'accepted' && t.store.contacts[0].notify_when_finished, 'accepted');

  const first = await t.finish('run-1');
  assert(first.body.sent === true, 'sent');
  const mail = t.sent[1];
  assert(mail.text.includes('Lock up') && mail.text.includes('(UTC+1)') && mail.text.includes('4 of 4'), 'details');
  assert(mail.headers['List-Unsubscribe'].includes('/shared-alert-decline?token='), 'one-click stops');
  const again = await t.finish('run-1');
  assert(again.body.alreadySent === true && (t.sent.length as number) === 2, 'same run is not emailed twice');
});

Deno.test('GET on a link never acts, it redirects to the confirm page', async () => {
  const t = setup();
  await t.invite();
  const token = tokenFrom(t.sent[0].text, 'accept');
  const res = await t.link('accept')(new Request(`https://f.example/shared-alert-accept?token=${token}`));
  assert(res.status === 303, '303');
  assert(res.headers.get('location') === `${testLinks.pagesBase}/confirm/#action=accept&token=${token}`, 'to confirm page');
  assert(t.store.contacts[0].status === 'pending', 'unchanged');
  const bad = await t.link('block')(new Request('https://f.example/shared-alert-block?token=%3Cscript%3E'));
  assert(bad.headers.get('location') === `${testLinks.pagesBase}/problem/`, 'bad token -> problem, fixed URL');
});

Deno.test('the app cannot be used to email strangers: limits and re-invite rules', async () => {
  const t = setup();
  // Re-sending to the same address on the same routine is capped per week.
  for (let i = 0; i < LIMITS.senderRecipientInvitesPerWeek; i++) {
    assert((await t.invite()).status === 200, `invite ${i}`);
  }
  const capped = await t.invite();
  assert(capped.status === 429 && capped.body.code === 'recipientWeeklyLimit', 'weekly cap per address');

  // Older invite links stop working once a newer one is sent.
  const oldToken = tokenFrom(t.sent[0].text, 'accept');
  assert(await t.confirm('accept', oldToken) === `${testLinks.pagesBase}/problem/`, 'superseded invite');

  // Daily cap across many addresses / routines.
  for (let i = 0; i < 20; i++) await t.invite({ routineKey: `local:${100 + i}`, recipientEmail: `p${i}@example.com` });
  const invitesToday = t.sent.length;
  assert(invitesToday === LIMITS.senderInvitesPerDay, `daily cap (${invitesToday})`);
});

Deno.test('one address receives at most a few invites a day across all senders', async () => {
  const t = setup();
  for (let i = 0; i < 8; i++) {
    await t.invite({ routineKey: `local:${i}` }, i % 2 === 0 ? 'a' : 'b');
  }
  assert(t.sent.length === LIMITS.recipientInvitesPerDay, `capped at ${LIMITS.recipientInvitesPerDay} (${t.sent.length})`);
  const refused = await t.invite({ routineKey: 'local:99' }, 'b');
  assert(refused.status === 429, 'still refused');
});

Deno.test('decline: stops emails, and the sender cannot re-invite for 30 days', async () => {
  const t = setup();
  await t.invite();
  const token = tokenFrom(t.sent[0].text, 'decline');
  assert(await t.confirm('decline', token) === `${testLinks.pagesBase}/declined/`, 'declined page');
  assert(t.store.contacts[0].status === 'declined', 'declined');
  const retry = await t.invite();
  assert(retry.status === 409 && retry.body.code === 'recentlyDeclined', 'cooldown');
  const elsewhere = await t.invite({ routineKey: 'local:2' });
  assert(elsewhere.status === 409, 'cooldown applies to other routines too');
  // Removing and re-adding the contact does not reset it.
  await t.call(t.contact, 'DELETE', { contactId: t.store.contacts[0].id });
  assert((await t.invite()).status === 409, 'remove + re-add still refused');
  t.advance(31 * DAY_MS);
  assert((await t.invite()).status === 200, 'allowed after cooldown');
});

Deno.test('stop link in a completion email works, also via RFC 8058 one-click', async () => {
  const t = setup();
  await t.invite();
  await t.confirm('accept', tokenFrom(t.sent[0].text, 'accept'));
  await t.finish('run-1');
  const unsubscribe = t.sent[1].headers['List-Unsubscribe'].slice(1, -1);
  const res = await t.link('decline')(new Request(unsubscribe, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: 'List-Unsubscribe=One-Click',
  }));
  assert(res.status === 200, 'one-click returns 200');
  assert(t.store.contacts[0].status === 'declined' && !t.store.contacts[0].notify_when_finished, 'stopped');
  assert((await t.finish('run-2')).body.reason === 'noAcceptedContact', 'no more emails');
  // The completion email's link can't be used to switch emails back on.
  const manage = tokenFrom(t.sent[1].text, 'decline');
  assert(await t.confirm('accept', manage) === `${testLinks.pagesBase}/problem/`, 'manage token cannot accept');
});

Deno.test('block: per sender by default, all senders when chosen, and honoured on send', async () => {
  const t = setup();
  await t.invite();
  await t.confirm('accept', tokenFrom(t.sent[0].text, 'accept'));
  await t.finish('run-1');
  const blockToken = tokenFrom(t.sent[1].text, 'block');
  assert(await t.confirm('block', blockToken) === `${testLinks.pagesBase}/blocked/`, 'blocked page');
  assert(t.store.contacts[0].status === 'blocked', 'contact blocked');
  const again = await t.invite({ routineKey: 'local:7' });
  assert(again.status === 403 && again.body.code === 'recipientBlocked', 'sender blocked');
  assert((await t.invite({}, 'b')).status === 200, 'other senders still allowed');

  const otherInvite = t.sent[t.sent.length - 1];
  assert(
    await t.confirm('block', tokenFrom(otherInvite.text, 'block'), { scope: 'all' }) === `${testLinks.pagesBase}/blocked/?all=1`,
    'block all page',
  );
  t.store.premium.add('user-c');
  const third = await t.invite({ routineKey: 'local:3' }, 'b');
  assert(third.status === 403 && third.body.code === 'recipientOptedOut', 'global opt-out');

  // Even if a contact row were flipped back to accepted, a block still wins.
  t.store.contacts[0].status = 'accepted';
  t.store.contacts[0].notify_when_finished = true;
  assert((await t.finish('run-9')).body.reason === 'noAcceptedContact', 'block honoured at send time');
});

Deno.test('changing the address: old recipient links cannot affect the new contact', async () => {
  const t = setup();
  await t.invite();
  const oldAccept = tokenFrom(t.sent[0].text, 'accept');
  const oldBlock = tokenFrom(t.sent[0].text, 'block');
  await t.invite({ recipientEmail: 'new@example.com' });
  assert(await t.confirm('accept', oldAccept) === `${testLinks.pagesBase}/problem/`, 'old accept rejected');
  // The old recipient can still block the sender for themselves.
  assert(await t.confirm('block', oldBlock) === `${testLinks.pagesBase}/blocked/`, 'old block works');
  assert(t.store.contacts[0].status === 'pending', 'new contact untouched');
  const oldHash = await sha256Hex('friend@example.com');
  assert(t.store.blocks.some((b) => b.hash === oldHash && b.expires_at === null), 'block recorded for old address');
});

Deno.test('completion emails are capped per contact and a failed send can be retried', async () => {
  const t = setup(['ok', 'fail']);
  await t.invite();
  await t.confirm('accept', tokenFrom(t.sent[0].text, 'accept'));
  const failed = await t.finish('run-1');
  assert(failed.status === 502 && failed.body.code === 'emailFailed', 'provider failure surfaces');
  assert(t.store.events[0].status === 'failed', 'logged failed');
  const retried = await t.finish('run-1');
  assert(retried.body.sent === true && t.store.events[0].attempts === 2, 'retry of same run sends');

  for (let i = 2; i <= LIMITS.contactEmailsPerHour; i++) assert((await t.finish(`run-${i}`)).body.sent, `send ${i}`);
  const limited = await t.finish('run-x');
  assert(limited.body.reason === 'rateLimited', 'hourly cap');
  assert(t.store.events.at(-1)?.status === 'skipped', 'skipped event recorded');
  t.advance(HOUR_MS + 1000);
  assert((await t.finish('run-y')).body.sent === true, 'allowed next hour');
});

Deno.test('premium is enforced server-side; lapsed senders send nothing but can still stop', async () => {
  const t = setup();
  t.store.premium.delete(SENDER.id);
  const res = await t.invite();
  assert(res.status === 403 && res.body.error.startsWith('Personal Premium is required'), 'invite needs premium');
  t.store.premium.add(SENDER.id);
  await t.invite();
  await t.confirm('accept', tokenFrom(t.sent[0].text, 'accept'));
  t.store.premium.delete(SENDER.id);
  assert((await t.finish('run-1')).body.reason === 'noActiveEntitlement', 'lapsed: no send');
  const id = t.store.contacts[0].id;
  const off = await t.call(t.contact, 'PATCH', { contactId: id, notifyWhenFinished: false });
  assert(off.status === 200 && off.body.contact.notifyWhenFinished === false, 'can turn off without premium');
  const on = await t.call(t.contact, 'PATCH', { contactId: id, notifyWhenFinished: true });
  assert(on.status === 403, 'turning on needs premium');
  const removed = await t.call(t.contact, 'DELETE', { contactId: id });
  assert(removed.status === 200 && t.store.contacts[0].status === 'disabled', 'can remove without premium');
});

Deno.test('hiding the routine name keeps it out of the email and the log', async () => {
  const t = setup();
  await t.invite();
  await t.confirm('accept', tokenFrom(t.sent[0].text, 'accept'));
  const id = t.store.contacts[0].id;
  const patched = await t.call(t.contact, 'PATCH', { contactId: id, includeRoutineName: false, includeStepCount: false });
  assert(patched.body.contact.includeRoutineName === false, 'patched');
  await t.finish('run-1', {
    routineTitle: 'Evening medication check',
    steps: [{ title: 'Take tablets', status: 'done', completedAt: '2026-10-03T20:58:00Z' }],
  });
  const mail = t.sent[1];
  assert(!mail.text.includes('medication') && !mail.html.includes('medication'), 'title not emailed');
  assert(!mail.text.includes('Steps:'), 'steps hidden');
  assert(!mail.text.includes('tablets') && !mail.html.includes('tablets'), 'step names not emailed');
  assert(t.store.events[0].routine_title === '', 'title not stored');
});

Deno.test('steps are listed with their times and never stored', async () => {
  const t = setup();
  await t.invite();
  await t.confirm('accept', tokenFrom(t.sent[0].text, 'accept'));
  await t.finish('run-1', {
    completedSteps: 1, totalSteps: 2,
    steps: [
      { title: 'Front door locked', status: 'done', completedAt: '2026-10-03T20:58:00Z' },
      { title: 'Hob off', status: 'skipped' },
    ],
  });
  const mail = t.sent[1];
  assert(mail.text.includes('✓ Front door locked  21:58') && mail.text.includes('– Hob off  Skipped'), 'rows in text');
  assert(mail.html.includes('Front door locked') && mail.html.includes('Skipped'), 'rows in html');
  assert(!JSON.stringify(t.store.events).includes('Front door'), 'step names not stored');
});

Deno.test('other users cannot read or change a contact; bad input is rejected', async () => {
  const t = setup();
  await t.invite();
  const id = t.store.contacts[0].id;
  assert((await t.call(t.contact, 'DELETE', { contactId: id }, 'b')).status === 404, 'not owner');
  assert((await t.call(t.contact, 'PATCH', { contactId: id, includeRoutineName: false }, 'b')).status === 404, 'not owner patch');
  assert((await t.call(t.contact, 'GET', undefined, 'nobody', '?routineKey=local:1')).status === 401, 'signed out');
  const bad = await t.invite({ recipientEmail: 'Evil <x@y.com>, z@w.com' });
  assert(bad.status === 400 && bad.body.code === 'invalidEmail', 'header-ish email rejected');
  assert((await t.invite({ routineKey: '../../etc' })).status === 400, 'bad routine key');
  const got = await t.call(t.contact, 'GET', undefined, 'a', '?routineKey=local:1');
  assert(got.body.contact.recipientEmail === 'friend@example.com', 'owner can read');
});

Deno.test('invite email failure is reported without provider details', async () => {
  const t = setup(['fail']);
  const res = await t.invite();
  assert(res.status === 502 && res.body.code === 'emailFailed', '502');
  assert(!JSON.stringify(res.body).includes('boom'), 'no provider text');
});

Deno.test('AI photo descriptions: emailed only with consent, labelled as AI, filtered and capped', async () => {
  const t = setup();
  await t.invite();
  assert(t.sent[0].text.includes('Photos are never emailed.'), 'invite says photos are never emailed');
  await t.confirm('accept', tokenFrom(t.sent[0].text, 'accept'));
  const descriptions = [
    'A white door with the handle pointing up.',
    'The hob is switched off.',
    '<b>Four</b> dials with the marker at the top.',
    'three', 'four', 'five', 'six',
  ];

  // No AI consent on the server: descriptions are dropped, the email still goes.
  assert((await t.finish('run-1', { descriptions })).body.sent === true, 'sent without descriptions');
  assert(!t.sent[1].text.includes('AI descriptions') && !t.sent[1].text.includes('white door'), 'not included without consent');

  t.store.aiConsent.add(SENDER.id);
  assert((await t.finish('run-2', { descriptions })).body.sent === true, 'sent');
  const mail = t.sent[2];
  assert(mail.text.includes('AI descriptions (can be wrong)'), 'AI line in text');
  assert(mail.html.includes('AI descriptions') && mail.html.includes('Can be wrong'), 'AI line in html');
  assert(mail.text.indexOf('AI descriptions') < mail.text.indexOf('Photo 1: A white door'), 'descriptions sit under the AI line');
  assert(!mail.text.includes('switched off') && !mail.html.includes('switched off'), 'verdict dropped');
  assert(mail.html.includes('&lt;b&gt;Four&lt;/b&gt;') && !mail.html.includes('<b>Four</b>'), 'escaped in html');
  assert(mail.text.includes('Photo 4: four') && !mail.text.includes('five') && !mail.text.includes('six'), 'first five only');
  assert(!JSON.stringify(t.store.events).includes('white door'), 'descriptions are not stored');

  // Without the field nothing changes.
  await t.finish('run-3');
  assert(!t.sent[3].text.includes('AI descriptions'), 'no section without descriptions');
});
