import { handler } from "./index.ts";

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
