import { activePersonalEntitlement, handler } from "./index.ts";
import { mapRevenueCatEvent } from "../revenuecat-webhook/index.ts";
import { purchaseTokenHash } from "../_shared/revenuecat.ts";

const USER = "a413cdbe-3dee-4eb5-8b59-b31dd23f4bed";

function restResponse(expiresMs: number) {
  return {
    subscriber: {
      entitlements: {
        personal_premium: {
          product_identifier: "personal_premium",
          product_plan_identifier: "yearly",
          purchase_date: new Date(expiresMs - 365 * 86_400_000).toISOString(),
          expires_date: new Date(expiresMs).toISOString(),
        },
      },
      subscriptions: {
        personal_premium: {
          store: "play_store",
          store_transaction_id: "GPA.1111-2222-3333-44444..1",
          product_plan_identifier: "yearly",
          expires_date: new Date(expiresMs).toISOString(),
        },
      },
    },
  };
}

Deno.test("sync and webhook derive the same purchase claim for one Google Play purchase", async () => {
  const expiresMs = Date.now() + 86_400_000;
  const active = activePersonalEntitlement(
    restResponse(expiresMs),
    "personal_premium",
  );
  if (!active) throw new Error("Expected an active entitlement");
  const syncKey = await purchaseTokenHash({
    userId: USER,
    store: active.store,
    productId: active.productId,
    originalTransactionId: active.originalTransactionId,
    transactionId: active.storeTransactionId,
  });

  const webhook = await mapRevenueCatEvent({
    type: "RENEWAL",
    entitlement_ids: ["personal_premium"],
    product_id: "personal_premium:yearly",
    store: "PLAY_STORE",
    transaction_id: "GPA.1111-2222-3333-44444..1",
    original_transaction_id: "GPA.1111-2222-3333-44444",
    expiration_at_ms: expiresMs,
  }, USER);
  if (!webhook) throw new Error("Expected mapped webhook event");

  const sync = {
    store: active.store,
    productId: active.productId,
    hash: syncKey.hash,
  };
  const hook = {
    store: webhook.store,
    productId: webhook.productId,
    hash: webhook.purchaseTokenHash,
  };
  if (JSON.stringify(sync) !== JSON.stringify(hook)) {
    throw new Error(
      `Sync ${JSON.stringify(sync)} != webhook ${JSON.stringify(hook)}`,
    );
  }
});

Deno.test("activePersonalEntitlement ignores an expired entitlement", () => {
  const active = activePersonalEntitlement(
    restResponse(Date.now() - 1000),
    "personal_premium",
  );
  if (active !== null) throw new Error("Expected null for expired entitlement");
});

function setupEnv() {
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_ANON_KEY", "anon-key-123");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-123");
  Deno.env.set("REVENUECAT_REST_API_KEY", "rc-key-123");
}

Deno.test("handler rejects GET requests with 405", async () => {
  setupEnv();
  const response = await handler(
    new Request("https://example.test/revenuecat-sync-entitlement", {
      method: "GET",
    }),
  );

  if (response.status !== 405) {
    throw new Error(`Expected 405, got ${response.status}`);
  }
});

Deno.test("handler rejects requests with missing authorization with 401", async () => {
  setupEnv();
  const response = await handler(
    new Request("https://example.test/revenuecat-sync-entitlement", {
      method: "POST",
    }),
  );

  if (response.status !== 401) {
    throw new Error(`Expected 401, got ${response.status}`);
  }
});

Deno.test("handler rejects requests using anon key with 401", async () => {
  setupEnv();
  const response = await handler(
    new Request("https://example.test/revenuecat-sync-entitlement", {
      method: "POST",
      headers: {
        authorization: "Bearer anon-key-123",
      },
    }),
  );

  if (response.status !== 401) {
    throw new Error(`Expected 401, got ${response.status}`);
  }
});
