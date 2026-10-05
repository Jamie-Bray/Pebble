# AI photo steps: proposal

**Status:** agreed direction, not yet built. Nothing here is in the app.
**Date:** 4 October 2026
**Replaces:** the pricing options in `AI_PHOTO_DESCRIPTION_FEASIBILITY.md`
(section 6). The cost figures and spending-control ideas there still apply.

## The shape Jamie asked for

- **Personal Premium only.**
- **One routine at a time** can have AI switched on.
- That routine can have **up to five AI photo steps**.
- Switching it on asks a plain yes-or-no question once. Saying no changes
  nothing else in the app.

This is small enough to explain in one sentence, and it removes the main
objection to the earlier options: nobody's photo is sent anywhere unless they
are a subscriber who has switched this on for a routine they chose.

## What the person sees

**Switching it on** (routine settings, Premium only):

> **Use AI on this routine?**
> Photos you take on AI steps are sent to *[provider]* to be described, then
> deleted. They are not used to train AI. Your other photos stay on this phone
> unless you have turned on backup.
>
> AI describes what it can see in a photo. It can't confirm that something is
> locked, off or safe.
>
> [Turn on AI] [Not now]

**In the routine:** after the photo is taken on an AI step, one line appears
under it, for example "A white door with the handle up and a key in the lock."
The step is complete as soon as the photo is taken; the description arrives a
moment later and never blocks or fails the step.

**In History:** the same line sits beside the photo, which makes old runs
readable at a glance and gives screen-reader users something to hear.

**When it can't help:** "Couldn't describe this photo." Never a guess.

## Rules that keep it honest

- It describes what is visible. It never says "locked", "off", "safe" or
  "done" as a verdict, and it never ticks a step for the user.
- No free tier and no "AI says you're safe" in any upgrade message.
- Copy goes through `COPY_GUIDELINES.md`.

## How it works

1. The app shrinks the photo (longest side about 1,000 px) and sends it to a
   new Edge Function, `describe-proof-photo`, with the user's sign-in token.
2. The function checks, on the server and in this order: the AI off switch,
   Premium is active, this user has accepted the AI notice, the photo size, and
   the user's allowance for today.
3. It reserves the allowance, calls the provider, and returns one or two
   sentences. The photo is not stored by Pebble.
4. The app saves the sentence with the photo on the phone. If backup is on, it
   travels with the run like any other step detail.

Sending the photo directly means this works whether or not backup is on, which
the earlier design did not allow for.

## Spending limits (all enforced on the server)

| Limit | Value | Why |
|---|---|---|
| Per user per day | 20 descriptions | Five steps, run a few times a day, with headroom |
| Whole app per month | A fixed budget, starting at £10 | Stops a runaway bill; requests are refused once it is reached |
| At the provider | A hard monthly cap on the account | Backstop if our own counting is wrong |
| Off switch | One database setting | Turns the feature off for everyone without an app update |

The "one routine, five steps" rule is enforced in the app; the daily count is
what protects the bill, so it is the one enforced on the server. If the limits
cannot be checked, the request is refused and the photo step carries on
without a description.

Rough cost: a subscriber using all five steps twice a day makes about 300
requests a month, which is pennies at the prices in the feasibility study.
Against a subscription of £1.99–£2.99 it is not a margin concern.

## Before any of this is built

1. **Choose the provider with a real test.** 30–50 photos (door locks, hobs,
   plugs, pill boxes, blurry and dark ones), run through two current small
   vision models, for example one from Anthropic and one from Google. Score:
   wrong claims, useful detail, and whether it says "can't tell" when it
   should. Needs: an API key for each, and photos Jamie is happy to use.
2. **Check each provider's terms** for no training on the photos and short or
   zero retention, and add the chosen one to `LEGAL_PROCESSOR_MAP.md`.
3. **Update the privacy policy and both store privacy forms** before the
   feature is switched on for anyone.
4. **Build it on the staging project behind the off switch**, with tests for
   every limit above.

## Open decisions for Jamie

- Which two providers to test, and creating the API accounts.
- Whether the description should also appear in completion emails (suggested:
  no, at least at first).
- Whether this ships with launch or in the first update after it (suggested:
  first update, so launch is not waiting on a privacy-policy change).
