# Pebble Copy Guidelines

Last updated: 5 October 2026

This is the working reference for user-facing Pebble copy. Use it when reviewing
app screens, templates, website text, store copy, emails, and shared-link pages.

Pebble copy should help users understand what to do next, what is stored where,
and what the app can and cannot do.

## How Pebble sounds

Pebble should read as if one sensible person wrote every word: someone who
knows the app well, respects the reader's time, and has met people who go back
to check the front door. Plain, specific, a little warm. Never flat, never
salesy, never soothing.

### Voice principles

1. **Say what happens, in the order it happens.** "Pebble sends them an invite.
   They can accept or decline." Not a promise about how it will feel.
2. **Use concrete nouns.** The straighteners, the back door, the hob, 08:02.
   Not "essentials", "items" or "your routine journey".
3. **Write in full, ordinary sentences.** Use contractions (don't, you'll,
   can't). Vary the length. A short sentence is fine when it carries
   information ("Backup is off."), not when it is there for effect.
4. **Sentence case everywhere,** including titles, buttons and template
   names. Proper names keep their capitals: Personal Premium, Google Play,
   theme names such as High Noon.
5. **Buttons are short verbs:** Start, Take photo, Save reminder, Done.
6. **Errors say what went wrong, then what to do,** in one or two sentences:
   "Couldn't save the photo. Try again." Drop "Please" and "We're sorry".
7. **Don't say the same thing twice.** If the title says it, the subtitle adds
   something new or isn't there.
8. **Show the record, not the reassurance.** "Checked at 08:02, with a photo",
   never "You're safe" or "No need to go back".
9. **UK English:** colour, personalise, cancelled, no serial comma unless it
   avoids confusion.

### Avoid

- Em dashes. Use a full stop or a comma.
- "Not X. Not Y. Just Z." and "It's not X, it's Y".
- Rule-of-three rhythm and slogan fragments: "Calm. Clear. Confident.",
  "Small routines. Lasting ripples."
- Sentences that trail off, and colon reveals ("Here's the thing:").
- Stacked adjectives: "a warm, grown-up, quietly expressive surface".
- Buzzwords: seamless, effortless, elevate, empower, unlock your..., journey,
  peace of mind, delightful, magic, crafted, designed to, simply, ensure,
  nudge, ripple, "whether you're X or Y", "take the guesswork out",
  "at your fingertips".
- "Just" as a softener, exclamation marks, and emoji as decoration.
- Telling people how they feel ("We know how stressful...", "You've got
  this", "Let's get started!").
- Reassurance and certainty claims: total confidence, never wonder, never
  slip your mind, kept safe, safe copy, no going back to check.
- Committee voice: "Your data is securely stored". Say who does what: "Pebble
  keeps your routines on this phone."

### Owner decisions

- **Say "this phone", not "this device",** even on tablets (owner, 5 October
  2026). "Saved on this phone." The legal pages keep their own wording.
- **The Home tagline is "Small steps, big ripples".** It is the reason the app
  is called Pebble and is not to be rewritten (owner, 5 October 2026). It is
  the one allowed use of "ripple".

### Before and after (from the app)

| Before | After |
| --- | --- |
| For routines you repeat. Not goals. Not streaks. | For the checks you already do. |
| Step out the door with total confidence. | Every check is saved with the time. |
| The doubt hits halfway down the street. Open Pebble: you ticked it off two minutes ago, with a photo. No going back to check. | You're halfway down the street when you start to wonder. Open Pebble and you can see you checked them at 08:02, with a photo. |
| Stay on track. Set up local, secure nudges to ensure your essential routines never slip your mind. | No reminders yet. Pebble can send a notification at the time you usually do "Leaving the house". |
| YOUR NEXT RIPPLE | UP NEXT |
| Never wonder twice. | Keep three weeks of checks. |
| Three weeks of answers, safe if you reinstall or change phone. | Three weeks of history, backed up in case you reinstall or change phone. |
| One tap and Pebble starts keeping a safe copy of your routines. | Turn it on and Pebble starts backing up your routines. |
| A deep, lush forest green surface with a natural feel. | Deep forest green. |
| Could not save photo. Please try again. | Couldn't save the photo. Try again. |

### Strings that must not be reworded casually

Some messages double as markers that code matches on. Change them only with
the matching code and tests:

- `lib/features/subscription/data/entitlement_flow_messages.dart` and the
  account-ownership messages in `lib/features/sync/local_data_ownership_guard.dart`.
- Backup status labels compared in code: "Checking backup", "Turning on
  backup", "Backup off", "Sign in".
- Server errors the app matches in `routine_reminders_screen.dart`
  ("Personal Premium is required", "Shared alert contact was not found" and
  others).
- The backup consent sentence in `cloud_backup_consent_provider.dart`, which
  is a recorded consent text.
- Photo markers in template steps: "(Take a photo)".

## Core Voice

Pebble is a grounded, matter-of-fact routine tool. It should feel reliable,
clear, and useful.

The voice is direct, practical, steady and clear.

Do:

- Sound useful, certain, and grounded.
- Use short, plain messages.
- Treat the user like a capable adult.

Good examples:

- "Routine ready."
- "Photo saved."
- "Backup is off."
- "Saved on this phone."

Avoid:

- Therapeutic language.
- Emotional reassurance.
- Anxiety-based sales copy.
- Productivity-bro language.
- Overly soft hand-holding.

Avoid examples:

- "You're safe now."
- "Relax, everything is okay."
- "Take a deep breath."
- "Unlock peace of mind."
- "Worry less."

## Language And Vocabulary

Use global plain English with UK spelling where spelling is unavoidable. Copy
should work naturally for users in the UK, US, Australia, Canada, and similar
markets.

Prefer neutral wording over strongly regional nouns.

| Avoid | Use instead |
| --- | --- |
| Torch / flashlight | Light |
| Bin / trash | Rewrite around the action, such as "Empty the kitchen waste" |
| Nappies / diapers | Baby items |
| Holiday / vacation | Trip |
| Tick | Check |
| Mobile | Phone |

Use UK spelling when needed:

- personalise
- grey
- behaviour

Where a word risks feeling regional or awkward, rewrite the sentence instead.

## Photos And Records

Keep the stakes everyday and functional. Words like "evidence" can make Pebble
sound legal, clinical, or workplace-focused.

Use:

- Photo.
- Saved photo.
- Photo required.
- Photo check.
- Save a copy to Photos.

Use only when naming the feature:

- Proof photos.

Avoid:

- Evidence.
- Proof evidence.
- Legal record.
- Verification, unless describing a technical account or store check.
- Permanent record.

## Completion Emails

Be literal about what the feature does. Do not imply an emergency safety network
or live monitoring.

Use:

- Completion email.
- Send completion email.
- Email contact.

Avoid:

- Trusted contacts.
- Emergency alerts.
- Safety contact.
- Shared reminders.
- Monitoring.
- Check-in network.

Recommended pattern:

- "Send a completion email."

Supporting copy:

> Pebble can email one contact when this routine is completed. The email can
> include the routine name, completion time, and step count. Photos and checklist
> details are not included.

Where AI photo descriptions are offered, add: "If you use AI photo
descriptions, you can choose to add them. Photos are never emailed."

## AI Photo Descriptions

Say what it does: it writes a short description of what is in a photo. Never
say it checks, confirms, verifies or makes sure of anything, and never use
medication as the example. Every description is labelled "AI description".

Use:

- AI photo descriptions.
- AI description.
- "Couldn't describe this photo."
- "AI descriptions are unavailable right now."

The consent wording, the provider's name and the sentence about what the
provider keeps live in lib/features/ai_photo/ai_photo_constants.dart and
nowhere else. Changing any of them means a new consent version there and in
supabase/functions/_shared/ai_photo.ts.

## Medical, Safety, And Compliance Guardrails

Pebble must not sound like medical safety software, legal evidence storage,
workplace compliance tooling, or an emergency system.

Medication and health-related routines may exist, but they should read like
ordinary routine tasks.

Use:

- "Take medication."
- "Medication packed."
- "Evening medication checked."

Avoid:

- "Dose adherence."
- "Treatment plan."
- "Medication safety."
- "Health compliance."
- "Never miss important medication."

Legal and safety disclaimers belong in Settings, About, Privacy, Terms, support,
store copy, and public web pages. They should not dominate the main routine
workflow.

## Data, History, And Backup

Be realistic and transparent about how data is stored.

Use:

- "Saved on this phone."
- "Stored on this phone."
- "Recent history."
- "Retained for 48 hours."
- "Retained for 21 days."
- "Backup is on."
- "Backup is paused."

Avoid:

- "Guaranteed backup."
- "Permanent archive."
- "Legal proof."
- "Never lose your data."
- "Always backed up."
- "Fully protected."

Backup must never sound automatic unless it is actually active. Backup requires
Premium, sign-in, and the user choosing to turn backup on.

## Premium Copy

Premium is a practical upgrade based on utility, capacity, and backup. It should
not exploit anxiety.

Do:

- Focus on longer history.
- Focus on cloud backup.
- Focus on account recovery.
- Be clear about what requires sign-in and backup consent.

Good examples:

- "Get longer history, cloud backup, and account recovery."
- "Premium gives you a longer recent history window and cloud backup when you choose to turn it on."

Avoid:

- "Worry less."
- "Protect your peace of mind."
- "Upgrade to stay safe."
- "Unlock everything."
- "Never lose anything."
- "Complete protection."

## Errors And Statuses

Messages should be short, specific, and clear. Remove vague padding and polite
fluff.

| Situation | Recommended copy |
| --- | --- |
| Loading | "Loading routines..." |
| Saving | "Saving..." |
| Saved | "Saved." |
| Failed save | "Couldn't save changes. Try again." |
| Network issue | "No connection. Check your network and try again." |
| Backup paused | "Backup is paused. Your routines are still saved on this phone." |
| Permission needed | "Camera access is off. Turn it on in device settings to take a photo." |
| Unknown fallback | "Something went wrong. Try again." |

Avoid using "Something went wrong" unless Pebble genuinely cannot identify the
problem.

For technical checks, use the simplest accurate wording:

- "Checking Premium."
- "Checking your account."
- "Checking the store."
- "Finishing setup."

## Summary

Pebble uses global plain English with UK spelling. The copy is direct,
practical, and matter-of-fact. It avoids therapeutic, clinical, legal,
emergency, and anxiety-based language.

Use "photo" in daily UI and "Proof photos" only as a feature name. Sharing is
called "completion emails." Premium copy focuses on longer history, backup, and
account recovery. Backup copy must always be clear that backup requires Premium,
sign-in, and the user choosing to turn it on.

Pebble should sound like a reliable tool for capable people who want to complete
their routine and get on with their day.
