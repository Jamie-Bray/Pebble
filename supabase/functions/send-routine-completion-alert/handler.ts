// POST {routineKey, routineTitle, runId, sessionId?, completedAt,
//       utcOffsetMinutes?, completedSteps, totalSteps, descriptions?}
// `descriptions` are AI photo descriptions the sender chose to add: at most
// five, cleaned and verdict-filtered here, sent only for an account with a
// current AI photo consent, and never stored. Photos are never emailed.
// Sends one completion email to the routine's accepted contact.
//
// Responses (all 200 unless noted), read by the app:
//   {sent: true, eventId, recipientEmail}
//   {sent: true, alreadySent: true}           same run already emailed
//   {sent: false, reason: 'noActiveEntitlement' | 'noAcceptedContact' | 'rateLimited' | 'duplicateRun'}
//   502 {error, code: 'emailFailed'}           the app may retry the same run

import { AI_PHOTO_CONSENT_VERSION } from '../_shared/ai_photo.ts';
import { buildCompletionEmail } from '../_shared/shared_alert_email.ts';
import {
  confirmPageUrl,
  createToken,
  formatCompletionTime,
  LIMITS,
  MANAGE_TTL_MS,
  oneClickUrl,
  parseCompletionInput,
  senderLabel,
  sendDecision,
  sha256Hex,
} from '../_shared/shared_alert_policy.ts';
import type { AuthUser, LinkConfig, Mailer } from '../_shared/shared_alert_runtime.ts';
import { log } from '../_shared/shared_alert_runtime.ts';
import type { EventRow, SharedAlertStore } from '../_shared/shared_alert_store.ts';

export type CompletionDeps = {
  store: SharedAlertStore;
  authenticate: (req: Request) => Promise<AuthUser | null>;
  mailer: Mailer;
  links: LinkConfig;
  now?: () => number;
};

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

export function createCompletionHandler(deps: CompletionDeps) {
  const now = deps.now ?? Date.now;
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

    const user = await deps.authenticate(req);
    if (!user) return json({ error: 'Invalid user authorization' }, 401);

    let body: unknown;
    try {
      body = await req.json();
    } catch (_) {
      return json({ error: 'Invalid JSON body' }, 400);
    }
    const t = now();
    const parsed = parseCompletionInput(body, t);
    if (!parsed.ok) return json({ error: parsed.error }, 400);
    const input = parsed.value;

    try {
      if (!await deps.store.hasActiveEntitlement(user.id)) {
        return json({ sent: false, reason: 'noActiveEntitlement' });
      }

      const contact = await deps.store.getContactForRoutine(user.id, input.routineKey);
      if (!contact || contact.status !== 'accepted' || !contact.notify_when_finished) {
        return json({ sent: false, reason: 'noAcceptedContact' });
      }
      // Belt and braces: a block or a global opt-out always wins, even if the
      // contact row somehow still says accepted.
      if (
        await deps.store.isBlocked(user.id, contact.recipient_email_hash) ||
        await deps.store.isSuppressed(contact.recipient_email_hash)
      ) {
        return json({ sent: false, reason: 'noAcceptedContact' });
      }

      const includeName = contact.include_routine_name !== false;
      const includeSteps = contact.include_step_count !== false;

      // One email per (contact, run). A failed send may be retried a few times.
      let event: EventRow | null = await deps.store.insertEvent({
        owner_user_id: user.id,
        contact_id: contact.id,
        routine_key: input.routineKey,
        run_id: input.runId,
        session_id: input.sessionId,
        // Don't keep a title the sender chose not to share.
        routine_title: includeName ? input.routineTitle : '',
        completed_at: input.completedAt.toISOString(),
        completed_steps: input.completedSteps,
        total_steps: input.totalSteps,
      });
      if (!event) {
        const existing = await deps.store.getEventForRun(contact.id, input.runId);
        if (existing?.status === 'sent') return json({ sent: true, alreadySent: true });
        const nextAttempt = (existing?.attempts ?? LIMITS.maxSendAttempts) + 1;
        if (
          !existing || existing.status !== 'failed' || nextAttempt > LIMITS.maxSendAttempts ||
          !await deps.store.claimFailedEvent(existing.id, nextAttempt)
        ) {
          return json({ sent: false, reason: 'duplicateRun' });
        }
        event = { ...existing, status: 'pending', attempts: nextAttempt };
      }

      if (sendDecision(await deps.store.sentCounts(contact.id, t)) === 'rateLimited') {
        await deps.store.updateEvent(event.id, { status: 'skipped', error_summary: 'rate_limited' });
        log('send-routine-completion-alert', { event: 'rate_limited' });
        return json({ sent: false, reason: 'rateLimited' });
      }

      const nowIso = new Date(t).toISOString();
      await deps.store.pruneTokens(contact.id, t);
      const token = createToken();
      await deps.store.insertInvite({
        contact_id: contact.id,
        owner_user_id: user.id,
        recipient_email_hash: contact.recipient_email_hash,
        purpose: 'manage',
        token_hash: await sha256Hex(token),
        expires_at: new Date(t + MANAGE_TTL_MS).toISOString(),
      });

      const descriptions = input.descriptions.length > 0 &&
          await deps.store.hasCurrentAiPhotoConsent(user.id, AI_PHOTO_CONSENT_VERSION)
        ? input.descriptions
        : [];

      const email = buildCompletionEmail({
        sender: senderLabel(user.email),
        privacyUrl: deps.links.privacyUrl,
        footerAddress: deps.links.footerAddress,
        routineTitle: includeName ? input.routineTitle : null,
        completedAtText: formatCompletionTime(input),
        steps: includeSteps ? { completed: input.completedSteps, total: input.totalSteps } : null,
        descriptions,
        stopUrl: confirmPageUrl(deps.links.pagesBase, 'decline', token),
        blockUrl: confirmPageUrl(deps.links.pagesBase, 'block', token),
        oneClickUrl: oneClickUrl(deps.links.functionsBase, 'decline', token),
      });

      const result = await deps.mailer({
        ...email,
        to: contact.recipient_email,
        idempotencyKey: `completion-${event.id}-${event.attempts}`,
      });
      if (!result.ok) {
        await deps.store.updateEvent(event.id, {
          status: 'failed',
          provider: 'resend',
          error_summary: result.error,
          provider_response: null,
        });
        log('send-routine-completion-alert', { event: 'send_failed', attempt: event.attempts, error: result.error });
        return json({ error: 'Completion email could not be sent', code: 'emailFailed' }, 502);
      }

      await deps.store.updateEvent(event.id, {
        status: 'sent',
        provider: 'resend',
        provider_message_id: result.id,
        provider_response: null,
        error_summary: null,
        updated_at: nowIso,
      });
      return json({ sent: true, eventId: event.id, recipientEmail: contact.recipient_email });
    } catch (error) {
      log('send-routine-completion-alert', {
        event: 'unexpected_error',
        message: error instanceof Error ? error.message : String(error),
      });
      return json({ error: 'Completion email could not be sent', code: 'serverError' }, 500);
    }
  };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}
