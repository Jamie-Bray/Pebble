// Pure rules for AI photo descriptions: limits, the consent version, request
// validation, the verdict-word filter and parsing of the model's reply.
// No I/O, so it is unit tested directly (ai_photo_test.ts). Also used by
// send-routine-completion-alert to filter descriptions before emailing them.

/**
 * The consent wording version the server accepts. Must equal
 * `aiPhotoConsentVersion` in lib/features/ai_photo/ai_photo_constants.dart
 * (test/features/ai_photo/ai_photo_constants_test.dart fails if they differ).
 * Change both when the provider, the retention sentence, the wording or the
 * data sent changes: every earlier consent then stops counting.
 */
export const AI_PHOTO_CONSENT_VERSION = '2026-10-05.5';

export const AI_PHOTO_LIMITS = {
  /** Descriptions one account can request in a rolling 24 hours. */
  dailyPerUser: 20,
  /** Requests per account per UTC calendar month. Enforced in migration 023. */
  monthlyPerUser: 100,
  /** Provider calls allowed across all accounts in a calendar month (UTC). */
  monthlyRequests: 5000,
  /** Decoded JPEG size cap. The app sends about 100-300 KB. */
  maxImageBytes: 1_500_000,
  /** A description is one or two sentences, at most 35 words. */
  maxDescriptionChars: 300,
  maxDescriptionWords: 35,
  /** Descriptions one completion email can carry (five AI photo steps). */
  maxEmailDescriptions: 5,
} as const;

// ---------------------------------------------------------------------------
// Request validation
// ---------------------------------------------------------------------------

/** Client-generated per photo; the app uses the photo's UUID. */
export function isValidIdempotencyKey(value: unknown): value is string {
  return typeof value === 'string' && /^[A-Za-z0-9_-]{8,80}$/.test(value);
}

/**
 * Checks that `value` is base64 for a JPEG no larger than the cap. Returns
 * the decoded size only; the bytes are not kept.
 */
export function validateJpegBase64(value: unknown): { ok: true; bytes: number } | { ok: false; code: string } {
  if (typeof value !== 'string' || value.length < 100) return { ok: false, code: 'imageMissing' };
  // 4 base64 characters carry 3 bytes. Refuse before decoding anything large.
  if (value.length > Math.ceil(AI_PHOTO_LIMITS.maxImageBytes / 3) * 4 + 4) return { ok: false, code: 'imageTooLarge' };
  if (value.length % 4 !== 0 || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) return { ok: false, code: 'imageNotBase64' };
  let head: string;
  try {
    head = atob(value.slice(0, 8));
  } catch (_) {
    return { ok: false, code: 'imageNotBase64' };
  }
  // JPEG files start FF D8 FF.
  if (head.charCodeAt(0) !== 0xff || head.charCodeAt(1) !== 0xd8 || head.charCodeAt(2) !== 0xff) {
    return { ok: false, code: 'imageNotJpeg' };
  }
  const padding = value.endsWith('==') ? 2 : value.endsWith('=') ? 1 : 0;
  const bytes = (value.length / 4) * 3 - padding;
  if (bytes > AI_PHOTO_LIMITS.maxImageBytes) return { ok: false, code: 'imageTooLarge' };
  return { ok: true, bytes };
}

// ---------------------------------------------------------------------------
// Verdict filter
//
// A description may say what is visible ("handle pointing up") but never a
// conclusion about state or safety. Any match discards the whole description.
// The list is the one agreed with the owner, plus plain word forms of it.
// ---------------------------------------------------------------------------

const VERDICT_PATTERNS: RegExp[] = [
  /\b(?:un)?lock(?:ed)\b/i, // locked, unlocked ("a key in the lock" is fine)
  /\b(?:in|un)?secure(?:d|ly)?\b/i,
  /\b(?:un)?safe(?:ly)?\b/i,
  // "off" as a word, except the colour off-white and a subject cut off by
  // the edge of the photo.
  /(?<!\bcut\s)\boff\b(?!-white)/i,
  // "on" as a state. As a preposition ("a pan on the hob") it is fine.
  /\b(?:switched|turned|powered)\s+on\b/i,
  /\b(?:is|are|was|were|be|still|left|remains?|stays?|appears?|looks?|seems?)\s+on\b(?=\s*(?:[.,;:!?)]|$)|\s+(?:and|but|or|while|whilst|though|although|now|again|too|so)\b)/i,
  /\b(?:set|switched|turned)\s+to\s+on\b/i,
  /\bon\s+position\b/i,
  /\b(?:closed|shut|fastened|latched)\s+(?:properly|correctly|securely|fully|tightly|firmly)\b/i,
  /\b(?:properly|correctly|securely|fully|tightly|firmly)\s+(?:closed|shut|fastened|latched)\b/i,
  /\btaken\b/i,
  /\bdone\b/i,
  /\bfine\b/i,
  /\bok(?:ay)?\b/i,
];

export function containsVerdict(text: string): boolean {
  return VERDICT_PATTERNS.some((pattern) => pattern.test(text));
}

// ---------------------------------------------------------------------------
// Descriptions
// ---------------------------------------------------------------------------

const CONTROL_OR_FORMAT = /[\p{Cc}\p{Cf}\u2028\u2029]/gu;

/**
 * A description fit to show or email: control and invisible characters
 * removed, whitespace collapsed, within the length cap and free of verdicts.
 * Returns null when it is not.
 */
export function cleanDescription(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const text = value.replace(CONTROL_OR_FORMAT, ' ').replace(/\s+/g, ' ').trim();
  if (!text || text.length > AI_PHOTO_LIMITS.maxDescriptionChars) return null;
  if (text.split(/\s+/).length > AI_PHOTO_LIMITS.maxDescriptionWords) return null;
  if (containsVerdict(text)) return null;
  return text;
}

/** Descriptions sent by the app for a completion email: at most five, each cleaned. */
export function cleanEmailDescriptions(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .slice(0, AI_PHOTO_LIMITS.maxEmailDescriptions)
    .map(cleanDescription)
    .filter((text): text is string => text !== null);
}

export type ParsedDescription =
  | { ok: true; description: string }
  | { ok: false; code: 'malformed' | 'cannot_tell' | 'verdict' | 'rejected' };

/**
 * Reads the model's reply, which should be
 * {"clarity":"clear"|"partly_unclear"|"cannot_tell","description":"..."}.
 * Anything else, a "cannot_tell", a verdict or an over-long description
 * becomes a failure code. The caller shows "Couldn't describe this photo."
 */
export function parseProviderReply(reply: string): ParsedDescription {
  const start = reply.indexOf('{');
  const end = reply.lastIndexOf('}');
  if (start < 0 || end <= start) return { ok: false, code: 'malformed' };
  let parsed: unknown;
  try {
    parsed = JSON.parse(reply.slice(start, end + 1));
  } catch (_) {
    return { ok: false, code: 'malformed' };
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return { ok: false, code: 'malformed' };
  const { clarity, description } = parsed as Record<string, unknown>;
  if (clarity === 'cannot_tell') return { ok: false, code: 'cannot_tell' };
  if ((clarity !== 'clear' && clarity !== 'partly_unclear') || typeof description !== 'string') {
    return { ok: false, code: 'malformed' };
  }
  if (containsVerdict(description)) return { ok: false, code: 'verdict' };
  const cleaned = cleanDescription(description);
  // A schema-valid reply can still end mid-sentence (for example "points
  // to "). Do not show an incomplete observation as a finished description.
  return cleaned && /[.!?]["'\u201d\u2019)]?$/.test(cleaned)
    ? { ok: true, description: cleaned }
    : { ok: false, code: 'rejected' };
}
