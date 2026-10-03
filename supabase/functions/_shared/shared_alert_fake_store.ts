// In-memory SharedAlertStore for tests. Mirrors the constraints the real
// tables enforce (unique (owner, routine_key) contacts, unique (contact, run)
// events, unique token hashes).

import { DAY_MS, HOUR_MS, type InviteCounts } from './shared_alert_policy.ts';
import type { Mailer } from './shared_alert_runtime.ts';
import type { ContactRow, EventRow, InviteRow, NewEvent, SharedAlertStore } from './shared_alert_store.ts';

type Block = { sender: string; hash: string; email: string; reason: string; expires_at: string | null };
type Event = NewEvent & EventRow & { created_at: string; error_summary?: string | null; [k: string]: unknown };

export class FakeStore implements SharedAlertStore {
  contacts: ContactRow[] = [];
  invites: InviteRow[] = [];
  blocks: Block[] = [];
  suppressions = new Set<string>();
  events: Event[] = [];
  premium = new Set<string>();
  private seq = 0;
  constructor(public clock: () => number) {}

  private id(prefix: string) {
    return `${prefix}-${++this.seq}`;
  }
  private iso() {
    return new Date(this.clock()).toISOString();
  }

  hasActiveEntitlement(userId: string) {
    return Promise.resolve(this.premium.has(userId));
  }
  getContactForRoutine(ownerId: string, routineKey: string) {
    return Promise.resolve(this.contacts.find((c) => c.owner_user_id === ownerId && c.routine_key === routineKey) ?? null);
  }
  getContactById(id: string) {
    return Promise.resolve(this.contacts.find((c) => c.id === id) ?? null);
  }
  upsertPendingContact(row: Omit<ContactRow, 'id' | 'accepted_at' | 'declined_at' | 'blocked_at' | 'disabled_at'>) {
    const existing = this.contacts.find((c) => c.owner_user_id === row.owner_user_id && c.routine_key === row.routine_key);
    const full = { ...row, accepted_at: null, declined_at: null, blocked_at: null, disabled_at: null };
    if (existing) {
      Object.assign(existing, full);
      return Promise.resolve({ ...existing });
    }
    const created = { id: this.id('contact'), ...full } as ContactRow;
    this.contacts.push(created);
    return Promise.resolve({ ...created });
  }
  updateContact(id: string, patch: Partial<ContactRow>) {
    const c = this.contacts.find((x) => x.id === id);
    if (!c) return Promise.resolve(null);
    Object.assign(c, patch);
    return Promise.resolve({ ...c });
  }
  inviteCounts({ ownerId, recipientHash, routineKey, now }: { ownerId: string; recipientHash: string; routineKey: string; now: number }): Promise<InviteCounts> {
    const since = (ms: number) => (i: InviteRow) => new Date(i.created_at).getTime() >= now - ms;
    const inv = this.invites.filter((i) => i.purpose === 'invite');
    const block = this.activeBlock(ownerId, recipientHash);
    return Promise.resolve({
      suppressed: this.suppressions.has(recipientHash),
      blocked: !!block && block.expires_at === null,
      senderInvitesLastDay: inv.filter((i) => i.owner_user_id === ownerId).filter(since(DAY_MS)).length,
      senderRecipientInvitesLastWeek: inv.filter((i) => i.owner_user_id === ownerId && i.recipient_email_hash === recipientHash)
        .filter(since(7 * DAY_MS)).length,
      recipientInvitesLastDay: inv.filter((i) => i.recipient_email_hash === recipientHash).filter(since(DAY_MS)).length,
      activeContactsElsewhere: this.contacts.filter((c) =>
        c.owner_user_id === ownerId && c.routine_key !== routineKey && (c.status === 'pending' || c.status === 'accepted')
      ).length,
      declinedUntil: block?.expires_at ? new Date(block.expires_at) : null,
    });
  }
  insertInvite(row: Omit<InviteRow, 'id' | 'created_at' | 'accepted_at' | 'declined_at' | 'blocked_at'>) {
    if (this.invites.some((i) => i.token_hash === row.token_hash)) throw new Error('duplicate token');
    this.invites.push({ id: this.id('invite'), created_at: this.iso(), accepted_at: null, declined_at: null, blocked_at: null, ...row });
    return Promise.resolve();
  }
  expireTokens(contactId: string, purpose: string, nowIso: string) {
    for (const i of this.invites) {
      if (i.contact_id === contactId && i.purpose === purpose && i.expires_at > nowIso) i.expires_at = nowIso;
    }
    return Promise.resolve();
  }
  pruneTokens(contactId: string, now: number) {
    this.invites = this.invites.filter((i) => !(i.contact_id === contactId && new Date(i.expires_at).getTime() < now - 7 * DAY_MS));
    return Promise.resolve();
  }
  findInviteByTokenHash(tokenHash: string) {
    return Promise.resolve(this.invites.find((i) => i.token_hash === tokenHash) ?? null);
  }
  markInvite(id: string, patch: Partial<InviteRow>) {
    const i = this.invites.find((x) => x.id === id);
    if (i) Object.assign(i, patch);
    return Promise.resolve();
  }
  private activeBlock(sender: string, hash: string) {
    const b = this.blocks.find((x) => x.sender === sender && x.hash === hash);
    if (b && b.expires_at && new Date(b.expires_at).getTime() <= this.clock()) return null;
    return b ?? null;
  }
  isBlocked(senderId: string, recipientHash: string) {
    const b = this.activeBlock(senderId, recipientHash);
    return Promise.resolve(!!b && b.expires_at === null);
  }
  isSuppressed(recipientHash: string) {
    return Promise.resolve(this.suppressions.has(recipientHash));
  }
  upsertBlock({ senderId, recipientHash, normalizedEmail }: { senderId: string; recipientHash: string; normalizedEmail: string }) {
    this.blocks = this.blocks.filter((b) => !(b.sender === senderId && b.hash === recipientHash));
    this.blocks.push({ sender: senderId, hash: recipientHash, email: normalizedEmail, reason: 'recipient_blocked', expires_at: null });
    return Promise.resolve();
  }
  recordDecline({ senderId, recipientHash, normalizedEmail, until }: { senderId: string; recipientHash: string; normalizedEmail: string; until: Date }) {
    const existing = this.blocks.find((b) => b.sender === senderId && b.hash === recipientHash);
    if (existing && existing.expires_at === null) return Promise.resolve();
    this.blocks = this.blocks.filter((b) => b !== existing);
    this.blocks.push({ sender: senderId, hash: recipientHash, email: normalizedEmail, reason: 'recipient_declined', expires_at: until.toISOString() });
    return Promise.resolve();
  }
  clearDecline(senderId: string, recipientHash: string) {
    this.blocks = this.blocks.filter((b) => !(b.sender === senderId && b.hash === recipientHash && b.reason === 'recipient_declined'));
    return Promise.resolve();
  }
  addSuppression(recipientHash: string) {
    this.suppressions.add(recipientHash);
    return Promise.resolve();
  }
  insertEvent(row: NewEvent) {
    if (this.events.some((e) => e.contact_id === row.contact_id && e.run_id === row.run_id)) return Promise.resolve(null);
    const e = { ...row, id: this.id('event'), status: 'pending' as const, attempts: 1, created_at: this.iso() };
    this.events.push(e);
    return Promise.resolve({ id: e.id, contact_id: e.contact_id, status: e.status, attempts: 1 });
  }
  getEventForRun(contactId: string, runId: string) {
    const e = this.events.find((x) => x.contact_id === contactId && x.run_id === runId);
    return Promise.resolve(e ? { id: e.id, contact_id: e.contact_id, status: e.status, attempts: e.attempts } : null);
  }
  claimFailedEvent(id: string, attempts: number) {
    const e = this.events.find((x) => x.id === id);
    if (!e || e.status !== 'failed' || e.attempts >= attempts) return Promise.resolve(false);
    e.status = 'pending';
    e.attempts = attempts;
    return Promise.resolve(true);
  }
  updateEvent(id: string, patch: Record<string, unknown>) {
    const e = this.events.find((x) => x.id === id);
    if (e) Object.assign(e, patch);
    return Promise.resolve();
  }
  sentCounts(contactId: string, now: number) {
    const sent = this.events.filter((e) => e.contact_id === contactId && e.status === 'sent');
    const within = (ms: number) => sent.filter((e) => new Date(e.created_at).getTime() >= now - ms).length;
    return Promise.resolve({ sentLastHour: within(HOUR_MS), sentLastDay: within(DAY_MS) });
  }
}

export type SentMail = Parameters<Mailer>[0];

export function fakeMailer(outcomes: ('ok' | 'fail')[] = []) {
  const sent: SentMail[] = [];
  const mailer: Mailer = (message) => {
    const outcome = outcomes.shift() ?? 'ok';
    if (outcome === 'fail') return Promise.resolve({ ok: false, error: 'resend 500 boom' });
    sent.push(message);
    return Promise.resolve({ ok: true, id: `msg-${sent.length}` });
  };
  return { mailer, sent };
}

export const testLinks = {
  functionsBase: 'https://ref.functions.supabase.co',
  pagesBase: 'https://pebbleroutines.com/shared-alert',
  privacyUrl: 'https://pebbleroutines.com/privacy.html',
  footerAddress: null,
};

/** Pulls the raw token out of a confirm-page link in an email. */
export function tokenFrom(text: string, action: string): string {
  const match = text.match(new RegExp(`#action=${action}&token=([A-Za-z0-9._%-]+)`));
  if (!match) throw new Error(`no ${action} link`);
  return decodeURIComponent(match[1]);
}
