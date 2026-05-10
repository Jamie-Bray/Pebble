import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
};

const redirectTargets = {
  blocked: 'https://pebbleroutines.com/shared-alert/blocked',
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

  const token = new URL(req.url).searchParams.get('token')?.trim() ?? '';
  if (!token) return redirectTo(redirectTargets.problem);

  const serviceClient = createClient(env.value.supabaseUrl, env.value.serviceRoleKey);
  const invite = await findInvite(serviceClient, token);
  if (!invite.ok) return redirectTo(redirectTargets.problem);

  const { data: contact, error: contactReadError } = await serviceClient
    .from('shared_alert_contacts')
    .select('id, owner_user_id, normalized_email, recipient_email_hash')
    .eq('id', invite.row.contact_id)
    .single();

  if (contactReadError) return redirectTo(redirectTargets.problem);

  const now = new Date().toISOString();
  const { error: blockError } = await serviceClient
    .from('shared_alert_blocks')
    .upsert({
      sender_user_id: contact.owner_user_id,
      normalized_email: contact.normalized_email,
      recipient_email_hash: contact.recipient_email_hash,
      reason: 'recipient_blocked',
      updated_at: now,
    }, { onConflict: 'sender_user_id,recipient_email_hash' });

  if (blockError) return redirectTo(redirectTargets.problem);

  const { error: contactError } = await serviceClient
    .from('shared_alert_contacts')
    .update({
      status: 'blocked',
      notify_when_finished: false,
      blocked_at: now,
    })
    .eq('id', contact.id);

  if (contactError) return redirectTo(redirectTargets.problem);

  const { error: inviteError } = await serviceClient
    .from('shared_alert_invites')
    .update({ blocked_at: now })
    .eq('id', invite.row.id);

  if (inviteError) return redirectTo(redirectTargets.problem);

  return redirectTo(redirectTargets.blocked);
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
    .select('id, contact_id, expires_at, blocked_at')
    .eq('token_hash', await sha256Hex(token))
    .maybeSingle();

  if (error) return { ok: false as const, status: 500, error: error.message };
  if (!data) return { ok: false as const, status: 404, error: 'This invite link was not found.' };
  if (data.blocked_at) return { ok: false as const, status: 410, error: 'This invite has already been blocked.' };
  if (new Date(data.expires_at).getTime() < Date.now()) {
    return { ok: false as const, status: 410, error: 'This invite link has expired.' };
  }
  return { ok: true as const, row: data };
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
