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
      return json({ error: 'Personal Premium is required for trusted contacts.' }, 403);
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
      return json({ error: 'Personal Premium is required for trusted contacts.' }, 403);
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
    return json({ error: 'Personal Premium is required for trusted contacts.' }, 403);
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
    'Pebble shared alert request',
    '',
    'Someone who uses Pebble would like to email you when they complete a routine.',
    '',
    'If you recognise this request, you can allow these alerts. Pebble will only send completion emails after you accept.',
    '',
    `Allow Pebble alerts: ${acceptUrl}`,
    `Decline this invite: ${declineUrl}`,
    `Block future invites from this sender: ${blockUrl}`,
    '',
    'You are receiving this because someone entered your email address in Pebble. If you did not expect this, you can ignore this email.',
  ].join('\n');

  const html = emailShell({
    preheader: 'Someone would like to share Pebble completion updates with you.',
    title: 'Shared alert request',
    body: [
      'Someone who uses Pebble would like to email you when they complete a routine.',
      'If you recognise this request, you can allow these alerts. Pebble will only send completion emails after you accept.',
    ],
    ctaLabel: 'Allow Pebble alerts',
    ctaUrl: acceptUrl,
    secondaryLinks: [
      { label: 'Decline this invite', url: declineUrl },
      { label: 'Block future invites from this sender', url: blockUrl },
    ],
    footer: 'You are receiving this because someone entered your email address in Pebble. If you did not expect this, you can ignore this email.',
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
      subject: 'Pebble shared alert request',
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
  title: string;
  body: string[];
  ctaLabel: string;
  ctaUrl: string;
  secondaryLinks: { label: string; url: string }[];
  footer: string;
}): string {
  const paragraphs = input.body
    .map((line) => `<p style="margin:0 0 14px;color:#253047;font-size:16px;line-height:1.6;">${escapeHtml(line)}</p>`)
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
                <span style="display:inline-block;margin-left:8px;color:#667085;font-size:13px;">Trusted contact invite</span>
              </p>
              <h1 style="margin:0 0 12px;color:#111827;font-size:32px;line-height:1.12;font-weight:800;letter-spacing:0;">${escapeHtml(input.title)}</h1>
              <p style="margin:0;color:#596277;font-size:15px;line-height:1.55;">Completion emails only start after you allow them.</p>
            </div>
            <div style="padding:26px 32px 30px;background:#ffffff;">
              ${paragraphs}
              <p style="margin:24px 0 22px;">
                <a href="${input.ctaUrl}" style="display:inline-block;background:#4b5cff;color:#ffffff;text-decoration:none;border-radius:999px;padding:14px 20px;font-size:15px;font-weight:800;box-shadow:0 10px 22px rgba(75,92,255,.22);">${escapeHtml(input.ctaLabel)}</a>
              </p>
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:0 0 20px;background:#f8fafc;border:1px solid #e7eaf3;border-radius:18px;">
                <tr>
                  <td style="padding:14px 16px;">
                    <p style="margin:0;color:#475467;font-size:13px;line-height:1.5;">Pebble will not send routine names or completion updates unless this invite is accepted.</p>
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

function escapeHtml(value: string): string {
  return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}
