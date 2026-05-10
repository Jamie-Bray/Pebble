## Legal Publication Checks

The legal pages no longer contain bracket placeholders, but several public
details must be confirmed before the pages are hosted or submitted to an app
store.

### Public details currently used

- Product name: `Pebble Routines`
- Developer/controller label: `Jamie Bray trading as Pebble`
- Country: `Scotland, United Kingdom`
- Governing law: `the laws of Scotland`
- Courts: `the courts of Scotland`
- Privacy email: `privacy@pebbleroutines.app`
- Support email: `support@pebbleroutines.app`

### Must be true before publication

- The `privacy@pebbleroutines.app` inbox exists and is monitored.
- The `support@pebbleroutines.app` inbox exists and is monitored.
- The domain used for the legal pages is owned or controlled by Pebble.
- The account-deletion URL is stable, public, HTTPS, and reachable without the app.
- The deletion request form posts to a deployed `request-account-deletion` Edge Function or equivalent backend, not just a `mailto:` link.
- The Play Console support email, privacy email, and deletion page match these pages.
- If the developer/controller label should be a limited company or different legal entity, update every legal page before launch.
- If a full postal address must be shown for a target market, add the real business correspondence address before launch.
- Decide whether to use a PO Box or other public correspondence address before launch; do not publish a home address casually.
- Check whether Pebble needs to pay the ICO data protection fee or document an exemption before launch.

### High-risk product items to keep aligned

- Personal Premium proof-photo retention: 30 days.
- Pebble Household proof-photo retention: 14 days.
- Pebble Workspace proof-photo retention: 60 days, but only with separate business terms.
- Growth/Enterprise retention: plan or order-form specific.
- Cloud Vault must mean short-term reassurance backup, not permanent archive or evidence storage.
- Location triggers are not in the current Android build. If launched later, update the permission flow, privacy policy, and store privacy forms before release.
- Biometric app lock is not in the current dependency set. If launched later, update the policy and app-store disclosures before release.
- Business Workspace/Growth/Enterprise should not launch on the consumer Terms alone. Create Business Terms and a Data Processing Addendum first.
- Cloud backup of sensitive user-added content now has an in-app consent gate and Supabase consent record; confirm the deployed database includes migration `005_cloud_backup_consent_and_deletion_requests.sql`.
- Guidance-audio files currently stay local. If audio-file cloud backup is introduced, update app UI, legal pages, store forms, and processor map first.

### Store privacy form alignment

Do not mark data as "not collected" just because collection is conditional on
sign-in or Premium. If a released build can collect it for any user, disclose it
in the relevant store forms.

Likely categories include:

- Email address
- User/account ID
- Purchase history or subscription status
- User content, including routines and routine history
- Photos if proof-photo cloud backup is enabled
- Photo/media library access because users can choose existing proof photos
- Audio metadata, and audio files if audio backup is introduced later
- App interactions or diagnostics if logging, crash reporting, or analytics are added later
- Device identifiers if later used for security, entitlement checks, diagnostics, analytics, or crash reporting

### Supporting audit docs

- `LEGAL_PROCESSOR_MAP.md` maps processors, SDKs, permissions, and data categories from the current codebase.
- `COPY_RISK_SCAN.md` lists softened copy and phrases to avoid in store listings, onboarding, paywalls, screenshots, and ads.
