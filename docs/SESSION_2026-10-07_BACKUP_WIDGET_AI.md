# 7 October 2026: backup, sign-in, widget and AI photos

Build 37, branch `claude/vibrant-euler-ltockb`. It builds on build 36
(`feat/phone-feedback-1`), which was on Jamie's phone and had not been merged.
Neither is on `main` yet; they reach it through a pull request.

## What was wrong, in plain English

**Backup said "backed up just now" while 11 changes were still waiting.**
- "Last backed up" was stamped after *any* single item succeeded, even when
  others failed. It also refreshed every time the app opened.
- Runs finished in the first moments after opening the app were never queued.
- A failing item had its retry count reset again and again, so it never
  reached "couldn't back up". It just sat in "waiting" for ever.
- A photo that failed to upload with its run was never tried again. The live
  database shows no proof photo uploaded since about 02:27 on 6 October.
- An edit made while that item was uploading could be lost.
- Every restore re-uploaded everything.
- Times were sent to the server as local time without saying so. In British
  Summer Time, every backed-up time was an hour out.

**AI descriptions never appeared.**
Returning from the camera counts as "the app opening again" on Android, and
that quietly rebuilt the player. The rebuild threw away the description in
progress and then overwrote the saved one. Failures were also hidden, so all
you ever saw was "Describing photo".

**The widget opened "Page not found".**
Android handed the widget's link (`pebble://play/<id>`) to the page router as
a page called `/<id>`. "Session no longer resumable" came from the same
player rebuild as the lost AI descriptions.

**Four or more photos ran off the completion screen.** The photo row didn't
measure the space it had.

## What changed

**Backup structure.**
- There is now one backup status, `BackupStatus` in
  `lib/features/sync/backup_status.dart`. Home, Account, the Backup screen and
  the completion screen all read it, so they can't disagree.
- The states are: Backed up · 2 min ago, Backing up, Waiting for internet,
  Couldn't back up · tap to retry, Backup off, Sign in to back up, Backup
  paused.
- "Last backed up" is only set when a whole backup run finishes with nothing
  failing.
- Waiting changes are retried every 3 minutes while the app is open, as well
  as after each change and when the app opens.
- Failed items keep their count. After 5 failures the item shows as "Couldn't
  back up", and Pebble keeps retrying.

**Backup screen.**
- One status card with a switch and one button.
- "What's backed up" and "How backup works" open only when you tap them.
- The three-step tracker, the banner, the grid and the pill sheets are gone.

**Turning on backup.**
- One sheet: the consent sentence word for word, then the "Turn on backup"
  button. There is no separate checkbox.
- The sentence and its server hash are unchanged.
- The sheet after buying Premium used to record this consent while showing
  different wording. It now shows the exact sentence.

**Sign-in.**
- Short screen.
- Removed the line "Signing in turns on backup", which wasn't true.
- With Premium, signing in now carries straight on to the "Turn on backup?"
  sheet.

**AI consent.**
- Two short lines, the sentence you agree to, and "Turn on".
- The full explanation is unchanged and sits behind "More details".
- The consent version is unchanged, so no server change was needed.

**Player.**
- Close, a thin progress bar and "4 of 5" at the top.
- With no photo yet, a large "Take photo" tile.
- With several photos, a strip of thumbnails. One caption slot under the
  photos shows the description for the photo you have selected.
- A soft "Describing…" while it works.
- If it fails, "Couldn't describe · Try again".
- The completion screen says how many descriptions there are. History and
  the photo viewer show them.

**Multiple photos on one step.** Each photo gets its own description. Tap a
thumbnail to read its description.

**Home "Checked" card.**
- The big "Check again" button is replaced by quiet "See this check" and
  "Run again" links.
- **The rule:** the card stays until the routine is next due. That is its
  next reminder, at least 2 hours after you finished, or 4am the next day if
  that comes first.
- The Start screen then says "Last checked today, 13:27" rather than "10h
  ago".
- The widget follows the same rule.

**Widget.**
- The link is fixed. Any unknown link now shows a calm "This page isn't
  available" page.
- "Show on widget" in a routine's ⋯ menu picks *the* widget routine. Only one
  routine is on the widget at a time.
- After you choose a routine, a sheet explains how to add the widget, with an
  "Add widget" button where the phone supports it.
- Settings has a "Home screen widget" row.
- The widget looks nicer, with a light and a dark version and a proper
  preview in the widget picker.
- There is still no iPhone widget. It needs an Xcode widget target, which
  this session couldn't do.

## Checked on the live server (read-only, nothing changed)

- The AI photo function (`describe-proof-photo`) is deployed. All
  migrations up to `023` are applied.
- Jamie's Play **test** subscription expired on the server at 06:49 on
  6 October; test subscriptions renew every 30 minutes and then stop. The phone
  still showed "Premium active" that afternoon. After a test subscription
  lapses, buy a fresh test subscription before testing backup or AI.

## Please test on the phone (build 37)

1. **Backup.** Turn backup on, complete a routine with photos, then open
   Backup. It should say "Backing up" and then "Backed up · just now". Turn on
   aeroplane mode, complete a routine: "Waiting for internet". Turn it off: it
   should catch up within a few minutes.
2. **AI.** On an AI routine, take two photos on one step. "Describing…" should
   turn into a description under each photo. Tap the other thumbnail to read
   its description.
3. **Widget.** Choose ⋯ → Show on widget, follow the sheet, then tap the
   widget. The routine should open.
4. **Four or more photos.** They should fit on the completion screen, showing
   "+N" for any extra.

Not yet tried on a real phone: the Android widget code was checked by eye but
not compiled here (there is no Android SDK in this environment). CI's Android
debug build will compile it.
