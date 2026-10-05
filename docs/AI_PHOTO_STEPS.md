# AI photo descriptions

Updated 5 October 2026. Built for testing; **not deployed or enabled**.

## What it does

Signed-in Personal Premium users can enable descriptions for any of their
routines on this phone, one consent sheet per routine. The first five photo
steps of each qualify; the monthly allowance is the overall limit. An unticked consent box names
Anthropic and explains the photo, step-title and optional step-description transfer, retention and limitations. No
description can complete or fail a step. Failed descriptions leave the photo
and routine usable. Switching off remains available after Premium expires.

Any check step can have a **Description (optional)**, up to 500 characters,
entered in its expanded composer card and shown under its title in the player.
This works without photos, AI or Premium. Existing `photoPrompt` storage is
reused, including draft autosave, session recovery and backup; the historical
default "Take a photo" is hidden. No database migration is needed for this field.

The app makes a JPEG copy with a longest side of 600 pixels and no EXIF,
or 1,000 pixels when the step has a description to focus on visible detail.
`describe-proof-photo` checks its switches, authentication, Premium, consent,
image size and request allowance before calling Anthropic's Messages API with
`claude-sonnet-5-5`. It sends the photo, step title, optional step description and a fixed prompt. No account
details or routine name are added. The title is untrusted context: it guides
focus, but cannot establish what is present or whether the step is complete.
Titles over 1,000 characters are refused before allowance is reserved. Captions
aim for one sentence of 8-18 words naming the object and an obvious feature.
The broad-caption prompt omits precise handle/dial directions and background detail.
When a step description is supplied, a separate brief asks for one 12-25-word
observation of the requested visible feature, still capped at 35 words. It can
describe a lever position, dial marker or unlit display, but cannot establish
lock engagement, power state or completion. The description is an untrusted
hypothesis; an absent expected object must not be invented. The server bounds
this field to 500 characters before reserving allowance. A readable printed
"Off" label may be quoted as a label; claims that an appliance is off remain
blocked. There are no match/difference badges or automatic step completion.
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
- Personal Premium includes 200 attempts per account per UTC calendar month,
  shared across phones. AI settings show the remaining allowance. Exhaustion
  explains the limit without blocking photos or checks. Each reservation counts
  even if the provider fails. Only AI photo requests count, not ordinary ticks.
- Additional limits: 20 requests per account per rolling 24 hours; 5,000
  reservations across all accounts per UTC calendar month. Override with
  `AI_PHOTO_DAILY_LIMIT` and `AI_PHOTO_MONTHLY_REQUEST_BUDGET`.
- Reservations are atomic, deduplicated by photo ID and not refunded. The
  provider may retry once for 429/5xx, so this is a request cap, not a precise
  monetary cap. Keep the provider's own spending controls in place.
- Consent version: `2026-10-05.7`, in both Dart and TypeScript. Future changes
  to provider, consent wording or transferred data require a new version.
- AI tables contain consent and usage metadata only. No photo or description
  is written to those tables or logged by the Edge Function. Old request rows
  older than both the current UTC month and the last two days are pruned on
  the account's next new request, not by a daily deletion job. Inactive accounts
  can retain older rows until another request or account deletion.
- Routine selection is local to each phone. The server checks account consent
  and usage; it does not enforce one selected routine across multiple phones.

## Deployment

Follow the proposed AI section in `supabase/DEPLOY_PLAN.md`. The earlier backend
repairs and backup-consent gate are dependencies. Migration 021 creates the AI
tables; 022 aligns backup consent; 023 enforces the account monthly allowance
and exposes a service-only remaining-count RPC. None was applied here.
Do not release the new app against the old backup-consent gate.

Keep the API key in server secrets only. The local testing convention is
`.env.local`; personal photos belong in ignored `ai_test_photos/`. Neither goes
into GitHub, an app build or a chat. Jamie supplied a local provider key and
23 private test photos after the initial handover review.

## Remaining evidence before enabling

1. Review the revised Sonnet captions as a description aid. Real provider,
   prompt and misleading-title comparisons have run. Optional step descriptions
   now focus observations on a visible feature; five final detail cases were
   checked, including a misleading object expectation and deliberate blur.
2. On a real phone, check camera orientation, JPEG compression, consent,
   switching off, offline use, account switching, Premium expiry and history.
3. In staging, verify concurrent allowance requests against PostgreSQL. Local
   embedded PostgreSQL checks apply 021/023 and test permissions, the 100th/101st
   attempt, duplicate IDs, independent accounts, daily/global limits, lazy
   pruning and next-month reset date. They do not simulate concurrent sessions.
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
