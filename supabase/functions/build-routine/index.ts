// Drafts a routine from a sentence with AI. Logic: ./handler.ts, provider: ./provider.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { ROUTINE_AI_LIMITS } from '../_shared/routine_ai.ts';
import { optionalAuthenticator, serviceClient } from './supabase.ts';
import { createRoutineAiHandler, supabaseRoutineAiStore } from './handler.ts';
import { anthropicRoutineAi } from './provider.ts';

const env = (name: string) => Deno.env.get(name)?.trim() || '';
const positiveInt = (name: string, fallback: number) => {
  const value = Number(env(name));
  return Number.isInteger(value) && value > 0 ? value : fallback;
};

const supabaseUrl = env('SUPABASE_URL');
const anonKey = env('SUPABASE_ANON_KEY');
const serviceRoleKey = env('SUPABASE_SERVICE_ROLE_KEY');
const apiKey = env('ANTHROPIC_API_KEY');

serve(
  !supabaseUrl || !anonKey || !serviceRoleKey
    ? () =>
      new Response(JSON.stringify({ error: 'Routine AI environment is not configured' }), {
        status: 500,
        headers: { 'content-type': 'application/json', 'access-control-allow-origin': '*' },
      })
    : createRoutineAiHandler({
      // Read on every request, so the switch is not baked into a warm worker.
      // On unless set to "false"; the routine_ai_settings.paused row is the
      // everyday off switch.
      enabled: () => env('ROUTINE_AI_ENABLED').toLowerCase() !== 'false',
      limits: {
        premiumDailyPerUser: positiveInt('ROUTINE_AI_PREMIUM_DAILY_LIMIT', ROUTINE_AI_LIMITS.premiumDailyPerUser),
        freeDailyCap: positiveInt('ROUTINE_AI_FREE_DAILY_CAP', ROUTINE_AI_LIMITS.freeDailyCap),
        monthlyCalls: positiveInt('ROUTINE_AI_MONTHLY_CALLS', ROUTINE_AI_LIMITS.monthlyCalls),
      },
      store: supabaseRoutineAiStore(serviceClient({ supabaseUrl, serviceRoleKey })),
      authenticate: optionalAuthenticator({ supabaseUrl, anonKey }),
      ask: apiKey ? anthropicRoutineAi(apiKey) : null,
    }),
);
