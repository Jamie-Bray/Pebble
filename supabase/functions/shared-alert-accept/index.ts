import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
};

const redirectTargets = {
  accepted: 'https://pebbleroutines.com/shared-alert/accepted',
  problem: 'https://pebbleroutines.com/shared-alert/problem',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'GET' && req.method !== 'POST') {
    return redirectTo(redirectTargets.problem);
  }

  const env = readEnv();
  if (!env.ok) return redirectTo(redirectTargets.problem);

  const token = tokenFromRequest(req);
  if (!token) return redirectTo(redirectTargets.problem);

  const serviceClient = createClient(env.value.supabaseUrl, env.value.serviceRoleKey);
  const invite = await findInvite(serviceClient, token);
  if (!invite.ok) return redirectTo(redirectTargets.problem);

  const now = new Date().toISOString();
  const { error: contactError } = await serviceClient
    .from('shared_alert_contacts')
    .update({
      status: 'accepted',
      notify_when_finished: true,
      accepted_at: now,
      declined_at: null,
      blocked_at: null,
      disabled_at: null,
    })
    .eq('id', invite.row.contact_id);

  if (contactError) return redirectTo(redirectTargets.problem);

  const { error: inviteError } = await serviceClient
    .from('shared_alert_invites')
    .update({ accepted_at: now })
    .eq('id', invite.row.id);

  if (inviteError) return redirectTo(redirectTargets.problem);

  return redirectTo(redirectTargets.accepted);
});

type Env = { supabaseUrl: string; serviceRoleKey: string };

function readEnv(): { ok: true; value: Env } | { ok: false; error: string } {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return { ok: false, error: 'Shared alert environment is not configured.' };
  }
  return { ok: true, value: { supabaseUrl, serviceRoleKey } };
}

async function findInvite(serviceClient: ReturnType<typeof createClient>, token: string) {
  const { data, error } = await serviceClient
    .from('shared_alert_invites')
    .select('id, contact_id, expires_at, accepted_at, declined_at, blocked_at')
    .eq('token_hash', await sha256Hex(token))
    .maybeSingle();

  if (error) return { ok: false as const, status: 500, error: error.message };
  if (!data) return { ok: false as const, status: 404, error: 'This invite link was not found.' };
  if (data.blocked_at) return { ok: false as const, status: 410, error: 'This invite has already been blocked.' };
  if (data.declined_at) return { ok: false as const, status: 410, error: 'This invite has already been declined.' };
  if (new Date(data.expires_at).getTime() < Date.now()) {
    return { ok: false as const, status: 410, error: 'This invite link has expired.' };
  }
  return { ok: true as const, row: data };
}

function tokenFromRequest(req: Request): string {
  const url = new URL(req.url);
  return url.searchParams.get('token')?.trim() ?? '';
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function redirectTo(location: string): Response {
  return new Response(null, {
    status: 303,
    headers: {
      ...corsHeaders,
      Location: location,
      'Cache-Control': 'no-store',
    },
  });
}
