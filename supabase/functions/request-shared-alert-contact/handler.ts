// Sender-side contact management for completion emails.
//   GET    ?routineKey=…            contact for a routine (or null)
//   POST   {routineKey, recipientEmail, includeRoutineName?, includeStepCount?}
//                                   create/replace the contact and email an invite
//   PATCH  {contactId, notifyWhenFinished?, includeRoutineName?, includeStepCount?}
//   DELETE {contactId}               remove (stops all emails)
// Requires a signed-in user; POST/PATCH need active Personal Premium.

import { buildInviteEmail } from '../_shared/shared_alert_email.ts';
import {
  confirmPageUrl,
  createToken,
  INVITE_TTL_MS,
  inviteDecision,
  isValidRecipientEmail,
  isValidRoutineKey,
  normalizeEmail,
  oneClickUrl,
  senderLabel,
  sha256Hex,
} from '../_shared/shared_alert_policy.ts';
import type { AuthUser, LinkConfig, Mailer } from '../_shared/shared_alert_runtime.ts';
import { log } from '../_shared/shared_alert_runtime.ts';
import type { ContactRow, SharedAlertStore } from '../_shared/shared_alert_store.ts';

export type ContactDeps = {
  store: SharedAlertStore;
  authenticate: (req: Request) => Promise<AuthUser | null>;
  mailer: Mailer;
  links: LinkConfig;
  now?: () => number;
};

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
};

const PREMIUM_REQUIRED = 'Personal Premium is required for completion emails.';

export function createContactHandler(deps: ContactDeps) {
  const now = deps.now ?? Date.now;
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

    const user = await deps.authenticate(req);
    if (!user) return json({ error: 'Invalid user authorization' }, 401);

    try {
      switch (req.method) {
        case 'GET':
          return await getContact(req, user);
        case 'POST':
          return await inviteContact(req, user);
        case 'PATCH':
          return await patchContact(req, user);
        case 'DELETE':
          return await removeContact(req, user);
        default:
          return json({ error: 'Method not allowed' }, 405);
      }
    } catch (error) {
      log('request-shared-alert-contact', {
        event: 'unexpected_error',
        method: req.method,
        message: error instanceof Error ? error.message : String(error),
      });
      return json({ error: 'Something went wrong. Try again.', code: 'serverError' }, 500);
    }
  };

  async function getContact(req: Request, user: AuthUser) {
    const routineKey = new URL(req.url).searchParams.get('routineKey')?.trim();
    if (!isValidRoutineKey(routineKey)) return json({ error: 'routineKey is required' }, 400);
    const contact = await deps.store.getContactForRoutine(user.id, routineKey);
    if (!contact || contact.status === 'disabled') return json({ contact: null });
    return json({ contact: serializeContact(contact) });
  }

  async function ownedContact(user: AuthUser, contactId: unknown): Promise<ContactRow | null> {
    if (typeof contactId !== 'string' || !contactId) return null;
    const contact = await deps.store.getContactById(contactId);
    return contact && contact.owner_user_id === user.id ? contact : null;
  }

  async function removeContact(req: Request, user: AuthUser) {
    // Removing never needs Premium: anyone must always be able to stop emails.
    const body = await readJson(req);
    if (!body) return json({ error: 'Invalid JSON body' }, 400);
    const contact = await ownedContact(user, body.contactId);
    if (!contact) return json({ error: 'Shared alert contact was not found' }, 404);
    const nowIso = new Date(now()).toISOString();
    await deps.store.updateContact(contact.id, {
      status: 'disabled',
      notify_when_finished: false,
      disabled_at: nowIso,
      updated_at: nowIso,
    });
    // A removed contact's pending invitation must not be accepted later.
    await deps.store.expireTokens(contact.id, 'invite', nowIso);
    return json({ removed: true });
  }

  async function patchContact(req: Request, user: AuthUser) {
    const body = await readJson(req);
    if (!body) return json({ error: 'Invalid JSON body' }, 400);
    const contact = await ownedContact(user, body.contactId);
    if (!contact) return json({ error: 'Shared alert contact was not found' }, 404);

    const patch: Partial<ContactRow> = {};
    for (const [field, column] of [
      ['includeRoutineName', 'include_routine_name'],
      ['includeStepCount', 'include_step_count'],
      ['notifyWhenFinished', 'notify_when_finished'],
    ] as const) {
      if (body[field] === undefined) continue;
      if (typeof body[field] !== 'boolean') return json({ error: `${field} must be true or false` }, 400);
      (patch as Record<string, boolean>)[column] = body[field] as boolean;
    }
    if (Object.keys(patch).length === 0) {
      return json({ error: 'contactId and notifyWhenFinished are required' }, 400);
    }
    if (contact.status === 'disabled') return json({ error: 'Shared alert contact was not found' }, 404);
    if (patch.notify_when_finished === true) {
      if (contact.status !== 'accepted') {
        return json({ error: 'The contact must accept before emails can be enabled' }, 409);
      }
      // Turning emails back on is a Premium feature; turning them off, or
      // sharing less, is always allowed.
      if (!await deps.store.hasActiveEntitlement(user.id)) return json({ error: PREMIUM_REQUIRED }, 403);
    }
    const updated = await deps.store.updateContact(contact.id, patch);
    return json({ contact: serializeContact(updated ?? { ...contact, ...patch }) });
  }

  async function inviteContact(req: Request, user: AuthUser) {
    if (!await deps.store.hasActiveEntitlement(user.id)) return json({ error: PREMIUM_REQUIRED }, 403);
    const body = await readJson(req);
    if (!body) return json({ error: 'Invalid JSON body' }, 400);

    const routineKey = typeof body.routineKey === 'string' ? body.routineKey.trim() : '';
    if (!isValidRoutineKey(routineKey)) return json({ error: 'routineKey is required' }, 400);
    const normalizedEmail = normalizeEmail(body.recipientEmail);
    if (!isValidRecipientEmail(normalizedEmail)) {
      return json({ error: 'Enter a valid email address', code: 'invalidEmail' }, 400);
    }
    const includeRoutineName = body.includeRoutineName !== false;
    const includeStepCount = body.includeStepCount !== false;
    const recipientHash = await sha256Hex(normalizedEmail);
    const t = now();
    const nowIso = new Date(t).toISOString();

    const existing = await deps.store.getContactForRoutine(user.id, routineKey);
    if (existing && existing.normalized_email === normalizedEmail && existing.status === 'accepted') {
      return json({ contact: serializeContact(existing), alreadyAccepted: true });
    }

    const decision = inviteDecision(
      await deps.store.inviteCounts({ ownerId: user.id, recipientHash, routineKey, now: t }),
      t,
    );
    if (!decision.ok) {
      log('request-shared-alert-contact', { event: 'invite_refused', code: decision.code });
      return json({ error: decision.error, code: decision.code }, decision.status);
    }

    const contact = await deps.store.upsertPendingContact({
      owner_user_id: user.id,
      routine_key: routineKey,
      recipient_email: normalizedEmail,
      normalized_email: normalizedEmail,
      recipient_email_hash: recipientHash,
      status: 'pending',
      notify_when_finished: false,
      include_routine_name: includeRoutineName,
      include_step_count: includeStepCount,
      invited_at: nowIso,
      updated_at: nowIso,
    });

    // Only the newest invitation can be accepted. This also stops a link sent
    // to a previous address from switching emails on for the new one.
    await deps.store.expireTokens(contact.id, 'invite', nowIso);
    await deps.store.pruneTokens(contact.id, t);

    const token = createToken();
    const expiresAt = new Date(t + INVITE_TTL_MS);
    await deps.store.insertInvite({
      contact_id: contact.id,
      owner_user_id: user.id,
      recipient_email_hash: recipientHash,
      purpose: 'invite',
      token_hash: await sha256Hex(token),
      expires_at: expiresAt.toISOString(),
    });

    const email = buildInviteEmail({
      sender: senderLabel(user.email),
      privacyUrl: deps.links.privacyUrl,
      footerAddress: deps.links.footerAddress,
      includeRoutineName,
      includeStepCount,
      expiresAt,
      acceptUrl: confirmPageUrl(deps.links.pagesBase, 'accept', token),
      declineUrl: confirmPageUrl(deps.links.pagesBase, 'decline', token),
      blockUrl: confirmPageUrl(deps.links.pagesBase, 'block', token),
      oneClickUrl: oneClickUrl(deps.links.functionsBase, 'block', token),
    });
    const sent = await deps.mailer({
      ...email,
      to: normalizedEmail,
      idempotencyKey: `invite-${contact.id}-${t}`,
    });
    if (!sent.ok) {
      log('request-shared-alert-contact', { event: 'invite_email_failed', error: sent.error });
      return json({
        error: "Couldn't send the invite email. Try again in a few minutes.",
        code: 'emailFailed',
      }, 502);
    }
    log('request-shared-alert-contact', { event: 'invite_sent', messageId: sent.id });
    return json({ contact: serializeContact(contact) });
  }
}

export function serializeContact(row: ContactRow) {
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

async function readJson(req: Request): Promise<Record<string, unknown> | null> {
  try {
    const body = await req.json();
    return body && typeof body === 'object' && !Array.isArray(body) ? body : null;
  } catch (_) {
    return null;
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}
