import { buildCompletionEmail, buildInviteEmail } from './shared_alert_email.ts';
import {
  completionTimeParts,
  confirmPageUrl,
  createToken,
  effectivePurpose,
  formatCompletionTime,
  formatStepTime,
  inviteDecision,
  isPlausibleToken,
  isValidRecipientEmail,
  isValidRoutineKey,
  LIMITS,
  parseCompletionInput,
  sanitizeTitle,
  sendDecision,
} from './shared_alert_policy.ts';
import { redact, resendMailer, summariseProviderError } from './shared_alert_runtime.ts';

function assert(condition: unknown, label: string): asserts condition {
  if (!condition) throw new Error(label);
}

const NOW = Date.parse('2026-10-03T21:45:00Z');

Deno.test('recipient email validation rejects header and display-name tricks', () => {
  for (const ok of ['a.b+tag@example.co.uk', 'x@sub.example.com', "o'brien@example.ie", 'a@xn--bcher-kva.example']) {
    assert(isValidRecipientEmail(ok), `accept ${ok}`);
  }
  for (const bad of [
    'Name<a@b.com>', '<a@b.com>', 'a@b.com,c@d.com', 'a@b.com;c@d.com', '"a"@b.com',
    'a@b.com\r\nBcc: x@y.com', 'a b@c.com', 'a@b', 'a@@b.com', '.a@b.com', 'a..b@c.com',
    'a@-b.com', 'a@b.c', 'a@b.123', `${'x'.repeat(65)}@b.com`,
  ]) {
    assert(!isValidRecipientEmail(bad), `reject ${JSON.stringify(bad)}`);
  }
});

Deno.test('routine keys must look like the app generates them', () => {
  assert(isValidRoutineKey('local:12'), 'local');
  assert(isValidRoutineKey('cloud:2b1f5b8e-1c1a-4b8f-9a39-3c2d6d1f0e11'), 'cloud');
  for (const bad of ['', 'local:', 'other:1', 'local:1 2', 'cloud:' + 'x'.repeat(81), 12]) {
    assert(!isValidRoutineKey(bad), `reject ${bad}`);
  }
});

Deno.test('titles: control and bidi characters stripped, emoji kept, length capped', () => {
  assert(sanitizeTitle('  Lock\u0000 up\n\tnow  ') === 'Lock up now', 'controls collapse');
  assert(sanitizeTitle('evil\u202Egnp.exe') === 'evilgnp.exe', 'bidi override removed');
  assert(sanitizeTitle('Family 👨‍👩‍👧 check') === 'Family 👨‍👩‍👧 check', 'ZWJ emoji kept');
  const long = sanitizeTitle('🔒'.repeat(200));
  assert(Array.from(long).length === 120 && long.endsWith('…'), 'capped without splitting emoji');
  assert(sanitizeTitle(42) === '', 'non-string');
});

Deno.test('completion input: ranges and offsets', () => {
  const base = {
    routineKey: 'local:1', routineTitle: 'Lock up', runId: 'run-1',
    completedAt: '2026-10-03T21:41:00.000Z', completedSteps: 9, totalSteps: 9, utcOffsetMinutes: 60,
  };
  const ok = parseCompletionInput(base, NOW);
  assert(ok.ok && ok.value.utcOffsetMinutes === 60 && ok.value.completedAtHasZone, 'valid');
  assert(!parseCompletionInput({ ...base, completedSteps: 10 }, NOW).ok, 'completed > total');
  assert(!parseCompletionInput({ ...base, totalSteps: 5000, completedSteps: 1 }, NOW).ok, 'huge total');
  assert(!parseCompletionInput({ ...base, completedAt: '2030-01-01T00:00:00Z' }, NOW).ok, 'future');
  assert(!parseCompletionInput({ ...base, completedAt: '2026-09-01T00:00:00Z' }, NOW).ok, 'too old');
  assert(!parseCompletionInput({ ...base, utcOffsetMinutes: 2000 }, NOW).ok, 'bad offset');
  assert(!parseCompletionInput({ ...base, runId: 'x'.repeat(101) }, NOW).ok, 'long run id');
  assert(!parseCompletionInput([], NOW).ok, 'array body');
  const legacy = parseCompletionInput({ ...base, completedAt: '2026-10-03T22:41:00.000', utcOffsetMinutes: undefined }, NOW);
  assert(legacy.ok && !legacy.value.completedAtHasZone && legacy.value.utcOffsetMinutes === null, 'legacy local time');
});

Deno.test('completion time is shown in the sender’s zone', () => {
  const at = new Date('2026-10-03T21:41:00Z');
  assert(formatCompletionTime({ completedAt: at, utcOffsetMinutes: 60, completedAtHasZone: true }) === '3 Oct 2026, 22:41 (UTC+1)', 'BST');
  assert(formatCompletionTime({ completedAt: at, utcOffsetMinutes: 330, completedAtHasZone: true }) === '4 Oct 2026, 03:11 (UTC+5:30)', 'IST');
  assert(formatCompletionTime({ completedAt: at, utcOffsetMinutes: -240, completedAtHasZone: true }) === '3 Oct 2026, 17:41 (UTC−4)', 'EDT');
  assert(formatCompletionTime({ completedAt: at, utcOffsetMinutes: null, completedAtHasZone: true }) === '3 Oct 2026, 21:41 (UTC)', 'zoned, no offset');
  // Older app builds sent wall-clock time without a zone; the runtime is UTC.
  const legacy = new Date('2026-10-03T22:41:00.000Z');
  assert(formatCompletionTime({ completedAt: legacy, utcOffsetMinutes: null, completedAtHasZone: false }) === '3 Oct 2026, 22:41', 'legacy');
});

Deno.test('invite decision: opt-out, block, cooldown, caps', () => {
  const clean = {
    suppressed: false, blocked: false, senderInvitesLastDay: 0, senderRecipientInvitesLastWeek: 0,
    recipientInvitesLastDay: 0, activeContactsElsewhere: 0, declinedUntil: null,
  };
  assert(inviteDecision(clean, NOW).ok, 'clean ok');
  const code = (patch: Partial<typeof clean> | Record<string, unknown>) => {
    const d = inviteDecision({ ...clean, ...patch } as typeof clean, NOW);
    return d.ok ? 'ok' : d.code;
  };
  assert(code({ suppressed: true }) === 'recipientOptedOut', 'suppressed');
  assert(code({ blocked: true }) === 'recipientBlocked', 'blocked');
  assert(code({ declinedUntil: new Date(NOW + 1000) }) === 'recentlyDeclined', 'cooldown');
  assert(code({ declinedUntil: new Date(NOW - 1000) }) === 'ok', 'cooldown over');
  assert(code({ activeContactsElsewhere: LIMITS.maxActiveContacts }) === 'tooManyContacts', 'max contacts');
  assert(code({ senderRecipientInvitesLastWeek: LIMITS.senderRecipientInvitesPerWeek }) === 'recipientWeeklyLimit', 'weekly');
  assert(code({ senderInvitesLastDay: LIMITS.senderInvitesPerDay }) === 'senderDailyLimit', 'daily');
  assert(code({ recipientInvitesLastDay: LIMITS.recipientInvitesPerDay }) === 'recipientDailyLimit', 'recipient daily');
  const cooldown = inviteDecision({ ...clean, declinedUntil: new Date('2026-11-02T10:00:00Z') }, NOW);
  assert(!cooldown.ok && cooldown.error.includes('2 November 2026'), 'cooldown date shown');
});

Deno.test('send decision caps emails per contact', () => {
  assert(sendDecision({ sentLastHour: 0, sentLastDay: 0 }) === 'ok', 'ok');
  assert(sendDecision({ sentLastHour: LIMITS.contactEmailsPerHour, sentLastDay: 3 }) === 'rateLimited', 'hour');
  assert(sendDecision({ sentLastHour: 0, sentLastDay: LIMITS.contactEmailsPerDay }) === 'rateLimited', 'day');
});

Deno.test('tokens: 256-bit, url-safe, unique; legacy purpose inferred', () => {
  const a = createToken();
  assert(a.length === 43 && /^[A-Za-z0-9_-]+$/.test(a), 'shape');
  assert(new Set(Array.from({ length: 200 }, createToken)).size === 200, 'unique');
  assert(isPlausibleToken(a) && isPlausibleToken(`${crypto.randomUUID()}.${crypto.randomUUID()}`), 'plausible');
  assert(!isPlausibleToken('<script>') && !isPlausibleToken('short'), 'implausible');
  assert(confirmPageUrl('https://p.example/shared-alert/', 'accept', 'a+b') === 'https://p.example/shared-alert/confirm/#action=accept&token=a%2Bb', 'fragment url');
  const created = '2026-10-01T00:00:00Z';
  assert(effectivePurpose({ purpose: null, created_at: created, expires_at: '2026-10-15T00:00:00Z' }) === 'invite', '14d invite');
  assert(effectivePurpose({ purpose: null, created_at: created, expires_at: '2026-12-30T00:00:00Z' }) === 'manage', '90d manage');
  assert(effectivePurpose({ purpose: 'invite', created_at: created, expires_at: '2026-12-30T00:00:00Z' }) === 'manage', 'old default with 90d');
});

Deno.test('templates escape hostile titles and senders everywhere', () => {
  const hostile = '<img src=x onerror=alert(1)> & "quotes" \'single\'';
  const email = buildCompletionEmail({
    sender: 'jamie@example.com', privacyUrl: 'https://p.example/privacy.html', footerAddress: '1 <b>Street</b>',
    routineTitle: hostile, completedAtText: '3 Oct 2026, 22:41 (UTC+1)', steps: { completed: 9, total: 9 },
    stopUrl: 'https://p.example/confirm/#action=decline&token=t"><script>', blockUrl: 'https://p.example/b',
    oneClickUrl: 'https://f.example/shared-alert-decline?token=t',
  });
  assert(!email.html.includes('<img') && !email.html.includes('<script>') && !email.html.includes('<b>'), 'no raw tags');
  assert(email.html.includes('&lt;img src=x onerror=alert(1)&gt; &amp; &quot;quotes&quot; &#39;single&#39;'), 'escaped');
  assert(email.subject === 'Routine completed · Pebble' && !email.subject.includes('img'), 'subject never has the title');
  assert(email.text.includes(hostile), 'plain text keeps the literal title');
  assert(email.headers['List-Unsubscribe'] === '<https://f.example/shared-alert-decline?token=t>', 'list-unsubscribe');
  assert(email.headers['List-Unsubscribe-Post'] === 'List-Unsubscribe=One-Click', 'one-click');
  assert(!/[\r\n]/.test(Object.values(email.headers).join('')), 'no header newlines');
});

Deno.test('completion email hides the routine name and steps when asked', () => {
  const email = buildCompletionEmail({
    sender: 'jamie@example.com', privacyUrl: 'https://p.example/privacy.html',
    routineTitle: null, completedAtText: '3 Oct 2026, 22:41', steps: null,
    stopUrl: 'https://p.example/s', blockUrl: 'https://p.example/b', oneClickUrl: 'https://f.example/o',
  });
  assert(!email.text.includes('Routine:') && !email.text.includes('Steps:'), 'rows hidden');
  assert(email.text.includes('Routine completed') && email.text.includes('Completed by jamie@example.com'), 'generic heading');
});

Deno.test('step list: optional, cleaned, never fails the request', () => {
  const base = {
    routineKey: 'local:1', routineTitle: 'Night', runId: 'r1', completedAt: '2026-10-03T21:41:00Z',
    utcOffsetMinutes: 60, completedSteps: 2, totalSteps: 3,
  };
  const none = parseCompletionInput(base, NOW);
  assert(none.ok && none.value.steps.length === 0, 'older builds send no steps');
  const bad = parseCompletionInput({ ...base, steps: 'nope' }, NOW);
  assert(bad.ok && bad.value.steps.length === 0, 'non-list ignored');
  const parsed = parseCompletionInput({
    ...base,
    steps: [
      { title: ' Front\u202E door ', status: 'done', completedAt: '2026-10-03T21:38:00Z', note: ' Keys\u202E in   the bowl ' },
      { title: 'Hob', status: 'skipped', completedAt: '2026-10-03T21:39:00Z', note: 'n'.repeat(400) },
      { title: 'Future', status: 'done', completedAt: '2026-10-04T21:39:00Z' },
      { title: '', status: 'done' },
      42,
      { title: 'x'.repeat(300), status: 'done', completedAt: 'not a date' },
    ],
  }, NOW);
  assert(parsed.ok, 'parsed');
  const steps = parsed.value.steps;
  assert(steps.length === 4, `kept 4, got ${steps.length}`);
  assert(steps[0].title === 'Front door' && steps[0].completedAt?.toISOString() === '2026-10-03T21:38:00.000Z', 'cleaned');
  assert(steps[1].skipped && steps[1].completedAt === null, 'skipped has no time');
  assert(steps[2].completedAt === null, 'time after the run dropped');
  assert(Array.from(steps[3].title).length === 90 && steps[3].completedAt === null, 'long title cut, bad time dropped');
  assert(steps[0].note === 'Keys in the bowl', 'note cleaned');
  assert(Array.from(steps[1].note ?? '').length === 140, 'long note cut');
  assert(steps[2].note === null, 'no note is null');
});

Deno.test('completion time parts and step times use the sender clock', () => {
  const run = { completedAt: new Date('2026-10-03T23:10:00Z'), utcOffsetMinutes: 60, completedAtHasZone: true };
  const parts = completionTimeParts(run);
  assert(parts.time === '00:10' && parts.day === 'Sunday 4 October 2026' && parts.zone === 'UTC+1', JSON.stringify(parts));
  assert(formatStepTime(new Date('2026-10-03T23:05:00Z'), run) === '00:05', 'same day');
  assert(formatStepTime(new Date('2026-10-03T22:55:00Z'), run) === '3 Oct, 23:55', 'earlier day');
  const legacy = completionTimeParts({ completedAt: new Date('2026-10-03T22:41:00Z'), utcOffsetMinutes: null, completedAtHasZone: false });
  assert(legacy.time === '22:41' && legacy.zone === null, 'legacy wall clock');
});

Deno.test('completion email lists steps with times, and hides them when asked', () => {
  const common = {
    sender: 'jamie@example.com', privacyUrl: 'https://p.example/privacy.html',
    routineTitle: 'Leaving the house', completedAtText: '3 Oct 2026, 08:02 (UTC+1)',
    completedAtParts: { time: '08:02', day: 'Friday 3 October 2026', zone: 'UTC+1' },
    stepList: [
      { title: 'Front <door>', time: '08:01', skipped: false, note: 'Keys in the <bowl>' },
      { title: 'Hob off', time: null, skipped: true },
    ],
    moreSteps: 2,
    stopUrl: 'https://p.example/s', blockUrl: 'https://p.example/b', oneClickUrl: 'https://f.example/o',
  };
  const shown = buildCompletionEmail({ ...common, steps: { completed: 3, total: 4 } });
  assert(shown.html.includes('Front &lt;door&gt;') && !shown.html.includes('<door>'), 'step title escaped');
  assert(shown.html.includes('08:01') && shown.html.includes('Skipped'), 'time and skipped shown');
  assert(shown.html.includes('and 2 more steps'), 'more steps');
  assert(shown.text.includes('✓ Front <door>  08:01') && shown.text.includes('– Hob off  Skipped'), 'plain text rows');
  assert(shown.text.includes('Steps: 3 of 4, 1 skipped'), 'summary');
  assert(shown.html.includes('Keys in the &lt;bowl&gt;') && !shown.html.includes('<bowl>'), 'step note escaped');
  assert(shown.text.includes('   Keys in the <bowl>'), 'plain text note');
  assert(shown.html.includes('Friday 3 October 2026'), 'hero day');
  const hidden = buildCompletionEmail({ ...common, steps: null });
  assert(!hidden.html.includes('Front') && !hidden.text.includes('Front') && !hidden.text.includes('Steps:'), 'steps hidden');
  assert(!hidden.html.includes('bowl') && !hidden.text.includes('bowl'), 'notes hidden with the steps');
});

Deno.test('invite email names the sender and contains no sender-written text', () => {
  const email = buildInviteEmail({
    sender: 'jamie@example.com', privacyUrl: 'https://p.example/privacy.html',
    includeRoutineName: false, includeStepCount: true, expiresAt: new Date('2026-10-17T10:00:00Z'),
    acceptUrl: 'https://p.example/a', declineUrl: 'https://p.example/d', blockUrl: 'https://p.example/b',
    oneClickUrl: 'https://f.example/shared-alert-block?token=t',
  });
  assert(email.text.includes('jamie@example.com would like Pebble Routines to email you'), 'sender named');
  assert(email.text.includes('17 October 2026'), 'expiry shown');
  assert(!email.text.includes('routine name'), 'hidden routine name not promised');
  assert(email.text.includes('Each step, and the time it was checked') && email.text.includes('Photos are never emailed.'), 'steps and photos explained');
  assert(email.html.includes('lang="en-GB"') && email.html.includes('prefers-color-scheme: dark'), 'lang + dark mode');
});

Deno.test('mailer retries once on 5xx with the same idempotency key, and redacts errors', async () => {
  const calls: Request[] = [];
  let n = 0;
  const fetchImpl = ((url: string, init: RequestInit) => {
    calls.push(new Request(url, init));
    n++;
    return Promise.resolve(n === 1
      ? new Response('{"name":"internal","message":"failed for bob@example.com"}', { status: 500 })
      : new Response('{"id":"msg_1"}', { status: 200 }));
  }) as typeof fetch;
  const send = resendMailer({ resendApiKey: 'k', fromEmail: 'Pebble <a@p.example>', replyToEmail: null }, fetchImpl, 0);
  const result = await send({ subject: 's', html: 'h', text: 't', headers: { 'List-Unsubscribe': '<x>' }, to: 'r@example.com', idempotencyKey: 'key-1' });
  assert(result.ok && result.id === 'msg_1', 'second attempt ok');
  assert(calls.length === 2 && calls.every((c) => c.headers.get('idempotency-key') === 'key-1'), 'same key');
  const body = await calls[0].json();
  assert(body.headers['List-Unsubscribe'] === '<x>' && body.to[0] === 'r@example.com', 'payload');

  const failing = resendMailer({ resendApiKey: 'k', fromEmail: 'a@p.example', replyToEmail: null },
    (() => Promise.resolve(new Response('{"name":"validation_error","message":"bad to: bob@example.com"}', { status: 422 }))) as unknown as typeof fetch, 0);
  const failed = await failing({ subject: 's', html: 'h', text: 't', headers: {}, to: 'r@example.com', idempotencyKey: 'k2' });
  assert(!failed.ok && !failed.error.includes('bob@') && failed.error.includes('422'), 'redacted, no retry on 4xx');
  assert(summariseProviderError(500, 'not json').startsWith('resend 500'), 'non-json');
  assert(redact('token Zm9vYmFyYmF6Zm9vYmFyYmF6Zm9vYmFyYmF6Zm9vYmFy for a@b.com') === 'token [token] for [email]', 'redact');
});
