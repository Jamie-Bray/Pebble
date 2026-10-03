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
    'Routine completed',
    '',
    sentence,
    '',
    `Stop these emails: ${declineUrl}`,
    `Block this sender: ${blockUrl}`,
    '',
    'You received this because you allowed completion emails from this Pebble user.',
  ].join('\n');
  const html = emailShell({
    preheader: `${routinePart} was completed at ${time}.`,
    eyebrow: 'Completion update',
    title: 'Routine completed',
    intro: 'Here is the completion update you asked Pebble to send.',
    routine: routinePart,
    completed: time,
    steps: input.includeStepCount
      ? `${input.completedSteps} of ${input.totalSteps}`
      : null,
    secondaryLinks: [
      { label: 'Stop these emails', url: declineUrl },
      { label: 'Block this sender', url: blockUrl },
    ],
    footer: 'You received this because you allowed completion emails from this Pebble user.',
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
      subject: 'Routine completed · Pebble',
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
  eyebrow: string;
  title: string;
  intro: string;
  routine: string;
  completed: string;
  steps: string | null;
  secondaryLinks: { label: string; url: string }[];
  footer: string;
}): string {
  const detailRow = (label: string, value: string, isLast = false) => `
    <tr>
      <td style="padding:14px 0;${isLast ? '' : 'border-bottom:1px solid #e2e6e2;'}color:#718077;font-size:13px;line-height:1.4;vertical-align:top;">${escapeHtml(label)}</td>
      <td align="right" style="padding:14px 0 14px 20px;${isLast ? '' : 'border-bottom:1px solid #e2e6e2;'}color:#243129;font-size:14px;line-height:1.4;font-weight:750;vertical-align:top;">${escapeHtml(value)}</td>
    </tr>`;
  const details = [
    detailRow('Routine', input.routine),
    detailRow('Completed', input.completed, input.steps === null),
    input.steps === null ? '' : detailRow('Steps', input.steps, true),
  ].join('');
  const links = input.secondaryLinks
    .map((link) => `<a href="${link.url}" style="color:#53665b;text-decoration:underline;text-decoration-color:#b7c0ba;text-underline-offset:3px;">${escapeHtml(link.label)}</a>`)
    .join('<span style="color:#b2bbb5;"> &nbsp;&nbsp;·&nbsp;&nbsp; </span>');
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="color-scheme" content="light">
  <style>
    @media only screen and (max-width:620px) {
      .email-shell { padding:20px 12px !important; }
      .email-card { border-radius:18px !important; }
      .email-section { padding-left:22px !important; padding-right:22px !important; }
      .email-title { font-size:30px !important; }
    }
  </style>
</head>
<body style="margin:0;padding:0;background:#f3f1ec;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;color:#1d2922;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${escapeHtml(input.preheader)}</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" class="email-shell" style="width:100%;background:#f3f1ec;padding:40px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" class="email-card" style="width:100%;max-width:580px;background:#fffdfa;border:1px solid #deddd7;border-radius:24px;box-shadow:0 16px 42px rgba(42,55,47,.08);overflow:hidden;">
          <tr>
            <td class="email-section" style="padding:26px 34px 24px;border-bottom:1px solid #ebe9e3;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                <tr>
                  <td><span style="display:inline-block;background:#24382d;color:#ffffff;border-radius:999px;padding:8px 12px;font-size:12px;line-height:1;font-weight:800;letter-spacing:.2px;">Pebble</span></td>
                  <td align="right" style="color:#718077;font-size:12px;font-weight:700;letter-spacing:.5px;text-transform:uppercase;">${escapeHtml(input.eyebrow)}</td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td class="email-section" style="padding:38px 34px 34px;">
              <table role="presentation" cellspacing="0" cellpadding="0" style="margin:0 0 22px;">
                <tr>
                  <td align="center" style="width:42px;height:42px;background:#e4eee7;border-radius:999px;color:#2e5b43;font-size:22px;font-weight:800;">✓</td>
                </tr>
              </table>
              <h1 class="email-title" style="margin:0 0 12px;color:#1d2922;font-size:36px;line-height:1.12;font-weight:800;letter-spacing:-.7px;">${escapeHtml(input.title)}</h1>
              <p style="margin:0 0 28px;color:#536159;font-size:16px;line-height:1.6;">${escapeHtml(input.intro)}</p>
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:0 0 28px;background:#f3f5f1;border:1px solid #dfe5df;border-radius:16px;">
                <tr>
                  <td style="padding:6px 20px;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                      ${details}
                    </table>
                  </td>
                </tr>
              </table>
              <p style="margin:0;font-size:13px;line-height:1.6;">${links}</p>
            </td>
          </tr>
          <tr>
            <td class="email-section" style="padding:20px 34px 24px;background:#f8f7f3;border-top:1px solid #ebe9e3;">
              <p style="margin:0;color:#748078;font-size:12px;line-height:1.6;">${escapeHtml(input.footer)}</p>
            </td>
          </tr>
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
