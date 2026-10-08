// The Supabase clients build-routine needs, kept here rather than imported
// from ../_shared/shared_alert_runtime.ts so this function's bundle stays
// small and separate from the email code.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export type AuthUser = { id: string; email: string | null };

/** The signed-in user, or null for a missing, anonymous or invalid token. */
export function optionalAuthenticator(env: { supabaseUrl: string; anonKey: string }) {
  return async (req: Request): Promise<AuthUser | null> => {
    const jwt = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '').trim();
    if (!jwt || jwt === env.anonKey) return null;
    const client = createClient(env.supabaseUrl, env.anonKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const { data, error } = await client.auth.getUser(jwt);
    if (error || !data.user || data.user.is_anonymous) return null;
    return { id: data.user.id, email: data.user.email ?? null };
  };
}

export function serviceClient(env: { supabaseUrl: string; serviceRoleKey: string }) {
  return createClient(env.supabaseUrl, env.serviceRoleKey, { auth: { persistSession: false } });
}
