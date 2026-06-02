# Pebble Auth Release Checklist

Use this before uploading any internal-test or production AAB. Auth is part of the purchase path, so a build should not ship unless every item here passes on the target Supabase project.

## Build Defines

- `APP_ENV=production`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_GOOGLE_WEB_CLIENT_ID`
- `REVENUECAT_ANDROID_API_KEY`
- `REVENUECAT_ENTITLEMENT_ID=personal_premium`

`build_production_aab.ps1` must fail if the Google web client id is missing. If Google sign-in is hidden in a release build, treat that build as invalid.

## Google Sign-In

- Supabase Auth Google provider is enabled.
- Google OAuth client is configured for the production Supabase project.
- Android OAuth setup includes the package name `com.vix.pebble_routines`.
- Android OAuth setup includes the Play App Signing SHA fingerprint used by internal testing and production.
- The release AAB shows `Continue with Google`.
- Google sign-in creates or finds the Supabase user and returns to Pebble.

## Email One-Time Code

Pebble's email UI expects a numeric one-time code, not a magic link.

- Supabase Auth email templates use `{{ .Token }}` for the code.
- Templates do not send users to a link-only `{{ .ConfirmationURL }}` flow.
- The signup template also shows the numeric code so first-time email users are not sent a dead confirmation link.
- The email copy says it is from Pebble and tells the user to enter the code in Pebble.
- The target Supabase project's Auth Site URL is not `localhost`.
- Allowed redirect URLs include `com.vix.pebble.routines://login-callback`.
- Test a brand-new email address and confirm the message contains a code.
- Test an existing email address and confirm the message contains a code.
- The code completes sign-in from the release app.

## Sender Setup

- Configure a Pebble-branded sender name.
- Configure custom SMTP or an approved sender domain before wider testing. Supabase requires the full SMTP admin email, host, port, user, and password before the sender name can be changed.
- Send a test email to Gmail, Outlook/Hotmail, and iCloud.
- Confirm the email does not land in junk for the main tester accounts.

## Broken-Build Symptoms

- Only `Use email instead` appears: the production build probably missed `SUPABASE_GOOGLE_WEB_CLIENT_ID`.
- Email says `Confirm your signup`: the Supabase template is still using the signup confirmation flow.
- Email opens `localhost:3000`: the target Supabase Auth Site URL is still set to localhost.
- Email contains only a link: the template is not compatible with Pebble's one-time-code screen.
