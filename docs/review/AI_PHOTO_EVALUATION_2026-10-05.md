# AI photo evaluation — 5 October 2026

Recommendation: keep AI descriptions disabled while testing accuracy. Step
titles are now included as context, but descriptions still contain confidently
wrong visible details. This is an optional description aid, never a pass/fail
check or proof of a physical state.

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

## Results

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

The app passes the saved step's title with its photo. The server bounds titles
to 1,000 characters before spending allowance and adds no account details or
routine name. User-written titles can themselves contain personal information.
The model is instructed to treat the title as untrusted context and follow
the image when they conflict. Nothing in this flow marks a step complete.

Consent, settings, privacy copy and store disclosure drafts now explicitly
include the step title. Consent version is `2026-10-05.3` in app and server;
older consent does not authorise this transfer. Structured JSON follows
https://platform.claude.com/docs/en/build-with-claude/structured-outputs.

Before enabling, repeat evaluation with owner-authored routine titles and
closer photos of ambiguous handles, markers and switches. Confirm native phone
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
