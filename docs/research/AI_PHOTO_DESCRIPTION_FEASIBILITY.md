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

We evaluated four options for image-understanding (vision) models as of October 2026. This evaluation excludes generative (image-creation) models.

### A. Provider Shortlist

**1. OpenAI: GPT-5.6 Luna**
*   **Availability:** General availability for developer accounts.
*   **Cost (per 1M tokens):** $0.20 Input / $1.20 Output.
*   **Data Terms:** Standard enterprise API terms; data is not used for training.
*   **Verification:** Verified via OpenAI Developer Pricing page on Oct 4, 2026.

**2. Google: Gemini 3.8 Flash**
*   **Availability:** General availability via Google Cloud Agent Platform / Developer API.
*   **Cost (per 1M tokens):** $0.75 Input / $3.75 Output. *(Note: Introductory pricing, expected to double Jan 1, 2027).*
*   **Data Terms:** Paid API tier data is excluded from model training. Free tier data *is* subject to product improvement logging.
*   **Verification:** Verified via Google Developer API pricing page on Oct 4, 2026.

**3. Anthropic: Claude Haiku 4.5**
*   **Availability:** General availability via Anthropic Console.
*   **Cost (per 1M tokens):** $1.00 Input / $5.00 Output.
*   **Data Terms:** Standard enterprise API terms; zero-retention policies available on request; not used for training.
*   **Verification:** Verified via Anthropic Pricing page on Oct 4, 2026.

**4. On-Device: Android AICore (Gemini Nano Multimodal)**
*   **Availability:** Supported on high-end 2026 flagships (12GB+ RAM) via ML Kit GenAI APIs.
*   **Cost:** $0.00 (Free per-request, processed locally).
*   **Data Terms:** 100% private, zero cloud transmission.
*   **Verification:** Verified via Android Developers AICore documentation on Oct 4, 2026.

### B. Fair Comparison & Selection Criteria

*   **Privacy & Operational Complexity:** On-device processing is the gold standard for privacy but fragments the user experience (requires high-end hardware). Server-mediated APIs require robust access controls.
*   **Latency:** Haiku 4.5 and Gemini 3.8 Flash are exceptionally fast. GPT-5.6 Luna balances speed with extreme cost-efficiency.
*   **Abstention & Description:** We cannot rank accuracy or safety adherence without evaluation. A shared evaluation dataset must be created (see Section 5).

---

## 3. Cost Calculations

We assume the API usage is funded by Pebble's operational budget, not Jamie's consumer AI subscriptions.

**Modelling Assumptions:**
*   **Input Tokens:** 408 tokens per request (258 tokens for standard resized WebP/JPEG + 150 tokens for the strict system prompt).
*   **Output Tokens:** 50 tokens (a constrained 1-2 sentence description).
*   **Thinking Tokens:** 0 (budget controls will enforce no hidden reasoning tokens).
*   **Retries/Failures:** Estimated 5% overhead.
*   **Infrastructure (Supabase):** Negligible for compute (Edge Functions are heavily cached), but bandwidth out is approx $0.09/GB.

**Estimated AI Costs (US$):**
*(Based on GPT-5.6 Luna at $0.20/1M Input, $1.20/1M Output)*
*Cost per photo = (408 * $0.0000002) + (50 * $0.0000012) = **$0.0001416***

| Monthly Photos | AI API Cost | Est. Backend/Bandwidth | **Total Cost** |
| :--- | :--- | :--- | :--- |
| **100** | $0.01 | $0.01 | **$0.02** |
| **1,000** | $0.14 | $0.05 | **$0.19** |
| **10,000** | $1.42 | $0.50 | **$1.92** |
| **100,000** (Normal Use) | $14.16 | $5.00 | **$19.16** |
| **1,000,000** (Runaway) | $141.60 | $50.00 | **$191.60** |

---

## 4. Enforceable Cost Controls

To protect Jamie from open-ended AI bills (e.g., a runaway script submitting 1M photos), we must design strict server-enforced controls before writing a single line of API integration. (Using $10/mo as an illustrative budget).

**Proposed Abuse-Prevention Design:**
1.  **Auth & Ownership:** The Supabase Edge Function reads the user's JWT. It asserts the user owns the `sessionId` before processing.
2.  **Concurrency & Idempotency:** The Edge Function uses a Redis/Postgres locking mechanism tied to the `proofId`. Repeated taps return the existing database record rather than firing new billable requests.
3.  **Client-Side Limits:** Maximum image resolution strictly downsampled in the app before upload (e.g., max 512x512). Output bounded to `max_tokens: 100`.
4.  **Thinking Controls:** If using models like Claude or Gemini Pro that support hidden reasoning tokens, the `thinking_budget` must be explicitly disabled (`0`) in the API request headers.
5.  **Per-User Allowances:** Supabase tracks a daily quota (e.g., 20 AI requests/day per user) in a rate-limiting table. 
6.  **Global Kill Switch:** A Supabase Remote Config flag (`ai_descriptions_enabled`) that the client checks. Jamie can toggle this to `false` in the dashboard to instantly drop all incoming AI requests.
7.  **Fallback Experience:** When an allowance is exhausted or the kill switch is flipped, the UI gracefully falls back. The button disables and says "AI limits reached for today." The ordinary photo feature continues working flawlessly.

---

## 5. Evaluation Plan

Before choosing a provider, we must evaluate them fairly.

**Shared Dataset & Rubric:**
*   Assemble 50 consented, human-labelled routine photos covering edge cases: clear actions, blurry photos, cropped sockets, disconnected plugs with hidden cables, and printed instructions in-frame.
*   **Metrics to Measure:**
    1.  *Unsupported Claims:* Does the model confidently state "The switch is off" when obscured? (Failure condition).
    2.  *Missed Details:* Does it fail to spot the iron?
    3.  *Appropriate Abstention:* Does it output "Cannot determine" for blurry shots?
    4.  *Latency:* Measure p90 round-trip time.

---

## 6. Decision-Ready Proposal

**Recommended Shortlist:** OpenAI GPT-5.6 Luna and Anthropic Claude Haiku 4.5. Both are exceptionally cheap, fast, and boast standard enterprise data privacy (zero training). 

**Unresolved Questions:**
*   Can these ultra-cheap models strictly adhere to the negative constraints (no safety verdicts, no medical claims)?
*   How accurately can on-device Gemini Nano process the same prompts for users on flagship hardware?

**Smallest Prototype:**
1.  Do not integrate with the app yet. 
2.  Write a standalone Python/Node script to feed the 50-image evaluation dataset through the Luna and Haiku APIs.
3.  Manually grade the outputs against the rubric.
4.  If one model passes the safety threshold, draft the Privacy Policy updates declaring third-party AI image processing and proceed to an app UI prototype.

*(Note: Implementation is not recommended until this evaluation establishes that cheap vision models can safely abstain from hallucinating safety states.)*
