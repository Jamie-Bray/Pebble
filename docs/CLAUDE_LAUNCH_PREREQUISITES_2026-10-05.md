# Claude launch prerequisites completed — 5 October 2026

Jamie asked Codex to do the five owner setup tasks in your pasted message.
They are now complete. Resume your database/function deployment and signed
build work from this state, rather than asking Jamie to repeat them.

## Completed

1. **PR #21 is already merged** into `main`; Codex did not merge it again.
   `origin/main` was `3538694`, containing build 35 (`3a1b5d0`) and your any-routine
   AI/composer polish. No new app change or build-number increase was made here.
2. **Supabase CLI is logged in** on this Windows user account. The checkout is
   linked to production `yncgjqbjjzbinqkpukug`. `npx supabase projects list`
   and `npx supabase migration list --linked` succeeded; no database password
   needs to be supplied just to repeat that read. Production is active/healthy;
   staging remains inactive. No project was unpaused or upgraded.
3. **Signing files are in `C:\development\Pebble\android`:**
   `upload-keystore.jks` and `key.properties`, copied from
   `G:\My Drive\Pebble_Secrets_Backup`. The Drive originals were not changed.
   The local property `storeFile` now points to `upload-keystore.jks` relative
   to `android/`. The keystore SHA-256 matches the backup; keytool opens it with
   the copied store password. Both files are ignored by Git. Never print their
   contents or commit them. Play's expected certificate was not independently
   compared; this is the owner's existing backup, not a newly generated key.
4. **`ANTHROPIC_API_KEY` is set in production Supabase secrets.** It came from
   the existing ignored `.env.local`, with the value kept out of output/chat/Git.
   The live secret digest matches the local key. The temporary secret upload
   file was deleted. There is no need for Jamie to enter it again. No other
   server secret or AI feature switch was changed.
5. **Website published:** the site uses an existing Cloudflare static-assets
   Worker, **`pebbleroutines-site`**, manually uploaded through its dashboard.
   It is not a Pages project and is not connected to Git auto-deploy.
   Uploaded the current `web/` folder (20 files), preserving nested page paths.
   The existing route `pebbleroutines.com/*` serves it. Current version prefix
   `4aeb8d39`, previous version `316adc16`. No DNS/route/plan changes.

Public checks passed:
- `https://pebbleroutines.com/shared-alert/confirm/`: HTTP 200 and the new
  **Allow completion emails?** page. Checked rendering with your dummy fragment;
  did not press Allow or Decline or send mail.
- `https://pebbleroutines.com/privacy.html`: HTTP 200 with AI photo wording.
- `https://pebbleroutines.com/terms.html`: HTTP 200 with the current 200-attempt
  allowance from your merged change.

For later website updates: Cloudflare → Workers & Pages →
`pebbleroutines-site` → **New deployment** → **folder** → select the contents
of this repository's `web/` folder, review the root/nested file list, then Deploy.
The uploader strips the enclosing `web` directory, so `index.html` is at the
site root and `shared-alert/confirm/index.html` keeps its nested path.
The dashboard's old versions remain available for rollback.

## Validation and remaining work

`build_production_aab.ps1 -DryRun` passed in the current PowerShell host. All
required production settings are present in local user/process environment,
including the RevenueCat Android SDK key and Google sign-in client ID. Sentry
is present; the optional deletion URL is unset, so the script reports the app's
in-app deletion request path. Do not print the environment values. No AAB was
built or uploaded by Codex in this prerequisite task.

`flutter analyze` reported No issues found. Current CI-equivalent non-golden
Flutter suite: **479 passed**. Latest build-35 GitHub jobs never started: their
annotation says account payments failed or the spending limit needs increasing.
This is a GitHub billing block, not a new Dart/Android failure. Do not represent
that run as green. The known Windows Sandstone golden mismatch remains separate;
references were not regenerated. Incidental old-Flutter lockfile/platform changes
were restored. Ignored local logs: `artifacts/phone-build/release-analyze.log`
and `release-tests.log`.

The remote migration ledger still shows `001`–`011` plus
`20260610083720` and `20260714194247`. No migrations, migration repair, function
deployment, cleanup change, AI enablement or account-data modification was
performed by Codex. The previous live audit's applied grants/revokes are separate
from what the migration ledger records. Follow `supabase/MIGRATION_REPAIR_PLAN.md`
and `supabase/DEPLOY_PLAN.md`, and inspect before repairing or applying anything.
Your cleanup-secret prerequisite and ordered function deployment still matter.
The published page and provider secret now unblock your email/AI deployments.

Actual live preparation was recorded in `supabase/DEPLOY_PLAN.md`. Backend
deployment, smoke checks, AI enablement and signed build 35 are the next work
you described in the pasted exchange; they are not claimed complete here.

## Checkout and preservation

Codex's documentation branch is **`codex/live-launch-prep`**, created from
the latest `origin/main`, with identical app code to merged PR #21. The current
local checkout is on that branch. Its documentation is pushed to GitHub; check
the local status before switching branches so you preserve any later work.
Local ignored signing files and the CLI login remain available on this machine
after a branch switch. Do not include them in commits or copy them into reports.

The optional website ZIP and public-page screenshot are in ignored
`artifacts/phone-build/`; the upload used the actual `web/` folder, not an APK
or the private photo-evaluation directory. No secret/private photo was published.
Do not repeat the earlier staging APK suggestion: Jamie asked for the production
signed AAB for Google Play, with working backend features.
