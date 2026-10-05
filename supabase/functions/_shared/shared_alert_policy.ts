// Pure rules for completion emails ("shared alerts"): input validation,
// abuse limits, link tokens and time formatting. No I/O, so it is unit tested
// directly (shared_alert_policy_test.ts).

import { cleanEmailDescriptions } from './ai_photo.ts';

export const DAY_MS = 24 * 60 * 60 * 1000;
export const HOUR_MS = 60 * 60 * 1000;

/** How long an invitation's Allow link works. */
export const INVITE_TTL_MS = 14 * DAY_MS;
/** How long the Stop / Block links in a completion email work. */
export const MANAGE_TTL_MS = 90 * DAY_MS;

export const LIMITS = {
  /** Invitation emails one sender can trigger in 24 hours (all recipients). */
  senderInvitesPerDay: 10,
  /** Invitation emails one sender can send the same address in 7 days. */
  senderRecipientInvitesPerWeek: 3,
  /** Invitation emails one address can receive in 24 hours (all senders). */
  recipientInvitesPerDay: 5,
  /** After someone declines, the same sender waits this long to re-invite. */
  declineCooldownDays: 30,
  /** Pending or accepted contacts one sender can have across routines. */
  maxActiveContacts: 20,
  /** Completion emails one contact can receive per rolling hour / day. */
  contactEmailsPerHour: 3,
  contactEmailsPerDay: 12,
  /** Times a failed completion email may be retried for the same run. */
  maxSendAttempts: 3,
} as const;

export const MAX_TITLE_LENGTH = 120;

export type LinkAction = 'accept' | 'decline' | 'block';
export type TokenPurpose = 'invite' | 'manage';

// ---------------------------------------------------------------------------
// Email addresses
// ---------------------------------------------------------------------------

export function normalizeEmail(email: unknown): string {
  return typeof email === 'string' ? email.trim().toLowerCase() : '';
}

const LOCAL_PART = /^[a-z0-9!#$%&'*+/=?^_`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*$/;
const DOMAIN_LABEL = /^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/;

/**
 * Strict address check for a recipient we are about to email. Rejects display
 * names, angle brackets, commas, quotes and control characters, so the value
 * can never smuggle a second recipient or a header into the provider request.
 * Expects an already-normalised (trimmed, lower-case) address.
 */
export function isValidRecipientEmail(email: string): boolean {
  if (email.length < 6 || email.length > 254) return false;
  const at = email.lastIndexOf('@');
  if (at <= 0 || email.indexOf('@') !== at) return false;
  const local = email.slice(0, at);
  const domain = email.slice(at + 1);
  if (local.length > 64 || !LOCAL_PART.test(local)) return false;
  const labels = domain.split('.');
  if (labels.length < 2) return false;
  if (!labels.every((label) => DOMAIN_LABEL.test(label))) return false;
  const tld = labels[labels.length - 1];
  return /^[a-z]{2,63}$/.test(tld) || /^xn--[a-z0-9-]{2,59}$/.test(tld);
}

/** The sender as the recipient sees them. Only ever the signed-in account email. */
export function senderLabel(email: unknown): string {
  const normalized = normalizeEmail(email);
  return isValidRecipientEmail(normalized) ? normalized : 'A Pebble Routines user';
}

// ---------------------------------------------------------------------------
// Request fields
// ---------------------------------------------------------------------------

/** Routine keys the app generates: `local:<int>` or `cloud:<uuid>`. */
export function isValidRoutineKey(value: unknown): value is string {
  return typeof value === 'string' && /^(local|cloud):[A-Za-z0-9_-]{1,80}$/.test(value);
}

const CONTROL_CHARS = /[\p{Cc}\u2028\u2029]/gu;
const FORMAT_CHARS = /\p{Cf}/gu;

/**
 * Routine title as shown in a completion email: control, format and bidi
 * override characters removed (they can disguise text), whitespace collapsed,
 * and cut to MAX_TITLE_LENGTH characters without splitting an emoji.
 * Zero-width joiners inside emoji sequences are kept.
 */
export function sanitizeTitle(value: unknown): string {
  if (typeof value !== 'string') return '';
  const cleaned = value
    .replace(CONTROL_CHARS, ' ')
    .replace(FORMAT_CHARS, (ch) => (ch === '\u200d' ? ch : ''))
    .replace(/\s+/g, ' ')
    .trim();
  const chars = Array.from(cleaned);
  if (chars.length <= MAX_TITLE_LENGTH) return cleaned;
  return chars.slice(0, MAX_TITLE_LENGTH - 1).join('').trimEnd() + '…';
}

export type CompletionInput = {
  routineKey: string;
  routineTitle: string;
  runId: string;
  sessionId: string | null;
  completedAt: Date;
  /** Minutes east of UTC on the sender's device, when the app sent it. */
  utcOffsetMinutes: number | null;
  /** True when completedAt carried an explicit zone (Z or ±hh:mm). */
  completedAtHasZone: boolean;
  completedSteps: number;
  totalSteps: number;
  /** AI photo descriptions the sender chose to add. Cleaned, verdict-free, at most five. */
  descriptions: string[];
};

export function parseCompletionInput(
  body: unknown,
  now: number,
): { ok: true; value: CompletionInput } | { ok: false; error: string } {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { ok: false, error: 'Invalid JSON body' };
  }
  const b = body as Record<string, unknown>;
  const routineKey = typeof b.routineKey === 'string' ? b.routineKey.trim() : '';
  const routineTitle = sanitizeTitle(b.routineTitle);
  const runId = typeof b.runId === 'string' ? b.runId.trim() : '';
  const sessionId = typeof b.sessionId === 'string' && b.sessionId.trim()
    ? b.sessionId.trim().slice(0, 100)
    : null;
  const rawCompletedAt = typeof b.completedAt === 'string' ? b.completedAt.trim() : '';
  const completedAt = rawCompletedAt ? new Date(rawCompletedAt) : null;

  if (!isValidRoutineKey(routineKey) || !routineTitle || !runId || !completedAt) {
    return { ok: false, error: 'routineKey, routineTitle, runId, and completedAt are required' };
  }
  if (runId.length > 100) return { ok: false, error: 'runId is too long' };
  if (Number.isNaN(completedAt.getTime())) {
    return { ok: false, error: 'completedAt must be a date' };
  }
  // Completion emails go out straight after a run. Allow clock drift and a
  // late retry, but not invented dates. Older app builds sent local time with
  // no zone, which the UTC runtime reads as up to 14 hours ahead.
  const hasZone = /(z|[+-]\d\d:?\d\d)$/i.test(rawCompletedAt);
  const maxAhead = (hasZone ? 10 : 14 * 60 + 10) * 60 * 1000;
  if (completedAt.getTime() > now + maxAhead || completedAt.getTime() < now - 3 * DAY_MS) {
    return { ok: false, error: 'completedAt is out of range' };
  }

  const completedSteps = Number(b.completedSteps);
  const totalSteps = Number(b.totalSteps);
  if (
    !Number.isInteger(completedSteps) || !Number.isInteger(totalSteps) ||
    completedSteps < 0 || totalSteps < 0 || totalSteps > 1000 || completedSteps > totalSteps
  ) {
    return { ok: false, error: 'completedSteps and totalSteps must be non-negative integers' };
  }

  let utcOffsetMinutes: number | null = null;
  if (b.utcOffsetMinutes !== undefined && b.utcOffsetMinutes !== null) {
    const offset = Number(b.utcOffsetMinutes);
    if (!Number.isInteger(offset) || offset < -840 || offset > 840) {
      return { ok: false, error: 'utcOffsetMinutes is out of range' };
    }
    utcOffsetMinutes = offset;
  }

  return {
    ok: true,
    value: {
      routineKey,
      routineTitle,
      runId,
      sessionId,
      completedAt,
      utcOffsetMinutes,
      completedAtHasZone: hasZone,
      completedSteps,
      totalSteps,
      descriptions: cleanEmailDescriptions(b.descriptions),
    },
  };
}

// ---------------------------------------------------------------------------
// Time
// ---------------------------------------------------------------------------

/**
 * "3 Oct 2026, 22:41" in the sender's local time.
 *
 * - New app builds send a UTC timestamp plus `utcOffsetMinutes`, so the time
 *   is shown in the sender's zone with the offset spelled out.
 * - Older builds sent a local wall-clock time with no zone. The edge runtime
 *   runs in UTC, so formatting in UTC shows that wall-clock time unchanged.
 * - A zoned timestamp with no offset is shown in UTC and labelled.
 */
export function formatCompletionTime(input: {
  completedAt: Date;
  utcOffsetMinutes: number | null;
  completedAtHasZone: boolean;
}): string {
  const shifted = input.utcOffsetMinutes === null
    ? input.completedAt
    : new Date(input.completedAt.getTime() + input.utcOffsetMinutes * 60 * 1000);
  const text = shifted.toLocaleString('en-GB', {
    timeZone: 'UTC',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  if (input.utcOffsetMinutes !== null) return `${text} (${offsetLabel(input.utcOffsetMinutes)})`;
  return input.completedAtHasZone ? `${text} (UTC)` : text;
}

export function offsetLabel(minutes: number): string {
  if (minutes === 0) return 'UTC';
  const sign = minutes > 0 ? '+' : '−';
  const abs = Math.abs(minutes);
  const h = Math.floor(abs / 60);
  const m = abs % 60;
  return `UTC${sign}${h}${m ? ':' + String(m).padStart(2, '0') : ''}`;
}

export function formatDate(date: Date): string {
  return date.toLocaleDateString('en-GB', {
    timeZone: 'UTC',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
}

// ---------------------------------------------------------------------------
// Abuse limits
// ---------------------------------------------------------------------------

export type InviteCounts = {
  suppressed: boolean;
  blocked: boolean;
  senderInvitesLastDay: number;
  senderRecipientInvitesLastWeek: number;
  recipientInvitesLastDay: number;
  /** Pending or accepted contacts on the sender's other routines. */
  activeContactsElsewhere: number;
  /** Set while a recent decline stops this sender re-inviting the address. */
  declinedUntil: Date | null;
};

export type Refusal = { ok: false; status: number; code: string; error: string };

export function inviteDecision(counts: InviteCounts, now: number): { ok: true } | Refusal {
  if (counts.suppressed) {
    return refuse(403, 'recipientOptedOut', 'This email address does not accept Pebble invitations.');
  }
  if (counts.blocked) {
    return refuse(403, 'recipientBlocked', 'This recipient has blocked invites from this account');
  }
  if (counts.declinedUntil && counts.declinedUntil.getTime() > now) {
    return refuse(
      409,
      'recentlyDeclined',
      `They declined recently. You can invite this address again from ${formatDate(counts.declinedUntil)}.`,
    );
  }
  if (counts.activeContactsElsewhere >= LIMITS.maxActiveContacts) {
    return refuse(429, 'tooManyContacts', `You can have up to ${LIMITS.maxActiveContacts} contacts. Remove one to add another.`);
  }
  if (counts.senderRecipientInvitesLastWeek >= LIMITS.senderRecipientInvitesPerWeek) {
    return refuse(429, 'recipientWeeklyLimit', 'This address has had several invites this week. Try again in a few days.');
  }
  if (counts.senderInvitesLastDay >= LIMITS.senderInvitesPerDay) {
    return refuse(429, 'senderDailyLimit', 'Too many invites today. Please try again tomorrow.');
  }
  if (counts.recipientInvitesLastDay >= LIMITS.recipientInvitesPerDay) {
    return refuse(429, 'recipientDailyLimit', 'This address has had several invites today. Try again tomorrow.');
  }
  return { ok: true };
}

export function sendDecision(counts: { sentLastHour: number; sentLastDay: number }): 'ok' | 'rateLimited' {
  if (counts.sentLastHour >= LIMITS.contactEmailsPerHour) return 'rateLimited';
  if (counts.sentLastDay >= LIMITS.contactEmailsPerDay) return 'rateLimited';
  return 'ok';
}

function refuse(status: number, code: string, error: string): Refusal {
  return { ok: false, status, code, error };
}

// ---------------------------------------------------------------------------
// Tokens and links
// ---------------------------------------------------------------------------

/** 256 random bits, base64url. Only its SHA-256 is stored. */
export function createToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}

export function isPlausibleToken(token: string): boolean {
  // New tokens are 43 base64url chars; older ones were two UUIDs joined by '.'.
  return token.length >= 20 && token.length <= 128 && /^[A-Za-z0-9._-]+$/.test(token);
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Link in an email. It opens a static page on the Pebble website that reads
 * the token from the URL fragment (never sent to any server, so not logged)
 * and asks the person to confirm. Nothing happens on GET, so mail scanners
 * that open every link change nothing.
 */
export function confirmPageUrl(pagesBase: string, action: LinkAction, token: string): string {
  return `${pagesBase.replace(/\/$/, '')}/confirm/#action=${action}&token=${encodeURIComponent(token)}`;
}

/** RFC 8058 one-click endpoint (mail apps POST `List-Unsubscribe=One-Click`). */
export function oneClickUrl(functionsBase: string, action: 'decline' | 'block', token: string): string {
  return `${functionsBase.replace(/\/$/, '')}/shared-alert-${action}?token=${encodeURIComponent(token)}`;
}

/**
 * Older rows have no `purpose`. Invitations lived 14 days and completion-email
 * links 90, so the lifetime tells them apart.
 */
export function effectivePurpose(row: { purpose?: string | null; created_at: string; expires_at: string }): TokenPurpose {
  if (row.purpose === 'manage') return 'manage';
  const ttl = new Date(row.expires_at).getTime() - new Date(row.created_at).getTime();
  return ttl > 30 * DAY_MS ? 'manage' : 'invite';
}
