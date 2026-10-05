# AI photo descriptions

Updated 5 October 2026. Built for testing; **not deployed or enabled**.

## What it does

Signed-in Personal Premium users can enable descriptions for one routine on
this phone. Its first five photo steps qualify. An unticked consent box names
Anthropic and explains the photo and step-title transfer, retention and limitations. No
description can complete or fail a step. Failed descriptions leave the photo
and routine usable. Switching off remains available after Premium expires.

The app makes a JPEG copy with a longest side of 1,000 pixels and no EXIF.
`describe-proof-photo` checks its switches, authentication, Premium, consent,
image size and request allowance before calling Anthropic's Messages API with
`claude-haiku-4-5`. It sends the photo, step title and a fixed prompt. No account
details or routine name are added. The title is untrusted context: it guides
focus, but cannot establish what is present or whether the step is complete.
Titles over 1,000 characters are refused before allowance is reserved.
Structured JSON prevents malformed quotation marks. The response parser rejects malformed replies, uncertainty
marked `cannot_tell`, incomplete sentences, over 35 words, excessive length and listed verdict words. This filter
reduces unwanted conclusions; it cannot guarantee factual accuracy or catch
every possible paraphrase. See the real-photo evaluation in
`docs/review/AI_PHOTO_EVALUATION_2026-10-05.md` before enabling.

Descriptions are saved with their photos in local history and included in
normal cloud backup when enabled. Completion emails include up to five only
after a separate affirmative choice. The server checks current AI consent and
filters the text again; email HTML escapes it. Photos are never emailed.

## Controls and limits

- Both `AI_PHOTO_ENABLED=true` and `ai_photo_settings.paused=false` are needed.
  Missing configuration or a failed settings lookup leaves the feature off.
- Default allowance: 20 requests per account per rolling 24 hours; 5,000
  reservations across all accounts per UTC calendar month. Override with
  `AI_PHOTO_DAILY_LIMIT` and `AI_PHOTO_MONTHLY_REQUEST_BUDGET`.
- Reservations are atomic, deduplicated by photo ID and not refunded. The
  provider may retry once for 429/5xx, so this is a request cap, not a precise
  monetary cap. Keep the provider's own spending controls in place.
- Consent version: `2026-10-05.3`, in both Dart and TypeScript. Future changes
  to provider, consent wording or transferred data require a new version.
- AI tables contain consent and usage metadata only. No photo or description
  is written to those tables or logged by the Edge Function. Old request rows
  are pruned on the account's next request, not by a daily deletion job.
- Routine selection is local to each phone. The server checks account consent
  and usage; it does not enforce one selected routine across multiple phones.

## Deployment

Follow the proposed AI section in `supabase/DEPLOY_PLAN.md`. The earlier backend
repairs and backup-consent gate are dependencies. Migration 021 creates the AI
tables; 022 aligns backup consent. Neither was applied during this handover.
Do not release the new app against the old backup-consent gate.

Keep the API key in server secrets only. The local testing convention is
`.env.local`; personal photos belong in ignored `ai_test_photos/`. Neither goes
into GitHub, an app build or a chat. Jamie supplied a local provider key and
23 private test photos after the initial handover review.

## Remaining evidence before enabling

1. Continue accuracy evaluation, especially small dial markers, handle
   directions and mismatched step titles. Real provider tests have now run;
   useful object descriptions still do not establish a reliable state check.
2. On a real phone, check camera orientation, JPEG compression, consent,
   switching off, offline use, account switching, Premium expiry and history.
3. In staging, verify migration permissions and concurrent allowance requests
   against PostgreSQL; the server tests use stand-in stores.
4. Check a real accepted contact receives descriptions only when chosen, and
   that ordinary completion emails still work with AI switched off.
5. Publish the updated privacy page and complete the matching store disclosures
   before enabling AI. Store health-data declarations and medical-device
   classification are different questions; do not infer either from the other.

Automated checks cover consent, local account separation, step selection,
description persistence, email payloads, the off switch, provider errors and
server refusal paths. They do not replace the checks above.

## Handover review results (5 October 2026)

Claude's seven unfinished disclosure/copy files were copied from its original
worktree without modifying that worktree. Codex's follow-up is on
`codex/ai-photo-finish`, based on AI commit `01750f8`.

Fixed: Premium expiry blocking the consent-off control; confirmation content
overflowing short screens; an unconditional 30-day deletion promise; and a
privacy table claiming usage records were always deleted after two days.
Prepared the missing migration 022 and deployment instructions. Existing
tagline, paywall headline and approved art direction were preserved.

Verification: Flutter analysis clean; 34 focused AI tests passed; 85 Deno server
tests passed; 14 AI walkthrough scenarios passed with no layout warnings.
Screenshots were inspected at small size and 1.6x text. The full Flutter suite
has the previously documented Windows Sandstone golden mismatch (0.41%); its
reference image was not regenerated. CI treats golden comparisons as
informational, so a green CI run is not proof that this image comparison passed.

The original AI branch's Android debug build also passed on GitHub. Follow-up
branch CI is separate evidence and must be checked before merging. No live
backend deployment or real-phone test was performed. Subsequent real provider
evaluation and context changes are recorded in the evaluation report.
