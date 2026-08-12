/**
 * Transactional email.
 *
 * WEA sends few messages, but each one arrives at a moment that matters: an
 * account has just been created, a registration has just been received, a
 * payment has just cleared. So three properties are built in.
 *
 * **Sending never breaks the thing that triggered it.** Every send is fire and
 * forget from the caller's point of view, and a provider outage is recorded
 * rather than raised. Nobody's payment fails because a mail server was busy.
 *
 * **Wording is the academy's.** The copy comes from site settings a Super
 * Admin edits, not from strings in this file.
 *
 * **The provider is configuration.** Zoho is implemented, but the rest of the
 * application asks for "send the welcome message", not for Zoho.
 */

import { newId } from './auth';
import { str } from './http';

export interface EmailConfig {
  /**
   * Zoho ZeptoMail send-mail token. A secret.
   *
   * ZeptoMail is Zoho's transactional product and speaks HTTPS; ordinary Zoho
   * Mail is IMAP/SMTP, which a Worker cannot authenticate against.
   */
  ZEPTOMAIL_TOKEN?: string;
  /** Regional host, e.g. api.zeptomail.com or api.zeptomail.eu. */
  ZEPTOMAIL_HOST?: string;
  /** The verified sending address, e.g. no-reply@wucoexecutiveacademy.org. */
  EMAIL_FROM_ADDRESS?: string;
}

export interface Recipient {
  email: string;
  name?: string;
}

export type EmailTemplate =
  | 'welcome'
  | 'event_registration_received'
  | 'event_payment_receipt'
  | 'event_payment_failed'
  | 'programme_registration_received'
  | 'programme_confirmed';

interface RenderedEmail {
  subject: string;
  heading: string;
  intro: string;
  /** Label/value pairs shown as a summary block. */
  facts: [string, string][];
  /** A closing paragraph, where one adds something. */
  outro?: string;
  action?: { label: string; url: string };
}

// ---------------------------------------------------------------------------
// Presentation
// ---------------------------------------------------------------------------

const escapeHtml = (value: string) =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

/**
 * The message as HTML.
 *
 * Deliberately plain: tables, inline styles and no external assets, because
 * that is what survives Outlook, Gmail's clipping and an image blocker. The
 * navy and azure are the academy's, so a receipt still looks like WEA.
 */
function renderHtml(email: RenderedEmail, signature: string): string {
  const facts = email.facts
    .filter(([, value]) => str(value) !== '')
    .map(
      ([label, value]) => `
        <tr>
          <td style="padding:6px 16px 6px 0;color:#64738A;font-size:13px;white-space:nowrap;vertical-align:top;">${escapeHtml(label)}</td>
          <td style="padding:6px 0;color:#0A1E3D;font-size:14px;font-weight:600;">${escapeHtml(value)}</td>
        </tr>`,
    )
    .join('');

  const action = email.action
    ? `<tr><td style="padding:24px 0 0;">
         <a href="${escapeHtml(email.action.url)}"
            style="display:inline-block;background:#1B6FC4;color:#ffffff;text-decoration:none;
                   padding:12px 22px;font-size:14px;font-weight:600;letter-spacing:.04em;">
           ${escapeHtml(email.action.label)}
         </a>
       </td></tr>`
    : '';

  return `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#F4F7FB;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F4F7FB;padding:32px 16px;">
<tr><td align="center">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
         style="max-width:560px;background:#ffffff;border:1px solid #DCE4EF;">
    <tr><td style="background:#0A1E3D;padding:22px 28px;">
      <div style="color:#F5F8FC;font-size:15px;font-weight:700;letter-spacing:.08em;">
        WUCO EXECUTIVE ACADEMY
      </div>
    </td></tr>
    <tr><td style="padding:30px 28px;font-family:Helvetica,Arial,sans-serif;">
      <h1 style="margin:0 0 12px;font-size:21px;line-height:1.3;color:#0A1E3D;font-weight:700;">
        ${escapeHtml(email.heading)}
      </h1>
      <p style="margin:0 0 20px;font-size:15px;line-height:1.6;color:#4A5A70;">
        ${escapeHtml(email.intro)}
      </p>
      ${facts ? `<table role="presentation" cellpadding="0" cellspacing="0" style="border-top:1px solid #DCE4EF;border-bottom:1px solid #DCE4EF;width:100%;margin:0 0 4px;padding:8px 0;">${facts}</table>` : ''}
      ${email.outro ? `<p style="margin:20px 0 0;font-size:14px;line-height:1.6;color:#4A5A70;">${escapeHtml(email.outro)}</p>` : ''}
      <table role="presentation" cellpadding="0" cellspacing="0">${action}</table>
    </td></tr>
    <tr><td style="padding:18px 28px;border-top:1px solid #DCE4EF;background:#F7F9FC;">
      <p style="margin:0;font-size:12px;line-height:1.6;color:#64738A;white-space:pre-line;">${escapeHtml(signature)}</p>
    </td></tr>
  </table>
</td></tr></table>
</body></html>`;
}

/** The same message as plain text, for clients that prefer or require it. */
function renderText(email: RenderedEmail, signature: string): string {
  const lines = [email.heading, '', email.intro, ''];
  for (const [label, value] of email.facts) {
    if (str(value) !== '') lines.push(`${label}: ${value}`);
  }
  if (email.action) lines.push('', `${email.action.label}: ${email.action.url}`);
  if (email.outro) lines.push('', email.outro);
  lines.push('', signature);
  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// Delivery
// ---------------------------------------------------------------------------

interface SendOutcome {
  status: 'SENT' | 'FAILED' | 'SKIPPED';
  detail: string;
}

/**
 * Hands the message to Zoho.
 *
 * With no token configured this reports SKIPPED rather than failing, so a
 * deployment without mail set up still registers people and takes payments —
 * it simply does not write to them, and the log says so.
 */
async function deliver(
  config: EmailConfig,
  to: Recipient,
  fromName: string,
  subject: string,
  html: string,
  text: string,
): Promise<SendOutcome> {
  const token = str(config.ZEPTOMAIL_TOKEN);
  const from = str(config.EMAIL_FROM_ADDRESS);
  if (token === '' || from === '') {
    return {
      status: 'SKIPPED',
      detail: 'No mail provider configured.',
    };
  }

  const host = str(config.ZEPTOMAIL_HOST) || 'api.zeptomail.com';

  try {
    const response = await fetch(`https://${host}/v1.1/email`, {
      method: 'POST',
      headers: {
        // ZeptoMail's scheme, not a bearer token.
        Authorization: `Zoho-enczapikey ${token}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        from: { address: from, name: fromName },
        to: [{ email_address: { address: to.email, name: to.name ?? '' } }],
        subject,
        htmlbody: html,
        textbody: text,
      }),
    });

    if (response.ok) return { status: 'SENT', detail: '' };

    const body = await response.text().catch(() => '');
    return {
      status: 'FAILED',
      // Truncated, and never echoed to a user: it can carry provider detail.
      detail: `${response.status} ${body}`.slice(0, 300),
    };
  } catch (error) {
    return { status: 'FAILED', detail: `${error}`.slice(0, 300) };
  }
}

// ---------------------------------------------------------------------------
// Templates
// ---------------------------------------------------------------------------

type Settings = Record<string, string>;

async function loadSettings(db: D1Database): Promise<Settings> {
  const rows = await db
    .prepare(
      `SELECT key, value FROM site_settings
        WHERE key LIKE 'email_%' OR key = 'public_site_url' OR key = 'contact_email'`,
    )
    .all<{ key: string; value: string }>();
  return Object.fromEntries(rows.results.map((row) => [row.key, row.value]));
}

export interface EmailContext {
  /** Who it is going to. */
  to: Recipient;
  /** Everything the template needs, already resolved by the caller. */
  data: Record<string, string>;
  /** Links back into the application. */
  reference?: string;
  userId?: string;
}

function build(
  template: EmailTemplate,
  context: EmailContext,
  settings: Settings,
): RenderedEmail {
  const site = (settings.public_site_url ?? '').replace(/\/$/, '');
  const data = context.data;
  const name = str(data.first_name) || 'there';

  switch (template) {
    case 'welcome':
      return {
        subject: 'Welcome to WUCO Executive Academy',
        heading: `Welcome, ${name}.`,
        intro:
          settings.email_welcome_intro ??
          'Your WUCO Executive Academy account is ready.',
        facts: [['Account', context.to.email]],
        action: { label: 'EXPLORE PROGRAMMES', url: `${site}/programmes` },
        outro:
          'If you did not create this account, please tell the academy office and we will remove it.',
      };

    case 'event_registration_received':
      return {
        subject: `Registration received — ${data.event_title}`,
        heading: 'We have your registration.',
        intro:
          settings.email_registration_intro ??
          'We have received your registration.',
        facts: [
          ['Event', data.event_title],
          ['Date', data.event_date],
          ['Reference', str(context.reference)],
          ['Registration fee', data.amount],
          ['Status', data.status],
        ],
        action: {
          label: 'VIEW YOUR REGISTRATION',
          url: `${site}/events/registration/${context.reference}`,
        },
        outro: str(data.payment_instructions) || undefined,
      };

    case 'event_payment_receipt':
      return {
        subject: `Payment received — ${data.event_title}`,
        heading: 'Your place is confirmed.',
        intro:
          settings.email_receipt_intro ??
          'Your payment has been received and verified.',
        facts: [
          ['Event', data.event_title],
          ['Date', data.event_date],
          ['Registrant', data.full_name],
          ['Reference', str(context.reference)],
          ['Amount paid', data.amount],
          ['Payment reference', data.payment_reference],
        ],
        action: {
          label: 'GO TO EVENT DASHBOARD',
          url: `${site}/events/registration/${context.reference}`,
        },
        outro:
          'This message is your receipt. Programme materials and joining details appear on your event dashboard.',
      };

    case 'event_payment_failed':
      return {
        subject: `Payment not completed — ${data.event_title}`,
        heading: 'Your payment did not go through.',
        intro:
          'Your registration has been saved, so nothing is lost. The payment was not successful, and you can try again whenever you are ready.',
        facts: [
          ['Event', data.event_title],
          ['Reference', str(context.reference)],
          ['Amount due', data.amount],
        ],
        action: {
          label: 'TRY PAYMENT AGAIN',
          url: `${site}/events/registration/${context.reference}`,
        },
      };

    case 'programme_registration_received':
      return {
        subject: `Application received — ${data.programme_title}`,
        heading: 'We have your application.',
        intro:
          settings.email_registration_intro ??
          'We have received your registration.',
        facts: [
          ['Programme', data.programme_title],
          ['Reference', str(context.reference)],
          ['Tuition', data.amount],
        ],
        action: { label: 'VIEW YOUR APPLICATION', url: `${site}/programmes` },
        outro: str(data.payment_instructions) || undefined,
      };

    case 'programme_confirmed':
      return {
        subject: `Your place is confirmed — ${data.programme_title}`,
        heading: 'Your place is confirmed.',
        intro:
          settings.email_receipt_intro ??
          'Your payment has been received and your place is confirmed.',
        facts: [
          ['Programme', data.programme_title],
          ['Reference', str(context.reference)],
          ['Amount', data.amount],
        ],
        action: { label: 'GO TO YOUR DASHBOARD', url: `${site}/learner` },
      };
  }
}

// ---------------------------------------------------------------------------
// The one function the rest of the application calls
// ---------------------------------------------------------------------------

export interface MailEnv extends EmailConfig {
  WEA_DB: D1Database;
}

/**
 * Sends one message and records what happened.
 *
 * Never throws. Call it from `ctx.waitUntil` so the response goes back to the
 * caller without waiting on a mail server.
 */
export async function sendTemplate(
  env: MailEnv,
  template: EmailTemplate,
  context: EmailContext,
): Promise<void> {
  const recipient = str(context.to.email).toLowerCase();
  if (!recipient.includes('@')) return;

  let outcome: SendOutcome = { status: 'FAILED', detail: 'not attempted' };
  let subject = '';

  try {
    const settings = await loadSettings(env.WEA_DB);
    const email = build(template, context, settings);
    subject = email.subject;
    const signature =
      settings.email_signature ?? 'WUCO Executive Academy';
    const fromName = settings.email_from_name ?? 'WUCO Executive Academy';

    outcome = await deliver(
      env,
      { email: recipient, name: context.to.name },
      fromName,
      subject,
      renderHtml(email, signature),
      renderText(email, signature),
    );
  } catch (error) {
    outcome = { status: 'FAILED', detail: `${error}`.slice(0, 300) };
  }

  // The log is written whatever happened, including SKIPPED, so the office can
  // always answer "was anything sent to this person".
  try {
    await env.WEA_DB.prepare(
      `INSERT INTO email_log
         (id, template, recipient, subject, reference, user_id, status, detail)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)`,
    )
      .bind(
        newId(),
        template,
        recipient,
        subject,
        str(context.reference),
        context.userId ?? null,
        outcome.status,
        outcome.detail,
      )
      .run();
  } catch {
    // If even the log cannot be written there is nothing useful left to do,
    // and it must not surface as a failure of the caller's request.
  }
}
