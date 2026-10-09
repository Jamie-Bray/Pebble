// The AI routine builder (/mnt/project-files/ai-routine-builder/PLAN.md).
//
// GET                                      -> {enabled}
// POST {action:'status', installId}        -> {enabled, premium, freeBuildUsed}
// POST {action:'questions'|'draft', installId, buildKey, description, answers?}
//      questions -> {ok: true, questions: [{question, options}]}
//      draft     -> {ok: true, draft: {name, steps: [{label, photo}]}}
//                 | {ok: false, reason}
//
// `reason` is one of featureOff, freeUsed, dailyLimit, busy, tooManyTries,
// couldNotBuild. Sign-in is optional: a signed-in person's free build also
// follows their account, and Personal Premium is checked on the server.
//
// Checks run in this order and fail closed before any provider call: the
// feature switch, the request, Personal Premium, then the allowance and the
// monthly budget (one database transaction, never refunded).
//
// Privacy: what the person typed is held in memory for the provider call.
// Neither it nor the draft is stored or logged; logs carry outcome codes only.

import {
  isValidBuildKey,
  isValidInstallId,
  parseDraftReply,
  parseQuestionsReply,
  ROUTINE_AI_LIMITS,
  validateBuildRequest,
} from '../_shared/routine_ai.ts';
import type { AuthUser } from './supabase.ts';
import type { AskRoutineAi } from './provider.ts';

export type Reservation =
  | 'ok'
  | 'too_many_tries'
  | 'free_used'
  | 'pending'
  | 'daily_limit'
  | 'free_daily_cap'
  | 'budget_exhausted';

export interface RoutineAiStore {
  /** The database off switch (public.routine_ai_settings.paused). */
  isPaused(): Promise<boolean>;
  hasActiveEntitlement(userId: string): Promise<boolean>;
  freeBuildUsed(installId: string, userId: string | null): Promise<boolean>;
  reserve(input: {
    buildKey: string;
    installId: string;
    userId: string | null;
    premium: boolean;
    callsPerBuild: number;
    premiumDailyLimit: number;
    freeDailyCap: number;
    monthlyLimit: number;
  }): Promise<Reservation>;
  /** Releases the pending call or consumes the free build after a draft. */
  finish(buildKey: string, outcome: 'draft' | 'questions' | 'failed'): Promise<'ok' | 'free_used'>;
}

export type RoutineAiDeps = {
  /** The ROUTINE_AI_ENABLED secret (off only when set to "false"). */
  enabled: () => boolean;
  limits?: Partial<typeof ROUTINE_AI_LIMITS>;
  store: RoutineAiStore;
  authenticate: (req: Request) => Promise<AuthUser | null>;
  /** null when no provider key is configured. */
  ask: AskRoutineAi | null;
  log?: (fields: Record<string, unknown>) => void;
};

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
};

const MAX_BODY_BYTES = 4096;

export function createRoutineAiHandler(deps: RoutineAiDeps) {
  const limits = { ...ROUTINE_AI_LIMITS, ...deps.limits };
  const log = (fields: Record<string, unknown>) =>
    (deps.log ?? ((f) => console.log(JSON.stringify(f))))({ scope: 'build-routine', ...fields });

  const featureOn = async () => {
    if (!deps.enabled() || !deps.ask) return false;
    try {
      return !await deps.store.isPaused();
    } catch (_) {
      return false;
    }
  };

  const premiumFor = async (user: AuthUser | null) => {
    if (!user) return false;
    try {
      return await deps.store.hasActiveEntitlement(user.id);
    } catch (_) {
      return false;
    }
  };

  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    try {
      if (req.method === 'GET') return json({ enabled: await featureOn() });
      if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

      let body: Record<string, unknown>;
      try {
        const text = await req.text();
        if (text.length > MAX_BODY_BYTES) return json({ error: 'Request is too large' }, 413);
        const parsed = JSON.parse(text);
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('not an object');
        body = parsed;
      } catch (_) {
        return json({ error: 'Invalid JSON body' }, 400);
      }
      const action = body.action;
      if (action !== 'status' && action !== 'questions' && action !== 'draft') {
        return json({ error: 'Unknown action' }, 400);
      }
      if (!isValidInstallId(body.installId)) return json({ error: 'installId is required', code: 'installId' }, 400);
      const installId = body.installId.toLowerCase();

      const refuse = (reason: string) => {
        log({ event: 'refused', action, reason });
        return json({ ok: false, reason });
      };

      // 1. Feature switch.
      const on = await featureOn();
      const user = await deps.authenticate(req).catch(() => null);

      if (action === 'status') {
        if (!on) return json({ enabled: false, premium: false, freeBuildUsed: false });
        const premium = await premiumFor(user);
        const freeBuildUsed = premium ? false : await deps.store.freeBuildUsed(installId, user?.id ?? null);
        return json({ enabled: true, premium, freeBuildUsed });
      }
      if (!on) return refuse('featureOff');

      // 2. The request itself.
      if (!isValidBuildKey(body.buildKey)) return json({ error: 'buildKey is required', code: 'buildKey' }, 400);
      const request = validateBuildRequest(body);
      if (!request.ok) return json({ error: 'Invalid request', code: request.code }, 400);

      // 3. Personal Premium, checked on the server. 4. Allowance and budget.
      const premium = await premiumFor(user);
      const reservation = await deps.store.reserve({
        buildKey: body.buildKey,
        installId,
        userId: user?.id ?? null,
        premium,
        callsPerBuild: limits.callsPerBuild,
        premiumDailyLimit: limits.premiumDailyPerUser,
        freeDailyCap: limits.freeDailyCap,
        monthlyLimit: limits.monthlyCalls,
      });
      if (reservation === 'free_used') return refuse('freeUsed');
      if (reservation === 'daily_limit') return refuse('dailyLimit');
      if (reservation === 'too_many_tries') return refuse('tooManyTries');
      if (reservation !== 'ok') return refuse('busy');

      const kind = action === 'draft' ? 'draft' : 'questions';
      const result = await deps.ask!({ kind, ...request.request });
      if (!result.ok) {
        await deps.store.finish(body.buildKey, 'failed');
        log({ event: 'provider_failed', action, code: result.code });
        return refuse('couldNotBuild');
      }
      if (kind === 'questions') {
        const parsed = parseQuestionsReply(result.text);
        if (!parsed.ok) {
          await deps.store.finish(body.buildKey, 'failed');
          log({ event: 'not_built', action, code: parsed.code });
          return refuse('couldNotBuild');
        }
        await deps.store.finish(body.buildKey, 'questions');
        log({ event: 'asked', count: parsed.questions.length, premium });
        return json({ ok: true, questions: parsed.questions });
      }
      const parsed = parseDraftReply(result.text);
      if (!parsed.ok) {
        await deps.store.finish(body.buildKey, 'failed');
        log({ event: 'not_built', action, code: parsed.code });
        return refuse('couldNotBuild');
      }
      if (await deps.store.finish(body.buildKey, 'draft') === 'free_used') return refuse('freeUsed');
      log({ event: 'built', steps: parsed.draft.steps.length, premium });
      return json({ ok: true, draft: parsed.draft });
    } catch (error) {
      // Error names only: a message could quote request content.
      log({ event: 'unexpected_error', name: error instanceof Error ? error.name : 'unknown' });
      return json({ error: 'Routine could not be built', code: 'serverError' }, 500);
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
export function supabaseRoutineAiStore(client: any): RoutineAiStore {
  const check = <T>(result: { data: T; error: { message: string } | null }): T => {
    if (result.error) throw new Error('database');
    return result.data;
  };
  return {
    async isPaused() {
      const row = check(await client.from('routine_ai_settings').select('paused').maybeSingle()) as { paused?: boolean } | null;
      // No row means the migration has not been applied: stay off.
      return row?.paused !== false;
    },
    async hasActiveEntitlement(userId) {
      return check(await client.rpc('has_active_personal_entitlement', { user_id: userId })) === true;
    },
    async freeBuildUsed(installId, userId) {
      return check(await client.rpc('routine_ai_free_build_used', { p_install_id: installId, p_user_id: userId })) === true;
    },
    async reserve(input) {
      const value = check(await client.rpc('reserve_routine_ai_call', {
        p_build_key: input.buildKey,
        p_install_id: input.installId,
        p_user_id: input.userId,
        p_premium: input.premium,
        p_calls_per_build: input.callsPerBuild,
        p_premium_daily_limit: input.premiumDailyLimit,
        p_free_daily_cap: input.freeDailyCap,
        p_monthly_limit: input.monthlyLimit,
      }));
      return (typeof value === 'string' ? value : 'budget_exhausted') as Reservation;
    },
    async finish(buildKey, outcome) {
      const value = check(await client.rpc('finish_routine_ai_call', {
        p_build_key: buildKey,
        p_outcome: outcome,
      }));
      if (value === 'ok' || value === 'free_used') return value;
      throw new Error('database');
    },
  };
}
