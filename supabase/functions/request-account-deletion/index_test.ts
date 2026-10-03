import { handler } from './index.ts';
import {
  clientIp,
  IP_MAX_REQUESTS,
  isValidEmail,
  throttleDecision,
  validateDeletionRequest,
} from './validate.ts';

function assert(condition: boolean, label: string) {
  if (!condition) throw new Error(label);
}

Deno.test('empty message is stored as null, not an empty string', () => {
  for (const message of [undefined, null, '', '   ', '\u0000\u0007']) {
    const result = validateDeletionRequest({
      email: 'a@example.com',
      confirmed: true,
      message,
    });
    assert(result.ok && result.value.message === null, `message ${JSON.stringify(message)}`);
  }
});

Deno.test('message keeps text, strips control characters, enforces 2000 chars', () => {
  const ok = validateDeletionRequest({
    email: 'a@example.com',
    confirmed: true,
    message: ' Please\u0000 delete\nmy data ',
  });
  assert(ok.ok && ok.value.message === 'Please delete\nmy data', 'cleaned message');
  const tooLong = validateDeletionRequest({
    email: 'a@example.com',
    confirmed: true,
    message: 'x'.repeat(2001),
  });
  assert(!tooLong.ok, 'long message rejected');
  const notText = validateDeletionRequest({
    email: 'a@example.com',
    confirmed: true,
    message: { nested: true },
  });
  assert(!notText.ok, 'non-string message rejected');
});

Deno.test('email validation', () => {
  for (const good of ['a@example.com', 'first.last+tag@sub.example.co.uk']) {
    assert(isValidEmail(good), `accept ${good}`);
  }
  for (const bad of [
    '',
    'plain',
    'a@b',
    'a@b.c',
    'a@@example.com',
    '.a@example.com',
    'a..b@example.com',
    'a b@example.com',
    'a@example.123',
    `${'x'.repeat(65)}@example.com`,
    `a@${'x'.repeat(250)}.com`,
    '<script>@example.com',
  ]) {
    assert(!isValidEmail(bad), `reject ${bad}`);
  }
});

Deno.test('confirmation and body shape are required', () => {
  assert(!validateDeletionRequest({ email: 'a@example.com' }).ok, 'unconfirmed');
  assert(!validateDeletionRequest({ email: 'a@example.com', confirmed: 'true' }).ok, 'string true');
  assert(!validateDeletionRequest(null).ok, 'null body');
  assert(!validateDeletionRequest(['a@example.com']).ok, 'array body');
  const ok = validateDeletionRequest({ email: ' A@Example.com ', confirmed: true });
  assert(ok.ok && ok.value.normalizedEmail === 'a@example.com', 'normalised');
});

Deno.test('clientIp prefers the Cloudflare header over x-forwarded-for', () => {
  assert(
    clientIp(new Headers({ 'cf-connecting-ip': '1.1.1.1', 'x-forwarded-for': '9.9.9.9, 1.1.1.1' })) === '1.1.1.1',
    'cf first',
  );
  assert(clientIp(new Headers({ 'x-forwarded-for': '2.2.2.2, 3.3.3.3' })) === '2.2.2.2', 'xff fallback');
  assert(clientIp(new Headers()) === null, 'none');
});

Deno.test('throttleDecision', () => {
  assert(throttleDecision({ recentForEmail: 0, recentForIp: 0, recentGlobal: 0 }) === 'accept', 'accept');
  assert(throttleDecision({ recentForEmail: 1, recentForIp: 0, recentGlobal: 1 }) === 'duplicate', 'dup');
  assert(
    throttleDecision({ recentForEmail: 0, recentForIp: IP_MAX_REQUESTS, recentGlobal: 5 }) === 'rate_limited',
    'ip',
  );
  assert(throttleDecision({ recentForEmail: 0, recentForIp: 0, recentGlobal: 1000 }) === 'rate_limited', 'global');
});

Deno.test('handler rejects oversized and invalid bodies before touching the database', async () => {
  const big = await handler(
    new Request('https://example.test/request-account-deletion', {
      method: 'POST',
      body: JSON.stringify({ email: 'a@example.com', confirmed: true, message: 'x'.repeat(20_000) }),
    }),
  );
  assert(big.status === 413, `expected 413, got ${big.status}`);
  const bad = await handler(
    new Request('https://example.test/request-account-deletion', {
      method: 'POST',
      body: JSON.stringify({ email: 'nope', confirmed: true }),
    }),
  );
  assert(bad.status === 400, `expected 400, got ${bad.status}`);
});
