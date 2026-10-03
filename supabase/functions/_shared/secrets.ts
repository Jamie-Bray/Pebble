// Constant-time shared-secret comparison for endpoints that are not protected
// by Supabase JWT verification (cron job, RevenueCat webhook).
//
// Both values are hashed first so the comparison always runs over 32 bytes,
// regardless of input length, then compared without early exit.

export async function secretsMatch(
  provided: string | null | undefined,
  expected: string | null | undefined,
): Promise<boolean> {
  const a = provided?.trim() ?? '';
  const b = expected?.trim() ?? '';
  // Fail closed: an unset or blank expected secret never matches anything.
  if (a.length === 0 || b.length === 0) return false;
  const [da, db] = await Promise.all([digest(a), digest(b)]);
  let diff = 0;
  for (let i = 0; i < da.length; i++) diff |= da[i] ^ db[i];
  return diff === 0;
}

/** Strips an optional `Bearer ` prefix from an Authorization header value. */
export function stripBearer(value: string | null | undefined): string {
  return (value ?? '').replace(/^Bearer\s+/i, '').trim();
}

async function digest(value: string): Promise<Uint8Array> {
  const bytes = new TextEncoder().encode(value);
  return new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
}
