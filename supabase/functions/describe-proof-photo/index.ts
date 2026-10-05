// Describes one proof photo with AI. Logic: ./handler.ts, provider: ./provider.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { AI_PHOTO_LIMITS } from '../_shared/ai_photo.ts';
import { serviceClient, supabaseAuthenticator } from '../_shared/shared_alert_runtime.ts';
import { createAiPhotoHandler, supabaseAiPhotoStore } from './handler.ts';
import { anthropicDescriber } from './provider.ts';

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
      new Response(JSON.stringify({ error: 'AI photo environment is not configured' }), {
        status: 500,
        headers: { 'content-type': 'application/json', 'access-control-allow-origin': '*' },
      })
    : createAiPhotoHandler({
      // Read on every request, so the switch is not baked into a warm worker.
      enabled: () => env('AI_PHOTO_ENABLED').toLowerCase() === 'true',
      limits: {
        dailyPerUser: positiveInt('AI_PHOTO_DAILY_LIMIT', AI_PHOTO_LIMITS.dailyPerUser),
        monthlyRequests: positiveInt('AI_PHOTO_MONTHLY_REQUEST_BUDGET', AI_PHOTO_LIMITS.monthlyRequests),
      },
      store: supabaseAiPhotoStore(serviceClient({ supabaseUrl, serviceRoleKey })),
      authenticate: supabaseAuthenticator({ supabaseUrl, anonKey }),
      describe: apiKey ? anthropicDescriber(apiKey) : null,
    }),
);
