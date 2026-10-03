# Release audit — 4 Oct 2026

Written by the Claude session that built the knowledge graph (`graphify-out/`).
Purpose: record what was checked, what was fixed, and what still needs a decision
before a store release.

## Health checks run

| Check | Result |
|---|---|
| `flutter analyze` | Clean. 2 info-level deprecation notes (`onReorder`), no errors or warnings. |
| `flutter test` | All 240 tests pass. |
| Knowledge graph | 5,222 nodes, 7,638 edges. Open `graphify-out/graph.html`. |

## Fixed in this session

1. **`GOOGLE_PLAY_RELEASE_CHECKLIST.md`** — the checklist said `WRITE_EXTERNAL_STORAGE`
   was removed. It is still declared in `android/app/src/main/AndroidManifest.xml`
   (capped at Android 9 and below, for Save a copy to Photos). Checklist line corrected.
   This matters because the Play Console permission declaration must match the manifest.
2. **`RETROSPECTIVE_PRD_GOOGLE_PLAY_PREMIUM_READINESS.md`** — added a "superseded in part"
   note at the top. It said the app can never unlock Premium locally; since the move to
   RevenueCat the app does unlock local Premium from RevenueCat, and only cloud features
   wait for the Supabase server check. `REVENUECAT_BILLING_SETUP.md` is the current rule.
3. **`test/features/theme/sandstone_theme_golden_test.dart`** — the test's own preview row
   overflowed by 46px and the overflow stripes were baked into the golden image. Wrapped
   the label in `Flexible` and regenerated `goldens/sandstone_vs_highnoon.png`. Test-only;
   no app code changed.

## Needs a decision (not changed)

1. **Uncommitted work — highest risk.** The last git commit is 18 Jul 2026 (build 31).
   `pubspec.yaml` is at build 33, and about 55 files are modified but not committed.
   If this laptop is lost, that work is gone, the same way builds 27/28 were lost.
   Recommended: commit and push now.
2. **Support email domain.** `web/index.html` (lines 53, 232) uses
   `support@pebbleroutines.com`. Every other page, the app, and the legal docs use
   `support@pebbleroutines.app`. The website itself is on `.com`. Only one of these
   inboxes may exist. Decide which is real, then make them all match.
3. **`supabase/functions/verify-purchase`** — no longer called from the app (RevenueCat
   replaced it). Probably dead. Check whether it is still deployed, then delete or keep
   deliberately.
4. **Proof retention default.** Migration `003` sets 21 days and the cleanup function
   enforces 21 days. `supabase/cleanup/README.md` warns production may still carry an
   older 30-day default. Not checked against the live database.
5. **Which store.** The repo is set up for Google Play (checklists, billing, `.aab` build).
   An Apple App Store release is a separate piece of work: nothing here covers
   App Store Connect, iOS signing, or iOS review.

## Graph questions answered

- **Who decides Premium?** RevenueCat for local Premium UI; Supabase
  (`personal_entitlements`, `EntitlementSource.serverVerified`) for cloud backup, restore
  and proof upload. Code: `revenuecat_purchase_repository.dart` (`_applyVerifiedEntitlement`),
  `cloud_access_provider.dart`, `subscription_provider.dart`.
- **Why is `SupabaseClient` connected to everything?** It is the single cloud handle, used
  by 10 files through one provider. Expected, not a problem.
- **`AppEnvironment` / `AppRuntimeConfig`.** Built from `APP_ENV` in `main.dart` (default
  `staging`). Drives Sentry setup, router debug logging, a production-only startup branch,
  the subscription production check, and the account-deletion URL.
- **Split the Drift database?** No. `local_db.dart` is 566 lines and 7 tables; the rest is
  generated code.
- **`_` nodes in the graph.** Extractor noise from Dart's throwaway parameter name. Ignore.

## Not covered by this audit

- No manual testing on a device. Passing tests do not prove the purchase, backup, camera
  or notification flows work on a real release build.
- The 16 SQL migrations were not parsed into the graph (missing parser).
- 141 dependencies have newer versions. Not upgraded; upgrading before a release adds risk.
- The live Supabase projects and the live website were not inspected.
