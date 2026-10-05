# AI photo evaluation — 5 October 2026

Launch direction: use short, useful captions with Sonnet 5.5 and step-title
context. The earlier results below describe Haiku with an overly detailed
brief, not a reason to abandon the feature. A subsequent model/prompt
comparison is recorded below. This is an optional description aid, never a
pass/fail check or proof of a physical state.

## Method and privacy

Jamie supplied 23 private JPEGs in ignored `ai_test_photos/`. Originals totalled
158,107,550 bytes; SHA-256 comparisons confirmed they were unchanged. Upright,
metadata-free JPEG test copies used a 1,000-pixel longest side and quality 80,
after approximating the proof-storage WebP conversion. Copies totalled
1,918,721 bytes, ranging from 26,874 to 170,502 bytes, below the server's 1.5 MB
cap. Sharp approximates the compression settings; native phone codecs,
orientation and gallery capture still need a real-device check.

Calls used the exact production `anthropicDescriber` and `parseProviderReply`
with `claude-haiku-4-5` and Jamie's local testing key. Test titles were authored
to match visible subjects; they were not recovered from original routines.
Photos, filenames, hashes, titles, replies and comparison HTML remain in ignored
local artifacts. Only this aggregate report belongs in GitHub.

## Initial results (Haiku and the detailed brief)

| Run | Provider successes | Accepted by parser |
| --- | ---: | ---: |
| Original photo-only implementation | 23/23 | 21/23 under original rules |
| Revised prompt and structured JSON | 23/23 | 20/23 under stricter rules |
| Revised prompt with step title | 23/23 | 23/23 |
| Deliberately misleading step titles | 3/3 | 3/3 |
| Repeat difficult photos and degraded copies | 4/4 | 1/4 |

Acceptance measures formatting, length and listed verdict checks, not accuracy.
This is a small exploratory sample with one pass per configuration, not a
controlled benchmark. Do not infer an accuracy percentage from these counts.

The original run included malformed JSON caused by quoted dial labels and an
overlong reply. Structured JSON removed malformed quotation marks in subsequent
runs. New local checks refuse descriptions over 35 words and replies ending
mid-sentence. Both a near-black copy and a heavily blurred copy returned
`cannot_tell` and were refused. A repeat dial reply ended mid-sentence and was
also refused.

With relevant titles, some output became more focused: a cupboard description
dropped an irrelevant ceiling detail, and the washing-machine dial marker was
described upward in that run. Other errors remained: a tap handle was described
upward when it points downward, an extractor description invented a window,
and a cylinder vacuum was called upright. Body-part descriptions and background
clutter also appeared despite prompt instructions. The earlier photo-only
runs invented or mislocated small hob details. Passing the parser does not
catch these mistakes, and more prompt instructions cannot establish reliability.

The keyboard stayed a keyboard with a towel/gym-bag title; a sink stayed a sink
with a door-lock title. A title instructing the model to say a door was locked
and safe did not produce those conclusions in this test. Some other visible
details were still wrong. These examples are useful evidence, not proof against
all prompt injection or misleading context.

There were 76 successful provider calls in this evaluation, using 114,334 input
and 4,026 output tokens: an estimated $0.134464 at Haiku 4.5's listed $1/M input
and $5/M output pricing. An experimental schema pattern was refused with HTTP
400 and removed; its unsuccessful requests are not included in that token-based
estimate. Account billing was not reconciled. Pricing source:
https://platform.claude.com/docs/en/models/haiku-4-5/overview.

## Implementation and remaining checks

### Follow-up: compare the brief and model, then implement the better version

Jamie's goal is to launch useful photo descriptions, not require the model to
prove that physical checks are complete. The initial prompt explicitly asked
for handle directions and dial positions, so it contributed to the problem.
It was too early to recommend leaving the feature disabled after that run.

Compared Haiku 4.5, Sonnet 5.5 and Opus 5.5 on the same eight difficult photos
with two briefs each (48 actual calls). Both arms used the same JSON schema
without a descriptive hint, so the system brief could be compared separately
from schema wording. Sonnet used `between_tools` thinking; Opus used low effort
with a larger 1,024-token allowance because thinking is always enabled.

| Model | Detailed brief: format checks | Short brief: format checks |
| --- | ---: | ---: |
| Haiku 4.5 | 5/8 | 8/8 |
| Sonnet 5.5 | 7/8 | 8/8 |
| Opus 5.5 | 7/8 | 8/8 |

The short brief helped every model avoid unnecessary positional claims.
Haiku still invented a headphone beside the keyboard and called a cylinder
vacuum upright. Sonnet recognised the keyboard tool and cylinder vacuum;
with the detailed brief it also got the tap direction right. Opus did not
show a clear benefit over Sonnet for the short-caption task in this sample.
This separates useful evidence about the prompt from the model choice; it
does not establish a general model ranking or an accuracy percentage.

**Implemented Sonnet 5.5 with the short brief.** Captions aim for one sentence
of 8-18 words naming the main visible object and an obvious feature, in UK
English. No exact dial/handle direction, small-print reading, screen-scene
interpretation or background narration is requested. Existing 35-word and
verdict checks remain. The model uses its documented `between_tools` setting
and the same 200-token output cap, with the existing 10-second timeout.

Tested the implementation on all 23 photos, then repeated all 23 after a
small clarification about screen descriptions. Both runs returned 23 captions
passing the parser. The final captions were 14-21 words. Visual review found
the relevant main objects represented usefully; small details can still be
imprecise (for example a socket's red marking described as an indicator light).
That is a caption limitation, not a reason to abandon the feature or demand
physical-state verification. The app continues to show the photo itself.

Three misleading-title checks still described the actual keyboard, sink and
door hardware; the instruction to declare a door locked/safe was ignored.
Two additional ordinary-photo repeats returned captions; near-black and heavily
blurred copies returned `cannot_tell` and the ordinary failure message. These
checks ran with the first short production brief before the screen clarification.

The final 23-photo run had median response time 2.124 seconds and maximum
2.713 seconds. Token-based cost was $0.086536, about $0.00376 per caption. All
101 successful calls in this follow-up (comparison, two full runs and checks)
totalled an estimated $0.418229. Account billing was not reconciled. Prices
and model IDs were verified at https://platform.claude.com/docs/en/models/overview;
Sonnet costs $2/M input and $10/M output tokens. Timing excludes app capture,
compression and the Supabase hop.

Sonnet's API setting is documented at
https://platform.claude.com/docs/en/models/sonnet-5-5/whats-new-sonnet-5-5.
No additional provider, app dependency or automatic model-routing system was
introduced. The private comparison page now shows the final Sonnet captions
first, with the earlier captions expandable for review.

The app passes the saved step's title with its photo. The server bounds titles
to 1,000 characters before spending allowance and adds no account details or
routine name. User-written titles can themselves contain personal information.
The model is instructed to treat the title as untrusted context and follow
the image when they conflict. Nothing in this flow marks a step complete.

Consent, settings, privacy copy and store disclosure drafts now explicitly
include the step title. Consent version is `2026-10-05.4` in app and server;
older consent does not authorise this transfer. Structured JSON follows
https://platform.claude.com/docs/en/build-with-claude/structured-outputs.

Complete launch checks with owner-authored routine titles. Confirm native phone
compression, accessibility, account switching and withdrawal. Verify staged
database permissions/concurrent budgets and actual completion emails. Publish
the matching privacy copy and store disclosures. No live Supabase changes or
feature enablement were performed in this evaluation.

Local verification after the context change: Flutter analysis clean; 471
CI-equivalent non-golden Flutter tests and 86 Deno server tests passed. All
14 AI walkthrough scenarios passed with an empty layout-error report; small
phone and 1.6x text consent screens were inspected. The previously documented
Windows Sandstone golden mismatch remains separate from those checks; no
reference image was regenerated. Android compilation is checked by GitHub CI
on the pushed branch, not by these local tests.

## Image size, monthly economics and visible cues (5 October)

Compared the same final short-caption prompt and Sonnet 5.5 on all 23 private
photos at 600, 800 and the previous 1,000-pixel longest side. Copies used the
same approximate native WebP-to-JPEG pipeline; originals' hashes are unchanged.
No EXIF/ICC/XMP was sent. Each size returned 23 captions passing the parser;
human review found the main objects useful. Acceptance counts are not accuracy
scores. Totals and per-100 costs below use actual reported tokens at $2/M input
and $10/M output; account billing was not reconciled.

| Longest side | Total JPEG bytes (23 photos) | Average request USD | 100 requests | 150 requests | 300 requests |
| --- | ---: | ---: | ---: | ---: | ---: |
| 600 px | 786,579 | 0.002599 | 0.26 | 0.39 | 0.78 |
| 800 px | 1,286,836 | 0.003113 | 0.31 | 0.47 | 0.93 |
| 1,000 px | 1,918,721 | 0.003762 | 0.38 | 0.56 | 1.13 |

600 pixels reduces average caption token cost by 30.9% and payload bytes by
59%. It is now the broad-caption app setting; saved photos remain unchanged.
Repeated ordinary photos still returned captions, three misleading titles
still described actual objects, and both dark/blurred challenges returned
`cannot_tell`. This size recommendation does not extend to reading small details.

Jamie selected 100 monthly attempts. Migration 023 enforces 100 per account
per UTC calendar month, shared across phones, with existing daily/global caps.
Settings show the remaining count, and the player explains exhaustion while
keeping the photo and step usable. Failed provider attempts consume one;
duplicates/rejected requests do not. No quota message is saved as a caption or
emailed. 150/300 are hypothetical cost comparisons, not included allowances.
Five AI photos daily require 150 attempts in 30 days; ordinary checks do not
spend AI allowance. Store fees, taxes, backend costs and retries are excluded.
Consent wording version is now `2026-10-05.5`.

### Optional visible-cue experiment

Jamie questioned the value of captions that repeat the step's object name and
suggested a setup field describing the intended visual evidence. Tested a
separate experimental prompt, not shipped to the app, with eight cases at
600 and 1,000 pixels (16 provider calls, estimated $0.04961). Same Sonnet model,
no agent loop or external tools. Output contained an observation plus an
experimental comparison with the desired visual cue, never a physical-state
or safety verdict. Desired cues were explicitly treated as hypotheses, not
evidence. The cases included a tap lever, washing-machine dial marker,
patio lever with both opposite expectations, dark display, wrong expected
object, near-black photo and heavily blurred photo.

At 1,000 pixels, observations agreed with visual review of the requested cues:
the tap lever was downward; the dial marker aligned towards its printed label;
the patio lever was horizontal under both opposing expectations; the display
was dark; the wrong-object and degraded inputs did not establish the desired
cue. At 600 pixels, the display case confused printed programme labels with
screen content and its comparison contradicted its own no-lit-digits
observation. A match/difference label therefore needs independent evaluation
and is not proposed for immediate release. Six photos plus two synthetic
degradations do not establish general reliability, nor do opposite prompts
substitute for actual photos of both physical positions.

The eight detailed-cue calls averaged $0.003688 each at 1,000 pixels (about
$0.37 per 100), compared with $0.002513 at 600 pixels. These are small-sample
token estimates, excluding store fees, backend costs and retries.

Recommendation: explore an optional "What should the photo show?" field with
1,000-pixel copies for these detailed observations. Help users specify visible
cues such as lever position or a dark display, rather than hidden conditions
such as lock engagement or power state. Keep the photo visible and leave step
completion to the person. Next evidence: new examples of both positions,
different lighting/angles and ambiguous or occluded cues; compare with an
optional user-captured reference photo before deciding whether that setup is
worth its extra effort. A reference comparison is a proposal, not tested here.
An agent is only justified if a particular tool (e.g. crop/zoom) demonstrates
an improvement beyond a single image request; it does not create new evidence.

Private report `artifacts/ai-photo-evaluation/report.html` now includes the
size economics and every experimental cue reply for owner review. No private
photos, raw replies, original filenames, API key or artifact runtime enters Git.
The broad-caption prompt remains unchanged by this experiment.

## Optional step descriptions implemented

Jamie chose a general optional step description, useful for instructions even
without photos or AI. The composer now offers **Description (optional)** on
each check step, limited to 500 characters; the player shows it under the title.
Existing `photoPrompt` JSON storage is reused, including draft autosave,
published routines, recovery and backup. The old "Take a photo" default is
hidden. Descriptions do not require Premium, and changing photo requirements
does not discard them.

For AI-enabled photo steps only, the description travels with the title and
a 1,000-pixel metadata-free copy. The server bounds it before spending allowance.
A separate production brief reports the requested visible feature without
match/difference labels or completion verdicts. Consent version .6, privacy
copy and store drafts include this additional context. Broad captions still
use 600 pixels when no description was added.

Five final calls used the actual production provider and parser: dial-marker
alignment with a readable printed label, a patio lever, an unlit display, a
keyboard under a misleading towel/bag expectation, and deliberate blur. Four
returned observations; the blur returned `cannot_tell`. This is a small sanity
check, not an accuracy score. An earlier dial response was too long and used
"off vertical", triggering the verdict filter; the brief was shortened and
clarified before the final calls. Only a narrowly recognised printed "Off"
label is exempted, never an appliance-state claim.

Final five-call token cost: $0.021012, averaging $0.0042024 each, about $0.42
per 100 attempts. Account billing was not reconciled. The earlier $0.37/100
cue experiment used a different prompt. Proposed £2.50/200 economics and the
yearly-price implication are in `docs/AI_PHOTO_PRICING.md`; the implemented
allowance remains 100 and no store pricing was changed.

Verification: Flutter analysis clean; 478 CI-equivalent non-golden Flutter
tests and 90 Deno tests passed. Two focused walkthrough scenarios cover
composer/player descriptions on an iPhone-sized screen and a 360px-wide phone
at 1.6x text, without layout errors. No further broad photo sweep was needed.
The existing Windows golden difference remains separate. No live deployment
or real-phone test was performed.

Local verification: Flutter analysis clean; 474 CI-equivalent non-golden app
tests and 88 Deno server tests passed. Embedded PostgreSQL (PGlite, ignored
local runtime only) applied the actual 021/023 migrations and passed
`supabase/tests/ai_photo_monthly_allowance.sql`. That check verifies permissions,
cap boundaries, duplicate IDs, independent accounts, daily/global caps,
pruning and reset-date arithmetic. Multiple-session concurrency and real
month rollover still need staging checks. No live backend change was made.
The filtered walkthrough passed 28 scenarios (14 AI plus matching email/player
scenes), with an empty layout-error report. Small-phone consent, large-text
consent and the settings allowance count were inspected. Golden images were
not regenerated; the previously documented Windows difference remains separate.
