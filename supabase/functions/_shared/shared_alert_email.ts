// Invitation and completion email templates. Pure functions: every dynamic
// value is escaped here, so callers pass raw strings.
//
// Design: the app's High Noon palette (warm ivory, forest, sage) with a serif
// heading and the stone cairn from the completion screen. "The time is the
// hero" (DESIGN_DIRECTION.md): the completion email leads with a large clock
// time, then lists each step with the time it was checked.
//
// Email-safe: table layout, inline styles, one 560px column that goes full
// width on phones, a dark-mode variant for clients that honour
// prefers-color-scheme, and no images (the cairn is drawn with rounded
// blocks, and Outlook on Windows, which can't round them, gets a text mark).

import { formatDate } from './shared_alert_policy.ts';

export type BuiltEmail = {
  subject: string;
  html: string;
  text: string;
  headers: Record<string, string>;
};

export type EmailCommon = {
  /** Who the email is from, as the recipient sees it (account email). */
  sender: string;
  privacyUrl: string;
  /** Optional postal address line for the footer. */
  footerAddress?: string | null;
};

export type EmailStep = {
  title: string;
  /** "22:38", or null for a skipped step or a step with no usable time. */
  time: string | null;
  skipped: boolean;
};

const PHOTO_NOTE = 'Photos are never emailed.';
const AI_NOTE =
  'If they use AI photo descriptions, they can add a sentence or two about each photo.';

export function buildInviteEmail(input: EmailCommon & {
  includeRoutineName: boolean;
  includeStepCount: boolean;
  expiresAt: Date;
  acceptUrl: string;
  declineUrl: string;
  blockUrl: string;
  oneClickUrl: string;
}): BuiltEmail {
  const included = [
    input.includeRoutineName ? 'The routine name' : null,
    'The time it was completed',
    input.includeStepCount ? 'Each step, and the time it was checked' : null,
  ].filter((x): x is string => x !== null);
  const expires = formatDate(input.expiresAt);

  const text = [
    'Allow completion emails?',
    '',
    `${input.sender} would like Pebble Routines to email you when they complete one of their routines.`,
    '',
    'Each email shows:',
    ...included.map((item) => `- ${item}`),
    '',
    `${PHOTO_NOTE} ${AI_NOTE}`,
    'You can stop the emails at any time from any email.',
    '',
    `Allow completion emails: ${input.acceptUrl}`,
    '',
    `Nothing is sent unless you allow it. This invitation expires on ${expires}.`,
    '',
    `Decline: ${input.declineUrl}`,
    `Block this sender: ${input.blockUrl}`,
    '',
    `You're getting this because ${input.sender} entered your email address in Pebble Routines. If you don't know them, ignore this email or block the sender.`,
    footerText(input),
  ].join('\n');

  const sample: EmailStep[] = [
    { title: 'Front door locked', time: '08:01', skipped: false },
    { title: 'Back door locked', time: '08:02', skipped: false },
    { title: 'Hob off', time: '08:02', skipped: false },
  ];

  const html = shell({
    preheader: `${input.sender} would like Pebble to email you when they complete a routine.`,
    body: `
      ${eyebrow('Invitation')}
      ${heading('Allow completion emails?')}
      ${para(`<strong class="pb-ink" style="color:${C.ink};font-weight:700;">${esc(input.sender)}</strong> would like Pebble Routines to email you when they complete one of their routines.`, { size: 17 })}
      ${box(`
        <p class="pb-muted" style="margin:0 0 12px;color:${C.muted};font-size:12px;line-height:1.4;font-weight:700;letter-spacing:0.8px;text-transform:uppercase;">Each email shows</p>
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;">
          ${included.map((item) => checkItem(item, true)).join('')}
          ${checkItem(PHOTO_NOTE, false)}
        </table>
        <p class="pb-muted" style="margin:10px 0 0;color:${C.muted};font-size:14px;line-height:1.55;">${esc(AI_NOTE)}</p>`)}
      ${input.includeStepCount ? samplePreview(sample, input.includeRoutineName) : ''}
      ${button('Allow completion emails', input.acceptUrl)}
      ${para(`Nothing is sent unless you allow it. You can stop the emails at any time from any email. This invitation expires on ${esc(expires)}.`, { size: 14, muted: true })}
      ${linkRow('Not interested?', [
        { label: 'Decline', url: input.declineUrl },
        { label: 'Block this sender', url: input.blockUrl },
      ])}`,
    footer: `You're getting this because ${esc(input.sender)} entered your email address in Pebble Routines. If you don't know them, ignore this email or block the sender.`,
    common: input,
  });

  return {
    subject: 'Allow completion emails from Pebble?',
    html,
    text,
    headers: listHeaders(input.oneClickUrl),
  };
}

export function buildCompletionEmail(input: EmailCommon & {
  /** null when the sender chose to hide the routine name. */
  routineTitle: string | null;
  completedAtText: string;
  /** The completion time split for the hero. Falls back to completedAtText. */
  completedAtParts?: { time: string; day: string; zone: string | null } | null;
  steps: { completed: number; total: number } | null;
  /**
   * Each step with the time it was checked, in run order. Only passed when
   * the sender shares steps; empty when the app didn't send them.
   */
  stepList?: EmailStep[];
  /** Steps left off the end of stepList to keep the email short. */
  moreSteps?: number;
  /** AI photo descriptions the sender chose to add. Already cleaned. */
  descriptions?: string[];
  stopUrl: string;
  blockUrl: string;
  oneClickUrl: string;
}): BuiltEmail {
  const what = input.routineTitle ? `“${input.routineTitle}”` : 'a routine';
  const stepList = input.steps ? input.stepList ?? [] : [];
  const moreSteps = stepList.length ? input.moreSteps ?? 0 : 0;
  const skipped = stepList.filter((s) => s.skipped).length;
  const stepsText = input.steps
    ? `${input.steps.completed} of ${input.steps.total}${skipped ? `, ${skipped} skipped` : ''}`
    : null;
  const parts = input.completedAtParts ?? null;
  const sentNote = 'Pebble sent this automatically when the routine was marked complete.';
  const descriptions = input.descriptions ?? [];
  const aiNote = `Written by AI from ${input.sender}'s photos. The descriptions can be wrong.`;
  const sentence = input.routineTitle
    ? `${esc(input.sender)} completed <strong class="pb-ink" style="color:${C.ink};font-weight:700;">${esc(input.routineTitle)}</strong>.`
    : `${esc(input.sender)} completed a routine in Pebble Routines.`;

  const text = [
    'Routine completed',
    '',
    `${input.sender} completed ${input.routineTitle ? `“${input.routineTitle}”` : 'a routine in Pebble Routines'}.`,
    '',
    ...(input.routineTitle ? [`Routine: ${input.routineTitle}`] : []),
    `Completed: ${input.completedAtText}`,
    ...(stepsText ? [`Steps: ${stepsText}`] : []),
    '',
    ...(stepList.length
      ? [
        ...stepList.map((s) => `${s.skipped ? '–' : '✓'} ${s.title}  ${s.skipped ? 'Skipped' : s.time ?? ''}`.trimEnd()),
        ...(moreSteps ? [`…and ${moreSteps} more ${moreSteps === 1 ? 'step' : 'steps'}`] : []),
        '',
      ]
      : []),
    ...(descriptions.length
      ? ['Photo descriptions', aiNote, ...descriptions.map((d, i) => `Photo ${i + 1}: ${d}`), '']
      : []),
    sentNote,
    '',
    `Stop these emails: ${input.stopUrl}`,
    `Block this sender: ${input.blockUrl}`,
    '',
    `You're getting this because you allowed completion emails from ${input.sender}. If you stop them, they'll see that the emails are off.`,
    footerText(input),
  ].join('\n');

  const hero = parts
    ? `
      <p class="pb-time" style="margin:0;color:${C.forest};font-family:${SERIF};font-size:60px;line-height:1;font-weight:400;letter-spacing:-1px;font-variant-numeric:tabular-nums;">${esc(parts.time)}</p>
      <p class="pb-muted" style="margin:10px 0 22px;color:${C.muted};font-size:15px;line-height:1.5;">${esc(parts.day)}${parts.zone ? `<span style="color:${C.faint};">&nbsp;&nbsp;·&nbsp;&nbsp;</span>${esc(parts.zone)}` : ''}</p>`
    : `
      <p class="pb-heading" style="margin:0 0 22px;color:${C.forest};font-family:${SERIF};font-size:26px;line-height:1.25;">${esc(input.completedAtText)}</p>`;

  const stepsCard = stepList.length
    ? box(`
        ${cardHead('Steps', stepsText ?? '')}
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;">
          ${stepList.map((s, i) => stepRow(s, i < stepList.length - 1 || moreSteps > 0)).join('')}
          ${moreSteps ? `<tr><td colspan="3" class="pb-muted" style="padding:12px 0 2px;color:${C.muted};font-size:14px;line-height:1.4;">…and ${moreSteps} more ${moreSteps === 1 ? 'step' : 'steps'}</td></tr>` : ''}
        </table>`, 'padding:18px 20px 10px;')
    : stepsText
    ? box(cardHead('Steps', stepsText).replace('margin:0 0 6px', 'margin:0'), 'padding:16px 20px;')
    : '';

  const html = shell({
    preheader: `${input.sender} completed ${what} at ${input.completedAtText}.`,
    body: `
      ${cairn(input.steps ? input.steps.total : 3, skipped)}
      ${eyebrow('Routine completed', true)}
      ${hero}
      ${para(sentence, { size: 17 })}
      ${stepsCard}
      ${descriptions.length
        ? box(`
        <p class="pb-muted" style="margin:0 0 6px;color:${C.muted};font-size:12px;line-height:1.4;font-weight:700;letter-spacing:0.8px;text-transform:uppercase;">Photo descriptions</p>
        <p class="pb-muted" style="margin:0 0 10px;color:${C.muted};font-size:14px;line-height:1.5;">${esc(aiNote)}</p>
        ${descriptions.map((d, i) => `<p class="pb-ink" style="margin:0 0 6px;color:${C.body};font-size:15px;line-height:1.55;overflow-wrap:anywhere;word-break:break-word;"><span class="pb-muted" style="color:${C.muted};">Photo ${i + 1}:</span> ${esc(d)}</p>`).join('')}`)
        : ''}
      ${para(esc(sentNote), { size: 14, muted: true })}
      ${linkRow(null, [
        { label: 'Stop these emails', url: input.stopUrl },
        { label: 'Block this sender', url: input.blockUrl },
      ])}`,
    footer: `You're getting this because you allowed completion emails from ${esc(input.sender)}. If you stop them, they'll see that the emails are off.`,
    common: input,
  });

  return {
    // Generic on purpose: subjects show on lock screens and in notification
    // previews, and a routine name can be personal.
    subject: 'Routine completed · Pebble',
    html,
    text,
    headers: listHeaders(input.oneClickUrl),
  };
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

export function esc(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function listHeaders(oneClickUrl: string): Record<string, string> {
  return {
    // RFC 2369 + RFC 8058: mail apps show an Unsubscribe button and POST
    // "List-Unsubscribe=One-Click" to this URL.
    'List-Unsubscribe': `<${oneClickUrl}>`,
    'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
    // RFC 3834: tells autoresponders not to reply.
    'Auto-Submitted': 'auto-generated',
  };
}

function footerText(common: EmailCommon): string {
  return [`Pebble Routines · Privacy: ${common.privacyUrl}`, common.footerAddress ?? '']
    .filter(Boolean)
    .join('\n');
}

/** Light palette. The dark variant lives in the <style> block in shell(). */
const C = {
  page: '#f3ece0',
  card: '#fffdf7',
  cardBorder: '#e6decd',
  tint: '#f4f1e6',
  tintBorder: '#e4e0d0',
  rule: '#e8e2d2',
  forest: '#193f36',
  ink: '#1f2a24',
  body: '#2d3a30',
  muted: '#5b665f',
  faint: '#9aa39c',
  sage: '#4e7a58',
  sageMid: '#76a07d',
  sageLight: '#a9c7ab',
  sageWash: '#e3ece1',
  onSage: '#ffffff',
} as const;

const SERIF = "'DM Serif Display',Georgia,'Iowan Old Style','Palatino Linotype','Times New Roman',serif";
const SANS = "'DM Sans',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";

function heading(text: string): string {
  return `<h1 class="pb-heading pb-title" style="margin:0 0 14px;color:${C.forest};font-family:${SERIF};font-size:34px;line-height:1.12;font-weight:400;letter-spacing:-0.3px;">${esc(text)}</h1>`;
}

function eyebrow(text: string, done = false): string {
  const dot = done
    ? `<span class="pb-dot" style="display:inline-block;width:8px;height:8px;border-radius:4px;background:${C.sage};vertical-align:1px;margin-right:8px;"></span>`
    : '';
  return `<p class="pb-eyebrow" style="margin:0 0 14px;color:${C.sage};font-size:12px;line-height:1.4;font-weight:700;letter-spacing:1.2px;text-transform:uppercase;">${dot}${esc(text)}</p>`;
}

function para(html: string, opts: { size?: number; muted?: boolean } = {}): string {
  const size = opts.size ?? 16;
  const cls = opts.muted ? 'pb-muted' : 'pb-ink';
  const color = opts.muted ? C.muted : C.body;
  return `<p class="${cls}" style="margin:0 0 24px;color:${color};font-size:${size}px;line-height:1.6;overflow-wrap:anywhere;word-break:break-word;">${html}</p>`;
}

function box(inner: string, padding = 'padding:18px 20px;'): string {
  return `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;margin:0 0 26px;">
    <tr><td class="pb-box" style="${padding}background:${C.tint};border:1px solid ${C.tintBorder};border-radius:16px;">${inner}</td></tr>
  </table>`;
}

function cardHead(label: string, right: string): string {
  return `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;margin:0 0 6px;"><tr>
    <td class="pb-muted" style="color:${C.muted};font-size:12px;line-height:1.4;font-weight:700;letter-spacing:0.8px;text-transform:uppercase;">${esc(label)}</td>
    <td align="right" class="pb-done" style="color:${C.sage};font-size:14px;line-height:1.4;font-weight:700;">${esc(right)}</td>
  </tr></table>`;
}

/** A round marker: a filled sage check for done, an outlined dash for skipped. */
function marker(done: boolean, size = 22): string {
  return done
    ? `<td class="pb-check" width="${size}" height="${size}" align="center" valign="middle" style="width:${size}px;height:${size}px;background:${C.sage};border-radius:${size / 2}px;color:${C.onSage};font-size:${Math.round(size * 0.55)}px;line-height:${size}px;font-weight:700;" aria-hidden="true">&#10003;</td>`
    : `<td class="pb-skip" width="${size - 2}" height="${size - 2}" align="center" valign="middle" style="width:${size - 2}px;height:${size - 2}px;border:1px solid ${C.faint};border-radius:${size / 2}px;color:${C.faint};font-size:${Math.round(size * 0.55)}px;line-height:${size - 2}px;" aria-hidden="true">&ndash;</td>`;
}

function stepRow(step: EmailStep, rule: boolean): string {
  const border = rule ? `border-bottom:1px solid ${C.rule};` : '';
  const right = step.skipped
    ? `<span class="pb-muted" style="color:${C.muted};font-size:14px;font-style:italic;">Skipped</span>`
    : step.time
    ? `<span class="pb-ink" style="color:${C.ink};font-size:15px;font-weight:700;font-variant-numeric:tabular-nums;white-space:nowrap;">${esc(step.time)}</span>`
    : '';
  return `<tr>
      <td class="pb-rule" valign="middle" width="34" style="width:34px;padding:11px 0;${border}">
        <table role="presentation" cellspacing="0" cellpadding="0" border="0"><tr>${marker(!step.skipped)}</tr></table>
      </td>
      <td class="pb-rule ${step.skipped ? 'pb-muted' : 'pb-ink'}" valign="middle" style="padding:11px 12px 11px 0;${border}color:${step.skipped ? C.muted : C.body};font-size:15px;line-height:1.4;overflow-wrap:anywhere;word-break:break-word;">${esc(step.title)}</td>
      <td class="pb-rule" align="right" valign="middle" style="padding:11px 0;${border}white-space:nowrap;">${right}</td>
    </tr>`;
}

function checkItem(text: string, included: boolean): string {
  return `<tr>
      <td valign="top" width="32" style="width:32px;padding:3px 0 9px;">
        <table role="presentation" cellspacing="0" cellpadding="0" border="0"><tr>${marker(included, 20)}</tr></table>
      </td>
      <td valign="top" class="${included ? 'pb-ink' : 'pb-muted'}" style="padding:3px 0 9px;color:${included ? C.body : C.muted};font-size:15px;line-height:20px;">${esc(text)}</td>
    </tr>`;
}

/** A small, clearly labelled example of a completion email, for invitations. */
function samplePreview(steps: EmailStep[], withName: boolean): string {
  return `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;margin:0 0 28px;">
    <tr><td class="pb-sample" style="padding:18px 20px 8px;background:${C.card};border:1px dashed ${C.cardBorder};border-radius:16px;">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;margin:0 0 4px;"><tr>
        <td class="pb-muted" style="color:${C.muted};font-size:12px;line-height:1.4;font-weight:700;letter-spacing:0.8px;text-transform:uppercase;">Example</td>
        <td align="right" class="pb-muted" style="color:${C.faint};font-size:12px;line-height:1.4;">Not a real routine</td>
      </tr></table>
      <p class="pb-time" style="margin:6px 0 2px;color:${C.forest};font-family:${SERIF};font-size:34px;line-height:1.1;font-variant-numeric:tabular-nums;">08:02</p>
      <p class="pb-muted" style="margin:0 0 6px;color:${C.muted};font-size:14px;line-height:1.5;">${withName ? 'Leaving the house&nbsp;&nbsp;·&nbsp;&nbsp;' : ''}3 of 3 steps</p>
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;">
        ${steps.map((s, i) => stepRow(s, i < steps.length - 1)).join('')}
      </table>
    </td></tr>
  </table>`;
}

/**
 * The cairn from the completion screen: one pebble per step (at most five),
 * skipped steps as outlines. Drawn with rounded blocks, so it needs no image.
 * Outlook on Windows can't round corners, so it gets nothing here and the
 * brand row's text mark carries the identity instead.
 */
function cairn(total: number, skipped: number): string {
  const count = Math.max(1, Math.min(5, total));
  const outlined = skipped <= 0
    ? 0
    : skipped >= total
    ? count
    : Math.min(count - 1, total <= 5 ? skipped : Math.max(1, Math.round((skipped * count) / total)));
  const fills = [C.sage, C.sageMid, C.sageLight, '#c9b48a', '#d9a383'];
  const dx = [0, -3, 4, -2, 3];
  const rows: string[] = [];
  for (let i = count - 1; i >= 0; i--) {
    const w = count === 1 ? 64 : Math.round(64 - (28 * i) / (count - 1));
    const h = Math.round(w * 0.46);
    const isOutline = i >= count - outlined;
    const fill = isOutline
      ? `border:2px solid ${C.faint};width:${w - 4}px;height:${h - 4}px;`
      : `background:${fills[i]};width:${w}px;height:${h}px;`;
    const left = Math.round((72 - w) / 2 + dx[i]);
    rows.push(`<div class="${isOutline ? 'pb-pebble-out' : `pb-pebble pb-pebble-${i}`}" style="${fill}margin:0 0 ${i === 0 ? 0 : -2}px ${left}px;border-radius:50%;font-size:0;line-height:0;">&nbsp;</div>`);
  }
  const label = skipped > 0 ? `${total - skipped} of ${total} steps checked, ${skipped} skipped` : 'Routine completed';
  return `<!--[if !mso]><!-->
      <div role="img" aria-label="${esc(label)}" style="width:72px;margin:0 0 18px;">${rows.join('')}</div>
      <!--<![endif]-->`;
}

/** The small brand cairn above the card. */
function brandMark(): string {
  return `<!--[if !mso]><!-->
        <div aria-hidden="true" style="display:inline-block;width:26px;vertical-align:middle;">
          <div class="pb-pebble pb-pebble-2" style="width:12px;height:7px;margin:0 0 -1px 8px;border-radius:50%;background:${C.sageLight};font-size:0;line-height:0;">&nbsp;</div>
          <div class="pb-pebble pb-pebble-1" style="width:18px;height:9px;margin:0 0 -1px 3px;border-radius:50%;background:${C.sageMid};font-size:0;line-height:0;">&nbsp;</div>
          <div class="pb-pebble pb-pebble-0" style="width:26px;height:12px;margin:0;border-radius:50%;background:${C.sage};font-size:0;line-height:0;">&nbsp;</div>
        </div>
        <!--<![endif]-->`;
}

function button(label: string, url: string): string {
  return `<table role="presentation" cellspacing="0" cellpadding="0" border="0" class="pb-btn-wrap" style="margin:0 0 18px;">
    <tr><td class="pb-btn" align="center" style="background:${C.forest};border-radius:999px;">
      <a class="pb-btn-link" href="${esc(url)}" style="display:inline-block;padding:16px 30px;color:#ffffff;font-family:${SANS};font-size:16px;line-height:20px;font-weight:700;text-decoration:none;border-radius:999px;">${esc(label)}</a>
    </td></tr>
  </table>`;
}

function linkRow(lead: string | null, links: { label: string; url: string }[]): string {
  const anchors = links
    .map((l) => `<a class="pb-link" href="${esc(l.url)}" style="color:${C.forest};font-weight:600;text-decoration:underline;text-underline-offset:3px;">${esc(l.label)}</a>`)
    .join(`<span class="pb-muted" style="color:${C.faint};">&nbsp;&nbsp;·&nbsp;&nbsp;</span>`);
  const leadHtml = lead ? `<span class="pb-muted" style="color:${C.muted};">${esc(lead)}</span>&nbsp; ` : '';
  return `<p style="margin:0;font-size:15px;line-height:1.8;">${leadHtml}${anchors}</p>`;
}

function shell(input: {
  preheader: string;
  body: string;
  footer: string;
  common: EmailCommon;
}): string {
  const address = input.common.footerAddress
    ? `<br>${esc(input.common.footerAddress)}`
    : '';
  return `<!doctype html>
<html lang="en-GB" xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<meta name="x-apple-disable-message-reformatting">
<title>Pebble Routines</title>
<style>
  body { margin:0 !important; padding:0 !important; width:100% !important; }
  a { color:${C.forest}; }
  @media only screen and (max-width:620px) {
    .pb-outer { padding:16px 10px 28px !important; }
    .pb-pad { padding-left:22px !important; padding-right:22px !important; }
    .pb-title { font-size:29px !important; }
    .pb-time { font-size:52px !important; }
    .pb-btn-wrap { width:100% !important; }
    .pb-btn-link { display:block !important; }
  }
  @media (prefers-color-scheme: dark) {
    .pb-bg { background:#121512 !important; }
    .pb-card { background:#1b1f1b !important; border-color:#2b322c !important; }
    .pb-heading, .pb-time { color:#e4efe2 !important; }
    .pb-ink { color:#e9ede6 !important; }
    .pb-muted { color:#b2bdb3 !important; }
    .pb-eyebrow, .pb-done { color:#9ccaa1 !important; }
    .pb-box { background:#222823 !important; border-color:#323b33 !important; }
    .pb-sample { background:#1b1f1b !important; border-color:#3a443b !important; }
    .pb-rule { border-color:#323b33 !important; }
    .pb-check, .pb-dot { background:#8db592 !important; color:#10200f !important; }
    .pb-skip { border-color:#6f7a70 !important; color:#8c978d !important; }
    .pb-pebble-0 { background:#8db592 !important; }
    .pb-pebble-1 { background:#6f9a75 !important; }
    .pb-pebble-2 { background:#55785b !important; }
    .pb-pebble-out { border-color:#6f7a70 !important; }
    .pb-btn { background:#cfe3d5 !important; }
    .pb-btn-link { color:#0f201a !important; }
    .pb-link, a { color:#cfe3d5 !important; }
  }
</style>
</head>
<body class="pb-bg" style="margin:0;padding:0;background:${C.page};font-family:${SANS};color:${C.ink};-webkit-text-size-adjust:100%;">
<div style="display:none;max-height:0;max-width:0;overflow:hidden;opacity:0;mso-hide:all;font-size:1px;line-height:1px;color:${C.page};">${esc(input.preheader)}&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" class="pb-bg pb-outer" style="width:100%;background:${C.page};padding:28px 16px 40px;">
  <tr><td align="center">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;max-width:560px;">
      <tr><td align="center" style="padding:4px 0 18px;font-family:${SANS};">
        ${brandMark()}
        <span class="pb-heading" style="display:inline-block;margin-left:8px;color:${C.forest};font-family:${SERIF};font-size:20px;line-height:24px;vertical-align:middle;">Pebble</span>
      </td></tr>
    </table>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" class="pb-card" style="width:100%;max-width:560px;background:${C.card};border:1px solid ${C.cardBorder};border-radius:24px;">
      <tr><td class="pb-pad" style="padding:36px 36px 32px;font-family:${SANS};">
        ${input.body}
      </td></tr>
    </table>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;max-width:560px;">
      <tr><td class="pb-pad" align="center" style="padding:22px 28px 0;font-family:${SANS};">
        <p class="pb-muted" style="margin:0 0 10px;color:${C.muted};font-size:13px;line-height:1.6;overflow-wrap:anywhere;word-break:break-word;">${input.footer}</p>
        <p class="pb-muted" style="margin:0;color:${C.muted};font-size:13px;line-height:1.6;">Pebble Routines &nbsp;·&nbsp; <a class="pb-link" href="${esc(input.common.privacyUrl)}" style="color:${C.forest};text-decoration:underline;">Privacy</a>${address}</p>
      </td></tr>
    </table>
  </td></tr>
</table>
</body>
</html>`;
}
