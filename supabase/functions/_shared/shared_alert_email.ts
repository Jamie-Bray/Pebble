// Invitation and completion email templates. Pure functions: every dynamic
// value is escaped here, so callers pass raw strings.
//
// Design: Pebble's website palette (cream, paper, forest green) with a serif
// heading, a single-column 560px card that becomes full-width on phones, and
// a dark-mode variant for clients that honour prefers-color-scheme.

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
    input.includeRoutineName ? 'the routine name' : null,
    'the time it was completed',
    input.includeStepCount ? 'how many steps were completed' : null,
  ].filter((x): x is string => x !== null);
  const includedSentence = `Each email shows ${joinList(included)}. Photos and checklist details are not included.`;
  const expires = formatDate(input.expiresAt);

  const text = [
    'Allow completion emails?',
    '',
    `${input.sender} would like Pebble Routines to email you when they complete one of their routines.`,
    '',
    includedSentence,
    'You can stop the emails at any time from any email.',
    '',
    `Allow completion emails: ${input.acceptUrl}`,
    '',
    `Nothing is sent unless you allow it. This invitation expires on ${expires}.`,
    '',
    `Decline: ${input.declineUrl}`,
    `Block this sender: ${input.blockUrl}`,
    '',
    `You are receiving this because ${input.sender} entered your email address in Pebble Routines. If you don't know them, ignore this email or block the sender.`,
    footerText(input),
  ].join('\n');

  const html = shell({
    preheader: `${input.sender} would like Pebble to email you when they complete a routine.`,
    eyebrow: 'Invitation',
    body: `
      ${heading('Allow completion emails?')}
      ${para(`<strong class="pb-ink" style="color:#182522;">${esc(input.sender)}</strong> would like Pebble Routines to email you when they complete one of their routines.`, { size: 17 })}
      ${box(`
        <p class="pb-ink" style="margin:0 0 6px;color:#182522;font-size:14px;line-height:1.4;font-weight:700;">What the emails show</p>
        <p class="pb-muted" style="margin:0 0 8px;color:#45524c;font-size:15px;line-height:1.55;">${esc(includedSentence)}</p>
        <p class="pb-muted" style="margin:0;color:#45524c;font-size:15px;line-height:1.55;">You can stop them at any time from any email.</p>`)}
      ${button('Allow completion emails', input.acceptUrl)}
      ${para(`Nothing is sent unless you allow it. This invitation expires on ${esc(expires)}.`, { size: 14, muted: true })}
      ${linkRow('Not interested?', [
        { label: 'Decline', url: input.declineUrl },
        { label: 'Block this sender', url: input.blockUrl },
      ])}`,
    footer: `You are receiving this because ${esc(input.sender)} entered your email address in Pebble Routines. If you don't know them, ignore this email or block the sender.`,
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
  steps: { completed: number; total: number } | null;
  stopUrl: string;
  blockUrl: string;
  oneClickUrl: string;
}): BuiltEmail {
  const what = input.routineTitle ? `“${input.routineTitle}”` : 'a routine';
  const stepsText = input.steps ? `${input.steps.completed} of ${input.steps.total}` : null;
  const rows: [string, string][] = [
    ...(input.routineTitle ? [['Routine', input.routineTitle] as [string, string]] : []),
    ['Completed', input.completedAtText],
    ...(stepsText ? [['Steps', stepsText] as [string, string]] : []),
  ];
  const sentNote = 'Sent automatically when the routine was marked complete in the Pebble app.';

  const text = [
    'Routine completed',
    '',
    `${input.sender} completed a routine in Pebble Routines.`,
    '',
    ...rows.map(([k, v]) => `${k}: ${v}`),
    '',
    sentNote,
    '',
    `Stop these emails: ${input.stopUrl}`,
    `Block this sender: ${input.blockUrl}`,
    '',
    `You are receiving this because you allowed completion emails from ${input.sender}. If you stop them, they will see that completion emails are off.`,
    footerText(input),
  ].join('\n');

  const detailRows = rows.map(([label, value], i) => {
    const border = i < rows.length - 1 ? 'border-bottom:1px solid #dfe5dc;' : '';
    return `<tr>
      <td class="pb-muted pb-rule" valign="top" style="padding:12px 12px 12px 0;${border}color:#55625c;font-size:14px;line-height:1.4;width:96px;">${esc(label)}</td>
      <td class="pb-ink pb-rule" valign="top" style="padding:12px 0;${border}color:#182522;font-size:16px;line-height:1.4;font-weight:700;word-break:break-word;">${esc(value)}</td>
    </tr>`;
  }).join('');

  const html = shell({
    preheader: `${input.sender} completed ${what} at ${input.completedAtText}.`,
    eyebrow: 'Completion email',
    body: `
      <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin:0 0 18px;">
        <tr><td class="pb-tick" align="center" valign="middle" width="44" height="44" style="width:44px;height:44px;background:#e3ece4;border-radius:22px;color:#193f36;font-size:22px;line-height:44px;font-weight:700;" aria-hidden="true">&#10003;</td></tr>
      </table>
      ${heading('Routine completed')}
      ${para(`<strong class="pb-ink" style="color:#182522;">${esc(input.sender)}</strong> completed a routine in Pebble Routines.`, { size: 17 })}
      ${box(`<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;">${detailRows}</table>`, 'padding:4px 20px;')}
      ${para(esc(sentNote), { size: 14, muted: true })}
      ${linkRow(null, [
        { label: 'Stop these emails', url: input.stopUrl },
        { label: 'Block this sender', url: input.blockUrl },
      ])}`,
    footer: `You are receiving this because you allowed completion emails from ${esc(input.sender)}. If you stop them, they will see that completion emails are off.`,
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

function joinList(items: string[]): string {
  if (items.length <= 1) return items.join('');
  return `${items.slice(0, -1).join(', ')} and ${items[items.length - 1]}`;
}

function footerText(common: EmailCommon): string {
  return [`Pebble Routines · Privacy: ${common.privacyUrl}`, common.footerAddress ?? '']
    .filter(Boolean)
    .join('\n');
}

const SERIF = "Georgia,'Iowan Old Style','Palatino Linotype','Times New Roman',serif";
const SANS = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";

function heading(text: string): string {
  return `<h1 class="pb-heading pb-title" style="margin:0 0 14px;color:#193f36;font-family:${SERIF};font-size:32px;line-height:1.15;font-weight:600;letter-spacing:-0.3px;">${esc(text)}</h1>`;
}

function para(html: string, opts: { size?: number; muted?: boolean } = {}): string {
  const size = opts.size ?? 16;
  const cls = opts.muted ? 'pb-muted' : 'pb-ink';
  const color = opts.muted ? '#55625c' : '#2a3631';
  return `<p class="${cls}" style="margin:0 0 22px;color:${color};font-size:${size}px;line-height:1.6;overflow-wrap:anywhere;word-break:break-word;">${html}</p>`;
}

function box(inner: string, padding = 'padding:16px 20px;'): string {
  return `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;margin:0 0 24px;">
    <tr><td class="pb-box" style="${padding}background:#eef3ec;border:1px solid #d8e2d6;border-radius:14px;">${inner}</td></tr>
  </table>`;
}

function button(label: string, url: string): string {
  return `<table role="presentation" cellspacing="0" cellpadding="0" border="0" class="pb-btn-wrap" style="margin:0 0 18px;">
    <tr><td class="pb-btn" align="center" style="background:#193f36;border-radius:12px;">
      <a class="pb-btn-link" href="${esc(url)}" style="display:inline-block;padding:15px 26px;color:#ffffff;font-family:${SANS};font-size:16px;line-height:20px;font-weight:700;text-decoration:none;border-radius:12px;">${esc(label)}</a>
    </td></tr>
  </table>`;
}

function linkRow(lead: string | null, links: { label: string; url: string }[]): string {
  const anchors = links
    .map((l) => `<a class="pb-link" href="${esc(l.url)}" style="color:#193f36;font-weight:600;text-decoration:underline;text-underline-offset:3px;">${esc(l.label)}</a>`)
    .join('<span class="pb-muted" style="color:#8a958f;">&nbsp;&nbsp;·&nbsp;&nbsp;</span>');
  const leadHtml = lead ? `<span class="pb-muted" style="color:#55625c;">${esc(lead)}</span>&nbsp; ` : '';
  return `<p style="margin:0;font-size:15px;line-height:1.8;">${leadHtml}${anchors}</p>`;
}

function shell(input: {
  preheader: string;
  eyebrow: string;
  body: string;
  footer: string;
  common: EmailCommon;
}): string {
  const address = input.common.footerAddress
    ? `<br>${esc(input.common.footerAddress)}`
    : '';
  return `<!doctype html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<title>Pebble Routines</title>
<style>
  body { margin:0 !important; padding:0 !important; width:100% !important; }
  a { color:#193f36; }
  @media only screen and (max-width:620px) {
    .pb-outer { padding:12px 8px !important; }
    .pb-pad { padding-left:22px !important; padding-right:22px !important; }
    .pb-title { font-size:27px !important; }
    .pb-btn-wrap { width:100% !important; }
    .pb-btn-link { display:block !important; }
  }
  @media (prefers-color-scheme: dark) {
    .pb-bg { background:#0f1715 !important; }
    .pb-card { background:#17211e !important; border-color:#2a3732 !important; }
    .pb-head { border-color:#2a3732 !important; }
    .pb-foot { background:#131c19 !important; border-color:#2a3732 !important; }
    .pb-heading { color:#d5e6da !important; }
    .pb-ink { color:#e8eee9 !important; }
    .pb-muted { color:#b3c0b9 !important; }
    .pb-box { background:#1d2a26 !important; border-color:#2f3f39 !important; }
    .pb-rule { border-color:#2f3f39 !important; }
    .pb-btn { background:#cfe3d5 !important; }
    .pb-btn-link { color:#0f201a !important; }
    .pb-link, a { color:#cfe3d5 !important; }
    .pb-mark { background:#cfe3d5 !important; color:#0f201a !important; }
    .pb-tick { background:#24352f !important; color:#cfe3d5 !important; }
  }
</style>
</head>
<body class="pb-bg" style="margin:0;padding:0;background:#f6efe2;font-family:${SANS};color:#182522;-webkit-text-size-adjust:100%;">
<div style="display:none;max-height:0;max-width:0;overflow:hidden;opacity:0;mso-hide:all;font-size:1px;line-height:1px;color:#f6efe2;">${esc(input.preheader)}&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" class="pb-bg pb-outer" style="width:100%;background:#f6efe2;padding:32px 16px;">
  <tr><td align="center">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" class="pb-card" style="width:100%;max-width:560px;background:#fffdf7;border:1px solid #e4dccb;border-radius:20px;">
      <tr><td class="pb-pad pb-head" style="padding:22px 32px;border-bottom:1px solid #eee6d6;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tr>
          <td valign="middle" style="font-family:${SANS};">
            <span class="pb-mark" style="display:inline-block;width:28px;height:28px;line-height:28px;text-align:center;border-radius:9px;background:#193f36;color:#fffaf1;font-family:${SERIF};font-size:16px;font-weight:700;vertical-align:middle;" aria-hidden="true">P</span>
            <span class="pb-heading" style="display:inline-block;margin-left:8px;color:#193f36;font-size:15px;font-weight:700;vertical-align:middle;">Pebble Routines</span>
          </td>
          <td align="right" valign="middle" class="pb-muted" style="color:#55625c;font-size:12px;font-weight:700;letter-spacing:0.6px;text-transform:uppercase;">${esc(input.eyebrow)}</td>
        </tr></table>
      </td></tr>
      <tr><td class="pb-pad" style="padding:32px 32px 30px;font-family:${SANS};">
        ${input.body}
      </td></tr>
      <tr><td class="pb-pad pb-foot" style="padding:18px 32px 22px;background:#faf6ed;border-top:1px solid #eee6d6;border-radius:0 0 20px 20px;">
        <p class="pb-muted" style="margin:0 0 8px;color:#55625c;font-size:13px;line-height:1.6;overflow-wrap:anywhere;word-break:break-word;">${input.footer}</p>
        <p class="pb-muted" style="margin:0;color:#55625c;font-size:13px;line-height:1.6;">Pebble Routines &nbsp;·&nbsp; <a class="pb-link" href="${esc(input.common.privacyUrl)}" style="color:#193f36;text-decoration:underline;">Privacy</a>${address}</p>
      </td></tr>
    </table>
  </td></tr>
</table>
</body>
</html>`;
}
