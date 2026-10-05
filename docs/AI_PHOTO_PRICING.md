# AI allowance pricing proposal — 5 October 2026

**Update, later on 5 October 2026:** Jamie chose **200 attempts per account per UTC
month** on the single Personal Premium plan, with no Plus tier for now. Migration
023, the server and the app copy use 200. Prices are still undecided; the app
is not yet in either store. The rest of this note is the earlier proposal.

At the time of writing the implemented allowance was 100 attempts per account per UTC month.
The launch price recorded in START_HERE remains £1.99/month and £14.99/year.
Jamie proposed £2.50/month with 200 attempts; no store price or live allowance
was changed. The yearly offer needs a separate decision if the allowance rises.

Five calls using the final Sonnet detail prompt averaged $0.0042024 per attempt:
about $0.42 for 100, or $0.84 for 200. Earlier $0.37/100 results used the
experimental prompt. General 600-pixel captions averaged about $0.26/100 over
23 photos. These are small token-cost samples, not guaranteed bills; retries
can add cost and user photos can differ.

Illustration assuming 20% UK VAT, 15% store fees on the price excluding VAT,
and **£0.75 per US dollar as an assumption**, with every included attempt used
at the measured final-detail cost:

| Offer | Revenue after VAT and store fee | AI cost | Remaining before other costs |
| --- | ---: | ---: | ---: |
| £1.99/month, 100 attempts | £1.41 | £0.32 | £1.09/month |
| £2.50/month, 200 attempts | £1.77 | £0.63 | £1.14/month |
| £14.99/year, 200 attempts each month | £0.88/month equivalent | £0.63/month | £0.25/month |

Remaining contribution = price ÷ 1.2 × 0.85 − attempts × $0.0042024 × 0.75.
This excludes hosting, email, storage, support, refunds, retries and other
expenses. It is not profit. The monthly change improves this illustration by
about 5p while doubling the allowance; the unchanged yearly price leaves much
less room. Five AI photos a day use 150 attempts in 30 days; ten use 300.

Recommendation: £2.50/200 is a plausible monthly offer to try with people,
provided the yearly offer is reviewed at the same time. Keep this as a pricing
proposal until chosen; changing marketing copy alone does not change the store
products or the server's monthly cap.

Sources: [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622),
[Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/),
[UK VAT rates](https://www.gov.uk/vat-rates). Apple's 15% rate requires eligibility
and enrolment; this calculation does not establish Jamie's account rate.
