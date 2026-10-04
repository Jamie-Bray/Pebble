# Backend live audit

**Date:** 4 October 2026
**Project:** `pebble-production` (`yncgjqbjjzbinqkpukug`). Staging (`lxvrvrrxdjbrjwsxzppl`) was left paused and untouched.
**Method:** read-only. Supabase connector (`list_migrations`, `list_tables`, `list_edge_functions`, `get_edge_function` for all 11 functions, both advisors, catalogue `SELECT`s, `query_logs`), plus a source read of `supabase/functions` and the Deno tests.
**Changed in Supabase by this audit:** nothing. No row content was read beyond counts and status totals. No secret values were read or recorded. One of my catalogue queries had a typo and shows up as the single `ERROR` in the Postgres log (06:17 UTC); it was a `SELECT` and changed nothing.

## Verdict

**Production is behind the repo. Nothing from the October backend work has been deployed except two hand-run grants.** Testing of sign-in and local routines can start now. Testing of subscriptions, completion emails and voice-prompt backup should wait for the owner steps in section (b).

- All 11 Edge Functions are still the May to July versions. Nine of them differ from the repo; `delete-account` matches; `verify-purchase` is unused.
- Migrations 001 to 013, 015 and 016 are in effect. **014, 017, 018 and 019 are not.**
- **Migration 020 is half applied.** Its first section (taking away the app's direct write access to the `shared_alert_*` tables) is live: the Postgres log shows the `revoke` statements being run on 3 Oct 2026 at 10:08 UTC. The rest of 020 (new columns, the opt-out table, the retention job) is not live. **This live change is not recorded in `supabase/DEPLOY_PLAN.md`,** which still says nothing has been applied. The consent-forging hole described in `COMPLETION_EMAIL_REVIEW.md` is therefore already closed.
- The web page the new email links need (`https://pebbleroutines.com/shared-alert/confirm/`) returns **404**. The result pages (`/accepted/`, `/problem/`) are up.
- The nightly cleanup job is healthy (147 runs, 0 failures). `prune-shared-alert-data-daily` and `reconcile-profile-tiers-daily` do not exist yet.

---

## (a) Live versus repo

### Migrations

"Recorded" is what `supabase_migrations.schema_migrations` says. "In effect" is what the catalogue shows, which is what matters.

| Repo file | Recorded as | In effect? | Evidence (4 Oct) |
|---|---|---|---|
| `001` to `011` | `001` to `011` | **Live** | 14 public tables, RLS on for all 14; the 3 `routine-proofs` storage policies; `personal_entitlements_unique_active_store_purchase` (009); `shared_alert_invites` policies go through the owning contact (010); consent hash `447b6676…` in `has_current_cloud_backup_consent` (011); no `anon` table grants beyond the leftovers noted below. |
| `012_function_grant_hardening` | `20260610083720` | **Live** | `anon` cannot execute any public function. Trigger functions have no API `EXECUTE`. `tg_set_updated_at` and `guard_profile_tier_client_write` have `search_path=""`. |
| `013_restore_rls_helper_grants` | not recorded | **Live** | `authenticated` can execute `has_active_personal_entitlement` and `has_personal_cloud_write_access`. |
| `014_rls_initplan_and_index` | not recorded | **Not live** | 36 of 37 public policies still have role `public` and bare `auth.uid()`. `idx_routine_reminders_routine_id` does not exist. Advisors: 36 `auth_rls_initplan`, 1 `unindexed_foreign_keys`. |
| `015_proof_usage_soft_delete_without_entitlement` | `20260714194247` | **Live** | `proof_asset_usage_update_with_entitlement` is `to authenticated`, uses `(select auth.uid())`, and has the `deleted_at is not null` escape. |
| `016_service_role_entitlement_helper_grant` | not recorded | **Live** | `has_function_privilege('service_role', …)` is true. Postgres log: `grant execute …` on 3 Oct 09:09 UTC. Matches the record in `DEPLOY_PLAN.md`. |
| `017_profile_tier_mirror_from_entitlements` | not recorded | **Not live** | No `entitled_profile_tier`, `refresh_profile_tier`, `reconcile_profile_tiers` functions; no trigger on `personal_entitlements` except `updated_at`; no cron job. Both profiles still read `personalPremium` although no entitlement is inside its paid period. Access is not affected (RLS reads `period_ends_at`). |
| `018_account_deletion_request_throttle_indexes` | not recorded | **Not live** | Only `account_deletion_requests_pkey` and `…_email_status_idx` exist; no length check constraint. |
| `019_routine_proofs_bucket_limits` | not recorded | **Not live** | `routine-proofs`: `file_size_limit` null, `allowed_mime_types` null. |
| `020_completion_email_hardening` | not recorded | **Differs (partly live)** | **Section 1 live:** `authenticated` has only `SELECT` on `shared_alert_contacts`, `_blocks`, `_events` and nothing on `shared_alert_invites`; `anon` has nothing on any of the four. Postgres log: the `revoke` statements at 3 Oct 10:08 UTC. **Sections 2 to 6 not live:** no `purpose`, `recipient_email_hash`, `owner_user_id` on invites; no `expires_at` on blocks; no `attempts` on events; no `shared_alert_suppressions` table; no `prune_shared_alert_data()`; no `prune-shared-alert-data-daily` cron job; none of the new indexes or constraints. |

The live functions use the service role for every `shared_alert_*` write, so the revoke did not break them.

Leftover grants (not from any one migration): `anon` and `authenticated` still hold `TRUNCATE`, `TRIGGER` and `REFERENCES` on the ten non-`shared_alert` tables. PostgREST cannot use them. Harmless, untidy.

### Edge Functions

Live version, date and `verify_jwt` are from `list_edge_functions`. "Source" is from reading the deployed file with `get_edge_function` next to the repo file. Every live `verify_jwt` matches `supabase/config.toml` (`verify-purchase` has no entry there; the default is `true`, which is what is live).

| Function | Live | `verify_jwt` live / repo | Source | What differs |
|---|---|---|---|---|
| `cleanup-proof-retention` | v14, 19 May | false / false | **Differs** | Live runs for any caller when its secret is unset, compares the secret with `!==`, and has no voice-prompt exclusion: it deletes any `proof_asset_usage` row older than 21 days, including `guidance_audio`. Last night's response body has no `skippedGuidanceAudio` field, which confirms the old code is what ran. |
| `delete-account` | v13, 19 May | true / true | **Live (matches)** | Read both; same logic line for line. Not byte-compared. |
| `request-account-deletion` | v14, 19 May | false / false | **Differs** | Live has the `message.isEmpty` bug, no size limit, no throttle, a loose email check, returns raw database errors, and prefers `x-forwarded-for` (caller-supplied) over `cf-connecting-ip`. |
| `request-shared-alert-contact` | v14, 7 Jul | true / true | **Differs** | Live is a single file. Anonymous invite ("Someone has added this email address"), daily limit counted on the contact row (so resends are not counted), DELETE and PATCH need Premium, raw Resend errors returned to the app, email links act on GET. |
| `send-routine-completion-alert` | v14, 7 Jul | true / true | **Differs** | Live has no per-contact cap, no retry, no idempotency key, no block or opt-out check at send time, stores the full provider response, and always stores the routine title. |
| `shared-alert-accept` | v13, 19 May | false / false | **Differs** | Live **acts on a plain GET**. It also re-enables a contact the sender removed (no status check) and accepts with a completion-email token. |
| `shared-alert-decline` | v13, 19 May | false / false | **Differs** | Live acts on GET. No cooldown. |
| `shared-alert-block` | v13, 19 May | false / false | **Differs** | Live acts on GET. No global opt-out. |
| `revenuecat-webhook` | v12, 4 Jun | false / false | **Differs** | Live returns **409** on a cross-account claim, filters TRANSFER by product id (so it misses its own rows), and does not recompute the old owner's tier. |
| `revenuecat-sync-entitlement` | v9, 4 Jun | true / true | **Differs** | Live stores `product_id` without the base plan and a different hash, so its rows never line up with the webhook's. No release of stale claims. |
| `verify-purchase` | v16, 19 May | true / (no entry) | **Could not verify byte for byte** | Same structure and markers as the repo file. The app does not call it (no reference under `lib/`). It returns 501 unless the Google Play secrets are set. |

Nothing has been deployed since 7 July: every `updated_at` equals the dates in `DEPLOY_PLAN.md`.

### Scheduled jobs (pg_cron)

| Job | State | Recent results |
|---|---|---|
| `cleanup-proof-retention-daily` (`0 2 * * *`) | Exists, active. Sends `x-cleanup-secret` from the Vault secret `cleanup-proof-retention-header` (present). | 147 runs since 11 May, all `succeeded`, none failed. Last 8 nights all succeeded. The last HTTP response (4 Oct 02:00 UTC) was 200 with zero deletions. |
| `prune-shared-alert-data-daily` | **Does not exist** (020 section 6 not applied). | n/a |
| `reconcile-profile-tiers-daily` | **Does not exist** (017 not applied). | n/a |

`succeeded` in `cron.job_run_details` only means the HTTP call was queued. The real result is in `net._http_response`, which keeps only the latest response.

### Storage

- One bucket, `routine-proofs`: private, no size limit, no type limit, **0 objects**.
- Proof photos and voice prompts share it. Voice prompts go under `users/<uid>/guidance_audio/`. There is no separate audio bucket.
- Three policies on `storage.objects`, all scoped to `users/<own uid>/…`: read, delete, and insert. Insert also needs cloud write access (Premium plus consent) and a matching, unexpired `proof_asset_usage` row.
- There is no UPDATE policy, so an object cannot be overwritten. The app uploads with `upsert: false`, so that is consistent.
- The policies still use role `public` and bare `auth.uid()`. Migration 014 deliberately does not touch them.

### Advisors (every finding)

Security:

| Level | Finding | Count | Comment |
|---|---|---|---|
| WARN | `auth_allow_anonymous_sign_ins` | 17 | 13 public tables, `storage.objects`, `cron.job`, `cron.job_run_details`, and `information_schema.routines` (a false positive from the name clash with `public.routines`). Caused by policies with role `public`; 014 fixes the public tables. Production has 0 anonymous users. |
| WARN | `authenticated_security_definer_function_executable` | 2 | `has_active_personal_entitlement`, `has_personal_cloud_write_access`. Needed by RLS. A signed-in user can ask whether another user id is Premium. Low. |
| WARN | `extension_in_public` | 1 | `pg_net`. The cron job depends on it; leave. |
| WARN | `auth_leaked_password_protection` | 1 | Pebble has no passwords. |
| INFO | `rls_enabled_no_policy` | 1 | `account_deletion_requests`. Intended: service role only. |

Docs: [0012](https://supabase.com/docs/guides/database/database-advisors?queryGroups=lint&lint=0012_auth_allow_anonymous_sign_ins), [0029](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), [0014](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public), [leaked passwords](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection), [0008](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).

Performance:

| Level | Finding | Count | Comment |
|---|---|---|---|
| WARN | `auth_rls_initplan` | 36 | Fixed by 014. |
| WARN | `multiple_permissive_policies` | 12 | `profiles` and `sync_tombstones`, SELECT, six roles each. An `ALL` policy overlaps the `SELECT` one. Performance only. |
| INFO | `unindexed_foreign_keys` | 1 | `routine_reminders.routine_id`. Fixed by 014. |
| INFO | `unused_index` | 6 | No traffic yet. Ignore. |

Docs: [0003](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan), [0006](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies), [0001](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys), [0005](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index).

### Logs (2 Oct 06:30 to 4 Oct 06:30 UTC)

- **Edge functions:** one call per night, the cron cleanup, HTTP 200. No other function was called. No errors.
- **Auth:** no log lines at all. Nobody signed in. The last sign-in on record is 12 August.
- **Postgres:** checkpoints, the cron job, and the two hand-run statements on 3 Oct (the 016 grant at 09:09, the 020 revokes at 10:08). One `ERROR`, from this audit's own malformed `SELECT`.
- **PostgREST:** three "Thread killed by timeout manager" lines. These are idle-connection timeouts, not failures.

The connector only serves 24 hours per query, so the August failures in `SUPABASE_LIVE_AUDIT.md` (409 loop, repeated photo downloads) were not re-read. The live source that caused the 409 loop is unchanged.

### Data state (counts only)

2 users, 0 anonymous. 2 profiles, both `personalPremium`. 4 entitlement rows: 2 `active`, 2 `expired`; **none inside a paid period.** 0 contacts, invites, events, blocks, deletion requests, proof rows and storage objects.

---

## The question from the app side: `routine_runs.id` and `routine_sessions.id`

**Still the case.** On production both tables have `PRIMARY KEY (id)`, `id uuid` with no default (the app supplies it), and RLS on. The same is true of `routines` and `routine_reminders`. The policies on both tables are:

| Command | USING | WITH CHECK |
|---|---|---|
| SELECT | `auth.uid() = owner_user_id` | |
| INSERT | | `auth.uid() = owner_user_id AND has_personal_cloud_write_access(auth.uid())` |
| UPDATE | `auth.uid() = owner_user_id` | same as INSERT |
| DELETE | `auth.uid() = owner_user_id` | |

The app calls `.upsert(payload)` with no `onConflict`, which PostgREST turns into `INSERT … ON CONFLICT (id) DO UPDATE`.

**What Postgres does when user B upserts an id that already exists under user A:**

1. The INSERT `WITH CHECK` is applied to B's proposed row. It passes if B sets `owner_user_id` to themselves and has Premium plus consent. (If B sends A's id as owner, it fails here.)
2. The insert hits the primary key, so Postgres takes the `DO UPDATE` path. The **existing** row, which belongs to A, is tested against the UPDATE `USING` policy (and the SELECT policy, because `ON CONFLICT DO UPDATE` needs to read the row). `auth.uid() = owner_user_id` is false.
3. Postgres **raises an error**; it does not skip the row quietly. This is documented behaviour for `ON CONFLICT DO UPDATE` under RLS. SQLSTATE `42501`, "new row violates row-level security policy (USING expression)". PostgREST returns HTTP 403.
4. The whole statement rolls back. If the request carried several rows, none are saved.

So: **A's row is safe.** B cannot read it, change it or take it over. But **B's row can never be saved under that id,** and every retry fails the same way until A's row is gone.

Random UUIDs will not collide by chance. The realistic way to hit this is one phone, two accounts: local rows created (or already backed up) under account A, then the user signs into account B and the app uploads the same local ids. That is the account-switch path testers will take. Reasoned from the live policies; **not tested by writing.** B also learns that the id exists, which is harmless for UUIDs.

Options, for the app team to choose: give rows new ids when the signed-in account changes, or treat a 403 on upsert as "re-key this row and retry". A database-side fix (primary key on `(owner_user_id, id)`) is possible but needs a migration and changes every `onConflict`.

---

## (b) What the owner must do or approve before testing

In order. Steps marked **Approve** need someone with Supabase access to run them (a developer, or a Claude session you have told to go ahead); your part is to say yes. "DP" is `supabase/DEPLOY_PLAN.md`.

1. **Check the function secrets exist** (you, 5 minutes). Dashboard → Edge Functions → Secrets. You see names only. Tick off: `CLEANUP_PROOF_RETENTION_SECRET`, `REVENUECAT_WEBHOOK_SECRET`, `REVENUECAT_REST_API_KEY`, `RESEND_API_KEY`, `SHARED_ALERT_FROM_EMAIL`, `SHARED_ALERT_PUBLIC_BASE_URL`. The first one matters most: the new cleanup refuses to run without it. If it is missing, say so before step 4. *DP → Order, step 2, and "Secrets each changed function needs".*
2. **Publish the website** so the new confirm page is live. Today `https://pebbleroutines.com/shared-alert/confirm/` is a 404. Afterwards, open `https://pebbleroutines.com/shared-alert/confirm/#action=accept&token=xxxxxxxxxxxxxxxxxxxxxxxx` and check it says "Allow completion emails?". *DP → Order, step 3.1.*
3. **Approve: apply migration 020 in full.** Its first part is already live; the rest only adds things, and the file is safe to run again. Without it the new email functions fail on every request. *DP → Order, step 3.2.*
4. **Approve: deploy the nine functions,** in this order: `cleanup-proof-retention` first (it stops voice prompts being deleted), then `revenuecat-webhook` and `revenuecat-sync-entitlement` together, `request-account-deletion`, and last the five completion-email functions (only after steps 2 and 3). *DP → Order, step 4.*
5. **Approve: repair the migration history and apply 014, 017 and 018.** This is bookkeeping plus three safe changes; it clears 37 advisor warnings and fixes the two profiles stuck on Premium. *DP → Order, step 5; commands in `MIGRATION_REPAIR_PLAN.md`.* Proposed addition: also record 016 and 020 as applied, since both were run by hand.
6. **Approve: apply 019 (file limits) last,** after one real-device test of a voice-prompt upload. The app's default type is `audio/wav`, which 019 allows, but a device can report something else, and 019 would then reject it. *DP → Order, step 5, last sentence.*
7. **Sign-in settings** (you, in the dashboard). Turn off anonymous sign-ins. Turn on custom SMTP, or testers outside your Supabase organisation will not receive email codes. Check both email templates show the code (`{{ .Token }}`). For iOS: enable Apple and add the iOS Google client id. *DP → "Behaviour notes", config.toml; full click-paths in `SUPABASE_LIVE_AUDIT.md` → "Things only the owner can do", items 1 to 6.* I could not see any of these settings.
8. **RevenueCat dashboard** (you). Webhook URL is `https://yncgjqbjjzbinqkpukug.supabase.co/functions/v1/revenuecat-webhook` and its Authorization value equals `REVENUECAT_WEBHOOK_SECRET`. After step 4, press "Send test event" and expect 200. *DP → Order, step 6.*
9. **Sending domain for completion emails** (you). Add the domain in Resend and create the DNS records it shows. Until this is done, completion emails to real testers may not arrive. *`COMPLETION_EMAIL_REVIEW.md` → "What needs the owner", item 1; DP → Order, step 3.3.*
10. **Run the smoke checks** with two inboxes you own, and look at the morning after's cleanup result. *DP → Order, step 6.*
11. **Decide on the Supabase plan** before inviting outside testers. On Free the project can pause when idle and has no backups. *`SUPABASE_LIVE_AUDIT.md` → Must fix, item 1.*
12. **Housekeeping, any time:** delete the unused `verify-purchase` function; clear the two August test accounts' data; start checking the `account_deletion_requests` table weekly. *DP → "What changed", last row.*

What can be tested **before** any of this: Google sign-in, local routines, reminders, and cloud backup of routines for an account that has Premium. What should **not** be tested yet: account switching with a subscription (step 4), completion emails (steps 2 to 4 and 9), voice-prompt backup lasting more than 21 days (step 4), email-code sign-in for outside testers (step 7).

---

## (c) Risks, ranked

"Demonstrated" means I read it in live source, live catalogue or logs, or it follows directly from the code. "Hypothesis" means it depends on something I could not observe.

| # | Severity | Risk | Status |
|---|---|---|---|
| 1 | High | **Live cleanup deletes voice prompts after 21 days,** and runs for any caller if its secret is unset. The app on this branch backs voice prompts up with a 10-year expiry, but live cleanup deletes any row whose `created_at` is older than 21 days. Fixed in the repo, not deployed. | **Demonstrated** (live source; app source) |
| 2 | High | **Live email links act on GET.** A mail scanner opening the link can accept, decline or block on someone's behalf. Live accept also revives a contact the sender removed. Fixed in the repo, not deployed; and the fix needs the confirm page, which is a 404 today. | **Demonstrated** (live source; HTTP check) |
| 3 | High | **Live RevenueCat webhook returns 409 after an account switch** and leaves the old account marked Premium. Two profiles are stale today. Fixed in the repo, not deployed. | **Demonstrated** (live source; live counts; August logs in the earlier audit) |
| 4 | Medium | **Deploy order can break the feature.** The new completion-email functions query columns and a table that only exist after the rest of 020 (`purpose`, `attempts`, `shared_alert_suppressions`). Deployed first, every invite and send returns 500. The new cleanup returns 503 if its secret is missing. | **Demonstrated** (repo source against live schema) |
| 5 | Medium | **Second account on the same phone cannot back up rows with existing ids** (403 on upsert, see the section above). Applies to routines, reminders, runs and sessions. | **Demonstrated** by reasoning from live policies; not exercised |
| 6 | Medium | **Premium may switch off on the server during a store billing grace period.** `statusForRevenueCatEvent` maps `BILLING_ISSUE` to `grace` only if `expiration_at_ms` is in the future, and stores that as `period_ends_at`; the database gate requires `period_ends_at > now()`. RevenueCat reports the grace end in a separate field (`grace_period_expiration_at_ms`), which the function never reads. If `expiration_at_ms` is the original period end, the user keeps Premium in the app but cloud writes and completion emails are refused. The sync function has the same shape (`expires_date`). | **Hypothesis.** Needs one real billing-retry test, or a look at a real `BILLING_ISSUE` payload |
| 7 | Medium | **A live change is unrecorded.** Part of 020 was run on production and `DEPLOY_PLAN.md` was not updated. The plan and the review still describe the hole as open. | **Demonstrated** (grants; Postgres log) |
| 8 | Medium | **Public deletion form.** Nobody is told when a request arrives. The global cap (100 an hour) means 100 junk requests an hour block the form for real users (in-app deletion still works). The stored IP hash is an unsalted SHA-256, which is reversible for IPv4. The table has no retention. | **Demonstrated** (repo source) |
| 9 | Low-Med | **Failed invite emails use up the invite allowance.** The token row is written before the email is sent and the limits count token rows. Three provider failures lock that address for a week for that sender. | **Demonstrated** (repo source) |
| 10 | Low | **A completion email can be lost after a database hiccup.** If a store call throws after the event row is inserted, the row stays `pending`; a retry for the same run then gets `duplicateRun` and never sends. | **Demonstrated** (repo source) |
| 11 | Low | **Account deletion leaves some traces.** The account's own rows and files are fully removed: all 13 user tables cascade from `auth.users` (checked live) and the function deletes everything under `users/<uid>/`, including voice prompts. Not removed: web deletion-request rows; the person's address where *another* user added them as a contact; RevenueCat and Resend records. The store subscription is not cancelled. | **Demonstrated** (live foreign keys; source) |
| 12 | Low | **Raw error text reaches clients** from `delete-account`, `revenuecat-sync-entitlement` and `cleanup-proof-retention`. The RevenueCat functions log user ids. | **Demonstrated** |
| 13 | Low | **Wildcard CORS on every JSON function,** including the webhook. Not exploitable, because auth is a bearer token or shared secret, never a cookie. | **Demonstrated** |
| 14 | Low | **Limits are checked, then written.** Invite, send and deletion-form limits count rows and then insert, so parallel requests can overshoot by a few. | **Demonstrated** |
| 15 | Low | **Cleanup and account deletion list storage 100 items at a time, folder by folder.** Fine now; will hit the function time limit with thousands of users. | **Hypothesis** |
| 16 | Low | **Cleanup can remove a usage row in the seconds between the app reserving it and uploading,** if that happens at 02:00 UTC. The upload is then refused and the app retries. | **Hypothesis** |
| 17 | Low | **`verify-purchase` is deployed and unused.** If its Google secrets were ever set, it would write entitlement rows keyed differently from the RevenueCat ones. | **Demonstrated** |

What I checked and found sound in the repo versions: every JWT function verifies the user with `auth.getUser`, and the purchase-sync and completion-email functions also refuse anonymous users; the webhook and cleanup fail closed without their secret and compare in constant time; the webhook checks its secret before parsing the body, never returns 409, and its writes are idempotent upserts; email sends carry an idempotency key; link tokens are 256-bit, stored only as a hash, and POST-only; all redirects go to fixed pages; input lengths and types are validated at each public entry point; no secret is logged or returned.

### Deno tests

`deno test --allow-env --allow-net=127.0.0.1` from `supabase/functions`, Deno 1.45.2 (`C:\tmp\deno_extracted\deno.exe`), real remote imports (no import-map stub):

**65 passed, 0 failed.**

These tests use fakes and an in-memory store. They say the repo code does what it intends. They say **nothing** about production, which is running different code.

---

## (d) What I could not check, and why

- **Whether each secret exists.** The connector has no secrets endpoint, and the live functions' behaviour does not reveal it without calling them, which I did not do. The Vault secret `cleanup-proof-retention-header` exists by name.
- **Auth settings:** providers, SMTP, templates, anonymous sign-in toggle, rate limits, redirect URLs. No connector endpoint.
- **Anything that needs a write or a function call:** whether the new code works against production, whether emails deliver, whether the RLS reasoning above holds in practice. Read-only rule.
- **Logs older than about 48 hours.** The connector serves 24 hours per query; I sampled two windows.
- **Byte-for-byte equality** of `delete-account` and `verify-purchase`. Compared by reading.
- **RevenueCat, Resend, Google Play and Apple dashboards.** Outside Supabase. Risk 6 in particular needs a real RevenueCat payload.
- **Staging.** Paused; left alone as instructed.
- **Who ran the 3 Oct revoke.** The log shows the statement, not the person.

## Changes made on this branch

- This document.
- `supabase/DEPLOY_PLAN.md`: a labelled "Proposed" section at the end. The existing record is unchanged.
- `supabase/README.md`: two stale lines said entitlements are written by `verify-purchase`.
- Two comments in `supabase/functions/_shared/` named migration 016 where they meant 017.

No function logic and no migration was changed.
