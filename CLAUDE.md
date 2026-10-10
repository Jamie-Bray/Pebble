# Pebble Routines: Working Rules

Pebble is a Flutter app (Android and iOS) with a Supabase backend and RevenueCat
subscriptions. The owner is not a developer, so explain outcomes in plain English
and handle git, tests and pushing yourself.

## Keep token use low

The owner is on a weekly usage limit, and everything read stays in context and is re-sent every turn.

- Search before reading. Use Grep with a specific path, then read only the line range you need.
- Never read a whole doc over about 10KB (`DESIGN_DIRECTION.md`, `SUPABASE_LIVE_AUDIT.md`,
  `VISUAL_WALKTHROUGH.md`, `SUBSCRIPTION_REVIEW.md`, `COMPLETION_EMAIL_REVIEW.md`).
  Grep for the heading and read that section only.
- Pipe long command output through `tail -n 40` (for example `flutter test 2>&1 | tail -n 40`).
- Only open walkthrough PNGs for the screens being changed, never the full set.
- Don't re-read a file you just edited. Don't explore the repo when the owner has named the file.
- Use subagents only when the owner asks.
- When a task is done, say so and suggest starting a fresh thread for the next one.

## Source of truth: GitHub, always

Work was lost twice (builds 27/28, and builds 32/33 sat uncommitted on a laptop),
so these rules are mandatory in every session, on every machine.

1. **Start in sync.** Before changing anything, run `git fetch origin` and check
   `git status`. If there is uncommitted work you did not make, stop and tell the
   owner. Never discard it, and never build on top of it silently.
2. **Never work directly on `main`.** Create a branch from the latest
   `origin/main` (for example `git checkout -b feature/<topic> origin/main`).
3. **Commit small and often,** and **push the branch before the session ends.**
   A session never finishes with uncommitted or unpushed work.
4. **Changes reach `main` only through a pull request** with CI green
   (`.github/workflows/ci.yml`: analyze and tests; the Android debug build
   runs only when started by hand, to save free Actions minutes).
5. **Never commit secrets:** `android/key.properties`, keystores, `.env` files,
   API keys, service-account JSON. Production values live in Codemagic, in the
   `pebble_production` group.
6. **Build numbers** (`version:` in `pubspec.yaml`) only go up, and only on the
   branch being released. Play Console has received build 28 or higher; check
   before uploading.

## Checks before every push

```bash
flutter analyze            # must say "No issues found!"
flutter test               # must be all green
```

To check screens visually, run the screenshot harness. It renders every screen
to PNGs and logs layout errors to `_layout_errors.txt`:
`WALKTHROUGH=1 FLUTTER_TESTER_REAL_FONTS=1 WALKTHROUGH_OUT=<dir> flutter test test/walkthrough/walkthrough_screens_test.dart`

CI and Codemagic pin Flutter 3.47.x, with Gradle 8.14, AGP 8.11.1 and Kotlin 2.3.20.

## Rules that protect users

- **Stored reminder times use a fixed US-English `h:mm a` format.** Use
  `encodeStoredClockTime` and `parseStoredClockTime` in
  `lib/core/ui/pebble_time.dart`. Never use a locale-dependent `DateFormat` for
  stored values. Dates and times on screen follow the device locale
  (`lib/core/config/pebble_locale.dart`).
- **Never delete user history** until the store or server confirms Premium has
  ended. The grace period is in `SUBSCRIPTION_REVIEW.md`.
- **Don't change the Android purchase, restore or sync call order** in
  `revenuecat_purchase_repository.dart` without tests and a real-device test.
- **The paid plan is called "Personal Premium".** Copy follows
  `COPY_GUIDELINES.md` and uses UK English.
- **Supabase production (`yncgjqbjjzbinqkpukug`) is read-only** unless the owner
  approves a step in `supabase/DEPLOY_PLAN.md`. Record every live change there.
- **Completion emails go through Edge Functions only.** The app must never write
  the `shared_alert_*` tables directly.

## Where things are

| Need | File |
|---|---|
| Launch status and owner to-do list | `START_HERE.md` |
| iOS account setup | `IOS_SETUP_CHECKLIST.md` |
| Builds (Codemagic) and release | `docs/BUILD_AND_RELEASE.md` |
| Backend deploy order and migrations | `supabase/DEPLOY_PLAN.md`, `supabase/MIGRATION_REPAIR_PLAN.md` |
| Design system and the beauty-pass plan | `DESIGN_DIRECTION.md` |
| Reviews | `LAUNCH_READINESS_AUDIT.md`, `SUPABASE_LIVE_AUDIT.md`, `VISUAL_WALKTHROUGH.md`, `SUBSCRIPTION_REVIEW.md`, `COMPLETION_EMAIL_REVIEW.md` |
| Store listings and privacy forms | `docs/store/` |
