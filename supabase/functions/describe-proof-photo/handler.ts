// AI photo descriptions for Personal Premium (docs/AI_PHOTO_STEPS.md).
//
// GET                                       -> {enabled}
// POST {action:'consent', consentVersion, routineKey?, appVersion?}
//                                           -> {consented: true} | {consented: false, reason}
// POST {action:'withdraw'}                  -> {withdrawn: true}
// POST {action:'allowance'}                 -> {allowance: {limit, used, remaining, resetsAt}}
// POST {action:'describe', idempotencyKey, imageBase64, stepLabel}
//                                           -> {described: true, description}
//                                            | {described: false, reason}
//
// `reason` includes featureOff, noActiveEntitlement, noConsent, dailyLimit,
// monthlyLimit, budgetExhausted, duplicate, couldNotDescribe. Allowance refusals
// explain when more are available; every refusal leaves the photo usable.
//
// Describe checks run in this order and every one fails closed, before any
// call to the provider: feature switch, sign-in, Personal Premium, current
// consent, the image itself, then the allowance and budget (reserved in one
// database transaction and never refunded).
//
// Privacy: the photo is held in memory for the one provider call. Neither it
// nor the description is stored or logged; logs carry outcome codes only.

import {
  AI_PHOTO_CONSENT_VERSION,
  AI_PHOTO_LIMITS,
  isValidIdempotencyKey,
  parseProviderReply,
  validateJpegBase64,
} from '../_shared/ai_photo.ts';
import { isValidRoutineKey } from '../_shared/shared_alert_policy.ts';
import type { AuthUser } from '../_shared/shared_alert_runtime.ts';
import type { DescribePhoto } from './provider.ts';

export type Reservation = 'ok' | 'duplicate' | 'daily_limit' | 'monthly_limit' | 'budget_exhausted';
export type AiPhotoAllowance = { limit: number; used: number; remaining: number; resetsAt: string };

export interface AiPhotoStore {
  /** The database off switch (public.ai_photo_settings.paused). */
  isPaused(): Promise<boolean>;
  hasActiveEntitlement(userId: string): Promise<boolean>;
  /** True when the account has an unwithdrawn consent for `version`. */
  hasCurrentConsent(userId: string, version: string): Promise<boolean>;
  recordConsent(row: { userId: string; version: string; routineKey: string | null; appVersion: string | null }): Promise<void>;
  withdrawConsent(userId: string): Promise<void>;
  allowance(userId: string): Promise<AiPhotoAllowance>;
  /** Atomically checks the idempotency key and both limits, and counts the call. */
  reserve(input: { userId: string; idempotencyKey: string; dailyLimit: number; monthlyLimit: number }): Promise<Reservation>;
}

export type AiPhotoDeps = {
  /** The AI_PHOTO_ENABLED secret. Anything but "true" means off. */
  enabled: () => boolean;
  limits?: { dailyPerUser: number; monthlyRequests: number };
  store: AiPhotoStore;
  authenticate: (req: Request) => Promise<AuthUser | null>;
  /** null when no provider key is configured. */
  describe: DescribePhoto | null;
  log?: (fields: Record<string, unknown>) => void;
};

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
};

/** Base64 of the largest allowed photo plus the small JSON wrapper. */
const MAX_BODY_BYTES = Math.ceil(AI_PHOTO_LIMITS.maxImageBytes / 3) * 4 + 2048;

export function createAiPhotoHandler(deps: AiPhotoDeps) {
  const limits = deps.limits ?? AI_PHOTO_LIMITS;
  const log = (fields: Record<string, unknown>) =>
    (deps.log ?? ((f) => console.log(JSON.stringify(f))))({ scope: 'describe-proof-photo', ...fields });

  const featureOn = async () => {
    if (!deps.enabled() || !deps.describe) return false;
    try {
      return !await deps.store.isPaused();
    } catch (_) {
      return false;
    }
  };

  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    try {
      if (req.method === 'GET') return json({ enabled: await featureOn() });
      if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

      if (Number(req.headers.get('content-length') ?? 0) > MAX_BODY_BYTES) {
        return json({ error: 'Request is too large', code: 'imageTooLarge' }, 413);
      }
      let body: Record<string, unknown>;
      try {
        const text = await req.text();
        if (text.length > MAX_BODY_BYTES) return json({ error: 'Request is too large', code: 'imageTooLarge' }, 413);
        const parsed = JSON.parse(text);
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('not an object');
        body = parsed;
      } catch (_) {
        return json({ error: 'Invalid JSON body' }, 400);
      }
      const action = body.action ?? 'describe';
      if (action !== 'describe' && action !== 'consent' && action !== 'withdraw' && action !== 'allowance') {
        return json({ error: 'Unknown action' }, 400);
      }
      const refuse = (reason: string) => {
        log({ event: 'refused', action, reason });
        return json({ [action === 'consent' ? 'consented' : 'described']: false, reason });
      };

      // 1. Feature switch. Withdrawing consent works whatever state it is in.
      if (action !== 'withdraw' && !await featureOn()) return refuse('featureOff');

      // 2. Signed-in user.
      const user = await deps.authenticate(req);
      if (!user) return json({ error: 'Invalid user authorization' }, 401);

      if (action === 'withdraw') {
        await deps.store.withdrawConsent(user.id);
        log({ event: 'consent_withdrawn' });
        return json({ withdrawn: true });
      }

      // 3. Personal Premium, checked on the server.
      if (!await deps.store.hasActiveEntitlement(user.id)) return refuse('noActiveEntitlement');

      if (action === 'allowance') {
        return json({ allowance: await deps.store.allowance(user.id) });
      }

      if (action === 'consent') {
        if (body.consentVersion !== AI_PHOTO_CONSENT_VERSION) {
          return json({ error: 'This consent wording is out of date. Update Pebble and try again.', code: 'consentVersion' }, 409);
        }
        const routineKey = isValidRoutineKey(body.routineKey) ? body.routineKey : null;
        const appVersion = typeof body.appVersion === 'string' ? body.appVersion.slice(0, 40) : null;
        await deps.store.recordConsent({ userId: user.id, version: AI_PHOTO_CONSENT_VERSION, routineKey, appVersion });
        log({ event: 'consent_recorded' });
        return json({ consented: true });
      }

      // 4. Current consent. 5. The request itself. 6. Allowance and budget.
      if (!await deps.store.hasCurrentConsent(user.id, AI_PHOTO_CONSENT_VERSION)) return refuse('noConsent');

      if (!isValidIdempotencyKey(body.idempotencyKey)) {
        return json({ error: 'idempotencyKey is required', code: 'idempotencyKey' }, 400);
      }
      // Bound context before reserving allowance. Missing context is supported
      // for callers that only need a general photo description.
      if (body.stepLabel !== undefined &&
          (typeof body.stepLabel !== 'string' || body.stepLabel.length > 1000)) {
        return json({ error: 'stepLabel must be text of at most 1000 characters', code: 'stepLabel' }, 400);
      }
      const stepLabel = typeof body.stepLabel === 'string' ? body.stepLabel.trim() : undefined;
      const image = validateJpegBase64(body.imageBase64);
      if (!image.ok) {
        log({ event: 'invalid_image', code: image.code });
        return json({ error: 'A JPEG photo is required', code: image.code }, image.code === 'imageTooLarge' ? 413 : 400);
      }

      const reservation = await deps.store.reserve({
        userId: user.id,
        idempotencyKey: body.idempotencyKey,
        dailyLimit: limits.dailyPerUser,
        monthlyLimit: limits.monthlyRequests,
      });
      if (reservation === 'duplicate') return refuse('duplicate');
      if (reservation === 'daily_limit') return refuse('dailyLimit');
      if (reservation === 'monthly_limit') return refuse('monthlyLimit');
      if (reservation !== 'ok') return refuse('budgetExhausted');

      const result = await deps.describe!(body.imageBase64 as string, stepLabel);
      if (!result.ok) {
        log({ event: 'provider_failed', code: result.code, bytes: image.bytes });
        return json({ described: false, reason: 'couldNotDescribe' });
      }
      const parsed = parseProviderReply(result.text);
      if (!parsed.ok) {
        log({ event: 'not_described', code: parsed.code, bytes: image.bytes });
        return json({ described: false, reason: 'couldNotDescribe' });
      }
      log({ event: 'described', bytes: image.bytes });
      return json({ described: true, description: parsed.description });
    } catch (error) {
      // Error names only: a message could quote request content.
      log({ event: 'unexpected_error', name: error instanceof Error ? error.name : 'unknown' });
      return json({ error: 'Photo could not be described', code: 'serverError' }, 500);
    }
  };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json', 'cache-control': 'no-store' },
  });
}

// deno-lint-ignore no-explicit-any
export function supabaseAiPhotoStore(client: any): AiPhotoStore {
  const check = <T>(result: { data: T; error: { message: string } | null }): T => {
    // The message can name a column but never carries request content.
    if (result.error) throw new Error('database');
    return result.data;
  };
  return {
    async isPaused() {
      const row = check(await client.from('ai_photo_settings').select('paused').maybeSingle()) as { paused?: boolean } | null;
      // No row means the migration has not been applied: stay off.
      return row?.paused !== false;
    },
    async hasActiveEntitlement(userId) {
      return check(await client.rpc('has_active_personal_entitlement', { user_id: userId })) === true;
    },
    async hasCurrentConsent(userId, version) {
      const row = check(await client.from('ai_photo_consents').select('owner_user_id')
        .eq('owner_user_id', userId).eq('consent_version', version).is('withdrawn_at', null).maybeSingle());
      return row !== null;
    },
    async recordConsent({ userId, version, routineKey, appVersion }) {
      const now = new Date().toISOString();
      check(await client.from('ai_photo_consents').upsert({
        owner_user_id: userId,
        consent_version: version,
        provider: 'anthropic',
        routine_key: routineKey,
        app_version: appVersion,
        consented_at: now,
        withdrawn_at: null,
        updated_at: now,
      }, { onConflict: 'owner_user_id' }));
    },
    async withdrawConsent(userId) {
      const now = new Date().toISOString();
      check(await client.from('ai_photo_consents').update({ withdrawn_at: now, updated_at: now })
        .eq('owner_user_id', userId).is('withdrawn_at', null));
    },
    async allowance(userId) {
      const value = check(await client.rpc('get_ai_photo_allowance', { p_user_id: userId }));
      if (!value || typeof value !== 'object') throw new Error('database');
      return value as AiPhotoAllowance;
    },
    async reserve({ userId, idempotencyKey, dailyLimit, monthlyLimit }) {
      const outcome = check(await client.rpc('reserve_ai_photo_description', {
        p_user_id: userId,
        p_idempotency_key: idempotencyKey,
        p_daily_limit: dailyLimit,
        p_monthly_limit: monthlyLimit,
      }));
      return outcome === 'ok' || outcome === 'duplicate' || outcome === 'daily_limit' || outcome === 'monthly_limit' ? outcome : 'budget_exhausted';
    },
  };
}
