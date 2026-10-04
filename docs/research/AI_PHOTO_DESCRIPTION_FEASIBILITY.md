# Feasibility Study: AI-Generated Routine Photo Descriptions

**Status:** Proposed Future Feature
**Date:** October 2026

This document investigates the feasibility of allowing Pebble users to request short AI-generated descriptions of their routine proof photos.

---

## 1. Product Fit

**Value Proposition:**
Pebble users take photos as "proof" that a routine step (e.g., locking the door, unplugging an iron) was completed. An AI description could automatically catalog visible details, providing peace of mind or aiding accessibility (e.g., screen readers parsing the photo).

**Limitations & Risks:**
*   **Inference vs. Observation:** An AI might confidently state "The iron is off" when it can only truly observe "The iron is unplugged."
*   **Repeated Checking:** Explicitly validating safety states via AI might encourage OCD-like checking loops, contrary to Pebble's guardrails against fostering anxiety. The feature must act as an objective "describer," not a "validator." No medical claims, safety verdicts, or automatic routine completions should be permitted.

**Recommendation:** If pursued, the feature should be strictly opt-in, disabled by default, and limited to factual visible descriptions (e.g., "A black plug resting on a counter next to a white socket"). We reserve the option to reject this feature entirely.

---

## 2. Provider Options and Cost Comparison

We evaluated options for image-understanding (vision) models as of October 2026. This evaluation excludes generative (image-creation) models.

### A. Verified Candidate Model

**OpenAI: GPT-4o-mini**
*   **Availability:** General availability for developer accounts.
*   **Cost (per 1M tokens):** $0.15 Input / $0.60 Output.
*   **Image Token Calculation:** OpenAI's official vision documentation lists GPT-4o-mini's low-detail image input as **2,833 tokens** (unlike GPT-4o which uses 85).
*   **Data Terms:** Standard enterprise API terms; data sent via the API is not used to train OpenAI models.
*   **Verification:** Verified via official [OpenAI API Pricing](https://openai.com/api/pricing/) and [Vision Documentation](https://developers.openai.com/api/docs/guides/images-vision) on Oct 4, 2026.

*(Note: Other models were considered, but GPT-4o-mini provides a definitively documented, low-cost baseline for this feasibility study.)*

### B. Fair Comparison & Selection Criteria

*   **Privacy & Operational Complexity:** Server-mediated APIs like GPT-4o-mini require robust access controls and budget limits, unlike on-device processing which is private but hardware-constrained.
*   **Latency:** GPT-4o-mini is optimized for low-latency tasks.
*   **Abstention & Description:** We cannot rank accuracy or safety adherence without empirical evaluation. A shared evaluation dataset must be created (see Section 5).

---

## 3. Cost Calculations

We assume the API usage is funded by Pebble's operational budget, not Jamie's consumer AI subscriptions. Calculations use the verified GPT-4o-mini pricing.

**Modelling Assumptions:**
*   **Image Tokens:** **2,833 tokens** per image input (GPT-4o-mini low-detail).
*   **System Instructions:** Estimated **150 input tokens** for strict formatting and safety rules.
*   **Total Input Tokens:** 2,983 tokens.
*   **Output Tokens:** Bounded to **50 output tokens** (1-2 sentences).
*   **Thinking Tokens:** 0 (GPT-4o-mini does not utilize hidden thinking/reasoning tokens).
*   **Retries/Failures:** An illustrative assumption of **5% overhead** for duplicated or failed requests (not a worst-case guarantee).
*   **Backend Infrastructure:** Supabase Edge Function invocations ($2/1M after free tier) and bandwidth out ($0.09/GB) are billed separately from OpenAI.

**Estimated AI Costs (US$):**
*Input Cost:* 2,983 tokens * ($0.15 / 1,000,000) = $0.00044745
*Output Cost:* 50 tokens * ($0.60 / 1,000,000) = $0.00003000
*Cost per successful photo:* **~$0.000477**
*Cost with illustrative 5% retry overhead:* **~$0.000501**

| Monthly Photos | AI API Cost | Est. Backend/Bandwidth | **Total Cost** |
| :--- | :--- | :--- | :--- |
| **100** | $0.05 | $0.01 | **$0.06** |
| **1,000** | $0.50 | $0.05 | **$0.55** |
| **10,000** | $5.01 | $0.50 | **$5.51** |
| **100,000** (Normal Use) | $50.13 | $5.00 | **$55.13** |

---

## 4. Proposed Spending Controls

To protect Jamie from open-ended AI bills, we propose strict server-enforced controls that check every request *before* any provider call is made. Using $10/mo as an illustrative budget, this design requires implementation tests before use.

**Server-Enforced Abuse-Prevention Design:**

1.  **Authentication and Photo Ownership:** The Supabase Edge Function decodes the user's JWT. It queries the database to strictly assert that the authenticated user owns the `proofId` requested.
2.  **Server-Checked Kill Switch:** The Edge Function queries a Postgres configuration table (`ai_enabled`). If `false`, the request is immediately rejected. This prevents client-side bypasses.
3.  **Actual Uploaded Bytes and Dimensions:** The server intercepts the image payload and checks the actual file size (<1MB) and dimensions before making the API call, ignoring client-reported limits.
4.  **Atomic Allowance & Global Budget Reservation:** Before calling OpenAI, the server starts a Postgres transaction. It adds the *conservative maximum cost* of the request (e.g., $0.0006 based on max output tokens) to a global `spent_this_month` counter. If this exceeds the $10 budget, the transaction aborts and the request is refused. If budget accounting is unavailable (e.g., database is down), requests must fail closed and stop immediately.
5.  **Idempotency & Persistent Request States:** To prevent duplicate provider calls, the system uses persistent request states in the database (e.g., `pending`, `completed`, `failed`) rather than relying solely on a transient transaction lock. When a user requests a description, a new state is written. If they tap again while the first request is `pending`, the server observes the persistent state and safely returns or waits, avoiding duplicate API calls.
6.  **Reconciliation & Bounded Retries:** After the OpenAI API returns successfully or fails with a definitive non-billable error, the server calculates the exact billed cost and reconciles the global budget counter. **Crucially, reservations are *not* refunded if a request merely times out**, because the provider may still process and bill a timed-out request. Reconciling only on definitive outcomes prevents spending the same allowance twice. Bounded retries ensure that the system does not enter a loop of indefinite reservations.
7.  **Provider-Specific Limits:** The OpenAI API payload hardcodes `max_tokens: 50` and `detail: low` to strictly bound output charges.

**Residual Exposure & UX:**
There are no absolute budget guarantees. *Residual exposure* remains because requests already in-flight at the provider before the budget was exhausted will complete and be billed. Furthermore, Supabase infrastructure costs (Edge Function time, egress bandwidth) are not capped by this logic.
When the allowance is exhausted or the database is unreachable, the ordinary photo feature will continue working seamlessly. The AI description button will safely disable and display "AI descriptions unavailable."

---

## 5. Evaluation Plan

Before proceeding to integration, we must evaluate the model fairly.

**Shared Dataset & Rubric:**
*   Assemble 50 consented, human-labelled routine photos covering edge cases: clear actions, blurry photos, cropped sockets, disconnected plugs with hidden cables, and printed instructions in-frame.
*   **Metrics to Measure:**
    1.  *Unsupported Claims:* Does the model confidently state "The switch is off" when obscured? (Failure condition).
    2.  *Missed Details:* Does it fail to spot the iron?
    3.  *Appropriate Abstention:* Does it output "Cannot determine" for blurry shots?
    4.  *Latency:* Measure p90 round-trip time.

---

## 6. Decision-Ready Proposal

**Recommended Candidate:** OpenAI GPT-4o-mini provides a verified, low-cost option with clear token calculations and enterprise data privacy.

**Unresolved Questions:**
*   Can GPT-4o-mini strictly adhere to the negative constraints (no safety verdicts, no medical claims) on ambiguous images?

**Smallest Prototype:**
1.  Do not integrate with the app yet. Do not activate billing or upload user photos.
2.  Write a standalone Python/Node script to feed the 50-image evaluation dataset through the GPT-4o-mini API (using a separate, strictly-budgeted dev account).
3.  Manually grade the outputs against the rubric.
4.  If the model passes the safety threshold, draft the Privacy Policy updates declaring third-party AI image processing and proceed to test the server-enforced controls described in Section 4.
