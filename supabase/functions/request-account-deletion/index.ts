import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers':
    'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: 'Invalid request body' }, 400);
  }

  const email = body.email?.toString().trim() ?? '';
  const message = body.message?.toString().trim() ?? '';
  const confirmed = body.confirmed === true;
  const normalizedEmail = email.toLowerCase();

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return json({ error: 'Enter the email address linked to your Pebble account.' }, 400);
  }

  if (!confirmed) {
    return json(
      {
        error:
          'Confirm that you understand this requests deletion of cloud account and backup data.',
      },
      400,
    );
  }

  if (message.length > 2000) {
    return json({ error: 'Message must be 2,000 characters or fewer.' }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: 'Supabase environment is not configured' }, 500);
  }

  const serviceClient = createClient(supabaseUrl, serviceRoleKey);
  const requestIp = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    req.headers.get('cf-connecting-ip')?.trim() ??
    '';
  const requestIpHash = requestIp.length === 0 ? null : await sha256Hex(requestIp);

  const { data, error } = await serviceClient
    .from('account_deletion_requests')
    .insert({
      email,
      normalized_email: normalizedEmail,
      message: message.isEmpty ? null : message,
      confirmed_understanding: confirmed,
      status: 'new',
      source: 'web',
      request_ip_hash: requestIpHash,
      user_agent: req.headers.get('user-agent'),
    })
    .select('id')
    .single();

  if (error) {
    return json({ error: error.message }, 500);
  }

  return json({ ok: true, requestId: data.id });
});

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'content-type': 'application/json',
    },
  });
}
