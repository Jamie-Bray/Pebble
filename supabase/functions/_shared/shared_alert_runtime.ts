// Runtime wiring for completion emails: environment, sign-in check and the
// Resend mailer. Kept apart from the handlers so tests can inject fakes.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { BuiltEmail } from './shared_alert_email.ts';
import { type SharedAlertStore, supabaseSharedAlertStore } from './shared_alert_store.ts';

export type LinkConfig = {
  /** Supabase functions base, e.g. https://<ref>.functions.supabase.co */
  functionsBase: string;
  /** Static pages base, e.g. https://pebbleroutines.com/shared-alert */
  pagesBase: string;
  privacyUrl: string;
  footerAddress: string | null;
};

export type SharedAlertEnv = LinkConfig & {
  supabaseUrl: string;
  anonKey: string;
  serviceRoleKey: string;
  resendApiKey: string;
  fromEmail: string;
  replyToEmail: string | null;
};

export function readSharedAlertEnv(): { ok: true; value: SharedAlertEnv } | { ok: false; error: string } {
  const get = (name: string) => Deno.env.get(name)?.trim() || '';
  const supabaseUrl = get('SUPABASE_URL');
  const anonKey = get('SUPABASE_ANON_KEY');
  const serviceRoleKey = get('SUPABASE_SERVICE_ROLE_KEY');
  const resendApiKey = get('RESEND_API_KEY');
  const fromEmail = get('SHARED_ALERT_FROM_EMAIL');
  const functionsBase = get('SHARED_ALERT_PUBLIC_BASE_URL');
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !resendApiKey || !fromEmail || !functionsBase) {
    return { ok: false, error: 'Shared alert environment is not configured' };
  }
  const replyTo = get('SHARED_ALERT_REPLY_TO_EMAIL');
  return {
    ok: true,
    value: {
      supabaseUrl,
      anonKey,
      serviceRoleKey,
      resendApiKey,
      fromEmail,
      replyToEmail: /^[^@\s<>,;"]+@[^@\s<>,;"]+\.[^@\s<>,;"]+$/.test(replyTo) ? replyTo : null,
      functionsBase,
      pagesBase: get('SHARED_ALERT_PAGES_BASE_URL') || 'https://pebbleroutines.com/shared-alert',
      privacyUrl: get('SHARED_ALERT_PRIVACY_URL') || 'https://pebbleroutines.com/privacy.html',
      footerAddress: get('SHARED_ALERT_POSTAL_ADDRESS') || null,
    },
  };
}

/** Link-handler functions only need the database. */
export function readLinkEnv(): { ok: true; value: { supabaseUrl: string; serviceRoleKey: string; pagesBase: string } } | { ok: false } {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) return { ok: false };
  return {
    ok: true,
    value: {
      supabaseUrl,
      serviceRoleKey,
      pagesBase: Deno.env.get('SHARED_ALERT_PAGES_BASE_URL')?.trim() || 'https://pebbleroutines.com/shared-alert',
    },
  };
}

export type AuthUser = { id: string; email: string | null };

export function supabaseAuthenticator(env: { supabaseUrl: string; anonKey: string }) {
  return async (req: Request): Promise<AuthUser | null> => {
    const jwt = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '').trim();
    if (!jwt) return null;
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

// ---------------------------------------------------------------------------
// Mailer
// ---------------------------------------------------------------------------

export type MailResult =
  | { ok: true; id: string | null }
  | { ok: false; error: string };

export type Mailer = (message: BuiltEmail & { to: string; idempotencyKey: string }) => Promise<MailResult>;

/**
 * Sends through Resend's HTTP API. One retry for network errors, timeouts,
 * 429 and 5xx, reusing the same Idempotency-Key so Resend never delivers the
 * same message twice. Errors are summarised without addresses or tokens.
 */
export function resendMailer(
  env: { resendApiKey: string; fromEmail: string; replyToEmail: string | null },
  fetchImpl: typeof fetch = fetch,
  retryDelayMs = 800,
): Mailer {
  return async (message) => {
    const body = JSON.stringify({
      from: env.fromEmail,
      to: [message.to],
      subject: message.subject,
      html: message.html,
      text: message.text,
      headers: message.headers,
      ...(env.replyToEmail ? { reply_to: env.replyToEmail } : {}),
    });
    let lastError = 'unknown';
    for (let attempt = 1; attempt <= 2; attempt++) {
      try {
        const response = await fetchImpl('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            authorization: `Bearer ${env.resendApiKey}`,
            'content-type': 'application/json',
            'idempotency-key': message.idempotencyKey,
          },
          body,
          signal: AbortSignal.timeout(10_000),
        });
        const textBody = await response.text();
        if (response.ok) {
          let id: string | null = null;
          try {
            const parsed = JSON.parse(textBody);
            id = typeof parsed?.id === 'string' ? parsed.id : null;
          } catch (_) { /* id stays null */ }
          return { ok: true, id };
        }
        lastError = summariseProviderError(response.status, textBody);
        if (response.status !== 429 && response.status < 500) break;
      } catch (error) {
        lastError = error instanceof Error ? `network: ${error.name}` : 'network';
      }
      if (attempt === 1) await new Promise((r) => setTimeout(r, retryDelayMs));
    }
    return { ok: false, error: lastError };
  };
}

export function summariseProviderError(status: number, body: string): string {
  let detail = '';
  try {
    const parsed = JSON.parse(body);
    detail = [parsed?.name, parsed?.message].filter((x) => typeof x === 'string').join(': ');
  } catch (_) {
    detail = body;
  }
  return redact(`resend ${status}${detail ? ' ' + detail : ''}`).slice(0, 300);
}

/** Removes email addresses and long token-like strings from log text. */
export function redact(text: string): string {
  return text
    .replace(/[^\s@<>"']+@[^\s@<>"']+/g, '[email]')
    .replace(/[A-Za-z0-9_-]{32,}/g, '[token]');
}

export function log(scope: string, fields: Record<string, unknown>) {
  console.log(JSON.stringify({ scope, ...fields }));
}

// ---------------------------------------------------------------------------
// Entrypoints (used by each function's index.ts)
// ---------------------------------------------------------------------------

type Handler = (req: Request) => Promise<Response>;

export type SenderDeps = {
  store: SharedAlertStore;
  authenticate: (req: Request) => Promise<AuthUser | null>;
  mailer: Mailer;
  links: LinkConfig;
};

export function senderEntrypoint(factory: (deps: SenderDeps) => Handler): Handler {
  const env = readSharedAlertEnv();
  if (!env.ok) {
    const error = env.error;
    return () =>
      Promise.resolve(
        new Response(JSON.stringify({ error }), {
          status: 500,
          headers: { 'content-type': 'application/json', 'access-control-allow-origin': '*' },
        }),
      );
  }
  return factory({
    store: supabaseSharedAlertStore(serviceClient(env.value)),
    authenticate: supabaseAuthenticator(env.value),
    mailer: resendMailer(env.value),
    links: env.value,
  });
}

export function linkEntrypoint(
  factory: (deps: { store: SharedAlertStore; pagesBase: string }) => Handler,
): Handler {
  const env = readLinkEnv();
  if (!env.ok) {
    return () =>
      Promise.resolve(
        new Response(null, {
          status: 303,
          headers: { Location: 'https://pebbleroutines.com/shared-alert/problem/', 'Cache-Control': 'no-store' },
        }),
      );
  }
  return factory({ store: supabaseSharedAlertStore(serviceClient(env.value)), pagesBase: env.value.pagesBase });
}
