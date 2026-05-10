# Pebble: Identity, Entitlement, and Cloud Access Model
**Decision document and PRD update guide**  
**Date:** 8 April 2026

## 1. Decision summary
- Pebble Personal remains fully usable without sign-in. Free mode stays local-first and offline-capable.
- Sign-in creates identity. It does not unlock paid features by itself.
- Store purchase determines entitlement. Auth and payment are separate concerns.
- Personal cloud backup and sync require both an authenticated account and a valid paid entitlement.
- Signing out must never delete cloud data. It pauses cloud access until the user signs in again.
- Workspace access remains a separate model driven by membership and approval, not by the personal paywall.

### Why this change
The current implementation appears to treat sign-in, Premium access, and sync as if they are the same state. That leads to unclear behaviour on logout, misleading sync messaging, and a data-loss feel even when backed-up data still exists. The new model separates those concerns so the product contract is explicit.

## 2. Core model

| Domain | What it answers | Example states | What it must not control |
|---|---|---|---|
| Auth | Who is using the app right now? | Signed out; Signed in(userId) | Whether the user has paid |
| Entitlement | What has been purchased or granted? | Free; Personal Premium; Household; Workspace Staff; Workspace Manager | Whether the user is signed in |
| Cloud access | Can this device read or write cloud data now? | Unavailable; Available; Syncing; Paused while signed out; Offline pending | Whether the user still owns their subscription |
| Workspace | Is the user part of an approved business space? | None; Pending; Approved; Revoked | The personal home paywall |

## 3. Behaviour matrix

| Scenario | Routines on device | Cloud backup / sync | What the user should see | Notes |
|---|---|---|---|---|
| Free, signed out | Available locally | Off | Your routines are stored on this device. | Default entry state |
| Free, signed in | Available locally | Off | Your account is ready. Upgrade to turn on backup and sync. | Identity without paid features |
| Paid, signed in | Available locally | On | Backup and sync are active. | Target Premium state |
| Paid, signed out | Available locally | Paused | You are signed out. Your backup is still in your account. Sign in again to restore sync. | Sign-out is non-destructive |
| Signed in, offline | Available locally | Pending | Changes will sync when you are back online. | No silent failure |
| Workspace staff approved | Available per workspace rules | On for workspace data | You are connected to your workspace. | No staff paywall |

## 4. Non-negotiable product rules
- **Sign-out:** Signing out ends the local session. It does not delete cloud data, subscriptions, or workspace membership.
- **Delete account / erase backup:** This is a separate destructive action with explicit warning and confirmation.
- **Sync messaging:** Messages must reflect the real blocker: signed out, offline, pending upload, or missing entitlement.
- **Photo storage:** Proof photos stay app-private by default. They should not be pushed into the device camera roll unless the user explicitly exports or saves them.
- **Premium restore:** A subscribed user who signs back in should regain cloud access after entitlement refresh. The app must not leave stale Free-state UI hanging around.
- **No silent failure:** If Pebble cannot sync, the reason must be visible and actionable.

## 5. Recommended user flows

### A. First install
- Land in Pebble Personal without mandatory account creation.
- Explain that routines are stored on the device by default.
- Offer sign-in as optional, not as a gate.
- Offer upgrade separately when the user reaches a paid feature or routine cap.

### B. Upgrade to Personal Premium
- Purchase via Play Store / App Store.
- After purchase, prompt the user to sign in or create an account to turn on cloud backup and sync.
- If already signed in, entitlement refresh should activate cloud features immediately.

### C. Sign out while subscribed
- Keep local routines available according to local storage rules.
- Pause cloud access and show that the user’s backup remains in their account.
- Do not delete Supabase data.

### D. Delete account or erase cloud backup
- Show a destructive confirmation screen with plain-language consequences.
- Differentiate deleting the account from canceling the subscription.
- Confirm whether local copies will remain or be removed.

## 6. PRD update instructions

### Replace this assumption
Replace the assumption that sign-in is the gateway to Personal Premium. The PRD should describe sign-in as identity, subscription as entitlement, and cloud sync as a capability that requires both.

### Sections that need amendment
- Section 5 (Technical Stack & Architecture): add explicit state domains for Auth, Entitlement, Cloud Access, and Workspace.
- Section 6 (Business Model): state that Personal Premium unlocks cloud features through store entitlement, not through sign-in alone.
- Section 8 (Cloud Architecture & Repository Pattern): replace the current workspace-only routing rule with a broader storage strategy for local, personal cloud, and workspace cloud.
- Section 9 (Security & B2B Workflow): keep workspace approval logic, but separate it from home-tier subscription logic.

### Suggested replacement text for the product model
- Pebble Personal (Free) remains local-first and can be used without an account. Users may optionally sign in to create an identity, but sign-in alone does not unlock paid features.
- Personal Premium and Household are determined by store entitlement. Personal cloud backup and sync activate only when the user both holds a valid entitlement and is signed in.
- Signing out pauses cloud access but does not erase backed-up data. Deleting cloud data requires a separate destructive action.
- Workspace access is governed by membership and approval. Staff users do not encounter the home paywall when entering a business workflow.

### Suggested replacement text for cloud routing
- If the user is not entitled to personal cloud features and is not in an approved workspace, routines remain local in Drift.
- If the user is entitled to Personal Premium or Household and is signed in, the app may back up and sync personal data with Supabase while preserving local-first behaviour on device.
- If the user is in an approved workspace, workspace data routes through the workspace cloud model and relevant RLS protections.

## 7. Implementation guardrails for Codex
- **State separation:** Model auth, entitlement, cloud access, and workspace membership as separate domains. Do not derive one directly from another unless explicitly required.
- **Logout flow:** Clear session state without deleting cloud records. Surface a clear signed-out / sync-paused state.
- **Entitlement refresh:** Restore paid capability after sign-in or app resume without leaving stale Free-state UI behind.
- **Sync copy:** Use plain English that matches the real blocker. Never show a generic sync line when the user is signed out.
- **Photo pipeline:** Keep proof photos app-private by default. Audit temporary files, upload handling, and gallery-saving behaviour.
- **Destructive actions:** Separate sign-out, cancel subscription, delete account, and erase backup into different actions and different confirmations.

## Working rule
If Pebble cannot explain the user’s current state in one plain sentence, the state model is still too tangled.
