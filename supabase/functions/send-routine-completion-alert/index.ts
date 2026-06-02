import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const env = readEnv();
  if (!env.ok) return json({ error: env.error }, 500);

  const auth = await authenticate(req, env.value);
  if (!auth.ok) return json({ error: auth.error }, auth.status);

  let body: {
    routineKey?: string;
    routineTitle?: string;
    runId?: string;
    sessionId?: string;
    completedAt?: string;
    completedSteps?: number;
    totalSteps?: number;
  };
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: 'Invalid JSON body' }, 400);
  }

  const routineKey = body.routineKey?.trim();
  const routineTitle = sanitizeTitle(body.routineTitle);
  const runId = body.runId?.trim();
  const sessionId = body.sessionId?.trim() || null;
  const completedAt = parseDate(body.completedAt);
  const completedSteps = Number(body.completedSteps);
  const totalSteps = Number(body.totalSteps);

  if (!routineKey || !routineTitle || !runId || !completedAt) {
    return json({ error: 'routineKey, routineTitle, runId, and completedAt are required' }, 400);
  }
  if (!Number.isInteger(completedSteps) || !Number.isInteger(totalSteps) || completedSteps < 0 || totalSteps < 0) {
    return json({ error: 'completedSteps and totalSteps must be non-negative integers' }, 400);
  }

  const serviceClient = createClient(env.value.supabaseUrl, env.value.serviceRoleKey);
  if (!await hasActivePersonalEntitlement(serviceClient, auth.user.id)) {
    return json({ sent: false, reason: 'noActiveEntitlement' });
  }

  const { data: contact, error: contactError } = await serviceClient
    .from('shared_alert_contacts')
    .select('*')
    .eq('owner_user_id', auth.user.id)
    .eq('routine_key', routineKey)
    .eq('status', 'accepted')
    .eq('notify_when_finished', true)
    .maybeSingle();

  if (contactError) return json({ error: contactError.message }, 500);
  if (!contact) {
    return json({ sent: false, reason: 'noAcceptedContact' });
  }

  const { data: event, error: eventError } = await serviceClient
    .from('shared_alert_events')
    .insert({
      owner_user_id: auth.user.id,
      contact_id: contact.id,
      routine_key: routineKey,
      run_id: runId,
      session_id: sessionId,
      routine_title: routineTitle,
      completed_at: completedAt.toISOString(),
      completed_steps: completedSteps,
      total_steps: totalSteps,
      status: 'pending',
    })
    .select()
    .single();

  if (eventError) {
    if (eventError.code === '23505') {
      return json({ sent: false, reason: 'duplicateRun' });
    }
    return json({ error: eventError.message }, 500);
  }

  const token = createToken();
  const now = Date.now();

  // Clean up older tokens for this contact to prevent accumulation.
  // We delete tokens created more than 14 days ago. This ensures the recipient
  // always has a working link in recent emails, without unbounded token growth.
  const cleanupThreshold = new Date(now - 14 * 24 * 60 * 60 * 1000).toISOString();
  await serviceClient
    .from('shared_alert_invites')
    .delete()
    .eq('contact_id', contact.id)
    .lt('created_at', cleanupThreshold);

  await serviceClient
    .from('shared_alert_invites')
    .insert({
      contact_id: contact.id,
      token_hash: await sha256Hex(token),
      expires_at: new Date(now + 90 * 24 * 60 * 60 * 1000).toISOString(),
    });

  const emailResult = await sendCompletionEmail({
    env: env.value,
    recipientEmail: contact.recipient_email,
    routineTitle,
    completedAt,
    completedSteps,
    totalSteps,
    includeRoutineName: contact.include_routine_name !== false,
    includeStepCount: contact.include_step_count !== false,
    token,
  });

  if (!emailResult.ok) {
    await serviceClient
      .from('shared_alert_events')
      .update({
        status: 'failed',
        provider: 'resend',
        error_summary: emailResult.error.slice(0, 500),
        provider_response: { error: emailResult.error },
      })
      .eq('id', event.id);
    return json({ error: 'Completion email could not be sent' }, 502);
  }

  await serviceClient
    .from('shared_alert_events')
    .update({
      status: 'sent',
      provider: 'resend',
      provider_message_id: emailResult.id,
      provider_response: emailResult.response,
    })
    .eq('id', event.id);

  return json({
    sent: true,
    eventId: event.id,
    recipientEmail: contact.recipient_email,
  });
});

async function sendCompletionEmail(input: {
  env: Env;
  recipientEmail: string;
  routineTitle: string;
  completedAt: Date;
  completedSteps: number;
  totalSteps: number;
  includeRoutineName: boolean;
  includeStepCount: boolean;
  token: string;
}): Promise<{ ok: true; id: string | null; response: unknown } | { ok: false; error: string }> {
  const declineUrl = actionUrl(input.env.publicBaseUrl, 'shared-alert-decline', input.token);
  const blockUrl = actionUrl(input.env.publicBaseUrl, 'shared-alert-block', input.token);
  const time = formatCompletionTime(input.completedAt);
  const routinePart = input.includeRoutineName ? input.routineTitle : 'A routine';
  const stepPart = input.includeStepCount
    ? ` ${input.completedSteps} of ${input.totalSteps} steps completed.`
    : '';
  const sentence = `${routinePart} was completed at ${time}.${stepPart}`;
  const text = [
    'Pebble routine completed',
    '',
    sentence,
    '',
    `Stop these emails: ${declineUrl}`,
    `Block this sender: ${blockUrl}`,
    '',
    'You are receiving this because you accepted Pebble completion alerts from this sender.',
  ].join('\n');
  const html = emailShell({
    preheader: 'A Pebble routine was completed.',
    title: 'Routine completed',
    body: [sentence],
    secondaryLinks: [
      { label: 'Stop these emails', url: declineUrl },
      { label: 'Block this sender', url: blockUrl },
    ],
    footer: 'You are receiving this because you accepted Pebble completion alerts from this sender.',
  });

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${input.env.resendApiKey}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      from: input.env.fromEmail,
      to: [input.recipientEmail],
      subject: 'Pebble routine completed',
      text,
      html,
      ...(input.env.replyToEmail ? { reply_to: input.env.replyToEmail } : {}),
    }),
  });

  const responseText = await response.text();
  const responseBody = parseResponseBody(responseText);
  if (!response.ok) {
    return { ok: false, error: JSON.stringify(responseBody) };
  }
  const id = typeof responseBody === 'object' && responseBody && 'id' in responseBody
    ? String((responseBody as { id?: unknown }).id ?? '')
    : null;
  return { ok: true, id, response: responseBody };
}

type Env = {
  supabaseUrl: string;
  anonKey: string;
  serviceRoleKey: string;
  resendApiKey: string;
  fromEmail: string;
  replyToEmail: string | null;
  publicBaseUrl: string;
};

function readEnv(): { ok: true; value: Env } | { ok: false; error: string } {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const resendApiKey = Deno.env.get('RESEND_API_KEY');
  const fromEmail = Deno.env.get('SHARED_ALERT_FROM_EMAIL');
  const replyToEmail = normalizeOptionalEmail(Deno.env.get('SHARED_ALERT_REPLY_TO_EMAIL'));
  const publicBaseUrl = Deno.env.get('SHARED_ALERT_PUBLIC_BASE_URL');
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !resendApiKey || !fromEmail || !publicBaseUrl) {
    return { ok: false, error: 'Shared alert environment is not configured' };
  }
  return { ok: true, value: { supabaseUrl, anonKey, serviceRoleKey, resendApiKey, fromEmail, replyToEmail, publicBaseUrl } };
}

async function authenticate(req: Request, env: Env) {
  const authorization = req.headers.get('authorization') ?? '';
  const jwt = authorization.replace(/^Bearer\s+/i, '').trim();
  if (!jwt) return { ok: false as const, status: 401, error: 'Missing user authorization' };

  const userClient = createClient(env.supabaseUrl, env.anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data, error } = await userClient.auth.getUser(jwt);
  if (error || !data.user) {
    return { ok: false as const, status: 401, error: 'Invalid user authorization' };
  }
  return { ok: true as const, user: data.user };
}

async function hasActivePersonalEntitlement(
  serviceClient: ReturnType<typeof createClient>,
  userId: string,
): Promise<boolean> {
  const { data, error } = await serviceClient.rpc(
    'has_active_personal_entitlement',
    { user_id: userId },
  );
  if (error) return false;
  return data === true;
}

function parseDate(value: unknown): Date | null {
  if (typeof value !== 'string') return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function sanitizeTitle(value: unknown): string {
  if (typeof value !== 'string') return '';
  return value.trim().slice(0, 160);
}

function formatCompletionTime(date: Date): string {
  return date.toLocaleString('en-GB', {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
}

function actionUrl(base: string, functionName: string, token: string): string {
  return `${base.replace(/\/$/, '')}/${functionName}?token=${encodeURIComponent(token)}`;
}

function normalizeOptionalEmail(value: string | undefined): string | null {
  if (typeof value !== 'string') return null;
  const email = value.trim().toLowerCase();
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) && email.length <= 320 ? email : null;
}

function createToken(): string {
  return `${crypto.randomUUID()}.${crypto.randomUUID()}`;
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function escapeHtml(value: string): string {
  return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}

function emailShell(input: {
  preheader: string;
  title: string;
  body: string[];
  secondaryLinks: { label: string; url: string }[];
  footer: string;
}): string {
  const paragraphs = input.body
    .map((line) => `<p style="margin:0 0 14px;color:#253047;font-size:17px;line-height:1.58;font-weight:600;">${escapeHtml(line)}</p>`)
    .join('');
  const links = input.secondaryLinks
    .map((link) => `<a href="${link.url}" style="color:#4b5cff;text-decoration:none;border-bottom:1px solid #c7ccff;">${escapeHtml(link.label)}</a>`)
    .join('<span style="color:#a0a7b8;"> &nbsp;|&nbsp; </span>');
  return `<!doctype html>
<html lang="en">
<body style="margin:0;padding:0;background:#f6f7fb;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;color:#111827;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${escapeHtml(input.preheader)}</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f6f7fb;padding:32px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border:1px solid #e7e9f2;border-radius:26px;box-shadow:0 18px 48px rgba(27,39,82,.10);overflow:hidden;">
          <tr><td>
            <div style="padding:30px 32px 0;background:linear-gradient(135deg,#ffffff 0%,#f7f8ff 52%,#f2fffb 100%);">
              <p style="margin:0 0 20px;">
                <span style="display:inline-block;background:#111827;color:#ffffff;border-radius:999px;padding:7px 11px;font-size:12px;font-weight:800;letter-spacing:0;">Pebble</span>
                <span style="display:inline-block;margin-left:8px;color:#667085;font-size:13px;">Completion update</span>
              </p>
              <h1 style="margin:0 0 12px;color:#111827;font-size:32px;line-height:1.12;font-weight:800;letter-spacing:0;">${escapeHtml(input.title)}</h1>
              <p style="margin:0;color:#596277;font-size:15px;line-height:1.55;">A trusted contact update from Pebble.</p>
            </div>
            <div style="padding:26px 32px 30px;background:#ffffff;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:0 0 20px;background:#f8fafc;border:1px solid #e7eaf3;border-radius:18px;">
                <tr>
                  <td style="padding:18px 18px 16px;">
                    ${paragraphs}
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 20px;font-size:13px;line-height:1.5;">${links}</p>
              <p style="margin:20px 0 0;border-top:1px solid #edf0f6;padding-top:16px;color:#667085;font-size:12px;line-height:1.55;">${escapeHtml(input.footer)}</p>
            </div>
          </td></tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function parseResponseBody(value: string): unknown {
  try {
    return JSON.parse(value);
  } catch (_) {
    return { body: value };
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}
