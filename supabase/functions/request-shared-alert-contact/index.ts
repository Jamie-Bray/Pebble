import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const env = readEnv();
  if (!env.ok) return json({ error: env.error }, 500);

  const auth = await authenticate(req, env.value);
  if (!auth.ok) return json({ error: auth.error }, auth.status);

  const serviceClient = createClient(env.value.supabaseUrl, env.value.serviceRoleKey);
  const userId = auth.user.id;

  if (req.method === 'GET') {
    const routineKey = new URL(req.url).searchParams.get('routineKey')?.trim();
    if (!routineKey) return json({ error: 'routineKey is required' }, 400);

    const { data, error } = await serviceClient
      .from('shared_alert_contacts')
      .select('*')
      .eq('owner_user_id', userId)
      .eq('routine_key', routineKey)
      .maybeSingle();

    if (error) return json({ error: error.message }, 500);
    if (data?.status === 'disabled') return json({ contact: null });
    return json({ contact: data ? serializeContact(data) : null });
  }

  if (req.method === 'DELETE') {
    if (!await hasActivePersonalEntitlement(serviceClient, userId)) {
      return json({ error: 'Personal Premium is required for completion emails.' }, 403);
    }

    let body: { contactId?: string };
    try {
      body = await req.json();
    } catch (_) {
      return json({ error: 'Invalid JSON body' }, 400);
    }

    if (!body.contactId) {
      return json({ error: 'contactId is required' }, 400);
    }

    const { data: existing, error: existingError } = await serviceClient
      .from('shared_alert_contacts')
      .select('*')
      .eq('id', body.contactId)
      .eq('owner_user_id', userId)
      .maybeSingle();

    if (existingError) return json({ error: existingError.message }, 500);
    if (!existing) return json({ error: 'Shared alert contact was not found' }, 404);

    const now = new Date().toISOString();
    const { error } = await serviceClient
      .from('shared_alert_contacts')
      .update({
        status: 'disabled',
        notify_when_finished: false,
        disabled_at: now,
        updated_at: now,
      })
      .eq('id', existing.id);

    if (error) return json({ error: error.message }, 500);
    return json({ removed: true });
  }

  if (req.method === 'PATCH') {
    if (!await hasActivePersonalEntitlement(serviceClient, userId)) {
      return json({ error: 'Personal Premium is required for completion emails.' }, 403);
    }

    let body: { contactId?: string; notifyWhenFinished?: boolean };
    try {
      body = await req.json();
    } catch (_) {
      return json({ error: 'Invalid JSON body' }, 400);
    }

    if (!body.contactId || typeof body.notifyWhenFinished !== 'boolean') {
      return json({ error: 'contactId and notifyWhenFinished are required' }, 400);
    }

    const { data: existing, error: existingError } = await serviceClient
      .from('shared_alert_contacts')
      .select('*')
      .eq('id', body.contactId)
      .eq('owner_user_id', userId)
      .maybeSingle();

    if (existingError) return json({ error: existingError.message }, 500);
    if (!existing) return json({ error: 'Shared alert contact was not found' }, 404);
    if (existing.status !== 'accepted') {
      return json({ error: 'The contact must accept before emails can be enabled' }, 409);
    }

    const { data, error } = await serviceClient
      .from('shared_alert_contacts')
      .update({ notify_when_finished: body.notifyWhenFinished })
      .eq('id', existing.id)
      .select()
      .single();

    if (error) return json({ error: error.message }, 500);
    return json({ contact: serializeContact(data) });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  if (!await hasActivePersonalEntitlement(serviceClient, userId)) {
    return json({ error: 'Personal Premium is required for completion emails.' }, 403);
  }

  let body: {
    routineKey?: string;
    routineTitle?: string;
    recipientEmail?: string;
    resend?: boolean;
    includeRoutineName?: boolean;
    includeStepCount?: boolean;
  };
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: 'Invalid JSON body' }, 400);
  }

  const routineKey = body.routineKey?.trim();
  const normalizedEmail = normalizeEmail(body.recipientEmail);
  if (!routineKey) return json({ error: 'routineKey is required' }, 400);
  if (!isValidEmail(normalizedEmail)) {
    return json({ error: 'Enter a valid email address' }, 400);
  }

  const recipientHash = await sha256Hex(normalizedEmail);
  const { data: block, error: blockError } = await serviceClient
    .from('shared_alert_blocks')
    .select('id')
    .eq('sender_user_id', userId)
    .eq('recipient_email_hash', recipientHash)
    .maybeSingle();

  if (blockError) return json({ error: blockError.message }, 500);
  if (block) {
    return json({ error: 'This recipient has blocked invites from this account' }, 403);
  }

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count, error: countError } = await serviceClient
    .from('shared_alert_contacts')
    .select('id', { count: 'exact', head: true })
    .eq('owner_user_id', userId)
    .gte('invited_at', since);

  if (countError) return json({ error: countError.message }, 500);
  if ((count ?? 0) >= 10) {
    return json({ error: 'Too many invites today. Please try again tomorrow.' }, 429);
  }

  const now = new Date().toISOString();
  const { data: existing, error: existingError } = await serviceClient
    .from('shared_alert_contacts')
    .select('*')
    .eq('owner_user_id', userId)
    .eq('routine_key', routineKey)
    .maybeSingle();

  if (existingError) return json({ error: existingError.message }, 500);
  if (
    existing &&
    existing.normalized_email === normalizedEmail &&
    existing.status === 'accepted'
  ) {
    return json({ contact: serializeContact(existing), alreadyAccepted: true });
  }

  const { data: contact, error: contactError } = await serviceClient
    .from('shared_alert_contacts')
    .upsert({
      owner_user_id: userId,
      routine_key: routineKey,
      recipient_email: body.recipientEmail!.trim(),
      normalized_email: normalizedEmail,
      recipient_email_hash: recipientHash,
      status: 'pending',
      notify_when_finished: false,
      include_routine_name: body.includeRoutineName !== false,
      include_step_count: body.includeStepCount !== false,
      invited_at: now,
      accepted_at: null,
      declined_at: null,
      blocked_at: null,
      disabled_at: null,
      updated_at: now,
    }, { onConflict: 'owner_user_id,routine_key' })
    .select()
    .single();

  if (contactError) return json({ error: contactError.message }, 500);

  const token = createToken();
  const { error: inviteError } = await serviceClient
    .from('shared_alert_invites')
    .insert({
      contact_id: contact.id,
      token_hash: await sha256Hex(token),
      expires_at: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString(),
    });

  if (inviteError) return json({ error: inviteError.message }, 500);

  const emailResult = await sendInviteEmail(env.value, body.recipientEmail!.trim(), token);
  if (!emailResult.ok) {
    return json({ error: emailResult.error }, 502);
  }

  return json({ contact: serializeContact(contact) });
});

async function sendInviteEmail(
  env: Env,
  recipientEmail: string,
  token: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  const acceptUrl = actionUrl(env.publicBaseUrl, 'shared-alert-accept', token);
  const declineUrl = actionUrl(env.publicBaseUrl, 'shared-alert-decline', token);
  const blockUrl = actionUrl(env.publicBaseUrl, 'shared-alert-block', token);
  const text = [
    'Allow completion emails from Pebble?',
    '',
    'Someone has added this email address to receive an update when they complete a routine.',
    '',
    'Completion emails can include the routine name, completion time, and step count. Photos and checklist details are never included.',
    '',
    'Pebble will not send any completion emails unless you allow them.',
    '',
    `Allow completion emails: ${acceptUrl}`,
    `Decline: ${declineUrl}`,
    `Block future invitations: ${blockUrl}`,
    '',
    'You received this because someone entered your email address in Pebble. If you were not expecting this, you can safely ignore it.',
  ].join('\n');

  const html = emailShell({
    preheader: 'Choose whether to receive routine completion emails from Pebble.',
    eyebrow: 'Invitation',
    title: 'Allow completion emails?',
    intro: 'Someone has added this email address to receive an update when they complete a routine.',
    body: [
      'Completion emails can include the routine name, completion time, and step count.',
      'Photos and checklist details are never included.',
    ],
    ctaLabel: 'Allow completion emails',
    ctaUrl: acceptUrl,
    secondaryLinks: [
      { label: 'Decline', url: declineUrl },
      { label: 'Block future invitations', url: blockUrl },
    ],
    footer: 'You received this because someone entered your email address in Pebble. If you were not expecting this, you can safely ignore it.',
  });

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${env.resendApiKey}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      from: env.fromEmail,
      to: [recipientEmail],
      subject: 'Allow completion emails from Pebble?',
      text,
      html,
      ...(env.replyToEmail ? { reply_to: env.replyToEmail } : {}),
    }),
  });

  if (response.ok) return { ok: true };
  return { ok: false, error: await response.text() };
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

function serializeContact(row: Record<string, unknown>) {
  return {
    id: row.id,
    routineKey: row.routine_key,
    recipientEmail: row.recipient_email,
    status: row.status,
    notifyWhenFinished: row.notify_when_finished,
    includeRoutineName: row.include_routine_name,
    includeStepCount: row.include_step_count,
    updatedAt: row.updated_at,
  };
}

function normalizeEmail(email: unknown): string {
  return typeof email === 'string' ? email.trim().toLowerCase() : '';
}

function isValidEmail(email: string): boolean {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) && email.length <= 320;
}

function normalizeOptionalEmail(value: string | undefined): string | null {
  const email = normalizeEmail(value);
  return isValidEmail(email) ? email : null;
}

function actionUrl(base: string, functionName: string, token: string): string {
  return `${base.replace(/\/$/, '')}/${functionName}?token=${encodeURIComponent(token)}`;
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

function emailShell(input: {
  preheader: string;
  eyebrow: string;
  title: string;
  intro: string;
  body: string[];
  ctaLabel: string;
  ctaUrl: string;
  secondaryLinks: { label: string; url: string }[];
  footer: string;
}): string {
  const paragraphs = input.body
    .map((line) => `<p style="margin:0 0 8px;color:#45534b;font-size:14px;line-height:1.55;">${escapeHtml(line)}</p>`)
    .join('');
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
      .email-button { display:block !important; text-align:center !important; }
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
              <h1 class="email-title" style="margin:0 0 14px;color:#1d2922;font-size:36px;line-height:1.12;font-weight:800;letter-spacing:-.7px;">${escapeHtml(input.title)}</h1>
              <p style="margin:0 0 28px;color:#536159;font-size:16px;line-height:1.6;">${escapeHtml(input.intro)}</p>
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:0 0 28px;background:#f3f5f1;border:1px solid #dfe5df;border-radius:16px;">
                <tr>
                  <td style="padding:18px 20px;">
                    <p style="margin:0 0 10px;color:#24382d;font-size:13px;line-height:1.4;font-weight:800;">What may be included</p>
                    ${paragraphs}
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 28px;">
                <a href="${input.ctaUrl}" class="email-button" style="display:inline-block;background:#2e5b43;color:#ffffff;text-decoration:none;border-radius:12px;padding:14px 20px;font-size:15px;line-height:1.2;font-weight:800;">${escapeHtml(input.ctaLabel)}</a>
              </p>
              <p style="margin:0 0 26px;color:#66746c;font-size:13px;line-height:1.6;">Nothing will be sent unless you choose to allow it.</p>
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

function escapeHtml(value: string): string {
  return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}
