# Pebble legal URL publishing plan

Google Play needs two public web links:

- Privacy policy URL: a public, active, non-PDF page.
- Account deletion URL: a public page where users can request deletion without reinstalling the app.

This does not need to be a business website. It can be a tiny free static site.

## Recommended free setup

Use a separate public GitHub repository, for example:

`pebble-routines-legal`

Publish only these files from this project:

- `web/privacy.html`
- `web/terms.html`
- `web/delete-account.html`
- `web/legal.css`
- `web/favicon.png`

Do not publish app source code, keystore files, Supabase files, or environment values.

Expected free URLs would look like:

- `https://YOUR_GITHUB_USERNAME.github.io/pebble-routines-legal/privacy.html`
- `https://YOUR_GITHUB_USERNAME.github.io/pebble-routines-legal/delete-account.html`
- `https://YOUR_GITHUB_USERNAME.github.io/pebble-routines-legal/terms.html`

These URLs are not pretty, but they are enough for Play submission if they stay live and load without sign-in.

## GitHub Pages steps

1. Create a new public GitHub repo named `pebble-routines-legal`.
2. Add the five files listed above.
3. In GitHub, open `Settings > Pages`.
4. Set source to `Deploy from a branch`.
5. Select branch `main` and folder `/root`.
6. Save, then wait for GitHub to show the Pages URL.
7. Open the privacy and deletion URLs in an incognito/private browser window.
8. Put the privacy URL into the Google Play privacy policy field.
9. Put the deletion URL into the Google Play Data safety account deletion field.

## Deletion form endpoint

The deletion page currently posts to:

`/functions/v1/request-account-deletion`

That only works if the page is hosted on the same Supabase domain as the function.

For GitHub Pages, update the page before publishing so it posts to the full Supabase function URL:

`https://YOUR_PROJECT_REF.supabase.co/functions/v1/request-account-deletion`

The `request-account-deletion` Supabase Edge Function must be deployed before submitting the URL to Google Play.

## Lowest-friction fallback

If the web form endpoint is not ready yet, keep the deletion page live with:

- The deletion explanation.
- The plain-text support email.
- The in-app deletion path.

However, the form should be wired before public release because it is more robust than relying on `mailto:` only.

## What not to use

Avoid these for Play submission:

- A PDF privacy policy.
- A Google Doc that can look editable or require sign-in.
- A page behind login.
- A link that redirects through JavaScript only.
- A temporary link that may expire.
- A private repo file URL.

