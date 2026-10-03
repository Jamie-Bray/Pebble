# Owner Notes: Store and Legal Launch Pack

Last updated: 3 October 2026

Decisions and facts only you can confirm, gathered while preparing
`web/privacy.html`, `web/terms.html` and the files in `docs/store/`. Nothing
in `lib/`, `ios/`, `android/` or `supabase/` was changed.

## 1. Email domain: `.com` site, `.app` inboxes

The website and every URL use **pebbleroutines.com**. Every contact email uses
**@pebbleroutines.app**. No `@pebbleroutines.com` address appears anywhere in
the repo. Nothing was changed. Confirm which domain you own and can receive
mail on, then update every line below together.

| File | Line | Address |
| --- | --- | --- |
| `web/privacy.html` | 53, 201, 418 | privacy@pebbleroutines.app |
| `web/privacy.html` | 420 | support@pebbleroutines.app |
| `web/privacy.html` | 36 | (owner TODO comment that mentions the domain) |
| `web/terms.html` | 44, 217 | support@pebbleroutines.app |
| `web/terms.html` | 219 | privacy@pebbleroutines.app |
| `web/support.html` | 42, 47 | support@pebbleroutines.app |
| `web/support.html` | 52 | privacy@pebbleroutines.app |
| `web/delete-account.html` | 20, 21, 44, 93, 150, 193 | support@pebbleroutines.app |
| `web/delete-account.html` | 148 | privacy@pebbleroutines.app |
| `web/index.html` | 171 | support@pebbleroutines.app |
| `lib/features/settings/ui/legal_about_screen.dart` | 91, 134 | privacy@pebbleroutines.app (in-app; needs a new build to change) |
| `lib/features/settings/ui/legal_about_screen.dart` | 93, 136, 171, 322 | support@pebbleroutines.app (in-app) |
| `LEGAL_PUBLICATION_CHECKS.md` | 14, 19 | privacy@pebbleroutines.app |
| `LEGAL_PUBLICATION_CHECKS.md` | 15, 20 | support@pebbleroutines.app |
| `GOOGLE_PLAY_RELEASE_CHECKLIST.md` | 45 | privacy@ and support@pebbleroutines.app |
| `LAUNCH_READINESS_AUDIT.md` | 69 | mentions @pebbleroutines.app |
| `docs/store/GOOGLE_PLAY_LISTING.md` | 142, 169 | support@pebbleroutines.app |
| `docs/store/APP_STORE_LISTING.md` | 240 | support@pebbleroutines.app (App Review notes) |

Not in the repo, but they must use a domain you own and have verified with
Resend:

- Supabase secret `SHARED_ALERT_FROM_EMAIL` (and optional
  `SHARED_ALERT_REPLY_TO_EMAIL`): the sender of completion emails.
- The Supabase Auth sender address, if you set up custom SMTP for sign-in
  codes.
- The Play Console and App Store Connect support email fields.

To find the lines again: `grep -rn "pebbleroutines\.app" --exclude-dir=.git .`

## 2. Legal details to fill in

These are marked with `<!-- OWNER TODO -->` comments in `web/privacy.html`.
They are HTML comments, so they will not show on the published page.

- **Postal address.** Add a business correspondence address (PO Box or
  similar, not your home) if one is needed for your markets. Currently none is
  shown.
- **ICO.** Pay the data protection fee and add the registration number, or
  record why you are exempt.
- **Processor terms.** Accept the data processing terms for Supabase,
  RevenueCat, Sentry and Resend. Confirm each one includes the UK
  International Data Transfer Addendum or SCCs, which is what the
  "International transfers" section relies on.
- **Sign-in code email sender.** If you set up custom SMTP (for example
  Resend, as `SUPABASE_LIVE_AUDIT.md` suggests), the policy already covers it
  under "Email and support tools" and Resend. If you use another provider, name
  it.
- **Sentry data region** (US or EU) and **Resend sending region.** The policy
  says USA for both. Change it if you chose EU.
- **Support inbox provider** (Google Workspace, Fastmail, iCloud and so on).
  It is covered generically as "email and support tools".
- **Controller name.** The pages say "Jamie Bray trading as Pebble". If you
  form a company, update privacy, terms, and the App Store copyright line.
- **Prices and App Store product IDs** (`APP_STORE_LISTING.md`).

## 3. Accuracy problems found in code

The disclosures were written to match the code as it is now. These are places
where the code, the public copy, or both should change before launch.

1. **Crash reports can contain the account ID.** `sentry_flutter` records
   `debugPrint` output as breadcrumbs by default, and release builds print
   lines containing the Supabase account ID and RevenueCat app user ID
   (`revenuecat_purchase_repository.dart`, `subscription_provider.dart`). Fix:
   `options.enablePrintBreadcrumbs = false` in
   `lib/core/monitoring/crash_reporting.dart`. Then update the sentence marked
   in the privacy policy's "Crash reports" section, and answer "Not linked" on
   Apple's label.
2. **Cloud history is not pruned at 21 days.** `cleanup-proof-retention` only
   deletes proof photos. Local pruning (`routine_run_repository.dart`,
   `cloud_sync_coordinator.dart`) deletes local rows only, so backed-up
   `routine_runs` and `routine_sessions` stay in Supabase until the account is
   deleted. The privacy policy now says this honestly in its own row. If you
   want cloud history to follow the 21-day window, add server-side cleanup and
   merge the two rows.
3. **Completion email records have no retention limit.** `shared_alert_events`
   (routine name, time, steps, delivery status) and removed contacts (status
   `disabled`, email kept) stay until the account is deleted. The policy says
   so. Consider deleting events after 21 to 90 days and hard-deleting removed
   contacts.
4. **Email-link scanners can accept invites.** The live `shared-alert-accept`
   function accepts on a plain GET (`SUPABASE_LIVE_AUDIT.md` item 3), so a mail
   scanner can accept for someone. The privacy policy says emails go out only
   after the contact accepts. Deploy the repo version, which needs a POST.
5. **"Trusted contact" wording in emails.** The repo's email templates say "A
   trusted contact update from Pebble". `COPY_GUIDELINES.md` lists "trusted
   contacts" as copy to avoid. The live templates are newer than git (see the
   live audit), so check both versions.
6. **Voice prompts are not backed up,** but the paywall says backup is "safe if
   you reinstall or change phone" (`LAUNCH_READINESS_AUDIT.md` item 8). The
   store copy here does not promise audio backup.
7. **The Google sign-in name.** `google_sign_in` uses the default options, so
   Google's token includes name and picture, and Supabase stores them. That is
   why Name is declared on both store forms. Check a Google user in Supabase
   Auth. If you would rather not hold the name, you can clear it, but it has to
   be disclosed while it is stored.
8. **RevenueCat keeps the customer after Pebble account deletion.**
   `delete-account` removes Supabase data only. Consider calling RevenueCat's
   delete-subscriber API from `delete-account`, or handle it by hand when you
   process deletions. The privacy policy says RevenueCat and the stores keep
   their own records.
9. **No `ios/Runner/PrivacyInfo.xcprivacy`** (see `APP_PRIVACY_LABELS.md`).
10. **The in-app privacy summary** (`legal_about_screen.dart`) does not name
    providers. It links to the full policy, which is fine. Keep it consistent
    when you next change it.
11. **The starter and template "Everyday Departure Check" differ** (4 steps
    against 10, `VISUAL_WALKTHROUGH.md`). The store copy describes the template
    version (hair tools, stove and oven, toaster, sink, heaters, windows and
    doors).

## 4. Copy decisions taken

- No "OCD", "anxiety", "worry" or "peace of mind" in titles, descriptions,
  keywords, captions or hashtags. The reasons are in each listing file. An
  optional neutral "peace of mind" line is offered in
  `GOOGLE_PLAY_LISTING.md` if you want it indexed on Play.
- Each store description ends with a short "What Pebble is, and is not"
  section pointing to a doctor or qualified professional, as the copy
  guidelines ask.
- Play target audience: 18+ only, to stay out of the Families policy.

## 5. Re-checking limits

`python3 docs/store/check_limits.py` counts every limited field in these files
and checks the App Store keyword rules. Run it after any copy edit.
