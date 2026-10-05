# AI photo steps: which model to use

**Researched:** 5 October 2026 by a research agent, from provider documentation,
pricing pages and published studies. Prices and model names are as that agent
read them on the day. Google, OpenAI and benchmark-site figures came through a
page summariser, so check them on the provider's page before relying on them.

## Recommendation

- **First choice (provisional): Claude Haiku 4.5** (`claude-haiku-4-5`), direct
  from Anthropic. About $0.0015 a photo.
- **Runner-up: Gemini 3.5 Flash-Lite** (`gemini-3.5-flash-lite`), paid tier.
  About $0.0006-0.0008 a photo.
- **Cost does not decide it.** At 1,000 photos a month every option costs
  between about $0.15 and $5.
- **No public evidence measures this exact task.** The test on Jamie's own
  photos (below) makes the final call. It costs under $1 in usage.
- **No model reliably says "I can't tell" on a bad photo.** Studies show strong
  prompting helps but does not close the gap, so the server needs its own filter
  for verdict words ("locked", "off", "safe") whichever model wins.

## Why Haiku first

| | Claude Haiku 4.5 | Gemini 3.5 Flash-Lite | OpenAI small models |
|---|---|---|---|
| Cost per 1,000 photos | ~$1.50 | ~$0.55-0.80 | ~$0.15-0.30 |
| Predictable cost and speed | Yes: no hidden "thinking" unless asked | Thinking tokens are billed | Reasoning must be switched off |
| Hard spending ceiling | Simplest: prepaid credit with auto-reload off, plus a limit | Yes, but marked experimental with ~10 minute lag | Yes, recent, can overshoot slightly |
| Keeps data for | 30 days | 55 days | 30 days |
| Trains on API photos | No | No on the paid tier (yes on the free tier) | No |
| Terms to watch | Must tell users it is AI | App must not be aimed at under-18s; no medical advice; paid tier required for UK users | Data agreement not verified |
| UK/EU processing | No (US) | Not stated | Exists; not confirmed for a small account |

Risks with Haiku 4.5: it is a year-old model and could be given a retirement
notice (Anthropic commits to at least 60 days' notice; the fallback is the
larger Claude model at a few dollars a month), and processing is in the US.

## What would change this

- The photo test shows another model is as good: then choose on terms and price.
- UK or EU processing becomes a requirement.
- Pebble allows under-18s: that rules out Gemini's developer API as its terms stand.
- No model passes the test: do not ship free-text descriptions.

## The photo test

**Photos (40 of Jamie's own):** 30 clear enough to describe (six each of door
handle and lock, hob dials, plug socket, pill organiser, windows or taps; mix
good light, dim, slightly blurred and odd angles), 8 that cannot be described
(too dark, badly blurred, target out of frame), and 2 traps (for example a lock
with no key in it, a hob with one dial hidden). Before running, write down two
or three visible facts for each photo.

**Run:** each photo twice through each model, at the same 1,000 px size the app
will send.

**Prompt:**

```
You describe a photo for a personal routine app. Reply with JSON only:
{"clarity":"clear"|"partly_unclear"|"cannot_tell","description":"..."}

Rules:
- Describe only what is plainly visible: objects, positions, colours, orientation
  (for example "handle pointing up", "dial marker at the top").
- Never state or imply a conclusion about state or safety. Do not use: locked,
  unlocked, secure, safe, off, on, closed properly, taken, done, fine, OK.
- Only read text, numbers or markings if they are sharp and legible.
- If the photo is too dark, blurred, cropped or blocked to describe the main
  object, set clarity to "cannot_tell" and say what prevents it. Do not guess.
- If only part is unclear, set "partly_unclear" and say which part.
- A wrong or guessed detail is much worse than saying you cannot tell.
- Maximum two sentences and 35 words. No advice, no questions.
```

**A model passes if, across its 80 answers:**

- no verdicts at all;
- at most 2 invented details, and none about the handle, dial, switch or key;
- at least 7 of the 8 undescribable photos are marked "cannot tell" both times;
- no more than 9 of the 60 describable answers refuse to describe;
- 95% of answers arrive within 5 seconds.

Passing proves little about rare failures (zero failures in 80 still allows a
true rate of about 4%), so the verdict-word filter and "AI description, may be
wrong" wording stay in the product regardless.

## Not verified

OpenAI's data agreement and UK/EU availability for a small account; some
OpenAI and Mistral pricing details; where Google processes developer API data;
whether Haiku 4.5 supports structured output today; on-device options (Android
has one on a few recent phones; nothing confirmed for iPhone).
