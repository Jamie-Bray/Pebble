// Database access for completion emails, behind a small interface so the
// handlers can be tested with an in-memory fake (shared_alert_fake_store.ts).
// The real implementation uses the service-role client: since migration 020
// the app cannot write these tables directly.

import { DAY_MS, HOUR_MS, type InviteCounts, type TokenPurpose } from './shared_alert_policy.ts';

export type ContactStatus = 'pending' | 'accepted' | 'declined' | 'blocked' | 'disabled';

export type ContactRow = {
  id: string;
  owner_user_id: string;
  routine_key: string;
  recipient_email: string;
  normalized_email: string;
  recipient_email_hash: string;
  status: ContactStatus;
  notify_when_finished: boolean;
  include_routine_name: boolean;
  include_step_count: boolean;
  invited_at: string;
  accepted_at: string | null;
  declined_at: string | null;
  blocked_at: string | null;
  disabled_at: string | null;
  updated_at: string;
};

export type InviteRow = {
  id: string;
  contact_id: string;
  owner_user_id: string | null;
  recipient_email_hash: string | null;
  purpose: TokenPurpose | null;
  token_hash: string;
  expires_at: string;
  created_at: string;
  accepted_at: string | null;
  declined_at: string | null;
  blocked_at: string | null;
};

export type EventRow = {
  id: string;
  contact_id: string;
  status: 'pending' | 'sent' | 'failed' | 'skipped';
  attempts: number;
};

export type NewEvent = {
  owner_user_id: string;
  contact_id: string;
  routine_key: string;
  run_id: string;
  session_id: string | null;
  routine_title: string;
  completed_at: string;
  completed_steps: number;
  total_steps: number;
};

export interface SharedAlertStore {
  hasActiveEntitlement(userId: string): Promise<boolean>;
  /** True when the account has an unwithdrawn AI photo consent for `version`. */
  hasCurrentAiPhotoConsent(userId: string, version: string): Promise<boolean>;

  getContactForRoutine(ownerId: string, routineKey: string): Promise<ContactRow | null>;
  getContactById(id: string): Promise<ContactRow | null>;
  upsertPendingContact(row: Omit<ContactRow, 'id' | 'accepted_at' | 'declined_at' | 'blocked_at' | 'disabled_at'>): Promise<ContactRow>;
  updateContact(id: string, patch: Partial<ContactRow>): Promise<ContactRow | null>;
  inviteCounts(input: { ownerId: string; recipientHash: string; routineKey: string; now: number }): Promise<InviteCounts>;

  insertInvite(row: Omit<InviteRow, 'id' | 'created_at' | 'accepted_at' | 'declined_at' | 'blocked_at'>): Promise<void>;
  /** Ends every still-valid token of `purpose` for a contact. */
  expireTokens(contactId: string, purpose: TokenPurpose, nowIso: string): Promise<void>;
  /** Deletes a contact's tokens that expired more than a week ago. */
  pruneTokens(contactId: string, now: number): Promise<void>;
  findInviteByTokenHash(tokenHash: string): Promise<InviteRow | null>;
  markInvite(id: string, patch: Partial<Pick<InviteRow, 'accepted_at' | 'declined_at' | 'blocked_at'>>): Promise<void>;

  /** True only for a permanent block (not a time-limited decline). */
  isBlocked(senderId: string, recipientHash: string): Promise<boolean>;
  isSuppressed(recipientHash: string): Promise<boolean>;
  upsertBlock(input: { senderId: string; recipientHash: string; normalizedEmail: string; nowIso: string }): Promise<void>;
  /** Stops re-invites until `until`. Never weakens a permanent block. */
  recordDecline(input: { senderId: string; recipientHash: string; normalizedEmail: string; until: Date; nowIso: string }): Promise<void>;
  clearDecline(senderId: string, recipientHash: string): Promise<void>;
  addSuppression(recipientHash: string, source: string): Promise<void>;

  /** Inserts a pending event; returns null when (contact, run) already exists. */
  insertEvent(row: NewEvent): Promise<EventRow | null>;
  getEventForRun(contactId: string, runId: string): Promise<EventRow | null>;
  /** failed -> pending with attempts + 1, only if still failed. */
  claimFailedEvent(id: string, attempts: number): Promise<boolean>;
  updateEvent(id: string, patch: Record<string, unknown>): Promise<void>;
  sentCounts(contactId: string, now: number): Promise<{ sentLastHour: number; sentLastDay: number }>;
}

// deno-lint-ignore no-explicit-any
type Client = any;

function check<T>(result: { data: T; error: { message: string; code?: string } | null }): T {
  if (result.error) throw new Error(result.error.message);
  return result.data;
}

async function countOf(query: Promise<{ count: number | null; error: { message: string } | null }>): Promise<number> {
  const { count, error } = await query;
  if (error) throw new Error(error.message);
  return count ?? 0;
}

export function supabaseSharedAlertStore(client: Client): SharedAlertStore {
  const head = { count: 'exact', head: true };
  async function getBlock(senderId: string, recipientHash: string): Promise<{ expires_at: string | null } | null> {
    // A decline row whose cooldown has passed counts as no block at all.
    const row = check(await client.from('shared_alert_blocks').select('expires_at')
      .eq('sender_user_id', senderId).eq('recipient_email_hash', recipientHash).maybeSingle()) as
      | { expires_at: string | null }
      | null;
    if (row && row.expires_at !== null && new Date(row.expires_at).getTime() <= Date.now()) return null;
    return row;
  }

  const store: SharedAlertStore = {
    async hasActiveEntitlement(userId) {
      const { data, error } = await client.rpc('has_active_personal_entitlement', { user_id: userId });
      if (error) {
        console.error(JSON.stringify({ scope: 'shared-alert', event: 'entitlement_check_failed', message: error.message }));
        return false;
      }
      return data === true;
    },

    async hasCurrentAiPhotoConsent(userId, version) {
      const row = check(await client.from('ai_photo_consents').select('owner_user_id')
        .eq('owner_user_id', userId).eq('consent_version', version).is('withdrawn_at', null).maybeSingle());
      return row !== null;
    },

    async getContactForRoutine(ownerId, routineKey) {
      return check(await client.from('shared_alert_contacts').select('*')
        .eq('owner_user_id', ownerId).eq('routine_key', routineKey).maybeSingle());
    },

    async getContactById(id) {
      return check(await client.from('shared_alert_contacts').select('*').eq('id', id).maybeSingle());
    },

    async upsertPendingContact(row) {
      return check(await client.from('shared_alert_contacts').upsert({
        ...row,
        accepted_at: null,
        declined_at: null,
        blocked_at: null,
        disabled_at: null,
      }, { onConflict: 'owner_user_id,routine_key' }).select().single());
    },

    async updateContact(id, patch) {
      return check(await client.from('shared_alert_contacts').update(patch).eq('id', id).select().maybeSingle());
    },

    async inviteCounts({ ownerId, recipientHash, routineKey, now }) {
      const dayAgo = new Date(now - DAY_MS).toISOString();
      const weekAgo = new Date(now - 7 * DAY_MS).toISOString();
      const invites = () => client.from('shared_alert_invites').select('id', head).eq('purpose', 'invite');
      const [suppressed, block, senderDay, senderRecipientWeek, recipientDay, active] = await Promise.all([
        store.isSuppressed(recipientHash),
        getBlock(ownerId, recipientHash),
        countOf(invites().eq('owner_user_id', ownerId).gte('created_at', dayAgo)),
        countOf(invites().eq('owner_user_id', ownerId).eq('recipient_email_hash', recipientHash).gte('created_at', weekAgo)),
        countOf(invites().eq('recipient_email_hash', recipientHash).gte('created_at', dayAgo)),
        countOf(client.from('shared_alert_contacts').select('id', head)
          .eq('owner_user_id', ownerId).in('status', ['pending', 'accepted']).neq('routine_key', routineKey)),
      ]);
      return {
        suppressed,
        blocked: block !== null && block.expires_at === null,
        senderInvitesLastDay: senderDay,
        senderRecipientInvitesLastWeek: senderRecipientWeek,
        recipientInvitesLastDay: recipientDay,
        activeContactsElsewhere: active,
        declinedUntil: block?.expires_at ? new Date(block.expires_at) : null,
      };
    },

    async insertInvite(row) {
      check(await client.from('shared_alert_invites').insert(row));
    },

    async expireTokens(contactId, purpose, nowIso) {
      check(await client.from('shared_alert_invites').update({ expires_at: nowIso })
        .eq('contact_id', contactId).eq('purpose', purpose).gt('expires_at', nowIso));
    },

    async pruneTokens(contactId, now) {
      check(await client.from('shared_alert_invites').delete()
        .eq('contact_id', contactId).lt('expires_at', new Date(now - 7 * DAY_MS).toISOString()));
    },

    async findInviteByTokenHash(tokenHash) {
      return check(await client.from('shared_alert_invites').select('*').eq('token_hash', tokenHash).maybeSingle());
    },

    async markInvite(id, patch) {
      check(await client.from('shared_alert_invites').update(patch).eq('id', id));
    },

    async isBlocked(senderId, recipientHash) {
      const block = await getBlock(senderId, recipientHash);
      return block !== null && block.expires_at === null;
    },

    async isSuppressed(recipientHash) {
      const row = check(await client.from('shared_alert_suppressions').select('recipient_email_hash')
        .eq('recipient_email_hash', recipientHash).maybeSingle());
      return row !== null;
    },

    async upsertBlock({ senderId, recipientHash, normalizedEmail, nowIso }) {
      check(await client.from('shared_alert_blocks').upsert({
        sender_user_id: senderId,
        normalized_email: normalizedEmail,
        recipient_email_hash: recipientHash,
        reason: 'recipient_blocked',
        expires_at: null,
        updated_at: nowIso,
      }, { onConflict: 'sender_user_id,recipient_email_hash' }));
    },

    async recordDecline({ senderId, recipientHash, normalizedEmail, until, nowIso }) {
      const existing = await getBlock(senderId, recipientHash);
      if (existing && existing.expires_at === null) return;
      check(await client.from('shared_alert_blocks').upsert({
        sender_user_id: senderId,
        normalized_email: normalizedEmail,
        recipient_email_hash: recipientHash,
        reason: 'recipient_declined',
        expires_at: until.toISOString(),
        updated_at: nowIso,
      }, { onConflict: 'sender_user_id,recipient_email_hash' }));
    },

    async clearDecline(senderId, recipientHash) {
      check(await client.from('shared_alert_blocks').delete()
        .eq('sender_user_id', senderId).eq('recipient_email_hash', recipientHash)
        .eq('reason', 'recipient_declined'));
    },

    async addSuppression(recipientHash, source) {
      check(await client.from('shared_alert_suppressions').upsert(
        { recipient_email_hash: recipientHash, source },
        { onConflict: 'recipient_email_hash', ignoreDuplicates: true },
      ));
    },

    async insertEvent(row) {
      const { data, error } = await client.from('shared_alert_events')
        .insert({ ...row, status: 'pending', attempts: 1 })
        .select('id, contact_id, status, attempts').single();
      if (error?.code === '23505') return null;
      if (error) throw new Error(error.message);
      return data;
    },

    async getEventForRun(contactId, runId) {
      return check(await client.from('shared_alert_events').select('id, contact_id, status, attempts')
        .eq('contact_id', contactId).eq('run_id', runId).maybeSingle());
    },

    async claimFailedEvent(id, attempts) {
      const rows = check(await client.from('shared_alert_events')
        .update({ status: 'pending', attempts, error_summary: null })
        .eq('id', id).eq('status', 'failed').lt('attempts', attempts).select('id')) as unknown[];
      return rows.length === 1;
    },

    async updateEvent(id, patch) {
      check(await client.from('shared_alert_events').update(patch).eq('id', id));
    },

    async sentCounts(contactId, now) {
      const sent = () => client.from('shared_alert_events').select('id', head)
        .eq('contact_id', contactId).eq('status', 'sent');
      const [hour, day] = await Promise.all([
        countOf(sent().gte('created_at', new Date(now - HOUR_MS).toISOString())),
        countOf(sent().gte('created_at', new Date(now - DAY_MS).toISOString())),
      ]);
      return { sentLastHour: hour, sentLastDay: day };
    },
  };
  return store;
}
