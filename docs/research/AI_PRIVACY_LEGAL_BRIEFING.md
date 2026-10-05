# Pebble briefing: AI photo descriptions (Part A) and legal-page rewrite check (Part B)

Prepared 5 October 2026. This is research, not legal advice. Items marked **[SOLICITOR]** need a solicitor to confirm. Items marked **[UNVERIFIED]** I could not confirm from a primary source in this session.

**How I worked**
- Repo read-only at `origin/integration/launch-pass` (f15d4c2) and `origin/main` (f5c3beb). Nothing was edited, committed or pushed.
- Web sources were fetched today unless marked otherwise.
- **Quoting limit:** you asked for a short verbatim quote of each store rule. I am limited to one short verbatim quote of third-party copyrighted text per response. I used it on the Apple third-party-AI rule and paraphrased the rest closely, with URLs so you can read the exact sentences.

## Headline findings

1. **The policy is already wrong about voice tips.** Voice tip audio files are uploaded to Supabase when backup is on (`lib/features/sync/guidance_audio_cloud_backup.dart`, called from `cloud_sync_coordinator.dart:650`, retention set to 3,650 days). `web/privacy.html:141` says they stay on the device, and both store forms say audio is not collected. The recorded backup consent sentence does not mention voice recordings. This is on `origin/main` too, so it predates PR #5.
2. **PR #5's "legal meaning unchanged" claim is mostly true.** Six sentences are slightly stronger or weaker than before. The one that matters is the new privacy-page lede, "keeps your data on your phone by default", which is broader than what the app does.
3. **For the AI feature, treat medication photos as health data.** That means explicit consent with a named provider, kept separate from other consents. Your planned check box fits. The planned default-on inclusion in the completion email does not; make it an explicit unprompted choice.
4. **"Pebble doesn't store the photo" is not the same as "nobody keeps it".** Anthropic's API default is deletion within 30 days. Google's Gemini API logs prompts for 55 days. Only a zero-retention arrangement lets you say the provider doesn't keep it.
5. **Apple now names third-party AI explicitly** in guideline 5.1.2(i). Guideline 5.1.1(ix) also says apps that "require sensitive user information" should be submitted by a legal entity, not an individual. That is worth a solicitor's view for a sole trader.

---

# Part A: sending users' photos to an AI provider

## 1. Lawful basis, special category data, explicit consent, children

**Lawful basis (Article 6)**
- Use consent (Art 6(1)(a)), not contract. The feature is optional, and you need explicit consent for Article 9 anyway. This matches how `web/privacy.html` already treats cloud backup.
- The ICO says consent is not freely given if it is a precondition of a service that does not need it. Keep Premium fully usable without AI. Apple 5.1.1(ii) says the same about paid functionality.
- Source: https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/consent/what-is-valid-consent/

**Is a photo of a pill organiser health data?**
- The ICO test for inferred data is whether you intend to make an inference linked to a special category, or to treat someone differently because of it. If so, it is special category data however confident the inference.
- A photo of a door is not health data. A photo of a labelled pill box in a routine called "Evening medication" is harder. An AI sentence such as "the Tuesday compartment is empty" is a deliberate statement about medication-taking.
- My reading: assume Article 9 applies whenever medication is visible, and design for it. **[SOLICITOR]** to confirm.
- EU position is, if anything, broader. From memory **[UNVERIFIED]**: CJEU C-184/20 (indirect revelation counts) and C-21/23 Lindenapotheke (online medicine orders are health data).
- Photos are not biometric data unless you do specific technical processing to identify people. Do not ask the model to identify anyone.
- Source: https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-is-special-category-data/

**What follows from Article 9**
- You need an Article 6 basis and an Article 9 condition. Explicit consent (Art 9(2)(a)) is the only realistic one.
- The ICO says explicit consent needs a clear written or spoken statement, must name the kind of special category data, and must be separate from other consents.
- No "appropriate policy document" is required for the explicit consent condition.
- Source: https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-are-the-conditions-for-processing/

**What valid explicit consent looks like in the app**

| Requirement | In practice for Pebble |
| --- | --- |
| Unambiguous positive action | Unticked box. "Turn on" disabled until it is checked. Closing the screen is not consent. |
| Explicit statement | The box label says what is agreed in words, and mentions medication or health. |
| Specific and informed | Names Pebble, names [PROVIDER], says USA, says what is sent and what comes back. |
| Granular | AI processing and email inclusion are two separate choices. Consent is per routine. |
| Freely given | Optional; nothing else in Premium depends on it. |
| Withdrawal as easy as giving | One switch in the same routine's settings, effective on the next photo. |
| Records | Server-side row: user, routine, consent text version and hash, provider name, policy version, timestamp, withdrawal timestamp. |
| Versioning | Re-ask if the provider, the retention terms, the wording or the data sent changes. |
| Refresh | The ICO says consent degrades over time. Re-confirm after a long gap or a lapsed subscription. |

- You already have this pattern in `cloud_backup_consent_provider.dart`. Reuse it with a new feature key. Do not copy its hard-coded versions (see Part B, item F2).
- EDPB Guidelines 05/2020 on consent say the same for the EU: https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-052020-consent-under-regulation-2016679_en **[not re-fetched today]**
- The Data (Use and Access) Act 2025 data protection changes mostly came into force on 5 February 2026. I found nothing that relaxes consent for this use. Sources: https://www.kennedyslaw.com/en/thought-leadership/article/2026/the-data-use-and-access-act-2025-commencement-dates-and-planned-guidance-for-2026 and https://www.financialinstitutionsnews.com/2026/02/09/data-use-and-access-act-2025-majority-of-changes-related-to-data-protection-now-in-force/

**Children and age**
- UK: a child can consent to an online service from 13. Below that you need verified parental consent. Source: https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/children-and-the-uk-gdpr/what-are-the-rules-about-an-iss-and-consent/
- EU: member states set the age between 13 and 16 (Art 8 EU GDPR). **[UNVERIFIED per country]**
- Your documents are inconsistent. Play target audience is "18 and over" (`docs/store/GOOGLE_PLAY_LISTING.md:202`), the privacy page says not directed at under-13s, and the terms have no age clause.
- Google's Gemini API terms require API users to be 18 or over and bar services directed at minors. I did not find an age clause in Anthropic's Commercial Terms; Anthropic has separate guidance for products serving minors that I did not fetch **[UNVERIFIED]**.
- Recommendation: make the AI feature 18+ and say so on the switch-on screen. **[SOLICITOR]** whether a self-declaration is enough.

## 2. Roles, DPA, transfers, DPIA

**Roles**
- Pebble (Jamie Bray trading as Pebble) is the controller.
- [PROVIDER] is a processor only if its terms say so and it does not use the data for its own purposes. Supabase is a processor that relays the photo through an Edge Function.
- Anthropic: the DPA is incorporated into the Commercial Terms; customer is controller, Anthropic is processor; no model training on customer content. Sources: https://www.anthropic.com/legal/commercial-terms and https://www.anthropic.com/legal/data-processing-addendum
- Google: for users in the UK, EEA or Switzerland you may only use Paid Services. Paid prompts are not used to improve products, and Google's data processing addendum applies. The unpaid tier allows human review and product improvement, so it is unusable here. Source: https://ai.google.dev/gemini-api/terms
- **Watch point:** Anthropic's DPA schedule lists special categories of personal data as "None". Ask Anthropic, or a solicitor, whether health-revealing photos are within what the DPA covers. **[SOLICITOR]**
- **Watch point:** Gemini terms prohibit use in clinical practice or to provide medical advice. Describing a photo is not that, but keep the feature well away from "has the medication been taken".

**Provider retention (affects what you can truthfully say)**

| Provider | Default | Zero retention |
| --- | --- | --- |
| Anthropic API | Inputs and outputs deleted within 30 days; flagged content up to 2 years | Available by agreement via sales; safety classifier results still kept |
| Gemini Developer API (paid) | Prompts and responses logged 55 days for abuse monitoring | Not offered on the page I read. Vertex AI documents a zero-retention route, but I could not load the page **[UNVERIFIED]** |

- Sources: https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data , https://privacy.claude.com/en/articles/8956058-i-have-a-zero-data-retention-agreement-with-anthropic-what-products-does-it-apply-to , https://ai.google.dev/gemini-api/docs/usage-policies , https://docs.cloud.google.com/vertex-ai/generative-ai/docs/data-governance
- Whether Anthropic grants zero retention to a very small customer is unknown. Ask before choosing.

**International transfers**
- Sending to a US processor is a restricted transfer. It needs adequacy regulations, a safeguard, or an exception. ICO guide (updated 15 January 2026): https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/international-transfers/international-transfers-a-guide/
- UK route 1: the UK-US data bridge, in force since 12 October 2023. It only covers recipients certified to the Data Privacy Framework with the UK Extension. Check each provider at https://www.dataprivacyframework.gov/list **[not checked]**. Source for status: https://www.mcdermottlaw.com/insights/uk-us-data-bridge-an-extension-to-eu-us-data-privacy-framework/
- UK route 2: the IDTA or the UK Addendum to the EU SCCs, plus a transfer risk assessment. Anthropic's DPA includes the SCCs (Modules 2 and 3) and the UK Addendum.
- EU route: the EU-US Data Privacy Framework adequacy decision stands. The General Court upheld it on 3 September 2025 (Latombe). An appeal, C-703/25 P, was filed on 31 October 2025. I could not confirm whether it has been decided. **[UNVERIFIED as of today]** Keep SCCs in place as a fallback. Source: https://www.wilmerhale.com/en/insights/blogs/wilmerhale-privacy-and-cybersecurity-law/20251201-european-court-of-justice-to-review-challenge-to-eu-us-data-privacy-framework
- The data bridge has limits for special category data unless it is flagged as sensitive to the recipient. **[UNVERIFIED, SOLICITOR]**
- EU representative: a UK controller offering an app to people in the EU may need an Article 27 EU GDPR representative. The exemption for occasional processing without large-scale special category data may not fit once health data is involved. **[SOLICITOR]**

**Is a DPIA needed?**
- The ICO lists "innovative technology", including AI, as requiring a DPIA when combined with another high-risk criterion. Special category data and possibly vulnerable users are such criteria.
- The ICO also says a DPIA is good practice for any major new project.
- My reading: do one. It is a few pages and the best evidence you thought it through.
- Source: https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/accountability-and-governance/data-protection-impact-assessments-dpias/when-do-we-need-to-do-a-dpia/

**Short DPIA outline for this feature**
1. **Description.** One routine per user, up to five photo steps. Phone to Supabase Edge Function to [PROVIDER] and back. Output is one or two sentences. Where the output is stored and for how long. Optional email to one accepted contact through Resend.
2. **Purpose and necessity.** Why a description helps. Why on-device models were not used. Why the limit is one routine and five photos (data minimisation).
3. **Data and people.** Subscribers; bystanders in the photo; the email contact. Home interiors, locks, medication, documents in shot.
4. **Lawful basis.** Art 6(1)(a) plus Art 9(2)(a) for the user. Basis for bystanders (see section 3).
5. **Processors and transfers.** DPA links, transfer mechanism, risk assessment, retention settings.
6. **Risks.** Listed below.
7. **Measures and residual risk.** Map to the technical checklist in (b).
8. **Sign-off and review date.** Review on provider change, model change or new data sent.

Risks to score:
- Provider keeps the photo longer than the wording says.
- Photo or description ends up in logs, crash reports or backups.
- Description is wrong and someone relies on it (lock, hob, medication).
- Description reveals health data to the email contact, or sits in an inbox indefinitely.
- Bystander or a child is in the photo; the model describes or names them.
- Security detail (lock type, alarm panel, address on post) goes to a third party.
- Consent not properly recorded, or processing continues after withdrawal.
- Prompt injection from text in the photo changes the output that is emailed.

## 3. Other people in the photo, and emailing the description

**Bystanders**
- The user may be covered by the personal or household exemption. Pebble is not; a service provider remains a controller for what it processes (Recital 18 GDPR). **[from memory]**
- Pebble needs its own basis for incidental bystander data. Legitimate interests is the realistic one, supported by minimisation: short-lived processing, no identification, no storage.
- If the photo shows someone else's health data, for example a partner's named prescription, there is no obvious Article 9 condition without that person's consent. This is a real gap. **[SOLICITOR]**
- Practical mitigations: tell users to keep people out of shot; instruct the model not to describe people beyond "a person is visible", and not to read out names, addresses or prescription labels; strip EXIF and GPS; do not keep the photo.
- The privacy page already asks users not to capture other people (`web/privacy.html`, "Sensitive content you choose to add"). Repeat it on the switch-on screen.

**Emailing the description**
- This is a disclosure of the user's data, possibly health data, to another person. It needs its own explicit choice. A default-on setting the user can turn off is not explicit consent.
- Recommendation: ask a required yes or no question when AI is switched on for a routine that has a completion email, with no preselected answer.
- Resend then processes text that may reveal health. Check Resend's DPA and retention of message bodies. **[not checked]**
- Email cannot be recalled or deleted from the contact's inbox. Say so.
- The contact accepted on wording that says photos and checklist details are not included (`supabase/functions/_shared/shared_alert_email.ts:39`, `web/privacy.html` completion emails section, and `COPY_GUIDELINES.md`). All three need updating. Consider telling existing contacts in the first email that includes a description.
- Keep the email subject generic, as it is now.
- A contact may rely on a wrong description ("door is bolted"). Put the limitation in the email itself, not only in the app.

## 4. Store rules

### Google Play

| Rule | What it says (paraphrase) | URL |
| --- | --- | --- |
| User Data: prominent disclosure | Disclosure must be inside the app, describe the data, and explain how it is used or shared. | https://support.google.com/googleplay/android-developer/answer/10144311 |
| User Data: consent | Consent needs an affirmative action such as a tap or a check box; leaving the screen is not consent. | same |
| User Data: third-party AI | The same requirements apply to third-party AI integrations, and the developer stays responsible. | same |
| Data safety: collect | Collecting means transmitting data off the device. | https://support.google.com/googleplay/android-developer/answer/10787469 |
| Data safety: share | Transfers to a service provider acting for you, or made with prominent disclosure and consent, are not "sharing". | same |
| Data safety: ephemeral | Data held only in memory and kept no longer than needed for the request is ephemeral; it must still be entered in the form. | same |
| AI-Generated Content | Apps that generate content with AI must have in-app reporting or flagging of offensive content. | https://support.google.com/googleplay/android-developer/answer/13985936 |
| AI-Generated Content: scope | Scope examples are chatbots and image generation; productivity apps using AI to improve an existing feature are listed as out of scope. | https://support.google.com/googleplay/android-developer/answer/14094294 |
| Health apps declaration | Every published app must complete it; categories include medication schedule and adherence apps. | https://support.google.com/googleplay/android-developer/answer/14738291 |

**Data safety form changes (`docs/store/DATA_SAFETY_ANSWERS.md`)**
- **Photos:** already "Collected: Yes" for backup. Keep "Shared: No" if [PROVIDER] is a processor under a DPA. Update the notes to add the AI purpose.
- **Ephemeral:** you cannot mark Photos as ephemeral. Backup photos are stored, and the provider keeps AI photos for 30 or 55 days unless you have zero retention.
- **Health info:** currently "No", with a note not to change it unless a health feature is added. An AI that describes pill organisers is close to that line. The cautious answer is "Yes, optional, App functionality". **[SOLICITOR or owner decision]**
- **Other user-generated content:** add the AI description text, including when it is emailed.
- **Audio:** must change to "Yes" regardless of this feature (see Part B, F1).
- **AI-generated content policy:** an image-to-sentence feature is probably out of scope, but a "Report this description" link is cheap and removes the argument.
- **Health apps declaration:** if you market or template medication routines, decide whether "medication management" applies. Do not market the AI feature for medication.

### Apple

- **Guideline 5.1.2(i)**, the one direct quote: "You must clearly disclose where personal data will be shared with third parties, including with third-party AI". It goes on to require explicit permission first. https://developer.apple.com/app-store/review/guidelines/
- **5.1.1(i):** the privacy policy must identify the data collected, how, and all uses; confirm third parties give equal protection; and explain retention, deletion and how to revoke consent.
- **5.1.1(ii):** consent is needed for collection, paid functionality must not depend on granting it, and withdrawal must be easy.
- **5.1.1(ix):** apps in regulated fields, or that require sensitive user information, should be submitted by a legal entity and not an individual developer. **[SOLICITOR]** on whether optional health-revealing photos trigger this for a sole trader account.
- **1.4.1:** medical apps that could give inaccurate information get extra scrutiny. Another reason not to present this as a medication check.
- **5.1.3:** health data may not be used for advertising or data mining. You do neither.

**App Privacy label changes (`docs/store/APP_PRIVACY_LABELS.md`)**
- Apple counts data as collected if you or a partner can access it for longer than needed to service the request in real time. A 30 or 55 day provider log meets that. Source: https://developer.apple.com/app-store/app-privacy-details/
- **Photos or Videos:** already declared, linked, App Functionality. Add the AI purpose to your notes.
- **Other User Content:** add AI descriptions, since they are stored in history and may be emailed.
- **Health** ("any other user provided health or medical data"): consider declaring. Same judgement as Play.
- **Audio Data:** must be declared regardless (Part B, F1).
- Update `ios/Runner/PrivacyInfo.xcprivacy` to match, and review the camera purpose string.
- Put the provider name and the consent flow in the App Review notes.

## 5. Accuracy and liability wording

**How to describe it**
- Say what it does: it writes a sentence about what appears in the photo.
- Do not say it checks, confirms, verifies, detects or makes sure of anything. That fits `COPY_GUIDELINES.md` ("Show the record, not the reassurance").
- Never use medication as the marketing example. Use a door, a window or a bag.
- Anthropic's Commercial Terms require you to tell users that factual statements in outputs should not be relied on without checking. Your screen wording should do that in plain words.

**Consumer law risk**
- Consumer Rights Act 2015: digital content must be of satisfactory quality (s.34), fit for a purpose the consumer made known (s.35), and as described (s.36). Section 47 stops you excluding those. https://www.legislation.gov.uk/ukpga/2015/15/part/1/chapter/3
- So a disclaimer does not cure an over-claim. The description of the feature is the protection. If the store listing says "confirms your door is locked", s.36 bites whatever the terms say.
- Digital Markets, Competition and Consumers Act 2024: misleading actions and omissions are unfair commercial practices from 6 April 2025. The CMA can fine directly, up to 10% of turnover. https://www.gov.uk/government/publications/unfair-commercial-practices-cma207
- Liability for death or personal injury caused by negligence cannot be excluded (CRA s.65). **[from memory]** A user who skips medication or leaves a hob on because of a wrong sentence is the scenario to design against. **[SOLICITOR]**
- EU AI Act Article 50 transparency duties apply from 2 August 2026: tell people when they deal with an AI system, and mark synthetic text. Whether Pebble is a provider or a deployer, and whether any Digital Omnibus delay applies, I could not confirm. **[UNVERIFIED, SOLICITOR]** Labelling every description "Written by AI" is sensible either way. https://artificialintelligenceact.eu/article/50/

**Honest disclaimers (use these ideas, in the app's voice)**
- "The description is the AI's reading of the photo. It can be wrong."
- "It can't tell whether a door is locked, something is switched off or medication has been taken."
- "Look at the photo yourself if it matters."
- Avoid "for informational purposes only", "no warranty" and similar. They tell the user nothing and do not help under s.47.

## 6. US angle, briefly

- **FTC.** Section 5 covers deceptive privacy promises and exaggerated AI claims. The FTC has brought AI-claims cases (Operation AI Comply, September 2024) and treats health-adjacent app data seriously. If you say "nothing else is sent" or "not kept", it must be literally true. **[FTC pages not fetched today; one URL returned 404]** Start at https://www.ftc.gov/business-guidance/privacy-security/health-privacy
- **Health Breach Notification Rule.** Probably not engaged, since Pebble is not a personal health record drawing from several sources. **[SOLICITOR, low priority]**
- **Washington My Health My Data Act.** Likely to bite if Washington residents use the feature with medication photos.
  - "Consumer health data" includes use of prescribed medication and data inferred by algorithms or machine learning.
  - No revenue threshold. Small businesses are still covered.
  - Consent is needed to collect beyond what the requested service requires, and separate consent to share.
  - It expects a separate consumer health data privacy policy linked from the homepage. **[from memory]**
  - Enforced through the Consumer Protection Act, which includes private claims.
  - Source: https://app.leg.wa.gov/RCW/default.aspx?cite=19.373&full=true
  - Nevada has a similar law without the private right of action. **[from memory]**
- **Illinois BIPA.** Not relevant as long as you do no face, voice or fingerprint template processing. Describing a scene is not that. Keep the instruction that the model must not identify people, and do not add face features later without revisiting this.
- **California CCPA.** Applies only above about $26.6m revenue, 100,000 California consumers or households, or 50% of revenue from selling or sharing data. Pebble is far below. A posted privacy policy is still expected under CalOPPA. **[threshold from secondary sources]** https://www.jacksonlewis.com/insights/navigating-california-consumer-privacy-act-30-essential-faqs-covered-businesses-including-clarifying-regulations-effective-1126
- **COPPA.** Not directed at under-13s. Keep it that way.

---

## (a) Draft wording

Notes on voice: sentence case, contractions, no em dashes, "check" not "tick", "phone" not "device", per `COPY_GUIDELINES.md`. Square-bracket alternatives depend on the technical checklist in (b). Pick the one that is true.

### Switch-on screen

**Title:** Turn on AI photo descriptions for "[Routine name]"

**Body:**

> When you take a photo in this routine, Pebble sends it to [PROVIDER], an AI company in the USA. [PROVIDER] sends back one or two sentences saying what's in the photo, such as "A white front door with the bolt across." Pebble shows that with the photo.
>
> **What's sent.** The photos from this routine's photo steps, up to five, each time you run it. Nothing else: not your name, your email address, the routine's name, your other routines or any other photos.
>
> **What happens to the photo.** Pebble passes it to [PROVIDER] and doesn't keep a copy for this. [PROVIDER doesn't keep it once it has replied. / PROVIDER deletes it within 30 days.] It doesn't use your photos to train its AI.
>
> **What the photo might show.** Your home, your locks, your medication. A photo of medication can say something about your health.
>
> **The description can be wrong.** It's the AI's reading of the photo. It can't tell whether a door is locked, something is switched off or medication has been taken. Look at the photo yourself if it matters.
>
> **Other people.** Keep other people, and anything with their name on it, out of these photos.
>
> This is optional and for people aged 18 or over. Pebble works the same without it. You can turn it off at any time in this routine's settings.

**Check box (unchecked):**

> I agree to Pebble sending the photos from this routine to [PROVIDER] to be described, including photos that show my medication or other details about my health.

**Buttons:** `Turn on` (disabled until the box is checked) and `Not now`

**Link:** How AI photo descriptions work

### Per-routine email question

Shown only if the routine has a completion email contact. No answer preselected.

**Title:** Add the descriptions to the completion email?

> This routine emails [contact email] when you finish it. Pebble can add the AI descriptions to that email, for example "Front door: A white front door with the bolt across."
>
> The photos are never emailed. [Contact email] will be able to read whatever the descriptions say, including anything about medication. Once an email is sent, Pebble can't take it back or delete it from their inbox.

**Buttons:** `Add descriptions` and `Don't add`

**Supporting line after choosing:** You can change this in the routine's completion email settings.

**Line to add to the email itself, above the descriptions:**

> Written by AI from [sender email]'s photos. It can be wrong and doesn't confirm anything was done.

### Settings text to turn it off

**Row:** AI photo descriptions. On for "[Routine name]".

**Detail:**

> Photos from this routine's photo steps are sent to [PROVIDER] to be described. Turn this off and Pebble stops sending them straight away.

**Button:** `Turn off`

**Confirmation:**

> Turn off AI photo descriptions?
>
> Pebble will stop sending photos from "[Routine name]" to [PROVIDER]. [Descriptions already in your history are deleted too. / Descriptions already in your history stay until that history is removed.] Emails already sent can't be taken back.

**Buttons:** `Turn off` and `Keep on`

**After:** AI photo descriptions are off.

**When Premium ends or the user signs out:** AI photo descriptions are off because [Premium has ended / you signed out]. No photos are being sent.

### New privacy policy section

> **AI photo descriptions**
>
> Signed-in Premium users can turn on AI photo descriptions for one routine. It is off unless you turn it on, and you can turn it off at any time in that routine's settings.
>
> When it is on, each photo you take in that routine's photo steps (up to five) is sent through Pebble's server to [PROVIDER] in the USA. [PROVIDER] returns one or two sentences describing what is in the photo. Pebble sends the photo only. It does not send your name, email address, account ID, routine name or any other content.
>
> Pebble does not store the photo for this feature. [PROVIDER does not keep the photo or the description after replying, except where the law requires it or to deal with misuse. / PROVIDER deletes the photo and description within 30 days.] [PROVIDER] acts on our instructions under its data processing terms and does not use your photos to train its models.
>
> The description is saved with your routine history on your phone. If cloud backup is on, it is backed up with that history. If you choose to add descriptions to a completion email, they are sent to your contact by Resend. Photos are never emailed.
>
> Photos may show private things such as your home, your locks or your medication, and a photo of medication can reveal information about your health. We only process these photos this way with your explicit consent, which you give on the switch-on screen. We keep a record of that consent: when you gave it, the wording you saw, the provider named and the version of this policy. To withdraw consent, turn the feature off. Pebble stops sending photos straight away.
>
> Descriptions are written by AI and can be wrong. They do not confirm that anything was done.
>
> Please keep other people, and anything showing their name or health details, out of these photos.
>
> This feature is for people aged 18 or over.

Also needed elsewhere on the privacy page:
- **Why we use data:** add "AI photo descriptions" to the Consent bullet, and say explicit consent where health details are involved.
- **Providers:** add "[PROVIDER] (USA) for AI photo descriptions, only if you turn them on."
- **International transfers:** add [PROVIDER] to the list of triggers.
- **Retention table:** add a row. "Photos sent for AI descriptions: not stored by Pebble. [Not stored by PROVIDER / deleted by PROVIDER within 30 days]. Descriptions: kept with your history."
- **Completion emails:** change "Photos and checklist details are not included" to "Photos and checklist details are not included. AI photo descriptions are included only if you choose to add them."
- **Short version box and in-app "No ads or AI training":** still true if the provider does not train. Consider "Pebble doesn't train AI on your content, and neither does any provider we use."

### Addition to the terms

> **AI photo descriptions**
>
> AI photo descriptions are an optional Premium feature for people aged 18 or over. If you turn them on, an AI service run by [PROVIDER] writes a short description of each photo in the routine you chose.
>
> A description says what the AI thinks is in the photo. It can be wrong or miss things. It does not check or confirm that a door is locked, an appliance is off, medication has been taken or any step was done. Don't rely on it for anything that affects your safety, your health or anyone else's. Look at the photo, or check for yourself.
>
> If you add descriptions to a completion email, tell your contact the same thing.
>
> Only use photos you have the right to share, and keep other people out of them where you can.
>
> We may change the AI provider. If we do, we will ask you to agree again before sending any photos to the new one.
>
> Nothing in this section limits your legal rights as a consumer.

Also add "AI photo descriptions" to the feature list in "What Pebble does", and add an age line to "Agreement" or "Accounts" if you adopt 18+ generally.

### Entries for LEGAL_PROCESSOR_MAP.md

Under "Third-Party Services Present In Code":

> - [PROVIDER]: AI photo descriptions, called only from the `[function-name]` Edge Function (`[api host]`, `[PROVIDER]_API_KEY`). Runs only for a signed-in Personal Premium user who has an accepted `ai_photo_description` consent record for that routine. Receives the photo bytes (re-encoded, EXIF and GPS removed) and a fixed prompt. Does not receive the account ID, email address, routine name, step name or device identifiers. Returns one or two sentences. Provider retention: [zero data retention agreement dated … / deleted within 30 days]. No model training on inputs. Processor under [DPA link]; transfer safeguard: [UK-US data bridge / UK Addendum to SCCs / EU SCCs]. The photo may show health details (medication), so this processing relies on explicit consent.
> - Resend: now also receives AI description text in completion emails, only where the sender chose to add descriptions for that routine.

Under "Outbound Network Calls Found":

> - Supabase Edge Function `[function-name]`, which calls `[api host]`.
> - Supabase table `ai_photo_consents` (or the name used): user ID, routine ID, consent text version and hash, provider, privacy and terms versions, consented and withdrawn timestamps.

Under "Store Privacy Data Categories To Declare If Enabled":

> - Photos sent to [PROVIDER] for AI descriptions when the user turns the feature on. Not shared (processor). Not ephemeral unless provider zero retention is confirmed.
> - AI description text, as user content, in history, backup and completion emails.
> - Health info: decision recorded here, with date and reason.

Under "Launch Checks":

> - Before changing AI provider, model, prompt contents or retention settings, update the consent text version, this map, `web/privacy.html` and both store forms, and re-ask users.

Also correct the stale entries noted in Part B (F1, F6).

---

## (b) What must be true technically for the wording to be honest

**Consent and gating**
1. The server refuses to call [PROVIDER] unless it finds a current consent row for that user and routine. A client-side flag is not enough.
2. The consent row stores: user ID, routine ID, exact consent text version and hash, provider name, privacy and terms versions actually shown, real app version, timestamp.
3. Withdrawal writes a timestamp and takes effect on the next request. Any queued or retrying upload is cancelled.
4. The feature turns off when Premium ends, on sign-out and on account deletion. Turning it back on asks again if the wording or provider has changed.
5. The server enforces one routine per user and five photo steps.
6. Changing provider or model region invalidates existing consents.
7. The email-inclusion choice is stored separately, per routine, with its own timestamp. No default.

**"Nothing else is sent"**
8. The request to [PROVIDER] contains only the image and a fixed prompt. No user ID, email, routine name, step title, location or device ID. If you send the step title to improve the description, the screen wording must change.
9. EXIF and GPS are stripped before sending. The backup path already re-encodes photos according to `APP_PRIVACY_LABELS.md`; I did not verify that code, and the AI path needs the same.
10. Only photos from that routine's photo steps are sent. Photos picked from the library for other routines are never sent.
11. Requests go from Pebble's server, so [PROVIDER] does not see the user's IP address.

**"Pebble doesn't keep a copy for this"**
12. The Edge Function holds the image in memory only. No write to Storage, a table or a temp file.
13. The image and the description are never written to Supabase function logs, error messages or Sentry. Note `crash_reporting.dart` already keeps print output out of breadcrumbs; keep it that way.
14. If cloud backup is on, the same photo is stored for backup under the backup consent. The wording says "for this", which covers it. Do not shorten it to "Pebble doesn't keep your photo".

**"[PROVIDER] doesn't keep it" and "doesn't train"**
15. You hold written confirmation of the provider's retention for your account: a zero-retention agreement, or the documented default. Use the matching sentence.
16. With Google, you are on Paid Services, and you have checked whether zero retention is available on the product you use.
17. You have accepted the provider's DPA and saved a dated copy, and you know which transfer mechanism applies.
18. Features that store data on the provider side (file uploads, prompt caching with long lifetimes, batch APIs) are not used unless covered.
19. You have checked the provider's sub-processor list and where processing happens.

**Descriptions**
20. The prompt tells the model to describe objects only, not to identify or describe people, not to read out names, addresses or prescription labels, and not to state that something is locked, off, safe or taken.
21. Text found inside the photo is treated as content, not instructions. Output is length-capped and escaped before it goes into an email.
22. Every description is labelled as AI-written in the app and in the email.
23. If the call fails, the routine still completes and the app says "Couldn't get a description." It does not retry indefinitely or hold the photo.
24. Where descriptions are stored (local history, cloud backup, email log `shared_alert_events`) matches the policy, and their retention follows the existing 48-hour and 21-day rules.
25. On withdrawal and on account deletion, the stored descriptions are handled as the confirmation dialog says.
26. A "Report this description" action exists, at least by email.

**Email**
27. Descriptions are added only when the per-routine choice is "Add descriptions" and the contact is still accepted.
28. The invitation email text and the completion email carry the updated "what's included" wording.
29. The Resend log retention for message bodies is known and reflected in the policy.

**Paperwork**
30. DPIA written and dated. Record of processing updated. `LEGAL_PROCESSOR_MAP.md`, `web/privacy.html`, `web/terms.html`, `DATA_SAFETY_ANSWERS.md`, `APP_PRIVACY_LABELS.md` and `PrivacyInfo.xcprivacy` updated before release.

---

## (c) Questions for a solicitor, ranked

1. Are medication photos, and AI sentences about them, special category data in our setup? Is the proposed explicit consent wording enough under UK and EU GDPR?
2. What is our position on other people's data in a photo, especially someone else's medication, where we have no consent from them?
3. Is a required yes or no choice sufficient for adding descriptions to the completion email, and do we owe the contact any notice?
4. If someone relies on a wrong description and is harmed, what is our exposure under the Consumer Rights Act and in negligence, and does the proposed wording reduce it? Should I be trading through a limited company and carrying insurance before launching this?
5. Does Apple guideline 5.1.1(ix) (legal entity, not individual, for apps needing sensitive information) apply to me as a sole trader?
6. Which transfer mechanism should I rely on for each provider from the UK and from the EU, given the pending DPF appeal, and is a transfer risk assessment needed?
7. Does Anthropic's DPA, which lists no special categories, cover health-revealing photos? Same question for Google's terms on medical use.
8. Do I need an EU representative under Article 27 EU GDPR once health data is involved?
9. Does the Washington My Health My Data Act apply, and do I need a separate consumer health data policy and consent flow for US users? Should I geo-restrict the feature instead?
10. Is 18+ by self-declaration adequate, and should the whole app's terms carry an age clause to match the Play listing?
11. Does EU AI Act Article 50 apply to Pebble, as provider or deployer, and what labelling does it require?
12. Should I answer "Health" on the Play Data safety form and the Apple privacy label, and does Play's Health apps declaration category for medication apps apply?
13. Is a DPIA mandatory here, and is there any reason to consult the ICO first?
14. Existing gaps: ICO fee and registration number, a published postal address, and the data protection complaints process required under the Data (Use and Access) Act from 19 June 2026.
15. The voice tip backup issue in Part B: do I need to re-obtain backup consent from existing users, and does it need reporting to anyone?

---

# Part B: checking the legal-page copy rewrite

**Scope.** I diffed `origin/main..origin/integration/launch-pass` for the five paths. I did not isolate PR #5's commits, so the diff may include other merges. It is small: 41 insertions, 45 deletions.

**Verdict.** The claim holds for most of it. No disclosure was removed outright and no retention period or processor changed. Six sentences shifted slightly, listed below. Everything not listed I judged "Same meaning", including all headings other than B5 and B6, the terms page changes ("designed for" to "meant for"), the footer text, and the delete-account lede and steps.

## Non-"Same meaning" items

**B1. Privacy page lede. Promise strengthened, and now inaccurate at the edges.** `web/privacy.html:48-50`
- Before: "Pebble Routines is a local-first routine support app. Most routine content stays on your device unless you choose account and cloud backup features."
- After: "Pebble Routines is a routine app that keeps your data on your phone by default. Most routine content stays there unless you choose to use an account or cloud backup."
- Why it matters: "your data" is wider than "routine content". By default, with no account, RevenueCat receives an install ID and device details at launch, and Sentry receives crash reports with no opt-out (`docs/store/DATA_SAFETY_ANSWERS.md`, Device IDs and Crash logs rows). Also "and" became "or": signing in alone does not upload routine content.
- Suggested: "Pebble Routines keeps your routines, photos and history on your phone unless you sign in, have Premium and turn on cloud backup. Some technical data, such as subscription checks and crash reports, is sent without an account. This page explains what and why."

**B2. In-app backup summary. Promise strengthened slightly.** `lib/features/settings/ui/legal_about_screen.dart:83`
- Before: "…Pebble may back up supported routine data, proof photos, sync records, and account metadata in Supabase."
- After: "…Pebble can back up your routine data, proof photos, sync records and account details to Supabase."
- Why it matters: dropping "supported" implies everything is backed up. It also still omits voice tips, which are uploaded (F1).
- Suggested: "If you sign in, have Premium and turn on cloud backup, Pebble backs up your routines, recent history, proof photos and voice tips to Supabase, along with the account details needed to do that."

**B3. In-app consent summary. Promise strengthened, disclosure slightly weakened.** `legal_about_screen.dart:87-89`
- Before: title "Sensitive content consent"; "Before cloud backup uploads supported routine data, Pebble asks you to confirm that backup may include private details you chose to add."
- After: title "Asking before backup"; "Before backup uploads anything, Pebble asks you to confirm that it may include private details you added."
- Why it matters: "anything" is absolute. The upload gate is there (`cloud_sync_coordinator.dart:208-211`), but I only confirmed it for routine sync, not every write. The title no longer signals sensitive content, and this consent is the one you rely on for health details.
- Suggested: title "Asking before backup"; body "Before backup uploads your routines or photos, Pebble asks you to confirm that they may include sensitive details, such as information about your health or home."

**B4. In-app sign-out sentence. Promise strengthened.** `legal_about_screen.dart:122`
- Before: "…It does not delete cloud data, cancel subscriptions, or remove local data."
- After: "…It doesn't delete cloud data, cancel a subscription or remove anything stored on the phone."
- Why it matters: "anything" is literally untrue, since the sign-in session is removed. The auth controller's `signOut` does not clear routines (`auth_state_provider` `signOut`, lines 171-185); I did not read the repository-level `signOut`.
- Suggested: "…or remove the routines and photos saved on the phone."

**B5. In-app backup limits. Promise strengthened slightly.** `legal_about_screen.dart:134`
- Before: "Cloud backup reduces some risk but is not permanent archive storage."
- After: "Cloud backup lowers the risk of losing data, but it is not a permanent archive."
- Why it matters: the hedge "some" went. `web/terms.html` still says "can reduce some risk".
- Suggested: "Cloud backup lowers some of the risk of losing data, but it is not a permanent archive."

**B6. Delete-account page, photo retention. Promise strengthened.** `web/delete-account.html:109-111`
- Before: "Pebble proof-photo backup is designed around a short rolling retention window."
- After: "Proof-photo backup only keeps photos for a short, rolling period."
- Why it matters: a design intention became a statement of fact. It depends on the daily clean-up job running, and that function refuses to run if its secret is not configured (`supabase/functions/cleanup-proof-retention/index.ts`). I could not check the deployed cron.
- Suggested: "Backed-up proof photos are kept for a rolling 21 days and then removed by a daily clean-up, unless you delete them earlier." Use it only once you have seen the job succeed in production.

**B7. Support page heading. Disclosure weakened in prominence.** `web/support.html:77`
- Before: heading "Important note" above the not-an-emergency-or-medical-service paragraph.
- After: heading "What Pebble is for".
- Why it matters: the text is unchanged, but the heading no longer flags a limitation.
- Suggested: "What Pebble is and isn't for".

**Lower-level notes, Same meaning but worth knowing**
- `web/support.html:56`: "access" became "getting a copy of your data". Narrower in law, but "other data questions" covers the rest.
- `legal_about_screen.dart:116`: "routine support and reassurance app" became "routine and checklist app". The disclaimer list is intact, and losing "reassurance" is an improvement.
- "Guidance audio" became "voice tips" in the app screen only. The web pages still say "guidance audio". Same thing, two names.
- `web/delete-account.html:37`: "Delete Account" became "Delete account", which now matches the button in `account_hub_screen.dart:210`.

## Factual problems regardless of the rewrite

**F1. Voice tip recordings are uploaded, and the pages say they are not. High.**
- Code: `lib/features/sync/guidance_audio_cloud_backup.dart` uploads clips to `users/<uid>/guidance_audio/` in the `routine-proofs` bucket. It is called from `cloud_sync_coordinator.dart:650`. Retention is set to 3,650 days, and `cleanup-proof-retention/plan.ts` deliberately skips these files.
- Wrong statements:
  - `web/privacy.html:141-143`: guidance audio files "currently stay on your device".
  - `docs/store/DATA_SAFETY_ANSWERS.md`: Voice or sound recordings "No".
  - `docs/store/APP_PRIVACY_LABELS.md`: Audio Data "Not collected".
  - `LEGAL_PROCESSOR_MAP.md` and `LEGAL_PUBLICATION_CHECKS.md`: audio stays local.
  - The recorded consent sentence in `cloud_backup_consent_provider.dart` lists routines, proof photos and history, not voice recordings.
  - The retention table has no row for voice tips, which are kept for the life of the routine, not 21 days.
- I read the code; I did not run the app or inspect the production bucket.
- Suggested policy wording: "If backup is on, Pebble also backs up your voice tip recordings. They are kept until you replace or remove them, delete the routine or delete your account."
- The consent sentence is a recorded text matched by hash, so changing it means a new consent version and re-asking users.

**F2. The consent record does not hold the versions the policy says it does. Medium.**
- `web/privacy.html:147-149` says Pebble records the app, privacy and terms versions shown at the time.
- `cloud_backup_consent_provider.dart` hard-codes app version `1.0.0+1` and privacy and terms versions `2026-05-04`. The pages are dated 3 October 2026 and the build is 1.0.0+31.

**F3. Crash report wording is out of step with the code. Low to medium.**
- `web/privacy.html:225` says the breadcrumb trail can include internal identifiers, with an owner note to fix it. `crash_reporting.dart:32` already sets `enablePrintBreadcrumbs = false`, and the store docs say it is fixed.
- `web/privacy.html` also says Pebble removes user details from crash reports before sending. `DATA_SAFETY_ANSWERS.md` notes that `beforeSend` does not run for native crashes, which carry a random Sentry installation ID.
- Suggested: "Crash reports don't include your account ID, name or email address. They do include a random ID for the app installation."

**F4. Owner TODO comments are in the public HTML source. Low.**
- `web/privacy.html` ships HTML comments about the ICO fee, unaccepted provider terms, a postal address and the unpruned history rows. Anyone can read them with "view source". Move them to `docs/store/OWNER_NOTES.md`.

**F5. Unresolved items those comments describe. Medium.**
- No ICO registration number or statement of exemption.
- No postal address. **[SOLICITOR]** on whether one is required for consumer contracts.
- Provider data processing terms not yet confirmed as accepted, so the transfers paragraph ("such as… or…") is a hedge and not a statement of what applies.
- The service that sends sign-in code emails is not named (`web/privacy.html:293`).
- No EU representative named. May be required. **[SOLICITOR]**
- No stated complaints process. The Data (Use and Access) Act requires one from 19 June 2026 according to the secondary sources I found. **[UNVERIFIED]** The page does invite contact first; make it explicit.

**F6. LEGAL_PROCESSOR_MAP.md is stale. Medium for your own records.**
- "Last scanned: July 14, 2026".
- The Edge Function list omits `request-shared-alert-contact`, `send-routine-completion-alert`, `shared-alert-accept`, `shared-alert-decline`, `shared-alert-block`, `revenuecat-sync-entitlement` and `cleanup-proof-retention`.
- It lists `verify-purchase` as called; `DATA_SAFETY_ANSWERS.md` says the app no longer calls it.

**F7. Age statements disagree. Medium.**
- Play listing: 18 and over. Privacy page: not directed at under-13s. Terms: no age clause. Pick one position.

**F8. Account deletion and processors. Low to medium.**
- The `delete-account` function removes storage files and the auth user, and every `auth.users` reference cascades. I saw no call to delete the RevenueCat customer record. The policy says RevenueCat keeps its own records, which is honest, but erasure requests should normally reach processors. **[SOLICITOR]**
- The "normally deleted within 30 days" wording is cautious against an in-app deletion that is immediate. Fine.
- Resend's own retention of sent email content is not in the retention table. **[not checked]**

**F9. Delete-account page tidy-ups. Low.**
- Lines 22-23 show the support address twice.
- No "last updated" date.
- Footer calls the terms "Terms and Conditions"; the app says "Terms of Use" and the page is headed "Terms".

**F10. Sentences that become false when the AI feature ships.**
- Completion emails: "Photos and checklist details are not included" in `web/privacy.html`, `shared_alert_email.ts:39` and `COPY_GUIDELINES.md`.
- `legal_about_screen.dart:71, 77, 83, 101`: photos leave the phone only with backup, and the camera is used only for proof photos.
- `DATA_SAFETY_ANSWERS.md` Health info note, and both store forms' photo rows.

## What I could not verify

- Production state: whether the clean-up cron runs, what is in the storage bucket, which provider DPAs are accepted.
- Whether the CJEU has ruled on the DPF appeal.
- Provider DPF and UK Extension certification, and current sub-processor lists.
- Google Vertex AI zero-retention details, Anthropic's guidance on minors, Resend's DPA and retention.
- FTC pages (one returned 404), EDPB guidelines and CJEU cases were cited from memory.
- The EXIF stripping claim for backup uploads, and the repository-level sign-out code.
- Whether the diff contains only PR #5.

## Source list

ICO
- https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/consent/what-is-valid-consent/
- https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-is-special-category-data/
- https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-are-the-conditions-for-processing/
- https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/accountability-and-governance/data-protection-impact-assessments-dpias/when-do-we-need-to-do-a-dpia/
- https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/international-transfers/international-transfers-a-guide/
- https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/children-and-the-uk-gdpr/what-are-the-rules-about-an-iss-and-consent/

Legislation and regulators
- https://www.legislation.gov.uk/ukpga/2015/15/part/1/chapter/3
- https://www.gov.uk/government/publications/unfair-commercial-practices-cma207
- https://artificialintelligenceact.eu/article/50/
- https://app.leg.wa.gov/RCW/default.aspx?cite=19.373&full=true
- https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-052020-consent-under-regulation-2016679_en (not re-fetched)
- https://www.dataprivacyframework.gov/list (not checked)

Status of transfers and UK reform (secondary)
- https://www.wilmerhale.com/en/insights/blogs/wilmerhale-privacy-and-cybersecurity-law/20251201-european-court-of-justice-to-review-challenge-to-eu-us-data-privacy-framework
- https://www.mcdermottlaw.com/insights/uk-us-data-bridge-an-extension-to-eu-us-data-privacy-framework/
- https://www.kennedyslaw.com/en/thought-leadership/article/2026/the-data-use-and-access-act-2025-commencement-dates-and-planned-guidance-for-2026
- https://www.financialinstitutionsnews.com/2026/02/09/data-use-and-access-act-2025-majority-of-changes-related-to-data-protection-now-in-force/
- https://www.jacksonlewis.com/insights/navigating-california-consumer-privacy-act-30-essential-faqs-covered-businesses-including-clarifying-regulations-effective-1126

Google Play
- https://support.google.com/googleplay/android-developer/answer/10144311
- https://support.google.com/googleplay/android-developer/answer/10787469
- https://support.google.com/googleplay/android-developer/answer/13985936
- https://support.google.com/googleplay/android-developer/answer/14094294
- https://support.google.com/googleplay/android-developer/answer/14738291

Apple
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/app-store/app-privacy-details/

Providers
- https://www.anthropic.com/legal/commercial-terms
- https://www.anthropic.com/legal/data-processing-addendum
- https://www.anthropic.com/legal/aup
- https://www.anthropic.com/subprocessors (not fetched)
- https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data
- https://privacy.claude.com/en/articles/8956058-i-have-a-zero-data-retention-agreement-with-anthropic-what-products-does-it-apply-to
- https://ai.google.dev/gemini-api/terms
- https://ai.google.dev/gemini-api/docs/usage-policies
- https://docs.cloud.google.com/vertex-ai/generative-ai/docs/data-governance (content did not load)

Repo files read (all under `C:\development\Pebble`, at `origin/integration/launch-pass`)
- `web/privacy.html`, `web/terms.html`, `web/delete-account.html`, `web/support.html`
- `lib/features/settings/ui/legal_about_screen.dart`
- `lib/features/sync/guidance_audio_cloud_backup.dart`, `lib/features/sync/cloud_sync_coordinator.dart`
- `lib/features/subscription/providers/cloud_backup_consent_provider.dart`
- `lib/core/monitoring/crash_reporting.dart`
- `lib/features/account_backup/ui/account_hub_screen.dart`
- `supabase/functions/cleanup-proof-retention/index.ts` and `plan.ts`, `supabase/functions/delete-account/index.ts`, `supabase/functions/_shared/shared_alert_email.ts`, `supabase/functions/request-account-deletion/index.ts`
- `supabase/migrations/020_completion_email_hardening.sql`
- `COPY_GUIDELINES.md`, `LEGAL_PROCESSOR_MAP.md`, `LEGAL_PUBLICATION_CHECKS.md`
- `docs/store/DATA_SAFETY_ANSWERS.md`, `docs/store/APP_PRIVACY_LABELS.md`, `docs/store/GOOGLE_PLAY_LISTING.md`