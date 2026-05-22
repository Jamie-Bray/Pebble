import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type VerifyPurchaseRequest = {
  store: 'googlePlay' | 'appStore';
  productId: string;
  serverVerificationData: string;
};

type VerifiedPurchase = {
  productId: string;
  tier: 'personalPremium' | 'pebbleHousehold';
  status: 'active' | 'grace' | 'account_hold' | 'paused' | 'cancelled_active' | 'expired';
  periodStartedAt: string | null;
  periodEndsAt: string | null;
};

const personalPremiumProductIds = new Set([
  'personal_premium',
]);

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: 'Supabase environment is not configured' }, 500);
  }

  const authorization = req.headers.get('authorization') ?? '';
  const jwt = authorization.replace(/^Bearer\s+/i, '').trim();
  if (!jwt || jwt === anonKey) {
    return json({ error: 'Missing user authorization' }, 401);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(jwt);
  if (userError || !userData.user) {
    return json({ error: 'Invalid user authorization' }, 401);
  }
  const userId = userData.user.id;

  let body: VerifyPurchaseRequest;
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: 'Invalid JSON body' }, 400);
  }

  if (!body.productId || !body.serverVerificationData || !body.store) {
    return json({ error: 'store, productId, and serverVerificationData are required' }, 400);
  }

  if (!isKnownProduct(body.productId)) {
    return json({ error: 'Unknown Pebble product ID' }, 400);
  }

  const verification = await verifyPurchase(body);
  if (!verification.ok) {
    return json({ error: verification.error }, verification.status);
  }

  const purchase = verification.purchase;
  const now = new Date().toISOString();
  const tokenHash = await sha256Hex(body.serverVerificationData);
  const serviceClient = createClient(supabaseUrl, serviceRoleKey);
  const entitlementRow = {
    owner_user_id: userId,
    product_id: purchase.productId,
    store: body.store,
    purchase_token_hash: tokenHash,
    entitlement_tier: purchase.tier,
    status: purchase.status,
    period_started_at: purchase.periodStartedAt,
    period_ends_at: purchase.periodEndsAt,
    last_verified_at: now,
    updated_at: now,
  };

  const { data: entitlement, error: entitlementError } = await serviceClient
    .from('personal_entitlements')
    .upsert(entitlementRow, {
      onConflict: 'owner_user_id,store,product_id,purchase_token_hash',
    })
    .select()
    .single();

  if (entitlementError) {
    return json({ error: entitlementError.message }, 500);
  }

  await serviceClient.from('profiles').upsert({
    id: userId,
    tier: isEntitlementCurrentlyActive(purchase.status, purchase.periodEndsAt)
      ? purchase.tier
      : 'personalFree',
    updated_at: now,
  });

  return json({
    entitlement: {
      tier: entitlement.entitlement_tier,
      status: entitlement.status,
      productId: entitlement.product_id,
      periodStartedAt: entitlement.period_started_at,
      periodEndsAt: entitlement.period_ends_at,
      lastVerifiedAt: entitlement.last_verified_at,
    },
  });
});

async function verifyPurchase(
  body: VerifyPurchaseRequest,
): Promise<
  | { ok: true; purchase: VerifiedPurchase }
  | { ok: false; status: number; error: string }
> {
  if (body.store !== 'googlePlay') {
    return {
      ok: false,
      status: 501,
      error: 'This store is not wired yet',
    };
  }

  if (!Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME') || !Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON')) {
    return {
      ok: false,
      status: 501,
      error: 'Google Play verification is not configured yet',
    };
  }

  try {
    const purchase = await getGooglePlaySubscription(body.serverVerificationData);
    const lineItem = selectLineItem(purchase, body.productId);
    if (!lineItem) {
      return {
        ok: false,
        status: 403,
        error: 'Google Play purchase does not contain this Pebble product',
      };
    }

    const mappedStatus = mapGoogleSubscriptionState(
      purchase.subscriptionState,
      lineItem.expiryTime ?? null,
    );

    return {
      ok: true,
      purchase: {
        productId: body.productId,
        tier: tierForProduct(body.productId),
        status: mappedStatus,
        periodStartedAt: purchase.startTime ?? null,
        periodEndsAt: lineItem.expiryTime ?? null,
      },
    };
  } catch (error) {
    return {
      ok: false,
      status: 502,
      error: error instanceof Error
        ? error.message
        : 'Google Play verification failed',
    };
  }
}

async function getGooglePlaySubscription(purchaseToken: string): Promise<GoogleSubscriptionPurchaseV2> {
  const packageName = Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME')!;
  const accessToken = await getGoogleAccessToken();
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;

  const response = await fetch(url, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  const data = await response.json().catch(() => null);
  if (!response.ok) {
    const message = data?.error?.message ?? 'Google Play rejected the purchase token';
    throw new Error(message);
  }
  return data as GoogleSubscriptionPurchaseV2;
}

async function getGoogleAccessToken(): Promise<string> {
  const rawJson = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON')!;
  const credentials = JSON.parse(rawJson) as {
    client_email?: string;
    private_key?: string;
    token_uri?: string;
  };
  if (!credentials.client_email || !credentials.private_key) {
    throw new Error('Google Play service account JSON is incomplete');
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: credentials.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: credentials.token_uri ?? 'https://oauth2.googleapis.com/token',
    exp: nowSeconds + 3600,
    iat: nowSeconds,
  };
  const unsigned = `${base64UrlJson(header)}.${base64UrlJson(claim)}`;
  const key = await importPrivateKey(credentials.private_key);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;

  const tokenResponse = await fetch(credentials.token_uri ?? 'https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const tokenData = await tokenResponse.json().catch(() => null);
  if (!tokenResponse.ok || !tokenData?.access_token) {
    throw new Error(tokenData?.error_description ?? 'Could not authenticate with Google Play');
  }
  return tokenData.access_token as string;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const base64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return crypto.subtle.importKey(
    'pkcs8',
    bytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

function selectLineItem(
  purchase: GoogleSubscriptionPurchaseV2,
  productId: string,
): GoogleSubscriptionLineItem | null {
  return purchase.lineItems?.find((item) => item.productId === productId) ?? null;
}

function mapGoogleSubscriptionState(
  state: string | undefined,
  expiryTime: string | null,
): VerifiedPurchase['status'] {
  switch (state) {
    case 'SUBSCRIPTION_STATE_ACTIVE':
      return isFuture(expiryTime) ? 'active' : 'expired';
    case 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD':
      return isFuture(expiryTime) ? 'grace' : 'expired';
    case 'SUBSCRIPTION_STATE_ON_HOLD':
      return 'account_hold';
    case 'SUBSCRIPTION_STATE_PAUSED':
      return 'paused';
    case 'SUBSCRIPTION_STATE_CANCELED':
      return isFuture(expiryTime) ? 'cancelled_active' : 'expired';
    case 'SUBSCRIPTION_STATE_EXPIRED':
    case 'SUBSCRIPTION_STATE_PENDING':
    case 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED':
    default:
      return 'expired';
  }
}

function isFuture(value: string | null): boolean {
  return value !== null && new Date(value).getTime() > Date.now();
}

function isKnownProduct(productId: string): boolean {
  return personalPremiumProductIds.has(productId);
}

function tierForProduct(productId: string): 'personalPremium' | 'pebbleHousehold' {
  return 'personalPremium';
}

function isEntitlementCurrentlyActive(status: string, periodEndsAt: string | null): boolean {
  if (!['active', 'grace', 'cancelled_active'].includes(status)) {
    return false;
  }
  return periodEndsAt === null || new Date(periodEndsAt).getTime() > Date.now();
}

async function sha256Hex(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'content-type': 'application/json',
    },
  });
}

function base64UrlJson(value: unknown): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}

function base64Url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

type GoogleSubscriptionPurchaseV2 = {
  startTime?: string;
  subscriptionState?: string;
  lineItems?: GoogleSubscriptionLineItem[];
};

type GoogleSubscriptionLineItem = {
  productId?: string;
  expiryTime?: string;
};
