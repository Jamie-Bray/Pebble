# Pebble Legal URL Publishing Plan

Google Play needs public, stable HTTPS links for privacy and account deletion.
Pebble uses the existing public site:

- Privacy policy: `https://pebbleroutines.com/privacy`
- Account deletion: `https://pebbleroutines.com/delete-account`
- Terms: `https://pebbleroutines.com/terms`
- Support: `https://pebbleroutines.com/support`

## Source Files

The source files for those pages live in `web/`:

- `web/privacy.html`
- `web/terms.html`
- `web/delete-account.html`
- `web/support.html`
- `web/legal.css`
- `web/site.js`
- `web/favicon.png`

Publish those files to `pebbleroutines.com` whenever product, privacy, retention,
account, backup, or subscription behaviour changes.

## Before Play Upload

1. Deploy the latest `web/` files to `pebbleroutines.com`.
2. Open each public URL in a private/incognito browser window.
3. Confirm the account deletion form posts successfully.
4. Put `https://pebbleroutines.com/privacy` in the Play Console privacy policy field.
5. Put `https://pebbleroutines.com/delete-account` in the Play Console account deletion field.
6. Build the app with:

```powershell
[Environment]::SetEnvironmentVariable(
  "PEBBLE_ACCOUNT_DELETION_URL",
  "https://pebbleroutines.com/delete-account",
  "User"
)
.\build_production_aab.ps1
```

## Current Behaviour To Keep Aligned

- Pebble works without an account.
- Free keeps recent local history and Pebble-owned proof-photo copies for 48 hours.
- Premium backup requires paid subscription, sign-in, and explicit backup consent.
- Premium recent history and proof-photo backup uses a rolling 21-day window.
- Pebble deletes only its own private app copies, never the user's camera roll or photo library.
- Signing out pauses backup without deleting local data.
- Account switching must not silently upload, merge, or wipe local data.

## What Not To Use

Avoid these for Play submission:

- PDF privacy policy.
- Google Doc or editable document.
- Page behind login.
- Temporary link.
- Private repo file URL.
- Public page that says different retention, account, or backup rules from the app.
