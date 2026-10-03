// Handler for the Allow / Decline (Stop) / Block links in completion emails.
//
// GET never changes anything. Hosted Supabase rewrites text/html responses
// from Edge Functions to text/plain, so the confirmation page lives on the
// Pebble website (web/shared-alert/confirm/). GET here only redirects there,
// which also keeps older emails' links working.
//
// POST acts. It comes from the confirmation page's form (token in the body)
// or from a mail app's RFC 8058 one-click unsubscribe (token in the query,
// body "List-Unsubscribe=One-Click"). Every outcome redirects to a fixed page
// on the Pebble website, so there is no open redirect.

import {
  confirmPageUrl,
  DAY_MS,
  effectivePurpose,
  isPlausibleToken,
  LIMITS,
  type LinkAction,
  sha256Hex,
} from './shared_alert_policy.ts';
import { log } from './shared_alert_runtime.ts';
import type { InviteRow, SharedAlertStore } from './shared_alert_store.ts';

export type LinkDeps = {
  store: SharedAlertStore;
  pagesBase: string;
  now?: () => number;
};

type Outcome = 'accepted' | 'declined' | 'blocked' | 'blocked-all' | 'problem';

const headers = { 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer' };

export function createLinkHandler(action: LinkAction, deps: LinkDeps) {
  const now = deps.now ?? Date.now;
  const pages = deps.pagesBase.replace(/\/$/, '');

  return async (req: Request): Promise<Response> => {
    if (req.method === 'GET' || req.method === 'HEAD') {
      const token = new URL(req.url).searchParams.get('token')?.trim() ?? '';
      if (!isPlausibleToken(token)) return redirect(`${pages}/problem/`);
      return redirect(confirmPageUrl(pages, action, token));
    }
    if (req.method !== 'POST') return redirect(`${pages}/problem/`);

    const form = await readForm(req);
    const oneClick = form.get('List-Unsubscribe') === 'One-Click';
    const token = (form.get('token') ?? new URL(req.url).searchParams.get('token') ?? '').trim();
    const blockAll = action === 'block' && form.get('scope') === 'all';

    let outcome: Outcome = 'problem';
    try {
      if (isPlausibleToken(token)) {
        const invite = await deps.store.findInviteByTokenHash(await sha256Hex(token));
        if (invite) outcome = await perform(invite, blockAll);
      }
    } catch (error) {
      log(`shared-alert-${action}`, {
        event: 'unexpected_error',
        message: error instanceof Error ? error.message : String(error),
      });
      outcome = 'problem';
    }
    log(`shared-alert-${action}`, { event: 'link_used', outcome, oneClick });

    if (oneClick) {
      return new Response(outcome === 'problem' ? 'Link not found' : 'Done', {
        status: outcome === 'problem' ? 404 : 200,
        headers: { ...headers, 'content-type': 'text/plain; charset=utf-8' },
      });
    }
    const page = outcome === 'blocked-all' ? 'blocked/?all=1' : `${outcome}/`;
    return redirect(`${pages}/${page}`);
  };

  async function perform(invite: InviteRow, blockAll: boolean): Promise<Outcome> {
    const t = now();
    const nowIso = new Date(t).toISOString();
    const contact = await deps.store.getContactById(invite.contact_id);
    const recipientHash = invite.recipient_email_hash ?? contact?.recipient_email_hash ?? null;
    const senderId = invite.owner_user_id ?? contact?.owner_user_id ?? null;
    if (!recipientHash || !senderId) return 'problem';
    // The contact row is reused when the sender changes the address, so a
    // link only touches the contact if it was sent to the current address.
    const current = contact && contact.recipient_email_hash === recipientHash ? contact : null;
    const knownEmail = current?.normalized_email ?? '';

    if (action === 'accept') {
      const expired = new Date(invite.expires_at).getTime() <= t;
      if (effectivePurpose(invite) !== 'invite' || expired || !current || invite.blocked_at) return 'problem';
      if (current.status === 'accepted') return 'accepted';
      if (current.status !== 'pending' && current.status !== 'declined') return 'problem';
      if (await deps.store.isBlocked(senderId, recipientHash)) return 'problem';
      if (await deps.store.isSuppressed(recipientHash)) return 'problem';
      await deps.store.updateContact(current.id, {
        status: 'accepted',
        notify_when_finished: true,
        accepted_at: nowIso,
        declined_at: null,
        blocked_at: null,
        updated_at: nowIso,
      });
      await deps.store.markInvite(invite.id, { accepted_at: nowIso });
      await deps.store.clearDecline(senderId, recipientHash);
      return 'accepted';
    }

    // Decline and block keep working after a link expires (until the token
    // is pruned): stopping emails should never fail on a technicality.
    if (action === 'decline') {
      if (current && (current.status === 'pending' || current.status === 'accepted')) {
        await deps.store.updateContact(current.id, {
          status: 'declined',
          notify_when_finished: false,
          declined_at: nowIso,
          updated_at: nowIso,
        });
      }
      if (current) await deps.store.expireTokens(current.id, 'invite', nowIso);
      await deps.store.recordDecline({
        senderId,
        recipientHash,
        normalizedEmail: knownEmail,
        until: new Date(t + LIMITS.declineCooldownDays * DAY_MS),
        nowIso,
      });
      await deps.store.markInvite(invite.id, { declined_at: nowIso });
      return 'declined';
    }

    await deps.store.upsertBlock({ senderId, recipientHash, normalizedEmail: knownEmail, nowIso });
    if (blockAll) await deps.store.addSuppression(recipientHash, 'recipient_link');
    if (current && current.status !== 'disabled') {
      await deps.store.updateContact(current.id, {
        status: 'blocked',
        notify_when_finished: false,
        blocked_at: nowIso,
        updated_at: nowIso,
      });
    }
    if (current) await deps.store.expireTokens(current.id, 'invite', nowIso);
    await deps.store.markInvite(invite.id, { blocked_at: nowIso });
    return blockAll ? 'blocked-all' : 'blocked';
  }
}

async function readForm(req: Request): Promise<Map<string, string>> {
  const out = new Map<string, string>();
  const type = req.headers.get('content-type') ?? '';
  try {
    if (type.includes('application/x-www-form-urlencoded') || type.includes('multipart/form-data')) {
      const data = await req.formData();
      for (const [key, value] of data.entries()) {
        if (typeof value === 'string') out.set(key, value);
      }
    } else if (type.includes('text/plain')) {
      // Some mail providers send the one-click body as text/plain.
      for (const [key, value] of new URLSearchParams(await req.text())) out.set(key, value);
    }
  } catch (_) {
    // An unreadable body is treated as empty.
  }
  return out;
}

function redirect(location: string): Response {
  return new Response(null, { status: 303, headers: { ...headers, Location: location } });
}
