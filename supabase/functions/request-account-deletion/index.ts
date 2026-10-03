import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  clientIp,
  EMAIL_WINDOW_MS,
  GLOBAL_WINDOW_MS,
  IP_WINDOW_MS,
  MAX_BODY_BYTES,
  MAX_USER_AGENT_LENGTH,
  throttleDecision,
  validateDeletionRequest,
} from './validate.ts';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers':
    'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

// deno-lint-ignore no-explicit-any
type ServiceClient = any;

export async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const declaredLength = Number(req.headers.get('content-length') ?? '0');
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
    return json({ error: 'Request is too large' }, 413);
  }

  let body: unknown;
  try {
    const raw = await req.text();
    if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) {
      return json({ error: 'Request is too large' }, 413);
    }
    body = JSON.parse(raw);
  } catch (_) {
    return json({ error: 'Invalid request body' }, 400);
  }

  const validated = validateDeletionRequest(body);
  if (!validated.ok) {
    return json({ error: validated.error }, 400);
  }
  const { email, normalizedEmail, message } = validated.value;

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: 'Supabase environment is not configured' }, 500);
  }

  const serviceClient = createClient(supabaseUrl, serviceRoleKey);
  const ip = clientIp(req.headers);
  const requestIpHash = ip === null ? null : await sha256Hex(ip);

  const counts = await throttleCounts(serviceClient, normalizedEmail, requestIpHash);
  if (counts.value === null) {
    log({ message: 'throttle_lookup_failed', error: counts.error });
    return json({ error: 'Could not submit the deletion request.' }, 500);
  }
  const decision = throttleDecision(counts.value);
  if (decision === 'rate_limited') {
    log({ message: 'rate_limited', has_ip: requestIpHash !== null });
    return json(
      { error: 'Too many requests. Please try again later.' },
      429,
      { 'retry-after': '3600' },
    );
  }
  if (decision === 'duplicate') {
    // Same answer as a new request, so the form cannot be used to learn
    // whether an address has already asked. The earlier request stands.
    log({ message: 'duplicate_within_window' });
    return json({ ok: true });
  }

  const userAgent = req.headers.get('user-agent')?.slice(0, MAX_USER_AGENT_LENGTH) ??
    null;
  const { data, error } = await serviceClient
    .from('account_deletion_requests')
    .insert({
      email,
      normalized_email: normalizedEmail,
      message,
      confirmed_understanding: true,
      status: 'new',
      source: 'web',
      request_ip_hash: requestIpHash,
      user_agent: userAgent,
    })
    .select('id')
    .single();

  if (error) {
    log({ message: 'insert_failed', error: error.message });
    return json({ error: 'Could not submit the deletion request.' }, 500);
  }

  log({ message: 'request_recorded', request_id: data.id });
  return json({ ok: true, requestId: data.id });
}

async function throttleCounts(
  client: ServiceClient,
  normalizedEmail: string,
  requestIpHash: string | null,
): Promise<
  | {
    value: { recentForEmail: number; recentForIp: number; recentGlobal: number };
    error: null;
  }
  | { value: null; error: string }
> {
  const now = Date.now();
  const count = async (
    filter: (query: ServiceClient) => ServiceClient,
    windowMs: number,
  ): Promise<number | string> => {
    const query = client
      .from('account_deletion_requests')
      .select('id', { count: 'exact', head: true })
      .gte('created_at', new Date(now - windowMs).toISOString());
    const { count, error } = await filter(query);
    return error ? error.message : count ?? 0;
  };

  const [forEmail, forIp, global] = await Promise.all([
    count((q) => q.eq('normalized_email', normalizedEmail), EMAIL_WINDOW_MS),
    requestIpHash === null
      ? Promise.resolve(0)
      : count((q) => q.eq('request_ip_hash', requestIpHash), IP_WINDOW_MS),
    count((q) => q, GLOBAL_WINDOW_MS),
  ]);
  for (const value of [forEmail, forIp, global]) {
    if (typeof value === 'string') return { value: null, error: value };
  }
  return {
    value: {
      recentForEmail: forEmail as number,
      recentForIp: forIp as number,
      recentGlobal: global as number,
    },
    error: null,
  };
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function json(
  body: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      ...extraHeaders,
      'content-type': 'application/json',
    },
  });
}

function log(fields: Record<string, unknown>) {
  console.log(JSON.stringify({ scope: 'request-account-deletion', ...fields }));
}

if (import.meta.main) {
  serve(handler);
}
