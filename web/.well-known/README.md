# Opening "Add to Pebble" links straight in the app

Shared routines link to `https://pebbleroutines.com/r#…`. Without the files
in this folder the link opens the web page (`web/r/index.html`), which shows
the steps and an "Open in Pebble" button. That already works on both phones.

These two files make the link skip the web page and open Pebble directly.
Upload both with the rest of `web/`, so they're served at
`https://pebbleroutines.com/.well-known/<name>` (no redirect, HTTPS).

## Android: `assetlinks.json`

1. Play Console → Pebble → Test and release → App integrity → App signing.
2. Copy the **SHA-256 certificate fingerprint** of the *App signing key*.
3. Replace `REPLACE_WITH_PLAY_APP_SIGNING_SHA256` with it.
4. Serve it as `application/json`. Android checks it when the app is
   installed or updated, so reinstall to test.

## iPhone: `apple-app-site-association`

1. Replace `REPLACE_WITH_TEAM_ID` with the Apple Developer Team ID
   (developer.apple.com → Membership).
2. Serve it as `application/json`, with no `.json` extension.
3. Turn on **Associated Domains** for `com.vix.pebbleroutines` in the Apple
   Developer portal, then add
   `<key>com.apple.developer.associated-domains</key><array><string>applinks:pebbleroutines.com</string></array>`
   to `ios/Runner/Runner.entitlements`. Do this only after the portal step,
   or iOS signing fails.

Until these are done, nothing breaks: links open the web page instead.
