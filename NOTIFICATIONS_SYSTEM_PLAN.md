# Pebble Notifications System Plan

## Trust Promise
- Reminder notifications are trust-critical reassurance behavior.
- If a reminder is visible as enabled in the app, it must be scheduled in the OS.
- Failures must be explicit, recoverable, and never silent.

## Baseline Guarantee (Free Tier)
- Users can create and manage recurring routine reminders.
- Every enabled reminder schedules as its own OS notification job.
- Reminder state is re-synced on app startup.
- Permission denial is surfaced immediately with an action to open system settings.

## Paid Notification Features
- Personal Premium:
  - Smart follow-up alerts if a routine is still incomplete after N minutes.
  - Escalation patterns (gentle nudge, then stronger nudge).
- Pebble Household:
  - Partner completion alerts ("Alex completed Kitchen Closeout").
  - Shared routine reminder opt-ins.
- Workspace / Enterprise:
  - Team-wide completion alerts by role/channel.
  - SLA reminders (routine overdue alerts).
  - Digest notifications (hourly/daily summary of completed/missed routines).

## Frontend Features
- Notification Health Card:
  - Shows permission state, last successful schedule sync, and failed reminders count.
- Reminder Delivery UX:
  - "Enabled and scheduled" confirmation after save.
  - "Saved locally, not scheduled" blocked state if permission/system scheduling fails.
- Household/Work Alert Preferences:
  - Per-routine subscription toggles for completion alerts.
  - Quiet hours, per-channel controls (push/email/SMS in paid plans).

## Backend Features
- Event model:
  - `routine_started`, `routine_completed`, `routine_missed`, `reminder_triggered`.
- Notification orchestration service:
  - Resolves recipient rules by plan, team membership, and preference settings.
  - Applies throttling, deduplication, and quiet-hour policies.
- Delivery adapters:
  - Push provider(s), email, SMS/webhook for workspace plans.
- Idempotency and audit:
  - Every send request has an idempotency key and immutable audit row.

## Reliability Guardrails
- SLO:
  - 99.9% of enabled reminders are scheduled within 10 seconds of save.
  - 99.9% startup re-sync completion for enabled reminders.
- Monitoring:
  - Metrics for schedule success/failure, permission-denied rate, and drift count.
  - Alerting on spikes in unscheduled-enabled reminders.
- Recovery jobs:
  - Client startup re-sync (already implemented).
  - Backend retry queue for networked notification channels.

## Data Model Direction
- Local:
  - `routine_reminders` is the source of truth for local recurring reminders.
- Cloud (paid/team):
  - `notification_subscriptions` per user/routine/channel.
  - `notification_deliveries` with state machine (`queued`, `sent`, `failed`, `retrying`).

## Rollout Phases
1. Reliability hardening for local reminders (complete in this patch).
2. Notification Health UI and observability events.
3. Household completion alerts over push.
4. Workspace orchestration (roles, channels, digest, SLAs).
5. Enterprise controls (policy, audit exports, webhook integrations).
