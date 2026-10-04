# Owner Notes: Store and Legal Launch Pack

Last updated: 5 October 2026

Decisions and facts only you can confirm, gathered while preparing
`web/privacy.html`, `web/terms.html` and the files in `docs/store/`. Nothing
in `lib/`, `ios/`, `android/` or `supabase/` was changed.

## 1. Email domain: decided, `@pebbleroutines.com`

Decided on 4 October 2026. The owner owns `pebbleroutines.com`, so every contact
address in the app, website, store listings and docs now uses
`support@pebbleroutines.com` and `privacy@pebbleroutines.com`. Changing the
in-app addresses (`lib/core/config/legal_links.dart`) needs a new build.

Still to do (owner):

- Set up free email forwarding so `support@` and `privacy@pebbleroutines.com`
  arrive in the Pebble Gmail (for example ImprovMX, or Cloudflare Email
  Routing if the domain's DNS is on Cloudflare). Send a test email to each.
- Use the same addresses in the Play Console and App Store Connect support
  fields.
- Set the Supabase secret `SHARED_ALERT_FROM_EMAIL` (for example
  `Pebble Routines <alerts@pebbleroutines.com>`) and verify the domain in
  Resend (SPF, DKIM, DMARC). See `COMPLETION_EMAIL_REVIEW.md`.
- If you set up custom SMTP for sign-in codes, use the same domain.

## 2. Legal details to fill in

These used to be `<!-- OWNER TODO -->` comments inside `web/privacy.html`.
Anyone can read HTML comments with "view source", so they were removed from
the page on 5 October 2026 and are kept here. The place each one applies to is
named so it can be found again.

Moved from the comment at the top of `web/privacy.html`:

- Confirm the email domain for privacy@ and support@ (done, see section 1).
- Add a business correspondence address if one is needed for your target
  markets. Do not publish a home address.
- Add your ICO registration number once the data protection fee is paid, or
  record why you are exempt.
- Accept each provider's data processing terms (Supabase, RevenueCat, Sentry,
  Resend) and confirm the transfer safeguard named in the "International
  transfers" section.
- Confirm which service sends sign-in code emails (Supabase default sender or
  custom SMTP) and name it in "Service providers" if it is a separate provider.
- Confirm the Sentry data region and the Resend sending region.

Moved from the "Crash reports" section: the note asked for Sentry print
breadcrumbs to be turned off and the sentence "That trail can include internal
technical identifiers" to be replaced. Both are done:
`lib/core/monitoring/crash_reporting.dart` sets
`enablePrintBreadcrumbs = false`, and the page now says reports don't include
the account ID but do include a random ID for the app installation.

Moved from the "Retention" table, above the row "Backed-up routines,
reminders, and text history records": cloud `routine_runs` and
`routine_sessions` rows are not pruned at 21 days (`cleanup-proof-retention`
only removes proof photos). If you add server-side 21-day clean-up for history
records, update that row to match. See also item 2 in section 3.

Moved from the "Owner and contact" section: add a business correspondence
address there if required (PO Box or similar, not a home address), and the ICO
registration number once the data protection fee is paid.

The same points as a list:

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

1. ~~Crash reports can contain the account ID.~~ Fixed:
   `lib/core/monitoring/crash_reporting.dart` sets
   `options.enablePrintBreadcrumbs = false`, the privacy policy's "Crash
   reports" section was corrected on 5 October 2026, and Apple's label answers
   "Not linked". Native crash reports still carry Sentry's random installation
   ID, which the policy now says.
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
6. **Voice prompts are now backed up** when Premium cloud backup is on
   (`lib/features/sync/guidance_audio_cloud_backup.dart`). They are kept until
   the recording is replaced or removed, the routine is deleted or the account
   is deleted; the 21-day clean-up skips them. On 5 October 2026 the privacy
   policy, in-app summary, both store forms (Audio: Yes), the processor map and
   the backup consent sentence were corrected to say so. The new consent
   sentence needs a database step before it works: see "Proposed (backup
   consent text, 5 Oct 2026)" in `supabase/DEPLOY_PLAN.md`.
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
9. ~~No `ios/Runner/PrivacyInfo.xcprivacy`~~ Added; it matches `APP_PRIVACY_LABELS.md`.
10. **The in-app privacy summary** (`legal_about_screen.dart`) does not name
    providers. It links to the full policy, which is fine. Keep it consistent
    when you next change it.
11. **The starter and template "Everyday departure check" differ** (4 steps
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
