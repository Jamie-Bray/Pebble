// Pure input validation and throttle rules for the public deletion form.

export const MAX_BODY_BYTES = 8 * 1024;
export const MAX_EMAIL_LENGTH = 254;
export const MAX_MESSAGE_LENGTH = 2000;
export const MAX_USER_AGENT_LENGTH = 512;

/** One stored request per email per window; repeats are acknowledged silently. */
export const EMAIL_WINDOW_MS = 24 * 60 * 60 * 1000;
/** Requests accepted from one IP per window. */
export const IP_WINDOW_MS = 60 * 60 * 1000;
export const IP_MAX_REQUESTS = 5;
/** Global ceiling across all callers per window, against IP rotation. */
export const GLOBAL_WINDOW_MS = 60 * 60 * 1000;
export const GLOBAL_MAX_REQUESTS = 100;

export type DeletionRequestInput = {
  email: string;
  normalizedEmail: string;
  message: string | null;
};

export type ValidationResult =
  | { ok: true; value: DeletionRequestInput }
  | { ok: false; error: string };

const EMAIL_PATTERN =
  /^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$/;

export function isValidEmail(email: string): boolean {
  if (email.length === 0 || email.length > MAX_EMAIL_LENGTH) return false;
  if (!EMAIL_PATTERN.test(email)) return false;
  const [local, domain] = email.split('@');
  if (local.length > 64 || local.startsWith('.') || local.endsWith('.')) {
    return false;
  }
  if (local.includes('..')) return false;
  const tld = domain.split('.').pop() ?? '';
  return tld.length >= 2 && !/^\d+$/.test(tld);
}

/** Removes control characters except tab and newline. */
export function stripControlCharacters(value: string): string {
  // deno-lint-ignore no-control-regex
  return value.replace(/[\u0000-\u0008\u000B-\u001F\u007F]/g, '');
}

export function validateDeletionRequest(body: unknown): ValidationResult {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    return { ok: false, error: 'Invalid request body' };
  }
  const record = body as Record<string, unknown>;

  const rawEmail = typeof record.email === 'string' ? record.email.trim() : '';
  if (!isValidEmail(rawEmail)) {
    return {
      ok: false,
      error: 'Enter the email address linked to your Pebble account.',
    };
  }

  if (record.confirmed !== true) {
    return {
      ok: false,
      error:
        'Confirm that you understand this requests deletion of cloud account and backup data.',
    };
  }

  if (record.message !== undefined && record.message !== null &&
    typeof record.message !== 'string') {
    return { ok: false, error: 'Message must be text.' };
  }
  const message = stripControlCharacters(
    typeof record.message === 'string' ? record.message : '',
  ).trim();
  if (message.length > MAX_MESSAGE_LENGTH) {
    return { ok: false, error: 'Message must be 2,000 characters or fewer.' };
  }

  return {
    ok: true,
    value: {
      email: rawEmail,
      normalizedEmail: rawEmail.toLowerCase(),
      message: message.length === 0 ? null : message,
    },
  };
}

/**
 * Client IP as seen by Supabase's edge. `cf-connecting-ip` is set by
 * Cloudflare and cannot be supplied by the caller; `x-forwarded-for` is only a
 * fallback.
 */
export function clientIp(headers: Headers): string | null {
  const cf = headers.get('cf-connecting-ip')?.trim();
  if (cf) return cf;
  const forwarded = headers.get('x-forwarded-for')?.split(',')[0]?.trim();
  return forwarded ? forwarded : null;
}

export type ThrottleCounts = {
  recentForEmail: number;
  recentForIp: number;
  recentGlobal: number;
};

export type ThrottleDecision = 'accept' | 'duplicate' | 'rate_limited';

export function throttleDecision(counts: ThrottleCounts): ThrottleDecision {
  if (counts.recentGlobal >= GLOBAL_MAX_REQUESTS) return 'rate_limited';
  if (counts.recentForIp >= IP_MAX_REQUESTS) return 'rate_limited';
  if (counts.recentForEmail > 0) return 'duplicate';
  return 'accept';
}
